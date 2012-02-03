
require "ratchet.http.server"

require "slimta.message"

slimta.edge = slimta.edge or {}
slimta.edge.http = {}
slimta.edge.http.__index = slimta.edge.http

-- {{{ slimta.edge.http.new()
function slimta.edge.http.new(socket, bus)
    local self = {}
    setmetatable(self, slimta.edge.http)

    self.socket = socket
    self.bus = bus

    return self
end
-- }}}

-- {{{ process_message()
local function process_message(self, message)
    local transaction = self.bus:send_request({message})
    local responses = transaction:recv_response()
    return responses and responses[1]
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

    -- Add necessary headers to message contents.
    if not contents.headers["from"][1] then
        contents:add_header("From", sender)
    end

    local message = slimta.message.new(client, envelope, contents, timestamp)

    -- Run some checks on the message.
    if not message.envelope.sender then
        return {code = 400, message = "Missing X-Sender header"}
    end
    if not message.envelope.recipients then
        return {code = 400, message = "Missing X-Recipient header"}
    end

    -- Send the message to the edge manager for processing.
    local response = process_message(self, message)
    return response:as_http()
end
-- }}}

-- {{{ slimta.edge.http:GET()
function slimta.edge.http:GET(uri, headers, data, from)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ slimta.edge.http:accept()
function slimta.edge.http:accept()
    local client, from_ip = self.socket:accept()

    return ratchet.http.server.new(client, from_ip, self)
end
-- }}}

-- {{{ slimta.edge.http:close()
function slimta.edge.http:close()
    self.socket:close()
end
-- }}}

return slimta.edge.http

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
