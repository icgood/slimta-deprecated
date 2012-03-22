
slimta
======

.. currentmodule:: slimta

The root module for all other slimta modules. Also contains several C supporting
functions. Note that this module only directly loads the modules implemented in
C, other modules will require direct ``require()`` calls.

.. function:: daemonize()

   Daemonizes the current process using the standard double-fork. This function
   closes standard input, output, and error and redirects them to ``/dev/null``,
   even if you previously called :func:`redirect_stdio()`.

   :return: the pid of the new daemon process.

.. function:: redirect_stdio([stdout], [stderr], [stdin])

   Redirects standard output, error, and input to the given filenames. Standard
   output and error are opened in append-mode, and standard input is opened in
   read-only mode. Leaving any parameter blank leaves that stream alone.

   :param stdout: filename to append the standard output stream into.
   :param stderr: filename to append the standard error stream into.
   :param stdin: filename to read from as the standard input stream.

.. toctree::

   slimta.base64
   slimta.hmac
   slimta.bus
   slimta.signalfd
   slimta.uuid
   slimta.xml
   slimta.message
   slimta.storage
   slimta.policies
   slimta.routing
   slimta.edge
   slimta.queue
   slimta.relay

