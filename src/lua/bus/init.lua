
require "slimta"
require "ratchet.bus.samestate"

slimta.bus = {}

require "slimta.bus.server"
require "slimta.bus.client"

-- {{{ slimta.bus.new_local()
function slimta.bus.new_local(...)
    return ratchet.bus.new_local(...)
end
-- }}}

-- {{{ slimta.bus.new_server()
function slimta.bus.new_server(...)
    return slimta.bus.server.new(...)
end
-- }}}

-- {{{ slimta.bus.new_client()
function slimta.bus.new_client(...)
    return slimta.bus.client.new(...)
end
-- }}}

return slimta.bus

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
