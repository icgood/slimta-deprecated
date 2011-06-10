
require "slimta.json"
require "ratchet.http.server"

require "slimta.message"

module("slimta.edge.http", package.seeall)
local class = getfenv()
__index = class

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
function new(uri, dns_query_types)
    local self = {}
    setmetatable(self, class)

    self.socket = setup_listening_socket(uri, dns_query_types)

    return self
end
-- }}}

-- {{{ set_manager()
function set_manager(self, manager)
    self.manager = manager
end
-- }}}

-- {{{ POST()
function POST(self, uri, headers, data, from)
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

    -- Send the message to the edge manager for processing, if
    -- one has been set.
    local queue_id, error_data = self.manager:queue_message(message)

    -- Return success if we got a queue ID, error otherwise.
    if queue_id then
        return {
            code = 200,
            message = "Queued Successfully",
            headers = {["Content-Length"] = {#queue_id}},
            data = queue_id,
        }
    else
        local error_str = json.encode(error_data)
        return {
            code = 500,
            message = "Message Not Queued",
            headers = {["Content-Length"] = {#error_str}},
            data = error_str,
        }
    end
end
-- }}}

-- {{{ GET()
function GET(self, uri, headers, data, from)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ loop()
function loop(self, kernel)
    while true do
        local client, from_ip = self.socket:accept()
        local handler = ratchet.http.server.new(client, from_ip, self)
        kernel:attach(handler.handle, handler)
    end
end
-- }}}

-- {{{ run()
function run(self, kernel)
    kernel:attach(loop, self, kernel)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
