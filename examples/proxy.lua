#!/usr/bin/lua
--
-- slimta proxy example
--
-- Opens port 2525 on the local machine accepting SMTP traffic. Performs an MX
-- lookup on the message recipients and proxies the traffic to the highest
-- priority record.
--

require "ratchet"

require "slimta.edge.smtp"
require "slimta.relay"
require "slimta.relay.smtp"
require "slimta.bus"
require "slimta.message"

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

    local relay_bus = slimta.bus.chain(policies, chain_bus)

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_relay, relay_bus)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
