local smtp_session = require "smtp_session"
local smtp_data = require "smtp_data"

local smtp_context = {}
smtp_context.__index = smtp_context

-- {{{ smtp_context.new()
function smtp_context.new(nexthop, results_channel)
    local self = {}
    setmetatable(self, smtp_context)

    for i, msg in ipairs(nexthop.messages) do
        msg.storage.loader = smtp_data.new(msg.storage)
        kernel:attach(msg.storage.loader)
    end

    self.session = smtp_session.new(nexthop, results_channel)
    self.host = nexthop.destination
    self.port = nexthop.port
    self.buffer = ""

    return self
end
-- }}}

-- {{{ smtp_context:queue_send()
function smtp_context:queue_send(socket, data, more_coming)
    self.pipeline = self.pipeline .. data
    while #self.pipeline > self.send_size do
        local to_send = self.pipeline:sub(1, self.send_size)
        socket:send(to_send)
        io.stderr:write("C: ["..to_send.."]\n")
        self.pipeline = self.pipeline:sub(self.send_size+1)
    end
    if not more_coming then
        socket:send(self.pipeline)
        io.stderr:write("C: ["..self.pipeline.."]\n")
        self.pipeline = ""
    end
end
-- }}}

-- {{{ smtp_context:on_error()
function smtp_context:on_error(err)
    print("ERROR: "..err)

    -- See RFC 5321 Section 3.8. for reasoning behind code 451.
    self.session:shutdown("softfail", "[[socket]]", "451", err)
end
-- }}}

-- {{{ smtp_context:__call()
function smtp_context:__call()
    kernel:set_error_handler(smtp_context.on_error, self)

    local rec = ratchet.socket.prepare_tcp(self.host, self.port, CONF(dns_query_types))
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    if not socket:connect(rec.addr) then
        -- See RFC 5321 Section 3.8. for reasoning behind code 451.
        self.session:shutdown("softfail", "[[socket]]", "451", "Connection failed.")
        return
    end

    self.send_size = CONF(socket_send_size, socket) or 102400

    while not self.session.is_finished do
        if self.session:is_waiting() then
            local data = socket:recv()
            io.stderr:write("S: ["..data.."]\n")
            if data == '' then
                break
            end

            self.buffer = self.session:process_from_buffer(self.buffer .. data)
        else
            self.pipeline = ""
            repeat
                local data, more_coming = self.session:send_more()

                if type(data) == "string" then
                    self:queue_send(socket, data, more_coming)
                else
                    -- We want to send an iterable object, such as message data.
                    for i, piece in data:iter() do
                        self:queue_send(socket, piece, more_coming)
                    end
                end
            until not more_coming
        end
    end

    self.session:shutdown()
end
-- }}}

protocols["SMTP"] = smtp_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
