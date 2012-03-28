
Working with Message Content
============================

Message :mod:`~slimta.message.contents` objects are used to read in raw message
data, allow easy access to and modification of message headers, and convert back
into raw message data.

Loading new message contents from a raw data string is simple::

   local contents = slimta.message.contents.new(raw_data)

To convert a message object back into a raw data string, with all header
modifications applied, use Lua's ``tostring()`` function on the object::

   local raw_data = tostring(contents)

Header Access
"""""""""""""

Once you have the ``contents`` object, you can access headers with its
``headers`` field::

   print(contents.headers.subject[1])

That line will print the first ``Subject:`` header from the message contents.
These headers are looked up in a case-insensitive way. If the message does not
have a ``Subject:`` header, that line will not error. That's because if you
access a header that doesn't exist, a Lua meta-method returns an empty table
instead of ``nil``. As such, to check for a missing header, you have to write a
check like this::

   if not contents.headers.date[1] then
       print("Message had no Date: header.")
   end

Header Modification
"""""""""""""""""""

You **should not** use the ``contents.headers`` table to add or remove headers
from the message contents. This is because ``contents.headers`` is a sort of
"view" into the message headers. Another, hidden table keeps track of the
ordering and case of the headers, such that message contents can be rebuilt
exactly like the were read.

To prepend a header to the message contents, use
:func:`~slimta.message.contents.add_header()`. Any other headers of the same
name will be unchanged.

::

   contents:add_header("X-Secret-Sauce", "onions")

To add a header to the very bottom of the existing headers, simple pass a third
``true`` argument::

   contents:add_header("X-Ignore-Me", slimta.base64.encode("I'm hiding!"), true)

To delete **all** headers of a given name, case-insensitively, use
:func:`~slimta.message.contents.delete_header()`::

   contents:delete_header("X-Internal-Header")

