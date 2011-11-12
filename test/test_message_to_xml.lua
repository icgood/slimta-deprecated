
require "slimta.message"
require "slimta.xml.writer"

local client = slimta.message.client.new("SMTP", "testing", "1.2.3.4", "TLS")
local envelope = slimta.message.envelope.new("sender@domain.com", {"recipient@domain.com"}, "SMTP", "4.3.2.1", "2500")
local contents = slimta.message.contents.new("test contents 1", true)
local msg1 = slimta.message.new(client, envelope, contents)

local client = slimta.message.client.new("HTTP", "there", "5.6.7.8", "SSL")
local envelope = slimta.message.envelope.new("sender@domain.com", {"recipient@domain.com"})
local contents = slimta.message.contents.new("test contents 2", true)
local msg2 = slimta.message.new(client, envelope, contents)

local writer = slimta.xml.writer.new()
writer:add_item(msg1)
writer:add_item(msg2)

local xml, attachments = writer:build({"edge", "messages"})

assert(2 == #attachments)
assert("test contents 1" == attachments[1])
assert("test contents 2" == attachments[2])

local expected_xml = [[
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
    <destination relayer="SMTP" port="2500">4.3.2.1</destination>
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
   </envelope>
   <contents part="2"/>
  </message>
 </messages>
</edge>
]]

expected_xml = expected_xml:gsub("%\r?%\n", "\r\n")

assert(expected_xml == xml)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
