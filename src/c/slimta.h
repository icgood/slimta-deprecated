#ifndef __SLIMTA_SLIMTA_H
#define __SLIMTA_SLIMTA_H

#include <lua.h>

#include "ratchet.h"

int luaopen_slimta_rlimit (lua_State *L);
int luaopen_slimta_uuid (lua_State *L);
int luaopen_slimta_xml (lua_State *L);

#if HAVE_SIGNALFD
int luaopen_slimta_signalfd (lua_State *L);
#endif

#endif
// vim:foldmethod=marker:ai:ts=4:sw=4:
