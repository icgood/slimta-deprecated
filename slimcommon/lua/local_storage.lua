
-- {{{ local_reader class
local local_reader = {}
local_reader.__index = local_reader

-- {{{ local_reader.new()
function local_reader.new(data)
    local self = {}
    setmetatable(self, local_reader)

    self.filename = data:gsub("^%s*", ""):gsub("%s*$", "")

    return self
end
-- }}}

-- {{{ local_reader:__call()
function local_reader:__call()
    local f = io.open(self.filename)
    return {message = f:read("*a")}
end
-- }}}

-- }}}

-- {{{ local_writer class
local local_writer = {}
local_writer.__index = local_writer

-- {{{ local_writer.new()
function local_writer.new()
    local self = {}
    setmetatable(self, local_writer)

    return self
end
-- }}}

-- {{{ local_writer:__call()
function local_writer:__call()
end
-- }}}

-- }}}

-- {{{ local_list class
local local_list = {}
local_list.__index = local_list

-- {{{ local_list.new()
function local_list.new()
    local self = {}
    setmetatable(self, local_list)

    return self
end
-- }}}

-- {{{ local_list:__call()
function local_list:__call()
end
-- }}}

-- }}}

--------------------------------------------------------------------------------

storage_engines["local"] = {
    new = local_writer,
    list = local_list,
    get = local_reader,
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
