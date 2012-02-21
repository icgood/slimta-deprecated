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
    local storage = slimta.storage[arg[1]].new(table.unpack(arg, 2))
    local queue = slimta.queue.new(nil, relay_bus, storage)

    local storage_session = storage:connect()

    local messages, invalids = queue:get_all_messages(storage_session)

    for i, message in ipairs(messages) do
        local response, err = queue:try_relay(message, storage_session)
        if response then
            print(("%s: [%s] %s"):format(message.id, response.code, response.message))
            if tostring(response.code) == "250" then
                storage_session:delete_message(message.id)
            end
        else
            print(("%s: %s"):format(message.id, err))
        end
    end

    for i, id in ipairs(invalids) do
        print(("%s: ERROR: Could not load message ID from storage."):format(id))
    end

    storage_session:close()
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
