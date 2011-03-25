
-- {{{ header_fold()
local function header_fold(name, value, max_line_len)
    max_line_len = max_line_len or 78

    local len = #name + 2 + #value  -- "name: value"
    if len <= max_line_len then
        return value
    end

    local value_words = {}
    local value_whitespace = {}
    for whitespace, word in value:gmatch("(%s*)(%S*)") do
        table.insert(value_whitespace, whitespace)
        table.insert(value_words, word)
    end

    -- Construct new value with interspersed line breaks *only* on whitespace.
    local new_value = ""
    local remaining = max_line_len - #name - 2
    for i, word in ipairs(value_words) do
        local whitespace = value_whitespace[i]

        local piece_total = #whitespace + #word
        if piece_total > remaining then
            if whitespace == "" then
                new_value = new_value .. word
                remaining = remaining - piece_total
            else
                new_value = new_value .. "\r\n" .. whitespace .. word
                remaining = max_line_len - piece_total
            end
        else
            new_value = new_value .. whitespace .. word
            remaining = remaining - piece_total
        end

    end

    return new_value
end
-- }}}

-- {{{ header_unfold()
local function header_unfold(value)
    return value:gsub("%\r?%\n(%s)", "%1")
end
-- }}}

local message = {}

-- {{{ message_index()
local function message_index(self, key)
    if key == "contents" then
        return self.orig_data:sub(self.contents_start)
    else
        return message[key]
    end
end
-- }}}

message.__index = message_index

-- {{{ message.new()
function message.new(data)
    local self = {}
    setmetatable(self, message)

    self.orig_data = data
    self.headers_end, self.contents_start = data:match("%\r?%\n()%s-%\r?%\n()")
    if not self.headers_end then
        return nil, "Message data had no header-content divide"
    end

    self:reset()

    return self
end
-- }}}

-- {{{ message:reset()
function message:reset()
    self.contents = nil
    self.headers = {}
    self.header_stack = {}

    self:load_headers()
end
-- }}}

-- {{{ message:load_headers()
function message:load_headers()
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

            self:add_header(name, header_unfold(value), true)
        end

        if i then
            i = header_data:match(to_line_end_pattern, i)
        end
    until not i
end
-- }}}

-- {{{ message:add_header()
function message:add_header(name, value, after_existing)
    local key = name:lower()
    if self.headers[key] then
        if after_existing then
            table.insert(self.headers[key], value)
        else
            table.insert(self.headers[key], 1, value)
        end
    else
        self.headers[key] = {value, i = 1}
    end

    if after_existing then
        table.insert(self.header_stack, name)
    else
        table.insert(self.header_stack, 1, name)
    end
end
-- }}}

-- {{{ message:delete_header()
function message:delete_header(name)
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

-- {{{ message:finalize()
function message:finalize()
    local headers = ""

    for i, name in ipairs(self.header_stack) do
        local key = name:lower()
        local this_header_vals = self.headers[key]

        local value = this_header_vals[this_header_vals.i]
        if not value then
            error("[" .. name .. "] header stack occurances did not match value depth, use add_header() instead of modifying manually.")
        end
        this_header_vals.i = this_header_vals.i + 1

        headers = headers .. name .. ": " .. header_fold(name, value) .. "\r\n"
    end

    self.raw_data = headers .. "\r\n" .. self.contents
    return self.raw_data
end
-- }}}

return message

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
