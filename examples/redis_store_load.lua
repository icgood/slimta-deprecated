#!/usr/bin/lua

require "ratchet"

require "slimta"
require "slimta.message"
require "slimta.storage.redis"

local kernel = ratchet.new(function ()
    local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS", "myhost.tld")
    local envelope = slimta.message.envelope.new("sender@domain.com", {"recipient@domain.com"}, "SMTP", "4.3.2.1", 2500)
    local contents = slimta.message.contents.new("test contents 1")
    local msg1 = slimta.message.new(client, envelope, contents, 12345)

    local redis = slimta.storage.redis.new()
    redis:connect(arg[1], arg[2])

    local id = msg1:store(redis)
    local msg2, err = slimta.message.load(redis, id)
    if not msg2 then
        error(err)
    end

    redis:remove_message(id)
    redis:close()

    assert(msg1.envelope.sender == msg2.envelope.sender)
    assert(tostring(msg1.contents) == tostring(msg2.contents))
end)
kernel:loop()

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
