
slimta.edge.http
================

.. currentmodule:: slimta.edge.http

Module that manages an edge listener for HTTP message requests. These requests
follow an unofficial, non-standard scheme where SMTP-like data is given as HTTP
headers and the SMTP data (including headers) is given as MIME type
*message/rfc822* data.

.. function:: new(socket, bus)

   Creates a new :mod:`http` edge listener. The *socket* should already be
   opened in listening mode, and *bus* is used to send received messages as
   requests.

   :param socket: listening socket.
   :param bus: :mod:`slimta.bus` client to send requests on.
   :return: new :mod:`http` edge object.

.. function:: accept(self)

   Waits for a new socket connection.

   :param self: :mod:`http` object.
   :return: a callable object that handles the entire connection transaction and
    sends the :mod:`message` as a request to the bus. Usually, this is called in
    a new thread so that :func:`accept()` can be called again immediately.

.. function:: close(self)

   Closes the :mod:`http` edge listener. This basically just closes the
   associated socket.

   :param self: :mod:`http` object.

