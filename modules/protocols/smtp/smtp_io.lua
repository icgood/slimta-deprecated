
local smtp_io = {}
smtp_io.__index = smtp_io

-- {{{ smtp_io.new()
function smtp_io.new(socket)
    local self = {}
    setmetatable(self, smtp_io)

    self.socket = socket
    self.send_size = config.socket.send_size(socket)

    self.send_buffer = ""
    self.recv_buffer = ""

    return self
end
-- }}}

-- {{{ smtp_io:close()
function smtp_io:close()
    return self.socket:close()
end
-- }}}

-- {{{ smtp_io:buffered_recv()
function smtp_io:buffered_recv()
    local received = self.socket:recv()
    local done

    if not received then
        io.stderr:write("S: timed out\n")
        done = "timed out"
    elseif received == "" then
        io.stderr:write("S: connection closed\n")
        done = "connection closed"
    else
        io.stderr:write("S: ["..received.."]\n")
        self.recv_buffer = self.recv_buffer .. received
    end

    return self.recv_buffer, done
end
-- }}}

-- {{{ smtp_io:buffered_send()
function smtp_io:buffered_send(data)
    self.send_buffer = self.send_buffer .. data
end
-- }}}

-- {{{ smtp_io:flush_send()
function smtp_io:flush_send()
    while #self.send_buffer > self.send_size do
        local to_send = self.send_buffer:sub(1, self.send_size)
        self.socket:send(to_send)
        io.stderr:write("C: ["..to_send.."]\n")
        self.send_buffer = self.send_buffer:sub(self.send_size+1)
    end

    if #self.send_buffer > 0 then
        self.socket:send(self.send_buffer)
        io.stderr:write("C: ["..self.send_buffer.."]\n")
        self.send_buffer = ""
    end
end
-- }}}

-- {{{ smtp_io:recv_reply()
function smtp_io:recv_reply()
    local pattern
    local code, message_lines = {}
    local bad_line_pattern = "^(.-)%\r?%\n()"

    while true do
        local input, done = self:buffered_recv()

        -- Build the full reply pattern once we know the code.
        if not pattern then
            code = input:match("^%d%d%d")
            if code then
                pattern = "^" .. code .. "([% %\t%-])(.-)%\r?%\n()"
            else
                local bad_line, end_i = input:match(bad_line_pattern)
                if bad_line then
                    self.recv_buffer = self.recv_buffer:sub(end_i+1)
                    return nil, bad_line
                end
            end
        end

        -- Check for lines that match the pattern.
        if pattern then
            local splitter, line, end_i = input:match(pattern)
            if line then
                table.insert(message_lines, line)
                self.recv_buffer = self.recv_buffer:sub(end_i+1)

                if splitter ~= "-" then
                    break
                end
            else
                local bad_line, end_i = input:match(bad_line_pattern)
                if bad_line then
                    self.recv_buffer = self.recv_buffer:sub(end_i+1)
                    return nil, bad_line
                end
            end
        end

        -- Handle timeouts and premature closure.
        if done then
            return nil, done
        end
    end

    return code, table.concat(message_lines, "\r\n")
end
-- }}}

-- {{{ smtp_io:recv_command()
function smtp_io:recv_command()
    while true do
        local input, done = self:buffered_recv()

        local line, end_i = input:match("^(.-)%\r?%\n()")
        if line then
            self.recv_buffer = self.recv_buffer:sub(end_i+1)

            local command, extra = line:match("^(%a+)%s+(.-)%s*$")
            if command then
                return command, extra
            else
                return line
            end
        end

        -- Handle timeouts and premature closure.
        if done then
            return nil, done
        end
    end
end
-- }}}

-- {{{ smtp_io:send_reply()
function smtp_io:send_reply(code, message, more_coming)
    local lines = {}
    for line in message:gmatch("(.-)%\r?%\n") do
        table.insert(lines, line)
    end
    local num_lines = #lines

    if num_lines == 0 then
        local to_send = code .. " " .. message .. "\r\n"
        return self:buffered_send(to_send, more_coming)
    else
        local to_send = ""
        for i=1,(num_lines-1) do
            to_send = to_send .. code .. "-" .. lines[i] .. "\r\n"
        end
        to_send = to_send .. code .. " " .. lines[num_lines] .. "\r\n"
        return self:buffered_send(to_send, more_coming)
    end
end
-- }}}

-- {{{ smtp_io:send_command()
function smtp_io:send_command(command)
    return self:buffered_send(command.."\r\n")
end
-- }}}

return smtp_io

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
