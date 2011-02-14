
local xml_wrapper = {}
xml_wrapper.__index = xml_wrapper

-- {{{ xml_wrapper.new()
function xml_wrapper.new(tags)
    local self = {}
    setmetatable(self, xml_wrapper)

    self.tags = tags

    return self
end
-- }}}

-- {{{ xml_wrapper:start_tag()
function xml_wrapper:start_tag(tag, attrs)
    local tags = self.tags
    local current = {tag = tag, attrs = attrs, data = ""}
    table.insert(self.tag_stack, current)

    for i, tag_variant in ipairs(tags) do
        -- Check if this tag is the one we're looking for.
        local depth = #self.tag_stack
        local valid = (#tag_variant == depth)
        for j, t in ipairs(tag_variant) do
            if t ~= self.tag_stack[depth-j+1].tag then
                valid = false
                break
            end
        end

        -- For valid tags, generate info and handler.
        if valid then
            local currinfo = self.results
            for j, t in ipairs(self.tag_stack) do
                if t.tag_i and tags[t.tag_i].list then
                    currinfo = currinfo[tags[t.tag_i].list]
                    currinfo = currinfo[#currinfo]
                end
            end
            if tag_variant.list then
                local n = tag_variant.list
                if not currinfo[n] then
                    currinfo[n] = {}
                end
                table.insert(currinfo[n], {})
                currinfo = currinfo[n][#currinfo[n]]
            end
    
            current.tag_i = i
            current.info = currinfo
            current.handle = tag_variant.handle

            break
        end
    end
end
-- }}}

-- {{{ xml_wrapper:end_tag()
function xml_wrapper:end_tag(tag)
    local current = self.tag_stack[#self.tag_stack]

    if current and current.handle then
        current.handle(current.info, current.attrs, current.data)
    end

    table.remove(self.tag_stack)
end
-- }}}

-- {{{ xml_wrapper:tag_data()
function xml_wrapper:tag_data(data)
    local current = self.tag_stack[#self.tag_stack]
    current.data = current.data .. data
end
-- }}}

-- {{{ xml_wrapper:parse_xml()
function xml_wrapper:parse_xml(data)
    self.tag_stack = {}
    self.results = {}

    local parser = slimta.xml.new(self, self.start_tag, self.end_tag, self.tag_data)
    local success, err = parser:parse(data)
    if not success then
        error(err)
    end

    return self.results
end
-- }}}

return xml_wrapper

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
