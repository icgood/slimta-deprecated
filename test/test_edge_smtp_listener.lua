
require "ratchet"
require "ratchet.smtp.client"

-- {{{ run_edge()
function run_edge(kernel)
    require "slimta.edge"

    local smtp = slimta.edge.smtp.new("tcp://localhost:2525", {"ipv4"}, true)
    smtp:set_banner_message(220, "ESMTP slimta test banner")
    smtp:set_max_message_size(10485760)

    local mock_queue = slimta.edge.queue_channel.mock(function (messages)
        assert(1 == #messages)
        local message = messages[1]

        assert("SMTP" == message.client.protocol)
        assert("test" == message.client.ehlo)
        assert("127.0.0.1" == message.client.ip)
        assert("none" == message.client.security)

        assert("sender@slimta.org" == message.envelope.sender)
        assert(1 == #message.envelope.recipients)
        assert("rcpt@slimta.org" == message.envelope.recipients[1])

        assert("arbitrary test message data" == tostring(message.contents))

        server_received_message = true
        smtp:halt()
    end)

    local edge = slimta.edge.new()
    edge:set_queue_channel(mock_queue)
    edge:add_listener(smtp)

    edge:run(kernel)
    
    kernel:attach(send_smtp, "tcp://localhost:2525")
end
-- }}}

-- {{{ send_smtp()
function send_smtp(where)
    local rec = ratchet.socket.prepare_uri(where, {"ipv4"})
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    local client = ratchet.smtp.client.new(socket)

    local banner = client:get_banner()
    assert(banner.code == "220" and banner.message == "ESMTP slimta test banner")

    local ehlo = client:ehlo("test")
    local mailfrom = client:mailfrom("sender@slimta.org")
    local rcptto = client:rcptto("rcpt@slimta.org")
    local data = client:data()

    local send_data = client:send_data("arbitrary test message data")
    local quit = client:quit()

    client_sent_message = true
end
-- }}}

local kernel = ratchet.new()
kernel:attach(run_edge, kernel)
kernel:loop()

assert(client_sent_message)
assert(server_received_message)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
