
slimta.config.new("config.modules.engines.nexthop.mx.pick_one", 1)

-- {{{ nexthop_mx()
local function nexthop_mx(msg)
    local domain = msg.envelope.recipients[1]:match("%@(.-)$")
    local rec = ratchet.dns.query(domain, "mx")

    local dest
    if rec then
        local i = config.modules.engines.nexthop.mx.pick_one(rec, msg.attempts)
        dest = rec:get_i(i)
    end
    if not dest then
        dest = domain
    end

    return {
        host = dest,
        port = 25,
        protocol = "SMTP",
    }
end
-- }}}

modules.engines.nexthop = nexthop_mx

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
