
require "ratchet"

require "slimta"

slimta.routing = slimta.routing or {}
slimta.routing.static = {}
slimta.routing.static.__index = slimta.routing.static

-- {{{ slimta.routing.static.new()
function slimta.routing.static.new(relayer, host, port)
    local self = {}
    setmetatable(self, slimta.routing.static)

    if type(relayer) == "function" then
        self.relayer_func = relayer
    else
        self.relayer = relayer
    end

    if type(host) == "function" then
        self.host_func = host
    else
        self.host = host
    end

    if type(port) == "function" then
        self.port_func = port
    else
        self.port = port or 25
    end

    return self
end
-- }}}

-- {{{ slimta.routing.static:route()
function slimta.routing.static:route(message)
    message.envelope.dest_relayer = self.relayer or self.relayer_func(message)
    message.envelope.dest_host = self.host or self.host_func(message)
    message.envelope.dest_port = self.port or self.port_func(message)

    return {message}
end
-- }}}

-- {{{ slimta.routing.static:__call()
function slimta.routing.static:__call(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, msg in ipairs(messages) do
            self:route(msg)
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
