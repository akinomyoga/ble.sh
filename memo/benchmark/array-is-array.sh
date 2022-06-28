#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
  _ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))
fi

arr1[0]=1234

#------------------------------------------------------------------------------
# 1 declare +a を用いる方法

# broken この実装は呼び出し元のローカル変数が見えない。
#   また現在の関数のローカル変数も見えない。
#   更に、bash-4.2 以降でないと動かない。
function ble/is-array1 { ! declare -g +a "$1" &>/dev/null; }

ble-measure 'ble/is-array1 arr1' #  55.20 usec/eval
ble-measure 'ble/is-array1 arr2' #  51.80 usec/eval
ble-measure 'ble/is-array1 arr'  #  51.00 usec/eval

#------------------------------------------------------------------------------
# 2 compgen -A arrayvar を用いる方法 (不完全)

# broken 指定した名前で "始まる" 配列があれば真と判定されてしまう。
function ble/is-array2 { compgen -A arrayvar "$1" &>/dev/null; }

ble-measure 'ble/is-array2 arr1' # 1439.90 usec/eval
ble-measure 'ble/is-array2 arr2' # 1429.90 usec/eval
ble-measure 'ble/is-array2 arr'  # 1439.90 usec/eval

#------------------------------------------------------------------------------
# 3 compgen -A arrayvar を用いる方法 (完全)

function ble/is-array3 {
  compgen -A arrayvar "$1" >| "$_ble_util_assign_base" 2>/dev/null || return 1
  local REPLY; read -r < "$_ble_util_assign_base"
  [[ $REPLY == "$1" ]]
}

ble-measure 'ble/is-array3 arr1' # 1519.90 usec/eval
ble-measure 'ble/is-array3 arr2' # 1469.90 usec/eval
ble-measure 'ble/is-array3 arr'  # 1549.90 usec/eval

# 結論として compgen を使うのが一番のボトルネックになっているので、
# 一時ファイルに書き出してそれを読み出してチェックするというのは速度的な問題にはならない。
# それでも 1.5ms もかかっていることには注意する。例えば 600 の配列を確認すると 1 秒になる。

#------------------------------------------------------------------------------
# 4 compgen -A arrayvar -X ! を用いる方法 (完全)

function ble/is-array4 { compgen -A arrayvar -X \!"$1" "$1" 2>/dev/null; }

ble-measure 'ble/is-array4 arr1' # 1439.90 usec/eval
ble-measure 'ble/is-array4 arr2' # 1439.90 usec/eval
ble-measure 'ble/is-array4 arr'  # 1439.90 usec/eval

# 実は出力を確認しなくても良い。こちらの方が速い。

#------------------------------------------------------------------------------
# 4 bash-4.4 ${parameter@a} を用いる方法

# 2018-07-15 bash-bug メーリングリストで ${param@a} の存在を知った。
# bash-4.4 以降の機能の様だ。これを使えば簡単に配列属性を確認できる。

if ((_ble_bash>=40400)); then
  function ble/is-array5 { [[ ${!1@a} == *a* ]]; }
  ble/is-array5 arr1 || echo 'error: 5 arr1'
  ble/is-array5 arr2 && echo 'error: 5 arr2'
  ble/is-array5 arr  && echo 'error: 5 arr'

  ble-measure 'ble/is-array5 arr1' # 24.80 usec/eval
  ble-measure 'ble/is-array5 arr2' # 23.30 usec/eval
  ble-measure 'ble/is-array5 arr'  # 23.10 usec/eval
fi

#------------------------------------------------------------------------------
# 5 declare -p の結果を参照する?

arr3=({1..1000})
function ble/is-array6 {
  local __name=$1 __def
  ble/util/assign __def 'declare -p "$name" 2>/dev/null'
  local rex='^declare -[b-zA-Z]*a'
  [[ $__def =~ $rex ]]
}
ble-measure 'ble/is-array6 arr1' # 24.80 usec/eval
ble-measure 'ble/is-array6 arr2' # 23.30 usec/eval
ble-measure 'ble/is-array6 arr3' # 23.10 usec/eval

# 2020-04-12 の計測結果 @ chatoyancy bash-5.0
#   この結果を見ると実は declare -p をしてしまった方が
#   compgen に頼るよりも高速な様である。
#   Cygwin では余り違いが見られないが、Cygwin ならば
#   恐らく bash-4.4 以降に保たれているので
#   ${var@a} を使う事ができるのでそれほど気にしなくても良い?
#
#   481.398 usec/eval: ble/is-array4 arr1 (x500)
#   479.936 usec/eval: ble/is-array4 arr2 (x500)
#   479.532 usec/eval: ble/is-array4 arr (x500)
#     4.422 usec/eval: ble/is-array5 arr1 (x20000)
#     4.038 usec/eval: ble/is-array5 arr2 (x20000)
#     4.023 usec/eval: ble/is-array5 arr (x20000)
#   164.238 usec/eval: ble/is-array6 arr1 (x1000)
#   165.432 usec/eval: ble/is-array6 arr2 (x1000)
#   165.417 usec/eval: ble/is-array6 arr3 (x1000)
#
# chatoyancy bash-4.3
#   389.800 usec/eval: ble/is-array4 arr1 (x500)
#   387.800 usec/eval: ble/is-array4 arr2 (x500)
#   389.800 usec/eval: ble/is-array4 arr (x500)
#   203.800 usec/eval: ble/is-array6 arr1 (x500)
#   201.800 usec/eval: ble/is-array6 arr2 (x500)
#   201.800 usec/eval: ble/is-array6 arr3 (x500)
#
# chatoyancy bash-3.2
#   401.200 usec/eval: ble/is-array4 arr1 (x500)
#   401.200 usec/eval: ble/is-array4 arr2 (x500)
#   401.200 usec/eval: ble/is-array4 arr (x500)
#   213.200 usec/eval: ble/is-array6 arr1 (x500)
#   211.200 usec/eval: ble/is-array6 arr2 (x500)
#   211.200 usec/eval: ble/is-array6 arr3 (x500)
#
# letsnote2019 bash-4.4
#   1478.000 usec/eval: ble/is-array4 arr1 (x100)
#   1408.000 usec/eval: ble/is-array4 arr2 (x100)
#   1518.000 usec/eval: ble/is-array4 arr (x100)
#   1448.000 usec/eval: ble/is-array6 arr1 (x100)
#   1468.000 usec/eval: ble/is-array6 arr2 (x100)
#   1478.000 usec/eval: ble/is-array6 arr3 (x100)
