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

#include "slimta.h"

/* {{{ myconf_new() */
static int myconf_new (lua_State *L)
{
	const char *location = luaL_checkstring (L, 1);
	lua_settop (L, 2);

	if (NULL != luaL_findtable (L, LUA_GLOBALSINDEX, location, 1))
		return luaL_error (L, "Configuration option already taken: %s", location);

	luaL_getmetatable (L, "slimta_config_meta");
	lua_setmetatable (L, -2);

	if (!lua_isnil (L, 2))
	{
		lua_getfield (L, -1, "value");
		if (lua_isnil (L, -1))
		{
			lua_pushvalue (L, 2);
			lua_setfield (L, -3, "value");
		}
		lua_pop (L, 1);
	}

	return 1;
}
/* }}} */

/* {{{ myconf_call() */
static int myconf_call (lua_State *L)
{
	int nargs = lua_gettop (L) - 1;

	lua_getfield (L, 1, "func");
	if (!lua_isnil (L, -1))
	{
		lua_insert (L, 2);
		lua_call (L, nargs, 1);
		if (!lua_isnil (L, -1))
			return 1;
	}

	lua_getfield (L, 1, "value");

	return 1;
}
/* }}} */

/* {{{ luaopen_slimta_config() */
int luaopen_slimta_config (lua_State *L)
{
	const luaL_Reg funcs[] = {
		{"new", myconf_new},
		{NULL}
	};

	const luaL_Reg metameths[] = {
		{"__call", myconf_call},
		{NULL}
	};

	const luaL_Reg meths[] = {
		{NULL}
	};

	/* Set up the slimta.config class and metatables. */
	luaL_newmetatable (L, "slimta_config_meta");
	luaI_openlib (L, NULL, metameths, 0);
	lua_pop (L, 1);

	/* Set up the slimta.config namespace functions. */
	luaI_openlib (L, "slimta.config", funcs, 0);

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
