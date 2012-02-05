
require "slimta"

slimta.policies = slimta.policies or {}
slimta.policies.add_date_header = {}
slimta.policies.add_date_header.__index = slimta.policies.add_date_header

-- {{{ default_build_date()
local function default_build_date(timestamp)
    return os.date("%a, %d %b %Y %T %z", timestamp)
end
-- }}}

-- {{{ slimta.policies.add_date_header.new()
function slimta.policies.add_date_header.new(build_date)
    local self = {}
    setmetatable(self, slimta.policies.add_date_header)

    self.build_date = build_date or default_build_date

    return self
end
-- }}}

-- {{{ slimta.policies.add_date_header:add()
function slimta.policies.add_date_header:add(message)
    if not message.contents.headers.date[1] then
        local date = self.build_date(message.timestamp)
        message.contents:add_header("Date", date)
    end
end
-- }}}

-- {{{ slimta.policies.add_date_header:__call()
function slimta.policies.add_date_header:__call(from_bus, to_bus)
    while true do
        local from_transaction, messages = from_bus:recv_request()
        for i, msg in ipairs(messages) do
            self:add(msg)
        end
        local to_transaction = to_bus:send_request(messages)
        local responses = to_transaction:recv_response()
        from_transaction:send_response(responses)
    end
end
-- }}}

return slimta.policies.add_date_header

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
