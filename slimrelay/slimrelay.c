#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "slimcommon.h"
#include "misc.h"
#include "globals.h"

#define ME "slimrelay"

/* {{{ main() */
int main (int argc, char *argv[])
{
	int ret;

	lua_State *L = luaL_newstate ();
	luaL_openlibs (L);
	luaopen_ratchet (L);
	slimcommon_openlibs (L);

	slimta_setup_globals (L, argc, argv);
	slimta_load_config (L, ME);

	lua_settop (L, 0);

	lua_getglobal (L, "require");
	lua_pushliteral (L, ME);
	lua_call (L, 1, 0);

	lua_close (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
