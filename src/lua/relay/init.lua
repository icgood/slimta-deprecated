
require "slimta"
require "slimta.bus"
require "slimta.message"

slimta.relay = {}
slimta.relay.__index = slimta.relay

local relay_session_meta = {}

require "slimta.relay.smtp"

-- {{{ slimta.relay.new()
function slimta.relay.new(bus)
    local self = {}
    setmetatable(self, slimta.relay)

    self.relayers = {}
    self.bus = bus

    return self
end
-- }}}

-- {{{ slimta.relay:add_relayer()
function slimta.relay:add_relayer(name, relayer)
    relayer:set_manager(self)
    self.relayers[name] = relayer
end
-- }}}

-- {{{ get_relayer_for_message()
local function get_relayer_for_message(self, message)
    local relayer

    if message.envelope.dest_relayer then
        relayer = self.relayers[message.envelope.dest_relayer]
    end

    if not relayer then
        -- Pick an arbitrary relayer.
        for k, v in pairs(self.relayers) do
            return v
        end
    else
        return relayer
    end
end
-- }}}

-- {{{ relayer_hash()
local function relayer_hash(relayer, host, port)
    return (relayer or 'default')..':['..host..']:'..(port or 'default')
end
-- }}}

-- {{{ build_sessions()
local function build_sessions(self, messages, responses)
    local sessions = {}

    for i, msg in ipairs(messages) do
        local which = get_relayer_for_message(self, msg)
        local hash = relayer_hash(msg.envelope.dest_relayer, msg.envelope.dest_host, msg.envelope.dest_port)
        if not sessions[hash] then
            sessions[hash] = which:new_session(msg.envelope.dest_host, msg.envelope.dest_port)
        end
        sessions[hash]:add_message(msg, responses, i)
    end

    return sessions
end
-- }}}

-- {{{ relay_session_meta.__call()
function relay_session_meta.__call(self)
    local threads = {}
    local responses = {}
    local sessions = build_sessions(self.relay, self.messages, responses)
    for hash, session in pairs(sessions) do
        table.insert(threads, ratchet.thread.attach(session.relay_all, session))
    end
    ratchet.thread.wait_all(threads)
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
