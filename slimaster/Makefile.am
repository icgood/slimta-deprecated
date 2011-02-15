masterdatadir = $(pkgdatadir)/master
commondatadir = $(pkgdatadir)/common

bin_PROGRAMS = slimaster

slimaster_LDFLAGS = @LUA_LIB@
slimaster_CFLAGS = -I../slimcommon/
slimaster_LDADD = ../slimcommon/libslimcommon.la
slimaster_SOURCES = slimaster.c

SUBDIRS = lua
