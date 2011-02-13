local http_server = require "http_server"

local httpmail_context = {}
httpmail_context.__index = httpmail_context

-- {{{ httpmail_context.new()
function httpmail_context.new(where)
    local self = {}
    setmetatable(self, httpmail_context)

    self.host, self.port = uri(where)

    return self
end
-- }}}

-- {{{ httpmail_context:__call()
function httpmail_context:__call()
    local rec = kernel:resolve_dns(self.host, self.port)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    while true do
        local client = socket:accept()
        local client_handler = http_server.new(client, self)
        kernel:attach(client_handler)
    end
end
-- }}}

return httpmail_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
