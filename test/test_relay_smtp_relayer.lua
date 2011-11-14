
require "ratchet"
require "ratchet.smtp.server"

require "slimta.bus"
require "slimta.relay"

tracker = 0

-- {{{ request()
function request(bus_client, relay)
    local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt1@slimta.org", "rcpt2@slimta.org"}, "SMTP", "localhost", "2525")
    local contents = slimta.message.contents.new([[
From: Test Sender <sender@slimta.org>
To: Test Recipient 1 <rcpt1@slimta.org>
Cc: Test Recipient 2 <rcpt2@slimta.org>
Subject: test message

beep beep
]])
    local msg = slimta.message.new(client, envelope, contents)
    local transaction = bus_client:send_request({msg})
    local responses = transaction:recv_response()

    assert(#responses == 1)
    assert(responses[1].code == "250")
    assert(responses[1].message == "2.6.0 Ok")

    relay:halt()

    response_received = true
end
-- }}}

-- {{{ run_relay()
function run_relay(kernel)
    local smtp = slimta.relay.smtp.new({"ipv4"})
    smtp:ehlo_as("test_ehlo")

    local bus_server, bus_client = slimta.bus.new_local()

    local relay = slimta.relay.new(bus_server)
    relay:add_relayer("SMTP", smtp)

    kernel:attach(request, bus_client, relay)
    relay:run(kernel)
end
-- }}}

-- {{{ receive_smtp()
function receive_smtp(where, kernel)
    local rec = ratchet.socket.prepare_uri(where, {"ipv4"})
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    assert(socket:bind(rec.addr))
    assert(socket:listen())

    kernel:attach(run_relay, kernel)

    local handlers = {
        EHLO = function (self, reply, ehlo_as)
            assert("test_ehlo" == ehlo_as)
            tracker = tracker + 1
        end,

        MAIL = function (self, reply, address)
            assert("sender@slimta.org" == address)
            tracker = tracker + 2
        end,

        RCPT = function (self, reply, address)
            if address == "rcpt1@slimta.org" then
                tracker = tracker + 4
            elseif address == "rcpt2@slimta.org" then
                tracker = tracker + 8
            else
                error("'" .. address .. "' ~= 'rcptN@slimta.org'")
            end
        end,

        HAVE_DATA = function (self, reply, data, err)
            tracker = tracker + 16

            local expected = [[
From: Test Sender <sender@slimta.org>
To: Test Recipient 1 <rcpt1@slimta.org>
Cc: Test Recipient 2 <rcpt2@slimta.org>
Subject: test message

beep beep]]
            expected = expected:gsub("%\r?%\n", "\r\n")

            assert(expected == data)

            reply.message = "Ok"
        end,
    }

    local conn = socket:accept()
    local server = ratchet.smtp.server.new(conn, handlers)
    server:handle()
end
-- }}}

local kernel = ratchet.new()
kernel:attach(receive_smtp, "tcp://localhost:2525", kernel)
kernel:loop()

assert(response_received)
assert(31 == tracker)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
