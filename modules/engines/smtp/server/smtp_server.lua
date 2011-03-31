
local smtp_io = require "modules.engines.smtp.smtp_io"
local smtp_extensions = require "modules.engines.smtp.smtp_extensions"

local smtp_server = {}
smtp_server.__index = smtp_server
smtp_server.commands = {}

-- {{{ smtp_server.new()
function smtp_server.new(socket, from_ip, handlers, max_size)
    local self = {}
    setmetatable(self, smtp_server)

    self.from_ip = from_ip
    self.handlers = handlers
    self.io = smtp_io.new(socket)

    self.extensions = smtp_extensions.new()
    self.extensions:add("PIPELINING")
    self.extensions:add("ENHANCEDSTATUSCODES")
    if max_size then
        self.extensions:add("SIZE", tostring(max_size))
    end

    return self
end
-- }}}

-- {{{ smtp_server:send_ESC_reply()
function smtp_server:send_ESC_reply(code, message, esc)
    local code_class = code:sub(1, 1)

    if code_class == "2" or code_class == "4" or code_class == "5" then
        -- If no Enhanced-Status-Code was given, use empty string.
        if not esc then
            esc = ""
        end

        -- Match E-S-C, and set defaults on non-match.
        local subject, detail = esc:match("^[245]%.(%d%d?%d?)%.(%d%d?%d?)$")
        if not subject then
            subject, detail = "0", "0"
        end

        -- Build E-S-C.
        esc = code_class .. "." .. subject .. "." .. detail

        -- Prefix E-S-C at the beginning of contiguous lines.
        message = esc .. " " .. message:gsub("(%\r?%\n)", "%0"..esc.." ")
    end

    self.io:send_reply(code, message)
end
-- }}}

-- {{{ Generic error responses

-- {{{ smtp_server:unknown_command()
function smtp_server:unknown_command(command, arg)
    self:send_ESC_reply("500", "Syntax error, command unrecognized", "5.5.2")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:unknown_parameter()
function smtp_server:unknown_parameter(command, arg)
    self:send_ESC_reply("504", "Command parameter not implemented", "5.5.4")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_sequence()
function smtp_server:bad_sequence(command, arg)
    self:send_ESC_reply("503", "Bad sequence of commands", "5.5.1")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_arguments()
function smtp_server:bad_arguments(command, arg)
    self:send_ESC_reply("501", "Syntax error in parameters or arguments", "5.5.4")
    self.io:flush_send()
end
-- }}}

-- }}}

-- {{{ Built-in Commands

-- {{{ smtp_server.commands.BANNER()
function smtp_server.commands.BANNER(self)
    local code, message = "220", "Banner"
    if self.handlers.BANNER then
        code, message = self.handlers:BANNER()
    end

    self.io:send_reply(code, message)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.EHLO()
function smtp_server.commands.EHLO(self, ehlo_as)
    local code, greeting = "250", "Hello " .. ehlo_as
    if self.handlers.EHLO then
        code, greeting = self.handlers:EHLO(ehlo_as)
    end

    local message = greeting
    if code == "250" then
        message = self.extensions:build_string(greeting)
    end
    self.io:send_reply(code, message)
    self.io:flush_send()

    self.ehlo_as = ehlo_as
end
-- }}}

-- {{{ smtp_server.commands.HELO()
function smtp_server.commands.HELO(self, ehlo_as)
    local code, greeting = "250", "Hello " .. ehlo_as
    if self.handlers.EHLO then
        code, greeting = self.handlers:EHLO(ehlo_as)
    end

    self.io:send_reply(code, greeting)
    self.io:flush_send()

    self.extensions:reset()
    self.ehlo_as = ehlo_as
end
-- }}}

-- {{{ smtp_server.commands.STARTTLS()
function smtp_server.commands.STARTTLS(self, arg)
    if not self.extensions:has("STARTTLS") then
        return self:unknown_command("STARTTLS", arg)
    end

    if not self.ehlo_as then
        return self:bad_sequence("STARTTLS", arg)
    end

    local code, message, esc = "220", "Go ahead", "2.7.0"
    if self.handlers.STARTTLS then
        code, message, esc = self.handlers:STARTTLS()
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()

    local enc = self.io.socket:encrypt(ssl.TLSv1)
    enc:server_handshake()

    self.extensions:drop("STARTTLS")
    self.ehlo_as = nil
end
-- }}}

-- {{{ smtp_server.commands.RSET()
function smtp_server.commands.RSET(self, arg)
    if #arg > 0 then
        return self:bad_arguments("RSET", arg)
    end

    local code, greeting, esc = "250", "Ok"
    if self.handlers.RSET then
        code, greeting, esc = self.handlers:RSET()
    end

    self:send_ESC_reply(code, greeting, esc)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.NOOP()
function smtp_server.commands.NOOP(self)
    local code, greeting, esc = "250", "Ok"
    if self.handlers.NOOP then
        code, greeting, esc = self.handlers:NOOP()
    end

    self:send_ESC_reply(code, greeting, esc)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.QUIT()
function smtp_server.commands.QUIT(self, arg)
    if #arg > 0 then
        return self:bad_arguments("QUIT", arg)
    end

    local code, greeting, esc = "221", "Bye"
    if self.handlers.QUIT then
        code, greeting, esc = self.handlers:QUIT()
    end

    self:send_ESC_reply(code, greeting, esc)
    self.io:flush_send()
    self.io:close()
end
-- }}}

-- }}}

-- {{{ smtp_server:__call()
function smtp_server:__call()
    self.commands.BANNER(self)

    repeat
        local command, arg = self.io:recv_command()
        if self.commands[command] then
            self.commands[command](self, arg)
        elseif self.handlers[command] then
            self.handlers[command](self.handlers, arg, io)
        else
            self:unknown_command(command, arg)
        end
    until command == "QUIT"
end
-- }}}

return smtp_server

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
