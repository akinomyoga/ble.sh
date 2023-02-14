#!/bin/bash

flag=

shopt -s extdebug

function set_exit {
  return "$1"
}
function set_trap {
  # DEBUG trap の中で trap や return を実行しても "現在のコマンド" は
  # 必ず実行される。
  #
  # Note: 中で BASH_COMMAND を書き換えても実際に実行されるコマンドが変
  # 化する訳ではない。(BASH_COMMAND="echo rewrite" として見たがやはり
  # NOT_REACHED1 が表示される)。
  #
  # Note: 中で trap - DEBUG するかどうかは関係ない。
  #
  # Note: continue や return の前に指定した終了ステータスは DEBUG trap
  # (extdebug) の振る舞いには関係ない。
  #
  #trap '[[ $flag == 1 ]] && { echo "cmd:$FUNCNAME/$BASH_COMMAND"; set_exit 2; return 2; }' DEBUG

  trap '[[ $flag == 1 ]] && { echo "cmd:$FUNCNAME/$BASH_COMMAND"; shopt -s extdebug; set_exit 2; }' DEBUG
}

function f1 {
  local flag= i=
  for ((i=0;i<10;i++)); do
    flag=1
    set_trap
    echo NOT_REACHED1
    flag=0
    echo NOT_REACHED2
  done
}
f1

