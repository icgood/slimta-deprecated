
--------------------------------------------------------------------------------
-- {{{ Load up protocols that will be used.

require "modules.protocols.edge.httpmail"

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Create queue-request and edge protocol channels.

queue_request_channel = queue_request_context.new("zmq:req:tcp://127.0.0.1:4554")
modules.protocols.edge.httpmail.new("tcp://*:8025", queue_request_channel)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:filetype=lua:sw=4:ts=4:sts=4:et:
