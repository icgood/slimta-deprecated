local queue_request_context = require "queue_request_context"
local relay_results_context = require "relay_results_context"

local queue_request_channel_str = get_conf.string(queue_request_channel)
local relay_results_channel_str = get_conf.string(relay_results_channel)

uri:register("tcp", ratchet.socket.parse_tcp_uri)
uri:register("zmq", ratchet.zmqsocket.parse_uri)

local queue_request = queue_request_context.new(queue_request_channel_str)
local relay_results = relay_results_context.new(relay_results_channel_str)

kernel:attach(queue_request)
kernel:attach(relay_results)

local function on_error(err)
    print("ERROR: " .. tostring(err))
end
kernel:set_error_handler(on_error)

kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
