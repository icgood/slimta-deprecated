
slimta.relay.smtp
=================

.. module:: slimta.relay.smtp

Module that attempts message delivery by connection to a remote SMTP server.

.. function:: new([ehlo_as], [family])

   Creates a new :mod:`smtp` relayer object.

   :param ehlo_as: EHLO string, or a function that returns an EHLO string.
   :param family: family of IP protocols to use, default "AF_UNSPEC". See the
    ``getsockaddr(3)`` man page for details.

.. function:: set_ehlo_as(self, ehlo_as)

   Sets the new EHLO string for sessions to use.

   :param self: :mod:`smtp` relayer object.
   :param ehlo_as: EHLO string, or a function that returns an EHLO string.

.. function:: use_security(self, mode, context, [force_verify])

   States that SMTP sessions created by this relayer should attempt to use TLS
   security when possible.

   :param self: :mod:`smtp` relayer object.
   :param mode: encryption mode string. ``"ssl"`` for full-connection encryption
    (i.e. port 465), or ``"starttls"`` for encryption as-available via the
    **STARTTLS** extension.
   :param context: a ``ratchet.ssl`` context object.
   :param force_verify: if true, consider it a complete failure of message
    delivery if the encryption session could not be verified, including
    certiciation validation.

