
Storage Engines
===============

The :doc:`queue <queue>` requires a persistent storage mechanism. Presently, the
main storage engine uses redis_ and the only alternative is a non-persistent
testing engine stored in local memory.

Creating a :mod:`~slimta.storage` object is relatively simple, especially if the
redis instance is dedicated to the queue::

   local redis = slimta.storage.redis.new("localhost", 6379)

If the redis instance is shared with other applications (or other queues), you
need to use a database offset. For example, if sharing with another queue that
consumes 4 redis database indices, use an offset of 4::

   local redis = slimta.storage.redis.new("localhost", 6379, 4)

Currently, it is only possible to use four adjacent databases.

--------------

**Database 0**

The first database uses the keys ``message_ids`` and ``retry_queue``.

The ``message_ids`` key is a redis `set`_ where all the members are messages in
the system.  Calling a redis storage session's
:func:`~slimta.storage.session.get_all_messages()` method simply queries this
set and returns it as a Lua table. Calling a redis storage session's
:func:`~slimta.storage.session.claim_message_id()` method attempts to add new
UUIDs to this SET until it is successful.

The ``retry_queue`` key is a redis `sorted set`_. The members of this set are
message IDs of messages that are waiting for delivery retry. The "score" of
these members is the UNIX timestamp when the next retry should occur. To
determine messages that are ready for retry, one could simply query for members
of the set whose score is less-than or equal-to the current UNIX timestamp. That
is exactly how :func:`slimta.queue.retry()` works.

--------------

**Database 1**

The second database uses message IDs as keys. Each key is a redis `hash`_
containing meta information about the message. The keys and values of these
hashes match the table generated by :func:`slimta.message.to_meta()`.

--------------

**Database 2**

The third database uses message IDs as keys. Each key is a simple string
containing the full, raw contents of the message.

--------------

**Database 3**

The fourth and final database is used to lock messages while a delivery attempt
is taking place. The keys in this database are message IDs that are currently
locked. The keys are created with expirations (using ``SETEX``), so that a stuck
relayer cannot indefinitely lock a message.

.. _redis: http://redis.io/
.. _set: http://redis.io/commands#set
.. _sorted set: http://redis.io/commands#sorted_set
.. _hash: http://redis.io/commands#hash

