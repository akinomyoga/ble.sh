#!/bin/bash

#%define 1
#%if target == "ksh"
#%% $ echo _ble_measure_target=ksh
#%end
if ! type ble/util/print &>/dev/null; then
  function ble/util/unlocal { builtin unset -v "$@"; }
  function ble/util/print { builtin printf '%s\n' "$1"; }
  function ble/util/print-lines { builtin printf '%s\n' "$@"; }
fi

function ble-measure/.loop {
  # Note: ksh requires to quote ;
  builtin eval "function _target { ${2:+"$2; "}return 0; }"
  local __ble_i __ble_n=$1
  for ((__ble_i=0;__ble_i<__ble_n;__ble_i++)); do
    _target
  done
}

## @fn ble-measure/.time n command
##   @param[in] n command
##   @var[out] ret
##     計測にかかった総時間を μs 単位で返します。
if ((BASH_VERSINFO[0]>=5)) ||
     { [[ ${ZSH_VERSION-} ]] && zmodload zsh/datetime &>/dev/null && [[ ${EPOCHREALTIME-} ]]; } ||
     [[ ${SECONDS-} == *.??? ]]
then
  ## @fn ble-measure/.get-realtime
  ##   @var[out] ret
  if [[ ${EPOCHREALTIME-} ]]; then
    _ble_measure_resolution=1 # [usec]
    function ble-measure/.get-realtime {
      local LC_ALL= LC_NUMERIC=C
      ret=$EPOCHREALTIME
    }
  else
    # Note: ksh does not have "local"-equivalent for the POSIX-style functions,
    #   so we do not set the locale here.  Anyway, we do not care the
    #   interference with outer-scope variables since this script is used
    #   limitedly in ksh.
    _ble_measure_resolution=1000 # [usec]
    function ble-measure/.get-realtime {
      ret=$SECONDS
    }
  fi
  function ble-measure/.time {
    ble-measure/.get-realtime 2>/dev/null; local __ble_time1=$ret
    ble-measure/.loop "$1" "$2" &>/dev/null
    ble-measure/.get-realtime 2>/dev/null; local __ble_time2=$ret

    # convert __ble_time1 and __ble_time2 to usec
    # Note: ksh does not support empty index as ${__ble_frac::6}.
    local __ble_frac
    [[ $__ble_time1 == *.* ]] || __ble_time1=${__ble_time1}.
    __ble_frac=${__ble_time1##*.}000000 __ble_time1=${__ble_time1%%.*}${__ble_frac:0:6}
    [[ $__ble_time2 == *.* ]] || __ble_time2=${__ble_time2}.
    __ble_frac=${__ble_time2##*.}000000 __ble_time2=${__ble_time2%%.*}${__ble_frac:0:6}

    ((ret=__ble_time2-__ble_time1))
    ((ret==0&&(ret=_ble_measure_resolution)))
    ((ret>0))
  }
elif [[ ${ZSH_VERSION-} ]]; then
  _ble_measure_resolution=1000 # [usec]
#%if target == "ksh"
  # [ksh incompatible code stripped]
#%else
  function ble-measure/.time {
    local result=
    result=$({ time ( ble-measure/.loop "$1" "$2" ; ) } 2>&1 )
    #local result=$({ time ( ble-measure/.loop "$1" "$2" &>/dev/null); } 2>&1)
    result=${result##*cpu }
    local rex='(([0-9]+):)?([0-9]+)\.([0-9]+) total$'
    if [[ $result =~ $rex ]]; then
      if [[ -o KSH_ARRAYS ]]; then
        local m=${match[1]} s=${match[2]} ms=${match[3]}
      else
        local m=${match[2]} s=${match[3]} ms=${match[4]}
      fi
      m=${m:-0} ms=${ms}000; ms=${ms:0:3}

      ((ret=((10#0$m*60+10#0$s)*1000+10#0$ms)*1000))
      return 0
    else
      builtin echo "ble-measure: failed to read the result of \`time': $result." >&2
      ret=0
      return 1
    fi
  }
#%end
else
  _ble_measure_resolution=1000 # [usec]
#%if target == "ksh"
  # [ksh incompatible code stripped]
#%else
  function ble-measure/.time {
    ret=0

    local result TIMEFORMAT='[%R]' __ble_n=$1 __ble_command=$2
    if declare -f ble/util/assign &>/dev/null; then
      ble/util/assign result '{ time ble-measure/.loop "$__ble_n" "$__ble_command" &>/dev/null;} 2>&1'
    else
      result=$({ time ble-measure/.loop "$1" "$2" &>/dev/null;} 2>&1)
    fi

    local rex='\[([0-9]+)(\.([0-9]+))?\]'
    [[ $result =~  $rex ]] || return 1
    local s=${BASH_REMATCH[1]}
    local ms=${BASH_REMATCH[3]}000; ms=${ms::3}
    ((ret=(10#0$s*1000+10#0$ms)*1000))
    return 0
  }
#%end
fi

_ble_measure_base= # [nsec]
_ble_measure_base_nestcost=0 # [nsec/10]
#%if target == "ksh"
#%% $ echo typeset -a _ble_measure_base_real
#%% $ echo typeset -a _ble_measure_base_guess
#%else
_ble_measure_base_real=()
_ble_measure_base_guess=()
#%end
_ble_measure_count=1 # 同じ倍率で _ble_measure_count 回計測して最小を取る。
_ble_measure_threshold=100000 # 一回の計測が threshold [usec] 以上になるようにする

#%if target != "ksh"
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
  local ret= nsec=

  local calibrate_count=1
  _ble_measure_base=0
  _ble_measure_base_nestcost=0

  # nest0: calibrate.0 の ble-measure 内部での ${#FUNCNAME[*]}
  local nest0=$((${#FUNCNAME[@]}+2))
  [[ ${ZSH_VERSION-} ]] && nest0=$((${#funcstack[@]}+2))
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

  local c= nest_level=${#FUNCNAME[@]}
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
#%end

## @fn ble-measure/.read-arguments.get-optarg
##   @var[in] args arg i c
##   @var[in,out] iarg
##   @var[out] optarg
function ble-measure/.read-arguments.get-optarg {
  if ((i+1<${#arg})); then
    optarg=${arg:$((i+1))}
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
  [[ ${ZSH_VERSION-} && ! -o KSH_ARRAYS ]] && iarg=1
  while [[ ${args[iarg]} == -* ]]; do
    local arg=${args[iarg++]}
    case $arg in
    (--) break ;;
    (--help) flags=h$flags ;;
    (--no-print-progress) flags=V$flags ;;
    (--*)
      ble/util/print "ble-measure: unrecognized option '$arg'."
      flags=E$flags ;;
    (-?*)
      local i= c= # Note: zsh prints the values with just "local i c"
      for ((i=1;i<${#arg};i++)); do
        c=${arg:$i:1}
        case $c in
        (q) flags=qV$flags ;;
        ([ca])
          [[ $c == a ]] && flags=a$flags
          ble-measure/.read-arguments.get-optarg && count=$optarg ;;
        (T)
          ble-measure/.read-arguments.get-optarg &&
            measure_threshold=$optarg ;;
        (B)
          ble-measure/.read-arguments.get-optarg &&
            __ble_base=$optarg ;;
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
  if [[ ${ZSH_VERSION-} ]]; then
    command="${args[$iarg,-1]}"
  else
    command="${args[*]:$iarg}"
  fi
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
  local __ble_level=${#FUNCNAME[@]} __ble_base=
  [[ ${ZSH_VERSION-} ]] && __ble_level=${#funcstack[@]}
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

  if [[ ! $__ble_base ]]; then
    if [[ $_ble_measure_base ]]; then
      # ble-measure/calibrate 実行済みの時
      __ble_base=$((_ble_measure_base+_ble_measure_base_nestcost*__ble_level/10))
    else
      # それ以外の時は __ble_level 毎に計測
      if [[ ! $ble_measure_calibrate && ! ${_ble_measure_base_guess[__ble_level]} ]]; then
        if [[ ! ${_ble_measure_base_real[__ble_level+1]} ]]; then
          if [[ ${_ble_measure_target-} == ksh ]]; then
            # Note: In ksh, we cannot do recursive call with dynamic scoping,
            # so we directly call the measuring function
            ble-measure/.time 50000 ''
            ((nsec=ret*1000/50000))
          else
            local ble_measure_calibrate=1
            ble-measure -qc3 -B 0 ''
            ble/util/unlocal ble_measure_calibrate
          fi
          _ble_measure_base_real[__ble_level+1]=$nsec
          _ble_measure_base_guess[__ble_level+1]=$nsec
        fi

        # 上の実測値は一つ上のレベル (__ble_level+1) での結果になるので現在のレベル
        # (__ble_level) の値に補正する。レベル毎の時間が chatoyancy での線形フィッ
        # トの結果に比例する仮定して補正を行う。
        #
        # linear-fit result with $f(x) = A x + B$ in chatoyancy
        #   A = 65.9818 pm 2.945 (4.463%)
        #   B = 4356.75 pm 19.97 (0.4585%)
        local cA=6598 cB=435675
        nsec=${_ble_measure_base_real[__ble_level+1]}
        _ble_measure_base_guess[__ble_level]=$((nsec*(cB+cA*(__ble_level-1))/(cB+cA*__ble_level)))
        ble/util/unlocal cA cB
      fi
      __ble_base=${_ble_measure_base_guess[__ble_level]:-0}
    fi
  fi

  local __ble_max_n=500000
  local prev_n= prev_utot=
  local -i n
  for n in {1,10,100,1000,10000,100000}\*{1,2,5}; do
    [[ $prev_n ]] && ((n/prev_n<=10 && prev_utot*n/prev_n<measure_threshold*2/5 && n!=50000)) && continue

    local utot=0
    [[ $flags != *V* ]] && printf '%s (x%d)...' "$command" "$n" >&2
    ble-measure/.time "$n" "$command" || return 1
    [[ $flags != *V* ]] && printf '\r\e[2K' >&2
    ((utot=ret,utot>=measure_threshold||n==__ble_max_n)) || continue

    prev_n=$n prev_utot=$utot
    local min_utot=$utot

    # 繰り返し計測して最小値 (-a の時は平均値) を採用
    if [[ $count ]]; then
      local sum_utot=$utot sum_count=1 i
      for ((i=2;i<=count;i++)); do
        [[ $flags != *V* ]] && printf '%s' "$command (x$n $i/$count)..." >&2
        if ble-measure/.time "$n" "$command"; then
          ((utot=ret,utot<min_utot)) && min_utot=$utot
          ((sum_utot+=utot,sum_count++))
        fi
        [[ $flags != *V* ]] && printf '\r\e[2K' >&2
      done
      if [[ $flags == *a* ]]; then
        ((utot=sum_utot/sum_count))
      else
        utot=$min_utot
      fi
    fi

    # upate base if the result is shorter than base
    if ((min_utot<0x7FFFFFFFFFFFFFFF/1000)); then
      local __ble_real=$((min_utot*1000/n))
      [[ ${_ble_measure_base_real[__ble_level]} ]] &&
        ((__ble_real<_ble_measure_base_real[__ble_level])) &&
        _ble_measure_base_real[__ble_level]=$__ble_real
      [[ ${_ble_measure_base_guess[__ble_level]} ]] &&
        ((__ble_real<_ble_measure_base_guess[__ble_level])) &&
        _ble_measure_base_guess[__ble_level]=$__ble_real
      ((__ble_real<__ble_base)) &&
        __ble_base=$__ble_real
    fi

    local nsec0=$__ble_base
    if [[ $flags != *q* ]]; then
      local reso=$_ble_measure_resolution
      local awk=ble/bin/awk
      type "$awk" &>/dev/null || awk=awk
      local -x title="$command (x$n)"
      "$awk" -v utot="$utot" -v nsec0="$nsec0" -v n="$n" -v reso="$reso" '
        function genround(x, mod) { return int(x / mod + 0.5) * mod; }
        BEGIN { title = ENVIRON["title"]; printf("%12.3f usec/eval: %s\n", genround(utot / n - nsec0 / 1000, reso / 10.0 / n), title); exit }'
    fi

    local out
    ((out=utot/n))
    if ((n>=1000)); then
      ((nsec=utot/(n/1000)))
    else
      ((nsec=utot*1000/n))
    fi
    ((out-=nsec0/1000,nsec-=nsec0))
    ret=$out
    return 0
  done
}
#%end
#%if target == "ksh"
#%% # varname and command names
#%% define 1 1.r|builtin ||
#%% define 1 1.r| local | typeset |
#%% define 1 1.r|ble_measure_calibrate|_ble_measure_calibrate|
#%% # function names
#%% define 1 1.r|ble/util/unlocal|_ble_util_unlocal|
#%% define 1 1.r|ble/util/print-lines|_ble_util_print_lines|
#%% define 1 1.r|ble/util/print|_ble_util_print|
#%% define 1 1.r|ble-measure/.loop|_ble_measure__loop|
#%% define 1 1.r|ble-measure/.get-realtime|_ble_measure__get_realtime|
#%% define 1 1.r|ble-measure/.time|_ble_measure__time|
#%% define 1 1.r|ble-measure/.read-arguments.get-optarg|_ble_measure__read_arguments_get_optarg|
#%% define 1 1.r|ble-measure/.read-arguments|_ble_measure__read_arguments|
#%% define 1 1.r|ble-measure|ble_measure|
#%% # function defs
#%% define 1 1.r|function _ble_measure__time|_ble_measure__time()|
#%% define 1 1.r|function _ble_measure__get_realtime|_ble_measure__get_realtime()|
#%% define 1 1.r|function _ble_util_unlocal|_ble_util_unlocal()|
#%% define 1 1.r|function _ble_measure__read_arguments_get_optarg|_ble_measure__read_arguments_get_optarg()|
#%% define 1 1.r|function _ble_measure__read_arguments|_ble_measure__read_arguments()|
#%% define 1 1.r|function ble_measure|ble_measure()|
#%end
#%expand 1
