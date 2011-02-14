require "json"

local http_connection = require "http_connection"
local uuids

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

-- {{{ couchdb_uuids
local couchdb_uuids = {}
couchdb_uuids.__index = couchdb_uuids

-- {{{ couchdb_uuids.new()
function couchdb_uuids.new()
    local self = {}
    setmetatable(self, couchdb_uuids)

    self.count = get_conf.number(couchdb_uuids_at_a_time) or 100
    self.where = get_conf.string(couchdb_channel)
    self.uuids = {}

    return self
end
-- }}}

-- {{{ couchdb_uuids:get_uuid()
function couchdb_uuids:get_uuid()
    local uuid = table.remove(self.uuids)
    if not uuid then
        -- Wait for the thread that gets new UUIDs from CouchDB.
        assert(self.thread, "CouchDB UUID retrieval thread was not started.")
        kernel:unpause(self.thread, kernel:running_thread())
        kernel:pause()

        return self:get_uuid()
    else
        return uuid
    end
end
-- }}}

-- {{{ couchdb_uuids:__call()
function couchdb_uuids:__call()
    self.thread = kernel:running_thread()

    while true do
        local to_unpause = kernel:pause()

        local couchttp = http_connection.new(self.where)
        local code, reason, headers, data = couchttp:query("GET", "/_uuids?count="..self.count)
        if code ~= 200 then
            error(reason)
        end

        local ret = json.decode(data)
        assert(ret and ret.uuids, "CouchDB did not return UUIDs properly.")
        self.uuids = ret.uuids

        if to_unpause then
            kernel:unpause(to_unpause)
        end
    end
end
-- }}}

-- }}}

--------------------------------------------------------------------------------

-- {{{ couchdb_new
local couchdb_new = {}
couchdb_new.__index = couchdb_new

-- {{{ couchdb_new.new()
function couchdb_new.new(data)
    local self = {}
    setmetatable(self, couchdb_new)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    self.data = data

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
    local info = json.encode(self.data)
    local code, reason, headers, data

    -- Keep attempting PUT on new UUIDs until don't get a collision.
    repeat
        local id = uuids:get_uuid()
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

-- {{{ couchdb_list
local couchdb_list = {}
couchdb_list.__index = couchdb_list

-- {{{ couchdb_list.new()
function couchdb_list.new()
    local self = {}
    setmetatable(self, couchdb_list)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    return self
end
-- }}}

-- {{{ couchdb_list:__call()
function couchdb_list:__call()
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/_all_docs")
    if code ~= 200 then
        error(reason)
    end

    local ret = json.decode(data)

    local list = {}
    for i, row in ipairs(ret.rows) do
        table.insert(list, row.id)
    end

    return list
end
-- }}}

-- }}}

-- {{{ couchdb_get
local couchdb_get = {}
couchdb_get.__index = couchdb_get

-- {{{ couchdb_get.new()
function couchdb_get.new()
    local self = {}
    setmetatable(self, couchdb_get)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    return self
end
-- }}}

-- {{{ couchdb_get:get_upcoming()
function couchdb_get:get_upcoming(timestamp)
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

-- {{{ couchdb_get:get_contents()
function couchdb_get:get_contents(data)
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

-- {{{ couchdb_get:__call()
function couchdb_get:__call(data)
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

-- {{{ couchdb_update
local couchdb_update = {}
couchdb_update.__index = couchdb_update

-- {{{ couchdb_update.new()
function couchdb_update.new(data)
    local self = {}
    setmetatable(self, couchdb_update)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    self.id = data:gsub("^%s*", ""):gsub("%s*$", "")

    return self
end
-- }}}

-- {{{ couchdb_update:get_helper()
function couchdb_update:get_helper()
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..self.id)
    if code ~= 200 then
        error(reason)
    end

    return json.decode(data)
end
-- }}}

-- {{{ couchdb_update:put_helper()
function couchdb_update:put_helper(info)
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

-- {{{ couchdb_update:set_next_attempt()
function couchdb_update:set_next_attempt()
    local code, reason

    repeat
        local info = self:get_helper()

        info.attempts = info.attempts + 1
        local next_attempt_getter = next_queue_attempt_timestamp or default_next_attempt_timestamp
        info.next_attempt = get_conf.number(next_attempt_getter, info.attempts, info)

        code, reason = self:put_helper(info)
    until code ~= 409

    if code ~= 201 then
        error(reason)
    end
end
-- }}}

-- {{{ couchdb_update:__call()
function couchdb_update:__call(new_values)
    local code, reason

    repeat
        local info = self:get_helper()

        for key, val in pairs(new_values) do
            info[key] = val
        end

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

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

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

    return ret
end
-- }}}

-- }}}

--------------------------------------------------------------------------------

uuids = couchdb_uuids.new()
kernel:attach(uuids)

storage_engines["couchdb"] = {
    new = couchdb_new,
    list = couchdb_list,
    get = couchdb_get,
    update = couchdb_update,
    delete = couchdb_delete,
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
