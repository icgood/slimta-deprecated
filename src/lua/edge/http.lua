
require "ratchet.http.server"

require "slimta.message"

slimta.edge.http = {}
slimta.edge.http.__index = slimta.edge.http

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

-- {{{ slimta.edge.http.new()
function slimta.edge.http.new(host, port, family)
    local self = {}
    setmetatable(self, slimta.edge.http)

    self.socket = setup_listening_socket(host, port, family)

    return self
end
-- }}}

-- {{{ slimta.edge.http:set_manager()
function slimta.edge.http:set_manager(manager)
    self.manager = manager
end
-- }}}

-- {{{ slimta.edge.http:POST()
function slimta.edge.http:POST(uri, headers, data, from)
    -- Check the URI to make sure we accept it.
    if uri ~= "/email" and uri ~= "/email/" then
        return {
            code = 404,
            message = "Not Found",
        }
    end

    -- Check the Content-Type for an email message.
    local expected_type = 'message/rfc822'
    if headers['content-type'][1]:lower():sub(1, #expected_type) ~= expected_type then
        return {
            code = 406,
            message = "Not Acceptable",
            headers = {["Accept"] = {"message/rfc822"}},
        }
    end

    -- Set the EHLO, if given.
    local ehlo = "none"
    if headers['x-ehlo'] then
        ehlo = headers['x-ehlo'][1]
    end

    -- Grab the sender and recipient from HTTP headers.
    local sender = headers['x-sender'][1]
    local recipients = headers['x-recipient']

    -- Build a slimta.message object.
    local client = slimta.message.client.new("HTTP", ehlo, from, "none")
    local envelope = slimta.message.envelope.new(sender, recipients)
    local contents = slimta.message.contents.new(data)
    local timestamp = os.time()

    local message = slimta.message.new(client, envelope, contents, timestamp)

    -- Run some checks on the message.
    if not message.envelope.sender then
        return {code = 400, message = "Missing X-Sender header"}
    end
    if not message.envelope.recipients then
        return {code = 400, message = "Missing X-Recipient header"}
    end

    -- Send the message to the edge manager for processing.
    local response = self.manager:process_message(message)
    return response:as_http()
end
-- }}}

-- {{{ slimta.edge.http:GET()
function slimta.edge.http:GET(uri, headers, data, from)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ slimta.edge.http:loop()
function slimta.edge.http:loop()
    while not self.done do
        self.paused_thread = ratchet.thread.self()
        local client, from_ip = self.socket:accept()
        self.paused_thread = nil

        if client then
            local handler = ratchet.http.server.new(client, from_ip, self)
            ratchet.thread.attach(handler.handle, handler)
        end
    end
end
-- }}}

-- {{{ slimta.edge.http:run()
function slimta.edge.http:run()
    ratchet.thread.attach(self.loop, self)
end
-- }}}

-- {{{ slimta.edge.http:halt()
function slimta.edge.http:halt()
    self.done = true
    self.socket:close()
    if self.paused_thread then
        ratchet.thread.kill(self.paused_thread)
    end
end
-- }}}

return slimta.edge.http

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
