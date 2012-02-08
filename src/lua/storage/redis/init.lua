
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

-- {{{ slimta.storage.redis:set_message_retry()
function slimta.storage.redis:set_message_retry(id, timestamp)
    local reply, err = self.driver("ZADD", "retry_queue", timestamp, id)
end
-- }}}

-- {{{ slimta.storage.redis:get_retry_queue()
function slimta.storage.redis:get_retry_queue(timestamp)
    timestamp = timestamp or os.time()
    local reply, err = self.driver("ZRANGEBYSCORE", "retry_queue", "-inf", timestamp)
    if err[1] then
        return nil, err[1]
    end

    return reply
end
-- }}}

-- {{{ slimta.storage.redis:store_message_meta()
function slimta.storage.redis:store_message_meta(meta)
    local uuid
    local reply, err
    repeat
        uuid = slimta.uuid.generate()
        local reply, err = self.driver("HSETNX", "message_meta", uuid, meta)
        if not reply[1] then
            return nil, err[1]
        end
    until reply[1] == 1
    return uuid
end
-- }}}

-- {{{ slimta.storage.redis:store_message_contents()
function slimta.storage.redis:store_message_contents(id, contents)
    local reply, err = self.driver("HSET", "message_contents", id, tostring(contents))
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:load_message_meta()
function slimta.storage.redis:load_message_meta(id)
    local reply, err = self.driver("HGET", "message_meta", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:load_message_contents()
function slimta.storage.redis:load_message_contents(id)
    local reply, err = self.driver("HGET", "message_contents", id)
    return reply[1], err[1]
end
-- }}}

-- {{{ slimta.storage.redis:lock_message()
function slimta.storage.redis:lock_message(id, length)
    local lock_key = "message_lock."..id
    self.driver("WATCH", lock_key)
    local reply, err = self.driver("GET", lock_key)
    if reply[1] then
        return false
    end

    self.driver("MULTI")
    self.driver("SETEX", lock_key, length, "locked")
    local reply, err = self.driver("EXEC")
    return reply[1] == "OK", err
end
-- }}}

-- {{{ slimta.storage.redis:unlock_message()
function slimta.storage.redis:unlock_message(id)
    local key = "message_lock."..id
    self.driver("DEL", key)
end
-- }}}

-- {{{ slimta.storage.redis:remove_message()
function slimta.storage.redis:remove_message(id)
    self.driver("MULTI")
    self.driver("HDEL", "message_meta", id)
    self.driver("HDEL", "message_contents", id)
    self.driver("ZREM", "retry_queue", id)
    self.driver("DEL", lock_key)
    local reply, err = self.driver("EXEC")
    return reply[1]
end
-- }}}

return slimta.storage.redis

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
