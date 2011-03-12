local smtp_encrypt = {}
smtp_encrypt.__index = smtp_encrypt

-- {{{ smtp_encrypt.new()
function smtp_encrypt.new(session)
    local self = {}
    setmetatable(self, smtp_encrypt)

    self.session = session

    return self
end
-- }}}

-- {{{ smtp_encrypt:act()
function smtp_encrypt:act(context, socket)
    local enc = socket:encrypt(ssl)
    enc:client_handshake()
    enc:check_certificate_chain()
end
-- }}}

-- {{{ smtp_encrypt:brief()
function smtp_encrypt:brief()
    return "[[ENCRYPTION INIT]]"
end
-- }}}

return smtp_encrypt

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
