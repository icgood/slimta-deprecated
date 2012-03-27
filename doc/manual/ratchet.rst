
Ratchet Library
===============

.. toctree::
   :hidden:

Installation and Basics
"""""""""""""""""""""""

First off, check out the *ratchet* website at http://ratchet.icgood.net. It has
all the latest installation details, and documentation far superior to what
you'll find here.

*Ratchet* is a required dependency of *slimta*. Include it before *slimta*, like
so::

   require "ratchet"
   require "slimta"

Using Ratchet
"""""""""""""

The "magic" of *ratchet* is the use of Lua coroutines to make socket calls that
look synchronous but aren't. When a socket call would block, the thread yields
control to other threads until the data is available. To create a *ratchet*
object, you must give it an entry thread::

   local kernel = ratchet.new(function ()
       -- This is the entry thread...
       -- Attach additional threads, make blocking socket calls, etc.
   end)
   kernel:loop()

After the constructor, call ``loop()`` to run the entry thread. The call will
not return until the entry thread and any additional attached threads have
completed.

If an error occurs, it is usually not desired for that error halt the whole
process and stop *slimta*. To avoid that, use an error handler::

   local function error_handler(err, thread)
       print(debug.traceback(thread, err))
   end

   local kernel = ratchet.new(entry_thread, error_handler)

This way, if a thread errors, its traceback information will be printed and
other threads will continue merrily on. The thread that errored cannot be
resumed.

.. _ratchet-threads:

Using Threads
"""""""""""""

Most every function call in *slimta* makes use of a *ratchet* feature, so it is
unwise (and may throw an error) to run *slimta* functions outside of a *ratchet*
thread.

Additionally, some parts of *slimta* are specifically designed to run in their
own threads, so they will not block or slow down the other parts of the MTA. As
an example, an effective use of :func:`slimta.edge.smtp.accept()` would look
like this::

   while not done do
       local callable = smtp_edge:accept()
       ratchet.thread.attach(callable)
   end

The :doc:`../api` and :doc:`../manual` will attempt to make it clear to developers
when it is necessary or desired to create new *ratchet* threads.

.. _ratchet-sockets:

Using Sockets
"""""""""""""

For functions that require a server socket, such as
:func:`slimta.edge.smtp.new()`, creating one will feel quite familiar to those
familiar with POSIX sockets::

   local rec = ratchet.socket.prepare_tcp("0.0.0.0", 25)
   local socket = ratchet.socket.new(rec.family, rec.socktype, rec.protocol)
   socket:setsockopt("SO_REUSEADDR", true)
   socket:bind(rec.addr)
   socket:listen()

At this point, pass the socket to the function and it will be responsible for
calling ``accept()`` on the socket.

