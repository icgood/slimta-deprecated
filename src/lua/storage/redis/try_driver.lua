require "ratchet"

local driver = require "driver"

-- {{{ do_request_reply()
local function do_request_reply(redis, request)
    local parts = {}
    for part in request:gmatch("[^%s]+") do
        table.insert(parts, part)
    end
    local reply, err = redis(table.unpack(parts))
    for i=1, reply.n do
        if reply[i] then
            print(i..": "..reply[i])
        else
            print(i..": ERROR: "..err[i])
        end
    end
end
-- }}}

-- {{{ try_driver()
function try_driver(socket)
    local redis = driver.new(socket)
    local reply

    print("> PING")
    do_request_reply(redis, "PING")

    while true do
        io.stdout:write("> ")
        io.stdout:flush()
        local request = io.stdin:read("*l")
        if not request then
            print("")
            break
        end
        do_request_reply(redis, request)
    end
end
-- }}}

kernel = ratchet.new(function ()
    local rec = ratchet.socket.prepare_tcp(arg[1], 6379)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    ratchet.thread.attach(try_driver, socket)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
