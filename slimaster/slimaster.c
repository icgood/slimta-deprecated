#include <stdlib.h>

const char *global_tables[] = {
	"storage_engines",
	NULL
};

const char *required_globals[] = {
	"storage_engines",
	NULL
};

const char *entry_script = "slimaster";

const char *DEFAULT_CONFIG = "/etc/slimta/slimta.conf";
const char *CONFIG_ENVVAR = "SLIMTA_CONFIG";

const char *DEFAULT_MY_CONFIG = NULL;
const char *MY_CONFIG_ENVVAR = NULL;

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimaster/lua/?.lua";
const char *PATH_ENVVAR = "SLIMASTER_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
