
slimta.policies.forward
=======================

.. module:: slimta.policies.forward

Module that implements pattern-based, prioritized recipient rewriting, also
known as forwarding.

.. function:: new([mapping])

   Creates a new :mod:`forward` object with the initial *mapping* table. The
   object's mapping table can be accessed and modified with the :mod:`forward`
   object's ``mapping`` attribute.

   :param mapping: initial mapping table, empty by default. This table should be
    an array of tables containing ``pattern``, ``repl``, and ``n`` keys,
    corresponding to the arguments of Lua's ``string.gsub()`` function.

    ::

        slimta.policies.forward.new({
            {pattern = "^staff%-([^%@]+)%@example%.com$", repl = "%1@staff.example.com"},
            {pattern = "^.*$", repl = "admin@example.com"},
        })

   :return: new :mod:`forward` policy object.

.. function:: map(self, message)

   For each recipient of the message, loops through the ``pattern`` fields in
   the mapping array entries attempting to match the recipient. If the recipient
   is a match, it is rewritten according to the entry's ``repl`` and ``n`` keys.

   :param self: :mod:`forward` policy object.
   :param message: :mod:`slimta.message` object.

