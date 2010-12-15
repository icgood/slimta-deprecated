local smtp_session = require "smtp_session"

local smtp_context = ratchet.new_context()

smtp_context.timeouts = {}

-- {{{ smtp_context.create()
function smtp_context.create(r, nexthop, results_channel)
    local session = smtp_session(nexthop, results_channel, hostname)
    local connect_to = string.format("tcp://[%s]:%d", nexthop.destination, nexthop.port)
    r:attach(smtp_context, r:connect_uri(connect_to), session)
end
-- }}}

-- {{{ smtp_context:each_response()
function smtp_context:save_each_response_function()
    self.each_response = function (before, code, after)
        if type(before) == "string" then
            local ret = ""
            for line in before:gmatch(code.."%-(.-\r?\n)") do
                ret = ret .. line
            end
            self.shutting_down = self.session:process_response(self, tonumber(code), ret .. after)
        else
            self.shutting_down = self.session:process_response(self, tonumber(code), after)
        end
        return ""
    end
end
-- }}}

-- {{{ smtp_context:process_from_buffer()
function smtp_context:process_from_buffer()
    local pattern = "^()(%d%d%d)%s+(.-\r?\n)"
    if not self.buffer:match(pattern) then
        pattern = "^(.-\r?\n)(%d%d%d)%s+(.-\r?\n)"
    end

    repeat
        local newbuf, n = self.buffer:gsub(pattern, self.each_response)
        self.buffer = newbuf
    until n == 0
end
-- }}}

-- {{{ smtp_context:queue_data()
function smtp_context:queue_data(data, more_coming)
    self.pipeline = self.pipeline .. data
    if not more_coming then
        self:send(self.pipeline)
        self.pipeline = ""
    end
end
-- }}}

-- {{{ smtp_context:on_init()
function smtp_context:on_init(session)
    self.session = session
    self.buffer = ""
    self.pipeline = ""

    self:save_each_response_function()
end
-- }}}

-- {{{ smtp_context:on_recv()
function smtp_context:on_recv()
    local data = self:recv()
    io.stderr:write("S: ["..data.."]\n")
    if data == "" then
        self.session:shutdown(self)
        return
    end
    self.buffer = self.buffer .. data
    self:process_from_buffer()

    if not self.shutting_down then
        self.session:send_more_commands(self)
    end
end
-- }}}

-- {{{ smtp_context:on_send()
function smtp_context:on_send(data)
    io.stderr:write("C: ["..data.."]\n")
end
-- }}}

protocols["SMTP"] = smtp_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
