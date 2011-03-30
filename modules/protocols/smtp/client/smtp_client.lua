
local smtp_io = require "modules.protocols.smtp.smtp_io"
local smtp_extensions = require "modules.protocols.smtp.smtp_extensions"
local smtp_reply = require "modules.protocols.smtp.smtp_reply"
local data_sender = require "modules.protocols.smtp.client.data_sender"

local smtp_client = {}
smtp_client.__index = smtp_client

-- {{{ smtp_client.new()
function smtp_client.new(socket)
    local self = {}
    setmetatable(self, smtp_client)

    self.io = smtp_io.new(socket)
    self.extensions = smtp_extensions.new()

    self.recv_queue = {}

    return self
end
-- }}}

-- {{{ smtp_client:recv_batch()
function smtp_client:recv_batch()
    self.io:flush_send()

    repeat
        local reply = table.remove(self.recv_queue, 1)
        if reply then
            reply:recv(self.io)
        end
    until not reply
end
-- }}}

-- {{{ smtp_client:get_banner()
function smtp_client:get_banner()
    local banner = smtp_reply.new()
    table.insert(self.recv_queue, banner)

    self:recv_batch()

    return banner
end
-- }}}

-- {{{ smtp_client:ehlo()
function smtp_client:ehlo(ehlo_as)
    local ehlo = smtp_reply.new()
    table.insert(self.recv_queue, ehlo)

    local command = "EHLO " .. ehlo_as
    self.io:send_command(command)

    self:recv_batch()
    if ehlo.code == "250" then
        self.extensions:reset()
        self.extensions:parse_string(ehlo.message)
    end

    return ehlo
end
-- }}}

-- {{{ smtp_client:helo()
function smtp_client:helo(helo_as)
    local ehlo = smtp_reply.new()
    table.insert(self.recv_queue, ehlo)

    local command = "HELO " .. helo_as
    self.io:send_command(command)

    self:recv_batch()

    return ehlo
end
-- }}}

-- {{{ smtp_client:starttls()
function smtp_client:starttls()
    local starttls = smtp_reply.new()
    table.insert(self.recv_queue, starttls)

    local command = "STARTTLS"
    self.io:send_command(command)

    self:recv_batch()

    return starttls
end
-- }}}

-- {{{ smtp_client:mailfrom()
function smtp_client:mailfrom(address, data_size)
    local mailfrom = smtp_reply.new()
    table.insert(self.recv_queue, mailfrom)

    local command = "MAIL FROM:<"..address..">"
    if data_size and self.extensions:has("SIZE") then
        command = command .. " SIZE=" .. data_size
    end
    self.io:send_command(command)

    if not self.extensions:has("PIPELINING") then
        self:recv_batch()
    end

    return mailfrom
end
-- }}}

-- {{{ smtp_client:rcptto()
function smtp_client:rcptto(address)
    local rcptto = smtp_reply.new()
    table.insert(self.recv_queue, rcptto)

    local command = "RCPT TO:<"..address..">"
    self.io:send_command(command)

    if not self.extensions:has("PIPELINING") then
        self:recv_batch()
    end

    return rcptto
end
-- }}}

-- {{{ smtp_client:data()
function smtp_client:data()
    local data = smtp_reply.new()
    table.insert(self.recv_queue, data)

    local command = "DATA"
    self.io:send_command(command)

    self:recv_batch()

    return data
end
-- }}}

-- {{{ smtp_client:send_data()
function smtp_client:send_data(data)
    local send_data = smtp_reply.new()
    table.insert(self.recv_queue, send_data)

    local data_sender = data_sender.new(data)
    data_sender:send(self.io)

    self:recv_batch()

    return send_data
end
-- }}}

-- {{{ smtp_client:send_empty_data()
function smtp_client:send_empty_data()
    local send_data = smtp_reply.new()
    table.insert(self.recv_queue, send_data)

    self.io:send_command(".")

    self:recv_batch()

    return send_data
end
-- }}}

-- {{{ smtp_client:rset()
function smtp_client:rset()
    local rset = smtp_reply.new()
    table.insert(self.recv_queue, rset)

    local command = "RSET"
    self.io:send_command(command)

    self:recv_batch()

    return send_data
end
-- }}}

-- {{{ smtp_client:quit()
function smtp_client:quit()
    local quit = smtp_reply.new()
    table.insert(self.recv_queue, quit)

    local command = "QUIT"
    self.io:send_command(command)

    self:recv_batch()
    self.io:close()

    return quit
end
-- }}}

return smtp_client

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
