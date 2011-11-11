
require "ratchet"
require "slimta.bus"

-- {{{ request_obj
local request_obj = {
    to_xml = function (self, attachments)
        table.insert(attachments, self.stuff)
        return {
            "<id>" .. self.id .. "</id>",
            "<stuff part=\"" .. #attachments .. "\"/>",
        }
    end,

    from_xml = function (tree_node, attachments)
        local part = tonumber(tree_node[2].attrs.part)
        return {
            id = tree_node[1].data,
            stuff = attachments[part],
        }
    end,
}
-- }}}

-- {{{ response_obj
local response_obj = {
    to_xml = function (self, attachments)
        return {
            "<response code=\"" .. self.code .. "\">" .. self.message .. "</response>",
        }
    end,

    from_xml = function (tree_node, attachments)
        return {
            code = tree_node[1].attrs.code,
            message = tree_node[1].data,
        }
    end,
}
-- }}}

function ctx1(where)
    local s_rec = ratchet.socket.prepare_uri(where)
    local s_socket = ratchet.socket.new(s_rec.family, s_rec.socktype, s_rec.protocol)
    s_socket.SO_REUSEADDR = true
    s_socket:bind(s_rec.addr)
    s_socket:listen()

    local c_rec = ratchet.socket.prepare_uri(where)
    local c_socket = ratchet.socket.new(c_rec.family, c_rec.socktype, c_rec.protocol)
    c_socket:connect(c_rec.addr)

    kernel:attach(server_bus, s_socket)
    kernel:attach(client_bus_1, c_socket)
end

function server_bus(socket)
    local bus = slimta.bus.new_server(socket, request_obj)

    local transaction, requests = bus:recv_request()

    assert(1 == #requests)
    assert("operation falcon" == requests[1].id)
    assert("important" == requests[1].stuff)

    response_obj.code = "250"
    response_obj.message = "Ok"

    transaction:send_response({response_obj})
end

function client_bus_1(socket)
    local bus = slimta.bus.new_client(socket, response_obj)

    request_obj.id = "operation falcon"
    request_obj.stuff = "important"

    local transaction = bus:send_request({request_obj})
    local responses = transaction:recv_response()

    assert(1 == #responses)
    assert("250" == responses[1].code)
    assert("Ok" == responses[1].message)
end

kernel = ratchet.new()
kernel:attach(ctx1, "tcp://localhost:10025")
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
