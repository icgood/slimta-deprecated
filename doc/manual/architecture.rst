
Choosing an Architecture
========================

One of the concept ideas that birthed *slimta* was that serving SMTP, queuing
messages, and delivering SMTP are all very different functions. Breaking them
apart allows for better service boundaries and also more focused hardware.
Serving and delivering SMTP will be network and CPU intensive with lots of
potentially idle file descriptors. The queue manager will likely be hitting the
disk.

The original design of *slimta* forced the separation of the three basic
elements: edge, queue, and relay :doc:`[1] <terminology>`. Ultimately that led
to complicated architectures for simple use cases; some people just want a
simple MTA running locally. The new design uses :doc:`buses <bus>` to control
the communication, using a generic enough syntax to allow either local or remote
communication.

