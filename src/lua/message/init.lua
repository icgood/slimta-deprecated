
require "slimta"

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

-- {{{ slimta.message.copy_per_recipient()
function slimta.message.copy_per_recipient(old)
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

-- {{{ slimta.message:store()
function slimta.message:store(storage_engine, next_attempt)
    -- We cannot simply use self as the document because the message contents
    -- must be written separately as an attachment.
    local document = {
        client = self.client,
        envelope = self.envelope,
        size = self.contents.size,
        timestamp = self.timestamp,
        attempts = self.attempts,
        next_attempt = self.next_attempt,
    }

    storage_engine:create_document(document)
    storage_engine:create_attachment(
        "message",
        "message/rfc822",
        tostring(self.contents)
    )

    self.id = storage_engine.id
end
-- }}}

-- {{{ slimta.message:load()
function slimta.message:load(storage_engine, id, do_not_parse)
    local document = storage_engine:load_document(id)

    self.client = slimta.message.client.new_from(document.client)
    self.envelope = slimta.message.envelope.new_from(document.envelope)
    self.timestamp = document.timestamp

    local attachment = storage_engine:load_attachment("message")
    self.contents = slimta.message.contents.new(attachment, do_not_parse)

    self.id = id
end
-- }}}

------------------------

-- {{{ slimta.message.to_xml()
function slimta.message.to_xml(msg, attachments)
    local lines = {
        "<message>",
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
