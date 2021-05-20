# -*- mode:sh;mode:sh-bash -*-
# bash script to be sourced from interactive shell

#------------------------------------------------------------------------------
# ble.sh options

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
function bleopt/.read-arguments {
  flags= pvars=() specs=()

  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--)
      ble/array#push specs "$@"
      break ;;
    (--help)
      flags=H$flags ;;
    (--color|--color=always)
      flags=c${flags//[cn]} ;;
    (--color=never)
      flags=n${flags//[cn]} ;;
    (--color=auto)
      flags=${flags//[cn]} ;;
    (-*)
      ble/util/print "bleopt: unrecognized option '$arg'" >&2
      flags=E$flags ;;
    (*)
      if local rex='^([_a-zA-Z0-9]+)(:?=|$)'; [[ $arg =~ $rex ]]; then
        local var=bleopt_${BASH_REMATCH[1]#bleopt_}
        if [[ ${BASH_REMATCH[2]} != ':=' && ! ${!var+set} ]]; then
          flags=E$flags
          ble/util/print "bleopt: unknown bleopt option \`${var#bleopt_}'" >&2
          continue
        fi

        if [[ ${BASH_REMATCH[2]} ]]; then
          local value=${arg:${#BASH_REMATCH}}
          ble/array#push specs "$var=$value"
        else
          ble/array#push pvars "$var"
        fi
      else
        ble/util/print "bleopt: unrecognized argument '$spec'" >&2
        flags=E$flags
      fi ;;
    esac
  done
}
function bleopt {
  local flags pvars specs
  bleopt/.read-arguments "$@"
  if [[ $flags == *E* ]]; then
    return 2
  elif [[ $flags == *H* ]]; then
    ble/util/print-lines \
      'usage: bleopt [NAME|NAME=VALUE|NAME:=VALUE]...' \
      '    Set ble.sh options. Without arguments, this prints all the settings.' \
      '' \
      '  Options:' \
      '    --help      Print this help.' \
      '' \
      '  Arguments:' \
      '    NAME        Print the value of the option.' \
      '    NAME=VALUE  Set the value to the option.' \
      '    NAME:=VALUE Set or create the value to the option.'
    return 0
  fi

  if ((${#pvars[@]}==0&&${#specs[@]}==0)); then
    local var ip=0
    for var in "${!bleopt_@}"; do
      ble/is-function "bleopt/obsolete:${var#bleopt_}" && continue
      pvars[ip++]=$var
    done
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
    local q="'" Q="'\''" var

    # 着色
    local sgr{0..3}=
    if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
      local ret
      ble/color/face2sgr command_function; sgr1=$ret
      ble/color/face2sgr syntax_varname; sgr2=$ret
      ble/color/face2sgr syntax_quoted; sgr3=$ret
      sgr0=$_ble_term_sgr0
    fi

    local var
    for var in "${pvars[@]}"; do
      if [[ ${!var+set} ]]; then
        local value chars=$'\a\b\e\f\n\r\t\v'
        if [[ ${!var} == *["$chars"]* ]]; then
          local ret; ble/string#escape-for-bash-escape-string "${!var}"
          value=$sgr3\$\'$ret\'$sgr0
        else
          local ret; ble/string#quote-word "${!var}" sgrq="$sgr3":sgr0="$sgr0"
          value=$ret
        fi
        ble/util/print "${sgr1}bleopt$sgr0 ${sgr2}${var#bleopt_}$sgr0=$value"
      else
        flags=E$flags
        ble/util/print "bleopt: invalid ble option name '${var#bleopt_}'" >&2
      fi
    done
  fi

  [[ $flags != *E* ]]
}

function bleopt/declare/.check-renamed-option {
  var=bleopt_$2
  local locate=$'\e[32m'${BASH_SOURCE[3]}:${BASH_LINENO[2]}$'\e[m'
  ble/util/print "$locate (bleopt): The option '$1' has been renamed. Please use '$2' instead." >&2
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
function bleopt/check-all {
  local name defname varname
  for defname in "${!_ble_opt_def_@}"; do
    name=${defname#_ble_opt_def_}
    varname=bleopt_$name
    [[ ${!varname} == "${!defname}" ]] && continue
    ble/is-function bleopt/obsolete:"$name" && continue
    ble/is-function bleopt/check:"$name" || continue

    # 一旦値を既定値に戻して改めてチェックを行う。
    local value=${!varname}
    builtin eval -- "$varname=\$$defname"
    bleopt/check:"$name" &&
      builtin eval "$varname=\$value"
  done
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
  local __name __prefix=$1; shift
  for __name; do
    if ble/is-array "$__name"; then
      builtin eval "$__prefix$__name=(\"\${$__name[@]}\")"
    else
      builtin eval "$__prefix$__name=\"\$$__name\""
    fi
  done
}
function ble/util/restore-vars {
  local __name __prefix=$1; shift
  for __name; do
    if ble/is-array "$__prefix$__name"; then
      builtin eval "$__name=(\"\${$__prefix$__name[@]}\")"
    else
      builtin eval "$__name=\"\$$__prefix$__name\""
    fi
  done
}

#%if !release
## @fn ble/debug/setdbg
function ble/debug/setdbg {
  ble/bin/rm -f "$_ble_base_run/dbgerr"
  local ret
  ble/util/readlink /proc/self/fd/3 3>&1
  ln -s "$ret" "$_ble_base_run/dbgerr"
}
## @fn ble/debug/print text
function ble/debug/print {
  if [[ -e $_ble_base_run/dbgerr ]]; then
    ble/util/print "$1" >> "$_ble_base_run/dbgerr"
  else
    ble/util/print "$1" >&2
  fi
}
## @fn ble/debug/.check-leak-variable
##   [デバグ用] 宣言忘れに依るグローバル変数の汚染位置を特定するための関数。
##
##   使い方
##
##   ```
##   eval "${_ble_debug_check_leak_variable//@var/ret}"
##   ...codes1...
##   ble/util/.check-leak-variable ret tag1
##   ...codes2...
##   ble/util/.check-leak-variable ret tag2
##   ...codes3...
##   ble/util/.check-leak-variable ret tag3
##   ```
_ble_debug_check_leak_variable='local @var=__t1wJltaP9nmow__'
function ble/debug/.check-leak-variable {
  if [[ ${!1} != __t1wJltaP9nmow__ ]]; then
    local IFS=$_ble_term_IFS
    ble/util/print "$1=${!1}:${*:2}" >> a.txt # DEBUG_LEAKVAR
    builtin eval "$1=__t1wJltaP9nmow__"
  fi
}

function ble/debug/print-variables/.append {
  local q=\' Q="'\''"
  _ble_local_out=$_ble_local_out"$1='${2//$q/$Q}'"
}
function ble/debug/print-variables/.append-array {
  local ret; ble/string#quote-words "${@:2}"
  _ble_local_out=$_ble_local_out"$1=($ret)"
}
function ble/debug/print-variables {
  (($#)) || return 0

  local flags= tag=
  local -a _ble_local_vars=()
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (-t) tag=$1; shift ;;
    (-*) ble/util/print "print-variables: unknown option '$arg'" >&2
         flags=${flags}e ;;
    (*) ble/array#push _ble_local_vars "$arg" ;;
    esac
  done
  [[ $flags == *e* ]] && return 1

  local _ble_local_out= _ble_local_var=
  [[ $tag ]] && _ble_local_out="$tag: "
  ble/util/unlocal flags tag arg
  for _ble_local_var in "${_ble_local_vars[@]}"; do
    if ble/is-array "$_ble_local_var"; then
      builtin eval -- "ble/debug/print-variables/.append-array \"\$_ble_local_var\" \"\${$_ble_local_var[@]}\""
    else
      ble/debug/print-variables/.append "$_ble_local_var" "${!_ble_local_var}"
    fi
    _ble_local_out=$_ble_local_out' '
  done
  ble/debug/print "${_ble_local_out%' '}"
}
#%end

#
# variable, array and strings
#

## @fn ble/variable#get-attr varname
##   指定した変数の属性を取得します。
##   @var[out] attr
if ((_ble_bash>=40400)); then
  function ble/variable#get-attr { attr=${!1@a}; }
  function ble/variable#has-attr { [[ ${!1@a} == *["$2"]* ]]; }
else
  function ble/variable#get-attr {
    attr=
    local __ble_tmp=$1
    ble/util/assign __ble_tmp 'declare -p "$__ble_tmp" 2>/dev/null'
    local rex='^declare -([a-zA-Z]*)'
    [[ $__ble_tmp =~ $rex ]] && attr=${BASH_REMATCH[1]}
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

function ble/variable#is-global/.test { ! local "$1" 2>/dev/null; }
function ble/variable#is-global {
  (readonly "$1"; ble/variable#is-global/.test "$1")
}
function ble/variable#copy-state {
  local src=$1 dst=$2
  if [[ ${!src+set} ]]; then
    builtin eval -- "$dst=\${$src}"
  else
    builtin unset -v "$dst"
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
function ble/array#filter {
  local _ble_local_script='
    local -a aARR=() eARR
    for eARR in "${ARR[@]}"; do
      "$2" "$eARR" && ble/array#push "aARR" "$eARR"
    done
    ARR=("${aARR[@]}")
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#filter-by-regex arr regex
function ble/array#filter-by-regex/.predicate { [[ $1 =~ $_ble_local_rex ]]; }
function ble/array#filter-by-regex {
  local _ble_local_rex=$2
  ble/array#filter "$1" ble/array#filter-by-regex/.predicate
}
function ble/array#remove-by-regex/.predicate { ! [[ $1 =~ $_ble_local_rex ]]; }
function ble/array#remove-by-regex {
  local _ble_local_rex=$2
  ble/array#filter "$1" ble/array#remove-by-regex/.predicate
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
      [[ $eARR == "$2" ]] && { ret=$iARR; return 0; }
      ((iARR++))
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
## @fn ble/array#remove arr index
function ble/array#remove-at {
  local _ble_local_script='
    builtin unset -v "ARR[$2]"
    ARR=("${ARR[@]}")
  '; builtin eval -- "${_ble_local_script//ARR/$1}"
}
## @fn ble/array#replace arr needle [replacement]
##   needle に一致する要素を全て replacement に置換します。
##   replacement が指定されていない時は該当要素を unset します。
##   @var[in] arr
##   @var[in] needle
##   @var[in,opt] replacement
function ble/array#replace {
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

function ble/dense-array#fill-range {
  ble/array#reserve-prototype $(($2-$1))
  local _ble_script='
    local -a sARR; sARR=("${_ble_array_prototype[@]::$3-$2}")
    ARR=("${ARR[@]::$2}" "${sARR[@]/#/$4}" "${ARR[@]:$3}")'
  builtin eval -- "${_ble_script//ARR/$1}"
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
  ret="${ret// /$1}"
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
  if [[ -o noglob ]]; then
    # Note: 末尾の sep が無視されない様に、末尾に手で sep を 1 個追加している。
    IFS=$2 builtin eval "$1=(\${*:3}\$2)"
  else
    set -f
    IFS=$2 builtin eval "$1=(\${*:3}\$2)"
    set +f
  fi
}
function ble/string#split-words {
  if [[ -o noglob ]]; then
    IFS=$_ble_term_IFS builtin eval "$1=(\${*:2})"
  else
    set -f
    IFS=$_ble_term_IFS builtin eval "$1=(\${*:2})"
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
## @fn ble/string#touppwer text
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
function ble/string#escape-characters {
  ret=$1
  if [[ $ret == *["$2"]* ]]; then
    local chars1=$2 chars2=${3:-$2}
    local i n=${#chars1} a b
    for ((i=0;i<n;i++)); do
      a=${chars1:i:1} b=\\${chars2:i:1} ret=${ret//"$a"/$b}
    done
  fi
}

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
  ret=${1//"$q"/$Q}
}
function ble/string#escape-for-bash-double-quote {
  ble/string#escape-characters "$1" '\"$`'
  local a b
  a='!' b='"\!"' ret=${ret//"$a"/$b}
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
    a=']'   b=\\$a     ret=${ret//"$a"/$b}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/$b}
    a=$'\t' b=$' \t'   ret=${ret//"$a"/$b}
  fi

  # 上の処理で extglob の ( も quote されてしまうので G の時には戻す。
  if [[ $2 == *G* ]] && shopt -q extglob; then
    a='!\(' b='!(' ret=${ret//"$a"/$b}
    a='@\(' b='@(' ret=${ret//"$a"/$b}
    a='?\(' b='?(' ret=${ret//"$a"/$b}
    a='*\(' b='*(' ret=${ret//"$a"/$b}
    a='+\(' b='+(' ret=${ret//"$a"/$b}
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
        ble/util/c2s $((code+64))
        ret=$sgr1^$ret$sgr0
      elif ((code==127)); then
        ret=$sgr1^?$sgr0
      elif ((128<=code&&code<160)); then
        ble/util/c2s $((code-64))
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
    ret=("${ret[@]/%/$q}")
    ret="${ret[*]/#/$q}"
  }
  function ble/string#quote-command {
    local q=\' Q="'\''" IFS=$_ble_term_IFS
    ret=("${@:2}")
    ret=("${ret[@]//$q/$Q}")
    ret=("${ret[@]/%/$q}")
    ret="$1 ${ret[*]/#/$q}"
  }
fi
## @fn ble/string#quote-word text opts
function ble/string#quote-word {
  ret=$1

  local rex_csi=$'\e\\[[ -?]*[@-~]'
  local opts=$2 sgrq= sgr0=
  if [[ $opts ]]; then
    local rex=':sgrq=(('$rex_csi'|[^:])*):'
    [[ :$opts: =~ $rex ]] &&
      sgrq=${BASH_REMATCH[1]} sgr0=$_ble_term_sgr0
    rex=':sgr0=(('$rex_csi'|[^:])*):'
    [[ :$opts: =~ $rex ]] &&
      sgr0=${BASH_REMATCH[1]}
  fi

  if [[ ! $ret ]]; then
    [[ :$opts: == *:quote-empty:* ]] &&
      ret=$sgrq\'\'$sgr0
    return
  fi

  local chars=$'\a\b\e\f\n\r\t\v'
  if [[ $ret == *["$chars"]* ]]; then
    ble/string#escape-for-bash-escape-string "$ret"
    ret=$sgrq\$\'$ret\'$sgr0
    return
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

## @fn ble/string#create-unicode-progress-bar/.block value
##   @var[out] ret
function ble/string#create-unicode-progress-bar/.block {
  local block=$1
  if ((block<=0)); then
    ble/util/c2w $((0x2588))
    ble/string#repeat ' ' "$ret"
  elif ((block>=8)); then
    ble/util/c2s $((0x2588))
    ((${#ret}==1)) || ret='*' # LC_CTYPE が非対応の文字の時
  else
    ble/util/c2s $((0x2590-block))
    if ((${#ret}!=1)); then
      # LC_CTYPE が非対応の文字の時
      ble/util/c2w $((0x2588))
      ble/string#repeat ' ' $((ret-1))
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
    ble/string#repeat "$ret" $((width-progress_integral))
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
  builtin eval -- "${_ble_local_script//opts/$1}"
}
function ble/path#prepend {
  local _ble_local_script='opts=$2${opts:+:}$opts'
  builtin eval -- "${_ble_local_script//opts/$1}"
}
function ble/path#remove {
  [[ $2 ]] || return 1
  local _ble_local_script='
    opts=:${opts//:/::}:
    opts=${opts//:"$2":}
    opts=${opts//::/:} opts=${opts#:} opts=${opts%:}'
  builtin eval -- "${_ble_local_script//opts/$1}"
}
function ble/path#remove-glob {
  [[ $2 ]] || return 1
  local _ble_local_script='
    opts=:${opts//:/::}:
    opts=${opts//:$2:}
    opts=${opts//::/:} opts=${opts#:} opts=${opts%:}'
  builtin eval -- "${_ble_local_script//opts/$1}"
}
function ble/path#contains {
  builtin eval "[[ :\${$1}: == *:\"\$2\":* ]]"
}

if ((_ble_bash>=40000)); then
  _ble_util_set_declare=(declare -A NAME)
  function ble/set#add { builtin eval -- "$1[x\$2]=1"; }
  function ble/set#remove { builtin unset -v "$1[x\$2]"; }
  function ble/set#contains { builtin eval "[[ \${$1[x\$2]+set} ]]"; }
else
  _ble_util_set_declare=(declare NAME)
  function ble/set#.escape {
    _ble_local_value=${_ble_local_value//$_ble_term_FS/$_ble_term_FS$_ble_term_FS}
    _ble_local_value=${_ble_local_value//:/$_ble_term_FS.}
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

_ble_util_adict_declare=''
## @fn ble/dict#.resolve dict key
function ble/adict#.resolve {
  # _ble_local_key
  _ble_local_key=$2
  _ble_local_key=${_ble_local_key//$_ble_term_FS/$_ble_term_FS$_ble_term_FS}
  _ble_local_key=${_ble_local_key//:/$_ble_term_FS.}

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

if ((_ble_bash>=40000)); then
  _ble_util_dict_declare='declare -A NAME'
  function ble/dict#set   { builtin eval -- "$1[x\$2]=\$3"; }
  function ble/dict#get   { builtin eval -- "ret=\${$1[x\$2]}; [[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#unset { builtin eval -- "builtin unset -v '$1[x\$2]'"; }
  function ble/dict#has   { builtin eval -- "[[ \${$1[x\$2]+set} ]]"; }
  function ble/dict#clear { builtin eval -- "$1=()"; }
else
  _ble_util_dict_declare='declare NAME NAME_keylist'
  function ble/dict#set   { ble/adict#set   "$@"; }
  function ble/dict#get   { ble/adict#get   "$@"; }
  function ble/dict#unset { ble/adict#unset "$@"; }
  function ble/dict#has   { ble/adict#has   "$@"; }
  function ble/dict#clear { ble/adict#clear "$@"; }
fi

if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  if ((_ble_bash>=40200)); then
    _ble_util_gdict_declare='declare -gA NAME=()'
  else
    _ble_util_gdict_declare='declare -A NAME=()'
  fi
  function ble/gdict#set   { ble/dict#set   "$@"; }
  function ble/gdict#get   { ble/dict#get   "$@"; }
  function ble/gdict#unset { ble/dict#unset "$@"; }
  function ble/gdict#has   { ble/dict#has   "$@"; }
  function ble/gdict#clear { ble/dict#clear "$@"; }
else
  _ble_util_gdict_declare=
  function ble/gdict#set   { ble/adict#set   "$@"; }
  function ble/gdict#get   { ble/adict#get   "$@"; }
  function ble/gdict#unset { ble/adict#unset "$@"; }
  function ble/gdict#has   { ble/adict#has   "$@"; }
  function ble/gdict#clear { ble/adict#clear "$@"; }
fi

#------------------------------------------------------------------------------
# blehook

## @fn blehook/.print
##   @var[in] flags
function blehook/.print {
  local out= q=\' Q="'\''" nl=$'\n'

  local sgr{0..3}=
  if [[ $flags == *c* || $flags == *a* && -t 1 ]]; then
    local ret
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; sgr3=$ret
    sgr0=$_ble_term_sgr0
    Q=$q$sgr0"\'"$sgr3$q
  fi

  local elem code='
    if ((${#_ble_hook_h_NAME[@]})); then
      for elem in "${_ble_hook_h_NAME[@]}"; do
        out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0+=${sgr3}$q${elem//$q/$Q}$q$sgr0$nl"
      done
    else
      out="${out}${sgr1}blehook$sgr0 ${sgr2}NAME$sgr0=$nl"
    fi'

  (($#)) || set -- "${!_ble_hook_h_@}"
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
    '' \
    '  Arguments:' \
    '    NAME            Print the corresponding hooks.' \
    '    NAME=COMMAND    Set hook after removing the existing hooks.' \
    '    NAME+=COMMAND   Add hook.' \
    '    NAME-=COMMAND   Remove hook.' \
    '    NAME-+=COMMAND  Add hook if the command is not registered.'
}

function blehook {
  local flags=a
  if (($#==0)); then
    blehook/.print
    return 0
  fi

  local -a print=()
  local -a process=()
  local rex1='^([a-zA-Z_][a-zA-Z_0-9]*)$'
  local rex2='^([a-zA-Z_][a-zA-Z_0-9]*)(:?-?\+?=)(.*)$'
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == -* ]]; then
      case $arg in
      (--help)
        flags=H$flags ;;
      (--color|--color=always) flags=c${flags//[ac]} ;;
      (--color=auto) flags=a${flags//[ac]} ;;
      (--color=never) flags=${flags//[ac]} ;;
      (*)
        ble/util/print "blehook: unrecognized option '$arg'." >&2
        flags=E$flags ;;
      esac
    elif [[ $arg =~ $rex1 ]]; then
      ble/array#push print "_ble_hook_h_$arg"
    elif [[ $arg =~ $rex2 ]]; then
      local name=${BASH_REMATCH[1]}
      if builtin eval "[[ ! \${_ble_hook_c_$name+set} ]]"; then
        if [[ ${BASH_REMATCH[2]} == :* ]]; then
          ((_ble_hook_c_$name=0))
        else
          ble/util/print "blehook: hook \"$name\" is not defined." >&2
          flags=E$flags
        fi
      fi
      ble/array#push process "$arg"
    else
      ble/util/print "blehook: invalid hook spec \"$arg\"" >&2
      flags=E$flags
    fi
  done
  if [[ $flags == *[HE]* ]]; then
    if [[ $flags == *H* ]]; then
      blehook/.print-help
    else
      blehook/.print-help >&2
    fi
    [[ $flags != *E* ]]; return "$?"
  fi

  if ((${#print[@]}||${#process[@]}+${#print[@]}==0)); then
    blehook/.print "${print[@]}"
  fi

  local proc ext=0
  for proc in "${process[@]}"; do
    [[ $proc =~ $rex2 ]]
    local name=${BASH_REMATCH[1]}
    local type=${BASH_REMATCH[2]}
    local value=${BASH_REMATCH[3]}
    if [[ $type == *-* ]]; then
      local ret
      ble/array#last-index "_ble_hook_h_$name" "$value"
      if ((ret>=0)); then
        ble/array#remove-at "_ble_hook_h_$name" "$ret"
      elif [[ ${type#:} == '-=' ]]; then
        ext=1
      fi
    fi
    [[ ${type#:} == '=' ]] && builtin eval "_ble_hook_h_$name=()"
    [[ ${type#:} != '-=' && $value ]] &&
      ble/array#push "_ble_hook_h_$name" "$value"
  done
  return "$ext"
}
blehook/.compatibility-ble-0.3

function blehook/has-hook {
  builtin eval "local count=\${#_ble_hook_h_$1[@]}"
  ((count))
}
function blehook/invoke {
  local lastexit=$? FUNCNEST=
  ((_ble_hook_c_$1++))
  local -a hooks; builtin eval "hooks=(\"\${_ble_hook_h_$1[@]}\")"; shift
  local hook ext=0
  for hook in "${hooks[@]}"; do
    if type "$hook" &>/dev/null; then
      ble/util/setexit "$lastexit"
      "$hook" "$@" 2>&3
    else
      ble/util/setexit "$lastexit"
      builtin eval -- "$hook" 2>&3
    fi || ext=$?
  done
  return "$ext"
} 3>&2 2>/dev/null # set -x 対策 #D0930
function blehook/eval-after-load {
  local hook_name=${1}_load value=$2
  if ((_ble_hook_c_$hook_name)); then
    builtin eval -- "$value"
  else
    blehook "$hook_name+=$value"
  fi
}

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

  if [[ $flags != *[hlpE]* ]]; then
    if [[ $flags != *c* ]]; then
      flags=p$flags
    elif ((${#sigspecs[@]}==0)); then
      sigspecs=("$command")
      command=-
    fi
  fi
}
_ble_builtin_trap_signames=()
_ble_builtin_trap_reserved=()
_ble_builtin_trap_handlers=()
_ble_builtin_trap_DEBUG=
_ble_builtin_trap_inside=
if ((_ble_bash>=40300||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  builtin unset -v _ble_builtin_trap_n2i
  if ((_ble_bash>=40300)); then
    declare -gA _ble_builtin_trap_n2i=()
  else
    declare -A _ble_builtin_trap_n2i=()
  fi
  function ble/builtin/trap/.register {
    local index=$1 name=$2
    _ble_builtin_trap_signames[index]=$name
    _ble_builtin_trap_n2i[$name]=$index
  }
  function ble/builtin/trap/.get-sig-index {
    if [[ $1 && ! ${1//[0-9]} ]]; then
      ret=$1
      return 0
    else
      ret=${_ble_builtin_trap_n2i[$1]}
      [[ $ret ]] && return 0

      ble/string#toupper "$1"; local upper=$ret
      ret=${_ble_builtin_trap_n2i[$upper]}
      if [[ ! $ret ]]; then
        ret=${_ble_builtin_trap_n2i[SIG$upper]}
        [[ $ret ]] || return 1
      fi
      _ble_builtin_trap_n2i[$1]=$ret
      return 0
    fi
  }
else
  function ble/builtin/trap/.register {
    local index=$1 name=$2
    _ble_builtin_trap_signames[index]=$name
  }
  function ble/builtin/trap/.get-sig-index {
    if [[ $1 && ! ${1//[0-9]} ]]; then
      ret=$1
      return 0
    else
      ble/string#toupper "$1"; local spec=$ret
      for ret in "${!_ble_builtin_trap_signames[@]}"; do
        local name=${_ble_builtin_trap_signames[ret]}
        [[ $spec == $name || SIG$spec == $name ]] && return 0
      done
      ret=
      return 1
    fi
  }
fi
function ble/builtin/trap/.initialize {
  function ble/builtin/trap/.initialize { :; }
  local ret i
  ble/util/assign ret 'builtin trap -l' 2>/dev/null
  ble/string#split-words ret "$ret"
  for ((i=0;i<${#ret[@]};i+=2)); do
    local index=${ret[i]%')'}
    local name=${ret[i+1]}
    ble/builtin/trap/.register "$index" "$name"
  done
  ble/builtin/trap/.register 0 EXIT
  ble/builtin/trap/.register 1000 DEBUG
  ble/builtin/trap/.register 1001 RETURN
  ble/builtin/trap/.register 1002 ERR

  _ble_builtin_trap_DEBUG=1000
}
function ble/builtin/trap/reserve {
  local ret
  ble/builtin/trap/.initialize
  ble/builtin/trap/.get-sig-index "$1" || return 1
  _ble_builtin_trap_reserved[ret]=1
}
function ble/builtin/trap/invoke {
  local lastexit=$? ret
  ble/builtin/trap/.initialize
  ble/builtin/trap/.get-sig-index "$1" || return 1
  ble/util/setexit "$lastexit"
  builtin eval -- "${_ble_builtin_trap_handlers[ret]}" 2>&3
} 3>&2 2>/dev/null # set -x 対策 #D0930
function ble/builtin/trap {
  local flags command sigspecs
  ble/builtin/trap/.read-arguments "$@"

  if [[ $flags == *h* ]]; then
    builtin trap --help
    return 2
  elif [[ $flags == *E* ]]; then
    return 2
  elif [[ $flags == *l* ]]; then
    builtin trap -l
  fi

  if [[ $flags == *p* ]]; then
    ble/builtin/trap/.initialize

    local -a indices=()
    if ((${#sigspecs[@]})); then
      local spec ret
      for spec in "${sigspecs[@]}"; do
        if ! ble/builtin/trap/.get-sig-index "$spec"; then
          ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
          continue
        fi
        ble/array#push indices "$ret"
      done
    else
      indices=("${!_ble_builtin_trap_handlers[@]}")
    fi

    local q=\' Q="'\''" index
    for index in "${indices[@]}"; do
      if [[ ${_ble_builtin_trap_handlers[index]+set} ]]; then
        local h=${_ble_builtin_trap_handlers[index]}
        local n=${_ble_builtin_trap_signames[index]}
        ble/util/print "trap -- '${h//$Q/$q}' $n"
      fi
    done
  else
    local _ble_builtin_trap_inside=1
    local spec ret
    for spec in "${sigspecs[@]}"; do
      if ! ble/builtin/trap/.get-sig-index "$spec"; then
        ble/util/print "ble/builtin/trap: invalid signal specification \"$spec\"." >&2
        continue
      fi

      if [[ $command == - ]]; then
        builtin unset -v "_ble_builtin_trap_handlers[ret]"
      else
        _ble_builtin_trap_handlers[ret]=$command
      fi

      if [[ ${_ble_builtin_trap_reserved[ret]} ]]; then
        ble/function#try ble/builtin/trap:"${_ble_builtin_trap_signames[ret]}" "$command" "$spec"
      else
        builtin trap -- "$command" "$spec"
      fi
    done
  fi
  return 0
}
function trap { ble/builtin/trap "$@"; }

function ble/builtin/trap/.invoke {
  local _ble_trap_count
  for ((_ble_trap_count=0;_ble_trap_count<1;_ble_trap_count++)); do
    ble/util/setexit "$_ble_trap_ext"
    builtin eval -- "$_ble_trap_handler"
    _ble_trap_done=done
    return "$_ble_trap_ext"
  done

  # break/continue 検出
  if ((_ble_trap_count==0)); then
    _ble_trap_done=break
  else
    _ble_trap_done=continue
  fi
  return "$_ble_trap_ext"
}
function ble/builtin/trap/.handler {
  local _ble_trap_ext=$? _ble_trap_sig=$1 _ble_trap_name=$2

  # ble.sh hook
  ble/util/joblist.check
  ble/util/setexit "$_ble_trap_ext"
  blehook/invoke "$_ble_trap_name"
  ble/util/joblist.check ignore-volatile-jobs

  # user hook
  local _ble_trap_handler=${_ble_builtin_trap_handlers[_ble_trap_sig]}
  local _ble_trap_done=
  ble/builtin/trap/.invoke
  _ble_trap_ext=$?
  case $_ble_trap_done in
  (break)
    _ble_builtin_trap_hook=break ;;
  (continue)
    _ble_builtin_trap_hook=continue ;;
  (done)
    _ble_builtin_trap_hook="ble/util/setexit $_ble_trap_ext" ;;
  (*)
    _ble_builtin_trap_hook="return $_ble_trap_ext" ;;
  esac
}

function ble/builtin/trap/install-hook {
  local ret opts=:$2:
  ble/builtin/trap/.initialize
  ble/builtin/trap/.get-sig-index "$1"
  local sig=$ret name=${_ble_builtin_trap_signames[ret]}
  ble/builtin/trap/reserve "$sig"

  local handler="ble/builtin/trap/.handler $sig ${name#SIG}; builtin eval -- \"\$_ble_builtin_trap_hook\""
  local trap_command="trap -- '$handler' $name"
  if [[ $opts == *:readline:* ]] && ! ble/util/is-running-in-subshell; then
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
    ble/util/assign trap "builtin trap -p $name"
    [[ $trap_command == "$trap" ]] && return 0
  fi

  builtin eval "builtin $trap_command"
}

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
if ((_ble_bash>=40000)); then
  function ble/util/readfile { # 155ms for man bash
    local __buffer
    mapfile __buffer < "$2"
    IFS= builtin eval "$1=\"\${__buffer[*]-}\""
  }
  function ble/util/mapfile {
    mapfile -t "$1"
  }
else
  function ble/util/readfile { # 465ms for man bash
    TMOUT= IFS= builtin read -r -d '' "$1" < "$2"
  }
  function ble/util/mapfile {
    local IFS= TMOUT=
    local _ble_local_i=0 _ble_local_val _ble_local_arr; _ble_local_arr=()
    while builtin read -r _ble_local_val || [[ $_ble_local_val ]]; do
      _ble_local_arr[_ble_local_i++]=$_ble_local_val
    done
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
  }
fi

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
      if local rex='^[a-zA-Z_][a-zA-Z_0-9]*$'; ! [[ $arg =~ $rex ]]; then
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
function ble/util/writearray {
  local _ble_local_array
  local -x _ble_local_nlfix _ble_local_delim
  ble/util/writearray/.read-arguments "$@" || return 2

  local rex_dq='^"([^\\"]|\\.)*"'
  local rex_es='^\$'\''([^\\'\'']|\\.)*'\'''
  local rex_sq='^'\''([^'\'']|'\'\\\\\'\'')*'\'''
  local rex_normal='^[^[:space:]$`"'\''()|&;<>\\]' # Note: []{}?*#!~^, @(), +() は quote されていなくても OK とする
  declare -p "$_ble_local_array" | ble/bin/awk -v _ble_bash="$_ble_bash" '
    BEGIN {
      DELIM = ENVIRON["_ble_local_delim"];
      FLAG_NLFIX = ENVIRON["_ble_local_nlfix"];
      if (FLAG_NLFIX) DELIM = "\n";

      IS_GAWK = AWKTYPE == "gawk";
      IS_XPG4 = AWKTYPE == "xpg4";
      REP_SL = "\\";
      if (IS_XPG4) REP_SL = "\\\\";

      es_control_chars["a"] = "\a";
      es_control_chars["b"] = "\b";
      es_control_chars["t"] = "\t";
      es_control_chars["n"] = "\n";
      es_control_chars["v"] = "\v";
      es_control_chars["f"] = "\f";
      es_control_chars["r"] = "\r";
      es_control_chars["e"] = "\033";

      for (i = 0; i < 16; i++)
        xdigit2int[sprintf("%x", i)] = i;
      for (i = 10; i < 16; i++)
        xdigit2int[sprintf("%X", i)] = i;

      c2s_initialize();

      decl = "";
    }

    function str2rep(str) {
      if (IS_XPG4) sub(/\\/, "\\\\\\\\", str);
      return str;
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
    function c2s_initialize(_, i) {
      if (sprintf("%c", 945) == "α") {
        C2S_UNICODE_PRINTF_C = 1;
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

    function unquote_dq(s, _, head) {
      head = "";
      while (match(s, /^([^\\]|\\[^$`"\\])*\\[$`"\\]/)) {
        head = head substr(s, 1, RLENGTH - 2) substr(s, RLENGTH, 1);
        s = substr(s, RLENGTH + 1);
      }
      return head s;
    }
    function unquote_sq(s) {
      gsub(/'\'\\\\\'\''/, "'\''", s);
      return s;
    }
    function unquote_es(s, _, head, c) {
      head = "";
      while (match(s, /^[^\\]*\\/)) {
        head = head substr(s, 1, RLENGTH - 1);
        s = substr(s, RLENGTH + 1);
        if ((c = es_control_chars[substr(s, 1, 1)])) {
          head = head c;
          s = substr(s, 2);
        } else if (match(s, /^[0-9]([0-9][0-9]?)?/)) {
          head = head c2s(s2i(substr(s, 1, RLENGTH), 8) % 256);
          s = substr(s, RLENGTH + 1);
        } else if (match(s, /^x[0-9a-fA-F][0-9a-fA-F]?/)) {
          head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
          s = substr(s, RLENGTH + 1);
        } else if (match(s, /^U[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
          # \\U[0-9]{5,8}
          head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
          s = substr(s, RLENGTH + 1);
        } else if (match(s, /^[uU][0-9a-fA-F]([0-9a-fA-F]([0-9a-fA-F][0-9a-fA-F]?)?)?/)) {
          # \\[uU][0-9]{1,4}
          head = head c2s(s2i(substr(s, 2, RLENGTH - 1), 16));
          s = substr(s, RLENGTH + 1);
        } else {
          head = head "\\";
        }
      }
      return head s;
    }
    function unquote(s, _, c) {
      c = substr(s, 1, 1);
      if (c == "\"")
        return unquote_dq(substr(s, 2, length(s) - 2));
      else if (c == "$")
        return unquote_es(substr(s, 3, length(s) - 3));
      else if (c == "'\''")
        return unquote_sq(substr(s, 2, length(s) - 2));
      else if (c == "\\")
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
#%  # 任意の場合は多少遅くなるがこちらの関数で処理する。
    function analyze_elements_general(decl, _, arr, i, n, nlfix_indices) {
      n = split(decl, arr, / /);
      nlfix_indices = "";
      for (i = 1; i <= n; i++) {
        elem = arr[i];
        sub(/^\[[0-9]+\]=/, "", elem);
        line = "";
        while (1) {
          if (match(elem, /'"$rex_dq"'|'"$rex_es"'|'"$rex_sq"'|'"$rex_normal"'|^\\./)) {
            mlen = RLENGTH;
            line = line unquote(substr(elem, 1, mlen));
            elem = substr(elem, mlen + 1);
          } else if (elem ~ /^[$"'\''\\]/ && i + 1 <= n) {
            elem = elem " " arr[++i];
          } else {
            break;
          }
        }

        if (FLAG_NLFIX) {
          if (line ~ /\n/) {
            gsub(/\\/, REP_SL REP_SL, line);
            gsub(/'\''/, REP_SL "'\''", line);
            gsub(/\a/, REP_SL "a", line);
            gsub(/\b/, REP_SL "b", line);
            gsub(/\t/, REP_SL "t", line);
            gsub(/\n/, REP_SL "n", line);
            gsub(/\v/, REP_SL "v", line);
            gsub(/\f/, REP_SL "f", line);
            gsub(/\r/, REP_SL "r", line);
            printf("$'\''%s'\''\n", line);
            nlfix_indices = nlfix_indices != "" ? nlfix_indices " " (i - 1) : (i - 1);
          } else {
            printf("%s\n", line);
          }
        } else if (DELIM != "") {
          printf("%s", line DELIM);
        } else {
          printf("%s%c", line, 0);
        }
      }
      if (FLAG_NLFIX)
        printf("%s\n", nlfix_indices);
      return 1;
    }

    function process_declaration(decl, _, mlen, line) {
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
      if (_ble_bash < 40000) {
        gsub(/\001\001\001\001/, "\001", decl);
        gsub(/\001\001\001\177/, "\177", decl);
      } else if (_ble_bash < 40400) {
        gsub(/\001\001/, "\001", decl);
        gsub(/\001\177/, "\177", decl);
      }

      sub(/^([_a-zA-Z][_a-zA-Z0-9]*)=\([[:space:]]*/, "", decl);
      sub(/[[:space:]]*\)[[:space:]]*$/, "", decl);

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
      local IFS= ARRI=0 ARR
      while builtin read -r -d "" "ARR[ARRI++]"; do :; done'
  fi

  if [[ $_ble_local_nlfix ]]; then
    _ble_local_script=$_ble_local_script'
      local ARRN=${#ARR[@]}
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
##   var=$(command) の高速な代替です。
##   command はサブシェルではなく現在のシェルで実行されます。
##
##   @param[in] var
##     代入先の変数名を指定します。
##   @param[in] command...
##     実行するコマンドを指定します。
##
_ble_util_assign_base=$_ble_base_run/$$.ble_util_assign.tmp
_ble_util_assign_level=0
if ((_ble_bash>=40000)); then
  # mapfile の方が read より高速
  function ble/util/assign {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$? _ble_local_arr=
    ((_ble_util_assign_level--))
    mapfile -t _ble_local_arr < "$_ble_local_tmp"
    IFS=$'\n' builtin eval "$1=\"\${_ble_local_arr[*]}\""
    return "$_ble_local_ret"
  }
else
  function ble/util/assign {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$?
    ((_ble_util_assign_level--))
    TMOUT= IFS= builtin read -r -d '' "$1" < "$_ble_local_tmp"
    builtin eval "$1=\${$1%$'\n'}"
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
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$?
    ((_ble_util_assign_level--))
    mapfile -t "$1" < "$_ble_local_tmp"
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$?
    ((_ble_util_assign_level--))
    ble/util/mapfile "$1" < "$_ble_local_tmp"
    return "$_ble_local_ret"
  }
fi

if ! ((_ble_bash>=40400)); then
  function ble/util/assign-array0 {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$?
    ((_ble_util_assign_level--))
    mapfile -d '' -t "$1" < "$_ble_local_tmp"
    return "$_ble_local_ret"
  }
else
  function ble/util/assign-array0 {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval -- "$2" >| "$_ble_local_tmp"
    local _ble_local_ret=$?
    ((_ble_util_assign_level--))
    local IFS= i=0 _ble_local_arr
    while builtin read -r -d '' "_ble_local_arr[i++]"; do :; done < "$_ble_local_tmp"
    [[ ${_ble_local_arr[--i]} ]] || builtin unset -v "_ble_local_arr[i]"
    ble/util/unlocal i IFS
    builtin eval "$1=(\"\${_ble_local_arr[@]}\")"
    return "$_ble_local_ret"
  }
fi

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
##     proc の中から参照できる変数です。
##     関数の呼び出しに使うコマンドを提供します。
##     例えば元の関数呼び出しが function arg1 arg2 だった場合、
##     ADVICE_WORDS=(function arg1 arg2) が設定されます。
##     before/around に於いて本来の関数の呼び出し前にこの配列を書き換える事で
##     呼び出す関数または関数の引数を変更する事ができます。
##
##   @var[in.out] ADVICE_EXIT
##     proc の中から参照できる変数です。
##     after/around に於いて関数実行後の戻り値を参照または
##     変更するのに使います。
##
function ble/function#advice/do {
  ble/function#advice/original:"${ADVICE_WORDS[@]}"
  ADVICE_EXIT=$?
}
function ble/function#advice/.proc {
  local ADVICE_WORDS ADVICE_EXIT=127
  ADVICE_WORDS=("$@")
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
          builtin eval -- "${def#*:}"
        fi
      fi
    fi
    builtin unset -f ble/function#advice/{before,after,around,original}:"$name" 2>/dev/null
    return 0 ;;
  (before|after|around)
    if [[ $def != *'ble/function#advice/.proc'* ]]; then
      builtin eval "ble/function#advice/original:$def"
      builtin eval "function $name { ble/function#advice/.proc \"\${FUNCNAME#*:}\" \"\$@\"; }"
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
      ((index++))
    done

    local def; ble/function#getdef "$name"
    builtin eval "ble/function#push/$index:$def"
  fi

  if [[ $proc ]]; then
    local q=\' Q="'\''"
    builtin eval "function $name { builtin eval -- '${proc//$q/$Q}'; }"
  fi
  return 0
}
function ble/function#pop {
  local name=$1 proc=$2
  if ! ble/is-function "$name"; then
    ble/util/print "ble/function#push: $name is not a function." >&2
    return 1
  fi

  local index=-1
  while ble/is-function "ble/function#push/$((index+1)):$name"; do
    ((index++))
  done

  if ((index<0)); then
    builtin unset -f "$name"
  else
    local def; ble/function#getdef "ble/function#push/$index:$name"
    builtin eval -- "${def#*:}"
    builtin unset -f "ble/function#push/$index:$name"
  fi
  return 0
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
  ((index)) || return 0
  "ble/function#push/$((index-1)):$func" "$@"
}

[[ $_ble_util_lambda_count ]] || _ble_util_lambda_count=0
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
    builtin eval "ble/function#suppress-stderr:$def"
  fi

  builtin eval "function $name { $lambda \"\$@\" 2>/dev/null; }"
  return 0
}

#
# miscallaneous utils
#

if ((_ble_bash>=40100)); then
  function ble/util/set {
    builtin printf -v "$1" %s "$2"
  }
else
  function ble/util/set {
    builtin eval "$1=\"\$2\""
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
  [[ $_ble_attached && $_ble_bash_expand_aliases ]] && shopt -s expand_aliases
  ble/util/assign-array "$1" 'builtin type -a -t -- "$3" 2>/dev/null' "$2"; local ext=$?
  [[ $_ble_attached && $_ble_bash_expand_aliases ]] && shopt -u expand_aliases
  return "$ext"
}
## @fn ble/util/expand-alias word
##   @var[out] ret
function ble/util/expand-alias {
  ret=$1
  local type; ble/util/type type "$ret"
  if [[ $type == alias ]]; then
    local data; ble/util/assign data 'LC_ALL=C alias "$ret"' &>/dev/null
    [[ $data == 'alias '*=* ]] && builtin eval "ret=${data#alias *=}"
  fi
}

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
    ((BASH_SUBSHELL)) && return 0
    local BASHPID; ble/util/getpid
    [[ $$ != $BASHPID ]]
  }
fi

## @fn ble/fd#is-open fd
##   指定したファイルディスクリプタが開いているかどうか判定します。
function ble/fd#is-open { : >&"$1"; } 2>/dev/null

_ble_util_openat_nextfd=
function ble/fd#alloc/.nextfd {
  [[ $_ble_util_openat_nextfd ]] ||
    _ble_util_openat_nextfd=$bleopt_openat_base
  # Note: Bash 3.1 では exec fd>&- で明示的に閉じても駄目。
  #   開いた後に読み取りプロセスで読み取りに失敗する。
  #   なので開いていない fd を探す必要がある。#D0992
  # Note: 指定された fd が開いているかどうかを
  #   可搬に高速に判定する方法を見つけたので
  #   常に開いていない fd を探索する。#D1318
  while ble/fd#is-open "$_ble_util_openat_nextfd"; do
    ((_ble_util_openat_nextfd++))
  done
  (($1=_ble_util_openat_nextfd++))
}

## @fn ble/fd#alloc fdvar redirect [opts]
##   "exec {fdvar}>foo" に該当する操作を実行します。
##   @param[out] fdvar
##     指定した変数に使用されたファイルディスクリプタを代入します。
##   @param[in] redirect
##     リダイレクトを指定します。
##   @param[in,opt] opts
##     inherit
##       既に fdvar が存在して有効な fd であれば何もしません。新しく fd を確保
##       した場合には終了処理を登録せず、また fdvar を export します。
##     share
##       >&NUMBER の形式のリダイレクトの場合に fd を複製する代わりに単に NUMBER
##       を fdvar に代入します。
_ble_util_openat_fdlist=()
function ble/fd#alloc {
  if [[ :$3: == *:inherit:* ]]; then
    [[ ${!1} ]] &&
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

  if ((_ble_bash>=40100)) && [[ :$3: != *:base:* ]]; then
    builtin eval "exec {$1}$2"
  else
    ble/fd#alloc/.nextfd "$1"
    # Note: Bash 3.2/3.1 のバグを避けるため、
    #   >&- を用いて一旦明示的に閉じる必要がある #D0857
    builtin eval "exec ${!1}>&- ${!1}$2"
  fi; local _ble_local_ext=$?

  if [[ :$3: == *:inherit:* ]]; then
    export "$1"
  else
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
  set -- $(($1))
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
if [[ -t 0 ]]; then
  ble/fd#alloc _ble_util_fd_stdin '<&0' base:inherit
else
  ble/fd#alloc _ble_util_fd_stdin '< /dev/tty' base:inherit
fi
if [[ -t 1 ]]; then
  ble/fd#alloc _ble_util_fd_stdout '>&1' base:inherit
else
  ble/fd#alloc _ble_util_fd_stdout '> /dev/tty' base:inherit
fi
if [[ -t 2 ]]; then
  ble/fd#alloc _ble_util_fd_stderr '>&2' base:inherit
else
  ble/fd#alloc _ble_util_fd_stderr ">&$_ble_util_fd_stdout" base:inherit:share
fi
ble/fd#alloc _ble_util_fd_null '<> /dev/null' base:inherit
[[ -c /dev/zero ]] &&
  ble/fd#alloc _ble_util_fd_zero '< /dev/zero' base:inherit

function ble/util/print-quoted-command {
  local ret; ble/string#quote-command "$@"
  ble/util/print "$ret"
}
function ble/util/declare-print-definitions {
  if [[ $# -gt 0 ]]; then
    declare -p "$@" | ble/bin/awk -v _ble_bash="$_ble_bash" -v OSTYPE="$OSTYPE" '
      BEGIN {
        decl = "";

#%      # 対策 #D1270: MSYS2 で ^M を代入すると消える
        flag_escape_cr = OSTYPE == "msys";
      }
      function declflush(_, isArray) {
        if (decl) {
          isArray = (decl ~ /^declare +-[ilucnrtxfFgGI]*[aA]/);

#%        # declare 除去
          sub(/^declare +(-[-aAilucnrtxfFgGI]+ +)?(-- +)?/, "", decl);
          if (isArray) {
            if (decl ~ /^([_a-zA-Z][_a-zA-Z0-9]*)='\''\(.*\)'\''$/) {
              sub(/='\''\(/, "=(", decl);
              sub(/\)'\''$/, ")", decl);
              gsub(/'\'\\\\\'\''/, "'\''", decl);

#%            # Note: bash-3.* の配列表記では ^A, ^? が二重にエスケープされて
#%            #   ^A^A^A^A, ^A^A^A^? になってしまう。一つ目のエスケープをここで
#%            # 外しておく。
              if (_ble_bash < 40000) {
                gsub(/\001\001/, "\001", decl);
                gsub(/\001\177/, "\177", decl);
              }
            }
          }

#%        # bash-3.0 の declare -p は改行について誤った出力をする。
          if (_ble_bash < 30100) gsub(/\\\n/, "\n", decl);

#%        # #D1238 bash-4.3 以前の declare -p は ^A, ^? を
#%        #   ^A^A, ^A^? と出力してしまうので補正する。
#%        # #D1325 更に Bash-3.0 では "x${_ble_term_DEL}y" とすると
#%        #   _ble_term_DEL の中身が消えてしまうので
#%        #   "x""${_ble_term_DEL}""y" とする必要がある。
          if (_ble_bash < 30100) {
            gsub(/\001\001/, "\"\"${_ble_term_SOH}\"\"", decl);
            gsub(/\001\177/, "\"\"${_ble_term_DEL}\"\"", decl);
          } else if (_ble_bash < 40400) {
            gsub(/\001\001/, "${_ble_term_SOH}", decl);
            gsub(/\001\177/, "${_ble_term_DEL}", decl);
          }
          if (flag_escape_cr)
            gsub(/\015/, "${_ble_term_CR}", decl);

          print decl;
          decl = "";
        }
      }
      /^declare / {
        declflush();
        decl = $0;
        next;
      }
      { decl = decl "\n" $0; }
      END { declflush(); }
    '
  fi
}

## @fn ble/util/print-global-definitions/.save-decl name
##   @var[out] __ble_decl
function ble/util/print-global-definitions/.save-decl {
  local __ble_name=$1
  if [[ ! ${!__ble_name+set} ]]; then
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
    __ble_decl="declare $__ble_name='${__ble_decl//$__ble_q//$__ble_Q}'"
  fi
}
## @fn ble/util/print-global-definitions varnames...
##
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
function ble/util/print-global-definitions {
  local __ble_hidden_only=
  [[ $1 == --hidden-only ]] && { __ble_hidden_only=1; shift; }
  (
    ((_ble_bash>=50000)) && shopt -u localvar_unset
    __ble_error=
    __ble_q="'" __ble_Q="'\''"
    # 補完で 20 階層も関数呼び出しが重なることはなかろう
    __ble_MaxLoop=20

    for __ble_name; do
      [[ ${__ble_name//[0-9a-zA-Z_]} || $__ble_name == __ble_* ]] && continue
      ((__ble_processed_$__ble_name)) && continue
      ((__ble_processed_$__ble_name=1))
      [[ $__ble_name == __ble_* ]] && continue

      __ble_decl=
      if ((_ble_bash>=40200)); then
        declare -g -r "$__ble_name"
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ! builtin unset -v "$__ble_name"; then
            ble/variable#is-global "$__ble_name" &&
              ble/util/print-global-definitions/.save-decl "$__ble_name"
            break
          fi
        done
      else
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          if ble/variable#is-global "$__ble_name"; then
            ble/util/print-global-definitions/.save-decl "$__ble_name"
            break
          fi
          builtin unset -v "$__ble_name" || break
        done
      fi

      [[ $__ble_decl ]] ||
        __ble_error=1 __ble_decl="declare $__ble_name; builtin unset -v $__ble_name" # not found
      [[ $__ble_hidden_only && $__ble_i == 0 ]] && continue
      ble/util/print "$__ble_decl"
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

  # Note: eval で囲んでおかないと failglob 失敗時に続きが実行されない
  # Note: failglob で失敗した時のエラーメッセージは殺す
  builtin eval "ret=($1)" 2>/dev/null
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
  ((10#${1##*.}&&sec++)) # 小数部分は切り上げ
  ble/bin/sleep "$sec"
}
function ble/util/msleep {
  local v=$((1000*$1-_ble_util_msleep_delay))
  ((v<=0)) && v=0
  ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
  ble/util/msleep/.core "$v"
}

_ble_util_msleep_calibrate_count=0
function ble/util/msleep/.calibrate-loop {
  local _ble_measure_threshold=10000
  local ret nsec _ble_measure_count=1 v=0
  _ble_util_msleep_delay=0 ble-measure 'ble/util/msleep 1'
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
  local msleep_type=$1
  _ble_util_msleep_fd=
  case $msleep_type in
  (socket)
    _ble_util_msleep_delay1=10000 # short msleep にかかる時間 [usec]
    _ble_util_msleep_delay2=50000 # /bin/sleep 0 にかかる時間 [usec]
    function ble/util/msleep/.core2 {
      ((v-=_ble_util_msleep_delay2))
      ble/bin/sleep $((v/1000000))
      ((v%=1000000))
    }
    function ble/util/msleep {
      local v=$((1000*$1-_ble_util_msleep_delay1))
      ((v<=0)) && v=100
      ((v>1000000+_ble_util_msleep_delay2)) &&
        ble/util/msleep/.core2
      ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
      ! builtin read -t "$v" v < /dev/udp/0.0.0.0/80
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
      ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
      ! builtin read -t "$v" -u "$_ble_util_msleep_fd" v
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
        _ble_util_msleep_tmp=$_ble_base_run/$$.ble_util_msleep.pipe
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
        _ble_util_msleep_read='! builtin read -t "$v" -u "$_ble_util_msleep_fd" v'
      elif [[ $open == exec ]]; then
        ble/fd#alloc _ble_util_msleep_fd "$redir \"\$_ble_util_msleep_tmp\""
        _ble_util_msleep_read='! builtin read -t "$v" -u "$_ble_util_msleep_fd" v'
      else
        _ble_util_msleep_read='! builtin read -t "$v" v '$redir' "$_ble_util_msleep_tmp"'
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
            ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
            builtin eval -- "$_ble_util_msleep_read"
          else
            local v=$((1000*$1-_ble_util_msleep_delay2))
            ((v<=0)) && v=100
            ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
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
          ble/util/sprintf v '%d.%06d' $((v/1000000)) $((v%1000000))
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
    if builtin read -t 0.000001 -u "$_ble_util_msleep_fd" _ble_util_msleep_dummy 2>/dev/null; (($?<=128)); then
      ble/fd#close _ble_util_msleep_fd
      _ble_util_msleep_fd=
      return 1
    fi
  fi
  return 0
}

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
      b1=$((10#${b1::14}))
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
        ((exp=10#${exp:2}))
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
      return 2
    elif [[ $flags == *[vh]* ]]; then
      return 0
    else
      b=00000000000000$b
      b=${b:${#b}-14}
      builtin sleep "$a.$b"
    fi
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
elif ble/bin/.freeze-utility-path sleepenh; then
  function ble/util/msleep/.core { ble/bin/sleepenh "$1" &>/dev/null; }
elif ble/bin/.freeze-utility-path usleep; then
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
    ((msec+=10#${frac::3}))
  fi
  ble/util/msleep "$msec"
}

#------------------------------------------------------------------------------
# ble/util/conditional-sync

## @fn ble/util/conditional-sync command [condition weight opts]
##   @param[in] command
##   @param[in,opt] condition
##   @param[in,opt] weight
##   @param[in,opt] opts
##     progressive-weight
##
function ble/util/conditional-sync {
  local __command=$1
  local __continue=${2:-'! ble/decode/has-input'}
  local __weight=$3; ((__weight<=0&&(__weight=100)))
  local __opts=$4

  local __timeout= __rex=':timeout=([^:]+):'
  [[ :$__opts: =~ $__rex ]] && ((__timeout=BASH_REMATCH[1]))

  [[ :$__opts: == *:progressive-weight:* ]] &&
    local __weight_max=$__weight __weight=1

  [[ $__timeout ]] && ((__timeout<=0)) && return 142
  builtin eval -- "$__continue" || return 148
  (
    builtin eval -- "$__command" & local __pid=$!
    while
      # check timeout
      if [[ $__timeout ]]; then
        if ((__timeout<=0)); then
          builtin kill "$__pid" &>/dev/null
          return 142
        fi
        ((__weight>__timeout)) && __weight=$__timeout
        ((__timeout-=__weight))
      fi

      ble/util/msleep "$__weight"
      [[ :$__opts: == *:progressive-weight:* ]] &&
        ((__weight<<=1,__weight>__weight_max&&(__weight=__weight_max)))
      builtin kill -0 "$__pid" &>/dev/null
    do
      if ! builtin eval -- "$__continue"; then
        builtin kill "$__pid" &>/dev/null
        return 148
      fi
    done
    wait "$__pid"
  )
}

#------------------------------------------------------------------------------

## @fn ble/util/cat [files..]
##   cat の代替。直接扱えない NUL で区切って読み出す。
function ble/util/cat/.impl {
  local content= TMOUT= IFS=
  while builtin read -r -d '' content; do
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

## @fn ble/util/getmtime filename
##   ファイル filename の mtime を取得し標準出力に出力します。
##   ミリ秒も取得できる場合には第二フィールドとしてミリ秒を出力します。
##   @param[in] filename ファイル名を指定します。
##
if ble/bin/date -r / +%s &>/dev/null; then
  function ble/util/getmtime { ble/bin/date -r "$1" +'%s %N' 2>/dev/null; }
elif ble/bin/.freeze-utility-path stat; then
  # 参考: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
  if ble/bin/stat -c %Y / &>/dev/null; then
    function ble/util/getmtime { ble/bin/stat -c %Y "$1" 2>/dev/null; }
  elif ble/bin/stat -f %m / &>/dev/null; then
    function ble/util/getmtime { ble/bin/stat -f %m "$1" 2>/dev/null; }
  fi
fi
# fallback: print current time
ble/is-function ble/util/getmtime ||
  function ble/util/getmtime { ble/util/strftime '%s %N'; }

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
  IFS= builtin eval 'ble/util/put "${_ble_util_buffer[*]-}"'
  _ble_util_buffer=()
}
function ble/util/buffer.clear {
  _ble_util_buffer=()
}

#------------------------------------------------------------------------------
# class dirty-range, urange

function ble/dirty-range#load {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    ((beg=${_prefix}beg,
      end=${_prefix}end,
      end0=${_prefix}end0))
  fi
}

function ble/dirty-range#clear {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    shift
  fi

  ((${_prefix}beg=-1,
    ${_prefix}end=-1,
    ${_prefix}end0=-1))
}

## @fn ble/dirty-range#update [--prefix=PREFIX] beg end end0
##   @param[out] PREFIX
##   @param[in]  beg    変更開始点。beg<0 は変更がない事を表す
##   @param[in]  end    変更終了点。end<0 は変更が末端までである事を表す
##   @param[in]  end0   変更前の end に対応する位置。
function ble/dirty-range#update {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    shift
    [[ $_prefix ]] && local beg end end0
  fi

  local begB=$1 endB=$2 endB0=$3
  ((begB<0)) && return 1

  local begA endA endA0
  ((begA=${_prefix}beg,endA=${_prefix}end,endA0=${_prefix}end0))

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

  if [[ $_prefix ]]; then
    ((${_prefix}beg=beg,
      ${_prefix}end=end,
      ${_prefix}end0=end0))
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
  case "${!1}" in
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

## @fn ble/util/test-rl-variable name [default_exit]
function ble/util/test-rl-variable {
  local rl_variables; ble/util/assign rl_variables 'builtin bind -v'
  if [[ $rl_variables == *"set $1 on"* ]]; then
    return 0
  elif [[ $rl_variables == *"set $1 off"* ]]; then
    return 1
  elif (($#>=2)); then
    (($2))
    return "$?"
  else
    return 2
  fi
}
## @fn ble/util/read-rl-variable name [default_value]
function ble/util/read-rl-variable {
  ret=$2
  local rl_variables; ble/util/assign rl_variables 'builtin bind -v'
  local rhs=${rl_variables#*$'\n'"set $1 "}
  [[ $rhs != "$rl_variables" ]] && ret=${rhs%%$'\n'*}
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
_ble_util_import_guards=()

## @fn ble/util/import/search/.check-directory name dir
##   @var[out] ret
function ble/util/import/search/.check-directory {
  local name=$1 dir=$2
  if [[ -f $dir/$name ]]; then
    ret=$dir/$name
  elif [[ $name != *.bash && -f $dir/$name.bash ]]; then
    ret=$dir/$name.bash
  elif [[ $name != *.sh && -f $dir/$name.sh ]]; then
    ret=$dir/$name.sh
  else
    return 1
  fi
  return 0
}
function ble/util/import/search {
  ret=$1
  if [[ $ret != /* && $ret != ./* ]]; then
    ble/util/import/search/.check-directory "$ret" "$_ble_base" ||
      ble/util/import/search/.check-directory "$ret" "$_ble_base/local" ||
      ble/util/import/search/.check-directory "$ret" "$_ble_base/share" ||
      return 1
  fi
  [[ -e $ret && ! -d $ret ]]
}
function ble/util/import/is-loaded {
  local ret
  ble/util/import/search "$1" &&
    ble/is-function "ble/util/import/guard:$ret"
}
# called by ble/base/unload (ble.pp)
function ble/util/import/finalize {
  local guard
  for guard in "${_ble_util_import_guards[@]}"; do
    builtin unset -f "$guard"
  done
}
## @fn ble/util/import/.read-arguments args...
##   @var[out] files
##   @var[out] flags
##     d delay
##     h help
##     f force
##     E error
function ble/util/import/.read-arguments {
  flags= files=()
  local -a not_found=()
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
          ([df]) flags=$c$flags ;;
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
  if [[ $flags != *f* ]] && ((${#not_found[@]})); then
    local file
    for file in "${not_found[@]}"; do
      ble/util/print "ble-import: file '$file' not found" >&2
    done
    flags=E$flags
  fi

  return 0
}
function ble/util/import {
  local file ext=0
  for file; do
    local guard=ble/util/import/guard:$file
    ble/is-function "$guard" && return 0
    [[ -e $file ]] || return 1
    source "$file" &&
      builtin eval "function $guard { :; }" &&
      ble/array#push _ble_util_import_guards "$guard" || ext=$?
  done
  return "$ext"
}
function ble-import {
  local files flags
  ble/util/import/.read-arguments "$@"
  if [[ $flags == *[Eh]* ]]; then
    [[ $flags == *E* ]] && ble/util/print
    {
      ble/util/print 'usage: ble-import [-df] SCRIPTFILE...'
      ble/util/print '  Search and source script files that have not yet been loaded.'
    } >&2
    [[ $flags == *E* ]] && return 2
    return 0
  elif ((!${#files[@]})); then
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

## @fn ble/util/clock
##   時間を計測するのに使うことができるミリ秒単位の軽量な時計です。
##   計測の起点は ble.sh のロード時です。
##   @var[out] ret
_ble_util_clock_base=
_ble_util_clock_reso=
_ble_util_clock_type=
function ble/util/clock/.initialize {
  local LC_ALL= LC_NUMERIC=C
  if ((_ble_bash>=50000)) && [[ $EPOCHREALTIME == *.???* ]]; then
    # implementation with EPOCHREALTIME
    _ble_util_clock_base=$((10#${EPOCHREALTIME%.*}))
    _ble_util_clock_reso=1
    _ble_util_clock_type=EPOCHREALTIME
    function ble/util/clock {
      local LC_ALL= LC_NUMERIC=C
      local now=$EPOCHREALTIME
      local integral=$((10#${now%%.*}-_ble_util_clock_base))
      local mantissa=${now#*.}000; mantissa=${mantissa::3}
      ((ret=integral*1000+10#$mantissa))
    }
    ble/function#suppress-stderr ble/util/clock # locale
  elif [[ -r /proc/uptime ]] && {
         local uptime
         ble/util/readfile uptime /proc/uptime
         ble/string#split-words uptime "$uptime"
         [[ $uptime == *.* ]]; }; then
    # implementation with /proc/uptime
    _ble_util_clock_base=$((10#${uptime%.*}))
    _ble_util_clock_reso=10
    _ble_util_clock_type=uptime
    function ble/util/clock {
      local now
      ble/util/readfile now /proc/uptime
      ble/string#split-words now "$now"
      local integral=$((10#${now%%.*}-_ble_util_clock_base))
      local fraction=${now#*.}000; fraction=${fraction::3}
      ((ret=integral*1000+10#$fraction))
    }
  elif ((_ble_bash>=40200)); then
    printf -v _ble_util_clock_base '%(%s)T'
    _ble_util_clock_reso=1000
    _ble_util_clock_type=printf
    function ble/util/clock {
      local now; printf -v now '%(%s)T'
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
  ## @fn[custom] ble/util/idle/IS_IDLE { ble/util/is-stdin-ready; }
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
  ##
  _ble_util_idle_task=()

  _ble_util_idle_SEP='\'

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

    ble/util/idle.clock/.initialize
    ble/util/idle.clock/.restart

    local _idle_start=$_ble_util_idle_sclock
    local _idle_is_first=1
    local _idle_processed=
    while :; do
      local _idle_key
      local _idle_next_time= _idle_next_itime= _idle_running= _idle_waiting=
      for _idle_key in "${!_ble_util_idle_task[@]}"; do
        ble/util/idle/IS_IDLE || { [[ $_idle_processed ]]; return "$?"; }
        local _idle_to_process=
        local _idle_status=${_ble_util_idle_task[_idle_key]%%"$_ble_util_idle_SEP"*}
        case ${_idle_status::1} in
        (R) _idle_to_process=1 ;;
        (I) [[ $_idle_is_first ]] && _idle_to_process=1 ;;
        (S) ble/util/idle/.check-clock "$_idle_status" && _idle_to_process=1 ;;
        (W) ble/util/idle/.check-clock "$_idle_status" && _idle_to_process=1 ;;
        (F) [[ -s ${_idle_status:1} ]] && _idle_to_process=1 ;;
        (E) [[ -e ${_idle_status:1} ]] && _idle_to_process=1 ;;
        (P) ! builtin kill -0 ${_idle_status:1} &>/dev/null && _idle_to_process=1 ;;
        (C) builtin eval -- "${_idle_status:1}" && _idle_to_process=1 ;;
        (*) builtin unset -v '_ble_util_idle_task[_idle_key]'
        esac

        if [[ $_idle_to_process ]]; then
          local _idle_command=${_ble_util_idle_task[_idle_key]#*"$_ble_util_idle_SEP"}
          _idle_processed=1
          ble/util/idle.do/.call-task "$_idle_command"

          # Note: #D1450 _idle_command が 148 を返したとしても idle.do は中断し
          # ない事にした。IS_IDLE と条件が同じとは限らないので。
          #((ext==148)) && return 0
        elif [[ $_idle_status == [FEPC]* ]]; then
          _idle_waiting=1
        fi
      done

      _idle_is_first=
      ble/util/idle.do/.sleep-until-next; local ext=$?
      ((ext==148)) && break

      [[ $_idle_next_itime$_idle_next_time$_idle_running$_idle_waiting ]] || break
    done

    [[ $_idle_processed ]]
  }
  ## @fn ble/util/idle.do/.call-task command
  ##   @var[in,out] _idle_next_time
  ##   @var[in,out] _idle_next_itime
  ##   @var[in,out] _idle_running
  ##   @var[in,out] _idle_waiting
  function ble/util/idle.do/.call-task {
    local _command=$1
    local ble_util_idle_status=
    local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_idle_start))
    builtin eval -- "$_command"; local ext=$?
    if ((ext==148)); then
      _ble_util_idle_task[_idle_key]=R$_ble_util_idle_SEP$_command
    elif [[ $ble_util_idle_status ]]; then
      _ble_util_idle_task[_idle_key]=$ble_util_idle_status$_ble_util_idle_SEP$_command
      if [[ $ble_util_idle_status == [WS]* ]]; then
        local scheduled_time=${ble_util_idle_status:1}
        if [[ $ble_util_idle_status == W* ]]; then
          local next=_idle_next_itime
        else
          local next=_idle_next_time
        fi
        if [[ ! ${!next} ]] || ((scheduled_time<next)); then
          builtin eval "$next=\$scheduled_time"
        fi
      elif [[ $ble_util_idle_status == R ]]; then
        _idle_running=1
      elif [[ $ble_util_idle_status == [FEPC]* ]]; then
        _idle_waiting=1
      fi
    else
      builtin unset -v '_ble_util_idle_task[_idle_key]'
    fi
    return "$ext"
  }
  ## @fn ble/util/idle/.check-clock status
  ##   @var[in,out] _idle_next_itime
  ##   @var[in,out] _idle_next_time
  function ble/util/idle/.check-clock {
    local status=$1
    if [[ $status == W* ]]; then
      local next=_idle_next_itime
      local current_time=$_ble_util_idle_sclock
    elif [[ $status == S* ]]; then
      local ret
      local next=_idle_next_time
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
  ##   @var[in] _idle_next_time
  ##   @var[in] _idle_next_itime
  ##   @var[in] _idle_running
  ##   @var[in] _idle_waiting
  function ble/util/idle.do/.sleep-until-next {
    ble/util/idle/IS_IDLE || return 148
    [[ $_idle_running ]] && return 0
    local isfirst=1
    while
      local sleep_amount=
      if [[ $_idle_next_itime ]]; then
        local clock=$_ble_util_idle_sclock
        local sleep1=$((_idle_next_itime-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      if [[ $_idle_next_time ]]; then
        local ret; ble/util/idle.clock; local clock=$ret
        local sleep1=$((_idle_next_time-clock))
        if [[ ! $sleep_amount ]] || ((sleep1<sleep_amount)); then
          sleep_amount=$sleep1
        fi
      fi
      [[ $isfirst && $_idle_waiting ]] || ((sleep_amount>0))
    do
      # Note: 変数 ble_util_idle_elapsed は
      #   $((bleopt_idle_interval)) の評価時に参照される。
      local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_idle_start))
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
    while [[ ${_ble_util_idle_task[i]} ]]; do ((i++)); done
    _ble_util_idle_task[i]=$entry
  }
  function ble/util/idle.push {
    local status=R nice=0
    while [[ $1 == -* ]]; do
      case $1 in
      (-[SWPFEC]) status=${1:1}$2; shift 2 ;;
      (-[SWPFECIR]*) status=${1:1}; shift ;;
      (-n) nice=$2; shift 2 ;;
      (-n*) nice=${1#-n}; shift ;;
      (*) break ;;
      esac
    done
    ble/util/idle.push/.impl "$nice" "$status$_ble_util_idle_SEP$1"
  }
  function ble/util/idle.push-background {
    ble/util/idle.push -n 10000 "$@"
  }
  function ble/util/is-running-in-idle {
    [[ ${ble_util_idle_status+set} ]]
  }
  function ble/util/idle.sleep {
    [[ ${ble_util_idle_status+set} ]] || return 1
    local ret; ble/util/idle.clock
    ble_util_idle_status=S$((ret+$1))
  }
  function ble/util/idle.isleep {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=W$((_ble_util_idle_sclock+$1))
  }
  function ble/util/idle.wait-user-input {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=I
  }
  function ble/util/idle.wait-process {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=P$1
  }
  function ble/util/idle.wait-file-content {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=F$1
  }
  function ble/util/idle.wait-filename {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=E$1
  }
  function ble/util/idle.wait-condition {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=C$1
  }
  function ble/util/idle.continue {
    [[ ${ble_util_idle_status+set} ]] || return 1
    ble_util_idle_status=R
  }

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
  printf '\eM\e[B' >&$_ble_util_fd_stderr
  _ble_term_ri=$'\e[A'

  # DLの修正
  function ble/canvas/put-dl.draw {
    local value=${1-1} i
    ((value)) || return 1

    # Note: DL が最終行まで消去する時、何も消去されない…。
    DRAW_BUFF[${#DRAW_BUFF[*]}]=$'\e[2K'
    if ((value>1)); then
      local ret
      ble/string#repeat $'\e[B\e[2K' $((value-1)); local a=$ret
      DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret$'\e['$((value-1))'A'
    fi

    DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
  }
}

function ble/term/DA2R.hook {
  blehook DA2R-=ble/term/DA2R.hook
  case $_ble_term_TERM in
  (contra)
    _ble_term_cuu=$'\e[%dk'
    _ble_term_cud=$'\e[%de'
    _ble_term_cuf=$'\e[%da'
    _ble_term_cub=$'\e[%dj'
    _ble_term_cup=$'\e[%l;%cf' ;;
  (cygwin)
    ble/term:cygwin/initialize.hook ;;
  esac
}
function ble/term/.initialize {
  if [[ $_ble_base/lib/init-term.sh -nt $_ble_base_cache/$TERM.term ]]; then
    source "$_ble_base/lib/init-term.sh"
  else
    source "$_ble_base_cache/$TERM.term"
  fi

  ble/string#reserve-prototype "$_ble_term_it"
  blehook DA2R+=ble/term/DA2R.hook
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
  ble/util/put "${_ble_term_visible_bell_show//'%message%'/$sgr$message}" >&2
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
    ble/canvas/put-cup.draw $((y0+1)) $((x0+1))
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put.draw "$_ble_term_rc"
    ble/canvas/put-cud.draw 1
    [[ :$opts: != *:update:* && $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret" # WA #D1495
  else
    ble/canvas/put.draw "$_ble_term_ri_or_cuu1$_ble_term_sgr0"
    ble/canvas/put-hpa.draw $((1+x0))
    ble/canvas/put.draw "$sgr$message$_ble_term_sgr0"
    ble/canvas/put-cud.draw 1
    ble/canvas/put-hpa.draw $((1+_ble_canvas_x))
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
    ble/canvas/put-cup.draw $((y0+1)) $((x0+1))
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
    # ble/canvas/put-hpa.draw $((1+x0))
    # ble/canvas/put.draw "$sgr"
    # ble/canvas/put-spaces.draw "$x"
    # ble/canvas/put.draw "$_ble_term_sgr0"
    # ble/canvas/put-cud.draw 1
    # ble/canvas/put-hpa.draw $((1+_ble_canvas_x)) # 親プロセスの _ble_canvas_x?
  fi
  ble/canvas/flush.draw >&2
}

function ble/term/visible-bell/defface.hook {
  ble/color/defface vbell       reverse
  ble/color/defface vbell_flash reverse,fg=green
  ble/color/defface vbell_erase bg=252
}
blehook color_init_defface+=ble/term/visible-bell/defface.hook

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
  local -a workers=()
  builtin eval 'workers=("$_ble_base_run/$$.visible-bell."*)' &>/dev/null # failglob 対策

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
ble/array#push _ble_term_stty_flags_enter kill undef erase undef intr undef quit undef susp undef
ble/array#push _ble_term_stty_flags_leave kill '' erase '' intr '' quit '' susp ''
function ble/term/stty/.initialize-flags {
  local stty; ble/util/assign stty 'stty -a'
  # lnext, werase は POSIX にはないのでチェックする
  if [[ $stty == *' lnext '* ]]; then
    ble/array#push _ble_term_stty_flags_enter lnext undef
    ble/array#push _ble_term_stty_flags_leave lnext ''
  fi
  if [[ $stty == *' werase '* ]]; then
    ble/array#push _ble_term_stty_flags_enter werase undef
    ble/array#push _ble_term_stty_flags_leave werase ''
  fi
  if [[ $TERM == minix ]]; then
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
}


#---- cursor state ------------------------------------------------------------

bleopt/declare -v term_cursor_external 0

_ble_term_cursor_current=unknown
_ble_term_cursor_internal=0
_ble_term_cursor_hidden_current=unknown
_ble_term_cursor_hidden_internal=reveal

# #D1516 今迄にカーソル変更がなく、且つ既定値に戻そうとしている時は
#   何もしない。xterm.js で DECSCUSR(0) がユーザー既定値でない事への
#   対策。外部コマンドがカーソル形状を復元するという事を前提にしている。
_ble_term_cursor_current=0

function ble/term/cursor-state/.update {
  local state=$(($1))
  [[ $_ble_term_cursor_current == "$state" ]] && return 0

  ble/util/buffer "${_ble_term_Ss//@1/$state}"

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

function ble/term/bracketed-paste-mode/enter {
  ble/util/buffer $'\e[?2004h'
}
function ble/term/bracketed-paste-mode/leave {
  ble/util/buffer $'\e[?2004l'
}
if [[ $TERM == minix ]]; then
  # Minix console は DECSET も使えない
  function ble/term/bracketed-paste-mode/enter { :; }
  function ble/term/bracketed-paste-mode/leave { :; }
fi

#---- DA2 ---------------------------------------------------------------------

_ble_term_TERM=
function ble/term/DA2/initialize-term {
  local rex='^[0-9]*(;[0-9]*)*$'; [[ $_ble_term_DA2R =~ $rex ]] || return
  local da2r; ble/string#split da2r ';' "$_ble_term_DA2R"

  # xterm
  if rex='^xterm(-|$)'; [[ $TERM =~ $rex ]]; then
    local version=${da2r[1]}
    if rex='^1;[0-9]+;0$'; [[ $_ble_term_DA2R =~ $rex ]]; then
      # 2000以上は vte
      ((version==0||95<=version&&version<2000))
    elif rex='^0;[0-9]+;0$'; [[ $_ble_term_DA2R =~ $rex ]]; then
      ((95<=version))
    elif rex='^(2|24|1[89]|41|6[145]);[0-9]+;0$'; [[ $_ble_term_DA2R =~ $rex ]]; then
      ((280<=version))
    elif rex='^32;[0-9]+;0$'; [[ $_ble_term_DA2R =~ $rex ]]; then
      ((354<=version&&version<2000))
    else
      false
    fi && { _ble_term_TERM=xterm:$version; return; }
  fi

  case $_ble_term_DA2R in
  ('1;'*)
    if ((da2r[1]>=2000)); then
      _ble_term_TERM=vte
    fi ;;
  ('99;'*)
    _ble_term_TERM=contra ;;
  ('65;'*)
    if ((da2r[1]>=100)); then
      _ble_term_TERM=RLogin
    fi ;;
  ('67;'*)
    local rex='^67;[0-9]{3,};0$'
    if [[ $TERM == cygwin && $_ble_term_DA2R =~ $rex ]]; then
      _ble_term_TERM=cygwin
    fi ;;
  ('83;'*)
    local rex='^83;[0-9]+;0$'
    [[ $_ble_term_DA2R =~ $rex ]] && _ble_term_TERM=screen ;;
  ('84;0;0')
    _ble_term_TERM=tmux ;;
  esac
  return 0
}

_ble_term_DA1R=
_ble_term_DA2R=
function ble/term/DA1/notify { _ble_term_DA1R=$1; blehook/invoke DA1R; }
function ble/term/DA2/notify {
  # Note #D1485: screen で attach した時に外側の端末の DA2R が混入する
  # 事がある。2回目以降に受信した内容は ble.sh の内部では使用しない事
  # にする。
  if [[ ! $_ble_term_DA2R ]]; then
    _ble_term_DA2R=$1
    ble/term/DA2/initialize-term
  fi
  blehook/invoke DA2R
}

_ble_term_DECSTBM=
function ble/term/test-DECSTBM.hook {
  (($1==2)) && _ble_term_DECSTBM=$'\e[%s;%sr'
}
function ble/term/test-DECSTBM {
  local -a DRAW_BUFF=()
  ble/canvas/panel/goto-top-dock.draw
  ble/canvas/put.draw "$_ble_term_sc"$'\e[1;2r'
  ble/canvas/put-cup.draw 2 1
  ble/canvas/put-cud.draw 1
  ble/term/CPR/request.draw ble/term/test-DECSTBM.hook
  ble/canvas/put.draw $'\e[;r'"$_ble_term_rc"
  ble/canvas/bflush.draw
}

#---- DSR(6) ------------------------------------------------------------------
# CPR (CURSOR POSITION REPORT)

_ble_term_CPR_hook=()
function ble/term/CPR/request.buff {
  ble/array#push _ble_term_CPR_hook "$1"
  ble/util/buffer $'\e[6n'
  return 147
}
function ble/term/CPR/request.draw {
  ble/array#push _ble_term_CPR_hook "$1"
  ble/canvas/put.draw $'\e[6n'
  return 147
}
function ble/term/CPR/notify {
  local hook=${_ble_term_CPR_hook[0]}
  ble/array#shift _ble_term_CPR_hook
  [[ ! $hook ]] || "$hook" "$1" "$2"
}

#---- SGR(>4): modifyOtherKeys ------------------------------------------------

bleopt/declare -v term_modifyOtherKeys_external auto
bleopt/declare -v term_modifyOtherKeys_internal auto

_ble_term_modifyOtherKeys_current=
function ble/term/modifyOtherKeys/.update {
  [[ $1 == "$_ble_term_modifyOtherKeys_current" ]] && return 0

  # Note: RLogin では modifyStringKeys (\e[>5m) も指定しないと駄目。
  #   また、RLogin は modifyStringKeys にすると S-数字 を
  #   記号に翻訳してくれないので注意。
  if [[ $_ble_term_TERM == RLogin ]]; then
    case $1 in
    (0) ble/util/buffer $'\e[>5;0m' ;;
    (1) ble/util/buffer $'\e[>5;1m' ;;
    (2) ble/util/buffer $'\e[>5;1m\e[>5;2m' ;;
    esac
  fi

  # Note: 対応していない端末が SGR と勘違いしても
  #  大丈夫な様に SGR を最後にクリアしておく。
  # Note: \e[>4;2m の時は、対応していない端末のため
  #   一端 \e[>4;1m にしてから \e[>4;2m にする。
  case $1 in
  (0) ble/util/buffer $'\e[>4;0m\e[m' ;;
  (1) ble/util/buffer $'\e[>4;1m\e[m' ;;
  (2) ble/util/buffer $'\e[>4;1m\e[>4;2m\e[m' ;;
  esac

  _ble_term_modifyOtherKeys_current=$1
}
function ble/term/modifyOtherKeys/.supported {
  # libvte は SGR(>4) を直接画面に表示してしまう。
  [[ $_ble_term_TERM == vte ]] && return 1

  # 改造版 Poderosa は通知でウィンドウサイズを毎回変更するので表示が乱れてしまう
  [[ $MWG_LOGINTERM == rosaterm ]] && return 1

  # Note #D1213: linux (kernel 5.0.0) は "\e[>" でエスケープシーケンスを閉じてしまう。
  #   5.4.8 は大丈夫だがそれでも modifyOtherKeys に対応していない。
  #   Solaris のコンソールもそのまま出力してしまう。
  [[ $TERM == linux || $TERM == minix || $TERM == sun* ]] && return 1

  return 0
}
function ble/term/modifyOtherKeys/enter {
  local value=$bleopt_term_modifyOtherKeys_internal
  if [[ $value == auto ]]; then
    value=2
    # 問題を起こす端末で無効化。
    ble/term/modifyOtherKeys/.supported || value=
  fi
  ble/term/modifyOtherKeys/.update "$value"
}
function ble/term/modifyOtherKeys/leave {
  local value=$bleopt_term_modifyOtherKeys_external
  if [[ $value == auto ]]; then
    value=1
    # 問題を起こす端末で無効化。
    if [[ $TERM == xterm-kitty ]]; then
      value=0 # Kitty は 1 では無効にならない。変な振る舞い
    else
      ble/term/modifyOtherKeys/.supported || value=
    fi
  fi
  ble/term/modifyOtherKeys/.update "$value"
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

  if ble/util/test-rl-variable convert-meta; then
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

_ble_term_state=external
function ble/term/enter {
  [[ $_ble_term_state == internal ]] && return 0
  ble/term/stty/enter
  ble/term/bracketed-paste-mode/enter
  ble/term/modifyOtherKeys/enter
  ble/term/cursor-state/.update "$_ble_term_cursor_internal"
  ble/term/cursor-state/.update-hidden "$_ble_term_cursor_hidden_internal"
  ble/term/rl-convert-meta/enter
  _ble_term_state=internal
}
function ble/term/leave {
  [[ $_ble_term_state == external ]] && return 0
  ble/term/stty/leave
  ble/term/bracketed-paste-mode/leave
  ble/term/modifyOtherKeys/leave
  ble/term/cursor-state/.update "$bleopt_term_cursor_external"
  ble/term/cursor-state/.update-hidden reveal
  ble/term/rl-convert-meta/leave
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
if ((_ble_bash>=40100)); then
  # - printf "'c" で Unicode が読める (どの LC_CTYPE でも Unicode になる)
  function ble/util/s2c {
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
      while TMOUT= IFS= builtin read -r -n 1 byte; do
        builtin printf "%d " "'\''$byte"
      done <<< "$s"
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
    ((40200<=_ble_bash&&_ble_bash<40500)) || return 1
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
        builtin printf -v ret '\\x%02x' $((0xE0|$1>>12&0x0F)) $((0x80|$1>>6&0x3F)) $((0x80|$1&0x3F))
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
        ble/util/c2s $((char7+96))
      else
        ble/util/c2s $((char7+64))
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
    local text=${keyseq::1}
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
  ((n=b0>0xF0
    ?(b0>0xFC?5:(b0>0xF8?4:3))
    :(b0>0xE0?2:(b0>0xC0?1:0)),
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
  bytes=($((code&0xFF)))
}

function ble/util/is-unicode-output {
  [[ $_ble_util_locale_triple != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.cache/update-locale
  [[ $_ble_util_locale_encoding == UTF-8 ]]
}
