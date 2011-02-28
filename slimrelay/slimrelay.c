#include <stdlib.h>

const char *global_tables[] = {
	"storage_engines",
	"protocols",
	NULL
};

const char *required_globals[] = {
	"storage_engines",
	"protocols",
	"request_channel",
	"results_channel",
	NULL
};

const char *entry_script = "slimrelay";

const char *DEFAULT_CONFIG = "/etc/slimta/slimta.conf";
const char *CONFIG_ENVVAR = "SLIMTA_CONFIG";

const char *DEFAULT_MY_CONFIG = "/etc/slimta/slimrelay.conf";
const char *MY_CONFIG_ENVVAR = "SLIMRELAY_CONFIG";

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimrelay/lua/?.lua";
const char *PATH_ENVVAR = "SLIMRELAY_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
