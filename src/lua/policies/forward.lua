
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

-- {{{ slimta.policies.forward:map()
function slimta.policies.forward:map(message)
    local n_rcpt = #message.envelope.recipients
    for i=1, n_rcpt do
        local old_rcpt = message.envelope.recipients[i]
        for j, mapping in ipairs(self.mapping) do
            local new_rcpt, num = old_rcpt:gsub(mapping.pattern, mapping.repl, mapping.n)
            if new_rcpt and num > 0 then
                message.envelope.recipients[i] = new_rcpt
                break
            end
        end
    end
end
-- }}}

return slimta.policies.forward

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
