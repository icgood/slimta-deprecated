#!/usr/bin/lua

require "ratchet"

require "slimta.edge.smtp"
require "slimta.relay"
require "slimta.relay.smtp"
require "slimta.queue"
require "slimta.bus"
require "slimta.message"

require "slimta.storage.redis"
require "slimta.storage.memory"

require "slimta.routing.mx"
require "slimta.policies.add_date_header"
require "slimta.policies.add_received_header"

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
function run_queue(bus_server, bus_client)
    local queue = slimta.queue.new(bus_server, bus_client)

    while true do
        local thread = queue:accept()

        local storage = slimta.storage[arg[1]].new()
        storage:connect(table.unpack(arg, 2))

        ratchet.thread.attach(thread, storage)
    end
end
-- }}}

-- {{{ run_relay()
function run_relay(bus_server)
    local smtp = slimta.relay.smtp.new()
    local hostname = os.getenv("HOSTNAME") or ratchet.socket.gethostname()
    smtp:set_ehlo_as(hostname or "unknown")

    local relay = slimta.relay.new(bus_server)
    relay:add_relayer("SMTP", smtp)

    while true do
        local thread = relay:accept()
        ratchet.thread.attach(thread)
    end
end
-- }}}

kernel = ratchet.new(function ()
    local chain_bus, edge_bus = slimta.bus.new_local()

    local policies = {
        slimta.routing.mx.new(),
        slimta.policies.add_date_header.new(),
        slimta.policies.add_received_header.new(),
    }

    local queue_bus = slimta.bus.chain(policies, chain_bus)
    local relay_server, relay_client = slimta.bus.new_local()

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_queue, queue_bus, relay_client)
    ratchet.thread.attach(run_relay, relay_server)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
