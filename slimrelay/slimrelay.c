#include <stdio.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "slimcommon.h"

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
	lua_setglobal (L, "arg");
}
/* }}} */

/* {{{ main() */
int main (int argc, char *argv[])
{
	int ret;

	lua_State *L = luaL_newstate ();
	luaL_openlibs (L);
	slimcommon_openlibs (L);

	lua_getfield (L, -1, "add_path");
	lua_pushstring (L, SLIMTA_SCRIPT_DIR);
	lua_call (L, 1, 0);

	push_argvs_to_global (L, argc, argv);
	if (luaL_dofile (L, SLIMTA_SCRIPT_DIR "/main.lua") != 0)
		return lua_error (L);

	lua_close (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
