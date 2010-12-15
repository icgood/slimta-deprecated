diskdatadir = $(pkgdatadir)/disk
commondatadir = $(pkgdatadir)/common

bin_PROGRAMS = slimdisk

slimdisk_LDFLAGS = @LUA_LIB@
slimdisk_CFLAGS = -I../slimcommon/ 
slimdisk_CFLAGS += -DSLIMDISK_SCRIPT_PATH=\"$(diskdatadir)\"
slimdisk_CFLAGS += -DSLIMCOMMON_SCRIPT_PATH=\"$(commondatadir)\"
slimdisk_LDADD = ../slimcommon/libslimcommon.la
slimdisk_SOURCES = slimdisk.c

SUBDIRS = lua
