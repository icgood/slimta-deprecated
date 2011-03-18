
slimta.config.new("config.modules.engines.attempting.linear.seconds", 300) -- Five minute default.
slimta.config.new("config.modules.engines.attempting.linear.retries", 144) -- 12 hour default, at five minutes per try.

-- {{{ modules.engines.attempting.linear()
function modules.engines.attempting.linear(attempts)
    local retries = config.modules.engines.attempting.linear.retries()
    if attempts < retries then
        local seconds = config.modules.engines.attempting.linear.seconds()
        return slimta.get_now() + seconds
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
