
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

-- {{{ slimta.relay.smtp:build_session_info()
function slimta.relay.smtp:build_session_info(message)
    local hash_parts = {
        message.envelope.dest_relayer or "default",
        ":[",
        message.envelope.dest_host or "default",
        "]:",
        message.envelope.dest_port or "default",
    }
    local info = {
        host = message.envelope.dest_host,
        port = message.envelope.dest_port,
    }

    return table.concat(hash_parts), info
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
function slimta.relay.smtp:new_session(info)
    local session = smtp_session.new(
        info.host, info.port,
        self.family
    )
    session:set_ehlo_as(self.ehlo_as)
    session:use_security(self.security.mode, self.security.method, self.security.force_verify)

    return session
end
-- }}}

return slimta.relay.smtp

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
