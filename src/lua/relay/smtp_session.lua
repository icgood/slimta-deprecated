
require "ratchet.smtp.client"

require "slimta.message"

local smtp_session = {}
smtp_session.__index = smtp_session

-- {{{ smtp_session.new()
function smtp_session.new(host, port, family)
    local self = {}
    setmetatable(self, smtp_session)

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
        print(info)
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

    local got_cert, verified = enc:verify_certificate()
    if self.force_verify and (not got_cert or not verified) then
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
        error({"530", "5.7.0 Required STARTTLS not available."})
    end

    local starttls_ret = client:starttls()
    if starttls_ret.code == "220" then
        encrypt_session(self, client.io.socket)
    elseif self.force_verify then
        error(starttls_ret)
    end
end
-- }}}

-- {{{ ehlo()
local function ehlo(self, client)
    local ehlo_as_str, err = pcall(self.ehlo_as, self)
    local ehlo_ret = client:ehlo(ehlo_as_str or self.ehlo_as)
    if ehlo_ret.code ~= "250" then error(ehlo_ret) end
end
-- }}}

-- {{{ handshake()
local function handshake(self, client)
    if self.security_mode == "ssl" then
        negotiate_ssl(self, client)
    end

    local banner_ret = client:get_banner()
    if banner_ret.code ~= "220" then error(banner_ret) end
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

    if mailfrom_ret.code ~= "250" then error(mailfrom_ret) end
    if data_ret.code ~= "354" then error(data_ret) end

    local send_data_ret = client:send_data(tostring(message.contents))
    if send_data_ret.code ~= "250" then error(send_data_ret) end

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

    self.client:quit()
end
-- }}}

return smtp_session

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
