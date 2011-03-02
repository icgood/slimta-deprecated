local request_context = require "request_context"
local results_context = require "results_context"

local results_channel = results_context.new()
local request_channel = request_context.new(results_channel)

kernel:attach(results_channel)
kernel:attach(request_channel)

local function on_error(err)
    print("ERROR: " .. tostring(err))
    print(debug.traceback())
end
kernel:set_error_handler(on_error)

kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
