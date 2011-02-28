
local relay_request_context = {}
relay_request_context.__index = relay_request_context

-- {{{ relay_request_context.new()
function relay_request_context.new(message)
    local self = {}
    setmetatable(self, relay_request_context)

    self.endpoint = CONF(relay_request_channel)
    self.nexthops = {}

    return self
end
-- }}}

-- {{{ relay_request_context:add_message()
function relay_request_context:add_message(message)
    local nexthop_info = self:get_nexthop(message)

    for i, hop in ipairs(self.nexthops) do
        local equal = true
        for j, v in pairs(nexthop_info) do
            if hop[j] ~= v then
                equal = false
            end
        end

        -- We found a nexthop that matches all criteria.
        if equal then
            table.insert(hop.messages, message)
            return
        end
    end

    -- We need to make a new nexthop for this message.
    local new_hop = nexthop_info
    new_hop.messages = {message}
    table.insert(self.nexthops, new_hop)
end
-- }}}

-- {{{ relay_request_context:get_nexthop()
function relay_request_context:get_nexthop(message)
    local ret = CONF(message_nexthop, message)
    if not ret.host then
        error("Could not calculate nexthop for message.")
    end
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
function relay_request_context:build_message()
    local root_tmpl = [[<slimta><deliver>
%s</deliver></slimta>
]]

    local nexthop_tmpl = [[ <nexthop>
  <protocol>%s</protocol>
  <destination>%s</destination>
  <port>%s</port>
  <security></security>
%s </nexthop>
]]

    local msg_tmpl = [[  <message>
   <envelope>
    <sender>%s</sender>
%s   </envelope>
   <storage engine="%s" size="%d">%s</storage>
  </message>
]]

    local rcpt_tmpl = [[    <recipient>%s</recipient>
]]

    local nexthops = ""
    for i, hop in ipairs(self.nexthops) do
        local msgs = ""

        for j, msg in ipairs(hop.messages) do
            local rcpts = ""
            for k, rcpt in ipairs(msg.envelope.recipients) do
                rcpts = rcpts .. rcpt_tmpl:format(rcpt)
            end

            msgs = msgs .. msg_tmpl:format(
                msg.envelope.sender,
                rcpts,
                msg.storage.engine,
                msg.size,
                msg.storage.data
            )
        end
        
        nexthops = nexthops .. nexthop_tmpl:format(
            hop.protocol,
            hop.host,
            hop.port,
            msgs
        )
    end

    return root_tmpl:format(nexthops)
end
-- }}}

-- {{{ relay_request_context:__call()
function relay_request_context:__call()
    local rec = ratchet.zmqsocket.prepare_uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local msg = self:build_message()

    print('RP: [' .. msg .. ']')
    socket:send(msg)
end
-- }}}

return relay_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
