
-- {{{ local
local local_writer = function ()
    template = get_conf.string(storage_dir .. "/message_XXXXXX")
    return slimta.mkstemp(template)
end

local local_reader_iter = function (f)
    return f:read("*l")
end

local local_reader = function (data)
    local filename = data:gsub("^%s*", ""):gsub("%s*$", "")
    return local_read_iter, io.input(filename)
end

storage_engines["local"] = {reader = local_read, writer = local_writer}
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
