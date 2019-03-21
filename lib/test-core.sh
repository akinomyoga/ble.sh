# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

function ble-test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    echo "fail: command=($f $in) result=($ret) expected=($expected)" >&2
}

function ble-test:ble/array#pop {
  local arr; eval "arr=($1)"
  ble/array#pop arr
  ret="$ret:(${arr[*]}):${#arr[*]}"
}

ble-test/check-ret ble-test:ble/array#pop '' ':():0'
ble-test/check-ret ble-test:ble/array#pop '1' '1:():0'
ble-test/check-ret ble-test:ble/array#pop '1 2' '2:(1):1'
ble-test/check-ret ble-test:ble/array#pop '0 0 0' '0:(0 0):2'
ble-test/check-ret ble-test:ble/array#pop '1 2 3' '3:(1 2):2'
ble-test/check-ret ble-test:ble/array#pop '" a a " " b b " " c c "' ' c c :( a a   b b ):2'

function ble-test:ble/string#escape {
  ble-test/check-ret ble/string#escape-for-sed-regex '\.[*?+|^$(){}/' '\\\.\[\*?+|\^\$(){}\/'
  ble-test/check-ret ble/string#escape-for-awk-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}\/'
  ble-test/check-ret ble/string#escape-for-extended-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}/'
  ble-test/check-ret ble/string#escape-for-bash-specialchars '[hello] (world) {this,is} <test>' '\[hello\]\ \(world\)\ \{this,is}\ \<test\>'
}

ble-test:ble/string#escape

function ble-test:ble/array#index {
  local needle=${1%%:*} arr
  arr=(${1#*:})
  ble/array#index arr "$needle"
}
ble-test/check-ret ble-test:ble/array#index 'hello:hello world this hello world' 0
ble-test/check-ret ble-test:ble/array#index 'hello:world hep this hello world' 3
ble-test/check-ret ble-test:ble/array#index 'check:hello world this hello world' -1

function ble-test:ble/array#last-index {
  local needle=${1%%:*} arr
  arr=(${1#*:})
  ble/array#last-index arr "$needle"
}
ble-test/check-ret ble-test:ble/array#last-index 'hello:hello world this hello world' 3
ble-test/check-ret ble-test:ble/array#last-index 'hello:world hep this hello world' 3
ble-test/check-ret ble-test:ble/array#last-index 'check:hello world this hello world' -1
