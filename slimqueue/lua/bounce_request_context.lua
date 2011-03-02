
local xml_wrapper = require "xml_wrapper"

local bounce_request_channel_str = CONF(bounce_request_channel)

-- {{{ tags table
local tags = {

    {"slimta"},

    {"queue", "slimta"},

    {"results", "queue", "slimta"},

    {"bounce", "results", "queue", "slimta",
        list = "bounces",
        handle = function (info, attrs, data)
            info.response_id = attrs.id
            local qid = data:gsub("^%s*", ""):gsub("%s*$", "")
            if qid ~= "" then
                info.queue_id = qid
            end
        end,
    },

    {"error", "bounce", "results", "queue", "slimta",
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

local bounce_request_context = {}
bounce_request_context.__index = bounce_request_context

-- {{{ bounce_request_context.new()
function bounce_request_context.new()
    local self = {}
    setmetatable(self, bounce_request_context)

    self.parser = xml_wrapper.new(tags)
    self.bounces = {}

    return self
end
-- }}}

-- {{{ bounce_request_context:add_bounce()
function bounce_request_context:add_bounce(info)
    table.insert(self.bounces, info)
end
-- }}}

-- {{{ bounce_request_context:build_message()
function bounce_request_context:build_message()
    local tmpl = [[<slimta><queue>
 <client>
%s </client>
</queue></slimta>
]]
    local msg_tmpl = [[  <bounce protocol="$(protocol)">
   <error code="$(code)">$(message)</error>
   <storage engine="$(engine)">$(data)</storage>
  </bounce>
]]

    local msgs = ""
    for i, bounce in ipairs(self.bounces) do
        msgs = msgs .. slimta.interp(msg_tmpl, {
            protocol = bounce.protocol,
            code = bounce.code,
            message = bounce.message,
            engine = bounce.storage.engine,
            data = bounce.storage.data,
        })
    end

    return tmpl:format(msgs)
end
-- }}}

-- {{{ bounce_request_context:__call()
function bounce_request_context:__call()
    local rec = ratchet.zmqsocket.prepare_uri(bounce_request_channel_str)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local msg = self:build_message()
    socket:send(msg)

    local data = socket:recv()
    local results = self.parser:parse_xml(data)

    return results
end
-- }}}

return bounce_request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
