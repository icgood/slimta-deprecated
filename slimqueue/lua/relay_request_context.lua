
local relay_request_context = {}
relay_request_context.__index = relay_request_context

-- {{{ relay_request_context.new()
function relay_request_context.new(message)
    local self = {}
    setmetatable(self, relay_request_context)

    self.endpoint = CONF(relay_request_channel)
    self.message = message

    return self
end
-- }}}

-- {{{ relay_request_context:get_nexthop()
function relay_request_context:get_nexthop()
    local ret = {}

    ret.host, ret.port, ret.protocol = CONF(message_nexthop, self.message)
    if not ret.port then
        ret.port = 25
    end
    if not ret.protocol then
        ret.protocol = "SMTP"
    end

    return ret
end
-- }}}

-- {{{ relay_request_context:build_message()
function relay_request_context:build_message(data, nexthop)
    local msg_tmpl = [[<slimta><deliver>
 <nexthop>
  <protocol>%s</protocol>
  <destination>%s</destination>
  <port>%s</port>
  <security></security>
  <message queueid="%s">
   <envelope>
    <sender>%s</sender>
%s   </envelope>
   <storage engine="%s" size="%d">%s</storage>
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
    local engine = self.message.storage.engine

    local msg = msg_tmpl:format(
        nexthop.protocol,
        nexthop.host,
        nexthop.port,
        data,
        sender,
        rcpts,
        engine,
        size,
        data
    )

    return msg
end
-- }}}

-- {{{ relay_request_context:__call()
function relay_request_context:__call(data)
    local rec = ratchet.zmqsocket.prepare_uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local nexthop = self:get_nexthop()
    local msg = self:build_message(data, nexthop)

    print('RP: [' .. msg .. ']')
    socket:send(msg)
end
-- }}}

return relay_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
