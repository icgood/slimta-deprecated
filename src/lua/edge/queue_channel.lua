
require "slimta.xml.writer"
require "slimta.xml.reader"

module("slimta.edge.queue_channel", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new(uri)
    local self = {}
    setmetatable(self, class)

    self.uri = uri

    return self
end
-- }}}

-- {{{ mock_request_enqueue()
local function mock_request_enqueue(self, messages)
    for i, msg in ipairs(messages) do
        msg.error_data = "Handled by Mock-Queue"
    end

    return self.callback(messages)
end
-- }}}

-- {{{ mock()
function mock(callback)
    local self = {}
    setmetatable(self, {__index = {
        request_enqueue = mock_request_enqueue,
    }})

    self.callback = callback

    return self
end
-- }}}

-- {{{ connect_to_queue()
local function connect_to_queue(uri)
    local rec = ratchet.zmqsocket.prepare_uri(uri)
    local socket = ratchet.zmqsocket.new(rec.type)
    socket:connect(rec.endpoint)

    return socket
end
-- }}}

-- {{{ request_container_to_xml()
local function request_container_to_xml(self, attachments)
    local lines = {
        "<request type=\"enqueue\" i=\""..self.i.."\">",
        self.message:to_xml(attachments),
        "</request>",
    }

    return lines
end
-- }}}

-- {{{ build_full_request()
local function build_full_request(messages)
    local writer = slimta.xml.writer.new()

    for i, msg in ipairs(messages) do
        local container = {
            i = i,
            message = msg,
            to_xml = request_container_to_xml,
        }
        writer:add_item(container)
    end

    return writer:build({"slimta"})
end
-- }}}

-- {{{ send_full_request()
local function send_full_request(socket, request, attachments)
    local num_attachments = #attachments
    local curr_attachment = 1
    local more_coming = curr_attachment <= num_attachments

    socket:send(request, more_coming)
    while more_coming do
        local data = attachments[curr_attachment]
        curr_attachment = curr_attachment + 1
        more_coming = curr_attachment <= num_attachments
        socket:send(data, more_coming)
    end
end
-- }}}

-- {{{ recv_responses()
local function recv_responses(socket)
    local response = socket:recv()

    local reader = slimta.xml.reader.new()
    local root_node = reader:parse_xml(response)

    assert(#root_node == 1)
    assert(root_node[1].name == "slimta")

    return root_node[1]
end
-- }}}

-- {{{ parse_responses()
local function parse_responses(xml_node, messages)
    for i, child_node in ipairs(xml_node) do
        local type = child_node.attrs.type
        local j = tonumber(child_node.attrs.i or i)

        if type == "enqueue" and messages[j] then
            if child_node[1].name == "success" then
                messages[j].id = child_node[1].data
            else
                messages[j].error_data = child_node[1]
            end
        end
    end
end
-- }}}

-- {{{ request_enqueue()
function request_enqueue(self, messages)
    local socket = connect_to_queue(self.uri)
    local request, attachments = build_full_request(messages)
    send_full_request(socket, request, attachments)
    local response_node = recv_responses(socket)
    parse_responses(response_node, messages)
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
