#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

function line {
  echo ---------- ---------- ---------- ----------
}

_ble_util_assign_base="/dev/shm/$UID.$$.read-stdout.tmp"
function veval {
  eval "${@:2}" >| "$_ble_util_assign_base"
  local _ret="$?"
  IFS= read -r -d '' "$1" < "$_ble_util_assign_base"
  return "$_ret"
}

d=/hello/world
dir=/hello/world
dirverylonglong=/hello/world

# # test
# ble-measure '[ a ]'
# ble-measure 'test a'
# ble-measure '[[ a ]]'

# # quote globpat
# ble-measure '[[ $dir == / ]]'
# ble-measure '[[ $dir == '\''/'\'' ]]'
# ble-measure '[[ $dir == "/" ]]'

# # quote var
# ble-measure '[[ $dir == / ]]'
# ble-measure '[[ "$dir" == / ]]'

# # varname
# ble-measure '[[ $dirverylonglong == / ]]'
# ble-measure '[[ $d == / ]]'
# ble-measure '[[ $dir == / ]]'

# # startsWith
# ble-measure '[[ $d == /* ]]'
# ble-measure '[[ ${d::1} == / ]]'
# ble-measure '[[ ! ${d##/*} ]]'
# ble-measure '[[ $d =~ ^/ ]]'

# # contains
# ble-measure '[[ $d == */* ]]'
# ble-measure '[[ ! ${d##*/*} ]]'
# ble-measure '[[ $d =~ / ]]'


#------------------------------------------------------------------------------
# 変数の代入

# # quote rhs
# ble-measure 'd=$d'
# ble-measure 'd="$d"'

# # multiple assign
# ble-measure 'a=$d b=$d'
# ble-measure 'a=$d; b=$d'

#------------------------------------------------------------------------------
# 算術式

# # assign
# ble-measure 'a=0'
# ble-measure '((a=0))'
# ble-measure 'a=0 b=0'
# ble-measure '((a=0,b=0))'

a=0 b=1

# # 判定
# ble-measure '[[ a == 0 ]] && x=1'
# ble-measure '((a==0)) && x=1'
# ble-measure '[[ a -eq 0 ]] && x=1'

# # increment
# ble-measure '((a++))'
# ble-measure "(('a++'))"
# ble-measure 'a=$((a+1))'
# ble-measure 'let a++'
# ble-measure "let 'a++'"

# # branch1
# ble-measure "((a==0&&(x=1)))"
# ble-measure "((a==0)) && x=1"
# ble-measure "((a==0)) && ((x=1))"
# ble-measure "if ((a==0)); then ((x=1)); fi"
# ble-measure "((a==1&&(x=1)))"
# ble-measure "((a==1)) && ((x=1))"
# ble-measure "if ((a==1)); then ((x=1)); fi"

# # branch2
# ble-measure "if ((a==0)); then ((x=1)); else ((y=1)); fi"
# ble-measure "((a==0?(x=1):(y=1)))"
# ble-measure "if ((a==1)); then ((x=1)); else ((y=1)); fi"
# ble-measure "((a==1?(x=1):(y=1)))"

# # branch3
# ble-measure "((a==1?(x=1):(a==2?(x=8):(a==3?(x=4):(x=3)))))"
# ble-measure "((x=a==1?1:(a==2?8:(a==3?4:3))))"
# ble-measure "if ((a==1)); then ((x=1)); elif ((a==2)); then ((x=8)); elif ((a==3)); then ((x=4)); else ((x=3)); fi"
# ble-measure "if [[ a == 1 ]]; then x=1; elif [[ a == 2 ]]; then x=8; elif [[ a == 3 ]]; then x=4; else x=3; fi"

# ble-measure 'n=0; for i in {1..10000}; do ((n+=i)); done; echo $n'
# ble-measure 'n=0; for i in $(seq 10000); do n=$(echo $n + $i | bc); done; echo $n'
# ble-measure 'for i in $(seq 10000); do printf "$i + "; [ $i -eq 10000 ] && printf "0\n"; done | bc'
# ble-measure "printf -v A '%d + ' {1..10000}; echo \$((\${A}0))"

#------------------------------------------------------------------------------
# 制御構造

# # 関数呼出
# function _empty { :; }
# function very_very_long_long_function_name { :; }
# ble-measure :
# ble-measure _empty
# ble-measure very_very_long_long_function_name

# # ループ
# ble-measure 'a=0; for ((i=0;i<10;i++)); do ((a+=i)); done'
# ble-measure 'a=0; for i in {0..10}; do ((a+=i)); done'
# ble-measure 'a=0; for ((i=0;i<10000;i++)); do ((a+=i)); done'
# ble-measure 'a=0; for i in {0..10000}; do ((a+=i)); done'

#------------------------------------------------------------------------------
# 配列操作

a=() b=()

# # push
# ble-measure "j=0; for i in {0..1000}; do a[j++]=\$i; done"
# ble-measure "for i in {0..1000}; do a+=(\$i); done"
# ble-measure "for i in {0..1000}; do a[\${#a[@]}]=\$i; done"
# ble-measure "for i in {0..1000}; do a=(\"\${a[@]}\" \$i); done"

#--------------------------------------
# 複数の配列の腹を触ると遅い件

# #a=({0..1000000})
# for n in 10 20 50 100 200 500 1000 2000 5000 10000 20000 50000 100000 200000; do
#   #a=(); ble-measure "for ((i=0;i<$n;i++)); do ((a[i]=i*i,b[i]=i)); done"
#   #ble-measure "for ((i=0;i<$n;i++)); do ((a[i]=i*i)); done; for ((i=0;i<$n;i++)); do ((b[i]=i)); done"
#   #ble-measure "for ((i=0;i<$n;i++)); do ((a[i]=i*i,b[i]=i)); done"
# done

# # 配列 & 変数にアクセス → 遅くない
# a=({0..1000000}); ble-measure "x=0; for ((i=0;i<200000;i++)); do ((a[i]=i*i,x=i)); done"

#------------------------------------------------------------------------------
# 配列 - glob フィルタ


# a=({0..999})
# function filter1 { i=0 b=(); for x in "${a[@]}"; do [[ $x == *1?2 ]] && b[i++]=$x; done; }
# function filter2 { veval b 'compgen -X "!*1?2" -W "${a[*]}"'; b=($b); }
# ble-measure 'filter1'
# ble-measure 'filter2'

# function filter2base { veval b 'type filter2base'; }
# ble-measure 'filter2base'

#------------------------------------------------------------------------------
# シェルオプション

# # shopt -q
# function ble/util/has-shopt { [[ :$BASHOPTS: == *:"$1":* ]]; }
# ble-measure 'shopt -q extquote'
# ble-measure '[[ :$BASHOPTS: == *:extquote:* ]]'
# ble-measure 'ble/util/has-shopt extquote'
# ble-measure 'shopt -q extquote &>/dev/null'

# # [[ -o option-name ]]
# ble-measure '[[ -o hashall ]]'
# ble-measure '[[ $- == *h* ]]'
# ble-measure '[[ :$SHELLOPTS: == *:hashall:* ]]'

#------------------------------------------------------------------------------
# その他 (未整理)

# ヒアストリングはそんなに速くない (fork に較べれば格段に速いが)
ble-measure ': <<< hello'
