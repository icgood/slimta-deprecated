
local xml_wrapper = require "xml_wrapper"
local relay_request_context = require "relay_request_context"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"queue", "slimta"},

    {"client", "queue", "slimta",
        list = "clients",
    },

    {"protocol", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            info.protocol = data:match("%S+")
        end,
    },

    {"host", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            info.host = data:match("%S+")
        end,
    },

    {"port", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            info.port = data:match("%d+")
        end,
    },

    {"security", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            -- Put security stuff here.
        end,
    },

    {"message", "client", "queue", "slimta",
        list = "messages",
    },

    {"envelope", "message", "client", "queue", "slimta"},

    {"sender", "envelope", "message", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

            info.envelope = info.envelope or {}
            info.envelope.sender = stripped_data
        end,
    },

    {"recipient", "envelope", "message", "client", "queue", "slimta",
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
    self.parser = xml_wrapper.new(tags)

    return self
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

-- {{{ queue_request_context:__call()
function queue_request_context:__call()
    -- Set up the ZMQ listener.
    local type_, endpoint = uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(type_)
    socket:bind(endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        self.msg_info = self.parser:parse_xml(data)
        self:handle_messages(socket)
        socket:send("yay!")
    end
end
-- }}}

return queue_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
