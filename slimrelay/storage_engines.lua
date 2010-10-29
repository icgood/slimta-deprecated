require "io"

storage_engines = {}

-- {{{ local
local local_iter = function (f)
    return f:read("*l")
end

storage_engines["local"] = function (data)
    local filename = data:gsub("^%s*", ""):gsub("%s*$", "")
    return local_iter, io.input(filename)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
