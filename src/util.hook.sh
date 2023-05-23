# -*- mode: sh; mode: sh-bash -*-

#------------------------------------------------------------------------------
# blehook

## @fn blehook/.print
##   @var[in] flags
function blehook/.print {
  (($#)) || return 0

  local out= q=\' Q="'\''" nl=$'\n'
  local sgr0= sgr1= sgr2= sgr3=
  if [[ $flags == *c* ]]; then
    local ret
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; sgr3=$ret
    sgr0=$_ble_term_sgr0
    Q=$q$sgr0"\'"$sgr3$q
  fi

  local elem op_assign code='
    if ((${#_ble_hook_h_NAME[@]})); then
      op_assign==
      for elem in "${_ble_hook_h_NAME[@]}"; do
        out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0$op_assign${sgr3}$q${elem//$q/$Q}$q$sgr0$nl"
        op_assign=+=
      done
    else
      out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0=$nl"
    fi'

  local hookname
  for hookname; do
    ble/is-array "$hookname" || continue
    builtin eval -- "${code//NAME/${hookname#_ble_hook_h_}}"
  done
  ble/util/put "$out"
}
function blehook/.print-help {
  ble/util/print-lines \
    'usage: blehook [NAME[[=|+=|-=|-+=]COMMAND]]...' \
    '    Add or remove hooks. Without arguments, this prints all the existing hooks.' \
    '' \
    '  Options:' \
    '    --help      Print this help.' \
    '    -a, --all   Print all hooks including the internal ones.' \
    '    --color[=always|never|auto]' \
    '                  Change color settings.' \
    '' \
    '  Arguments:' \
    '    NAME            Print the corresponding hooks.' \
    '    NAME=COMMAND    Set hook after removing the existing hooks.' \
    '    NAME+=COMMAND   Add hook.' \
    '    NAME-=COMMAND   Remove hook.' \
    '    NAME!=COMMAND   Add hook if the command is not registered.' \
    '    NAME-+=COMMAND  Append the hook and remove the duplicates.' \
    '    NAME+-=COMMAND  Prepend the hook and remove the duplicates.' \
    '' \
    '  NAME:' \
    '    The hook name.  The character `@'\'' may be used as a wildcard.' \
    ''
}

## @fn blehook/.read-arguments args...
##   @var[out] flags
function blehook/.read-arguments {
  flags= print=() process=()
  local opt_color=auto
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == -* ]]; then
      case $arg in
      (--help)
        flags=H$flags ;;
      (--color) opt_color=always ;;
      (--color=always|--color=auto|--color=never)
        opt_color=${arg#*=} ;;
      (--color=*)
        ble/util/print "blehook: '${arg#*=}': unrecognized option argument for '--color'." >&2
        flags=E$flags ;;
      (--all) flags=a$flags ;;
      (--*)
        ble/util/print "blehook: unrecognized long option '$arg'." >&2
        flags=E$flags ;;
      (-)
        ble/util/print "blehook: unrecognized argument '$arg'." >&2
        flags=E$flags ;;
      (*)
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          (a) flags=a$flags ;;
          (*)
            ble/util/print "blehook: unrecognized option '-$c'." >&2
            flags=E$flags ;;
          esac
        done ;;
      esac
    elif [[ $arg =~ $rex1 ]]; then
      if [[ $arg == *@* ]] || ble/is-array "_ble_hook_h_$arg"; then
        ble/array#push print "$arg"
      else
        ble/util/print "blehook: undefined hook '$arg'." >&2
      fi
    elif [[ $arg =~ $rex2 ]]; then
      local name=${BASH_REMATCH[1]}
      if [[ $name == *@* ]]; then
        if [[ ${BASH_REMATCH[2]} == :* ]]; then
          ble/util/print "blehook: hook pattern cannot be combined with '${BASH_REMATCH[2]}'." >&2
          flags=E$flags
          continue
        fi
      else
        local var_counter=_ble_hook_c_$name
        if [[ ! ${!var_counter+set} ]]; then
          if [[ ${BASH_REMATCH[2]} == :* ]]; then
            (($var_counter=0))
          else
            ble/util/print "blehook: hook \"$name\" is not defined." >&2
            flags=E$flags
            continue
          fi
        fi
      fi
      ble/array#push process "$arg"
    else
      ble/util/print "blehook: invalid hook spec \"$arg\"" >&2
      flags=E$flags
    fi
  done

  # resolve patterns
  local pat ret out; out=()
  for pat in "${print[@]}"; do
    if [[ $pat == *@* ]]; then
      bleopt/expand-variable-pattern "_ble_hook_h_$pat"
      ble/array#filter ret ble/is-array
      [[ $pat == *[a-z]* || $flags == *a* ]] ||
        ble/array#remove-by-glob ret '_ble_hook_h_*[a-z]*'
      if ((!${#ret[@]})); then
        ble/util/print "blehook: '$pat': matching hook not found." >&2
        flags=E$flags
        continue
      fi
    else
      ret=("_ble_hook_h_$pat")
    fi
    ble/array#push out "${ret[@]}"
  done
  print=("${out[@]}")

  out=()
  for pat in "${process[@]}"; do
    [[ $pat =~ $rex2 ]]
    local name=${BASH_REMATCH[1]}
    if [[ $name == *@* ]]; then
      local type=${BASH_REMATCH[3]}
      local value=${BASH_REMATCH[4]}

      bleopt/expand-variable-pattern "_ble_hook_h_$pat"
      ble/array#filter ret ble/is-array
      [[ $pat == *[a-z]* || $flags == *a* ]] ||
        ble/array#remove-by-glob ret '_ble_hook_h_*[a-z]*'
      if ((!${#ret[@]})); then
        ble/util/print "blehook: '$pat': matching hook not found." >&2
        flags=E$flags
        continue
      fi
      if ((_ble_bash>=40300)) && ! shopt -q compat42; then
        ret=("${ret[@]/%/"$type$value"}") # WA #D1570 #D1751 checked
      else
        ret=("${ret[@]/%/$type$value}") # WA #D1570 #D1738 checked
      fi
    else
      ret=("_ble_hook_h_$pat")
    fi
    ble/array#push out "${ret[@]}"
  done
  process=("${out[@]}")

  [[ $opt_color == always || $opt_color == auto && -t 1 ]] && flags=c$flags
}

function blehook {
  local set shopt
  ble/base/adjust-BASH_REMATCH
  ble/base/.adjust-bash-options set shopt

  local flags print process
  local rex1='^([_a-zA-Z@][_a-zA-Z0-9@]*)$'
  local rex2='^([_a-zA-Z@][_a-zA-Z0-9@]*)(:?([-+!]|-\+|\+-)?=)(.*)$'
  blehook/.read-arguments "$@"
  if [[ $flags == *[HE]* ]]; then
    if [[ $flags == *H* ]]; then
      [[ $flags == *E* ]] &&
        ble/util/print >&2
      blehook/.print-help
    fi
    [[ $flags != *E* ]]; local ext=$?
    ble/base/.restore-bash-options set shopt
    ble/base/restore-BASH_REMATCH
    return "$ext"
  fi

  if ((${#print[@]}==0&&${#process[@]}==0)); then
    print=("${!_ble_hook_h_@}")
    [[ $flags == *a* ]] || ble/array#remove-by-glob print '_ble_hook_h_*[a-z]*'
  fi

  local proc ext=0
  for proc in "${process[@]}"; do
    [[ $proc =~ $rex2 ]]
    local name=${BASH_REMATCH[1]}
    local type=${BASH_REMATCH[3]}
    local value=${BASH_REMATCH[4]}

    local append=$value
    case $type in
    (*-*) # -=, -+=, +-=
      local ret
      ble/array#last-index "$name" "$value"
      if ((ret>=0)); then
        ble/array#remove-at "$name" "$ret"
      elif [[ ${type#:} == '-=' ]]; then
        ext=1
      fi

      if [[ $type != -+ ]]; then
        append=
        [[ $type == +- ]] &&
          ble/array#unshift "$name" "$value"
      fi ;;

    ('!') # !=
      local ret
      ble/array#last-index "$name" "$value"
      ((ret>=0)) && append= ;;

    ('') builtin eval "$name=()" ;; # =
    ('+'|*) ;; # +=
    esac
    [[ $append ]] && ble/array#push "$name" "$append"
  done

  if ((${#print[@]})); then
    blehook/.print "${print[@]}"
  fi

  ble/base/.restore-bash-options set shopt
  ble/base/restore-BASH_REMATCH
  return "$ext"
}
blehook/.compatibility-ble-0.3

function blehook/has-hook {
  builtin eval "local count=\${#_ble_hook_h_$1[@]}"
  ((count))
}
## @fn blehook/invoke.sandbox
##   @var[in] _ble_local_hook _ble_local_lastexit _ble_local_lastarg
function blehook/invoke.sandbox {
  if type "$_ble_local_hook" &>/dev/null; then
    ble/util/setexit "$_ble_local_lastexit" "$_ble_local_lastarg"
    "$_ble_local_hook" "$@" 2>&3
  else
    ble/util/setexit "$_ble_local_lastexit" "$_ble_local_lastarg"
    builtin eval -- "$_ble_local_hook" 2>&3
  fi
}
function blehook/invoke {
  local _ble_local_lastexit=$? _ble_local_lastarg=$_ FUNCNEST=
  ((_ble_hook_c_$1++))
  local -a _ble_local_hooks
  builtin eval "_ble_local_hooks=(\"\${_ble_hook_h_$1[@]}\")"; shift
  local _ble_local_hook _ble_local_ext=0
  for _ble_local_hook in "${_ble_local_hooks[@]}"; do
    blehook/invoke.sandbox "$@" || _ble_local_ext=$?
  done
  return "$_ble_local_ext"
} 3>&2 2>/dev/null # set -x 対策 #D0930
function blehook/eval-after-load {
  local hook_name=${1}_load value=$2
  if ((_ble_hook_c_$hook_name)); then
    builtin eval -- "$value"
  else
    blehook "$hook_name+=$value"
  fi
}

#------------------------------------------------------------------------------
# blehook

_ble_builtin_trap_inside=  # ble/builtin/trap 処理中かどうか

## @fn ble/builtin/trap/.read-arguments args...
##   @var[out] flags
function ble/builtin/trap/.read-arguments {
  flags= command= sigspecs=()
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == -?* && flags != *A* ]]; then
      if [[ $arg == -- ]]; then
        flags=A$flags
        continue
      elif [[ $arg == --* ]]; then
        case $arg in
        (--help)
          flags=h$flags
          continue ;;
        (*)
          ble/util/print "ble/builtin/trap: unknown long option \"$arg\"." >&2
          flags=E$flags
          continue ;;
        esac
      fi

      local i
      for ((i=1;i<${#arg};i++)); do
        case ${arg:i:1} in
        (l) flags=l$flags ;;
        (p) flags=p$flags ;;
        (P) flags=P$flags ;;
        (*)
          ble/util/print "ble/builtin/trap: unknown option \"-${arg:i:1}\"." >&2
          flags=E$flags ;;
        esac
      done
    else
      if [[ $flags != *[pc]* ]]; then
        command=$arg
        flags=c$flags
      else
        ble/array#push sigspecs "$arg"
      fi
    fi
  done

  if [[ $flags != *[hlpPE]* ]]; then
    if [[ $flags != *c* ]]; then
      flags=p$flags
    elif ((${#sigspecs[@]}==0)); then
      sigspecs=("$command")
      command=-
    fi
  elif [[ $flags == *p* && $flags == *P* ]]; then
    ble/util/print "ble/builtin/trap: cannot specify both -p and -P" >&2
    flags=E${flags//[pP]}
  fi
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_trap_name2sig}"
_ble_builtin_trap_sig_name=()
_ble_builtin_trap_sig_opts=()
_ble_builtin_trap_sig_base=1000
_ble_builtin_trap_EXIT=
_ble_builtin_trap_DEBUG=
_ble_builtin_trap_RETURN=
_ble_builtin_trap_ERR=
function ble/builtin/trap/sig#register {
  local sig=$1 name=$2
  _ble_builtin_trap_sig_name[sig]=$name
  ble/gdict#set _ble_builtin_trap_name2sig "$name" "$sig"
}
function ble/builtin/trap/sig#reserve {
  local ret
  ble/builtin/trap/sig#resolve "$1" || return 1
  _ble_builtin_trap_sig_opts[ret]=${2:-1}
}
## @fn ble/builtin/trap/sig#resolve sigspec
##   @var[out] ret
function ble/builtin/trap/sig#resolve {
  ble/builtin/trap/sig#init
  if [[ $1 && ! ${1//[0-9]} ]]; then
    ret=$1
    return 0
  else
    ble/gdict#get _ble_builtin_trap_name2sig "$1"
    [[ $ret ]] && return 0

    ble/string#toupper "$1"; local upper=$ret
    ble/gdict#get _ble_builtin_trap_name2sig "$upper" ||
      ble/gdict#get _ble_builtin_trap_name2sig "SIG$upper" ||
      return 1
    ble/gdict#set _ble_builtin_trap_name2sig "$1" "$ret"
    return 0
  fi
}
## @fn ble/builtin/trap/sig#new sig [opts]
##   @param[in,opt] opts
##
##     builtin (internal use)
##       reserve the special handling of the corresponding builtin trap.  Used
##       for DEBUG, RETURN, and ERR.
##
##     override-builtin-signal (internal use)
##       indicates that the builtin trap handler is overridden by ble.sh.  The
##       user traps should be restored on ble-unload.
##
##     user-trap-in-postproc
##       evaluate user traps outside the trap-handler function.  When this is
##       enabled, the last argument $_ is not modified by the user trap
##       handlers because of the limitation of the implementation.
##
function ble/builtin/trap/sig#new {
  local name=$1 opts=$2
  local sig=$((_ble_builtin_trap_$name=_ble_builtin_trap_sig_base++))
  ble/builtin/trap/sig#register "$sig" "$name"
  if [[ :$opts: != *:builtin:* ]]; then
    ble/builtin/trap/sig#reserve "$sig" "$opts"
  fi
}
function ble/builtin/trap/sig#init {
  function ble/builtin/trap/sig#init { :; }
  local ret i
  ble/util/assign-words ret 'builtin trap -l' 2>/dev/null
  for ((i=0;i<${#ret[@]};i+=2)); do
    local index=${ret[i]%')'}
    local name=${ret[i+1]}
    ble/builtin/trap/sig#register "$index" "$name"
  done

  _ble_builtin_trap_EXIT=0
  ble/builtin/trap/sig#register "$_ble_builtin_trap_EXIT" EXIT
  ble/builtin/trap/sig#new DEBUG  builtin
  ble/builtin/trap/sig#new RETURN builtin
  ble/builtin/trap/sig#new ERR    builtin
}

_ble_builtin_trap_handlers=()
_ble_builtin_trap_handlers_RETURN=()
## @fn ble/builtin/trap/user-handler#load sig
##   @param[in] sig
##     トラップ番号を指定します。
##   @var[out] _ble_trap_handler
##     ユーザートラップを格納します。
##   @exit
##     ユーザートラップが設定されている時に 0 を返します。
function ble/builtin/trap/user-handler#load {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]}
  if [[ $name == RETURN ]]; then
    ble/builtin/trap/user-handler#load:RETURN
  else
    _ble_trap_handler=${_ble_builtin_trap_handlers[sig]-}
    [[ ${_ble_builtin_trap_handlers[sig]+set} ]]
  fi
}
## @fn ble/builtin/trap/user-handler#save sig handler
##   指定したトラップに対するハンドラーを記録します。
##   @param[in] sig handler
##     トラップ番号を指定します。
##   @var[out] _ble_trap_handler
##     ユーザートラップを格納します。
##   @exit
##     ユーザートラップが設定されている時に 0 を返します。
function ble/builtin/trap/user-handler#save {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]} handler=$2
  if [[ $name == RETURN ]]; then
    ble/builtin/trap/user-handler#save:RETURN "$handler"
  else
    if [[ $handler == - ]]; then
      builtin unset -v '_ble_builtin_trap_handlers[sig]'
    else
      _ble_builtin_trap_handlers[sig]=$handler
    fi
  fi
  return 0
}
function ble/builtin/trap/user-handler#save:RETURN {
  local handler=$1

  local offset=
  for ((offset=1;offset<${#FUNCNAME[@]};offset++)); do
    case ${FUNCNAME[offset]} in
    (trap | ble/builtin/trap) ;;
    (ble/builtin/trap/user-handler#save) ;;
    (*) break ;;
    esac
  done
  local current_level=$((${#FUNCNAME[@]}-offset))

  local level
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    if ((level>current_level)); then
      builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
    fi
  done

  if [[ $handler == - ]]; then
    if [[ $- == *T* ]] || shopt -q extdebug; then
      for ((level=current_level;level>=0;level--)); do
        builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
      done
    else
      for ((level=current_level;level>=0;level--,offset++)); do
        builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
        ((level)) && ble/function#has-attr "${FUNCNAME[offset]}" t || break
      done
    fi
  else
    _ble_builtin_trap_handlers_RETURN[current_level]=$handler
  fi
  return 0
}
function ble/builtin/trap/user-handler#load:RETURN {
  # この関数の呼び出し文脈・handler 探索開始関数レベルの決定
  local offset= in_trap=
  for ((offset=1;offset<${#FUNCNAME[@]};offset++)); do
    case ${FUNCNAME[offset]} in
    (trap | ble/builtin/trap) ;;
    (ble/builtin/trap/.handler) ;;
    (ble/builtin/trap/user-handler#load) ;;
    (ble/builtin/trap/user-handler#has) ;;
    (ble/builtin/trap/finalize) ;;
    (ble/builtin/trap/install-hook) ;;
    (ble/builtin/trap/invoke) ;;
    (*) break ;;
    esac
  done
  local search_level=
  if [[ $- == *T* ]] || shopt -q extdebug; then
    search_level=0
  else
    for ((;offset<${#FUNCNAME[@]};offset++)); do
      ble/function#has-attr "${FUNCNAME[offset]}" t || break
    done
    search_level=$((${#FUNCNAME[@]}-offset))
  fi

  # search_level 以降の最大 index に記録されている handler を取得
  local level found= handler=
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    ((level>=search_level)) || continue
    found=1 handler=${_ble_builtin_trap_handlers_RETURN[level]}
  done

  _ble_trap_handler=$handler
  [[ $found ]]
}
## @fn ble/builtin/trap/user-handler#update:RETURN
##   関数が戻る時に呼び出して RETURN トラップの呼び出し元への継承を実行します。
##   この関数は ble/builtin/trap/.handler から呼び出される事を想定しています。
function ble/builtin/trap/user-handler#update:RETURN {
  # この関数の呼び出し文脈の取得
  local offset=2 # ... ble/builtin/trap/.handler から直接呼び出されると仮定
  local current_level=$((${#FUNCNAME[@]}-offset))
  ((current_level>0)) || return 0

  # current_level 以降の最大 index に記録されている handler を取得
  local level found= handler=
  for level in "${!_ble_builtin_trap_handlers_RETURN[@]}"; do
    ((level>=current_level)) || continue
    found=1 handler=${_ble_builtin_trap_handlers_RETURN[level]}

    # 自身及びそれ以下のレベルに記録した handler は削除する。見つかった handler
    # は後でひとつ上のレベルにコピーする。
    if ((level>=current_level)); then
      builtin unset -v '_ble_builtin_trap_handlers_RETURN[level]'
    fi
  done
  if [[ $found ]]; then
    _ble_builtin_trap_handlers_RETURN[current_level-1]=$handler
  fi
}
function ble/builtin/trap/user-handler#has {
  local _ble_trap_handler
  ble/builtin/trap/user-handler#load "$1"
}
function ble/builtin/trap/user-handler#init {
  local script _ble_builtin_trap_user_handler_init=1
  ble/util/assign script 'builtin trap -p'
  builtin eval -- "$script"
}
function ble/builtin/trap/user-handler/is-internal {
  case $1 in
  ('ble/builtin/trap/'*) return 0 ;; # ble-0.4
  ('ble/base/unload'*|'ble-edit/'*) return 0 ;; # bash-0.3 以前
  (*) return 1 ;;
  esac
}

function ble/builtin/trap/finalize {
  _ble_builtin_trap_handlers_reload=()

  local sig unload_opts=$1
  for sig in "${!_ble_builtin_trap_sig_opts[@]}"; do
    local name=${_ble_builtin_trap_sig_name[sig]}
    local opts=${_ble_builtin_trap_sig_opts[sig]}
    [[ $name && :$opts: == *:override-builtin-signal:* ]] || continue

    # Note (#D2021): reload の為に一旦設定を復元する時は readline によ
    # る WINCH trap を破壊しない様に WINCH だけはそのままにして置く。
    # 元々のユーザートラップは _ble_builtin_trap_handlers_reload に記
    # 録し、後の ble/builtin/trap/install-hook で読み取る。
    if [[ :$opts: == *:readline:* && :$unload_opts: == *:reload:* ]]; then
      if local _ble_trap_handler; ble/builtin/trap/user-handler#load "$sig"; then
        local q=\' Q="'\''"
        _ble_builtin_trap_handlers_reload[sig]="trap -- '${_ble_trap_handler//$q/$Q}' $name"
      else
        _ble_builtin_trap_handlers_reload[sig]=
      fi
      continue
    fi

    if local _ble_trap_handler; ble/builtin/trap/user-handler#load "$sig"; then
      builtin trap -- "$_ble_trap_handler" "$name"
    else
      builtin trap -- - "$name"
    fi
  done
}
function ble/builtin/trap {
  local set shopt; ble/base/.adjust-bash-options set shopt
  local flags command sigspecs
  ble/builtin/trap/.read-arguments "$@"

  if [[ $flags == *h* ]]; then
    builtin trap --help
    ble/base/.restore-bash-options set shopt
    return 2
  elif [[ $flags == *E* ]]; then
    builtin trap --usage 2>&1 1>/dev/null | ble/bin/grep ^trap >&2
    ble/base/.restore-bash-options set shopt
    return 2
  elif [[ $flags == *l* ]]; then
    builtin trap -l
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/adjust-BASH_REMATCH

  if [[ $flags == *[pP]* ]]; then
    local -a indices=()
    if ((${#sigspecs[@]})); then
      local spec ret
      for spec in "${sigspecs[@]}"; do
        if ! ble/builtin/trap/sig#resolve "$spec"; then
          ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
          continue
        fi
        ble/array#push indices "$ret"
      done
    else
      indices=("${!_ble_builtin_trap_handlers[@]}" "$_ble_builtin_trap_RETURN")
    fi

    local q=\' Q="'\''" index _ble_trap_handler
    for index in "${indices[@]}"; do
      if ble/builtin/trap/user-handler#load "$index"; then
        if [[ $flags == *p* ]]; then
          local n=${_ble_builtin_trap_sig_name[index]}
          _ble_trap_handler="trap -- '${_ble_trap_handler//$q/$Q}' $n"
        fi
        ble/util/print "$_ble_trap_handler"
      fi
    done
  else
    # Ignore ble.sh handlers of the previous session
    [[ $_ble_builtin_trap_user_handler_init ]] &&
      ble/builtin/trap/user-handler/is-internal "$command" &&
      return 0

    local _ble_builtin_trap_inside=1
    local spec ret
    for spec in "${sigspecs[@]}"; do
      if ! ble/builtin/trap/sig#resolve "$spec"; then
        ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
        continue
      fi
      local sig=$ret
      local name=${_ble_builtin_trap_sig_name[sig]}
      ble/builtin/trap/user-handler#save "$sig" "$command"
      [[ $_ble_builtin_trap_user_handler_init ]] && continue

      local trap_command='builtin trap -- "$command" "$spec"'
      local install_opts=${_ble_builtin_trap_sig_opts[sig]}
      if [[ $install_opts ]]; then
        local custom_trap=ble/builtin/trap:$name
        if ble/is-function "$custom_trap"; then
          trap_command='"$custom_trap" "$command" "$spec"'
        elif [[ :$install_opts: == *:readline:* ]] && ! ble/util/is-running-in-subshell; then
          # Note (#D1345 #D1862): readline 介入を破壊しない為に親シェル内部では
          # builtin trap 再設定はしない。
          trap_command=
        elif [[ $command == - ]]; then
          if [[ :$install_opts: == *:inactive:* ]]; then
            # Note #D1858: 単に ble/builtin/trap/.handler 経由で処理する trap の場合。
            # trap を解除する時にはそのまま解除して良い。
            trap_command='builtin trap - "$spec"'
          else
            # Note #D1858: 内部処理の為に trap は常設しているので、trap の削除
            # はしない。だからと言って改めて内部処理の為のコマンドを登録する訳
            # でもない (特に subshell の中で改めて実行したい訳でもなければ)。
            trap_command=
          fi
        elif [[ :$install_opts: == *:override-builtin-signal:* ]]; then
          # Note #D1862: 内部処理の為に trap を常設していたとしても EXIT 等の
          # 様に subshell に継承されない trap があるので毎回明示的に builtin
          # trap を実行する。
          ble/builtin/trap/install-hook/.compose-trap_command "$sig"
          trap_command="builtin $trap_command"
        else
          # ble/builtin/trap/{.register,reserve} で登録したカスタム trap の場合
          # は builtin trap 関係の操作は何もしない。発火の制御に関しては
          # ble/builtin/trap/invoke を適切な場所で呼び出す様に実装するべき。
          trap_command=
        fi
      fi

      if [[ $trap_command ]]; then
        # Note #D1858: set -E (-o errtrace) が設定されていない限り、関数の中か
        # ら trap ERR を削除する事はできない。仕方がないので空の command を
        # trap として設定する事にする。元々 trap ERR が設定されていない時の動作
        # は「何もしない」なので空文字列で問題ないはず。
        if [[ $name == ERR && $command == - && $- != *E* ]]; then
          command=
        fi
        builtin eval -- "$trap_command"
      fi
    done
  fi

  [[ ! $_ble_attached || $_ble_edit_exec_inside_userspace ]] &&
    ble/base/restore-BASH_REMATCH
  ble/base/.restore-bash-options set shopt
  return 0
}
function trap { ble/builtin/trap "$@"; }
ble/builtin/trap/user-handler#init

function ble/builtin/trap/.TRAPRETURN {
  local IFS=$_ble_term_IFS
  local backtrace=" ${BLE_TRAP_FUNCNAME[*]-} "
  case $backtrace in
  # 呼び出し元が RETURN trap の設置に用いた trap の時は RETURN は無視する。それ
  # 以外の trap 呼び出しについても無視して良い。
  (' trap '* | ' ble/builtin/trap '*) return 126 ;;
  # ble/builtin/trap/.handler 内部処理に対する RETURN は無視するが、
  # ble/builtin/trap/.handler から更に呼び出された blehook / trap_string の中で
  # 呼び出されている関数については RETURN を発火させる。
  (*' ble/builtin/trap/.handler '*)
    case ${backtrace%%' ble/builtin/trap/.handler '*}' ' in
    (' '*' blehook/invoke.sandbox '* | ' '*' ble/builtin/trap/invoke.sandbox '*) ;;
    (*) return 126 ;;
    esac ;;
  # 待避処理をしていないユーザーコマンド実行後に呼び出される関数達。
  (*' ble-edit/exec:gexec/.save-lastarg ' | ' _ble_edit_exec_gexec__TRAPDEBUG_adjust ') return 126 ;;
  esac
  return 0
}
blehook internal_RETURN!=ble/builtin/trap/.TRAPRETURN

# user trap handler 専用の $?, $_ の記録。
_ble_builtin_trap_user_lastcmd=
_ble_builtin_trap_user_lastarg=
_ble_builtin_trap_user_lastexit=
## @fn ble/builtin/trap/invoke.sandbox params...
##   @param[in] params...
##   @var[in] _ble_trap_handler
##   @var[out] _ble_trap_done
##   @var[in,out] _ble_trap_lastexit _ble_trap_lastarg
function ble/builtin/trap/invoke.sandbox {
  local _ble_trap_count
  for ((_ble_trap_count=0;_ble_trap_count<1;_ble_trap_count++)); do
    _ble_trap_done=return
    # Note #D1757: そのまま制御を変更せずに trap handler の実行が終わっ
    # た時は $? $_ を保存する。同じ eval の中でないと $_ が eval を抜
    # けた時に eval の最終引数に置き換えられてしまう事に注意する。
    ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
    builtin eval -- "$_ble_trap_handler"$'\n_ble_trap_lastexit=$? _ble_trap_lastarg=$_' 2>&3
    _ble_trap_done=done
    return 0
  done
  _ble_trap_lastexit=$? _ble_trap_lastarg=$_

  # break/continue 検出
  if ((_ble_trap_count==0)); then
    _ble_trap_done=break
  else
    _ble_trap_done=continue
  fi
  return 0
}
## @fn ble/builtin/trap/invoke sig params...
##   @param[in] sig
##   @param[in] params...
##   @var[in] ? _
##   @var[in,out] _ble_builtin_trap_postproc[sig]
##   @var[in,out] _ble_builtin_trap_lastarg[sig]
function ble/builtin/trap/invoke {
  local _ble_trap_lastexit=$? _ble_trap_lastarg=$_ _ble_trap_sig=$1; shift
  if [[ ${_ble_trap_sig//[0-9]} ]]; then
    local ret
    ble/builtin/trap/sig#resolve "$_ble_trap_sig" || return 1
    _ble_trap_sig=$ret
    ble/util/unlocal ret
  fi

  local _ble_trap_handler
  ble/builtin/trap/user-handler#load "$_ble_trap_sig"
  [[ $_ble_trap_handler ]] || return 0

  # restore $_ and $? for user trap handlers
  if [[ $_ble_attached && ! $_ble_edit_exec_inside_userspace ]]; then
    if [[ $_ble_builtin_trap_user_lastcmd != $_ble_edit_CMD ]]; then
      _ble_builtin_trap_user_lastcmd=$_ble_edit_CMD
      _ble_builtin_trap_user_lastexit=$_ble_edit_exec_lastexit
      _ble_builtin_trap_user_lastarg=$_ble_edit_exec_lastarg
    fi
    _ble_trap_lastexit=$_ble_builtin_trap_user_lastexit
    _ble_trap_lastarg=$_ble_builtin_trap_user_lastarg
  fi

  local _ble_trap_done=
  ble/builtin/trap/invoke.sandbox "$@"; local ext=$?
  case $_ble_trap_done in
  (done)
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit" ;;
  (break | continue)
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    if ble/string#match "$_ble_trap_lastarg" '^-?[0-9]+$'; then
      _ble_builtin_trap_postproc[_ble_trap_sig]="$_ble_trap_done $_ble_trap_lastarg"
    else
      _ble_builtin_trap_postproc[_ble_trap_sig]=$_ble_trap_done
    fi ;;
  (return)
    # Note #D1757: return 自体の lastarg は最早取得できないが、もし
    # 仮に直接 builtin trap で実行されたとしても、return で関数を抜
    # けた時に lastarg は書き換えられるので取得できない。精々関数を
    # 呼び出す前の lastarg を設定して置いて return が失敗した時に前
    # の状態を keep するぐらいしかない気がする。
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$ext
    _ble_builtin_trap_postproc[_ble_trap_sig]="return $ext" ;;
  (exit)
    # Note #D1782: trap handler の中で ble/builtin/exit (edit.sh) を呼
    #   び出した時は、即座に bash を終了せずに取り敢えずは trap の処理
    #   は完了させる。TRAPDEBUGによって _ble_trap_done=exit が設定され
    #   る。また、元々 exit に渡された引数は $_ble_trap_lastarg に設定
    #   される。
    # Note #D1782: 他の trap の中で更にまた DEBUG trap が起動している
    #   時などの為に、builtin exit ではなく ble/builtin/exit を再度呼
    #   び出し直す。
    _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/builtin/exit $_ble_trap_lastarg" ;;
  esac

  # save $_ and $? for user trap handlers
  if [[ $_ble_attached && ! $_ble_edit_exec_inside_userspace ]]; then
    _ble_builtin_trap_user_lastexit=$_ble_trap_lastexit
    _ble_builtin_trap_user_lastarg=$_ble_trap_lastarg
  fi

  return 0
} 3>&2 2>/dev/null # set -x 対策 #D0930

## @var _ble_builtin_trap_processing
##   ble/builtin/trap/.handler 実行中かどうかを表すローカル変数です。
##   以下の二つの形式の内のどちらかを取ります。
##
##   SUBSHELL/SIG
##     SUBSHELL は trap 処理の実行元のサブシェルの深さ (呼び出し元にお
##     ける BASH_SUBSHELL の値) を記録します。SIG はシグナルを表す整数
##     値です。
##
##   SUBSHELL/exit:EXIT
##     EXIT は ble/builtin/exit に渡された終了ステータスで、これは最終
##     的な exit で使われる終了ステータスです。
##
_ble_builtin_trap_processing=
_ble_builtin_trap_postproc=()
_ble_builtin_trap_lastarg=()
function ble/builtin/trap/install-hook/.compose-trap_command {
  local sig=$1 name=${_ble_builtin_trap_sig_name[$1]}
  local handler='ble/builtin/trap/.handler SIGNUM "$BASH_COMMAND" "$@"; builtin eval -- "${_ble_builtin_trap_postproc[SIGNUM]}" \# "${_ble_builtin_trap_lastarg[SIGNUM]}"'
  trap_command="trap -- '${handler//SIGNUM/$sig}' $name" # WA #D1738 checked (sig is integer)
}

_ble_trap_builtin_handler_DEBUG_filter=

## @fn ble/builtin/trap/.handler sig bash_command params...
##   @param[in] sig
##     Specifies the signal number
##   @param[in] bash_command
##     Specifies the value of BASH_COMMAND in the original context
##   @param[in] params...
##     Specifies the positional parameters in the original context
##   @var[in] _ble_builtin_trap_depth
##   @var[out] _ble_builtin_trap_xlastarg[_ble_builtin_trap_depth]
##   @var[out] _ble_builtin_trap_xpostproc[_ble_builtin_trap_depth]
function ble/builtin/trap/.handler {
  local _ble_trap_lastexit=$? _ble_trap_lastarg=$_ FUNCNEST= IFS=$_ble_term_IFS
  local _ble_trap_sig=$1 _ble_trap_bash_command=$2
  shift 2

  # Note: bash-5.2 では read -t の最中に WINCH が来るとその場で発火して変なこと
  #   が色々起こる。(1) 内部で ble/util/msleep を実行しようとすると外側の
  #   timeout 設定が削除されて、外側の read -t が永遠に終わらない状態になる。特
  #   に msleep では終端しないストリームから読み出そうとするのでデッドロックす
  #   る。(2) 中でコマンド置換 $() や mapfile を使おうとすると、
  #   run_pending_trap (trap.c) が途中で予期せず中断してしまって running_trap
  #   が放置された状態になる。trap 処理入れ子状態になってしまってずっと WINCH
  #   を受信できない状態になってしまう。
  if [[ $_ble_bash_read_winch && ${_ble_builtin_trap_sig_name[_ble_trap_sig]} == SIGWINCH ]]; then
    local ret
    ble/string#quote-command "$FUNCNAME" "$_ble_trap_sig" "$_ble_trap_bash_command" "$@"
    _ble_bash_read_winch=$ret$'\n''builtin eval -- "${_ble_builtin_trap_postproc['$_ble_trap_sig']}"'
    return 0
  fi

  # Early filter for frequently called DEBUG (set by edit.sh)
  if ((_ble_trap_sig==_ble_builtin_trap_DEBUG)) &&
       ! builtin eval -- "$_ble_trap_builtin_handler_DEBUG_filter"; then
    _ble_builtin_trap_lastarg[_ble_trap_sig]=${_ble_trap_lastarg//*$_ble_term_nl*}
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit"
    return 0
  fi

  # Adjust trap context
  local _ble_trap_set _ble_trap_shopt; ble/base/.adjust-bash-options _ble_trap_set _ble_trap_shopt
  local _ble_trap_name=${_ble_builtin_trap_sig_name[_ble_trap_sig]#SIG}
  local -a _ble_trap_args; _ble_trap_args=("$@")
  if [[ ! $_ble_trap_bash_command ]] || ((_ble_bash<30200)); then
    # Note: Bash 3.0, 3.1 は trap 中でも BASH_COMMAND は trap 発動対象ではなく
    # て現在実行中のコマンドになっている。_ble_trap_bash_command には単に
    # ble/builtin/trap/.handler が入っているので別の適当な値で置き換える。
    if [[ $_ble_attached ]]; then
      _ble_trap_bash_command=$_ble_edit_exec_BASH_COMMAND
    else
      ble/util/assign _ble_trap_bash_command 'HISTTIMEFORMAT=__ble_ext__ builtin history 1'
      _ble_trap_bash_command=${_ble_trap_bash_command#*__ble_ext__}
    fi
  fi

  local _ble_builtin_trap_processing=${BASH_SUBSHELL:-0}/$_ble_trap_sig
  _ble_builtin_trap_lastarg[_ble_trap_sig]=$_ble_trap_lastarg
  _ble_builtin_trap_postproc[_ble_trap_sig]="ble/util/setexit $_ble_trap_lastexit"

  # Note #D1782: ble/builtin/exit で "builtin exit ... &>/dev/null" と
  #   したリダイレクションを元に戻す。元々 builtin exit が出力するエラー
  #   を無視する為のリダイレクトだが、続いて呼び出される EXIT trap に
  #   対してもこのリダイレクションが有効なままになる (但し、
  #   bash-4.4..5.1 ではバグで top-level まで制御を戻してから EXIT
  #   trap 他の処理が実行されるので、EXIT trap は tty に繋がった状態で
  #   実行される)。他の trap が予期せず呼び出された場合にも同様の事が
  #   起こる。trap handler を exit を実行した文脈での stdout/stderr で
  #   実行する為に、stdout/stderr を保存していた物に繋ぎ戻す。
  if [[ $_ble_builtin_exit_processing ]]; then
    exec 1>&- 1>&"$_ble_builtin_exit_stdout"
    exec 2>&- 2>&"$_ble_builtin_exit_stderr"
  fi

  local BLE_TRAP_FUNCNAME BLE_TRAP_SOURCE BLE_TRAP_LINENO
  BLE_TRAP_FUNCNAME=("${FUNCNAME[@]:1}")
  BLE_TRAP_SOURCE=("${BASH_SOURCE[@]:1}")
  BLE_TRAP_LINENO=("${BASH_LINENO[@]}")
  [[ $_ble_attached ]] &&
    BLE_TRAP_LINENO[${#BASH_LINENO[@]}-1]=$_ble_edit_LINENO

  # ble.sh internal hook
  ble/util/joblist.check
  ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
  blehook/invoke "internal_$_ble_trap_name"; local internal_ext=$?
  ble/util/joblist.check ignore-volatile-jobs

  if ((internal_ext!=126)); then
    if ! ble/util/is-running-in-subshell; then
      # blehook (only activated in parent shells)
      ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
      BASH_COMMAND=$_ble_trap_bash_command \
        blehook/invoke "$_ble_trap_name"
      ble/util/joblist.check ignore-volatile-jobs
    fi

    # user hook
    local install_opts=${_ble_builtin_trap_sig_opts[_ble_trap_sig]}
    if [[ :$_ble_tra_opts: == *:user-trap-in-postproc:* ]]; then
      # ユーザートラップを外で実行 (Note: user-trap lastarg は反映されず)
      local q=\' Q="'\''" _ble_trap_handler postproc=
      ble/builtin/trap/user-handler#load "$_ble_trap_sig"
      if [[ $_ble_trap_handler == *[![:space:]]* ]]; then
        postproc="ble/util/setexit $_ble_trap_lastexit '${_ble_trap_lastarg//$q/$Q}'"
        postproc=$postproc";LINENO=$BLE_TRAP_LINENO builtin eval -- '${_ble_trap_handler//$q/$Q}'"
      else
        postproc="ble/util/setexit $_ble_trap_lastexit"
      fi
      _ble_builtin_trap_postproc[_ble_trap_sig]=$postproc
    else
      ble/util/setexit "$_ble_trap_lastexit" "$_ble_trap_lastarg"
      BASH_COMMAND=$_ble_trap_bash_command LINENO=$BLE_TRAP_LINENO \
        ble/builtin/trap/invoke "$_ble_trap_sig" "${_ble_trap_args[@]}"
    fi
  fi

  # 何処かの時点で exit が要求された場合
  if [[ $_ble_builtin_trap_processing == */exit:* && ${_ble_builtin_trap_postproc[_ble_trap_sig]} != 'ble/builtin/exit '* ]]; then
    _ble_builtin_trap_postproc[_ble_trap_sig]="ble/builtin/exit ${_ble_builtin_trap_processing#*/exit:}"
  fi

  # Note #D1757: 現在 eval が終わった後の $_ を設定する為には eval に
  # '#' "$lastarg" を余分に渡すしかないので改行を含める事はできない。
  # 中途半端な値を設定するよりは最初から何も設定しない事にする。ここ設
  # 定する lastarg は一見して誰も使わない様な気がするが、裸で設定され
  # た user trap が参照するかもしれないので一応設定する。
  [[ ${_ble_builtin_trap_lastarg[_ble_trap_sig]} == *$'\n'* ]] &&
    _ble_builtin_trap_lastarg[_ble_trap_sig]=

  if ((_ble_trap_sig==_ble_builtin_trap_EXIT)); then
    # Note #D1797: EXIT に対する ble/base/unload は trap handler のできるだけ最
    # 後に実行する。勝手に削除されても困るし、他の handler が ble.sh の機能を使っ
    # た時に問題が起こらない様にする為。
    ble/base/unload EXIT
  elif ((_ble_trap_sig==_ble_builtin_trap_RETURN)); then
    # Note #D1863: RETURN trap の呼び出し元への継承処理を実行する。
    ble/builtin/trap/user-handler#update:RETURN
  fi

  ble/base/.restore-bash-options _ble_trap_set _ble_trap_shopt
}

## @fn ble/builtin/trap/install-hook sig [opts]
##   @param[in] sig
##     シグナル名、もしくは番号
##   @param[in,opt] opts
##     readline readline による処理が追加されることが期待される trap handler で
##              ある事を示します。既に設定済みのハンドラーが存在している場合に
##              はハンドラーの再設定を行いません。
##     inactive ユーザートラップが設定されていない時は builtin trap からハンド
##              ラの登録を削除します。
function ble/builtin/trap/install-hook {
  local ret opts=${2-}
  ble/builtin/trap/sig#resolve "$1"
  local sig=$ret name=${_ble_builtin_trap_sig_name[ret]}
  ble/builtin/trap/sig#reserve "$sig" "override-builtin-signal:$opts"

  local trap_command; ble/builtin/trap/install-hook/.compose-trap_command "$sig"
  local trap_string; ble/util/assign trap_string "builtin trap -p $name"

  if [[ :$opts: == *:readline:* ]] && ! ble/util/is-running-in-subshell; then
    # Note #D1345: ble.sh の内部で "builtin trap -- WINCH" 等とすると
    # readline の処理が行われなくなってしまう (COLUMNS, LINES が更新さ
    # れない)。
    #
    # Bash では TSTP, TTIN, TTOU, INT, TERM, HUP, QUIT, WINCH について
    # は readline が処理を追加している。builtin trap を実行すると、一旦
    # は trap の設定した trap_handler が設定されるが、"コマンド実行後"
    # に readline が rl_maybe_set_sighandler という関数を用いて上書きし
    # てreadline 特有の処理を挿入する。ble.sh は readline の "コマンド
    # 実行"を使わないので、readline による追加処理が消滅する。
    #
    # 対策として、今から登録しようとしている文字列が既に登録されている
    # 物と一致する場合には、builtin trap の呼び出しを省略する。
    #
    # - 現状では問題になっているのは WINCH だけなので取り敢えず WINCH
    #   だけ対策をする。
    # - INT は bind -x 内だと改めて設定しないと有効にならない(?)様なの
    #   で既に登録されていても、builtin trap は省略できない。
    #
    [[ $trap_command == "$trap_string" ]] && trap_command= trap_string=

    # Note (#D2021): reload 時に元の trap が保存されていればそれを読み取る。
    [[ $trap_string ]] || trap_string=${_ble_builtin_trap_handlers_reload[sig]-}
  fi

  [[ ! $trap_command || :$opts: == *:inactive:* && ! $trap_string ]] ||
    builtin eval "builtin $trap_command"; local ext=$?

  local q=\'
  if [[ $trap_string == "trap -- '"* ]] && ! ble/builtin/trap/user-handler/is-internal "${trap_string#*$q}"; then
    # Note: 1000 以上はデバグ用の trap (DEBUG, RETURN, EXIT) で既定では trapが
    # 関数呼び出しで継承されないので、trap_string の内容は信用できない。
    ((sig<1000)) &&
      # Note: 既存の handler がない時のみ設定を読み取る。既存の設定がある時は
      # ble.sh をロードしてから trap が実行された事を意味する。一方で、ble.sh
      # がロードされて以降に builtin trap の設定がユーザーによって直接変更され
      # る事は想定していないので、builtin trap から読み取った結果は ble.sh ロー
      # ド前と想定して良い。
      ! ble/builtin/trap/user-handler#has "$sig" &&
      builtin eval -- "ble/builtin/$trap_string"
  fi

  return "$ext"
}
