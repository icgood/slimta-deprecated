
require "slimta"
require "slimta.message"

slimta.queue = {}
slimta.queue.__index = slimta.queue

local queue_thread_meta = {}
queue_thread_meta.__index = queue_thread_meta

-- {{{ default_get_retry_timestamp()
local function default_get_retry_timestamp(message)
    return os.time() + 600
end
-- }}}

-- {{{ slimta.queue.new()
function slimta.queue.new(edge_bus, relay_bus, get_retry_timestamp, lock_duration)
    local self = {}
    setmetatable(self, slimta.queue)

    self.edge_bus = edge_bus
    self.relay_bus = relay_bus
    self.get_retry_timestamp = get_retry_timestamp or default_get_retry_timestamp
    self.lock_duration = lock_duration or 120

    return self
end
-- }}}

-- {{{ slimta.queue:get_retry_messages()
function slimta.queue:get_retry_messages(storage, timestamp)
    local message_ids, err = storage:get_retry_queue(timestamp)
    if err then
        error(err)
    end

    local messages = {}
    for i=1, message_ids.n do
        local id = message_id[i]
        if id then
            local msg = slimta.message.load(storage, id)
            if not msg then
                storage:remove_message(id)
            else
                table.insert(messages, msg)
            end
        end
    end

    return messages
end
-- }}}

-- {{{ slimta.queue:try_relay()
function slimta.queue:try_relay(message, storage)
    if storage and not storage:lock_message(message.id, self.lock_duration) then
        return false, "locked"
    end

    local transaction = self.relay_bus:send_request({message})
    local responses = transaction:recv_response()

    if storage then
        storage:unlock_message(message.id)
    end

    return responses[1]
end
-- }}}

-- {{{ queue_thread_meta:store()
function queue_thread_meta:store(storage)
    local errs = {n=#self.messages}

    local responses = {}
    for i, msg in ipairs(self.messages) do
        local id, err = msg:store(storage)
        errs[i] = err

        if not id then
            responses[i] = slimta.message.response.new(
                "450",
                ("Message queuing failed: %s"):format(err),
                err
            )
        else
            responses[i] = slimta.message.response.new(
                "250",
                ("Message queued as %s"):format(id),
                id
            )
        end
    end

    self.transaction:send_response(responses)
end
-- }}}

-- {{{ queue_thread_meta:relay()
function queue_thread_meta:relay(storage)
    for i, message in ipairs(self.messages) do
        if storage:lock_message(message.id, self.queue.lock_duration) then
            local response = self.queue:try_relay(message)
            local code_type = response and response.code:sub(1, 1)

            if code_type == '2' then
                storage:remove_message(message.id)
            else -- if code_type == '4' then
                message.attempts = message.attempts + 1
                local next_retry = self.queue.get_retry_timestamp(message)
                storage:set_message_retry(message.id, next_retry)
                storage:unlock_message(message.id)
            end
        end
    end
end
-- }}}

-- {{{ queue_thread_meta:__call()
function queue_thread_meta:__call(storage)
    self:store(storage)
    if self.queue.relay_bus then
        self:relay(storage)
    end

    storage:close()
end
-- }}}

-- {{{ slimta.queue:accept()
function slimta.queue:accept()
    local transaction, messages = self.edge_bus:recv_request()

    local queue_thread = {
        messages = messages,
        transaction = transaction,
        queue = self,
    }
    setmetatable(queue_thread, queue_thread_meta)

    return queue_thread
end
-- }}}

return slimta.queue

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
