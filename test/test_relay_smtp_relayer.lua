
require "ratchet"
require "ratchet.smtp.server"

require "slimta.bus"
require "slimta.relay"

tracker = 0

-- {{{ request()
function request(host, port, bus_client)
    local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt1@slimta.org", "rcpt2@slimta.org"}, "SMTP", host, port)
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

    response_received = true
end
-- }}}

-- {{{ run_relay()
function run_relay(host, port)
    local smtp = slimta.relay.smtp.new()
    smtp:set_ehlo_as("test_ehlo")

    local bus_server, bus_client = slimta.bus.new_local()

    local relay = slimta.relay.new(bus_server)
    relay:add_relayer("SMTP", smtp)

    ratchet.thread.attach(request, host, port, bus_client)

    local thread = relay:accept()
    thread()
end
-- }}}

-- {{{ receive_smtp()
function receive_smtp(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket.SO_REUSEADDR = true
    assert(socket:bind(rec.addr))
    assert(socket:listen())

    ratchet.thread.attach(run_relay, host, port)

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
    conn:set_timeout(2.0)
    local server = ratchet.smtp.server.new(conn, handlers)
    server:handle()
end
-- }}}

kernel = ratchet.new(function ()
    ratchet.thread.attach(receive_smtp, "localhost", 2525)
end)
kernel:loop()

assert(response_received)
assert(31 == tracker)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
