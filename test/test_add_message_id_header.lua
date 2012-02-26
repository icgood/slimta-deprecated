
require "slimta.policies.add_message_id_header"
require "slimta.message"

local contents = slimta.message.contents.new("test message")
local message = slimta.message.new(nil, nil, contents)

local amidh = slimta.policies.add_message_id_header.new(
    "hostname.tld",
    function () return "abcdefg" end,
    function () return "1234567890" end
)

assert(not message.contents.headers["message-id"][1])

amidh:add(message)

assert(#message.contents.headers["message-id"] == 1)
assert("<abcdefg.1234567890@hostname.tld>" == message.contents.headers["message-id"][1])

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
