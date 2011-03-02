local httpmail_context = require "httpmail_context"

local httpmail = httpmail_context.new()

kernel:attach(httpmail)

local function on_error(err)
    print("ERROR: " .. tostring(err))
end
kernel:set_error_handler(on_error)

kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
