
require "ratchet"
require "ratchet.socketpad"

local driver = {}
driver.__index = driver

-- {{{ driver.new()
function driver.new(socket)
    local self = {}
    setmetatable(self, driver)

    self.pad = ratchet.socketpad.new(socket)

    return self
end
-- }}}

-- {{{ driver:send_request()
function driver:send_request(cmd, ...)
    local to_send = {}
    local args = table.pack(...)

    table.insert(to_send, '*')
    table.insert(to_send, tostring(args.n+1))
    table.insert(to_send, '\r\n')
    table.insert(to_send, '$')
    table.insert(to_send, tostring(#cmd))
    table.insert(to_send, '\r\n')
    table.insert(to_send, cmd)
    table.insert(to_send, '\r\n')

    for i=1, args.n do
        local raw = args[i] or ""
        if type(raw) ~= "string" then
            raw = tostring(raw)
        end
        table.insert(to_send, '$')
        table.insert(to_send, tostring(#raw))
        table.insert(to_send, '\r\n')
        table.insert(to_send, raw)
        table.insert(to_send, '\r\n')
    end

    self.pad:send(table.concat(to_send))
end
-- }}}

-- {{{ read_line()
local function read_line(self)
    local line, err = self.pad:recv("\r\n")
    if not line then
        error(err or "Failed to receive reply.")
    end
    return line
end
-- }}}

-- {{{ trim_error()
local function trim_error(err)
    if err:sub(1, 4) == "ERR " then
        return err:sub(5)
    end
end
-- }}}

-- {{{ driver:recv_reply()
function driver:recv_reply(no_multi_bulk)
    local line = read_line(self)
    local first_byte = line:sub(1, 1)
    local rest = line:sub(2, -3)

    if first_byte == '$' then
        local len = tonumber(rest)
        local raw = self.pad:recv(len)
        local _ = self.pad:recv("\r\n")
        return {n=1, raw}, {}
    elseif first_byte == '+' then
        return {n=1, rest}, {}
    elseif first_byte == ':' then
        return {n=1, tonumber(rest)}, {}
    elseif first_byte == '-' then
        return {n=1}, {trim_error(rest)}
    elseif not no_multi_bulk and first_byte == '*' then
        local num = tonumber(rest)
        if num < 1 then
            return {n=0}, {}
        end
        local rets = {n = num}
        local errs = {}
        for i=1, num do
            local ret, err = self:recv_reply(true)
            if ret[1] then
                rets[i] = ret[1]
            else
                errs[i] = err[1]
            end
        end
        return rets, errs
    end

    error("Invalid reply marker: ["..first_byte.."]")
end
-- }}}

-- {{{ driver:__call()
function driver:__call(cmd, ...)
    self:send_request(cmd, ...)
    return self:recv_reply()
end
-- }}}

return driver

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
