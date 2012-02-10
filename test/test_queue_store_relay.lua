
require "ratchet"
require "ratchet.smtp.server"

require "slimta.bus"
require "slimta.queue"
require "slimta.relay"
require "slimta.storage.memory"

responses_received = 0
messages_received = 0
n = 5

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

    responses_received = responses_received + 1
end
-- }}}

-- {{{ run_queue()
function run_queue(queue_bus, relay_bus, storage)
    local queue = slimta.queue.new(queue_bus, relay_bus)

    for i=1, n do
        local thread = queue:accept()
        thread(storage)
    end
end
-- }}}

-- {{{ run_relay()
function run_relay(relay_bus)
    local smtp = slimta.relay.smtp.new()
    smtp:set_ehlo_as("test_ehlo")

    local relay = slimta.relay.new(relay_bus)
    relay:add_relayer("SMTP", smtp)

    for i=1, n do
        local thread = relay:accept()
        thread()
    end
end
-- }}}

-- {{{ receive_smtp()
function receive_smtp(relay_bus, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    assert(socket:bind(rec.addr))
    assert(socket:listen())

    ratchet.thread.attach(run_relay, relay_bus)

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

            reply.code = "250"
            reply.message = "Testing"
        end,
    }

    for i=1, n do
        local conn = socket:accept()
        local server = ratchet.smtp.server.new(conn, handlers)
        server:handle()

        messages_received = messages_received + 1
    end
end
-- }}}

kernel = ratchet.new(function ()
    local queue_server, queue_client = slimta.bus.new_local()
    local relay_server, relay_client = slimta.bus.new_local()

    local storage = slimta.storage.memory.new()
    storage:connect()

    local threads = {}
    for i=1, n do
        local t = ratchet.thread.attach(request, queue_client, "localhost", 2525)
        table.insert(threads, t)
    end
    local t = ratchet.thread.attach(run_queue, queue_server, relay_client, storage)
    ratchet.thread.attach(receive_smtp, relay_server, "localhost", 2525)
    table.insert(threads, t)
    ratchet.thread.wait_all(threads)

    local messages = storage:get_all_messages()
    assert(#messages == 0)
end)
kernel:loop()

assert(responses_received == n)
assert(messages_received == n)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
