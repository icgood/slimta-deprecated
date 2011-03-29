
local smtp_error = {}
smtp_error.__index = smtp_error

-- {{{ smtp_error.new()
function smtp_error.new(errmsg, command, reply)
    local self = {}
    setmetatable(self, smtp_error)

    self.errmsg = errmsg
    self.command = command
    self.reply = reply

    return self
end
-- }}}

-- {{{ smtp_error:__tostring()
function smtp_error:__tostring()
    return self.errmsg
end
-- }}}

-- {{{ smtp_error:debug_simplify()
function smtp_error:debug_simplify()
    local ret = {
        ["error"] = tostring(self),
    }
    if self.command then
        ret.command = self.command:debug_simplify()
    end
    if self.reply then
        ret.reply = self.reply:debug_simplify()
    end

    return ret
end
-- }}}

return smtp_error

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
