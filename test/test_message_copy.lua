
require "slimta.message"

local client = slimta.message.client.new()
local envelope = slimta.message.envelope.new(nil, {'test1'})
local contents = slimta.message.contents.new('test contents')

local message1 = slimta.message.new(client, envelope, contents)
local message2 = slimta.message.copy(message1)

message1.contents:add_header('Test-Header', 'beep beep')
message2.contents:add_header('Important-Header', 'derp')

table.insert(message1.envelope.recipients, 'test2')
message2.envelope.recipients = {'likeaboss'}

assert(#message1.envelope.recipients == 2)
assert(message1.envelope.recipients[1] == 'test1')
assert(message1.envelope.recipients[2] == 'test2')

assert(#message2.envelope.recipients == 1)
assert(message2.envelope.recipients[1] == 'likeaboss')

assert(message1.contents.headers['test-header'][1] == 'beep beep')
assert(not message1.contents.headers['important-header'][1])

assert(message2.contents.headers['important-header'][1] == 'derp')
assert(not message2.contents.headers['test-header'][1])

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
