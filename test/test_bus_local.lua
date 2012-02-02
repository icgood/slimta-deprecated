
require "ratchet"
require "slimta.bus"

local request_obj, response_obj = {}, {}

function ctx1(where)
    local bus_server, bus_client = slimta.bus.new_local()

    ratchet.thread.attach(server_bus, bus_server)
    ratchet.thread.attach(client_bus_1, bus_client)
end

function server_bus(bus)
    local transaction, requests = bus:recv_request()

    assert(1 == #requests)
    assert("operation falcon" == requests[1].id)
    assert("important" == requests[1].stuff)

    response_obj.code = "250"
    response_obj.message = "Ok"

    transaction:send_response({response_obj})
end

function client_bus_1(bus)
    request_obj.id = "operation falcon"
    request_obj.stuff = "important"

    local transaction = bus:send_request({request_obj})
    local responses = transaction:recv_response()

    assert(1 == #responses)
    assert("250" == responses[1].code)
    assert("Ok" == responses[1].message)
end

kernel = ratchet.new(function ()
    ratchet.thread.attach(ctx1)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
