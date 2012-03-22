
slimta.policies.add_date_header
===============================

.. module:: slimta.policies.add_date_header

Module that implements policy logic to add a ``Date:`` header to an outgoing
message, as per *RFC 2822*. This header should be added to all messages that do
not already have one.

.. function:: new([build_date])

   Creates a new :mod:`add_date_header` policy object.

   :param build_date: function that takes a timestamp and returns a string to
    add as the ``Date:`` header. The default should work just fine.
   :return: new :mod:`add_date_header` policy object.

.. function:: add(self, message)

   If the *message* does not already contain a ``Date:`` header, one is
   constructed and added to *message*. The timestamp of the message's reception
   (``message.timestamp``) is used to generate the date, and is not necessarily
   the current time.

   :param self: :mod:`add_date_header` object.
   :param message: :mod:`slimta.message` object.

