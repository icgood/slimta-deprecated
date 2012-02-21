#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.65])
AC_INIT([slimta], [0.0], [Ian Good <icgood@gmail.com>])
AM_INIT_AUTOMAKE([color-tests silent-rules])
LT_PREREQ([2.2])
LT_INIT([dlopen])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src/c/slimta.h])
AC_CONFIG_HEADERS([config.h])

#####################
# Check for programs.
AC_PROG_CC
AC_PROG_AWK
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AM_PROG_CC_C_O

#####################
# Configure options: --with-lua-cpath=CPATH
AC_ARG_WITH([lua-cpath], [AS_HELP_STRING([--with-lua-cpath=CPATH],
	                                 [Install Lua C modules to CPATH])])
if test "x${with_lua_cpath}" == "x"; then
	with_lua_cpath="`pkg-config lua --variable=INSTALL_CMOD`"
fi
AC_SUBST([LUA_CPATH], ["$with_lua_cpath"])

#####################
# Configure options: --with-lua-lpath=LPATH
AC_ARG_WITH([lua-lpath], [AS_HELP_STRING([--with-lua-lpath=LPATH],
	                                 [Install Lua modules to LPATH])])
if test "x${with_lua_lpath}" == "x"; then
	with_lua_lpath="`pkg-config lua --variable=INSTALL_LMOD`"
fi
AC_SUBST([LUA_LPATH], ["$with_lua_lpath"])

#####################
# Configure options: --enable-devel
AC_ARG_ENABLE([devel], [AS_HELP_STRING([--disable-devel],
	                               [do not install development headers and libraries.])],
	      [enable_devel="${enableval}"], [enable_devel=no])
AM_CONDITIONAL([ENABLE_DEVEL], [test "x${enable_devel}" != "xno"])

#####################
# Check for libraries.


# Lua
AX_WITH_LUA
if test "x${LUA}" == "x"; then
	AC_MSG_NOTICE([Lua interpreter not found, disabling build tests.])
else
	AX_WITH_LUA([502])
fi
AX_LUA_HEADERS
AX_LUA_HEADERS_VERSION([502])
AX_LUA_LIBS
if test "x${LUA_LIB}" == "x"; then
	AC_MSG_ERROR([Lua development libraries required for building.])
fi
LIBS="${LIBS} ${LUA_LIB}"
AC_SUBST([LUA], ["$LUA"])
AM_CONDITIONAL([HAVE_LUA_INTERPRETER], [test "x${LUA}" != "x"])

# Ratchet
AC_CHECK_HEADERS([ratchet.h], [have_ratchet=yes], [have_ratchet=no])
AC_CHECK_LIB([ratchet], [luaopen_ratchet], [], [have_ratchet=no])
if test "x${have_ratchet}" != "xyes"; then
	AC_MSG_ERROR([Lua Ratchet library is required for building.])
fi
AC_SUBST([RATCHET_LIB], [-lratchet])

# Lua CJSON
# http://www.kyne.com.au/~mark/software/lua-cjson.php
AC_MSG_CHECKING([lua cjson module])
AC_RUN_LOG([:$LUA -lcjson -e ''])
$LUA -lcjson -e '' >> config.log 2>&1
if test $? -eq 0; then
	AC_MSG_RESULT([yes])
else
	AC_MSG_ERROR([Lua CJSON library is required.])
fi

# Expat
AC_CHECK_HEADERS([expat.h], [have_expat=yes], [have_expat=no])
AC_SEARCH_LIBS([XML_ParserCreate], [expat], [], [have_expat=no])
if test "x${have_expat}" != "xyes"; then
	AC_MSG_ERROR([Expat headers and libraries are required for building.])
fi

# Libuuid
AC_CHECK_HEADERS([uuid/uuid.h], [have_uuid=yes], [have_uuid=no])
AC_SEARCH_LIBS([uuid_generate], [uuid], [], [have_uuid=no])
if test "x${have_uuid}" != "xyes"; then
	AC_MSG_ERROR([UUID generation libraries unavailable (see util-linux-ng).])
fi

#####################
# Checks for header files.
AC_CHECK_HEADERS([fcntl.h sys/ioctl.h sys/socket.h sys/time.h signal.h sys/signalfd.h pwd.h grp.h])
AX_LUA_HEADERS
if test "x${ac_cv_header_lua_h}" != "xyes"; then
	AC_MSG_ERROR([Lua headers are required for building.])
fi

#####################
# Checks for typedefs, structures, and compiler characteristics.
AC_TYPE_SIZE_T
AC_TYPE_SSIZE_T

#####################
# Checks for library functions.
AC_CHECK_FUNCS([memset modf strchr strdup strerror uname sigaction on_exit signalfd getpwnam getgrnam])
AC_FUNC_STRERROR_R

AC_CONFIG_FILES([Makefile
		 test/Makefile
		 src/c/Makefile
		 src/lua/Makefile
])

AC_OUTPUT
