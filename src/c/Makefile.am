
if ENABLE_DEVEL
include_HEADERS = slimta.h
lib_LTLIBRARIES = libslimta.la
else
noinst_LTLIBRARIES = libslimta.la
endif

lualibdir = @WITH_LUA_LPATH@
lualib_LTLIBRARIES = slimta.la
slimta_la_LDFLAGS = -module -avoid-version -shared
slimta_la_LIBADD = libslimta.la

libslimta_la_SOURCES = config_.c \
		       rlimit.c \
		       uuid.c \
		       slimta.c \
		       xml.c \
		       misc.c

