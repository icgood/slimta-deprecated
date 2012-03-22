
slimta.policies.add_message_id_header
=====================================

.. module:: slimta.policies.add_message_id_header

Module that implements policy logic to add a ``Message-Id:`` header to an
outgoing message, as per *RFC 2822*. This header should be added to all messages
that do not already have one.

.. function:: new([hostname], [random_func], [time_func])

   Creates a new :mod:`add_message_id_header` policy object.

   :param hostname: the hostname of the system generating the message-id. By
    default, this information will be retrieved manually.
   :param random_func: function that returns a random string to differentiate
    this message from others. The default should work just fine.
   :param time_func: function that returns the current system timestamp. The default is Lua's ``os.time()``.
   :return: new :mod:`add_message_id_header` policy object.

.. function:: add(self, message)

   If the message does not already contain a ``Message-Id:`` header, one is
   constructed and added to the message. This header will be of the form
   ``<randomstring.timestamp@hostname>``.

   :param self: :mod:`add_message_id_header` object.
   :param message: :mod:`slimta.message` object.

