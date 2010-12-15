local storage_request = ratchet.new_context()
local handle_put_request = ratchet.new_context()
local handle_get_request = ratchet.new_context()

-- {{{ storage_request:on_init()
function storage_request:on_init(t)
    if t == 'get' then
        self.t = 'get'
    else
        self.t = 'put'
    end
end
-- }}}

-- {{{ storage_request:on_recv()
function storage_request:on_recv()
    if self.t == 'get' then
        return self:accept(handle_get_request)
    else
        return self:accept(handle_put_request)
    end
end
-- }}}

-- {{{ handle_put_request:on_init()
function handle_put_request:on_init()
    self.backing, self.filename = storage_engines["local"].writer()
end
-- }}}

-- {{{ handle_put_request:on_recv()
function handle_put_request:on_recv()
    local data = self:recv()
    if #data > 0 then
        self.backing:write(data)
    else
        if self.backing then
            self.backing:close()
            self:send(self.filename)
        end
        self.backing = nil
    end
end
-- }}}

-- {{{ handle_put_request:on_send()
function handle_put_request:on_send(data)
    self:close()
end
-- }}}

-- {{{ handle_get_request:on_init()
function handle_get_request:on_init()
    self.data = ''
end
-- }}}

-- {{{ handle_get_request:on_recv()
function handle_get_request:on_recv()
    local data = self:recv()
    if #data > 0 then
        self.data = self.data .. data
    else
        local filename = self.data:gsub("^%s*", ""):gsub("%s*$", "")
    end
end
-- }}}

-- {{{ handle_get_request:on_send()
function handle_get_request:on_send(data)
    self:close()
end
-- }}}

return storage_request

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
