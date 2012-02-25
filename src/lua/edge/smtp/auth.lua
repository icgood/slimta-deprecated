
require "slimta"

slimta.edge.smtp.auth = {}
slimta.edge.smtp.auth.__index = slimta.edge.smtp.auth

-- {{{ slimta.edge.smtp.auth.new()
function slimta.edge.smtp.auth.new()
    local self = {}
    setmetatable(self, slimta.edge.smtp.auth)

    self.mechanisms = {}
    self.disabled_mechanisms = {}

    return self
end
-- }}}

-- {{{ slimta.edge.smtp.auth:add_mechanism()
function slimta.edge.smtp.auth:add_mechanism(name, handler, disabled)
    if disabled then
        self.disabled_mechanisms[name:upper()] = handler
    else
        self.mechanisms[name:upper()] = handler
    end
end
-- }}}

-- {{{ slimta.edge.smtp.auth:enable_mechanism()
function slimta.edge.smtp.auth:enable_mechanism(name)
    local handler = self.disabled_mechanisms[name:upper()]
    if handler then
        self.mechanisms[name:upper()] = handler
    end
end
-- }}}

-- {{{ slimta.edge.smtp.auth:disable_mechanism()
function slimta.edge.smtp.auth:disable_mechanism(name)
    local handler = self.mechanisms[name:upper()]
    if handler then
        self.disabled_mechanisms[name:upper()] = handler
    end
end
-- }}}

-- {{{ parse_arg()
local function parse_arg(self, arg)
    local mechanism, initial_response = arg:match("^([%a%d%-%_]+)%s*(.*)$")
    if initial_response == "" then
        initial_response = nil
    elseif initial_response == "=" then
        initial_response = ""
    end
    return self.mechanisms[mechanism:upper()], initial_response
end
-- }}}

-- {{{ slimta.edge.smtp.auth:challenge()
function slimta.edge.smtp.auth:challenge(arg, final_reply, data, last_response, using_tls)
    if not last_response then
        data.mechanism, last_response = parse_arg(self, arg)
        if not data.mechanism then
            final_reply.code = "504"
            final_reply.message = "Invalid authentication mechanism"
            final_reply.enhanced_status_code = "5.5.4"
            return
        end
    end

    if last_response == "*" then
        final_reply.code = "501"
        final_reply.message = "Authentication canceled by client"
        final_reply.enhanced_status_code = "5.7.0"
        return
    end

    return data.mechanism:challenge(data, last_response, final_reply, using_tls)
end
-- }}}

-- {{{ slimta.edge.smtp.auth:__tostring()
function slimta.edge.smtp.auth:__tostring()
    local mechanisms = {}
    for k, v in pairs(self.mechanisms) do
        table.insert(mechanisms, k)
    end
    return table.concat(mechanisms, " ")
end
-- }}}

slimta.edge.smtp.auth.PLAIN = {}
slimta.edge.smtp.auth.PLAIN.__index = slimta.edge.smtp.auth.PLAIN

-- {{{ slimta.edge.smtp.auth.PLAIN.new()
function slimta.edge.smtp.auth.PLAIN.new(verify_func)
    local self = {}
    setmetatable(self, slimta.edge.smtp.auth.PLAIN)

    self.verify_func = verify_func or error("Verification function required.")

    return self
end
-- }}}

-- {{{ slimta.edge.smtp.auth.PLAIN:challenge()
function slimta.edge.smtp.auth.PLAIN:challenge(data, last_response, final_reply, using_tls)
    if not using_tls then
        final_reply.code = "538"
        final_reply.message = "Encryption required for PLAIN authentication"
        final_reply.enhanced_status_code = "5.7.11"
        return
    end

    if not last_response then
        return ""
    end

    local decoded = slimta.base64.decode(last_response)
    local zid, cid, password = decoded:match("^([^%\0]*)%\0([^%\0]+)%\0([^%\0]+)$")
    if not zid then
        final_reply.code = "501"
        final_reply.message = "Invalid PLAIN authentication string"
        final_reply.enhanced_status_code = "5.5.2"
        return
    end

    local success, message = self.verify_func(zid, cid, password)
    if not success then
        final_reply.code = "535"
        final_reply.message = "Authentication credentials invalid"
        final_reply.enhanced_status_code = "5.7.8"
    end
    if message then
        final_reply.message = message
    end
end
-- }}}

return slimta.edge.smtp.auth

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
