queuedatadir = $(pkgdatadir)/queue
commondatadir = $(pkgdatadir)/common

bin_PROGRAMS = slimqueue

slimqueue_LDFLAGS = @LUA_LIB@
slimqueue_CFLAGS = -I../slimcommon/ 
slimqueue_LDADD = ../slimcommon/libslimcommon.la
slimqueue_SOURCES = slimqueue.c

SUBDIRS = lua
