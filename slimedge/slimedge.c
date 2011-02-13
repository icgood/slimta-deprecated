#include <stdlib.h>

const char *global_tables[] = {
	"protocols",
	"storage_engines",
	NULL
};

const char *entry_script = "slimedge";

const char *DEFAULT_CONFIG = "/etc/slimta/slimedge.conf";
const char *CONFIG_ENVVAR = "SLIMEDGE_CONFIG";

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimedge/lua/?.lua";
const char *PATH_ENVVAR = "SLIMEDGE_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
