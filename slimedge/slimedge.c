#include <stdlib.h>

const char *global_tables[] = {
	"protocols",
	"storage_engines",
	NULL
};

const char *entry_script = "slimedge";

const char *DEFAULT_CONFIG = "/etc/slimta/slimedge.conf";
const char *CONFIG_ENVVAR = "SLIMEDGE_CONFIG";

// vim:foldmethod=marker:ai:ts=4:sw=4:
