# -*- mode: sh; mode: sh-bash; -*-

#------------------------------------------------------------------------------
# 現在の実装 (51us)
function bisect.0 {
  local c=$1 l=0 u=${#_ble_util_c2w_musl_ranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_musl_ranges[m=(l+u)/2]<=c?(l=m):(u=m)))
  done
  #echo "${_ble_util_c2w_musl_ranges[l]} <= $c < ${_ble_util_c2w_musl_ranges[l+1]}"
  w=${_ble_util_c2w_musl[_ble_util_c2w_musl_ranges[l]]}
}

#------------------------------------------------------------------------------
# ${a[@]:c+1} の残り要素を数える方法 (260us)
function bisect.1 {
  local a c=$1
  a=("${_ble_util_c2w_musl[@]:c+1}")
  ((i=${#_ble_util_c2w_musl[@]}-${#a[@]}-1))
  #echo "${_ble_util_c2w_musl_ranges[i]} <= $c < ${_ble_util_c2w_musl_ranges[i+1]}"
  w=${_ble_util_c2w_musl[_ble_util_c2w_musl_ranges[i]]}
}

#------------------------------------------------------------------------------
# ${a[@]:c+1:1} で見つかる最初の要素に初めから答えを入れておく方法 (64us)
function bisect.2.init {
  _ble_util_c2w_musl_reverse_index=()
  _ble_util_c2w_musl_reverse=()
  local prev=0 i
  for i in "${!_ble_util_c2w_musl[@]}"; do
    _ble_util_c2w_musl_reverse_index[i]=$prev
    _ble_util_c2w_musl_reverse[i]=${_ble_util_c2w_musl[prev]}
    prev=$i
  done
}
bisect.2.init

function bisect.2 {
  #local c=$1
  #local c1=${_ble_util_c2w_musl_reverse_index[*]:c+1:1}
  #echo "$c1 <= $c < ????"
  w=${_ble_util_c2w_musl_reverse[*]:$1+1:1}
}

# 関数呼び出しをスキップすると 58us になる (6us だけ速い)
# ble-measure 'w=${_ble_util_c2w_musl_reverse[*]:6680+1:1}'; echo "w=$w"
# ble-measure 'w=${_ble_util_c2w_musl_reverse[*]:6681+1:1}'; echo "w=$w"
# ble-measure 'w=${_ble_util_c2w_musl_reverse[*]:6682+1:1}'; echo "w=$w"

#------------------------------------------------------------------------------
# 現在の二分探索を完全に算術式にしたもの (45us)

function bisect.3 {
  local c=$1 l=0 u=${#_ble_util_c2w_musl_ranges[@]} m
  local L='_ble_util_c2w_musl_ranges[m=(l+u)/2]<=c?(l=m):(u=m),l+1<u&&L'
  ((l+1<u&&L))
  #echo "${_ble_util_c2w_musl_ranges[l]} <= $c < ${_ble_util_c2w_musl_ranges[l+1]}"
  w=${_ble_util_c2w_musl[_ble_util_c2w_musl_ranges[l]]}
}

#------------------------------------------------------------------------------

ble-measure 'bisect.0 6680'; echo "w=$w"
ble-measure 'bisect.0 6681'; echo "w=$w"
ble-measure 'bisect.0 6682'; echo "w=$w"
ble-measure 'bisect.1 6680'; echo "w=$w"
ble-measure 'bisect.1 6681'; echo "w=$w"
ble-measure 'bisect.1 6682'; echo "w=$w"
ble-measure 'bisect.2 6680'; echo "w=$w"
ble-measure 'bisect.2 6681'; echo "w=$w"
ble-measure 'bisect.2 6682'; echo "w=$w"
ble-measure 'bisect.3 6680'; echo "w=$w"
ble-measure 'bisect.3 6681'; echo "w=$w"
ble-measure 'bisect.3 6682'; echo "w=$w"

# bisect.3 6680
# bisect.3 6681
# bisect.3 6682
