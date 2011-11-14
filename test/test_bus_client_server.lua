
require "ratchet"
require "slimta.bus"

-- {{{ request_obj
local request_obj = {
    to_xml = function (self, attachments)
        table.insert(attachments, self.stuff)
        return {
            "<request>",
            " <id>" .. self.id .. "</id>",
            " <stuff part=\"" .. #attachments .. "\"/>",
            "</request>",
        }
    end,

    from_xml = function (tree_node, attachments)
        assert("request" == tree_node.name)
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
            code = tree_node.attrs.code,
            message = tree_node.data,
        }
    end,
}
-- }}}

function server_bus(where)
    local bus = slimta.bus.new_server(where, request_obj)
    kernel:attach(client_bus, where)

    local transaction, requests = bus:recv_request()

    assert(1 == #requests)
    assert("operation falcon" == requests[1].id)
    assert("important" == requests[1].stuff)

    response_obj.code = "250"
    response_obj.message = "Ok"

    transaction:send_response({response_obj})
end

function client_bus(where)
    local bus = slimta.bus.new_client(where, response_obj)

    request_obj.id = "operation falcon"
    request_obj.stuff = "important"

    local transaction = bus:send_request({request_obj})
    local responses = transaction:recv_response()

    assert(1 == #responses)
    assert("250" == responses[1].code)
    assert("Ok" == responses[1].message)
end

kernel = ratchet.new()
kernel:attach(server_bus, "tcp://localhost:10025")
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
