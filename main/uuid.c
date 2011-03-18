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
#include <uuid/uuid.h>
#include <errno.h>

#include "uuid.h"

#ifndef UUID_STRING_BUFFER_SIZE
#define UUID_STRING_BUFFER_SIZE 37
#endif

/* {{{ myuuid_generate() */
static int myuuid_generate (lua_State *L)
{
	uuid_t uuid;
	char uuid_s[UUID_STRING_BUFFER_SIZE];
	uuid_generate (uuid);
	uuid_unparse_lower (uuid, uuid_s);
	lua_pushstring (L, uuid_s);
	
	return 1;
}
/* }}} */

/* {{{ luaopen_slimta_uuid() */
int luaopen_slimta_uuid (lua_State *L)
{
	static const luaL_Reg funcs[] = {
		{"generate", myuuid_generate},
		{NULL}
	};

	/* Set up the slimta.uuid namespace functions. */
	luaL_register (L, "slimta.uuid", funcs);

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
