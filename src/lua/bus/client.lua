
require "ratchet.bus"
require "slimta.xml.writer"
require "slimta.xml.reader"

slimta.bus.client = {}
slimta.bus.client.__index = slimta.bus.client

-- {{{ request_to_bus()
local function request_to_bus(data)
    local writer = slimta.xml.writer.new()

    for i, contents in ipairs(data) do
        writer:add_item(contents)
    end

    return writer:build({"requests"})
end
-- }}}

-- {{{ build_response_from_bus()
local function build_response_from_bus(self)
    return function (data, attachments)
        local reader = slimta.xml.reader.new()
        local root_node = reader:parse_xml(data)

        assert(1 == #root_node)
        assert("responses" == root_node[1].name)
    
        local rets = {}
        for i, child_node in ipairs(root_node[1]) do
            rets[i] = self.response_type.from_xml(child_node, attachments)
        end
    
        return rets
    end
end
-- }}}

-- {{{ slimta.bus.client.new()
function slimta.bus.client.new(host, port, response_type)
    local self = {}
    setmetatable(self, slimta.bus.client)

    self.host = host
    self.port = port
    self.response_type = response_type

    return self
end
-- }}}

-- {{{ slimta.bus.client:send_request()
function slimta.bus.client:send_request(request)
    local rec = ratchet.socket.prepare_tcp(self.host, self.port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    local bus = ratchet.bus.new_client(socket, request_to_bus, build_response_from_bus(self))

    return bus:send_request(request)
end
-- }}}

return slimta.bus.client

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
