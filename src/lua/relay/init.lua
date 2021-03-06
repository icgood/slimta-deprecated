
require "slimta"
require "slimta.bus"
require "slimta.message"

slimta.relay = slimta.relay or {}
slimta.relay.__index = slimta.relay

local relay_session_meta = {}

require "slimta.relay.smtp"

-- {{{ slimta.relay.new()
function slimta.relay.new(bus, default)
    local self = {}
    setmetatable(self, slimta.relay)

    self.relayers = {}
    self.bus = bus
    self.default = default

    return self
end
-- }}}

-- {{{ slimta.relay:add_relayer()
function slimta.relay:add_relayer(name, relayer)
    self.relayers[name] = relayer
end
-- }}}

-- {{{ get_relayer_for_message()
local function get_relayer_for_message(self, message)
    local relayer

    if message.envelope.dest_relayer then
        return self.relayers[message.envelope.dest_relayer]
    end

    -- Use the default, if set.
    if self.default then
        return self.relayers[self.default]
    end

    -- Pick an arbitrary relayer.
    local k, v = next(self.relayers)
    return v
end
-- }}}

-- {{{ build_sessions()
local function build_sessions(self, messages, responses)
    local sessions = {}
    local n = 0

    for i, msg in ipairs(messages) do
        local which = get_relayer_for_message(self, msg)
        local hash, info = which:build_session_info(msg)
        if not sessions[hash] then
            sessions[hash] = which:new_session(info)
            n = n + 1
        end
        sessions[hash]:add_message(msg, responses, i)
    end

    return sessions, n
end
-- }}}

-- {{{ relay_session_meta.__call()
function relay_session_meta.__call(self, synchronous)
    local responses = {}
    local sessions, n = build_sessions(self.relay, self.messages, responses)

    if n > 1 and not synchronous then
        local threads = {}
        for hash, session in pairs(sessions) do
            table.insert(threads, ratchet.thread.attach(session.relay_all, session))
        end
        ratchet.thread.wait_all(threads)
    else
        for hash, session in pairs(sessions) do
            session:relay_all()
        end
    end

    self.transaction:send_response(responses)
end
-- }}}

-- {{{ slimta.relay:accept()
function slimta.relay:accept()
    local transaction, messages = self.bus:recv_request()

    local relay_session = {
        messages = messages,
        transaction = transaction,
        relay = self,
    }
    setmetatable(relay_session, relay_session_meta)

    return relay_session
end
-- }}}

return slimta.relay

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
