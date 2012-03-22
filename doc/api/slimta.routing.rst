
slimta.routing
==============

.. module:: slimta.routing

:mod:`slimta.message` objects received from edge services do not have routing
information associated with them. Without routing information, relay attempts
will not be possible. Routing policies simply modify the :mod:`message` object
to add that information.

--------------

.. currentmodule:: slimta.routing.static

Module for static routing logic for messages. This function is ideal for inbound
mail traffic where all messages follow the same routing rules.

.. function:: new(relayer, host, port)

   Creates a new :mod:`static` routing object. The parameters define the
   relaying information applied to each routed message. Generally, this
   information is static (i.e. a string or a number), but each parameter can
   also be given as a function which will be called in :func:`route()` with the
   message as the only parameter.

   :param relayer: string identifier of the relayer to use for routing messages.
   :param host: the host to use for routing messages.
   :param port: the port to use for routing messages, default 25.
   :return: a new :mod:`static` object.

.. function:: route(self, message)

   Applies the :mod:`static` routing information to the :mod:`slimta.message`'s
   envelope. If any piece of the routing information was given as a function,
   that function is called with *message* as the only parameter and the result
   is used.

   :param self: :mod:`static` object.
   :param message: :mod:`slimta.message` object to modify.
   :return: an array containing one element, *message*, for
    compatibility with other routing types.

--------------

.. currentmodule:: slimta.routing.mx

Module for standard, RFC-compliant MX-based routing logic. When a message is MX
routed, it is split such that there is a new message with the recipients of each
unique recipient domain. The new messages are identical otherwise. Any recipient
without a domain is left in the original message object and deemed "unroutable".

.. function:: new([pick_mx], [pick_relayer], [pick_port])

   Creates a new :mod:`mx` routing object. Individual objects can have their own
   logic for picking records, relayers, and ports, as well as having hard-coded
   rules set by the :func:`set_mx()` method.

   :param pick_mx: a function which, given a :mod:`message` as a parameter,
    returns an index defining which MX record to use, with 1 being the first
    record of the lowest preference value and N being the last record of the
    highest preference value. If the resulting index is greater than a domain's
    N, the value is wrapped. The default is to pick directly based on the number
    of delivery attempts.
   :param pick_relayer: a function which, given a :mod:`slimta.message` as a
    parameter, returns a string indicating a relayer. The default is the string
    ``"SMTP"``. See the :mod:`slimta.relay` module for more information.
   :param pick_port: a function which, given a :mod:`slimta.message` as a
    parameter, returns a port number to attempt delivery to. The default is port
    ``25``.
   :return: new :mod:`mx` routing object.

.. function:: set_mx(self, domain, record)

   Sets a hard-coded MX record for a domain. Instead of doing a DNS MX query,
   this table is indexed by the object's ``pick_mx()`` function for delivery.
   This is primarily used for testing, but may be useful for some special
   policies.

   :param self: :mod:`mx` routing object.
   :param domain: the domain to hard-code.
   :param record: an array of hard-coded MX records, ordered by lowest to
    highest preference value.

.. function:: route(self, message)

   Takes a :mod:`slimta.message` and routes it according the logic established
   by the object. If a recipient domain is hard-coded by :func:`set_mx()`, that
   takes precedence over doing a DNS MX query.

   :param self: :mod:`mx` routing object.
   :param message: :mod:`slimta.message` object to modify.
   :return: returns an array of new :mod:`slimta.message` objects, one for each
    unique recipient domain, with their envelopes correctly filled with relaying
    information. The original *message* parameter may be returned as a second
    returned value with any recipients that did not have a recognizable domain
    name.

