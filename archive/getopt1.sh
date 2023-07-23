#!/bin/bash
# -*- coding:utf-8 -*-

# Usage
#
#   local "${_ble_getopt_vars[@]/%/=}" # WA #D1570 checked
#   ble-getopt-begin "progname" "m:n c:n,n k:n,n" "$@"
#   ble-getopt
#
# ToDo
#
#   * next-argument: appropriate error message
#   * next-argument: negative tests
#   * next-argument: function calls
#   * getopt_index を OPTIND に名前を変える?

_ble_getopt_vars=(
  optargs      # 読み取られたオプション

  getopt_cmd   # 呼出元コマンド名
  getopt_odefs # オプション定義
  getopt_args  # コマンド引数
  getopt_len   # コマンド引数の数
  getopt_index # 現在のコマンド引数の位置 OPTIND

  getopt_opt   # 解析中オプション
  getopt_oarg  # オプション引数
  getopt_olen  # オプション引数の数
  getopt_oind  # オプション引数の現在位置
)

function .ble-getopt.next-argument {
  local type=$1 oarg
  if ((getopt_oind<getopt_olen)); then
    oarg=${getopt_oarg[getopt_oind++]}
  elif ((getopt_index<getopt_len)); then
    oarg=${getopt_args[getopt_index++]}
  else
    if [[ $type == '?'* ]]; then
      oarg=${type:1}
      [[ ! $oarg ]] && return 0
    else
      ble/util/print "$getopt_cmd: missing an argument of the option \`${optargs[0]}'." 1>&2
      return 1
    fi
  fi

  # check
  case $type in
  [nefdhcbpugkrwxsv])
    if [ ! -$type "$oarg" ]; then
      ble/util/print "$getopt_cmd: the argument of the option \`${optargs[0]}' is empty string (oarg=$oarg)." 1>&2
      return 1
    fi ;;
  esac

  optargs[${#optargs[@]}]=$oarg
}

function .ble-getopt.process-option {
  local name=$1
  optargs=("$name")

  # search the option definition
  local i f_found adef
  for ((i=0;i<${#getopt_odefs[@]};i++)); do
    if [[ $name == "${getopt_odefs[$i]%%:*}" ]]; then
      f_found=1
      ble/string#split adef : "${getopt_odefs[i]}"
      break
    fi
  done

  # unknown option
  if [[ ! $f_found ]]; then
    if [[ $f_longname ]]; then
      ble/util/print "an unknown long-name option \`--$name'" 1>&2
    else
      ble/util/print "an unknown option \`-$name'" 1>&2
    fi
    return 1
  fi

  for ((i=1;i<${#adef[@]};i++)); do
    .ble-getopt.next-argument "${adef[$i]}" || return 1
  done
}

function ble-getopt-begin {
  ble/string#split-words getopt_cmd "$1"
  ble/string#split-words getopt_odefs "$2"
  shift 2
  getopt_args=("$@")
  getopt_len=${#getopt_args[@]}
  getopt_index=0

  getopt_opt=
  getopt_olen=0
  getopt_oind=0

  optargs=()
}

function .ble-getopt.check-oarg-processed {
  if ((getopt_oind<getopt_olen)); then
    ble/util/print "$getopt_cmd: an option argument not processed (oarg=${getopt_oarg[$getopt_oind]})." 1>&2
    getopt_oind=0
    getopt_olen=0
    builtin unset -v 'getopt_oarg[@]'
    return 1
  fi
}

function ble-getopt {
  # 読み掛けのオプション列
  if [[ $getopt_opt ]]; then
    local o=${getopt_opt::1}
    getopt_opt=${getopt_opt:1}
    .ble-getopt.process-option "$o"
    return "$?"
  fi

  # oarg が残っていたらエラー
  .ble-getopt.check-oarg-processed || return 1

  # 完了
  if ((getopt_index>=getopt_len)); then
    builtin unset -v 'optargs[@]'
    return 2
  fi

  local arg=${getopt_args[getopt_index++]}
  if [[ $arg == -?* ]]; then
    
    if [[ $arg == --?* ]]; then
      # longname option
      local f_longname=1
      getopt_opt=${arg:2}

      local o=${getopt_opt%%=*}
      if [[ $o != "$getopt_opt" ]]; then
        getopt_oarg=("${getopt_opt#*=}")
        getopt_oind=0
        getopt_olen=1
      fi
      getopt_opt=

      .ble-getopt.process-option "$o"
      .ble-getopt.check-oarg-processed || return 1
      return 0
    else
      # short options
      local f_longname=
      getopt_opt=${arg:1}

      ble/string#split getopt_oarg : "$getopt_opt"
      getopt_olen=${#getopt_oarg[@]}
      getopt_oind=1
      ble-getopt
      return "$?"
    fi
  else
    # 通常の引数
    optargs=('' "$arg")
  fi

}
