#!/bin/bash

source out/data/c2w.eaw-13.0.0.sh
source src/canvas.c2w.sh

function dump {
  local out= i=0
  arr=()
  for ((c=0;c<0x110000;c++)); do
    "$1" "$c"; out="$out $ret"
    if (((c+1)%32==0)); then
      arr[i++]=$out
      out=
    fi
  done
  printf '%s\n' "${arr[@]}"
}

function c2w.binary {
  local c=$1
  ret=${_ble_unicode_EastAsianWidth_c2w[c]}
  [[ $ret ]] && return 0

  local l u m
  ((l=0,u=${#_ble_unicode_EastAsianWidth_c2w_ranges[@]}-1))

  while ((l+1<u)); do
    ((m=(l+u)/2))
    if ((_ble_unicode_EastAsianWidth_c2w_ranges[m]<=c)); then
      l=$m
    else
      u=$m
    fi
  done
  ret=${_ble_unicode_EastAsianWidth_c2w[_ble_unicode_EastAsianWidth_c2w_ranges[l]]}
}

function c2w.bindex {
  local c=$1
  ret=${_ble_unicode_EastAsianWidth_c2w[c]}
  [[ $ret ]] && return 0

  ret=${_ble_unicode_EastAsianWidth_c2w_index[c<0x20000?c>>8:((c>>12)-32+512)]}
  if [[ $ret == *:* ]]; then
    local l=${ret%:*} u=${ret#*:} m
    while ((l+1<u)); do
      ((m=(l+u)/2))
      if ((_ble_unicode_EastAsianWidth_c2w_ranges[m]<=c)); then
        l=$m
      else
        u=$m
      fi
    done
    ret=${_ble_unicode_EastAsianWidth_c2w[_ble_unicode_EastAsianWidth_c2w_ranges[l]]}
  fi
}

function c2w.unified {
  local c=$1
  ret=${_ble_unicode_c2w[c]}
  if [[ ! $ret ]]; then
    ret=${_ble_unicode_c2w_index[c<0x20000?c>>8:((c>>12)-32+512)]}
    if [[ $ret == *:* ]]; then
      local l=${ret%:*} u=${ret#*:} m
      while ((l+1<u)); do
        ((m=(l+u)/2))
        if ((_ble_unicode_c2w_ranges[m]<=c)); then
          l=$m
        else
          u=$m
        fi
      done
      ret=${_ble_unicode_c2w[_ble_unicode_c2w_ranges[l]]}
    fi
  fi
  ret=${_ble_unicode_c2w_UnicodeVersionMapping[ret*_ble_unicode_c2w_UnicodeVersionCount+_ble_unicode_c2w_version]}
}

#time dump c2w.binary > out/data/c2w.eaw-13.0.0.impl1.dump
#time dump c2w.bindex > out/data/c2w.eaw-13.0.0.impl2.dump

ble/unicode/c2w/version2index 13.0
_ble_unicode_c2w_version=$ret
time dump c2w.unified > out/data/c2w.eaw-13.0.0.impl3.dump
