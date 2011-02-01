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

#include <string.h>

#include "misc.h"
#include "globals.h"

static const char *global_tables[] = {
	"storage_engines",
	"slimrelay.protocols",
	"slimrelay.connections",
	NULL
};

extern char **environ;

#ifndef SLIMTA_CONFIG_DEFAULT
#define SLIMTA_CONFIG_DEFAULT "/etc/slimta.conf"
#endif

/* {{{ push_argvs_to_global() */
static void push_argvs_to_global (lua_State *L, int argc, char **argv)
{
	int i;
	lua_newtable (L);
	for (i=0; i<argc; i++)
	{
		lua_pushstring (L, argv[i]);
		lua_rawseti (L, -2, i);
	}
	lua_pushliteral (L, "n");
	lua_pushinteger (L, argc);
	lua_rawset (L, -3);
	lua_setglobal (L, "arg");

}
/* }}} */

/* {{{ slimta_setup_globals() */
void slimta_setup_globals (lua_State *L, int argc, char **argv)
{
	push_argvs_to_global (L, argc, argv);
}
/* }}} */

/* {{{ slimta_load_config() */
int slimta_load_config (lua_State *L, const char *nspace)
{
	int i;

	/* Get config filename from env or default. */
	const char *filename = SLIMTA_CONFIG_DEFAULT;
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_pushliteral (L, "SLIMTA_CONFIG");
	lua_call (L, 1, 1); 
	if (lua_isstring (L, -1))
		filename = lua_tostring (L, -1);
	lua_pop (L, 2);

	/* Set up 'config' global table with given tables pre-created. */
	for (i=0; global_tables[i] != NULL; i++)
	{
		luaL_findtable (L, LUA_GLOBALSINDEX, global_tables[i], 0);
		lua_pop (L, 1);
	}

	/* Load the config file as a Lua thread, set its environment, and call it. */
	if (luaL_dofile (L, filename) != 0)
		return lua_error (L);

	/* Pull values from config[nspace] table into root of config. */
	lua_getglobal (L, nspace);
	if (lua_istable (L, -1))
	{
		for (lua_pushnil (L); lua_next (L, -2) != 0; lua_pop (L, 1))
		{
			lua_pushvalue (L, -2);
			lua_pushvalue (L, -2);
			lua_settable (L, LUA_GLOBALSINDEX);
		}
	}
	lua_pop (L, 1);

	/* Wipe the namespace from global, after we pulled its data. */
	lua_pushnil (L);
	lua_setglobal (L, nspace);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
