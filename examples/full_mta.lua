#!/usr/bin/lua

require "ratchet"
require "ratchet.smtp.smtp_auth"

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
require "slimta.policies.add_message_id_header"

if not slimta.storage[arg[1]] then
    print("usage: "..arg[0].." <memory|redis> [redis host] [redis port]")
    os.exit(1)
end

-- {{{ reception_logger()
function reception_logger(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, message in ipairs(messages) do
            print(("R timestamp=(%s) client=([%s]) sender=(%s) recipients=(%s)"):format(
                os.date("%F %T", tonumber(message.timestamp)),
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
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        for i, message in ipairs(messages) do
            print(("D id=(%s) dest=([%s]:%s) sender=(%s) recipients=(%s) code=(%s) message=(%s)"):format(
                message.id,
                message.envelope.dest_host,
                message.envelope.dest_port,
                message.envelope.sender,
                table.concat(message.envelope.recipients, ","),
                responses[i] and responses[i].code,
                responses[i] and responses[i].message
            ))
        end
        from_transaction:send_response(responses)
    end
end
-- }}}

-- {{{ error_logger()
function error_logger(err, thread)
    local time = os.date("%F %T")
    local traceback = debug.traceback(thread, tostring(err)):gsub("(%\r?%\n)", "%1 ")
    if err.type == "ratchet_error" then
        io.stderr:write(("E time=(%s) code=(%s) traceback=(\"%s\")\n"):format(time, err.code, traceback))
    else
        io.stderr:write(("E time=(%s) traceback=(\"%s\")\n"):format(time, traceback))
    end
    io.stderr:flush()
end
-- }}}

-- {{{ run_edge()
function run_edge(bus_client, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:setsockopt("SO_REUSEADDR", true)
    socket:bind(rec.addr)
    socket:listen()

    local smtp = slimta.edge.smtp.new(socket, bus_client)
    smtp:set_timeout(10.0)

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
        local retry = queue:retry()
        if retry then
            ratchet.thread.attach(retry)
        end
        tfd:read()
    end
end
-- }}}

-- {{{ run_queue()
function run_queue(bus_server, bus_client)
    local retry_backoff = function (message)
        if message.attempts <= 5 then
            return os.time() + 600
        else
            return nil
        end
    end

    local storage = slimta.storage[arg[1]].new(table.unpack(arg, 2))
    local queue = slimta.queue.new(bus_server, bus_client, storage)
    queue:set_retry_algorithm(retry_backoff)
    local bounce_builder = slimta.message.bounce.new("postmaster@"..ratchet.socket.gethostname())
    queue:set_bounce_builder(bounce_builder)

    ratchet.thread.attach(run_queue_retry, queue)

    while true do
        local thread = queue:accept()
        ratchet.thread.attach(thread)
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

-- {{{ main()
function main()
    local prequeue_policies = {
        slimta.policies.add_date_header.new(),
        slimta.policies.add_received_header.new(),
        slimta.policies.add_message_id_header.new(),
        reception_logger,
    }
    local postqueue_policies = {
        slimta.routing.mx.new(),
        delivery_logger,
    }

    local prequeue_chain_bus, edge_bus = slimta.bus.new_local()
    local postqueue_chain_bus, queue_relay = slimta.bus.new_local()

    local queue_edge = slimta.bus.chain(prequeue_policies, prequeue_chain_bus)
    local relay_bus = slimta.bus.chain(postqueue_policies, postqueue_chain_bus)

    ratchet.thread.attach(run_edge, edge_bus, "*", 2525)
    ratchet.thread.attach(run_queue, queue_edge, queue_relay)
    ratchet.thread.attach(run_relay, relay_bus)
end
-- }}}

kernel = ratchet.new(main, error_logger)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
