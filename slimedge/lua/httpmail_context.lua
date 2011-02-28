require "json"
local http_server = require "http_server"
local queue_request_context = require "queue_request_context"

local httpmail_context = {}
httpmail_context.__index = httpmail_context

-- {{{ httpmail_context.new()
function httpmail_context.new(where)
    local self = {}
    setmetatable(self, httpmail_context)

    self.where = where

    return self
end
-- }}}

-- {{{ httpmail_context:POST()
function httpmail_context:POST(uri, headers, data)
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

    if not message.sender or not message.recipients or not #message.recipients then
        return {
            code = 400,
            message = "Missing X-Sender or X-Recipient header",
        }
    end

    local queue_up = queue_request_context.new()
    local i = queue_up:add_contents(message.contents)
    queue_up:add_message(message, i)

    local results = queue_up()

    local first_msg = results.messages[1]
    if first_msg.queue_id then
        return {
            code = 202,
            message = "Queued Successfully",
            headers = {["X-Queue-Id"] = {first_msg.queue_id}},
        }
    else
        return {
            code = 500,
            message = "Message Not Queued",
            data = json.encode(first_msg.error),
        }
    end
end
-- }}}

-- {{{ httpmail_context:GET()
function httpmail_context:GET(uri, headers, data)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ httpmail_context:__call()
function httpmail_context:__call()
    local rec = ratchet.socket.prepare_uri(self.where, dns, CONF(dns_query_types))
    local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
    socket.SO_REUSEADDR = true
    socket:bind(rec.addr)
    socket:listen()

    while true do
        local client = socket:accept()
        local client_handler = http_server.new(client, self)
        kernel:attach(client_handler)
    end
end
-- }}}

return httpmail_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
