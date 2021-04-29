#!/bin/bash

# 一旦配列に入れるだけでもコストになっている。
# time { a=({000000..500000}); printf '%s\0' "${a[@]}"; } >/dev/null
# time { printf '%s\0' {000000..500000}; } >/dev/null

if ((_ble_bash>=50000)); then
  a=({000000..500000})
else
  a=({000000..050000})
fi
echo a:initialized

# ble-measure 'declare -p a > .tmp' # 100ms

function qprint1 {
  printf '%s\n' "${a[@]@Q}"
}
function qprint1b {
  printf '%q\n' "${a[@]}"
}
function qprint2 {
  local i n=${#a[@]}
  for ((i=0;i<n;i++)); do
    echo "${a[i]@Q}"
  done
}
#ble-measure 'qprint1 > .tmp' # 1573
#ble-measure 'qprint1b > .tmp' # 1285
#ble-measure 'qprint2 > .tmp' #2409

function eval1 {
  eval "b=($(< .tmp))"
}
#ble-measure 'eval1' # 1073

#------------------------------------------------------------------------------

function zprint0 {
  # bash-3.* では ^A, ^? が化けるので補正が必要
  printf '%s\0' "${a[@]}" > .tmp
}
function zprint1 {
  local i n=${#a[@]}
  for ((i=0;i<n;i++)); do
    printf '%s\0' "${a[i]}"
  done
}
#ble-measure zprint0 # 954
#ble-measure 'zprint1 > .tmp' # 2303

function zmapfile1 {
  mapfile -d '' b < .tmp
}
#ble-measure 'zmapfile1' # 1603

# ble-measure 'ble/util/writearray -d "" a > .tmp' # 883ms
# ble-measure 'ble/util/readarray -d "" b < .tmp' # 1636ms
# echo "a:${#a[@]} -> b:${#b[@]}"

#------------------------------------------------------------------------------

function save-nl1 {
  printf '%s\n' "${a[@]}"
}
function save-nl2 {
  local i n=${#a[@]}
  for ((i=0;i<n;i++)); do
    echo "${a[i]}"
  done
}
function save-nl3 {
  local i n=${#a[@]} B=$1
  for ((i=0;i<n;i+=B)); do
    printf '%s\n' "${a[@]:i:B}"
  done
}
#ble-measure 'save-nl1 > .tmp' # 1129
#ble-measure 'save-nl2 > .tmp' # 2171
#ble-measure 'save-nl3 10 > .tmp' # -
#ble-measure 'save-nl3 100 > .tmp' # -
#ble-measure 'save-nl3 1000 > .tmp' # -
#ble-measure 'save-nl3 10000 > .tmp' # 13948
#ble-measure 'save-nl3 100000 > .tmp' # 3254

function load-nl1 {
  mapfile -t b < .tmp
}
#ble-measure 'mapfile1' # 67

function save-nlfix1 {
  local i n=${#a[@]} ret
  for ((i=0;i<n;i++)); do
    if [[ ${a[i]} == *$'\n'* ]]; then
      ble/string#escape-for-bash-escape-string "${a[i]}"
      echo "$ret"
      echo "$i" >> .tmp-nlfix
    else
      echo "${a[i]}"
    fi
  done
}
function save-nlfix2 {
  local i n=${#a[@]} v ret
  for ((i=0;i<n;i++)); do
    v=${a[i]}
    if [[ $v == *$'\n'* ]]; then
      ble/string#escape-for-bash-escape-string "$v"
      echo "\$'$ret'"
      echo "$i" >> .tmp-nlfix
    else
      echo "$v"
    fi
  done
}

function save-nlfix3 {
  ble/util/writearray --nlfix a
}

#ble-measure 'save-nlfix1 > .tmp' # 3157
#ble-measure 'save-nlfix2 > .tmp' # 3119
#ble-measure 'save-nlfix3 > .tmp'

# 制御文字を含む時: 2382 (gawk), 1284 (nawk), 817 (mawk)
# 制御文字を含まない時: 2150 (gawk), 372 (nawk), 1350 (mawk)
#ble-measure 'save-nlfix3 > .tmp'

function load-nlfix1 {
  mapfile -t b < .tmp
  local ifix
  for ifix in $(< .tmp-nlfix); do
    eval "b[ifix]=${b[ifix]}"
  done
}
#ble-measure 'load-nlfix1' # 83

ble-measure 'ble/util/writearray --nlfix a > .tmp' # 364ms (480ms bash-4.0)
ble-measure 'ble/util/readarray --nlfix b < .tmp' # 81ms (110ms bash-4.0)
echo "a:${#a[@]} -> b:${#b[@]}"

#------------------------------------------------------------------------------
# function ble/util/save-large-array {
#   ble/util/writearray --nlfix > .tmp
# }
# function ble/util/load-large-array {
#   ble/util/writearray --nlfix < .tmp
# }



a=() b=()
