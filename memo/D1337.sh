#!/bin/bash

f1() {
  local message='hello world'
  ble-stackdump "$message"
}

f2() {
  local dummy=1
  f1
  output=$dummy
}

f3() {
  local input=$1 output=
  f2
  ret=$output
}

f3
