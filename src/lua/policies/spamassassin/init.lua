
require "ratchet"
require "slimta"

slimta.policies = slimta.policies or {}
slimta.policies.spamassassin = {}
slimta.policies.spamassassin.__index = slimta.policies.spamassassin

local spamc = require "slimta.policies.spamassassin.spamc"

-- {{{ slimta.policies.spamassassin.new()
function slimta.policies.spamassassin.new(host, port, family)
    local self = {}
    setmetatable(self, slimta.policies.spamassassin)

    self.host = host
    self.port = port
    self.family = family

    return self
end
-- }}}

-- {{{ slimta.policies.spamassassin.scan()
function slimta.policies.spamassassin.scan(self, message)
    local rec = ratchet.socket.prepare_tcp(self.host, self.port, self.family)
    if not rec then
        error(("Could not connect to spamd on [%s]:%s!"):format(self.host, self.port))
    end
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)

    if not pcall(socket.connect, socket, rec.addr) then
        error(("Could not connect to spamd on [%s]:%s!"):format(self.host, self.port))
    end

    spamc.send_request(socket, message)
    message.spammy = spamc.recv_response(socket)

    return message.spammy
end
-- }}}

return slimta.policies.spamassassin

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
