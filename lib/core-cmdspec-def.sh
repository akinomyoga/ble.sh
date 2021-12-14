# -*- mode: sh; mode: sh-bash -*-

function ble/cmdspec/initialize { ble-import "$_ble_base/lib/core-cmdspec.sh"; }
ble/is-function ble/util/idle.push && ble-import -d "$_ble_base/lib/core-cmdspec.sh"


## @type cmdspec_opts
##   各コマンドのコマンドライン引数解釈に関する情報を記述します。
##   コロン区切りのオプションの列で記述されます。
##   以下の値の組み合わせで指定します。
##
##    mandb-disable-man
##      mandb 構築の際に man page を参照しません。
##
##    mandb-help
##      mandb 構築の際に $CMD --help の結果を解析します。
##    mandb-help=%COMMAND
##      mandb 構築の際に COMMAND の実行結果を利用します。
##    mandb-help=@HELPTEXT
##      mandb 構築の際に HELPTEXT を解析します。
##    mandb-help-usage
##      mandb 構築を mandb-help を通して行う時に [-abc] [-a ARG] の形の使用方法
##      からオプションを抽出します。
##
##    mandb-usage
##      mandb 構築の際に $CMD --usage の結果を解析します。
##
##    plus-options
##    plus-options=xyzw
##      "'+' CHAR" の形式のオプションを受け取る事を示します。
##      引数を指定した場合には更に対応している plus option の集合と解釈します。
##      例えば xyzw を指定した時、+x, +y, +z, +w に対応している事を示します。
##
##    no-options
##      オプションを解釈しない事を示します。
##    stop-options-on=REX_STOP
##      指定したパターンに一致する引数より後はオプションの解釈を行わないません。
##    stop-options-unless=REX_CONT
##      指定したパターンに一致しない引数より後はオプションの解釈を行わないません。
##    stop-options-at=IWORD
##      指定した位置以降の引数ではオプションの解釈を行わない事を示します。
##    stop-options-postarg
##      通常引数の後はオプションの解釈を行わない事を示します。
##      この設定は stop-options-unless により上書きされます。
##    disable-double-hyphen
##      オプション '--' 以降もオプションの解釈を行います。
##      この設定は stop-options-on により上書きされます。
##

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_cmdspec_opts}"

function ble/cmdspec/opts {
  local spec=$1 command; shift
  for command; do
    ble/gdict#set _ble_cmdspec_opts "$command" "$spec"
  done
}
## @fn ble/cmdspec/opts#load command [default_value]
##   @var[out] cmdspec_opts
function ble/cmdspec/opts#load {
  cmdspec_opts=$2
  local ret=
  if ble/gdict#get _ble_cmdspec_opts "$1" ||
      { [[ $1 == */*[!/] ]] && ble/gdict#get _ble_cmdspec_opts "${1##*/}"; }
  then
    cmdspec_opts=$ret
  fi
}
