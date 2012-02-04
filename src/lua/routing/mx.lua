
require "ratchet"

require "slimta"

slimta.routing = slimta.routing or {}
slimta.routing.mx = {}
slimta.routing.mx.__index = slimta.routing.mx

-- {{{ default_pick_mx()
local function default_pick_mx(message)
    return message.attempts + 1
end
-- }}}

-- {{{ default_pick_relayer()
local function default_pick_relayer()
    return "SMTP"
end
-- }}}

-- {{{ default_pick_port()
local function default_pick_port()
    return 25
end
-- }}}

-- {{{ slimta.routing.mx.new()
function slimta.routing.mx.new(pick_mx, pick_relayer, pick_port)
    local self = {}
    setmetatable(self, slimta.routing.mx)

    self.pick_mx = pick_mx or default_pick_mx
    self.pick_relayer = pick_relayer or default_pick_relayer
    self.pick_port = pick_port or default_pick_port

    self.force_mx = {}

    return self
end
-- }}}

-- {{{ slimta.routing.mx:set_mx()
function slimta.routing.mx:set_mx(domain, rec)
    self.force_mx[domain] = rec
end
-- }}}

-- {{{ set_routing_from_domain()
local function set_routing_from_domain(self, message, domain)
    local dest

    if self.force_mx[domain] then
        local i = self.pick_mx(message)
        dest = self.force_mx[domain][i]
    else
        local i = self.pick_mx(message)
        local rec = ratchet.dns.query(domain, "mx")
        if rec then
            dest = rec:get_i(i)
        end
    end

    if not dest then
        dest = domain
    end

    message.envelope.dest_relayer = self.pick_relayer(message, domain)
    message.envelope.dest_host = dest
    message.envelope.dest_port = self.pick_port(message, domain)
end
-- }}}

-- {{{ slimta.routing.mx:route()
function slimta.routing.mx:route(message)
    local messages_by_domain = {}
    local no_domain_rcpts = {}

    for i, rcpt in ipairs(message.envelope.recipients) do
        local domain = rcpt:match("%@([^%@]+)$")
        if not domain then
            table.insert(no_domain_rcpts, rcpt)
        else
            local domain_message = messages_by_domain[domain:lower()]
            if domain_message then
                table.insert(domain_message.envelope.recipients, rcpt)
            else
                local new = slimta.message.copy(message)
                new.envelope.recipients = {rcpt}
                messages_by_domain[domain:lower()] = new
            end
        end
    end

    local unroutable = nil
    if no_domain_rcpts[1] then
        message.envelope.recipients = no_domain_rcpts
        unroutable = message
    end

    local new_messages = {}
    for domain, message in pairs(messages_by_domain) do
        set_routing_from_domain(self, message, domain)
        table.insert(new_messages, message)
    end

    return new_messages, unroutable
end
-- }}}

-- {{{ slimta.routing.mx:__call()
function slimta.routing.mx:__call(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        local responses = {}
        for i, msg in ipairs(messages) do
            local new_messages = self:route(msg)
            local to_transaction = to_bus:send_request(new_messages)
            local all_responses = to_transaction:recv_response()
            responses[i] = all_responses[#all_responses]
        end
        from_transaction:send_response(responses)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
