
#############################
slimta: Mail Transfer Library
#############################

Installation Procedure
======================

If your distribution includes a package for installation slimta, that would be
the preferred method. If not, try a compilation option below.

Compiling from Tarball
""""""""""""""""""""""

Compiling from a versioned, source tarball is the preferred method of
compilation.

::

    $ ./configure
    $ make
    $ sudo make install

Compiling from Git
""""""""""""""""""

Compiling directly from the Git repository allows for "bleeding edge"
installations, but there is no guarantee that it will be functional. Most likely
you should only use Git compilations if you are doing development.

::

    $ autoreconf -i
    $ ./configure
    $ make
    $ sudo make install

