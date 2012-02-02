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

#include <stdlib.h>
#include <string.h>

#include "slimta.h"

/* {{{ luaopen_slimta() */
int luaopen_slimta (lua_State *L)
{
	static const luaL_Reg funcs[] = {
		{NULL}
	};

	luaL_newlib (L, funcs);
	lua_pushvalue (L, -1);
	lua_setglobal (L, "slimta");

	luaL_requiref (L, "slimta.xml", luaopen_slimta_xml, 0);
	lua_setfield (L, -2, "xml");

	luaL_requiref (L, "slimta.uuid", luaopen_slimta_uuid, 0);
	lua_setfield (L, -2, "uuid");

	luaL_requiref (L, "slimta.rlimit", luaopen_slimta_rlimit, 0);
	lua_setfield (L, -2, "rlimit");

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
