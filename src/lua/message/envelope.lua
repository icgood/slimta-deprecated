
module("slimta.message.envelope", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(sender, recipients, dest_addr, dest_port)
    local self = {}
    setmetatable(self, class)

    self.sender = sender
    self.recipients = recipients
    self.dest_addr = dest_addr
    self.dest_port = dest_port

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
        "<envelope>",
        " <sender>" .. self.sender .. "</sender>",
    }
    for i, recip in ipairs(self.recipients) do
        table.insert(lines, " <recipient>" .. recip .. "</recipient>")
    end
    if self.dest_addr then
        if self.dest_port then
            table.insert(lines, " <destination port=\"" .. self.dest_port .. "\">" .. self.dest_addr .. "</destination>")
        else
            table.insert(lines, " <destination>" .. self.dest_addr .. "</destination>")
        end
    end
    table.insert(lines, "</envelope>")

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    local protocol, ehlo, ip, security
    local sender, recipients = nil, {}
    local dest_addr, dest_port

    for i, child_node in ipairs(tree_node) do
        if child_node.name == "sender" then
            sender = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
        elseif child_node.name == "recipient" then
            local stripped = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(recipients, stripped)
        elseif child_node.name == "destination" then
            dest_addr = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
            dest_port = tonumber(child_node.attrs.port or 25)
        end
    end

    return new(sender, recipients, dest_addr, dest_port)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
