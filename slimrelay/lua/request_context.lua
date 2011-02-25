
local xml_wrapper = require "xml_wrapper"

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
        handle = function (info, attrs, data)
            info.qid = attrs["queueid"]
        end
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

    {"contents", "message", "nexthop", "deliver", "slimta",
        handle = function (info, attrs, data)
            attrs.data = data
            info.contents = attrs
        end,
    },

}
-- }}}

local request_context = {}
request_context.__index = request_context

-- {{{ request_context.new()
function request_context.new(endpoint, results_channel)
    local self = {}
    setmetatable(self, request_context)

    self.endpoint = endpoint
    self.results_channel = results_channel
    self.parser = xml_wrapper.new(tags)

    return self
end
-- }}}

-- {{{ request_context:create_sessions()
function request_context:create_sessions()
    for i, nexthop in ipairs(self.msg_info.nexthops) do
        local proto = protocols[nexthop.protocol]
        if proto then
            local proto_channel = proto.new(nexthop, self.results_channel)
            kernel:attach(proto_channel)
        else
            error("Unsupported protocol: " .. proto)
        end
    end
end
-- }}}

-- {{{ request_context:__call()
function request_context:__call()
    -- Set up the ZMQ listener.
    local rec = ratchet.zmqsocket.prepare_uri(self.endpoint)
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

return request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
