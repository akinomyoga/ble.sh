#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

declare RANDSUP=32768

function fill-rand {
  data=()
  local i n=${1:-10000}
  for ((i=0;i<n;i++)); do
    data[i]=$RANDOM
  done
}

function sort.command {
  data=($(printf '%s\n' "${data[@]}"|sort -n))
}

function sort.qsort1.1 {
  local L=$1 U=$2
  local p=${data[L+RANDOM*(U-L)/RANDSUP]}

  local i=$L j=$((U-1)) t
  while :; do
    while ((data[i]<p)); do ((i++)); done
    while ((i<j&&p<=data[j])); do ((j--)); done

    ((i<j)) || break

    ((t=data[i],data[i++]=data[j],data[j--]=t))
  done
  while ((data[j]==p)); do ((j++)); done
  #((j++))
  ((L+1<i)) && sort.qsort1.1 "$L" "$i"
  ((j+1<U)) && sort.qsort1.1 "$j" "$U"
}
function sort.qsort1 {
  local L=0 U=${#data[@]}
  ((L+1<U)) && sort.qsort1.1 "$L" "$U"
}

#------------------------------------------------------------------------------

function sort.qsort3.1 {
  local L=$1 U=$2

  local length=$((U-L))
  if ((length<=1)); then
    return 0

  elif ((length==2)); then
    local a=${data[L]} b=${data[L+1]}
    if ((a>b)); then
      data[L]=$b
      data[L+1]=$a
    fi
    return 0

  elif ((length==3)); then
    local a=${data[L]} b=${data[L+1]} c=${data[L+2]}
    if ((b<a)); then
      if ((a<c)); then # bac
        data[L]=$b data[L+1]=$a
      elif ((b<c)); then # bca
        data[L]=$b data[L+1]=$c data[L+2]=$a
      else # cba
        data[L]=$c data[L+2]=$a
      fi
    else # ab
      if ((c<a)); then # cab
        data[L]=$c data[L+1]=$a data[L+2]=$b
      elif ((c<b)); then # acb
        data[L+1]=$c data[L+2]=$b
      fi
    fi

  elif ((length==4)); then
    local a=${data[L]} b=${data[L+1]} c=${data[L+2]} d=${data[L+3]}
    ((b<a)) && local a=$b b=$a
    ((d<c)) && local c=$d d=$c

    if ((a<c)); then
      #a|b,cd
      if ((b<c)); then # abcd
        data[L]=$a data[L+1]=$b data[L+2]=$c data[L+3]=$d
      elif ((b<d)); then # acbd
        data[L]=$a data[L+1]=$c data[L+2]=$b data[L+3]=$d
      else # acdb
        data[L]=$a data[L+1]=$c data[L+2]=$d data[L+3]=$b
      fi
    else
      #c|ab,d
      if ((d<a)); then # cdab
        data[L]=$c data[L+1]=$d data[L+2]=$a data[L+3]=$b
      elif ((d<b)); then # cadb
        data[L]=$c data[L+1]=$a data[L+2]=$d data[L+3]=$b
      else # cabd
        data[L]=$c data[L+1]=$a data[L+2]=$b data[L+3]=$d
      fi
    fi

  elif ((length<=64)); then
    local M=$((L+length/2))
    sort.qsort3.1 "$L" "$M"
    sort.qsort3.1 "$M" "$U"

    # merge
    local index=$L lhs rhs out=
    for rhs in "${data[@]:M:U-M}"; do
      while ((index<M&&(lhs=data[index])<rhs)); do
        out="$out $lhs"
        ((index++))
      done
      out="$out $rhs"
    done
    out="$out ${data[*]:index:M-index}"

    data=("${data[@]::L}" $out "${data[@]:U}")

  else #elif ((length<10)); then
    # quick sort
    local L=$1 U=$2
    local p=${data[L+RANDOM*(U-L)/RANDSUP]}

    local i=$L j=$((U-1)) t
    while :; do
      while ((data[i]<p)); do ((i++)); done
      while ((i<j&&p<=data[j])); do ((j--)); done
      ((i<j)) || break
      ((t=data[i],data[i++]=data[j],data[j--]=t))
    done
    while ((data[j]==p)); do ((j++)); done
    #((j++))
    ((L+1<i)) && sort.qsort3.1 "$L" "$i"
    ((j+1<U)) && sort.qsort3.1 "$j" "$U"
  fi
}

function sort.qsort3 {
  local L=0 U=${#data[@]}
  ((L+1<U)) && sort.qsort3.1 "$L" "$U"
}

#------------------------------------------------------------------------------

function sort.array {
  local -a dict
  local a dup=0
  for a in "${data[@]}"; do ((dict[a]++&&dup++)); done
  if ((dup)); then
    # 重複があると駄目…
    data=()
    for a in "${!dict[@]}"; do
      for ((i=0;i<dict[a];i++)); do
        data+=("$a")
      done
    done
  else
    data=("${!dict[@]}")
  fi
}

#------------------------------------------------------------------------------

function sort._insert {
  local L=${1:-0} U=${2:-${#data[@]}}
  for ((i=L+1;i<U;i++)); do
    for ((j=i;j>L;j--)); do
      ((data[j-1]<=data[j])) && break
      # ■
    done
  done
}

# fill-rand
# declare -p data
# sort.command
# declare -p data

ble-measure 'fill-rand'
ble-measure 'fill-rand && sort.qsort1'
ble-measure 'fill-rand && sort.qsort3'
ble-measure 'fill-rand && sort.command'
ble-measure 'fill-rand && sort.array'

function check-sort-algorithm {
  local algorithm=$1
  local i
  for ((i=0;i<100;i++)); do
    fill-rand
    eval "$algorithm"
    prev=${data[0]}
    for v in "${data[@]}"; do
      ((prev<=v)) || return 1
      prev=$v
    done
  done
}

#check-sort-algorithm sort.qsort1 || echo failed
#check-sort-algorithm sort.qsort3 || echo failed

#------------------------------------------------------------------------------
# swap の速度
#
#   長さ2の配列の swap は data=(...) の方が速い
#   長さ2の配列の swap は t=${data[0]} data[0]=${data[1]} data[1]=$t の方が速い
#

# data=(4321 1324)
# ble-measure 'local t=${data[0]}; data[0]=${data[1]}; data[1]=$t' # 5.88u(chat)
# ble-measure 'data=("${data[1]}" "${data[0]}")' # 4.88u(chat)

# data=(4321 123 1324)
# ble-measure 'local t=${data[0]}; data[0]=${data[2]}; data[2]=$t' # 5.88u(chat)
# ble-measure 'data=("${data[2]}" "${data[1]}" "${data[0]}")' # 4.88u(chat)
