
--------------------------------------------------------------------------------
-- {{{ Include necessary logic files.

require "slimqueue.attempt_timer_context"
require "slimqueue.queue_request_context"
require "slimqueue.relay_results_context"

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup config options and their defaults.

slimta.config.new("config.queue.default_storage", "couchdb")

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
