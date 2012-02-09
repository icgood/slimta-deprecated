#!/usr/bin/lua

require "ratchet"

require "slimta.relay"
require "slimta.relay.smtp"
require "slimta.queue"
require "slimta.bus"
require "slimta.message"

require "slimta.routing.mx"

require "slimta.storage.memory"
require "slimta.storage.redis"

if not slimta.storage[arg[1]] then
    print("usage: "..arg[0].." <memory|redis> [redis host] [redis port]")
    os.exit(1)
end

-- {{{ run_relay()
function run_relay(bus_server)
    local smtp = slimta.relay.smtp.new()
    local hostname = os.getenv("HOSTNAME") or ratchet.socket.gethostname()
    smtp:set_ehlo_as(hostname or "unknown")

    local relay = slimta.relay.new(bus_server)
    relay:add_relayer("SMTP", smtp)

    while true do
        local thread = relay:accept()
        ratchet.thread.attach(thread)
    end
end
-- }}}

-- {{{ flush_queue()
function flush_queue(relay_bus)
    local queue = slimta.queue.new(nil, relay_bus)

    local storage = slimta.storage[arg[1]].new()
    storage:connect(table.unpack(arg, 2))

    local messages = queue:get_all_queued_messages(storage)
    for i, message in ipairs(messages) do
        local response = queue:try_relay(message, storage)
        print(("%s: [%s] %s"):format(message.id, response.code, response.message))
        if tostring(response.code) == "250" then
            storage:remove_message(message.id)
        end
    end

    storage:close()
end
-- }}}

kernel = ratchet.new(function ()
    local chain_server, relay_client = slimta.bus.new_local()

    local policies = {
        slimta.routing.mx.new(),
    }

    local relay_server, chain_threads = slimta.bus.chain(policies, chain_server)

    local rt = ratchet.thread.attach(run_relay, relay_server)
    local fq = ratchet.thread.attach(flush_queue, relay_client)

    ratchet.thread.wait_all({fq})
    ratchet.thread.kill(rt)
    ratchet.thread.kill_all(chain_threads)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
