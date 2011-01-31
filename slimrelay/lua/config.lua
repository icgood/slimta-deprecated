hostname = "stonehenge"

------------------------------------------------------------------------------
-- Load up storage engines that will be used.
require "local_storage"
--require "couchdb_storage"

------------------------------------------------------------------------------
-- Load up the SMTP protocol.
require "smtp_context"

------------------------------------------------------------------------------
-- Connections strings
connections.request_channel = "zmq:pull:tcp://*:5544"
connections.results_channel = "zmq:push:tcp://localhost:4455"

------------------------------------------------------------------------------
-- Set some resource limits.
local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

smtp_send_size = function (socket)
    -- socket(7) option SO_SNDBUF returns double the desired value.
    return socket.SO_SNDBUF / 2
end

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et: