
require "slimta"
require "ratchet"
require "ratchet.bus.samestate"

slimta.bus = {}

require "slimta.bus.proxy"
require "slimta.bus.server"
require "slimta.bus.client"

-- {{{ slimta.bus.new_local()
function slimta.bus.new_local(...)
    return ratchet.bus.new_local(...)
end
-- }}}

-- {{{ slimta.bus.new_server()
function slimta.bus.new_server(...)
    return slimta.bus.server.new(...)
end
-- }}}

-- {{{ slimta.bus.new_client()
function slimta.bus.new_client(...)
    return slimta.bus.client.new(...)
end
-- }}}

-- {{{ run_chain_link()
local function run_chain_link(call, from_bus, to_bus)
    while true do
        local from_transaction, request = from_bus:recv_request()
        ratchet.thread.attach(call, from_transaction, request, to_bus)
    end
end
-- }}}

-- {{{ slimta.bus.chain()
function slimta.bus.chain(calls, from_bus)
    local threads = {}
    local call_stacks = {}
    local call_from_bus, call_to_bus, prev_from_bus

    for i, call in ipairs(calls) do
        call_from_bus, call_to_bus = slimta.bus.new_local()
        call_stacks[i] = {call, prev_from_bus, call_to_bus}
        prev_from_bus = call_from_bus
    end

    if call_stacks[1] then
        call_stacks[1][2] = from_bus
    end

    local final_to_bus
    for i, stack in ipairs(call_stacks) do
        local t = ratchet.thread.attach(run_chain_link, table.unpack(stack))
        table.insert(threads, t)
        final_to_bus = stack[3]
    end

    return final_to_bus, threads
end
-- }}}

return slimta.bus

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
