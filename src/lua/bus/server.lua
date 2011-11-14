
require "ratchet.bus"
require "ratchet.socket"
require "slimta.xml.writer"
require "slimta.xml.reader"

module("slimta.bus.server", package.seeall)
local class = getfenv()
__index = class

-- {{{ build_request_from_bus()
local function build_request_from_bus(self)
    return function (data, attachments, from)
        local reader = slimta.xml.reader.new()
        local root_node = reader:parse_xml(data)

        assert(1 == #root_node)
        assert("requests" == root_node[1].name)

        local rets = {}
        for i, child_node in ipairs(root_node[1]) do
            rets[i] = self.request_type.from_xml(child_node, attachments, from)
        end
    
        return rets
    end
end
-- }}}

-- {{{ response_to_bus()
local function response_to_bus(data)
    local writer = slimta.xml.writer.new()

    for i, contents in ipairs(data) do
        writer:add_item(contents)
    end

    return writer:build({"responses"})
end
-- }}}

-- {{{ new()
function new(uri, request_type)
    local self = {}
    setmetatable(self, class)

    self.uri = uri
    self.request_type = request_type

    return self
end
-- }}}

-- {{{ create_ratchet_bus()
local function create_ratchet_bus(self)
    local rec = ratchet.socket.prepare_uri(self.uri)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    self.bus = ratchet.bus.new_server(socket, build_request_from_bus(self), response_to_bus)
end
-- }}}

-- {{{ recv_request()
function recv_request(self)
    if not self.bus then
        create_ratchet_bus(self)
    end

    return self.bus:recv_request()
end
-- }}}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
