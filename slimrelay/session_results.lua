
local session_results = {}
session_results.__index = session_results

-- {{{ session_results.new()
function session_results.new(messages, results_channel, protocol)
    local self = {}
    setmetatable(self, session_results)

    self.results_channel = results_channel
    self.protocol = protocol

    -- Initialize all messages to temp-failed state.
    self.messages = messages
    self.current = 1
    self.results = {}
    for i, msg in ipairs(messages) do
        local r = {}
        r.storage = msg.storage
        r.failed_rcpts = {}
        self.results[i] = r
        self:set_result(i, "softfail", "", "421", "Unknown")
    end

    return self
end
-- }}}

-- {{{ session_results:set_result()
function session_results:set_result(i, type_, command, code, message)
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
        r.message = slimta.xml.escape(message:gsub("%s*$", ""))
    end
end
-- }}}

-- {{{ session_results:push_result()
function session_results:push_result(type, command, code, message)
    local i = self.current
    if not self.results[i] then
        return false
    end
    self:set_result(i, type, command, code, message)
    self.current = i + 1
    return true
end
-- }}}

-- {{{ session_results:add_softfailed_rcpt()
function session_results:add_softfailed_rcpt(msg_i, rcpt_j, code, message)
    local addr = self.messages[msg_i].envelope.recipients[rcpt_j]
    local msg = slimta.xml.escape(message:gsub("%s*$", ""))
    local f = {addr = addr, type = "softfail", code = code, message = msg}
    local r = self.results[msg_i]
    table.insert(r.failed_rcpts, f)
end
-- }}}

-- {{{ session_results:add_hardfailed_rcpt()
function session_results:add_hardfailed_rcpt(msg_i, rcpt_j, code, message)
    local addr = self.messages[msg_i].envelope.recipients[rcpt_j]
    local msg = slimta.xml.escape(message:gsub("%s*$", ""))
    local f = {addr = addr, type = "hardfail", code = code, message = msg}
    local r = self.results[msg_i]
    table.insert(r.failed_rcpts, f)
end
-- }}}

-- {{{ session_results:format_results()
function session_results:format_results()
    local results_tmpl = [[<slimta><deliver>
 <results>
%s </results>
</deliver></slimta>
]]

    local success_tmpl = [[  <message protocol="$(protocol)">
   <storage engine="$(engine)">$(data)</storage>
   <result type="success"/>
$(failed_recipients)  </message>
]]
    local fail_tmpl = [[  <message protocol="$(protocol)">
   <storage engine="$(engine)">$(data)</storage>
   <result type="$(fail_type)">
    <command>$(command)</command>
    <response code="$(code)">$(message)</response>
   </result>
$(failed_recipients)  </message>
]]

    local failrcpt_tmpl = [[
   <recipient type="$(fail_type)">
    $(recipient)
    <response code="$(code)">$(message)</response>
   </recipient>
]]

    local msgs = ""
    for i, r in ipairs(self.results) do
        local rcptmsgs = ""
        for i, rcpt in ipairs(r.failed_rcpts) do
            rcptmsgs = rcptmsgs .. slimta.interp(failrcpt_tmpl, {
                fail_type = rcpt.type,
                recipient = rcpt.addr,
                code = rcpt.code,
                message = rcpt.message,
            })
        end

        local substitutions = {
            protocol = self.protocol,
            engine = r.storage.engine,
            data = r.storage.data,
            fail_type = r.type,
            command = r.command,
            code = r.code,
            message = r.message,
            failed_recipients = rcptmsgs,
        }
        if r.type == "success" then
            msgs = msgs .. slimta.interp(success_tmpl, substitutions)
        else
            msgs = msgs .. slimta.interp(fail_tmpl, substitutions)
        end
    end

    -- Bring together all results.
    return results_tmpl:format(msgs)
end
-- }}}

-- {{{ session_results:send()
function session_results:send()
    local results = self:format_results()
    self.results_channel:send(results)
end
-- }}}

return session_results

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
