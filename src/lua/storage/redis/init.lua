
require "ratchet"
require "slimta"

slimta.storage = slimta.storage or {}
slimta.storage.redis = {}
slimta.storage.redis.__index = slimta.storage.redis

local driver = require "slimta.storage.redis.driver"
local session = require "slimta.storage.redis.session"

-- {{{ slimta.storage.redis.new()
function slimta.storage.redis.new(host, port)
    local self = {}
    setmetatable(self, slimta.storage.redis)

    self.host = host
    self.port = port or 6379

    return self
end
-- }}}

-- {{{ slimta.storage.redis:connect()
function slimta.storage.redis:connect()
    local rec = ratchet.socket.prepare_tcp(self.host, self.port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    local driver = driver.new(socket)
    return session.new(driver)
end
-- }}}

return slimta.storage.redis

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
