
slimta.signalfd
====================

.. module:: slimta.signalfd

Module for catching signals in an event-based manner. Uses the ``signalfd()``
system call only available on GNU/Linux systems.

.. function:: mask(sigs)

   Returns a signal mask suitable for passing to :func:`sigprocmask()` or
   :func:`new()`. The signals passed to this function are simply the names in
   the ``signal(7)`` man page, e.g. ``"SIGHUP"`` or ``"SIGTERM"``.

   :param sigs: table of signal names.
   :return: signal mask suitable for later use.

.. function:: sigprocmask(mask)

   Sets the new signal mask of the current process and returns the old one. The
   signal mask defines those signals whose handlers are blocked, which does not
   mean that signalfd cannot catch them.

   :param mask: the new signal mask, as returned by :func:`mask()`.
   :return: the old signal mask.

.. function:: new()

   Creates a new :mod:`signalfd` object.

   :return: a new :mod:`signalfd` object.

.. function:: setmask(self, mask)

   Sets the mask of the :mod:`signalfd` object. This defines which signals the
   signalfd's :func:`read()` method will catch. Generally, this mask is also
   passed to :func:`sigprocmask()` to have their default handlers blocked.

   :param self: the :mod:`signalfd` object.
   :param mask: the new mask for the :mod:`signalfd` object.

.. function:: close(self)

   Closes the signalfd object.

   :param self the :mod:`signalfd` object.

.. function:: read(self)

   Pauses the current ratchet thread until a signal belonging to the
   :mod:`signalfd` object's mask is sent to the current process. The name string
   of this signal is the return value of this function.

   :param self: the :mod:`signalfd` object.
   :return: a string name of the signal received, e.g. ``"SIGUSR1"``.

