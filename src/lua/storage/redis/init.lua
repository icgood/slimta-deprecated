
require "ratchet"
require "slimta"

slimta.storage = slimta.storage or {}
slimta.storage.redis = {}
slimta.storage.redis.__index = slimta.storage.redis

local driver = require "slimta.storage.redis.driver"

-- {{{ slimta.storage.redis.new()
function slimta.storage.redis.new()
    local self = {}
    setmetatable(self, slimta.storage.redis)

    return self
end
-- }}}

-- {{{ slimta.storage.redis:connect()
function slimta.storage.redis:connect(host, port)
    self.host = host
    self.port = port or 6379
    local rec = ratchet.socket.prepare_tcp(self.host, self.port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    self.socket = socket
    self.driver = driver.new(socket)
end
-- }}}

-- {{{ slimta.storage.redis:close()
function slimta.storage.redis:close()
    if self.socket then
        self.socket:close()
        self.socket = nil
        self.driver = nil
    end
end
-- }}}

-- {{{ slimta.storage.redis:get_active_messages()
function slimta.storage.redis:get_active_messages()
    self.driver("SELECT", 1)
    local reply, err = self.driver("KEYS", "*")
    self.driver("SELECT", 0)
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ slimta.storage.redis:get_deferred_messages()
function slimta.storage.redis:get_deferred_messages(timestamp)
    timestamp = timestamp or "+inf"
    local reply, err = self.driver("ZRANGEBYSCORE", "retry_queue", "-inf", timestamp)
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ slimta.storage.redis:get_all_messages()
function slimta.storage.redis:get_all_messages()
    local reply, err = self.driver("HKEYS", "message_meta")
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ slimta.storage.redis:claim_message_id()
function slimta.storage.redis:claim_message_id()
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

-- {{{ slimta.storage.redis:set_message_meta()
function slimta.storage.redis:set_message_meta(id, meta)
    local reply, err = self.driver("HSET", "message_meta", id, tostring(meta))
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:set_message_contents()
function slimta.storage.redis:set_message_contents(id, contents)
    local reply, err = self.driver("HSET", "message_contents", id, contents)
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:get_message_meta()
function slimta.storage.redis:get_message_meta(id)
    local reply, err = self.driver("HGET", "message_meta", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:get_message_contents()
function slimta.storage.redis:get_message_contents(id)
    local reply, err = self.driver("HGET", "message_contents", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:set_message_retry()
function slimta.storage.redis:set_message_retry(id, timestamp)
    local reply, err = self.driver("ZADD", "retry_queue", timestamp, id)
end
-- }}}

-- {{{ slimta.storage.redis:lock_message()
function slimta.storage.redis:lock_message(id, length)
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

-- {{{ slimta.storage.redis:unlock_message()
function slimta.storage.redis:unlock_message(id)
    self.driver("SELECT", 1)
    self.driver("DEL", id)
    self.driver("SELECT", 0)
end
-- }}}

-- {{{ slimta.storage.redis:delete_message()
function slimta.storage.redis:delete_message(id)
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

return slimta.storage.redis

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
