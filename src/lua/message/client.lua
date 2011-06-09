
module("slimta.message.client", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(protocol, ehlo, ip, security)
    local self = {}
    setmetatable(self, class)

    self.protocol = protocol
    self.ehlo = ehlo
    self.ip = ip
    self.security = security

    return self
end
-- }}}

-- {{{ new_from()
function new_from(tbl)
    setmetatable(tbl, class)
end
-- }}}

------------------------

-- {{{ to_xml()
function to_xml(self)
    local lines = {
        "<client>",
        " <protocol>" .. self.protocol .. "</protocol>",
        " <ehlo>" .. self.ehlo .. "</ehlo>",
        " <ip>" .. self.ip .. "</ip>",
        " <security>" .. self.security .. "</security>",
        "</client>",
    }

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    local protocol, ehlo, ip, security

    for i, child_node in ipairs(tree_node) do
        if child_node.name == "protocol" then
            protocol = child_node.data:match("%S+")
        elseif child_node.name == "ehlo" then
            ehlo = child_node.data:match("%S+")
        elseif child_node.name == "ip" then
            ip = child_node.data:match("%S+")
        elseif child_node.name == "security" then
            security = child_node.data:match("%S+")
        end
    end

    return new(protocol, ehlo, ip, security)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
