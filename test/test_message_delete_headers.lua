
require "slimta.message.contents"

local data = [[
From: test
To: test
Subject: test test
To: another guy

beep beep
]]
data = data:gsub("%\r?%\n", "\r\n")

local contents = slimta.message.contents.new(data)

contents:delete_header("To")

local expected_data = [[
From: test
Subject: test test

beep beep
]]
expected_data = expected_data:gsub("%\r?%\n", "\r\n")
assert(expected_data == tostring(contents))

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
