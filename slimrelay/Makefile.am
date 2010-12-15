relaydatadir = $(pkgdatadir)/relay
commondatadir = $(pkgdatadir)/common

bin_PROGRAMS = slimrelay

slimrelay_LDFLAGS = @LUA_LIB@
slimrelay_CFLAGS = -I../slimcommon/
slimrelay_CFLAGS += -DSLIMRELAY_SCRIPT_PATH=\"$(relaydatadir)\"
slimrelay_CFLAGS += -DSLIMCOMMON_SCRIPT_PATH=\"$(commondatadir)\"
slimrelay_LDADD = ../slimcommon/libslimcommon.la
slimrelay_SOURCES = slimrelay.c

SUBDIRS = lua
