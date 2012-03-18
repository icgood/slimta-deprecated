
require "slimta"
require "slimta.xml.reader"
require "slimta.xml.writer"

slimta.message = {}
slimta.message.__index = slimta.message

require "slimta.message.client"
require "slimta.message.envelope"
require "slimta.message.contents"
require "slimta.message.bounce"
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
function slimta.message.new(client, envelope, contents, timestamp, id, attempts)
    local self = {}
    setmetatable(self, slimta.message)

    self.client = client
    self.envelope = envelope
    self.contents = contents
    self.timestamp = timestamp
    self.id = id

    self.attempts = attempts or 0

    return self
end
-- }}}

-- {{{ slimta.message.load()
function slimta.message.load(storage_session, id)
    local meta = storage_session:get_message_meta(id)
    local contents = storage_session:get_message_contents(id)
    if not meta or not contents then
        return nil, "invalid"
    end

    return slimta.message.from_meta(meta, contents, id)
end
-- }}}

-- {{{ slimta.message:store()
function slimta.message:store(storage_session, id)
    self.id = id or storage_session:claim_message_id()

    local meta = self:to_meta()
    local contents = tostring(self.contents)

    storage_session:set_message_meta(self.id, meta)
    storage_session:set_message_contents(self.id, contents)

    return self.id
end
-- }}}

-- {{{ slimta.message:increment_attempts()
function slimta.message:increment_attempts(storage_session)
    self.attempts = self.attempts + 1
    storage_session:set_message_meta_key(self.id, "attempts", self.attempts)
end
-- }}}

------------------------

-- {{{ add_attr()
local function add_attr(attrs, name, value)
    table.insert(attrs, " ")
    table.insert(attrs, name)
    table.insert(attrs, "=\"")
    table.insert(attrs, value)
    table.insert(attrs, "\"")
end
-- }}}

-- {{{ slimta.message.to_xml()
function slimta.message.to_xml(msg, attachments)
    local attrs = {}
    if msg.id then
        add_attr(attrs, "id", msg.id)
    end
    if msg.timestamp then
        add_attr(attrs, "timestamp", msg.timestamp)
    end
    if msg.attempts > 0 then
        add_attr(attrs, "attempts", msg.attempts)
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
function slimta.message.from_xml(tree_node, attachments, force_id)
    local timestamp = tree_node.attrs.timestamp
    local id = force_id or tree_node.attrs.id
    local attempts = tonumber(tree_node.attrs.attempts)

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

    return slimta.message.new(client, envelope, contents, timestamp, id, attempts)
end
-- }}}

-- {{{ slimta.message.to_meta()
function slimta.message.to_meta(msg, meta)
    meta = meta or {}

    meta.timestamp = msg.timestamp
    meta.attempts = msg.attempts

    msg.client:to_meta(meta)
    msg.envelope:to_meta(meta)
    msg.contents:to_meta(meta)

    return meta
end
-- }}}

-- {{{ slimta.message.from_meta()
function slimta.message.from_meta(meta, raw_contents, force_id)
    local client = slimta.message.client.from_meta(meta, raw_contents, force_id)
    local envelope = slimta.message.envelope.from_meta(meta, raw_contents, force_id)
    local contents = slimta.message.contents.from_meta(meta, raw_contents, force_id)

    local timestamp = tonumber(meta.timestamp)
    local id = force_id or meta.id
    local attempts = tonumber(meta.attempts)

    return slimta.message.new(client, envelope, contents, timestamp, id, attempts)
end
-- }}}

return slimta.message

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
