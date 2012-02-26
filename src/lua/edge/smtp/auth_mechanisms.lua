
local plain = {}
plain.__index = plain

-- {{{ plain.new()
function plain.new(secret_func)
    local self = {}
    setmetatable(self, plain)

    self.secret_func = secret_func or error("Secrecy function required.")

    return self
end
-- }}}

-- {{{ plain:challenge()
function plain:challenge(data, last_response, final_reply)
    if not last_response then
        return nil, ""
    end

    local decoded = slimta.base64.decode(last_response)
    local zid, cid, password = decoded:match("^([^%\0]*)%\0([^%\0]+)%\0([^%\0]+)$")
    if not zid then
        final_reply.code = "501"
        final_reply.message = "Invalid PLAIN authentication string"
        final_reply.enhanced_status_code = "5.5.2"
        return
    end

    local secret, identity, message = self.secret_func(cid, zid)
    if not secret or secret ~= password then
        final_reply.code = "535"
        final_reply.message = message or "Authentication credentials invalid"
        final_reply.enhanced_status_code = "5.7.8"
        return
    end

    if message then
        final_reply.message = message
    end
    
    return identity or cid
end
-- }}}

local login = {}
login.__index = login

-- {{{ login.new()
function login.new(secret_func)
    local self = {}
    setmetatable(self, login)

    self.secret_func = secret_func or error("Secrecy function required.")

    return self
end
-- }}}

-- {{{ login:challenge()
function login:challenge(data, last_response, final_reply)
    if not data.requested_anything then
        data.requested_anything = true
        return nil, "VXNlcm5hbWU6" -- slimta.base64.encode("Username:")
    elseif not data.username then
        data.username = slimta.base64.decode(last_response)
        return nil, "UGFzc3dvcmQ6" -- slimta.base64.encode("Password:")
    elseif not data.password then
        data.password = slimta.base64.decode(last_response)
    end

    local secret, identity, message = self.secret_func(data.username)
    if not secret or secret ~= data.password then
        final_reply.code = "535"
        final_reply.message = "Authentication credentials invalid"
        final_reply.enhanced_status_code = "5.7.8"
        return
    end

    if message then
        final_reply.message = message
    end

    return identity or data.username
end
-- }}}

local crammd5 = {}
crammd5.__index = crammd5

-- {{{ crammd5.new()
function crammd5.new(secret_func, hostname)
    local self = {}
    setmetatable(self, crammd5)

    self.secure = true
    self.secret_func = secret_func or error("Secrecy function required.")
    self.hostname = hostname or os.getenv("HOSTNAME") or ratchet.socket.gethostname()

    return self
end
-- }}}

-- {{{ build_initial_crammd5_challenge()
local function build_initial_crammd5_challenge(self)
    local uuid = slimta.uuid.generate()
    local timestamp = os.time()
    return ("<%s.%s@%s>"):format(uuid, timestamp, self.hostname)
end
-- }}}

-- {{{ create_crammd5_hex_digest()
local function create_crammd5_hex_digest(data)
    local ret = {}
    for i=1, #data do
        local n = string.byte(data, i)
        table.insert(ret, ("%02x"):format(n))
    end
    return table.concat(ret)
end
-- }}}

-- {{{ crammd5:challenge()
function crammd5:challenge(data, last_response, final_reply)
    if not data.challenge then
        data.challenge = build_initial_crammd5_challenge(self)
        return nil, slimta.base64.encode(data.challenge)
    end

    local response = slimta.base64.decode(last_response)
    local username, digest = response:match("^(.*) ([^ ]+)$")
    if not username then
        final_reply.code = "501"
        final_reply.message = "Invalid CRAM-MD5 response"
        final_reply.enhanced_status_code = "5.5.2"
        return
    end

    local secret, identity, message = self.secret_func(username)
    if not secret then
        final_reply.code = "535"
        final_reply.message = "Authentication credentials invalid"
        final_reply.enhanced_status_code = "5.7.8"
        return
    end

    local expected = create_crammd5_hex_digest(slimta.hmac.encode("md5", data.challenge, secret))
    if expected ~= digest then
        final_reply.code = "535"
        final_reply.message = "Authentication credentials invalid"
        final_reply.enhanced_status_code = "5.7.8"
        return
    end

    if message then
        final_reply.message = message
    end

    return identity or username
end
-- }}}

return {
    ["plain"] = plain,
    ["login"] = login,
    ["CRAM-MD5"] = crammd5,
}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
