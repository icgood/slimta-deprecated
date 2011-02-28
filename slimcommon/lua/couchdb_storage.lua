require "json"

local http_connection = require "http_connection"

-- {{{ default_next_attempt_timestamp()
local function default_next_attempt_timestamp()
    return slimta.get_now() + 300
end
-- }}}

-- {{{ strip_quotes()
local function strip_quotes(str)
    local first = str:sub(1, 1)
    local last = str:sub(-1)

    if first == '"' and last == '"' then
        return str:sub(2, -2)
    end
end
-- }}}

--------------------------------------------------------------------------------

-- {{{ couchdb_new
local couchdb_new = {}
couchdb_new.__index = couchdb_new

-- {{{ couchdb_new.new()
function couchdb_new.new(data, contents)
    local self = {}
    setmetatable(self, couchdb_new)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    self.data = data
    self.message = contents

    return self
end
-- }}}

-- {{{ couchdb_new:attach_data()
function couchdb_new:attach_data(data)
    self.message = data
end
-- }}}

-- {{{ couchdb_new:create_message_root()
function couchdb_new:create_message_root()
    local root_info = {
        envelope = self.data.envelope,
        attempts = self.data.attempts,
        size = self.data.size,
    }

    local info = json.encode(root_info)
    local code, reason, headers, data

    -- Keep attempting PUT on new UUIDs until don't get a collision.
    repeat
        local id = slimta.uuid.generate()
        local couchttp = http_connection.new(self.where)
        code, reason, headers, data = couchttp:query(
            "PUT",
            "/"..self.database.."/"..id,
            {["Content-Type"] = "application/json", ["Content-Length"] = #info},
            info
        )
    until code ~= 409

    -- Not a collision, but not a success? Return reason.
    if code ~= 201 then
        error(reason)
    end

    local info = json.decode(data)

    return info
end
-- }}}

-- {{{ couchdb_new:delete_message_root()
function couchdb_new:delete_message_root(info)
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("DELETE", "/"..self.database.."/"..info.id.."?rev="..info.rev)
    if code ~= 200 then
        error(reason)
    end

    return true
end
-- }}}

-- {{{ couchdb_new:create_message_body()
function couchdb_new:create_message_body(info)
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query(
        "PUT",
        "/"..self.database.."/"..info.id.."/message?rev="..info.rev,
        {["Content-Type"] = "message/rfc822", ["Content-Length"] = #self.message},
        self.message
    )
    if code ~= 201 then
        error(reason)
    end

    local info = json.decode(data)

    return info
end
-- }}}

-- {{{ couchdb_new:__call()
function couchdb_new:__call()
    local ret, reason

    ret, reason = self:create_message_root()
    if not ret then
        error(reason)
    end
    local info = ret

    ret, reason = self:create_message_body(info)
    if not ret then
        self:delete_message_root(info)
        error(reason)
    end

    return info.id
end
-- }}}

-- }}}

-- {{{ couchdb_get_deliverable
local couchdb_get_deliverable = {}
couchdb_get_deliverable.__index = couchdb_get_deliverable

-- {{{ couchdb_get_deliverable.new()
function couchdb_get_deliverable.new()
    local self = {}
    setmetatable(self, couchdb_get_deliverable)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    return self
end
-- }}}

-- {{{ couchdb_get_deliverable:__call()
function couchdb_get_deliverable:__call(timestamp)
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/_design/attempts/_view/upcoming")
    if code ~= 200 then
        error(reason)
    end
    local success, info = pcall(json.decode, data)
    if not success then
        info = {rows = {}}
    end

    local ret = {}
    for i, row in ipairs(info.rows) do
        if row.key <= timestamp then
            table.insert(ret, row.id)
        else
            break
        end
    end
    return ret
end
-- }}}

-- }}}

-- {{{ couchdb_get_contents
local couchdb_get_contents = {}
couchdb_get_contents.__index = couchdb_get_contents

-- {{{ couchdb_get_contents.new()
function couchdb_get_contents.new()
    local self = {}
    setmetatable(self, couchdb_get_contents)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    return self
end
-- }}}

-- {{{ couchdb_get_contents:__call()
function couchdb_get_contents:__call(data)
    local id = data:gsub("^%s*", ""):gsub("%s*$", "")
    local couchttp, code, reason, headers, data

    couchttp = http_connection.new(self.where)
    code, reason, headers, data = couchttp:query("HEAD", "/"..self.database.."/"..id)
    if code ~= 200 then
        error(reason)
    end
    local rev = strip_quotes(headers["etag"])

    couchttp = http_connection.new(self.where)
    code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..id.."/message?rev="..rev)
    if code ~= 200 then
        error(reason)
    end
    return data
end
-- }}}

-- }}}

-- {{{ couchdb_get_info
local couchdb_get_info = {}
couchdb_get_info.__index = couchdb_get_info

-- {{{ couchdb_get_info.new()
function couchdb_get_info.new()
    local self = {}
    setmetatable(self, couchdb_get_info)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    return self
end
-- }}}

-- {{{ couchdb_get_info:__call()
function couchdb_get_info:__call(data)
    local id = data:gsub("^%s*", ""):gsub("%s*$", "")

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..id)
    if code ~= 200 then
        error(reason)
    end
    local info = json.decode(data)

    return info
end
-- }}}

-- }}}

-- {{{ couchdb_set_next_attempt
local couchdb_set_next_attempt = {}
couchdb_set_next_attempt.__index = couchdb_set_next_attempt

-- {{{ couchdb_set_next_attempt.new()
function couchdb_set_next_attempt.new(data)
    local self = {}
    setmetatable(self, couchdb_set_next_attempt)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    self.id = data:gsub("^%s*", ""):gsub("%s*$", "")

    return self
end
-- }}}

-- {{{ couchdb_set_next_attempt:get_helper()
function couchdb_set_next_attempt:get_helper()
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..self.id)
    if code ~= 200 then
        error(reason)
    end

    return json.decode(data)
end
-- }}}

-- {{{ couchdb_set_next_attempt:put_helper()
function couchdb_set_next_attempt:put_helper(info)
    local data = json.encode(info)

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query(
        "PUT",
        "/"..self.database.."/"..self.id,
        {["Content-Type"] = "application/json", ["Content-Length"] = #data},
        data
    )

    return code, reason
end
-- }}}

-- {{{ couchdb_set_next_attempt:__call()
function couchdb_set_next_attempt:__call()
    local code, reason

    repeat
        local info = self:get_helper()

        info.attempts = info.attempts + 1
        local next_attempt_getter = next_queue_attempt_timestamp or default_next_attempt_timestamp
        info.next_attempt = CONF(next_attempt_getter, info.attempts, info)

        code, reason = self:put_helper(info)
    until code ~= 409

    if code ~= 201 then
        error(reason)
    end
end
-- }}}

-- }}}

-- {{{ couchdb_delete
local couchdb_delete = {}
couchdb_delete.__index = couchdb_delete

-- {{{ couchdb_delete.new()
function couchdb_delete.new(data)
    local self = {}
    setmetatable(self, couchdb_delete)

    self.where = CONF(couchdb_channel)
    self.database = CONF(couchdb_queue)

    self.id = data:gsub("^%s*", ""):gsub("%s*$", "")

    return self
end
-- }}}

-- {{{ couchdb_delete:__call()
function couchdb_delete:__call()
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("HEAD", "/"..self.database.."/"..self.id)
    if code ~= 200 then
        error(reason)
    end
    local rev = strip_quotes(headers["etag"])

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("DELETE", "/"..self.database.."/"..self.id.."?rev="..rev)
    if code ~= 200 then
        error(reason)
    end
end
-- }}}

-- }}}

--------------------------------------------------------------------------------

storage_engines["couchdb"] = {
    new = couchdb_new,
    get_deliverable = couchdb_get_deliverable,
    get_contents = couchdb_get_contents,
    get_info = couchdb_get_info,
    set_next_attempt = couchdb_set_next_attempt,
    delete = couchdb_delete,
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
