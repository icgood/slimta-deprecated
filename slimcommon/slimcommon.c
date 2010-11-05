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

#include <ratchet/misc.h>

#include "xml.h"

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

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
