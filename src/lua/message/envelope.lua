
module("slimta.message.envelope", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(sender, recipients, dest_relayer, dest_host, dest_port)
    local self = {}
    setmetatable(self, class)

    self.sender = sender
    self.recipients = recipients
    self.dest_relayer = dest_relayer
    self.dest_host = dest_host
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
    if self.dest_host then
        local attrs = ""
        if self.dest_relayer then
            attrs = attrs .. " relayer=\"" .. self.dest_relayer .. "\""
        end
        if self.dest_port then
            attrs = attrs .. " port=\"" .. self.dest_port .. "\""
        end

        table.insert(lines, " <destination" .. attrs .. ">" .. self.dest_host .. "</destination>")
    end
    table.insert(lines, "</envelope>")

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    local protocol, ehlo, ip, security
    local sender, recipients = nil, {}
    local dest_host, dest_port, dest_relayer

    for i, child_node in ipairs(tree_node) do
        if child_node.name == "sender" then
            sender = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
        elseif child_node.name == "recipient" then
            local stripped = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(recipients, stripped)
        elseif child_node.name == "destination" then
            dest_host = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
            dest_port = tonumber(child_node.attrs.port or 25)
            if child_node.attrs.relayer then
                dest_relayer = child_node.attrs.relayer:gsub("^%s*", ""):gsub("%s*$", "")
            end
        end
    end

    return new(sender, recipients, dest_relayer, dest_host, dest_port)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
