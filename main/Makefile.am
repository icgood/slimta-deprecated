
noinst_LTLIBRARIES = libcommon.la libmain.la

libcommon_la_SOURCES = misc.h misc.c \
		       myconfig.h myconfig.c \
		       xml.h xml.c \
		       rlimit.h rlimit.c \
		       uuid.h uuid.c \
		       slimta.c slimta.h

libmain_la_CFLAGS = -DPKGLIBDIR=\"$(pkglibdir)\" -DSYSCONFDIR=\"$(sysconfdir)\"
libmain_la_LIBADD = libcommon.la
libmain_la_SOURCES = main.c

dist_pkglib_DATA = setup.lua

bin_PROGRAMS = slimedge slimrelay slimqueue slimaster

slimedge_LDFLAGS = @LUA_LIB@ @RATCHET_LIB@
slimedge_LDADD = libcommon.la libmain.la
slimedge_SOURCES = slimedge.c

slimrelay_LDFLAGS = @LUA_LIB@ @RATCHET_LIB@
slimrelay_LDADD = libcommon.la libmain.la
slimrelay_SOURCES = slimrelay.c

slimqueue_LDFLAGS = @LUA_LIB@ @RATCHET_LIB@
slimqueue_LDADD = libcommon.la libmain.la
slimqueue_SOURCES = slimqueue.c

slimaster_LDFLAGS = @LUA_LIB@ @RATCHET_LIB@
slimaster_LDADD = libcommon.la libmain.la
slimaster_SOURCES = slimaster.c

