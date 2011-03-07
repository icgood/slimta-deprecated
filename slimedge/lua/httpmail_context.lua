require "json"
local http_server = require "http_server"
local queue_request_context = require "queue_request_context"

local httpmail_channel_str = CONF(httpmail_channel)

local httpmail_context = {}
httpmail_context.__index = httpmail_context

-- {{{ httpmail_context.new()
function httpmail_context.new()
    local self = {}
    setmetatable(self, httpmail_context)

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
        ehlo = headers['x-ehlo'],
        contents = data,
    }

    local checks = {
        sender = function (d) if not d then return "Missing X-Sender header" end end,
        recipients = function (d) if not d then return "Missing X-Recipient headers" end end,
        ehlo = function (d) if not d then return "Missing X-Ehlo headers" end end,
    }
    for k, v in pairs(checks) do
        local err = v(message[k])
        if err then
            return {code = 400, message = err}
        end
    end

    local queue_up = queue_request_context.new()
    local i = queue_up:add_contents(message.contents)
    queue_up:add_message(message, i)

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
function httpmail_context:GET(uri, headers, data)
    return {code = 503, message = "Service Unavailable"}
end
-- }}}

-- {{{ httpmail_context:__call()
function httpmail_context:__call()
    local rec = ratchet.socket.prepare_uri(httpmail_channel_str, CONF(dns_query_types))
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
