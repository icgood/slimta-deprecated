#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <dirent.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <ratchet.h>

#include "misc.h"
#include "slimta.h"

#include "config.h"

extern const char *which_config;
extern const char *which_setups[];

#ifndef SYSCONFDIR
static const char *DEFAULT_CONF_PATH = "/etc/" PACKAGE;
#else
static const char *DEFAULT_CONF_PATH = SYSCONFDIR "/slimta";
#endif
static const char *CONF_PATH_ENVVAR = "SLIMTA_CONF_PATH";

#ifndef PKGLIBDIR
static const char *DEFAULT_LIB_PATH = "/var/lib/slimta";
#else
static const char *DEFAULT_LIB_PATH = PKGLIBDIR;
#endif
static const char *LIB_PATH_ENVVAR = "SLIMTA_LIB_PATH";

static const char *global_tables[] = {
	"modules",

	"modules.protocols.http",
	"modules.protocols.relay",
	"modules.protocols.edge",
	"modules.engines.storage",
	"modules.engines.prestorage",

	NULL
};

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
	/* Uncomment these lines to check for global namespace pollution on exit. */
	/* lua_settop (L, 0);
	 * lua_pushvalue (L, LUA_GLOBALSINDEX);
	 * for (lua_pushnil (L); lua_next (L, 1) != 0; lua_pop (L, 1))
	 * {
	 * 	const char *key = lua_tostring (L, -2);
	 * 	printf ("%s\n", key);
	 * }
	 */

	lua_close (L);

	_exit (0);
}
/* }}} */

/* {{{ handle_exitsig() */
static void handle_exitsig (int signum)
{
	printf ("\n");
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

/* {{{ setup_kernel() */
static void setup_kernel (lua_State *L)
{
	luaopen_ratchet (L);

	/* Set up 'kernel' global by calling ratchet.new(). */
	lua_getfield (L, -1, "new");
	lua_call (L, 0, 1);
	lua_setglobal (L, "kernel");
}
/* }}} */

/* {{{ set_paths() */
static int set_paths (lua_State *L)
{
	int i = 0;

	lua_getglobal (L, "package");

	/* Set up initial (default) path set. */
	lua_newtable (L);
	lua_pushliteral (L, ";");
	lua_rawseti (L, -2, ++i);

	/* Add the lib path for ?.lua. */
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_remove (L, -2);
	lua_pushstring (L, LIB_PATH_ENVVAR);
	lua_call (L, 1, 1);
	if (!lua_isstring (L, -1))
	{
		lua_pushstring (L, DEFAULT_LIB_PATH);
		lua_replace (L, -2);
	}
	lua_pushliteral (L, "/?.lua");
	lua_concat (L, 2);
	lua_rawseti (L, -2, ++i);

	/* Add the lib path for ?/init.lua. */
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_remove (L, -2);
	lua_pushstring (L, LIB_PATH_ENVVAR);
	lua_call (L, 1, 1);
	if (!lua_isstring (L, -1))
	{
		lua_pushstring (L, DEFAULT_LIB_PATH);
		lua_replace (L, -2);
	}
	lua_pushliteral (L, "/?/init.lua");
	lua_concat (L, 2);
	lua_rawseti (L, -2, ++i);

	/* Concatenate table values. */
	lua_getglobal (L, "table");
	lua_getfield (L, -1, "concat");
	lua_remove (L, -2);
	lua_pushvalue (L, -2);
	lua_pushliteral (L, ";");
	lua_call (L, 2, 1);

	/* Set path into package.path. */
	lua_setfield (L, -3, "path");
	lua_pop (L, 2);

	return 0;
}
/* }}} */

/* {{{ set_cpaths() */
static int set_cpaths (lua_State *L)
{
	int i = 0;

	lua_getglobal (L, "package");

	/* Set up initial (default) path set. */
	lua_newtable (L);
	lua_pushliteral (L, ";");
	lua_rawseti (L, -2, ++i);

	/* Add the lib path for ?.so. */
	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_remove (L, -2);
	lua_pushstring (L, LIB_PATH_ENVVAR);
	lua_call (L, 1, 1);
	if (!lua_isstring (L, -1))
	{
		lua_pushstring (L, DEFAULT_LIB_PATH);
		lua_replace (L, -2);
	}
	lua_pushliteral (L, "/?.so");
	lua_concat (L, 2);
	lua_rawseti (L, -2, ++i);

	/* Concatenate table values. */
	lua_getglobal (L, "table");
	lua_getfield (L, -1, "concat");
	lua_remove (L, -2);
	lua_pushvalue (L, -2);
	lua_pushliteral (L, ";");
	lua_call (L, 2, 1);

	/* Set path into package.cpath. */
	lua_setfield (L, -3, "cpath");
	lua_pop (L, 2);

	return 0;
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

/* {{{ global_configs_dodir() */
static int global_configs_dodir (lua_State *L, const char *fromdir)
{
	lua_pushstring (L, fromdir);
	lua_pushliteral (L, "/conf.d/");
	lua_concat (L, 2);

	DIR *dir = opendir (lua_tostring (L, -1));
	if (!dir)
		return handle_perror (L);
	
	struct dirent *entry;
	while ((entry = readdir (dir)) != NULL)
	{
		lua_getglobal (L, "dofile");
		lua_pushvalue (L, -2);

		lua_getfield (L, 2, "match");
		lua_pushstring (L, entry->d_name);
		lua_pushliteral (L, ".-%.conf");
		lua_call (L, 2, 1);

		if (!lua_isnil (L, -1))
		{
			lua_concat (L, 2);
			lua_call (L, 1, 0);
		}
		else
			lua_pop (L, 3);
	}

	closedir (dir);
	lua_pop (L, 1);

	return 0;
}
/* }}} */

/* {{{ run_dofile_on_configs() */
static int run_dofile_on_configs (lua_State *L)
{
	lua_getglobal (L, "dofile");

	lua_getglobal (L, "os");
	lua_getfield (L, -1, "getenv");
	lua_remove (L, -2);
	lua_pushstring (L, CONF_PATH_ENVVAR);
	lua_call (L, 1, 1);
	if (!lua_isstring (L, -1))
	{
		lua_pushstring (L, DEFAULT_CONF_PATH);
		lua_replace (L, -2);
	}
	global_configs_dodir(L, lua_tostring (L, -1));
	lua_pushliteral (L, "/");
	lua_pushstring (L, which_config);
	lua_concat (L, 3);

	lua_call (L, 1, 0);

	return 0;
}
/* }}} */

/* {{{ run_require_on_setups() */
static int run_require_on_setups (lua_State *L)
{
	int i;

	/* Run require(f) for each f in which_setups. */
	for (i=0; which_setups[i] != NULL; i++)
	{
		lua_getglobal (L, "require");
		lua_pushstring (L, which_setups[i]);
		lua_call (L, 1, 0);
	}

	return 0;
}
/* }}} */

/* {{{ hand_control_to_kernel() */
static int hand_control_to_kernel (lua_State *L)
{
	lua_getglobal (L, "kernel");
	lua_getfield (L, -1, "loop");
	lua_insert (L, -2);
	lua_call (L, 1, 0);

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
	slimta_openlibs (L);

	push_argvs_to_global (L, argc, argv);
	setup_kernel (L);
	setup_globals (L);
	lua_settop (L, 0);

	set_paths (L);
	set_cpaths (L);
	run_require_on_setups (L);
	run_dofile_on_configs (L);

	hand_control_to_kernel (L);

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
