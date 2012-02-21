
require "ratchet"
require "slimta"

local redis_session = {}
redis_session.__index = redis_session

-- {{{ redis_session.new()
function redis_session.new(driver)
    local self = {}
    setmetatable(self, redis_session)

    self.driver = driver

    return self
end
-- }}}

-- {{{ redis_session:close()
function redis_session:close()
    self.driver:close()
end
-- }}}

-- {{{ redis_session:get_active_messages()
function redis_session:get_active_messages()
    self.driver("SELECT", 1)
    local reply, err = self.driver("KEYS", "*")
    self.driver("SELECT", 0)
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ redis_session:get_deferred_messages()
function redis_session:get_deferred_messages(timestamp)
    timestamp = timestamp or "+inf"
    local reply, err = self.driver("ZRANGEBYSCORE", "retry_queue", "-inf", timestamp)
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ redis_session:get_all_messages()
function redis_session:get_all_messages()
    local reply, err = self.driver("HKEYS", "message_meta")
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ redis_session:claim_message_id()
function redis_session:claim_message_id()
    local uuid
    repeat
        uuid = slimta.uuid.generate()
        local reply, err = self.driver("SADD", "message_ids", uuid)
        if not reply[1] then
            return nil, err[1]
        end
    until reply[1] == 1
    return uuid
end
-- }}}

-- {{{ redis_session:set_message_meta()
function redis_session:set_message_meta(id, meta)
    local reply, err = self.driver("HSET", "message_meta", id, tostring(meta))
    return reply[1], err[1]
end
-- }}}

-- {{{ redis_session:set_message_contents()
function redis_session:set_message_contents(id, contents)
    local reply, err = self.driver("HSET", "message_contents", id, contents)
    return reply[1], err[1]
end
-- }}}

-- {{{ redis_session:get_message_meta()
function redis_session:get_message_meta(id)
    local reply, err = self.driver("HGET", "message_meta", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ redis_session:get_message_contents()
function redis_session:get_message_contents(id)
    local reply, err = self.driver("HGET", "message_contents", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ redis_session:set_message_retry()
function redis_session:set_message_retry(id, timestamp)
    local reply, err = self.driver("ZADD", "retry_queue", timestamp, id)
end
-- }}}

-- {{{ redis_session:lock_message()
function redis_session:lock_message(id, length)
    self.driver("SELECT", 1)
    self.driver("WATCH", id)
    local reply, err = self.driver("TTL", id)
    if reply[1] and reply[1] >= 0 then
        self.driver("UNWATCH")
        self.driver("SELECT", 0)
        return false
    end

    self.driver("MULTI")
    self.driver("SETEX", id, length, "locked")
    reply, err = self.driver("EXEC")
    self.driver("SELECT", 0)
    return reply[1] == "OK", err
end
-- }}}

-- {{{ redis_session:unlock_message()
function redis_session:unlock_message(id)
    self.driver("SELECT", 1)
    self.driver("DEL", id)
    self.driver("SELECT", 0)
end
-- }}}

-- {{{ redis_session:delete_message()
function redis_session:delete_message(id)
    self.driver("MULTI")
    self.driver("SREM", "message_ids", id)
    self.driver("HDEL", "message_meta", id)
    self.driver("HDEL", "message_contents", id)
    self.driver("ZREM", "retry_queue", id)
    self.driver("SELECT", 1)
    self.driver("DEL", id)
    self.driver("SELECT", 0)
    local reply, err = self.driver("EXEC")
    return reply[1]
end
-- }}}

return redis_session

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
