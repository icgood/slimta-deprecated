
require "slimta"
require "slimta.xml.reader"
require "slimta.xml.writer"

slimta.message = {}
slimta.message.__index = slimta.message

require "slimta.message.client"
require "slimta.message.envelope"
require "slimta.message.contents"
require "slimta.message.response"

-- {{{ slimta.message.copy()
function slimta.message.copy(old)
    local self = {}
    setmetatable(self, slimta.message)

    for k, v in pairs(old) do
        self[k] = v
    end

    self.client = slimta.message.client.copy(old.client)
    self.envelope = slimta.message.envelope.copy(old.envelope)
    self.contents = slimta.message.contents.copy(old.contents)

    return self
end
-- }}}

-- {{{ slimta.message.new()
function slimta.message.new(client, envelope, contents, timestamp, id)
    local self = {}
    setmetatable(self, slimta.message)

    self.client = client
    self.envelope = envelope
    self.contents = contents
    self.timestamp = timestamp
    self.id = id

    self.attempts = 0
    self.next_attempt = 0

    return self
end
-- }}}

-- {{{ slimta.message.load()
function slimta.message.load(storage, id)
    if not storage:lock_message(id, 120) then
        return nil, "locked"
    end

    local meta = storage:load_message_meta(id)
    local contents = storage:load_message_contents(id)
    if not meta or not contents then
        return nil, "invalid"
    end

    local parser = slimta.xml.reader.new()
    local node = parser:parse_xml(meta)
    local ret = slimta.message.from_xml(node[1], {contents})

    storage:unlock_message(id)

    return ret
end
-- }}}

-- {{{ slimta.message:store()
function slimta.message:store(storage)
    local writer = slimta.xml.writer.new()
    writer:add_item(self)
    local meta, attachments = writer:build() 

    self.id = storage:store_message_meta(meta)

    if not storage:lock_message(self.id, 120) then
        error("Could not lock new message: "..self.id)
    end
    storage:store_message_contents(self.id, attachments[1])
    storage:unlock_message(self.id)

    return self.id
end
-- }}}

------------------------

-- {{{ slimta.message.to_xml()
function slimta.message.to_xml(msg, attachments)
    local attrs = {}
    if msg.id then
        table.insert(attrs, " id=\"")
        table.insert(attrs, msg.id)
        table.insert(attrs, "\"")
    end
    if msg.timestamp then
        table.insert(attrs, " timestamp=\"")
        table.insert(attrs, msg.timestamp)
        table.insert(attrs, "\"")
    end

    local lines = {
        ("<message%s>"):format(table.concat(attrs)),
        msg.client:to_xml(attachments),
        msg.envelope:to_xml(attachments),
        msg.contents:to_xml(attachments),
        "</message>",
    }

    return lines
end
-- }}}

-- {{{ slimta.message.from_xml()
function slimta.message.from_xml(tree_node, attachments)
    local timestamp = tree_node.attrs.timestamp
    local id = tree_node.attrs.id

    assert("message" == tree_node.name)

    local client, envelope, contents
    for i, child_node in ipairs(tree_node) do
        if child_node.name == "client" then
            client = slimta.message.client.from_xml(child_node, attachments)
        elseif child_node.name == "envelope" then
            envelope = slimta.message.envelope.from_xml(child_node, attachments)
        elseif child_node.name == "contents" then
            contents = slimta.message.contents.from_xml(child_node, attachments)
        end
    end

    return slimta.message.new(client, envelope, contents, timestamp, id)
end
-- }}}

return slimta.message

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
