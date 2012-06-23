
require "ratchet"

require "slimta.message"
require "slimta.policies.spamassassin"

spamd_host = "localhost"
spamd_port = 783

-- {{{ spam_message
-- GTUBE, http://spamassassin.apache.org/gtube/
spam_message = [[
Subject: Test spam mail (GTUBE)
Message-ID: <GTUBE1.1010101@slimta.org>
Date: Wed, 23 Jul 2003 23:30:00 +0200
From: Sender <sender@slimta.org>
To: Recipient <recipient@slimta.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X
]]
-- }}}

-- {{{ ham_message
ham_message = [[
Subject: Test ham mail
Message-ID: <MAIL1.1010101@slimta.org>
Date: Wed, 23 Jul 2003 23:30:00 +0200
From: Sender <sender@slimta.org>
To: Recipient <recipient@slimta.org>
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit

This is a legitimate, useful message!
]]
-- }}}

function scan_message()
    local client = slimta.message.client.new("SMTP", "testing")
    local envelope = slimta.message.envelope.new("sender@slimta.org", {"recipient@slimta.org"})
    local spam_data = slimta.message.contents.new(spam_message)
    local ham_data = slimta.message.contents.new(ham_message)

    local spam_message = slimta.message.new(client, envelope, spam_data)
    local ham_message = slimta.message.new(client, envelope, ham_data)

    local spamassassin = slimta.policies.spamassassin.new(spamd_host, spamd_port)

    if not pcall(spamassassin.scan, spamassassin, spam_message) then
        io.stderr:write("WARNING: Could not connect to spamassassin, skipping test.\n")
        os.exit(77)
    end
    assert(spam_message.spammy)

    if not pcall(spamassassin.scan, spamassassin, ham_message) then
        io.stderr:write("WARNING: Could not connect to spamassassin, skipping test.\n")
        os.exit(77)
    end
    assert(not ham_message.spammy)

end

kernel = ratchet.new(function ()
    ratchet.thread.attach(scan_message)
end)
kernel:loop()

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
