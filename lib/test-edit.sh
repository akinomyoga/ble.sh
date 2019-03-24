#!/bin/bash

function ble/test/check-ret {
  local f=$2 expected=$1 ret
  "$f" "${@:3}"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    ble/bin/echo "fail: command=($f ${*:3}) result=($ret) expected=($expected)" >&2
}

function ble/test:ble-edit/content/find-logical-eol {
  local _ble_edit_str=$1 index=$2 offset=$3
  ble-edit/content/find-logical-eol "$index" "$offset"
  ret=$?:$ret
}
function ble/test:ble-edit/content/find-logical-bol {
  local _ble_edit_str=$1 index=$2 offset=$3
  ble-edit/content/find-logical-bol "$index" "$offset"
  ret=$?:$ret
}

ble/test/check-ret 0:10 ble/test:ble-edit/content/find-logical-eol $'echo\nhello\nworld' 13 -1
ble/test/check-ret 0:5  ble/test:ble-edit/content/find-logical-bol $'echo\nhello\nworld' 13 -1
