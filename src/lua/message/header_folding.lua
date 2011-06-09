
module("slimta.message.header_folding", package.seeall)

local default_max_line_len = 78

-- {{{ fold()
function fold(name, value, max_line_len)
    max_line_len = max_line_len or default_max_line_len

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

-- {{{ unfold()
function unfold(value)
    return value:gsub("%\r?%\n(%s)", "%1")
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
