#!/bin/bash

if ! type ble/util/print &>/dev/null; then
  function ble/util/unlocal { builtin unset -v "$@"; }
  function ble/util/print { builtin printf '%s\n' "$1"; }
  function ble/util/print-lines { builtin printf '%s\n' "$@"; }
fi

function ble-measure/.loop {
  builtin eval "function _target { ${2:+$2; }return 0; }"
  local _i _n=$1
  for ((_i=0;_i<_n;_i++)); do
    _target
  done
}

## @fn ble-measure/.time command
##   @var[in]  n
##   @var[out] utot
##     計測にかかった総時間を返します。
##   @var[out] usec
##     1評価当たりの時間を返します。
if [[ ${ZSH_VERSION-} ]]; then
  _ble_measure_resolution=1000 # [usec]
  function ble-measure/.time {
    local result
    result=$({ time ( ble-measure/.loop "$n" "$1" ; ) } 2>&1 )
    #local result=$({ time ( ble-measure/.loop "$n" "$1" &>/dev/null); } 2>&1)
    result=${result##*cpu }
    local rex='(([0-9]+):)?([0-9]+)\.([0-9]+) total$'
    if [[ $result =~ $rex ]]; then
      if [[ -o KSH_ARRAYS ]]; then
        local m=${match[1]} s=${match[2]} ms=${match[3]}
      else
        local m=${match[1]} s=${match[2]} ms=${match[3]}
      fi
      m=${m:-0} ms=${ms}000; ms=${ms:0:3}
     
      ((utot=((10#0$m*60+10#0$s)*1000+10#0$ms)*1000,
        usec=utot/n))
      return 0
    else
      builtin echo "ble-measure: failed to read the result of \`time': $result." >&2
      utot=0 usec=0
      return 1
    fi
  }
elif ((BASH_VERSINFO[0]>=5)); then
  _ble_measure_resolution=1 # [usec]
  function ble-measure/.get-realtime {
    local LC_ALL= LC_NUMERIC=C
    time=$EPOCHREALTIME
  }
  function ble-measure/.time {
    local command=$1
    local time
    ble-measure/.get-realtime 2>/dev/null; local time1=${time//.}
    ble-measure/.loop "$n" "$command" &>/dev/null
    ble-measure/.get-realtime 2>/dev/null; local time2=${time//.}
    ((utot=time2-time1,usec=utot/n))
    ((utot>0))
  }
else
  _ble_measure_resolution=1000 # [usec]
  function ble-measure/.time {
    utot=0 usec=0

    local result TIMEFORMAT='[%R]' command=$1
    if declare -f ble/util/assign &>/dev/null; then
      ble/util/assign result '{ time ble-measure/.loop "$n" "$command" &>/dev/null;} 2>&1'
    else
      result=$({ time ble-measure/.loop "$n" "$1" &>/dev/null;} 2>&1)
    fi

    local rex='\[([0-9]+)(\.([0-9]+))?\]'
    [[ $result =~  $rex ]] || return 1
    local s=${BASH_REMATCH[1]}
    local ms=${BASH_REMATCH[3]}000; ms=${ms::3}
    ((utot=(10#0$s*1000+10#0$ms)*1000,usec=utot1/n))
    return 0
  }
fi

_ble_measure_base= # [nsec]
_ble_measure_base_real=()
_ble_measure_base_nestcost=0 # [nsec/10]
_ble_measure_count=1 # 同じ倍率で _ble_measure_count 回計測して最小を取る。
_ble_measure_threshold=100000 # 一回の計測が threshold [usec] 以上になるようにする

## @fn ble-measure/calibrate
function ble-measure/calibrate.0 { ble-measure -qc"$calibrate_count" ''; }
function ble-measure/calibrate.1 { ble-measure/calibrate.0; }
function ble-measure/calibrate.2 { ble-measure/calibrate.1; }
function ble-measure/calibrate.3 { ble-measure/calibrate.2; }
function ble-measure/calibrate.4 { ble-measure/calibrate.3; }
function ble-measure/calibrate.5 { ble-measure/calibrate.4; }
function ble-measure/calibrate.6 { ble-measure/calibrate.5; }
function ble-measure/calibrate.7 { ble-measure/calibrate.6; }
function ble-measure/calibrate.8 { ble-measure/calibrate.7; }
function ble-measure/calibrate.9 { ble-measure/calibrate.8; }
function ble-measure/calibrate.A { ble-measure/calibrate.9; }
function ble-measure/calibrate {
  local ret nsec

  local calibrate_count=1
  _ble_measure_base=0
  _ble_measure_base_nestcost=0

  # nest0: calibrate.0 の ble-measure 内部での ${#FUNCNAME[*]}
  local nest0=$((${#FUNCNAME[@]}+2))
  ble-measure/calibrate.0; local x0=$nsec
  ble-measure/calibrate.A; local xA=$nsec
  local nest_cost=$((xA-x0))
  _ble_measure_base=$((x0-nest_cost*nest0/10))
  _ble_measure_base_nestcost=$nest_cost
}
function ble-measure/fit {
  local ret nsec
  _ble_measure_base=0
  _ble_measure_base_nestcost=0

  local calibrate_count=10

  local c nest_level=${#FUNCNAME[@]}
  for c in {0..9} A; do
    "ble-measure/calibrate.$c"
    ble/util/print "$((nest_level++)) $nsec"
  done > ble-measure-fit.txt

  gnuplot - <<EOF
f(x) = a * x + b
b=4500;a=100
fit f(x) 'ble-measure-fit.txt' via a,b
EOF
}

## @fn ble-measure/.read-arguments.get-optarg
##   @var[in,out] args iarg arg i c
function ble-measure/.read-arguments.get-optarg {
  if ((i+1<${#arg})); then
    optarg=${arg:i+1}
    i=${#arg}
    return 0
  elif ((iarg<${#args[@]})); then
    optarg=${args[iarg++]}
    return 0
  else
    ble/util/print "ble-measure: missing option argument for '-$c'."
    flags=E$flags
    return 1
  fi
}

## @fn ble-measure/.read-arguments args
##   @var[out] flags
##   @var[out] command count
function ble-measure/.read-arguments {
  local -a args; args=("$@")
  local iarg=0 optarg=
  while [[ ${args[iarg]} == -* ]]; do
    local arg=${args[iarg++]}
    case $arg in
    (--) break ;;
    (--help) flags=h$flags ;;
    (--*)
      ble/util/print "ble-measure: unrecognized option '$arg'."
      flags=E$flags ;;
    (-?*)
      local i c
      for ((i=1;i<${#arg};i++)); do
        c=${arg:i:1}
        case $c in
        (q) flags=q$flags ;;
        ([ca])
          [[ $c == a ]] && flags=a$flags
          ble-measure/.read-arguments.get-optarg && count=$optarg ;;
        (T)
          ble-measure/.read-arguments.get-optarg &&
            measure_threshold=$optarg ;;
        (B)
          ble-measure/.read-arguments.get-optarg &&
            __base=$optarg ;;
        (*)
          ble/util/print "ble-measure: unrecognized option '-$c'."
          flags=E$flags ;;
        esac
      done ;;
    (-)
      ble/util/print "ble-measure: unrecognized option '$arg'."
      flags=E$flags ;;
    esac
  done
  local IFS=$' \t\n'
  command="${args[*]:iarg}"
  [[ $flags != *E* ]]
}

## @fn ble-measure [-q|-ac COUNT] command
##   command を繰り返し実行する事によりその実行時間を計測します。
##   -q を指定した時、計測結果を出力しません。
##   -c COUNT を指定した時 COUNT 回計測して最小値を採用します。
##   -a COUNT を指定した時 COUNT 回計測して平均値を採用します。
##
##   @var[out] ret
##     実行時間を usec 単位で返します。
##   @var[out] nsec
##     実行時間を nsec 単位で返します。
function ble-measure {
  local __level=${#FUNCNAME[@]} __base=
  local flags= command= count=$_ble_measure_count
  local measure_threshold=$_ble_measure_threshold
  ble-measure/.read-arguments "$@" || return "$?"
  if [[ $flags == *h* ]]; then
    ble/util/print-lines \
      'usage: ble-measure [-q|-ac COUNT|-TB TIME] [--] COMMAND' \
      '    Measure the time of command.' \
      '' \
      '  Options:' \
      '    -q        Do not print results to stdout.' \
      '    -a COUNT  Measure COUNT times and average.' \
      '    -c COUNT  Measure COUNT times and take minimum.' \
      '    -T TIME   Set minimal measuring time.' \
      '    -B BASE   Set base time (overhead of ble-measure).' \
      '    --        The rest arguments are treated as command.' \
      '    --help    Print this help.' \
      '' \
      '  Arguments:' \
      '    COMMAND   Command to be executed repeatedly.' \
      '' \
      '  Exit status:' \
      '    Returns 1 for the failure in measuring the time.  Returns 2 after printing' \
      '    help.  Otherwise, returns 0.'
    return 2
  fi

  if [[ ! $__base ]]; then
    if [[ $_ble_measure_base ]]; then
      # ble-measure/calibrate 実行済みの時
      __base=$((_ble_measure_base+_ble_measure_base_nestcost*__level/10))
    else
      # それ以外の時は __level 毎に計測
      if [[ ! $ble_measure_calibrate && ! ${_ble_measure_base[__level]} ]]; then
        if [[ ! ${_ble_measure_base_real[__level+1]} ]]; then
          local ble_measure_calibrate=1
          local a; ble-measure -qc3 -B 0 ''
          ble/util/unlocal ble_measure_calibrate a
          _ble_measure_base_real[__level+1]=$nsec
          _ble_measure_base[__level+1]=$nsec
        fi

        # linear-fit result in chatoyancy
        #   65.9818 pm 2.945 (4.463%)
        #   4356.75 pm 19.97 (0.4585%)
        local A=6598 B=435675
        nsec=${_ble_measure_base_real[__level+1]}
        _ble_measure_base[__level]=$((nsec*(B+A*(__level-1))/(B+A*__level)))
        ble/util/unlocal A B
      fi
      __base=${_ble_measure_base[__level]:-0}
    fi
  fi

  local prev_n= prev_utot=
  local -i n
  for n in {1,10,100,1000,10000}\*{1,2,5}; do
    [[ $prev_n ]] && ((n/prev_n<=10 && prev_utot*n/prev_n<measure_threshold*2/5 && n!=50000)) && continue

    local utot=0 usec=0
    [[ $flags != *q* ]] && printf '%s (x%d)...' "$command" "$n" >&2
    ble-measure/.time "$command" || return 1
    [[ $flags != *q* ]] && printf '\r\e[2K' >&2
    ((utot >= measure_threshold)) || continue

    prev_n=$n prev_utot=$utot
    local min_utot=$utot

    # 繰り返し計測して最小値 (-a の時は平均値) を採用
    if [[ $count ]]; then
      local sum_utot=$utot sum_count=1 i
      for ((i=2;i<=count;i++)); do
        [[ $flags != *q* ]] && printf '%s' "$command (x$n $i/$count)..." >&2
        if ble-measure/.time "$command"; then
          ((utot<min_utot)) && min_utot=$utot
          ((sum_utot+=utot,sum_count++))
        fi
        [[ $flags != *q* ]] && printf '\r\e[2K' >&2
      done
      if [[ $flags == *a* ]]; then
        ((utot=sum_utot/sum_count))
      else
        utot=$min_utot
      fi
    fi

    # upate base if the result is shorter than base
    if ((min_utot<0x7FFFFFFFFFFFFFFF/1000)); then
      local __real=$((min_utot*1000/n))
      [[ ${_ble_measure_base_real[__level]} ]] &&
        ((__real<_ble_measure_base_real[__level])) &&
        _ble_measure_base_real[__level]=$__real
      [[ ${_ble_measure_base[__level]} ]] &&
        ((__real<_ble_measure_base[__level])) &&
        _ble_measure_base[__level]=$__real
      ((__real<__base)) &&
        __base=$__real
    fi

    local nsec0=$__base
    if [[ $flags != *q* ]]; then
      local reso=$_ble_measure_resolution
      local awk=ble/bin/awk
      type "$awk" &>/dev/null || awk=awk
      "$awk" -v utot=$utot -v nsec0=$nsec0 -v n=$n -v reso=$reso -v title="$command (x$n)" \
             ' function genround(x, mod) { return int(x / mod + 0.5) * mod; }
          BEGIN { printf("%12.3f usec/eval: %s\n", genround(utot / n - nsec0 / 1000, reso / 10.0 / n), title); exit }'
    fi
    ((ret=utot/n))
    if ((n>=1000)); then
      ((nsec=utot/(n/1000)))
    else
      ((nsec=utot*1000/n))
    fi
    ((ret-=nsec0/1000,nsec-=nsec0))
    return 0
  done
}
