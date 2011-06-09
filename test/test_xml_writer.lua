
require "slimta.xml.writer"

item2 = {
    to_xml = function (self, attachments)
        table.insert(attachments, "test")
        return {
            "1",
        }
    end,
}

item1 = {
    to_xml = function (self, attachments)
        return {
            "<item>",
            item2:to_xml(attachments),
            "</item>",
        }
    end,
}

local writer = slimta.xml.writer.new()
writer:add_item(item1)

local xml, attachments = writer:build({"container"})

assert(1 == #attachments)
assert("test" == attachments[1])

local expected_xml = [[
<container>
 <item>
  1
 </item>
</container>
]]

expected_xml = expected_xml:gsub("%\r?%\n", "\r\n")

assert(expected_xml == xml)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
