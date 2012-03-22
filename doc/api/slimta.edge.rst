
slimta.edge
===========

.. currentmodule:: slimta.edge

Contains various edge service protocols for receiving messages from the outside
the MTA. This could be from the entire Internet, just your customers, just the
local system. Not *all* messages come from an edge service, however, bounce
messages are generated internally by the MTA.

There is no edge manager, like there is for relay services.

--------------

**Modules:**

.. toctree::

   slimta.edge.http
   slimta.edge.smtp

