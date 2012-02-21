
require "slimta"
require "slimta.message"

slimta.queue = {}
slimta.queue.__index = slimta.queue

local queue_thread_meta = {}
queue_thread_meta.__index = queue_thread_meta

-- {{{ default_retry_algorithm()
local function default_retry_algorithm()
    return nil
end
-- }}}

-- {{{ slimta.queue.new()
function slimta.queue.new(edge_bus, relay_bus, storage)
    local self = {}
    setmetatable(self, slimta.queue)

    self.edge_bus = edge_bus
    self.relay_bus = relay_bus
    self.storage = storage
    self.retry_algorithm = default_retry_algorithm
    self.bounce_builder = slimta.message.bounce.new()
    self.lock_duration = 120

    return self
end
-- }}}

-- {{{ slimta.queue:set_retry_algorithm()
function slimta.queue:set_retry_algorithm(func)
    self.retry_algorithm = func
end
-- }}}

-- {{{ slimta.queue:set_bounce_builder()
function slimta.queue:set_bounce_builder(new)
    self.bounce_builder = new
end
-- }}}

-- {{{ slimta.queue:set_lock_duration()
function slimta.queue:set_lock_duration(new)
    self.lock_duration = new
end
-- }}}

-- {{{ load_messages_from_ids()
local function load_messages_from_ids(storage_session, ids)
    local invalids = {}
    local messages = {}
    local n = ids.n or #ids
    for i=1, n do
        local id = ids[i]
        if id then
            local msg = slimta.message.load(storage_session, id)
            if not msg then
                table.insert(invalids, id)
            else
                table.insert(messages, msg)
            end
        end
    end

    return messages, invalids
end
-- }}}

-- {{{ slimta.queue:get_deferred_messages()
function slimta.queue:get_deferred_messages(storage_session, timestamp)
    local message_ids, err = storage_session:get_deferred_messages(timestamp)
    if err then
        error(err)
    end

    local messages, invalids = load_messages_from_ids(storage_session, message_ids)
    for i, id in ipairs(invalids) do
        storage_session:delete_message(id)
    end

    return messages
end
-- }}}

-- {{{ slimta.queue:get_all_messages()
function slimta.queue:get_all_messages(storage_session)
    local message_ids, err = storage_session:get_all_messages()
    if err then
        error(err)
    end

    return load_messages_from_ids(storage_session, message_ids)
end
-- }}}

-- {{{ slimta.queue:try_relay()
function slimta.queue:try_relay(message, storage_session)
    if storage_session and not storage_session:lock_message(message.id, self.lock_duration) then
        return false, "locked"
    end

    local transaction = self.relay_bus:send_request({message})
    local responses = transaction:recv_response()

    if storage_session then
        storage_session:unlock_message(message.id)
    end

    return responses[1]
end
-- }}}

-- {{{ queue_thread_meta:store()
function queue_thread_meta:store()
    local errs = {n=#self.messages}
    local storage_session = self.queue.storage:connect()

    local responses = {}
    for i, msg in ipairs(self.messages) do
        local id, err = msg:store(storage_session)
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

    storage_session:close()

    if self.transaction then
        self.transaction:send_response(responses)
    end
end
-- }}}

-- {{{ fail_message()
local function fail_message(self, storage_session, message, response)
    local bounce = self.queue.bounce_builder:build(message, response)
    local id = bounce:store(storage_session)
    storage_session:set_message_retry(id, os.time())
    storage_session:delete_message(message.id)
end
-- }}}

-- {{{ retry_message()
local function retry_message(self, storage_session, message, response)
    message.attempts = message.attempts + 1
    local next_retry = self.queue.retry_algorithm(message)
    if next_retry then
        message:flush(storage_session)
        storage_session:set_message_retry(message.id, next_retry)
        storage_session:unlock_message(message.id)
    else
        response.message = response.message .. " (Too many retries)"
        fail_message(self, storage_session, message, response) 
    end
end
-- }}}

-- {{{ queue_thread_meta:relay()
function queue_thread_meta:relay()
    local storage_session = self.queue.storage:connect()

    for i, message in ipairs(self.messages) do
        if storage_session:lock_message(message.id, self.queue.lock_duration) then
            local response = self.queue:try_relay(message)
            local code_type = response and response.code:sub(1, 1)

            if code_type == '2' then
                storage_session:delete_message(message.id)
            elseif code_type == '4' then
                retry_message(self, storage_session, message, response) 
            else
                fail_message(self, storage_session, message, response) 
            end
        end
    end

    storage_session:close()
end
-- }}}

-- {{{ queue_thread_meta:__call()
function queue_thread_meta:__call()
    if not self.retry_attempt then
        self:store()
    end

    if self.queue.relay_bus then
        self:relay()
    end
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

-- {{{ slimta.queue:retry()
function slimta.queue:retry()
    local storage_session = self.storage:connect()

    local now = os.time()
    local message_ids = storage_session:get_deferred_messages(now)
    if not message_ids[1] then
        storage_session:close()
        return nil
    end

    local messages = load_messages_from_ids(storage_session, message_ids)

    storage_session:close()

    local queue_thread = {
        messages = messages,
        retry_attempt = true,
        queue = self,
    }
    setmetatable(queue_thread, queue_thread_meta)

    return queue_thread
end
-- }}}

return slimta.queue

-- vim:et:fdm=marker:sts=4:sw=4:ts=4
