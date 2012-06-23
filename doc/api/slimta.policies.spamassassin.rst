
slimta.policies.spamassassin
============================

.. module:: slimta.policies.spamassassin

Module that implements spam scanning via `SpamAssassin`_. This module uses spamc
protocol version 1.1 to connect directly to a running spamd instance over a
socket.

.. function:: new([host], [port])

   Creates a new :mod:`spamassassin` object, such that queries will connect to
   *host*:*port*.

   :param host: the host to use connecting to spamd.
   :param port: the port to use connecting to spamd.

   :return: new :mod:`spamassassin` object.

.. function:: scan(self, message)

   Makes a connection to SpamAssassin's spamd daemon, passing the given
   *message* data. When a response is received on whether the message should be
   considered spam, the *spammy* boolean attribute is added to the message
   object. This method will throw an error if the spamd connection failed.

   :param self: :mod:`spamassassin` policy object.
   :param message: :mod:`slimta.message` object.

   :return: *true* if the message was spammy, *false* otherwise.

.. _SpamAssassin: http://spamassassin.apache.org/
