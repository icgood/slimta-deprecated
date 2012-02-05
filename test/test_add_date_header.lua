
require "slimta.policies.add_date_header"
require "slimta.message"

local contents = slimta.message.contents.new("test message")
local message = slimta.message.new(nil, nil, contents)

local adh = slimta.policies.add_date_header.new(function () return "test date" end)

assert(not message.contents.headers.date[1])

adh:add(message)

assert(#message.contents.headers.date == 1)
assert(message.contents.headers.date[1] == "test date")

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
