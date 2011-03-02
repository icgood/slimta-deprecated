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
#include <expat.h>
#include <errno.h>

#include "xml.h"

/* {{{ generic_start_cb() */
static void XMLCALL generic_start_cb (void *user_data, const char *name, const char **atts)
{
	lua_State *L = (lua_State *) user_data;
	int i;

	lua_getfenv (L, 1);
	lua_getfield (L, -1, "start_cb");
	lua_getfield (L, -2, "state");
	lua_pushstring (L, name);
	lua_newtable (L);
	for (i=0; atts[i] != NULL; i+=2)
	{
		lua_pushstring (L, atts[i]);
		lua_pushstring (L, atts[i+1]);
		lua_rawset (L, -3);
	}
	lua_call (L, 3, 0);
	lua_pop (L, 1);
}
/* }}} */

/* {{{ generic_end_cb() */
static void XMLCALL generic_end_cb (void *user_data, const char *name)
{
	lua_State *L = (lua_State *) user_data;

	lua_getfenv (L, 1);
	lua_getfield (L, -1, "end_cb");
	lua_getfield (L, -2, "state");
	lua_pushstring (L, name);
	lua_call (L, 2, 0);
	lua_pop (L, 1);
}
/* }}} */

/* {{{ generic_data_cb() */
static void generic_data_cb (void *user_data, const char *s, int len)
{
	lua_State *L = (lua_State *) user_data;

	lua_getfenv (L, 1);
	lua_getfield (L, -1, "data_cb");
	lua_getfield (L, -2, "state");
	lua_pushlstring (L, s, (size_t) len);
	lua_call (L, 2, 0);
	lua_pop (L, 1);
}
/* }}} */

/* {{{ myxml_new() */
static int myxml_new (lua_State *L)
{
	/* Get the start element handler parameter. */
	XML_StartElementHandler start_cb = NULL;
	if (!lua_isnoneornil (L, 2))
	{
		luaL_checktype (L, 2, LUA_TFUNCTION);
		start_cb = generic_start_cb;
	}

	/* Get the end element handler parameter. */
	XML_EndElementHandler end_cb = NULL;
	if (!lua_isnoneornil (L, 3))
	{
		luaL_checktype (L, 3, LUA_TFUNCTION);
		end_cb = generic_end_cb;
	}

	/* Get the data handler parameter. */
	XML_CharacterDataHandler data_cb = NULL;
	if (!lua_isnoneornil (L, 4))
	{
		luaL_checktype (L, 4, LUA_TFUNCTION);
		data_cb = generic_data_cb;
	}

	/* Get the encoding parameter, usually none. */
	const char *encoding = luaL_optstring (L, 5, NULL);

	/* Create the parser object in a new Lua userdata. */
	XML_Parser *parser = (XML_Parser *) lua_newuserdata (L, sizeof (XML_Parser));
	*parser = XML_ParserCreate (encoding);
	if (!*parser)
		return luaL_error (L, "XML parser create failed");

	/* Configure the parser internally. */
	XML_SetUserData (*parser, L);
	if (start_cb || end_cb)
		XML_SetElementHandler (*parser, start_cb, end_cb);
	if (data_cb)
		XML_SetCharacterDataHandler (*parser, data_cb);

	/* Save info about the parser in the environment. */
	lua_createtable (L, 0, 4);
	lua_pushvalue (L, 1);
	lua_setfield (L, -2, "state");
	lua_pushvalue (L, 2);
	lua_setfield (L, -2, "start_cb");
	lua_pushvalue (L, 3);
	lua_setfield (L, -2, "end_cb");
	lua_pushvalue (L, 4);
	lua_setfield (L, -2, "data_cb");
	lua_setfenv (L, -2);

	/* Make this userdata an object of the slimta.xml class. */
	luaL_getmetatable (L, "slimta_xml_meta");
	lua_setmetatable (L, -2);

	return 1;
}
/* }}} */

/* {{{ myxml_escape() */
static int myxml_escape(lua_State *L)
{
	luaL_checkstring (L, 1);
	lua_settop (L, 1);

	lua_getfield (L, -1, "gsub");
	lua_pushvalue (L, -2);
	lua_pushliteral (L, "%<");
	lua_pushliteral (L, "&lt;");
	lua_call (L, 3, 1);

	lua_getfield (L, -1, "gsub");
	lua_pushvalue (L, -2);
	lua_pushliteral (L, "%>");
	lua_pushliteral (L, "&gt;");
	lua_call (L, 3, 1);

	return 1;
}
/* }}} */

/* {{{ myxml_gc() */
static int myxml_gc (lua_State *L)
{
	XML_Parser parser = *(XML_Parser *) luaL_checkudata (L, 1, "slimta_xml_meta");
	if (parser)
		XML_ParserFree (parser);

	return 0;
}
/* }}} */

/* {{{ myxml_parse() */
static int myxml_parse (lua_State *L)
{
	XML_Parser parser = *(XML_Parser *) luaL_checkudata (L, 1, "slimta_xml_meta");
	size_t data_len;
	const char *data = luaL_checklstring (L, 2, &data_len);
	int more_coming = lua_toboolean (L, 3);

	int ret = XML_Parse (parser, data, data_len, (more_coming ? 0 : 1));
	if (ret == 0)
	{
		lua_pushnil (L);
		int error = (int) XML_GetErrorCode (parser);
		lua_pushstring (L, XML_ErrorString (error));
		return 2;
	}
	else
	{
		lua_pushboolean (L, 1);
		return 1;
	}
}
/* }}} */

/* {{{ myxml_parsesome() */
static int myxml_parsesome (lua_State *L)
{
	/* Keep the same args, with a true boolean as the third parameter to parse(). */
	lua_settop (L, 2);
	lua_pushboolean (L, 1);
	lua_getfield (L, 1, "parse");
	lua_call (L, 3, 2);
	return 2;
}
/* }}} */

/* {{{ luaopen_slimta_xml() */
int luaopen_slimta_xml (lua_State *L)
{
	static const luaL_Reg funcs[] = {
		{"new", myxml_new},
		{"escape", myxml_escape},
		{NULL}
	};

	static const luaL_Reg metameths[] = {
		{"__gc", myxml_gc},
		{NULL}
	};

	static const luaL_Reg meths[] = {
		/* Documented methods. */
		{"parse", myxml_parse},
		{"parsesome", myxml_parsesome},
		/* Undocumented, helper methods. */
		{NULL}
	};

	/* Set up the slimta.xml class and metatables. */
	luaL_newmetatable (L, "slimta_xml_meta");
	lua_newtable (L);
	luaI_openlib (L, NULL, meths, 0);
	lua_setfield (L, -2, "__index");
	luaI_openlib (L, NULL, metameths, 0);
	lua_pop (L, 1);

	/* Set up the slimta.xml namespace functions. */
	luaI_openlib (L, "slimta.xml", funcs, 0);

	return 1;
}
/* }}} */

// vim:foldmethod=marker:ai:ts=4:sw=4:
