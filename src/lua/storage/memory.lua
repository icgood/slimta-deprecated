
require "slimta"

slimta.storage = slimta.storage or {}
slimta.storage.memory = {}
slimta.storage.memory.__index = slimta.storage.memory

-- {{{ slimta.storage.memory.new()
function slimta.storage.memory.new()
    local self = {}
    setmetatable(self, slimta.storage.memory)

    self.meta_hash = {}
    self.contents_hash = {}
    self.lock_hash = {}
    self.retry_queue = {}

    return self
end
-- }}}

-- {{{ slimta.storage.memory:connect()
function slimta.storage.memory:connect()
end
-- }}}

-- {{{ slimta.storage.memory:close()
function slimta.storage.memory:close()
end
-- }}}

-- {{{ slimta.storage.memory:set_message_retry()
function slimta.storage.memory:set_message_retry(id, timestamp)
    self.retry_queue[id] = timestamp
end
-- }}}

-- {{{ slimta.storage.memory:get_retry_queue()
function slimta.storage.memory:get_retry_queue(timestamp)
    timestamp = timestamp or os.time()
    local ret = {}
    for id, next_retry in pairs(self.retry_queue) do
        if timestamp == "all" or next_retry <= timestamp then
            table.insert(ret, id)
        end
    end
    return ret
end
-- }}}

-- {{{ slimta.storage.memory:get_full_queue()
function slimta.storage.memory:get_full_queue()
    local ret = {}
    for id, meta in pairs(self.meta_hash) do
        table.insert(ret, id)
    end
    return ret
end
-- }}}

-- {{{ slimta.storage.memory:store_message_meta()
function slimta.storage.memory:store_message_meta(meta)
    local uuid
    repeat
        uuid = slimta.uuid.generate()
    until not self.meta_hash[uuid]
    self.meta_hash[uuid] = meta
    return uuid
end
-- }}}

-- {{{ slimta.storage.memory:store_message_contents()
function slimta.storage.memory:store_message_contents(id, contents)
    self.contents_hash[id] = tostring(contents)
end
-- }}}

-- {{{ slimta.storage.memory:load_message_meta()
function slimta.storage.memory:load_message_meta(id)
    if self.meta_hash[id] then
        return self.meta_hash[id]
    else
        return nil, "Message ID not found."
    end
end
-- }}}

-- {{{ slimta.storage.memory:load_message_contents()
function slimta.storage.memory:load_message_contents(id)
    if self.contents_hash[id] then
        return self.contents_hash[id]
    else
        return nil, "Message ID not found."
    end
end
-- }}}

-- {{{ slimta.storage.memory:lock_message()
function slimta.storage.memory:lock_message(id, length)
    local now = os.time()
    if self.lock_hash[id] and self.lock_hash[id] >= now then
        return false, "locked"
    end

    self.lock_hash[id] = now+length
    return true
end
-- }}}

-- {{{ slimta.storage.memory:unlock_message()
function slimta.storage.memory:unlock_message(id)
    self.lock_hash[id] = nil
end
-- }}}

-- {{{ slimta.storage.memory:remove_message()
function slimta.storage.memory:remove_message(id)
    self.meta_hash[id] = nil
    self.contents_hash[id] = nil
    self.lock_hash[id] = nil
    self.retry_queue[id] = nil
end
-- }}}

return slimta.storage.memory

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
