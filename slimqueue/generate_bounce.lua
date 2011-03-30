
local relay_request_context = require "slimqueue.relay_request_context"
local message_wrapper = require "slimqueue.message_wrapper"

local generate_bounce = {}
generate_bounce.__index = generate_bounce

-- {{{ generate_bounce.new()
function generate_bounce.new(bounce, relay_req_uri)
    local self = {}
    setmetatable(self, generate_bounce)

    self.bounce = bounce
    self.relay_req_uri = relay_req_uri

    return self
end
-- }}}

-- {{{ generate_bounce:store_and_request_relay()
function generate_bounce:store_and_request_relay(data)
    local msg = self.bounce
    local which_engine = msg.orig_storage.engine
    local engine = modules.engines.storage[which_engine].new

    msg.storage = {engine = which_engine}

    local storage = engine.new(msg)
    local relay_req = relay_request_context.new(self.relay_req_uri)
    relay_req:add_message(msg)

    -- Create the message container and get access data.
    msg.storage.data = storage:create_message_root()

    -- Run pre-storage modules and add message data to storage container.
    data = self:handle_prestorage_modules(msg, data)
    storage:create_message_body(data)

    -- Send message data, unless storage engine says not to.
    if not storage.dont_send then
        relay_req()
    end
end
-- }}}

-- {{{ generate_bounce:handle_prestorage_modules()
function generate_bounce:handle_prestorage_modules(message, data)
    -- Check if no prestorage modules are loaded.
    if not modules.engines.prestorage[1] then
        return data
    end

    local wrapper = message_wrapper.new(data)
    for i, mod in ipairs(modules.engines.prestorage) do
        mod(wrapper, message)
    end

    return tostring(wrapper)
end
-- }}}

-- {{{ generate_bounce:get_original_message()
function generate_bounce:get_original_message()
    local orig_storage = self.bounce.orig_storage
    local engine = modules.engines.storage[orig_storage.engine]
    local info, data

    local get_info = engine.get_info.new()
    info = get_info(orig_storage.data)

    local get_contents = engine.get_contents.new()
    data = get_contents(orig_storage.data)

    return info, data
end
-- }}}

-- {{{ generate_bounce:set_bounce_envelope()
function generate_bounce:set_bounce_envelope(orig)
    self.bounce.envelope = {
        sender = "",
        recipients = {orig.envelope.sender}
    }
end
-- }}}

-- {{{ generate_bounce:build_bounce_data()
function generate_bounce:build_bounce_data(orig, orig_data)
    local boundary = "=_boundary_" .. slimta.uuid.generate()

    local header_tmpl = "From: MAILER-DAEMON\r\nTo: $(sender)\r\nSubject: Undelivered Mail Returned to Sender\r\nAuto-Submitted: auto-replied\r\nMIME-Version: 1.0\r\nContent-Type: multipart/report; report-type=delivery-status; \r\n\tboundary=\"$(boundary)\"\r\nContent-Transfer-Encoding: 7bit\r\n\r\nThis is a multi-part message in MIME format.\r\n\r\n--$(boundary)\r\nContent-Type: text/plain\r\n\r\nDelivery failed.\r\n\r\n--$(boundary)\r\nContent-Type: message/delivery-status\r\n\r\nRemote-MTA: dns; blah [0.0.0.0]\r\nDiagnostic-Code: $(protocol); $(code) $(message)\r\n\r\n--$(boundary)\r\nContent-Type: message/rfc822\r\n\r\n"
    local footer_tmpl = "\r\n--$(boundary)--\r\n"

    local substitutions = {
        boundary = boundary,
        sender = orig.envelope.sender,
        protocol = self.bounce.protocol,
        code = self.bounce.code,
        message = self.bounce.message,
    }

    local header = slimta.interp(header_tmpl, substitutions)
    local footer = slimta.interp(footer_tmpl, substitutions)

    return header .. orig_data .. footer
end
-- }}}

-- {{{ generate_bounce:on_error()
function generate_bounce:on_error(err)
    self.bounce.storage = nil
    self.bounce.storage_error = err
end
-- }}}

-- {{{ generate_bounce:__call()
function generate_bounce:__call()
    kernel:set_error_handler(self.on_error, self)

    self.bounce.server = "localhost"

    local orig, orig_data = self:get_original_message()
    self:set_bounce_envelope(orig)
    local bounce_data = self:build_bounce_data(orig, orig_data)

    self.bounce.attempts = 0
    self.bounce.size = #bounce_data

    self:store_and_request_relay(bounce_data)
end
-- }}}

return generate_bounce

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
