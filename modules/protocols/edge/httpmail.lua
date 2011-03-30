
require "modules.engines.json"
require "modules.engines.http.server"

local httpmail_context = {}
httpmail_context.__index = httpmail_context

-- {{{ httpmail_context.new()
function httpmail_context.new(uri, queue_request_channel)
    local self = {}
    setmetatable(self, httpmail_context)

    self.uri = uri
    self.queue_request_channel = queue_request_channel

    kernel:attach(self)

    return self
end
-- }}}

-- {{{ httpmail_context:POST()
function httpmail_context:POST(uri, headers, data, from)
    if uri ~= "/email" and uri ~= "/email/" then
        return {
            code = 404,
            message = "Not Found",
        }
    end

    local expected_type = 'message/rfc822'
    if headers['content-type'][1]:lower():sub(1, #expected_type) ~= expected_type then
        return {
            code = 406,
            message = "Not Acceptable",
            headers = {["Accept"] = {"message/rfc822"}},
        }
    end

    local message = {
        sender = headers['x-sender'][1],
        recipients = headers['x-recipient'],
        contents = data,
    }

    local checks = {
        sender = function (d) if not d then return "Missing X-Sender header" end end,
        recipients = function (d) if not d then return "Missing X-Recipient headers" end end,
    }
    for k, v in pairs(checks) do
        local err = v(message[k])
        if err then
            return {code = 400, message = err}
        end
    end

    local ehlo = "none"
    if headers['x-ehlo'] then
        ehlo = headers['x-ehlo'][1]
    end

    local queue_up = self.queue_request_channel:new_request()
    local i = queue_up:add_client("HTTP", ehlo, from)
    local j = queue_up:add_contents(message.contents)
    local timestamp = os.time()
    queue_up:add_message(message, i, j, timestamp)
    local results = queue_up()

    local first_msg = results.messages[1]
    if first_msg.queue_id then
        return {
            code = 200,
            message = "Queued Successfully",
            headers = {["Content-Length"] = {#first_msg.queue_id}},
            data = first_msg.queue_id,
        }
    else
        local error_data = json.encode(first_msg.error)
        return {
            code = 500,
            message = "Message Not Queued",
            headers = {["Content-Length"] = {#error_data}},
            data = error_data,
        }
    end
end
-- }}}

-- {{{ httpmail_context:GET()
function httpmail_context:GET(uri, headers, data, from)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ httpmail_context:__call()
function httpmail_context:__call()
    local rec = ratchet.socket.prepare_uri(self.uri, config.dns.a_queries())
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    while true do
        local client, from_ip = socket:accept()
        local client_handler = modules.engines.http.server.new(client, from_ip, self)
        kernel:attach(client_handler)
    end
end
-- }}}

modules.protocols.edge.httpmail = httpmail_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
