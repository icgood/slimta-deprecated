
module("slimta.xml.writer", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new()
    local self = {}
    setmetatable(self, class)

    self.lines = {}
    self.attachments = {}

    return self
end
-- }}}

-- {{{ concat_table()
local function concat_table(t1, t2)
    local end_t1 = #t1

    for i, v in ipairs(t2) do
        t1[end_t1+i] = v
    end
end
-- }}}

-- {{{ add_item()
function add_item(self, item)
    concat_table(self.lines, item:to_xml(self.attachments))
end
-- }}}

-- {{{ add_container_opens()
local function add_container_opens(parts, containers)
    for i, v in ipairs(containers) do
        table.insert(parts, string.rep(" ", i-1) .. "<" .. v .. ">\r\n")
    end
end
-- }}}

-- {{{ add_container_closes()
local function add_container_closes(parts, containers)
    local parts_n = #parts
    for i, v in ipairs(containers) do
        table.insert(parts, parts_n+1, string.rep(" ", i-1) .. "</" .. v .. ">\r\n")
    end
end
-- }}}

-- {{{ build_recursive()
local function build_recursive(parts, this, indent)
    if type(this) == "string" then
        table.insert(parts, string.rep(" ", indent) .. this .. "\r\n")
    else
        for i, v in ipairs(this) do
            build_recursive(parts, v, indent+1)
        end
    end
end
-- }}}

-- {{{ build()
function build(self, containers)
    local parts = {}
    containers = containers or {}

    add_container_opens(parts, containers)

    local indent = #containers
    for i, v in ipairs(self.lines) do
        build_recursive(parts, v, indent)
    end

    add_container_closes(parts, containers)

    return table.concat(parts), self.attachments
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
