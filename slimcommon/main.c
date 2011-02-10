#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "slimcommon.h"

extern const char *DEFAULT_CONFIG;
extern const char *CONFIG_ENVVAR;
extern const char *entry_script;
extern const char *global_tables[];

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

/* {{{ load_config() */
static int load_config (lua_State *L)
{
	int i;

	/* Get config filename from env or default. */
	const char *filename = DEFAULT_CONFIG;
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_pushstring (L, CONFIG_ENVVAR);
	lua_call (L, 1, 1); 
	if (lua_isstring (L, -1))
		filename = lua_tostring (L, -1);
	lua_pop (L, 2);

	/* Set up globals with given tables pre-created. */
	for (i=0; global_tables[i] != NULL; i++)
	{
		luaL_findtable (L, LUA_GLOBALSINDEX, global_tables[i], 0);
		lua_pop (L, 1);
	}

	/* Load the config file as a Lua thread, set its environment, and call it. */
	if (luaL_dofile (L, filename) != 0)
		return lua_error (L);

	return 0;
}
/* }}} */

/* {{{ setup_kernel() */
static void setup_kernel (lua_State *L)
{
	luaopen_ratchet (L);

	/* Set up 'kernel' global by calling ratchet.new(). */
	lua_getfield (L, -1, "new");
	lua_call (L, 0, 1);
	lua_setglobal (L, "kernel");

	/* Set up 'uri' global by calling ratchet.uri.new(). */
	lua_getfield (L, -1, "uri");
	lua_getfield (L, -1, "new");
	lua_call (L, 0, 1);
	lua_setglobal (L, "uri");
	lua_pop (L, 1);
}
/* }}} */

/* {{{ main() */
int main (int argc, char *argv[])
{
	int ret;

	lua_State *L = luaL_newstate ();
	luaL_openlibs (L);
	slimcommon_openlibs (L);

	push_argvs_to_global (L, argc, argv);
	setup_kernel (L);
	load_config (L);

	lua_settop (L, 0);

	lua_getglobal (L, "require");
	lua_pushstring (L, entry_script);
	lua_call (L, 1, 0);

	lua_close (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
