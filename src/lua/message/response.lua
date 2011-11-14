
module("slimta.message.response", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(code, message, id)
    local self = {}
    setmetatable(self, class)

    self.code = code or ''
    self.message = message or ''
    self.id = id

    return self
end
-- }}}

-- {{{ new_from()
function new_from(tbl)
    setmetatable(tbl, class)
end
-- }}}

-- {{{ as_smtp()
function as_smtp(self)
    return self.code, self.message
end
-- }}}

-- {{{ as_http()
function as_http(self)
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

-- {{{ to_xml()
function to_xml(self)
    local lines = {
        "<reply code=\"" .. self.code .. "\">" .. self.message .. "</reply>",
    }

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    assert("reply" == tree_node.name)

    local code = tonumber(tree_node.attrs.code)
    local message = tree_node.data:gsub("^%s*", ""):gsub("%s*$", "")

    return new(code, message)
end
-- }}}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
