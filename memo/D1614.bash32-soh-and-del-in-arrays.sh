#!/bin/bash

function test1 {
  s=$'x\1y\177z'
  a=($'x\1y' $'z\177w')
  declare -p s a | cat -v
}
#test1
#(test1)

function test2 {
  a=($'x\1y' $'z\177w')
  b=("${a[@]}")
  declare -p a b | cat -v
}
#test2

# "正解" を生成している時に "正解" が変質している可能性
function test3 {
  local a; a=($'x\1y' $'z\177w')
  printf '%s\0' "${a[@]}" | cat -v
}
#test3

#------------------------------------------------------------------------------
# ble/util/declare-print-definitions に失敗する問題

function status { echo "${#a6[*]}:(""${a6[*]}"")"; }
function test4 {
  a6=($'\x01' a$'\x01'b)
  status a6 | cat -v
}
#test4

function status { ret="${#a6[*]}:(""${a6[*]}"")"; }
function test5 {
  a6=($'\x01' a$'\x01'b)
  status a6
  echo "$ret" | cat -v
}
#test4

function test6 {
  a6=($'\x01' a$'\x01'b)
  echo "$a6" | cat -v
  a6[0]=$'\x01'
  echo "$a6" | cat -v
  a6=$'\x01'
  echo "$a6" | cat -v
}
#test4

function test7 {
  local x=$'\x01' y=$'\x7F' a6
  a6=("$x" "$y")
  declare -p a6 | cat -v
}
test7

# 正しく実装する為には arr=() の形式は使ってはならないという事。
function test7 {
  local -a a=()
  a[0]=$'x\1y'
  a[1]=$'z\177w'
  declare -p a | cat -v
}
#test7
