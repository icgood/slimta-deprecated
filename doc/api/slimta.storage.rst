
slimta.storage
==============

.. module:: slimta.storage

Module of storage engines currently available to slimta. Every storage engine
should expose the same base set of methods, and every storage engine session
should as well.

--------------

.. currentmodule:: slimta.storage.memory

.. function:: new()

   Creates a new in-memory storage engine. This engine is NOT persistent to disk
   in any way. If this object is garbage-collected or the process ends for any
   reason, any messages queued with this engine will be lost. It's primary
   purpose is as a storage "mock" for testing.

   :return: new :mod:`memory` storage engine object.

.. function:: connect(self)

   Creates a :mod:`slimta.storage.session` from the given :mod:`memory` engine
   object. Sessions are the more transient storage objects that open and close
   frequently during execution, as opposed to the engine objects themselves of
   which you generally only create one. You should always close sessions when
   you are done with them.

   :param self: :mod:`memory` storage engine object.
   :return: a :mod:`slimta.storage.session` object connected to the engine.

--------------

.. currentmodule:: slimta.storage.redis

.. function:: new(host, port, offset)

   Creates a new :mod:`redis` storage engine. When sessions are created, they
   will connect to the given *host* and *port*. This storage engine, at the time
   of writing, consumes 4 adjacent databases, e.g. 0-3 if *offset* argument is
   ``0`` or ``nil``.

.. function:: connect(self)

   Creates a :mod:`slimta.storage.session` from the given :mod:`redis` engine
   object. Sessions are the more transient storage objects that open and close
   frequently during execution, as opposed to the engine objects themselves of
   which you generally only create one. You should always close sessions when
   you are done with them.

   :param self: :mod:`redis` storage engine object.
   :return: a :mod:`slimta.storage.session` object connected to the engine.

--------------

**Modules**

.. toctree::

   slimta.storage.session

