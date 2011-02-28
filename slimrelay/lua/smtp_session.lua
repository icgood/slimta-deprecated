local smtp_states = require "smtp_states"
local message_results = require "message_results"

local smtp_session = {}
smtp_session.__index = smtp_session

-- {{{ smtp_session.new()
function smtp_session.new(data, results_channel)
    local self = {}
    setmetatable(self, smtp_session)

    self.messages = data.messages
    self.security = data.security

    self.ehlo_as = CONF(hostname, self) or os.getenv("HOSTNAME")
    self.extensions = {}

    self:save_each_response_function()

    self.current_msg = 0
    self.commands = {
        waiting_for = {smtp_states.Banner.new(self)},
        to_send = {smtp_states.EHLO.new(self)},
    }

    self.results = message_results.new(self.messages, results_channel, self.message_placeholder)

    return self
end
-- }}}

-- {{{ smtp_session.on_action[]
smtp_session.on_action = {
    quit_immediately = function (self, command, code, message)
        self.is_finished = true
    end,

    softfail_and_quit_immediately = function (self, command, code, message)
        self.is_finished = true
        self.results:push_result("softfail", command, code, message)
    end,

    quit = function (self)
        self.commands.to_send = {smtp_states.QUIT(self)}
    end,

    try_helo = function (self)
        self.commands.to_send = {smtp_states.HELO(self)}
    end,

    fail_message = function (self, command, code, message)
        self.results:push_result("hardfail", command, code, message)
    end,

    softfail_message = function (self, command, code, message)
        self.results:push_result("softfail", command, code, message)
    end,

    success = function (self, command)
        if command.name == "DATA_send" then
            self.results:push_result("success")
        elseif command.name == "RCPT" then
            self.some_rcpts_accepted = true
        end
    end,

    fail_recipient = function (self, command, code, message)
        self.results:add_hardfailed_rcpt(command.which, code, message)
    end,

    softfail_recipient = function(self, command, code, message)
        self.results:add_softfailed_rcpt(command.which, code, message)
    end,
}
-- }}}

-- {{{ smtp_session:shutdown()
function smtp_session:shutdown(type_, command, code, response)
    -- Push out results for any remaining messages.
    if type_ then
        while self.results:push_result(type_, command, code, response) do end
    end

    self.results:send()
end
-- }}}

-- {{{ smtp_session:is_waiting()
function smtp_session:is_waiting()
    return self.commands.waiting_for[1] ~= nil
end
-- }}}

-- {{{ smtp_session:each_response()
function smtp_session:save_each_response_function()
    self.each_response = function (before, code, after)
        if type(before) == "string" then
            local ret = ""
            for line in before:gmatch(code.."%-(.-\r?\n)") do
                ret = ret .. line
            end
            self:process_response(tonumber(code), ret .. after)
        else
            self:process_response(tonumber(code), after)
        end
        return ""
    end
end
-- }}}

-- {{{ smtp_session:process_from_buffer()
function smtp_session:process_from_buffer(buffer)
    repeat
        local pattern = "^()(%d%d%d)%s+(.-\r?\n)"
        if not buffer:match(pattern) then
            pattern = "^(.-\r?\n)(%d%d%d)%s+(.-\r?\n)"
        end

        local newbuf, n = buffer:gsub(pattern, self.each_response, 1)
        buffer = newbuf
    until n == 0

    -- Return the new remaining bufferc
    return buffer
end
-- }}}

-- {{{ smtp_session:process_response()
function smtp_session:process_response(code, message)
    local command = table.remove(self.commands.waiting_for, 1) or smtp_states.Error.new(self)

    local failure = command:parse_response(code, message)
    if failure then
        self.on_action[failure](self, command, code, message)
    else
        self.on_action.success(self, command, code, message)
    end
end
-- }}}

-- {{{ smtp_session:queue_next_msg_commands()
function smtp_session:queue_next_msg_commands()
    self.some_rcpts_accepted = false
    self.current_msg = self.current_msg + 1
    local msg = self.messages[self.current_msg]

    if not msg then
        self.commands.to_send = {smtp_states.QUIT.new(self)}
        return
    end

    self.commands.to_send = {}

    -- MAIL FROM:<sender>
    table.insert(self.commands.to_send, smtp_states.MAIL.new(self, msg))

    -- RCPT TO:<forward-addr>
    local which = {which = 0}
    for i, rcpt in ipairs(msg.envelope.recipients) do
        which.which = i
        table.insert(self.commands.to_send, smtp_states.RCPT.new(self, msg, which))
    end

    -- DATA
    table.insert(self.commands.to_send, smtp_states.DATA.new(self, msg))
    table.insert(self.commands.to_send, smtp_states.DATA_send.new(self, msg))

    -- QUIT (after all messages)
    if self.current_msg == #self.messages then
        table.insert(self.commands.to_send, smtp_states.QUIT.new(self))
    end
end
-- }}}

-- {{{ smtp_session:send_more()
function smtp_session:send_more()
    if #self.commands.to_send == 0 then
        self:queue_next_msg_commands()
    end

    -- Dequeue command from to_send and enqueue in waiting_for.
    local command = table.remove(self.commands.to_send, 1)
    table.insert(self.commands.waiting_for, command)

    -- Build command string and whether it supports pipelining.
    local data = command:build_command()
    local more = command.supports_pipeline and self:has_extension("PIPELINING")

    return data, more
end
-- }}}

-- {{{ smtp_session:add_extension()
function smtp_session:add_extension(keyword, data)
    if data and #data > 0 then
        self.extensions[keyword:upper()] = data
    else
        self.extensions[keyword:upper()] = true
    end
end
-- }}}

-- {{{ smtp_session:has_extension()
function smtp_session:has_extension(keyword)
    return self.extensions[keyword]
end
-- }}}

return smtp_session

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
