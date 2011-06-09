
require "slimta.message.header_folding"

module("slimta.message.contents", package.seeall)
local class = getfenv()
__index = class

-- {{{ load_headers()
local function load_headers(self)
    local header_data = self.orig_data:sub(1, self.headers_end)

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

            self:add_header(name, slimta.message.header_folding.unfold(value), true)
        end

        if i then
            i = header_data:match(to_line_end_pattern, i)
        end
    until not i
end
-- }}}

-- {{{ new()
function new(data)
    local self = {}
    setmetatable(self, class)

    self.size = #data
    self.orig_data = data

    self.headers = {}
    self.header_stack = {}

    self.headers_end, self.contents_start = data:match("%\r?%\n()%s-%\r?%\n()")
    if self.headers_end then
        load_headers(self)
    end

    return self
end
-- }}}

-- {{{ add_header()
function add_header(self, name, value, after_existing)
    local key = name:lower()
    if self.headers[key] then
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

-- {{{ delete_header()
function delete_header(self, name)
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

-- {{{ __tostring()
function __tostring(self)
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

        headers = headers .. name .. ": " .. slimta.message.header_folding.fold(name, value) .. "\r\n"
    end
    if #headers > 0 then
        headers = headers .. "\r\n"
    end
    
    self.raw_data = headers .. get_contents(self)
    return self.raw_data
end
-- }}}

------------------------

-- {{{ to_xml()
function to_xml(self, attachments)
    table.insert(attachments, tostring(self))
    local lines = {
        "<contents part=\"" .. #attachments .. "\"/>",
    }

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node, attachments)
    local part = tonumber(tree_node.attrs.part or 0)
    local data = attachments[part]
    if data then
        return new(data)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
