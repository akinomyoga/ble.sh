#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

#------------------------------------------------------------------------------

function concat.str {
  local a out=
  for a in {1..1000}; do
    out=$out$a
  done
  ret=$out
}
function concat.ret {
  local a; ret=
  for a in {1..1000}; do
    ret=$ret$a
  done
}
function concat.arr {
  local a arr i=0; arr=()
  for a in {1..1000}; do
    arr[i++]=$a
  done
  ret="${arr[*]}"
}

function measure {
  local ret=
  ble-measure concat.str
  ble-measure concat.ret
  ble-measure concat.arr
}
measure

#------------------------------------------------------------------------------

function concatB.str {
  local a out= arr2; arr2=()
  for a in {1..1000}; do
    arr2[i%10]=$a
    out=$out$a
  done
  ret=$out
}
function concatB.ret {
  local a arr2; ret= arr2=()
  for a in {1..1000}; do
    arr2[i%10]=$a
    ret=$ret$a
  done
}
function concatB.arr {
  local a arr i=0 arr2; arr=() arr2=()
  for a in {1..1000}; do
    arr2[i%10]=$a
    arr[i++]=$a
  done
  ret="${arr[*]}"
}

function measureB {
  local ret=
  ble-measure concatB.str
  ble-measure concatB.ret
  ble-measure concatB.arr
}
measureB
