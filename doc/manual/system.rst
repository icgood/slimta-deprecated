
System Helpers
==============

.. toctree::
   :hidden:

Long-running applications usually require some special tricks for management and
secuirty. Many of these things are available in other Lua libraries, *slimta*
simply includes some of the more important ones to avoid extra dependencies.
None of the system helpers are required.

Daemonization
"""""""""""""

Running *slimta* in the background as a daemon is relatively easy::

   local pid = slimta.daemonize()

:func:`slimta.daemonize()` can be described with the following pseudo-code::

   fork()
   setsid()
   fork()
   chdir("/")
   umask(0)

   close(stdin)
   close(stdout)
   close(stderr)

   stdin = open("/dev/null")
   stdout = open("/dev/null")
   stderr = open("/dev/null")

   setsid()
   return getpid()

Often it is desired to still have access to standard I/O streams. To redirect
them after daemonization, use :func:`slimta.redirect_stdio()`.

Dropping System Privileges
""""""""""""""""""""""""""

Most ports that *slimta* systems will often need to open require root
privileges, such as port 25. However, once these sockets are open, there is
little reason to retain those privileges.

A call to :func:`slimta.drop_privileges()` is *highly* recommended after opening
all ports, if running *slimta* as root.

UUID Generation
"""""""""""""""

Linux systems with the ``util-linux`` package support ``libuuid`` and the
``uuid_generate()`` function. They are the basis for :mod:`slimta.uuid`, which
is used throughout *slimta*. The specific dependency on Linux is very much
undesirable, and should be fixed ASAP.

Signalfd
""""""""

Another specific feature of Linux systems is :mod:`slimta.signalfd`. Functions
and objects in this module correspond closely to the correlating system calls,
so more information about them is available in the man pages.

The reason ``signalfd`` is included, however, is to make signal handling cheap
and easy in a way that fits the *slimta* and *ratchet* thread paradigms.

If a developer wanted to allow config-reloading with ``SIGHUP``, as well as safe
process termination with ``SIGINT`` or ``SIGTERM``, they might attach a thread
like the following::

   function catch_signals()
       local mask = slimta.signalfd.mask({"SIGHUP", "SIGINT", "SIGTERM"})
       slimta.signalfd.sigprocmask("block", mask)
       local sfd = slimta.signalfd.new()
       sfd:setmask(mask)

       while true do
           local sig, sender_pid = sfd:read()
           if sig == "SIGHUP" then
               reload_configs()
           elseif sig == "SIGINT" or sig == "SIGTERM" then
               print("Process terminating...")
               os.exit(0)
           end
       end
   end

