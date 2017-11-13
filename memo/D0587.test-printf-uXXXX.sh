#!/bin/bash

function test1 {
  var=123
  printf -v var '\u222E'
  echo "printf1: ext=$ext #var=${#var} var='$var'"
  printf -v var '\u3042'
  echo "printf2: ext=$ext #var=${#var} var='$var'"

  eval "var=\$'\u222E'"
  echo "esc1: ext=$ext #var=${#var} var='$var'"
  eval "var=\$'\u3042'"
  echo "esc2: ext=$ext #var=${#var} var='$var'"
}

echo LANG=ja_JP.UTF-8
LANG=ja_JP.UTF-8
test1

echo LANG=ja_JP.eucJP
LANG=ja_JP.eucJP
test1
