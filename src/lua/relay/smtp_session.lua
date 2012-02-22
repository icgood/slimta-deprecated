
require "ratchet"
require "ratchet.smtp.client"

require "slimta.message"

local smtp_session = {}
smtp_session.__index = smtp_session

-- {{{ smtp_session.new()
function smtp_session.new(host, port, family)
    local self = {}
    setmetatable(self, smtp_session)

    assert(host, "No destination for SMTP delivery of message.")

    self.host = host
    self.port = port or 25
    self.family = family
    self.ehlo_as = "unknown"
    self.messages = {}

    return self
end
-- }}}

-- {{{ smtp_session:set_ehlo_as()
function smtp_session:set_ehlo_as(ehlo_as)
    self.ehlo_as = ehlo_as
end
-- }}}

-- {{{ smtp_session:use_security()
function smtp_session:use_security(mode, method, force_verify)
    self.security_mode = mode
    self.security_method = method or ratchet.ssl.TLSv1
    self.force_verify = force_verify
end
-- }}}

-- {{{ smtp_session:add_message()
function smtp_session:add_message(message, responses, key)
    responses[key] = slimta.message.response.new()
    self.messages[message] = responses[key]
end
-- }}}

-- {{{ set_response_to_all_messages()
local function set_response_to_all_messages(self, info)
    if type(info) == "table" and info.type ~= "ratchet_error" then
        for msg, response in pairs(self.messages) do
            response.code = info[1] or info.code
            response.message = info[2] or info.message
        end
    else
        for msg, response in pairs(self.messages) do
            response.code = "451"
            response.message = "Unhandled error in processing."
            response.enhanged_status_code = "4.0.0"
        end
    end
end
-- }}}

-- {{{ connect_socket()
local function connect_socket(self)
    local rec = ratchet.socket.prepare_tcp(self.host, self.port, self.family)
    if not rec then error({"451", "4.4.1 Host not found"}) end
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)

    if not pcall(socket.connect, socket, rec.addr) then
        error({"451", "4.4.1 Connection failed"})
    end

    return socket
end
-- }}}

-- {{{ encrypt_session()
local function encrypt_session(self, socket)
    local enc = socket:encrypt(self.security_method)
    enc:client_handshake()

    local got_cert, verified, host_matched = enc:verify_certificate(self.host)
    if self.force_verify and (not got_cert or not verified or not host_matched) then
        self.client:quit()
        error({"530", "5.7.0 Unable to verify certificates"})
    end
end
-- }}}

-- {{{ negotiate_ssl()
local function negotiate_ssl(self, client)
    encrypt_session(self, client.io.socket)
end
-- }}}

-- {{{ negotiate_starttls()
local function negotiate_starttls(self, client)
    if self.force_verify and not client.extensions:has("STARTTLS") then
        self.client:quit()
        error({"530", "5.7.0 Required STARTTLS not available."})
    end

    local starttls_ret = client:starttls()
    if starttls_ret.code == "220" then
        encrypt_session(self, client.io.socket)
    elseif self.force_verify then
        self.client:quit()
        error(starttls_ret)
    end
end
-- }}}

-- {{{ ehlo()
local function ehlo(self, client)
    local ehlo_as_str = self.ehlo_as
    local callable, ret = pcall(self.ehlo_as, self)
    if callable then
        ehlo_as_str = ret
    end
    local ehlo_ret = client:ehlo(ehlo_as_str)

    if ehlo_ret.code ~= "250" then
        self.client:quit()
        error(ehlo_ret)
    end
end
-- }}}

-- {{{ handshake()
local function handshake(self, client)
    if self.security_mode == "ssl" then
        negotiate_ssl(self, client)
    end

    local banner_ret = client:get_banner()
    if banner_ret.code ~= "220" then
        self.client:quit()
        error(banner_ret)
    end
    ehlo(self, client)

    if self.security_mode == "starttls" then
        negotiate_starttls(self, client)
        ehlo(self, client)
    end
end
-- }}}

-- {{{ send_message()
local function send_message(client, message, response)
    local mailfrom_ret = client:mailfrom(message.envelope.sender)
    local rcptto_rets = {}
    for i, rcpt in ipairs(message.envelope.recipients) do
        rcptto_rets[i] = client:rcptto(rcpt)
    end
    local data_ret = client:data()

    if mailfrom_ret.code ~= "250" then
        response.code = mailfrom_ret.code
        response.message = mailfrom_ret.message
        return
    end
    if data_ret.code ~= "354" then
        response.code = data_ret.code
        response.message = data_ret.message
        return
    end

    local send_data_ret = client:send_data(tostring(message.contents))
    response.code = send_data_ret.code
    response.message = send_data_ret.message
end
-- }}}

-- {{{ relay_all_propagate_errors()
local function relay_all_propagate_errors(self)
    local socket = connect_socket(self)
    self.client = ratchet.smtp.client.new(socket)

    handshake(self, self.client)
    for msg, response in pairs(self.messages) do
        send_message(self.client, msg, response)
    end
end
-- }}}

-- {{{ smtp_session:relay_all()
function smtp_session:relay_all()
    local success, err = pcall(relay_all_propagate_errors, self)
    if not success then
        set_response_to_all_messages(self, err)
    end

    if self.client then
        self.client:close()
    end
end
-- }}}

return smtp_session

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
