
module("slimta.edge.mock_queue_channel", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(callback)
    local self = {}
    setmetatable(self, class)

    self.callback = callback

    return self
end
-- }}}

-- {{{ request_enqueue()
function request_enqueue(self, messages)
    for i, msg in ipairs(messages) do
        msg.error_data = "Handled by Mock-Queue"
    end

    return self.callback(messages)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
