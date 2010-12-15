local storage_request = require "storage_request"
--local queue_message = require "queue_message"
--local relay_request = require "relay_request"

local relay_request_channel_str = get_conf.string(connections.relay_request_channel)
local relay_results_channel_str = get_conf.string(connections.relay_results_channel)
local queue_storage_channel_str = get_conf.string(connections.queue_storage_channel)
local queue_request_channel_str = get_conf.string(connections.queue_storage_channel)
local master_timeout = get_conf.number(master_timeout) or 10.0

local zmqr = ratchet(ratchet.zmq.poll())
zmqr:register_uri("zmq", ratchet.zmq.socket, ratchet.zmq.parse_uri)

local epr = ratchet(ratchet.epoll())
epr:register_uri("tcp", ratchet.socket, ratchet.socket.parse_tcp_uri)

-- {{{ epoll_context: Handles events from the epoll-based ratchet.
local epoll_context = zmqr:new_context()
function epoll_context:on_recv()
    return epr:run{iterations=1, timeout=0.0, maxevents=5}
end
-- }}}

zmqr:attach(epoll_context, epr) -- Trap epoll events from zmq_poll.

epr:attach(storage_request, epr:listen_uri(queue_storage_channel_str))
--zmqr:attach(queue_message, zmqr:listen_uri(queue_request_channel_str))
--zmqr:attach(relay_request, zmqr:connect_uri(relay_request_channel_str))
--zmqr:attach(relay_results, zmqr:listen_uri(relay_results_channel_str))

local on_error = function (err)
    print("ERROR: " .. tostring(err))
    print(debug.traceback())
end
zmqr:run {timeout = master_timeout}
--zmqr:run {timeout = master_timeout, panicf = on_error}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
