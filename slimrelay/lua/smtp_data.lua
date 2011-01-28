local smtp_message = {}
smtp_message.__index = smtp_message

-- {{{ smtp_message.new()
function smtp_message.new(storage_type, info)
    local self = {}
    setmetatable(self, smtp_message)

    local engine = storage_engines[storage_type]
    if not engine then
        error("invalid storage engine: [" .. engine .."]")
    end
    self.engine = engine.reader.new(info)
    self.iter_size = get_conf.number(smtp_iterate_size or 1024)

    return self
end
-- }}}

-- {{{ message_iterator()
local function message_iterator(invariant, i)
    local message = invariant.full_message
    local len = invariant.send_size
    local last_part = invariant.last_part

    local piece = message:sub(i, i+len-1)
    if piece == "" then
        return  -- We are done iterating over the message.
    end

    piece = last_part .. piece

    piece = piece:gsub("%\r", "")
    piece = piece:gsub("%\n", "\r\n")
    piece = piece:gsub("%\n%.", "\n..")

    local delta = (2 * len) - (#piece - #last_part)
    piece = piece:sub(1+#last_part, len+#last_part)
    invariant.last_part = piece:sub(-2)

    return i + delta, piece
end
-- }}}

-- {{{ smtp_message:iterate()
function smtp_message:iterate()
    if not self.full_message then
        self.unpause_thread = kernel:running_thread()
        kernel:pause()
    end

    local invariant = {send_size = self.iter_size,
                       last_part = "",
                       full_message = self.full_message}

    return message_iterator, invariant, 1
end
-- }}}

-- {{{ smtp_message:get()
function smtp_message:get()
    if not self.full_message then
        self.unpause_thread = kernel:running_thread()
        kernel:pause()
    end

    return self.full_message
end
-- }}}

-- {{{ smtp_message:__call()
function smtp_message:__call()
    self.full_message = self.engine()
    if self.unpause_thread then
        kernel:unpause(self.unpause_thread)
        self.unpause_thread = nil
    end
end
-- }}}

return smtp_message

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
