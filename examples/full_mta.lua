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

-- {{{ reception_logger()
function reception_logger(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, message in ipairs(messages) do
            print(("R client=([%s]) sender=(%s) recipients=(%s)"):format(
                message.client.ip,
                message.envelope.sender,
                table.concat(message.envelope.recipients, ",")
            ))
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

-- {{{ delivery_logger()
function delivery_logger(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, message in ipairs(messages) do
            print(("D id=(%s) dest=([%s]:%s) sender=(%s) recipients=(%s)"):format(
                message.id,
                message.envelope.dest_host,
                message.envelope.dest_port,
                message.envelope.sender,
                table.concat(message.envelope.recipients, ",")
            ))
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

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

-- {{{ run_queue_retry()
function run_queue_retry(queue)
    local tfd = ratchet.timerfd.new()
    tfd:settime(5.0, 5.0)

    while true do
        local storage = slimta.storage[arg[1]].new()
        storage:connect(table.unpack(arg, 2))

        local retry = queue:retry(storage)
        if retry then
            ratchet.thread.attach(retry, storage)
        else
            storage:close()
        end
        tfd:read()
    end
end
-- }}}

-- {{{ run_queue()
function run_queue(bus_server, bus_client)
    local retry_backoff = function (message)
        if message.attempts <= 2 then
            return os.time() + 10
        else
            return nil
        end
    end

    local bounce_builder = slimta.message.bounce.new("postmaster@"..ratchet.socket.gethostname())
    local queue = slimta.queue.new(bus_server, bus_client, retry_backoff, bounce_builder)

    ratchet.thread.attach(run_queue_retry, queue)

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
    local pre_policies = {
        slimta.policies.add_date_header.new(),
        slimta.policies.add_received_header.new(),
        reception_logger,
    }
    local post_policies = {
        slimta.routing.mx.new(),
        delivery_logger,
    }

    local pre_chain_bus, edge_bus = slimta.bus.new_local()
    local post_chain_bus, queue_relay = slimta.bus.new_local()

    local queue_edge = slimta.bus.chain(pre_policies, pre_chain_bus)
    local relay_bus = slimta.bus.chain(post_policies, post_chain_bus)

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_queue, queue_edge, queue_relay)
    ratchet.thread.attach(run_relay, relay_bus)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
