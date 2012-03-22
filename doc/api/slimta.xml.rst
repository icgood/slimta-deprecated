
slimta.xml
====================

.. module:: slimta.xml

Module that provides an interface to XML parsing using libexpat. This module
does nothing fancy but functions very similar to using expat in C.

.. function:: escape(data)

   Escapes a string of data for XML usage, replacing all angle-brackets and
   ampersands with the XML equivalents and returning a copy of the result.

   :param data: string of data to escape.
   :return: string of data suitable for inclusing in XML.

.. function:: new(state, start_cb, end_cb, data_cb)

   Creates a new parser state. Data is then passed to this state with
   :func:`parse()` or :func:`parsesome()` to actually parse the XML and run the
   callbacks.

   :param state: a value that is passed as the first parameter to each
    callback.
   :param start_cb: called for each start tag. Arguments are the state, the tag
    name, and a table of attributes.
   :param end_cb: called for each end tag. Arguments are the state and the tag
    name.
   :param data_cb: called for each piece of tag data. This callback may be
    called more than once per tag.
   :return: new :mod:`slimta.xml` object.

.. function:: parse(self, data, [more_coming])

   Parses a string of XML data so that the callbacks given in the parser
   constructor are called.

   :param self: :mod:`slimta.xml` object.
   :param data: the string of data to parse.
   :param more_coming: true if this is not the last piece of data in the chunk.

.. function:: parsesome(self, data)

   calls parse() with more_coming set to true.

   :param self: :mod:`slimta.xml` object.
   :param data: the string of data to parse.

--------------

**Modules**

.. toctree::

   slimta.xml.reader
   slimta.xml.writer

