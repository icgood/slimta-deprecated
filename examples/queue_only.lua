#!/usr/bin/lua

require "ratchet"

require "slimta.edge.smtp"
require "slimta.queue"
require "slimta.bus"
require "slimta.message"
require "slimta.storage.redis"

-- {{{ run_edge()
function run_edge(bus_client, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    local smtp = slimta.edge.smtp.new(socket, bus_client)

    while true do
        local thread = smtp:accept()
        ratchet.thread.attach(thread)
    end
    smtp:close()
end
-- }}}

-- {{{ run_queue()
function run_queue(bus_server)
    local queue = slimta.queue.new(bus_server)

    while true do
        local thread = queue:accept()

        local redis = slimta.storage.redis.new()
        redis:connect(arg[1], arg[2])

        ratchet.thread.attach(thread, redis)
    end
end
-- }}}

kernel = ratchet.new(function ()
    local queue_bus, edge_bus = slimta.bus.new_local()

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_queue, queue_bus)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
