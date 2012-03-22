
slimta.message.bounce
=====================

.. currentmodule:: slimta.message.bounce

Module for taking a message and response and generating a bounce message to
explain to the sender why the original message failed to send.

.. function:: new([sender], [client], [header_tmpl], [footer_tmpl])

   Creates a new :mod:`bounce` object. A form of variable substitution is
   applied to the *header_tmpl* and *footer_tmp* strings allowing them to
   contain information about the message, see the usage manual for more details.

   :param sender: used as the envelope sender of the bounce message, default
    ``""``.
   :param client: :mod:`slimta.message.client` object used for the bounce
    message.
   :param header_tmpl: the MIME data string preceding the original message
    contents.
   :param footer_tmpl: the MIME data string proceeding the original message
    contents.
   :return: new :mod:`bounce` object.

.. function:: build(self, message, response, [timestamp])

   Takes information about the original message and what happened to it and
   generates a bounce message to alert the sender that the message failed to be
   delivered and why.

   :param self: :mod:`bounce` object.
   :param message: original :mod:`slimta.message` object.
   :param response: :mod:`slimta.message.response` object describing failure.
   :param timestamp: timestamp to use for the bounce message, defaulting to the
    current time.
   :return: new bounce :mod:`slimta.message` object.

