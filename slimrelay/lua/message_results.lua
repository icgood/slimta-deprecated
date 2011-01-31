
local message_results = {}
message_results.__index = message_results

-- {{{ message_results.new()
function message_results.new(messages, results_channel, message_placeholder)
    local self = {}
    setmetatable(self, message_results)

    self.results_channel = results_channel
    self.message_placeholder = message_placeholder

    -- Initialize all messages to temp-failed state.
    self.messages = messages
    self.current = 1
    self.results = {}
    for i, msg in ipairs(messages) do
        local r = {}
        r.qid = msg.qid
        r.failed_rcpts = {}
        self.results[i] = r
        self:set_result(i, "softfail", "", "421", "Unknown")
    end

    return self
end
-- }}}

-- {{{ message_results:set_result()
function message_results:set_result(i, type_, command, code, message)
    local r = self.results[i]
    if type_ == "success" then
        r.type = "success"
    else
        r.type = type_
        if type(command) == "string" then
            r.command = command:gsub("%s*$", "")
        else
            local command = command:build_command()
            if type(command) == "string" then
                r.command = command:gsub("%s*$", "")
            else
                r.command = command:brief()
            end
        end
        r.code = code
        r.message = message:gsub("%s*$", "")
    end
end
-- }}}

-- {{{ message_results:push_result()
function message_results:push_result(type, command, code, message)
    local i = self.current
    self:set_result(i, type, command, code, message)
    self.current = i + 1
end
-- }}}

-- {{{ message_results:add_softfailed_rcpt()
function message_results:add_softfailed_rcpt(which, code, message)
    local n = self.current
    local addr = self.messages[n].envelope.recipients[which]
    local msg = message:gsub("%s*$", "")
    local f = {addr = addr, type = "softfail", code = code, message = msg}
    local r = self.results[n]
    table.insert(r.failed_rcpts, f)
end
-- }}}

-- {{{ message_results:add_hardfailed_rcpt()
function message_results:add_hardfailed_rcpt(which, code, message)
    local n = self.current
    local addr = self.messages[n].envelope.recipients[which]
    local msg = message:gsub("%s*$", "")
    local f = {addr = addr, type = "hardfail", code = code, message = msg}
    local r = self.results[n]
    table.insert(r.failed_rcpts, f)
end
-- }}}

-- {{{ message_results:format_results()
function message_results:format_results()
    local results_tmpl = [[<slimta><deliver>
    <results>
%s    </results>
</deliver></slimta>
]]

    local success_tmpl = [[        <message queueid="%s">
            <result type="success"/>
%s        </message>
]]
    local fail_tmpl = [[        <message queueid="%s">
            <result type="%s">
                <command>%s</command>
                <response code="%d">%s</response>
            </result>
        </message>
]]

    local failrcpt_tmpl = [[
            <recipient type="%s">
                %s
                <response code="%d">%s</response>
            </recipient>
]]

    local msgs = ""
    for i, r in ipairs(self.results) do
        if r.type == "success" then
            -- The message may have been sent successfully but not necessarily to all recipients.
            local rcptmsgs = ""
            for i, rcpt in ipairs(r.failed_rcpts) do
                rcptmsgs = failrcpt_tmpl:format(rcpt.type, rcpt.addr, rcpt.code, rcpt.message)
            end
            msgs = msgs .. success_tmpl:format(r.qid, rcptmsgs)
        else
            msgs = msgs .. fail_tmpl:format(r.qid, r.type, r.command, r.code, r.message)
        end
    end

    -- Bring together all results.
    return results_tmpl:format(msgs)
end
-- }}}

-- {{{ message_results:send()
function message_results:send()
    local results = self:format_results()
    self.results_channel:send(results)
end
-- }}}

return message_results

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
