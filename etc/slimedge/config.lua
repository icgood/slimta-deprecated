
--------------------------------------------------------------------------------
-- {{{ Create queue request channel.

-- Channel to send requests for new queued messages.
queue_request_channel = queue_request_context.new("zmq:req:tcp://127.0.0.1:4554")

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup edge protocols that will be used.

require "modules.protocols.edge.httpmail"

-- Channel to listen for HTTP-Mail traffic.
modules.protocols.edge.httpmail.new("tcp://*:8025", queue_request_channel)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:filetype=lua:sw=4:ts=4:sts=4:et:
