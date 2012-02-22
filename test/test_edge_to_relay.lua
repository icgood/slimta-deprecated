
require "ratchet"
require "ratchet.smtp.server"
require "ratchet.http.client"

require "slimta.edge.http"
require "slimta.relay"
require "slimta.relay.smtp"
require "slimta.bus"
require "slimta.message"

tracker = 0

---------- Edge part

-- {{{ run_edge()
function run_edge(bus_client, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket:setsockopt("SO_REUSEADDR", true)
    socket:bind(rec.addr)
    socket:listen()

    local http = slimta.edge.http.new(socket, bus_client)

    ratchet.thread.attach(send_http, host, port)

    local thread = http:accept()
    thread()
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

    local headers = {
    }

    local code, reason, headers, data = client:query(
        "POST",
        "/email",
        {
            ["X-Sender"] = {"sender@slimta.org"},
            ["X-Recipient"] = {"rcpt1@slimta.org", "rcpt2@slimta.org"},
            ["X-Ehlo"] = {"test"},
            ["Content-Type"] = {"message/rfc822"},
            ["Content-Length"] = {27},
        },
        "arbitrary test message data"
    )

    assert("451" == tostring(code))
    assert("4.6.0 Testing" == reason)
    client_checks_ok = true
end
-- }}}

--------- Relay part

-- {{{ run_relay()
function run_relay(bus_server)
    local smtp = slimta.relay.smtp.new()
    smtp:set_ehlo_as("test_ehlo")

    local relay = slimta.relay.new(bus_server)
    relay:add_relayer("SMTP", smtp)

    local thread = relay:accept()
    thread()
end
-- }}}

-- {{{ receive_smtp()
function receive_smtp(bus_server, host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:setsockopt("SO_REUSEADDR", true)
    socket:set_timeout(2.0)
    socket:bind(rec.addr)
    socket:listen()

    ratchet.thread.attach(run_relay, bus_server)

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
From: sender@slimta.org

arbitrary test message data]]
            expected = expected:gsub("%\r?%\n", "\r\n")

            assert(expected == data)

            reply.code = "451"
            reply.message = "4.6.0 Testing"
        end,
    }

    local conn = socket:accept()
    conn:set_timeout(2.0)
    local server = ratchet.smtp.server.new(conn, handlers)
    server:handle()
end
-- }}}

--------------------

-- {{{ router_proxy()
function router_proxy(edge_server, relay_client)
    local edge_transaction, messages = edge_server:recv_request()
    for i, msg in ipairs(messages) do
        msg.envelope.dest_relayer = "SMTP"
        msg.envelope.dest_host = "localhost"
        msg.envelope.dest_port = 2525
    end

    local relay_transaction = relay_client:send_request(messages)
    local responses = relay_transaction:recv_response()
    edge_transaction:send_response(responses)
end
-- }}}

kernel = ratchet.new(function ()
    local edge_server, edge_client = slimta.bus.new_local()
    local relay_server, relay_client = slimta.bus.new_local()

    ratchet.thread.attach(router_proxy, edge_server, relay_client)

    ratchet.thread.attach(run_edge, edge_client, "localhost", 8025)
    ratchet.thread.attach(receive_smtp, relay_server, "localhost", 2525)
end)
kernel:loop()

assert(client_checks_ok)
assert(31 == tracker)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
