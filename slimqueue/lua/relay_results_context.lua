
local xml_wrapper = require "xml_wrapper"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"deliver", "slimta"},

    {"results", "deliver", "slimta"},

    {"message", "results", "deliver", "slimta",
        list = "messages",
        handle = function (info, attrs, data)
            info.queueid = attrs.queueid
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
function relay_results_context:delete_message(queue_id)
    local which_engine = get_conf.string(use_storage_engine, msg, data)
    local engine = storage_engines[which_engine].delete

    local storage = engine.new(queue_id)
    kernel:attach(storage)
end
-- }}}

-- {{{ relay_results_context:try_again_later()
function relay_results_context:try_again_later(queue_id)
    local which_engine = get_conf.string(use_storage_engine, msg, data)
    local engine = storage_engines[which_engine].update

    local storage = engine.new(queue_id)
    kernel:attach(storage.set_next_attempt, storage)
end
-- }}}

-- {{{ relay_results_context:queue_bounce()
function relay_results_context:queue_bounce(queue_id)
end
-- }}}

-- {{{ relay_results_context:__call()
function relay_results_context:__call()
    -- Set up the ZMQ listener.
    local type_, endpoint = uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(type_)
    socket:bind(endpoint)

    -- Gather all results messages.
    while true do
        local data = socket:recv()
        self.results = self.parser:parse_xml(data)
        for i, msg in ipairs(self.results.messages) do
            if msg.type == "success" then
                self:delete_message(msg.queueid)
            elseif msg.type == "hardfail" then
                self:queue_bounce(msg.queueid)
            else
                self:try_again_later(msg.queueid)
            end
        end
    end
end
-- }}}

return relay_results_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
