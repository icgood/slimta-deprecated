
require "ratchet"
require "ratchet.http.client"

-- {{{ run_edge()
function run_edge(kernel)
    require "slimta.edge"

    local http = slimta.edge.http.new("tcp://localhost:2525", {"ipv4"}, true)

    local mock_queue = slimta.edge.queue_channel.mock(function (messages)
        for i, msg in ipairs(messages) do
            msg.error_data = "Handled by Mock-Queue"
        end

        assert(1 == #messages)
        local message = messages[1]

        assert("HTTP" == message.client.protocol)
        assert("test" == message.client.ehlo)
        assert("127.0.0.1" == message.client.ip)
        assert("none" == message.client.security)

        assert("sender@slimta.org" == message.envelope.sender)
        assert(1 == #message.envelope.recipients)
        assert("rcpt@slimta.org" == message.envelope.recipients[1])

        assert("arbitrary test message data" == tostring(message.contents))

        server_received_message = true
        http:halt()
    end)

    local edge = slimta.edge.new()
    edge:set_queue_channel(mock_queue)
    edge:add_listener(http)

    edge:run(kernel)
    
    kernel:attach(send_http, "tcp://localhost:2525")
end
-- }}}

-- {{{ send_http()
function send_http(where)
    local rec = ratchet.socket.prepare_uri(where, {"ipv4"})
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    local client = ratchet.http.client.new(socket)

    local headers = {
    }

    local code, reason, headers, data = client:query(
        "POST",
        "/email",
        {
            ["X-Sender"] = {"sender@slimta.org"},
            ["X-Recipient"] = {"rcpt@slimta.org"},
            ["X-Ehlo"] = {"test"},
            ["Content-Type"] = {"message/rfc822"},
            ["Content-Length"] = {27},
        },
        "arbitrary test message data"
    )

    client_sent_message = true
end
-- }}}

local kernel = ratchet.new()
kernel:attach(run_edge, kernel)
kernel:loop()

assert(client_sent_message)
assert(server_received_message)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
