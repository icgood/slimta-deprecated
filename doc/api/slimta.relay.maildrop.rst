
slimta.relay.maildrop
=====================

.. currentmodule:: slimta.relay.maildrop

Module that implements a relayer using the ``maildrop`` command-line utility.
This is a venerable, local delivery method often used in conjunction with
courier-POP or mutt.

.. function:: new([cmd], [time_limit])

   Creates a new :mod:`maildrop` relayer object.

   :param cmd: the command name, default ``"maildrop"``.
   :param time_limit: maximum time to wait for maildrop to finish before failing
    the message.
   :return: new :mod:`maildrop` object.

