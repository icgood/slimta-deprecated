
local xml_wrapper = require "xml_wrapper"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"deliver", "slimta"},

    {"results", "deliver", "slimta"},

    {"message", "results", "deliver", "slimta",
        list = "messages",
    },

    {"storage", "message", "results", "deliver", "slimta",
        handle = function (info, attrs, data)
            attrs.data = data
            info.storage = attrs
        end,
    },

    {"result", "message", "results", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.type = attrs.type
        end,
    },

    {"command", "result", "message", "results", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.command = data:gsub("^%s*", ""):gsub("%s*$", "")
        end,
    },

    {"response", "result", "message", "results", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.code = tonumber(attrs.code)
            info.reason = data
        end,
    },

    {"recipient", "message", "results", "deliver", "slimta",
        list = "recipients",
        handle = function (info, attrs, data)
            info.type = attrs.type
            info.address = data:gsub("^%s*", ""):gsub("%s*$", "")
        end,
    },

    {"response", "recipient", "message", "results", "deliver", "slimta",
        handle = function (info, attrs, data)
            info.code = tonumber(attrs.code)
            info.reason = data
        end,
    },

}
-- }}}

local relay_results_context = {}
relay_results_context.__index = relay_results_context

-- {{{ relay_results_context.new()
function relay_results_context.new(endpoint)
    local self = {}
    setmetatable(self, relay_results_context)

    self.endpoint = endpoint
    self.parser = xml_wrapper.new(tags)

    return self
end
-- }}}

-- {{{ relay_results_context:delete_message()
function relay_results_context:delete_message(storage)
    local engine = storage_engines[storage.engine].delete

    local storage = engine.new(storage.data)
    kernel:attach(storage)
end
-- }}}

-- {{{ relay_results_context:try_again_later()
function relay_results_context:try_again_later(storage)
    local engine = storage_engines[storage.engine].set_next_attempt

    local storage = engine.new(storage.data)
    kernel:attach(storage)
end
-- }}}

-- {{{ relay_results_context:queue_bounce()
function relay_results_context:queue_bounce(storage)
end
-- }}}

-- {{{ relay_results_context:__call()
function relay_results_context:__call()
    -- Set up the ZMQ listener.
    local rec = ratchet.zmqsocket.prepare_uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:bind(rec.endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        print('RR: [' .. data .. ']')
        self.results = self.parser:parse_xml(data)
        for i, msg in ipairs(self.results.messages) do
            if msg.type == "success" then
                self:delete_message(msg.storage)
            elseif msg.type == "hardfail" then
                self:queue_bounce(msg.storage)
            else
                self:try_again_later(msg.storage)
            end
        end
    end
end
-- }}}

return relay_results_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
