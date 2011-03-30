
local data_loader = {}
data_loader.__index = data_loader

-- {{{ data_loader.new()
function data_loader.new(storage)
    local self = {}
    setmetatable(self, data_loader)

    self.storage = storage

    return self
end
-- }}}

-- {{{ data_loader:get()
function data_loader:get()
    if not self.contents then
        self.waiting_thread = kernel:running_thread()
        kernel:pause()
    end
    return self.contents
end
-- }}}

-- {{{ data_loader:__call()
function data_loader:__call()
    local which = self.storage.engine:lower()
    local engine = modules.engines.storage[which]
    if not engine then
        error("invalid storage engine: [" .. which .."]")
    end
    engine = engine.get_contents.new()
    
    self.contents = engine(self.storage.data)
    if self.waiting_thread then
        kernel:unpause(self.waiting_thread)
        self.waiting_thread = nil
    end
end
-- }}}

return data_loader

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
