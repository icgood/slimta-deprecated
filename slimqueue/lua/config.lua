------------------------------------------------------------------------------
-- Load up queue engines that will be used.
require "couchdb_queue"
couchdb_info.database_name = "queue"
couchdb_info.channel = "tcp://localhost:5984"

------------------------------------------------------------------------------
-- Load up storage engines that will be used.
storage_dir = "/home/ian/queue"
require "local_storage"
--require "couchdb_storage"

------------------------------------------------------------------------------
-- Connections strings
connections.relay_request_channel = "zmq:push:tcp://localhost:5544"
connections.relay_results_channel = "zmq:pull:tcp://*:4455"
connections.queue_storage_channel = "tcp://*:4554"
connections.queue_request_channel = "tcp://*:5445"

------------------------------------------------------------------------------
-- Set some resource limits.
local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
