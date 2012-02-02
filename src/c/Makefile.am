
if ENABLE_DEVEL
include_HEADERS = slimta.h
lib_LTLIBRARIES = libslimta.la
else
noinst_LTLIBRARIES = libslimta.la
endif

libslimta_la_CFLAGS = -std=gnu99 -Wall -Wno-unused-function -Wno-unused-label
libslimta_la_LDFLAGS = 

libslimta_la_SOURCES = slimta.c \
		       rlimit.c \
		       uuid.c \
		       xml.c \
		       misc.c

lualibdir = @LUA_CPATH@
lualib_LTLIBRARIES = slimta.la
slimta_la_LDFLAGS = -module -avoid-version -shared
slimta_la_LIBADD = libslimta.la
slimta_la_SOURCES = 

