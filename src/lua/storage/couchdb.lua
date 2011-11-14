
require "slimta.uuid"
require "slimta.json"
require "ratchet.http.client"

module("slimta.storage.couchdb", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(where, database, dns_query_types)
    local self = {}
    setmetatable(self, class)

    self.where = where
    self.database = database
    self.dns_query_types = dns_query_types

    return self
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

-- {{{ new_connection()
function new_connection(self)
    local rec = ratchet.socket.prepare_uri(self.where, self.dns_query_types)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket:connect(rec.addr)

    return ratchet.http.client.new(socket)
end
-- }}}

-- {{{ create_document()
function create_document(self, document, force_id)
    local doc_str = json.encode(document)
    local code, reason, headers, data

    -- Keep attempting PUT on new UUIDs until we don't get a collision.
    repeat
        local id = force_id or slimta.uuid.generate()
        local couchttp = self:new_connection()
        code, reason, headers, data = couchttp:query(
            "PUT",
            "/"..self.database.."/"..id,
            {["Content-Type"] = {"application/json"}, ["Content-Length"] = {#doc_str}},
            doc_str
        )
    until code ~= 409 or force_id

    -- Not a collision, but not a success? Return reason.
    if code ~= 201 then
        error(reason)
    end

    local info = json.decode(data)
    self.id = info.id
    self.rev = info.rev
end
-- }}}

-- {{{ refresh_rev()
function refresh_rev(self, new_id)
    self.id = new_id or self.id

    local couchttp = self:new_connection()
    local code, reason, headers, data = couchttp:query(
        "HEAD",
        "/"..self.database.."/"..self.id
    )

    if code ~= 200 then
        error(reason)
    end
    self.rev = strip_quotes(headers["etag"][1])
end
-- }}}

-- {{{ load_document()
function load_document(self, new_id)
    self.id = new_id or self.id

    local couchttp = self:new_connection()
    local code, reason, headers, data = couchttp:query(
        "GET",
        "/"..self.database.."/"..self.id
    )

    if code ~= 200 then
        error(reason)
    end
    local info = json.decode(data)

    self.rev = info._rev

    return info
end
-- }}}

-- {{{ update_document()
function update_document(self, update_func, new_id, ...)
    local document = self:load_document(new_id)
    update_func(document, ...)
    self:create_document(document, self.id)
end
-- }}}

-- {{{ create_attachment()
function create_attachment(self, name, ctype, contents, new_id)
    self:refresh_rev(new_id)

    local couchttp = self:new_connection()
    local code, reason, headers, data = couchttp:query(
        "PUT",
        "/"..self.database.."/"..self.id.."/"..name.."?rev="..self.rev,
        {
            ["Content-Type"] = {ctype},
            ["Content-Length"] = {#contents},
        },
        contents
    )

    if code ~= 201 then
        error(reason)
    end
end
-- }}}

-- {{{ load_attachment()
function load_attachment(self, name, new_id)
    self:refresh_rev(new_id)

    local couchttp = self:new_connection()
    local code, reason, headers, data = couchttp:query(
        "GET",
        "/"..self.database.."/"..self.id.."/"..name.."?rev="..self.rev
    )

    if code ~= 200 then
        error(reason)
    end

    return data, headers["content-type"][1]
end
-- }}}

-- {{{ delete_document()
function delete_document(self, new_id)
    self:refresh_rev(new_id)

    local couchttp = self:new_connection()
    local code, reason, headers, data = couchttp:query(
        "DELETE",
        "/"..self.database.."/"..self.id.."?rev="..self.rev
    )

    if code ~= 200 then
        error(reason)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
