local request_storage = require "request_storage"
local queue_message = require "queue_message"
local relay_request = require "relay_request"

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
zmqr:attach(queue_message, zmqr:listen_uri(XXX_channel_str))
zmqr:attach(relay_request, zmqr:connect_uri(XXX_channel_str))
epr:attach(request_storage, epr:listen_uri(storage_channel_str))

local on_error = function (err)
    print("ERROR: " .. tostring(err))
    print(debug.traceback())
end
zmqr:run {timeout = master_timeout, panicf = on_error}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
