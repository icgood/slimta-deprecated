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

#include <ratchet/misc.h>

#include "xml.h"

/* {{{ slimcommon_stackdump() */
static int slimcommon_stackdump (lua_State *L)
{
	rhelp_stackdump (L);

	return 0;
}
/* }}} */

/* {{{ slimcommon_openlibs () */
int slimcommon_openlibs (lua_State *L)
{
	const luaL_Reg funcs[] = {
		{"stackdump", slimcommon_stackdump},
		{NULL}
	};
	luaL_register (L, "slimta", funcs);

	luaopen_slimta_xml (L);
	lua_setfield (L, -1, "xml");

	return 0;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
