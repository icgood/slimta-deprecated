
local smtp_reply = {}
smtp_reply.__index = smtp_reply

-- {{{ smtp_reply.new()
function smtp_reply.new()
    local self = {}
    setmetatable(self, smtp_reply)

    return self
end
-- }}}

-- {{{ smtp_reply:recv()
function smtp_reply:recv(io)
    self.code, self.message = io:recv_reply()
end
-- }}}

return smtp_reply

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
