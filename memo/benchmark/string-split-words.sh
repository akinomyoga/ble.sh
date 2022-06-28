#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  _ble_term_IFS=$' \t\n'
  source ../../src/benchmark.sh
  _ble_bash_tmout_wa=()
fi

text=$'
echo hello world\x20
echo hello\t\tworld\t

echo hello 11
'

Answer=(echo hello world echo hello world echo hello 11)

function check-split-implementation {
  local ret
  if ! "$1" ret "$text"; then
    ble/util/print "$1: failed (exit: $?)" >&2
    return 1
  fi
  
  if ((${#ret[@]}!=${#Answer[@]})); then
    ble/util/print "$1: the size of array is incorrect" >&2
    return 1
  fi

  local i
  for ((i=0;i<${#Answer[@]};i++)); do
    if [[ ${ret[i]} != "${Answer[i]}" ]]; then
      ble/util/print "$1: the element ret[$i]='${ret[i]}' is incorrect (expect '${Answer[i]}')" >&2
      return 1
    fi
  done
}

# original impl of ble/string#split-words
function split1 {
  if [[ -o noglob ]]; then
    IFS=$_ble_term_IFS builtin eval "$1=(\${*:2})"
  else
    set -f
    IFS=$_ble_term_IFS builtin eval "$1=(\${*:2})"
    set +f
  fi
}
check-split-implementation split1
ble-measure 'split1 ret "$text"'

function split2 {
  builtin eval -- "$1=()"
  builtin read -r -d '' "${_ble_bash_tmout_wa[@]}" -a "$1" <<< "$2"
  return 0
}
check-split-implementation split2
ble-measure 'split2 ret "$text"'

function split3 {
  if [[ -o noglob ]]; then
    IFS=$_ble_term_IFS builtin eval "$1=(\$2)"
  else
    set -f
    IFS=$_ble_term_IFS builtin eval "$1=(\$2)"
    set +f
  fi
}
check-split-implementation split3
ble-measure 'split3 ret "$text"'

function split4 {
  if [[ -o noglob ]]; then
    IFS=$_ble_term_IFS builtin eval "$1"'=($2)'
  else
    set -f
    IFS=$_ble_term_IFS builtin eval "$1"'=($2)'
    set +f
  fi
}
check-split-implementation split4
ble-measure 'split4 ret "$text"'

function split5 {
  local IFS=$_ble_term_IFS
  if [[ -o noglob ]]; then
    builtin eval "$1=(\$2)"
  else
    set -f
    builtin eval "$1=(\$2)"
    set +f
  fi
}
check-split-implementation split5
ble-measure 'split5 ret "$text"'

#        5.2  5.1  5.0  4.4  4.3  4.2  4.1  4.0  3.2  3.1  3.0 
# split1 34.5 32.9 33.5 37.7 33.9 38.0 45.3 44.6 44.1 34.4 31.8
# split2 58.8 58.2 72.7 75.0 74.5 83.8 94.3 93.6 89.1 92.6 90.2
# split3 30.6 30.1 31.1 33.1 31.0 32.0 39.4 38.9 37.6 29.2 27.1 [split1 + only $2] 多少速くなる。
# split4 30.0 30.6 30.8 34.8 30.3 33.2 38.2 38.7 37.1 29.0 26.6 [split3 + change quoting] 一緒に計測すると遅くなる傾向
# split5 21.0 20.7 20.5 22.8 22.9 25.8 31.6 32.1 30.4 31.0 29.9 [split3 + local instead of tempenv] どうも tempenv は遅い様だ。
#
# split5 の実装が最も早いのでこれを採用する。
