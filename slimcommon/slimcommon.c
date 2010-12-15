/* Copyright (c) 2010 Ian C. Good
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "config.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

#include <ratchet/misc.h>

#include "xml.h"

/* {{{ slimcommon_string_or_func() */
static int slimcommon_string_or_func (lua_State *L)
{
	/* Call function with any args before attempting string conversion. */
	if (lua_isfunction (L, 1))
	{
		int args = lua_gettop (L) - 1;
		lua_call (L, args, 1);
	}
	lua_settop (L, 1);

	luaL_callmeta (L, 1, "__tostring");
	lua_tostring (L, -1);

	return 1;
}
/* }}} */

/* {{{ slimcommon_number_or_func() */
static int slimcommon_number_or_func (lua_State *L)
{
	/* Call function with any args before attempting number conversion. */
	if (lua_isfunction (L, 1))
	{
		int args = lua_gettop (L) - 1;
		lua_call (L, args, 1);
	}
	lua_settop (L, 1);

	lua_tonumber (L, 1);

	return 1;
}
/* }}} */

/* {{{ slimcommon_uname_index() */
static int slimcommon_uname_index (lua_State *L)
{
	struct utsname *info = (struct utsname *) lua_touserdata (L, 1);
	const char *index = luaL_checkstring (L, 2);
	if (strcmp (index, "sysname") == 0)
		lua_pushstring (L, info->sysname);
	else if (strcmp (index, "nodename") == 0)
		lua_pushstring (L, info->nodename);
	else if (strcmp (index, "release") == 0)
		lua_pushstring (L, info->release);
	else if (strcmp (index, "version") == 0)
		lua_pushstring (L, info->version);
	else if (strcmp (index, "machine") == 0)
		lua_pushstring (L, info->machine);
#ifdef _GNU_SOURCE
	else if (strcmp (index, "domainname") == 0)
		lua_pushstring (L, info->domainname);
#endif
	else
		lua_pushnil (L);
	return 1;

}
/* }}} */

/* {{{ slimcommon_init_uname() */
static int slimcommon_init_uname (lua_State *L)
{
	struct utsname *info = (struct utsname *) lua_newuserdata (L, sizeof (struct utsname));
	memset (info, 0, sizeof (struct utsname));
	if (uname (info) < 0)
		errno = 0;
	lua_createtable (L, 0, 1);
	lua_pushcfunction (L, slimcommon_uname_index);
	lua_setfield (L, -2, "__index");
	lua_setmetatable (L, -2);
	return 1;
}
/* }}} */

/* {{{ slimcommon_stackdump() */
static int slimcommon_stackdump (lua_State *L)
{
	rhelp_stackdump (L);

	return 0;
}
/* }}} */

/* {{{ slimcommon_add_path() */
static int slimcommon_add_path (lua_State *L)
{
	lua_settop (L, 1);
	luaL_checkstring (L, 1);
	luaopen_package (L);
	lua_settop (L, 1);
	lua_getglobal (L, "package");

	/* Set the new package.path. */
	lua_pushvalue (L, 1);
	lua_pushliteral (L, "/?.lua;");
	lua_getfield (L, 2, "path");
	lua_concat (L, 3);
	lua_setfield (L, 2, "path");

	/* Set the new package.cpath. */
	lua_pushvalue (L, 1);
	lua_pushliteral (L, "/?.so;");
	lua_getfield (L, 2, "cpath");
	lua_concat (L, 3);
	lua_setfield (L, 2, "cpath");

	lua_settop (L, 1);

	return 0;
}
/* }}} */

/* {{{ slimcommon_mkstemp_close() */
static int slimcommon_mkstemp_close (lua_State *L)
{
	FILE **fp = (FILE **) luaL_checkudata (L, 1, LUA_FILEHANDLE);
	int ok = (fclose (*fp) == 0);
	*fp = NULL;
	int eno = errno;
	if (ok)
	{
		lua_pushboolean (L, 1);
		return 1;
	}
	else
	{
		lua_pushnil (L);
		lua_pushfstring (L, "%s", strerror (eno));
		lua_pushinteger (L, eno);
		return 3;
	}
}
/* }}} */

/* {{{ slimcommon_mkstemp() */
static int slimcommon_mkstemp (lua_State *L)
{
	const char *tmpl_arg = luaL_checkstring (L, 1);
	char *tmpl = strdup (tmpl_arg);

	int fd = mkstemp (tmpl);
	if (fd == -1)
		return 0;

	FILE *f = fdopen (fd, "w");
	if (!f)
		return rhelp_perror (L);
	FILE **fobj = (FILE **) lua_newuserdata (L, sizeof (FILE *));
	*fobj = f;
	luaL_getmetatable (L, LUA_FILEHANDLE);
	lua_setmetatable (L, -2);
	lua_pushstring (L, tmpl);
	free (tmpl);

	return 2;
}
/* }}} */

/* {{{ slimcommon_openlibs () */
int slimcommon_openlibs (lua_State *L)
{
	const luaL_Reg get_conf_funcs[] = {
		{"string", slimcommon_string_or_func},
		{"number", slimcommon_number_or_func},
		{NULL}
	};
	luaL_register (L, "get_conf", get_conf_funcs);

	const luaL_Reg funcs[] = {
		{"stackdump", slimcommon_stackdump},
		{"add_path", slimcommon_add_path},
		{NULL}
	};
	luaL_register (L, "slimta", funcs);

	luaopen_slimta_xml (L);
	lua_setfield (L, -2, "xml");
	luaopen_slimta_rlimit (L);
	lua_setfield (L, -2, "rlimit");
	slimcommon_init_uname (L);
	lua_setfield (L, -2, "uname");

	/* Set up the mkstemp function. */
	lua_pushcfunction (L, slimcommon_mkstemp);
	lua_getglobal (L, "io");
	lua_getfield (L, -1, "open");
	lua_getfenv (L, -1);
	lua_setfenv (L, -4);
	lua_pop (L, 2);
	lua_setfield (L, -2, "mkstemp");

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
