
slimta.bus.proxy
================

.. module:: slimta.bus.proxy

Module that provides a convenient way to apply policies and make changes to a
stream of requests traversing a bus. For example, a message going from the queue
to the relayer may not yet have any routing information in order to be relayed.

.. function:: new(from_bus, to_bus, [filter])

   Creates a new proxy object between a source and destination bus.

   :param from_bus: requests are received from this bus as the source.
   :param to_bus: passed to the filter as the destination bus to proxy requests
    to.
   :param filter: function to filter requests and proxy them to the destination
    bus. Accepts two parameters, the destination bus object and the request
    array. It should return an appropriate response array that will be sent back
    to the source bus. The default filter simply proxies to the destination
    without modification.
   :return: new :mod:`slimta.bus.proxy` object.

.. function:: accept(self)

   Waits for a new request on the source bus. When one is received, a callable
   object is returned that will run the proxy object's filter function. Usually
   the application will call the returned value in a new thread so that it may
   keep calling :func:`accept()` for new requests.

   :param self: :mod:`slimta.bus.proxy` object.
   :return: a callable object to filter and proxy the received request.

.. function:: __call(self)

   Enters an infinite loop of accepting new requests and starting new threads to
   proxy them. This metamethod is given as a convenience so that a proxy object
   can be called as a new thread.

   :param self: :mod:`slimta.bus.proxy` object.
   :return: this function never returns and should be called in its own thread.

