
require "slimta"

local auth_mechanisms = require "slimta.edge.smtp.auth_mechanisms"

slimta.edge.smtp.auth = {}
slimta.edge.smtp.auth.__index = slimta.edge.smtp.auth

local auth_session = {}
auth_session.__index = auth_session

-- {{{ slimta.edge.smtp.auth.new()
function slimta.edge.smtp.auth.new()
    local self = {}
    setmetatable(self, slimta.edge.smtp.auth)

    self.secure_mechanisms = {}
    self.all_mechanisms = {}
    self.known_mechanisms = auth_mechanisms

    return self
end
-- }}}

-- {{{ slimta.edge.smtp.auth:add_mechanism()
function slimta.edge.smtp.auth:add_mechanism(name, arg, ...)
    name = name:upper()

    local handler
    local mechanism = self.known_mechanisms[name]
    if not mechanism then
        handler = arg
        assert(handler.challenge, "Second argument is not an AUTH mechanism.")
    else
        handler = mechanism.new(arg, ...)
    end

    if handler.secure then
        self.secure_mechanisms[name] = handler
    end
    self.all_mechanisms[name] = handler
end
-- }}}

-- {{{ slimta.edge.smtp.auth:get_session()
function slimta.edge.smtp.auth:get_session(encrypted)
    local which
    if encrypted then
        which = self.all_mechanisms
    else
        which = self.secure_mechanisms
    end

    if not next(which) then
        -- No mechanisms, no auth.
        return nil
    end

    local ret = {mechanisms = which}
    setmetatable(ret, auth_session)
    return ret
end
-- }}}

-- {{{ parse_arg()
local function parse_arg(session, arg)
    local mechanism, initial_response = arg:match("^([%a%d%-%_]+)%s*(.*)$")
    if initial_response == "" then
        initial_response = nil
    elseif initial_response == "=" then
        initial_response = ""
    end
    return session.mechanisms[mechanism:upper()], initial_response
end
-- }}}

-- {{{ auth_session:challenge()
function auth_session:challenge(arg, final_reply, data, last_response)
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

    return data.mechanism:challenge(data, last_response, final_reply)
end
-- }}}

-- {{{ auth_session:__tostring()
function auth_session:__tostring()
    local mechanisms = {}
    for k, v in pairs(self.mechanisms) do
        table.insert(mechanisms, k)
    end
    return table.concat(mechanisms, " ")
end
-- }}}

return slimta.edge.smtp.auth

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
