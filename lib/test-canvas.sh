#!/bin/bash

function ble-test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    echo "fail: command=($f $in) result=($ret) expected=($expected)" >&2
}

function test1 {
  local -a DRAW_BUFF=() x=0 y=0 LINES=20 COLUMNS=10
  ble/canvas/rmoveto.draw 3 3
  x=0 y=0
  ble/canvas/trace.draw 'hello world this is a flow world' relative
  ble/canvas/bflush.draw
  ble/util/buffer.flush
  echo

  LINES=1 COLUMNS=20 x=0 y=0
  ble/canvas/trace.draw '12345678901234567890hello' nooverflow
  ble/canvas/bflush.draw
  ble/util/buffer.flush
}
test1
echo

function ble/test:ble/canvas/trace.draw {
  local fields esc=${1#*:}
  ble/string#split fields , "${1%%:*}"
  local -a DRAW_BUFF=()
  local x=${fields[0]} y=${fields[1]}
  local COLUMNS=${fields[2]:-10} LINES=${fields[3]:-20}
  local x1 x2 y1 y2; ble/canvas/trace.draw "$esc" measure-bbox
  ret=$x1-$x2:$y1-$y2
}

# 結果は以下の様になる筈
#  0123456789
#3:   hello
#4:    123
ble-test/check-ret ble/test:ble/canvas/trace.draw 3,3:$'hello\e[B\e[4D123' 3-8:3-5
ble-test/check-ret ble/test:ble/canvas/trace.draw 0,0:$'日本語' 0-6:0-1
