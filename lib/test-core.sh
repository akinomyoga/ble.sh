# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

function ble-test:ble/string#escape/.check {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble-assert '[[ $ret == "$expected" ]]' ||
    echo "fail: args=($@) result=($ret) expected=($expected)" >&2
}

function ble-test:ble/string#escape {
  ble-test:ble/string#escape/.check ble/string#escape-for-sed-regex '\.[*?+|^$(){}/' '\\\.\[\*?+|\^\$(){}\/'
  ble-test:ble/string#escape/.check ble/string#escape-for-awk-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}\/'
  ble-test:ble/string#escape/.check ble/string#escape-for-extended-regex '\.[*?+|^$(){}/' '\\\.\[\*\?\+\|\^\$\(\)\{\}/'

  ble-test:ble/string#escape/.check ble/string#escape-for-bash-specialchars '[hello] (world) {this,is} <test>' '\[hello\]\ \(world\)\ \{this,is\}\ \<test\>'
}
