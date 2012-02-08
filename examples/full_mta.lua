#!/usr/bin/lua

require "ratchet"

require "slimta.edge.smtp"
require "slimta.relay"
require "slimta.relay.smtp"
require "slimta.queue"
require "slimta.bus"
require "slimta.message"
require "slimta.storage.redis"

require "slimta.routing.mx"
require "slimta.policies.add_date_header"
require "slimta.policies.add_received_header"

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

        local redis = slimta.storage.redis.new()
        redis:connect(arg[1], arg[2])

        ratchet.thread.attach(thread, redis)
    end
end
-- }}}

-- {{{ run_relay()
function run_relay(bus_server)
    local smtp = slimta.relay.smtp.new()
    smtp:set_ehlo_as("test_ehlo")

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
