
require "ratchet"
require "ratchet.smtp.client"

require "slimta.edge.smtp"
require "slimta.bus"
require "slimta.message"

-- {{{ check_messages()
local function check_messages(messages)
    assert(1 == #messages)
    local message = messages[1]

    assert("SMTP" == message.client.protocol)
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

    local smtp = slimta.edge.smtp.new(socket, bus_client)
    smtp:set_banner_message(220, "ESMTP slimta test banner")
    smtp:set_max_message_size(10485760)

    local edge_thread = ratchet.thread.attach(handle_connections, smtp)
    ratchet.thread.attach(send_smtp, "localhost", 2525)

    local transaction, messages = bus_server:recv_request()
    local responses = check_messages(messages)
    transaction:send_response(responses)

    ratchet.thread.kill(edge_thread)
    smtp:close()
end
-- }}}

-- {{{ send_smtp()
function send_smtp(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
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

    assert("451" == tostring(send_data.code))
    assert("Testing" == send_data.message:match("%a+"))

    client_checks_ok = true
end
-- }}}

kernel = ratchet.new()
kernel = ratchet.new(function ()
    ratchet.thread.attach(run_edge, "localhost", 2525)
end)
kernel:loop()

assert(client_checks_ok)
assert(server_checks_ok)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
