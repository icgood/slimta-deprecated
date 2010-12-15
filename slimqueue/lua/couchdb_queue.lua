require "json"

-- {{{ couchdb_new_context

local couchdb_new_context = ratchet.new_context()

-- {{{ couchdb_new_context:on_init()
function couchdb_new_context:on_init()
    
end
-- }}}

-- {{{ couchdb_new_context:on_recv()
function couchdb_new_context:on_recv()
    local data = self:recv()
end
-- }}}

-- }}}

queue_engines["couchdb"] = {
    new = couchdb_new_context,
    list = couchdb_list_context,
    get = couchdb_get_context,
}

couchdb_info = {
    database = "queue",
    channel = "tcp://localhost:5984",
}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
