# bash source -*- mode:sh; mode:sh-bash -*-

## 典型的な使用例
##
## function myfunc {
##   local flagVersion= flagHelp= flagEnd=
##
##   builtin eval -- "$_ble_getopt_prologue"
##   ble/getopt.init myfunc "$@"
##   while ble/getopt.next; do
##     case $option in
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
##         process "$optarg"
##       else
##         # 引数が見付からなかった場合
##         ble/getopt.print-argument-message "missing an option argument for $option"
##         getopt_error=1
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
##         process "$optarg"
##       else
##         # 形式 --continue (直接引数なし) の場合
##       fi
##
##     #
##     # -- 以降は通常引数として解釈する場合
##     #
##     (--)
##       # 残りの引数を処理
##       process "${@:optind}"
##       break ;;
##
##     (-*)
##       ble/getopt.print-argument-message "unknown option."
##       getopt_error=1 ;;
##     (*)
##       process "$option" ;;
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

_ble_getopt_locals=(getopt_args getopt_chars getopt_arg getopt_error optind option optarg)
_ble_getopt_prologue='declare "${_ble_getopt_locals[@]}"'
function ble/getopt.init {
  getopt_args=("$@")
  getopt_chars=
  getopt_arg=
  getopt_error=
  optind=1 option= optarg=
}
function ble/getopt.print-argument-message {
  local IFS=$_ble_term_IFS
  local index=$((optind-1))
  ble/util/print "${getopt_args[0]##*/} (argument#$index \`${getopt_args[index]}'): $*" >&2
}
function ble/getopt.print-message {
  local IFS=$_ble_term_IFS
  local index=$((optind-1))
  ble/util/print "${getopt_args[0]##*/} (arguments): $*" >&2
}

function ble/getopt.next {
  ble/getopt/.check-optarg-cleared
  if ((${#getopt_chars})); then
    option=-${getopt_chars::1}
    getopt_chars=${getopt_chars:1}
  elif ((optind<${#getopt_args[@]})); then
    option=${getopt_args[optind++]}
    if [[ $option == -[^-]* ]]; then
      getopt_chars=${option:2}
      option=${option::2}
    elif [[ $option == --*=* ]]; then
      getopt_arg==${option#--*=}
      option=${option%%=*}
    fi
  else
    return 1
  fi
}

# optarg
function ble/getopt.get-optarg {
  if [[ $getopt_arg ]]; then
    optarg=${getopt_arg:1}
    getopt_arg=
  elif ((optind<${#getopt_args[@]})); then
    optarg=${getopt_args[optind++]}
  else
    return 1
  fi
}
function ble/getopt.has-optarg {
  [[ $getopt_arg ]]
}
function ble/getopt/.check-optarg-cleared {
  if [[ $getopt_arg ]]; then
    ble/getopt.print-argument-message "the option argument \`${getopt_arg:1}' is not processed ">&2
    getopt_error=1 getopt_arg=
  fi
}

function ble/getopt.finalize {
  ble/getopt/.check-optarg-cleared
  
  [[ ! $getopt_error ]]
}

