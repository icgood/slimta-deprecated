
local SPAMC_PROTOCOL_VERSION = 1.1

local spamc = {}
spamc.__index = spamc

-- {{{ build_request_str()
local function build_request_str(message)
    local raw_message = tostring(message.contents)
    local parts = {
        "SYMBOLS SPAMC/",
        SPAMC_PROTOCOL_VERSION,
        "\r\nContent-Length: ",
        #raw_message,
        "\r\nUser: slimta\r\n\r\n",
        raw_message,
    }
    return table.concat(parts)
end
-- }}}

-- {{{ spamc.send_request()
function spamc.send_request(socket, message)
    local request_str = build_request_str(message)
    repeat
        request_str = socket:send(request_str)
    until not request_str
    socket:shutdown("write")
end
-- }}}

-- {{{ get_line()
local function get_line(socket, buffer)
    while true do
        local line, end_i = buffer:match("^(.-)%\r?%\n()")
        if line then
            return line, buffer:sub(end_i)
        end

        local data = socket:recv()
        if data == "" then
            return nil
        end
        buffer = buffer .. data
    end
end
-- }}}

-- {{{ spamc.recv_response()
function spamc.recv_response(socket)
    local line, match
    local buffer = ""
    local spammy = false

    line, buffer = get_line(socket, buffer)
    if not line or not line:match("^SPAMD/[^ ]+ 0 EX_OK$") then
        error("Error occured scanning message with spamassassin: [" .. line .. "]")
    end

    while true do
        line, buffer = get_line(socket, buffer)
        if not line or line == "" then
            break
        end

        if "True" == line:match("^Spam: ([^ ]+)") then
            spammy = true
        end
    end

    local lines = {}
    while true do
        line, buffer = get_line(socket, buffer)
        if not line or line == "" then
            break
        end
        table.insert(lines, line)
    end
    socket:close()

    return spammy, table.concat(lines, "\r\n")
end
-- }}}

return spamc

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
