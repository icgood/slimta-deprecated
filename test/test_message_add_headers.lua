
require "slimta.message"

local data = [[
From: test
To: test
Subject: test test

beep beep
]]
data = data:gsub("%\r?%\n", "\r\n")

local contents = slimta.message.contents.new(data)

contents:add_header("Date", "some day")

local expected_data = [[
Date: some day
From: test
To: test
Subject: test test

beep beep
]]
expected_data = expected_data:gsub("%\r?%\n", "\r\n")
assert(expected_data == tostring(contents))

contents:add_header("To", "another guy", true)

local expected_data = [[
Date: some day
From: test
To: test
Subject: test test
To: another guy

beep beep
]]
expected_data = expected_data:gsub("%\r?%\n", "\r\n")
assert(expected_data == tostring(contents))

----------------
-- Check header addition when no others existed.
local data = [[
beep beep
]]
data = data:gsub("%\r?%\n", "\r\n")

local contents = slimta.message.contents.new(data)

contents:add_header("Subject", "test test")

local expected_data = [[
Subject: test test

beep beep
]]
expected_data = expected_data:gsub("%\r?%\n", "\r\n")
assert(expected_data == tostring(contents))

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
