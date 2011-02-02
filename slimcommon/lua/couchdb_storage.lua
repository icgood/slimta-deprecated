require "json"

local http_connection = require "http_connection"

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
    }
    return json.encode(info)
end
-- }}}

-- {{{ couchdb_new:create_message_root()
function couchdb_new:create_message_root()
    local info = self.get_jsoned_info()

    local couchttp = http_connection.new(self.where)
    local code, reason, headers, data = couchttp:query(
        "POST",
        "/"..self.database.."/",
        {["Content-Type"] = "application/json", ["Content-Length"] = #info},
        info
    )
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
    local code, reason, headers, data = couchttp:query(
        "DELETE",
        "/"..self.database.."/"..info.id.."?rev="..info.rev
    )
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
        "/"..self.database.."/"..info.id.."?rev="..info.rev,
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

    ret, reason = self:create_couchttp()
    if not ret then
        return nil, reason
    end
    local info = ret

    ret, reason = self:create_message_body(info)
    if not ret then
        self:delete_couchttp(info)
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

--------------------------------------------------------------------------------

storage_engines["couchdb"] = {
    new = couchdb_new,
    list = couchdb_list,
    get = couchdb_get,
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
