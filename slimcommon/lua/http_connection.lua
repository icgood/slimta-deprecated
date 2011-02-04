
local http_connection = {}
http_connection.__index = http_connection

-- {{{ http_connection.new()
function http_connection.new(where)
    local self = {}
    setmetatable(self, http_connection)

    self.host, self.port = uri(where)

    return self
end
-- }}}

-- {{{ http_connection:build_header_string()
function http_connection:build_header_string(headers)
    local ret = ""
    for name, value in pairs(headers) do
        ret = ret .. name .. ": " .. tostring(value) .. "\r\n"
    end
    return ret
end
-- }}}

-- {{{ http_connection:build_request_and_headers()
function http_connection:build_request_and_headers(command, uri, headers, data)
    local ret = command:upper() .. " " .. uri .. " HTTP/1.0\r\n"
    if headers and #headers then
        ret = ret .. self:build_header_string(headers)
    end
    ret = ret .. "\r\n"
    return ret
end
-- }}}

-- {{{ http_connection:slow_send()
function http_connection:slow_send(socket, request, data)
    -- The purpose of this function is to avoid concatenating with data.

    while #request > self.send_size do
        local to_send = request:sub(1, self.send_size)
        socket:send(to_send)
        request = request:sub(self.send_size+1)
    end
    if not data then
        socket:send(request)
    else
        local to_send = request .. data:sub(1, self.send_size - #request)
        socket:send(to_send)
        data = data:sub(self.send_size - #request + 1)
        repeat
            to_send = data:sub(1, self.send_size)
            socket:send(to_send)
            data = data:sub(self.send_size+1)
        until data == ""
    end
end
-- }}}

-- {{{ http_connection:send_request()
function http_connection:send_request(socket, command, uri, headers, data)
    local request = self:build_request_and_headers(command, uri, headers, data)
    self:slow_send(socket, request, data)
    socket:shutdown("write")
end
-- }}}

-- {{{ http_connection:parse_response()
function http_connection:parse_response(socket)
    local full_reply = ""
    repeat
        local data = socket:recv()
        if #data > 0 then
            full_reply = full_reply .. data
        end
    until data == ""

    socket:close()

    local code, reason, lineend = full_reply:match("^HTTP%/%d%.%d (%d%d%d) (.-)\r\n()")
    local headers = {}
    local data

    if not code then
        return
    end

    repeat
        local name, value
        name, value, lineend = full_reply:match("^(.-):%s+(.-)\r\n()", lineend)
        if name then
            headers[name:lower()] = value
        end
    until not name

    lineend = full_reply:match("\r\n\r\n()", lineend)
    if lineend then
        data = full_reply:sub(lineend)
    end

    return tonumber(code), reason, headers, data
end
-- }}}

-- {{{ http_connection:query()
function http_connection:query(command, uri, headers, data)
    local rec = kernel:resolve_dns(self.host, self.port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    self.send_size = get_conf.number(socket_send_size or 102400, socket)

    self:send_request(socket, command, uri, headers, data)
    return self:parse_response(socket)
end
-- }}}

return http_connection

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
