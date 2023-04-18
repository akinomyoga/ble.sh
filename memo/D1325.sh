#!/bin/bash

function print-header {
  echo
  printf '%s\n' "$@"
}

print-header 'Q0. readonly 属性は解除できないし変数も削除できない。'
(
  var=aaa
  declare -g -r aaa
  declare -p aaa
  echo "\${param+-} ... ${aaa+set}${aaa-unset}"
  echo "\${param+-} ... ${!var+set}${!var-unset}"
  declare +r aaa 2>/dev/null || echo cannot reset rflag
  unset -v aaa 2>/dev/null || echo cannot unset readonly var
)


print-header 'Q1 外側のスコープの変数に対して -r を付加できるか。' \
             '→readonly で付加する事ができる。'
(
  v1=1
  function f1 { readonly v1; }
  f1
  declare -p v1
)

print-header 'Q2. typeset を実行すると新しく変数が関数内に作られる。'
(
  v1=1
  function f1 { typeset -r v1; }
  f1
  declare -p v1
)

print-header 'Q3. 存在しない変数に対して readonly を呼び出すと何が起こるか。' \
             '→どうやらグローバルの slot に readonly が付加される様子だ。'
(
  function f1 { readonly v1; declare -p v1; }
  f1
  declare -p v1
)

print-header 'Q4. readonly を付加したグローバル変数と同名のローカル変数は作れない筈。'
(
  readonly v1=1
  function f1 { local v1=1 2>/dev/null || echo fail; }
  f1
)

print-header 'Q5. readonly を付加した局所変数の場合は局所変数を作れる'
(
  function f1 { local -r v1=1; f2; }
  function f2 { local v1=2 2>/dev/null || echo fail; declare -p v1; }
  f1
)

function is-global/test { ! local "$1" 2>/dev/null; }
function is-global { (readonly "$1"; is-global/test "$1"); }
print-header 'Q6. is-global は readonly を使って実装できる。'
(
  v1=1 v2=2
  function f1 {
    local v2=22 v3=33
    f2
  }
  function f2 {
    local v4=444
    is-global v0 && echo v0:ok
    is-global v1 && echo v1:ok
    is-global v2 || echo v2:ok
    is-global v3 || echo v3:ok
    is-global v4 || echo v4:ok
  }
  f1
)

print-header 'Q7 readonly ローカル変数は unlocal できない。'
(
  v1=g
  function f1 { local -r v1=L; f2; }
  function f2 { unset v1; declare -p v1; }
  f1
)
