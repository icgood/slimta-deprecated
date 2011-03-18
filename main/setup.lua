
--------------------------------------------------------------------------------
-- {{{ Setup global config options and their defaults.

slimta.config.new("config.dns.a_queries", {"ipv6", "ipv4"})
slimta.config.new("config.socket.send_size", 102400)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Set some resource limits.

local cur, max = slimta.rlimit.get("NOFILE");
slimta.rlimit.set("NOFILE", max, max)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
