
slimta.message.client = {}
slimta.message.client.__index = slimta.message.client

-- {{{ slimta.message.client.copy()
function slimta.message.client.copy(old)
    local self = {}
    setmetatable(self, slimta.message.client)

    for k, v in pairs(old) do
        self[k] = v
    end

    return self
end
-- }}}

-- {{{ slimta.message.client.new()
function slimta.message.client.new(protocol, ehlo, ip, security, receiver)
    local self = {}
    setmetatable(self, slimta.message.client)

    self.protocol = protocol
    self.ehlo = ehlo
    self.ip = ip
    self.security = security
    self.receiver = receiver

    return self
end
-- }}}

-- {{{ slimta.message.client.new_from()
function slimta.message.client.new_from(tbl)
    setmetatable(tbl, slimta.message.client)
end
-- }}}

------------------------

-- {{{ slimta.message.client.to_xml()
function slimta.message.client.to_xml(client)
    local lines = {
        "<client>",
        " <protocol>" .. client.protocol .. "</protocol>",
        " <ehlo>" .. client.ehlo .. "</ehlo>",
        " <ip>" .. client.ip .. "</ip>",
        " <security>" .. client.security .. "</security>",
        " <receiver>" .. client.receiver .. "</receiver>",
        "</client>",
    }

    return lines
end
-- }}}

-- {{{ slimta.message.client.from_xml()
function slimta.message.client.from_xml(tree_node)
    local protocol, ehlo, ip, security, receiver

    for i, child_node in ipairs(tree_node) do
        if child_node.name == "protocol" then
            protocol = child_node.data:match("%S+")
        elseif child_node.name == "ehlo" then
            ehlo = child_node.data:match("%S+")
        elseif child_node.name == "ip" then
            ip = child_node.data:match("%S+")
        elseif child_node.name == "security" then
            security = child_node.data:match("%S+")
        elseif child_node.name == "receiver" then
            receiver = child_node.data:match("%S+")
        end
    end

    return slimta.message.client.new(protocol, ehlo, ip, security, receiver)
end
-- }}}

return slimta.message.client

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
