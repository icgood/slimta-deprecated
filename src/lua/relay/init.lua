
require "slimta"
require "slimta.bus"
require "slimta.message"

slimta.relay = {}
slimta.relay.__index = slimta.relay

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

-- {{{ relay_messages()
local function relay_messages(self, messages, transaction)
    local threads = {}
    local responses = {}
    local sessions = build_sessions(self, messages, responses)
    for hash, session in pairs(sessions) do
        table.insert(threads, ratchet.thread.attach(session.relay_all, session))
    end
    ratchet.thread.wait_all(threads)
    transaction:send_response(responses)
end
-- }}}

-- {{{ slimta.relay:run()
function slimta.relay:run()
    while not self.done do
        self.paused_thread = ratchet.thread.self()
        local transaction, messages = self.bus:recv_request()
        self.paused_thread = nil

        if transaction then
            ratchet.thread.attach(relay_messages, self, messages, transaction)
        end
    end
end
-- }}}

-- {{{ slimta.relay:halt()
function slimta.relay:halt()
    self.done = true
    if self.paused_thread then
        ratchet.thread.kill(self.paused_thread)
    end
end
-- }}}

return slimta.relay

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
