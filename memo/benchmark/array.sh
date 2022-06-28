#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

S=({1..10000})

# 2016-07-07
# ここでは巨大配列に対して効率的に処理を実行する方法について考える。

#------------------------------------------------------------------------------
# array#filter

function truncateD.1 {
  local -a A=()
  A=("${S[@]}")

  local N=${#S[@]}
  local i=$((N/4*3))
  A=("${S[@]::i}")
}
function truncateD.unset1 {
  local -a A=()
  A=("${S[@]}")

  local N=${#S[@]}
  local i=$((N/4*3))
  for ((j=i;j<N;j++)); do
    unset 'A[i]'
  done
}
function truncateD.unset2 {
  local -a A=()
  A=("${S[@]}")

  local N=${#S[@]}
  local i=$((N/4*3))
  for ((j=N;--j>=i;)); do
    unset 'A[j]'
  done
}

# ble-measure truncateD.1 # 101972us for 10k
# ble-measure truncateD.unset1 # 347972us for 10k
# ble-measure truncateD.unset2 # 203972us for 10k
# # 元の配列の長さと削除する長さに依存する。

function filterD.1 {
  local -a A=()
  A=("${S[@]}")

  local i j=-1 N=${#S[@]}
  for ((i=0;i<N;i++)); do
    if ((A[i]%243!=2)); then
      ((++j!=i)) && A[j]="${A[i]}"
    fi
  done

  local k
  for ((k=N;--k>j;)); do
    unset 'A[k]'
  done
}

function filterD.2 {
  local -a A=()
  A=("${S[@]}")

  local field i=0 j=-1 N=${#S[@]}
  for field in "${A[@]}"; do
    if ((field%243!=2)); then
      ((++j!=i)) && A[j]="$field"
    fi
    ((i++))
  done

  local k
  for ((k=N;--k>j;)); do
    unset 'A[k]'
  done
}

ble-measure filterD.1 # 855972us for 10k
ble-measure filterD.2 # 551972us for 10k


#------------------------------------------------------------------------------

function seq_read.1 {
  local s=0 N=${#S[@]}
  for ((i=0;i<N;i++)); do
    ((s+=S[i]))
  done
}

function reverse_read.1 {
  local s=0 N=${#S[@]}
  for ((i=N-1;i>=0;i--)); do
    ((s+=S[i]))
  done
}

# ble-measure seq_read.1
# ble-measure reverse_read.1

#------------------------------------------------------------------------------
# sparse_array_read
#
#   bash では疎な配列を作成することができる。
#   疎な配列に対して連続的に添字を動かしてアクセスする場合の速度はどうか。
#   疎な配列の場合には連続的に添字を動かすと殆どの場合で hit しない。
#   この様な場合にアクセスは遅くならないだろうかというのが気になる。
#

S1=()
S1[1]=1
S1[10]=1
S1[100]=1
S1[1000]=1
S1[10000]=1
S1[100000]=1

function sparse_array_read.dense {
  local s=0
  for ((i=0;i<10000;i++)); do
    ((s+=S[i]*i))
  done
}

function sparse_array_read.1 {
  local s=0
  for ((i=0;i<10000;i++)); do
    ((s+=S1[i]*i))
  done
}

function sparse_array_read.1r {
  local s=0
  for ((i=0;i<10000;i++)); do
    ((s+=S1[9999-i]*i))
  done
}

# ble-measure sparse_array_read.dense
# ble-measure sparse_array_read.1
# ble-measure sparse_array_read.1r
