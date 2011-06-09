
module("slimta.message.envelope", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(sender, recipients)
    local self = {}
    setmetatable(self, class)

    self.sender = sender
    self.recipients = recipients

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
    table.insert(lines, "</envelope>")

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    local protocol, ehlo, ip, security
    local sender, recipients = nil, {}

    for i, child_node in ipairs(tree_node) do
        if child_node.name == "sender" then
            sender = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
        elseif child_node.name == "recipient" then
            local stripped = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(recipients, stripped)
        end
    end

    return new(sender, recipients)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
