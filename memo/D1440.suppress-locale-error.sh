#!/bin/bash

{
  LC_CTYPE=pt_PT.UTF-8
} 2>/dev/null

checkA1() { local LC_ALL= LC_CTYPE=C; builtin read -t 0; } 2>/dev/null
checkB1() { local LC_ALL= LC_CTYPE=C; builtin eval 'echo "${#a}"'; } 2>/dev/null

# x [bash-bug] この方法だと LC_CTYPE が反映されない。
checkA2() { LC_ALL= LC_CTYPE=C builtin read -t 0; } 2>/dev/null
checkB2() { LC_ALL= LC_CTYPE=C eval 'echo "${#a}"'; } 2>/dev/null

# checkB3
# - この方法だと余分に関数呼び出しが入る
# o 然し、unlocal は共通関数なのでその場で定義するのは一つの関数だけで良い。
# - 終了ステータスが意味を持つ場合には一旦ステータスを保存しなければならない。
checkB3() {
  local LC_ALL= LC_CTYPE=C
  echo "${#a}"
  ble/util/unlocal LC_CTYPE LC_ALL
} 2>/dev/null

# checkB4
# - これは動くが、これも余分に関数呼び出しが入る。
# - その場で関数を複数定義しなければならない。
checkB4.impl() { local LC_ALL= LC_CTYPE=C; echo "${#a}"; }
checkB4() {
  checkB4.impl 2>/dev/null
}

# x bash-4.1 以下で LC_CTYPE が反映されない。
checkB5.impl() { echo "${#a}"; }
checkB5() {
  LC_ALL= LC_CTYPE=C checkB5.impl 2>/dev/null
}

a=あいう
echo A
# checkA1
# checkB1
#checkA2
#checkB3
#checkB4
checkB5
echo Z
