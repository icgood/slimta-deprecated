#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([slimta], [0.0], [Ian Good <icgood@gmail.com>])
AM_INIT_AUTOMAKE
LT_PREREQ([2.2])
LT_INIT([dlopen])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([main/slimrelay.c])
AC_CONFIG_HEADERS([config.h])

# Check for programs.
AC_PROG_CC
AC_PROG_AWK
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AM_PROG_CC_C_O

# Check for libraries.
AX_LUA_HEADERS
AX_LUA_HEADERS_VERSION([501])
AX_LUA_LIBS
if test "x${LUA_LIB}" == "x"; then
	AC_MSG_ERROR([Lua development libraries required for building.])
fi
AC_SUBST([LUA_LIB])

AC_CHECK_HEADERS([ratchet.h], [have_ratchet=yes], [have_ratchet=no])
AC_CHECK_LIB([ratchet], [luaopen_ratchet], [:], [have_ratchet=no], $LUA_LIB)
if test "x${have_ratchet}" != "xyes"; then
	AC_MSG_ERROR([Lua Ratchet library is required for building.])
fi
AC_SUBST([RATCHET_LIB], [-lratchet])

AC_CHECK_HEADERS([expat.h], [have_expat=yes], [have_expat=no])
AC_SEARCH_LIBS([XML_ParserCreate], [expat], [], [have_expat=no])
if test "x${have_expat}" != "xyes"; then
	AC_MSG_ERROR([Expat headers and libraries are required for building.])
fi

AC_CHECK_HEADERS([uuid/uuid.h], [have_uuid=yes], [have_uuid=no])
AC_SEARCH_LIBS([uuid_generate], [uuid], [], [have_uuid=no])
if test "x${have_uuid}" != "xyes"; then
	AC_MSG_ERROR([UUID generation libraries unavailable (see util-linux-ng).])
fi

# Check for header files.
AX_LUA_HEADERS
if test "x${ac_cv_header_lua_h}" != "xyes"; then
	AC_MSG_ERROR([Lua headers are required for building.])
fi

AC_CHECK_HEADERS([fcntl.h sys/ioctl.h sys/socket.h sys/time.h signal.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T

# Checks for library functions.
AC_CHECK_FUNCS([memset modf strchr strdup strerror uname sigaction on_exit])
AC_FUNC_STRERROR_R

AC_CONFIG_FILES([Makefile
		 etc/Makefile
		 main/Makefile

		 slimedge/Makefile
		 slimqueue/Makefile
		 slimrelay/Makefile
		 slimaster/Makefile

		 modules/Makefile
		 modules/protocols/Makefile
		 modules/protocols/edge/Makefile
		 modules/protocols/relay/Makefile
		 modules/engines/Makefile
		 modules/engines/storage/Makefile
		 modules/engines/prestorage/Makefile
		 modules/engines/nexthop/Makefile
		 modules/engines/failure/Makefile
		 modules/engines/attempting/Makefile
		 modules/engines/http/Makefile
		 modules/engines/smtp/Makefile
		 modules/engines/smtp/client/Makefile
		 modules/engines/smtp/server/Makefile
])

AC_OUTPUT
