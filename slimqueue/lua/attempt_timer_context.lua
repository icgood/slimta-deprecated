local relay_request_context = require "relay_request_context"

local attempt_timer_context = {}
attempt_timer_context.__index = attempt_timer_context

-- {{{ attempt_timer_context.new()
function attempt_timer_context.new()
    local self = {}
    setmetatable(self, attempt_timer_context)

    self.interval = CONF(queue_attempt_poll_interval) or 60

    return self
end
-- }}}

-- {{{ attempt_timer_context:get_deliverable()
function attempt_timer_context:get_deliverable(which_engine)
    local engine = storage_engines[which_engine].get_deliverable
    local storage = engine.new()

    local now = slimta.get_now()
    return storage(now)
end
-- }}}

-- {{{ attempt_timer_context:get_message_data_and_send_relay_request()
function attempt_timer_context:get_message_data_and_send_relay_request(which_engine, id)
    local engine = storage_engines[which_engine].get_info
    local storage = engine.new()

    local info = storage(id)
    info.storage = {engine = which_engine}

    local relay_req = relay_request_context.new(info)
    relay_req(id)
end
-- }}}

-- {{{ attempt_timer_context:send_relay_requests()
function attempt_timer_context:send_relay_requests(which_engine, ids)
    for i, id in ipairs(ids) do
        kernel:attach(self.get_message_data_and_send_relay_request, self, which_engine, id)
    end
end
-- }}}

-- {{{ attempt_timer_context:__call()
function attempt_timer_context:__call(data)
    local tfd = ratchet.timerfd.new()
    tfd:settime(self.interval, self.interval)

    while true do
        local fires = tfd:read()
        for engine, v in pairs(storage_engines) do
            local ids = self:get_deliverable(engine)
            self:send_relay_requests(engine, ids)
        end
    end
end
-- }}}

return attempt_timer_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
