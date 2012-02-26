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

#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <math.h>
#include <netdb.h>
#include <errno.h>

#if HAVE_OPENSSL
#include <openssl/sha.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>
#endif

#include "ratchet.h"
#include "misc.h"

#define add_method(L, n) do { lua_pushlightuserdata (L, (void *) EVP_##n ()); lua_setfield (L, -2, #n); } while (0)

/* {{{ push_evp_table() */
static void push_evp_table (lua_State *L)
{
	lua_newtable (L);
	add_method (L, md_null);
	add_method (L, md2);
	add_method (L, md5);
	add_method (L, sha);
	add_method (L, sha1);
	add_method (L, sha224);
	add_method (L, sha256);
	add_method (L, sha384);
	add_method (L, sha512);
	add_method (L, dss);
	add_method (L, dss1);
	add_method (L, mdc2);
	add_method (L, ripemd160);
}
/* }}} */

/* {{{ get_method_from_evp_table() */
static const EVP_MD *get_method_from_evp_table (lua_State *L, int ni, int ti)
{
	lua_pushvalue (L, ti);
	lua_pushvalue (L, ni);
	lua_rawget (L, -2);
	if (lua_isnil (L, -1))
		luaL_argerror (L, ni, "Invalid EVP method name.");
	const EVP_MD *ret = (const EVP_MD *) lua_topointer (L, -1);
	lua_pop (L, 2);
	return ret;
}
/* }}} */

/* ---- Namespace Functions ------------------------------------------------- */

/* {{{ rhmac_encode() */
static int rhmac_encode (lua_State *L)
{
#if HAVE_OPENSSL
	size_t data_len, key_len;
	luaL_checkstring (L, 1);
	const unsigned char *data = (const unsigned char *) luaL_checklstring (L, 2, &data_len);
	const void *key = (const void *) luaL_checklstring (L, 3, &key_len);
	const EVP_MD *evp_md = get_method_from_evp_table (L, 1, lua_upvalueindex (1));

	luaL_Buffer outbuf;

	luaL_buffinit (L, &outbuf);
	unsigned char *md = (unsigned char *) luaL_prepbuffsize (&outbuf, EVP_MAX_MD_SIZE);
	unsigned int md_len;

	if (!HMAC (evp_md, key, (int) key_len, data, (int) data_len, md, &md_len))
		return luaL_error (L, "Error occured in HMAC().");

	luaL_addsize (&outbuf, (size_t) md_len);
	luaL_pushresult (&outbuf);

	return 1;
#else
	return luaL_error (L, "Compile slimta with OpenSSL support for HMAC-MD5 support.");
#endif
}
/* }}} */

/* ---- Public Functions ---------------------------------------------------- */

/* {{{ luaopen_slimta_hmac() */
int luaopen_slimta_hmac (lua_State *L)
{
	static const luaL_Reg funcs[] = {
		{"encode", rhmac_encode},
		{NULL}
	};

	lua_newtable (L);
	push_evp_table (L);
	luaL_setfuncs (L, funcs, 1);
	lua_pushvalue (L, -1);
	lua_setfield (L, LUA_REGISTRYINDEX, "slimta_hmac_class");

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
