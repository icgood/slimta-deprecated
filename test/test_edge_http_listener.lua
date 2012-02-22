
require "ratchet"
require "ratchet.http.client"

require "slimta.edge.http"
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

    local expected = [[
From: sender@slimta.org

arbitrary test message data]]
    expected = expected:gsub("%\r?%\n", "\r\n")

    assert(expected == tostring(message.contents))

    server_checks_ok = true

    local responses = {}
    for i, msg in ipairs(messages) do
        local response = slimta.message.response.new("451", "Testing")
        table.insert(responses, response)
    end

    return responses
end
-- }}}

-- {{{ handle_connections()
function handle_connections(edge)
    while true do
        local thread = edge:accept()
        ratchet.thread.attach(thread)
    end
end
-- }}}

-- {{{ run_edge()
function run_edge(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket:setsockopt("SO_REUSEADDR", true)
    socket:bind(rec.addr)
    socket:listen()

    local bus_server, bus_client = slimta.bus.new_local()

    local http = slimta.edge.http.new(socket, bus_client)

    local edge_thread = ratchet.thread.attach(handle_connections, http)
    ratchet.thread.attach(send_http, host, port)

    local transaction, messages = bus_server:recv_request()
    local responses = check_messages(messages)
    transaction:send_response(responses)

    ratchet.thread.kill(edge_thread)
    http:close()
end
-- }}}

-- {{{ send_http()
function send_http(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket:connect(rec.addr)

    local client = ratchet.http.client.new(socket)

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

kernel = ratchet.new(function ()
    ratchet.thread.attach(run_edge, "localhost", 8025)
end)
kernel:loop()

assert(client_checks_ok)
assert(server_checks_ok)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
