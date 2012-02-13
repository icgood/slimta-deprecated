
require "ratchet"
require "ratchet.http.client"

require "slimta.edge.http"
require "slimta.bus"
require "slimta.message"

-- {{{ send_http()
function send_http(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket:connect(rec.addr)

    local client = ratchet.http.client.new(socket)

    local email_contents = ([[
From: %s
To: %s
Subject: test message

This is a test of the HTTP email messaging system. This is only a test.
]]
    ):format(arg[1], arg[2])

    local code, reason, headers, data = client:query(
        "POST",
        "/email",
        {
            ["X-Sender"] = {arg[1]},
            ["X-Recipient"] = {arg[2]},
            ["X-Ehlo"] = {ratchet.socket.gethostname()},
            ["Content-Type"] = {"message/rfc822"},
            ["Content-Length"] = {#email_contents},
        },
        email_contents
    )

    print(code .. " " .. reason)
end
-- }}}

kernel = ratchet.new(function ()
    ratchet.thread.attach(send_http, "localhost", 8025)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
