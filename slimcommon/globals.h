#ifndef __SLIMTA_GLOBALS_H
#define __SLIMTA_GLOBALS_H

#include <lua.h>

void slimta_setup_globals (lua_State *L, int argc, char **argv);
int slimta_load_config (lua_State *L, const char *nspace);

#endif
// vim:foldmethod=marker:ai:ts=4:sw=4:
