bin_PROGRAMS = slimrelay

slimrelay_LDFLAGS = @LUA_LIB@
slimrelay_CFLAGS = -I../slimcommon/ -DSLIMRELAY_SCRIPT_PATH=\"$(pkgdatadir)\"
slimrelay_LDADD = ../slimcommon/libslimcommon.la
slimrelay_SOURCES = slimrelay.c

dist_pkgdata_DATA = smtp_session.lua \
		    smtp_states.lua \
		    smtp_context.lua \
		    message_results.lua \
		    local_storage.lua \
		    request_context.lua \
		    config.lua \
		    main.lua

