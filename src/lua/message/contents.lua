
local header_folding = require "slimta.message.header_folding"

slimta.message.contents = {}
slimta.message.contents.__index = slimta.message.contents

-- {{{ headers_metatable
local headers_metatable = {

    -- For any non-existent header, return an empty table.
    __index = function (headers, key)
        local check_lower = rawget(headers, key:lower())
        if check_lower then
            return check_lower
        else
            return {}
        end
    end

}
-- }}}

-- {{{ load_headers()
local function load_headers(self, header_data)
    local pattern = "^([%d%a%-]+)%:%s(.-)()%\r?%\n"
    local multi_line_pattern = "^(%\r?%\n%s.-)()%\r?%\n"
    local to_line_end_pattern = "^.-%\n()"

    local i = 1
    repeat
        local name, value, new_i = header_data:match(pattern, i)

        if name then
            i = new_i
            repeat
                local new_line
                new_line, new_i = header_data:match(multi_line_pattern, i)

                if new_line then
                    i = new_i
                    value = value .. new_line
                end
            until not new_i

            self:add_header(name, header_folding.unfold(value), true)
        end

        if i then
            i = header_data:match(to_line_end_pattern, i)
        end
    until not i
end
-- }}}

-- {{{ slimta.message.contents.copy()
function slimta.message.contents.copy(old)
    local self = {}
    setmetatable(self, slimta.message.contents)

    for k, v in pairs(old) do
        self[k] = v
    end

    self.headers = {}
    setmetatable(self.headers, headers_metatable)
    for k, t in pairs(old.headers) do
        self.headers[k] = {}
        for i, v in ipairs(t) do
            self.headers[k][i] = v
        end
    end

    self.header_stack = {}
    for i, v in ipairs(old.header_stack) do
        self.header_stack[i] = v
    end

    return self
end
-- }}}

-- {{{ slimta.message.contents.new()
function slimta.message.contents.new(data)
    local self = {}
    setmetatable(self, slimta.message.contents)

    self.size = #data
    self.orig_data = data

    self.headers = {}
    setmetatable(self.headers, headers_metatable)
    self.header_stack = {}

    self.headers_end, self.contents_start = data:match("%\r?%\n()%s-%\r?%\n()")
    if self.headers_end then
        load_headers(self, self.orig_data:sub(1, self.headers_end))
    end

    return self
end
-- }}}

-- {{{ slimta.message.contents:add_header()
function slimta.message.contents:add_header(name, value, after_existing)
    if not value then
        return
    end

    local key = name:lower()
    if self.headers[key][1] then
        if after_existing then
            table.insert(self.headers[key], value)
        else
            table.insert(self.headers[key], 1, value)
        end
    else
        self.headers[key] = {value}
    end

    if after_existing then
        table.insert(self.header_stack, name)
    else
        table.insert(self.header_stack, 1, name)
    end
end
-- }}}

-- {{{ slimta.message.contents:delete_header()
function slimta.message.contents:delete_header(name)
    local key = name:lower()
    self.headers[key] = nil

    local i = 1
    while true do
        local v = self.header_stack[i]
        if not v then
            break
        end

        local this_key = v:lower()
        if this_key == key then
            table.remove(self.header_stack, i)
        else
            i = i + 1
        end
    end
end
-- }}}

-- {{{ get_contents()
local function get_contents(self)
    if self.contents_start then
        return self.orig_data:sub(self.contents_start)
    else
        return self.orig_data
    end
end
-- }}}

-- {{{ slimta.message.contents:__tostring()
function slimta.message.contents:__tostring()
    local headers = ""
    local header_i = {}

    for i, name in ipairs(self.header_stack) do
        local key = name:lower()
        local this_header_vals = self.headers[key]
        
        if not header_i[key] then
            header_i[key] = 1
        end

        local value = this_header_vals[header_i[key]]
        if not value then
            error("[" .. name .. "] header stack occurances did not match value depth, use add_header() instead of modifying manually.")
        end
        header_i[key] = header_i[key] + 1

        headers = headers .. name .. ": " .. header_folding.fold(name, value) .. "\r\n"
    end
    if #headers > 0 then
        headers = headers .. "\r\n"
    end
    
    self.raw_data = headers .. get_contents(self)
    return self.raw_data
end
-- }}}

------------------------

-- {{{ slimta.message.contents.to_xml()
function slimta.message.contents.to_xml(contents, attachments)
    table.insert(attachments, tostring(contents))
    local lines = {
        "<contents part=\"" .. #attachments .. "\"/>",
    }

    return lines
end
-- }}}

-- {{{ slimta.message.contents.from_xml()
function slimta.message.contents.from_xml(tree_node, attachments)
    local part = tonumber(tree_node.attrs.part or 0)
    local data = attachments[part]
    if data then
        return slimta.message.contents.new(data)
    end
end
-- }}}

-- {{{ slimta.message.contents.to_meta()
function slimta.message.contents.to_meta(msg, meta)
    meta = meta or {}
    return meta
end
-- }}}

-- {{{ slimta.message.contents.from_meta()
function slimta.message.contents.from_meta(meta, raw_contents)
    return slimta.message.contents.new(raw_contents)
end
-- }}}

return slimta.message.contents

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
