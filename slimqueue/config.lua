------------------------------------------------------------------------------
-- Load up storage engines that will be used.
require "local_storage"
--require "couchdb_storage"

------------------------------------------------------------------------------
-- Connections strings
connections.request_channel = "zmq:push:tcp://localhost:5544"
connections.results_channel = "zmq:pull:tcp://*:4455"
connections.storage_channel = "tcp://localhost:4554"

------------------------------------------------------------------------------
-- Set some resource limits.
local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
