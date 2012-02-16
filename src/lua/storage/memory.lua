
require "slimta"

slimta.storage = slimta.storage or {}
slimta.storage.memory = {}
slimta.storage.memory.__index = slimta.storage.memory

-- {{{ slimta.storage.memory.new()
function slimta.storage.memory.new()
    local self = {}
    setmetatable(self, slimta.storage.memory)

    self.id_hash = {}
    self.meta_hash = {}
    self.contents_hash = {}
    self.lock_hash = {}
    self.defer_queue = {}

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

-- {{{ slimta.storage.memory:get_active_messages()
function slimta.storage.memory:get_active_messages()
    local ret = {}
    for id, _ in pairs(self.lock_hash) do
        table.insert(ret, id)
    end
    return ret
end
-- }}}

-- {{{ slimta.storage.memory:get_deferred_messages()
function slimta.storage.memory:get_deferred_messages(timestamp)
    local ret = {}
    for id, next_retry in pairs(self.defer_queue) do
        if not timestamp or os.difftime(next_retry, timestamp) <= 0 then
            table.insert(ret, id)
        end
    end
    return ret
end
-- }}}

-- {{{ slimta.storage.memory:get_all_messages()
function slimta.storage.memory:get_all_messages()
    local ret = {}
    for id, _ in pairs(self.id_hash) do
        table.insert(ret, id)
    end
    return ret
end
-- }}}

-- {{{ slimta.storage.memory:claim_message_id()
function slimta.storage.memory:claim_message_id()
    local uuid
    repeat
        uuid = slimta.uuid.generate()
    until not self.id_hash[uuid]
    self.id_hash[uuid] = true
    return uuid
end
-- }}}

-- {{{ slimta.storage.memory:set_message_meta()
function slimta.storage.memory:set_message_meta(id, meta)
    self.meta_hash[id] = tostring(meta)
end
-- }}}

-- {{{ slimta.storage.memory:set_message_contents()
function slimta.storage.memory:set_message_contents(id, contents)
    self.contents_hash[id] = contents
end
-- }}}

-- {{{ slimta.storage.memory:get_message_meta()
function slimta.storage.memory:get_message_meta(id)
    if self.meta_hash[id] then
        return self.meta_hash[id]
    else
        return nil, "Message ID not found."
    end
end
-- }}}

-- {{{ slimta.storage.memory:get_message_contents()
function slimta.storage.memory:get_message_contents(id)
    if self.contents_hash[id] then
        return self.contents_hash[id]
    else
        return nil, "Message ID not found."
    end
end
-- }}}

-- {{{ slimta.storage.memory:set_message_retry()
function slimta.storage.memory:set_message_retry(id, timestamp)
    self.defer_queue[id] = timestamp
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

-- {{{ slimta.storage.memory:delete_message()
function slimta.storage.memory:delete_message(id)
    self.id_hash[id] = nil
    self.meta_hash[id] = nil
    self.contents_hash[id] = nil
    self.lock_hash[id] = nil
    self.defer_queue[id] = nil
end
-- }}}

return slimta.storage.memory

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
