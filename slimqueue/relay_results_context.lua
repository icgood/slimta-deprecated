
local xml_wrapper = require "modules.engines.xml_wrapper"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"deliver", "slimta"},

    {"results", "deliver", "slimta"},

    {"message", "results", "deliver", "slimta",
        list = "messages",
        handle = function (info, attrs, data)
            info.protocol = attrs.protocol
        end,
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
            info.code = attrs.code
            info.message = data
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
            info.code = attrs.code
            info.message = data
        end,
    },

}
-- }}}

relay_results_context = {}
relay_results_context.__index = relay_results_context

-- {{{ relay_results_context.new()
function relay_results_context.new(uri)
    local self = {}
    setmetatable(self, relay_results_context)

    self.uri = uri
    self.parser = xml_wrapper.new(tags)

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ relay_results_context:on_delete_error()
function relay_results_context:on_delete_error()
    -- No-op.
end
-- }}}

-- {{{ relay_results_context:delete_message()
function relay_results_context:delete_message(msg)
    kernel:set_error_handler(self.on_delete_error, self)

    local engine = modules.engines.storage[msg.storage.engine].delete

    local storage = engine.new(msg.storage.data)
    storage()
end
-- }}}

-- {{{ relay_results_context:try_again_later()
function relay_results_context:try_again_later(msg)
    local engine = modules.engines.storage[msg.storage.engine].set_next_attempt

    local storage = engine.new(msg.storage.data)
    if not storage() then
        self:fail_message(msg)
    end
end
-- }}}

-- {{{ relay_results_context:fail_message()
function relay_results_context:fail_message(msg)
    modules.engine.failure({msg})
    self:delete_message(msg)
end
-- }}}

-- {{{ relay_results_context:__call()
function relay_results_context:__call()
    -- Set up the ZMQ listener.
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:bind(rec.endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        print('RR: [' .. data .. ']')
        self.results = self.parser:parse_xml(data)
        for i, msg in ipairs(self.results.messages) do
            if msg.type == "success" then
                kernel:attach(self.delete_message, self, msg)
            elseif msg.type == "hardfail" then
                kernel:attach(self.fail_message, self, msg)
            else
                kernel:attach(self.try_again_later, self, msg)
            end
        end
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
