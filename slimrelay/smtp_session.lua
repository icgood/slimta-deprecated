require "os"
require "string"
require "table"

require "ratchet"

require "smtp_states"
require "message_results"
require "storage_engines"

msg_status = ratchet.makeclass()
smtp_session = ratchet.makeclass()

local template_start = string.char(1, 3, 9, 27)
local template_end = string.char(27, 9, 3, 1)

-- {{{ smtp_session:init()
function smtp_session:init(data, ehlo_as)
    self.messages = data.messages
    self.security = data.security

    self.ehlo_as = ehlo_as or os.getenv("HOSTNAME")
    self.extensions = {}

    self.current_msg = 0
    self.commands = {
        waiting_for = {smtp_states.Banner(self)},
        to_send = {smtp_states.EHLO(self)},
    }

    self.results = message_results(self.messages)
end
-- }}}

-- {{{ smtp_session:shutdown()
function smtp_session:shutdown(context)
    context:close()
    self.results:send(results_channel)
end
-- }}}

-- {{{ smtp_session:queue_next_msg_commands()
function smtp_session:queue_next_msg_commands()
    self.current_msg = self.current_msg + 1
    local msg = self.messages[self.current_msg]

    if not msg then
        self.commands.to_send = {smtp_states.QUIT(self)}
        return
    end

    -- MAIL FROM:<sender>
    self.commands.to_send = {smtp_states.MAIL(self, msg)}

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

    success = function (self, context)
        self.results:push_result("success")
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

    local action = command:parse_response(code, message)
    if action then
        return self.on_action[action](self, context, command, code, message)
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

-- {{{ smtp_session:check_data_and_send()
function smtp_session:check_data_and_send(context, data, more)
    local pattern = "^(.-)"..self:message_placeholder().."(.*)$"
    local before, after = data:match(pattern)
    if not before then
        -- Data does not include message placeholder, send away!
        context:queue_data(data, more)
    else
        context:queue_data(before, true)

        local msg = self.messages[self.current_msg]
        for line in storage_engines[msg.contents.storage](msg.contents.data) do
            if line:match("^%.") then
                line = "." .. line
            end
            line = line .. "\r\n"
            context:queue_data(line, true)
        end

        context:queue_data(after, more)
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

-- {{{ smtp_session:message_placeholder()
function smtp_session:message_placeholder()
    return template_start .. "message" .. template_end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
