
slimta.hmac
====================

.. currentmodule:: slimta.hmac

Module for generating HMAC-encoded digests using OpenSSL's HMAC() function.

.. function:: encode(method, data, key)

   Encodes the data using the given secret key. This is not a reversible action.

   :param method: the method string. The available methods are the corresponding
    ``EVP_*()`` names, e.g. ``"md5"`` or ``"sha1"``.
   :param data: a string of data to encode.
   :param key: a secret key to encode the data with.
   :return: a string of bytes containing the result of the encoding.

