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

// vim:foldmethod=marker:ai:ts=4:sw=4:
