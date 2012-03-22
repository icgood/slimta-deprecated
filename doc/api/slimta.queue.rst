
slimta.queue
============

.. currentmodule:: slimta.queue

Module to manage the queue of messages passing through the MTA. This involves
receiving messages from the edge service, storing it in a storage engine,
immediately attempting relay, and retrying failed messages at regular intervals.

.. function:: new(edge_bus, relay_bus, storage)

   Creates a new :mod:`queue` object. Requests are received from *edge_bus*,
   delivered to *relay_bus*, and messages are stored in the *storage* engine
   until they are successfully delivered or bounced.

   The default retry algorithm immediately returns ``nil``, meaning the message
   will bounce immediately on transient failures (not usually desired). Use the
   :func:`set_retry_algorithm()` to specify new behavior.

   The default :mod:`bounce builder <slimta.message.bounce>` uses a null-sender and borrows the original
   :mod:`~slimta.message` object's ``client`` field. This is usually ok, but you
   can use the :func:`set_bounce_builder()` to specify new behavior.

   The default lock duration for actively relaying messages is two minutes (120
   seconds). You can specify a new lock duration with
   :func:`set_lock_duration()`.

   :param edge_bus: receive requests from the edge service on this bus.
   :param relay_bus: send requests to the relay service on this bus.
   :param storage: :mod:`slimta.storage` engine to write to.
   :return: new :mod:`queue` object.

.. function:: set_retry_algorithm(self, func)

   Sets a new function to generate a retry timestamp for a failed message. This
   function is passed a :mod:`slimta.message` object and a
   :mod:`slimta.message.response` object and returns ``nil`` or a timestamp
   number. If ``nil`` is returned, it signifies the message should not be
   retried and a bounce is delivered to the sender.

   :param self: :mod:`queue` object.
   :param func: the new retry algorithm function.

.. function:: set_bounce_builder(self, new)

   Sets a new :mod:`slimta.message.bounce` builder object for the queue.

   :param self: :mod:`queue` object.
   :param new: the new :mod:`slimta.message.bounce` builder object.

.. function:: set_lock_duration(self, new)

   Sets the new lock duration in seconds. Until this time expires or the lock is
   removed, no other queue manager will be able to lock the message and attempt
   a simultaneous delivery. Ideally, relayers should be configured to timeout
   and fail before this lock expires.

   :param self: :mod:`queue` object.
   :param new: the new lock duration in seconds.

.. function:: get_deferred_messages(self, storage_session, [timestamp])

   Gets deferred messages. If *timestamp* is given, only messages with retry
   timestamps it will be returned.

   :param self: :mod:`queue` object.
   :param storage_session: :mod:`slimta.storage.session` object.
   :param timestamp: if given, only return messages whose retry time comes
    before it. This is useful for gathering all messages ready for immediate
    retry by passing the current timestamp.
   :return: table array of deferred :mod:`slimta.message` objects.

.. function:: get_all_messages(self, storage_session)

   Returns all messages in the storage engine.

   :param self: :mod:`queue` object.
   :param storage_session: :mod:`slimta.storage.session` object.
   :return: table array of all stored :mod:`slimta.message` objects.

.. function:: try_relay(self, message, [storage_session])

   Attempts delivery of the :mod:`slimta.message`.

   :param self: :mod:`queue` object.
   :param message: :mod:`slimta.message` object.
   :param storage_session: if given, only attempt delivery if the message can be
    locked by the :mod:`slimta.storage.session` object.
   :return: :mod:`slimta.message.response` object from the relayer.

.. function:: accept(self)

   Waits for a request from the edge bus.

   :param self: :mod:`queue` object.
   :return: a callable object which stores the message and attempts delivery.
    Usually, this is called in its own thread so that :func:`accept()` may be
    immediately called again.

.. function:: retry(self)

   Checks storage for any deferred messages that are due for another attempt.
   Unlike :func:`accept()`, this method does not wait, but immediately returns
   ``nil`` if no deferred messages are ready for retry. It is expected that the
   caller will wait before checking again.

   :param self: :mod:`queue` object.
   :return: a callable object which attempts a delivery retry for all messages
    that are ready for immediate retry. Usually, this is called in its own
    thread.

