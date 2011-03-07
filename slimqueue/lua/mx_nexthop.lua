
-- {{{ mx_nexthop()
function mx_nexthop(msg)
    local domain = msg.envelope.recipients[1]:match("%@(.-)$")
    local rec = ratchet.dns.query(domain, "mx")

    local dest
    if rec then
        local i = tonumber(CONF(pick_which_mx, rec, msg.attempts) or 1)
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

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
