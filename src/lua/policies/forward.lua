
require "slimta"

slimta.policies = slimta.policies or {}
slimta.policies.forward = {}
slimta.policies.forward.__index = slimta.policies.forward

-- {{{ slimta.policies.forward.new()
function slimta.policies.forward.new(mapping)
    local self = {}
    setmetatable(self, slimta.policies.forward)

    self.mapping = mapping or {}

    return self
end
-- }}}

-- {{{ slimta.policies.forward:set()
function slimta.policies.forward:set(pattern, dest)
    self.mapping[pattern] = dest
end
-- }}}

-- {{{ slimta.policies.forward:map()
function slimta.policies.forward:map(message)
    local n_rcpt = #message.envelope.recipients
    for i=1, n_rcpt do
        for pattern, dest in pairs(self.mapping) do
            if message.envelope.recipients[i]:match(pattern) then
                message.envelope.recipients[i] = dest
            end
        end
    end
end
-- }}}

-- {{{ slimta.policies.forward:__call()
function slimta.policies.forward:__call(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, msg in ipairs(messages) do
            self:map(msg)
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

return slimta.policies.forward

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
