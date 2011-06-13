if HAVE_LUA_INTERPRETER

TESTS_ENVIRONMENT = LUA_CPATH="../src/c/.libs/?.so;;" LUA_PATH="./?.lua;./?/init.lua;;" @LUA@

xml_tests = test_xml_writer.lua \
	    test_xml_reader.lua

message_tests = test_message_to_xml.lua \
		test_message_from_xml.lua \
		test_message_add_headers.lua \
		test_message_delete_headers.lua \
		test_message_header_folding.lua

edge_tests = test_edge_http_listener.lua \
	     test_edge_smtp_listener.lua \
	     test_edge_queue_channel.lua

TESTS = $(xml_tests) $(message_tests) $(edge_tests)

XFAIL_TESTS = 
EXTRA_DIST = $(TESTS)

check_DATA = slimta-link
CLEANFILES = slimta

slimta-link:
	ln -nsf ../src/lua ./slimta

endif
