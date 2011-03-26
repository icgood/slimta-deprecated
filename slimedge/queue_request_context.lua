
local xml_wrapper = require "modules.engines.xml_wrapper"

-- {{{ tags table
local tags = {

    {"slimta"},

    {"queue", "slimta"},

    {"results", "queue", "slimta"},

    {"message", "results", "queue", "slimta",
        list = "messages",
        handle = function (info, attrs, data)
            info.response_id = attrs.id
            local qid = data:gsub("^%s*", ""):gsub("%s*$", "")
            if qid ~= "" then
                info.queue_id = qid
            end
        end,
    },

    {"error", "message", "results", "queue", "slimta",
        handle = function (info, attrs, data)
            info.error = {}
            for k, v in pairs(attrs) do
                info.error[k] = v
            end
            info.error.message = data:gsub("^%s*", ""):gsub("%s*$", "")
        end,
    },

}
-- }}}

queue_request_context = {}
queue_request_context.__index = queue_request_context

local channel = {}
channel.__index = channel

-- {{{ queue_request_context.new()
function queue_request_context.new(uri)
    local self = {}
    setmetatable(self, queue_request_context)

    self.uri = uri

    return self
end
-- }}}

-- {{{ queue_request_context:new_request()
function queue_request_context:new_request()
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    return channel.new(socket, rec)
end
-- }}}

-- {{{ channel.new()
function channel.new(socket, rec)
    local self = {}
    setmetatable(self, channel)

    self.socket = socket
    self.rec = rec

    self.parser = xml_wrapper.new(tags)
    self.contents = {}
    self.clients = {}

    return self
end
-- }}}

-- {{{ channel:add_contents()
function channel:add_contents(data)
    table.insert(self.contents, data)
    return #self.contents
end
-- }}}

-- {{{ channel:add_client()
function channel:add_client(protocol, ehlo)
    local client = {
        protocol = protocol,
        ehlo = ehlo,
        messages = {},
    }

    table.insert(self.clients, client)
    return #self.clients
end
-- }}}

-- {{{ channel:add_message()
function channel:add_message(info, client_i, contents_i, timestamp)
    local msg = {
        info = info,
        i = contents_i,
        timestamp = timestamp,
    }

    table.insert(self.clients[client_i].messages, msg)
end
-- }}}

-- {{{ channel:build_message()
function channel:build_message()
    local tmpl = [[<slimta><queue>
 <host>%s</host>
%s</queue></slimta>
]]
    local client_tmpl = [[ <client>
  <protocol>%s</protocol>
  <ehlo>%s</ehlo>
%s </client>
]]
    local msg_tmpl = [[  <message timestamp="%s">
   <envelope>
    <sender>%s</sender>
%s   </envelope>
   <contents part="%d"/>
  </message>
]]

    local rcpt_tmpl = [[    <recipient>%s</recipient>
]]

    local clients = ""
    for i, client in ipairs(self.clients) do
        local msgs = ""
        for j, msg in ipairs(client.messages) do
            local rcpts = ""
            for k, rcpt in ipairs(msg.info.recipients) do
                rcpts = rcpts .. rcpt_tmpl:format(rcpt)
            end
            msgs = msgs .. msg_tmpl:format(msg.timestamp, msg.info.sender, rcpts, msg.i)
        end
        clients = clients .. client_tmpl:format(client.protocol, client.ehlo, msgs)
    end

    local whoami = config.edge.fqdn()

    return tmpl:format(whoami, clients)
end
-- }}}

-- {{{ channel:__call()
function channel:__call()
    local msg = self:build_message()
    local num_contents = #self.contents

    if num_contents > 0 then
        self.socket:send(msg, true)
        for i, data in ipairs(self.contents) do
            if num_contents == i then
                self.socket:send(data)
            else
                self.socket:send(data, true)
            end
        end
    else
        self.socket:send(msg)
    end

    local data = self.socket:recv()
    local results = self.parser:parse_xml(data)

    return results
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
