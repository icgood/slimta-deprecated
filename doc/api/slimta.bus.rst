

slimta.bus
==========

.. currentmodule:: slimta.bus

Module that simplifies and abstracts the transfer of objects either locally
(within the same Lua state) or over a socket.

For server-side bus objects, the :func:`server.recv_request()` method is
implemented which results in a transaction and a array of requests. The
transaction object implements the :func:`server.send_response()` method which
sends an array of responses back to the client.

For client-side bus objects, the :func:`client.send_request()` method is
implemented which results in a transaction object. The transaction object
implements the :func:`client.recv_response()` method, which gets the array of
responses back from the server.

Objects sent and received with socket buses either as the request or as the
response MUST implement ``to_xml()`` and ``from_xml()`` functions. The ``to_xml()``
function is as described in the :mod:`slimta.xml.writer` module. The ``from_xml()``
function takes a root tree node (as in :mod:`slimta.xml.reader`) and an array of
arbitrary string attachments.

For more information, see the ratchet.bus API documentation and usage
manual.

.. function:: new_local()

   Creates a new local bus, implemented as a queue structure using Lua tables
   and ratchet threads, such that one thread may wait for requests until
   another sends one. After a thread sends a request, it may then wait for a
   response. The result is a client-server model.

   :return: the server end of the bus, followed by the client end.

.. function:: new_server(host, port, request_type)

   Creates a server-side bus object to listen for requests on a socket listening
   on the given host and port. Received requests are translated from XML using
   the ``from_xml()`` function of the given request data type, and sent
   responses are translated to XML using its ``to_xml()`` method.

   :param host: the host interface to listen on.
   :param port: the port to listen on.
   :param request_type: a table implementing the from_xml() function for
                        interpreting the request XML.
   :return: a new server-side socket bus.

.. function:: new_client(host, port, response_type)

   Creates a client-side bus object to send requests to a server bus located by
   the given host and port. Received responses are translated from XML using the
   ``from_xml()`` function of the given response data type, and sent requests
   are translated to XML using the ``to_xml()`` method.

   :param host: the host to connect to.
   :param port: the port to connect to.
   :param response_type: a table implementing the ``from_xml()`` function for
                         interpreting the response XML.
   :return: a new client-side socket bus.

--------------

**Modules**

.. toctree::

   slimta.bus.proxy

