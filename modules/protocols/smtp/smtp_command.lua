
local smtp_command = {}
smtp_command.__index = smtp_command

-- {{{ smtp_command.new()
function smtp_command.new(name, param)
    local self = {}
    setmetatable(self, smtp_command)

    self.name = name
    self.param = param

    return self
end
-- }}}

-- {{{ smtp_command:__tostring()
function smtp_command:__tostring()
    if self.param then
        return self.name .. " " .. self.param
    else
        return self.name
    end
end
-- }}}

-- {{{ smtp_command:debug_simplify()
function smtp_command:debug_simplify()
    return tostring(self)
end
-- }}}

return smtp_command

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
