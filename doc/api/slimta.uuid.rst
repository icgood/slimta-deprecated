
slimta.uuid
====================

.. currentmodule:: slimta.uuid

Module for generating "Universally Unique IDentifiers". According to the man
page for ``uuid_generate()``, "The new UUID can reasonably be considered unique
among all UUIDs created  on  the  local  system,  and among UUIDs created on
other systems in the past and in the future."

.. function:: generate()

   Generates and returns a 36-character UUID string. This string is composed of
   letters, numbers, and dashes.

   :return: a newly-generated UUID string.


