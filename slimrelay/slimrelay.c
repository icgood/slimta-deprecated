#include <stdlib.h>

const char *global_tables[] = {
	"protocols",
	"storage_engines",
	"connections",
	NULL
};

const char *entry_script = "slimrelay";

const char *DEFAULT_CONFIG = "/etc/slimta/slimrelay.conf";
const char *CONFIG_ENVVAR = "SLIMRELAY_CONFIG";

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimrelay/lua/?.lua";
const char *PATH_ENVVAR = "SLIMRELAY_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
