
require "slimta.message"
require "slimta.xml.reader"

local xml = [[
<edge>
 <messages>
  <message>
   <client>
    <protocol>SMTP</protocol>
    <ehlo>testing</ehlo>
    <ip>1.2.3.4</ip>
    <security>TLS</security>
   </client>
   <envelope>
    <sender>sender@domain.com</sender>
    <recipient>recipient@domain.com</recipient>
   </envelope>
   <contents part="1"/>
  </message>
  <message>
   <client>
    <protocol>HTTP</protocol>
    <ehlo>there</ehlo>
    <ip>5.6.7.8</ip>
    <security>SSL</security>
   </client>
   <envelope>
    <sender>sender@domain.com</sender>
    <recipient>recipient@domain.com</recipient>
    <destination relayer="SMTP" port="2500">4.3.2.1</destination>
   </envelope>
   <contents part="2"/>
  </message>
 </messages>
</edge>
]]

local attachments = {
    "test message data 1",
    "test message data 2",
}

local reader = slimta.xml.reader.new()
local tree = reader:parse_xml(xml)

assert(1 == #tree, "tree does not have a root node")
assert("edge" == tree[1].name, "tree root node was not 'edge'")
assert(1 == #tree[1], "'edge' does not have a child node")
assert("messages" == tree[1][1].name, "tree root child node was not 'messages'")

local messages = tree[1][1]

local msg1 = slimta.message.from_xml(messages[1], attachments)
local msg2 = slimta.message.from_xml(messages[2], attachments)

assert("SMTP" == msg1.client.protocol)
assert("testing" == msg1.client.ehlo)
assert("1.2.3.4" == msg1.client.ip)
assert("TLS" == msg1.client.security)
assert("sender@domain.com" == msg1.envelope.sender)
assert(1 == #msg1.envelope.recipients and "recipient@domain.com" == msg1.envelope.recipients[1])
assert("test message data 1" == tostring(msg1.contents))

assert("HTTP" == msg2.client.protocol)
assert("there" == msg2.client.ehlo)
assert("5.6.7.8" == msg2.client.ip)
assert("SSL" == msg2.client.security)
assert("sender@domain.com" == msg2.envelope.sender)
assert(1 == #msg2.envelope.recipients and "recipient@domain.com" == msg2.envelope.recipients[1])
assert("SMTP" == msg2.envelope.dest_relayer)
assert(2500 == msg2.envelope.dest_port)
assert("4.3.2.1" == msg2.envelope.dest_addr)
assert("test message data 2" == tostring(msg2.contents))

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
