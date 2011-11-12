
module("slimta.message.response", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(code, message, id)
    local self = {}
    setmetatable(self, class)

    self.code = code
    self.message = message
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
        "<message code=\"" .. self.code .. "\">" .. self.message .. "</message>",
    }

    return lines
end
-- }}}

-- {{{ from_xml()
function from_xml(tree_node)
    local message_node = tree_node[1]
    assert(message_node and "message" == message_node.name)

    local code = tonumber(message_node.attrs.code)
    local message = message_node.data:gsub("^%s*", ""):gsub("%s*$", "")

    return new(code, message)
end
-- }}}

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
