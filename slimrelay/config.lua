
------------------------------------------------------------------------------
-- Set some resource limits.
local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

------------------------------------------------------------------------------
-- Load up storage engines that will be used.
require "local_storage"
--require "couchdb_storage"

------------------------------------------------------------------------------
-- Load up session protocols that will be used.
require "smtp_context"
--require "lmtp_context"

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
