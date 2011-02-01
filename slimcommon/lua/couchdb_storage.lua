require "json"

-- {{{ couchdb_new

local couchdb_new = ratchet.new_context()

-- {{{ couchdb_new:on_init()
function couchdb_new:on_init(message)
    self.msg = message
    self.received = ''

    self:send_command(message)
end
-- }}}

-- {{{ couchdb_new:on_recv()
function couchdb_new:on_recv()
    local data = self:recv()
    if #data > 0 then
        self.received = self.received .. data
    else
        self:parse_response(self.received, self.msg)
    end
end
-- }}}

-- {{{ couchdb_new:send_command()
function couchdb_new:send_command(message)
    local command = "POST /%s/ HTTP/1.0\r\nContent-Length: %d\r\nContent-Type: application/json\r\n\r\n%s\r\n"
    local data = json.encode(message)
    local send = command:format(couchdb_info.database, #data, data)
    self:send(send)
end
-- }}}

-- {{{ couchdb_new:parse_response()
function couchdb_new:parse_response(data, message)
    local first_line, headers, content = data:match("^(.-)\r?\n(.-)\r?\n\r?\n(.*)$")
    if not first_line then
        -- fail gracefully with no error info.
    end
    local code, text = first_line:match("^HTTP/[%d%.]+%s+(%d+)%s+(.*)$")
    if tonumber(code) ~= 201 then
        -- fail gracefully with a code/text.
    end

    local info = json.decode(content)
    if not info or not info.ok or not info.id then
        -- fail gracefully, no id given, shouldn't happen.
    end

    -- succeed, provide info.id.
end
-- }}}

-- }}}

-- {{{ couchdb_list

local couchdb_list = ratchet.new_context()

-- {{{ couchdb_list:on_init()
function couchdb_list:on_init()
    self.received = ''

    self:send_command()
end
-- }}}

-- {{{ couchdb_list:on_recv()
function couchdb_list:on_recv()
    local data = self:recv()
    if #data > 0 then
        self.received = self.received .. data
    else
        self:parse_response(self.received)
    end
end
-- }}}

-- {{{ couchdb_list:send_command()
function couchdb_list:send_command()
    local command = "GET /%s/_all_docs HTTP/1.0\r\nContent-Length: %d\r\nContent-Type: application/json\r\n\r\n%s\r\n"
    local data = json.encode(message)
    local send = command:format(couchdb_info.database, #data, data)
    self:send(send)
end
-- }}}

-- {{{ couchdb_list:parse_response()
function couchdb_list:parse_response(data)
    local first_line, headers, content = data:match("^(.-)\r?\n(.-)\r?\n\r?\n(.*)$")
    if not first_line then
        -- fail gracefully with no error info.
    end
    local code, text = first_line:match("^HTTP/[%d%.]+%s+(%d+)%s+(.*)$")
    if tonumber(code) ~= 201 then
        -- fail gracefully with a code/text.
    end

    local info = json.decode(content)
    if not info or not info.ok or not info.id then
        -- fail gracefully, no id given, shouldn't happen.
    end

    -- succeed, provide info.id.
end
-- }}}

-- }}}

queue_engines["couchdb"] = {
    new = couchdb_new,
    list = couchdb_list,
    get = couchdb_get,
}

couchdb_info = {
    database = "queue",
    channel = "tcp://localhost:5984",
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
