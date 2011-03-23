
local xml_wrapper = require "modules.engines.xml_wrapper"

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
function bounce_request_context.new(uri, msgs)
    local self = {}
    setmetatable(self, bounce_request_context)

    self.uri = uri
    self.parser = xml_wrapper.new(tags)
    self.bounces = msgs or {}

    return self
end
-- }}}

-- {{{ bounce_request_context:add_message()
function bounce_request_context:add_message(msg)
    table.insert(self.bounces, msg)
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
    local rec = ratchet.zmqsocket.prepare_uri(self.uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    local msg = self:build_message()
    socket:send(msg)

    local data = socket:recv()
    local results = self.parser:parse_xml(data)

    return results
end
-- }}}

slimta.config.new("config.modules.engines.failure.bounce.request_uri")

-- {{{ failure_bounce()
local function failure_bounce(msgs)
    local uri = config.modules.engines.failure.bounce.request_uri()
    if not uri then
        error("config.modules.engines.failure.bounce.request_uri required.")
    end
    local ctx = bounce_request_context.new(uri, msgs)
    return ctx()
end
-- }}}

modules.engines.failure = failure_bounce

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
