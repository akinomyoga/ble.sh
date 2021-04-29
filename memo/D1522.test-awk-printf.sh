#!/bin/bash

x=($'\1' $'\2' $'\32' ' ' $'\a' $'\b' $'\t' $'\n' $'\v' $'\f' $'\r' $'\177' a \" \' \$ \! \` \~)
declare -p x

function test-awk-c2s() {
  {
    echo 43 # +
    echo 945 # α
    echo 12354 # あ
  } | LANG=C awk '
    BEGIN{
      # ENCODING: UTF-8
      if (sprintf("%c", 945) == "α") {
        PRINTF_C_UNICODE = 1;
      } else {
        for (i = 1; i <= 255; i++)
          byte2char[i] = sprintf("%c", i);
      }
    }

    # ENCODING: UTF-8
    function c2s(code, _, leadbyte_mark, leadbyte_sup, tail) {
      if (PRINTF_C_UNICODE)
        return sprintf("%c", code);

      leadbyte_sup = 0x80;
      leadbyte_mark = 0;
      tail = "";
      while (code >= leadbyte_sup) {
        leadbyte_sup /= 2;
        leadbyte_mark = leadbyte_mark ? leadbyte_mark / 2 : 0xFFC0;
        tail = byte2char[0x80 + int(code % 64)] tail;
        code = int(code / 64);
      }
      return byte2char[(leadbyte_mark + code) % 256] tail;
    }
    {print c2s($1);}
  '
}
test-awk-c2s
