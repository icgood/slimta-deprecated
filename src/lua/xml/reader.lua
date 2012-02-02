
require "slimta"

slimta.xml.reader = {}
slimta.xml.reader.__index = slimta.xml.reader

-- {{{ slimta.xml.reader.new()
function slimta.xml.reader.new()
    local self = {}
    setmetatable(self, slimta.xml.reader)

    return self
end
-- }}}

-- {{{ start_tag()
local function start_tag(self, tag, attrs)
    local newtag = {
        name = tag,
        attrs = attrs,
        data = "",
        prev = self.curr,
    }

    table.insert(self.curr, newtag)
    self.curr = newtag
end
-- }}}

-- {{{ tag_data()
local function tag_data(self, data)
    self.curr.data = self.curr.data .. data
end
-- }}}

-- {{{ end_tag()
local function end_tag(self, tag)
    local curr = self.curr
    self.curr = curr.prev
    curr.prev = nil
end
-- }}}

-- {{{ slimta.xml.reader:parse_xml()
function slimta.xml.reader:parse_xml(data)
    self.tree = {}
    self.curr = self.tree

    local parser = slimta.xml.new(self, start_tag, end_tag, tag_data)
    local success, err = parser:parse(data)
    if not success then
        error(err)
    end

    return self.tree
end
-- }}}

return slimta.xml.reader

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
