
require "ratchet.bus"
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
    
        local rets = {}
        for i, child_node in ipairs(root_node) do
            local ret = self.request_type.from_xml(child_node, attachments, from)
            table.insert(rets, ret)
        end
    
        return rets
    end
end
-- }}}

-- {{{ response_container_to_xml()
local function response_container_to_xml(self, attachments)
    local lines = {
        "<response i=\"" .. self.i .. "\">",
        self.contents:to_xml(attachments),
        "</response>",
    }

    return lines
end
-- }}}

-- {{{ response_to_bus()
local function response_to_bus(data)
    local writer = slimta.xml.writer.new()

    for i, contents in ipairs(data) do
        local container = {
            i = i,
            contents = contents,
            to_xml = response_container_to_xml,
        }
        writer:add_item(container)
    end

    return writer:build()
end
-- }}}

-- {{{ new()
function new(socket, request_type)
    local self = {}
    setmetatable(self, class)

    self.bus = ratchet.bus.new_server(socket, build_request_from_bus(self), response_to_bus)
    self.request_type = request_type

    return self
end
-- }}}

-- {{{ recv_request()
function recv_request(self)
    return self.bus:recv_request()
end
-- }}}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
