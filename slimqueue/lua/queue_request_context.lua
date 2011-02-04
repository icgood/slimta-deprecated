
local relay_request_context = require "relay_request_context"

-- {{{ tags table
local tags = {

    slimta = {},

    queue = {"slimta"},

    client = {"slimta", "queue",
        list = "clients",
    },

    protocol = {"slimta", "deliver", "client",
        handle = function (info, attrs, data)
            info.protocol = data:match("%S+")
        end,
    },

    host = {"slimta", "queue", "client",
        handle = function (info, attrs, data)
            info.host = data:match("%S+")
        end,
    },

    port = {"slimta", "queue", "client",
        handle = function (info, attrs, data)
            info.port = data:match("%d+")
        end,
    },

    security = {"slimta", "queue", "client",
        handle = function (info, attrs, data)
            -- Put security stuff here.
        end,
    },

    message = {"slimta", "queue", "client",
        list = "messages",
    },

    envelope = {"slimta", "queue", "client", "message"},

    sender = {"slimta", "queue", "client", "message", "envelope",
        handle = function (info, attrs, data)
            local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

            info.envelope = info.envelope or {}
            info.envelope.sender = stripped_data
        end,
    },

    recipient = {"slimta", "queue", "client", "message", "envelope",
        handle = function (info, attrs, data)
            local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

            info.envelope = info.envelope or {}
            info.envelope.recipients = info.envelope.recipients or {}
            table.insert(info.envelope.recipients, stripped_data)
        end,
    },

}
-- }}}

-- {{{ store_then_request_relay()
local function store_then_request_relay(storage, relay_req)
    id = storage()
    relay_req(id)
end
-- }}}

local queue_request_context = {}
queue_request_context.__index = queue_request_context

-- {{{ queue_request_context.new()
function queue_request_context.new(endpoint)
    local self = {}
    setmetatable(self, queue_request_context)

    self.endpoint = endpoint

    return self
end
-- }}}

-- {{{ queue_request_context:start_tag()
function queue_request_context:start_tag(tag, attrs)
    local current = {tag = tag, attrs = attrs, data = ""}

    if tags[tag] then
        -- Check if this tag is valid and in the right place.
        local valid = (#tags[tag] == #self.tag_stack)
        for i, t in ipairs(tags[tag]) do
            if t ~= self.tag_stack[i].tag then
                valid = false
                break
            end
        end

        -- For valid tags, generate info and handler.
        if valid then
            local currinfo = self.msg_info
            for i, t in ipairs(self.tag_stack) do
                if tags[t.tag].list then
                    currinfo = currinfo[tags[t.tag].list]
                    currinfo = currinfo[#currinfo]
                end
            end
            if tags[tag].list then
                local n = tags[tag].list
                if not currinfo[n] then
                    currinfo[n] = {}
                end
                table.insert(currinfo[n], {})
                currinfo = currinfo[n][#currinfo[n]]
            end

            current.info = currinfo
            current.handle = tags[tag].handle
        end
    end

    table.insert(self.tag_stack, current)
end
-- }}}

-- {{{ queue_request_context:end_tag()
function queue_request_context:end_tag(tag)
    local current = self.tag_stack[#self.tag_stack]

    if current and current.handle then
        current.handle(current.info, current.attrs, current.data)
    end

    table.remove(self.tag_stack)
end
-- }}}

-- {{{ queue_request_context:tag_data()
function queue_request_context:tag_data(data)
    local current = self.tag_stack[#self.tag_stack]
    current.data = current.data .. data
end
-- }}}

-- {{{ queue_request_context:parse_request()
function queue_request_context:parse_request(data)
    local parser = slimta.xml.new(self, self.start_tag, self.end_tag, self.tag_data)
    parser:parse(data)
end
-- }}}

-- {{{ queue_request_context:store_message_and_request_relay()
function queue_request_context:store_message_and_request_relay(msg, data)
    local which_engine = get_conf.string(use_storage_engine, msg, data)
    local engine = storage_engines[which_engine].new

    local storage = engine.new()
    storage:set_mailfrom(msg.envelope.sender)
    storage:set_rcpttos(msg.envelope.recipients)
    storage:add_data(data)

    local relay_req = relay_request_context.new(msg)

    kernel:attach(store_then_request_relay, storage, relay_req)
end
-- }}}

-- {{{ queue_request_context:handle_messages()
function queue_request_context:handle_messages(socket)
    for i, client in ipairs(self.msg_info.clients) do
        for j, message in ipairs(client.messages) do
            if not socket:is_rcvmore() then
                error("Message count does not match received")
            end
            local message_data = socket:recv()
            message.size = #message_data
            self:store_message_and_request_relay(message, message_data)
        end
    end
end
-- }}}

-- {{{ queue_request_context:reset()
function queue_request_context:reset()
    self.tag_stack = {}
    self.msg_info = {}
end
-- }}}

-- {{{ queue_request_context:__call()
function queue_request_context:__call()
    -- Set up the ZMQ listener.
    local type_, endpoint = uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(type_)
    socket:bind(endpoint)

    -- Gather all results messages.
    while true do
        self:reset()
        local data = socket:recv()
        self:parse_request(data)
        self:handle_messages(socket)
        socket:send("yay!")
    end
end
-- }}}

return queue_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
