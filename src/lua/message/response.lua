
slimta.message.response = {}
slimta.message.response.__index = slimta.message.response

-- {{{ slimta.message.response.new()
function slimta.message.response.new(code, message, data)
    local self = {}
    setmetatable(self, slimta.message.response)

    self.code = code or ''
    self.message = message or ''
    self.data = data

    return self
end
-- }}}

-- {{{ slimta.message.response:as_smtp()
function slimta.message.response:as_smtp()
    return self.code, self.message
end
-- }}}

-- {{{ http_code_translation table
-- XXX: These translations are NOT exact.
local http_code_translation = {
    "2%d%d", "200",
    "421", "503",
    "450", "503",
    "4%d%d", "500",
    "535", "403",
    "%d%d%d", "400"
}
-- }}}

-- {{{ translate_code_to_http()
local function translate_code_to_http(code)
    local code_str = tostring(code)
    local len = #http_code_translation
    for i=1, len, 2 do
        local pattern = http_code_translation[i]
        if code_str:match(pattern) then
            return http_code_translation[i+1]
        end
    end
    error("Invalid message response code: "..code)
end
-- }}}

-- {{{ slimta.message.response:as_http()
function slimta.message.response:as_http()
    local ret = {
        code = translate_code_to_http(self.code),
        message = self.message,
        headers = {},
    }

    if self.data then
        ret.headers['Content-Length'] = {#self.data}
        ret.data = self.data
    end

    return ret
end
-- }}}

------------------------

-- {{{ slimta.message.response.to_xml()
function slimta.message.response.to_xml(response)
    if response.data then
        return {
            ("<reply code=\"%s\">%s"):format(response.code, response.message),
            (" <data>%s</data>"):format(response.data),
            "</reply>",
        }
    else
        return {
            ("<reply code=\"%s\">%s</reply>"):format(response.code, response.message),
        }
    end
end
-- }}}

-- {{{ slimta.message.response.from_xml()
function slimta.message.response.from_xml(tree_node)
    assert("reply" == tree_node.name)

    local code = tonumber(tree_node.attrs.code)
    local message = tree_node.data:gsub("^%s*", ""):gsub("%s*$", "")

    local data
    for i, child_node in ipairs(tree_node) do
        if child_node.name == "data" then
            data = child_node.data:gsub("^%s*", ""):gsub("%s*$", "")
        end
    end

    return slimta.message.response.new(code, message, data)
end
-- }}}

return slimta.message.response

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
