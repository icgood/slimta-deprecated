
slimta.edge.smtp.auth
=====================

.. currentmodule:: slimta.edge.smtp.auth

Module for managing the authentication procedures of clients connecting to an
:mod:`slimta.edge.smtp` service. Clients have a choice of any mechanisms the
server exposes, such as ``"PLAIN"`` or ``"CRAM-MD5"``. See *RFC 4954*.

.. function:: new()

   Creates a new :mod:`auth` object.

   :return: new :mod:`auth` object.

.. function:: add_mechanism(self, name, [...])

   Adds a new **AUTH** mechanism to the object, given by name. The extra
   parameters will vary by mechanism, see the usage manual for supported
   mechanisms and more information. Note, some mechanisms will only show up to
   the client if the session has been encrypted.

   :param self: :mod:`auth` object.
   :param name: the mechanism name, e.g. ``"PLAIN"`` or ``"CRAM-MD5"``.
   :param ...: extra parameters specific to the mechanism.

