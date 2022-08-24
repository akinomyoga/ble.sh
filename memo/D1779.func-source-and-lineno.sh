#!/bin/bash

function ble/function#get-source-and-lineno/.extract {
  local command=$1
  if [[ ${FUNCNAME[1]-} == "$_ble_util_function_util" && ${FUNCNAME[2]-} != "$_ble_util_function_util" ]]; then
    return 1
  else
    if [[ ${FUNCNAME[1]-} == "$_ble_util_function_name" ]]; then
      local src=${BASH_SOURCE[1]}
      local line=${BASH_LINENO[0]}
      echo "$src:$line" >/dev/tty
      if [[ -s $src ]]; then
        less +"${line}g" "$src"
      fi
    else
      declare -p BASH_SOURCE BASH_LINENO FUNCNAME >/dev/tty
    fi
    return 0
  fi
} 1>&11 2>&12

function ble/function#get-source-and-lineno {
  local _ble_util_function_name=$1
  local _ble_util_function_util=$FUNCNAME
  if ble/is-function "$_ble_util_function_name"; then
    (
      declare -ft "$_ble_util_function_name"
      builtin trap 'ble/function#get-source-and-lineno/.extract && return 0' DEBUG
      "$_ble_util_function_name"
    ) 11>&1 12>&2
  fi
}

function ble/function#get-source-and-lineno.impl2 {
  local ret unset_extdebug=
  if ! shopt -q extdebug; then
    unset_extdebug=1
    shopt -s extdebug
  fi
  ble/util/assign ret "declare -F '$1' &>/dev/null"; local ext=$?
  if [[ $unset_extdebug ]]: then
     shopt -u extdebug
  fi

  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
  fi
  return "$ext"
}

function ble/function#get-source-and-lineno.impl3 {
  local ret shopt=$BASHOPTS # 古い bash で使えない
  shopt -s extdebug
  ble/util/assign ret "declare -F '$1' &>/dev/null"; local ext=$?
  [[ :$unset_extdebug: == *:extdebug:* ]] || shopt -u extdebug

  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
  fi
  return "$ext"
}

function ble/function#get-source-and-lineno.impl4 {
  local ret ext
  if ! shopt -q extdebug; then
    shopt -s extdebug
    ble/util/assign ret "declare -F '$1' &>/dev/null"; ext=$?
    shopt -u extdebug
  else
    ble/util/assign ret "declare -F '$1' &>/dev/null"; ext=$?
  fi
  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
  fi
  return "$ext"
}

function ble/function#get-source-and-lineno.impl2a {
  local ret unset_extdebug=
  shopt -q extdebug || { unset_extdebug=1; shopt -s extdebug; }
  ble/util/assign ret "declare -F '$1' &>/dev/null"; local ext=$?
  [[ ! $unset_extdebug ]] || shopt -u extdebug
  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
  fi
  return "$ext"
}

#ble/function#get-source-and-lineno ble/util/assign
#ble/function#get-source-and-lineno ble/function#get-source-and-lineno
#ble/function#get-source-and-lineno ble/util/is-stdin-ready
#ble/function#get-source-and-lineno ble/util/setexit
