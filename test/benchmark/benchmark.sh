#!/bin/bash

function ble-measure/.loop {
  eval "function _target { $2; }"
  local _i _n="$1"
  for ((_i=0;_i<_n;_i++)); do
    _target
  done
}

if [[ $ZSH_VERSION ]]; then
  function ble-measure/.time {
    local result
    result=$({ time ( ble-measure/.loop "$n" "$*" ; ) } 2>&1 )
    #local result=$({ time ( ble-measure/.loop "$n" "$*" &>/dev/null); } 2>&1)
    result="${result##*cpu }"
    local rex='(([0-9]+):)?([0-9]+)\.([0-9]+) total$'
    if [[ $result =~ $rex ]]; then
      if [[ -o KSH_ARRAYS ]]; then
        local m="${match[1]}" s="${match[2]}" ms="${match[3]}"
      else
        local m="${match[1]}" s="${match[2]}" ms="${match[3]}"
      fi
      m="${m:-0}" ms="${ms}000"; ms="${ms:0:3}"
     
      ((utot=((10#$m*60+10#$s)*1000+10#$ms)*1000,
        usec=utot/n))
      return 0
    else
      echo "ble-measure: failed to read the result of \`time': $result." >&2
      utot=0 usec=0
      return 1
    fi
  }
else
  ## @fn ble-measure/.time command
  ##   @var[in]  n
  ##   @var[out] utot usec
  function ble-measure/.time {
    utot=0 usec=0
    local word utot1 usec1
    local head=
    for word in $({ time ble-measure/.loop "$n" "$*" &>/dev/null;} 2>&1); do
      local rex='(([0-9])+m)?([0-9]+)(\.([0-9]+))?s'
      if [[ $word =~  $rex ]]; then
        local m=${BASH_REMATCH[2]}
        local s=${BASH_REMATCH[3]}
        local ms=${BASH_REMATCH[5]}000; ms=${ms::3}
        
        ((utot1=((10#$m*60+10#$s)*1000+10#$ms)*1000,
          usec1=utot1/n))
        # printf '  %-5s%9dus/op\n' "$head" "$usec1"
        (((utot1>utot)&&(utot=utot1),
          (usec1>usec)&&(usec=usec1)))
        head=
      else
        head="$head$word "
      fi
    done

    [[ $utot1 ]]
  }
fi

_ble_measure_base=
_ble_measure_time=1 # 同じ倍率で _ble_measure_time 回計測して最小を取る。
_ble_measure_threshold=100000 # 一回の計測が threshold [usec] 以上になるようにする

## @var[out] ret nsec
function ble-measure {
  local TIMEFORMAT=
  if [[ ! $_ble_measure_base ]]; then
    _ble_measure_base=0 nsec=0
    # : よりも a=1 の方が速い様だ
    ble-measure a=1 &>/dev/null
    _ble_measure_base="$nsec"
  fi

  local prev_n= prev_utot=
  local -i n
  for n in {1,10,100,1000,10000}\*{1,2,5}; do
    [[ $prev_n ]] && ((n/prev_n <= 10 && prev_utot*n/prev_n < _ble_measure_threshold*2/5 && n != 50000)) && continue

    local utot=0 usec=0
    printf '%s (x%d)...' "$*" "$n" >&2
    ble-measure/.time "$*" || return 1
    printf '\r\e[2K' >&2

    prev_n=$n prev_utot=$utot

    ((utot >= _ble_measure_threshold)) || continue

    # 繰り返し計測して最小値を採用
    if [[ $_ble_measure_time ]]; then
      local min_utot=$utot i
      for ((i=2;i<=_ble_measure_time;i++)); do
        printf '%s' "$* (x$n $i/$_ble_measure_time)..." >&2
        ble-measure/.time "$*" && ((utot<min_utot)) && min_utot=$utot
        printf '\r\e[2K' >&2
      done
      utot=$min_utot
    fi
        
    local nsec0=$_ble_measure_base
    local awk=ble/bin/awk
    type "$awk" &>/dev/null || awk=awk
    "$awk" -v utot=$utot -v nsec0=$nsec0 -v n=$n -v title="$* (x$n)" \
        ' function genround(x, mod) { return int(x / mod + 0.5) * mod; }
            BEGIN { printf("%12.2f usec/eval: %s\n", genround(utot / n - nsec0 / 1000, 100 / n), title); exit }'
    ((ret=utot/n))
    if ((n>=1000)); then
      ((nsec=utot/(n/1000)))
    else
      ((nsec=utot*1000/n))
    fi
    ((ret-=nsec0/1000,nsec-=nsec0))
    return
  done
}
