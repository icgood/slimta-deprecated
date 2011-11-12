
require "ratchet"
require "ratchet.http.client"

require "slimta.edge"
require "slimta.bus"
require "slimta.message"

-- {{{ check_messages()
local function check_messages(messages)
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

    server_checks_ok = true

    local responses = {}
    for i, msg in ipairs(messages) do
        local response = slimta.message.response.new("451", "Testing")
        table.insert(responses, response)
    end

    return responses
end
-- }}}

-- {{{ run_edge()
function run_edge()
    local http = slimta.edge.http.new("tcp://localhost:2525", {"ipv4"})

    local bus_server, bus_client = slimta.bus.new_local()

    local edge = slimta.edge.new(bus_client)
    edge:add_listener(http)

    edge:run(kernel)
    
    kernel:attach(send_http, "tcp://localhost:2525")

    local transaction, messages = bus_server:recv_request()
    local responses = check_messages(messages)
    transaction:send_response(responses)

    edge:halt()
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

    assert("451" == tostring(code))
    assert("Testing" == reason)
    client_checks_ok = true
end
-- }}}

kernel = ratchet.new()
kernel:attach(run_edge, kernel)
kernel:loop()

assert(client_checks_ok)
assert(server_checks_ok)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
