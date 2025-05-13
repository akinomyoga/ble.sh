#!/usr/bin/env bash

[[ ${BLE_VERSION-} ]] || source out/ble.sh --lib

a001k=({1..1000})
a010k=({1..10000})
a100k=({1..100000})

function ble/array#fill-range.0a {
  local _ble_array_fill_range=$(($3-$2))
  local _ble_local_script='
    while ((--_ble_array_fill_range>=0)); do
      NAME[$2+_ble_array_fill_range]=$4
    done'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#fill-range.0b {
  local _ble_array_fill_range=$(($3-$2))
  local _ble_local_script='
    for ((;_ble_array_fill_range;_ble_array_fill_range--)); do
      NAME[$3-_ble_array_fill_range]=$4
    done'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#fill-range.0c {
  local _ble_array_fill_range
  _ble_array_fill_range[0]=$2
  _ble_array_fill_range[1]=$3
  local _ble_local_script='
    while ((_ble_array_fill_range<_ble_array_fill_range[1])); do
      NAME[_ble_array_fill_range++]=$4
    done'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#fill-range.0d {
  local _ble_local_script='
    local iNAME=$2
    while ((iNAME<'"$(($3))"')); do NAME[iNAME++]=$4; done'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#fill-range.1 {
  local _ble_array_fill_range=$(($3-$2))
  ble/array#reserve-prototype "$_ble_array_fill_range"
  _ble_array_fill_range=("${_ble_array_prototype[@]::$3-$2}")
  ble/array#map-prefix _ble_array_fill_range "$4"

  local _ble_local_script='
    NAME=("${NAME[@]::$2}" "${_ble_array_fill_range[@]}" "${NAME[@]:$3}")'
  builtin eval -- "${_ble_local_script//NAME/$1}"
}
function ble/array#fill-range.2a {
  local _ble_array_fill_range
  _ble_array_fill_range[0]=$(($2))
  _ble_array_fill_range[1]=$(($3-1))
  ((_ble_array_fill_range[0]<=_ble_array_fill_range[1])) || return 0
  if ((_ble_array_fill_range[0]==_ble_array_fill_range[1])); then
    local _ble_local_script='NAME['"${_ble_array_fill_range}"']=$4'
  else
    local _ble_local_script='local iNAME; for iNAME in {'"${_ble_array_fill_range}"'..'"${_ble_array_fill_range[1]}"'}; do NAME[iNAME]=$4; done'
  fi
  builtin eval -- "${_ble_local_script//NAME/$1}"
}

#for arr in a001k a010k a100k; do
for arr in a001k a010k; do
  builtin eval -- "arrlen=\${#$arr[@]}"
  echo "== $arr (# = $arrlen) =="
  for count in 100 200 500 1000 2000 5000 10000 20000 50000; do
    ((count < arrlen)) || continue
    # (ble-measure "ble/array#fill-range.0a $arr 2352 $((2352+count)) \$RANDOM")
    # (ble-measure "ble/array#fill-range.0b $arr 2352 $((2352+count)) \$RANDOM")
    # (ble-measure "ble/array#fill-range.0c $arr 2352 $((2352+count)) \$RANDOM")
    # (ble-measure "ble/array#fill-range.1  $arr 2352 $((2352+count)) \$RANDOM")
    (ble-measure "ble/array#fill-range.0d $arr 2352 $((2352+count)) \$RANDOM")
    (ble-measure "ble/array#fill-range.2a $arr 2352 $((2352+count)) \$RANDOM")
  done
done

# Conclusion: 0d seems to perform the best in general. In some cases with a
# large rewriting, 2a can be slightly faster, but it still seems to be within
# the fluctuations.
