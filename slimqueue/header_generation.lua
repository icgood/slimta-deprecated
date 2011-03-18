
local header_generation = {}
header_generation.__index = header_generation

-- {{{ build_received_header()
local function default_received_header(message)
    local parts = {}

    return table.concat(parts, " ")
end
-- }}}

-- {{{ header_generation.new()
function header_generation.new(edge, client, message, data)
    local self = {}
    setmetatable(self, header_generation)

    self.edge = edge
    self.client = client
    self.message = message

    self.headers = {}
    self:read_existing_headers(data)

    return self
end
-- }}}

-- {{{ header_generation:read_existing_headers()
function header_generation:read_existing_headers(data)
    local pattern = "^([%d%a%-]+)%:%s(.-%\r?%\n(%s.-%\r?\n)-)()"
    local end_pattern = "^%s-%\r?%\n"
    local bad_line_pattern = "^.-%\r?%\n()"

    local i = 1
    repeat
        local name, value, _, new_i = data:match(pattern, i)

        if name then
            local key = name:lower()
            if self.headers[key] then
                table.insert(self.headers[key], value)
            else
                self.headers[key] = {value}
            end
        else
            if not data:match(end_pattern, i) then
                new_i = data:match(bad_line_pattern, i)
            end
        end

        i = new_i
    until not i
end
-- }}}

-- {{{ header_generation:add_all_headers()
function header_generation:add_all_headers()
    local headers = {}

    self:add_date_header(headers)

    return headers
end
-- }}}

-- {{{ header_generation:add_date_header()
function header_generation:add_date_header(headers)
    if not self.headers.date then
        local date = os.date("%a, %d %b %Y %T %z")
        headers["Date"] = {date}
    end
end
-- }}}

-- {{{ header_generation:add_received_header()
function header_generation:add_received_header(headers)
    local rcvd = build_received_header(self.message, self.client)

    if not headers["Received"] then
        headers["Received"] = {rcvd}
    else
        table.insert(headers["Received"], rcvd)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
