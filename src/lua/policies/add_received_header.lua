

require "slimta"

slimta.policies = slimta.policies or {}
slimta.policies.add_received_header = {}
slimta.policies.add_received_header.__index = slimta.policies.add_received_header

-- {{{ build_from_section()
local function build_from_section(message, parts)
    local template = "from %s (%s [%s]%s)"

    local ehlo = message.client.ehlo or "[]"
    local ip = message.client.ip or "unknown"
    local host = message.client.host or "unknown"
    local port = ""
    if message.client.port then
        port = ":" .. message.client.port
    end

    table.insert(parts, template:format(ehlo, host, ip, port))
end
-- }}}

-- {{{ build_by_section()
local function build_by_section(message, parts)
    local template = "by %s (slimta %s)"
    table.insert(parts, template:format(message.client.receiver, slimta.version))
end
-- }}}

-- {{{ build_with_section()
local function build_with_section(message, parts)
    local template = "with %s"
    table.insert(parts, template:format(message.client.protocol))
end
-- }}}

-- {{{ build_id_section()
local function build_id_section(message, parts)
    if message.storage then
        local template = "id %s"
        local id = message.storage.data
        table.insert(parts, template:format(id))
    end
end
-- }}}

-- {{{ build_for_section()
local function build_for_section(message, parts)
    local template = "for <%s>"
    local filler = table.concat(message.envelope.recipients, ">,<")
    table.insert(parts, template:format(filler))
end
-- }}}

-- {{{ slimta.policies.add_received_header.new()
function slimta.policies.add_received_header.new()
    local self = {}
    setmetatable(self, slimta.policies.add_received_header)

    return self
end
-- }}}

-- {{{ slimta.policies.add_received_header:add()
function slimta.policies.add_received_header:add(message)
    local parts = {}

    build_from_section(message, parts)
    build_by_section(message, parts)
    build_with_section(message, parts)
    build_id_section(message, parts)
    build_for_section(message, parts)

    local date = os.date("%a, %d %b %Y %T %z (%Z)", message.timestamp)

    local data = table.concat(parts, " ") .. "; " .. date
    message.contents:add_header("Received", data)
end
-- }}}

-- {{{ slimta.policies.add_received_header:__call()
function slimta.policies.add_received_header:__call(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, msg in ipairs(messages) do
            self:add(msg)
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

return slimta.policies.add_received_header

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
