
require "slimta.policies.add_received_header"
require "slimta.message"

local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS", "myhost.tld")
local envelope = slimta.message.envelope.new("sender@domain.com", {"recipient@domain.com"}, "SMTP", "4.3.2.1", "2500")
local contents = slimta.message.contents.new("test contents 1")
local message = slimta.message.new(client, envelope, contents, 1234567890)

local arh = slimta.policies.add_received_header.new(nil, true)

assert(not message.contents.headers.received[1])

arh:add(message)

assert(#message.contents.headers.received == 1)
assert(message.contents.headers.received[1] == "from testing (unknown [1.2.3.4]) by myhost.tld (slimta 0.0) with SMTP for <recipient@domain.com>; Fri, 13 Feb 2009 23:31:30 +0000")

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
