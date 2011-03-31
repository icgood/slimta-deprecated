
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
function smtp_server.new(socket, handlers)
    local self = {}
    setmetatable(self, smtp_server)

    self.handlers = handlers
    self.io = smtp_io.new(socket)

    self.extensions = smtp_extensions.new()
    self.extensions:add("8BITMIME")
    self.extensions:add("PIPELINING")
    self.extensions:add("ENHANCEDSTATUSCODES")

    return self
end
-- }}}

-- {{{ smtp_server:send_ESC_reply()
function smtp_server:send_ESC_reply(reply)
    local code, message, esc = reply.code, reply.message, reply.enhanced_status_code
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

    local reply = {
        code = "250",
        message = "Message Accepted for Delivery",
        enhanced_status_code = "2.6.0"
    }

    if self.handlers.HAVE_DATA then
        self.handlers:HAVE_DATA(reply, data, err)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:close()
function smtp_server:close()
    if self.handlers.CLOSE then
        self.handlers:CLOSE()
    end
    self.io:close()
end
-- }}}

-- {{{ Generic error responses

-- {{{ smtp_server:unknown_command()
function smtp_server:unknown_command(command, arg, message)
    local reply = {
        code = "500",
        message = message or "Syntax error, command unrecognized",
        enhanced_status_code = "5.5.2",
    }
    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:unknown_parameter()
function smtp_server:unknown_parameter(command, arg, message)
    local reply = {
        code = "504",
        message = message or "Command parameter not implemented",
        enhanced_status_code = "5.5.4",
    }
    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_sequence()
function smtp_server:bad_sequence(command, arg, message)
    local reply = {
        code = "503",
        message = message or "Bad sequence of commands",
        enhanced_status_code = "5.5.1",
    }
    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server:bad_arguments()
function smtp_server:bad_arguments(command, arg, message)
    local reply = {
        code = "501",
        message = message or "Syntax error in parameters or arguments",
        enhanced_status_code = "5.5.4",
    }
    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- }}}

-- {{{ Built-in Commands

-- {{{ smtp_server.commands.BANNER()
function smtp_server.commands.BANNER(self)
    local reply = {
        code = "220",
        message = "ESMTP Welcome to slimta " .. slimta.version,
    }

    if self.handlers.BANNER then
        self.handlers:BANNER(reply)
    end

    self.io:send_reply(reply.code, reply.message)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.EHLO()
function smtp_server.commands.EHLO(self, ehlo_as)
    local reply = {
        code = "250",
        message = "Hello " .. ehlo_as,
    }

    if self.handlers.EHLO then
        self.handlers:EHLO(reply, ehlo_as)
    end

    -- Add extensions, if success code.
    if reply.code == "250" then
        reply.message = self.extensions:build_string(reply.message)
    end

    self.io:send_reply(reply.code, reply.message)
    self.io:flush_send()

    if reply.code == "250" then
        self.have_mailfrom = nil
        self.have_rcptto = nil

        self.ehlo_as = ehlo_as
    end
end
-- }}}

-- {{{ smtp_server.commands.HELO()
function smtp_server.commands.HELO(self, ehlo_as)
    local reply = {
        code = "250",
        message = "Hello " .. ehlo_as,
    }

    if self.handlers.EHLO then
        self.handlers:EHLO(reply, ehlo_as)
    end

    self.io:send_reply(reply.code, reply.greeting)
    self.io:flush_send()

    if reply.code == "250" then
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

    local reply = {
        code = "220",
        message = "Go ahead",
        enhanced_status_code = "2.7.0"
    }

    if self.handlers.STARTTLS then
        self.handlers:STARTTLS(reply)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    if reply.code == "220" then
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
                local reply = {
                    code = "552",
                    message = "Message size exceeds "..max_size.." limit",
                    enhanced_status_code = "5.3.4"
                }
                self:send_ESC_reply(reply)
                self.io:flush_send()
                return
            end
        else
            return self:unknown_parameter("MAIL", arg)
        end
    end

    -- Normal handling of command based on address.
    local reply = {
        code = "250",
        message = "Sender <"..address.."> Ok",
        enhanced_status_code = "2.1.0"
    }

    if self.handlers.MAIL then
        self.handlers:MAIL(reply, address)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    self.have_mailfrom = self.have_mailfrom or (reply.code == "250")
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
    local reply = {
        code = "250",
        message = "Recipient <"..address.."> Ok",
        enhanced_status_code = "2.1.5"
    }

    if self.handlers.RCPT then
        self.handlers:RCPT(reply, address)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    self.have_rcptto = self.have_rcptto or (reply.code == "250")
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

    local reply = {
        code = "354",
        message = "Start mail input; end with <CRLF>.<CRLF>",
    }

    if self.handlers.DATA then
        self.handlers:DATA(reply)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    if reply.code == "354" then
        self:get_message_data()
    end
end
-- }}}

-- {{{ smtp_server.commands.RSET()
function smtp_server.commands.RSET(self, arg)
    if #arg > 0 then
        return self:bad_arguments("RSET", arg)
    end

    local reply = {
        code = "250",
        message = "Ok",
    }

    if self.handlers.RSET then
        self.handlers:RSET(reply)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    if reply.code == "250" then
        self.have_mailfrom = nil
        self.have_rcptto = nil
    end
end
-- }}}

-- {{{ smtp_server.commands.NOOP()
function smtp_server.commands.NOOP(self)
    local reply = {
        code = "250",
        message = "Ok",
    }

    if self.handlers.NOOP then
        self.handlers:NOOP(reply)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()
end
-- }}}

-- {{{ smtp_server.commands.QUIT()
function smtp_server.commands.QUIT(self, arg)
    if #arg > 0 then
        return self:bad_arguments("QUIT", arg)
    end

    local reply = {
        code = "221",
        message = "Bye",
    }

    if self.handlers.QUIT then
        self.handlers:QUIT(reply)
    end

    self:send_ESC_reply(reply)
    self.io:flush_send()

    self:close()
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
