
require "ratchet.bus.samestate"
require "slimta.bus.server"
require "slimta.bus.client"

module("slimta.bus", package.seeall)

-- {{{ new_local()
function new_local(...)
    return ratchet.bus.samestate.new(...)
end
-- }}}

-- {{{ new_server()
function new_server(...)
    return slimta.bus.server.new(...)
end
-- }}}

-- {{{ new_client()
function new_client(...)
    return slimta.bus.client.new(...)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
