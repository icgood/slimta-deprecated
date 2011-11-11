
require "ratchet.bus"
require "slimta.xml.writer"
require "slimta.xml.reader"

module("slimta.bus.client", package.seeall)
local class = getfenv()
__index = class

-- {{{ request_container_to_xml()
local function request_container_to_xml(self, attachments)
    local lines = {
        "<request i=\"" .. self.i .. "\">",
        self.contents:to_xml(attachments),
        "</request>",
    }

    return lines
end
-- }}}

-- {{{ request_to_bus()
local function request_to_bus(data)
    local writer = slimta.xml.writer.new()

    for i, contents in ipairs(data) do
        local container = {
            i = i,
            contents = contents,
            to_xml = request_container_to_xml,
        }
        writer:add_item(container)
    end

    return writer:build()
end
-- }}}

-- {{{ build_response_from_bus()
local function build_response_from_bus(self)
    return function (data, attachments)
        local reader = slimta.xml.reader.new()
        local root_node = reader:parse_xml(data)
    
        local rets = {}
        for i, child_node in ipairs(root_node) do
            local ret = self.response_type.from_xml(child_node, attachments)
            table.insert(rets, ret)
        end
    
        return rets
    end
end
-- }}}

-- {{{ new()
function new(socket, response_type)
    local self = {}
    setmetatable(self, class)

    self.bus = ratchet.bus.new_client(socket, request_to_bus, build_response_from_bus(self))
    self.response_type = response_type

    return self
end
-- }}}

-- {{{ send_request()
function send_request(self, request)
    return self.bus:send_request(request)
end
-- }}}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
