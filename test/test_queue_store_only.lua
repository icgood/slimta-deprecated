
require "ratchet"

require "slimta.bus"
require "slimta.queue"
require "slimta.storage.memory"

-- {{{ request()
function request(bus_client, i)
    local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS", "localhost")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt1@slimta.org", "rcpt2@slimta.org"})
    local contents = slimta.message.contents.new("test contents")
    local msg = slimta.message.new(client, envelope, contents, 12345)
    local transaction = bus_client:send_request({msg})
    local responses = transaction:recv_response()

    assert(#responses == 1)
    assert(responses[1].code == "250")

    response_received = true
end
-- }}}

-- {{{ run_queue()
function run_queue(bus_server, n)
    local queue = slimta.queue.new(bus_server)
    local storage = slimta.storage.memory.new()
    storage:connect()

    local store_threads = {}
    for i=1, n do
        local thread = queue:accept()
        local r_thread = ratchet.thread.attach(thread.store, thread, storage)
        table.insert(store_threads, r_thread)
    end
    ratchet.thread.wait_all(store_threads)

    local messages = queue:get_all_messages(storage)

    assert(#messages == n)
    for i=1, n do
        assert(messages[i].envelope.sender == "sender@slimta.org")
        assert(tostring(messages[i].contents) == "test contents")
    end

    messages_matched = true
end
-- }}}

kernel = ratchet.new(function ()
    local bus_server, bus_client = slimta.bus.new_local()

    local n = 5
    for i=1, n do
        ratchet.thread.attach(request, bus_client, i)
    end
    ratchet.thread.attach(run_queue, bus_server, n)
end)
kernel:loop()

assert(response_received)
assert(messages_matched)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
