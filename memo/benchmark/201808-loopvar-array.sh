#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

# 要素数1の配列に順々に要素を入れてループを回したい。
# 一番速い方法はどれか。
# 試してみた結果だと直接配列名をループ変数扱いするのが速い。

function f1 { :; }

function array-loop1 {
  local -a arr1=()
  local a
  for a in {1..1000}; do
    arr1=("$a")
    f1
  done
}

function array-loop2 {
  local -a arr1=()
  local a
  for a in {1..1000}; do
    arr1[0]=$a
    f1
  done
}

function array-loop3 {
  local -a arr1=()
  local a
  for a in {1..1000}; do
    arr1=$a
    f1
  done
}

function array-loop4 {
  local -a arr1=()
  local a
  for arr1 in {1..1000}; do
    f1
  done
}

ble-measure array-loop1
ble-measure array-loop2
ble-measure array-loop3
ble-measure array-loop4
