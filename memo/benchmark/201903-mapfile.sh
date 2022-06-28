#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

_ble_util_assign_base="/dev/shm/$UID.$$.read-stdout.tmp"
_ble_util_assign_level=0

function ble/util/mapfile {
  local _ble_local_i=0 _ble_local_val _ble_local_arr; _ble_local_arr=()
  while builtin read -r _ble_local_val || [[ $_ble_local_val ]]; do
    _ble_local_arr[_ble_local_i++]=$_ble_local_val
  done
  builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
}

#------------------------------------------------------------------------------
# split-lines

function ble/util/uparr { builtin unset -v "$1" && builtin eval "$1=(\"\${@:2}\")"; }
function ble/string#split {
  if [[ -o noglob ]]; then
    # Note: 末尾の sep が無視されない様に、末尾に手で sep を 1 個追加している。
    IFS=$2 builtin eval "$1=(\${*:3}\$2)"
  else
    set -f
    IFS=$2 builtin eval "$1=(\${*:3}\$2)"
    set +f
  fi
}
function split-lines.1 {
  local name=$1 text=${*:2} sep='' esc='\'
  if [[ $text == *$sep* ]]; then
    local a b arr ret value
    a=$esc b=$esc'A' text=${text//"$a"/"$b"}
    a=$sep b=$esc'B' text=${text//"$a"/"$b"}

    text=${text//$'\n'/"$sep"}
    ble/string#split arr "$sep" "$text"

    for value in "${arr[@]}"; do
      if [[ $value == *$esc* ]]; then
        a=$esc'B' b=$sep value=${value//"$a"/"$b"}
        a=$esc'A' b=$esc value=${value//"$a"/"$b"}
      fi
      ret[${#ret[@]}]=$value
    done
  else
    local ret
    text=${text//$'\n'/"$sep"}
    ble/string#split ret "$sep" "$text"
  fi
  local "$name" && ble/util/uparr "$name" "${ret[@]}"
}
function split-lines.2 {
  ble/util/mapfile "$1" <<< "$2"
}
function ble/string#split-lines {
  split-lines.2 "$@"
}

data=$(< array-reverse.sh)

ble-measure 'split-lines.1 arr1 "$data"' # 532000.00 usec/eval (x1)
ble-measure 'split-lines.2 arr1 "$data"' #   8945.00 usec/eval (x20)

#------------------------------------------------------------------------------

function assign {
  eval "${@:2}" >| "$_ble_util_assign_base"
  local _ret="$?"
  IFS= read -r -d '' "$1" < "$_ble_util_assign_base"
  return "$_ret"
}

function ble/util/assign {
  local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
  builtin eval "$2" >| "$_ble_local_tmp"
  local _ble_local_ret=$?
  ((_ble_util_assign_level--))
  IFS= builtin read -r -d '' "$1" < "$_ble_local_tmp"
  eval "$1=\${$1%$'\n'}"
  return "$_ble_local_ret"
}

function assign-array.1 {
  ble/util/assign "$@"
  if [[ ${!1} ]]; then
    ble/string#split-lines "$1" "${!1%$'\n'}"
  else
    eval "$1=()"
  fi
}
function assign-array.2 {
  local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
  builtin eval "$2" >| "$_ble_local_tmp"
  local _ble_local_ret=$?
  ((_ble_util_assign_level--))
  ble/util/mapfile "$1" < "$_ble_local_tmp"
  return "$_ble_local_ret"
}

ble-measure 'assign-array.1 arr1 "cat array-reverse.sh"' # 11900.00 usec/eval (x10)
ble-measure 'assign-array.2 arr1 "cat array-reverse.sh"' #  4536.00 usec/eval (x50)
