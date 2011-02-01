edgedatadir = $(pkgdatadir)/edge
commondatadir = $(pkgdatadir)/common

bin_PROGRAMS = slimedge

slimedge_LDFLAGS = @LUA_LIB@
slimedge_CFLAGS = -I../slimcommon/
slimedge_LDADD = ../slimcommon/libslimcommon.la
slimedge_SOURCES = slimedge.c

SUBDIRS = lua
