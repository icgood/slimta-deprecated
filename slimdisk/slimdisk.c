#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "slimcommon.h"

#ifndef SLIMDISK_SCRIPT_PATH
#define SLIMDISK_SCRIPT_PATH "/usr/share/slimta/disk"
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

/* {{{ setup_globals() */
static void setup_globals (lua_State *L, int argc, char **argv)
{
	push_argvs_to_global (L, argc, argv);

	/* Initial table of storage engines, populated by included files. */
	lua_newtable (L);
	lua_setglobal (L, "storage_engines");
}
/* }}} */

/* {{{ get_script_path() */
static const char *get_script_path (const char *file)
{
	const char *envpath = getenv ("SLIMDISK_SCRIPT_PATH");
	const char *path = (envpath ? envpath : SLIMDISK_SCRIPT_PATH);
	if (!file)
		return path;

	static char with_file[1024];
	snprintf (with_file, 1024, "%s/%s", path, file);
	return with_file;
}
/* }}} */

/* {{{ get_common_path() */
static const char *get_common_path (const char *file)
{
	const char *envpath = getenv ("SLIMCOMMON_SCRIPT_PATH");
	const char *path = (envpath ? envpath : SLIMCOMMON_SCRIPT_PATH);
	if (!file)
		return path;

	static char with_file[1024];
	snprintf (with_file, 1024, "%s/%s", path, file);
	return with_file;
}
/* }}} */

/* {{{ main() */
int main (int argc, char *argv[])
{
	int ret;

	lua_State *L = luaL_newstate ();
	luaL_openlibs (L);
	luaopen_ratchet (L);

	slimcommon_openlibs (L);

	lua_getfield (L, -1, "add_path");
	lua_pushstring (L, get_script_path (NULL));
	lua_call (L, 1, 0);
	lua_settop (L, 0);

	lua_getfield (L, -1, "add_path");
	lua_pushstring (L, get_common_path (NULL));
	lua_call (L, 1, 0);
	lua_settop (L, 0);

	setup_globals (L, argc, argv);

	if (luaL_dofile (L, get_script_path ("config.lua")) != 0)
		return lua_error (L);
	if (luaL_dofile (L, get_script_path ("main.lua")) != 0)
		return lua_error (L);

	lua_close (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
