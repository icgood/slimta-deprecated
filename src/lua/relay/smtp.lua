
local smtp_session = require "slimta.relay.smtp_session"

slimta.relay = slimta.relay or {}
slimta.relay.smtp = {}
slimta.relay.smtp.__index = slimta.relay.smtp

-- {{{ slimta.relay.smtp.new()
function slimta.relay.smtp.new(ehlo_as, family)
    local self = {}
    setmetatable(self, slimta.relay.smtp)

    self.ehlo_as = ehlo_as
    self.family = family
    self.security = {}

    return self
end
-- }}}

-- {{{ slimta.relay.smtp:set_manager()
function slimta.relay.smtp:set_manager()
    -- This function is currently a no-op.
end
-- }}}

-- {{{ slimta.relay.smtp:set_ehlo_as()
function slimta.relay.smtp:set_ehlo_as(ehlo_as)
    self.ehlo_as = ehlo_as
end
-- }}}

-- {{{ slimta.relay.smtp:use_security()
function slimta.relay.smtp:use_security(mode, method, force_verify)
    self.security.mode = mode
    self.security.method = method
    self.security.force_verify = force_verify
end
-- }}}

-- {{{ slimta.relay.smtp:new_session()
function slimta.relay.smtp:new_session(host, port)
    local session = smtp_session.new(
        host, port,
        self.family
    )
    session:set_ehlo_as(self.ehlo_as)
    session:use_security(self.security.mode, self.security.method, self.security.force_verify)

    return session
end
-- }}}

return slimta.relay.smtp

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
