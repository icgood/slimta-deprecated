bin_PROGRAMS = slimqueue

slimqueue_LDFLAGS = @LUA_LIB@
slimqueue_CFLAGS = -I../slimcommon/ -DSLIMQUEUE_SCRIPT_PATH=\"$(pkgdatadir)\"
slimqueue_LDADD = ../slimcommon/libslimcommon.la
slimqueue_SOURCES = slimqueue.c

dist_pkgdata_DATA = \
		    config.lua \
		    main.lua

