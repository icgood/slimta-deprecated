
require "ratchet"

require "slimta.message"

local EX_TEMPFAIL = 75

local maildrop_session = {}
maildrop_session.__index = maildrop_session

-- {{{ maildrop_session.new()
function maildrop_session.new(argv, time_limit)
    local self = {}
    setmetatable(self, maildrop_session)

    self.argv0 = argv0 or "maildrop"
    self.messages = {}
    self.time_limit = time_limit

    return self
end
-- }}}

-- {{{ maildrop_session:add_message()
function maildrop_session:add_message(message, responses, key)
    responses[key] = slimta.message.response.new()
    self.messages[message] = responses[key]
end
-- }}}

-- {{{ start_maildrop()
local function start_maildrop(self, message, response, processes)
    local argv = {self.argv0, "-f", message.envelope.sender}
    local p = ratchet.exec.new(argv)
    p:start()
    local remaining = tostring(message.contents)
    repeat
        remaining = p:stdin():write(remaining)
    until not remaining
    p:stdin():close()
    processes[p] = response
end
-- }}}

-- {{{ set_response()
local function set_response(response, status, err)
    if status == 0 then
        response.code = "250"
        response.message = "Message delivered successfully."
    elseif status == EX_TEMPFAIL then
        err = err:gsub("^maildrop%: ", ""):gsub("%\r?%\n", "")
        response.code = "450"
        response.message = err
    else
        err = err:gsub("^maildrop%: ", ""):gsub("%\r?%\n", "")
        response.code = "550"
        response.message = err
    end
end
-- }}}

-- {{{ get_time_remaining()
local function get_time_remaining(p, time_limit)
    if time_limit then
        local start_time = p:get_start_time()
        local running = os.time() - start_time
        local remaining = time_limit - running
        if remaining > 0.0 then
            return remaining
        else
            return 0.0
        end
    end
end
-- }}}

-- {{{ wait_for_all()
local function wait_for_all(self, processes)
    for p, response in pairs(processes) do
        local err = p:stderr():read()
        local limit = get_time_remaining(p, self.time_limit)
        local status = p:wait(limit)
        set_response(response, status, err)
    end
end
-- }}}

-- {{{ maildrop_session:relay_all()
function maildrop_session:relay_all()
    local processes = {}
    for message, response in pairs(self.messages) do
        start_maildrop(self, message, response, processes)
    end
    wait_for_all(self, processes)
end
-- }}}

return maildrop_session

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
