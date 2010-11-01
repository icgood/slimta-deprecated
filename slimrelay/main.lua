require "ratchet"

require "request_context"

local zmqr = ratchet(ratchet.zmq.poll())
zmqr:register_uri("zmq", ratchet.zmq.socket, ratchet.zmq.parse_uri)

local epr = ratchet(ratchet.epoll())
epr:register_uri("tcp", ratchet.socket, ratchet.socket.parse_tcp_uri)

-- {{{ epoll_context: Handles events from the epoll-based ratchet.
epoll_context = zmqr:new_context()
function epoll_context:on_recv()
    return epr:run{iterations=1, timeout=0.0, maxevents=5}
end
-- }}}

zmqr:attach(epr, epoll_context) -- Trap epoll events from zmq_poll.
local results_channel = zmqr:connect('zmq:push:tcp://localhost:4455')
zmqr:listen('zmq:pull:tcp://*:5544', request_context, epr, results_channel)

zmqr:run {timeout = 1.0}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
