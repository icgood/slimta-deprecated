
local smtp_extensions = {}
smtp_extensions.__index = smtp_extensions

-- {{{ smtp_extensions.new()
function smtp_extensions.new()
    local self = {}
    setmetatable(self, smtp_extensions)

    self.extensions = {}

    return self
end
-- }}}

-- {{{ smtp_extensions:reset()
function smtp_extensions:reset()
    self.extensions = {}
end
-- }}}

-- {{{ smtp_extensions:has_extension()
function smtp_extensions:has_extension(ext)
    return self.extensions[ext:upper()]
end
-- }}}

-- {{{ smtp_extensions:add_extension()
function smtp_extensions:add_extension(ext, param)
    if param and #param > 0 then
        self.extensions[ext:upper()] = param
    else
        self.extensions[ext:upper()] = true
    end
end
-- }}}

-- {{{ smtp_extensions:parse_string()
function smtp_extensions:parse_string(str)
    local pattern = "^%s*(%w[%w%-]*)(.*)$"
    for line in str:gmatch("(.-)%\r?%\n") do
        self:add_extension(line:match(pattern))
    end
end
-- }}}

-- {{{ smtp_extensions:build_string()
function smtp_extensions:build_string()
    local lines = {}
    for k, v in pairs(self.extensions) do
        if v == true then
            table.insert(lines, k)
        else
            table.insert(lines, k.." "..v)
        end
    end
    return table.concat(lines, "\r\n")
end
-- }}}

return smtp_extensions

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
