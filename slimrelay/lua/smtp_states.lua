local smtp_states = {}

-- {{{ new_state()
local function new_state(name, supports_pipeline)
    local ret = {name = name, supports_pipeline = supports_pipeline}
    ret.__index = ret
    function ret.new(session, message, extra_named)
        local self = {session = session, message = message}
        setmetatable(self, ret)
        if extra_named then
            for k, v in pairs(extra_named) do
                self[k] = v
            end
        end
        return self
    end
    smtp_states[name] = ret
end
-- }}}

--------------------------------------------------------------------------------

-- {{{ Banner
new_state("Banner")

function smtp_states.Banner:build_command()
    return ""
end

function smtp_states.Banner:parse_response(code, response)
    if code ~= 220 then
        return "quit_immediately"
    end
end
-- }}}

-- {{{ Error
new_state("Error")

function smtp_states.Error:build_command()
    return ""
end

function smtp_states.Error:parse_response(code, response)
    if code == 421 then
        return "quit_immediately"
    end
end
-- }}}

-- {{{ HELO
new_state("HELO")

function smtp_states.HELO:build_command()
    return "HELO " .. session.ehlo_as .. "\r\n"
end

function smtp_states.HELO:parse_response(code, response)
    if code ~= 250 then
        if code == 421 then
            return "quit_immediately"
        else
            return "quit"
        end
    end
end
-- }}}

-- {{{ EHLO
new_state("EHLO")

function smtp_states.EHLO:build_command()
    return "EHLO " .. self.session.ehlo_as .. "\r\n"
end

function smtp_states.EHLO:parse_response(code, response)
    if code ~= 250 then
        if code == 421 then
            return "quit_immediately"
        elseif code >= 500 and code < 600 then
            return "try_helo"
        else
            return "quit"
        end
    end

    local greeting = false
    for line in response:gmatch("(.-)%s-\n") do
        if not greeting then
            greeting = line
        else
            local pattern = "^%s*(%w[%w%-]*)(.*)$"
            self.session:add_extension(line:match(pattern))
        end
    end
end
-- }}}

-- {{{ MAIL
new_state("MAIL", true)

function smtp_states.MAIL:build_command()
    local command = "MAIL FROM:<" .. self.message.envelope.sender .. ">"
    local size = tonumber(self.message.contents.size)
    if self.session:has_extension("SIZE") and size then
        command = command .. " size=" .. size
    end
    return command .. "\r\n"
end

function smtp_states.MAIL:parse_response(code, response)
    if code ~= 250 then
        if code == 421 then
            return "quit_immediately"
        elseif code >= 500 and code < 600 then
            return "fail_message"
        else
            return "softfail_message"
        end
    end
end
-- }}}

-- {{{ RCPT
new_state("RCPT", true)

function smtp_states.RCPT:build_command()
    return "RCPT TO:<" .. self.message.envelope.recipients[self.which] .. ">\r\n"
end

function smtp_states.RCPT:parse_response(code, response)
    if code ~= 250 and code ~= 251 then
        if code == 421 then
            return "quit_immediately"
        elseif code >= 500 and code < 600 then
            return "fail_recipient"
        else
            return "softfail_recipient"
        end
    end
end
-- }}}

-- {{{ DATA
new_state("DATA")

function smtp_states.DATA:build_command()
    return "DATA\r\n"
end

function smtp_states.DATA:parse_response(code, response)
    if code ~= 354 then
        if code == 421 then
            return "quit_immediately"
        elseif code >= 500 and code < 600 then
            return "fail_message"
        else
            return "softfail_message"
        end
    end
end
-- }}}

-- {{{ DATA_send
new_state("DATA_send", true)

function smtp_states.DATA_send:build_command()
    -- RFC 5321 specifies you should only send message data if there was at
    -- least one accepted RCPT TO, otherwise send an empty message (only
    -- matters if DATA still returned 354, which it should not have).
    if self.session.some_rcpts_accepted then
        return self.session.current_msg
    else
        return ""
    end
end

function smtp_states.DATA_send:parse_response(code, response)
    if code ~= 250 then
        if code == 421 then
            return "quit_immediately"
        elseif code >= 500 and code < 600 then
            return "fail_message"
        else
            return "softfail_message"
        end
    end
end
-- }}}

-- {{{ RSET
new_state("RSET", true)

function smtp_states.RSET:build_command()
    return "RSET\r\n"
end

function smtp_states.RSET:parse_response(code, response)
    if code < 200 or code >= 300 then
        return "quit"
    end
end
-- }}}

-- {{{ QUIT
new_state("QUIT")

function smtp_states.QUIT:build_command()
    return "QUIT\r\n"
end

function smtp_states.QUIT:parse_response(code, response)
    return "quit_immediately"
end
-- }}}

return smtp_states

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
