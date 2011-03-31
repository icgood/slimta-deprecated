
require "modules.engines.smtp.server"

local smtp_edge = {}
smtp_edge.__index = smtp_edge

-- {{{ smtp_edge.new()
function smtp_edge.new(uri, queue_request_channel)
    local self = {}
    setmetatable(self, smtp_edge)

    self.uri = uri
    self.queue_request_channel = queue_request_channel

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ smtp_edge:BANNER()
function smtp_edge:BANNER()
    return "220", "ESMTP Welcome to slimta " .. slimta.version .. "."
end
-- }}}

-- {{{ smtp_edge:__call()
function smtp_edge:__call()
    local rec = ratchet.socket.prepare_uri(self.uri, config.dns.a_queries())
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    while true do
        local client, from_ip = socket:accept()
        local client_handler = modules.engines.smtp.server.new(client, from_ip, self)
        client_handler.extensions:add("STARTTLS")
        kernel:attach(client_handler)
    end
end
-- }}}

modules.protocols.edge.smtp = smtp_edge

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
