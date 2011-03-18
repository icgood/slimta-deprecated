
--------------------------------------------------------------------------------
-- {{{ Setup all channels.

-- URI to which requests are made to slimrelay to attempt immediate delivery.
local relay_request_uri = "zmq:push:tcp://127.0.0.1:5544"

-- Channel on which new messages arrive from slimedge for queuing.
queue_request_context.new("zmq:rep:tcp://127.0.0.1:4554", relay_request_uri)

-- Channel on which delivery attempt results are received from slimrelay.
relay_results_context.new("zmq:pull:tcp://127.0.0.1:4455")

-- Channel which regularly polls the storage engines for messages that are
-- due for immediate retrying. The first argument is the number of seconds to
-- wait between each poll.
attempt_timer_context.new(5, relay_request_uri)

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup storage engine usage logic.

-- {{{ config.queue.which_storage
config.queue.which_storage.value = "couchdb"
-- }}}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup nexthop handling.

require "modules.engines.nexthop.mx"

-- {{{ config.queue.which_nexthop
config.queue.which_nexthop.value = "mx"
-- }}}

-- {{{ config.modules.engines.nexthop.mx.pick_one
config.modules.engines.nexthop.mx.pick_one.func = function (mxs, attempts)
    -- Cycle to a new MX every NN attempts, looping back to the first
    -- one after all have been tried. Return values must start at 1.
    local next_mx_every_NN = 4

    return math.fmod(math.floor(attempts/next_mx_every_NN), mxs.n) + 1
end
-- }}}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup failure handling.

require "modules.engines.failure.bounce"

-- {{{ config.queue.which_failure
config.queue.which_failure.value = "bounce"
-- }}}

-- {{{ config.modules.engines.failure.bounce.request_uri
config.modules.engines.failure.bounce.request_uri = "zmq:req:tcp://127.0.0.1:4554"
-- }}}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup next-attempt logic.

require "modules.engines.attempting.linear"

-- {{{ config.queue.which_attempting
config.queue.which_attempting.value = "linear"
-- }}}

-- {{{ config.modules.engines.attempting.linear.seconds
config.modules.engines.attempting.linear.seconds.value = 5
-- }}}

-- {{{ config.modules.engines.attempting.linear.retries
config.modules.engines.attempting.linear.retries.value = 5
-- }}}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:filetype=lua:sw=4:ts=4:sts=4:et:
