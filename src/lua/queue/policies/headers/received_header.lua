
-- {{{ build_from_section()
local function build_from_section(info, parts)
    local template = "from %s (%s [%s]%s)"

    local ehlo = info.client.ehlo or "[]"
    local ip = info.client.ip or "unknown"
    local host = info.client.host or "unknown"
    local port = ""
    if info.client.port then
        port = ":" .. info.client.port
    end

    table.insert(parts, template:format(ehlo, host, ip, port))
end
-- }}}

-- {{{ build_by_section()
local function build_by_section(info, parts)
    local template = "by %s (slimta %s)"
    table.insert(parts, template:format(info.server, slimta.version))
end
-- }}}

-- {{{ build_with_section()
local function build_with_section(info, parts)
    local template = "with %s"
    table.insert(parts, template:format(info.client.protocol))
end
-- }}}

-- {{{ build_id_section()
local function build_id_section(info, parts)
    local template = "id %s"
    local id = info.storage.data
    table.insert(parts, template:format(id))
end
-- }}}

-- {{{ build_for_section()
local function build_for_section(info, parts)
    local template = "for <%s>"
    local filler = table.concat(info.envelope.recipients, ">,<")
    table.insert(parts, template:format(filler))
end
-- }}}

-- {{{ add_received_header()
local function add_received_header(msg, info)
    local parts = {}

    build_from_section(info, parts)
    build_by_section(info, parts)
    build_with_section(info, parts)
    build_id_section(info, parts)
    build_for_section(info, parts)
    
    local date = os.date("%a, %d %b %Y %T %z (%Z)")

    local data = table.concat(parts, " ") .. "; " .. date
    msg:add_header("Received", data)
end
-- }}}

table.insert(modules.engines.prestorage, add_received_header)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
