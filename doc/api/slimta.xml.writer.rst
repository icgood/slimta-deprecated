
slimta.xml.writer
====================

.. currentmodule:: slimta.xml.writer

Module which provides a consistent interface for generating XML representations
of an object's data, such that it can be recreated without access to the
original object.

Objects written added to an xml.writer MUST implement a ``to_xml()`` method
which returns a table array of strings for each line of representation XML.
Alternatively, a line may instead be a nested table of more lines, so that
objects may allow child objects to implement their own XML representation
routines. For readability, lines a prefixed with spaces based on tag depth.
Finally, an object's ``to_xml()`` method may take advantage of an attachments
table passed as a parameter, where it may append arbitrary non-representable
string data.

.. function:: new()

   Creates a new :mod:`slimta.xml.writer` object.

   :return: new :mod:`slimta.xml.writer` object.

.. function:: add_item(self, item)

   Adds an object to the list of objects for which the current xml.writer will
   generate XML for.

   :param self: :mod:`slimta.xml.writer` object.
   :param item: an object implementing a ``to_xml()`` method.

.. function:: build(self, [containers])

   Builds XML representing all objects added to the :mod:`slimta.xml.writer`. If
   more than one item has been added to the :mod:`slimta.xml.writer`, the
   optional *containers* array parameter becomes required, or else the resulting
   XML will not be valid.

   :param self: :mod:`slimta.xml.writer` object.
   :param containers: table array of container tags, such that the
    ``containers[1]`` is the outermost tag, followed by ``containers[2]`` and so
    on.
   :return: a string of resulting XML, followed by the resulting attachments
    table containing all non-representable string data.

