
require "slimta.relay.smtp_session"

module("slimta.relay.smtp", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(dns_query_types, ehlo_as)
    local self = {}
    setmetatable(self, class)

    self.dns_query_types = dns_query_types
    self.ehlo_as = ehlo_as

    return self
end
-- }}}

-- {{{ set_manager()
function set_manager()
    -- This function is currently a no-op.
end
-- }}}

-- {{{ ehlo_as()
function ehlo_as(self, ehlo_as)
    self.ehlo_as = ehlo_as
end
-- }}}

-- {{{ use_security()
function use_security(self, mode, method, force_verify)
    self.security_mode = mode
    self.security_method = method
    self.security_force_verify = force_verify
end
-- }}}

-- {{{ new_session()
function new_session(self, kernel, host, port)
    local session = slimta.relay.smtp_session.new(
        kernel,
        host, port,
        self.dns_query_types
    )
    session:ehlo_as(self.ehlo_as)
    session:use_security(self.security_mode, self.security_method, self.security_force_verify)

    return session
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
