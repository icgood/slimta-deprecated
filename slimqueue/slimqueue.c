#include <stdlib.h>

const char *global_tables[] = {
	"storage_engines",
	NULL
};

const char *required_globals[] = {
	"storage_engines",
	"use_storage_engine",
	"message_nexthop",
	"queue_request_channel",
	"relay_request_channel",
	"relay_results_channel",
	NULL
};

const char *entry_script = "slimqueue";

const char *DEFAULT_CONFIG = "/etc/slimta/slimta.conf";
const char *CONFIG_ENVVAR = "SLIMTA_CONFIG";

const char *DEFAULT_MY_CONFIG = "/etc/slimta/slimqueue.conf";
const char *MY_CONFIG_ENVVAR = "SLIMQUEUE_CONFIG";

const char *DEFAULT_PATH = ";;/var/lib/slimta/slimcommon/lua/?.lua;/var/lib/slimta/slimqueue/lua/?.lua";
const char *PATH_ENVVAR = "SLIMQUEUE_PATH";

// vim:foldmethod=marker:ai:ts=4:sw=4:
