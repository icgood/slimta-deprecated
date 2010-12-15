------------------------------------------------------------------------------
-- Load up storage engines that will be used.
storage_dir = "/home/ian/queue"
require "local_storage"
--require "couchdb_storage"

------------------------------------------------------------------------------
-- Connections strings
connections.local_storage_put = "tcp://*:7887"
connections.local_storage_get = "tcp://*:8778"

------------------------------------------------------------------------------
-- Set some resource limits.
local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
