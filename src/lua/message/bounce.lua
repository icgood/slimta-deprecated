
slimta.message.bounce = {}
slimta.message.bounce.__index = slimta.message.bounce

-- {{{ default_header_tmpl
local default_header_tmpl = [[
From: MAILER-DAEMON
To: $(sender)
Subject: Undelivered Mail Returned to Sender
Auto-Submitted: auto-replied
MIME-Version: 1.0
Content-Type: multipart/report; report-type=delivery-status; 
    boundary="$(boundary)"
Content-Transfer-Encoding: 7bit

This is a multi-part message in MIME format.

--$(boundary)
Content-Type: text/plain

Delivery failed.

Destination host responded:
$(code) $(message)

--$(boundary)
Content-Type: message/delivery-status

Remote-MTA: dns; $(client_name) [$(client_ip)]
Diagnostic-Code: $(protocol); $(code) $(message)

--$(boundary)
Content-Type: message/rfc822

]]
-- }}}

-- {{{ default_footer_tmpl
local default_footer_tmpl = [[

--$(boundary)--
]]
-- }}}

-- {{{ slimta.message.bounce.new()
function slimta.message.bounce.new(sender, client, header_tmpl, footer_tmpl)
    local self = {}
    setmetatable(self, slimta.message.bounce)

    self.sender = sender or ""
    self.client = client

    self.header_tmpl = header_tmpl or default_header_tmpl
    self.footer_tmpl = footer_tmpl or default_footer_tmpl

    self.header_tmpl = self.header_tmpl:gsub("%\r?%\n", "\r\n")
    self.footer_tmpl = self.footer_tmpl:gsub("%\r?%\n", "\r\n")

    return self
end
-- }}}

-- {{{ get_substitution_table()
local function get_substitution_table(message, response)
    local boundary = "boundary_"..slimta.uuid.generate()

    local sub_table = {
        boundary = boundary,
        sender = message.envelope.sender,
        client_name = message.client.host or "unknown",
        client_ip = message.client.ip or "unknown",
        dest_host = message.envelope.dest_host or "unknown",
        dest_port = message.envelope.dest_port or "unknown",
        protocol = message.client.protocol,
        code = response.code,
        message = response.message,
    }

    return sub_table
end
-- }}}

-- {{{ slimta.message.bounce:build()
function slimta.message.bounce:build(message, response, timestamp)
    local body_sub_table = get_substitution_table(message, response)
    local bounce_body_parts = {
        self.header_tmpl:gsub("%$%((.-)%)", body_sub_table),
        tostring(message.contents),
        self.footer_tmpl:gsub("%$%((.-)%)", body_sub_table),
    }
    local bounce_body = table.concat(bounce_body_parts, "", 1, 3)

    timestamp = timestamp or os.time()
    local client = self.client or slimta.message.client.copy(message.client)
    local envelope = slimta.message.envelope.new(self.sender, {message.envelope.sender})
    local contents = slimta.message.contents.new(bounce_body)
    local bounce = slimta.message.new(client, envelope, contents, timestamp)

    return bounce
end
-- }}}

return slimta.message.bounce

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
