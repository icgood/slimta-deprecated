
--------------------------------------------------------------------------------
-- {{{ Create results and request channels.

results_channel = results_context.new("zmq:push:tcp://127.0.0.1:4455")
request_context.new("zmq:pull:tcp://127.0.0.1:5544", results_channel)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Set config values.

-- {{{ config.relay.ehlo_as
config.relay.ehlo_as.value = "slimta1.dev.slimta.com"
-- }}}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Load up relay protocols that may be used.

require "modules.protocols.relay.smtp"

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:filetype=lua:sw=4:ts=4:sts=4:et:
