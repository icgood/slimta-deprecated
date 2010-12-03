local smtp_states = require "smtp_states"
local message_results = require "message_results"

local smtp_session = ratchet.makeclass()

local template_start = string.char(1, 3, 9, 27)
local template_end = string.char(27, 9, 3, 1)

-- {{{ smtp_session:init()
function smtp_session:init(data, results_channel, ehlo_as)
    self.messages = data.messages
    self.security = data.security

    self.ehlo_as = get_conf.string(ehlo_as or os.getenv("HOSTNAME"), self)
    self.extensions = {}

    self.current_msg = 0
    self.commands = {
        waiting_for = {smtp_states.Banner(self)},
        to_send = {smtp_states.EHLO(self)},
    }

    self.results = message_results(self.messages, results_channel, self.message_placeholder())
end
-- }}}

-- {{{ smtp_session:shutdown()
function smtp_session:shutdown(context)
    context:close()
    self.results:send()
end
-- }}}

-- {{{ smtp_session:queue_next_msg_commands()
function smtp_session:queue_next_msg_commands()
    self.some_rcpts_accepted = false
    self.current_msg = self.current_msg + 1
    local msg = self.messages[self.current_msg]

    if not msg then
        self.commands.to_send = {smtp_states.QUIT(self)}
        return
    end

    self.commands.to_send = {}
    if self.current_msg > 1 then
        table.insert(self.commands.to_send, smtp_states.RSET(self))
    end

    -- MAIL FROM:<sender>
    table.insert(self.commands.to_send, smtp_states.MAIL(self, msg))

    -- RCPT TO:<forward-addr>
    local which = {which = 0}
    for i, rcpt in ipairs(msg.envelope.recipients) do
        which.which = i
        table.insert(self.commands.to_send, smtp_states.RCPT(self, msg, which))
    end

    -- DATA
    table.insert(self.commands.to_send, smtp_states.DATA(self, msg))
    table.insert(self.commands.to_send, smtp_states.DATA_send(self, msg))

    -- QUIT (after all messages)
    if n == #self.messages then
        table.insert(self.commands.to_send, smtp_states.QUIT(self))
    end
end
-- }}}

-- {{{ smtp_session.on_action[]
smtp_session.on_action = {
    quit_immediately = function (self, context, command, code, message)
        self:shutdown(context)
        return true
    end,

    quit = function (self, context)
        self.commands.to_send = {smtp_states.QUIT(self)}
    end,

    try_helo = function (self, context)
        self.commands.to_send = {smtp_states.HELO(self)}
    end,

    fail_message = function (self, context, command, code, message)
        self.results:push_result("hardfail", command, code, message)
    end,

    softfail_message = function (self, context, command, code, message)
        self.results:push_result("softfail", command, code, message)
    end,

    success = function (self, context, command)
        if command.name == "DATA" then
            self.results:push_result("success")
        elseif command.name == "RCPT" then
            self.some_rcpts_accepted = true
        end
    end,

    fail_recipient = function (self, context, command, code, message)
        self.results:add_hardfailed_rcpt(command.which, code, message)
    end,

    softfail_recipient = function(self, context, command, code, message)
        self.results:add_softfailed_rcpt(command.which, code, message)
    end,
}
-- }}}

-- {{{ smtp_session:process_response()
function smtp_session:process_response(context, code, message)
    local command = table.remove(self.commands.waiting_for, 1) or smtp_states.Error(self)

    local failure = command:parse_response(code, message)
    if failure then
        return self.on_action[failure](self, context, command, code, message)
    else
        return self.on_action.success(self, context, command, code, message)
    end
end
-- }}}

-- {{{ smtp_session:send_more_commands()
function smtp_session:send_more_commands(context)
    if #self.commands.waiting_for == 0 and #self.commands.to_send == 0 then
        self:queue_next_msg_commands()
    end

    -- Send all pipeline-able commands at the front of the send queue.
    local remaining = {}
    local more = true
    for i, command in ipairs(self.commands.to_send) do
        if not more then
            table.insert(remaining, command)
        else
            local data = command:build_command()
            more = command.supports_pipeline and self:has_extension("PIPELINING")
            self:check_data_and_send(context, data, more)
            table.insert(self.commands.waiting_for, command)
        end
    end
    if not more then
        self.commands.to_send = remaining
    else
        self:queue_next_msg_commands()
        return self:send_more_commands(context)
    end
end
-- }}}

-- {{{ smtp_session:send_message_contents()
function smtp_session:send_message_contents(context)
    local msg = self.messages[self.current_msg]

    -- Storage engine must provide iteration through lines of message, without
    -- including endline characters.
    for line in storage_engines[msg.contents.storage](msg.contents.data) do
        if line:match("^%.") then
            line = "." .. line
        end
        line = line .. "\r\n"
        context:queue_data(line, true)
    end
end
-- }}}

-- {{{ smtp_session:check_data_and_send()
function smtp_session:check_data_and_send(context, data, more, start_i)
    local pattern = "^(.-)"..self:message_placeholder().."()"
    local before, end_i = data:match(pattern, start_i)
    if not before then
        -- Data does not include message placeholder, send away!
        if start_i then
            context:queue_data(data:sub(start_i), more)
        else
            context:queue_data(data, more)
        end
    else
        context:queue_data(before, true)

        -- RFC 5321 specifies specifies you should only send message data
        -- if there was at least one accepted RCPT TO, otherwise send an
        -- empty message (only matters if DATA still returned 354, which
        -- it should not have).
        if self.some_rcpts_accepted then
            self:send_message_contents(context)
        end

        -- Recurse through rest of data, after message placeholder.
        self:check_data_and_send(context, data, more, end_i)
    end
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

-- {{{ smtp_session.message_placeholder()
function smtp_session.message_placeholder()
    return template_start .. "message" .. template_end
end
-- }}}

return smtp_session

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
