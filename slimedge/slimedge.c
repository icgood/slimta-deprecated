#include <stdlib.h>

const char *global_tables[] = {
	"storage_engines",
	"protocols",
	NULL
};

const char *required_globals[] = {
	"protocols",
	"queue_request_channel",
	"httpmail_channel",
	NULL
};

const char *entry_script = "slimedge";

const char *DEFAULT_CONFIG = "/etc/slimta/slimta.conf";
const char *CONFIG_ENVVAR = "SLIMTA_CONFIG";

const char *DEFAULT_MY_CONFIG = "/etc/slimta/slimedge.conf";
const char *MY_CONFIG_ENVVAR = "SLIMEDGE_CONFIG";

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimedge/lua/?.lua";
const char *PATH_ENVVAR = "SLIMEDGE_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
