
slimta.storage.session
======================

.. module:: slimta.storage.session

Module describing the methods exposed by storage engine sessions. These objects
can only be created by calling the :func:`slimta.storage.connect()` method of a
:mod:`slimta.storage` engine, they have no constructors. You should always call
a :mod:`session`'s :func:`close()` method when you are done with it.

.. function:: close(self)

   Closes the given :mod:`session`. For example, if the storage engine required
   a socket connection to a remote instance, this socket would be closed.

   :param self: :mod:`session` object.

.. function:: get_active_messages(self)

   Returns a table of message IDs that are currently being delivered by a
   relayer service. These messages should be considered "locked" until the
   delivery attempt is completed.

   :param self: :mod:`session` object.
   :return: table of active message IDs.

.. function:: get_deferred_messages(self)

   Returns a table of message IDs that are currently awaiting their next retry
   attempt.

   :param self: :mod:`session` object.
   :return: table of deferred message IDs.

.. function:: get_all_messages(self)

   Returns a table of all message IDs stored in the engine, in any state.

   :param self: :mod:`session` object.
   :return: table of all known message IDs.

.. function:: claim_message_id(self)

   Randomly generates a new message ID and checks if it is available in the
   storage engine. If so, it is returned, if not it tries again with new random
   IDs until one is available. The returned message ID should be considered a
   stored message, even if no meta information or contents have been written
   yet, (e.g. it may be returned by :func:`get_all_messages()`).

   :param self: :mod:`session` object.
   :return: a new, claimed message ID.

.. function:: set_message_meta(self, id, meta)

   Sets the message meta information to the contents of the given simple
   meta table, as produced by :func:`slimta.message.to_meta()`.

   :param self: :mod:`session` object.
   :param id: the message ID to set meta for.
   :param meta: the simple meta key-value table to store.

.. function:: set_message_meta_key(self, id, key, value)

   Sets one key in the message meta information to the given value. This is
   especially useful for keys that change frequently, like the number of message
   delivery attempts.

   :param self: :mod:`session` object.
   :param id: the message ID to set meta for.
   :param key: the meta key to set.
   :param value: the new value for the meta key.

.. function:: get_message_contents(self, id)

   Loads the raw message contents from storage..

   :param self: :mod:`session` object.
   :param id: the message ID to load contents for.
   :return: the raw message contents string.

.. function:: set_message_retry(self, id, timestamp)

   Sets the next retry attempt time for the given message. This function also
   signifies the message is deferred.

   :param self: :mod:`session` object.
   :param id: the message ID to set retry attempt timestamp for.
   :param timestamp: next retry delivery attempt no earlier than this timestamp.

.. function:: lock_message(self, id, length)

   Locks a message for a period of time. This function does not necessarily
   prevent other access/modification of the message, but MUST guarantee that
   other attempts (by other threads, processes, or systems) to lock the message
   will fail for the duration. This function signifies the message is active,
   and no other relayer may attempt delivery.

   :param self: :mod:`session` object.
   :param id: the message ID to lock.
   :param length: the number of seconds to hold the lock.
   :return: true if the lock was successful, false if the lock could not be
    established right now.

.. function:: unlock_message(self, id)

   Unlocks the message, so that the next future attempt (by any thread, process,
   or system) to lock the message will be successful.

   :param self: :mod:`session` object.
   :param id: the message ID to unlock.

.. function:: delete_message(self, id)

   Removes all references to the message in the storage engine. This is useful
   when the message was successfully delivered or when a message was permanently
   failed and a bounce message was queued to the sender.

   :param self: :mod:`session` object.
   :param id: the message ID to delete.

