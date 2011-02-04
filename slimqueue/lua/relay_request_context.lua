
local relay_request_context = {}
relay_request_context.__index = relay_request_context

-- {{{ relay_request_context.new()
function relay_request_context.new(message)
    local self = {}
    setmetatable(self, relay_request_context)

    self.endpoint = get_conf.string(relay_request_channel)
    self.message = message

    return self
end
-- }}}

-- {{{ relay_request_context:build_message()
function relay_request_context:build_message(data)
    local msg_tmpl = [[<slimta><deliver>
 <nexthop>
  <protocol>SMTP</protocol>
  <destination>mx1.emailsrvr.com</destination>
  <port>25</port>
  <security></security>
  <message queueid="0123456789">
   <envelope>
    <sender>%s</sender>
%s   </envelope>
   <contents storage="couchdb" size="%d">%s</contents>
  </message>
 </nexthop>
</deliver></slimta>
]]

    local rcpt_tmpl = [[    <recipient>%s</recipient>
]]

    local rcpts = ""
    for i, rcpt in ipairs(self.message.envelope.recipients) do
        rcpts = rcpts .. rcpt_tmpl:format(rcpt)
    end
    local sender = self.message.envelope.sender
    local size = self.message.size

    local msg = msg_tmpl:format(sender, rcpts, size, data)

    return msg
end
-- }}}

-- {{{ relay_request_context:__call()
function relay_request_context:__call(data)
    local t, e = uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(t)
    socket:connect(e)

    local msg = self:build_message(data)

    socket:send(msg)
end
-- }}}

return relay_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
