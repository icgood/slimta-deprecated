
require "slimta.message"

local data = [[
Subject: test test test test test test test test test test test test test test test test test test test

beep beep
]]
data = data:gsub("%\r?%\n", "\r\n")

local contents = slimta.message.contents.new(data)

assert("test test test test test test test test test test test test test test test test test test test" == contents.headers["subject"][1])

local expected_data = [[
Subject: test test test test test test test test test test test test test test
 test test test test test

beep beep
]]
expected_data = expected_data:gsub("%\r?%\n", "\r\n")
assert(expected_data == tostring(contents))

local contents = slimta.message.contents.new(expected_data)

assert("test test test test test test test test test test test test test test test test test test test" == contents.headers["subject"][1])

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
