#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([slimta], [0.0], [Ian Good <icgood@gmail.com>])
AM_INIT_AUTOMAKE
LT_PREREQ([2.2])
LT_INIT([dlopen])
AC_CONFIG_MACRO_DIR([m4])
#AC_CONFIG_SRCDIR([])
AC_CONFIG_HEADERS([config.h])

# Check for programs.
AC_PROG_CC
AC_PROG_AWK
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AM_PROG_CC_C_O

# Check for libraries.
AX_LUA_LIBS
if test "x${LUA_LIB}" == "x"; then
	AC_MSG_ERROR([Lua libraries required for building.])
fi
AC_SUBST([LUA_LIB])

AC_CHECK_HEADERS([ratchet.h], [have_ratchet=yes], [have_ratchet=no])
AC_SEARCH_LIBS([luaopen_ratchet], [ratchet], [], [have_ratchet=no], $LUA_LIB)
if test "x${have_ratchet}" != "xyes"; then
	AC_MSG_ERROR([Lua Ratchet library is required for building.])
fi

AC_CHECK_HEADERS([expat.h], [have_expat=yes], [have_expat=no])
AC_SEARCH_LIBS([XML_ParserCreate], [expat], [], [have_expat=no], $LUA_LIB)
if test "x${have_expat}" != "xyes"; then
	AC_MSG_ERROR([Expat headers and libraries are required for building.])
fi

# Check for header files.
AX_LUA_HEADERS
if test "x${ac_cv_header_lua_h}" != "xyes"; then
	AC_MSG_ERROR([Lua headers are required for building.])
fi

# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T

# Checks for library functions.

AC_CONFIG_FILES([Makefile
		 slimcommon/Makefile
		 slimrelay/Makefile
		 slimqueue/Makefile
		 slimedge/Makefile])
AC_OUTPUT
