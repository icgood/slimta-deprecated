
require "slimta.edge.http"
require "slimta.edge.smtp"
require "slimta.edge.queue_channel"

module("slimta.edge", package.seeall)
local class = getfenv()
__index = class

-- {{{ new()
function new()
    local self = {}
    setmetatable(self, class)

    self.listeners = {}

    return self
end
-- }}}

-- {{{ add_listener()
function add_listener(self, listener)
    listener:set_manager(self)
    table.insert(self.listeners, listener)
end
-- }}}

-- {{{ set_queue_channel()
function set_queue_channel(self, channel)
    self.queue = channel
end
-- }}}

-- {{{ queue_message()
function queue_message(self, message)
    if self.queue then
        self.queue:request_enqueue({message})
    else
        message.error_data = "Please configure a queue channel."
    end

    if message.id then
        return message.id
    else
        return nil, message.error_data
    end
end
-- }}}

-- {{{ run()
function run(self, kernel)
    for i, listener in ipairs(self.listeners) do
        listener:run(kernel)
    end
end
-- }}}

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
