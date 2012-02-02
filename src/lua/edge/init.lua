
require "slimta"

require "slimta.bus"
require "slimta.message"

slimta.edge = {}
slimta.edge.__index = slimta.edge

require "slimta.edge.http"
require "slimta.edge.smtp"

-- {{{ slimta.edge.new()
function slimta.edge.new(bus)
    local self = {}
    setmetatable(self, slimta.edge)

    self.listeners = {}
    self.bus = bus

    return self
end
-- }}}

-- {{{ slimta.edge:add_listener()
function slimta.edge:add_listener(listener)
    listener:set_manager(self)
    table.insert(self.listeners, listener)
end
-- }}}

-- {{{ slimta.edge:process_message()
function slimta.edge:process_message(message)
    local transaction = self.bus:send_request({message})
    local responses = transaction:recv_response()
    return responses and responses[1]
end
-- }}}

-- {{{ slimta.edge:run()
function slimta.edge:run()
    for i, listener in ipairs(self.listeners) do
        listener:run()
    end
end
-- }}}

-- {{{ slimta.edge:halt()
function slimta.edge:halt()
    for i, listener in ipairs(self.listeners) do
        listener:halt()
    end
end
-- }}}

return slimta.edge

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
