# bash source -*- mode:sh; mode:sh-bash -*-

## 典型的な使用例
##
## function myfunc {
##   local flagVersion= flagHelp= flagEnd=
##
##   builtin eval -- "$ble_getopt_prologue"
##   ble/getopt.init myfunc "$@"
##   while ble/getopt.next; do
##     case "$OPTION" in
##
##     #
##     # --version, --help (引数を取らないオプション)
##     #
##     (-v|--version) flagVersion=1 flagEnd=1 ;;
##     (-h|--help)    flagHelp=1    flagEnd=1 ;;
##
##     #
##     # -w OPTARG, --width=OPTARG, --width OPTARG の形式で引数を取る場合
##     #
##     (-w|--width)
##       if ble/getopt.get-optarg; then
##         # 引数が見付かった場合
##         process "$OPTARG"
##       else
##         # 引数が見付からなかった場合
##         ble/getopt.print-argument-message "missing an option argument for $OPTION"
##         _opterror=1
##       fi
##
##     #
##     # -c, --continue の形式では引数を取らず、
##     # --continue=OPTARG の形式では引数を取る場合
##     #
##     (-c|--continue)
##       if ble/getopt.has-optarg; then
##         # 形式 --continue=... (直接引数あり) の場合
##         ble/getopt.get-optarg
##         process "$OPTARG"
##       else
##         # 形式 --continue (直接引数なし) の場合
##       fi
##
##     #
##     # -- 以降は通常引数として解釈する場合
##     #
##     (--)
##       # 残りの引数を処理
##       process "${@:OPTIND}"
##       break ;;
##
##     (-*)
##       ble/getopt.print-argument-message "unknown option."
##       _opterror=1 ;;
##     (*)
##       process "$OPTION" ;;
##     esac
##   done
##
##   [[ $flagVersion ]] && print-version
##   [[ $flagHelp ]] && print-help
##   [[ $flagEnd ]] && return 0
##
##   if ! ble/getopt.finalize; then
##     # 引数の読み取り中にエラーがあった場合
##     print-usage >&2
##     exit 1
##   elif ! check-argument-consistency; then
##     ble/getopt.print-message "no input files are specified."
##     print-usage >&2
##     exit 1
##   fi
## }

ble_getopt_locals=(_optargs _optchars _optarg _opterror OPTIND OPTION OPTARG)
ble_getopt_prologue='declare "${ble_getopt_locals[@]}"'
function ble/getopt.init {
  _optargs=("$@")
  _optchars= _optarg= _opterror=
  OPTIND=1 OPTION= OPTARG=
}
function ble/getopt.print-argument-message {
  local index=$((OPTIND-1))
  ble/util/print "${_optargs[0]##*/} (argument#$index \`${_optargs[index]}'): $*" >&2
}
function ble/getopt.print-message {
  local index=$((OPTIND-1))
  ble/util/print "${_optargs[0]##*/} (arguments): $*" >&2
}

function ble/getopt.next {
  ble/getopt/.check-optarg-cleared
  if ((${#_optchars})); then
    OPTION=-${_optchars::1}
    _optchars=${_optchars:1}
  elif ((OPTIND<${#_optargs[@]})); then
    OPTION=${_optargs[OPTIND++]}
    if [[ $OPTION == -[^-]* ]]; then
      _optchars=${OPTION:2}
      OPTION=${OPTION::2}
    elif [[ $OPTION == --*=* ]]; then
      _optarg==${OPTION#--*=}
      OPTION=${OPTION%%=*}
    fi
  else
    return 1
  fi
}

# optarg
function ble/getopt.get-optarg {
  if [[ $_optarg ]]; then
    OPTARG=${_optarg:1}
    _optarg=
  elif ((OPTIND<${#_optargs[@]})); then
    OPTARG=${_optargs[OPTIND++]}
  else
    return 1
  fi
}
function ble/getopt.has-optarg {
  [[ $_optarg ]]
}
function ble/getopt/.check-optarg-cleared {
  if [[ $_optarg ]]; then
    ble/getopt.print-argument-message "the option argument \`${_optarg:1}' is not processed ">&2
    _opterror=1 _optarg=
  fi
}

function ble/getopt.finalize {
  ble/getopt/.check-optarg-cleared
  
  [[ ! $_opterror ]]
}

