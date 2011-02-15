local httpmail_context = require "httpmail_context"

local httpmail_channel_str = get_conf.string(httpmail_channel)

uri:register("tcp", ratchet.socket.parse_tcp_uri)
uri:register("zmq", ratchet.zmqsocket.parse_uri)

local httpmail = httpmail_context.new(httpmail_channel_str)

kernel:attach(httpmail)

local function on_error(err)
    print("ERROR: " .. tostring(err))
end
kernel:set_error_handler(on_error)

kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
