
require "ratchet.smtp.server"

require "slimta.message"

slimta.edge = slimta.edge or {}
slimta.edge.smtp = {}
slimta.edge.smtp.__index = slimta.edge.smtp

local command_handler = {}
command_handler.__index = command_handler

-- {{{ slimta.edge.smtp.new()
function slimta.edge.smtp.new(socket, bus)
    local self = {}
    setmetatable(self, slimta.edge.smtp)

    self.socket = socket
    self.bus = bus

    self.settings = {
        banner_code = 220,
        banner_message = "ESMTP Welcome",
    }

    return self
end
-- }}}

-- {{{ slimta.edge.smtp:set_banner_message()
function slimta.edge.smtp:set_banner_message(code, message)
    self.settings.banner_code = code
    self.settings.banner_message = message
end
-- }}}

-- {{{ slimta.edge.smtp:set_max_message_size()
function slimta.edge.smtp:set_max_message_size(size)
    self.settings.max_message_size = size
end
-- }}}

-- {{{ slimta.edge.smtp:enable_tls()
function slimta.edge.smtp:enable_tls()
    self.settings.enable_tls = true
end
-- }}}

-- {{{ apply_extension_settings()
local function apply_extension_settings(extensions, settings)
    if settings.enable_tls then
        extensions:add("STARTTLS")
    end

    if settings.max_message_size then
        extensions:add("SIZE", tostring(settings.max_message_size))
    end
end
-- }}}

-- {{{ process_message()
local function process_message(self, message)
    local transaction = self.bus:send_request({message})
    local responses = transaction:recv_response()
    return responses and responses[1]
end
-- }}}

-- {{{ slimta.edge.smtp:accept()
function slimta.edge.smtp:accept()
    local client, from_ip = self.socket:accept()
    
    local cmd_handler = command_handler.new(from_ip, self)
    local smtp_handler = ratchet.smtp.server.new(client, cmd_handler)

    apply_extension_settings(smtp_handler.extensions, self.settings)

    return smtp_handler
end
-- }}}

-- {{{ slimta.edge.smtp:close()
function slimta.edge.smtp:close()
    self.socket:close()
end
-- }}}

-- {{{ command_handler.new()
function command_handler.new(from_ip, smtp_edge)
    local self = {}
    setmetatable(self, command_handler)

    self.security = "none"
    self.from_ip = from_ip
    self.smtp_edge = smtp_edge

    return self
end
-- }}}

-- {{{ command_handler:BANNER()
function command_handler:BANNER(reply)
    if self.smtp_edge.settings.banner_code then
        reply.code = self.smtp_edge.settings.banner_code
    end

    if self.smtp_edge.settings.banner_message then
        reply.message = self.smtp_edge.settings.banner_message
    end
end
-- }}}

-- {{{ command_handler:STARTTLS()
function command_handler:STARTTLS()
    self.security = "TLS"
end
-- }}}

-- {{{ command_handler:EHLO()
function command_handler:EHLO(reply, ehlo_as)
    self.ehlo_as = ehlo_as

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
        -- Build a slimta.message object.
        local client = slimta.message.client.new("SMTP", self.ehlo_as, self.from_ip, self.security)
        local envelope = slimta.message.envelope.new(self.message.sender, self.message.recipients)
        local contents = slimta.message.contents.new(data)
        local timestamp = os.time()

        local message = slimta.message.new(client, envelope, contents, timestamp)

        -- Send the message to the edge manager for processing.
        local response = process_message(self.smtp_edge, message)
        reply.code, reply.message = response:as_smtp()

        -- Reset the session for more messages.
        self.message = nil
    end
end
-- }}}

return slimta.edge.smtp

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
