
require "ratchet"
require "ratchet.smtp.client"

require "slimta.edge.smtp"
require "slimta.edge.smtp.auth"
require "slimta.bus"
require "slimta.message"

local hmac = require "slimta.hmac".encode
local encode = require "slimta.base64".encode
local decode = require "slimta.base64".decode

-- {{{ get_auth_secret()
function get_auth_secret(user)
    assert(user == "testuser")
    return "testpass"
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

    local auth = slimta.edge.smtp.auth.new()
    auth:add_mechanism("PLAIN", get_auth_secret)
    auth:add_mechanism("LOGIN", get_auth_secret)
    auth:add_mechanism("CRAM-MD5", get_auth_secret, "testhost")

    local ssl = ratchet.ssl.new(ratchet.ssl.TLSv1_server)
    ssl:load_certs("cert.pem")

    local smtp = slimta.edge.smtp.new(socket, bus_client)
    smtp:enable_tls(ssl)
    smtp:enable_authentication(auth)
    smtp:set_timeout(2.0)

    run_auth_tests(smtp, host, port)

    smtp:close()
end
-- }}}

-- {{{ initialize_connection()
function initialize_connection(host, port)
    local rec = ratchet.socket.prepare_tcp(host, port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:set_timeout(2.0)
    socket:connect(rec.addr)

    local client = ratchet.smtp.client.new(socket)

    local banner = client:get_banner()
    assert(banner.code == "220")

    local ehlo = client:ehlo("test")
    assert(ehlo.code == "250")
    assert(client.extensions:has("AUTH"))

    return client
end
-- }}}

-- {{{ initialize_tls()
function initialize_tls(client)
    local ssl = ratchet.ssl.new(ratchet.ssl.TLSv1_client)
    ssl:load_cas(nil, "cert.pem")

    local tls_reply = client:starttls()
    assert(tls_reply.code == "220")

    local enc = client.io.socket:encrypt(ssl)
    enc:client_handshake()

    local got_cert, verified = enc:verify_certificate()
    assert(got_cert and verified)

    local ehlo = client:ehlo("test")
    assert(ehlo.code == "250")
    assert(client.extensions:has("AUTH"))
end
-- }}}

-- {{{ send_auth()
function send_auth(server, host, port, do_auth)
    ratchet.thread.attach(function ()
        client = initialize_connection(host, port)
        do_auth(client)
        client:quit()
    end)
    local thread = server:accept()
    thread()
end
-- }}}

-- {{{ auth_plain_good_1()
function auth_plain_good_1(client)
    local notls_reply = client:custom_command("AUTH", "PLAIN")
    assert(notls_reply.code == "504")

    initialize_tls(client)

    local reply1 = client:custom_command("AUTH", "PLAIN")
    assert(reply1.code == "334")

    local reply2 = client:custom_command("AHRlc3R1c2VyAHRlc3RwYXNz")
    assert(reply2.code == "235")
end
-- }}}

-- {{{ auth_plain_good_2()
function auth_plain_good_2(client)
    local notls_reply = client:custom_command("AUTH", "PLAIN")
    assert(notls_reply.code == "504")

    initialize_tls(client)

    local reply = client:custom_command("AUTH", "PLAIN AHRlc3R1c2VyAHRlc3RwYXNz")
    assert(reply.code == "235")
end
-- }}}

-- {{{ auth_plain_bad_1()
function auth_plain_bad_1(client)
    initialize_tls(client)

    local reply1 = client:custom_command("AUTH", "PLAIN")
    assert(reply1.code == "334")

    local reply2 = client:custom_command("AHRlc3R1c2VyAHNzYXB0c2V0")
    assert(reply2.code == "535")
end
-- }}}

-- {{{ auth_plain_bad_2()
function auth_plain_bad_2(client)
    initialize_tls(client)

    local reply = client:custom_command("AUTH", "PLAIN AHRlc3R1c2VyAHNzYXB0c2V0")
    assert(reply.code == "535")
end
-- }}}

-- {{{ auth_login_good()
function auth_login_good(client)
    local notls_reply = client:custom_command("AUTH", "LOGIN")
    assert(notls_reply.code == "504")

    initialize_tls(client)

    local reply1 = client:custom_command("AUTH", "LOGIN")
    assert(reply1.code == "334")

    local reply2 = client:custom_command("dGVzdHVzZXI=")
    assert(reply2.code == "334")

    local reply3 = client:custom_command("dGVzdHBhc3M=")
    assert(reply3.code == "235")
end
-- }}}

-- {{{ auth_login_bad()
function auth_login_bad(client)
    initialize_tls(client)

    local reply1 = client:custom_command("AUTH", "LOGIN")
    assert(reply1.code == "334")

    local reply2 = client:custom_command("dGVzdHVzZXI=")
    assert(reply2.code == "334")

    local reply3 = client:custom_command("c3NhcHRzZXQ=")
    assert(reply3.code == "535")
end
-- }}}

-- {{{ create_crammd5_hex_digest()
function create_crammd5_hex_digest(data)
    local ret = {}
    for i=1, #data do
        local n = string.byte(data, i)
        table.insert(ret, ("%02x"):format(n))
    end
    return table.concat(ret)
end
-- }}}

-- {{{ auth_crammd5_good()
function auth_crammd5_good(client)
    local reply1 = client:custom_command("AUTH", "CRAM-MD5")
    assert(reply1.code == "334")
    local challenge = decode(reply1.message)

    digest = create_crammd5_hex_digest(hmac("md5", challenge, "testpass"))
    local response = encode(("testuser %s"):format(digest))
    local reply2 = client:custom_command(response)
    assert(reply2.code == "235")
end
-- }}}

-- {{{ auth_crammd5_bad()
function auth_crammd5_bad(client)
    local reply1 = client:custom_command("AUTH", "CRAM-MD5")
    assert(reply1.code == "334")
    local challenge = decode(reply1.message)

    digest = create_crammd5_hex_digest(hmac("md5", challenge, "ssaptset"))
    local response = encode(("testuser %s"):format(digest))
    local reply2 = client:custom_command(response)
    assert(reply2.code == "535")
end
-- }}}

-- {{{ run_auth_tests()
function run_auth_tests(server, host, port)
    send_auth(server, host, port, auth_plain_good_1)
    send_auth(server, host, port, auth_plain_good_2)
    send_auth(server, host, port, auth_plain_bad_1)
    send_auth(server, host, port, auth_plain_bad_2)
    send_auth(server, host, port, auth_login_good)
    send_auth(server, host, port, auth_login_bad)
    send_auth(server, host, port, auth_crammd5_good)
    send_auth(server, host, port, auth_crammd5_bad)
end
-- }}}

kernel = ratchet.new()
kernel = ratchet.new(function ()
    ratchet.thread.attach(run_edge, "localhost", 2525)
end, function (err, thread)
    print(debug.traceback(thread, err))
    os.exit(1)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
