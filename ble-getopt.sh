#!/bin/bash
# -*- coding:utf-8 -*-

# Usage
#
#   local "${ble_getopt_vars[@]}"
#   ble-getopt-begin "progname" "m:n c:n,n k:n,n" "$@"
#   ble-getopt
#
# ToDo
#
#   * next-argument: appropriate error message
#   * next-argument: negative tests
#   * next-argument: function calls
#   * _getopt_index を OPTIND に名前を変える?

ble_getopt_vars=(
  OPTARGS       # 読み取られたオプション

  _getopt_cmd   # 呼出元コマンド名
  _getopt_odefs # オプション定義
  _getopt_args  # コマンド引数
  _getopt_len   # コマンド引数の数
  _getopt_index # 現在のコマンド引数の位置 OPTIND

  _getopt_opt   # 解析中オプション
  _getopt_oarg  # オプション引数
  _getopt_olen  # オプション引数の数
  _getopt_oind  # オプション引数の現在位置
)

function .ble-getopt.next-argument {
  local type="$1" oarg
  if ((_getopt_oind<_getopt_olen)); then
    oarg="${_getopt_oarg[$_getopt_oind]}"
    ((_getopt_oind++))
  elif ((_getopt_index<_getopt_len)); then
    oarg="${_getopt_args[$_getopt_index]}"
    ((_getopt_index++))
  else
    if [ "x${type::1}" = 'x?' ]; then
      oarg="${type:1}"
      [ -z "$oarg" ] && return
    else
      echo "$_getopt_cmd: missing an argument of the option \`${OPTARGS[0]}'." 1>&2
      return 1
    fi
  fi

  # check
  case "$type" in
  [nefdhcbpugkrwxsv])
    if [ ! -$type "$oarg" ]; then
      echo "$_getopt_cmd: the argument of the option \`${OPTARGS[0]}' is empty string (oarg=$oarg)." 1>&2
      return 1
    fi ;;
  esac

  OPTARGS[${#OPTARGS[@]}]="$oarg"
}

function .ble-getopt.process-option {
  local name="$1"
  OPTARGS=("$name")

  # search the option definition
  local i f_found adef
  for ((i=0;i<${#_getopt_odefs[@]};i++)); do
    if [ "$name" = "${_getopt_odefs[$i]%%:*}" ]; then
      f_found=1
      IFS=: eval 'adef=(${_getopt_odefs[$i]})'
      break
    fi
  done

  # unknown option
  if [ -z "$f_found" ]; then
    if [ -n "$f_longname" ]; then
      echo "an unknown long-name option \`--$name'" 1>&2
    else
      echo "an unknown option \`-$name'" 1>&2
    fi
    return 1
  fi

  for ((i=1;i<${#adef[@]};i++)); do
    .ble-getopt.next-argument "${adef[$i]}" || return 1
  done
}

function ble-getopt-begin {
  _getopt_cmd=($1)
  _getopt_odefs=($2)
  shift 2
  _getopt_args=("$@")
  _getopt_len="${#_getopt_args[@]}"
  _getopt_index=0

  _getopt_opt=
  _getopt_olen=0
  _getopt_oind=0

  OPTARGS=()
}

function .ble-getopt.check-oarg-processed {
  if ((_getopt_oind<_getopt_olen)); then
    echo "$_getopt_cmd: an option argument not processed (oarg=${_getopt_oarg[$_getopt_oind]})." 1>&2
    _getopt_oind=0
    _getopt_olen=0
    unset _getopt_oarg[@]
    return 1
  fi
}

function ble-getopt {

  # 読み掛けのオプション列
  if [ -n "$_getopt_opt" ]; then
    local o="${_getopt_opt::1}"
    _getopt_opt="${_getopt_opt:1}"
    .ble-getopt.process-option "$o"
    return
  fi

  # oarg が残っていたらエラー
  .ble-getopt.check-oarg-processed || return 1

  # 完了
  if ((_getopt_index>=_getopt_len)); then
    unset 'OPTARGS[@]'
    return 2
  fi

  local arg="${_getopt_args[$_getopt_index]}"
  ((_getopt_index++))
  if [ ${#arg} -gt 1 -a "${arg::1}" = - ]; then
    _getopt_opt="${arg:1}"

    if [ ${#_getopt_opt} -gt 1 -a "x${_getopt_opt::1}" = x- ]; then
      # longname option
      local f_longname=1
      _getopt_opt="${_getopt_opt:1}"

      local o="${_getopt_opt%%=*}"
      if [ "x$o" != "x$_getopt_opt" ]; then
        _getopt_oarg=("${_getopt_opt#*=}")
        _getopt_oind=0
        _getopt_olen=1
      fi
      _getopt_opt=

      .ble-getopt.process-option "$o"
      .ble-getopt.check-oarg-processed || return 1
      return
    else
      # short options
      local f_longname=

      IFS=: eval 'local arr=($_getopt_opt)'
      _getopt_oarg=("${arr[@]}")
      _getopt_olen="${#_getopt_oarg[@]}"
      _getopt_oind=1
      ble-getopt
      return
    fi
  else
    # 通常の引数
    OPTARGS=('' "$arg")
  fi
 
}
