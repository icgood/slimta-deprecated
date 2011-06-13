
require "ratchet"

-- {{{ mock_queue_listener()
function mock_queue_listener(kernel)
    local rec = ratchet.zmqsocket.prepare_uri("zmq:rep:tcp://127.0.0.1:7357")
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:bind(rec.endpoint)

    kernel:attach(request_message_enqueue, "zmq:req:tcp://127.0.0.1:7357")

    local data = socket:recv()

    local expected = [[
<slimta>
 <request type="enqueue" i="1">
  <message>
   <client>
    <protocol>SMTP</protocol>
    <ehlo>test</ehlo>
    <ip>1.2.3.4</ip>
    <security>none</security>
   </client>
   <envelope>
    <sender>sender@slimta.org</sender>
    <recipient>rcpt@slimta.org</recipient>
   </envelope>
   <contents part="1"/>
  </message>
 </request>
 <request type="enqueue" i="2">
  <message>
   <client>
    <protocol>HTTP</protocol>
    <ehlo>test</ehlo>
    <ip>5.6.7.8</ip>
    <security>none</security>
   </client>
   <envelope>
    <sender>sender@slimta.org</sender>
    <recipient>rcpt@slimta.org</recipient>
   </envelope>
   <contents part="2"/>
  </message>
 </request>
</slimta>
]]
    expected = expected:gsub("%\r?%\n", "\r\n")
    assert(expected == data)

    while socket:is_rcvmore() do
        local data = socket:recv()
        assert("arbitrary test message data" == data)
    end

    local response = [[
<slimta>
 <response type="enqueue" i="1">
  <success>0123456789</success>
 </response>
 <response type="enqueue" i="2">
  <error>Could Not Queue!</error>
 </response>
</slimta>
]]

    socket:send(response)
end
-- }}}

-- {{{ request_message_enqueue()
function request_message_enqueue(where)
    require "slimta.edge"
    require "slimta.message"

    local channel = slimta.edge.queue_channel.new(where)

    local client = slimta.message.client.new("SMTP", "test", "1.2.3.4", "none")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt@slimta.org"})
    local contents = slimta.message.contents.new("arbitrary test message data")
    local message1 = slimta.message.new(client, envelope, contents)

    local client = slimta.message.client.new("HTTP", "test", "5.6.7.8", "none")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"rcpt@slimta.org"})
    local contents = slimta.message.contents.new("arbitrary test message data")
    local message2 = slimta.message.new(client, envelope, contents)

    channel:request_enqueue({message1, message2})

    assert("0123456789" == message1.id)
    assert("Could Not Queue!" == message2.error_data.data)

    queue_responses_valid = true
end
-- }}}

local kernel = ratchet.new()
kernel:attach(mock_queue_listener, kernel)
kernel:loop()

assert(queue_responses_valid)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
