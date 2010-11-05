local request_storage = require "request_storage"

local results_channel_str = get_conf(connections.results_channel)
local request_channel_str = get_conf(connections.request_channel)
local storage_channel_str = get_conf(connections.storage_channel)
local master_timeout = tonumber(get_conf(master_timeout or 10.0))

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

zmqr:attach(epr, epoll_context) -- Trap epoll events from zmq_poll.
epr:listen(storage_channel_str, request_storage)

local on_error = function (err)
    print("ERROR: " .. tostring(err))
    print(debug.traceback())
end
zmqr:run {timeout = master_timeout, panicf = on_error}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
