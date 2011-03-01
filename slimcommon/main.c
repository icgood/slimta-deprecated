#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "misc.h"
#include "slimcommon.h"

extern const char *DEFAULT_CONFIG;
extern const char *CONFIG_ENVVAR;
extern const char *DEFAULT_MY_CONFIG;
extern const char *MY_CONFIG_ENVVAR;
extern const char *DEFAULT_PATH;
extern const char *PATH_ENVVAR;
extern const char *entry_script;
extern const char *global_tables[];
extern const char *required_globals[];

/* {{{ handle_exit() */
#if HAVE_ON_EXIT
static void handle_exit (int ret, void *data)
{
	lua_State *L = (lua_State *) data;
#else
lua_State *L_global = NULL;
static void handle_exit (void)
{
	lua_State *L = L_global;
#endif
	/* Uncomment these lines to check for global namespace pollution on exit.
	 * lua_settop (L, 0);
	 * lua_pushvalue (L, LUA_GLOBALSINDEX);
	 * for (lua_pushnil (L); lua_next (L, 1) != 0; lua_pop (L, 1))
	 * {
	 * 	const char *key = lua_tostring (L, -2);
	 * 	printf ("%s\n", key);
	 * }
	 */

	lua_close (L);
}
/* }}} */

/* {{{ handle_exitsig() */
static void handle_exitsig (int signum)
{
	exit (0);
}
/* }}} */

/* {{{ setup_exit_handler() */
static void setup_exit_handler (lua_State *L)
{
#if HAVE_ON_EXIT
	on_exit (handle_exit, L);
#else
	L_global = L;
	atexit (handle_exit);
#endif

	struct sigaction act;
	memset (&act, 0, sizeof (act));
	act.sa_handler = handle_exitsig;
	sigaction (SIGINT, &act, NULL);
	sigaction (SIGTERM, &act, NULL);
}
/* }}} */

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
static int load_config (lua_State *L, const char *def, const char *envvar)
{
	/* Get config filename from env or default. */
	const char *filename = def;
	if (envvar)
	{
		lua_getglobal (L, "os");
		lua_getfield (L, -1, "getenv");
		lua_pushstring (L, envvar);
		lua_call (L, 1, 1);
		if (lua_isstring (L, -1))
			filename = lua_tostring (L, -1);
		lua_pop (L, 2);
	}

	/* Load the config file as a Lua thread, set its environment, and call it. */
	if (filename && luaL_dofile (L, filename) != 0)
		return lua_error (L);

	return 0;
}
/* }}} */

/* {{{ setup_path() */
static int setup_path (lua_State *L)
{
	/* Get path from env or default. */
	const char *path = DEFAULT_PATH;
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_pushstring (L, PATH_ENVVAR);
	lua_call (L, 1, 1); 
	if (lua_isstring (L, -1))
		path = lua_tostring (L, -1);
	lua_pop (L, 2);

	/* Set path into package.path. */
	lua_getglobal (L, "package");
	lua_pushstring (L, path);
	lua_setfield (L, -2, "path");
	lua_pop (L, 1);

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

	/* Set up 'dns' global by calling ratchet.dns.new(). */
	lua_getfield (L, -1, "dns");
	lua_getfield (L, -1, "new");
	lua_getglobal (L, "kernel");
	lua_call (L, 1, 1);
	lua_setglobal (L, "dns");
	lua_pop (L, 1);
}
/* }}} */

/* {{{ setup_globals() */
static int setup_globals (lua_State *L)
{
	int i;

	/* Set up globals with given tables pre-created. */
	for (i=0; global_tables[i] != NULL; i++)
	{
		luaL_findtable (L, LUA_GLOBALSINDEX, global_tables[i], 0);
		lua_pop (L, 1);
	}

	return 0;
}
/* }}} */

/* {{{ enforce_required_globals() */
static int enforce_required_globals (lua_State *L)
{
	int i;

	/* Check all required config values. */
	for (i=0; required_globals[i] != NULL; i++)
	{
		lua_getglobal (L, required_globals[i]);
		if (lua_isnil (L, -1))
			return luaL_error (L, "required config value not set: %s", required_globals[i]);
		lua_pop (L, 1);
	}

	return 0;
}
/* }}} */

/* {{{ main() */
int main (int argc, char *argv[])
{
	int ret;

	lua_State *L = luaL_newstate ();
	setup_exit_handler (L);
	luaL_openlibs (L);
	slimcommon_openlibs (L);

	push_argvs_to_global (L, argc, argv);
	setup_kernel (L);
	setup_path (L);
	setup_globals (L);
	load_config (L, DEFAULT_CONFIG, CONFIG_ENVVAR);
	load_config (L, DEFAULT_MY_CONFIG, MY_CONFIG_ENVVAR);
	enforce_required_globals (L);

	lua_settop (L, 0);

	lua_getglobal (L, "require");
	lua_pushstring (L, entry_script);
	lua_call (L, 1, 0);

	lua_close (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
