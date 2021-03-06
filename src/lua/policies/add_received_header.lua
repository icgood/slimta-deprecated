

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
    if message.id then
        local template = "id %s"
        table.insert(parts, template:format(message.id))
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
function slimta.policies.add_received_header.new(date_format, use_utc)
    local self = {}
    setmetatable(self, slimta.policies.add_received_header)

    self.date_format = date_format or "%a, %d %b %Y %T %z"
    if use_utc then
        self.date_format = "!" .. self.date_format
    end

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

    local date = os.date(self.date_format, message.timestamp)

    local data = table.concat(parts, " ") .. "; " .. date
    message.contents:add_header("Received", data)
end
-- }}}

return slimta.policies.add_received_header

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
