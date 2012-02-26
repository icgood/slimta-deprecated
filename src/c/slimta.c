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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>
#include <grp.h>

#include "slimta.h"

/* {{{ redirect_fd_to_filename() */
static int redirect_fd_to_filename (lua_State *L, int fd, const char *filename, int flags)
{
	if (!filename)
		return 0;

	if (close (fd) == -1)
		return ratchet_error_errno (L, "slimta.redirect_stdio()", "close");

	int new_fd = open (filename, flags);
	if (new_fd == -1)
		return ratchet_error_errno (L, "slimta.redirect_stdio()", "open");

	if (dup2 (new_fd, fd) == -1)
	{
		close (new_fd);
		return ratchet_error_errno (L, "slimta.redirect_stdio()", "dup2");
	}

	return 0;
}
/* }}} */

/* {{{ get_uid_arg() */
static uid_t get_uid_arg (lua_State *L, int index)
{
	if (lua_isnumber (L, index))
		return (uid_t) lua_tointeger (L, index);

	const char *user = luaL_checkstring (L, index);

	struct passwd *pwd = getpwnam (user);
	if (!pwd)
		ratchet_error_errno (L, "slimta.drop_privileges()", "getpwnam");

	return pwd->pw_uid;
}
/* }}} */

/* {{{ get_gid_arg() */
static gid_t get_gid_arg (lua_State *L, int index)
{
	if (lua_isnumber (L, index))
		return (gid_t) lua_tointeger (L, index);

	const char *group = luaL_checkstring (L, index);

	struct group *grp = getgrnam (group);
	if (!grp)
		ratchet_error_errno (L, "slimta.drop_privileges()", "getgrnam");

	return grp->gr_gid;
}
/* }}} */

/* ---- slimta Functions ---------------------------------------------------- */

/* {{{ slimta_redirect_stdio() */
static int slimta_redirect_stdio (lua_State *L)
{
	const char *out_filename = luaL_optstring (L, 1, NULL);
	const char *err_filename = luaL_optstring (L, 2, NULL);
	const char *in_filename = luaL_optstring (L, 3, NULL);

	redirect_fd_to_filename (L, 1, out_filename, O_WRONLY | O_CREAT | O_APPEND);
	redirect_fd_to_filename (L, 2, err_filename, O_WRONLY | O_CREAT | O_APPEND);
	redirect_fd_to_filename (L, 0, in_filename, O_RDONLY);

	return 0;
}
/* }}} */

/* {{{ slimta_daemonize() */
static int slimta_daemonize (lua_State *L)
{
	int devnull;
	pid_t newpid;

	/* The following ensure appropriate daemonization. */
	if (fork () != 0)
		_exit (0);
	setsid ();
	if (fork () != 0)
		_exit (0);
	if (chdir ("/") != 0)
		return ratchet_error_errno (L, "slimta.daemonize()", "chdir");

	umask (0);
	devnull = open ("/dev/null", O_RDWR);
	close (STDIN_FILENO);
	close (STDOUT_FILENO);
	close (STDERR_FILENO);
	dup2 (devnull, STDIN_FILENO);
	dup2 (devnull, STDOUT_FILENO);
	dup2 (devnull, STDERR_FILENO);
	close (devnull);
	setsid ();

	newpid = getpid ();
	lua_pushinteger (L, (lua_Integer) newpid);
	return 1;
}
/* }}} */

/* {{{ slimta_drop_privileges() */
static int slimta_drop_privileges (lua_State *L)
{
	uid_t uid = get_uid_arg (L, 1);
	gid_t gid = get_gid_arg (L, 2);

	if (-1 == setgid (gid))
		return ratchet_error_errno (L, "slimta.drop_privileges()", "setgid");

	if (-1 == setuid (uid))
		return ratchet_error_errno (L, "slimta.drop_privileges()", "setuid");

	return 0;
}
/* }}} */

/* ---- Public Functions ---------------------------------------------------- */

/* {{{ luaopen_slimta() */
int luaopen_slimta (lua_State *L)
{
	static const luaL_Reg funcs[] = {
		{"redirect_stdio", slimta_redirect_stdio},
		{"daemonize", slimta_daemonize},
		{"drop_privileges", slimta_drop_privileges},
		{NULL}
	};

	luaL_newlib (L, funcs);
	lua_pushvalue (L, -1);
	lua_setglobal (L, "slimta");

	lua_pushstring (L, VERSION);
	lua_setfield (L, -2, "version");

	luaL_requiref (L, "slimta.xml", luaopen_slimta_xml, 0);
	lua_setfield (L, -2, "xml");

	luaL_requiref (L, "slimta.uuid", luaopen_slimta_uuid, 0);
	lua_setfield (L, -2, "uuid");

	luaL_requiref (L, "slimta.rlimit", luaopen_slimta_rlimit, 0);
	lua_setfield (L, -2, "rlimit");

	luaL_requiref (L, "slimta.process", luaopen_slimta_rlimit, 0);
	lua_setfield (L, -2, "rlimit");

#if HAVE_SIGNALFD
	luaL_requiref (L, "slimta.signalfd", luaopen_slimta_signalfd, 0);
	lua_setfield (L, -2, "signalfd");
#endif

	luaL_requiref (L, "slimta.base64", luaopen_slimta_base64, 0);
	lua_setfield (L, -2, "base64");

	luaL_requiref (L, "slimta.hmac", luaopen_slimta_hmac, 0);
	lua_setfield (L, -2, "hmac");

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
