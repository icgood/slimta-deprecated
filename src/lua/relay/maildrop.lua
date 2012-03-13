
local maildrop_session = require "slimta.relay.maildrop_session"

slimta.relay = slimta.relay or {}
slimta.relay.maildrop = {}
slimta.relay.maildrop.__index = slimta.relay.maildrop

-- {{{ slimta.relay.maildrop.new()
function slimta.relay.maildrop.new(argv0, time_limit)
    local self = {}
    setmetatable(self, slimta.relay.maildrop)

    self.argv0 = argv0
    self.time_limit = time_limit

    return self
end
-- }}}

-- {{{ slimta.relay.maildrop:build_session_info()
function slimta.relay.maildrop:build_session_info()
    return "maildrop"
end
-- }}}

-- {{{ slimta.relay.maildrop:new_session()
function slimta.relay.maildrop:new_session()
    local session = maildrop_session.new(self.argv0, self.time_limit)
    return session
end
-- }}}

return slimta.relay.maildrop

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
