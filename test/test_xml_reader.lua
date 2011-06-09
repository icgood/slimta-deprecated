
require "slimta.xml.reader"

local xml = [[<container><item1>1</item1>test<item2>2</item2></container>]]

local reader = slimta.xml.reader.new()
local tree = reader:parse_xml(xml)

assert(1 == #tree, "tree does not have one root node")
assert(2 == #tree[1], "tree root node does not have 2 child nodes")
assert("test" == tree[1].data, "tree root node data wrong")
assert("container" == tree[1].name, "tree root node name is wrong")
assert("item1" == tree[1][1].name, "tree child node 1 name is wrong")
assert("item2" == tree[1][2].name, "tree child node 2 name is wrong")
assert("1" == tree[1][1].data, "tree child node 1 data wrong")
assert("2" == tree[1][2].data, "tree child node 2 data wrong")

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
