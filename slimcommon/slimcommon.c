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
#include <string.h>
#include <sys/utsname.h>

#include <ratchet/misc.h>

#include "xml.h"

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

/* {{{ slimcommon_string_or_func() */
static int slimcommon_string_or_func (lua_State *L)
{
	if (lua_isstring (L, 1))
	{
		lua_settop (L, 1);
		return 1;
	}

	else if (lua_isfunction (L, 1))
	{
		int args = lua_gettop (L) - 1;
		lua_call (L, args, 1);
		return 1;
	}

	else
		return luaL_typerror (L, 1, "string or function");
}
/* }}} */

/* {{{ slimcommon_openlibs () */
int slimcommon_openlibs (lua_State *L)
{
	lua_pushcfunction (L, slimcommon_string_or_func);
	lua_setglobal (L, "get_conf");

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

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
