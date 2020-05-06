#!/bin/bash

function check1 {
  function f1 {
    local i
    for ((i=0;i<10;i++)); do
      ((i==0)) && continue
      ((i==1)) && break
    done
    return 1
  }
  function f2 {
    echo f2:BEGIN
    f1
    echo f2:END
  }

  trap 'echo "\$ $BASH_COMMAND"' DEBUG

  # trace 属性のない場合
  f2

  # 内側の関数のみ trace 属性のある場合
  declare -ft f1
  f2

  # 外側・内側の関数に trace 属性の在る場合
  declare -ft f1 f2
  f2
}

echo ------------------------------------------------------------------------------
echo check1
(check1)

function check2 {
  function f1 {
    echo '$ trap -p'
    trap -p
    echo '$ trap -p DEBUG'
    trap -p DEBUG
  }

  trap 'echo "\$ $BASH_COMMAND"' DEBUG
  echo '$ trap -p'
  trap -p
  echo '$ trap -p DEBUG'
  trap -p DEBUG
  f1
}

echo ------------------------------------------------------------------------------
echo check2
(check2)

function check3 {
  function f1 {
    trap 'echo "[DEBUG]"' DEBUG
  }
  function f2 {
    trap DEBUG
  }

  trap 'echo "\$ $BASH_COMMAND"' DEBUG
  f2
  f2
  f1
  f1
}
echo ------------------------------------------------------------------------------
echo check3
(check3)

function check4 {
  function f1 {
    echo hello1
    trap 'echo "\$ $BASH_COMMAND"' DEBUG
    echo hello2
  }
  trap 'echo "\$ $BASH_COMMAND"' DEBUG
  f1
}
echo ------------------------------------------------------------------------------
echo check4
(check4)

echo ------------------------------------------------------------------------------
function check5 {
  function trap-debug {
    echo "alpha:$BASH_COMMAND"
    trap 'echo "DEBUG:DEBUG $BASH_COMMAND"' DEBUG
    trap -p DEBUG
    echo "beta:$BASH_COMMAND"
  }
  trap 'echo A; trap-debug; echo Z' DEBUG
  echo gamma
}
echo check5
(check5)
