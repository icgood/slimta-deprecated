
slimta.bus.proxy = {}
slimta.bus.proxy.__index = slimta.bus.proxy

local bus_proxy_session_meta = {}
bus_proxy_session_meta.__index = bus_proxy_session_meta

-- {{{ default_filter()
local function default_filter(to_bus, request)
    local to_transaction = to_bus:send_request(request)
    return to_transaction:recv_response()
end
-- }}}

-- {{{ slimta.bus.proxy.new()
function slimta.bus.proxy.new(from_bus, to_bus, filter)
    local self = {}
    setmetatable(self, slimta.bus.proxy)

    self.from_bus = from_bus or error("slimta.bus.proxy.new(): No source bus given.")
    self.to_bus = to_bus or error("slimta.bus.proxy.new(): No destination bus given.")
    self.filter = filter or default_filter

    return self
end
-- }}}

-- {{{ bus_proxy_session_meta:__call()
function bus_proxy_session_meta:__call()
    local responses = self.filter(self.to_bus, self.request)
    self.transaction:send_response(responses)
end
-- }}}

-- {{{ slimta.bus.proxy:accept()
function slimta.bus.proxy:accept()
    local transaction, request = self.from_bus:recv_request()

    local session = {
        request = request,
        transaction = transaction,
        to_bus = self.to_bus,
        filter = self.filter,
    }
    setmetatable(session, bus_proxy_session_meta)

    return session
end
-- }}}

-- {{{ slimta.bus.proxy:__call()
function slimta.bus.proxy:__call()
    while true do
        local thread = self:accept()
        ratchet.thread.attach(thread)
    end
end
-- }}}

return slimta.bus.proxy

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
