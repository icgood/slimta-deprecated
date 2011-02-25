local relay_request_context = require "relay_request_context"

local attempt_timer_context = {}
attempt_timer_context.__index = attempt_timer_context

-- {{{ get_message_data_and_send_relay_request()
local function get_message_data_and_send_relay_request(id)
    local which_engine = confstring(use_storage_engine, msg, data)
    local engine = storage_engines[which_engine].get
    local storage = engine.new()

    local info = storage(id)

    local relay_req = relay_request_context.new(info)
    relay_req(id)
end
-- }}}

-- {{{ attempt_timer_context.new()
function attempt_timer_context.new()
    local self = {}
    setmetatable(self, attempt_timer_context)

    self.interval = confnumber(queue_attempt_poll_interval) or 60

    return self
end
-- }}}

-- {{{ attempt_timer_context:get_deliverables()
function attempt_timer_context:get_deliverables()
    local which_engine = confstring(use_storage_engine, msg, data)
    local engine = storage_engines[which_engine].get
    local storage = engine.new()

    local now = slimta.get_now()
    return storage:get_upcoming(now)
end
-- }}}

-- {{{ attempt_timer_context:send_relay_requests()
function attempt_timer_context:send_relay_requests(ids)
    for i, id in ipairs(ids) do
        kernel:attach(get_message_data_and_send_relay_request, id)
    end
end
-- }}}

-- {{{ attempt_timer_context:__call()
function attempt_timer_context:__call(data)
    local tfd = ratchet.timerfd.new()
    tfd:settime(self.interval, self.interval)

    while true do
        local fires = tfd:read()
        local ids = self:get_deliverables()
        self:send_relay_requests(ids)
    end
end
-- }}}

return attempt_timer_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
