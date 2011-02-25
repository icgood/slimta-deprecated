
local xml_wrapper = require "xml_wrapper"

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

local queue_request_context = {}
queue_request_context.__index = queue_request_context

-- {{{ queue_request_context.new()
function queue_request_context.new()
    local self = {}
    setmetatable(self, queue_request_context)

    self.endpoint = confstring(queue_request_channel)
    self.parser = xml_wrapper.new(tags)
    self.contents = {}
    self.messages = {}

    return self
end
-- }}}

-- {{{ queue_request_context:add_contents()
function queue_request_context:add_contents(data)
    table.insert(self.contents, data)
    return #self.contents
end
-- }}}

-- {{{ queue_request_context:add_message()
function queue_request_context:add_message(info, contents_i)
    table.insert(self.messages, {info = info, i = contents_i})
end
-- }}}

-- {{{ queue_request_context:build_message()
function queue_request_context:build_message()
    local tmpl = [[<slimta><queue>
 <client>
%s </client>
</queue></slimta>
]]
    local msg_tmpl = [[  <message>
   <envelope>
    <sender>%s</sender>
%s   </envelope>
   <contents part="%d"/>
  </message>
]]

    local rcpt_tmpl = [[    <recipient>%s</recipient>
]]

    local msgs = ""
    for i, msg in ipairs(self.messages) do
        local rcpts = ""
        for j, rcpt in ipairs(msg.info.recipients) do
            rcpts = rcpts .. rcpt_tmpl:format(rcpt)
        end
        msgs = msgs .. msg_tmpl:format(msg.info.sender, rcpts, msg.i)
    end

    return tmpl:format(msgs)
end
-- }}}

-- {{{ queue_request_context:__call()
function queue_request_context:__call()
    local rec = ratchet.zmqsocket.prepare_uri(self.endpoint)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local msg = self:build_message()
    local num_contents = #self.contents

    if num_contents > 0 then
        socket:send(msg, true)
        for i, data in ipairs(self.contents) do
            if num_contents == i then
                socket:send(data)
            else
                socket:send(data, true)
            end
        end
    else
        socket:send(msg)
    end

    local data = socket:recv()
    local results = self.parser:parse_xml(data)

    return results
end
-- }}}

return queue_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
