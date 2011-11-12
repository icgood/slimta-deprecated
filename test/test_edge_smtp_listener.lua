
require "ratchet"
require "ratchet.smtp.client"

require "slimta.edge"
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
    local smtp = slimta.edge.smtp.new("tcp://localhost:2525", {"ipv4"}, true)
    smtp:set_banner_message(220, "ESMTP slimta test banner")
    smtp:set_max_message_size(10485760)

    local bus_server, bus_client = slimta.bus.new_local()

    local edge = slimta.edge.new(bus_client)
    edge:add_listener(smtp)

    edge:run(kernel)
    
    kernel:attach(send_smtp, "tcp://localhost:2525")

    local transaction, messages = bus_server:recv_request()
    local responses = check_messages(messages)
    transaction:send_response(responses)

    smtp:halt()
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

    assert("451" == tostring(send_data.code))
    assert("Testing" == send_data.message:match("%a+"))

    client_checks_ok = true
end
-- }}}

kernel = ratchet.new()
kernel:attach(run_edge, kernel)
kernel:loop()

assert(client_checks_ok)
assert(server_checks_ok)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
