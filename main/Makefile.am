
noinst_LTLIBRARIES = libmain.la
libmain_la_LDFLAGS = @LUA_LIB@ @RATCHET_LIB@
libmain_la_SOURCES = misc.h misc.c \
		     config.h config.c \
		     xml.h xml.c \
		     rlimit.h rlimit.c \
		     uuid.h uuid.c \
		     slimta.c slimta.h \
		     main.c

dist_pkglib_DATA = setup.lua

bin_PROGRAMS = slimedge slimrelay slimqueue slimaster

slimedge_LDADD = libmain.la
slimedge_SOURCES = slimedge.c

slimrelay_LDADD = libmain.la
slimrelay_SOURCES = slimrelay.c

slimqueue_LDADD = libmain.la
slimqueue_SOURCES = slimqueue.c

slimaster_LDADD = libmain.la
slimaster_SOURCES = slimaster.c

