
require "slimta.relay.smtp"

require "slimta.bus"
require "slimta.message"

module("slimta.relay", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(bus)
    local self = {}
    setmetatable(self, class)

    self.relayers = {}
    self.bus = bus

    return self
end
-- }}}

-- {{{ add_relayer()
function add_relayer(self, name, relayer)
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
local function build_sessions(self, kernel, messages, responses)
    local sessions = {}

    for i, msg in ipairs(messages) do
        local which = get_relayer_for_message(self, msg)
        local hash = relayer_hash(msg.envelope.dest_relayer, msg.envelope.dest_host, msg.envelope.dest_port)
        if not sessions[hash] then
            sessions[hash] = which:new_session(kernel, msg.envelope.dest_host, msg.envelope.dest_port)
        end
        sessions[hash]:add_message(msg, responses, i)
    end

    return sessions
end
-- }}}

-- {{{ relay_messages()
local function relay_messages(self, kernel, messages, transaction)
    local threads = {}
    local responses = {}
    local sessions = build_sessions(self, kernel, messages, responses)
    for hash, session in pairs(sessions) do
        table.insert(threads, kernel:attach(session.relay_all, session))
    end
    kernel:wait_all(threads)
    transaction:send_response(responses)
end
-- }}}

-- {{{ run()
function run(self, kernel)
    while not self.done do
        self.paused_thread = ratchet.running_thread()
        local transaction, messages = self.bus:recv_request()
        self.paused_thread = nil

        if transaction then
            kernel:attach(relay_messages, self, kernel, messages, transaction)
        end
    end
end
-- }}}

-- {{{ halt()
function halt(self)
    self.done = true
    if self.paused_thread then
        ratchet.unpause(self.paused_thread)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
