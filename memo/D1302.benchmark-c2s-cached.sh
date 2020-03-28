#!/bin/bash

source src/benchmark.sh

ble/util/c2s.0() { :; }

table1=$' \x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F'
table1=$table1$'\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F'
table1=$table1$'\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F'
table1=$table1$'\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F'
table1=$table1$'\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F'
table1=$table1$'\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F'
table1=$table1$'\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F'
table1=$table1$'\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F'
ble/util/c2s.1() {
  if ((c<0x80)); then
    ret=${table1:c:1}
  else
    ret=something
  fi
}

for i in {0..127}; do
  table2[i]=${table1:i:1}
done
ble/util/c2s.2() {
  ret=${table2[c]}
  if [[ ! $ret ]]; then
    ret=something
  fi
}

#------------------------------------------------------------------------------

set +f
input=($(od -vAn -tx1 /dev/urandom | head -200 | od -vAn -td1))
function tester.loop {
  local ret
  for c; do
    "$c2s" "$c"
  done
}
function tester {
  local c2s=$1
  tester.loop "${input[@]}"
}

# ble-measure 'tester ble/util/c2s.0'
# ble-measure 'tester ble/util/c2s.1'
# ble-measure 'tester ble/util/c2s.2'

# bash-5.0
# 68272.500 usec/eval: tester ble/util/c2s.1 (x2)
# 87022.500 usec/eval: tester ble/util/c2s.2 (x2)

# bash-4.2
# 12300000.000 usec/eval: tester ble/util/c2s.1 (x1)
# 12323000.000 usec/eval: tester ble/util/c2s.2 (x1)

# bash-4.0
# 12262000.000 usec/eval: tester ble/util/c2s.1 (x1)
# 12323000.000 usec/eval: tester ble/util/c2s.2 (x1)

#------------------------------------------------------------------------------
# どうも遅いのは c2s を辞書から引く操作ではなくて、大量の引数を抱えた
# 関数から子関数を呼び出す時の動作の様である。
# 次に引数を小分けにして呼び出す事を考えてみる。
# 結果を見ると Bash-5.0 ではまとめて呼び出す方が速いが、
# Bash-4.4 以下では分割した方が速い。
# 色々計測しても一定しないが大体 150-170 辺りが最小になるだろうか。

function tester.2/loop1 {
  local N=$# i
  for ((i=0;i+B<N;i+=B)); do
    tester.loop "${@:i+1:B}"
  done
  ((i<N)) && tester.loop "${@:i+1:N-i}"
}
function tester.2 {
  local c2s=$1 B=${2:-100}
  tester.2/loop1 "${input[@]}"
}
# ble-measure 'tester.2 ble/util/c2s.0 5'
# ble-measure 'tester.2 ble/util/c2s.0 10'
# ble-measure 'tester.2 ble/util/c2s.0 20'
# ble-measure 'tester.2 ble/util/c2s.0 50'
# ble-measure 'tester.2 ble/util/c2s.0 100'
# ble-measure 'tester.2 ble/util/c2s.0 200'
# ble-measure 'tester.2 ble/util/c2s.0 500'
# ble-measure 'tester.2 ble/util/c2s.0 1000'
# ble-measure 'tester.2 ble/util/c2s.0 2000'
# ble-measure 'tester.2 ble/util/c2s.0 5000'
# ble-measure 'tester.2 ble/util/c2s.0 10000'

# bash-4.0
# 21591000.000 usec/eval: tester.2 ble/util/c2s.0 2 (x1)
#  8790000.000 usec/eval: tester.2 ble/util/c2s.0 5 (x1)
#  4481000.000 usec/eval: tester.2 ble/util/c2s.0 10 (x1)
#  2276000.000 usec/eval: tester.2 ble/util/c2s.0 20 (x1)
#   982000.000 usec/eval: tester.2 ble/util/c2s.0 50 (x1)
#   603000.000 usec/eval: tester.2 ble/util/c2s.0 100 (x1)
#   513000.000 usec/eval: tester.2 ble/util/c2s.0 200 (x1)
#   747000.000 usec/eval: tester.2 ble/util/c2s.0 500 (x1)
#  1297000.000 usec/eval: tester.2 ble/util/c2s.0 1000 (x1)
#  2491000.000 usec/eval: tester.2 ble/util/c2s.0 2000 (x1)
#  6045000.000 usec/eval: tester.2 ble/util/c2s.0 5000 (x1)
# 12179000.000 usec/eval: tester.2 ble/util/c2s.0 10000 (x1)

# bash-5.0
# 4975379.200 usec/eval: tester.2 ble/util/c2s.0 5 (x1)
# 2594160.200 usec/eval: tester.2 ble/util/c2s.0 10 (x1)
# 1371359.200 usec/eval: tester.2 ble/util/c2s.0 20 (x1)
#  591166.200 usec/eval: tester.2 ble/util/c2s.0 50 (x1)
#  333587.200 usec/eval: tester.2 ble/util/c2s.0 100 (x1)
#  199348.200 usec/eval: tester.2 ble/util/c2s.0 200 (x1)
#  122687.200 usec/eval: tester.2 ble/util/c2s.0 500 (x1)
#   95477.700 usec/eval: tester.2 ble/util/c2s.0 1000 (x2)
#   82203.200 usec/eval: tester.2 ble/util/c2s.0 2000 (x2)
#   72446.200 usec/eval: tester.2 ble/util/c2s.0 5000 (x2)
#   68311.200 usec/eval: tester.2 ble/util/c2s.0 10000 (x2)

# bash-4.4
#  8066000.000 usec/eval: tester.2 ble/util/c2s.0 5 (x1)
#  4074000.000 usec/eval: tester.2 ble/util/c2s.0 10 (x1)
#  2070000.000 usec/eval: tester.2 ble/util/c2s.0 20 (x1)
#   904000.000 usec/eval: tester.2 ble/util/c2s.0 50 (x1)
#   528000.000 usec/eval: tester.2 ble/util/c2s.0 100 (x1)
#   438000.000 usec/eval: tester.2 ble/util/c2s.0 200 (x1)
#   705000.000 usec/eval: tester.2 ble/util/c2s.0 500 (x1)
#  1290000.000 usec/eval: tester.2 ble/util/c2s.0 1000 (x1)
#  2541000.000 usec/eval: tester.2 ble/util/c2s.0 2000 (x1)
#  6197000.000 usec/eval: tester.2 ble/util/c2s.0 5000 (x1)
# 12171000.000 usec/eval: tester.2 ble/util/c2s.0 10000 (x1)
#   428000.000 usec/eval: tester.2 ble/util/c2s.0 150 (x1)
#   435000.000 usec/eval: tester.2 ble/util/c2s.0 200 (x1)
#   463000.000 usec/eval: tester.2 ble/util/c2s.0 250 (x1)
#   494000.000 usec/eval: tester.2 ble/util/c2s.0 300 (x1)
#   544000.000 usec/eval: tester.2 ble/util/c2s.0 350 (x1)
#   586000.000 usec/eval: tester.2 ble/util/c2s.0 400 (x1)

# 改めて計測する→対して違いは見られない
# ble-measure 'tester.2 ble/util/c2s.0 160'
# ble-measure 'tester.2 ble/util/c2s.1 160'
# ble-measure 'tester.2 ble/util/c2s.2 160'

#------------------------------------------------------------------------------
# 実際に buff に値を格納して確かめてみる事にする
# 然し、それでも大した計算時間の違いはない。

function tester.3/loop2 {
  local ret
  for c; do
    "$c2s" "$c"
    buff[b++]=$ret
  done
}
function tester.3/loop1 {
  local N=$# i b=0
  local -a buff=()
  for ((i=0;i+B<N;i+=B)); do
    tester.3/loop2 "${@:i+1:B}"
  done
  ((i<N)) && tester.3/loop2 "${@:i+1:N-i}"
}
function tester.3 {
  local c2s=$1 B=${2:-160}
  tester.3/loop1 "${input[@]}"
}

# ble-measure 'tester.3 ble/util/c2s.0'
# ble-measure 'tester.3 ble/util/c2s.1'
# ble-measure 'tester.3 ble/util/c2s.2'
