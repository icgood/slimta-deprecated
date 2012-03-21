
slimta.xml.reader
====================

.. currentmodule:: slimta.xml.reader

Module that parses XML data into a consistent tree structure that data types may
use to recreate objects.

Tree nodes contain three associative key elements: ``name`` is the name of the
node's tag, ``attrs`` is a table whose keys correlate to tag attributes, and
``data`` is a concatenation of all the data found between the start and end of
the tag. Child node of a node are given, in order, as numeric table indices
(``node[1]``, ``node[2]``, etc.).

.. function:: new()

   Creates a new :mod:`slimta.xml.reader` object.

   :return: new :mod:`slimta.xml.reader` object.

.. function:: parse_xml(self, data)

   Parses the given XML data into a tree structure, returning the root node.
   Traversing the tree from the root node provides access to all the data
   contained in the original XML.

   :param self: :mod:`slimta.xml.reader` object.
   :param data: the XML data to parse.
   :return: the root node of the tree structure.

