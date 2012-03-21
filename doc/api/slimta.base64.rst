
slimta.base64
=============

.. currentmodule:: slimta.base64

Module containing encoding and decoding functions for the standard base64 codec,
as provided by the OpenSSL crypto library.

.. function:: encode(data)

   Encodes the string with the base64 algorithm. This operation will increase
   the size of the data by about 33%, but will make it transferable on
   traditionally 7-bit streams such as SMTP.

   :param data: string of data to encode.
   :return: string of base64 encoded data.

.. function:: decode(data)

   Decodes the string with the base64 algorithm. The following operation should
   always be true: ``decode(encode(X)) == X``

   :param data: string of base64 data to decode.
   :return: string of potentially binary, decoded data.

