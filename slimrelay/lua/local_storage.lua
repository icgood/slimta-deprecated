
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
    return f:read("*a")
end
-- }}}

-- }}}

-- {{{ local_writer class

-- }}}

--------------------------------------------------------------------------------

storage_engines["local"] = {reader = local_reader, writer = local_writer}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
