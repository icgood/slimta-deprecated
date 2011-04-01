
require "modules.engines.smtp.server"

local smtp_edge = {}
smtp_edge.__index = smtp_edge

local command_handler = {}
command_handler.__index = command_handler

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

-- {{{ smtp_edge:__call()
function smtp_edge:__call()
    local rec = ratchet.socket.prepare_uri(self.uri, config.dns.a_queries())
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    while true do
        local client, from_ip = socket:accept()

        local handler = command_handler.new(from_ip, self.queue_request_channel)
        local smtp_handler = modules.engines.smtp.server.new(client, handler)

        local max_size = config.modules.protocols.edge.smtp.maximum_size()

        smtp_handler.extensions:add("STARTTLS")
        if max_size then
            smtp_handler.extensions:add("SIZE", max_size)
        end

        kernel:attach(smtp_handler)
    end
end
-- }}}

-- {{{ command_handler.new()
function command_handler.new(from_ip, queue_request_channel)
    local self = {}
    setmetatable(self, command_handler)

    self.from_ip = from_ip
    self.queue_up = queue_request_channel:new_request()

    return self
end
-- }}}

-- {{{ command_handler:BANNER()
function command_handler:BANNER(reply)
    local banner_message = config.modules.protocols.edge.smtp.banner_message()

    if self.banner_message then
        reply.message = banner_message
    end
end
-- }}}

-- {{{ command_handler:EHLO()
function command_handler:EHLO(reply, ehlo_as)
    if not self.client_i then
        self.client_i = self.queue_up:add_client("SMTP", ehlo_as, self.from_ip)
    end

    self.message = nil
end
-- }}}

-- {{{ command_handler:RSET()
function command_handler:RSET()
    self.message = nil
end
-- }}}

-- {{{ command_handler:MAIL()
function command_handler:MAIL(reply, address)
    self.message = {
        sender = address,
        recipients = {},
    }
end
-- }}}

-- {{{ command_handler:RCPT()
function command_handler:RCPT(reply, address)
    table.insert(self.message.recipients, address)
end
-- }}}

-- {{{ command_handler:HAVE_DATA()
function command_handler:HAVE_DATA(reply, data, err)
    if not err then
        local contents_i = self.queue_up:add_contents(data)
        local timestamp = os.time()
        self.queue_up:add_message(self.message, self.client_i, contents_i, timestamp)
        local results = self.queue_up()

        local first_msg = results.messages[1]
        if first_msg.queue_id then
            reply.message = "Message Queued as " .. first_msg.queue_id
        else
            reply.code = "451"
            reply.message = "Message Queue Failure"
        end

        self.message = nil
    end
end
-- }}}

slimta.config.new("config.modules.protocols.edge.smtp.banner_message")
slimta.config.new("config.modules.protocols.edge.smtp.maximum_size", "10485760")

modules.protocols.edge.smtp = smtp_edge

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
