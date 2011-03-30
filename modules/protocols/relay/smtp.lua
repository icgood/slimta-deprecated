
require "modules.protocols.smtp.client"

local data_loader = require "modules.engines.storage.data_loader"

local smtp_relay = {}
smtp_relay.__index = smtp_relay

-- {{{ smtp_relay.new()
function smtp_relay.new(nexthop, session_results)
    local self = {}
    setmetatable(self, smtp_relay)

    for i, msg in ipairs(nexthop.messages) do
        msg.storage.loader = data_loader.new(msg.storage)
        kernel:attach(msg.storage.loader)
    end

    self.host = nexthop.destination
    self.port = nexthop.port
    self.security = nexthop.security
    self.ehlo_as = config.relay.ehlo_as(self)
    self.results = session_results

    self.messages = nexthop.messages
    self.replies = {}

    return self
end
-- }}}

-- {{{ smtp_relay:on_error()
function smtp_relay:on_error(err)
end
-- }}}

-- {{{ smtp_relay:handshake()
function smtp_relay:handshake(client)
    -- Get the SMTP banner.
    local banner = client:get_banner()
    if banner.code ~= "220" then
        error("expected 220 from banner: " .. tostring(banner.code))
    end

    -- Send the EHLO/HELO.
    local ehlo = client:ehlo(self.ehlo_as)
    if ehlo.code and ehlo.code:sub(1, 1) == "5" then
        ehlo = client:helo(self.ehlo_as)
    end
    if ehlo.code ~= "250" then
        error("expected 250 from EHLO/HELO: " .. tostring(ehlo.code))
    end
end
-- }}}

-- {{{ smtp_relay:negotiate_ssl()
function smtp_relay:negotiate_ssl(client, socket)
    if self.security.when ~= "connection" then
        return
    end

    local ssl_obj = ssl[self.security.method]
    if not ssl_obj then
        error("unknown SSL security method: " .. self.security.method)
    end

    local force = (self.security.mode == "force")

    local enc = socket:encrypt(ssl_obj)
    enc:client_handshake()

    local got_cert, verified = enc:verify_certificate()
    if force and (not got_cert or not verified) then
        error("remote host certificate could not be verified")
    end
end
-- }}}

-- {{{ smtp_relay:negotiate_tls()
function smtp_relay:negotiate_tls(client, socket)
    if self.security.when ~= "starttls" then
        return
    end

    local tls_obj = ssl[self.security.method]
    if not tls_obj then
        error("unknown TLS security method: " .. self.security.method)
    end

    local force = (self.security.mode == "force")

    -- Send the STARTTLS.
    local starttls = client:starttls()
    if starttls.code == "220" then
        local enc = socket:encrypt(tls_obj)
        enc:client_handshake()

        local got_cert, verified = enc:verify_certificate()
        if force and (not got_cert or not verified) then
            error("remote host certificate could not be verified")
        end

        -- Redo the EHLO.
        ehlo = client:ehlo(self.ehlo_as)
        if ehlo.code ~= "250" then
            error("expected 250 from EHLO after STARTTLS: " .. tostring(ehlo.code))
        end
    elseif force then
        error("expected 220 from STARTTLS: " .. tostring(starttls.code))
    end
end
-- }}}

-- {{{ smtp_relay:check_for_accepted_rcpt()
function smtp_relay:check_for_accepted_rcpt(rcpt_replies)
    for i, res in ipairs(rcpt_replies) do
        if res.code == "250" then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ smtp_relay:check_all_rejected_rcpts()
function smtp_relay:check_all_rejected_rcpts(rcpt_replies)
    for i, res in ipairs(rcpt_replies) do
        if not res.code or res.code:sub(1, 1) ~= "5" then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ smtp_relay:send_message_envelope()
function smtp_relay:send_message_envelope(client, message, msg_replies)
    -- Send the MAIL FROM.
    msg_replies.sender = client:mailfrom(message.envelope.sender)
    
    -- Send the RCPT TOs.
    msg_replies.recipients = {}
    for i, rcpt in ipairs(message.envelope.recipients) do
        msg_replies.recipients[i] = client:rcptto(rcpt)
    end
end
-- }}}

-- {{{ smtp_relay:send_message_data()
function smtp_relay:send_message_data(client, message, msg_replies)
    -- Send the DATA.
    msg_replies.data = client:data()
    
    -- Send the message contents, if desired.
    msg_replies.send_data = {}
    if msg_replies.data.code == "354" then
        if msg_replies.sender.code == "250" and self:check_for_accepted_rcpt(msg_replies.recipients) then
            local data = message.storage.loader:get()
            msg_replies.send_data = client:send_data(data)
        else
            msg_replies.send_data = client:send_empty_data()
        end
    end

    -- Check if we need to RSET the session.
    if msg_replies.send_data.code ~= "250" then
        client:rset()
    end
end
-- }}}

-- {{{ smtp_relay:send_message()
function smtp_relay:send_message(client, message_i)
    local msg_replies = {}
    local message = self.messages[message_i]
    self.replies[message_i] = msg_replies

    self:send_message_envelope(client, message, msg_replies)
    self:send_message_data(client, message, msg_replies)
end
-- }}}

-- {{{ smtp_relay:handle_data_replies()
function smtp_relay:handle_data_replies(i, data_reply, send_data_reply)
    if send_data_reply.code ~= "250" then
        if data_reply.code ~= "354" then
            if not data_reply.code or data_reply.code:sub(1, 1) ~= "5" then
                self.results:set_result(i, "softfail", "DATA", data_reply.code, data_reply.message)
            else
                self.results:set_result(i, "hardfail", "DATA", data_reply.code, data_reply.message)
            end
        else
            if not send_data_reply.code or send_data_reply.code:sub(1, 1) ~= "5" then
                self.results:set_result(i, "softfail", "[[Message Contents]]", send_data_reply.code, send_data_reply.message)
            else
                self.results:set_result(i, "hardfail", "[[Message Contents]]", send_data_reply.code, send_data_reply.message)
            end
        end
    else
        self.results:set_result(i, "success")
    end
end
-- }}}

-- {{{ smtp_relay:handle_recipient_replies()
function smtp_relay:handle_recipient_replies(i, replies)
    -- Return specific recipient failures.
    for j, reply in ipairs(replies) do
        if reply.code ~= "250" then
            if not reply.code or reply.code:sub(1, 1) ~= "5" then
                self.results:add_softfailed_rcpt(i, j, reply.code, reply.message)
            else
                self.results:add_hardfailed_rcpt(i, j, reply.code, reply.message)
            end
        end
    end

    -- Override any message-wide results, if no recipients accepted.
    if not self:check_for_accepted_rcpt(replies) then
        if self:check_all_rejected_rcpts(replies) then
            self.results:set_result(i, "hardfail", "DATA", "503", "5.5.1 DATA without RCPT TO")
        else
            self.results:set_result(i, "softfail", "DATA", "503", "5.5.1 DATA without RCPT TO")
        end
    end
end
-- }}}

-- {{{ smtp_relay:handle_sender_replies()
function smtp_relay:handle_sender_replies(i, reply)
    if reply.code ~= "250" then
        if not reply.code or reply.code:sub(1, 1) ~= "5" then
            self.results:set_result(i, "softfail", "MAIL FROM", reply.code, reply.message)
        else
            self.results:set_result(i, "hardfail", "MAIL FROM", reply.code, reply.message)
        end
    end
end
-- }}}

-- {{{ smtp_relay:handle_message_replies()
function smtp_relay:handle_message_replies()
    for i, replies in ipairs(self.replies) do
        self:handle_data_replies(i, replies.data, replies.send_data)
        self:handle_recipient_replies(i, replies.recipients)
        self:handle_sender_replies(i, replies.sender)
    end

    self.results:send()
end
-- }}}

-- {{{ smtp_relay:__call()
function smtp_relay:__call()
    local rec = ratchet.socket.prepare_tcp(self.host, self.port, config.dns.a_queries())
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    if not socket:connect(rec.addr) then
        error("connection failed")
        -- See RFC 5321 Section 3.8. for reasoning behind code 451.
    end

    local client = modules.protocols.smtp.client.new(socket)

    self:negotiate_ssl(client, socket)
    self:handshake(client)
    self:negotiate_tls(client, socket)

    -- Loop through and send the messages.
    for i, msg in ipairs(self.messages) do
        self:send_message(client, i)
    end

    client:quit()

    -- Loop through replies and send session results.
    self:handle_message_replies()
end
-- }}}

modules.protocols.relay.smtp = smtp_relay

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
