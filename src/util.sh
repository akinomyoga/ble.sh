# -*- mode: sh; mode: sh-bash -*-
# bash script to be sourced from interactive shell

#------------------------------------------------------------------------------
# ble.sh options

function bleopt/.read-arguments/process-option {
  local name=$1
  case $name in
  (help)
    flags=H$flags ;;
  (color|color=always)
    flags=c${flags//[cn]} ;;
  (color=never)
    flags=n${flags//[cn]} ;;
  (color=auto)
    flags=${flags//[cn]} ;;
  (color=*)
    ble/util/print "bleopt: '${name#*=}': unrecognized option argument for '--color'." >&2
    flags=E$flags ;;
  (reset)   flags=r$flags ;;
  (changed) flags=u$flags ;;
  (initialize) flags=I$flags ;;
  (*)
    ble/util/print "bleopt: unrecognized long option '--$name'." >&2
    flags=E$flags ;;
  esac
}

## @fn bleopt/expand-variable-pattern pattern opts
##   @var[out] ret
function bleopt/expand-variable-pattern {
  ret=()
  local pattern=$1
  if [[ $pattern == *@* ]]; then
    builtin eval -- "ret=(\"\${!${pattern%%@*}@}\")"
    ble/array#filter-by-glob ret "${pattern//@/?*}"
  elif [[ ${!pattern+set} || :$opts: == :allow-undefined: ]]; then
    ret=("$pattern")
  fi
  ((${#ret[@]}))
}

## @fn bleopt/.read-arguments
##   @var[out] flags
##     H --help
##     c --color=always
##     n --color=never
##     r --reset
##     u --changed
##     I --initialize
##   @var[out] pvars
##   @var[out] specs
function bleopt/.read-arguments {
  flags= pvars=() specs=()
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--)
      ble/array#push specs "$@"
      break ;;
    (-)
      ble/util/print "bleopt: unrecognized argument '$arg'." >&2
      flags=E$flags ;;
    (--*)
      bleopt/.read-arguments/process-option "${arg:2}" ;;
    (-*)
      local i c
      for ((i=1;i<${#arg};i++)); do
        c=${arg:i:1}
        case $c in
        (r) bleopt/.read-arguments/process-option reset ;;
        (u) bleopt/.read-arguments/process-option changed ;;
        (I) bleopt/.read-arguments/process-option initialize ;;
        (*)
          ble/util/print "bleopt: unrecognized option '-$c'." >&2
          flags=E$flags ;;
        esac
      done ;;
    (*)
      if local rex='^([_a-zA-Z0-9@]+)(:?=|$)(.*)'; [[ $arg =~ $rex ]]; then
        local name=${BASH_REMATCH[1]#bleopt_}
        local var=bleopt_$name
        local op=${BASH_REMATCH[2]}
        local value=${BASH_REMATCH[3]}

        # check/expand variable names
        if [[ $op == ':=' ]]; then
          if [[ $var == *@* ]]; then
            ble/util/print "bleopt: \`${var#bleopt_}': wildcard cannot be used in the definition." >&2
            flags=E$flags
            continue
          fi
        else
          local ret; bleopt/expand-variable-pattern "$var"

          # obsolete な物は除外
          var=()
          local v i=0
          for v in "${ret[@]}"; do
            ble/is-function "bleopt/obsolete:${v#bleopt_}" && continue
            var[i++]=$v
          done

          # 表示目的で obsolete しかない時は obsolete でも表示
          [[ ${#var[@]} == 0 ]] && var=("${ret[@]}")

          # 適した物が見つからない場合は失敗
          if ((${#var[@]}==0)); then
            ble/util/print "bleopt: option \`$name' not found" >&2
            flags=E$flags
            continue
          fi
        fi

        if [[ $op ]]; then
          var=("${var[@]}") # #D1570: WA bash-3.0 ${scal[@]/x} bug
          if ((_ble_bash>=40300)) && ! shopt -q compat42; then
            ble/array#push specs "${var[@]/%/"=$value"}" # WA #D1570 #D1751 checked
          else
            ble/array#push specs "${var[@]/%/=$value}" # WA #D1570 #D1738 checked
          fi
        else
          ble/array#push pvars "${var[@]}"
        fi
      else
        ble/util/print "bleopt: unrecognized argument '$arg'" >&2
        flags=E$flags
      fi ;;
    esac
  done
}

function bleopt/changed.predicate {
  local cur=$1 def=_ble_opt_def_${1#bleopt_}
  [[ ! ${!def+set} || ${!cur} != "${!def}" ]]
}

## @fn bleopt args...
##   @params[in] args
##     args は以下の内の何れかの形式を持つ。
##
##     var=value
##       既存の設定変数に値を設定する。
##       設定変数が存在しないときはエラー。
##     var:=value
##       設定変数に値を設定する。
##       設定変数が存在しないときは新しく作成する。
##     var
##       変数の設定内容を表示する
##
function bleopt {
  local flags pvars specs
  bleopt/.read-arguments "$@"
  if [[ $flags == *E* ]]; then
    return 2
  elif [[ $flags == *H* ]]; then
    ble/util/print-lines \
      'usage: bleopt [OPTION] [NAME|NAME=VALUE|NAME:=VALUE]...' \
      '    Set ble.sh options. Without arguments, this prints all the settings.' \
      '' \
      '  Options' \
      '    --help           Print this help.' \
      '    -r, --reset      Reset options to the default values' \
      '    -I, --initialize Re-initialize settings' \
      '    -u, --changed    Only select changed options' \
      '    --color[=always|never|auto]' \
      '                     Change color settings.' \
      '' \
      '  Arguments' \
      '    NAME        Print the value of the option.' \
      '    NAME=VALUE  Set the value to the option.' \
      '    NAME:=VALUE Set or create the value to the option.' \
      '' \
      '  NAME can contain "@" as a wildcard.' \
      ''
    return 0
  fi

  if ((${#pvars[@]}==0&&${#specs[@]}==0)); then
    local var ip=0
    for var in "${!bleopt_@}"; do
      ble/is-function "bleopt/obsolete:${var#bleopt_}" && continue
      pvars[ip++]=$var
    done
  fi

  [[ $flags == *u* ]] &&
    ble/array#filter pvars bleopt/changed.predicate

  # --reset: pvars を全て既定値の設定に読み替える
  if [[ $flags == *r* ]]; then
    local var
    for var in "${pvars[@]}"; do
      local name=${var#bleopt_}
      ble/is-function bleopt/obsolete:"$name" && continue
      local def=_ble_opt_def_$name
      [[ ${!def+set} && ${!var-} != "${!def}" ]] &&
        ble/array#push specs "$var=${!def}"
    done
    pvars=()
  elif [[ $flags == *I* ]]; then
    local var
    for var in "${pvars[@]}"; do
      bleopt/reinitialize "${var#bleopt_}"
    done
    pvars=()
  fi

  if ((${#specs[@]})); then
    local spec
    for spec in "${specs[@]}"; do
      local var=${spec%%=*} value=${spec#*=}
      [[ ${!var+set} && ${!var} == "$value" ]] && continue
      if ble/is-function bleopt/check:"${var#bleopt_}"; then
        local bleopt_source=${BASH_SOURCE[1]}
        local bleopt_lineno=${BASH_LINENO[0]}
        if ! bleopt/check:"${var#bleopt_}"; then
          flags=E$flags
          continue
        fi
      fi
      builtin eval -- "$var=\"\$value\""
    done
  fi

  if ((${#pvars[@]})); then
    # 着色
    local sgr0= sgr1= sgr2= sgr3=
    if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
      local ret
      ble/color/face2sgr command_function; sgr1=$ret
      ble/color/face2sgr syntax_varname; sgr2=$ret
      ble/color/face2sgr syntax_quoted; sgr3=$ret
      sgr0=$_ble_term_sgr0
    fi

    local var
    for var in "${pvars[@]}"; do
      local ret
      ble/string#quote-word "${!var}" sgrq="$sgr3":sgr0="$sgr0"
      ble/util/print "${sgr1}bleopt$sgr0 ${sgr2}${var#bleopt_}$sgr0=$ret"
    done
  fi

  [[ $flags != *E* ]]
}

function bleopt/declare/.check-renamed-option {
  var=bleopt_$2

  local sgr0= sgr1= sgr2= sgr3=
  if [[ -t 2 ]]; then
    sgr0=$_ble_term_sgr0
    sgr1=${_ble_term_setaf[2]}
    sgr2=${_ble_term_setaf[1]}$_ble_term_bold
    sgr3=${_ble_term_setaf[4]}$_ble_term_bold
  fi

  local locate=$sgr1${BASH_SOURCE[3]-'(stdin)'}:${BASH_LINENO[2]}$sgr0
  ble/util/print "$locate (bleopt): The option '$sgr2$1$sgr0' has been renamed. Please use '$sgr3$2$sgr0' instead." >&2
  if ble/is-function bleopt/check:"$2"; then
    bleopt/check:"$2"
    return "$?"
  fi
  return 0
}
function bleopt/declare {
  local type=$1 name=bleopt_$2 default_value=$3
  # local set=${!name+set} value=${!name-}
  case $type in
  (-o)
    builtin eval -- "$name='[obsolete: renamed to $3]'"
    builtin eval -- "function bleopt/check:$2 { bleopt/declare/.check-renamed-option $2 $3; }"
    builtin eval -- "function bleopt/obsolete:$2 { :; }" ;;
  (-n)
    builtin eval -- "_ble_opt_def_$2=\$3"
    builtin eval -- ": \"\${$name:=\$default_value}\"" ;;
  (*)
    builtin eval -- "_ble_opt_def_$2=\$3"
    builtin eval -- ": \"\${$name=\$default_value}\"" ;;
  esac
  return 0
}
function bleopt/reinitialize {
  local name=$1
  local defname=_ble_opt_def_$name
  local varname=bleopt_$name
  [[ ${!defname+set} ]] || return 1
  [[ ${!varname} == "${!defname}" ]] && return 0
  ble/is-function bleopt/obsolete:"$name" && return 0
  ble/is-function bleopt/check:"$name" || return 0

  # 一旦値を既定値に戻して改めてチェックを行う。
  local value=${!varname}
  builtin eval -- "$varname=\$$defname"
  bleopt/check:"$name" &&
    builtin eval "$varname=\$value"
}

## @bleopt input_encoding
bleopt/declare -n input_encoding UTF-8
function bleopt/check:input_encoding {
  if ! ble/is-function "ble/encoding:$value/decode"; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'." \
                 "A function 'ble/encoding:$value/decode' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/b2c"; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'." \
                 "A function 'ble/encoding:$value/b2c' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/c2bc"; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'." \
                 "A function 'ble/encoding:$value/c2bc' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/generate-binder"; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'." \
                 "A function 'ble/encoding:$value/generate-binder' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/is-intermediate"; then
    ble/util/print "bleopt: Invalid value input_encoding='$value'." \
                 "A function 'ble/encoding:$value/is-intermediate' is not defined." >&2
    return 1
  fi

  # Note: ble/encoding:$value/clear は optional な設定である。

  if [[ $bleopt_input_encoding != "$value" ]]; then
    local bleopt_input_encoding=$value
    ble/decode/rebind
  fi
  return 0
}

## @bleopt internal_stackdump_enabled
##   エラーが起こった時に関数呼出の構造を標準エラー出力に出力するかどうかを制御する。
##   算術式評価によって非零の値になる場合にエラーを出力する。
##   それ以外の場合にはエラーを出力しない。
bleopt/declare -v internal_stackdump_enabled 0

## @bleopt openat_base
##   bash-4.1 未満で exec {var}>foo が使えない時に ble.sh で内部的に fd を割り当てる。
##   この時の fd の base を指定する。bleopt_openat_base, bleopt_openat_base+1, ...
##   という具合に順番に使用される。既定値は 30 である。
bleopt/declare -n openat_base 30

## @bleopt pager
bleopt/declare -v pager ''

## @bleopt editor
bleopt/declare -v editor ''

shopt -s checkwinsize

#------------------------------------------------------------------------------
# util

function ble/util/setexit { return "$1"; }

## @var _ble_util_upvar_setup
## @var _ble_util_upvar
##
##   これらの変数は関数を定義する時に [-v varname] の引数を認識させ、
##   関数の結果を格納する変数名を外部から指定できるようにするのに用いる。
##   使用する際は関数を以下の様に記述する。既定の格納先変数は ret となる。
##
##     function MyFunction {
##       eval "$_ble_util_upvar_setup"
##
##       ret=... # 処理を行い、変数 ret に結果を格納するコード
##               # (途中で return などすると正しく動かない事に注意)
##
##       eval "$_ble_util_upvar"
##     }
##
##   既定の格納先変数を別の名前 (以下の例では arg) にする場合は次の様にする。
##
##     function MyFunction {
##       eval "${_ble_util_upvar_setup//ret/arg}"
##
##       arg=... # 処理を行い、変数 arg に結果を格納するコード
##
##       eval "${_ble_util_upvar//ret/arg}"
##     }
##
_ble_util_upvar_setup='local var=ret ret; [[ $1 == -v ]] && var=$2 && shift 2'
_ble_util_upvar='local "${var%%\[*\]}" && ble/util/upvar "$var" "$ret"'
if ((_ble_bash>=50000)); then
  function ble/util/unlocal {
    if shopt -q localvar_unset; then
      shopt -u localvar_unset
      builtin unset -v "$@"
      shopt -s localvar_unset
    else
      builtin unset -v "$@"
    fi
  }
  function ble/util/upvar { ble/util/unlocal "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
  function ble/util/uparr { ble/util/unlocal "$1" && builtin eval "$1=(\"\${@:2}\")"; }
else
  function ble/util/unlocal { builtin unset -v "$@"; }
  function ble/util/upvar { builtin unset -v "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
  function ble/util/uparr { builtin unset -v "$1" && builtin eval "$1=(\"\${@:2}\")"; }
fi

function ble/util/save-vars {
  local __ble_name __ble_prefix=$1; shift
  for __ble_name; do
    if ble/is-array "$__ble_name"; then
      builtin eval "$__ble_prefix$__ble_name=(\"\${$__ble_name[@]}\")"
    else
      builtin eval "$__ble_prefix$__ble_name=\"\$$__ble_name\""
    fi
  done
}
function ble/util/restore-vars {
  local __ble_name __ble_prefix=$1; shift
  for __ble_name; do
    if ble/is-array "$__ble_prefix$__ble_name"; then
      # Note: bash-4.2 以下では set -u で空配列に対する "${arr[@]}" が失敗す
      # るので ${arr[@]+"${arr[@]}"} とする。
      builtin eval "$__ble_name=(\${$__ble_prefix$__ble_name[@]+\"\${$__ble_prefix$__ble_name[@]}\"})"
    else
      builtin eval "$__ble_name=\"\${$__ble_prefix$__ble_name-}\""
    fi
  done
}

#
# variable, array and strings
#

## @fn ble/variable#get-attr varname
##   指定した変数の属性を取得します。
##   @var[out] attr
if ((_ble_bash>=40400)); then
  function ble/variable#get-attr {
    if [[ $1 == -v ]]; then
      builtin eval -- "$2=\${!3@a}"
    else
      attr=${!1@a}
    fi
  }
  function ble/variable#has-attr { [[ ${!1@a} == *["$2"]* ]]; }
else
  function ble/variable#get-attr {
    if [[ $1 == -v ]]; then
      local __ble_var=$2 __ble_tmp=$3
    else
      local __ble_var=attr __ble_tmp=$1
    fi
    ble/util/assign __ble_tmp 'declare -p "$__ble_tmp" 2>/dev/null'
    local rex='^declare -([a-zA-Z]*)'; [[ $__ble_tmp =~ $rex ]]
    builtin eval -- "$__ble_var=\${BASH_REMATCH[1]-}"
    return 0
  }
  function ble/variable#has-attr {
    local __ble_tmp=$1
    ble/util/assign __ble_tmp 'declare -p "$__ble_tmp" 2>/dev/null'
    local rex='^declare -([a-zA-Z]*)'
    [[ $__ble_tmp =~ $rex && ${BASH_REMATCH[1]} == *["$2"]* ]]
  }
fi
function ble/is-inttype { ble/variable#has-attr "$1" i; }
function ble/is-readonly { ble/variable#has-attr "$1" r; }
function ble/is-transformed { ble/variable#has-attr "$1" luc; }

function ble/variable#is-declared { [[ ${!1+set} ]] || declare -p "$1" &>/dev/null; }
function ble/variable#is-global/.test { ! local "$1"; }
function ble/variable#is-global {
  (builtin readonly "$1"; ble/variable#is-global/.test "$1") 2>/dev/null
}
function ble/variable#copy-state {
  local src=$1 dst=$2
  if [[ ${!src+set} ]]; then
    builtin eval -- "$dst=\${$src}"
  else
    builtin unset -v "$dst[0]" 2>/dev/null || builtin unset -v "$dst"
  fi
}

_ble_array_prototype=()
function ble/array#reserve-prototype {
  local n=$1 i
  for ((i=${#_ble_array_prototype[@]};i<n;i++)); do
    _ble_array_prototype[i]=
  done
}

## @fn ble/is-array arr
##
##   Note: これに関しては様々な実現方法が考えられるが大体余りうまく動かない。
##
##   * ! declare +a arr だと現在の関数のローカル変数の判定になってしまう。
##   * bash-4.2 以降では ! declare -g +a arr を使えるが、
##     これだと呼び出し元の関数で定義されている配列が見えない。
##     というか現在のスコープの配列も見えない。
##   * 今の所は compgen -A arrayvar を用いているが、
##     この方法だと bash-4.3 以降では連想配列も配列と判定され、
##     bash-4.2 以下では連想配列は配列とはならない。
if ((_ble_bash>=40400)); then
  function ble/is-array { [[ ${!1@a} == *a* ]]; }
  function ble/is-assoc { [[ ${!1@a} == *A* ]]; }
else
  function ble/is-array {
    local "decl$1"
    ble/util/assign "decl$1" "declare -p $1" 2>/dev/null || return 1
    local rex='^declare -[b-zA-Z]*a'
    builtin eval "[[ \$decl$1 =~ \$rex ]]"
  }
  function ble/is-assoc {
    local "decl$1"
    ble/util/assign "decl$1" "declare -p $1" 2>/dev/null || return 1
    local rex='^declare -[a-zB-Z]*A'
    builtin eval "[[ \$decl$1 =~ \$rex ]]"
  }
  ((_ble_bash>=40000)) ||
    function ble/is-assoc { false; }
fi

## @fn ble/array#set arr value...
##   配列に値を設定します。
##   Bash 4.4 で arr2=("${arr1[@]}") が遅い問題を回避する為の関数です。
function ble/array#set { builtin eval "$1=(\"\${@:2}\")"; }

## @fn ble/array#push arr value...
if ((_ble_bash>=40000)); then
  function ble/array#push {
    builtin eval "$1+=(\"\${@:2}\")"
  }
elif ((_ble_bash>=30100)); then
  function ble/array#push {
    # Note (workaround Bash 3.1/3.2 bug): #D1198
    #   何故か a=("${@:2}") は IFS に特別な物が設定されていると
    #   "${*:2}" と同じ振る舞いになってしまう。
    IFS=$_ble_term_IFS builtin eval "$1+=(\"\${@:2}\")"
  }
else
  function ble/array#push {
    while (($#>=2)); do
      builtin eval -- "$1[\${#$1[@]}]=\"\$2\""
      set -- "$1" "${@:3}"
    done
  }
fi
## @fn ble/array#pop arr
##   @var[out] ret
function ble/array#pop {
  builtin eval "local i$1=\$((\${#$1[@]}-1))"
  if ((i$1>=0)); then
    builtin eval "ret=\${$1[i$1]}"
    builtin unset -v "$1[i$1]"
    return 0
  else
    ret=
    return 1
  fi
}
## @fn ble/array#unshift arr value...
function ble/array#unshift {
  builtin eval -- "$1=(\"\${@:2}\" \"\${$1[@]}\")"
}
## @fn ble/array#shift arr count
function ble/array#shift {
  # Note: Bash 4.3 以下では ${arr[@]:${2:-1}} が offset='${2'
  # length='-1' に解釈されるので、先に算術式展開させる。
  builtin eval -- "$1=(\"\${$1[@]:$((${2:-1}))}\")"
}
## @fn ble/array#reverse arr
function ble/array#reverse {
  builtin eval "
  set -- \"\${$1[@]}\"; $1=()
  local e$1 i$1=\$#
  for e$1; do $1[--i$1]=\"\$e$1\"; done"
}

## @fn ble/array#insert-at arr index elements...
function ble/array#insert-at {
  builtin eval "$1=(\"\${$1[@]::$2}\" \"\${@:3}\" \"\${$1[@]:$2}\")"
}
## @fn ble/array#insert-after arr needle elements...
function ble/array#insert-after {
  local _ble_local_script='
    local iARR=0 eARR aARR=
    for eARR in "${ARR[@]}"; do
      ((iARR++))
      [[ $eARR == "$2" ]] && aARR=iARR && break
    done
    [[ $aARR ]] && ble/array#insert-at "$1" "$aARR" "${@:3}"
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#insert-before arr needle elements...
function ble/array#insert-before {
  local _ble_local_script='
    local iARR=0 eARR aARR=
    for eARR in "${ARR[@]}"; do
      [[ $eARR == "$2" ]] && aARR=iARR && break
      ((iARR++))
    done
    [[ $aARR ]] && ble/array#insert-at "$1" "$aARR" "${@:3}"
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#filter arr predicate
##   @param[in] predicate
##     When a function name is specified, the target string is passed
##     to the function as the first argument.  Otherwise, the value of
##     PREDICATE is treated as a command string where the argument can
##     be referenced as $1.
function ble/array#filter/.eval {
  builtin eval -- "$_ble_local_predicate_cmd"
}
function ble/array#filter {
  local _ble_local_predicate=$2
  if [[ $2 == *'$'* ]] || ! ble/is-function "$2"; then
    _ble_local_predicate=ble/array#filter/.eval
    _ble_local_predicate_cmd=$2
  fi

  local _ble_local_script='
    local -a aARR=() eARR
    for eARR in "${ARR[@]}"; do
      "$_ble_local_predicate" "$eARR" && ble/array#push "aARR" "$eARR"
    done
    ARR=("${aARR[@]}")
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
function ble/array#filter/not.predicate { ! "$_ble_local_pred" "$1"; }
function ble/array#remove-if {
  local _ble_local_pred=$2
  ble/array#filter "$1" ble/array#filter/not.predicate
}
## @fn ble/array#filter-by-regex arr regex
function ble/array#filter/regex.predicate { [[ $1 =~ $_ble_local_rex ]]; }
function ble/array#filter-by-regex {
  local _ble_local_rex=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#filter "$1" ble/array#filter/regex.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#remove-by-regex {
  local _ble_local_rex=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#remove-if "$1" ble/array#filter/regex.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#filter/glob.predicate { [[ $1 == $_ble_local_glob ]]; }
function ble/array#filter-by-glob {
  local _ble_local_glob=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#filter "$1" ble/array#filter/glob.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
function ble/array#remove-by-glob {
  local _ble_local_glob=$2
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/array#remove-if "$1" ble/array#filter/glob.predicate
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}
## @fn ble/array#remove arr element
function ble/array#remove/.predicate { [[ $1 != "$_ble_local_value" ]]; }
function ble/array#remove {
  local _ble_local_value=$2
  ble/array#filter "$1" ble/array#remove/.predicate
}
## @fn ble/array#index arr needle
##   @var[out] ret
function ble/array#index {
  local _ble_local_script='
    local eARR iARR=0
    for eARR in "${ARR[@]}"; do
      if [[ $eARR == "$2" ]]; then ret=$iARR; return 0; fi
      ((++iARR))
    done
    ret=-1; return 1
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#last-index arr needle
##   @var[out] ret
function ble/array#last-index {
  local _ble_local_script='
    local eARR iARR=${#ARR[@]}
    while ((iARR--)); do
      [[ ${ARR[iARR]} == "$2" ]] && { ret=$iARR; return 0; }
    done
    ret=-1; return 1
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#remove-at arr index
function ble/array#remove-at {
  local _ble_local_script='
    builtin unset -v "ARR[$2]"
    ARR=("${ARR[@]}")
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
function ble/array#fill-range {
  ble/array#reserve-prototype "$(($3-$2))"
  local _ble_script='
      local -a sARR; sARR=("${_ble_array_prototype[@]::$3-$2}")
      ARR=("${ARR[@]::$2}" "${sARR[@]/#/$4}" "${ARR[@]:$3}")' # WA #D1570 #D1738 checked
  ((_ble_bash>=40300)) && ! shopt -q compat42 &&
    _ble_script=${_ble_script//'$4'/'"$4"'}
  builtin eval -- "${_ble_script//ARR/$1}"
}
## @fn ble/idict#replace arr needle [replacement]
##   needle に一致する要素を全て replacement に置換します。
##   replacement が指定されていない時は該当要素を unset します。
##   @var[in] arr
##   @var[in] needle
##   @var[in,opt] replacement
function ble/idict#replace {
  local _ble_local_script='
    local iARR=0 extARR=1
    for iARR in "${!ARR[@]}"; do
      [[ ${ARR[iARR]} == "$2" ]] || continue
      extARR=0
      if (($#>=3)); then
        ARR[iARR]=$3
      else
        builtin unset -v '\''ARR[iARR]'\''
      fi
    done
    return "$extARR"
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}

function ble/idict#copy {
  local _ble_script='
    '$1'=()
    local i'$1$2'
    for i'$1$2' in "${!'$2'[@]}"; do
      '$1'[i'$1$2']=${'$2'[i'$1$2']}
    done'
  builtin eval -- "$_ble_script"
}

_ble_string_prototype='        '
function ble/string#reserve-prototype {
  local n=$1 c
  for ((c=${#_ble_string_prototype};c<n;c*=2)); do
    _ble_string_prototype=$_ble_string_prototype$_ble_string_prototype
  done
}

## @fn ble/string#repeat str count
##   @param[in] str
##   @param[in] count
##   @var[out] ret
function ble/string#repeat {
  ble/string#reserve-prototype "$2"
  ret=${_ble_string_prototype::$2}
  ret=${ret// /"$1"}
}

## @fn ble/string#common-prefix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-prefix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b::${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return 0
  fi

  # l <= 解 < u, (${a:u}: 一致しない, ${a:l} 一致する)
  local l=0 u=${#a} m
  while ((l+1<u)); do
    ((m=(l+u)/2))
    if [[ ${a::m} == "${b::m}" ]]; then
      ((l=m))
    else
      ((u=m))
    fi
  done

  ret=${a::l}
}

## @fn ble/string#common-suffix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-suffix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b:${#b}-${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return 0
  fi

  # l < 解 <= u, (${a:l}: 一致しない, ${a:u} 一致する)
  local l=0 u=${#a} m
  while ((l+1<u)); do
    ((m=(l+u+1)/2))
    if [[ ${a:m} == "${b:m}" ]]; then
      ((u=m))
    else
      ((l=m))
    fi
  done

  ret=${a:u}
}

## @fn ble/string#split arr sep str...
##   文字列を分割します。
##   空白類を分割に用いた場合は、空要素は削除されます。
##
##   @param[out] arr 分割した文字列を格納する配列名を指定します。
##   @param[in]  sep 分割に使用する文字を指定します。
##   @param[in]  str 分割する文字列を指定します。
##
function ble/string#split {
  local IFS=$2
  if [[ -o noglob ]]; then
    # Note: 末尾の sep が無視されない様に、末尾に手で sep を 1 個追加している。
    builtin eval "$1=(\$3\$2)"
  else
    set -f
    builtin eval "$1=(\$3\$2)"
    set +f
  fi
}
function ble/string#split-words {
  local IFS=$_ble_term_IFS
  if [[ -o noglob ]]; then
    builtin eval "$1=(\$2)"
  else
    set -f
    builtin eval "$1=(\$2)"
    set +f
  fi
}
## @fn ble/string#split-lines arr text
##   文字列を行に分割します。空行も省略されません。
##
##   @param[out] arr  分割した文字列を格納する配列名を指定します。
##   @param[in]  text 分割する文字列を指定します。
##   @var[out] ret
##
if ((_ble_bash>=40000)); then
  function ble/string#split-lines {
    mapfile -t "$1" <<< "$2"
  }
else
  function ble/string#split-lines {
    ble/util/mapfile "$1" <<< "$2"
  }
fi
## @fn ble/string#count-char text chars
##   @param[in] text
##   @param[in] chars
##     検索対象の文字の集合を指定します。
##   @var[out] ret
function ble/string#count-char {
  local text=$1 char=$2
  text=${text//[!"$char"]}
  ret=${#text}
}

## @fn ble/string#count-string text string
##   @var[out] ret
function ble/string#count-string {
  local text=${1//"$2"}
  ((ret=(${#1}-${#text})/${#2}))
}

## @fn ble/string#index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     この引数を指定したとき n 番目の一致を検索します。
##   @var[out] ret
##     一致した場合に見つかった位置を返します。
##     見つからなかった場合に -1 を返します。
##   @exit
##     一致した場合に成功し、見つからなかった場合に失敗します。
function ble/string#index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '*"$needle"' "$count"; local pattern=$ret
  builtin eval "local transformed=\${haystack#$pattern}"
  ((ret=${#haystack}-${#transformed}-${#needle},
    ret<0&&(ret=-1),ret>=0))
}

## @fn ble/string#last-index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     この引数を指定したとき n 番目の一致を検索します。
##   @var[out] ret
function ble/string#last-index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '"$needle"*' "$count"; local pattern=$ret
  builtin eval "local transformed=\${haystack%$pattern}"
  if [[ $transformed == "$haystack" ]]; then
    ret=-1
  else
    ret=${#transformed}
  fi
  ((ret>=0))
}

## @fn ble/string#toggle-case text
## @fn ble/string#toupper text
## @fn ble/string#tolower text
##   @param[in] text
##   @var[out] ret
_ble_util_string_lower_list=abcdefghijklmnopqrstuvwxyz
_ble_util_string_upper_list=ABCDEFGHIJKLMNOPQRSTUVWXYZ
function ble/string#toggle-case.impl {
  local LC_ALL= LC_COLLATE=C
  local text=$1 ch i
  local -a buff
  for ((i=0;i<${#text};i++)); do
    ch=${text:i:1}
    if [[ $ch == [A-Z] ]]; then
      ch=${_ble_util_string_upper_list%%"$ch"*}
      ch=${_ble_util_string_lower_list:${#ch}:1}
    elif [[ $ch == [a-z] ]]; then
      ch=${_ble_util_string_lower_list%%"$ch"*}
      ch=${_ble_util_string_upper_list:${#ch}:1}
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]-}"'
}
function ble/string#toggle-case {
  ble/string#toggle-case.impl "$1" 2>/dev/null # suppress locale error #D1440
}
## @fn ble/string#tolower text
## @fn ble/string#toupper text
##   @var[out] ret
if ((_ble_bash>=40000)); then
  function ble/string#tolower { ret=${1,,}; }
  function ble/string#toupper { ret=${1^^}; }
else
  function ble/string#tolower.impl {
    local LC_ALL= LC_COLLATE=C
    local i text=$1 ch
    local -a buff=()
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if [[ $ch == [A-Z] ]]; then
        ch=${_ble_util_string_upper_list%%"$ch"*}
        ch=${_ble_util_string_lower_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= builtin eval 'ret="${buff[*]-}"'
  }
  function ble/string#toupper.impl {
    local LC_ALL= LC_COLLATE=C
    local i text=$1 ch
    local -a buff=()
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if [[ $ch == [a-z] ]]; then
        ch=${_ble_util_string_lower_list%%"$ch"*}
        ch=${_ble_util_string_upper_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= builtin eval 'ret="${buff[*]-}"'
  }
  function ble/string#tolower {
    ble/string#tolower.impl "$1" 2>/dev/null # suppress locale error #D1440
  }
  function ble/string#toupper {
    ble/string#toupper.impl "$1" 2>/dev/null # suppress locale error #D1440
  }
fi

function ble/string#capitalize {
  local tail=$1

  # prefix
  local rex='^[^a-zA-Z0-9]*'
  [[ $tail =~ $rex ]]
  local out=$BASH_REMATCH
  tail=${tail:${#BASH_REMATCH}}

  # words
  rex='^[a-zA-Z0-9]+[^a-zA-Z0-9]*'
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    ble/string#toupper "${rematch::1}"; out=$out$ret
    ble/string#tolower "${rematch:1}" ; out=$out$ret
    tail=${tail:${#rematch}}
  done
  ret=$out$tail
}

## @fn ble/string#trim text
##   @var[out] ret
function ble/string#trim {
  ret=$1
  local rex=$'^[ \t\n]+'
  [[ $ret =~ $rex ]] && ret=${ret:${#BASH_REMATCH}}
  local rex=$'[ \t\n]+$'
  [[ $ret =~ $rex ]] && ret=${ret::${#ret}-${#BASH_REMATCH}}
}
## @fn ble/string#ltrim text
##   @var[out] ret
function ble/string#ltrim {
  ret=$1
  local rex=$'^[ \t\n]+'
  [[ $ret =~ $rex ]] && ret=${ret:${#BASH_REMATCH}}
}
## @fn ble/string#rtrim text
##   @var[out] ret
function ble/string#rtrim {
  ret=$1
  local rex=$'[ \t\n]+$'
  [[ $ret =~ $rex ]] && ret=${ret::${#ret}-${#BASH_REMATCH}}
}

## @fn ble/string#escape-characters text chars1 [chars2]
##   @param[in]     text
##   @param[in]     chars1
##   @param[in,opt] chars2
##   @var[out] ret
if ((_ble_bash>=50200)); then
  function ble/string#escape-characters {
    ret=$1
    if [[ $ret == *["$2"]* ]]; then
      if [[ ! $3 ]]; then
        local patsub_replacement=
        shopt -q patsub_replacement && patsub_replacement=1
        shopt -s patsub_replacement
        ret=${ret//["$2"]/\\&} # #D1738 patsub_replacement
        [[ $patsub_replacement ]] || shopt -u patsub_replacement
      else
        local chars1=$2 chars2=${3:-$2}
        local i n=${#chars1} a b
        for ((i=0;i<n;i++)); do
          a=${chars1:i:1} b=\\${chars2:i:1} ret=${ret//"$a"/"$b"}
        done
      fi
    fi
  }
else
  function ble/string#escape-characters {
    ret=$1
    if [[ $ret == *["$2"]* ]]; then
      local chars1=$2 chars2=${3:-$2}
      local i n=${#chars1} a b
      for ((i=0;i<n;i++)); do
        a=${chars1:i:1} b=\\${chars2:i:1} ret=${ret//"$a"/"$b"}
      done
    fi
  }
fi


## @fn ble/string#escape-for-sed-regex text
## @fn ble/string#escape-for-awk-regex text
## @fn ble/string#escape-for-extended-regex text
## @fn ble/string#escape-for-bash-glob text
## @fn ble/string#escape-for-bash-single-quote text
## @fn ble/string#escape-for-bash-double-quote text
## @fn ble/string#escape-for-bash-escape-string text
##   @param[in] text
##   @var[out] ret
function ble/string#escape-for-sed-regex {
  ble/string#escape-characters "$1" '\.[*^$/'
}
function ble/string#escape-for-awk-regex {
  ble/string#escape-characters "$1" '\.[*?+|^$(){}/'
}
function ble/string#escape-for-extended-regex {
  ble/string#escape-characters "$1" '\.[*?+|^$(){}'
}
function ble/string#escape-for-bash-glob {
  ble/string#escape-characters "$1" '\*?[('
}
function ble/string#escape-for-bash-single-quote {
  local q="'" Q="'\''"
  ret=${1//$q/$Q}
}
function ble/string#escape-for-bash-double-quote {
  ble/string#escape-characters "$1" '\"$`'
  local a b
  a='!' b='"\!"' ret=${ret//"$a"/"$b"} # WA #D1751 checked
}
function ble/string#escape-for-bash-escape-string {
  ble/string#escape-characters "$1" $'\\\a\b\e\f\n\r\t\v'\' '\abefnrtv'\'
}
## @fn ble/string#escape-for-bash-specialchars text flags
##   @param[in] text
##   @param[in] flags
##     c 単語中でチルダ展開を誘導する文字をエスケープします。
##     b ブレース展開の文字もエスケープします。
##     H 語頭の #, ~ のエスケープをしません。
##     T 語頭のチルダのエスケープをしません。
##     G グロブ文字をエスケープしません。
##   @var[out] ret
function ble/string#escape-for-bash-specialchars {
  local chars='\ "'\''`$|&;<>()!^'
  # Note: = と : は文法的にはエスケープは不要だが
  #   補完の際の COMP_WORDBREAKS を避ける為に必要である。
  [[ $2 != *G* ]] && chars=$chars'*?['
  [[ $2 == *c* ]] && chars=$chars'=:'
  [[ $2 == *b* ]] && chars=$chars'{,}'
  ble/string#escape-characters "$1" "$chars"
  [[ $2 != *[HT]* && $ret == '~'* ]] && ret=\\$ret
  [[ $2 != *H* && $ret == '#'* ]] && ret=\\$ret
  if [[ $ret == *[$']\n\t']* ]]; then
    local a b
    a=']'   b=\\$a     ret=${ret//"$a"/"$b"}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/"$b"} # WA #D1751 checked
    a=$'\t' b=$'\\\t'  ret=${ret//"$a"/"$b"}
  fi

  # 上の処理で extglob の ( も quote されてしまうので G の時には戻す。
  if [[ $2 == *G* ]] && shopt -q extglob; then
    local a b
    a='!\(' b='!(' ret=${ret//"$a"/"$b"}
    a='@\(' b='@(' ret=${ret//"$a"/"$b"}
    a='?\(' b='?(' ret=${ret//"$a"/"$b"}
    a='*\(' b='*(' ret=${ret//"$a"/"$b"}
    a='+\(' b='+(' ret=${ret//"$a"/"$b"}
  fi
}

## @fn ble/string#escape-for-display str [opts]
##   str に含まれる制御文字を ^A などのキャレット表記に置き換えます。
##
##   @param[in] str
##   @param[in] opts
##     revert
##       キャレット表記を反転表示します。
##     sgr1=*
##       キャレット表記に用いる SGR シーケンスを指定します。
##       キャレット表記の開始に挿入されます。
##     sgr0=*
##       キャレット表記以外の部分に用いる地の SGR シーケンスを指定します。
##       キャレット表記の終端に挿入されます。
##
function ble/string#escape-for-display {
  local head= tail=$1 opts=$2

  local sgr0= sgr1=
  local rex_csi=$'\e\\[[ -?]*[@-~]'
  if [[ :$opts: == *:revert:* ]]; then
    ble/color/g2sgr "$_ble_color_gflags_Revert"
    sgr1=$ret sgr0=$_ble_term_sgr0
  else
    if local rex=':sgr1=(('$rex_csi'|[^:])*):'; [[ :$opts: =~ $rex ]]; then
      sgr1=${BASH_REMATCH[1]} sgr0=$_ble_term_sgr0
    fi
    if local rex=':sgr0=(('$rex_csi'|[^:])*):'; [[ :$opts: =~ $rex ]]; then
      sgr0=${BASH_REMATCH[1]}
    fi
  fi

  while [[ $tail ]]; do
    if ble/util/isprint+ "$tail"; then
      head=$head${BASH_REMATCH}
      tail=${tail:${#BASH_REMATCH}}
    else
      ble/util/s2c "${tail::1}"
      local code=$ret
      if ((code<32)); then
        ble/util/c2s "$((code+64))"
        ret=$sgr1^$ret$sgr0
      elif ((code==127)); then
        ret=$sgr1^?$sgr0
      elif ((128<=code&&code<160)); then
        ble/util/c2s "$((code-64))"
        ret=${sgr1}M-^$ret$sgr0
      else
        ret=${tail::1}
      fi
      head=$head$ret
      tail=${tail:1}
    fi
  done
  ret=$head
}

if ((_ble_bash>=40400)); then
  function ble/string#quote-words {
    local IFS=$_ble_term_IFS
    ret="${*@Q}"
  }
  function ble/string#quote-command {
    local IFS=$_ble_term_IFS
    ret=$1; shift
    (($#)) && ret="$ret ${*@Q}"
  }
else
  function ble/string#quote-words {
    local q=\' Q="'\''" IFS=$_ble_term_IFS
    ret=("${@//$q/$Q}")
    ret=("${ret[@]/%/$q}") # WA #D1570 #D1738 checked
    ret="${ret[*]/#/$q}"   # WA #D1570 #D1738 checked
  }
  function ble/string#quote-command {
    if (($#<=1)); then
      ret=$1
      return 0
    fi
    local q=\' Q="'\''" IFS=$_ble_term_IFS
    ret=("${@:2}")
    ret=("${ret[@]//$q/$Q}")  # WA #D1570 #D1738 checked
    ret=("${ret[@]/%/$q}")    # WA #D1570 #D1738 checked
    ret="$1 ${ret[*]/#/$q}"   # WA #D1570 #D1738 checked
  }
fi
## @fn ble/string#quote-word text opts
function ble/string#quote-word {
  ret=${1-}

  local rex_csi=$'\e\\[[ -?]*[@-~]'
  local opts=${2-} sgrq= sgr0=
  if [[ $opts ]]; then
    local rex=':sgrq=(('$rex_csi'|[^:])*):'
    if [[ :$opts: =~ $rex ]]; then
      sgrq=${BASH_REMATCH[1]} sgr0=$_ble_term_sgr0
    fi
    rex=':sgr0=(('$rex_csi'|[^:])*):'
    if [[ :$opts: =~ $rex ]]; then
      sgr0=${BASH_REMATCH[1]}
    elif [[ :$opts: == *:ansi:* ]]; then
      sgr0=$'\e[m'
    fi
  fi

  if [[ ! $ret ]]; then
    if [[ :$opts: == *:quote-empty:* ]]; then
      ret=$sgrq\'\'$sgr0
    fi
    return 0
  fi

  local chars=$'\a\b\e\f\n\r\t\v'
  if [[ $ret == *["$chars"]* ]]; then
    ble/string#escape-for-bash-escape-string "$ret"
    ret=$sgrq\$\'$ret\'$sgr0
    return 0
  fi

  local chars=$_ble_term_IFS'"`$\<>()|&;*?[]!^=:{,}#~' q=\'
  if [[ $ret == *["$chars"]* ]]; then
    local Q="'$sgr0\'$sgrq'"
    ret=$sgrq$q${ret//$q/$Q}$q$sgr0
    ret=${ret#"$sgrq$q$q$sgr0"} ret=${ret%"$sgrq$q$q$sgr0"}
  elif [[ $ret == *["$q"]* ]]; then
    local Q="\'"
    ret=${ret//$q/$Q}
  fi
}

function ble/string#match { [[ $1 =~ $2 ]]; }

## @fn ble/string#create-unicode-progress-bar/.block value
##   @var[out] ret
function ble/string#create-unicode-progress-bar/.block {
  local block=$1
  if ((block<=0)); then
    ble/util/c2w "$((0x2588))"
    ble/string#repeat ' ' "$ret"
  elif ((block>=8)); then
    ble/util/c2s "$((0x2588))"
    ((${#ret}==1)) || ret='*' # LC_CTYPE が非対応の文字の時
  else
    ble/util/c2s "$((0x2590-block))"
    if ((${#ret}!=1)); then
      # LC_CTYPE が非対応の文字の時
      ble/util/c2w "$((0x2588))"
      ble/string#repeat ' ' "$((ret-1))"
      ret=$block$ret
    fi
  fi
}

## @fn ble/string#create-unicode-progress-bar value max width opts
##   @param[in] opts
##     unlimited ... 上限が不明である事を示します。
##   @var[out] ret
function ble/string#create-unicode-progress-bar {
  local value=$1 max=$2 width=$3 opts=:$4:

  local opt_unlimited=
  if [[ $opts == *:unlimited:* ]]; then
    opt_unlimited=1
    ((value%=max,width--))
  fi

  local progress=$((value*8*width/max))
  local progress_fraction=$((progress%8)) progress_integral=$((progress/8))

  local out=
  if ((progress_integral)); then
    if [[ $opt_unlimited ]]; then
      # unlimited の時は左は空白
      ble/string#create-unicode-progress-bar/.block 0
    else
      ble/string#create-unicode-progress-bar/.block 8
    fi
    ble/string#repeat "$ret" "$progress_integral"
    out=$ret
  fi

  if ((progress_fraction)); then
    if [[ $opt_unlimited ]]; then
      # unlimited の時は2升を使って位置を表す
      ble/string#create-unicode-progress-bar/.block "$progress_fraction"
      out=$out$'\e[7m'$ret$'\e[27m'
    fi

    ble/string#create-unicode-progress-bar/.block "$progress_fraction"
    out=$out$ret
    ((progress_integral++))
  else
    if [[ $opt_unlimited ]]; then
      ble/string#create-unicode-progress-bar/.block 8
      out=$out$ret
    fi
  fi

  if ((progress_integral<width)); then
    ble/string#create-unicode-progress-bar/.block 0
    ble/string#repeat "$ret" "$((width-progress_integral))"
    out=$out$ret
  fi

  ret=$out
}
# Note: Bash-4.1 以下では "LC_CTYPE=C 組み込みコマンド" の形式だと
#   locale がその場で適用されないバグがある。
function ble/util/strlen.impl {
  local LC_ALL= LC_CTYPE=C
  ret=${#1}
}
function ble/util/strlen {
  ble/util/strlen.impl "$@" 2>/dev/null # suppress locale error #D1440
}
function ble/util/substr.impl {
  local LC_ALL= LC_CTYPE=C
  ret=${1:$2:$3}
}
function ble/util/substr {
  ble/util/substr.impl "$@" 2>/dev/null # suppress locale error #D1440
}

function ble/path#append {
  local _ble_local_script='opts=$opts${opts:+:}$2'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#prepend {
  local _ble_local_script='opts=$2${opts:+:}$opts'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#remove {
  [[ $2 ]] || return 1
  local _ble_local_script='
    opts=:${opts//:/::}:
    opts=${opts//:"$2":}
    opts=${opts//::/:} opts=${opts#:} opts=${opts%:}'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#remove-glob {
  [[ $2 ]] || return 1
  local _ble_local_script='
    opts=:${opts//:/::}:
    opts=${opts//:$2:}
    opts=${opts//::/:} opts=${opts#:} opts=${opts%:}'
  _ble_local_script=${_ble_local_script//opts/"$1"}
  builtin eval -- "$_ble_local_script"
}
function ble/path#contains {
  builtin eval "[[ :\${$1}: == *:\"\$2\":* ]]"
}

## @fn ble/opts#has opts key
function ble/opts#has {
  local rex=':'$2'[=:]'
  [[ :$1: =~ $rex ]]
}
## @fn ble/opts#remove opts value
function ble/opts#remove {
  ble/path#remove "$@"
}

## @fn ble/opts#extract-first-optarg opts key [default_value]
function ble/opts#extract-first-optarg {
  ret=
  local rex=':'$2'(=[^:]*)?:'
  [[ :$1: =~ $rex ]] || return 1
  if [[ ${BASH_REMATCH[1]} ]]; then
    ret=${BASH_REMATCH[1]:1}
  elif [[ ${3+set} ]]; then
    ret=$3
  fi
  return 0
}
## @fn ble/opts#extract-last-optarg opts key [default_value]
function ble/opts#extract-last-optarg {
  ret=
  local rex='.*:'$2'(=[^:]*)?:'
  [[ :$1: =~ $rex ]] || return 1
  if [[ ${BASH_REMATCH[1]} ]]; then
    ret=${BASH_REMATCH[1]:1}
  elif [[ ${3+set} ]]; then
    ret=$3
  fi
  return 0
}
## @fn ble/opts#extract-all-optargs opts key [default_value]
##   extract all values from the string OPTS of the form
##   "...:key=value1:...:key=value2:...:key:...".
##
##   @param[in] key
##     This should not include any special characters of regular
##     expressions---preferably composed of [-_[:alnum:]].
##
##   @arr[out] ret
function ble/opts#extract-all-optargs {
  ret=()
  local value=:$1: rex=':'$2'(=[^:]*)?(:.*)$' count=0
  while [[ $value =~ $rex ]]; do
    ((count++))
    if [[ ${BASH_REMATCH[1]} ]]; then
      ble/array#push ret "${BASH_REMATCH[1]:1}"
    elif [[ ${3+set} ]]; then
      ble/array#push ret "$3"
    fi
    value=${BASH_REMATCH[2]}
  done
  ((count))
}

if ((_ble_bash>=40000)); then
  _ble_util_set_declare=(declare -A NAME)
  function ble/set#add { builtin eval -- "$1[x\$2]=1"; }
  function ble/set#remove { builtin unset -v "$1[x\$2]"; }
  function ble/set#contains { builtin eval "[[ \${$1[x\$2]+set} ]]"; }
else
  _ble_util_set_declare=(declare NAME)
  function ble/set#.escape {
    _ble_local_value=${_ble_local_value//$_ble_term_FS/"$_ble_term_FS$_ble_term_FS"}
    _ble_local_value=${_ble_local_value//:/"$_ble_term_FS."}
  }
  function ble/set#add {
    local _ble_local_value=$2; ble/set#.escape
    ble/path#append "$1" "$_ble_local_value"
  }
  function ble/set#remove {
    local _ble_local_value=$2; ble/set#.escape
    ble/path#remove "$1" "$_ble_local_value"
  }
  function ble/set#contains {
    local _ble_local_value=$2; ble/set#.escape
    builtin eval "[[ :\$$1: == *:\"\$_ble_local_value\":* ]]"
  }
fi


#--------------------------------------
# dict

_ble_util_adict_declare='declare NAME NAME_keylist'
## @fn ble/dict#.resolve dict key
function ble/adict#.resolve {
  # _ble_local_key
  _ble_local_key=$2
  _ble_local_key=${_ble_local_key//$_ble_term_FS/"$_ble_term_FS,"}
  _ble_local_key=${_ble_local_key//:/"$_ble_term_FS."}

  local keylist=${1}_keylist; keylist=:${!keylist}
  local vec=${keylist%%:"$_ble_local_key":*}
  if [[ $vec != "$keylist" ]]; then
    vec=${vec//[!:]}
    _ble_local_index=${#vec}
  else
    _ble_local_index=-1
  fi
}
function ble/adict#set {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  if ((_ble_local_index>=0)); then
    builtin eval -- "$1[_ble_local_index]=\$3"
  else
    local _ble_local_script='
      local _ble_local_vec=${NAME_keylist//[!:]}
      NAME[${#_ble_local_vec}]=$3
      NAME_keylist=$NAME_keylist$_ble_local_key:
    '
    builtin eval -- "${_ble_local_script//NAME/$1}"
  fi
  return 0
}
function ble/adict#get {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  if ((_ble_local_index>=0)); then
    builtin eval -- "ret=\${$1[_ble_local_index]}; [[ \${$1[_ble_local_index]+set} ]]"
  else
    builtin eval -- ret=
    return 1
  fi
}
function ble/adict#unset {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  ((_ble_local_index>=0)) &&
    builtin eval -- "builtin unset -v '$1[_ble_local_index]'"
  return 0
}
function ble/adict#has {
  local _ble_local_key _ble_local_index
  ble/adict#.resolve "$1" "$2"
  ((_ble_local_index>=0)) &&
    builtin eval -- "[[ \${$1[_ble_local_index]+set} ]]"
}
function ble/adict#clear {
  builtin eval -- "${1}_keylist= $1=()"
}
function ble/adict#keys {
  local _ble_local_keylist=${1}_keylist
  _ble_local_keylist=${!_ble_local_keylist%:}
  ble/string#split ret : "$_ble_local_keylist"
  if [[ $_ble_local_keylist == *"$_ble_term_FS"* ]]; then
    ret=("${ret[@]//$_ble_term_FS./:}")             # WA #D1570 checked
    ret=("${ret[@]//$_ble_term_FS,/$_ble_term_FS}") # WA #D1570 #D1738 checked
  fi

  # filter out unset elements
  local _ble_local_keys _ble_local_i _ble_local_ref=$1[_ble_local_i]
  _ble_local_keys=("${ret[@]}") ret=()
  for _ble_local_i in "${!_ble_local_keys[@]}"; do
    [[ ${_ble_local_ref+set} ]] &&
      ble/array#push ret "${_ble_local_keys[_ble_local_i]}"
  done
}

if ((_ble_bash>=40000)); then
  _ble_util_dict_declare='declare -A NAME'
  function ble/dict#set   { builtin eval -- "$1[x\$2]=\$3"; }
  function ble/dict#get   { builtin eval -- "ret=\${$1[x\$2]-}; [[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#unset { builtin eval -- "builtin unset -v '$1[x\$2]'"; }
  function ble/dict#has   { builtin eval -- "[[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#clear { builtin eval -- "$1=()"; }
  function ble/dict#keys  { builtin eval -- 'ret=("${!'"$1"'[@]}"); ret=("${ret[@]#x}")'; }
else
  _ble_util_dict_declare='declare NAME NAME_keylist='
  function ble/dict#set   { ble/adict#set   "$@"; }
  function ble/dict#get   { ble/adict#get   "$@"; }
  function ble/dict#unset { ble/adict#unset "$@"; }
  function ble/dict#has   { ble/adict#has   "$@"; }
  function ble/dict#clear { ble/adict#clear "$@"; }
  function ble/dict#keys  { ble/adict#keys  "$@"; }
fi

if ((_ble_bash>=40200)); then
  _ble_util_gdict_declare='{ builtin unset -v NAME; declare -gA NAME; NAME=(); }'
  function ble/gdict#set   { ble/dict#set   "$@"; }
  function ble/gdict#get   { ble/dict#get   "$@"; }
  function ble/gdict#unset { ble/dict#unset "$@"; }
  function ble/gdict#has   { ble/dict#has   "$@"; }
  function ble/gdict#clear { ble/dict#clear "$@"; }
  function ble/gdict#keys  { ble/dict#keys  "$@"; }
elif ((_ble_bash>=40000)); then
  _ble_util_gdict_declare='{ if ! ble/is-assoc NAME; then if local _ble_local_test 2>/dev/null; then NAME_keylist=; else builtin unset -v NAME NAME_keylist; declare -A NAME; fi fi; NAME=(); }'
  function ble/gdict#.is-adict {
    local keylist=${1}_keylist
    [[ ${!keylist+set} ]]
  }
  function ble/gdict#set   { if ble/gdict#.is-adict "$1"; then ble/adict#set   "$@"; else ble/dict#set   "$@"; fi; }
  function ble/gdict#get   { if ble/gdict#.is-adict "$1"; then ble/adict#get   "$@"; else ble/dict#get   "$@"; fi; }
  function ble/gdict#unset { if ble/gdict#.is-adict "$1"; then ble/adict#unset "$@"; else ble/dict#unset "$@"; fi; }
  function ble/gdict#has   { if ble/gdict#.is-adict "$1"; then ble/adict#has   "$@"; else ble/dict#has   "$@"; fi; }
  function ble/gdict#clear { if ble/gdict#.is-adict "$1"; then ble/adict#clear "$@"; else ble/dict#clear "$@"; fi; }
  function ble/gdict#keys  { if ble/gdict#.is-adict "$1"; then ble/adict#keys  "$@"; else ble/dict#keys  "$@"; fi; }
else
  _ble_util_gdict_declare='{ builtin unset -v NAME NAME_keylist; NAME_keylist= NAME=(); }'
  function ble/gdict#set   { ble/adict#set   "$@"; }
  function ble/gdict#get   { ble/adict#get   "$@"; }
  function ble/gdict#unset { ble/adict#unset "$@"; }
  function ble/gdict#has   { ble/adict#has   "$@"; }
  function ble/gdict#clear { ble/adict#clear "$@"; }
  function ble/gdict#keys  { ble/adict#keys  "$@"; }
fi


function ble/dict/.print {
  declare -p "$2" &>/dev/null || return 1
  local ret _ble_local_key _ble_local_value

  ble/util/print "builtin eval -- \"\${_ble_util_${1}_declare//NAME/$2}\""
  ble/"$1"#keys "$2"
  for _ble_local_key in "${ret[@]}"; do
    ble/"$1"#get "$2" "$_ble_local_key"
    ble/string#quote-word "$ret" quote-empty
    _ble_local_value=$ret

    ble/string#quote-word "$_ble_local_key" quote-empty
    _ble_local_key=$ret

    ble/util/print "ble/$1#set $2 $_ble_local_key $_ble_local_value"
  done
}
function ble/dict#print { ble/dict/.print dict "$1"; }
function ble/adict#print { ble/dict/.print adict "$1"; }
function ble/gdict#print { ble/dict/.print gdict "$1"; }

function ble/dict/.copy {
  local ret
  ble/"$1"#keys "$2"
  ble/"$1"#clear "$3"
  local _ble_local_key
  for _ble_local_key in "${ret[@]}"; do
    ble/"$1"#get "$2" "$_ble_local_key"
    ble/"$1"#set "$3" "$_ble_local_key" "$ret"
  done
}
function ble/dict#cp { ble/dict/.copy dict "$1" "$2"; }
function ble/adict#cp { ble/dict/.copy adict "$1" "$2"; }
function ble/gdict#cp { ble/dict/.copy gdict "$1" "$2"; }

#------------------------------------------------------------------------------
# assign: reading files/streams into variables
#

## @fn ble/util/readfile var filename
## @fn ble/util/mapfile arr < filename
##   ファイルの内容を変数または配列に読み取ります。
##
##   @param[in] var
##     読み取った内容の格納先の変数名を指定します。
##   @param[in] arr
##     読み取った内容を行毎に格納する配列の名前を指定します。
##   @param[in] filename
##     読み取るファイルの場所を指定します。
##
## Note: bash-5.2 以上で $(< file) を使う可能性も考えたが、末尾改行が
##   消えてしまう事、末尾改行を未定義にしてまで使う程の速度差もない事、
##   などから採用は見送る事にした。
if ((_ble_bash>=40000)); then
  function ble/util/readfile { # 155ms for man bash
    local -a _ble_local_buffer=()
    mapfile _ble_local_buffer < "$2"; local _ble_local_ext=$?
    IFS= builtin eval "$1=\"\${_ble_local_buffer[*]-}\""
    return "$_ble_local_ext"
  }
  function ble/util/mapfile {
    mapfile -t "$1"
  }
else
  function ble/util/readfile { # 465ms for man bash
    [[ -r $2 && ! -d $2 ]] || return 1
    local IFS=
    ble/bash/read -d '' "$1" < "$2"
    return 0
  }
  function ble/util/mapfile {
    local IFS=
    local _ble_local_i=0 _ble_local_val _ble_local_arr; _ble_local_arr=()
    while ble/bash/read _ble_local_val || [[ $_ble_local_val ]]; do
      _ble_local_arr[_ble_local_i++]=$_ble_local_val
    done
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
  }
fi

function ble/util/copyfile {
  local src=$1 dst=$2 content
  ble/util/readfile content "$1" || return "$?"
  ble/util/put "$content" >| "$dst"
}

## @fn ble/util/writearray [OPTIONS] arr
##   配列の内容を読み出し可能な形式で出力します。
##
## OPTIONS
##   --       以降の引数は通常引数
##   -d delim 配列要素を区切るのに使う文字を設定します。
##            既定値は改行 "\n" です。
##   --nlfix  改行区切りで出力します。要素に改行が含まれる時は $'' を用
##            いて内容をエスケープします。改行が含まれる要素番号の一覧
##            を一番最後の要素に追加します。
##
function ble/util/writearray/.read-arguments {
  _ble_local_array=
  _ble_local_nlfix=
  _ble_local_delim=$'\n'
  local flags=
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != *-* && $arg == -* ]]; then
      case $arg in
      (--nlfix) _ble_local_nlfix=1 ;;
      (-d)
        if (($#)); then
          _ble_local_delim=$1; shift
        else
          ble/util/print "${FUNCNAME[1]}: '$arg': missing option argument." >&2
          flags=E$flags
        fi ;;
      (--) flags=-$flags ;;
      (*)
        ble/util/print "${FUNCNAME[1]}: '$arg': unrecognized option." >&2
        flags=E$flags ;;
      esac
    else
      if local rex='^[_a-zA-Z][_a-zA-Z0-9]*$'; ! [[ $arg =~ $rex ]]; then
        ble/util/print "${FUNCNAME[1]}: '$arg': invalid array name." >&2
        flags=E$flags
      elif [[ $flags == *A* ]]; then
        ble/util/print "${FUNCNAME[1]}: '$arg': an array name has been already specified." >&2
        flags=E$flags
      else
        _ble_local_array=$arg
        flags=A$flags
      fi
    fi
  done
  [[ $_ble_local_nlfix ]] && _ble_local_delim=$'\n'
  [[ $flags != *E* ]]
}

_ble_bin_awk_libES='
  function s2i_initialize(_, i) {
    for (i = 0; i < 16; i++)
      xdigit2int[sprintf("%x", i)] = i;
    for (i = 10; i < 16; i++)
      xdigit2int[sprintf("%X", i)] = i;
  }
  function s2i(s, base, _, i, n, r) {
    if (!base) base = 10;
    r = 0;
    n = length(s);
    for (i = 1; i <= n; i++)
      r = r * base + xdigit2int[substr(s, i, 1)];
    return r;
  }

  # ENCODING: UTF-8
  function c2s_initialize(_, i, n, buff) {
    if (sprintf("%c", 945) == "α") {
      C2S_UNICODE_PRINTF_C = 1;
      n = split(ENVIRON["__ble_rawbytes"], buff);
      for (i = 1; i <= n; i++)
        c2s_byte2raw[127 + i] = buff[i];
    } else {
      C2S_UNICODE_PRINTF_C = 0;
      for (i = 1; i <= 255; i++)
        c2s_byte2char[i] = sprintf("%c", i);
    }
  }
  function c2s(code, _, leadbyte_mark, leadbyte_sup, tail) {
    if (C2S_UNICODE_PRINTF_C)
      return sprintf("%c", code);

    leadbyte_sup = 128; # 0x80
    leadbyte_mark = 0;
    tail = "";
    while (leadbyte_sup && code >= leadbyte_sup) {
      leadbyte_sup /= 2;
      leadbyte_mark = leadbyte_mark ? leadbyte_mark / 2 : 65472; # 0xFFC0
      tail = c2s_byte2char[128 + int(code % 64)] tail;
      code = int(code / 64);
    }
    return c2s_byte2char[(leadbyte_mark + code) % 256] tail;
  }
  function c2s_raw(code, _, ret) {
    if (code >= 128 && C2S_UNICODE_PRINTF_C) {
      ret = c2s_byte2raw[code];
      if (ret != "") return ret;
    }
    return sprintf("%c", code);
  }

  function es_initialize(_, c) {
    s2i_initialize();
    c2s_initialize();
    es_control_chars["a"] = "\a";
    es_control_chars["b"] = "\b";
    es_control_chars["t"] = "\t";
    es_control_chars["n"] = "\n";
    es_control_chars["v"] = "\v";
    es_control_chars["f"] = "\f";
    es_control_chars["r"] = "\r";
    es_control_chars["e"] = "\033";
    es_control_chars["E"] = "\033";
    es_control_chars["?"] = "?";
    es_control_chars["'\''"] = "'\''";
    es_control_chars["\""] = "\"";
    es_control_chars["\\"] = "\\";

    for (c = 32; c < 127; c++)
      es_s2c[sprintf("%c", c)] = c;
  }
  function es_unescape(s, _, head, c) {
    head = "";
    while (match(s, /^[^\\]*\\/)) {
      head = head substr(s, 1, RLENGTH - 1);
      s = substr(s, RLENGTH + 1);
      if ((c = es_control_chars[substr(s, 1, 1)])) {
        head = head c;
        s = substr(s, 2);
      } else if (match(s, /^[0-9]([0-9][0-9]?)?/)) {
        head = head c2s_raw(s2i(substr(s, 1, RLENGTH), 8) % 256);
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^x[0-9a-fA-F][0-9a-fA-F]?/)) {
        head = head c2s_raw(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
        # \\U[0-9]{5,8}
        head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^[uU][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
        # \\[uU][0-9]{1,4}
        head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
        s = substr(s, RLENGTH + 1);
      } else if (match(s, /^c[ -~]/)) {
        # \\c[ -~] (non-ascii characters are unsupported)
        c = es_s2c[substr(s, 2, 1)];
        head = head c2s(_ble_bash >= 40400 && c == 63 ? 127 : c % 32);
        s = substr(s, 3);
      } else {
        head = head "\\";
      }
    }
    return head s;
  }
'
_ble_bin_awk_libNLFIX='
  ## @var nlfix_index
  ## @var nlfix_indices
  ## @var nlfix_rep_slash
  ## @var nlfix_rep_double_slash
  ## @fn nlfix_begin()
  ## @fn nlfix_push(elem)
  ## @fn nlfix_end()
  function nlfix_begin(_, tmp) {
    nlfix_rep_slash = "\\";
    if (AWKTYPE == "xpg4") nlfix_rep_slash = "\\\\";

    nlfix_rep_double_slash = "\\\\";
    sub(/.*/, nlfix_rep_double_slash, tmp);
    if (tmp == "\\") nlfix_rep_double_slash = "\\\\\\\\";

    nlfix_indices = "";
    nlfix_index = 0;
  }
  function nlfix_push(elem, file) {
    if (elem ~ /\n/) {
      gsub(/\\/,   nlfix_rep_double_slash, elem);
      gsub(/'\''/, nlfix_rep_slash "'\''", elem);
      gsub(/\007/, nlfix_rep_slash "a",    elem);
      gsub(/\010/, nlfix_rep_slash "b",    elem);
      gsub(/\011/, nlfix_rep_slash "t",    elem);
      gsub(/\012/, nlfix_rep_slash "n",    elem);
      gsub(/\013/, nlfix_rep_slash "v",    elem);
      gsub(/\014/, nlfix_rep_slash "f",    elem);
      gsub(/\015/, nlfix_rep_slash "r",    elem);
      if (file)
        printf("$'\''%s'\''\n", elem) > file;
      else
        printf("$'\''%s'\''\n", elem);
      nlfix_indices = nlfix_indices != "" ? nlfix_indices " " nlfix_index : nlfix_index;
    } else {
      if (file)
        printf("%s\n", elem) > file;
      else
        printf("%s\n", elem);
    }
    nlfix_index++;
  }
  function nlfix_end(file) {
    if (file)
      printf("%s\n", nlfix_indices) > file;
    else
      printf("%s\n", nlfix_indices);
  }
'
_ble_util_writearray_rawbytes=
function ble/util/writearray {
  local _ble_local_array
  local -x _ble_local_nlfix _ble_local_delim
  ble/util/writearray/.read-arguments "$@" || return 2

  # select the fastest awk implementation
  local __ble_awk=ble/bin/awk __ble_awktype=$_ble_bin_awk_type
  if ble/is-function ble/bin/mawk; then
    __ble_awk=ble/bin/mawk __ble_awktype=mawk
  elif ble/is-function ble/bin/nawk; then
    __ble_awk=ble/bin/nawk __ble_awktype=nawk
  fi

  # Note: printf も遅いが awk による parse の方が遅いので nlfix でない限りは直
  # 接 printf を使う。但し、bash-5.2 以降では printf が格段に遅くなるので避ける。
  if ((!_ble_local_nlfix)) && ! [[ _ble_bash -ge 50200 && $__ble_awktype == [mn]awk ]]; then
    if [[ $_ble_local_delim ]]; then
      if [[ $_ble_local_delim == *["%\'"]* ]]; then
        local __ble_q=\' __ble_Q="'\''"
        _ble_local_delim=${_ble_local_delim//'%'/'%%'}
        _ble_local_delim=${_ble_local_delim//'\'/'\\'}
        _ble_local_delim=${_ble_local_delim//$__ble_q/$__ble_Q}
      fi
      builtin eval "printf '%s$_ble_local_delim' \"\${$_ble_local_array[@]}\""
    else
      builtin eval "printf '%s\0' \"\${$_ble_local_array[@]}\""
    fi
    return "$?"
  fi

  # Note: mawk は定義していない関数を使おうとすると、それが実際に決し
  # て実行されないとしてもコンパイルに失敗して動かない。
  local __ble_function_gensub_dummy=
  [[ $__ble_awktype == gawk ]] ||
    __ble_function_gensub_dummy='function gensub(rex, rep, n, str) { exit 3; }'

  # Note: gawk の内部では $'\302' 等から現在のコードにないバイトを生成できない
  # ので外部から与える。
  if [[ ! $_ble_util_writearray_rawbytes ]]; then
    local IFS=$_ble_term_IFS __ble_tmp; __ble_tmp=('\'{2,3}{0..7}{0..7})
    builtin eval "local _ble_util_writearray_rawbytes=\$'${__ble_tmp[*]}'"
  fi
  local -x __ble_rawbytes=$_ble_util_writearray_rawbytes

  local __ble_rex_dq='^"([^\\"]|\\.)*"'
  local __ble_rex_es='^\$'\''([^\\'\'']|\\.)*'\'''
  local __ble_rex_sq='^'\''([^'\'']|'\'\\\\\'\'')*'\'''
  local __ble_rex_normal=$'^[^'$_ble_term_space'$`"'\''()|&;<>\\]' # Note: []{}?*#!~^, @(), +() は quote されていなくても OK とする
  declare -p "$_ble_local_array" | "$__ble_awk" -v _ble_bash="$_ble_bash" '
    '"$__ble_function_gensub_dummy"'
    BEGIN {
      DELIM = ENVIRON["_ble_local_delim"];
      FLAG_NLFIX = ENVIRON["_ble_local_nlfix"];
      if (FLAG_NLFIX) DELIM = "\n";

      IS_GAWK = AWKTYPE == "gawk";
      IS_XPG4 = AWKTYPE == "xpg4";

      REP_SL = "\\";
      if (IS_XPG4) REP_SL = "\\\\";

      es_initialize();

      decl = "";
    }

    '"$_ble_bin_awk_libES"'
    '"$_ble_bin_awk_libNLFIX"'

    # Note: "str" must not contain "&" or "\\\\".  When "&" is
    # present, the escaping rule for "\\" changes in some awk.
    # Now there is no problem because only DELIM (one character) is
    # currently passed.
    function str2rep(str) {
      if (IS_XPG4) sub(/\\/, "\\\\\\\\", str);
      return str;
    }


    function unquote_dq(s, _, head) {
      if (IS_GAWK) {
        return gensub(/\\([$`"\\])/, "\\1", "g", s);
      } else {
        if (s ~ /\\[$`"\\]/) {
          gsub(/\\\$/, "$" , s);
          gsub(/\\`/ , "`" , s);
          gsub(/\\"/ , "\"", s);
          gsub(/\\\\/, "\\", s);
        }
        return s;
      }
    }
    function unquote_sq(s) {
      gsub(/'\'\\\\\'\''/, "'\''", s);
      return s;
    }
    function unquote_dqes(s) {
      if (s ~ /^"/)
        return unquote_dq(substr(s, 2, length(s) - 2));
      else
        return es_unescape(substr(s, 3, length(s) - 3));
    }
    function unquote(s) {
      if (s ~ /^"/)
        return unquote_dq(substr(s, 2, length(s) - 2));
      else if (s ~ /^\$/)
        return es_unescape(substr(s, 3, length(s) - 3));
      else if (s ~ /^'\''/)
        return unquote_sq(substr(s, 2, length(s) - 2));
      else if (s ~ /^\\/)
        return substr(s, 2, 1);
      else
        return s;
    }

#%  # 制御文字が要素に含まれていない場合は全て [1]="..." の形式になっている筈。
    function analyze_elements_dq(decl, _, arr, i, n) {
      if (decl ~ /^\[[0-9]+\]="([^'$'\1\2''"\n\\]|\\.)*"( \[[0-9]+\]="([^\1\2"\\]|\\.)*")*$/) {
        if (IS_GAWK) {
          decl = gensub(/\[[0-9]+\]="(([^"\\]|\\.)*)" ?/, "\\1\001", "g", decl);
          sub(/\001$/, "", decl);
          decl = gensub(/\\([\\$"`])/, "\\1", decl);
        } else {
          # Convert to a ^A-separated list
          gsub(/\[[0-9]+\]="([^"\\]|\\.)*" /, "&\001", decl);
          gsub(/" \001\[[0-9]+\]="/, "\001", decl);
          sub(/^\[[0-9]+\]="/, "", decl);
          sub(/"$/, "", decl);

          # Unescape
          gsub(/\\\\/, "\002", decl);
          gsub(/\\\$/, "$", decl);
          gsub(/\\"/, "\"", decl);
          gsub(/\\`/, "`", decl);
          gsub(/\002/, REP_SL, decl);
        }

        # Output
        if (DELIM != "") {
          gsub(/\001/, str2rep(DELIM), decl);
          printf("%s", decl DELIM);
        } else {
          n = split(decl, arr, /\001/);
          for (i = 1; i <= n; i++)
            printf("%s%c", arr[i], 0);
        }

#%      # [N]="" の形式の時は要素内改行はないと想定
        if (FLAG_NLFIX) printf("\n");

        return 1;
      }
      return 0;
    }

    function _process_elem(elem) {
      if (FLAG_NLFIX) {
        nlfix_push(elem);
      } else if (DELIM != "") {
        printf("%s", elem DELIM);
      } else {
        printf("%s%c", elem, 0);
      }
    }

#%  # 任意の場合は多少遅くなるがこちらの関数で処理する。
    function analyze_elements_general(decl, _, arr, i, n, str, elem, m) {
      if (FLAG_NLFIX)
        nlfix_begin();

      # Note: We here assume that all the elements have the form [N]=...
      # Note: We here assume that the original array has at least one element
      n = split(decl, arr, /\]=/);
      str = " " arr[1];
      elem = "";
      first = 1;
      for (i = 2; i <= n; i++) {
        str = str "]=" arr[i];
        if (sub(/^ \[[0-9]+\]=/, "", str)) {
          if (first)
            first = 0;
          else
            _process_elem(elem);
          elem = "";
        }

        if (match(str, /('"$__ble_rex_dq"'|'"$__ble_rex_es"') /)) {
          mlen = RLENGTH;
          elem = elem unquote_dqes(substr(str, 1, mlen - 1));
          str = substr(str, mlen);
          continue;
        } else if (i == n || str !~ /^[\$"]/) {
          # Fallback: As far as all the values have the form "" or $'', the
          # control would only enter this branch for the last element.
          while (match(str, /'"$__ble_rex_dq"'|'"$__ble_rex_es"'|'"$__ble_rex_sq"'|'"$__ble_rex_normal"'|^\\./)) {
            mlen = RLENGTH;
            elem = elem unquote(substr(str, 1, mlen));
            str = substr(str, mlen + 1);
          }
        }
      }
      _process_elem(elem);

      if (FLAG_NLFIX)
        nlfix_end();
      return 1;
    }

    function process_declaration(decl) {
#%    # declare 除去
      sub(/^declare +(-[-aAilucnrtxfFgGI]+ +)?(-- +)?/, "", decl);

#%    # 全体 quote の除去
      if (decl ~ /^([_a-zA-Z][_a-zA-Z0-9]*)='\''\(.*\)'\''$/) {
        sub(/='\''\(/, "=(", decl);
        sub(/\)'\''$/, ")", decl);
        gsub(/'\'\\\\\'\''/, "'\''", decl);
      }

#%    # bash-3.0 の declare -p は改行について誤った出力をする。
      if (_ble_bash < 30100) gsub(/\\\n/, "\n", decl);

#%    # #D1238 bash-4.3 以前の declare -p は ^A, ^? を
#%    #   ^A^A, ^A^? と出力してしまうので補正する。
#%    # #D1325 更に Bash-3.0 では "x${_ble_term_DEL}y" とすると
#%    #   _ble_term_DEL の中身が消えてしまうので
#%    #   "x""${_ble_term_DEL}""y" とする必要がある。
      if (_ble_bash < 40400) {
        gsub(/\001\001/, "\001", decl);
        gsub(/\001\177/, "\177", decl);
      }

      sub(/^([_a-zA-Z][_a-zA-Z0-9]*)=\(['"$_ble_term_space"']*/, "", decl);
      sub(/['"$_ble_term_space"']*\)['"$_ble_term_space"']*$/, "", decl);

#%    # 空配列
      if (decl == "") return 1;

#%    # [N]="value" だけの時の高速実装。mawk だと却って遅くなる様だ
      if (AWKTYPE != "mawk" && analyze_elements_dq(decl)) return 1;

      return analyze_elements_general(decl);
    }
    { decl = decl ? decl "\n" $0: $0; }
    END { process_declaration(decl); }
  '
}
function ble/util/readarray {
  local _ble_local_array
  local -x _ble_local_nlfix _ble_local_delim
  ble/util/writearray/.read-arguments "$@" || return 2

  if ((_ble_bash>=40400)); then
    local _ble_local_script='
      mapfile -t -d "$_ble_local_delim" ARR'
  elif ((_ble_bash>=40000)) && [[ $_ble_local_delim == $'\n' ]]; then
    local _ble_local_script='
      mapfile -t ARR'
  else
    local _ble_local_script='
      local IFS= ARRI=0; ARR=()
      while ble/bash/read -d "$_ble_local_delim" "ARR[ARRI++]"; do :; done'
  fi

  if [[ $_ble_local_nlfix ]]; then
    _ble_local_script=$_ble_local_script'
      local ARRN=${#ARR[@]} ARRF ARRI
      if ((ARRN--)); then
        ble/string#split-words ARRF "${ARR[ARRN]}"
        builtin unset -v "ARR[ARRN]"
        for ARRI in "${ARRF[@]}"; do
          builtin eval -- "ARR[ARRI]=${ARR[ARRI]}"
        done
      fi'
  fi
  builtin eval -- "${_ble_local_script//ARR/$_ble_local_array}"
}

## @fn ble/util/assign var command
##   var=$(command) の高速な代替です。command はサブシェルではなく現在のシェル
##   で実行されます。Bash 5.3 の var=${ command; } に等価です。
##
##   @param[in] var
##     代入先の変数名を指定します。
##   @param[in] command...
##     実行するコマンドを指定します。
##
## @remarks util.bgproc.sh では « ble/util/assign bgpid '(set -m; command &
##   bgpid=$!; ble/util/print "$bgpid")' » でプロセスグループが作られる事を想定
##   している。例えば bgpid=$(...) はプロセスグループが作られないので使えない。
##
_ble_util_assign_base=$_ble_base_run/$$.util.assign.tmp
_ble_util_assign_level=0
if ((_ble_bash>=40000)); then
  function ble/util/assign/mktmp {
    _ble_local_tmpfile=$_ble_util_assign_base.$((_ble_util_assign_level++))
    ((BASH_SUBSHELL)) && _ble_local_tmpfile=$_ble_local_tmpfile.$BASHPID
  }
else
  function ble/util/assign/mktmp {
    _ble_local_tmpfile=$_ble_util_assign_base.$((_ble_util_assign_level++))
    ((BASH_SUBSHELL)) && _ble_local_tmpfile=$_ble_local_tmpfile.$RANDOM
  }
fi
function ble/util/assign/rmtmp {
  ((_ble_util_assign_level--))
#%if !release
  if ((BASH_SUBSHELL)); then
    printf 'caller %s\n' "${FUNCNAME[@]}" >| "$_ble_local_tmpfile"
  else
    >| "$_ble_local_tmpfile"
  fi
#%else
  >| "$_ble_local_tmpfile"
#%end
}
if ((_ble_bash>=50300)); then
  function ble/util/assign {
    builtin eval "$1=\${ builtin eval -- \"\$2\"; }"
  }
elif ((_ble_bash>=40000)); then
  # mapfile の方が read より高速
  function ble/util/assign {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$? _ble_local_arr=
    mapfile -t _ble_local_arr < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    IFS=$'\n' builtin eval "$1=\"\${_ble_local_arr[*]}\""
    return "$_ble_local_ret"
  }
else
  function ble/util/assign {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$? IFS=
    ble/bash/read -d '' "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    builtin eval "$1=\${$1%\$_ble_term_nl}"
    return "$_ble_local_ret"
  }
fi
## @fn ble/util/assign-array arr command args...
##   mapfile -t arr < <(command ...) の高速な代替です。
##   command はサブシェルではなく現在のシェルで実行されます。
##
##   @param[in] arr
##     代入先の配列名を指定します。
##   @param[in] command
##     実行するコマンドを指定します。
##   @param[in] args...
##     command から参照する引数 ($3 $4 ...) を指定します。
##
if ((_ble_bash>=40000)); then
  function ble/util/assign-array {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    mapfile -t "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    ble/util/mapfile "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
fi

if ! ((_ble_bash>=40400)); then
  function ble/util/assign-array0 {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    mapfile -d '' -t "$1" < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array0 {
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$2" >| "$_ble_local_tmpfile"
    local _ble_local_ret=$?
    local IFS= i=0 _ble_local_arr
    while ble/bash/read -d '' "_ble_local_arr[i++]"; do :; done < "$_ble_local_tmpfile"
    ble/util/assign/rmtmp
    [[ ${_ble_local_arr[--i]} ]] || builtin unset -v "_ble_local_arr[i]"
    ble/util/unlocal i IFS
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
    return "$_ble_local_ret"
  }
fi

## @fn ble/util/assign.has-output command
function ble/util/assign.has-output {
  local _ble_local_tmpfile; ble/util/assign/mktmp
  builtin eval -- "$1" >| "$_ble_local_tmpfile"
  [[ -s $_ble_local_tmpfile ]]
  local _ble_local_ret=$?
  ble/util/assign/rmtmp
  return "$_ble_local_ret"
}

function ble/util/assign-words {
  ble/util/assign "$1" "$2"
  ble/string#split-words "$1" "${!1}"
}


# ble/bin/awk の初期化に ble/util/assign を使うので
ble/bin/awk/.instantiate

#
# functions
#

## @fn ble/is-function function
##   関数 function が存在するかどうかを検査します。
##
##   @param[in] function
##     存在を検査する関数の名前を指定します。
##
if ((_ble_bash>=30200)); then
  function ble/is-function {
    declare -F "$1" &>/dev/null
  }
else
  # bash-3.1 has bug in declare -f.
  # it does not accept a function name containing non-alnum chars.
  function ble/is-function {
    local type
    ble/util/type type "$1"
    [[ $type == function ]]
  }
fi

## @fn ble/function#getdef function
##   @var[out] def
##
## Note: declare -pf "$name" が -o posix に依存しない関数定義の取得方
##   法であるかに思えたが、declare -pf "$name" を使うと -t 属性が付い
##   ていた時に末尾に declare -ft name という余分な属性付加のコマンド
##   が入ってしまう。或いはこの属性も一緒に保存できた方が良いのかもし
##   れないが、取り敢えず今は属性が入らない様に declare -pf name は使
##   わない。
if ((_ble_bash>=30200)); then
  function ble/function#getdef {
    local name=$1
    ble/is-function "$name" || return 1
    if [[ -o posix ]]; then
      ble/util/assign def 'type "$name"'
      def=${def#*$'\n'}
    else
      ble/util/assign def 'declare -f "$name"'
    fi
  }
else
  function ble/function#getdef {
    local name=$1
    ble/is-function "$name" || return 1
    ble/util/assign def 'type "$name"'
    def=${def#*$'\n'}
  }
fi

## @fn ble/function#evaldef def
##   関数を定義します。基本的に eval に等価ですが評価時に extglob を保
##   証します。
function ble/function#evaldef {
  local reset_extglob=
  if ! shopt -q extglob; then
    reset_extglob=1
    shopt -s extglob
  fi
  builtin eval -- "$1"; local ext=$?
  [[ ! $reset_extglob ]] || shopt -u extglob
  return "$ext"
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_util_function_traced}"
function ble/function#trace {
  local func
  for func; do
    declare -ft "$func" &>/dev/null || continue
    ble/gdict#set _ble_util_function_traced "$func" 1
  done
}
function ble/function#has-trace {
  ble/gdict#has _ble_util_function_traced "$1"
}
function ble/function#has-attr {
  local __ble_tmp=$1
  ble/util/assign-array __ble_tmp 'declare -pf "$__ble_tmp" 2>/dev/null'
  local nline=${#__ble_tmp[@]}
  ((nline)) &&
    ble/string#match "${__ble_tmp[nline-1]}" '^declare -([a-zA-Z]*)' &&
    [[ ${BASH_REMATCH[1]} == *["$2"]* ]]
}

## @fn ble/function/is-global-trace-context
##   この関数の呼び出し元の文脈で確実に global の DEBUG が見えているかどうかを
##   判定します。
function ble/function/is-global-trace-context {
  # Note: 例え set -T が設定されていたとしても、それが global で設定された物な
  #   のか呼び出しの何処かの深さで設定された物なのか分からない。なので、set -T
  #   が設定されていたからと言って無条件に global が見えているとは限らない。
  # Note: ble に属する関数は勝手に set -T を一時的に有効にしたりする事は基本的
  #   にないので許可する。但し、内部で一時的に restore-bash-options している時
  #   はあるが、その内部で ble-attach 乃至は ble/function/is-global-trace-context等
  #   を実行する事はないと仮定する。
  local func depth=1 ndepth=${#FUNCNAME[*]}
  for func in "${FUNCNAME[@]:1}"; do
    local src=${BASH_SOURCE[depth]}
    [[ $- == *T* && ( $func == ble || $func == ble[-/]* || $func == source && $src == "$_ble_base_blesh_raw" ) ]] ||
      [[ $func == source && depth -eq ndepth-1 && BASH_LINENO[depth] -eq 0 && ( ${src##*/} == .bashrc || ${src##*/} == .bash_profile || ${src##*/} == .profile ) ]] ||
      ble/gdict#has _ble_util_function_traced "$func" || return 1
    ((depth++))
  done
  return 0
}

## @fn ble/function#try function args...
##   関数 function が存在している時に限り関数を呼び出します。
##
##   @param[in] function
##     存在を検査して実行する関数の名前を指定します。
##   @param[in] args
##     関数に渡す引数を指定します。
##   @exit 関数が呼び出された場合はその終了ステータスを返します。
##     関数が存在しなかった場合は 127 を返します。
##
function ble/function#try {
  local lastexit=$?
  ble/is-function "$1" || return 127
  ble/util/setexit "$lastexit"
  "$@"
}

function ble/function#get-source-and-lineno {
  local ret unset_extdebug=
  shopt -q extdebug || { unset_extdebug=1; shopt -s extdebug; }
  ble/util/assign ret "declare -F '$1' 2>/dev/null"; local ext=$?
  [[ ! $unset_extdebug ]] || shopt -u extdebug
  if ((ext==0)); then
    ret=${ret#*' '}
    lineno=${ret%%' '*}
    source=${ret#*' '}
    [[ $lineno && ! ${lineno//[0-9]} && $source ]] || return 1
  fi
  return "$ext"
}

## @fn ble/function#advice type function proc
##   既存の関数の振る舞いを変更します。
##
##   @param[in] type
##     before を指定した時、処理 proc を関数 function の前に挿入します。
##     after を指定した時、処理 proc を関数 function の後に挿入します。
##     around を指定した時、関数 function の呼び出し前後に処理 proc を行います。
##     around proc の中では本来の関数を呼び出す為に ble/function#advice/do
##     を実行する必要があります。
##
##   @fn ble/function#advice/do
##     around proc の中から呼び出せる関数です。
##     本来の関数を呼び出します。
##
##   @arr[in,out] ADVICE_WORDS
##     proc の中から参照できる変数です。関数の呼び出しに使うコマンドを提供しま
##     す。例えば元の関数呼び出しが function arg1 arg2 だった場合、
##     ADVICE_WORDS=(function arg1 arg2) が設定されます。before/around に於いて
##     本来の関数の呼び出し前にこの配列を書き換える事で呼び出す関数または関数の
##     引数を変更する事ができます。
##
##   @var[in.out] ADVICE_EXIT
##     proc の中から参照できる変数です。after/around に於いて関数実行後の戻り値
##     を参照または変更するのに使います。
##
##   @var[in.out] ADVICE_FUNCNAME
##     proc の中から参照できる変数です。FUNCNAME から ble/function#advice の調
##     整による余分な関数呼び出しを取り除いたものを保持します。
##
function ble/function#advice/do {
  ble/util/setexit "$advice_lastexit" "$advice_lastarg"
  ble/function#advice/original:"${ADVICE_WORDS[@]}"
  ADVICE_EXIT=$?
}
function ble/function#advice/.proc {
  local advice_lastexit=$? advice_lastarg=$_

  local ADVICE_WORDS ADVICE_EXIT=127
  ADVICE_WORDS=("$@")
  local -a ADVICE_FUNCNAME=()
  local func
  for func in "${FUNCNAME[@]}"; do
    [[ $func == ble/function#advice/* ]] ||
      ble/array#push ADVICE_FUNCNAME "$func"
  done
  ble/util/unlocal func

  ble/function#try "ble/function#advice/before:$1"
  if ble/is-function "ble/function#advice/around:$1"; then
    "ble/function#advice/around:$1"
  else
    ble/function#advice/do
  fi
  ble/function#try "ble/function#advice/after:$1"
  return "$ADVICE_EXIT"
}
function ble/function#advice {
  local type=$1 name=$2 proc=$3
  if ! ble/is-function "$name"; then
    local t=; ble/util/type t "$name"
    case $t in
    (builtin|file) builtin eval "function $name { : ZBe85Oe28nBdg; command $name \"\$@\"; }" ;;
    (*)
      ble/util/print "ble/function#advice: $name is not a function." >&2
      return 1 ;;
    esac
  fi

  local def; ble/function#getdef "$name"
  case $type in
  (remove)
    if [[ $def == *'ble/function#advice/.proc'* ]]; then
      ble/function#getdef "ble/function#advice/original:$name"
      if [[ $def ]]; then
        if [[ $def == *ZBe85Oe28nBdg* ]]; then
          builtin unset -f "$name"
        else
          ble/function#evaldef "${def#*:}"
        fi
      fi
    fi
    builtin unset -f ble/function#advice/{before,after,around,original}:"$name" 2>/dev/null
    return 0 ;;
  (before|after|around)
    if [[ $def != *'ble/function#advice/.proc'* ]]; then
      ble/function#evaldef "ble/function#advice/original:$def"
      builtin eval "function $name { ble/function#advice/.proc \"\$FUNCNAME\" \"\$@\"; }"
    fi

    local q=\' Q="'\''"
    builtin eval "ble/function#advice/$type:$name() { builtin eval '${proc//$q/$Q}'; }"
    return 0 ;;
  (*)
    ble/util/print "ble/function#advice unknown advice type '$type'" >&2
    return 2 ;;
  esac
}

## @fn ble/function#push name [proc]
## @fn ble/function#pop name
##   関数定義を保存・復元する関数です。
##
function ble/function#push {
  local name=$1 proc=$2
  if ble/is-function "$name"; then
    local index=0
    while ble/is-function "ble/function#push/$index:$name"; do
      ((++index))
    done

    local def; ble/function#getdef "$name"
    ble/function#evaldef "ble/function#push/$index:$def"
  fi

  if [[ $proc ]]; then
    local q=\' Q="'\''"
    builtin eval "function $name { builtin eval -- '${proc//$q/$Q}'; }"
  else
    builtin unset -f "$name"
  fi
  return 0
}
function ble/function#pop {
  local name=$1 proc=$2

  local index=-1
  while ble/is-function "ble/function#push/$((index+1)):$name"; do
    ((++index))
  done

  if ((index<0)); then
    if ble/is-function "$name"; then
      builtin unset -f "$name"
      return 0
    elif ble/bin#has "$name"; then
      ble/util/print "ble/function#pop: $name is not a function." >&2
      return 1
    else
      return 0
    fi
  else
    local def; ble/function#getdef "ble/function#push/$index:$name"
    ble/function#evaldef "${def#*:}"
    builtin unset -f "ble/function#push/$index:$name"
    return 0
  fi
}
function ble/function#push/call-top {
  local func=${FUNCNAME[1]}
  if ! ble/is-function "$func"; then
    ble/util/print "ble/function#push/call-top: This function should be called from a function" >&2
    return 1
  fi
  local index=0
  if [[ $func == ble/function#push/?*:?* ]]; then
    index=${func#*/*/}; index=${index%%:*}
    func=${func#*:}
  else
    while ble/is-function "ble/function#push/$index:$func"; do ((index++)); done
  fi
  if ((index==0)); then
    command "$func" "$@"
  else
    "ble/function#push/$((index-1)):$func" "$@"
  fi
}

: "${_ble_util_lambda_count:=0}"
## @fn ble/function#lambda var body
##   無名関数を定義しその実際の名前を変数 var に格納します。
function ble/function#lambda {
  local _ble_local_q=\' _ble_local_Q="'\''"
  ble/util/set "$1" ble/function#lambda/$((_ble_util_lambda_count++))
  builtin eval -- "function ${!1} { builtin eval -- '${2//$_ble_local_q/$_ble_local_Q}'; }"
}

## @fn ble/function#suppress-stderr function_name
##   @param[in] function_name
function ble/function#suppress-stderr {
  local name=$1
  if ! ble/is-function "$name"; then
    ble/util/print "$FUNCNAME: '$name' is not a function name" >&2
    return 2
  fi

  # 重複して suppress-stderr した時の為、未定義の時のみ実装を待避
  local lambda=ble/function#suppress-stderr:$name
  if ! ble/is-function "$lambda"; then
    local def; ble/function#getdef "$name"
    ble/function#evaldef "ble/function#suppress-stderr:$def"
  fi

  builtin eval "function $name { $lambda \"\$@\" 2>/dev/null; }"
  return 0
}

#
# miscallaneous utils
#

# Note: "printf -v" for an array element is only allowed in bash-4.1
# or later.
if ((_ble_bash>=40100)); then
  function ble/util/set {
    builtin printf -v "$1" %s "$2"
  }
else
  function ble/util/set {
    builtin eval -- "$1=\"\$2\""
  }
fi

if ((_ble_bash>=30100)); then
  function ble/util/sprintf {
    builtin printf -v "$@"
  }
else
  function ble/util/sprintf {
    local -a args; args=("${@:2}")
    ble/util/assign "$1" 'builtin printf "${args[@]}"'
  }
fi

## @fn ble/util/type varname command
##   @param[out] varname
##     結果を格納する変数名を指定します。
##   @param[in] command
##     種類を判定するコマンド名を指定します。
function ble/util/type {
  ble/util/assign-array "$1" 'builtin type -a -t -- "$3" 2>/dev/null' "$2"
}

if ((_ble_bash>=40000)); then
  function ble/is-alias {
    [[ ${BASH_ALIASES[$1]+set} ]]
  }
  function ble/alias#active {
    shopt -q expand_aliases &&
      [[ ${BASH_ALIASES[$1]+set} ]]
  }
  ## @fn ble/alias#expand word
  ##   @var[out] ret
  ##   @exit
  ##     エイリアス展開が実際に行われた時に成功します。
  function ble/alias#expand {
    ret=$1
    shopt -q expand_aliases &&
      ret=${BASH_ALIASES[$ret]-$ret}
  }
  function ble/alias/list {
    ret=("${!BASH_ALIASES[@]}")
  }
else
  function ble/is-alias {
    [[ $1 != *=* ]] && alias "$1" &>/dev/null
  }
  function ble/alias#active {
    shopt -q expand_aliases &&
      [[ $1 != *=* ]] && alias "$1" &>/dev/null
  }
  function ble/alias#expand {
    ret=$1
    local type; ble/util/type type "$ret"
    [[ $type != alias ]] && return 1
    local data; ble/util/assign data 'LC_ALL=C alias "$ret"' &>/dev/null
    [[ $data == 'alias '*=* ]] && builtin eval "ret=${data#alias *=}"
  }
  function ble/alias/list {
    ret=()
    local data iret=0
    ble/util/assign-array data 'alias -p'
    for data in "${data[@]}"; do
      [[ $data == 'alias '*=* ]] &&
        data=${data%%=*} &&
        builtin eval "ret[iret++]=${data#alias }"
    done
  }
fi

if ((_ble_bash>=40000)); then
  # #D1341 対策 変数代入形式だと組み込みコマンドにロケールが適用されない。
  function ble/util/is-stdin-ready {
    local IFS= LC_ALL= LC_CTYPE=C
    builtin read -t 0
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/util/is-stdin-ready
else
  function ble/util/is-stdin-ready { false; }
fi

# Note: BASHPID は Bash-4.0 以上

if ((_ble_bash>=40000)); then
  function ble/util/getpid { :; }
  function ble/util/is-running-in-subshell { [[ $$ != $BASHPID ]]; }
else
  ## @fn ble/util/getpid
  ##   @var[out] BASHPID
  function ble/util/getpid {
    local command='echo $PPID'
    ble/util/assign BASHPID 'ble/bin/sh -c "$command"'
  }
  function ble/util/is-running-in-subshell {
    # Note: bash-4.3 以下では BASH_SUBSHELL はパイプやプロセス置換で増えないの
    #   で信頼性が低いらしい。唯、関数内で実行している限りは大丈夫なのかもしれ
    #   ない。
    ((BASH_SUBSHELL==0)) || return 0
    local BASHPID; ble/util/getpid
    [[ $$ != $BASHPID ]]
  }
fi

## @fn ble/fd#is-open fd
##   指定したファイルディスクリプタが開いているかどうか判定します。
function ble/fd#is-open { builtin : >&"$1"; } 2>/dev/null

_ble_util_openat_nextfd=
function ble/fd#alloc/.nextfd {
  [[ $_ble_util_openat_nextfd ]] ||
    _ble_util_openat_nextfd=${bleopt_openat_base:-30}
  # Note: Bash 3.1 では exec fd>&- で明示的に閉じても駄目。
  #   開いた後に読み取りプロセスで読み取りに失敗する。
  #   なので開いていない fd を探す必要がある。#D0992
  # Note: 指定された fd が開いているかどうかを
  #   可搬に高速に判定する方法を見つけたので
  #   常に開いていない fd を探索する。#D1318
  # Note: fd が枯渇すると探索が無限ループになるので fd 探索範囲の上限を 1024 に
  #   制限する。もし見つからない場合には初期値の fd を上書きする。
  local _ble_local_init=$_ble_util_openat_nextfd
  local _ble_local_limit=$((_ble_local_init+1024))
  while ((_ble_util_openat_nextfd<_ble_local_limit)) &&
          ble/fd#is-open "$_ble_util_openat_nextfd"; do
    ((_ble_util_openat_nextfd++))
  done
  if ((_ble_util_openat_nextfd>=_ble_local_limit)); then
    _ble_util_openat_nextfd=$_ble_local_init
    builtin eval "exec $_ble_util_openat_nextfd>&-"
  fi
  (($1=_ble_util_openat_nextfd++))
}

## @fn ble/fd#alloc fdvar redirect [opts]
##   "exec {fdvar}>foo" に該当する操作を実行します。
##   @param[out] fdvar
##     指定した変数に使用されたファイルディスクリプタを代入します。
##   @param[in] redirect
##     リダイレクトを指定します。
##   @param[in,opt] opts
##     export
##       指定した変数を export します。
##     inherit
##       既に fdvar が存在して有効な fd であれば何もしません。新しく fd を確保
##       した場合には終了処理を登録しません。また上記の export を含みます。
##     share
##       >&NUMBER の形式のリダイレクトの場合に fd を複製する代わりに単に NUMBER
##       を fdvar に代入します。
##     overwrite
##       既に fdvar が存在する場合その fd を上書きします。
_ble_util_openat_fdlist=()
function ble/fd#alloc {
  local _ble_local_preserve=
  if [[ :$3: == *:inherit:* ]]; then
    [[ ${!1-} ]] &&
      ble/fd#is-open "${!1}" &&
      return 0
  fi

  if [[ :$3: == *:share:* ]]; then
    local _ble_local_ret='[<>]&['$_ble_term_IFS']*([0-9]+)['$_ble_term_IFS']*$'
    if [[ $2 =~ $rex ]]; then
      builtin eval -- "$1=${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  if [[ ${!1-} && :$3: == *:overwrite:* ]]; then
    _ble_local_preserve=1
    builtin eval "exec ${!1}$2"
  elif ((_ble_bash>=40100)) && [[ :$3: != *:base:* ]]; then
    builtin eval "exec {$1}$2"
  else
    ble/fd#alloc/.nextfd "$1"
    # Note: Bash 3.2/3.1 のバグを避けるため、
    #   >&- を用いて一旦明示的に閉じる必要がある #D0857
    builtin eval "exec ${!1}>&- ${!1}$2"
  fi; local _ble_local_ext=$?

  if [[ :$3: == *:inherit:* || :$3: == *:export:* ]]; then
    export "$1"
  elif [[ ! $_ble_local_preserve ]]; then
    ble/array#push _ble_util_openat_fdlist "${!1}"
  fi
  return "$_ble_local_ext"
}
function ble/fd#finalize {
  local fd
  for fd in "${_ble_util_openat_fdlist[@]}"; do
    builtin eval "exec $fd>&-"
  done
  _ble_util_openat_fdlist=()
}
## @fn ble/fd#close fd
##   指定した fd を閉じます。
function ble/fd#close {
  set -- "$(($1))"
  (($1>=3)) || return 1
  builtin eval "exec $1>&-"
  ble/array#remove _ble_util_openat_fdlist "$1"
  return 0
}

## @var _ble_util_fd_stdout
## @var _ble_util_fd_stderr
## @var _ble_util_fd_null
## @var _ble_util_fd_zero
##   既に定義されている場合は継承する
if [[ $_ble_init_command ]]; then
  # コマンドモードで実行している時には標準ストリームはそのまま使う。
  _ble_util_fd_stdin=0
  _ble_util_fd_stdout=1
  _ble_util_fd_stderr=2
else
  if [[ -t 0 ]]; then
    ble/fd#alloc _ble_util_fd_stdin '<&0' base:overwrite:export
  else
    ble/fd#alloc _ble_util_fd_stdin '< /dev/tty' base:inherit
  fi
  if [[ -t 1 ]]; then
    ble/fd#alloc _ble_util_fd_stdout '>&1' base:overwrite:export
  else
    ble/fd#alloc _ble_util_fd_stdout '> /dev/tty' base:inherit
  fi
  if [[ -t 2 ]]; then
    ble/fd#alloc _ble_util_fd_stderr '>&2' base:overwrite:export
  else
    ble/fd#alloc _ble_util_fd_stderr ">&$_ble_util_fd_stdout" base:inherit:share
  fi
fi
ble/fd#alloc _ble_util_fd_null '<> /dev/null' base:inherit
[[ -c /dev/zero ]] &&
  ble/fd#alloc _ble_util_fd_zero '< /dev/zero' base:inherit

function ble/fd#close-all-tty {
  local -a fds=()
  if [[ -d /proc/$$/fd ]]; then
    ble/util/getpid
    local fd
    for fd in /proc/"$BASHPID"/fd/[0-9]*; do
      ble/array#push fds "${fd##*/}"
    done
  else
    fd=({0..255})
  fi

  # Note: 0 1 2 及び _ble_util_fd_std{in,out,err} を閉じる事を考えたが、どうも
  # redirect によって待避されている物などたくさんある様なので全部チェックする事
  # にした。
  local fd
  for fd in "${fds[@]}"; do
    if ble/string#match "$fd" '^[0-9]+$' && [[ -t $fd ]]; then
      builtin eval "exec $fd>&- $fd>&$_ble_util_fd_null"
      ble/array#remove _ble_util_openat_fdlist "$fd"
    fi
  done
}
## @fn ble/util/nohup command [opts]
##   @param[in] command
##   @param[in,opt] opts
##     @opts print-bgpid
function ble/util/nohup {
  if ((!BASH_SUBSHELL)); then
    (ble/util/nohup "$@")
    return "$?"
  fi

  ble/fd#close-all-tty
  shopt -u huponexit
  builtin eval -- "$1" &>/dev/null </dev/null & { local pid=$!; disown; }
  if [[ :$2: == *:print-bgpid:* ]]; then
    ble/util/print "$pid"
  fi
}

function ble/util/print-quoted-command {
  local ret; ble/string#quote-command "$@"
  ble/util/print "$ret"
}
function ble/util/declare-print-definitions {
  (($#==0)) && return 0

  # Note (#D2055): mawk 1.3.3-20090705 bug の為に [:space:] を正規表現内部で使
  # 用する事ができない。Ubuntu 16.04 LTS 及び Ubuntu 18.04 LTS で mawk
  # 1.3.3-20090705 が使用されている。なので _ble_term_space という変数に
  # <SP><TAB> を入れて使う。

  declare -p "$@" | ble/bin/awk -v _ble_bash="$_ble_bash" -v OSTYPE="$OSTYPE" '
    BEGIN {
      decl = "";

#%    # 対策 #D1270: MSYS2 で ^M を代入すると消える
      flag_escape_cr = OSTYPE == "msys";
    }

    function fix_value(value) {
#%    # bash-3.0 の declare -p は改行について誤った出力をする。
      if (_ble_bash < 30100) gsub(/\\\n/, "\n", value);

#%    # #D1238 bash-4.3 以前の declare -p は ^A, ^? を
#%    #   ^A^A, ^A^? と出力してしまうので補正する。
#%    # #D1325 更に Bash-3.0 では "x${_ble_term_DEL}y" とすると
#%    #   _ble_term_DEL の中身が消えてしまうので
#%    #   "x""${_ble_term_DEL}""y" とする必要がある。
      if (_ble_bash < 30100) {
        gsub(/\001\001/, "\"\"${_ble_term_SOH}\"\"", value);
        gsub(/\001\177/, "\"\"${_ble_term_DEL}\"\"", value);
      } else if (_ble_bash < 40400) {
        gsub(/\001\001/, "${_ble_term_SOH}", value);
        gsub(/\001\177/, "${_ble_term_DEL}", value);
      }

      if (flag_escape_cr)
        gsub(/\015/, "${_ble_term_CR}", value);
      return value;
    }

#%  # #D1522 #D1614 Bash-3.2 未満で配列要素に ^A または ^? を含む場合は
#%  #   arr=(...) の形式だと評価時に ^A, ^? が倍加するので、
#%  #   要素ごとに代入を行う必要がある。
    function print_array_elements(decl, _, name, out, key, value) {
      if (match(decl, /^[_a-zA-Z][_a-zA-Z0-9]*=\(/) == 0) return 0;
      name = substr(decl, 1, RLENGTH - 2);
      decl = substr(decl, RLENGTH + 1, length(decl) - RLENGTH - 1);
      sub(/^['"$_ble_term_space"']+/, decl);

      out = name "=()\n";

      while (match(decl, /^\[[0-9]+\]=/)) {
        key = substr(decl, 2, RLENGTH - 3);
        decl = substr(decl, RLENGTH + 1);

        value = "";
        if (match(decl, /^('\''[^'\'']*'\''|\$'\''([^\\'\'']|\\.)*'\''|\$?"([^\\"]|\\.)*"|\\.|[^'"$_ble_term_space"'"'\''`;&|()])*/)) {
          value = substr(decl, 1, RLENGTH)
          decl = substr(decl, RLENGTH + 1)
        }

        out = out name "[" key "]=" fix_value(value) "\n";
        sub(/^['"$_ble_term_space"']+/, decl);
      }

      if (decl != "") return 0;

      print out;
      return 1;
    }

    function declflush(_, isArray) {
      if (!decl) return 0;
      isArray = (decl ~ /^declare +-[ilucnrtxfFgGI]*[aA]/);

#%    # declare 除去
      sub(/^declare +(-[-aAilucnrtxfFgGI]+ +)?(-- +)?/, "", decl);
      if (isArray) {
        if (decl ~ /^([_a-zA-Z][_a-zA-Z0-9]*)='\''\(.*\)'\''$/) {
          sub(/='\''\(/, "=(", decl);
          sub(/\)'\''$/, ")", decl);
          gsub(/'\'\\\\\'\''/, "'\''", decl);
        }

        if (_ble_bash < 40000 && decl ~ /[\001\177]/)
          if (print_array_elements(decl))
            return 1;
      }

      print fix_value(decl);
      decl = "";
      return 1;
    }
    /^declare / {
      declflush();
      decl = $0;
      next;
    }
    { decl = decl "\n" $0; }
    END { declflush(); }
  '
}

## @fn ble/util/print-global-definitions/.print-decl name opts
##   指定された変数の宣言を出力します。
##   @param[in] name
##     処理対象の変数名を指定します。
##   @param[in] opts
##     指定した名前の変数が見つからない時 unset が指定されます。
##   @stdout
##     変数宣言を出力します。指定した名前の変数が見つからない時は unset 状態に
##     するコマンドを出力します。
function ble/util/print-global-definitions/.print-decl {
  local __ble_name=$1 __ble_decl=
  if [[ ! ${!__ble_name+set} || :$2: == *:unset:* ]]; then
    __ble_decl="declare $__ble_name; builtin unset -v $__ble_name"
  elif ble/variable#has-attr "$__ble_name" aA; then
    if ((_ble_bash>=40000)); then
      ble/util/assign __ble_decl "declare -p $__ble_name" 2>/dev/null
      __ble_decl=${__ble_decl#declare -* }
    else
      ble/util/assign __ble_decl "ble/util/declare-print-definitions $__ble_name" 2>/dev/null
    fi
    if ble/is-array "$__ble_name"; then
      __ble_decl="declare -a $__ble_decl"
    else
      __ble_decl="declare -A $__ble_decl"
    fi
  else
    __ble_decl=${!__ble_name}
    __ble_decl="declare $__ble_name='${__ble_decl//$__ble_q/$__ble_Q}'"
  fi
  ble/util/print "$__ble_decl"
}

## @fn ble/util/print-global-definitions varnames...
##   @var[in] varnames
##
##   指定した変数のグローバル変数としての定義を出力します。
##
##   制限: 途中同名の readonly ローカル変数がある場合は、
##   グローバル変数の値は取得できないので unset を返す。
##   そもそも readonly な変数には問題が多いので ble.sh では使わない。
##
##   制限: __ble_* という変数名はこの関数の実装に使用するので、
##   対応しない。
##
##   Note: bash-4.2 にはバグがあって、グローバル変数が存在しない時に
##   declare -g -r var とすると、ローカルに新しく読み取り専用の var 変数が作られる。
##   現在の実装では問題にならない。
##
function ble/util/print-global-definitions {
  local __ble_opts=
  [[ $1 == --hidden-only ]] && { __ble_opts=hidden-only; shift; }
  ble/util/for-global-variables ble/util/print-global-definitions/.print-decl "$__ble_opts" "$@"
}

## @fn ble/util/for-global-variables proc opts varnames...
##   @fn proc name opts
##     @param[in] name
##       処理対象の変数名を指定します。
##     @param[in] opts
##       指定した名前の変数が見つからない時 unset が指定されます。
##   @param[in] opts
##     hidden-only が含まれている時、対応するグローバル変数が別のローカル変数で
##     被覆されている時にのみ proc を呼び出します。
##   @param[in] varnames...
##     処理対象の変数名の集合を指定します。
function ble/util/for-global-variables {
  local __ble_proc=$1 __ble_opts=$2; shift 2
  local __ble_hidden_only=
  [[ :$__ble_opts: == *:hidden-only:* ]] && __ble_hidden_only=1
  (
    ((_ble_bash>=50000)) && shopt -u localvar_unset
    __ble_error=
    __ble_q="'" __ble_Q="'\''"
    # 補完で 20 階層も関数呼び出しが重なることはなかろう
    __ble_MaxLoop=20
    builtin unset -v "${!_ble_processed_@}"

    for __ble_name; do
      [[ ${__ble_name//[_a-zA-Z0-9]} || $__ble_name == __ble_* ]] && continue
      ((__ble_processed_$__ble_name)) && continue
      ((__ble_processed_$__ble_name=1))

      __ble_found=
      if ((_ble_bash>=40200)); then
        declare -g -r "$__ble_name"
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ! builtin unset -v "$__ble_name"; then
            # Note: Even if the variable is declared readonly at the top level,
            # we can test if the visible variable is global or not by using
            # `(readonly var; ! local var)' because `local var' succeeds if the
            # visible variable is local readonly.
            if builtin readonly "$__ble_name"; ble/variable#is-global/.test "$__ble_name"; then
              __ble_found=1
              [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
                "$__ble_proc" "$__ble_name"
            fi
            break
          fi
        done
      else
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ble/variable#is-global "$__ble_name"; then
            __ble_found=1
            [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
              "$__ble_proc" "$__ble_name"
            break
          fi
          builtin unset -v "$__ble_name" || break
        done
      fi

      if [[ ! $__ble_found ]]; then
        __ble_error=1
        [[ $__ble_hidden_only && $__ble_i == 0 ]] ||
          "$__ble_proc" "$__ble_name" unset
      fi
    done

    [[ ! $__ble_error ]]
  ) 2>/dev/null
}

## @fn ble/util/has-glob-pattern pattern
##   指定したパターンがグロブパターンを含むかどうかを判定します。
##
## Note: Bash 5.0 では変数に \ が含まれている時に echo $var を実行すると
##   パス名展開と解釈されて failglob, nullglob などが有効になるが、
##   echo \[a\] の様に明示的に書いている場合にはパス名展開と解釈されない。
##   この判定では明示的に書いた時にグロブパターンと認識されるかどうかに基づく。
function ble/util/has-glob-pattern {
  [[ $1 ]] || return 1

  local restore=:
  if ! shopt -q nullglob 2>/dev/null; then
    restore="$restore;shopt -u nullglob"
    shopt -s nullglob
  fi
  if shopt -q failglob 2>/dev/null; then
    restore="$restore;shopt -s failglob"
    shopt -u failglob
  fi

  local dummy=$_ble_base_run/$$.dummy ret
  builtin eval "ret=(\"\$dummy\"/${1#/})" 2>/dev/null
  builtin eval -- "$restore"
  [[ ! $ret ]]
}

## @fn ble/util/is-cygwin-slow-glob word
##   Cygwin では // で始まるパスの展開は遅い (#D1168) のでその判定を行う。
function ble/util/is-cygwin-slow-glob {
  # Note: core-complete.sh ではエスケープを行うので
  #   "'//...'" 等の様な文字列が "$1" に渡される。
  [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && ${1#\'} == //* && ! -o noglob ]] &&
    ble/util/has-glob-pattern "$1"
}

## @fn ble/util/eval-pathname-expansion pattern
##   @var[out] ret
function ble/util/eval-pathname-expansion {
  ret=()
  if ble/util/is-cygwin-slow-glob; then # Note: #D1168
    if shopt -q failglob &>/dev/null; then
      return 1
    elif shopt -q nullglob &>/dev/null; then
      return 0
    else
      set -f
      ble/util/eval-pathname-expansion "$1"; local ext=$1
      set +f
      return "$ext"
    fi
  fi

  # adjust glob settings
  local canon=
  if [[ :$2: == *:canonical:* ]]; then
    canon=1
    local set=$- shopt gignore=$GLOBIGNORE
    if ((_ble_bash>=40100)); then
      shopt=$BASHOPTS
    else
      shopt=
      shopt -q failglob && shopt=$shopt:failglob
      shopt -q nullglob && shopt=$shopt:nullglob
      shopt -q extglob && shopt=$shopt:extglob
      shopt -q dotglob && shopt=$shopt:dotglob
    fi
    shopt -u failglob
    shopt -s nullglob
    shopt -s extglob
    set +f
    GLOBIGNORE=
  fi

  # Note: eval で囲んでおかないと failglob 失敗時に続きが実行されない
  # Note: failglob で失敗した時のエラーメッセージは殺す
  builtin eval "ret=($1)" 2>/dev/null; local ext=$?

  # restore glob settings
  if [[ $canon ]]; then
    # Note: dotglob is changed by GLOBIGNORE
    GLOBIGNORE=$gignore
    if [[ :$shopt: == *:dotglob:* ]]; then shopt -s dotglob; else shopt -u dotglob; fi
    [[ $set == *f* ]] && set -f
    [[ :$shopt: != *:extglob:* ]] && shopt -u extglob
    [[ :$shopt: != *:nullglob:* ]] && shopt -u nullglob
    [[ :$shopt: == *:failglob:* ]] && shopt -s failglob
  fi

  return "$ext"
}


# 正規表現は _ble_bash>=30000
_ble_util_rex_isprint='^[ -~]+'
## @fn ble/util/isprint+ str
##
##   @var[out] BASH_REMATCH ble-exit/text/update/position で使用する。
function ble/util/isprint+ {
  local LC_ALL= LC_COLLATE=C
  [[ $1 =~ $_ble_util_rex_isprint ]]
}
# suppress locale error #D1440
ble/function#suppress-stderr ble/util/isprint+

if ((_ble_bash>=40200)); then
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      builtin printf -v "$2" "%($3)T" "${4:--1}"
    else
      builtin printf "%($1)T" "${2:--1}"
    fi
  }
else
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      local fmt=$3 time=$4
      ble/util/assign "$2" 'ble/bin/date +"$fmt" $time'
    else
      ble/bin/date +"$1" $2
    fi
  }
fi

#%< util.hook.sh

#------------------------------------------------------------------------------
# ble/util/msleep

#%include benchmark.sh

function ble/util/msleep/.check-builtin-sleep {
  local ret; ble/util/readlink "$BASH"
  local bash_prefix=${ret%/*/*}
  if [[ -s $bash_prefix/lib/bash/sleep ]] &&
    (enable -f "$bash_prefix/lib/bash/sleep" sleep && builtin sleep 0.0) &>/dev/null; then
    enable -f "$bash_prefix/lib/bash/sleep" sleep
    return 0
  else
    return 1
  fi
}
function ble/util/msleep/.check-sleep-decimal-support {
  local version; ble/util/assign version 'LC_ALL=C ble/bin/sleep --version 2>&1' 2>/dev/null # suppress locale error #D1440
  [[ $version == *'GNU coreutils'* || $OSTYPE == darwin* && $version == 'usage: sleep seconds' ]]
}

_ble_util_msleep_delay=2000 # [usec]
function ble/util/msleep/.core {
  local sec=${1%%.*}
  ((10#0${1##*.}&&sec++)) # 小数部分は切り上げ
  ble/bin/sleep "$sec"
}
function ble/util/msleep {
  local v=$((1000*$1-_ble_util_msleep_delay))
  ((v<=0)) && v=0
  ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
  ble/util/msleep/.core "$v"
}

_ble_util_msleep_calibrate_count=0
function ble/util/msleep/.calibrate-loop {
  local _ble_measure_threshold=10000
  local ret nsec _ble_measure_count=1 v=0
  _ble_util_msleep_delay=0 ble-measure -q 'ble/util/msleep 1'
  local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
  ((count<=0||delay<_ble_util_msleep_delay)) && _ble_util_msleep_delay=$delay # 最小値
  # ((_ble_util_msleep_delay=(count*_ble_util_msleep_delay+delay)/(count+1))) # 平均値
}
function ble/util/msleep/calibrate {
  ble/util/msleep/.calibrate-loop &>/dev/null
  ((++_ble_util_msleep_calibrate_count<5)) &&
    ble/util/idle.continue
}

## @fn ble/util/msleep/.use-read-timeout type
##   @param[in] type
##     FILE.OPEN
##       FILE=fifo mkfifo によりファイルを作成します。
##       FILE=zero /dev/zero を開きます。
##       FILE=ptmx /dev/ptmx を開きます。
##       OPEN=open 毎回ファイルを開きます。
##       OPEN=exec1 ファイルを読み取り専用で開きます。
##       OPEN=exec2 ファイルを読み書き両用で開きます。
##     socket
##       /dev/udp/0.0.0.0/80 を使います。
##     procsub
##       9< <(sleep) を使います。
function ble/util/msleep/.use-read-timeout {
  local msleep_type=$1 opts=${2-}
  _ble_util_msleep_fd=
  case $msleep_type in
  (socket)
    _ble_util_msleep_delay1=10000 # short msleep にかかる時間 [usec]
    _ble_util_msleep_delay2=50000 # /bin/sleep 0 にかかる時間 [usec]
    function ble/util/msleep/.core2 {
      ((v-=_ble_util_msleep_delay2))
      ble/bin/sleep "$((v/1000000))"
      ((v%=1000000))
    }
    function ble/util/msleep {
      local v=$((1000*$1-_ble_util_msleep_delay1))
      ((v<=0)) && v=100
      ((v>1000000+_ble_util_msleep_delay2)) &&
        ble/util/msleep/.core2
      ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
      ! ble/bash/read-timeout "$v" v < /dev/udp/0.0.0.0/80
    }
    function ble/util/msleep/.calibrate-loop {
      local _ble_measure_threshold=10000
      local ret nsec _ble_measure_count=1 v=0

      _ble_util_msleep_delay1=0 ble-measure 'ble/util/msleep 1'
      local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
      ((count<=0||delay<_ble_util_msleep_delay1)) && _ble_util_msleep_delay1=$delay # 最小値

      _ble_util_msleep_delay2=0 ble-measure 'ble/util/msleep/.core2'
      local delay=$((nsec/1000))
      ((count<=0||delay<_ble_util_msleep_delay2)) && _ble_util_msleep_delay2=$delay # 最小値
    } ;;
  (procsub)
    _ble_util_msleep_delay=300
    ble/fd#alloc _ble_util_msleep_fd '< <(
      [[ $- == *i* ]] && builtin trap -- '' INT QUIT
      while kill -0 $$; do command sleep 300; done &>/dev/null
    )'
    function ble/util/msleep {
      local v=$((1000*$1-_ble_util_msleep_delay))
      ((v<=0)) && v=100
      ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
      ! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v
    } ;;
  (*.*)
    if local rex='^(fifo|zero|ptmx)\.(open|exec)([12])(-[a-z]+)?$'; [[ $msleep_type =~ $rex ]]; then
      local file=${BASH_REMATCH[1]}
      local open=${BASH_REMATCH[2]}
      local direction=${BASH_REMATCH[3]}
      local fall=${BASH_REMATCH[4]}

      # tmpfile
      case $file in
      (fifo)
        _ble_util_msleep_tmp=$_ble_base_run/$$.util.msleep.pipe
        if [[ ! -p $_ble_util_msleep_tmp ]]; then
          [[ -e $_ble_util_msleep_tmp ]] && ble/bin/rm -rf "$_ble_util_msleep_tmp"
          ble/bin/mkfifo "$_ble_util_msleep_tmp"
        fi ;;
      (zero)
        open=dup
        _ble_util_msleep_tmp=$_ble_util_fd_zero ;;
      (ptmx)
        _ble_util_msleep_tmp=/dev/ptmx ;;
      esac

      # redirection type
      local redir='<'
      ((direction==2)) && redir='<>'

      # open type
      if [[ $open == dup ]]; then
        _ble_util_msleep_fd=$_ble_util_msleep_tmp
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v'
      elif [[ $open == exec ]]; then
        ble/fd#alloc _ble_util_msleep_fd "$redir \"\$_ble_util_msleep_tmp\""
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" -u "$_ble_util_msleep_fd" v'
      else
        _ble_util_msleep_read='! ble/bash/read-timeout "$v" v '$redir' "$_ble_util_msleep_tmp"'
      fi

      # fallback/switch
      if [[ $fall == '-coreutil' ]]; then
        _ble_util_msleep_switch=200 # [msec]
        _ble_util_msleep_delay1=2000 # short msleep にかかる時間 [usec]
        _ble_util_msleep_delay2=50000 # /bin/sleep 0 にかかる時間 [usec]
        function ble/util/msleep {
          if (($1<_ble_util_msleep_switch)); then
            local v=$((1000*$1-_ble_util_msleep_delay1))
            ((v<=0)) && v=100
            ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
            builtin eval -- "$_ble_util_msleep_read"
          else
            local v=$((1000*$1-_ble_util_msleep_delay2))
            ((v<=0)) && v=100
            ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
            ble/bin/sleep "$v"
          fi
        }
        function ble/util/msleep/.calibrate-loop {
          local _ble_measure_threshold=10000
          local ret nsec _ble_measure_count=1

          _ble_util_msleep_switch=200
          _ble_util_msleep_delay1=0 ble-measure 'ble/util/msleep 1'
          local delay=$((nsec/1000-1000)) count=$_ble_util_msleep_calibrate_count
          ((count<=0||delay<_ble_util_msleep_delay1)) && _ble_util_msleep_delay1=$delay # 最小値を選択

          _ble_util_msleep_delay2=0 ble-measure 'ble/bin/sleep 0'
          local delay=$((nsec/1000))
          ((count<=0||delay<_ble_util_msleep_delay2)) && _ble_util_msleep_delay2=$delay # 最小値を選択
          ((_ble_util_msleep_switch=_ble_util_msleep_delay2/1000+10))
        }
      else
        function ble/util/msleep {
          local v=$((1000*$1-_ble_util_msleep_delay))
          ((v<=0)) && v=100
          ble/util/sprintf v '%d.%06d' "$((v/1000000))" "$((v%1000000))"
          builtin eval -- "$_ble_util_msleep_read"
        }
      fi
    fi ;;
  esac

  # Note: 古い Cygwin では双方向パイプで "Communication error on send" というエラーになる。
  #   期待通りの振る舞いをしなかったらプロセス置換に置き換える。 #D1449
  # #D1467 Cygwin/Linux では timeout は 142 だが、これはシステム依存。
  #   man bash にある様に 128 より大きいかどうかで判定
  if [[ :$opts: == *:check:* && $_ble_util_msleep_fd ]]; then
    if ble/bash/read-timeout 0.000001 -u "$_ble_util_msleep_fd" _ble_util_msleep_dummy 2>/dev/null; (($?<=128)); then
      ble/fd#close _ble_util_msleep_fd
      _ble_util_msleep_fd=
      return 1
    fi
  fi
  return 0
}

_ble_util_msleep_builtin_available=
if ((_ble_bash>=40400)) && ble/util/msleep/.check-builtin-sleep; then
  _ble_util_msleep_builtin_available=1
  _ble_util_msleep_delay=300
  function ble/util/msleep/.core { builtin sleep "$1"; }

  ## @fn ble/builtin/sleep/.read-time time
  ##   @var[out] a1 b1
  ##     それぞれ整数部と小数部を返します。
  ##   @var[in,out] flags
  function ble/builtin/sleep/.read-time {
    a1=0 b1=0
    local unit= exp=
    if local rex='^\+?([0-9]*)\.([0-9]*)([eE][-+]?[0-9]+)?([smhd]?)$'; [[ $1 =~ $rex ]]; then
      a1=${BASH_REMATCH[1]}
      b1=${BASH_REMATCH[2]}00000000000000
      b1=$((10#0${b1::14}))
      exp=${BASH_REMATCH[3]}
      unit=${BASH_REMATCH[4]}
    elif rex='^\+?([0-9]+)([eE][-+]?[0-9]+)?([smhd]?)$'; [[ $1 =~ $rex ]]; then
      a1=${BASH_REMATCH[1]}
      exp=${BASH_REMATCH[2]}
      unit=${BASH_REMATCH[3]}
    else
      ble/util/print "ble/builtin/sleep: invalid time spec '$1'" >&2
      flags=E$flags
      return 2
    fi

    if [[ $exp ]]; then
      case $exp in
      ([eE]-*)
        ((exp=10#0${exp:2}))
        while ((exp--)); do
          ((b1=a1%10*frac_scale/10+b1/10,a1/=10))
        done ;;
      ([eE]*)
        exp=${exp:1}
        ((exp=${exp#+}))
        while ((exp--)); do
          ((b1*=10,a1=a1*10+b1/frac_scale,b1%=frac_scale))
        done ;;
      esac
    fi

    local scale=
    case $unit in
    (d) ((scale=24*3600)) ;;
    (h) ((scale=3600)) ;;
    (m) ((scale=60)) ;;
    esac
    if [[ $scale ]]; then
      ((b1*=scale))
      ((a1=a1*scale+b1/frac_scale))
      ((b1%=frac_scale))
    fi
    return 0
  }

  function ble/builtin/sleep {
    local set shopt; ble/base/.adjust-bash-options set shopt
    local frac_scale=100000000000000
    local a=0 b=0 flags=
    if (($#==0)); then
      ble/util/print "ble/builtin/sleep: no argument" >&2
      flags=E$flags
    fi
    while (($#)); do
      case $1 in
      (--version) flags=v$flags ;;
      (--help)    flags=h$flags ;;
      (-*)
        flags=E$flags
        ble/util/print "ble/builtin/sleep: unknown option '$1'" >&2 ;;
      (*)
        if local a1 b1; ble/builtin/sleep/.read-time "$1"; then
          ((b+=b1))
          ((a=a+a1+b/frac_scale))
          ((b%=frac_scale))
        fi ;;
      esac
      shift
    done
    if [[ $flags == *h* ]]; then
      ble/util/print-lines \
        'usage: sleep NUMBER[SUFFIX]...' \
        'Pause for the time specified by the sum of the arguments. SUFFIX is one of "s"' \
        '(seconds), "m" (minutes), "h" (hours) or "d" (days).' \
        '' \
        'OPTIONS' \
        '     --help    Show this help.' \
        '     --version Show version.'
    fi
    if [[ $flags == *v* ]]; then
      ble/util/print "sleep (ble) $BLE_VERSION"
    fi
    if [[ $flags == *E* ]]; then
      ble/util/setexit 2
    elif [[ $flags == *[vh]* ]]; then
      ble/util/setexit 0
    else
      b=00000000000000$b
      b=${b:${#b}-14}
      builtin sleep "$a.$b"
    fi
    local ext=$?
    ble/base/.restore-bash-options set shopt 1
    return "$ext"
  }
  function sleep { ble/builtin/sleep "$@"; }
elif [[ -f $_ble_base/lib/init-msleep.sh ]] &&
       source "$_ble_base/lib/init-msleep.sh" &&
       ble/util/msleep/.load-compiled-builtin
then
  # 自前で sleep.so をコンパイルする。
  #
  # Note: #D1452 #D1468 #D1469 元々使っていた read -t による手法が
  # Bash のバグでブロックする事が分かった。bash 4.3..5.1 ならばどの OS
  # でも再現する。仕方が無いので自前で loadable builtin をコンパイルす
  # る事にした。と思ったがライセンスの問題でこれを有効にする訳には行か
  # ない。
  function ble/util/msleep { ble/builtin/msleep "$1"; }
elif ((40000<=_ble_bash&&!(40300<=_ble_bash&&_ble_bash<50200))) &&
       [[ $OSTYPE != cygwin* && $OSTYPE != mingw* && $OSTYPE != haiku* && $OSTYPE != minix* ]]
then
  # FIFO (mkfifo) を予め読み書き両用で開いて置き read -t する方法。
  #
  # Note: #D1452 #D1468 #D1469 Bash 4.3 以降では一般に read -t が
  # SIGALRM との race condition で固まる可能性がある。socket
  # (/dev/udp) や fifo で特に問題が発生しやすい。特に Cygwin で顕著。
  # 但し、発生する頻度は環境や用法・手法によって異なる。Cygwin/MSYS,
  # Haiku 及び Minix では fifo は思う様に動かない。
  ble/util/msleep/.use-read-timeout fifo.exec2
elif ((_ble_bash>=40000)) && ble/fd#is-open "$_ble_util_fd_zero"; then
  # /dev/zero に対して read -t する方法。
  #
  # Note: #D1452 #D1468 #D1469 元々使っていた FIFO に対する方法が安全
  # でない時は /dev/zero に対して read -t する。0 を読み続ける事になる
  # ので CPU を使う事になるが短時間の sleep の時のみに使う事にして我慢
  # する事にする。確認した全ての OS で /dev/zero は存在した (Linux,
  # Cygwin, FreeBSD, Solaris, Minix, Haiku, MSYS2)。
  ble/util/msleep/.use-read-timeout zero.exec1-coreutil
elif ble/bin#freeze-utility-path sleepenh; then
  function ble/util/msleep/.core { ble/bin/sleepenh "$1" &>/dev/null; }
elif ble/bin#freeze-utility-path usleep; then
  function ble/util/msleep {
    local v=$((1000*$1-_ble_util_msleep_delay))
    ((v<=0)) && v=0
    ble/bin/usleep "$v" &>/dev/null
  }
elif ble/util/msleep/.check-sleep-decimal-support; then
  function ble/util/msleep/.core { ble/bin/sleep "$1"; }
fi

function ble/util/sleep {
  local msec=$((${1%%.*}*1000))
  if [[ $1 == *.* ]]; then
    frac=${1##*.}000
    ((msec+=10#0${frac::3}))
  fi
  ble/util/msleep "$msec"
}

#------------------------------------------------------------------------------
# ble/util/conditional-sync

function ble/util/conditional-sync/.collect-descendant-pids {
  local pid=$1 awk_script='
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
      child[$2,child[$2]++]=$1;
    }
    function print_recursive(pid, _, n, i) {
      if (child[pid]) {
        n = child[pid];
        child[pid] = 0; # avoid infinite loop
        for (i = 0; i < n; i++) {
          print_recursive(child[pid, i]);
        }
      }
      print pid;
    }
    END { print_recursive(pid); }
  '
  ble/util/assign ret 'ble/bin/ps -A -o pid,ppid'
  ble/util/assign-array ret 'ble/bin/awk -v pid="$pid" "$awk_script" <<< "$ret"'
}

## @fn ble/util/conditional-sync/.kill
##   @var[in] __ble_pid
##   @var[in] __ble_opts
function ble/util/conditional-sync/.kill {
  [[ $__ble_pid ]] || return 0
  local kill_pids
  if [[ :$__ble_opts: == *:killall:* ]]; then
    ble/util/conditional-sync/.collect-descendant-pids "$__ble_pid"
    kill_pids=("${ret[@]}")
  else
    kill_pids=("$__ble_pid")
  fi

  # Note #D2031: In Cygwin/MSYS2 (Windows), we somehow need to fork at least
  # one process before `kill` to make sure it works.
  if [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]]; then
    (ble/util/setexit 0)
  fi

  if [[ :$__ble_opts: == *:SIGKILL:* ]]; then
    builtin kill -9 "${kill_pids[@]}" &>/dev/null
  else
    builtin kill -- "${kill_pids[@]}" &>/dev/null
  fi
} &>/dev/null

## @fn ble/util/conditional-sync command [condition weight opts]
##   Evaluate COMMAND and kill it when CONDITION becomes unsatisfied before
##   COMMAND ends.
##
##   @param[in] command
##     The command that is evaluated in a subshell.  If an empty string is
##     specified, only the CONDITION is checked for the synchronization and any
##     background subshell is not started.
##
##   @param[in,opt] condition
##     The command to test the condition to continue to run the command.  The
##     default condition is "! ble/decode/has-input".  The following local
##     variables are available from the condition command:
##
##     @var sync_elapsed
##       Accumulated time of sleep in milliseconds.
##
##   @param[in,opt] weight
##     The interval of checking CONDITION in milliseconds.  The default is
##     "100".
##   @param[in,opt] opts
##     A colon-separated list of the following fields to control the detailed
##     behavior:
##
##     @opt progressive-weight
##       The interval of checking CONDITION is gradually increased and stops
##       at the value specified by WEIGHT.
##     @opt timeout=TIMEOUT
##       When this is specified, COMMAND is unconditionally terminated when
##       it does not end until the time specified by TIMEOUT in milliseconds
##     @opt killall
##       Kill also all the children and descendant processes. When this is
##       unspecified, only the subshell used to run COMMAND is killed.
##     @opt SIGKILL
##       The processes are killed by SIGKILL.  When this is unspecified, the
##       processes are killed by SIGTERM.
##
##     @opt pid=PID
##       When specified, COMMAND is not evaluate, and the function instead
##       waits for the exit of the process specified by PID.  If a negative
##       integer is specified, it is treated as PGID.  When the condition is
##       unsatisfied or the timeout has been reached, the specified process
##       will be killed.
##
##     @opt no-wait-pid
##       Do not wait for the exit status of the background process
##
function ble/util/conditional-sync {
  local __ble_command=$1
  local __ble_continue=${2:-'! ble/decode/has-input'}
  local __ble_weight=$3; ((__ble_weight<=0&&(__ble_weight=100)))
  local __ble_opts=$4

  local __ble_timeout= __ble_rex=':timeout=([^:]+):'
  [[ :$__ble_opts: =~ $__ble_rex ]] && ((__ble_timeout=BASH_REMATCH[1]))

  [[ :$__ble_opts: == *:progressive-weight:* ]] &&
    local __ble_weight_max=$__ble_weight __ble_weight=1

  # read opt "pid=PID/-PGID"
  local ret
  ble/opts#extract-last-optarg "$__ble_opts" pid
  local __ble_pid=$ret
  ble/util/unlocal ret

  local sync_elapsed=0
  if [[ $__ble_timeout ]] && ((__ble_timeout<=0)); then
    ble/util/conditional-sync/.kill
    return 142
  fi
  builtin eval -- "$__ble_continue" || return 148
  (
    [[ $__ble_pid ]] || builtin eval -- "$__ble_command" & __ble_pid=$!
    while
      # check timeout
      if [[ $__ble_timeout ]]; then
        if ((__ble_timeout<=0)); then
          ble/util/conditional-sync/.kill
          return 142
        fi
        ((__ble_weight>__ble_timeout)) && __ble_weight=$__ble_timeout
        ((__ble_timeout-=__ble_weight))
      fi

      ble/util/msleep "$__ble_weight"
      ((sync_elapsed+=__ble_weight))
      [[ :$__ble_opts: == *:progressive-weight:* ]] &&
        ((__ble_weight<<=1,__ble_weight>__ble_weight_max&&(__ble_weight=__ble_weight_max)))
      [[ ! $__ble_pid ]] || builtin kill -0 "$__ble_pid" &>/dev/null
    do
      if ! builtin eval -- "$__ble_continue"; then
        ble/util/conditional-sync/.kill
        return 148
      fi
    done
    [[ ! $__ble_pid || :$__ble_opts: == *:no-wait-pid:* ]] || wait "$__ble_pid"
  )
}

#------------------------------------------------------------------------------

## @fn ble/util/cat [files..]
##   cat の代替。直接扱えない NUL で区切って読み出す。
function ble/util/cat/.impl {
  local content= IFS=
  while ble/bash/read -d '' content; do
    printf '%s\0' "$content"
  done
  [[ $content ]] && printf '%s' "$content"
}
function ble/util/cat {
  if (($#)); then
    local file
    for file; do ble/util/cat/.impl < "$1"; done
  else
    ble/util/cat/.impl
  fi
}

_ble_util_less_fallback=
function ble/util/get-pager {
  if [[ ! $_ble_util_less_fallback ]]; then
    if type -t less &>/dev/null; then
      _ble_util_less_fallback=less
    elif type -t pager &>/dev/null; then
      _ble_util_less_fallback=pager
    elif type -t more &>/dev/null; then
      _ble_util_less_fallback=more
    else
      _ble_util_less_fallback=cat
    fi
  fi

  builtin eval "$1=\${bleopt_pager:-\${PAGER:-\$_ble_util_less_fallback}}"
}
function ble/util/pager {
  local pager; ble/util/get-pager pager
  builtin eval -- "$pager \"\$@\""
}

_ble_util_file_stat=
function ble/file/has-stat {
  if [[ ! $_ble_util_file_stat ]]; then
    _ble_util_file_stat=-
    if ble/bin#freeze-utility-path -n stat; then
      # 参考: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
      if ble/bin/stat -c %Y / &>/dev/null; then
        _ble_util_file_stat=c
      elif ble/bin/stat -f %m / &>/dev/null; then
        _ble_util_file_stat=f
      fi
    fi
  fi

  function ble/file/has-stat { [[ $_ble_util_file_stat != - ]]; } || return 1
  ble/file/has-stat
}

## @fn ble/file#mtime filename
##   ファイル filename の mtime を取得します。
##   @param[in] filename ファイル名を指定します。
##
##   @var[out] ret
##     時刻を Unix Epoch で取得します。
##     秒以下の少数も取得できる場合には ret[1] に小数部を格納します。
##
function ble/file#mtime {
  # fallback: print current time
  function ble/file#mtime { ble/util/strftime -v ret '%s %N'; ble/string#split-words ret "$ret"; ((0)); } || return 1

  if ble/bin/date -r / +%s &>/dev/null; then
    function ble/file#mtime { local file=$1; ble/util/assign-words ret 'ble/bin/date -r "$file" +"%s %N"' 2>/dev/null; }
  elif ble/file/has-stat; then
    # 参考: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
    case $_ble_util_file_stat in
    (c) function ble/file#mtime { local file=$1; ble/util/assign ret 'ble/bin/stat -c %Y "$file"' 2>/dev/null; } ;;
    (f) function ble/file#mtime { local file=$1; ble/util/assign ret 'ble/bin/stat -f %m "$file"' 2>/dev/null; } ;;
    esac
  fi

  ble/file#mtime "$@"
}

function ble/file#inode {
  # fallback
  function ble/file#inode { ret=; ((0)); } || return 1

  if ble/bin#freeze-utility-path -n ls &&
      ble/util/assign-words ret 'ble/bin/ls -di /' 2>/dev/null &&
      ((${#ret[@]}==2)) && ble/string#match "$ret" '^[0-9]+$'
  then
    function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/ls -di "$file"' 2>/dev/null; }
  elif ble/file/has-stat; then
    case $_ble_util_file_stat in
    (c) function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/stat -c %i "$file"' 2>/dev/null; } ;;
    (f) function ble/file#inode { local file=$1; ble/util/assign-words ret 'ble/bin/stat -f %i "$file"' 2>/dev/null; } ;;
    esac
  fi

  ble/file#inode "$@"
}

function ble/file#hash {
  local file=$1 size
  if ! ble/util/assign size 'ble/bin/wc -c "$file" 2>/dev/null'; then
    ret=error:$RANDOM
    return 1
  fi
  ble/string#split-words size "$size"
  ble/file#hash/.impl
}
if ble/bin#freeze-utility-path -n git; then
  function ble/file#hash/.impl {
    ble/util/assign ret 'ble/bin/git hash-object "$file"'
    ret="size:$size;hash:$ret"
  }
elif ble/bin#freeze-utility-path -n openssl; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/openssl sha1 -r "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n sha1sum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/sha1sum "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n sha1; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/sha1 -r "$file"'
    ret="size:$size;sha1:$ret"
  }
elif ble/bin#freeze-utility-path -n md5sum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/md5sum "$file"'
    ret="size:$size;md5:$ret"
  }
elif ble/bin#freeze-utility-path -n md5; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/md5 -r "$file"'
    ret="size:$size;md5:$ret"
  }
elif ble/bin#freeze-utility-path -n cksum; then
  function ble/file#hash/.impl {
    ble/util/assign-words ret 'ble/bin/cksum "$file"'
    ret="size:$size;cksum:$ret"
  }
else
  function ble/file#hash/.impl {
    ret="size:$size"
  }
fi

#------------------------------------------------------------------------------
## @fn ble/util/buffer text
_ble_util_buffer=()
function ble/util/buffer {
  _ble_util_buffer[${#_ble_util_buffer[@]}]=$1
}
function ble/util/buffer.print {
  ble/util/buffer "$1"$'\n'
}
function ble/util/buffer.flush {
  IFS= builtin eval 'local text="${_ble_util_buffer[*]-}"'
  _ble_util_buffer=()
  [[ $text ]] || return 0

  # Note: 出力の瞬間だけカーソルを非表示にする。Windows terminal など途中
  # のカーソル移動も無理やり表示しようとする端末に対する対策。
  [[ $_ble_term_state == internal ]] &&
    [[ $_ble_term_cursor_hidden_internal != hidden ]] &&
    [[ $text != *"$_ble_term_civis"* && $text != *"$_ble_term_cvvis"* ]] &&
    text=$_ble_term_civis$text$_ble_term_cvvis

  ble/util/put "$text"
}
function ble/util/buffer.clear {
  _ble_util_buffer=()
}

#------------------------------------------------------------------------------
# class dirty-range, urange

function ble/dirty-range#load {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    ((beg=${prefix}beg,
      end=${prefix}end,
      end0=${prefix}end0))
  fi
}

function ble/dirty-range#clear {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    shift
  fi

  ((${prefix}beg=-1,
    ${prefix}end=-1,
    ${prefix}end0=-1))
}

## @fn ble/dirty-range#update [--prefix=PREFIX] beg end end0
##   @param[out] PREFIX
##   @param[in]  beg    変更開始点。beg<0 は変更がない事を表す
##   @param[in]  end    変更終了点。end<0 は変更が末端までである事を表す
##   @param[in]  end0   変更前の end に対応する位置。
function ble/dirty-range#update {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#--prefix=}
    shift
    [[ $prefix ]] && local beg end end0
  fi

  local begB=$1 endB=$2 endB0=$3
  ((begB<0)) && return 1

  local begA endA endA0
  ((begA=${prefix}beg,endA=${prefix}end,endA0=${prefix}end0))

  local delta
  if ((begA<0)); then
    ((beg=begB,
      end=endB,
      end0=endB0))
  else
    ((beg=begA<begB?begA:begB))
    if ((endA<0||endB<0)); then
      ((end=-1,end0=-1))
    else
      ((end=endB,end0=endA0,
        (delta=endA-endB0)>0?(end+=delta):(end0-=delta)))
    fi
  fi

  if [[ $prefix ]]; then
    ((${prefix}beg=beg,
      ${prefix}end=end,
      ${prefix}end0=end0))
  fi
}

## @fn ble/urange#clear [--prefix=prefix]
##
##   @param[in,opt] prefix=
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#clear {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  ((${prefix}umin=-1,${prefix}umax=-1))
}
## @fn ble/urange#update [--prefix=prefix] min max
##
##   @param[in,opt] prefix=
##   @param[in]     min max
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#update {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  local min=$1 max=$2
  ((0<=min&&min<max)) || return 1
  (((${prefix}umin<0||min<${prefix}umin)&&(${prefix}umin=min),
    (${prefix}umax<0||${prefix}umax<max)&&(${prefix}umax=max)))
}
## @fn ble/urange#shift [--prefix=prefix] dbeg dend dend0
##
##   @param[in,opt] prefix=
##   @param[in]     dbeg dend dend0
##   @var[in,out]   {prefix}umin {prefix}umax
##
function ble/urange#shift {
  local prefix=
  if [[ $1 == --prefix=* ]]; then
    prefix=${1#*=}; shift
  fi
  local dbeg=$1 dend=$2 dend0=$3 shift=$4
  ((dbeg>=0)) || return 1
  [[ $shift ]] || ((shift=dend-dend0))
  ((${prefix}umin>=0&&(
      dbeg<=${prefix}umin&&(${prefix}umin<=dend0?(${prefix}umin=dend):(${prefix}umin+=shift)),
      dbeg<=${prefix}umax&&(${prefix}umax<=dend0?(${prefix}umax=dbeg):(${prefix}umax+=shift))),
    ${prefix}umin<${prefix}umax||(
      ${prefix}umin=-1,
      ${prefix}umax=-1)))
}

#------------------------------------------------------------------------------
## @fn ble/util/joblist opts
##   現在のジョブ一覧を取得すると共に、ジョブ状態の変化を調べる。
##
##   @param[in] opts
##     ignore-volatile-jobs
##
##   @var[in,out] _ble_util_joblist_events
##   @var[out]    joblist                ジョブ一覧を格納する配列
##   @var[in,out] _ble_util_joblist_jobs 内部使用
##   @var[in,out] _ble_util_joblist_list 内部使用
##
##   @remark 実装方法について。
##   終了したジョブを確認するために内部で2回 jobs を呼び出す。
##   比較のために前回の jobs の呼び出し結果も _ble_util_joblist_{jobs,list} (#1) に記録する。
##   先ず jobs0,list (#2) に1回目の jobs 呼び出し結果を格納して #1 と #2 の比較を行いジョブ状態の変化を調べる。
##   次に #1 に2回目の jobs 呼び出し結果を上書きして #2 と #1 の比較を行い終了ジョブを調べる。
##
_ble_util_joblist_jobs=
_ble_util_joblist_list=()
_ble_util_joblist_events=()
function ble/util/joblist {
  local opts=$1 jobs0
  ble/util/assign jobs0 'jobs'
  if [[ $jobs0 == "$_ble_util_joblist_jobs" ]]; then
    # 前回の呼び出し結果と同じならば状態変化はないものとして良い。終了・強制終
    # 了したジョブがあるとしたら "終了" だとか "Terminated" だとかいう表示にな
    # っているはずだが、その様な表示は二回以上は為されないので必ず変化がある。
    joblist=("${_ble_util_joblist_list[@]}")
    return 0
  elif [[ ! $jobs0 ]]; then
    # 前回の呼び出しで存在したジョブが新しい呼び出しで無断で消滅することは恐ら
    # くない。今回の結果が空という事は本来は前回の結果も空のはずであり、だとす
    # ると上の分岐に入るはずなのでここには来ないはずだ。しかしここに入った時の
    # 為に念を入れて空に設定して戻るようにする。
    _ble_util_joblist_jobs=
    _ble_util_joblist_list=()
    joblist=()
    return 0
  fi

  local lines list ijob
  ble/string#split lines $'\n' "$jobs0"
  if ((${#lines[@]})); then
    ble/util/joblist.split list "${lines[@]}"
  else
    list=()
  fi

  # check changed jobs from _ble_util_joblist_list to list
  if [[ $jobs0 != "$_ble_util_joblist_jobs" ]]; then
    for ijob in "${!list[@]}"; do
      if [[ ${_ble_util_joblist_list[ijob]} && ${list[ijob]#'['*']'[-+ ]} != "${_ble_util_joblist_list[ijob]#'['*']'[-+ ]}" ]]; then
        if [[ ${list[ijob]} != *'__ble_suppress_joblist__'* ]]; then
          ble/array#push _ble_util_joblist_events "${list[ijob]}"
        fi
        list[ijob]=
      fi
    done
  fi

  ble/util/assign _ble_util_joblist_jobs 'jobs'
  _ble_util_joblist_list=()
  if [[ $_ble_util_joblist_jobs != "$jobs0" ]]; then
    ble/string#split lines $'\n' "$_ble_util_joblist_jobs"
    ble/util/joblist.split _ble_util_joblist_list "${lines[@]}"

    # check removed jobs through list -> _ble_util_joblist_list.
    if [[ :$opts: != *:ignore-volatile-jobs:* ]]; then
      for ijob in "${!list[@]}"; do
        local job0=${list[ijob]}
        if [[ $job0 && ! ${_ble_util_joblist_list[ijob]} ]]; then
          if [[ $job0 != *'__ble_suppress_joblist__'* ]]; then
            ble/array#push _ble_util_joblist_events "$job0"
          fi
        fi
      done
    fi
  else
    for ijob in "${!list[@]}"; do
      [[ ${list[ijob]} ]] &&
        _ble_util_joblist_list[ijob]=${list[ijob]}
    done
  fi
  joblist=("${_ble_util_joblist_list[@]}")
} 2>/dev/null

function ble/util/joblist.split {
  local arr=$1; shift
  local line ijob= rex_ijob='^\[([0-9]+)\]'
  for line; do
    [[ $line =~ $rex_ijob ]] && ijob=${BASH_REMATCH[1]}
    [[ $ijob ]] && builtin eval "$arr[ijob]=\${$arr[ijob]}\${$arr[ijob]:+\$_ble_term_nl}\$line"
  done
}

## @fn ble/util/joblist.check
##   ジョブ状態変化の確認だけ行います。
##   内部的に jobs を呼び出す直前に、ジョブ状態変化を取り逃がさない為に明示的に呼び出します。
function ble/util/joblist.check {
  local joblist
  ble/util/joblist "$@"
}
## @fn ble/util/joblist.has-events
##   未出力のジョブ状態変化の記録があるかを確認します。
function ble/util/joblist.has-events {
  local joblist
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]}))
}

## @fn ble/util/joblist.flush
##   ジョブ状態変化の確認とそれまでに検出した変化の出力を行います。
function ble/util/joblist.flush {
  local joblist
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return 1
  printf '%s\n' "${_ble_util_joblist_events[@]}"
  _ble_util_joblist_events=()
}
function ble/util/joblist.bflush {
  local joblist out
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return 1
  ble/util/sprintf out '%s\n' "${_ble_util_joblist_events[@]}"
  ble/util/buffer "$out"
  _ble_util_joblist_events=()
}

## @fn ble/util/joblist.clear
##   bash 自身によってジョブ状態変化が出力される場合には比較用のバッファを clear します。
function ble/util/joblist.clear {
  _ble_util_joblist_jobs=
  _ble_util_joblist_list=()
}

#------------------------------------------------------------------------------
## @fn ble/util/save-editing-mode varname
##   現在の編集モード (emacs/vi/none) を変数に設定します。
##
##   @param varname 設定する変数の変数名を指定します。
##
function ble/util/save-editing-mode {
  if [[ -o emacs ]]; then
    builtin eval "$1=emacs"
  elif [[ -o vi ]]; then
    builtin eval "$1=vi"
  else
    builtin eval "$1=none"
  fi
}
## @fn ble/util/restore-editing-mode varname
##   編集モードを復元します。
##
##   @param varname 編集モードを記録した変数の変数名を指定します。
##
function ble/util/restore-editing-mode {
  case ${!1} in
  (emacs) set -o emacs ;;
  (vi) set -o vi ;;
  (none) set +o emacs ;;
  esac
}

## @fn ble/util/reset-keymap-of-editing-mode
##   既定の keymap に戻す。bind 'set keymap vi-insert' 等で
##   既定の keymap 以外になっている事がある。
##   set -o emacs/vi を実行すれば既定の keymap に戻る。#D1038
function ble/util/reset-keymap-of-editing-mode {
  if [[ -o emacs ]]; then
    set -o emacs
  elif [[ -o vi ]]; then
    set -o vi
  fi
}

## @fn ble/util/rlvar#load
##   @var[out] _ble_local_rlvars
function ble/util/rlvar#load {
  # Note (#D1823): suppress warnings in a non-interactive session
  ble/util/assign _ble_local_rlvars 'builtin bind -v 2>/dev/null'
  _ble_local_rlvars=$'\n'$_ble_local_rlvars
}

## @fn ble/util/rlvar#has name
##   指定した readline 変数に bash が対応しているか確認します。
function ble/util/rlvar#has {
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  [[ $_ble_local_rlvars == *$'\n'"set $1 "* ]]
}

## @fn ble/util/rlvar#test name [default(0 or 1)]
function ble/util/rlvar#test {
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  if [[ $_ble_local_rlvars == *$'\n'"set $1 on"* ]]; then
    return 0
  elif [[ $_ble_local_rlvars == *$'\n'"set $1 off"* ]]; then
    return 1
  elif (($#>=2)); then
    (($2))
    return "$?"
  else
    return 2
  fi
}
## @fn ble/util/rlvar#read name [default_value]
function ble/util/rlvar#read {
  [[ ${2+set} ]] && ret=$2
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi
  local rhs=${_ble_local_rlvars#*$'\n'"set $1 "}
  [[ $rhs != "$_ble_local_rlvars" ]] && ret=${rhs%%$'\n'*}
}

## @fn ble/util/rlvar#bind-bleopt name bleopt [opts]
function ble/util/rlvar#bind-bleopt {
  local name=$1 bleopt=$2 opts=$3
  if [[ ! ${_ble_local_rlvars:-} ]]; then
    local _ble_local_rlvars
    ble/util/rlvar#load
  fi

  # Bash が readlie 変数に対応している場合、bleopt に対する代入と合わせて
  # readline 変数にも対応する値を設定する。
  if ble/util/rlvar#has "$name"; then
    # 値の同期
    # Note (#D1148): ble.sh の側で Bash と異なる既定値を持っている物については
    # (初期化時に --keep-rlvars を指定していない限りは) ble.sh の側に書き換えて
    # しまう。多くのユーザは自分で設定しないので便利な機能が off になっている。
    # 一方で設定するユーザは自分で off に戻すぐらいはできるだろう。
    if [[ :$_ble_base_arguments_opts: == *:keep-rlvars:* ]]; then
      local ret; ble/util/rlvar#read "$name"
      [[ :$opts: == *:bool:* && $ret == off ]] && ret=
      bleopt "$bleopt=$ret"
    else
      local var=bleopt_$bleopt val=off
      [[ ${!var:-} ]] && val=on
      # Note: #D1823 suppress stderr for non-interactive warning
      builtin bind "set $name $val" 2>/dev/null
    fi

    local proc_original=
    if ble/is-function "bleopt/check:$bleopt"; then
      ble/function#push "bleopt/check:$bleopt"
      proc_original='ble/function#push/call-top "$@" || return "$?"'
    fi

    # Note: #D1823 suppress stderr for non-interactive warning
    local proc_set='builtin bind "set '$name' $value" 2>/dev/null'
    if [[ :$opts: == *:bool:* ]]; then
      proc_set='
        if [[ $value ]]; then
          builtin bind "set '$name' on" 2>/dev/null
        else
          builtin bind "set '$name' off" 2>/dev/null
        fi'
    fi

    builtin eval -- "
      function bleopt/check:$bleopt {
        $proc_original
        $proc_set
        return 0
      }"
  fi

  local proc_bleopt='bleopt '$bleopt'="$1"'
  if [[ :$opts: == *:bool:* ]]; then
    proc_bleopt='
      local value; ble/string#split-words value "$1"
      if [[ ${value-} == 1 || ${value-} == [Oo][Nn] ]]; then
        bleopt '$bleopt'="$value"
      else
        bleopt '$bleopt'=
      fi'
  fi
  builtin eval -- "
    function ble/builtin/bind/set:$name {
      $proc_bleopt
      return 0
    }"
}

#------------------------------------------------------------------------------
# Functions for modules

## @fn ble/util/invoke-hook array
##   array に登録されているコマンドを実行します。
function ble/util/invoke-hook {
  local -a hooks; builtin eval "hooks=(\"\${$1[@]}\")"
  local hook ext=0
  for hook in "${hooks[@]}"; do builtin eval -- "$hook \"\${@:2}\"" || ext=$?; done
  return "$ext"
}

## @fn ble/util/.read-arguments-for-no-option-command commandname args...
##   @var[out] flags args
function ble/util/.read-arguments-for-no-option-command {
  local commandname=$1; shift
  flags= args=()

  local flag_literal=
  while (($#)); do
    local arg=$1; shift
    if [[ ! $flag_literal ]]; then
      case $arg in
      (--) flag_literal=1 ;;
      (--help) flags=h$flags ;;
      (-*)
        ble/util/print "$commandname: unrecognized option '$arg'" >&2
        flags=e$flags ;;
      (*)
        ble/array#push args "$arg" ;;
      esac
    else
      ble/array#push args "$arg"
    fi
  done
}


## @fn ble-autoload scriptfile functions...
##   関数が定義されたファイルを自動で読み取る設定を行います。
##   scriptfile には functions の実体を定義します。
##   functions に指定した関数が初めて呼び出された時に、
##   scriptfile が自動的に source されます。
##
##   @param[in] scriptfile
##     functions が定義されているファイル
##
##     注意: このファイル内でグローバルに変数を定義する際は
##     declare/typeset を用いないで下さい。
##     autoload を行う関数内から source されるので、
##     その関数のローカル変数として扱われてしまいます。
##     連想配列などの特殊変数を定義したい場合は ble-autoload
##     の設定時に同時に行って下さい。
##     ※declare -g は bash-4.3 以降です
##
##   @param[in] functions...
##     定義する関数名のリスト
##
##     scriptfile の source の起点となる関数です。
##     scriptfile に定義される関数名を全て列挙する必要はなく、
##     scriptfile 呼出の起点として使用する関数のみで充分です。
##
function ble/util/autoload {
  local file=$1; shift
  ble/util/import/is-loaded "$file" && return 0

  # ※$FUNCNAME は元から環境変数に設定されている場合、
  #   特別変数として定義されない。
  #   この場合無闇にコマンドとして実行するのは危険である。

  local q=\' Q="'\''" funcname
  for funcname; do
    builtin eval "function $funcname {
      builtin unset -f $funcname
      ble-import '${file//$q/$Q}' &&
        $funcname \"\$@\"
    }"
  done
}
function ble/util/autoload/.print-usage {
  ble/util/print 'usage: ble-autoload SCRIPTFILE FUNCTION...'
  ble/util/print '  Setup delayed loading of functions defined in the specified script file.'
} >&2
## @fn ble/util/autoload/.read-arguments args...
##   @var[out] file functions flags
function ble/util/autoload/.read-arguments {
  file= flags= functions=()

  local args
  ble/util/.read-arguments-for-no-option-command ble-autoload "$@"

  # check empty arguments
  local arg index=0
  for arg in "${args[@]}"; do
    if [[ ! $arg ]]; then
      if ((index==0)); then
        ble/util/print 'ble-autoload: the script filename should not be empty.' >&2
      else
        ble/util/print 'ble-autoload: function names should not be empty.' >&2
      fi
      flags=e$flags
    fi
    ((index++))
  done

  [[ $flags == *h* ]] && return 0

  if ((${#args[*]}==0)); then
    ble/util/print 'ble-autoload: script filename is not specified.' >&2
    flags=e$flags
  elif ((${#args[*]}==1)); then
    ble/util/print 'ble-autoload: function names are not specified.' >&2
    flags=e$flags
  fi

  file=${args[0]} functions=("${args[@]:1}")
}
function ble-autoload {
  local file flags
  local -a functions=()
  ble/util/autoload/.read-arguments "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && builtin printf '\n'
    ble/util/autoload/.print-usage
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  ble/util/autoload "$file" "${functions[@]}"
}

## @fn ble-import scriptfile...
##   指定したファイルを検索して source で読み込みます。
##   既に import 済みのファイルは読み込みません。
##
##   @param[in] scriptfile
##     読み込むファイルを指定します。
##     絶対パスで指定した場合にはそのファイルを使用します。
##     それ以外の場合には $_ble_base:$_ble_base/local:$_ble_base/share から検索します。
##
_ble_util_import_files=()

bleopt/declare -n import_path "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/local"

## @fn ble/util/import/search/.check-directory name dir
##   @var[out] ret
function ble/util/import/search/.check-directory {
  local name=$1 dir=${2%/}
  [[ -d ${dir:=/} ]] || return 1

  # {lib,contrib}/ で始まるパスの時は lib,contrib ディレクトリのみで探索
  if [[ $name == lib/* ]]; then
    [[ $dir == */lib ]] || return 1
    dir=${dir%/lib}
  elif [[ $name == contrib/* ]]; then
    [[ $dir == */contrib ]] || return 1
    dir=${dir%/contrib}
  fi

  if [[ -f $dir/$name ]]; then
    ret=$dir/$name
    return 0
  elif [[ $name != *.bash && -f $dir/$name.bash ]]; then
    ret=$dir/$name.bash
    return 0
  elif [[ $name != *.sh && -f $dir/$name.sh ]]; then
    ret=$dir/$name.sh
    return 0
  fi
  return 1
}
function ble/util/import/search {
  ret=$1
  if [[ $ret != /* && $ret != ./* && $ret != ../* ]]; then
    local -a dirs=()
    if [[ $bleopt_import_path ]]; then
      local tmp; ble/string#split tmp : "$bleopt_import_path"
      ble/array#push dirs "${tmp[@]}"
    fi
    ble/array#push dirs "$_ble_base"{,/contrib,/lib}

    "${_ble_util_set_declare[@]//NAME/checked}" # WA #D1570 checked
    local path
    for path in "${dirs[@]}"; do
      ble/set#contains checked "$path" && continue
      ble/set#add checked "$path"
      ble/util/import/search/.check-directory "$ret" "$path" && break
    done
  fi
  [[ -e $ret && ! -d $ret ]]
}
function ble/util/import/encode-filename {
  ret=$1
  local chars=%$'\t\n !"$&\'();<>\\^`|' # <emacs bug `>
  if [[ $ret == *["$chars"]* ]]; then
    local i n=${#chars} reps a b
    reps=(%{25,08,0A,2{0..2},24,2{6..9},3B,3C,3E,5C,5E,60,7C})
    for ((i=0;i<n;i++)); do
      a=${chars:i:1} b=${reps[i]} ret=${ret//"$a"/"$b"}
    done
  fi
  return 0
}
function ble/util/import/is-loaded {
  local ret
  ble/util/import/search "$1" &&
    ble/util/import/encode-filename "$ret" &&
    ble/is-function ble/util/import/guard:"$ret"
}
# called by ble/base/unload (ble.pp)
function ble/util/import/finalize {
  local file ret
  for file in "${_ble_util_import_files[@]}"; do
    ble/util/import/encode-filename "$file"; local enc=$ret
    local guard=ble/util/import/guard:$enc
    builtin unset -f "$guard"

    local onload=ble/util/import/onload:$enc
    if ble/is-function "$onload"; then
      "$onload" ble/util/unlocal
      builtin unset -f "$onload"
    fi
  done
  _ble_util_import_files=()
}
## @fn ble/util/import/.read-arguments args...
##   @var[out] files not_found
##   @var[out] flags
##     E error
##     h help
##     d delay
##     f force
##     q query
function ble/util/import/.read-arguments {
  flags= files=() not_found=()
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != *-* ]]; then
      case $arg in
      (--)
        flags=-$flags
        continue ;;
      (--*)
        case $arg in
        (--delay) flags=d$flags ;;
        (--help)  flags=h$flags ;;
        (--force) flags=f$flags ;;
        (--query) flags=q$flags ;;
        (*)
          ble/util/print "ble-import: unrecognized option '$arg'" >&2
          flags=E$flags ;;
        esac
        continue ;;
      (-?*)
        local i c
        for ((i=1;i<${#arg};i++)); do
          c=${arg:i:1}
          case $c in
          ([dfq]) flags=$c$flags ;;
          (*)
            ble/util/print "ble-import: unrecognized option '-$c'" >&2
            flags=E$flags ;;
          esac
        done
        continue ;;
      esac
    fi

    local ret
    if ! ble/util/import/search "$arg"; then
      ble/array#push not_found "$arg"
      continue
    fi; local file=$ret
    ble/array#push files "$file"
  done

  # 存在しないファイルがあった時
  if [[ $flags != *[fq]* ]] && ((${#not_found[@]})); then
    local file
    for file in "${not_found[@]}"; do
      ble/util/print "ble-import: file '$file' not found" >&2
    done
    flags=E$flags
  fi

  return 0
}
function ble/util/import {
  local files file ext=0 ret enc
  files=("$@")
  set -- # Note #D: source によって引数が継承されるのを防ぐ
  for file in "${files[@]}"; do
    ble/util/import/encode-filename "$file"; enc=$ret
    local guard=ble/util/import/guard:$enc
    ble/is-function "$guard" && return 0
    [[ -e $file ]] || return 1
    source "$file" || { ext=$?; continue; }
    builtin eval "function $guard { :; }"
    ble/array#push _ble_util_import_files "$file"

    local onload=ble/util/import/onload:$enc
    ble/function#try "$onload" ble/util/invoke-hook
  done
  return "$ext"
}
## @fn ble/util/import/option:query
##   @var[in] files not_found
function ble/util/import/option:query {
  if ((${#not_found[@]})); then
    return 127
  elif ((${#files[@]})); then
    local file
    for file in "${files[@]}"; do
      ble/util/import/is-loaded "$file" || return 1
    done
    return 0
  else
    ble/util/print-lines "${_ble_util_import_files[@]}"
    return "$?"
  fi
}

function ble-import {
  local files flags not_found
  ble/util/import/.read-arguments "$@"
  if [[ $flags == *[Eh]* ]]; then
    [[ $flags == *E* ]] && ble/util/print
    ble/util/print-lines \
      'usage: ble-import [-dfq|--delay|--force|--query] [--] [SCRIPTFILE...]' \
      'usage: ble-import --help' \
      '    Search and source script files that have not yet been loaded.' \
      '' \
      '  OPTIONS' \
      '    --help        Show this help.' \
      '    -d, --delay   Delay actual loading of the files if possible.' \
      '    -f, --force   Ignore non-existent files without errors.' \
      '    -q, --query   When SCRIPTFILEs are specified, test if all of these files' \
      '                  are already loaded.  Without SCRIPTFILEs, print the list of' \
      '                  already imported files.' \
      '' \
      >&2
    [[ $flags == *E* ]] && return 2
    return 0
  fi

  if [[ $flags == *q* ]]; then
    ble/util/import/option:query
    return "$?"
  fi

  if ((!${#files[@]})); then
    [[ $flags == *f* ]] && return 0
    ble/util/print 'ble-import: files are not specified.' >&2
    return 2
  fi

  if [[ $flags == *d* ]] && ble/is-function ble/util/idle.push; then
    local ret
    ble/string#quote-command ble/util/import "${files[@]}"
    ble/util/idle.push "$ret"
    return 0
  fi

  ble/util/import "${files[@]}"
}

_ble_util_import_onload_count=0
function ble/util/import/eval-after-load {
  local ret file
  if ! ble/util/import/search "$1"; then
    ble/util/print "ble-import: file '$1' not found." >&2
    return 2
  fi; file=$ret

  ble/util/import/encode-filename "$file"; local enc=$ret
  local guard=ble/util/import/guard:$enc
  if ble/is-function "$guard"; then
    builtin eval -- "$2"
  else
    local onload=ble/util/import/onload:$enc
    if ! ble/is-function "$onload"; then
      local q=\' Q="'\''" list=_ble_util_import_onload_$((_ble_util_import_onload_count++))
      builtin eval -- "$list=(); function $onload { \"\$1\" $list \"\${@:2}\"; }"
    fi
    "$onload" ble/array#push "$2"
  fi
}

## @fn ble-stackdump [message]
##   現在のコールスタックの状態を出力します。
##
##   @param[in,opt] message
##     スタック情報の前に表示するメッセージを指定します。
##   @var[in] _ble_util_stackdump_title
##     スタック情報の前に表示するタイトルを指定します。
##
_ble_util_stackdump_title=stackdump
_ble_util_stackdump_start=
function ble/util/stackdump {
  ((bleopt_internal_stackdump_enabled)) || return 1
  local message=$1 nl=$'\n' IFS=$_ble_term_IFS
  message="$_ble_term_sgr0$_ble_util_stackdump_title: $message$nl"
  local extdebug= iarg=$BASH_ARGC args=
  shopt -q extdebug 2>/dev/null && extdebug=1
  local i i0=${_ble_util_stackdump_start:-1} iN=${#FUNCNAME[*]}
  for ((i=i0;i<iN;i++)); do
    if [[ $extdebug ]] && ((BASH_ARGC[i])); then
      args=("${BASH_ARGV[@]:iarg:BASH_ARGC[i]}")
      ble/array#reverse args
      args=" ${args[*]}"
      ((iarg+=BASH_ARGC[i]))
    else
      args=
    fi
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i-1]} (${FUNCNAME[i]}$args)$nl"
  done
  ble/util/put "$message"
}
function ble-stackdump {
  local flags args
  ble/util/.read-arguments-for-no-option-command ble-stackdump "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && ble/util/print
    {
      ble/util/print 'usage: ble-stackdump command [message]'
      ble/util/print '  Print stackdump.'
    } >&2
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  local _ble_util_stackdump_start=2
  local IFS=$_ble_term_IFS
  ble/util/stackdump "${args[*]}"
}

## @fn ble-assert command [message]
##   コマンドを評価し失敗した時にメッセージを表示します。
##
##   @param[in] command
##     評価するコマンドを指定します。eval で評価されます。
##   @param[in,opt] message
##     失敗した時に表示するメッセージを指定します。
##
function ble/util/assert {
  local expr=$1 message=$2
  if ! builtin eval -- "$expr"; then
    shift
    local _ble_util_stackdump_title='assertion failure'
    local _ble_util_stackdump_start=3
    ble/util/stackdump "$expr$_ble_term_nl$message" >&2
    return 1
  else
    return 0
  fi
}
function ble-assert {
  local flags args
  ble/util/.read-arguments-for-no-option-command ble-assert "$@"
  if [[ $flags != *h* ]]; then
    if ((${#args[@]}==0)); then
      ble/util/print 'ble-assert: command is not specified.' >&2
      flags=e$flags
    fi
  fi
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && ble/util/print
    {
      ble/util/print 'usage: ble-assert command [message]'
      ble/util/print '  Evaluate command and print stackdump on fail.'
    } >&2
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  local IFS=$_ble_term_IFS
  ble/util/assert "${args[0]}" "${args[*]:1}"
}

#------------------------------------------------------------------------------
# Event loop

bleopt/declare -v debug_idle ''

## @fn ble/util/clock
##   時間を計測するのに使うことができるミリ秒単位の軽量な時計です。
##   計測の起点は ble.sh のロード時です。
##   @var[out] ret
_ble_util_clock_base=
_ble_util_clock_reso=
_ble_util_clock_type=
function ble/util/clock/.initialize {
  local LC_ALL= LC_NUMERIC=C
  if ((_ble_bash>=50000)) && {
       local now=$EPOCHREALTIME
       [[ $now == *.???* && $now != $EPOCHREALTIME ]]; }; then
    # implementation with EPOCHREALTIME
    builtin readonly EPOCHREALTIME
    _ble_util_clock_base=$((10#0${now%.*}))
    _ble_util_clock_reso=1
    _ble_util_clock_type=EPOCHREALTIME
    function ble/util/clock {
      local LC_ALL= LC_NUMERIC=C
      local now=$EPOCHREALTIME
      local integral=$((10#0${now%%.*}-_ble_util_clock_base))
      local mantissa=${now#*.}000; mantissa=${mantissa::3}
      ((ret=integral*1000+10#0$mantissa))
    }
    ble/function#suppress-stderr ble/util/clock # locale
  elif [[ -r /proc/uptime ]] && {
         local uptime
         ble/util/readfile uptime /proc/uptime
         ble/string#split-words uptime "$uptime"
         [[ $uptime == *.* ]]; }; then
    # implementation with /proc/uptime
    _ble_util_clock_base=$((10#0${uptime%.*}))
    _ble_util_clock_reso=10
    _ble_util_clock_type=uptime
    function ble/util/clock {
      local now
      ble/util/readfile now /proc/uptime
      ble/string#split-words now "$now"
      local integral=$((10#0${now%%.*}-_ble_util_clock_base))
      local fraction=${now#*.}000; fraction=${fraction::3}
      ((ret=integral*1000+10#0$fraction))
    }
  elif ((_ble_bash>=40200)); then
    printf -v _ble_util_clock_base '%(%s)T' -1
    _ble_util_clock_reso=1000
    _ble_util_clock_type=printf
    function ble/util/clock {
      local now; printf -v now '%(%s)T' -1
      ((ret=(now-_ble_util_clock_base)*1000))
    }
  elif [[ $SECONDS && ! ${SECONDS//[0-9]} ]]; then
    builtin readonly SECONDS
    _ble_util_clock_base=$SECONDS
    _ble_util_clock_reso=1000
    _ble_util_clock_type=SECONDS
    function ble/util/clock {
      local now=$SECONDS
      ((ret=(now-_ble_util_clock_base)*1000))
    }
  else
    ble/util/strftime -v _ble_util_clock_base '%s'
    _ble_util_clock_reso=1000
    _ble_util_clock_type=date
    function ble/util/clock {
      ble/util/strftime -v ret '%s'
      ((ret=(ret-_ble_util_clock_base)*1000))
    }
  fi
}
ble/util/clock/.initialize 2>/dev/null

if ((_ble_bash>=40000)); then
  ## @fn[custom] ble/util/idle/IS_IDLE
  ##   他にするべき処理がない時 (アイドル時) に終了ステータス 0 を返します。
  ##   Note: この設定関数は ble-decode.sh で上書きされます。
  function ble/util/idle/IS_IDLE { ! ble/util/is-stdin-ready; }

  _ble_util_idle_sclock=0
  function ble/util/idle/.sleep {
    local msec=$1
    ((msec<=0)) && return 0
    ble/util/msleep "$msec"
    ((_ble_util_idle_sclock+=msec))
  }

  function ble/util/idle.clock/.initialize {
    function ble/util/idle.clock/.initialize { :; }

    ## @fn ble/util/idle.clock
    ##   タスクスケジューリングに使用する時計
    ##   @var[out] ret
    function ble/util/idle.clock/.restart { :; }
    if [[ ! $_ble_util_clock_type || $_ble_util_clock_type == date ]]; then
      function ble/util/idle.clock {
        ret=$_ble_util_idle_sclock
      }
    elif ((_ble_util_clock_reso<=100)); then
      function ble/util/idle.clock {
        ble/util/clock
      }
    else
      ## @fn ble/util/idle/.adjusted-clock
      ##   参照時計 (rclock) と sleep 累積時間 (sclock) を元にして、
      ##   参照時計を秒以下に解像度を上げた時計 (aclock) を提供します。
      ##
      ## @var[in,out] _ble_util_idle_aclock_tick_rclock
      ## @var[in,out] _ble_util_idle_aclock_tick_sclock
      ##   最後に参照時計が切り替わった時の rclock と sclock の値を保持します。
      ##
      ## @var[in,out] _ble_util_idle_aclock_shift
      ##   時刻のシフト量を表します。
      ##
      ##   初期化時の秒以下の時刻が分からないため、
      ##   取り敢えず 0.000 になっていると想定して時刻を測り始めます。
      ##   最初の秒の切り替わりの時点でずれの量が判明するので、それを記録します。
      ##   一様時計を提供する為に、以降もこのずれを適用する為に使用します。
      ##
      _ble_util_idle_aclock_shift=
      _ble_util_idle_aclock_tick_rclock=
      _ble_util_idle_aclock_tick_sclock=
      function ble/util/idle.clock/.restart {
        _ble_util_idle_aclock_shift=
        _ble_util_idle_aclock_tick_rclock=
        _ble_util_idle_aclock_tick_sclock=
      }
      function ble/util/idle/.adjusted-clock {
        local resolution=$_ble_util_clock_reso
        local sclock=$_ble_util_idle_sclock
        local ret; ble/util/clock; local rclock=$((ret/resolution*resolution))

        if [[ $_ble_util_idle_aclock_tick_rclock != "$rclock" ]]; then
          if [[ $_ble_util_idle_aclock_tick_rclock && ! $_ble_util_idle_aclock_shift ]]; then
            local delta=$((sclock-_ble_util_idle_aclock_tick_sclock))
            ((_ble_util_idle_aclock_shift=delta<resolution?resolution-delta:0))
          fi
          _ble_util_idle_aclock_tick_rclock=$rclock
          _ble_util_idle_aclock_tick_sclock=$sclock
        fi

        ((ret=rclock+(sclock-_ble_util_idle_aclock_tick_sclock)-_ble_util_idle_aclock_shift))
      }
      function ble/util/idle.clock {
        ble/util/idle/.adjusted-clock
      }
    fi
  }

  function ble/util/idle/.initialize-options {
    local interval='ble_util_idle_elapsed>600000?500:(ble_util_idle_elapsed>60000?200:(ble_util_idle_elapsed>5000?100:20))'
    ((_ble_bash>50000)) && [[ $_ble_util_msleep_builtin_available ]] && interval=20
    bleopt/declare -v idle_interval "$interval"
  }
  ble/util/idle/.initialize-options

  ## @arr _ble_util_idle_task
  ##   タスク一覧を保持します。各要素は一つのタスクを表し、
  ##   status|command の形式の文字列です。
  ##   command にはタスクを実行する coroutine を指定します。
  ##   status は以下の何れかの値を持ちます。
  ##
  ##     R
  ##       現在実行中のタスクである事を表します。
  ##       ble/util/idle.push で設定されます。
  ##     I
  ##       次のユーザの入力を待っているタスクです。
  ##       タスク内から ble/util/idle.wait-user-input で設定します。
  ##     S<rtime>
  ##       時刻 <rtime> になるのを待っているタスクです。
  ##       タスク内から ble/util/idle.sleep で設定します。
  ##     W<stime>
  ##       sleep 累積時間 <stime> になるのを待っているタスクです。
  ##       タスク内から ble/util/idle.isleep で設定します。
  ##     E<filename>
  ##       ファイルまたはディレクトリ <filename> が現れるのを待っているタスクです。
  ##       タスク内から ble/util/idle.wait-filename で設定します。
  ##     F<filename>
  ##       ファイル <filename> が有限のサイズになるのを待っているタスクです。
  ##       タスク内から ble/util/idle.wait-file-content で設定します。
  ##     P<pid>
  ##       プロセス <pid> (ユーザからアクセス可能) が終了するのを待っているタスクです。
  ##       タスク内から ble/util/idle.wait-process で設定します。
  ##     C<command>
  ##       コマンド <command> の実行結果が真になるのを待っているタスクです。
  ##       タスク内から ble/util/idle.wait-condition で設定します。
  ##     Z
  ##       停止中のタスクです。外部から状態を設定する事によって再開します。
  ##
  _ble_util_idle_task=()
  _ble_util_idle_lasttask=
  _ble_util_idle_SEP=$_ble_term_FS

  ## @fn ble/util/idle.do
  ##   待機状態の処理を開始します。
  ##
  ##   @exit
  ##     待機処理を何かしら実行した時に成功 (0) を返します。
  ##     何も実行しなかった時に失敗 (1) を返します。
  ##
  function ble/util/idle.do {
    local IFS=$_ble_term_IFS
    ble/util/idle/IS_IDLE || return 1
    ((${#_ble_util_idle_task[@]}==0)) && return 1
    ble/util/buffer.flush >&2

    local ret
    ble/util/idle.clock/.initialize
    ble/util/idle.clock/.restart
    ble/util/idle.clock
    local _ble_idle_clock_start=$ret
    local _ble_idle_sclock_start=$_ble_util_idle_sclock
    local _ble_idle_is_first=1
    local _ble_idle_processed=
    local _ble_idle_info_shown=
    local _ble_idle_after_task=0
    while :; do
      local _ble_idle_key
      local _ble_idle_next_time= _ble_idle_next_itime= _ble_idle_running= _ble_idle_waiting=
      for _ble_idle_key in "${!_ble_util_idle_task[@]}"; do
        ble/util/idle/IS_IDLE || break 2
        local _ble_idle_to_process=
        local _ble_idle_status=${_ble_util_idle_task[_ble_idle_key]%%"$_ble_util_idle_SEP"*}
        case ${_ble_idle_status::1} in
        (R) _ble_idle_to_process=1 ;;
        (I) [[ $_ble_idle_is_first ]] && _ble_idle_to_process=1 ;;
        (S) ble/util/idle/.check-clock "$_ble_idle_status" && _ble_idle_to_process=1 ;;
        (W) ble/util/idle/.check-clock "$_ble_idle_status" && _ble_idle_to_process=1 ;;
        (F) [[ -s ${_ble_idle_status:1} ]] && _ble_idle_to_process=1 ;;
        (E) [[ -e ${_ble_idle_status:1} ]] && _ble_idle_to_process=1 ;;
        (P) ! builtin kill -0 ${_ble_idle_status:1} &>/dev/null && _ble_idle_to_process=1 ;;
        (C) builtin eval -- "${_ble_idle_status:1}" && _ble_idle_to_process=1 ;;
        (Z) ;;
        (*) builtin unset -v '_ble_util_idle_task[_ble_idle_key]'
        esac

        if [[ $_ble_idle_to_process ]]; then
          local _ble_idle_command=${_ble_util_idle_task[_ble_idle_key]#*"$_ble_util_idle_SEP"}
          _ble_idle_processed=1
          ble/util/idle.do/.call-task "$_ble_idle_command"

          # Note: #D1450 _ble_idle_command が 148 を返したとしても idle.do は中
          # 断しない事にした。IS_IDLE と条件が同じとは限らないので。
          # ((ext==148)) && return 0

          ((_ble_idle_after_task++))
        elif [[ $_ble_idle_status == [FEPC]* ]]; then
          _ble_idle_waiting=1
        fi
      done

      _ble_idle_is_first=
      ble/util/idle.do/.sleep-until-next; local ext=$?
      ((ext==148)) && break

      [[ $_ble_idle_next_itime$_ble_idle_next_time$_ble_idle_running$_ble_idle_waiting ]] || break
    done

    [[ $_ble_idle_info_shown ]] &&
      ble/edit/info/immediate-default
    ble/util/idle.do/.do-after-task
    [[ $_ble_idle_processed ]]
  }
  ## @fn ble/util/idle.do/.do-after-task
  ##   @var[ref] _ble_idle_after_task
  function ble/util/idle.do/.do-after-task {
    if ((_ble_idle_after_task)); then
      # 50ms 以上の待機時間があれば再描画などの処理を試行する。
      blehook/invoke idle_after_task
      _ble_idle_after_task=0
    fi
  }
  ## @fn ble/util/idle.do/.call-task command
  ##   @var[in,out] _ble_idle_next_time
  ##   @var[in,out] _ble_idle_next_itime
  ##   @var[in,out] _ble_idle_running
  ##   @var[in,out] _ble_idle_waiting
  function ble/util/idle.do/.call-task {
    local _ble_local_command=$1
    local ble_util_idle_status=
    local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_ble_idle_sclock_start))
    if [[ $bleopt_debug_idle && ( $_ble_edit_info_scene == default || $_ble_idle_info_shown ) ]]; then
      _ble_idle_info_shown=1
      ble/edit/info/immediate-show text "${EPOCHREALTIME:+[$EPOCHREALTIME] }idle: $_ble_local_command"
    fi
    builtin eval -- "$_ble_local_command"; local ext=$?
    if ((ext==148)); then
      _ble_util_idle_task[_ble_idle_key]=R$_ble_util_idle_SEP$_ble_local_command
    elif [[ $ble_util_idle_status ]]; then
      _ble_util_idle_task[_ble_idle_key]=$ble_util_idle_status$_ble_util_idle_SEP$_ble_local_command
      if [[ $ble_util_idle_status == [WS]* ]]; then
        local scheduled_time=${ble_util_idle_status:1}
        if [[ $ble_util_idle_status == W* ]]; then
          local next=_ble_idle_next_itime
        else
          local next=_ble_idle_next_time
        fi
        if [[ ! ${!next} ]] || ((scheduled_time<next)); then
          builtin eval "$next=\$scheduled_time"
        fi
      elif [[ $ble_util_idle_status == R ]]; then
        _ble_idle_running=1
      elif [[ $ble_util_idle_status == [FEPC]* ]]; then
        _ble_idle_waiting=1
      fi
    else
      builtin unset -v '_ble_util_idle_task[_ble_idle_key]'
    fi
    return "$ext"
  }
  ## @fn ble/util/idle/.check-clock status
  ##   @var[in,out] _ble_idle_next_itime
  ##   @var[in,out] _ble_idle_next_time
  function ble/util/idle/.check-clock {
    local status=$1
    if [[ $status == W* ]]; then
      local next=_ble_idle_next_itime
      local current_time=$_ble_util_idle_sclock
    elif [[ $status == S* ]]; then
      local ret
      local next=_ble_idle_next_time
      ble/util/idle.clock; local current_time=$ret
    else
      return 1
    fi

    local scheduled_time=${status:1}
    if ((scheduled_time<=current_time)); then
      return 0
    elif [[ ! ${!next} ]] || ((scheduled_time<next)); then
      builtin eval "$next=\$scheduled_time"
    fi
    return 1
  }
  ## @fn ble/util/idle.do/.sleep-until-next
  ##   @var[in] _ble_idle_next_time
  ##   @var[in] _ble_idle_next_itime
  ##   @var[in] _ble_idle_running
  ##   @var[in] _ble_idle_waiting
  function ble/util/idle.do/.sleep-until-next {
    ble/util/idle/IS_IDLE || return 148
    [[ $_ble_idle_running ]] && return 0
    local isfirst=1
    while
      # ファイル等他の条件を待っている時は一回だけで外に戻り確認する状態確認
      [[ $_ble_idle_waiting && ! $isfirst ]] && break

      local sleep_amount=
      if [[ $_ble_idle_next_itime ]]; then
        local clock=$_ble_util_idle_sclock
        local sleep1=$((_ble_idle_next_itime-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      if [[ $_ble_idle_next_time ]]; then
        local ret; ble/util/idle.clock; local clock=$ret
        local sleep1=$((_ble_idle_next_time-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      [[ $_ble_idle_waiting ]] || ((sleep_amount>0))
    do
      # Note: 変数 ble_util_idle_elapsed は
      #   $((bleopt_idle_interval)) の評価時に参照される。
      local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_ble_idle_sclock_start))

      # sleep_amount が十分に長い場合に idle_after_task が必要あれば実行する
      ((sleep_amount>50)) && ble/util/idle.do/.do-after-task

      local interval=$((bleopt_idle_interval))

      if [[ ! $sleep_amount ]] || ((interval<sleep_amount)); then
        sleep_amount=$interval
      fi
      ble/util/idle/.sleep "$sleep_amount"
      ble/util/idle/IS_IDLE || return 148
      isfirst=
    done
  }

  function ble/util/idle.push/.impl {
    local base=$1 entry=$2
    local i=$base
    while [[ ${_ble_util_idle_task[i]-} ]]; do ((i++)); done
    _ble_util_idle_task[i]=$entry
    _ble_util_idle_lasttask=$i
  }
  function ble/util/idle.push {
    local status=R nice=0
    while [[ $1 == -* ]]; do
      local sleep= isleep=
      case $1 in
      (-[SWPFEC]) status=${1:1}$2; shift 2 ;;
      (-[SWPFECIRZ]*) status=${1:1}; shift ;;
      (-n) nice=$2; shift 2 ;;
      (-n*) nice=${1#-n}; shift ;;
      (--sleep)    sleep=$2; shift 2 ;;
      (--sleep=*)  sleep=${1#*=}; shift ;;
      (--isleep)   isleep=$2; shift 2 ;;
      (--isleep=*) isleep=${1#*=}; shift ;;
      (*) break ;;
      esac

      if [[ $sleep ]]; then
        local ret; ble/util/idle.clock
        status=S$((ret+sleep))
      elif [[ $isleep ]]; then
        status=W$((_ble_util_idle_sclock+isleep))
      fi
    done
    ble/util/idle.push/.impl "$nice" "$status$_ble_util_idle_SEP$1"
  }
  function ble/util/idle.push-background {
    ble/util/idle.push -n 10000 "$@"
  }
  function ble/util/idle.cancel {
    local command=$1 i removed=
    for i in "${!_ble_util_idle_task[@]}"; do
      [[ ${_ble_util_idle_task[i]} == *"$_ble_util_idle_SEP$command" ]] &&
        builtin unset -v '_ble_util_idle_task[i]' &&
        removed=1
    done
    [[ $removed ]]
  }

  function ble/util/is-running-in-idle {
    [[ ${ble_util_idle_status+set} ]]
  }
  function ble/util/idle.suspend {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=Z
  }
  function ble/util/idle.sleep {
    [[ ${ble_util_idle_status+set} ]] || return 2
    local ret; ble/util/idle.clock
    ble_util_idle_status=S$((ret+$1))
  }
  function ble/util/idle.isleep {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=W$((_ble_util_idle_sclock+$1))
  }
  ## @fn ble/util/idle.sleep-until clock opts
  function ble/util/idle.sleep-until {
    [[ ${ble_util_idle_status+set} ]] || return 2
    if [[ :$2: == *:checked:* ]]; then
      local ret; ble/util/idle.clock
      (($1>ret)) || return 1
    fi
    ble_util_idle_status=S$1
  }
  ## @fn ble/util/idle.isleep-until sclock opts
  function ble/util/idle.isleep-until {
    [[ ${ble_util_idle_status+set} ]] || return 2
    if [[ :$2: == *:checked:* ]]; then
      (($1>_ble_util_idle_sclock)) || return 1
    fi
    ble_util_idle_status=W$1
  }
  function ble/util/idle.wait-user-input {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=I
  }
  function ble/util/idle.wait-process {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=P$1
  }
  function ble/util/idle.wait-file-content {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=F$1
  }
  function ble/util/idle.wait-filename {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=E$1
  }
  function ble/util/idle.wait-condition {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=C$1
  }
  function ble/util/idle.continue {
    [[ ${ble_util_idle_status+set} ]] || return 2
    ble_util_idle_status=R
  }

  function ble/util/idle/.delare-external-modifier {
    local name=$1
    builtin eval -- 'function ble/util/idle#'$name' {
      local index=$1
      [[ ${_ble_util_idle_task[index]+set} ]] || return 2
      local ble_util_idle_status=${_ble_util_idle_task[index]%%"$_ble_util_idle_SEP"*}
      local ble_util_idle_command=${_ble_util_idle_task[index]#*"$_ble_util_idle_SEP"}
      ble/util/idle.'$name' "${@:2}"
      _ble_util_idle_task[index]=$ble_util_idle_status$_ble_util_idle_SEP$ble_util_idle_command
    }'
  }
  # @fn ble/util/idle#suspend
  # @fn ble/util/idle#sleep time
  # @fn ble/util/idle#isleep time
  ble/util/idle/.delare-external-modifier suspend
  ble/util/idle/.delare-external-modifier sleep
  ble/util/idle/.delare-external-modifier isleep

  ble/util/idle.push-background 'ble/util/msleep/calibrate'
else
  function ble/util/idle.do { false; }
fi

#------------------------------------------------------------------------------
# ble/util/fiberchain

_ble_util_fiberchain=()
_ble_util_fiberchain_prefix=
function ble/util/fiberchain#initialize {
  _ble_util_fiberchain=()
  _ble_util_fiberchain_prefix=$1
}
function ble/util/fiberchain#resume/.core {
  _ble_util_fiberchain=()
  local fib_clock=0
  local fib_ntask=$#
  while (($#)); do
    ((fib_ntask--))
    local fiber=${1%%:*} fib_suspend= fib_kill=
    local argv; ble/string#split-words argv "$fiber"
    [[ $1 == *:* ]] && fib_suspend=${1#*:}
    "$_ble_util_fiberchain_prefix/$argv.fib" "${argv[@]:1}"

    if [[ $fib_kill ]]; then
      break
    elif [[ $fib_suspend ]]; then
      _ble_util_fiberchain=("$fiber:$fib_suspend" "${@:2}")
      return 148
    fi
    shift
  done
}
function ble/util/fiberchain#resume {
  ble/util/fiberchain#resume/.core "${_ble_util_fiberchain[@]}"
}
## @fn ble/util/fiberchain#push fiber...
##   @param[in] fiber
##     複数指定することができます。
##     一つ一つは空白区切りの単語を並べた文字列です。
##     コロン ":" を含むことはできません。
##     一番最初の単語にファイバー名 name を指定します。
##     引数 args... があれば二つ目以降の単語として指定します。
##
##   @remarks
##     実際に実行されるファイバーは以下のコマンドになります。
##     "$_ble_util_fiber_chain_prefix/$name.fib" "${args[@]}"
##
function ble/util/fiberchain#push {
  ble/array#push _ble_util_fiberchain "$@"
}
function ble/util/fiberchain#clear {
  _ble_util_fiberchain=()
}

#------------------------------------------------------------------------------
# **** terminal controls ****

bleopt/declare -v vbell_default_message ' Wuff, -- Wuff!! '
bleopt/declare -v vbell_duration 2000
bleopt/declare -n vbell_align left

function ble/term:cygwin/initialize.hook {
  # RIの修正
  # Note: Cygwin console では何故か RI (ESC M) が
  #   1行スクロールアップとして実装されている。
  #   一方で CUU (CSI A) で上にスクロールできる。
  printf '\eM\e[B' >&"$_ble_util_fd_stderr"
  _ble_term_ri=$'\e[A'

  # DLの修正
  function ble/canvas/put-dl.draw {
    local value=${1-1} i
    ((value)) || return 1

    # Note: DL が最終行まで消去する時、何も消去されない…。
    DRAW_BUFF[${#DRAW_BUFF[*]}]=$'\e[2K'
    if ((value>1)); then
      local ret
      ble/string#repeat $'\e[B\e[2K' "$((value-1))"; local a=$ret
      DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret$'\e['$((value-1))'A'
    fi

    DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
  }
}

function ble/term/DA2R.hook {
  blehook term_DA2R-=ble/term/DA2R.hook
  case $_ble_term_TERM in
  (contra:*)
    _ble_term_cuu=$'\e[%dk'
    _ble_term_cud=$'\e[%de'
    _ble_term_cuf=$'\e[%da'
    _ble_term_cub=$'\e[%dj'
    _ble_term_cup=$'\e[%l;%cf' ;;
  (cygwin:*)
    ble/term:cygwin/initialize.hook ;;
  esac
}
function ble/term/.initialize {
  if [[ -s $_ble_base_cache/term.$TERM && $_ble_base_cache/term.$TERM -nt $_ble_base/lib/init-term.sh ]]; then
    source "$_ble_base_cache/term.$TERM"
  else
    source "$_ble_base/lib/init-term.sh"
  fi

  ble/string#reserve-prototype "$_ble_term_it"
  blehook term_DA2R!=ble/term/DA2R.hook
}
ble/term/.initialize

function ble/term/put {
  BUFF[${#BUFF[@]}]=$1
}
function ble/term/cup {
  local x=$1 y=$2 esc=$_ble_term_cup
  esc=${esc//'%x'/$x}
  esc=${esc//'%y'/$y}
  esc=${esc//'%c'/$((x+1))}
  esc=${esc//'%l'/$((y+1))}
  BUFF[${#BUFF[@]}]=$esc
}
function ble/term/flush {
  IFS= builtin eval 'ble/util/put "${BUFF[*]}"'
  BUFF=()
}

# **** vbell/abell ****

function ble/term/audible-bell {
  ble/util/put '' 1>&2
}

# visible-bell の表示の管理について。
#
# vbell の表示の削除には worker サブシェルを使用する。
# 現在の表示内容及び消去に関しては二つのファイルを使う。
#
#   workerfile=$_ble_base_run/$$.visible-bell.$i
#     1つの worker に対して1つ割り当てられ、
#     その worker が生きている間は非空である。
#     またそのタイムスタンプは worker 起動時刻を表す。
#
#   _ble_term_visible_bell_ftime=$_ble_base_run/$$.visible-bell.time
#     最後に表示の更新を行った時刻を記録するのに使う。
#
# 前回の表示内容は以下の配列に格納する。
#
# @arr _ble_term_visible_bell_prev=(vbell_type message [x0 y0 x y])

_ble_term_visible_bell_prev=()
_ble_term_visible_bell_ftime=$_ble_base_run/$$.visible-bell.time

_ble_term_visible_bell_show='%message%'
_ble_term_visible_bell_clear=
function ble/term/visible-bell:term/init {
  if [[ ! $_ble_term_visible_bell_clear ]]; then
    local -a BUFF=()
    ble/term/put "$_ble_term_ri_or_cuu1$_ble_term_sc$_ble_term_sgr0"
    ble/term/cup 0 0
    ble/term/put "$_ble_term_el%message%$_ble_term_sgr0$_ble_term_rc${_ble_term_cud//'%d'/1}"
    IFS= builtin eval '_ble_term_visible_bell_show="${BUFF[*]}"'

    BUFF=()
    ble/term/put "$_ble_term_sc$_ble_term_sgr0"
    ble/term/cup 0 0
    ble/term/put "$_ble_term_el2$_ble_term_rc"
    IFS= builtin eval '_ble_term_visible_bell_clear="${BUFF[*]}"'
  fi

  # 一行に収まる様に切り詰める
  local cols=${COLUMNS:-80}
  ((_ble_term_xenl||cols--))
  local message=${1::cols}
  _ble_term_visible_bell_prev=(term "$message")
}
function ble/term/visible-bell:term/show {
  local sgr=$1 message=${_ble_term_visible_bell_prev[1]}
  message=${_ble_term_visible_bell_show//'%message%'/"$sgr$message"}
  ble/util/put "$message" >&2
}
function ble/term/visible-bell:term/update {
  ble/term/visible-bell:term/show "$@"
}
function ble/term/visible-bell:term/clear {
  local sgr=$1
  ble/util/put "$_ble_term_visible_bell_clear" >&2
}

function ble/term/visible-bell:canvas/init {
  local message=$1

  local lines=1 cols=${COLUMNS:-80}
  ((_ble_term_xenl||cols--))
  local x= y=
  local ret sgr0= sgr1=
  ble/canvas/trace-text "$message" nonewline:external-sgr
  message=$ret

  local x0=0 y0=0
  if [[ $bleopt_vbell_align == right ]]; then
    ((x0=COLUMNS-1-x,x0<0&&(x0=0)))
  elif [[ $bleopt_vbell_align == center ]]; then
    ((x0=(COLUMNS-1-x)/2,x0<0&&(x0=0)))
  fi

  _ble_term_visible_bell_prev=(canvas "$message" "$x0" "$y0" "$x" "$y")
}
function ble/term/visible-bell:canvas/show {
  local sgr=$1 opts=$2
  local message=${_ble_term_visible_bell_prev[1]}
  local x0=${_ble_term_visible_bell_prev[2]}
  local y0=${_ble_term_visible_bell_prev[3]}
  local x=${_ble_term_visible_bell_prev[4]}
  local y=${_ble_term_visible_bell_prev[5]}

  local -a DRAW_BUFF=()
  [[ :$opts: != *:update:* && $_ble_attached ]] && # WA #D1495
    [[ $_ble_term_ri || :$opts: != *:erased:* && :$opts: != *:update:* ]] &&
    ble/canvas/panel/ensure-tmargin.draw
  if [[ $_ble_term_rc ]]; then
    local ret=
    [[ :$opts: != *:update:* && $_ble_attached ]] && ble/canvas/panel/save-position goto-top-dock # WA #D1495
    ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sc$_ble_term_sgr0"
    ble/canvas/put-cup.draw "$((y0+1))" "$((x0+1))"
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put.draw "$_ble_term_rc"
    ble/canvas/put-cud.draw 1
    [[ :$opts: != *:update:* && $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret" # WA #D1495
  else
    ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sgr0"
    ble/canvas/put-hpa.draw "$((1+x0))"
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put-cud.draw 1
    ble/canvas/put-hpa.draw "$((1+_ble_canvas_x))"
  fi
  ble/canvas/bflush.draw
  ble/util/buffer.flush >&2
}
function ble/term/visible-bell:canvas/update {
  ble/term/visible-bell:canvas/show "$@"
}
function ble/term/visible-bell:canvas/clear {
  local sgr=$1
  local x0=${_ble_term_visible_bell_prev[2]}
  local y0=${_ble_term_visible_bell_prev[3]}
  local x=${_ble_term_visible_bell_prev[4]}
  local y=${_ble_term_visible_bell_prev[5]}

  local -a DRAW_BUFF=()
  if [[ $_ble_term_rc ]]; then
    local ret=
    #[[ $_ble_attached ]] && ble/canvas/panel/save-position goto-top-dock # WA #D1495
    ble/canvas/put.draw "$_ble_term_sc$_ble_term_sgr0"
    ble/canvas/put-cup.draw "$((y0+1))" "$((x0+1))"
    ble/canvas/put.draw "$sgr"
    ble/canvas/put-spaces.draw "$x"
    #ble/canvas/put-ech.draw "$x"
    #ble/canvas/put.draw "$_ble_term_el"
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_rc"
    #[[ $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret" # WA #D1495
  else
    : # 親プロセスの _ble_canvas_x が分からないので座標がずれる
    # ble/util/buffer.flush >&2
    # ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sgr0"
    # ble/canvas/put-hpa.draw "$((1+x0))"
    # ble/canvas/put.draw "$sgr"
    # ble/canvas/put-spaces.draw "$x"
    # ble/canvas/put.draw "$_ble_term_sgr0"
    # ble/canvas/put-cud.draw 1
    # ble/canvas/put-hpa.draw "$((1+_ble_canvas_x))" # 親プロセスの _ble_canvas_x?
  fi
  ble/canvas/flush.draw >&2
}

function ble/term/visible-bell/defface.hook {
  ble/color/defface vbell       reverse
  ble/color/defface vbell_flash reverse,fg=green
  ble/color/defface vbell_erase bg=252
}
blehook color_defface_load+=ble/term/visible-bell/defface.hook

function ble/term/visible-bell/.show {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/show "$@"
}
function ble/term/visible-bell/.update {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/update "$1" "$2:update"
}
function ble/term/visible-bell/.clear {
  local bell_type=${_ble_term_visible_bell_prev[0]}
  ble/term/visible-bell:"$bell_type"/clear "$@"
  >| "$_ble_term_visible_bell_ftime"
}

function ble/term/visible-bell/.erase-previous-visible-bell {
  local ret workers
  ble/util/eval-pathname-expansion '"$_ble_base_run/$$.visible-bell."*' canonical
  workers=("${ret[@]}")

  local workerfile
  for workerfile in "${workers[@]}"; do
    if [[ -s $workerfile && ! ( $workerfile -ot $_ble_term_visible_bell_ftime ) ]]; then
      ble/term/visible-bell/.clear "$sgr0"
      return 0
    fi
  done
  return 1
}

function ble/term/visible-bell/.create-workerfile {
  local i=0
  while
    workerfile=$_ble_base_run/$$.visible-bell.$i
    [[ -s $workerfile ]]
  do ((i++)); done
  ble/util/print 1 >| "$workerfile"
}
## @fn ble/term/visible-bell/.worker
##   @var[in] workerfile
function ble/term/visible-bell/.worker {
  # Note: ble/util/assign は使えない。本体の ble/util/assign と一時ファイルが衝突する可能性がある。
  ble/util/msleep 50
  [[ $workerfile -ot $_ble_term_visible_bell_ftime ]] && return 0 >| "$workerfile"
  ble/term/visible-bell/.update "$sgr2"

  if [[ :$opts: == *:persistent:* ]]; then
    local dead_workerfile=$_ble_base_run/$$.visible-bell.Z
    ble/util/print 1 >| "$dead_workerfile"
    return 0 >| "$workerfile"
  fi

  # load time duration settings
  local msec=$bleopt_vbell_duration

  # wait
  ble/util/msleep "$msec"
  [[ $workerfile -ot $_ble_term_visible_bell_ftime ]] && return 0 >| "$workerfile"

  # check and clear
  ble/term/visible-bell/.clear "$sgr0"

  >| "$workerfile"
}

## @fn ble/term/visible-bell message [opts]
function ble/term/visible-bell {
  local message=$1 opts=$2
  message=${message:-$bleopt_vbell_default_message}

  # Note: 1行しかない時は表示しない。0行の時は全てログに行くので出力する。空文
  # 字列の時は設定されていないだけなので表示する。
  ((LINES==1)) && return 0

  if ble/is-function ble/canvas/trace-text; then
    ble/term/visible-bell:canvas/init "$message"
  else
    ble/term/visible-bell:term/init "$message"
  fi

  local sgr0=$_ble_term_sgr0
  local sgr1=${_ble_term_setaf[2]}$_ble_term_rev
  local sgr2=$_ble_term_rev
  if ble/is-function ble/color/face2sgr; then
    local ret
    ble/color/face2sgr vbell_flash; sgr1=$ret
    ble/color/face2sgr vbell; sgr2=$ret
    ble/color/face2sgr vbell_erase; sgr0=$ret
  fi

  local show_opts=
  ble/term/visible-bell/.erase-previous-visible-bell && show_opts=erased
  ble/term/visible-bell/.show "$sgr1" "$show_opts"

  local workerfile; ble/term/visible-bell/.create-workerfile
  # Note: __ble_suppress_joblist__ を指定する事によって、
  #   終了したジョブの一覧に現れない様にする。
  #   対策しないと read の置き換え実装でジョブ一覧が表示されてしまう。
  # Note: 標準出力を閉じて置かないと $() の中で
  #   read を呼び出した時に visible-bell worker がブロックしてしまう。
  # ref #D1000, #D1087
  ( ble/term/visible-bell/.worker __ble_suppress_joblist__ 1>/dev/null & )
}
function ble/term/visible-bell/cancel-erasure {
  >| "$_ble_term_visible_bell_ftime"
}
function ble/term/visible-bell/erase {
  local sgr0=$_ble_term_sgr0
  if ble/is-function ble/color/face2sgr; then
    local ret
    ble/color/face2sgr vbell_erase; sgr0=$ret
  fi
  ble/term/visible-bell/.erase-previous-visible-bell
}

#---- stty --------------------------------------------------------------------

# 改行 (C-m, C-j) の取り扱いについて
#   入力の C-m が C-j に勝手に変換されない様に -icrnl を指定する必要がある。
#   (-nl の設定の中に icrnl が含まれているので、これを取り消さなければならない)
#   一方で、出力の LF は CR LF に変換されて欲しいので onlcr は保持する。
#   (これは -nl の設定に含まれている)
#
# -icanon について
#   stty icanon を設定するプログラムがある。これを設定すると入力が buffering され
#   その場で入力を受信する事ができない。結果として hang した様に見える。
#   従って、enter で -icanon を設定する事にする。

## @var _ble_term_stty_state
##   現在 stty で制御文字の効果が解除されているかどうかを保持します。
##
## Note #D1238: arr=(...) の形式を用いると Bash 3.2 では勝手に ^? が ^A^? に化けてしまう
##   仕方がないので此処では ble/array#push を使って以下の配列を初期化する事にする。
_ble_term_stty_state=
_ble_term_stty_flags_enter=()
_ble_term_stty_flags_leave=()
ble/array#push _ble_term_stty_flags_enter intr undef quit undef susp undef
ble/array#push _ble_term_stty_flags_leave intr '' quit '' susp ''
function ble/term/stty/.initialize-flags {
  # # ^U, ^V, ^W, ^?
  # # Note: lnext, werase は POSIX にはないので stty の項目に存在する
  # #   かチェックする。
  # # Note (#D1683): ble/decode/bind/adjust-uvw が正しい対策。以下の対
  # #   策の効果は不明。寧ろ vim :term 内部で ^? が効かなくなるなど問
  # #   題を起こす様なので取り敢えず無効化する。
  # ble/array#push _ble_term_stty_flags_enter kill undef erase undef
  # ble/array#push _ble_term_stty_flags_leave kill '' erase ''
  # local stty; ble/util/assign stty 'stty -a'
  # if [[ $stty == *' lnext '* ]]; then
  #   ble/array#push _ble_term_stty_flags_enter lnext undef
  #   ble/array#push _ble_term_stty_flags_leave lnext ''
  # fi
  # if [[ $stty == *' werase '* ]]; then
  #   ble/array#push _ble_term_stty_flags_enter werase undef
  #   ble/array#push _ble_term_stty_flags_leave werase ''
  # fi

  if [[ $TERM == minix ]]; then
    local stty; ble/util/assign stty 'stty -a'
    if [[ $stty == *' rprnt '* ]]; then
      ble/array#push _ble_term_stty_flags_enter rprnt undef
      ble/array#push _ble_term_stty_flags_leave rprnt ''
    elif [[ $stty == *' reprint '* ]]; then
      ble/array#push _ble_term_stty_flags_enter reprint undef
      ble/array#push _ble_term_stty_flags_leave reprint ''
    fi
  fi
}
ble/term/stty/.initialize-flags

function ble/term/stty/initialize {
  ble/bin/stty -ixon -echo -nl -icrnl -icanon \
               "${_ble_term_stty_flags_enter[@]}"
  _ble_term_stty_state=1
}
function ble/term/stty/leave {
  [[ ! $_ble_term_stty_state ]] && return 0
  ble/bin/stty echo -nl icanon \
               "${_ble_term_stty_flags_leave[@]}"
  _ble_term_stty_state=
}
function ble/term/stty/enter {
  [[ $_ble_term_stty_state ]] && return 0
  ble/bin/stty -echo -nl -icrnl -icanon \
               "${_ble_term_stty_flags_enter[@]}"
  _ble_term_stty_state=1
}
function ble/term/stty/finalize {
  ble/term/stty/leave
}
function ble/term/stty/TRAPEXIT {
  # exit の場合は echo
  ble/bin/stty echo -nl \
               "${_ble_term_stty_flags_leave[@]}"

  # Note (#D): WA for bash-5.2 stty: bash-5.2 以降では EXIT trap よりも後に readline
  # が stty を復元しようとするので、セッション終了後に制御端末が壊れた状態にな
  # る。親プロセスが同じ端末に属していてかつ ble.sh セッションでない場合には、
  # 入力に支障を来すので制御端末の状態を手動で復元する様に表示を行う。
  if ((_ble_bash>=50200)) && [[ :$1: == *:EXIT:* && ! -e $_ble_base_run/$PPID.load ]]; then
    local lines
    ble/util/assign-array lines 'ble/bin/ps -o tty "$$" "$PPID"'
    ((${#lines[@]}>=3)) && lines=("${lines[@]:${#lines[@]}-2}")
    if [[ ${lines[0]} == ${lines[1]} ]]; then
      local sgr=$_ble_term_bold${_ble_term_setaf[4]} sgr0=$_ble_term_sgr0
      ble/util/print "ble: Please run \`${sgr}stty sane$sgr0' to recover the correct TTY state." >&"${_ble_util_fd_stderr:-2}"
    fi
  fi
}

function ble/term/update-winsize {
  # (0) checkwinsize による実装 (2167.054 usec/eval)
  if ((_ble_bash<50200||50300<=_ble_bash)); then
    function ble/term/update-winsize {
      if shopt -q checkwinsize; then
        (:)
      else
        shopt -s checkwinsize
        (:)
        shopt -u checkwinsize
      fi 2>&"$_ble_util_fd_stderr"
    }
    ble/term/update-winsize
    return 0
  fi

  local ret

  # (a) "tput lines cols" または "tput li co" による実装 (2909.052 usec/eval)
  if ble/bin#freeze-utility-path tput; then
    if ble/util/assign-words ret 'ble/bin/tput lines cols' 2>/dev/null &&
        [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/update-winsize {
        local -x ret LINES= COLUMNS=
        ble/util/assign-words ret 'ble/bin/tput lines cols' 2>/dev/null
        ble/util/unlocal LINES COLUMNS
        [[ ${ret[0]} ]] && LINES=${ret[0]}
        [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
      }
      return 0
    elif ble/util/assign-words ret 'ble/bin/tput li co' 2>/dev/null &&
        [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/update-winsize {
        local -x ret LINES= COLUMNS=
        ble/util/assign-words ret 'ble/bin/tput li co' 2>/dev/null
        ble/util/unlocal LINES COLUMNS
        [[ ${ret[0]} ]] && LINES=${ret[0]}
        [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
      }
      return 0
    fi
  fi

  # (b) "stty size" による実装 (2976.172 usec/eval)
  if ble/util/assign-words ret 'ble/bin/stty size' 2>/dev/null &&
      [[ ${#ret[@]} -eq 2 && ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
  then
    LINES=${ret[0]} COLUMNS=${ret[1]}
    function ble/term/update-winsize {
      local ret
      ble/util/assign-words ret 'ble/bin/stty size' 2>/dev/null
      [[ ${ret[0]} ]] && LINES=${ret[0]}
      [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
    }
    return 0
  fi

  # (c) "resize" による実装 (3108.696 usec/eval)
  if ble/bin#freeze-utility-path resize &&
      ble/util/assign ret 'ble/bin/resize' &&
      ble/string#match "$ret" 'COLUMNS=([0-9]+).*LINES=([0-9]+)'
  then
    LINES=${BASH_REMATCH[2]} COLUMNS=${BASH_REMATCH[1]}
    function ble/term/update-winsize {
      local ret
      ble/util/assign ret 'ble/bin/resize' 2>/dev/null
      ble/string#match ret 'COLUMNS=([0-9]+).*LINES=([0-9]+)'
      [[ ${BASH_REMATCH[2]} ]] && LINES=${BASH_REMATCH[2]}
      [[ ${BASH_REMATCH[1]} ]] && COLUMNS=${BASH_REMATCH[1]}
    }
    return 0
  fi

  # (d) "bash -O checkwinsize -c ..." による実装 (bash-4.3 以上) (9094.595 usec/eval)
  function ble/term/update-winsize {
    local ret script='LINES= COLUMNS=; (:); [[ $COLUMNS && $LINES ]] && builtin echo "$LINES $COLUMNS"'
    ble/util/assign-words ret '"$BASH" -O checkwinsize -c "$script"' 2>&"$_ble_util_fd_stderr"
    [[ ${ret[0]} ]] && LINES=${ret[0]}
    [[ ${ret[1]} ]] && COLUMNS=${ret[1]}
  }
  ble/term/update-winsize
  return 0
}

# bash-5.2 では "bind -x" 内部で checkwinsize が動作しないので
# ble/term/stty/enter に於いて自前で端末サイズを取得して LINES COLUMNS を更新す
# る。
if ((50200<=_ble_bash&&_ble_bash<50300)); then
  ## @fn ble/term/update-winsize/.stty-enter.advice
  ##   ble/term/stty/enter の実装を "stty size" を用いて調節します。
  ##
  ##   最初の ble/term/stty/enter の呼び出し時に'stty "${enter_options[@]}"
  ##   size' が動くか検査し、使えそうならば今後はstty に size を追加して呼び出
  ##   してそれを元にして LINES, COLUMNS を再設定する様にする。
  ##
  ##   テスト自体が stty の設定を変更するので、初回の ble/term/stty/enter の呼
  ##   び出しの時にテストも含めて調整を実行することにしている。
  function ble/term/update-winsize/.stty-enter.advice {
    local ret stderr test_command='ble/bin/stty -echo -nl -icrnl -icanon "${_ble_term_stty_flags_enter[@]}" size'
    if ble/util/assign stderr 'ble/util/assign-words ret "$test_command" 2>&1' &&
        [[ ! $stderr ]] &&
        ((${#ret[@]}==2)) &&
        [[ ${ret[0]} =~ ^[0-9]+$ && ${ret[1]} =~ ^[0-9]+$ ]]
    then
      LINES=${ret[0]} COLUMNS=${ret[1]}
      function ble/term/stty/enter {
        [[ $_ble_term_stty_state ]] && return 0
        local ret
        ble/util/assign-words ret 'ble/bin/stty -echo -nl -icrnl -icanon "${_ble_term_stty_flags_enter[@]}" size'
        [[ ${ret[0]} =~ ^[0-9]+$ ]] && LINES=${ret[0]}
        [[ ${ret[1]} =~ ^[0-9]+$ ]] && COLUMNS=${ret[1]}
        _ble_term_stty_state=1
      }
    else
      ble/term/update-winsize
      ble/function#advice before ble/term/stty/enter ble/term/update-winsize
    fi
    builtin unset -f "$FUNCNAME"
  }
  ble/function#advice before ble/term/stty/enter ble/term/update-winsize/.stty-enter.advice
fi


#---- cursor state ------------------------------------------------------------

bleopt/declare -v term_cursor_external 0

_ble_term_cursor_current=unknown
_ble_term_cursor_internal=0
_ble_term_cursor_hidden_current=unknown
_ble_term_cursor_hidden_internal=reveal

# #D1516 今迄にカーソル変更がなく、且つ既定値に戻そうとしている時は何
#   もしない為、初めから 0 にしておく事にする。xterm.js で DECSCUSR(0)
#   がユーザー既定値でない事への対策。外部コマンドがカーソル形状を復元
#   するという事を前提にしている。
# #D1873 単に 0 を指定しているだけだと cursor をユーザー設定していなく
#   ても、コマンド実行後の term/enter の時に結局 unknown が設定されて、
#   DECSCUSR(0) が送信されて問題になる。未だ一度も ble.sh として変更し
#   ていない事を表す値として default という物を導入する事にした。
#   default の時には term/enter 時のクリアをしない。
_ble_term_cursor_current=default

function ble/term/cursor-state/.update {
  local state=$(($1))
  [[ ${_ble_term_cursor_current/default/0} == "$state" ]] && return 0

  if [[ ! $_ble_term_Ss ]]; then
    case $_ble_term_TERM in
    (mintty:*|xterm:*|RLogin:*|kitty:*|screen:*|tmux:*|contra:*|cygwin:*|wezterm:*|wt:*)
      local _ble_term_Ss=$'\e[@1 q' ;;
    esac
  fi
  local ret=${_ble_term_Ss//@1/"$state"}

  # Note: 既に pass-through seq が含まれている時はスキップする。
  [[ $ret && $ret != $'\eP'*$'\e\\' ]] &&
    ble/term/quote-passthrough "$ret" '' all

  ble/util/buffer "$ret"

  _ble_term_cursor_current=$state
}
function ble/term/cursor-state/set-internal {
  _ble_term_cursor_internal=$1
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update "$1"
}

function ble/term/cursor-state/.update-hidden {
  local state=$1
  [[ $state != hidden ]] && state=reveal
  [[ $_ble_term_cursor_hidden_current == "$state" ]] && return 0

  if [[ $state == hidden ]]; then
    ble/util/buffer "$_ble_term_civis"
  else
    ble/util/buffer "$_ble_term_cvvis"
  fi

  _ble_term_cursor_hidden_current=$state
}
function ble/term/cursor-state/hide {
  _ble_term_cursor_hidden_internal=hidden
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update-hidden hidden
}
function ble/term/cursor-state/reveal {
  _ble_term_cursor_hidden_internal=reveal
  [[ $_ble_term_state == internal ]] &&
    ble/term/cursor-state/.update-hidden reveal
}

#---- DECSET(2004): bracketed paste mode --------------------------------------

function ble/term/bracketed-paste-mode/.init {
  local _ble_local_rlvars; ble/util/rlvar#load

  bleopt/declare -v term_bracketed_paste_mode on
  if ((_ble_bash>=50100)) && ! ble/util/rlvar#test enable-bracketed-paste; then
    # Bash 5.1 以降では既定で on なのでもし無効になっていたら意図的にユーザーが
    # off にしたという事。
    bleopt term_bracketed_paste_mode=
  fi
  function bleopt/check:term_bracketed_paste_mode {
    if [[ $_ble_term_bracketedPasteMode_internal ]]; then
      if [[ $value ]]; then
        [[ $bleopt_term_bracketed_paste_mode ]] || ble/util/buffer $'\e[?2004h'
      else
        [[ ! $bleopt_term_bracketed_paste_mode ]] || ble/util/buffer $'\e[?2004l'
      fi
    fi
  }
  ble/util/rlvar#bind-bleopt enable-bracketed-paste term_bracketed_paste_mode bool

  builtin unset -f "$FUNCNAME"
}
ble/term/bracketed-paste-mode/.init

_ble_term_bracketedPasteMode_internal=
function ble/term/bracketed-paste-mode/enter {
  _ble_term_bracketedPasteMode_internal=1
  [[ ${bleopt_term_bracketed_paste_mode-} ]] &&
    ble/util/buffer $'\e[?2004h'
}
function ble/term/bracketed-paste-mode/leave {
  _ble_term_bracketedPasteMode_internal=
  [[ ${bleopt_term_bracketed_paste_mode-} ]] &&
    ble/util/buffer $'\e[?2004l'
}
if [[ $TERM == minix ]]; then
  # Minix console は DECSET も使えない
  function ble/term/bracketed-paste-mode/enter { :; }
  function ble/term/bracketed-paste-mode/leave { :; }
fi

#---- DA2 ---------------------------------------------------------------------

_ble_term_TERM=()
_ble_term_DA1R=()
_ble_term_DA2R=()
_ble_term_TERM_done=

## @fn ble/term/DA2/initialize-term [depth]
##   @var[out] _ble_term_TERM
function ble/term/DA2/initialize-term {
  local depth=$1
  local da2r=${_ble_term_DA2R[depth]}
  local rex='^[0-9]*(;[0-9]*)*$'; [[ $da2r =~ $rex ]] || return 1
  local da2r_vec
  ble/string#split da2r_vec ';' "$da2r"
  da2r_vec=("${da2r_vec[@]/#/10#0}") # 0で始まっていても10進数で解釈; WA #D1570 checked (is-array)

  case $da2r in
  # Note #D1946: Terminology は xterm と区別が付かないが決め打ちの様なので、丁
  # 度 xterm の該当 version を使っている可能性は低いと見て、取り敢えず
  # terminology と判断する事にする。
  ('0;271;0')  _ble_term_TERM[depth]=terminology:200 ;;   # 2012-10-05 https://github.com/borisfaure/terminology/commit/500e7be8b2b876462ed567ef6c90527f37482adb
  ('41;285;0') _ble_term_TERM[depth]=terminology:300 ;;   # 2013-01-22 https://github.com/borisfaure/terminology/commit/526cc2aeacc0ae54825cbc3a3e2ab64f612f83c9
  ('61;337;0') _ble_term_TERM[depth]=terminology:10400 ;; # 2019-01-20 https://github.com/borisfaure/terminology/commit/96bbfd054b271f7ad7f31e699b13c12cb8fbb2e2

  # Note #D1909: wezterm が 2022-04-07 に DA2 を変更している。xterm-277 と区別
  # が付かないが、ちょうど該当 xterm version (2012-01-08) を使っている可能性は
  # 低いと見て取り敢えず wezterm とする。更に mlterm-3.4.2..3.7.1
  # (201412..201608) も 1;277;0 を使っていた。
  ('0;0;0') _ble_term_TERM[depth]=wezterm:0 ;;
  ('1;277;0') _ble_term_TERM[depth]=wezterm:20220408 ;; # 2022-04-07 https://github.com/wez/wezterm/commit/ad91e3776808507cbef9e6d758b89d7ca92a4c7e

  # Konsole も大体決め打ちにしている。最近変更した様だ。
  ('0;115;0') _ble_term_TERM[depth]=konsole:30000  ;; # 2001-09-16 https://github.com/KDE/konsole/commit/2d93fed82aa27e89c9d7301d09d2e24e4fa4416d
  ('1;115;0') _ble_term_TERM[depth]=konsole:220380 ;; # 2022-02-24 https://github.com/KDE/konsole/commit/0cc64dcf7b90075bd17e46653df3069208d6a590

  # mlterm (#D1999)
  # - 0;96;0   v3.1.0 (2012-03-24) https://github.com/arakiken/mlterm/commit/6ca37d7f99337194d8c893cc48285c0614762535
  # * 1;96;0   v3.1.2 (2012-05-20) https://github.com/arakiken/mlterm/commit/6293d0af9cf1e78fd6c35620824b62ff6c87370b
  # * 1;277;0  v3.4.2 (2014-12-27) https://github.com/arakiken/mlterm/commit/c4fb36291ec67daf73c48c5b60d1af88ad0487e6
  # - 1;279;0  v3.7.2 (2016-08-06) https://github.com/arakiken/mlterm/commit/24a2a4886b70f747fba4ea7c07d6e50a6a49039d
  # * 24;279;0 v3.7.2 (2016-08-11) https://github.com/arakiken/mlterm/commit/d094f0f4a31224e1b8d2fa15c6ab37bd1c4c4713
  ('1;96;0')   _ble_term_TERM[depth]=mlterm:30102 ;;
  ('1;277;0')  _ble_term_TERM[depth]=mlterm:30402 ;; # Note: wezterm:20220408 と同じ。wezterm の方を優先
  ('24;279;0') _ble_term_TERM[depth]=mlterm:30702 ;;

  ('0;10;1') # Windows Terminal
    # 現状ハードコードされている。
    # https://github.com/microsoft/terminal/blob/bcc38d04/src/terminal/adapter/adaptDispatch.cpp#L779-L782
    _ble_term_TERM[depth]=wt:0 ;;
  ('0;'*';1')
    if ((da2r_vec[1]>=1001)); then
      # Alacritty
      # https://github.com/alacritty/alacritty/blob/4734b2b8/alacritty_terminal/src/term/mod.rs#L1315
      # https://github.com/alacritty/alacritty/blob/4734b2b8/alacritty_terminal/src/term/mod.rs#L3104
      _ble_term_TERM[depth]=alacritty:$((da2r_vec[1]))
    fi ;;
  ('1;0'?????';0')
    _ble_term_TERM[depth]=foot:${da2r:3:5} ;;
  ('1;'*)
    if ((4000<=da2r_vec[1]&&da2r_vec[1]<=4009&&3<=da2r_vec[2])); then
      _ble_term_TERM[depth]=kitty:$((da2r_vec[1]-4000))
    elif ((2000<=da2r_vec[1]&&da2r_vec[1]<5400&&da2r_vec[2]==0)); then
      local version=$((da2r_vec[1]))
      _ble_term_TERM[depth]=vte:$version
      if ((version<4000)); then
        # Note #D1785: vte 0.40.0 未満では DECSCUSR に対応していない。更に未知のシーケ
        # ンスを無視する事もできない。それにも拘らず vte-based な端末は
        # TERM=xterm を設定するので DECSCUSR が出力されて表示が乱れる原因になる。
        # vte の version を見て強制的に DECSCUSR を off にする。
        _ble_term_Ss=
      fi
    fi ;;
  ('65;'*)
    if ((5300<=da2r_vec[1]&&da2r_vec[2]==1)); then
      _ble_term_TERM[depth]=vte:$((da2r_vec[1]))
    elif ((da2r_vec[1]>=100)); then
      _ble_term_TERM[depth]=RLogin:$((da2r_vec[1]))
    fi ;;
  ('67;'*)
    local rex='^67;[0-9]{3,};0$'
    if [[ $TERM == cygwin && $da2r =~ $rex ]]; then
      _ble_term_TERM[depth]=cygwin:$((da2r_vec[1]))
    fi ;;
  ('77;'*';0')
    _ble_term_TERM[depth]=mintty:$((da2r_vec[1])) ;;
  ('83;'*)
    local rex='^83;[0-9]+;0$'
    [[ $da2r =~ $rex ]] && _ble_term_TERM[depth]=screen:$((da2r_vec[1])) ;;
  ('84;0;0')
    _ble_term_TERM[depth]=tmux:0 ;;
  ('99;'*)
    _ble_term_TERM[depth]=contra:$((da2r_vec[1])) ;;
  esac
  [[ ${_ble_term_TERM[depth]} ]] && return 0

  # xterm
  if rex='^xterm(-|$)'; [[ $TERM =~ $rex ]]; then
    local version=$((da2r_vec[1]))
    if rex='^1;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      # Note: vte (2000以上), kitty (4000以上) は処理済み
      true
    elif rex='^0;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((95<=version))
    elif rex='^(2|24|1[89]|41|6[145]);[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((280<=version))
    elif rex='^32;[0-9]+;0$'; [[ $da2r =~ $rex ]]; then
      ((354<=version&&version<2000))
    else
      false
    fi && { _ble_term_TERM[depth]=xterm:$version; return 0; }
  fi

  _ble_term_TERM[depth]=unknown:-
  return 0
}

function ble/term/DA1/notify { _ble_term_DA1R=$1; blehook/invoke term_DA1R; }
function ble/term/DA2/notify {
  # Note #D1485: screen で attach した時に外側の端末の DA2R が混入する
  # 事がある。2回目以降に受信した内容は ble.sh の内部では使用しない事
  # にする。
  local depth=${#_ble_term_DA2R[@]}
  if ((depth==0)) || ble/string#match "${_ble_term_TERM[depth-1]}" '^(screen|tmux):'; then
    _ble_term_DA2R[depth]=$1
    ble/term/DA2/initialize-term "$depth"

    local is_outermost=1
    case ${_ble_term_TERM[depth]} in
    (screen:*|tmux:*)
      # 外側の端末にも DA2 要求を出す。[ Note: 最初の DA2 要求は
      # ble/decode/attach (decode.sh) から送信されている。 ]
      local ret is_outermost=
      ble/term/quote-passthrough $'\e[>c' "$((depth+1))"
      ble/util/buffer "$ret" ;;
    (contra:*)
      if [[ ! ${_ble_term_Ss-} ]]; then
        _ble_term_Ss=$'\e[@1 q'
      fi ;;
    (terminology:*)
      # Note #D1946: Terminology にはカーソル位置を戻した時に xenl 状態
      # (ty->termstate.wrapnext) が残ってしまうバグがある。これを避ける為に一旦
      # CR で行頭に戻ってから DECRC する。
      _ble_term_sc=$'\e7' _ble_term_rc=$'\r\e8' ;;
    esac

    if [[ $is_outermost ]]; then
      _ble_term_TERM_done=1
      ble/term/modifyOtherKeys/reset
    fi

    # 外側の端末情報は以降では処理しない
    ((depth)) && return 0
  fi

  blehook/invoke term_DA2R
}

## @fn ble/term/quote-passthrough seq [level] [opts]
##   指定したシーケンスを、端末マルチプレクサを通過する様に加工します。
##
##   @param[in] seq
##     送信するシーケンスを指定します。
##
##   @param[in,opt] level
##     シーケンスを届ける階層。0 が一番内側の Bash が動作している端末マルチプレ
##     クサ。省略した場合は一番外側の端末にシーケンスを届ける。
##
##   @param[in,opt] opts
##     コロン区切りの設定。
##
##     all
##       指定した階層以下の全ての端末・端末マルチプレクサに同じシーケンスを送信
##       する。[ Note: terminal multiplexer 自体が処理して外側に作用するかもし
##       れないので、先に pass-through で外側に送った後に terminal multiplexer
##       自体にも送る。 ]
##
##   @var[out] ret
##     加工されたシーケンスを格納します。
##
function ble/term/quote-passthrough {
  local seq=$1 level=${2:-$((${#_ble_term_DA2R[@]}-1))} opts=$3
  local all=; [[ :$opts: == *:all:* ]] && all=1
  ret=$seq
  [[ $seq ]] || return 0
  local i
  for ((i=level;--i>=0;)); do
    if [[ ${_ble_term_TERM[i]} == tmux:* ]]; then
      # Note: tmux では pass-through seq の中に含まれる \e は \e\e の様に
      # escape する。
      ret=$'\ePtmux;'${ret//$'\e'/$'\e\e'}$'\e\\'${all:+$seq}
    else
      # Note: screen は、最初に現れる \e\\ で pass-through sequence が終わって
      # しまうので単純に pass-through sequence を入れ子にはできない。なので、例
      # えば "\ePXXX\e\\YYY" を pass-through する時には、\e と \\ の間で
      # [\ePXXX\e][\\YYY] の様に分割して、それぞれ pass-through する。
      ret=$'\eP'${ret//$'\e\\'/$'\e\e\\\eP\\'}$'\e\\'${all:+$seq}
    fi
  done
}

_ble_term_DECSTBM=
_ble_term_DECSTBM_reset=
function ble/term/test-DECSTBM.hook1 {
  (($1==2)) && _ble_term_DECSTBM=$'\e[%s;%sr'
}
function ble/term/test-DECSTBM.hook2 {
  if [[ $_ble_term_DECSTBM ]]; then
    if (($1==2)); then
      # Failed to reset DECSTBM with \e[;r
      _ble_term_DECSTBM_reset=$'\e[r'
    else
      _ble_term_DECSTBM_reset=$'\e[;r'
    fi
  fi
}
function ble/term/test-DECSTBM {
  # Note: kitty 及び wezterm では SCORC と区別できる形の \e[;r では復
  # 帰できない。
  local -a DRAW_BUFF=()
  ble/canvas/panel/goto-top-dock.draw
  ble/canvas/put.draw "$_ble_term_sc"$'\e[1;2r'
  ble/canvas/put-cup.draw 2 1
  ble/canvas/put-cud.draw 1
  ble/term/CPR/request.draw ble/term/test-DECSTBM.hook1
  ble/canvas/put.draw $'\e[;r'
  ble/canvas/put-cup.draw 2 1
  ble/canvas/put-cud.draw 1
  ble/term/CPR/request.draw ble/term/test-DECSTBM.hook2
  ble/canvas/put.draw $'\e[r'"$_ble_term_rc"
  ble/canvas/bflush.draw
}

#---- DSR(6) ------------------------------------------------------------------
# CPR (CURSOR POSITION REPORT)

_ble_term_CPR_timeout=60
_ble_term_CPR_last_seconds=$SECONDS
_ble_term_CPR_hook=()
function ble/term/CPR/request.buff {
  ((SECONDS>_ble_term_CPR_last_seconds+_ble_term_CPR_timeout)) &&
    _ble_term_CPR_hook=()
  _ble_term_CPR_last_seconds=$SECONDS
  ble/array#push _ble_term_CPR_hook "$1"
  ble/util/buffer $'\e[6n'
  return 147
}
function ble/term/CPR/request.draw {
  ((SECONDS>_ble_term_CPR_last_seconds+_ble_term_CPR_timeout)) &&
    _ble_term_CPR_hook=()
  _ble_term_CPR_last_seconds=$SECONDS
  ble/array#push _ble_term_CPR_hook "$1"
  ble/canvas/put.draw $'\e[6n'
  return 147
}
function ble/term/CPR/notify {
  local hook=${_ble_term_CPR_hook[0]}
  ble/array#shift _ble_term_CPR_hook
  [[ ! $hook ]] || builtin eval -- "$hook $1 $2"
}

#---- SGR(>4): modifyOtherKeys ------------------------------------------------

bleopt/declare -v term_modifyOtherKeys_external auto
bleopt/declare -v term_modifyOtherKeys_internal auto
bleopt/declare -v term_modifyOtherKeys_passthrough_kitty_protocol ''

_ble_term_modifyOtherKeys_current=
_ble_term_modifyOtherKeys_current_method=
_ble_term_modifyOtherKeys_current_TERM=
function ble/term/modifyOtherKeys/.update {
  local IFS=$_ble_term_IFS state=${1%%:*}
  [[ $1 == "$_ble_term_modifyOtherKeys_current" ]] &&
    [[ $state != 2 || "${_ble_term_TERM[*]}" == "$_ble_term_modifyOtherKeys_current_TERM" ]] &&
    return 0

  # Note: RLogin では modifyStringKeys (\e[>5m) も指定しないと駄目。
  #   また、RLogin は modifyStringKeys にすると S-数字 を
  #   記号に翻訳してくれないので注意。
  local previous=${_ble_term_modifyOtherKeys_current%%:*} method
  if [[ $state == 2 ]]; then
    case $_ble_term_TERM in
    (RLogin:*) method=RLogin_modifyStringKeys ;;
    (kitty:*)
      local da2r_vec
      ble/string#split da2r_vec ';' "$_ble_term_DA2R"
      if ((da2r_vec[2]>=23)); then
        method=kitty_keyboard_protocol
      else
        method=kitty_modifyOtherKeys
      fi ;;
    (screen:*|tmux:*)
      method=modifyOtherKeys

      if [[ $bleopt_term_modifyOtherKeys_passthrough_kitty_protocol ]]; then
        # Note (#D1843): if the outermost terminal is kitty-0.23+, we directly
        #   send keyboard-protocol sequences to the outermost kitty.
        local index=$((${#_ble_term_TERM[*]}-1))
        if [[ ${_ble_term_TERM[index]} == kitty:* ]]; then
          local da2r_vec
          ble/string#split da2r_vec ';' "${_ble_term_DA2R[index]}"
          ((da2r_vec[2]>=23)) && method=kitty_keyboard_protocol
        fi
      fi ;;
    (*)
      method=modifyOtherKeys
      if [[ $1 == *:auto ]]; then
        # 問題を起こす端末で無効化。
        ble/term/modifyOtherKeys/.supported || method=disabled
      fi ;;
    esac

    # Note #D2062: mc の内部にいる時は外側の端末に関係なく modifyOtherKeys は無
    # 効化する。C-o が効かなくなるし、その他の mc に対するコマンドも効かなくな
    # る可能性がある。
    [[ $MC_SID ]] && method=disabled

    # 別の方式で有効化されている時は先に解除しておく。
    if ((previous>=2)) &&
      [[ $method != "$_ble_term_modifyOtherKeys_current_method" ]]
    then
      ble/term/modifyOtherKeys/.update 1
      previous=1
    fi
  else
    method=$_ble_term_modifyOtherKeys_current_method
  fi
  _ble_term_modifyOtherKeys_current=$1
  _ble_term_modifyOtherKeys_current_method=$method
  _ble_term_modifyOtherKeys_current_TERM="${_ble_term_TERM[*]}"

  case $method in
  (RLogin_modifyStringKeys)
    case $state in
    (0) ble/util/buffer $'\e[>5;0m' ;;
    (1) ble/util/buffer $'\e[>5;1m' ;;
    (2) ble/util/buffer $'\e[>5;1m\e[>5;2m' ;;
    esac
    ;; # fallback to modifyOtherKeys
  (kitty_modifyOtherKeys)
    # Note: kitty has quirks in its implementation of modifyOtherKeys.
    # Note #D1549: 1 では無効にならない。変な振る舞い。
    # Note #D1626: 更に最近の kitty では \e[>4;0m でも駄目で \e[>4m としなければならない様だ。
    case $state in
    (0|1) ble/util/buffer $'\e[>4;0m\e[>4m' ;;
    (2)   ble/util/buffer $'\e[>4;1m\e[>4;2m\e[m' ;;
    esac
    return 0 ;;
  (kitty_keyboard_protocol)
    # Note: Kovid removed the support for modifyOtherKeys in kitty 0.24 after
    #   vim has pointed out the quirk of kitty.  The kitty keyboard mode only
    #   has push/pop operations so that their numbers need to be balanced.
    local seq=
    case $state in
    (0|1) # pop keyboard mode
      # When this is empty, ble.sh has not yet pushed any keyboard modes, so
      # we just ignore the keyboard mode change.
      [[ $previous ]] || return 0

      ((previous>=2)) && seq=$'\e[<u' ;;
    (2) # push keyboard mode
      ((previous>=2)) || seq=$'\e[>1u' ;;
    esac
    if [[ $seq ]]; then
      # Note (#D1843): we directly send kitty-keyboard-protocol sequences to
      #   the outermost terminal.
      local ret
      ble/term/quote-passthrough "$seq"
      ble/util/buffer "$ret"

      # find innermost tmux and adjust its modifyOtherKeys state (do not care
      # about screen which is transparent for the user input keys)
      local level
      for ((level=1;level<${#_ble_term_TERM[@]}-1;level++)); do
        [[ ${_ble_term_TERM[level]} == tmux:* ]] || continue
        case $state in
        (0) seq=$'\e[>4;0m\e[m' ;;
        (1) seq=$'\e[>4;1m\e[m' ;;
        (2) seq=$'\e[>4;1m\e[>4;2m\e[m' ;;
        esac
        ble/term/quote-passthrough "$seq" "$level"
        ble/util/buffer "$ret"
        break
      done
    fi
    return 0 ;;
  (disabled)
    return 0 ;;
  esac

  # Note: 対応していない端末が SGR と勘違いしても
  #  大丈夫な様に SGR を最後にクリアしておく。
  # Note: \e[>4;2m の時は、対応していない端末のため
  #   一端 \e[>4;1m にしてから \e[>4;2m にする。
  case $state in
  (0) ble/util/buffer $'\e[>4;0m\e[m' ;;
  (1) ble/util/buffer $'\e[>4;1m\e[m' ;;
  (2) ble/util/buffer $'\e[>4;1m\e[>4;2m\e[m' ;;
  esac
}
function ble/term/modifyOtherKeys/.supported {
  [[ $_ble_term_TERM_done ]] || return 1

  # libvte は SGR(>4) を直接画面に表示してしまう。
  [[ $_ble_term_TERM == vte:* ]] && return 1

  # 改造版 Poderosa は通知でウィンドウサイズを毎回変更するので表示が乱れてしまう
  [[ $MWG_LOGINTERM == rosaterm ]] && return 1

  case $TERM in
  (linux)
    # Note #D1213: linux (kernel 5.0.0) は "\e[>" でエスケープシーケンスを閉じ
    # てしまう。5.4.8 は大丈夫だがそれでも modifyOtherKeys に対応していない。
    return 1 ;;
  (minix|sun*)
    # minix, Solaris のコンソールもそのまま出力してしまう。
    return 1 ;;
  (st|st-*)
    # Note #D1631: st のエラーログに unknown csi が出るとの文句が出たので無効化。
    # 恐らく将来に亘って st は modifyOtherKeys には対応しないだろう。
    return 1 ;;
  esac

  return 0
}
function ble/term/modifyOtherKeys/enter {
  local value=$bleopt_term_modifyOtherKeys_internal
  if [[ $value == auto ]]; then
    value=2:auto
  fi
  ble/term/modifyOtherKeys/.update "$value"
}
function ble/term/modifyOtherKeys/leave {
  local value=$bleopt_term_modifyOtherKeys_external
  if [[ $value == auto ]]; then
    value=1:auto
  fi
  ble/term/modifyOtherKeys/.update "$value"
}
function ble/term/modifyOtherKeys/reset {
  ble/term/modifyOtherKeys/.update "$_ble_term_modifyOtherKeys_current"
}

#---- Alternate Screen Buffer mode --------------------------------------------

_ble_term_altscr_state=
function ble/term/enter-altscr {
  [[ $_ble_term_altscr_state ]] && return 0
  _ble_term_altscr_state=("$_ble_canvas_x" "$_ble_canvas_y")
  if [[ $_ble_term_rmcup ]]; then
    ble/util/buffer "$_ble_term_smcup"
  else
    local -a DRAW_BUFF=()
    ble/canvas/put.draw $'\e[?1049h'
    ble/canvas/put-cup.draw "$LINES" 0
    ble/canvas/put-ind.draw "$LINES"
    ble/canvas/bflush.draw
  fi
}
function ble/term/leave-altscr {
  [[ $_ble_term_altscr_state ]] || return 0
  if [[ $_ble_term_rmcup ]]; then
    ble/util/buffer "$_ble_term_rmcup"
  else
    local -a DRAW_BUFF=()
    ble/canvas/put-cup.draw "$LINES" 0
    ble/canvas/put-ind.draw
    ble/canvas/put.draw $'\e[?1049l'
    ble/canvas/bflush.draw
  fi
  _ble_canvas_x=${_ble_term_altscr_state[0]}
  _ble_canvas_y=${_ble_term_altscr_state[1]}
  _ble_term_altscr_state=()
}

#---- rl variable: convert-meta -----------------------------------------------

_ble_term_rl_convert_meta_adjusted=
_ble_term_rl_convert_meta_external=
function ble/term/rl-convert-meta/enter {
  [[ $_ble_term_rl_convert_meta_adjusted ]] && return 0
  _ble_term_rl_convert_meta_adjusted=1

  if ble/util/rlvar#test convert-meta; then
    _ble_term_rl_convert_meta_external=on
    builtin bind 'set convert-meta off'
  else
    _ble_term_rl_convert_meta_external=off
  fi
}
function ble/term/rl-convert-meta/leave {
  [[ $_ble_term_rl_convert_meta_adjusted ]] || return 1
  _ble_term_rl_convert_meta_adjusted=

  [[ $_ble_term_rl_convert_meta_external == on ]] &&
    builtin bind 'set convert-meta on'
}

#---- terminal enter/leave ----------------------------------------------------

function ble/term/enter-for-widget {
  ble/term/bracketed-paste-mode/enter
  ble/term/modifyOtherKeys/enter
  ble/term/cursor-state/.update "$_ble_term_cursor_internal"
  ble/term/cursor-state/.update-hidden "$_ble_term_cursor_hidden_internal"
  ble/util/buffer.flush >&2
}
function ble/term/leave-for-widget {
  ble/term/visible-bell/erase
  ble/term/bracketed-paste-mode/leave
  ble/term/modifyOtherKeys/leave
  ble/term/cursor-state/.update "$bleopt_term_cursor_external"
  ble/term/cursor-state/.update-hidden reveal
  ble/util/buffer.flush >&2
}

_ble_term_state=external
function ble/term/enter {
  [[ $_ble_term_state == internal ]] && return 0
  ble/term/stty/enter
  ble/term/rl-convert-meta/enter
  ble/term/enter-for-widget
  _ble_term_state=internal
}
function ble/term/leave {
  [[ $_ble_term_state == external ]] && return 0
  ble/term/stty/leave
  ble/term/rl-convert-meta/leave
  ble/term/leave-for-widget
  [[ $_ble_term_cursor_current == default ]] ||
    _ble_term_cursor_current=unknown # vim は復元してくれない
  _ble_term_cursor_hidden_current=unknown
  _ble_term_state=external
}

function ble/term/finalize {
  ble/term/stty/finalize
  ble/term/leave
  ble/util/buffer.flush >&2
}
function ble/term/initialize {
  ble/term/stty/initialize
  ble/term/test-DECSTBM
  ble/term/enter
}

#------------------------------------------------------------------------------
# String manipulations

_ble_util_s2c_table_enabled=
## @fn ble/util/s2c text [index]
##   @param[in] text
##   @param[in,opt] index
##   @var[out] ret
if ((_ble_bash>=50300)); then
  # printf "'c" で Unicode が読める (どの LC_CTYPE でも Unicode になる)
  function ble/util/s2c {
    builtin printf -v ret %d "'$1"
  }
elif ((_ble_bash>=40100)); then
  function ble/util/s2c {
    # Note #D1881: bash-5.2 以前では printf %d "'x" に対して mbstate_t 状態が
    # 残ってしまう。なので一旦 clear を試みる。
    if ble/util/is-unicode-output; then
      builtin printf -v ret %d "'μ"
    else
      builtin printf -v ret %d "'x"
    fi
    builtin printf -v ret %d "'$1"
  }
elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_util_s2c_table
  _ble_util_s2c_table_enabled=1
  function ble/util/s2c {
    [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
      ble/util/.cache/update-locale

    local s=${1::1}
    ret=${_ble_util_s2c_table[x$s]}
    [[ $ret ]] && return 0

    ble/util/sprintf ret %d "'$s"
    _ble_util_s2c_table[x$s]=$ret
  }
elif ((_ble_bash>=40000)); then
  function ble/util/s2c {
    ble/util/sprintf ret %d "'${1::1}"
  }
else
  # bash-3 では printf %d "'あ" 等としても
  # "あ" を構成する先頭バイトの値が表示されるだけである。
  # 何とかして unicode 値に変換するコマンドを見つけるか、
  # 各バイトを取り出して unicode に変換するかする必要がある。
  # bash-3 では read -n 1 を用いてバイト単位で読み取れる。これを利用する。
  function ble/util/s2c {
    local s=${1::1}
    if [[ $s == [$'\x01'-$'\x7F'] ]]; then
      if [[ $s == $'\x7F' ]]; then
        # Note: bash-3.0 では printf %d "'^?" とすると 0 になってしまう。
        #   printf %d \'^? であれば問題なく 127 になる。
        ret=127
      else
        ble/util/sprintf ret %d "'$s"
      fi
      return 0
    fi

    local bytes byte
    ble/util/assign bytes '
      local IFS=
      while ble/bash/read -n 1 byte; do
        builtin printf "%d " "'\''$byte"
      done <<< "$s"
      IFS=$_ble_term_IFS
    '
    "ble/encoding:$bleopt_input_encoding/b2c" $bytes
  }
fi

# ble/util/c2s

## @fn ble/util/c2s.impl char
##   @var[out] ret
if ((_ble_bash>=40200)); then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.

  # workarounds of bashbug that printf '\uFFFF' results in a broken surrogate
  # pair in systems where sizeof(wchar_t) == 2.
  function ble/util/.has-bashbug-printf-uffff {
    ((40200<=_ble_bash&&_ble_bash<50000)) || return 1
    local LC_ALL=C.UTF-8 2>/dev/null # Workaround: CentOS 7 に C.UTF-8 がなかった
    local ret
    builtin printf -v ret '\uFFFF'
    ((${#ret}==2))
  }
  # suppress locale error #D1440
  ble/function#suppress-stderr ble/util/.has-bashbug-printf-uffff

  if ble/util/.has-bashbug-printf-uffff; then
    function ble/util/c2s.impl {
      if ((0xE000<=$1&&$1<=0xFFFF)) && [[ $_ble_util_locale_encoding == UTF-8 ]]; then
        builtin printf -v ret '\\x%02x' "$((0xE0|$1>>12&0x0F))" "$((0x80|$1>>6&0x3F))" "$((0x80|$1&0x3F))"
      else
        builtin printf -v ret '\\U%08x' "$1"
      fi
      builtin eval "ret=\$'$ret'"
    }
    function ble/util/chars2s.impl {
      if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
        local -a buff=()
        local c i=0
        for c; do
          ble/util/c2s.cached "$c"
          buff[i++]=$ret
        done
        IFS= builtin eval 'ret="${buff[*]}"'
      else
        builtin printf -v ret '\\U%08x' "$@"
        builtin eval "ret=\$'$ret'"
      fi
    }
  else
    function ble/util/c2s.impl {
      builtin printf -v ret '\\U%08x' "$1"
      builtin eval "ret=\$'$ret'"
    }
    function ble/util/chars2s.impl {
      builtin printf -v ret '\\U%08x' "$@"
      builtin eval "ret=\$'$ret'"
    }
  fi
else
  _ble_text_xdigit=(0 1 2 3 4 5 6 7 8 9 A B C D E F)
  _ble_text_hexmap=()
  for ((i=0;i<256;i++)); do
    _ble_text_hexmap[i]=${_ble_text_xdigit[i>>4&0xF]}${_ble_text_xdigit[i&0xF]}
  done

  # 動作確認済 3.1, 3.2, 4.0, 4.2, 4.3
  function ble/util/c2s.impl {
    if (($1<0x80)); then
      builtin eval "ret=\$'\\x${_ble_text_hexmap[$1]}'"
      return 0
    fi

    local bytes i iN seq=
    ble/encoding:"$_ble_util_locale_encoding"/c2b "$1"
    for ((i=0,iN=${#bytes[@]};i<iN;i++)); do
      seq="$seq\\x${_ble_text_hexmap[bytes[i]&0xFF]}"
    done
    builtin eval "ret=\$'$seq'"
  }

  function ble/util/chars2s.loop {
    for c; do
      ble/util/c2s.cached "$c"
      buff[i++]=$ret
    done
  }
  function ble/util/chars2s.impl {
    # Note: 大量の引数を抱えた関数からの関数呼び出しは重いので
    # B=160 毎に小分けにして関数を呼び出す事にする。
    local -a buff=()
    local c i=0 b N=$# B=160
    for ((b=0;b+B<N;b+=B)); do
      ble/util/chars2s.loop "${@:b+1:B}"
    done
    ble/util/chars2s.loop "${@:b+1:N-b}"
    IFS= builtin eval 'ret="${buff[*]}"'
  }
fi

# どうもキャッシュするのが一番速い様だ
_ble_util_c2s_table=()
## @fn ble/util/c2s char
##   @var[out] ret
function ble/util/c2s {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.cache/update-locale

  ret=${_ble_util_c2s_table[$1]-}
  if [[ ! $ret ]]; then
    ble/util/c2s.impl "$1"
    _ble_util_c2s_table[$1]=$ret
  fi
}
function ble/util/c2s.cached {
  # locale check のない版
  ret=${_ble_util_c2s_table[$1]-}
  if [[ ! $ret ]]; then
    ble/util/c2s.impl "$1"
    _ble_util_c2s_table[$1]=$ret
  fi
}
function ble/util/chars2s {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.cache/update-locale
  ble/util/chars2s.impl "$@"
}

## @fn ble/util/c2bc
##   gets a byte count of the encoded data of the char
##   指定した文字を現在の符号化方式で符号化した時のバイト数を取得します。
##   @param[in]  $1 = code
##   @param[out] ret
function ble/util/c2bc {
  "ble/encoding:$bleopt_input_encoding/c2bc" "$1"
}

## @fn ble/util/.cache/update-locale
##
##  使い方
##
##    [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
##      ble/util/.cache/update-locale
##
_ble_util_locale_triple=
_ble_util_locale_ctype=
_ble_util_locale_encoding=UTF-8
function ble/util/.cache/update-locale {
  _ble_util_locale_triple=$LC_ALL:$LC_CTYPE:$LANG

  # clear cache if LC_CTYPE is changed
  local ret; ble/string#tolower "${LC_ALL:-${LC_CTYPE:-$LANG}}"
  if [[ $_ble_util_locale_ctype != "$ret" ]]; then
    _ble_util_locale_ctype=$ret
    _ble_util_c2s_table=()
    [[ $_ble_util_s2c_table_enabled ]] &&
      _ble_util_s2c_table=()

    _ble_util_locale_encoding=C
    if local rex='\.([^@]+)'; [[ $_ble_util_locale_ctype =~ $rex ]]; then
      local enc=${BASH_REMATCH[1]}
      if [[ $enc == utf-8 || $enc == utf8 ]]; then
        enc=UTF-8
      fi

      ble/is-function "ble/encoding:$enc/b2c" &&
        _ble_util_locale_encoding=$enc
    fi
  fi
}

function ble/util/is-unicode-output {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.cache/update-locale
  [[ $_ble_util_locale_encoding == UTF-8 ]]
}

#------------------------------------------------------------------------------

## @fn ble/util/s2chars text
##   @var[out] ret
function ble/util/s2chars {
  local text=$1 n=${#1} i chars
  chars=()
  for ((i=0;i<n;i++)); do
    ble/util/s2c "${text:i:1}"
    ble/array#push chars "$ret"
  done
  ret=("${chars[@]}")
}
function ble/util/s2bytes {
  local LC_ALL= LC_CTYPE=C
  ble/util/s2chars "$1"; local ext=$?
  ble/util/unlocal LC_ALL LC_CTYPE
  ble/util/.cache/update-locale
  return "$?"
} &>/dev/null

# bind で使用される keyseq の形式

## @fn ble/util/c2keyseq char
##   @var[out] ret
function ble/util/c2keyseq {
  local char=$(($1))
  case $char in
  (7)   ret='\a' ;;
  (8)   ret='\b' ;;
  (9)   ret='\t' ;;
  (10)  ret='\n' ;;
  (11)  ret='\v' ;;
  (12)  ret='\f' ;;
  (13)  ret='\r' ;;
  (27)  ret='\e' ;;
  (92)  ret='\\' ;;
  (127) ret='\d' ;;
  (28)  ret='\x1c' ;; # workaround \C-\, \C-\\
  (156) ret='\x9c' ;; # workaround \M-\C-\, \M-\C-\\
  (*)
    if ((char<32||128<=char&&char<160)); then
      local char7=$((char&0x7F))
      if ((1<=char7&&char7<=26)); then
        ble/util/c2s "$((char7+96))"
      else
        ble/util/c2s "$((char7+64))"
      fi
      ret='\C-'$ret
      ((char&0x80)) && ret='\M-'$ret
    else
      ble/util/c2s "$char"
    fi ;;
  esac
}
## @fn ble/util/chars2keyseq char...
##   @var[out] ret
function ble/util/chars2keyseq {
  local char str=
  for char; do
    ble/util/c2keyseq "$char"
    str=$str$ret
  done
  ret=$str
}
## @fn ble/util/keyseq2chars keyseq
##   @arr[out] ret
function ble/util/keyseq2chars {
  local keyseq=$1
  local -a chars=()
  local mods=
  local rex='^([^\]+)|^\\([CM]-|[0-7]{1,3}|x[0-9a-fA-F]{1,2}|.)?'
  while [[ $keyseq ]]; do
    local text=${keyseq::1} esc
    [[ $keyseq =~ $rex ]] &&
      text=${BASH_REMATCH[1]} esc=${BASH_REMATCH[2]}

    if [[ $text ]]; then
      keyseq=${keyseq:${#text}}
      ble/util/s2chars "$text"
    else
      keyseq=${keyseq:1+${#esc}}
      ret=()
      case $esc in
      ([CM]-)  mods=$mods${esc::1}; continue ;;
      (x?*)    ret=$((16#${esc#x})) ;;
      ([0-7]*) ret=$((8#$esc)) ;;
      (a) ret=7 ;;
      (b) ret=8 ;;
      (t) ret=9 ;;
      (n) ret=10 ;;
      (v) ret=11 ;;
      (f) ret=12 ;;
      (r) ret=13 ;;
      (e) ret=27 ;;
      (d) ret=127 ;;
      (*) ble/util/s2c "$esc" ;;
      esac
    fi

    [[ $mods == *C* ]] && ((ret=ret==63?127:(ret&0x1F)))
    [[ $mods == *M* ]] && ble/array#push chars 27
    #[[ $mods == *M* ]] && ((ret|=0x80))
    mods=
    ble/array#push chars "${ret[@]}"
  done

  if [[ $mods ]]; then
    [[ $mods == *M* ]] && ble/array#push chars 27
    ble/array#push chars 0
  fi

  ret=("${chars[@]}")
}

#------------------------------------------------------------------------------

## @fn ble/encoding:UTF-8/b2c byte...
##   @var[out] ret
function ble/encoding:UTF-8/b2c {
  local bytes b0 n i
  bytes=("$@")
  ret=0
  ((b0=bytes[0]&0xFF))
  ((n=b0>=0xF0
    ?(b0>=0xFC?5:(b0>=0xF8?4:3))
    :(b0>=0xE0?2:(b0>=0xC0?1:0)),
    ret=n?b0&0x7F>>n:b0))
  for ((i=1;i<=n;i++)); do
    ((ret=ret<<6|0x3F&bytes[i]))
  done
}

## @fn ble/encoding:UTF-8/c2b char
##   @arr[out] bytes
function ble/encoding:UTF-8/c2b {
  local code=$1 n i
  ((code=code&0x7FFFFFFF,
    n=code<0x80?0:(
      code<0x800?1:(
        code<0x10000?2:(
          code<0x200000?3:(
            code<0x4000000?4:5))))))
  if ((n==0)); then
    bytes=("$code")
  else
    bytes=()
    for ((i=n;i;i--)); do
      ((bytes[i]=0x80|code&0x3F,
        code>>=6))
    done
    ((bytes[0]=code&0x3F>>n|0xFF80>>n&0xFF))
  fi
}

## @fn ble/encoding:C/b2c byte
##   @var[out] ret
function ble/encoding:C/b2c {
  local byte=$1
  ((ret=byte&0xFF))
}
## @fn ble/encoding:C/c2b char
##   @arr[out] bytes
function ble/encoding:C/c2b {
  local code=$1
  bytes=("$((code&0xFF))")
}

#------------------------------------------------------------------------------
# builtin readonly

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_readonly_blacklist}"

function ble/builtin/readonly/.initialize-blacklist {
  function ble/builtin/readonly/.initialize-blacklist { return 0; }

  local -a list=()

  # Bash variables ble.sh uses
  ble/array#push list FUNCNEST IFS IGNOREEOF POSIXLY_CORRECT TMOUT # adjust
  ble/array#push list PWD OLDPWD CDPATH # readlink
  ble/array#push list BASHPID GLOBIGNORE MAPFILE REPLY # util
  ble/array#push list INPUTRC # decode
  ble/array#push list LINES COLUMNS # canvas
  ble/array#push list HIST{CONTROL,IGNORE,SIZE,TIMEFORMAT} # history
  ble/array#push list PROMPT_COMMAND PS1 # prompt
  ble/array#push list BASH_COMMAND BASH_REMATCH HISTCMD LINENO PIPESTATUS TIMEFORMAT # exec
  ble/array#push list BASH_XTRACEFD PS4 # debug

  # Other common variables that ble.sh uses
  ble/array#push list CC LESS MANOPT MANPAGER PAGER PATH MANPATH

  # Other uppercase variables that ble.sh internally uses in each module
  ble/array#push list BUFF # util
  ble/array#push list KEYS KEYMAP WIDGET LASTWIDGET # decode
  ble/array#push list DRAW_BUFF # canvas
  ble/array#push list D{MIN,MAX,MAX0} {HIGHLIGHT,PREV}_{BUFF,UMAX,UMIN} LEVEL LAYER_{UMAX,UMIN} # color
  ble/array#push list HISTINDEX_NEXT FILE LINE INDEX INDEX_FILE # history
  ble/array#push list ARG FLAG REG # vi
  ble/array#push list COMP{1,2,S,V} ACTION CAND DATA INSERT PREFIX_LEN # core-complete
  ble/array#push list PRETTY_NAME NAME VERSION # edit (/etc/os-release)

  local v
  for v in "${list[@]}"; do ble/gdict#set _ble_builtin_readonly_blacklist "$v" 1; done
}
function ble/builtin/readonly/.check-variable-name {
  # Local variables are always allowed to make readonly.  Note: this
  # implementation does not block propagating tempenv variables being
  # propagated to the global context.  There is no way to reliably detect the
  # tempenv variables.
  ble/variable#is-global "$1" || return 0

  # If the variable starts with "_" but does not start with "_ble", it could be
  # a global variable used by another framework.  We allow such namespaced
  # variables being readonly.
  if [[ $1 == _* && $1 != _ble* && $1 != __ble* ]]; then
    return 0
  fi

  # These special variables should not be made readonly.
  case $1 in
  (?)                    return 1;; # single character variables
  (BLE_*|ADVICE_*)       return 1;; # ble.sh variables
  (COMP_*|COMPREPLY)     return 1;; # completion variables
  (READLINE_*)           return 1;; # readline variables
  (LC_*|LANG)            return 1;; # locale variables
  esac

  # If the variable name is in the black list, the variable cannot be readonly.
  ble/builtin/readonly/.initialize-blacklist
  if ble/gdict#get _ble_builtin_readonly_blacklist; then
    return 1
  fi

  # Otherwise, the variables that do not contain lowercase characters are
  # allowed to become readonly.
  if [[ $1 != *[a-z]* ]]; then
    return 0
  fi

  return 1
}

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_builtin_readonly_mark}"
_ble_builtin_readonly_message_count=0
blehook internal_PREEXEC!='_ble_builtin_readonly_message_count=0'

## @fn ble/builtin/readonly/.print-warning
##   @var[out] _ble_local_caller
function ble/builtin/readonly/.print-warning {
  [[ -t 2 ]] || return 0

  # If the caller iformation has not been initialized:
  if [[ ! $_ble_local_caller ]]; then
    _ble_local_caller=-
    local i n=${#FUNCNAME[@]}
    for ((i=1;i<n;i++)); do
      [[ ${FUNCNAME[i]} == *readonly ]] && continue
      [[ ${FUNCNAME[i]} == ble/function#advice/* ]] && continue
      _ble_local_caller="${BASH_SOURCE[i]}:${BASH_LINENO[i-1]}"
      break
    done
  fi

  local s_caller=
  if [[ $_ble_local_caller != - ]]; then
    ! ble/gdict#has _ble_builtin_readonly_mark "$_ble_local_caller:$1" || return 0
    ble/gdict#set _ble_builtin_readonly_mark "$_ble_local_caller:$1" yes
    s_caller=" ($_ble_local_caller)"
  else
    # We show messages only up to ten times
    ((_ble_builtin_readonly_message_count++<10)) || return 0
  fi

  _ble_local_flags=w$_ble_local_flags
  ble/util/print "ble.sh$s_caller: An attempt to make variable \`$1' readonly was blocked." >&2

  return 0
}
function ble/builtin/readonly {
  local _ble_local_set _ble_local_shopt
  ble/base/.adjust-bash-options _ble_local_set _ble_local_shopt

  local _ble_local_flags=
  local -a _ble_local_options=()
  local _ble_local_caller= # used by print-warning
  while (($#)); do
    if ble/string#match "$1" '^([_a-zA-Z][_a-zA-Z0-9]*)($|=)'; then
      _ble_local_flags=v$_ble_local_flags
      local _ble_local_var=${BASH_REMATCH[1]}
      if [[ ${BASH_REMATCH[2]} == = ]]; then
        ble/util/sprintf "$_ble_local_var" "${1#*=}"
      fi

      if ble/builtin/readonly/.check-variable-name "$_ble_local_var"; then
        _ble_local_flags=r$_ble_local_flags
        ble/array#push _ble_local_options "$_ble_local_var"
      else
        ble/builtin/readonly/.print-warning "$1"
      fi
    else
      ble/array#push _ble_local_options "$1"
    fi
    shift
  done

  if [[ $_ble_local_flags == *w* ]]; then
    ble/util/print 'ble.sh: The global variables with unprefixed lowercase names or special names should not be made readonly. It can break arbitrary Bash configurations.' >&2
  fi
  local _ble_local_ext=0
  if [[ $_ble_local_flags != *v* || $_ble_local_flags == *r* ]]; then
    # We call `builtin readonly' only when no variables are specified
    # (e.g. readonly, readonly --help), or at least one variable are allowed to
    # become readonly.
    builtin readonly "${_ble_local_options[@]}"
    _ble_local_ext=$?
  fi
  ble/base/.restore-bash-options _ble_local_set _ble_local_shopt
  return "$?"
}

function readonly { ble/builtin/readonly "$@"; }

#------------------------------------------------------------------------------
# ble/util/message

>| "$_ble_base_run/$$.util.message-listening"
>> "$_ble_base_run/$$.util.message"
_ble_util_message_precmd=()

## @fn ble/util/message/.encode-data target data
##   @param[in] target
##     送信対象のプロセスの PID を指定します
##   @param[in] data
##     送るデータを指定します
##   @var[out] ret
function ble/util/message/.encode-data {
  local target=$1 data=$2
  if ((${#data}<256)); then
    ble/string#quote-word "$data"
    ret=eval:$ret
  else
    ble/util/getpid

    local index=0 file
    while
      file=$_ble_base_run/$target.util.message.data-$BASHPID-$index
      [[ -e $file ]]
    do ((++index)); done

    ble/util/put "$data" >| "$file"

    ret=file:${file##*.}
  fi
}
## @fn ble/util/message/.decode-data data
##   @var[out] ret
function ble/util/message/.decode-data {
  ret=$1
  case $ret in
  (eval:*)
    local value=${ret#eval:}
    ble/syntax:bash/simple-word/is-simple "$value" &&
      builtin eval -- "ret=($value)" ;;
  (file:*)
    local file=$_ble_base_run/$$.util.message.${ret#file:}
    ble/util/readfile ret "$file"
    ble/array#push _ble_local_remove "$file"
  esac
}

function ble/util/message.post {
  local target=${1:-$$} event=${2-} type=${3-} data=${4-}

  if ! [[ $type && $type != *["$_ble_term_IFS"]* ]]; then
    ble/util/print "ble/util/message: invalid message type format '$type'" >&2
    return 2
  elif [[ $target == $$ ]] && ! ble/is-function ble/util/message/handler:"$type"; then
    ble/util/print "ble/util/message: unknown message type name '$type'" >&2
    return 2
  fi

  case $event in
  (precmd) ;;
  (*)
    ble/util/print "ble/util/message: unknown event type '$event'" >&2
    return 2 ;;
  esac

  if [[ $target == broadcast ]]; then
    local ret file
    ble/util/eval-pathname-expansion '"$_ble_base_run"/+([0-9]).util.message-listening' canonical
    for file in "${ret[@]}"; do
      file=${file%-listening}
      local pid=${file##*/}; pid=${pid%%.*}
      if builtin kill -0 "$pid"; then
        ble/util/message/.encode-data "$pid" "$data"
        ble/util/print "$event $type $ret" >> "$file"
      fi
    done

  elif ble/string#match "$target" '^[0-9]+$'; then
    if ! builtin kill -0 "$target"; then
      ble/util/print "ble/util/message: target process $target is not found" >&2
      return 2
    elif [[ ! -f $_ble_base_run/$target.util.message-listening ]]; then
      ble/util/print "ble/util/message: target process $target is not listening ble-messages" >&2
      return 2
    fi

    local ret
    ble/util/message/.encode-data "$target" "$data"
    ble/util/print "$event $type $ret" >> "$_ble_base_run/$target.util.message"
  else
    ble/util/print "ble/util/message: unknown target '$target'" >&2
    return 2
  fi
}
function ble/util/message.check {
  local file=$_ble_base_run/$$.util.message
  while [[ -f $file && -s $file ]]; do
    local fread=$file
    ble/bin/mv -f "$file" "$file-reading" && fread=$file-reading

    local IFS=$_ble_term_IFS event type data
    while ble/bash/read event type data || [[ $event ]]; do
      # check message handler
      [[ $type ]] && ble/is-function ble/util/message/handler:"$type" || continue

      case $event in
      (precmd) ble/array#push _ble_util_message_precmd "$type $data" ;;
      esac
    done < "$fread"

    >| "$fread"
  done
}
function ble/util/message.process {
  ble/util/message.check

  local event=$1
  case $event in
  (precmd)
    local _ble_local_messages
    _ble_local_messages=("${_ble_util_message_precmd[@]}")
    _ble_util_message_precmd=()

    local _ble_local_message
    local -a _ble_local_remove=()
    for _ble_local_message in "${_ble_local_messages[@]}"; do
      local _ble_local_event=${_ble_local_message%%' '*}
      local ret; ble/util/message/.decode-data "${_ble_local_message#* }"
      local _ble_local_data=$ret
      ble/util/unlocal ret
      ble/util/message/handler:"$_ble_local_event" "$_ble_local_data"
    done

    ((${#_ble_local_remove[@]})) &&ble/bin/rm -f "${_ble_local_remove[@]}" ;;
  (*)
    ble/util/print "ble/util/message: unknown event type '$event'" >&2
    return 2 ;;
  esac
}

function ble/util/message/handler:print {
  ble/edit/enter-command-layout # #D1800 pair=leave-command-layout
  ble/util/print "$1" >&2
  ble/edit/leave-command-layout # #D1800 pair=enter-command-layout
}

blehook internal_PRECMD!='ble/util/message.process precmd'
