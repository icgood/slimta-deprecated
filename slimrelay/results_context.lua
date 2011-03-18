
local session_results = require "slimrelay.session_results"

results_context = {}
results_context.__index = results_context

-- {{{ results_context.new()
function results_context.new(uri)
    local self = {}
    setmetatable(self, results_context)

    self.uri = uri

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ results_context:new_session()
function results_context:new_session(messages, protocol)
    return session_results.new(messages, self, protocol)
end
-- }}}

-- {{{ results_context:send()
function results_context:send(what)
    kernel:unpause(self.thread, what)
end
-- }}}

-- {{{ results_context:__call()
function results_context:__call()
    -- Save the current thread for unpausing by a method called
    -- from another thread.
    self.thread = kernel:running_thread()

    -- Set up the ZMQ connector.
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    -- Wait for messages to send.
    while true do
        local result = kernel:pause()
        socket:send(result)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
