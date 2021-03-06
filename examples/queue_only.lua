#!/usr/bin/lua

require "ratchet"

require "slimta.edge.smtp"
require "slimta.queue"
require "slimta.bus"
require "slimta.message"

require "slimta.policies.add_date_header"
require "slimta.policies.add_received_header"

require "slimta.storage.memory"
require "slimta.storage.redis"

if not slimta.storage[arg[1]] then
    print("usage: "..arg[0].." <memory|redis> [redis host] [redis port]")
    os.exit(1)
end

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
    local storage = slimta.storage[arg[1]].new(table.unpack(arg, 2))
    local queue = slimta.queue.new(bus_server, nil, storage)

    while true do
        local thread = queue:accept()
        ratchet.thread.attach(thread, storage)
    end
end
-- }}}

kernel = ratchet.new(function ()
    local chain_bus, edge_bus = slimta.bus.new_local()

    local policies = {
        slimta.policies.add_date_header.new(),
        slimta.policies.add_received_header.new(),
    }

    local queue_bus = slimta.bus.chain(policies, chain_bus)

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_queue, queue_bus)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
