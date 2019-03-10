#!/bin/bash

function ble-test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    echo "fail: command=($f $in) result=($ret) expected=($expected)" >&2
}

function test1 {
  local -a DRAW_BUFF=() x=0 y=0 g=0 LINES=20 COLUMNS=10
  ble/canvas/put-move.draw 3 3
  x=0 y=0
  ble/canvas/trace.draw 'hello world this is a flow world' relative
  ble/canvas/flush.draw
  echo

  LINES=1 COLUMNS=20 x=0 y=0
  ble/canvas/trace.draw '12345678901234567890hello' nooverflow
  ble/canvas/flush.draw
}
test1
echo

function ble/test:ble/canvas/trace {
  local fields esc=${1#*:}
  ble/string#split fields , "${1%%:*}"
  local COLUMNS=${fields[2]:-10} LINES=${fields[3]:-20}
  local x=${fields[0]} y=${fields[1]} g=0
  local x1 x2 y1 y2; ble/canvas/trace "$esc" measure-bbox # -> ret
  ret=$x1-$x2:$y1-$y2
}

# 結果は以下の様になる筈
#  0123456789
#3:   hello
#4:    123
ble-test/check-ret ble/test:ble/canvas/trace 3,3:$'hello\e[B\e[4D123' 3-8:3-5
ble-test/check-ret ble/test:ble/canvas/trace 0,0:$'日本語' 0-6:0-1

#------------------------------------------------------------------------------
# from test/check-trace.sh

function ble/test:canvas/goto {
  local x1=$1 y1=$2 text=$3
  ble/canvas/put-move-x.draw $((x1-x))
  ble/canvas/put-move-y.draw $((y1-y))
}
function ble/test:canvas/print-at {
  ble/canvas/put.draw "$_ble_term_sc"
  ble/test:canvas/goto "$1" "$2"
  ble/canvas/put.draw "$3"
  ble/canvas/put.draw "$_ble_term_rc"
  ble/canvas/flush.draw
}

_ble_test_check_count=0
function ble/test:canvas/check-point {
  ble/util/assert "((x==$1&&y==$2))"
  ble/test:canvas/print-at $((_ble_test_check_count+10)) 12 $((_ble_test_check_count++%10))
}

function ble/test:canvas/check-trace-1 {
  local input=$1 x=$2 y=$3
  ble/canvas/trace.draw "$input"
  ble/test:canvas/check-point "$x" "$y"
}

function ble/test:canvas/check-trace {
  local -a DRAW_BUFF=()
  ble/canvas/put.draw "$_ble_term_clear"
  x=0 y=0

  # 0-9
  ble/test:canvas/check-trace-1 "abc" 3 0
  ble/test:canvas/check-trace-1 $'\n\n\nn' 1 3
  ble/test:canvas/check-trace-1 $'\e[3BB' 2 6
  ble/test:canvas/check-trace-1 $'\e[2AA' 3 4
  ble/test:canvas/check-trace-1 $'\e[20CC' 24 4
  ble/test:canvas/check-trace-1 $'\e[8DD' 17 4
  ble/test:canvas/check-trace-1 $'\e[9EE' 1 13
  ble/test:canvas/check-trace-1 $'\e[6FF' 1 7
  ble/test:canvas/check-trace-1 $'\e[28GG' 28 7
  ble/test:canvas/check-trace-1 $'\e[II' 33 7

  ble/test:canvas/check-trace-1 $'\e[3ZZ' 17 7
  ble/test:canvas/check-trace-1 $'\eDD' 18 8
  ble/test:canvas/check-trace-1 $'\eMM' 19 7
  ble/test:canvas/check-trace-1 $'\e77\e[3;3Hexcur\e8\e[C8' 21 7
  ble/test:canvas/check-trace-1 $'\eEE' 1 8
  ble/test:canvas/check-trace-1 $'\e[10;24HH' 24 9
  ble/test:canvas/check-trace-1 $'\e[1;94mb\e[m' 25 9
  ble/test:canvas/goto 0 15
  ble/canvas/flush.draw
}

ble/test:canvas/check-trace
