
slimta.edge.smtp
================

.. module:: slimta.edge.smtp

Module that manages an edge listener for SMTP message requests.

.. function:: new(socket, bus)

   Creates a new :mod:`smtp` edge listener. The *socket* should already be
   opened in listening mode, and *bus* is used to send received messages as
   requests.

   :param socket: listening socket.
   :param bus: :mod:`slimta.bus` client to send requests on.
   :return: new :mod:`smtp` edge object.

.. function:: set_banner_message(self, code, message)

   Sets the *code* and *message* first received by clients when they connect to
   the :mod:`smtp` listener. Currently, this banner is static and cannot react
   dynamically to the IP of the connecting client.

   :param self: :mod:`smtp` object.
   :param code: the SMTP reply code to send with the banner, usually ``"220"``.
   :param message: the banner message. This message should start with the
    server's hostname and the string ``"ESMTP"``, e.g. ``slimta.org ESMTP Mail
    Gateway``.

.. function:: set_max_message_size(self, size)

   Instantiates a policy that the SMTP server will not accept messages over the
   size limit, and that clients may announce the message size before sending.
   This uses the **SIZE** extension of ESMTP described in *RFC 1870*.

   :param self: :mod:`smtp` object.
   :param size: new maximum acceptable message size, in bytes.

.. function:: enable_tls(self, context, [immediately])

   Turns on TLS support in the SMTP server using the given context. This is
   implemented using the **STARTTLS** extension of ESMTP described in *RFC 2487*.

   :param self: :mod:`smtp` object.
   :param context: a ``ratchet.ssl`` context object.
   :param immediately: if true, expect clients to encrypt the entire session
    immediately rather than using **STARTTLS**. This is usually done on port 465
    rather than 25, but was made obsolete by **STARTTLS**.

.. function:: set_validator(self, command, func)

   Sets a validator function for an SMTP command. This allows for policies that
   happen before receipt of message data, e.g. rejecting an address in the
   ``RCPT`` command. Please see the examples and usage manual for information on
   how to effectively use these.

   :param self: :mod:`smtp` object.
   :param command: the simple command name string, e.g. ``"MAIL"`` or ``"RCPT"``.
   :param func: the function to validate with. This function is passed a session
    table, reply table, and anything extra on a per-command basis, such as a
    recipient address or EHLO string.

.. function:: enable_authentication(self, auth)

   Enables the authentication extension for the SMTP server. Once a session has
   been authenticated, the ``authed`` key will be true in the session argument
   passed to validators.

   :param self: :mod:`smtp` object.
   :param auth: :mod:`slimta.edge.smtp.auth` object for managing authentication.

.. function:: accept(self)

   Waits for a new socket connection.

   :param self: :mod:`smtp` object.
   :return: a callable object that handles the entire connection transaction and
    sends the message as a request to the bus. Usually, this is called in a new
    thread so that :func:`accept()` can be called again immediately.

.. function:: close(self)

   Closes the :mod:`smtp` edge object. Basically this just closes the associated
   listening socket.

   :param self: :mod:`smtp` object.

.. toctree::

   slimta.edge.smtp.auth

