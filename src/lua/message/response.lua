
slimta.message.response = {}
slimta.message.response.__index = slimta.message.response

-- {{{ slimta.message.response.new()
function slimta.message.response.new(code, message, id)
    local self = {}
    setmetatable(self, slimta.message.response)

    self.code = code or ''
    self.message = message or ''
    self.id = id

    return self
end
-- }}}

-- {{{ slimta.message.response.new_from()
function slimta.message.response.new_from(tbl)
    setmetatable(tbl, slimta.message.response)
end
-- }}}

-- {{{ slimta.message.response:as_smtp()
function slimta.message.response:as_smtp()
    return self.code, self.message
end
-- }}}

-- {{{ slimta.message.response:as_http()
function slimta.message.response:as_http()
    local ret = {
        code = self.code,
        message = self.message,
        headers = {},
    }

    if self.id then
        ret.headers['Content-Length'] = {#self.id}
        ret.data = self.id
    end

    return ret
end
-- }}}

------------------------

-- {{{ slimta.message.response.to_xml()
function slimta.message.response.to_xml(response)
    local lines = {
        "<reply code=\"" .. response.code .. "\">" .. response.message .. "</reply>",
    }

    return lines
end
-- }}}

-- {{{ slimta.message.response.from_xml()
function slimta.message.response.from_xml(tree_node)
    assert("reply" == tree_node.name)

    local code = tonumber(tree_node.attrs.code)
    local message = tree_node.data:gsub("^%s*", ""):gsub("%s*$", "")

    return slimta.message.response.new(code, message)
end
-- }}}

return slimta.message.response

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
