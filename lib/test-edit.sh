#!/bin/bash

ble-import lib/core-test

ble/test/start-section 'ble/edit' 7

(
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-eol 13 -1" exit=0 ret=10
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-bol 13 -1" exit=0 ret=5
)

# The read wrapper must preserve the caller's field splitting without using
# that IFS for its internal argument arrays (#735).
(
  _ble_decode_bind_state=ready
  function ble/test:read-ifs {
    local IFS=$1 input=$2 a= b=
    shift 2
    ble/builtin/read -r "$@" a b <<< "$input"
    local ext=$?
    ret=$a/$b
    return "$ext"
  }
  ble/test "ble/test:read-ifs \$'\\001' \$'x\\001y'" ret=x/y
  ble/test "ble/test:read-ifs ',' 'x,y'" ret=x/y
  ble/test "ble/test:read-ifs ' ' 'x y'" ret=x/y
  ble/test "ble/test:read-ifs \$'\\001' \$'x\\001y;tail' -d ';'" ret=x/y
  ble/test "ble/test:read-ifs ',' \$'x,y\\001tail' -d \$'\\001'" ret=x/y
)

ble/test/end-section
