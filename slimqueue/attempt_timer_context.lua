
local relay_request_context = require "slimqueue.relay_request_context"

attempt_timer_context = {}
attempt_timer_context.__index = attempt_timer_context

-- {{{ attempt_timer_context.new()
function attempt_timer_context.new(interval, relay_req_uri)
    local self = {}
    setmetatable(self, attempt_timer_context)

    self.interval = interval
    self.relay_req_uri = relay_req_uri

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ attempt_timer_context:get_deliverable()
function attempt_timer_context:get_deliverable(which_engine)
    local engine = modules.engines.storage[which_engine].get_deliverable
    local storage = engine.new()

    local now = slimta.get_now()
    local ret = storage(now)
    if ret[1] then
        return ret
    end
end
-- }}}

-- {{{ attempt_timer_context:get_and_request_message()
function attempt_timer_context:get_and_request_message(storage, id, which_engine, relay_req)
    local info = storage(id)
    info.storage = {
        engine = which_engine,
        data = id,
    }
    relay_req:add_message(info)
end
-- }}}

-- {{{ attempt_timer_context:send_relay_requests()
function attempt_timer_context:send_relay_requests(which_engine, ids)
    local engine = modules.engines.storage[which_engine].get_info
    local storage = engine.new()

    local relay_req = relay_request_context.new(self.relay_req_uri)

    local children = {}
    for i, id in ipairs(ids) do
        local thread = kernel:attach(self.get_and_request_message, self, storage, id, which_engine, relay_req)
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
        for engine, v in pairs(modules.engines.storage) do
            local ids = self:get_deliverable(engine)
            if ids then
                self:send_relay_requests(engine, ids)
            end
        end

        local fires = tfd:read()
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
