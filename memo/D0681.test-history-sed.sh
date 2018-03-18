#!/bin/bash

# D0681
#
# "HISTTIMEFORMAT=__ble_ext__ history"
# の出力を整形する sed スクリプトのテスト

{
  echo 1234
  echo hello
  echo world
  echo '1234 ??aaaaa'
  echo '111 ??echo test'
  echo hello
  echo world
  echo '1 ??echo www'
  echo '2 ??echo test'
  echo '3 ??echo aaaa'
} | sed '
  s/^ *[0-9]\{1,\}\*\{0,1\} \{1,\}__ble_ext__)//
  s/^ *[0-9]\{1,\}\*\{0,1\} \{1,\}??//
  tF
  ${H;s/.*//;bF;}
  H;d
:F
  x;s/^\n//
  /\n/ {
    s/['\''\\]/&/g
    s/\n/\\n/g
    s/.*/eval -- $'\''&'\''/
  }
  p;s/.*//
  ${x;/./{x;bF;};x}
  d
'
