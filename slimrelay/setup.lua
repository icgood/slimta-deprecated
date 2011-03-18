
--------------------------------------------------------------------------------
-- {{{ Include necessary logic files.

require "slimrelay.request_context"
require "slimrelay.results_context"

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup config options and their defaults.

slimta.config.new("config.relay.ehlo_as", os.getenv("HOSTNAME"))
slimta.config.new("config.relay.data.iterate_size", 1024)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
