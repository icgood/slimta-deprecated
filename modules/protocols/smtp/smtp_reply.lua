
local smtp_error = require "modules.protocols.smtp.smtp_error"

local smtp_reply = {}
smtp_reply.__index = smtp_reply

-- {{{ smtp_reply.new()
function smtp_reply.new(command, code, message)
    local self = {}
    setmetatable(self, smtp_reply)

    self.command = command
    self.code = code
    self.message = message

    if not code then
        error(self:invalid_reply())
    end

    return self
end
-- }}}

-- {{{ smtp_reply:unexpected_code()
function smtp_reply:unexpected_code()
    local err = "received unexpected code in reply"
    return smtp_error.new(err, self.command, self)
end
-- }}}

-- {{{ smtp_reply:invalid_reply()
function smtp_reply:invalid_reply()
    local err = "received invalid line in reply"

    return smtp_error.new(err, self.command, self)
end
-- }}}

-- {{{ smtp_reply:__tostring()
function smtp_reply:__tostring()
    local template = "%s %s"
    local message = self.message:gsub("%\r?%\n", "\\r\\n")
    return template:format(tostring(self.command), self.code, message)
end
-- }}}

-- {{{ smtp_reply:debug_simplify()
function smtp_relpy:debug_simplify()
    return {
        code = self.code,
        message = self.message,
    }
end
-- }}}

return smtp_reply

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
