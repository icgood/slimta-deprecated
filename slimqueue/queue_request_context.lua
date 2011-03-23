
local xml_wrapper = require "modules.engines.xml_wrapper"
local relay_request_context = require "slimqueue.relay_request_context"
local generate_bounce = require "slimqueue.generate_bounce"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"queue", "slimta"},

    {"host", "queue", "slimta",
        handle = function (info, attrs, data)
            info.host = data:match("%S+")
        end,
    },

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
        handle = function (info, attrs, data)
            if attrs.id then
                info.response_id = attrs.id
            end
        end,
    },

    {"contents", "message", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            if attrs.part then
                info.contents_i = tonumber(attrs.part)
            else
                info.contents = data
            end
        end,
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

    {"bounce", "client", "queue", "slimta",
        list = "bounces",
        handle = function (info, attrs, data)
            info.protocol = attrs.protocol
            if attrs.id then
                info.response_id = attrs.id
            end
        end,
    },

    {"storage", "bounce", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            attrs.data = data
            info.orig_storage = attrs
        end,
    },

    {"error", "bounce", "client", "queue", "slimta",
        handle = function (info, attrs, data)
            info.code = attrs.code
            info.message = data:gsub("^%s*", ""):gsub("%s*$", "")
        end,
    },

}
-- }}}

queue_request_context = {}
queue_request_context.__index = queue_request_context

-- {{{ queue_request_context.new()
function queue_request_context.new(uri, relay_req_uri)
    local self = {}
    setmetatable(self, queue_request_context)

    self.uri = uri
    self.relay_req_uri = relay_req_uri
    self.parser = xml_wrapper.new(tags)

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ queue_request_context:on_storage_error()
function queue_request_context:on_storage_error(message, err)
    message.storage = nil
    message.storage_error = err
end
-- }}}

-- {{{ queue_request_context:chain_store_then_request_relay_calls()
function queue_request_context:chain_store_then_request_relay_calls(message, storage, relay_req)
    kernel:set_error_handler(self.on_storage_error, message)

    -- The second, rarely-necessary return value can be used to skip the immediate
    -- relay attempt. This may be useful when a message is not immediately available
    -- for reading even when the storage engine has returned a queue ID. The only
    -- built-in usage of this parameter is for the blackhole storage engine.
    local id, dont_send = storage()

    message.storage.data = id
    if not dont_send then
        relay_req()
    end
end
-- }}}

-- {{{ queue_request_context:store_and_request_relay()
function queue_request_context:store_and_request_relay(msg, data)
    local which_engine = config.queue.default_storage(msg, data)
    local engine = modules.engines.storage[which_engine].new

    msg.storage = {engine = which_engine}

    local storage = engine.new(msg, data)
    local relay_req = relay_request_context.new(self.relay_req_uri)
    relay_req:add_message(msg)

    local chain_calls = self.chain_store_then_request_relay_calls
    return kernel:attach(chain_calls, self, msg, storage, relay_req)
end
-- }}}

-- {{{ queue_request_context:handle_new_message()
function queue_request_context:handle_new_message(message, content_parts)
    local message_data
    if message.contents_i then
        message_data = content_parts[message.contents_i]
    else
        message_data = message.contents
    end

    if not message_data then
        error("Message contents missing.")
    end

    message.attempts = 0
    message.size = #message_data

    return self:store_and_request_relay(message, message_data)
end
-- }}}

-- {{{ queue_request_context:handle_messages()
function queue_request_context:handle_messages(socket)
    -- Receive contents from other ZMQ msg parts.
    local content_parts = {}
    while socket:is_rcvmore() do
        local data = socket:recv()
        print('QP: [' .. data .. ']')
        table.insert(content_parts, data)
    end

    -- Finalize message info and find contents.
    local msg_i = 0
    local children = {}
    for i, client in ipairs(self.msg_info.clients) do
        if client.messages then
            for j, message in ipairs(client.messages) do
                msg_i = msg_i + 1
                if not message.response_id then
                    message.response_id = msg_i
                end

                local thread = self:handle_new_message(message, content_parts, msg_i)
                table.insert(children, thread)
            end
        end

        if client.bounces then
            for j, bounce in ipairs(client.bounces) do
                msg_i = msg_i + 1
                if not bounce.response_id then
                    bounce.response_id = msg_i
                end

                local gen_bounce = generate_bounce.new(bounce)
                local thread = kernel:attach(gen_bounce)
                table.insert(children, thread)
            end
        end
    end

    kernel:wait_all(children)
end
-- }}}

-- {{{ queue_request_context:build_response()
function queue_request_context:build_response()
    local tmpl = [[<slimta><queue>
 <results>
%s </results>
</queue></slimta>
]]

    local msg_tmpl = [[  <message id="%s">%s</message>
]]
    local bounce_tmpl = [[  <bounce id="%s">%s</bounce>
]]
    local msg_error_tmpl = [[  <message id="%s">
   <error>%s</error>
  </message>
]]

    local bounce_error_tmpl = [[  <bounce id="%s">
   <error>%s</error>
  </bounce>
]]

    local msgs = ""
    for i, client in ipairs(self.msg_info.clients) do
        if client.messages then
            for j, msg in ipairs(client.messages) do
                if msg.storage then
                    msgs = msgs .. msg_tmpl:format(msg.response_id, msg.storage.data)
                else
                    msgs = msgs .. msg_error_tmpl:format(msg.response_id, msg.storage_error)
                end
            end
        end

        if client.bounces then
            for j, bounce in ipairs(client.bounces) do
                if bounce.storage then
                    msgs = msgs .. bounce_tmpl:format(bounce.response_id, bounce.storage.data)
                else
                    msgs = msgs .. bounce_error_tmpl:format(bounce.response_id, bounce.storage_error)
                end
            end
        end
    end

    return tmpl:format(msgs)
end
-- }}}

-- {{{ queue_request_context:__call()
function queue_request_context:__call()
    -- Set up the ZMQ listener.
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:bind(rec.endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        print('QP: [' .. data .. ']')
        self.msg_info = self.parser:parse_xml(data)
        self:handle_messages(socket)
        local response = self:build_response()
        print('QR: [' .. response .. ']')
        socket:send(response)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
