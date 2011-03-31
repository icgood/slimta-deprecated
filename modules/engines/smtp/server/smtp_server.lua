
-- {{{ find_outside_quotes()
local function find_outside_quotes(haystack, needle, i)
    local needle_where = haystack:find(needle, i, true)
    if not needle_where then
        return
    end

    local start_quote = haystack:find("\"", i, true)
    if not start_quote or start_quote > needle_where then
        return needle_where
    end

    local end_quote = haystack:find("\"", start_quote+1, true)
    if end_quote then
        if end_quote > needle_where then
            return find_outside_quotes(haystack, needle, end_quote+1)
        else
            return find_outside_quotes(haystack, needle, needle_where+1)
        end
    end
end
-- }}}

local data_reader = require "modules.engines.smtp.server.data_reader"
local smtp_io = require "modules.engines.smtp.smtp_io"
local smtp_extensions = require "modules.engines.smtp.smtp_extensions"

local smtp_server = {}
smtp_server.__index = smtp_server
smtp_server.commands = {}

-- {{{ smtp_server.new()
function smtp_server.new(socket, from_ip, handlers)
    local self = {}
    setmetatable(self, smtp_server)

    self.from_ip = from_ip
    self.handlers = handlers
    self.io = smtp_io.new(socket)

    self.extensions = smtp_extensions.new()
    self.extensions:add("PIPELINING")
    self.extensions:add("ENHANCEDSTATUSCODES")

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

-- {{{ smtp_server:get_message_data()
function smtp_server:get_message_data()
    local max_size = tonumber(self.extensions:has("SIZE"))
    local reader = data_reader.new(self.io, max_size)

    local data, err = reader:recv()

    code, message, esc = "250", "Message Accepted for Delivery", "2.6.0"
    if self.handlers.HAVE_DATA then
        code, message, esc = self.handlers:HAVE_DATA(data, err)
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()
end
-- }}}

-- {{{ Generic error responses

-- {{{ smtp_server:unknown_command()
function smtp_server:unknown_command(command, arg, message)
    self:send_ESC_reply("500", message or "Syntax error, command unrecognized", "5.5.2")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:unknown_parameter()
function smtp_server:unknown_parameter(command, arg, message)
    self:send_ESC_reply("504", message or "Command parameter not implemented", "5.5.4")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_sequence()
function smtp_server:bad_sequence(command, arg, message)
    self:send_ESC_reply("503", message or "Bad sequence of commands", "5.5.1")
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_arguments()
function smtp_server:bad_arguments(command, arg, message)
    self:send_ESC_reply("501", message or "Syntax error in parameters or arguments", "5.5.4")
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

    -- Add extensions, if success code.
    if code == "250" then
        message = self.extensions:build_string(greeting)
    else
        message = greeting
    end

    self.io:send_reply(code, message)
    self.io:flush_send()

    if code == "250" then
        self.have_mailfrom = nil
        self.have_rcptto = nil

        self.ehlo_as = ehlo_as
    end
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

    if code == "250" then
        self.have_mailfrom = nil
        self.have_rcptto = nil

        self.extensions:reset()
        self.ehlo_as = ehlo_as
    end
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

    if code == "220" then
        local enc = self.io.socket:encrypt(ssl.TLSv1)
        enc:server_handshake()

        self.extensions:drop("STARTTLS")
        self.ehlo_as = nil
    end
end
-- }}}

-- {{{ smtp_server.commands.MAIL()
function smtp_server.commands.MAIL(self, arg)
    -- Ensure the syntax of the FROM:<address> arg portion.
    local start_address = arg:match("^[fF][rR][oO][mM]%:%s*%<()")
    if not start_address then
        return self:bad_arguments("MAIL", arg)
    end

    local end_address = find_outside_quotes(arg, ">", start_address)
    if not end_address then
        return self:bad_arguments("MAIL", arg)
    end

    local address = arg:sub(start_address, end_address-1)

    -- Ensure after an EHLO/HELO.
    if not self.ehlo_as then
        return self:bad_sequence("MAIL", arg)
    end

    -- Ensure not already in a mail transaction.
    if self.have_mailfrom then
        return self:bad_sequence("MAIL", arg)
    end

    -- Check for SIZE=NNNN parameter, and process if SIZE extension is enabled.
    local size = arg:match("%s[sS][iI][zZ][eE]%=(%d+)", end_address+1)
    if size then
        local max_size = self.extensions:has("SIZE")
        if max_size then
            if tonumber(size) > tonumber(max_size) then
                self:send_ESC_reply("552", "Message size exceeds "..max_size.." limit", "5.3.4")
                self.io:flush_send()
                return
            end
        else
            return self:unknown_parameter("MAIL", arg)
        end
    end

    -- Normal handling of command based on address.
    local code, message, esc = "250", "Sender <"..address.."> Ok", "2.1.0"
    if self.handlers.MAIL then
        code, message, esc = self.handlers:MAIL(address)
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()

    self.have_mailfrom = self.have_mailfrom or (code == "250")
end
-- }}}

-- {{{ smtp_server.commands.RCPT()
function smtp_server.commands.RCPT(self, arg)
    -- Ensure the syntax of the TO:<address> arg portion.
    local start_address = arg:match("^[tT][oO]%:%s*%<()")
    if not start_address then
        return self:bad_arguments("RCPT", arg)
    end

    local end_address = find_outside_quotes(arg, ">", start_address)
    if not end_address then
        return self:bad_arguments("RCPT", arg)
    end

    local address = arg:sub(start_address, end_address-1)

    -- Ensure already in a mail transaction.
    if not self.have_mailfrom then
        return self:bad_sequence("RCPT", arg)
    end

    -- Normal handling of command based on address.
    local code, message, esc = "250", "Recipient <"..address.."> Ok", "2.1.5"
    if self.handlers.RCPT then
        code, message, esc = self.handlers:RCPT(address)
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()

    self.have_rcptto = self.have_rcptto or (code == "250")
end
-- }}}

-- {{{ smtp_server.commands.DATA()
function smtp_server.commands.DATA(self, arg)
    if #arg > 0 then
        return self:bad_arguments("DATA", arg)
    end

    if not self.have_mailfrom then
        return self:bad_sequence("DATA", arg, "No valid sender given")
    elseif not self.have_rcptto then
        return self:bad_sequence("DATA", arg, "No valid recipients given")
    end

    local code, message, esc = "354", "Start mail input; end with <CRLF>.<CRLF>"
    if self.handlers.DATA then
        code, message, esc = self.handlers:DATA()
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()

    if code == "354" then
        self:get_message_data()
    end
end
-- }}}

-- {{{ smtp_server.commands.RSET()
function smtp_server.commands.RSET(self, arg)
    if #arg > 0 then
        return self:bad_arguments("RSET", arg)
    end

    local code, message, esc = "250", "Ok"
    if self.handlers.RSET then
        code, message, esc = self.handlers:RSET()
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()

    if code == "250" then
        self.have_mailfrom = nil
        self.have_rcptto = nil
    end
end
-- }}}

-- {{{ smtp_server.commands.NOOP()
function smtp_server.commands.NOOP(self)
    local code, message, esc = "250", "Ok"
    if self.handlers.NOOP then
        code, message, esc = self.handlers:NOOP()
    end

    self:send_ESC_reply(code, message, esc)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.QUIT()
function smtp_server.commands.QUIT(self, arg)
    if #arg > 0 then
        return self:bad_arguments("QUIT", arg)
    end

    local code, message, esc = "221", "Bye"
    if self.handlers.QUIT then
        code, message, esc = self.handlers:QUIT()
    end

    self:send_ESC_reply(code, message, esc)
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
