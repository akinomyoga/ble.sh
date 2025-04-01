#!/usr/bin/env bash

a0=()
a1=("")
a2=("" "" "" "" "")
a3=("" "" "" "" "")
unset -v 'a3[2]'

function check {
  builtin eval -- "$1 a0" && echo "fail: $1 a0"
  builtin eval -- "$1 a1" && echo "fail: $1 a1"
  builtin eval -- "$1 a2" && echo "fail: $1 a2"
  builtin eval -- "$1 a3" || echo "fail: $1 a3"
  ble-measure -c4 "$1 a0"
  ble-measure -c4 "$1 a1"
  ble-measure -c4 "$1 a2"
  ble-measure -c4 "$1 a3"
}

# 比較1
function is-sparse-1a {
  builtin eval -- "((\${#$1[@]}>0)) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
function is-sparse-1b {
  builtin eval -- "((\${#$1[@]}>0)) && set -- \"\${$1[@]:\${#$1[@]}:1}\" && ((\$#))"
}
function is-sparse-1c {
  builtin eval -- "((\${#$1[@]}>0)) && { local _ble_local_test; _ble_local_test=(\"\${$1[@]:\${#$1[@]}:1}\"); ((${#_ble_local_test[@]})); }"
}
function ble/util/has-arg { (($#)); }
function is-sparse-1d {
  builtin eval -- "((\${#$1[@]}>0)) && ble/util/has-arg \"\${$1[@]:\${#$1[@]}:1}\""
}

#check is-sparse-1a # accept
#check is-sparse-1b # reject: 微妙に遅い
#check is-sparse-1c # reject: ローカル変数を作るのはとても遅い
#check is-sparse-1d # reject: 関数呼び出しは微妙に遅い

# 比較2
function is-sparse-2a {
  builtin eval -- "((\${#$1[@]}>0)) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
function is-sparse-2b {
  builtin eval -- "((\${#$1[@]})) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
function is-sparse-2c {
  builtin eval "((\${#$1[@]})) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
function is-sparse-2d {
  builtin eval "((\${#$1[@]}))" && { builtin eval "set -- \"\${$1[@]:\${#$1[@]}:1}\""; (($#)); }
}

#check is-sparse-2a # reject: 空配列が微妙に速いが他は b より遅い。と思ったが空配列については単に最初のテストが過小評価するから?
#check is-sparse-2b # reject: c の方が速い
#check is-sparse-2c # accept
#check is-sparse-2d # reject: 遅い

# 比較3
function is-sparse-3a {
  builtin eval "((\${#$1[@]})) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
function is-sparse-3b {
  local _ble_local_script='((${#A[@]})) && set -- "${A[@]:${#A[@]}:1}"'
  builtin eval "${_ble_local_script//A/$1}" && (($#)) # disable=#D1738
}
#check is-sparse-3a # accept
#check is-sparse-3b # reject: 単に遅い

function ble/array#is-sparse {
  builtin eval "((\${#$1[@]})) && set -- \"\${$1[@]:\${#$1[@]}:1}\"" && (($#))
}
check ble/array#is-sparse
