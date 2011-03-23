
local relay_request_context = require "slimqueue.relay_request_context"

attempt_timer_context = {}
attempt_timer_context.__index = attempt_timer_context

-- {{{ attempt_timer_context.new()
function attempt_timer_context.new(interval, relay_req_uri, which_storage)
    local self = {}
    setmetatable(self, attempt_timer_context)

    self.interval = interval
    self.relay_req_uri = relay_req_uri
    self.which_storage = which_storage

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ attempt_timer_context:get_deliverable()
function attempt_timer_context:get_deliverable()
    local engine = modules.engines.storage[self.which_storage]
    local storage = engine.get_deliverable.new()

    local now = slimta.get_now()
    local ret = storage(now)
    if ret[1] then
        return ret
    end
end
-- }}}

-- {{{ attempt_timer_context:get_and_request_message()
function attempt_timer_context:get_and_request_message(storage, id, relay_req)
    local info = storage(id)
    info.storage = {
        engine = self.which_storage,
        data = id,
    }
    relay_req:add_message(info)
end
-- }}}

-- {{{ attempt_timer_context:send_relay_requests()
function attempt_timer_context:send_relay_requests(ids)
    local engine = modules.engines.storage[self.which_storage].get_info
    local storage = engine.new()

    local relay_req = relay_request_context.new(self.relay_req_uri)

    local children = {}
    for i, id in ipairs(ids) do
        local thread = kernel:attach(self.get_and_request_message, self, storage, id, relay_req)
        table.insert(children, thread)
    end
    kernel:wait_all(children)

    relay_req()
end
-- }}}

-- {{{ attempt_timer_context:__call()
function attempt_timer_context:__call(data)
    local tfd = ratchet.timerfd.new()
    tfd:settime(self.interval, self.interval)

    while true do
        local ids = self:get_deliverable()
        if ids then
            self:send_relay_requests(ids)
        end

        local fires = tfd:read()
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
