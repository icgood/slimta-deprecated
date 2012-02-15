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

#if HAVE_SIGNALFD

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/signalfd.h>
#include <errno.h>

#include <ratchet.h>

#include "slimta.h"

#define is_signal_name(L, n, sig) do { if (0 == strcmp (#sig, n)) return sig; } while (0)
#define is_signal_num(L, s, sig) do { if (s == sig) return #sig; } while (0)
#define signalfd_fd(L, i) (int *) luaL_checkudata (L, i, "slimta_signalfd_meta")

/* {{{ get_signal_num() */
static int get_signal_num (lua_State *L, const char *n)
{
	is_signal_name (L, n, SIGHUP);
	is_signal_name (L, n, SIGINT);
	is_signal_name (L, n, SIGQUIT);
	is_signal_name (L, n, SIGILL);
	is_signal_name (L, n, SIGABRT);
	is_signal_name (L, n, SIGFPE);
	is_signal_name (L, n, SIGSEGV);
	is_signal_name (L, n, SIGPIPE);
	is_signal_name (L, n, SIGALRM);
	is_signal_name (L, n, SIGTERM);
	is_signal_name (L, n, SIGUSR1);
	is_signal_name (L, n, SIGUSR2);
	is_signal_name (L, n, SIGCHLD);
	is_signal_name (L, n, SIGCONT);
	is_signal_name (L, n, SIGTSTP);
	is_signal_name (L, n, SIGTTIN);
	is_signal_name (L, n, SIGTTOU);
	is_signal_name (L, n, SIGKILL);
	is_signal_name (L, n, SIGSTOP);
	return 0;
}
/* }}} */

/* {{{ get_signal_name() */
static const char *get_signal_name (lua_State *L, int sig)
{
	is_signal_num (L, sig, SIGHUP);
	is_signal_num (L, sig, SIGINT);
	is_signal_num (L, sig, SIGQUIT);
	is_signal_num (L, sig, SIGILL);
	is_signal_num (L, sig, SIGABRT);
	is_signal_num (L, sig, SIGFPE);
	is_signal_num (L, sig, SIGSEGV);
	is_signal_num (L, sig, SIGPIPE);
	is_signal_num (L, sig, SIGALRM);
	is_signal_num (L, sig, SIGTERM);
	is_signal_num (L, sig, SIGUSR1);
	is_signal_num (L, sig, SIGUSR2);
	is_signal_num (L, sig, SIGCHLD);
	is_signal_num (L, sig, SIGCONT);
	is_signal_num (L, sig, SIGTSTP);
	is_signal_num (L, sig, SIGTTIN);
	is_signal_num (L, sig, SIGTTOU);
	is_signal_num (L, sig, SIGKILL);
	is_signal_num (L, sig, SIGSTOP);
	return NULL;
}
/* }}} */

/* ---- Namespace Functions ------------------------------------------------- */

/* {{{ sfd_mask() */
static int sfd_mask (lua_State *L)
{
	int i, sig;
	sigset_t *mask = (sigset_t *) lua_newuserdata (L, sizeof (sigset_t));
	luaL_getmetatable (L, "slimta_signalfd_mask_meta");
	lua_setmetatable (L, -2);

	sigemptyset (mask);

	for (i=1; ; i++)
	{
		lua_rawgeti (L, 1, i);
		if (lua_isnil (L, -1))
		{
			lua_pop (L, 1);
			break;
		}
		sig = get_signal_num (L, lua_tostring (L, -1));
		if (sig == 0)
			return luaL_error (L, "Invalid signal name: %s", lua_tostring (L, -1));
		sigaddset (mask, sig);
		lua_pop (L, 1);
	}

	return 1;
}
/* }}} */

/* {{{ sfd_sigprocmask() */
static int sfd_sigprocmask (lua_State *L)
{
	static const char *lst[] = {"block", "SIG_BLOCK", "setmask", "SIG_SETMASK", "unblock", "SIG_UNBLOCK", NULL};
	static const int howlst[] = {SIG_BLOCK, SIG_BLOCK, SIG_SETMASK, SIG_SETMASK, SIG_UNBLOCK, SIG_UNBLOCK};
	int how = howlst[luaL_checkoption (L, 1, "block", lst)];

	sigset_t *mask = (sigset_t *) luaL_checkudata (L, 2, "slimta_signalfd_mask_meta");
	sigset_t *oldmask = (sigset_t *) lua_newuserdata (L, sizeof (sigset_t));
	luaL_getmetatable (L, "slimta_signalfd_mask_meta");
	lua_setmetatable (L, -2);

	int ret = sigprocmask (how, mask, oldmask);
	if (ret == -1)
		return ratchet_error_errno (L, "slimta.signalfd.sigprocmask()", "sigprocmask");

	return 1;
}
/* }}} */

/* {{{ sfd_new() */
static int sfd_new (lua_State *L)
{
	int *tfd = (int *) lua_newuserdata (L, sizeof (int));
	*tfd = -1;

	luaL_getmetatable (L, "slimta_signalfd_meta");
	lua_setmetatable (L, -2);

	return 1;
}
/* }}} */

/* ---- Member Functions ---------------------------------------------------- */

/* {{{ sfd_setmask() */
static int sfd_setmask (lua_State *L)
{
	int *fd = signalfd_fd (L, 1);
	sigset_t *mask = (sigset_t *) luaL_checkudata (L, 2, "slimta_signalfd_mask_meta");
	*fd = signalfd (*fd, mask, SFD_NONBLOCK);
	if (*fd == -1)
		return ratchet_error_errno (L, "slimta.signalfd.setmask()", "signalfd");
	return 0;
}
/* }}} */

/* {{{ sfd_close() */
static int sfd_close (lua_State *L)
{
	int *fd = signalfd_fd (L, 1);
	if (*fd < 0)
		return 0;

	int ret = close (*fd);
	if (ret == -1)
		return ratchet_error_errno (L, "slimta.signalfd.close()", "close");
	*fd = -1;

	return 0;
}
/* }}} */

/* {{{ sfd_get_fd() */
static int sfd_get_fd (lua_State *L)
{
	int fd = *signalfd_fd (L, 1);
	lua_pushinteger (L, fd);
	return 1;
}
/* }}} */

/* {{{ sfd_read() */
static int sfd_read (lua_State *L)
{
	int ctx = 0;
	lua_getctx (L, &ctx);
	if (ctx == 1 && !lua_toboolean (L, 2))
		return ratchet_error_str (L, "slimta.signalfd.read()", "ETIMEDOUT", "Timed out waiting for signals.");

	lua_settop (L, 1);
	int fd = *signalfd_fd (L, 1);
	struct signalfd_siginfo fdsi;
	ssize_t ret;

	ret = read (fd, &fdsi, sizeof (fdsi));
	if (ret == -1)
	{
		if (errno == EAGAIN || errno == EWOULDBLOCK)
		{
			lua_pushlightuserdata (L, RATCHET_YIELD_READ);
			lua_pushvalue (L, 1);
			return lua_yieldk (L, 2, 1, sfd_read);
		}

		else
			return ratchet_error_errno (L, "slimta.signalfd.read()", "read");
	}

	else if (ret < sizeof (fdsi))
		return ratchet_error_str (L, "slimta.signalfd.read()", "read", "Incomplete read of signal info.");

	const char *signame = get_signal_name (L, (int) fdsi.ssi_signo);
	if (signame)
		lua_pushstring (L, signame);
	else
		return ratchet_error_str (L, "slimta.signalfd.read()", "read", "Unknown signal number: %d", (int) fdsi.ssi_signo);

	return 1;
}
/* }}} */

/* ---- Public Functions ---------------------------------------------------- */

/* {{{ luaopen_slimta_signalfd() */
int luaopen_slimta_signalfd (lua_State *L)
{
	/* Static functions in the slimta.signalfd namespace. */
	static const luaL_Reg funcs[] = {
		{"new", sfd_new},
		{"mask", sfd_mask},
		{"sigprocmask", sfd_sigprocmask},
		{NULL}
	};

	/* Meta-methods for slimta.signalfd object metatables. */
	static const luaL_Reg metameths[] = {
		{"__gc", sfd_close},
		{NULL}
	};

	/* Methods in the slimta.signalfd class. */
	static const luaL_Reg meths[] = {
		/* Documented methods. */
		{"setmask", sfd_setmask},
		{"close", sfd_close},
		{"get_fd", sfd_get_fd},
		{"read", sfd_read},
		/* Undocumented, helper methods. */
		{NULL}
	};

	/* Set up the slimta.signalfd namespace functions. */
	luaL_newlib (L, funcs);
	lua_pushvalue (L, -1);
	lua_setfield (L, LUA_REGISTRYINDEX, "slimta_signalfd_class");

	/* Set up the slimta.signalfd class and metatables. */
	luaL_newmetatable (L, "slimta_signalfd_meta");
	lua_newtable (L);
	luaL_setfuncs (L, meths, 0);
	lua_setfield (L, -2, "__index");
	luaL_setfuncs (L, metameths, 0);
	lua_pop (L, 1);

	luaL_newmetatable (L, "slimta_signalfd_mask_meta");
	lua_pop (L, 1);

	return 1;
}
/* }}} */

#endif /* HAVE_SIGNALFD */

// vim:foldmethod=marker:ai:ts=4:sw=4:
