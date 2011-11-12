
require "slimta.edge.http"
require "slimta.edge.smtp"

require "slimta.bus"
require "slimta.message"

module("slimta.edge", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(bus)
    local self = {}
    setmetatable(self, class)

    self.listeners = {}
    self.bus = bus

    return self
end
-- }}}

-- {{{ add_listener()
function add_listener(self, listener)
    listener:set_manager(self)
    table.insert(self.listeners, listener)
end
-- }}}

-- {{{ process_message()
function process_message(self, message)
    local transaction = self.bus:send_request({message})
    local responses = transaction:recv_response()
    return responses[1]
end
-- }}}

-- {{{ run()
function run(self, kernel)
    for i, listener in ipairs(self.listeners) do
        listener:run(kernel)
    end
end
-- }}}

-- {{{ halt()
function halt(self)
    for i, listener in ipairs(self.listeners) do
        listener:halt()
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
