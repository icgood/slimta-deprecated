local queue_request_context = require "queue_request_context"
local relay_results_context = require "relay_results_context"
local attempt_timer_context = require "attempt_timer_context"

local queue_request = queue_request_context.new()
local relay_results = relay_results_context.new()
local attempt_timer = attempt_timer_context.new()

kernel:attach(queue_request)
kernel:attach(relay_results)
kernel:attach(attempt_timer)

local function on_error(err)
    print("ERROR: " .. tostring(err))
end
kernel:set_error_handler(on_error)

kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
