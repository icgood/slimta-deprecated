
local xml_wrapper = require "modules.engines.xml_wrapper"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"deliver", "slimta"},

    {"nexthop", "deliver", "slimta",
        list = "nexthops",
    },

    {"protocol", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.protocol = data:match("%S+")
        end,
    },

    {"destination", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.destination = data:match("%S+")
        end,
    },

    {"port", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.port = data:match("%d+")
        end,
    },

    {"security", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            -- Put security stuff here.
        end,
    },

    {"message", "nexthop", "deliver", "slimta",
        list = "messages",
    },

    {"envelope", "message", "nexthop", "deliver", "slimta"},

    {"sender", "envelope", "message", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

            info.envelope = info.envelope or {}
            info.envelope.sender = stripped_data
        end,
    },

    {"recipient", "envelope", "message", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

            info.envelope = info.envelope or {}
            info.envelope.recipients = info.envelope.recipients or {}
            table.insert(info.envelope.recipients, stripped_data)
        end,
    },

    {"storage", "message", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            attrs.data = data
            info.storage = attrs
        end,
    },

}
-- }}}

request_context = {}
request_context.__index = request_context

-- {{{ request_context.new()
function request_context.new(uri, results_channel)
    local self = {}
    setmetatable(self, request_context)

    self.uri = uri
    self.results_channel = results_channel
    self.parser = xml_wrapper.new(tags)

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ request_context:create_sessions()
function request_context:create_sessions()
    for i, nexthop in ipairs(self.msg_info.nexthops) do
        local which = nexthop.protocol:lower()
        local proto = modules.protocols.relay[which]
        if proto then
            local proto_channel = proto.new(nexthop, self.results_channel)
            kernel:attach(proto_channel)
        else
            error("Unsupported protocol: " .. which)
        end
    end
end
-- }}}

-- {{{ request_context:__call()
function request_context:__call()
    -- Set up the ZMQ listener.
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:bind(rec.endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        self.msg_info = self.parser:parse_xml(data)
        self:create_sessions()
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
