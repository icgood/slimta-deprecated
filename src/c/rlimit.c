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
#include <sys/resource.h>

#include "misc.h"
#include "slimta.h"

/* {{{ myrlimit_resource() */
static int myrlimit_resource (lua_State *L, int index)
{
	int type = lua_type (L, index);

	if (type == LUA_TNUMBER)
		return (int) lua_tointeger (L, index);

	else if (type == LUA_TSTRING)
	{
		lua_pushvalue (L, lua_upvalueindex (1));
		lua_pushvalue (L, index);
		lua_gettable (L, -2);
		if (lua_isnumber (L, -1))
		{
			int ret = (int) lua_tointeger (L, -1);
			lua_pop (L, 2);
			return ret;
		}
		else
			return luaL_error (L, "Unknown rlimit resource: %s", lua_tostring (L, index));
	}

	else
		return luaL_argerror (L, index, "string or integer required");
}
/* }}} */

/* {{{ myrlimit_get() */
static int myrlimit_get (lua_State *L)
{
	int resource = myrlimit_resource (L, 1);
	struct rlimit l;

	if (getrlimit (resource, &l) < 0)
		return ratchet_error_errno (L, "slimta.rlimit.get()", "getrlimit");

	lua_pushnumber (L, (lua_Number) l.rlim_cur);
	lua_pushnumber (L, (lua_Number) l.rlim_max);

	return 2;
}
/* }}} */

/* {{{ myrlimit_set() */
static int myrlimit_set (lua_State *L)
{
	int resource = myrlimit_resource (L, 1);
	lua_Number soft = luaL_checknumber (L, 2);
	lua_Number hard = luaL_checknumber (L, 3);
	struct rlimit l = {(rlim_t) soft, (rlim_t) hard};

	if (setrlimit (resource, &l) < 0)
		return ratchet_error_errno (L, "slimta.rlimit.set()", "setrlimit");

	return 0;
}
/* }}} */

#define set_rlimit_int(s) lua_pushinteger(L, RLIMIT_##s); lua_setfield(L, -2, #s);

/* {{{ luaopen_slimta_rlimit() */
int luaopen_slimta_rlimit (lua_State *L)
{
	const luaL_Reg funcs[] = {
		{"get", myrlimit_get},
		{"set", myrlimit_set},
		{NULL}
	};

	lua_newtable (L);
	lua_pushvalue (L, -1);
	luaL_setfuncs (L, funcs, 1);

	set_rlimit_int (AS);
	set_rlimit_int (CORE);
	set_rlimit_int (CPU);
	set_rlimit_int (DATA);
	set_rlimit_int (FSIZE);
#ifdef RLIMIT_LOCKS
	set_rlimit_int (LOCKS);
#endif
	set_rlimit_int (MEMLOCK);
#ifdef RLIMIT_MSGQUEUE
	set_rlimit_int (MSGQUEUE);
#endif
#ifdef RLIMIT_NICE
	set_rlimit_int (NICE);
#endif
	set_rlimit_int (NOFILE);
	set_rlimit_int (NPROC);
	set_rlimit_int (RSS);
#ifdef RLIMIT_RTPRIO
	set_rlimit_int (RTPRIO);
#endif
#ifdef RLIMIT_RTTIME
	set_rlimit_int (RTTIME);
#endif
#ifdef RLIMIT_SIGPENDING
	set_rlimit_int (SIGPENDING);
#endif

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
