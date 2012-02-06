
require "slimta"
require "ratchet"
require "ratchet.bus.samestate"

slimta.bus = {}

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

-- {{{ slimta.bus.chain()
function slimta.bus.chain(calls, from_bus)
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
        ratchet.thread.attach(table.unpack(stack))
        final_to_bus = stack[3]
    end

    return final_to_bus
end
-- }}}

return slimta.bus

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
