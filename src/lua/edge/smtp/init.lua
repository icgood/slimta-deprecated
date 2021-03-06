
require "ratchet.smtp.server"

require "slimta.message"

slimta.edge = slimta.edge or {}
slimta.edge.smtp = {}
slimta.edge.smtp.__index = slimta.edge.smtp

local command_handler = {}
command_handler.__index = command_handler

-- {{{ slimta.edge.smtp.new()
function slimta.edge.smtp.new(socket, bus)
    local self = {}
    setmetatable(self, slimta.edge.smtp)

    self.socket = socket
    self.bus = bus

    self.settings = {
        banner_code = 220,
        banner_message = "ESMTP Welcome",
        validators = {},
    }

    return self
end
-- }}}

-- {{{ slimta.edge.smtp:set_banner_message()
function slimta.edge.smtp:set_banner_message(code, message)
    self.settings.banner_code = code
    self.settings.banner_message = message
end
-- }}}

-- {{{ slimta.edge.smtp:set_max_message_size()
function slimta.edge.smtp:set_max_message_size(size)
    self.settings.max_message_size = size
end
-- }}}

-- {{{ slimta.edge.smtp:enable_tls()
function slimta.edge.smtp:enable_tls(context, immediately)
    self.settings.tls_context = context
    self.settings.tls_immediately = immediately
end
-- }}}

-- {{{ slimta.edge.smtp:set_validator()
function slimta.edge.smtp:set_validator(which, func)
    self.settings.validators[which:upper()] = func
end
-- }}}

-- {{{ slimta.edge.smtp:set_timeout()
function slimta.edge.smtp:set_timeout(timeout)
    self.settings.timeout = timeout
end
-- }}}

-- {{{ slimta.edge.smtp:enable_authentication()
function slimta.edge.smtp:enable_authentication(auth)
    self.settings.enable_auth = auth
end
-- }}}

-- {{{ apply_extension_settings()
local function apply_extension_settings(extensions, settings)
    if settings.max_message_size then
        extensions:add("SIZE", tostring(settings.max_message_size))
    end

    if settings.enable_auth then
        local session = settings.enable_auth:get_session()
        if session then
            extensions:add("AUTH", session)
        end
    end
end
-- }}}

-- {{{ process_message()
local function process_message(self, message)
    local transaction = self.bus:send_request({message})
    local responses = transaction:recv_response()
    return responses and responses[1]
end
-- }}}

-- {{{ slimta.edge.smtp:accept()
function slimta.edge.smtp:accept()
    local client, from = self.socket:accept()
    if self.settings.timeout then
        client:set_timeout(self.settings.timeout)
    end
    
    local cmd_handler = command_handler.new(tostring(from), self)
    local smtp_handler = ratchet.smtp.server.new(
        client,
        cmd_handler,
        self.settings.tls_context,
        self.settings.tls_immediately
    )

    apply_extension_settings(smtp_handler.extensions, self.settings)

    return smtp_handler
end
-- }}}

-- {{{ slimta.edge.smtp:close()
function slimta.edge.smtp:close()
    self.socket:close()
end
-- }}}

-- {{{ generate_protocol_string()
local function generate_protocol_string(old, change)
    if old == "SMTP" and change == "EHLO" then
        return "ESMTP"
    elseif old == "SMTP" and change == "STARTTLS" then
        return "SMTPS"
    elseif old == "SMTPS" and change == "EHLO" then
        return "ESMTPS"
    elseif old == "ESMTP" and change == "STARTTLS" then
        return "ESMTPS"
    elseif old == "ESMTPA" and change == "STARTTLS" then
        return "ESMTPSA"
    elseif old == "ESMTP" and change == "AUTH" then
        return "ESMTPA"
    elseif old == "ESMTPS" and change == "AUTH" then
        return "ESMTPSA"
    else
        return old
    end
end
-- }}}

-- {{{ command_handler.new()
function command_handler.new(from_ip, smtp_edge)
    local self = {}
    setmetatable(self, command_handler)

    self.protocol = "SMTP"
    self.security = "none"
    self.from_ip = from_ip
    self.smtp_edge = smtp_edge

    return self
end
-- }}}

-- {{{ command_handler:BANNER()
function command_handler:BANNER(reply)
    if self.smtp_edge.settings.banner_code then
        reply.code = self.smtp_edge.settings.banner_code
    end

    if self.smtp_edge.settings.banner_message then
        reply.message = self.smtp_edge.settings.banner_message
    end

    local validator = self.smtp_edge.settings.validators.BANNER
    if validator then
        validator(self, reply)
    end
end
-- }}}

-- {{{ command_handler:EHLO()
function command_handler:EHLO(reply, ehlo_as, helo)
    local validator = self.smtp_edge.settings.validators.EHLO
    if validator then
        validator(self, reply, ehlo_as)
    end

    self.protocol = generate_protocol_string(self.protocol, "EHLO")

    if reply.code == "250" then
        self.ehlo_as = ehlo_as
        self.message = nil
    end
end
-- }}}

-- {{{ command_handler:STARTTLS()
function command_handler:STARTTLS(reply, extensions)
    local validator = self.smtp_edge.settings.validators.STARTTLS
    if validator then
        validator(self, reply)
    end

    local auth = self.smtp_edge.settings.enable_auth
    if auth then
        local session = auth:get_session(true)
        if session then
            extensions:add("AUTH", session)
        end
    end

    self.protocol = generate_protocol_string(self.protocol, "STARTTLS")
    self.security = "TLS"
end
-- }}}

-- {{{ command_handler:AUTH()
function command_handler:AUTH(arg, server)
    local ext = server.extensions:has("AUTH")
    if not ext then
        return server:unknown_command("AUTH", arg)
    end

    if not self.ehlo_as or self.authed or self.have_mailfrom then
        return server:bad_sequence("AUTH", arg)        
    end

    local reply = {
        code = "235",
        message = "Authentication successful",
        enhanced_status_code = "2.7.0",
    }

    local result, challenge, challenge_response
    local data = {}
    while true do
        result, challenge = ext:challenge(arg, reply, data, challenge_response)
        if not challenge then
            break
        end

        server.io:send_reply("334", challenge)
        server.io:flush_send()
        challenge_response = server.io:recv_line()
    end

    if reply.code == "235" then
        self.protocol = generate_protocol_string(self.protocol, "AUTH")
        self.authed = result
    end

    return reply
end
-- }}}

-- {{{ command_handler:RSET()
function command_handler:RSET()
    self.message = nil
end
-- }}}

-- {{{ command_handler:MAIL()
function command_handler:MAIL(reply, address)
    local validator = self.smtp_edge.settings.validators.MAIL
    if validator then
        validator(self, reply, address)
    end

    if reply.code == "250" then
        self.message = {
            sender = address,
            recipients = {},
        }
    end
end
-- }}}

-- {{{ command_handler:RCPT()
function command_handler:RCPT(reply, address)
    local validator = self.smtp_edge.settings.validators.RCPT
    if validator then
        validator(self, reply, address)
    end

    if reply.code == "250" then
        table.insert(self.message.recipients, address)
    end
end
-- }}}

-- {{{ command_handler:DATA()
function command_handler:DATA(reply)
    local validator = self.smtp_edge.settings.validators.DATA
    if validator then
        validator(self, reply)
    end
end
-- }}}

-- {{{ command_handler:HAVE_DATA()
function command_handler:HAVE_DATA(reply, data, err)
    -- Check for handleable errors.
    if not data then
        if ratchet.error.is(err, "MSGTOOBIG") then
            reply.code = "552"
            reply.message = "Message exceeded size limit."
            reply.enhanced_status_code = "5.3.4"
            return
        else
            error(err)
        end
    end

    -- Build a slimta.message object.
    local hostname = os.getenv("HOSTNAME") or ratchet.socket.gethostname()
    local client = slimta.message.client.new(self.protocol, self.ehlo_as, self.from_ip, self.security, hostname, self.authed)
    local envelope = slimta.message.envelope.new(self.message.sender, self.message.recipients)
    local contents = slimta.message.contents.new(data)
    local timestamp = os.time()

    -- Add necessary headers to message contents.
    if not contents.headers["from"][1] then
        contents:add_header("From", self.message.sender)
    end

    local message = slimta.message.new(client, envelope, contents, timestamp)

    -- Send the message to the edge manager for processing.
    local response = process_message(self.smtp_edge, message)
    reply.code, reply.message = response:as_smtp()

    -- Reset the session for more messages.
    self.message = nil
end
-- }}}

return slimta.edge.smtp

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
