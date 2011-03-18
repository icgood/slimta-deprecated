
local relay_request_context = {}
relay_request_context.__index = relay_request_context

-- {{{ relay_request_context.new()
function relay_request_context.new(uri, message)
    local self = {}
    setmetatable(self, relay_request_context)

    self.uri = uri
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
    local which = config.queue.which_nexthop()
    local engine = modules.engines.nexthop[which]

    local ret = engine(message)
    if not ret or not ret.host or not ret.port or not ret.protocol then
        error("Invalid nexthop for message.")
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
  <protocol>$(protocol)</protocol>
  <destination>$(destination)</destination>
  <port>$(port)</port>
  <security></security>
$(messages) </nexthop>
]]

    local msg_tmpl = [[  <message>
   <envelope>
    <sender>$(sender)</sender>
$(recipients)   </envelope>
   <storage engine="$(engine)" size="$(size)">$(data)</storage>
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

            msgs = msgs .. slimta.interp(msg_tmpl, {
                sender = msg.envelope.sender,
                recipients = rcpts,
                size = msg.size,
                engine = msg.storage.engine,
                data = msg.storage.data,
            })
        end
        
        nexthops = nexthops .. slimta.interp(nexthop_tmpl, {
            protocol = hop.protocol,
            destination = hop.host,
            port = hop.port,
            messages = msgs,
        })
    end

    return root_tmpl:format(nexthops)
end
-- }}}

-- {{{ relay_request_context:__call()
function relay_request_context:__call()
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local msg = self:build_message()

    print('RP: [' .. msg .. ']')
    socket:send(msg)
end
-- }}}

return relay_request_context 

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
