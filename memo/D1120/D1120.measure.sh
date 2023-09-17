#!/bin/bash

_initialize() {
  : >| D1119.measure.out
  echo "builtin history -c" >| D1119.measure._read_r
  echo "builtin history -c" >| D1119.measure._read_s
  local N=$1
  echo "builtin history -r /dev/stdin <<__BLE_EOF__" >> D1119.measure._read_r
  for ((i=0;i<N;i++)); do
    command="echo hello $RANDOM world abcdefg this is a test"
    echo "$command" >> D1119.measure.out
    echo "builtin history -s -- '$command'" >> D1119.measure._read_s
    echo "$command" >> D1119.measure._read_r
  done
  echo "__BLE_EOF__" >> D1119.measure._read_r
  echo "builtin history -a /dev/null" >> D1119.measure._read_r
  echo "builtin history -a /dev/null" >> D1119.measure._read_s
}

_read_r() {
  builtin history -c
  source D1119.measure._read_r
  builtin history -a /dev/null
}
_read_s() {
  builtin history -c
  source D1119.measure._read_s
  builtin history -a /dev/null
}

function measure1 {
  local HISTCONTROL= HISTIGNORE=
  #for N in 1 2 5 10 20 50 100; do
  for N in {6..9}; do
    _initialize $N
    ble-measure "_read_r $N"
    ble-measure "_read_s $N"
  done
}
measure1
