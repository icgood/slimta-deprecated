
--------------------------------------------------------------------------------
-- {{{ Global configuration options.

config.socket.send_size.func = function (socket)
    -- socket(7) option SO_SNDBUF returns double the desired value.
    return socket.SO_SNDBUF / 2
end

config.dns.a_queries.value = {"ipv6", "ipv4"}

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Load up storage engines that will be used.
require "modules.engines.storage.couchdb"

config.modules.engines.storage.couchdb.uri.value = "tcp://slimta2:5984"

config.modules.engines.storage.couchdb.queue.value = "queue"

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- {{{ Setup SSL Encryption.

ssl = ratchet.ssl.new(ratchet.ssl.SSLv3)
ssl:load_cas("/etc/ssl/certs")

-- }}} -------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- vim:foldmethod=marker:filetype=lua:sw=4:ts=4:sts=4:et:
