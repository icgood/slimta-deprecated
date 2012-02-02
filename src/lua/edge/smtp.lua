
require "ratchet.smtp.server"

require "slimta.message"

slimta.edge.smtp = {}
slimta.edge.smtp.__index = slimta.edge.smtp

local command_handler = {}
command_handler.__index = command_handler

-- {{{ setup_listening_socket()
local function setup_listening_socket(host, port, family)
    local rec = ratchet.socket.prepare_tcp(host, port, family)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    return socket
end
-- }}}

-- {{{ slimta.edge.smtp.new()
function slimta.edge.smtp.new(host, port, family)
    local self = {}
    setmetatable(self, slimta.edge.smtp)

    self.socket = setup_listening_socket(host, port, family)

    self.settings = {
        banner_code = 220,
        banner_message = "ESMTP Welcome",
    }

    return self
end
-- }}}

-- {{{ slimta.edge.smtp:set_manager()
function slimta.edge.smtp:set_manager(manager)
    self.manager = manager
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

-- {{{ slimta.edge.smtp:loop()
function slimta.edge.smtp:loop()
    while not self.done do
        self.paused_thread = ratchet.thread.self()
        local client, from_ip = self.socket:accept()
        self.paused_thread = nil
        
        if client then
            local handler = command_handler.new(from_ip, self.manager, self.settings)
            local smtp_handler = ratchet.smtp.server.new(client, handler)

            apply_extension_settings(smtp_handler.extensions, self.settings)

            ratchet.thread.attach(smtp_handler.handle, smtp_handler)
        end
    end
end
-- }}}

-- {{{ slimta.edge.smtp:run()
function slimta.edge.smtp:run()
    ratchet.thread.attach(self.loop, self)
end
-- }}}

-- {{{ slimta.edge.smtp.halt()
function slimta.edge.smtp.halt(self)
    self.done = true
    self.socket:close()
    if self.paused_thread then
        ratchet.thread.kill(self.paused_thread)
    end
end
-- }}}

-- {{{ command_handler.new()
function command_handler.new(from_ip, manager, settings)
    local self = {}
    setmetatable(self, command_handler)

    self.security = "none"
    self.from_ip = from_ip
    self.manager = manager
    self.settings = settings

    return self
end
-- }}}

-- {{{ command_handler:BANNER()
function command_handler:BANNER(reply)
    if self.settings.banner_code then
        reply.code = self.settings.banner_code
    end

    if self.settings.banner_message then
        reply.message = self.settings.banner_message
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
        local response = self.manager:process_message(message)
        reply.code, reply.message = response:as_smtp()

        -- Reset the session for more messages.
        self.message = nil
    end
end
-- }}}

return slimta.edge.smtp

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
