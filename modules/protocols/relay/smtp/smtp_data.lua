local smtp_data = {}
smtp_data.__index = smtp_data

-- {{{ smtp_data.new()
function smtp_data.new(storage)
    local self = {}
    setmetatable(self, smtp_data)

    local which = storage.engine:lower()
    local engine = modules.engines.storage[which]
    if not engine then
        error("invalid storage engine: [" .. which .."]")
    end
    self.data = storage.data
    self.engine = engine.get_contents.new()
    self.iter_size = config.relay.data.iterate_size()

    return self
end
-- }}}

-- {{{ iterator_func()
local function iterator_func(invariant, i)
    local message = invariant.full_message
    local len = invariant.send_size
    local last_part = invariant.last_part

    -- If we're done iterator, jump out.
    if invariant.done then
        return
    end

    local piece = message:sub(i, i+len-1)
    if piece == "" then
        -- We are done iterating over the message, but need to return
        -- the ".\r\n" to end DATA command.
        invariant.done = true
        local end_marker = ".\r\n"
        if #last_part > 0 and last_part ~= "\r\n" then
            end_marker = "\r\n" .. end_marker
        end
        return i, end_marker
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

-- {{{ smtp_data:iter()
function smtp_data:iter()
    if not self.full_message then
        self.unpause_thread = kernel:running_thread()
        kernel:pause()
    end

    local invariant = {send_size = self.iter_size,
                       last_part = "",
                       done = false,
                       full_message = self.full_message}

    return iterator_func, invariant, 1
end
-- }}}

-- {{{ smtp_data:get()
function smtp_data:get()
    if not self.full_message then
        self.unpause_thread = kernel:running_thread()
        kernel:pause()
    end

    return self.full_message
end
-- }}}

-- {{{ smtp_data:act()
function smtp_data:act(context, socket, more_coming)
    for i, piece in self:iter() do
        context:queue_send(socket, piece, true)
    end
    context:queue_send(socket, "", more_coming)
end
-- }}}

-- {{{ smtp_data:brief()
function smtp_data:brief()
    return "[[MESSAGE CONTENTS]]"
end
-- }}}

-- {{{ smtp_data:__call()
function smtp_data:__call()
    self.full_message = self.engine(self.data)
    if self.unpause_thread then
        kernel:unpause(self.unpause_thread)
        self.unpause_thread = nil
    end
end
-- }}}

return smtp_data

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
