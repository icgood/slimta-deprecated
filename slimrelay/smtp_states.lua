-- {{{ new_state()
local new_state = function ()
    local ret = ratchet.makeclass()
    ret.init = function (self, session, message, extra_named)
        self.session = session
        self.message = message
        if extra_named then
            for k, v in pairs(extra_named) do
                self[k] = v
            end
        end
    end
    return ret
end
-- }}}

------------------

local smtp_states = {}

-- {{{ Banner
smtp_states.Banner = new_state()

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
smtp_states.Error = new_state()

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
smtp_states.HELO = new_state()

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
smtp_states.EHLO = new_state()

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
smtp_states.MAIL = new_state()
smtp_states.MAIL.supports_pipeline = true

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
smtp_states.RCPT = new_state()
smtp_states.RCPT.supports_pipeline = true

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
smtp_states.DATA = new_state()

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
smtp_states.DATA_send = new_state()
smtp_states.DATA_send.supports_pipeline = true

function smtp_states.DATA_send:build_command()
    return self.session:message_placeholder() .. "\r\n.\r\n"
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

    return "success"
end
-- }}}

-- {{{ QUIT
smtp_states.QUIT = new_state()

function smtp_states.QUIT:build_command()
    return "QUIT\r\n"
end

function smtp_states.QUIT:parse_response(code, response)
    return "quit_immediately"
end
-- }}}

return smtp_states

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
