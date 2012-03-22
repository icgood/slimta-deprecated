
slimta.policies.add_received_header
===================================

.. currentmodule:: slimta.policies.add_received_header

Module that implements policy logic to add a ``Received:`` header to an outgoing
message, as per *RFC 2821*. This header should be prepended to all messages
handled by the MTA.

.. function:: new([date_format], [use_utc])

   Creates a new :mod:`add_received_header` policy object.

   :param date_format: date format to use in the header, as described by Lua's
    ``os.date()``.
   :param use_utc: forces the date string to use UTC instead of the local system
    timezone.
   :return: new :mod:`add_received_header` policy object.

.. function:: add(self, message)

   Prepends a ``Received:`` header to the message, describing information about
   its reception from the edge.

   :param self: :mod:`add_received_header` object.
   :param message: :mod:`slimta.message` object.

