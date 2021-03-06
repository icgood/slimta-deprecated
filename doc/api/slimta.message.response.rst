
slimta.message.response
=======================

.. module:: slimta.message.response

Module to represent a response to a message delivery. These responses must come
from an SMTP relayer attempting delivery or must be translated into valid SMTP
command responses. For example, successfully writing a message into a user's
local mailbox should yield a ``"250"`` even if an SMTP relayer was not used.

.. function:: new(code, message, [data])

   Creates a new :mod:`response` object.

   :param code: SMTP code describing the success or failure.
   :param message: simple message string describing the response.
   :param data: data string providing further information, such as a queue ID or
    error message. This data is not used by SMTP protocols.
   :return: new :mod:`response` object.

.. function:: as_smtp(self)

   Returns the response code and message, as it could be returned to the client
   of an SMTP edge service.

   :param self: :mod:`response` object.
   :return: code, message

.. function:: as_http(self)

   Returns a table suitable for returning as an HTTP response. This table
   includes an HTTP code and message, and can also include the arbitrary data
   string passed to the constructor. SMTP codes are translated (rather
   ignorantly) into HTTP codes, e.g. ``"250"`` => ``"200"``.

   :param self: :mod:`response` object.
   :return: an HTTP response table.

.. function:: to_xml(self)

   Generates a table array of lines of XML representing the :mod:`response`
   object, suitable for use by the :mod:`slimta.xml.writer` module.

   :param self: :mod:`response` object.

.. function:: from_xml(tree_node)

   Loads a message response object from the given XML node tree, as generated by
   the :mod:`slimta.xml.reader` module.

   :param tree_node: node of the XML tree where the message response starts.
   :return: new :mod:`response` object.

