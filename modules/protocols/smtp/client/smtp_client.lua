
local smtp_io = require "modules.protocols.smtp.smtp_io"
local smtp_error = require "modules.protocols.smtp.smtp_error"
local smtp_extensions = require "modules.protocols.smtp.smtp_extensions"
local smtp_command = require "modules.protocols.smtp.smtp_command"
local smtp_reply = require "modules.protocols.smtp.smtp_reply"

local smtp_client = {}
smtp_client.__index = smtp_client

-- {{{ smtp_client.new()
function smtp_client.new(socket)
    local self = {}
    setmetatable(self, smtp_client)

    self.io = smtp_io.new(socket)
    self.ext = smtp_extensions.new()

    return self
end
-- }}}

-- {{{ smtp_client:simple_command()
function smtp_client:simple_command(name, param)
    local command = smtp_command.new(name, param)
    self.io:send_command(command)
    return smtp_reply.new(command, self.io:recv_reply())
end
-- }}}

-- {{{ smtp_client:handle_banner()
function smtp_client:handle_banner()
    local command = smtp_command.new("[BANNER]")
    local reply = smtp_reply.new(command, self.io:recv_reply())

    if reply.code ~= "220" then
        error(reply:unexpected_code())
    end
end
-- }}}

-- {{{ smtp_client:handle_hello()
function smtp_client:handle_hello(ehlo_as, use_helo)
    local cmd = "EHLO"
    if use_helo then
        cmd = "HELO"
    end
    local reply = self:simple_command(cmd, ehlo_as)

    if reply.code:sub(1, 1) == "5" and not use_helo then
        return self:handle_hello(ehlo_as, true)
    end

    if reply.code ~= "250" then
        error(reply:unexpected_code())
    end

    if not use_helo then
        self.ext:parse_string(reply.message)
    end
end
-- }}}

-- {{{ smtp_client:tls_handshake()
function smtp_client:tls_handshake(ehlo_as, tls)
    if not self.ext:has_extensions("STARTTLS") then
        return smtp_error.new("remote host does not support STARTTLS extension")
    end

    local reply = self:simple_command("STARTTLS")

    if reply.code == "220" then
        local enc = socket:encrypt(ssl)
        enc:client_handshake()

        local got_cert, verified = enc:verify_certificate()
        if not got_cert then
            return smtp_error.new("did not receive TLS certificate")
        elseif not verified then
            return smtp_error.new("received non-verifiable TLS certificate")
        end

        self.ext:reset()
        self:handle_hello(ehlo_as)
    else
        return reply:unexpected_code()
    end
end
-- }}}

-- {{{ smtp_client:handle_tls()
function smtp_client:handle_tls(ehlo_as, tls, tls_mode)
    if tls_mode ~= "off" then
        local err = self:tls_handshake(ehlo_as, tls)
        if err and tls_mode == "force" then
            error(err)
        end
    end
end
-- }}}

-- {{{ smtp_client:handshake()
function smtp_client:handshake(ehlo_as, tls, tls_mode)
    self:handle_banner()
    self:handle_hello(ehlo_as)
    self:handle_tls(ehlo_as, tls, tls_mode)
end
-- }}}

-- {{{ smtp_client:quit()
function smtp_client:quit()
    self:simple_command("QUIT")
    return self:quit_immediately()
end
-- }}}

-- {{{ smtp_client:quit_immediately()
function smtp_client:quit_immediately()
    return self.io:close()
end
-- }}}

return smtp_client

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
