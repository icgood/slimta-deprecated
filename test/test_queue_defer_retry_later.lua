
require "ratchet"
require "ratchet.smtp.server"

require "slimta.bus"
require "slimta.queue"
require "slimta.relay"
require "slimta.storage.memory"

-- {{{ request()
function request(bus_client, host, port)
    local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS", "localhost")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt1@slimta.org", "rcpt2@slimta.org"}, "SMTP", host, port)
    local contents = slimta.message.contents.new("test contents")
    local msg = slimta.message.new(client, envelope, contents, 12345)
    local transaction = bus_client:send_request({msg})
    local responses = transaction:recv_response()

    assert(#responses == 1)
    assert(responses[1].code == "250")

    response_received = true
end
-- }}}

-- {{{ run_queue()
function run_queue(queue_bus, relay_bus)
    local storage = slimta.storage.memory.new()
    local queue = slimta.queue.new(queue_bus, relay_bus, storage)
    queue:set_retry_algorithm(function () return os.time()+100 end)

    local edge_thread = queue:accept()
    edge_thread(storage)

    local deferred = queue:get_deferred_messages(storage)
    assert(1 == #deferred)

    local retry_thread = queue:retry(storage)
    assert(not retry_thread)

    local messages = queue:get_deferred_messages(storage)
    assert(1 == #messages)
end
-- }}}

-- {{{ run_relay()
function run_relay(relay_bus)
    local smtp = slimta.relay.smtp.new()
    smtp:set_ehlo_as("test_ehlo")

    local relay = slimta.relay.new(relay_bus)
    relay:add_relayer("SMTP", smtp)

    local thread = relay:accept()
    thread()
end
-- }}}

-- {{{ receive_smtp()
function receive_smtp(relay_bus, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket.SO_REUSEADDR = true
    assert(socket:bind(rec.addr))
    assert(socket:listen())

    ratchet.thread.attach(run_relay, relay_bus)

    local ret_code

    local handlers = {
        EHLO = function (self, reply, ehlo_as)
            assert("test_ehlo" == ehlo_as)
        end,

        MAIL = function (self, reply, address)
            assert("sender@slimta.org" == address)
        end,

        RCPT = function (self, reply, address)
            if address == "rcpt1@slimta.org" then
                -- Ok...
            elseif address == "rcpt2@slimta.org" then
                -- Ok...
            else
                error("'" .. address .. "' ~= 'rcptN@slimta.org'")
            end
        end,

        HAVE_DATA = function (self, reply, data, err)
            local expected = [[test contents]]
            expected = expected:gsub("%\r?%\n", "\r\n")

            assert(expected == data)

            reply.code = ret_code
            reply.message = "Testing"
        end,
    }

    ret_code = "450"
    local conn = socket:accept()
    conn:set_timeout(2.0)
    local server = ratchet.smtp.server.new(conn, handlers)
    server:handle()

    message_received = true
end
-- }}}

kernel = ratchet.new(function ()
    local queue_server, queue_client = slimta.bus.new_local()
    local relay_server, relay_client = slimta.bus.new_local()

    local request_t = ratchet.thread.attach(request, queue_client, "localhost", 2525)
    local queue_t = ratchet.thread.attach(run_queue, queue_server, relay_client)
    ratchet.thread.attach(receive_smtp, relay_server, "localhost", 2525)
end)
kernel:loop()

assert(response_received)
assert(message_received)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
