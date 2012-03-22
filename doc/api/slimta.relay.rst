
slimta.relay
============

.. module:: slimta.relay

Module that manages the delivery of messages. Different messages can be
delivered in different ways, some may be forwarded by SMTP to another host while
others may belong to a local mailbox on disk. Different relayers are identified
by an arbitrary unique string, such as ``"SMTP"``, ``"maildrop"``, or completely
arbitrary like ``"gmail"``.

.. function:: new(bus, [default])

   Creates a new :mod:`relay` object, which receives relay requests on *bus*.

   :param bus: :mod:`slimta.bus` server object to receive requests on.
   :param default: if a message does not specify its intended relayer, it should
    use the one indicated by this string.
   :return: new :mod:`relay` object.

.. function:: add_relayer(self, name, relayer)

   Adds a new available relayer object. This relayer will handle any messages
   that specify it as the delivery relayer.

   :param self: :mod:`relay` object.
   :param name: arbitrary string to identify the relayer and allow messages to
    specify it.
   :param relayer: relayer object, such as :mod:`slimta.relay.smtp` or
    :mod:`slimta.relay.maildrop`.


.. function:: accept(self)

   Waits for a relay request from the bus.

   :param self: :mod:`relay` object.
   :return: a callable object which attempts message delivery by its specified
    relayer (or the default). Usually, this is called in a separate thread so
    that :func:`accept()` can be called again immediately.

--------------

**Modules**

.. toctree::

   slimta.relay.smtp
   slimta.relay.maildrop

