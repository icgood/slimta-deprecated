
require "ratchet.smtp.server"

require "slimta.message"

module("slimta.edge.smtp", package.seeall)
local class = getfenv()
__index = class

local command_handler = {}
command_handler.__index = command_handler

-- {{{ setup_listening_socket()
local function setup_listening_socket(uri, dns_query_types)
    local rec = ratchet.socket.prepare_uri(uri, dns_query_types)
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    return socket
end
-- }}}

-- {{{ new()
function new(uri, dns_query_types, synchronous)
    local self = {}
    setmetatable(self, class)

    self.socket = setup_listening_socket(uri, dns_query_types)
    self.synchronous = synchronous

    self.settings = {
        banner_code = 220,
        banner_message = "ESMTP Welcome",
    }

    return self
end
-- }}}

-- {{{ set_manager()
function set_manager(self, manager)
    self.manager = manager
end
-- }}}

-- {{{ set_banner_message()
function set_banner_message(self, code, message)
    self.settings.banner_code = code
    self.settings.banner_message = message
end
-- }}}

-- {{{ set_max_message_size()
function set_max_message_size(self, size)
    self.settings.max_message_size = size
end
-- }}}

-- {{{ enable_tls()
function enable_tls(self)
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

-- {{{ loop()
function loop(self, kernel)
    while not self.done do
        local client, from_ip = self.socket:accept()

        local handler = command_handler.new(from_ip, self.manager, self.settings)
        local smtp_handler = ratchet.smtp.server.new(client, handler)

        apply_extension_settings(smtp_handler.extensions, self.settings)

        if self.synchronous then
            smtp_handler:handle()
        else
            kernel:attach(smtp_handler.handle, smtp_handler)
        end
    end
end
-- }}}

-- {{{ run()
function run(self, kernel)
    kernel:attach(loop, self, kernel)
end
-- }}}

-- {{{ halt()
function halt(self, kernel)
    self.done = true
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

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
