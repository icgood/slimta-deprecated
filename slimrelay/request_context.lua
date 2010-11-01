local request_context = ratchet.new_context()

-- {{{ tags table
tags = {slimta = {},

        deliver = {"slimta"},

        nexthop = {"slimta", "deliver",
            list = "nexthops",
        },

        protocol = {"slimta", "deliver", "nexthop",
            handle = function (info, attrs, data)
                info.protocol = data:match("%S+")
            end,
        },

        destination = {"slimta", "deliver", "nexthop",
            handle = function (info, attrs, data)
                info.destination = data:match("%S+")
            end,
        },

        port = {"slimta", "deliver", "nexthop",
            handle = function (info, attrs, data)
                info.port = data:match("%d+")
            end,
        },

        security = {"slimta", "deliver", "nexthop",
            handle = function (info, attrs, data)
                -- Put security stuff here.
            end,
        },

        message = {"slimta", "deliver", "nexthop",
            list = "messages",
            handle = function (info, attrs, data)
                info.qid = attrs["queueid"]
            end
        },

        envelope = {"slimta", "deliver", "nexthop", "message"},

        sender = {"slimta", "deliver", "nexthop", "message", "envelope",
            handle = function (info, attrs, data)
                local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

                info.envelope = info.envelope or {}
                info.envelope.sender = stripped_data
            end,
        },

        recipient = {"slimta", "deliver", "nexthop", "message", "envelope",
            handle = function (info, attrs, data)
                local stripped_data = data:gsub("^%s*", ""):gsub("%s*$", "")

                info.envelope = info.envelope or {}
                info.envelope.recipients = info.envelope.recipients or {}
                table.insert(info.envelope.recipients, stripped_data)
            end,
        },

        contents = {"slimta", "deliver", "nexthop", "message",
            handle = function (info, attrs, data)
                attrs["data"] = data
                info.contents = attrs
            end,
        },

    }
-- }}}

-- {{{ on_init()
function request_context:on_init(use_ratchet, results_channel)
    self.use_ratchet = use_ratchet
    self.results_channel = results_channel
end
-- }}}

-- {{{ on_recv()
function request_context:on_recv()
    local data = self:recv()

    self.tag_stack = {}
    self.msg_info = {}

    local parser = slimta.xml {state = self,
                               startelem = self.start_tag,
                               endelem = self.end_tag,
                               elemdata = self.tag_data}
    parser:parse(data)

    self:create_sessions()
end
-- }}}

-- {{{ start_tag()
function request_context:start_tag(tag, attrs)
    local current = {tag = tag, attrs = attrs, data = ""}

    if tags[tag] then
        -- Check if this tag is valid and in the right place.
        local valid = (#tags[tag] == #self.tag_stack)
        for i, t in ipairs(tags[tag]) do
            if t ~= self.tag_stack[i].tag then
                valid = false
                break
            end
        end

        -- For valid tags, generate info and handler.
        if valid then
            local currinfo = self.msg_info
            for i, t in ipairs(self.tag_stack) do
                if tags[t.tag].list then
                    currinfo = currinfo[tags[t.tag].list]
                    currinfo = currinfo[#currinfo]
                end
            end
            if tags[tag].list then
                local n = tags[tag].list
                if not currinfo[n] then
                    currinfo[n] = {}
                end
                table.insert(currinfo[n], {})
                currinfo = currinfo[n][#currinfo[n]]
            end

            current.info = currinfo
            current.handle = tags[tag].handle
        end
    end

    table.insert(self.tag_stack, current)
end
-- }}}

-- {{{ end_tag()
function request_context:end_tag(tag)
    local current = self.tag_stack[#self.tag_stack]

    if current and current.handle then
        current.handle(current.info, current.attrs, current.data)
    end

    table.remove(self.tag_stack)
end
-- }}}

-- {{{ tag_data()
function request_context:tag_data(data)
    local current = self.tag_stack[#self.tag_stack]
    current.data = current.data .. data
end
-- }}}

-- {{{ create_sessions()
function request_context:create_sessions()
    for i, nexthop in ipairs(self.msg_info.nexthops) do
        local proto = protocols[nexthop.protocol]
        if proto then
            proto.create(self.use_ratchet, nexthop, self.results_channel)
        else
            error("Unsupported protocol: " .. proto)
        end
    end
end
-- }}}

return request_context

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
