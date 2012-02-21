
slimta.message.envelope = {}
slimta.message.envelope.__index = slimta.message.envelope

-- {{{ slimta.message.envelope.copy()
function slimta.message.envelope.copy(old)
    local self = {}
    setmetatable(self, slimta.message.envelope)

    for k, v in pairs(old) do
        self[k] = v
    end

    self.recipients = {}
    for i, v in ipairs(old.recipients) do
        self.recipients[i] = v
    end

    return self
end
-- }}}

-- {{{ slimta.message.envelope.new()
function slimta.message.envelope.new(sender, recipients, dest_relayer, dest_host, dest_port)
    local self = {}
    setmetatable(self, slimta.message.envelope)

    self.sender = sender
    self.recipients = recipients
    self.dest_relayer = dest_relayer
    self.dest_host = dest_host
    self.dest_port = dest_port

    return self
end
-- }}}

------------------------

-- {{{ slimta.message.envelope.to_xml()
function slimta.message.envelope.to_xml(envelope)
    local lines = {
        "<envelope>",
        " <sender>" .. envelope.sender .. "</sender>",
    }
    for i, recip in ipairs(envelope.recipients) do
        table.insert(lines, " <recipient>" .. recip .. "</recipient>")
    end
    if envelope.dest_host then
        local attrs = ""
        if envelope.dest_relayer then
            attrs = attrs .. " relayer=\"" .. envelope.dest_relayer .. "\""
        end
        if envelope.dest_port then
            attrs = attrs .. " port=\"" .. envelope.dest_port .. "\""
        end

        table.insert(lines, " <destination" .. attrs .. ">" .. envelope.dest_host .. "</destination>")
    end
    table.insert(lines, "</envelope>")

    return lines
end
-- }}}

-- {{{ slimta.message.envelope.from_xml()
function slimta.message.envelope.from_xml(tree_node)
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
            dest_port = tonumber(child_node.attrs.port)
            if child_node.attrs.relayer then
                dest_relayer = child_node.attrs.relayer:gsub("^%s*", ""):gsub("%s*$", "")
            end
        end
    end

    return slimta.message.envelope.new(sender, recipients, dest_relayer, dest_host, dest_port)
end
-- }}}

-- {{{ slimta.message.envelope.to_meta()
function slimta.message.envelope.to_meta(msg, meta)
    meta = meta or {}

    meta.sender = msg.sender
    meta.recipients = table.concat(msg.recipients, "\0").."\0"
    meta.dest_relayer = msg.dest_relayer
    meta.dest_host = msg.dest_host
    meta.dest_port = msg.dest_port

    return meta
end
-- }}}

-- {{{ slimta.message.envelope.from_meta()
function slimta.message.envelope.from_meta(meta)
    local recipients = {}
    for rcpt in meta.recipients:gmatch("([^%\0]*)%\0") do
        table.insert(recipients, rcpt)
    end

    return slimta.message.envelope.new(
        meta.sender,
        recipients,
        meta.dest_relayer,
        meta.dest_host,
        meta.dest_port
    )
end
-- }}}

return slimta.message.envelope

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
