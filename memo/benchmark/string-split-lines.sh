#!/usr/bin/env bash

source ../../src/benchmark.sh


text='
echo hello 2
echo hello 3
echo hello 4

echo hello 6
echo hello 7
echo hello 8


echo hello 11
'

function check-split-implementation {
  local fname=$1 ret
  "$fname" "$text"
  if ((${#ret[@]}!=12)); then
    echo "$fname: wrong result"
    declare -p ret
  fi >&2
}

#------------------------------------------------------------------------------
# 実装1: 改行を置換 & eval arr=()

function split1 {
  local text=$1 sep='' esc='\'
  if [[ $text == *$sep* ]]; then
    a=$esc b=$esc'A' text=${text//"$a"/"$b"}
    a=$sep b=$esc'B' text=${text//"$a"/"$b"}

    text=${text//$'\n'/"$sep"}
    GLOBIGNORE=\* IFS=$sep eval 'arr=($text$sep)'

    ret=()
    local value
    for value in "${arr[@]}"; do
      if [[ $value == *$esc* ]]; then
        a=$esc'B' b=$sep value=${value//"$a"/"$b"}
        a=$esc'A' b=$esc value=${value//"$a"/"$b"}
      fi
      ret[${#ret[@]}]=$value
    done
  else
    text=${text//$'\n'/"$sep"}
    GLOBIGNORE=\* IFS=$sep eval 'ret=($text$sep)'
  fi
}

check-split-implementation split1
function split1.measure { split1 "$text"; }
ble-measure split1.measure

#------------------------------------------------------------------------------
# 実装2: 正規表現で一つずつ切り出し

function split2 {
  local text=$1 rex=$'[^\n]*'
  ret=()
  while :; do
    [[ $text =~ $rex ]]
    ret[${#ret[@]}]=$BASH_REMATCH
    text=${text:${#BASH_REMATCH}}
    [[ $text ]] || break
    text=${text:1}
  done

  # 以下のようにしてみたが微妙に遅くなった。
  # ${#BASH_REMATCH} の計算を変数に保存しても変わらない。
  # while :; do
  #   [[ $text =~ $rex ]]
  #   ret[${#ret[@]}]=$BASH_REMATCH
  #   ((${#BASH_REMATCH}<${#text})) || break
  #   text=${text:${#BASH_REMATCH}+1}
  # done
}

check-split-implementation split2
function split2.measure { split2 "$text"; }
ble-measure split2.measure

#------------------------------------------------------------------------------
# 実装3: mapfile を使う

function split3 {
  mapfile -t ret <<< "$1"
}
check-split-implementation split3
function split3.measure { split3 "$text"; }
ble-measure split3.measure

#------------------------------------------------------------------------------
# 実装4: グロブパターンで一つずつ切り出し

function split4 {
  local text=$1 value
  ret=()
  while :; do
    if [[ $text == *$'\n'* ]]; then
      value=${text%%$'\n'*}
      ret[${#ret[@]}]=$value
      text=${text#*$'\n'}
      #text=${text:${#value}+1}
    else
      ret[${#ret[@]}]=$text
      break
    fi
  done
}
check-split-implementation split4
function split4.measure { split4 "$text"; }
ble-measure split4.measure

