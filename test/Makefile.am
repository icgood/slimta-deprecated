if HAVE_LUA_INTERPRETER

TESTS_ENVIRONMENT = LUA_CPATH="../src/c/.libs/?.so;@LUA_CPATH@/?.so;;" LUA_PATH="./?.lua;./?/init.lua;@LUA_LPATH@/?.lua;@LUA_LPATH@/?/init.lua;;" @LUA@

bus_tests = test_bus_client_server.lua \
	    test_bus_local.lua

xml_tests = test_xml_writer.lua \
	    test_xml_reader.lua

message_tests = test_message_to_xml.lua \
		test_message_from_xml.lua \
		test_message_copy.lua \
		test_message_add_headers.lua \
		test_message_delete_headers.lua \
		test_message_header_folding.lua

edge_tests = test_edge_http_listener.lua \
	     test_edge_smtp_listener.lua

relay_tests = test_relay_smtp_relayer.lua

policy_tests = test_add_date_header.lua \
	       test_add_received_header.lua

coordination_tests = test_edge_to_relay.lua

TESTS = $(bus_tests) $(xml_tests) $(message_tests) \
	$(edge_tests) $(relay_tests) $(coordination_tests) \
	$(policy_tests)

XFAIL_TESTS = 
EXTRA_DIST = $(TESTS)

check_DATA = slimta-link
CLEANFILES = slimta

slimta-link:
	ln -nsf ../src/lua ./slimta

endif
