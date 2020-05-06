#!/bin/bash

(
  trap 'echo "RETURN:$BASH_COMMAND:[$FUNCNAME]"' RETURN
  function f1 {
    echo A
  }
  function f2 {
    echo B
    return 0
  }
  f1; f2

  set -T
  f1; f2
  set +T

  declare -ft f1 f2
  f1; f2
)

echo ------------------------------------------------------------------------------
(
  function ret { local count=0; return 1; }
  trap 'echo RETURN:$BASH_COMMAND; [[ $FUNCNAME == ret ]] && ((count++==0)) && return 2' RETURN
  function f1 {
    ret
    echo "exit=$?"
  }
  set -T
  f1
)

echo ------------------------------------------------------------------------------
# continue/break の引数
# 実際に抜けられるループ数よりも大きな数を指定すると全てのループを抜ける。
# 呼び出し元の関数にあるループを抜けるという事はない。

function f1 {
  local i
  for i in {0..2}; do
    echo "f1#$i:BEGIN"
    f2
    echo "f1#$i:END"
  done
}

function f2 {
  local i
  for i in {0..2}; do
    echo "f2#$i:BEGIN"
    break 2
    #continue 2
    echo "f2#$i:END"
  done
}

f1

echo ------------------------------------------------------------------------------
echo 'RETURN in trap'

(
  set -T
  function f1 {
    return 123
  }
  function handler {
    echo handler
    trap 'echo return Handler' RETURN
    f1
    return 321
  }

  trap handler RETURN
  f1

  trap handler DEBUG
  f1
)
