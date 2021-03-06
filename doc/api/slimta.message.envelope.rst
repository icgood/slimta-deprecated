
slimta.message.envelope
=======================

.. module:: slimta.message.envelope

Module for describing the envelope of a :mod:`message`, in other words the info
used by policies and the relayer to deliver the message.

.. function:: copy(old)

   Copies a :mod:`envelope` object into a new object. This is a "deep" copy
   operation, tables are not recycled.

   :param old: the original :mod:`envelope` object.
   :return: a new :mod:`envelope` object, identical to the original.

.. function:: new(sender, recipients, [dest_relayer], [dest_host], [dest_port])

   Creates a new :mod:`envelope` object from the given information.

   :param sender: the original sender address of the message.
   :param recipients: table array of intended message recipients.
   :param dest_relayer: string identifying the intended relayer.
   :param dest_host: string identifying the destination host.
   :param dest_port: the destination port number.
   :return: new :mod:`envelope` object.

.. function:: to_xml(self)

   Generates a table array of XML representing the :mod:`envelope` object.

   :param self: :mod:`envelope` object.
   :return: a table array of XML lines, suitable for :mod:`slimta.xml.writer`.

.. function:: from_xml(tree_node)

   Loads a :mod:`envelope` object from the given XML node tree, as generated by
   the :mod:`slimta.xml.reader` module.

   :param tree_node: node of the XML tree where the message envelope starts.
   :return: new :mod:`envelope` object.

.. function:: to_meta(self, meta)

   Creates a simple key-value table describing all the information contained in
   the message envelope object, suitable for serialization or, more commonly,
   storage in a storage engine.

   :param self: :mod:`envelope` object.
   :param meta: the table to add simple key-value meta information to.

.. function:: from_meta(meta)

   Loads a message envelope object from the given simple table of meta
   information.

   :param meta: simple key-value table of meta information to load from.
   :return: new :mod:`envelope` object.

