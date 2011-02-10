require "json"

local http_connection = require "http_connection"
local uuids

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
            return nil, reason
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
function couchdb_new.new()
    local self = {}
    setmetatable(self, couchdb_new)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    self.mailfrom = ""
    self.rcpttos = {}
    self.message = ""

    return self
end
-- }}}

-- {{{ couchdb_new:set_mailfrom()
function couchdb_new:set_mailfrom(new_mf)
    self.mailfrom = new_mf
end
-- }}}

-- {{{ couchdb_new:add_rcptto()
function couchdb_new:add_rcptto(new_to)
    table.insert(self.rcpttos, new_to)
end
-- }}}

-- {{{ couchdb_new:set_rcpttos()
function couchdb_new:set_rcpttos(new_tos)
    self.rcpttos = new_tos
end
-- }}}

-- {{{ couchdb_new:add_data()
function couchdb_new:add_data(data)
    if self.message == "" then
        self.message = data
    else
        self.message = self.message .. data
    end
end
-- }}}

-- {{{ couchdb_new:get_jsoned_info()
function couchdb_new:get_jsoned_info()
    local info = {
        mailfrom = self.mailfrom,
        rcpttos = self.rcpttos,
        attempts = 0,
    }
    return json.encode(info)
end
-- }}}

-- {{{ couchdb_new:create_message_root()
function couchdb_new:create_message_root()
    local info = self:get_jsoned_info()
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
        return nil, reason
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
        return nil, reason
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
        return nil, reason
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
        return nil, reason
    end
    local info = ret

    ret, reason = self:create_message_body(info)
    if not ret then
        self:delete_message_root(info)
        return nil, reason
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
        return nil, reason
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
function couchdb_get.new(data)
    local self = {}
    setmetatable(self, couchdb_get)

    self.where = get_conf.string(couchdb_channel)
    self.database = get_conf.string(couchdb_queue)

    self.id = data:gsub("^%s*", ""):gsub("%s*$", "")

    return self
end
-- }}}

-- {{{ couchdb_get:__call()
function couchdb_get:__call()
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..self.id)
    if code ~= 200 then
        return nil, reason
    end
    local info = json.decode(data)

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("GET", "/"..self.database.."/"..self.id.."/message?rev="..info._rev)
    if code ~= 200 then
        return nil, reason
    end
    local message = data

    local ret = {
        mailfrom = info.mailfrom,
        rcpttos = info.rcpttos,
        message = message,
    }

    return ret
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

-- {{{ couchdb_update:__call()
function couchdb_update:__call(attempts, next_attempt)
    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("HEAD", "/"..self.database.."/"..self.id)
    if code ~= 200 then
        return nil, reason
    end
    local rev = strip_quotes(headers["etag"])

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("DELETE", "/"..self.database.."/"..self.id.."?rev="..rev)
    if code ~= 200 then
        return nil, reason
    end

    return ret
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
        return nil, reason
    end
    local rev = strip_quotes(headers["etag"])

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query("DELETE", "/"..self.database.."/"..self.id.."?rev="..rev)
    if code ~= 200 then
        return nil, reason
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
