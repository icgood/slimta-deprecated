
Non-Delivery Reports (Bounces)
==============================

Because a client that sent a message to an *edge* service will disconnect once
the message has been queued, there is no way of reporting to the client that the
message was delivered (successfully or unsuccessfully).

As such, the message sender should assume that a message was delivered
successfully unless told otherwise. If *slimta* failed to deliver a message,
either because of too many delivery attempts or a permanent error, it will
generate and deliver a *bounce* message back to the original sender address of
the message. From this *bounce* message, the sender should be able to tell which
message failed and why.

Generating Bounce Messages
""""""""""""""""""""""""""

:mod:`~slimta.message.bounce` objects are used to build *bounce* messages from
the original :mod:`~slimta.message` object and that message's
:mod:`~slimta.message.response` object.

The :mod:`~slimta.message.bounce` module allows for customization of the format
of this bounce message.

The first parameter to :func:`~slimta.message.bounce.new()` is the sender
address to use. *Bounce* messages are not "from" anyone, and thus the (RFC
mandated) default is ``""``.

The second parameter specifies an optional :mod:`~slimta.message.client` object
to use as the *bounce* message's ``client`` attribute. By default, the original
:mod:`~slimta.message` object's ``client`` attribute is copied into the *bounce*
message with :func:`~slimta.message.client.copy()`.

The *bounce* :mod:`~slimta.message.contents` object is generated using the
original message's raw :mod:`~slimta.message.contents` surrounded by the header
and footer templates given in :func:`~slimta.message.bounce.new()`'s third and
fourth parameters.

The header and footer templates can contain the following variables, which will
be replaced with the associated data, if available:

* ``$(boundary)`` -- A generated string useful as a MIME boundary.
* ``$(sender)`` -- The origin message's sender address.
* ``$(client_name)`` -- The reverse-lookup of the client's IP, rarely available.
* ``$(client_ip)`` -- The client IP address string.
* ``$(protocol)`` -- The protocol used to receive the message.
* ``$(dest_host)`` -- The host that delivery was attempted to.
* ``$(dest_port)`` -- The port that delivery was attempted to.
* ``$(code)`` -- The error code from delivery attempt(s).
* ``$(message)`` -- The error message from delivery attempt(s).

