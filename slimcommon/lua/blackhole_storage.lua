
--------------------------------------------------------------------------------

-- {{{ blackhole_new
local blackhole_new = {}
blackhole_new.__index = blackhole_new

-- {{{ blackhole_new.new()
function blackhole_new.new(data, message)
    local self = {}
    setmetatable(self, blackhole_new)

    self.data = data
    self.message = message

    return self
end
-- }}}

-- {{{ blackhole_new:__call()
function blackhole_new:__call()
    local id = slimta.uuid.generate()
    print('Blackholing message:')
    slimta.stackdump(self.data, self.message, id)
    print('---------------------------------------')
    print('')

    -- Second return value tells slimqueue not to attempt immediate relay.
    return id, true
end
-- }}}

-- }}}

-- {{{ blackhole_get_deliverable
local blackhole_get_deliverable = {}
blackhole_get_deliverable.__index = blackhole_get_deliverable

-- {{{ blackhole_get_deliverable.new()
function blackhole_get_deliverable.new()
    local self = {}
    setmetatable(self, blackhole_get_deliverable)

    return self
end
-- }}}

-- {{{ blackhole_get_deliverable:__call()
function blackhole_get_deliverable:__call(timestamp)
    return {}
end
-- }}}

-- }}}

-- {{{ blackhole_get_contents
local blackhole_get_contents = {}
blackhole_get_contents.__index = blackhole_get_contents

-- {{{ blackhole_get_contents.new()
function blackhole_get_contents.new()
    local self = {}
    setmetatable(self, blackhole_get_contents)

    return self
end
-- }}}

-- {{{ blackhole_get_contents:__call()
function blackhole_get_contents:__call(data)
end
-- }}}

-- }}}

-- {{{ blackhole_get_info
local blackhole_get_info = {}
blackhole_get_info.__index = blackhole_get_info

-- {{{ blackhole_get_info.new()
function blackhole_get_info.new()
    local self = {}
    setmetatable(self, blackhole_get_info)

    return self
end
-- }}}

-- {{{ blackhole_get_info:__call()
function blackhole_get_info:__call(data)
end
-- }}}

-- }}}

-- {{{ blackhole_set_next_attempt
local blackhole_set_next_attempt = {}
blackhole_set_next_attempt.__index = blackhole_set_next_attempt

-- {{{ blackhole_set_next_attempt.new()
function blackhole_set_next_attempt.new()
    local self = {}
    setmetatable(self, blackhole_set_next_attempt)

    return self
end
-- }}}

-- {{{ blackhole_set_next_attempt:__call()
function blackhole_set_next_attempt:__call()
end
-- }}}

-- }}}

-- {{{ blackhole_delete
local blackhole_delete = {}
blackhole_delete.__index = blackhole_delete

-- {{{ blackhole_delete.new()
function blackhole_delete.new()
    local self = {}
    setmetatable(self, blackhole_delete)

    return self
end
-- }}}

-- {{{ blackhole_delete:__call()
function blackhole_delete:__call()
end
-- }}}

-- }}}

--------------------------------------------------------------------------------

storage_engines["blackhole"] = {
    new = blackhole_new,
    get_deliverable = blackhole_get_deliverable,
    get_contents = blackhole_get_contents,
    get_info = blackhole_get_info,
    set_next_attempt = blackhole_set_next_attempt,
    delete = blackhole_delete,
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
