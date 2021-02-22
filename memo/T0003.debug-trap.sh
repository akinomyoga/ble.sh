#!/bin/bash

bash44_traverse=1

function user-debug-handler {
  local caller=${FUNCNAME[1]}
  [[ $caller == ble-debug-handler ]] &&
    caller=${FUNCNAME[2]}
  echo "trap($*):$caller: $BASH_COMMAND"
}

# * 4.4 以降では最初に DEBUG を設定した関数呼び出しレベルを書き換える?
#   否、関数終了時に上書きする様にしたら良いという事の気がする。
# * 関数を一つ上がったら trap handler を削除
# * trap handler が全てなくなったら解除
# ? yes: 内側の関数で活性化した時に外側の関数でもちゃんと DEBUG trap が発動
#   するのだろうか。

_debug_trap_handlers=()
function ble/trap-debug {
  local depth=$((${#FUNCNAME[@]}-2))
  if [[ $1 != - ]]; then
    _debug_trap_handlers[depth]=$1

    # 再活性化 (extdebug/functrace が設定されていなければ、
    # 設定を行った関数呼び出しレベルでしか DEBUG trap は発生しない)。
    builtin trap ble-debug-handler DEBUG
  else
    unset '_debug_trap_handlers[depth]'
  fi
}
function ble-debug-handler {
  local depth=$((${#FUNCNAME[@]}-1))
  [[ $_ble_trap_suppress || ${FUNCNAME[1]} == trap ]] && return 0
  #echo "ble-debug-handler"
  for ((;depth>=0;depth--)); do
    local handler=${_debug_trap_handlers[depth]-}
    [[ $handler ]] || continue
    eval "$handler"
    return "$?"
  done
}
function ble-return-handler {
  #echo "ble-return-handler"
  local _ble_trap_suppress=1
  local depth=$((${#FUNCNAME[@]}-1))
  ((depth)) || return 0
  if [[ $bash44_traverse && ${_debug_trap_handlers[depth]+set} ]]; then
    _debug_trap_handlers[depth-1]=${_debug_trap_handlers[depth]}
  fi
}

#------------------------------------------------------------------------------

function f3 {
  builtin trap '_ble_trap_suppress=1 ble-return-handler' RETURN
  trap 'user-debug-handler f3' DEBUG
  echo f3
}
function f2 {
  builtin trap '_ble_trap_suppress=1 ble-return-handler' RETURN
  echo f2:1
  f3
  echo f2:2
  trap - DEBUG
}
function f1 {
  builtin trap '_ble_trap_suppress=1 ble-return-handler' RETURN
  trap 'user-debug-handler f1' DEBUG
  echo f1:1
  f2
  echo f1:3
  trap - DEBUG
}

#------------------------------------------------------------------------------

#trap ble-debug-handler DEBUG

# 通常
f1

echo ----------
trap ble-return-handler RETURN
function trap { local _ble_trap_suppress=1; ble/trap-debug "$1"; }
f1
