
require "ratchet"
require "slimta"

slimta.policies = slimta.policies or {}
slimta.policies.add_message_id_header = {}
slimta.policies.add_message_id_header.__index = slimta.policies.add_message_id_header

-- {{{ slimta.policies.add_message_id_header.new()
function slimta.policies.add_message_id_header.new(hostname, random_func, time_func)
    local self = {}
    setmetatable(self, slimta.policies.add_message_id_header)

    self.hostname = hostname or os.getenv("HOSTNAME") or ratchet.socket.gethostname()
    self.random_func = random_func or slimta.uuid.generate
    self.time_func = time_func or os.time

    return self
end
-- }}}

-- {{{ slimta.policies.add_message_id_header:add()
function slimta.policies.add_message_id_header:add(message)
    if not message.contents.headers["message-id"][1] then
        local mid = ("<%s.%s@%s>"):format(
            self.random_func(),
            self.time_func(),
            self.hostname
        )
        message.contents:add_header("Message-Id", mid)
    end
end
-- }}}

return slimta.policies.add_message_id_header

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
