#!/bin/bash

ble-import lib/core-test

ble/test/start-section 'ble/edit' 7

(
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-eol 13 -1" exit=0 ret=10
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-bol 13 -1" exit=0 ret=5
)

(
  # #D2436: Bash >= 4.0 has a bug that "${array[@]}" is wrongly split by
  # #IFS=$'\001'.
  function ble/test:ble/builtin/read {
    local vIFS=$IFS input=$1 expect=$2 IFS=$_ble_term_IFS
    shift 2

    # To forcibly make "ble/builtin/read" use its own processing, we need to
    # set _ble_decode_bind_state to mimic the bind state where ble/decode is
    # attached.
    local _ble_decode_bind_state=emacs

    local a= b=
    IFS=$vIFS ble/builtin/read -r "$@" a b <<< "$input"
    local ext=$?

    local ret
    ble/string#quote-word "$vIFS"; local wIFS=$ret
    ble/string#quote-word "$input"; local winput=$ret
    local title="IFS=$wIFS ble/builtin/read -r a b <<< $winput"

    ble/test code:'ret=$a/$b; ble/util/setexit "$ext"' ret:"$expect" \
      --depth=1 --display-code="$title"
  }
  IFS=$'\001' ble/test:ble/builtin/read $'x\001y'      x/y
  IFS=','     ble/test:ble/builtin/read 'x,y'          x/y
  IFS=' '     ble/test:ble/builtin/read 'x y'          x/y
  IFS=$'\001' ble/test:ble/builtin/read $'x\001y;tail' x/y -d ';'
  IFS=','     ble/test:ble/builtin/read $'x,y\001tail' x/y -d $'\001'
)

ble/test/end-section
