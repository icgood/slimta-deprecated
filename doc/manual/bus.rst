
Generic Request-Response Bus
============================

.. toctree::
   :hidden:

Concept
"""""""

Nearly everything in *slimta* can be boiled down to a request and a
corresponding response. Most message buses (RabbitMQ, ZeroMQ, etc.) focus on
more on the request and less on the response, making them unsuitable for the
MTA world where the response is critical.

*slimta* expands on *ratchet's* basic request-response bus idea, where a request
can either be local (using threads and a queue) or remote (using sockets). The
*slimta* addition is the use of XML to serialize objects for sending on sockets
in a standard way. Any object that exposes XML serialization functions
(``from_xml()`` and ``to_xml()``) can be sent as a request or a response.
Furthermore, in *slimta*, requests and responses are always sent in arrays. More
specifically, if you receive an array of 5 requests, you **must** respond with 5
responses, and conversely if you send an array of 5 requests you should expect
an array of 5 responses.

While the analogy does not always intuitive, *slimta* commonly refers to the
*"server"* side of the bus as that which receives requests and sends responses,
and refers to the *"client"* side of the bus as that which sends requests and
receives responses.

Inter-connecting Buses
""""""""""""""""""""""

Effective use of *slimta* will require the use of buses to transport messages
from place to place and to communicate what happened to those messages. For
example, it would be outside the scope of an SMTP listener to also be
responsible to write the message to disk, so it might request that a queue
manager write the message to disk and then wait for the queue manager to report
if it was successful or not.

Buses also allow for policy injection. An SMTP listener does not care whether
its bus is actually connected directly to a queue manager or not. It could
actually be connected to a middle-man that performs message-reception logging.
That middle-man would then initiate a bus request to the queue manager, and
forward its response back to the SMTP listener. In essence, the middle-man is a
proxy. This is the exact function of the :mod:`slimta.bus.proxy` convenience
module.

Connecting Local Buses
''''''''''''''''''''''

::

   local bus_server, bus_client = slimta.bus.new_local()

   local edge = slimta.edge.smtp.new(socket, bus_client)
   local relay = slimta.edge.relay.new(bus_server)

Edge services produce bus requests, so they make use of the client-side of the
local bus. That is, edge services *send* requests and *receive* responses.

Relay services receive bus requests, so they make use of the server-side of the
local bus. That is, relay services *receive* requests and *send* responses.

Connecting Remote Buses
'''''''''''''''''''''''

::
   
   -- The request object is of type slimta.message.
   local bus_server = slimta.bus.new_server('localhost', 1234, slimta.message)

   -- The response object is of type slimta.message.response.
   local bus_client = slimta.bus.new_client('localhost', 1234, slimta.message.response)

   local edge = slimta.edge.smtp.new(socket, bus_client)
   local relay = slimta.edge.relay.new(bus_server)

The remote client and server buses are thus configured to communicate on
localhost port 1234.

Edge services produce bus requests, so they make use of the client-side of the
local bus. That is, edge services *send* requests and *receive* responses.

Relay services receive bus requests, so they make use of the server-side of the
local bus. That is, relay services *receive* requests and *send* responses.

Creating Bus-compatible Objects
"""""""""""""""""""""""""""""""

As stated before, if a module has the two functions ``from_xml()`` and
``to_xml()``, its objects can be sent or received from buses.

.. highlights::

   Please see :mod:`slimta.message` or :mod:`slimta.message.response` for
   examples of bus-compatible modules/objects until this documentation section
   is completed.

