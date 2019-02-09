# -*- mode:sh;mode:sh-bash -*-
# bash script to be sourced from interactive shell

## オプション input_encoding
: ${bleopt_input_encoding:=UTF-8}

function bleopt/check:input_encoding {
  if ! ble/is-function "ble/encoding:$value/decode"; then
    echo "bleopt: Invalid value input_encoding='$value'." \
         "A function 'ble/encoding:$value/decode' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/b2c"; then
    echo "bleopt: Invalid value input_encoding='$value'." \
         "A function 'ble/encoding:$value/b2c' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/c2bc"; then
    echo "bleopt: Invalid value input_encoding='$value'." \
         "A function 'ble/encoding:$value/c2bc' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/generate-binder"; then
    echo "bleopt: Invalid value input_encoding='$value'." \
         "A function 'ble/encoding:$value/generate-binder' is not defined." >&2
    return 1
  elif ! ble/is-function "ble/encoding:$value/is-intermediate"; then
    echo "bleopt: Invalid value input_encoding='$value'." \
         "A function 'ble/encoding:$value/is-intermediate' is not defined." >&2
    return 1
  fi

  # Note: ble/encoding:$value/clear は optional な設定である。

  if [[ $bleopt_input_encoding != "$value" ]]; then
    ble-decode/unbind
    bleopt_input_encoding=$value
    ble-decode/bind
  fi
  return 0
}

## オプション internal_stackdump_enabled
##   エラーが起こった時に関数呼出の構造を標準エラー出力に出力するかどうかを制御する。
##   算術式評価によって非零の値になる場合にエラーを出力する。
##   それ以外の場合にはエラーを出力しない。
: ${bleopt_internal_stackdump_enabled=0}

## オプション openat_base
##   bash-4.1 未満で exec {var}>foo が使えない時に ble.sh で内部的に fd を割り当てる。
##   この時の fd の base を指定する。bleopt_openat_base, bleopt_openat_base+1, ...
##   という具合に順番に使用される。既定値は 30 である。
: ${bleopt_openat_base:=30}

## オプション pager
: ${bleopt_pager:=}

shopt -s checkwinsize

#------------------------------------------------------------------------------
# util

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
  local name prefix=$1; shift
  for name; do eval "$prefix$name=\"\$$name\""; done
}
function ble/util/save-arrs {
  local name prefix=$1; shift
  for name; do eval "$prefix$name=(\"\${$name[@]}\")"; done
}
function ble/util/restore-vars {
  local name prefix=$1; shift
  for name; do eval "$name=\"\$$prefix$name\""; done
}
function ble/util/restore-arrs {
  local name prefix=$1; shift
  for name; do eval "$name=(\"\${$prefix$name[@]}\")"; done
}

#%if !release
## 関数 ble/debug/.check-leak-variable
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
    echo "$1=${!1}:${2:*}" >> a.txt
    eval "$1=__t1wJltaP9nmow__"
  fi
}
#%end

#
# array and strings
#

_ble_array_prototype=()
function ble/array#reserve-prototype {
  local n=$1 i
  for ((i=${#_ble_array_prototype[@]};i<n;i++)); do
    _ble_array_prototype[i]=
  done
}

## 関数 ble/is-array arr
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
else
  function ble/is-array { compgen -A arrayvar -X \!"$1" "$1" &>/dev/null; }
fi

## 関数 ble/array#push arr value...
if ((_ble_bash>=30100)); then
  function ble/array#push {
    builtin eval "$1+=(\"\${@:2}\")"
  }
else
  function ble/array#push {
    while (($#>=2)); do
      builtin eval "$1[\${#$1[@]}]=\"\$2\""
      set -- "$1" "${@:3}"
    done
  }
fi
function ble/array#pop {
  eval "local i$1=\$((\${#$1[@]}-1))"
  if ((i$1>=0)); then
    eval "ret=\${$1[i$1]}"
    unset -v "$1[i$1]"
  else
    ret=
  fi
}
## 関数 ble/array#reverse arr
function ble/array#reverse {
  builtin eval "
  set -- \"\${$1[@]}\"; $1=()
  local e$1 i$1=\$#
  for e$1; do $1[--i$1]=\"\$e$1\"; done"
}

_ble_string_prototype='        '
function ble/string#reserve-prototype {
  local n=$1 c
  for ((c=${#_ble_string_prototype};c<n;c*=2)); do
    _ble_string_prototype=$_ble_string_prototype$_ble_string_prototype
  done
}

## 関数 ble/string#repeat str count
##   @param[in] str
##   @param[in] count
##   @var[out] ret
function ble/string#repeat {
  ble/string#reserve-prototype "$2"
  ret=${_ble_string_prototype::$2}
  ret="${ret// /$1}"
}

## 関数 ble/string#common-prefix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-prefix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b::${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return
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

## 関数 ble/string#common-suffix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-suffix {
  local a=$1 b=$2
  ((${#a}>${#b})) && local a=$b b=$a
  b=${b:${#b}-${#a}}
  if [[ $a == "$b" ]]; then
    ret=$a
    return
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

## 関数 ble/string#split arr sep str...
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
    IFS=$' \t\n' builtin eval "$1=(\${*:2})"
  else
    set -f
    IFS=$' \t\n' builtin eval "$1=(\${*:2})"
    set +f
  fi
}
## 関数 ble/string#split-lines arr text...
##   文字列を行に分割します。空行も省略されません。
##
##   @param[out] arr  分割した文字列を格納する配列名を指定します。
##   @param[in]  text 分割する文字列を指定します。
##
if ((_ble_bash>=40000)); then
  function ble/string#split-lines {
    mapfile -t "$1" <<< "${*:2}"
  }
else
  function ble/string#split-lines {
    local name=$1 text=${*:2} sep='' esc='\'
    if [[ $text == *$sep* ]]; then
      local a b arr ret value
      a=$esc b=$esc'A' text=${text//"$a"/"$b"}
      a=$sep b=$esc'B' text=${text//"$a"/"$b"}

      text=${text//$'\n'/"$sep"}
      ble/string#split arr "$sep" "$text"

      for value in "${arr[@]}"; do
        if [[ $value == *$esc* ]]; then
          a=$esc'B' b=$sep value=${value//"$a"/"$b"}
          a=$esc'A' b=$esc value=${value//"$a"/"$b"}
        fi
        ret[${#ret[@]}]=$value
      done
    else
      local ret
      text=${text//$'\n'/"$sep"}
      ble/string#split ret "$sep" "$text"
    fi
    local "$name" && ble/util/uparr "$name" "${ret[@]}"
  }
fi
## 関数 ble/string#count-char text chars
##   @param[in] text
##   @param[in] chars
##     検索対象の文字の集合を指定します。
##   @var[out] ret
function ble/string#count-char {
  local text=$1 char=$2
  text=${text//[!"$char"]}
  ret=${#text}
}

## 関数 ble/string#count-string text string
function ble/string#count-string {
  local text=${1//"$2"}
  ((ret=(${#1}-${#text})/${#2}))
}

## 関数 ble/string#index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     この引数を指定したとき n 番目の一致を検索します。
function ble/string#index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '*"$needle"' "$count"; local pattern=$ret
  eval "local transformed=\${haystack#$pattern}"
  ((ret=${#haystack}-${#transformed}-${#needle},
    ret<0&&(ret=-1),ret>=0))
}

## 関数 ble/string#last-index-of text needle [n]
##   @param[in] text
##   @param[in] needle
##   @param[in] n
##     この引数を指定したとき n 番目の一致を検索します。
function ble/string#last-index-of {
  local haystack=$1 needle=$2 count=${3:-1}
  ble/string#repeat '"$needle"*' "$count"; local pattern=$ret
  eval "local transformed=\${haystack%$pattern}"
  if [[ $transformed == "$haystack" ]]; then
    ret=-1
  else
    ret=${#transformed}
  fi
  ((ret>=0))
}

## 関数 ble/string#toggle-case text...
## 関数 ble/string#touppwer text...
## 関数 ble/string#tolower text...
##   @param[in] text
##   @var[out] ret
_ble_util_string_lower_list=abcdefghijklmnopqrstuvwxyz
_ble_util_string_upper_list=ABCDEFGHIJKLMNOPQRSTUVWXYZ
function ble/string#toggle-case {
  local text=$* ch i
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
  IFS= eval 'ret="${buff[*]-}"'
}
if ((_ble_bash>=40000)); then
  function ble/string#tolower { ret=${*,,}; }
  function ble/string#toupper { ret=${*^^}; }
else
  function ble/string#tolower {
    local text=$*
    local -a buff ch
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if [[ $ch == [A-Z] ]]; then
        ch=${_ble_util_string_upper_list%%"$ch"*}
        ch=${_ble_util_string_lower_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= eval 'ret="${buff[*]-}"'
  }
  function ble/string#toupper {
    local text=$*
    local -a buff ch
    for ((i=0;i<${#text};i++)); do
      ch=${text:i:1}
      if [[ $ch == [a-z] ]]; then
        ch=${_ble_util_string_lower_list%%"$ch"*}
        ch=${_ble_util_string_upper_list:${#ch}:1}
      fi
      ble/array#push buff "$ch"
    done
    IFS= eval 'ret="${buff[*]-}"'
  }
fi

## 関数 ble/string#escape-characters chars1 chars2 text
##   @param[in]     chars1
##   @param[in,opt] chars2
##   @param[in]     text
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

function ble/string#escape-for-sed-regex {
  ble/string#escape-characters "$*" '\.[*^$/'
}
function ble/string#escape-for-awk-regex {
  ble/string#escape-characters "$*" '\.[*?+|^$(){}/'
}
function ble/string#escape-for-extended-regex {
  ble/string#escape-characters "$*" '\.[*?+|^$(){}'
}
function ble/string#escape-for-bash-glob {
  ble/string#escape-characters "$*" '\*?[('
}
function ble/string#escape-for-bash-single-quote {
  ret="$*"
  local q="'" Q="'\''"
  ret=${ret//"$q"/$Q}
}
function ble/string#escape-for-bash-double-quote {
  ble/string#escape-characters "$*" '\"$`'
  local a b
  a='!' b='"\!"' ret=${ret//"$a"/$b}
}
function ble/string#escape-for-bash-escape-string {
  ble/string#escape-characters "$*" $'\\\a\b\e\f\n\r\t\v'\' '\abefnrtv'\'
}
function ble/string#escape-for-bash-specialchars {
  ble/string#escape-characters "$*" '\ ["'\''`$|&;<>()*?!^{'
  if [[ $ret == *[$']\n\t']* ]]; then
    local a b
    a=']'   b=\\$a     ret=${ret//"$a"/$b}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/$b}
    a=$'\t' b=$' \t'   ret=${ret//"$a"/$b}
  fi
}
function ble/string#escape-for-bash-specialchars-in-brace {
  ble/string#escape-characters "$*" '\ ["'\''`$|&;<>()*?!^{,}'
  if [[ $ret == *[$']\n\t']* ]]; then
    local a b
    a=']'   b=\\$a     ret=${ret//"$a"/$b}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/$b}
    a=$'\t' b=$' \t'   ret=${ret//"$a"/$b}
  fi
}

#
# assign: reading files/streams into variables
#

## 関数 ble/util/readfile var filename
## 関数 ble/util/mapfile arr < filename
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
    IFS= eval "$1"'="${__buffer[*]-}"'
  }
  function ble/util/mapfile {
    mapfile -t "$1"
  }
else
  function ble/util/readfile { # 465ms for man bash
    IFS= builtin read -r -d '' "$1" < "$2"
  }
  function ble/util/mapfile {
    IFS= builtin read -r -d '' "$1"
    ble/string#split-lines "$1" "${!1}"
  }
fi

## 関数 ble/util/assign var command...
##   var=$(command ...) の高速な代替です。
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
    builtin eval "$2" >| "$_ble_local_tmp"
    local _ret=$? __arr
    ((_ble_util_assign_level--))
    mapfile -t __arr < "$_ble_local_tmp"
    IFS=$'\n' eval "$1=\"\${__arr[*]-}\""
    return "$_ret"
  }
else
  function ble/util/assign {
    local _ble_local_tmp=$_ble_util_assign_base.$((_ble_util_assign_level++))
    builtin eval "$2" >| "$_ble_local_tmp"
    local _ret=$?
    ((_ble_util_assign_level--))
    IFS= builtin read -r -d '' "$1" < "$_ble_local_tmp"
    eval "$1=\${$1%$'\n'}"
    return "$_ret"
  }
fi
## 関数 ble/util/assign-array arr command args...
##   mapfile -t arr <(command ...) の高速な代替です。
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
    builtin eval "$2" >| "$_ble_local_tmp"
    local _ret=$?
    ((_ble_util_assign_level--))
    mapfile -t "$1" < "$_ble_local_tmp"
    return "$_ret"
  }
else
  function ble/util/assign-array {
    ble/util/assign "$@"
    if [[ ${!1} ]]; then
      ble/string#split-lines "$1" "${!1%$'\n'}"
    else
      eval "$1=()"
    fi
  }
fi

#
# functions
#

if ((_ble_bash>=30200)); then
  function ble/is-function {
    builtin declare -F "$1" &>/dev/null
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
function ble/function#try {
  ble/is-function "$1" || return 127
  "$@"
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

## 関数 ble/util/type varname command
##   @param[out] varname
##     結果を格納する変数名を指定します。
##   @param[in] command
##     種類を判定するコマンド名を指定します。
function ble/util/type {
  ble/util/assign "$1" 'builtin type -t -- "$3" 2>/dev/null' "$2"
  builtin eval "$1=\"\${$1%$_ble_term_nl}\""
}

if ((_ble_bash>=40000)); then
  function ble/util/is-stdin-ready { IFS= LC_ALL=C builtin read -t 0; } &>/dev/null
else
  function ble/util/is-stdin-ready { false; }
fi

# exec {var}>foo
_ble_util_openat_fdlist=()
if ((_ble_bash>=40100)); then
  function ble/util/openat {
    local _fdvar=$1 _redirect=$2
    builtin eval "exec {$_fdvar}$_redirect"; local ret=$?
    ble/array#push _ble_util_openat_fdlist "${!_fdvar}"
    return "$ret"
  }
else
  _ble_util_openat_nextfd=$bleopt_openat_base
  function ble/util/openat {
    local _fdvar=$1 _redirect=$2
    (($_fdvar=_ble_util_openat_nextfd++))
    # Note: Bash 3.2/3.1 のバグを避けるため、
    #   >&- を用いて一旦明示的に閉じる必要がある #D0857
    builtin eval "exec ${!_fdvar}>&- ${!_fdvar}$_redirect"; local ret=$?
    ble/array#push _ble_util_openat_fdlist "${!_fdvar}"
    return "$ret"
  }
fi
function ble/util/openat/finalize {
  local fd
  for fd in "${_ble_util_openat_fdlist[@]}"; do
    builtin eval "exec $fd>&-"
  done
  _ble_util_openat_fdlist=()
}

function ble/util/declare-print-definitions {
  if [[ $# -gt 0 ]]; then
    declare -p "$@" | ble/bin/awk -v _ble_bash="$_ble_bash" '
      BEGIN { decl = ""; }
      function declflush(_, isArray) {
        if (decl) {
          isArray = (decl ~ /declare +-[fFgilrtux]*[aA]/);

          # bash-3.0 の declare -p は改行について誤った出力をする。
          if (_ble_bash < 30100) gsub(/\\\n/, "\n", decl);

          # declare 除去
          sub(/^declare +(-[-aAfFgilrtux]+ +)?(-- +)?/, "", decl);
          if (isArray) {
            if (decl ~ /^([[:alpha:]_][[:alnum:]_]*)='\''\(.*\)'\''$/) {
              sub(/='\''\(/, "=(", decl);
              sub(/\)'\''$/, ")", decl);
              gsub(/'\'\\\\\'\''/, "'\''", decl);
            }
          }
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
## 関数 ble/util/print-global-definitions varnames...
##
##   @var[in] varnames
##
##   指定した変数のグローバル変数としての定義を出力します。
##   現状では配列変数には対応していません。
##
##   制限: 途中に readonly なローカル変数があるとその変数の値を返す。
##   しかし、そもそも readonly な変数には問題が多いので ble.sh では使わない。
##
##   制限: __ble_* という変数名は内部で使用するので、対応しません。
##
if ((_ble_bash>=40200)); then
  # 注意: bash-4.2 にはバグがあって、グローバル変数が存在しない時に
  #   declare -g -r var とすると、ローカルに新しく読み取り専用の var 変数が作られる。
  #   現在の実装では問題にならない。
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
        ((__ble_processed_$__ble_name)) && continue
        ((__ble_processed_$__ble_name=1))
        [[ $_ble_name == __ble_* ]] && continue

        declare -g -r "$__ble_name"

        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          __ble_value=${!__ble_name}
          unset -v "$__ble_name" || break
        done 2>/dev/null

        ((__ble_i==__ble_MaxLoop)) && __ble_error=1 __ble_value= # not found

        [[ $__ble_hidden_only && $__ble_i == 0 ]] && continue
        echo "declare $__ble_name='${__ble_value//$__ble_q//$__ble_Q}'"
      done
      
      [[ ! $__ble_error ]]
    ) 2>/dev/null
  }
else
  # 制限: グローバル変数が定義されずローカル変数が定義されているとき、
  #   ローカル変数の値が取得されてしまう。
  function ble/util/print-global-definitions {
    local __ble_hidden_only=
    [[ $1 == --hidden-only ]] && { __ble_hidden_only=1; shift; }
    (
      ((_ble_bash>=50000)) && shopt -u localvar_unset
      __ble_error=
      __ble_q="'" __ble_Q="'\''"
      __ble_MaxLoop=20

      for __ble_name; do
        ((__ble_processed_$__ble_name)) && continue
        ((__ble_processed_$__ble_name=1))
        [[ $_ble_name == __ble_* ]] && continue

        __ble_value= __ble_found=
        for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
          [[ ${!__ble_name+set} ]] && __ble_value=${!__ble_name} __ble_found=$__ble_i
          unset -v "$__ble_name" 2>/dev/null
        done

        [[ $__ble_found ]] || __ble_error= __ble_value= # not found
        [[ $__ble_hidden_only && $__ble_found == 0 ]] && continue

        echo "declare $__ble_name='${__ble_value//$__ble_q//$__ble_Q}'"
      done
      
      [[ ! $__ble_error ]]
    ) 2>/dev/null
  }
fi

function ble/util/eval-pathname-expansion {
  # Note: eval で囲んでおかないと failglob 失敗時に続きが実行されない
  # Note: failglob で失敗した時のエラーメッセージは殺す
  ret=()
  eval "ret=($1)" 2>/dev/null
}


# 正規表現は _ble_bash>=30000
_ble_util_rex_isprint='^[ -~]+'
## 関数 ble/util/isprint+ str
##
##   @var[out] BASH_REMATCH ble-exit/text/update/position で使用する。
function ble/util/isprint+ {
  # LC_COLLATE=C ...  &>/dev/null for cygwin collation
  LC_COLLATE=C ble/util/isprint+.impl "$@" &>/dev/null
}
function ble/util/isprint+.impl {
  [[ $1 =~ $_ble_util_rex_isprint ]]
}

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
      ble/util/assign "$2" 'ble/bin/date +"$3" $4'
    else
      ble/bin/date +"$1" $2
    fi
  }
fi

function ble/util/sleep/.check-builtin-sleep {
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

if ((_ble_bash>=40400)) && ble/util/sleep/.check-builtin-sleep; then
  _ble_util_sleep_builtin_available=1
  function ble/util/sleep { builtin sleep "$1"; }
elif ((_ble_bash>=40000)); then
  # 遅延初期化
  _ble_util_sleep_fd=
  _ble_util_sleep_tmp=
  function ble/util/sleep {
    function ble/util/sleep { local REPLY=; ! builtin read -u "$_ble_util_sleep_fd" -t "$1"; } &>/dev/null

    if [[ $OSTYPE == cygwin* ]]; then
      # Cygwin workaround

      ble/util/openat _ble_util_sleep_fd '< <(
        [[ $- == *i* ]] && trap -- '' INT QUIT
        while kill -0 $$; do ble/bin/sleep 300; done &>/dev/null
      )'

      if [[ $BASH_VERSION ]]; then
        function ble/util/sleep {
          local s=${1%%.*}
          if ((s>0)); then
            ! builtin read -u "$_ble_util_sleep_fd" -t "$1" s
          else
            ! builtin read -t "$1" s < /dev/udp/0.0.0.0/80
          fi
        }
      fi
    else
      _ble_util_sleep_tmp=$_ble_base_run/$$.ble_util_sleep.pipe
      if [[ ! -p $_ble_util_sleep_tmp ]]; then
        [[ -e $_ble_util_sleep_tmp ]] && ble/bin/rm -rf "$_ble_util_sleep_tmp"
        ble/bin/mkfifo "$_ble_util_sleep_tmp"
      fi
      ble/util/openat _ble_util_sleep_fd "<> $_ble_util_sleep_tmp"
    fi

    ble/util/sleep "$1"
  }
elif ble/bin/.freeze-utility-path sleepenh; then
  function ble/util/sleep { ble/bin/sleepenh "$1" &>/dev/null; }
elif ble/bin/.freeze-utility-path usleep; then
  function ble/util/sleep {
    if [[ $1 == *.* ]]; then
      local sec=${1%%.*} sub=${1#*.}000000
      if (($sec)); then
        ble/bin/usleep "$sec${sub::6}"
      else
        ble/bin/usleep $((10#${sub::6}))
      fi
    else
      ble/bin/usleep "${1}000000"
    fi
  }
else
  function ble/util/sleep { ble/bin/sleep "$1"; }
fi

## 関数 ble/util/cat
##   cat の代替。但し、ファイル内に \0 が含まれる場合は駄目。
function ble/util/cat {
  local content=
  if [[ $1 && $1 != - ]]; then
    IFS= builtin read -r -d '' content < "$1"
  else
    IFS= builtin read -r -d '' content
  fi
  printf %s "$content"
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

  eval "$1"'=${bleopt_pager:-${PAGER:-$_ble_util_less_fallback}}'
}
function ble/util/pager {
  local pager; ble/util/get-pager pager
  eval "$pager \"\$@\""
}

## 関数 ble/util/getmtime filename
##   ファイル filename の mtime を取得し標準出力に出力します。
##   ミリ秒も取得できる場合には第二フィールドとしてミリ秒を出力します。
##   @param[in] filename ファイル名を指定します。
##
if type date &>/dev/null && date -r / +%s &>/dev/null; then
  function ble/util/getmtime { date -r "$1" +'%s %N' 2>/dev/null; }
elif type stat &>/dev/null; then
  # 参考: http://stackoverflow.com/questions/17878684/best-way-to-get-file-modified-time-in-seconds
  if stat -c %Y / &>/dev/null; then
    function ble/util/getmtime { stat -c %Y "$1" 2>/dev/null; }
  elif stat -f %m / &>/dev/null; then
    function ble/util/getmtime { stat -f %m "$1" 2>/dev/null; }
  fi
fi
# fallback: print current time
ble/is-function ble/util/getmtime ||
  function ble/util/getmtime { ble/util/strftime '%s %N'; }

#------------------------------------------------------------------------------
## 関数 ble/util/buffer text...
_ble_util_buffer=()
function ble/util/buffer {
  _ble_util_buffer[${#_ble_util_buffer[@]}]="$*"
}
function ble/util/buffer.print {
  ble/util/buffer "$*"$'\n'
}
function ble/util/buffer.flush {
  IFS= builtin eval 'builtin echo -n "${_ble_util_buffer[*]-}"'
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

## 関数 ble/dirty-range#update [--prefix=PREFIX] beg end end0
## @param[out] PREFIX
## @param[in]  beg    変更開始点。beg<0 は変更がない事を表す
## @param[in]  end    変更終了点。end<0 は変更が末端までである事を表す
## @param[in]  end0   変更前の end に対応する位置。
function ble/dirty-range#update {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    shift
    [[ $_prefix ]] && local beg end end0
  fi

  local begB=$1 endB=$2 endB0=$3
  ((begB<0)) && return

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

## 関数 ble/urange#clear [--prefix=prefix]
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
## 関数 ble/urange#update [--prefix=prefix] min max
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
  ((0<=min&&min<max)) || return
  (((${prefix}umin<0||min<${prefix}umin)&&(${prefix}umin=min),
    (${prefix}umax<0||${prefix}umax<max)&&(${prefix}umax=max)))
}
## 関数 ble/urange#shift [--prefix=prefix] dbeg dend dend0
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
  ((dbeg>=0)) || return
  [[ $shift ]] || ((shift=dend-dend0))
  ((${prefix}umin>=0&&(
      dbeg<=${prefix}umin&&(${prefix}umin<=dend0?(${prefix}umin=dend):(${prefix}umin+=shift)),
      dbeg<=${prefix}umax&&(${prefix}umax<=dend0?(${prefix}umax=dbeg):(${prefix}umax+=shift))),
    ${prefix}umin<${prefix}umax||(
      ${prefix}umin=-1,
      ${prefix}umax=-1)))
}

#------------------------------------------------------------------------------
## 関数 ble/util/joblist
##   現在のジョブ一覧を取得すると共に、ジョブ状態の変化を調べる。
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
  local jobs0
  ble/util/assign jobs0 'jobs'
  if [[ $jobs0 == "$_ble_util_joblist_jobs" ]]; then
    # 前回の呼び出し結果と同じならば状態変化はないものとして良い。終了・強制終
    # 了したジョブがあるとしたら "終了" だとか "Terminated" だとかいう表示にな
    # っているはずだが、その様な表示は二回以上は為されないので必ず変化がある。
    joblist=("${_ble_util_joblist_list[@]}")
    return
  elif [[ ! $jobs0 ]]; then
    # 前回の呼び出しで存在したジョブが新しい呼び出しで無断で消滅することは恐ら
    # くない。今回の結果が空という事は本来は前回の結果も空のはずであり、だとす
    # ると上の分岐に入るはずなのでここには来ないはずだ。しかしここに入った時の
    # 為に念を入れて空に設定して戻るようにする。
    _ble_util_joblist_jobs=
    _ble_util_joblist_list=()
    joblist=()
    return
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
        ble/array#push _ble_util_joblist_events "${list[ijob]}"
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
    for ijob in "${!list[@]}"; do
      if [[ ${list[ijob]} && ! ${_ble_util_joblist_list[ijob]} ]]; then
        ble/array#push _ble_util_joblist_events "${list[ijob]}"
      fi
    done
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
    [[ $ijob ]] && eval "$arr[ijob]=\${$arr[ijob]}\${$arr[ijob]:+\$_ble_term_nl}\$line"
  done
}

## 関数 ble/util/joblist.check
##   ジョブ状態変化の確認だけ行います。
##   内部的に jobs を呼び出す直前に、ジョブ状態変化を取り逃がさない為に明示的に呼び出します。
function ble/util/joblist.check {
  local joblist
  ble/util/joblist
}

## 関数 ble/util/joblist.flush
##   ジョブ状態変化の確認とそれまでに検出した変化の出力を行います。
function ble/util/joblist.flush {
  local joblist
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return
  printf '%s\n' "${_ble_util_joblist_events[@]}"
  _ble_util_joblist_events=()
}
function ble/util/joblist.bflush {
  local joblist out
  ble/util/joblist
  ((${#_ble_util_joblist_events[@]})) || return
  ble/util/sprintf out '%s\n' "${_ble_util_joblist_events[@]}"
  ble/util/buffer "$out"
  _ble_util_joblist_events=()
}

## 関数 ble/util/joblist.clear
##   bash 自身によってジョブ状態変化が出力される場合には比較用のバッファを clear します。
function ble/util/joblist.clear {
  _ble_util_joblist_jobs=
  _ble_util_joblist_list=()
}

#------------------------------------------------------------------------------
## 関数 ble/util/save-editing-mode varname
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
## 関数 ble/util/restore-editing-mode varname
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

function ble/util/test-rl-variable {
  local rl_variables; ble/util/assign rl_variables 'builtin bind -v'
  [[ $rl_variables == *"set $1 on"* ]]
}

#------------------------------------------------------------------------------
# Functions for modules

function ble/util/invoke-hook {
  local -a hooks; eval "hooks=(\"\${$1[@]}\")"
  local hook ext=0
  for hook in "${hooks[@]}"; do eval "$hook" || ext=$?; done
  return "$ext"
}

## 関数 ble/util/.read-arguments-for-no-option-command commandname args...
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
        echo "$commandname: unrecognized option '$arg'" >&2
        flags=e$flags ;;
      (*)
        ble/array#push args "$arg" ;;
      esac
    else
      ble/array#push args "$arg"
    fi
  done
}


## 関数 ble-autoload scriptfile functions...
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
      unset -f $funcname
      ble/util/import '${file//$q/$Q}'
      $funcname \"\$@\"
    }"
  done
}
function ble/util/autoload/.print-usage {
  echo 'usage: ble-autoload SCRIPTFILE FUNCTION...'
  echo '  Setup delayed loading of functions defined in the specified script file.'
} >&2    
## 関数 ble/util/autoload/.read-arguments args...
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
        echo 'ble-autoload: the script filename should not be empty.' >&2
      else
        echo 'ble-autoload: function names should not be empty.' >&2
      fi
      flags=e$flags
    fi
    ((index++))
  done

  [[ $flags == *h* ]] && return

  if ((${#args[*]}==0)); then
    echo 'ble-autoload: script filename is not specified.' >&2
    flags=e$flags
  elif ((${#args[*]}==1)); then
    echo 'ble-autoload: function names are not specified.' >&2
    flags=e$flags
  fi

  file=${args[0]} functions=("${#args[@]:1}")
}
function ble-autoload {
  local file flags
  local -a functions=()
  ble/util/autoload/.read-arguments "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && echo
    ble/util/autoload/.print-usage
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  ble/util/autoload "$file" "${functions[@]}"
}

## 関数 ble-import scriptfile...
##   指定したファイルを検索して source で読み込みます。
##   既に import 済みのファイルは読み込みません。
##
##   @param[in] scriptfile
##     読み込むファイルを指定します。
##     絶対パスで指定した場合にはそのファイルを使用します。
##     それ以外の場合には $_ble_base:$_ble_base/local:$_ble_base/share から検索します。
##
_ble_util_import_guards=()
function ble/util/import {
  local file=$1
  if [[ $file == /* ]]; then
    local guard=ble/util/import/guard:$1
    ble/is-function "$guard" && return 0
    if [[ -f $file ]]; then
      source "$file"
    else
      return 1
    fi && eval "function $guard { :; }" &&
      ble/array#push _ble_util_import_guards "$guard"
  else
    local guard=ble/util/import/guard:ble/$1
    ble/is-function "$guard" && return 0
    if [[ -f $_ble_base/$file ]]; then
      source "$_ble_base/$file"
    elif [[ -f $_ble_base/local/$file ]]; then
      source "$_ble_base/local/$file"
    elif [[ -f $_ble_base/share/$file ]]; then
      source "$_ble_base/share/$file"
    else
      return 1
    fi && eval "function $guard { :; }" &&
      ble/array#push _ble_util_import_guards "$guard"
  fi
}
# called by ble/base/unload (ble.pp)
function ble/util/import/finalize {
  local guard
  for guard in "${_ble_util_import_guards[@]}"; do
    unset -f "$guard"
  done
}
## 関数 ble/util/import/.read-arguments args...
##   @var[out] files flags
function ble/util/import/.read-arguments {
  flags= files=()

  local args
  ble/util/.read-arguments-for-no-option-command ble-import "$@"

  [[ $flags == *h* ]] && return

  if ((!${#args[@]})); then
    echo 'ble-import: argument is not specified.' >&2
    flags=e$flags
  fi

  files=("${args[@]}")
}
function ble-import {
  local files flags
  ble/util/import/.read-arguments "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && echo
    {
      echo 'usage: ble-import SCRIPT_FILE...'
      echo '  Search and source script files that have not yet been loaded.'
    } >&2
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  local file
  for file in "${files[@]}"; do
    ble/util/import "$file"
  done
}

## 関数 ble-stackdump [message]
##   現在のコールスタックの状態を出力します。
##
##   @param[in,opt] message
##     スタック情報の前に表示するメッセージを指定します。
##   @var[in] _ble_util_stackdump_title
##     スタック情報の前に表示するタイトルを指定します。
##
_ble_util_stackdump_title=stackdump
function ble/util/stackdump {
  ((bleopt_internal_stackdump_enabled)) || return
  local message=$1
  local i nl=$'\n'
  local message="$_ble_term_sgr0$_ble_util_stackdump_title: $message$nl"
  for ((i=1;i<${#FUNCNAME[*]};i++)); do
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i]} (${FUNCNAME[i]})$nl"
  done
  builtin echo -n "$message" >&2
}
function ble-stackdump {
  local flags args
  ble/util/.read-arguments-for-no-option-command ble-stackdump "$@"
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && echo
    {
      echo 'usage: ble-stackdump command [message]'
      echo '  Print stackdump.'
    } >&2
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  ble/util/stackdump "${args[*]}"
}

## 関数 ble-assert command [message]
##   コマンドを評価し失敗した時にメッセージを表示します。
##
##   @param[in] command
##     評価するコマンドを指定します。eval で評価されます。
##   @param[in,opt] message
##     失敗した時に表示するメッセージを指定します。
##
function ble/util/assert {
  local expr=$1 message=$2
  local _ble_util_stackdump_title='assertion failure'
  if ! builtin eval -- "$expr"; then
    shift
    ble/util/stackdump "$expr$_ble_term_nl$message"
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
      echo 'ble-assert: command is not specified.' >&2
      flags=e$flags
    fi
  fi
  if [[ $flags == *[eh]* ]]; then
    [[ $flags == *e* ]] && echo
    {
      echo 'usage: ble-assert command [message]'
      echo '  Evaluate command and print stackdump on fail.'
    } >&2
    [[ $flags == *e* ]] && return 2
    return 0
  fi

  ble/util/assert "${args[0]}" "${args[*]:1}"
}

#------------------------------------------------------------------------------
# Event loop

## 関数 ble/util/clock
##   時間を計測するのに使うことができるミリ秒単位の計量な時計です。
##   計測の起点は ble.sh のロード時です。
##   @var[out] ret
_ble_util_clock_base=
_ble_util_clock_reso=
_ble_util_clock_type=
function ble/util/clock/.initialize {
  if ((_ble_bash>=50000)) && [[ $EPOCHREALTIME == *.???* ]]; then
    # implementation with EPOCHREALTIME
    _ble_util_clock_base=$((10#${EPOCHREALTIME%.*}))
    _ble_util_clock_reso=1
    _ble_util_clock_type=EPOCHREALTIME
    function ble/util/clock {
      local now=$EPOCHREALTIME
      local integral=$((10#${now%%.*}-_ble_util_clock_base))
      local mantissa=${now#*.}000; mantissa=${mantissa::3}
      ((ret=integral*1000+10#$mantissa))
    }
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
ble/util/clock/.initialize

if ((_ble_bash>=40000)); then
  ## 設定関数 ble/util/idle/IS_IDLE { ble/util/is-stdin-ready; }
  ##   他にするべき処理がない時 (アイドル時) に終了ステータス 0 を返します。
  ##   Note: この設定関数は ble-decode.sh で上書きされます。
  function ble/util/idle/IS_IDLE { ! ble/util/is-stdin-ready; }

  _ble_util_idle_sclock=0
  function ble/util/idle/.sleep {
    local msec=$1
    ((msec<=0)) && return 0
    local integral=$((msec/1000)) fraction=00$((msec%1000))
    fraction=${fraction:${#fraction}-3}
    local sec=$integral.$fraction
    ble/util/sleep "$sec"
    ((_ble_util_idle_sclock+=msec))
  }

  function ble/util/idle.clock/.initialize {
    function ble/util/idle.clock/.initialize { :; }

    ## 関数 ble/util/idle.clock
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
      ## 関数 ble/util/idle/.adjusted-clock
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

  : ${bleopt_idle_interval:=}
  if [[ ! $bleopt_idle_interval ]]; then
    if ((_ble_bash>50000)) && [[ $_ble_util_sleep_builtin_available ]]; then
      bleopt_idle_interval=20
    else
      bleopt_idle_interval='ble_util_idle_elapsed>600000?500:(ble_util_idle_elapsed>60000?200:(ble_util_idle_elapsed>5000?100:20))'
    fi
  fi

  ## @arr _ble_util_idle_task
  ##   タスク一覧を保持します。各要素は一つのタスクを表し、
  ##   status:command の形式の文字列です。
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

  ## 関数 ble/util/idle.do
  ##   待機状態の処理を開始します。
  ##
  ##   @exit
  ##     待機処理を何かしら実行した時に成功 (0) を返します。
  ##     何も実行しなかった時に失敗 (1) を返します。
  ##
  function ble/util/idle.do {
    local IFS=$' \t\n'
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
        ble/util/idle/IS_IDLE || { [[ $_idle_processed ]]; return; }
        local _idle_to_process=
        local _idle_status=${_ble_util_idle_task[_idle_key]%%:*}
        case ${_idle_status::1} in
        (R) _idle_to_process=1 ;;
        (I) [[ $_idle_is_first ]] && _idle_to_process=1 ;;
        (S) ble/util/idle/.check-clock "$_idle_status" && _idle_to_process=1 ;;
        (W) ble/util/idle/.check-clock "$_idle_status" && _idle_to_process=1 ;;
        (F) [[ -s ${_idle_status:1} ]] && _idle_to_process=1 ;;
        (E) [[ -e ${_idle_status:1} ]] && _idle_to_process=1 ;;
        (P) ! kill -0 ${_idle_status:1} &>/dev/null && _idle_to_process=1 ;;
        (C) eval -- "${_idle_status:1}" && _idle_to_process=1 ;;
        (*) unset -v '_ble_util_idle_task[_idle_key]'
        esac

        if [[ $_idle_to_process ]]; then
          local _idle_command=${_ble_util_idle_task[_idle_key]#*:}
          _idle_processed=1
          ble/util/idle.do/.call-task "$_idle_command"
          (($?==148)) && return 0
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
  ## 関数 ble/util/idle.do/.call-task command
  ##   @var[in,out] _idle_next_time
  ##   @var[in,out] _idle_next_itime
  ##   @var[in,out] _idle_running
  ##   @var[in,out] _idle_waiting
  function ble/util/idle.do/.call-task {
    local _command=$1
    local ble_util_idle_status=
    local ble_util_idle_elapsed=$((_ble_util_idle_sclock-_idle_start))
    builtin eval "$_command"; local ext=$?
    if ((ext==148)); then
      _ble_util_idle_task[_idle_key]=R:$_command
    elif [[ $ble_util_idle_status ]]; then
      _ble_util_idle_task[_idle_key]=$ble_util_idle_status:$_command
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
      unset -v '_ble_util_idle_task[_idle_key]'
    fi
    return "$ext"
  }
  ## 関数 ble/util/idle/.check-clock status
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
  ## 関数 ble/util/idle.do/.sleep-until-next
  ##   @var[in] _idle_next_time
  ##   @var[in] _idle_next_itime
  ##   @var[in] _idle_running
  ##   @var[in] _idle_waiting
  function ble/util/idle.do/.sleep-until-next {
    ble/util/idle/IS_IDLE || return 148
    [[ $_idle_running ]] && return
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
    ble/util/idle.push/.impl 0 "R:$*"
  }
  function ble/util/idle.push-background {
    ble/util/idle.push/.impl 10000 "R:$*"
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
## 関数 ble/util/fiberchain#push fiber...
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

## 関数 bleopt args...
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
  local error_flag=
  local -a pvars
  if (($#==0)); then
    pvars=("${!bleopt_@}")
  else
    local spec var type= value= ip=0
    pvars=()
    for spec; do
      if [[ $spec == *:=* ]]; then
        type=a var=${spec%%:=*} value=${spec#*:=}
      elif [[ $spec == *=* ]]; then
        type=ac var=${spec%%=*} value=${spec#*=}
      else
        type=p var=$spec
      fi

      var=bleopt_${var#bleopt_}
      if [[ $type == *c* && ! ${!var+set} ]]; then
        error_flag=1
        echo "bleopt: unknown bleopt option \`${var#bleopt_}'" >&2
        continue
      fi

      case "$type" in
      (a*)
        [[ ${!var} == "$value" ]] && continue
        if ble/is-function bleopt/check:"${var#bleopt_}"; then
          if ! bleopt/check:"${var#bleopt_}"; then
            error_flag=1
            continue
          fi
        fi
        eval "$var=\"\$value\"" ;;
      (p*) pvars[ip++]=$var ;;
      (*)  echo "bleopt: unknown type '$type' of the argument \`$spec'" >&2 ;;
      esac
    done
  fi

  if ((${#pvars[@]})); then
    local q="'" Q="'\''" var
    for var in "${pvars[@]}"; do
      if [[ ${!var+set} ]]; then
        builtin printf '%s\n' "bleopt ${var#bleopt_}='${!var//$q/$Q}'"
      else
        builtin printf '%s\n' "bleopt: invalid ble option name '${var#bleopt_}'" >&2
      fi
    done
  fi

  [[ ! $error_flag ]]
}

#------------------------------------------------------------------------------
# **** terminal controls ****

: ${bleopt_vbell_default_message=' Wuff, -- Wuff!! '}
: ${bleopt_vbell_duration=2000}

function ble-term/.initialize {
  if [[ $_ble_base/lib/init-term.sh -nt $_ble_base_cache/$TERM.term ]]; then
    source "$_ble_base/lib/init-term.sh"
  else
    source "$_ble_base_cache/$TERM.term"
  fi

  ble/string#reserve-prototype "$_ble_term_it"
}

ble-term/.initialize

function ble-term/put {
  BUFF[${#BUFF[@]}]=$1
}
function ble-term/cup {
  local x=$1 y=$2 esc=$_ble_term_cup
  esc=${esc//'%x'/$x}
  esc=${esc//'%y'/$y}
  esc=${esc//'%c'/$((x+1))}
  esc=${esc//'%l'/$((y+1))}
  BUFF[${#BUFF[@]}]=$esc
}
function ble-term/flush {
  IFS= builtin eval 'builtin echo -n "${BUFF[*]}"'
  BUFF=()
}

# **** vbell/abell ****

function ble/term/visible-bell/.initialize {
  _ble_term_visible_bell__ftime=$_ble_base_run/$$.visible-bell.time

  local -a BUFF=()
  ble-term/put "$_ble_term_ri$_ble_term_sc$_ble_term_sgr0"
  ble-term/cup 0 0
  ble-term/put "$_ble_term_el%message%$_ble_term_sgr0$_ble_term_rc${_ble_term_cud//'%d'/1}"
  IFS= builtin eval '_ble_term_visible_bell_show="${BUFF[*]}"'
  
  BUFF=()
  ble-term/put "$_ble_term_sc$_ble_term_sgr0"
  ble-term/cup 0 0
  ble-term/put "$_ble_term_el2$_ble_term_rc"
  IFS= builtin eval '_ble_term_visible_bell_clear="${BUFF[*]}"'
}

ble/term/visible-bell/.initialize


function ble/term/audible-bell {
  builtin echo -n '' 1>&2
}
function ble/term/visible-bell {
  local _count=$((++_ble_term_visible_bell__count))
  local cols=${COLUMNS:-80}
  local message="$*"
  message=${message:-$bleopt_vbell_default_message}

  builtin echo -n "${_ble_term_visible_bell_show//'%message%'/${_ble_term_setaf[2]}$_ble_term_rev${message::cols}}" >&2
  (
    {
      # Note: ble/util/assign は使えない。本体の ble/util/assign と一時ファイルが衝突する可能性がある。

      ble/util/sleep 0.05
      builtin echo -n "${_ble_term_visible_bell_show//'%message%'/$_ble_term_rev${message::cols}}" >&2

      # load time duration settings
      declare msec=$bleopt_vbell_duration
      declare sec=$(builtin printf '%d.%03d' $((msec/1000)) $((msec%1000)))

      # wait
      >| "$_ble_term_visible_bell__ftime"
      ble/util/sleep "$sec"

      # check and clear
      declare -a time1 time2
      time1=($(ble/util/getmtime "$_ble_term_visible_bell__ftime"))
      time2=($(ble/bin/date +'%s %N' 2>/dev/null)) # ※ble/util/strftime だとミリ秒まで取れない
      if (((time2[0]-time1[0])*1000+(10#0${time2[1]::3}-10#0${time1[1]::3})>=msec)); then
        builtin echo -n "$_ble_term_visible_bell_clear" >&2
      fi
    } &
  )
}
function ble/term/visible-bell/cancel-erasure {
  >| "$_ble_term_visible_bell__ftime"
}

#---- stty --------------------------------------------------------------------

## 変数 _ble_term_stty_state
##   現在 stty で制御文字の効果が解除されているかどうかを保持します。
_ble_term_stty_state=

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

function ble/term/stty/initialize {
  ble/bin/stty -ixon -echo -nl -icrnl -icanon \
    kill   undef  lnext  undef  werase undef  erase  undef \
    intr   undef  quit   undef  susp   undef
  _ble_term_stty_state=1
}
function ble/term/stty/leave {
  [[ ! $_ble_term_stty_state ]] && return
  ble/bin/stty  echo -nl icanon \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
  _ble_term_stty_state=
}
function ble/term/stty/enter {
  [[ $_ble_term_stty_state ]] && return
  ble/bin/stty -echo -nl -icrnl -icanon \
    kill   undef  lnext  undef  werase undef  erase  undef \
    intr   undef  quit   undef  susp   undef
  _ble_term_stty_state=1
}
function ble/term/stty/finalize {
  [[ ! $_ble_term_stty_state ]] && return
  # detach の場合 -echo を指定する
  ble/bin/stty -echo -nl icanon \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
  _ble_term_stty_state=
}
function ble/term/stty/TRAPEXIT {
  # exit の場合は echo
  ble/bin/stty echo -nl \
    kill   ''  lnext  ''  werase ''  erase  '' \
    intr   ''  quit   ''  susp   ''
}


#---- cursor state ------------------------------------------------------------

: ${bleopt_term_cursor_external=0}

_ble_term_cursor_current=unknown
_ble_term_cursor_internal=0
_ble_term_cursor_hidden_current=unknown
_ble_term_cursor_hidden_internal=reveal
function ble/term/cursor-state/.update {
  local state=$(($1))
  [[ $_ble_term_cursor_current == "$state" ]] && return

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
  [[ $_ble_term_cursor_hidden_current == "$state" ]] && return

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

#---- DA2 ---------------------------------------------------------------------

_ble_term_DA2R=
function ble/term/DA2/notify {
  _ble_term_DA2R=$1
}

#---- SGR(>4): modifyOtherKeys ------------------------------------------------

: ${bleopt_term_modifyOtherKeys_external=auto}
: ${bleopt_term_modifyOtherKeys_internal=auto}

_ble_term_modifyOtherKeys_current=
function ble/term/modifyOtherKeys/.update {
  [[ $1 == "$_ble_term_modifyOtherKeys_current" ]] && return
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
  # libvte は SGR(>4) を直接画面に表示してしまう
  [[ $_ble_term_DA2R == '1;'* ]] && return 1

  # 改造版 Poderosa は通知でウィンドウサイズを毎回変更するので表示が乱れてしまう
  [[ $MWG_LOGINTERM == rosaterm ]] && return 1
}
function ble/term/modifyOtherKeys/enter {
  local value=$bleopt_term_modifyOtherKeys_internal
  if [[ $value == auto ]]; then
    value=2
    # 問題を起こす端末で無効化。
    ble/term/modifyOtherKeys/.supported || value=
  fi
  ble/term/modifyOtherKeys/.update "$bleopt_term_modifyOtherKeys_internal"
}
function ble/term/modifyOtherKeys/leave {
  local value=$bleopt_term_modifyOtherKeys_internal
  if [[ $value == auto ]]; then
    value=1
    # 問題を起こす端末で無効化。
    ble/term/modifyOtherKeys/.supported || value=
  fi
  ble/term/modifyOtherKeys/.update "$bleopt_term_modifyOtherKeys_external"
}

#---- rl variable: convert-meta -----------------------------------------------

_ble_term_rl_convert_meta_adjusted=
_ble_term_rl_convert_meta_external=
function ble/term/rl-convert-meta/enter {
  [[ $_ble_term_rl_convert_meta_adjusted ]] && return
  _ble_term_rl_convert_meta_adjusted=1

  if ble/util/test-rl-variable convert-meta; then
    _ble_term_rl_convert_meta_external=on
    builtin bind 'set convert-meta off'
  else
    _ble_term_rl_convert_meta_external=off
  fi
}
function ble/term/rl-convert-meta/leave {
  [[ $_ble_term_rl_convert_meta_adjusted ]] || return
  _ble_term_rl_convert_meta_adjusted=

  [[ $_ble_term_rl_convert_meta_external == on ]] &&
    builtin bind 'set convert-meta on'
}

#---- terminal enter/leave ----------------------------------------------------

_ble_term_state=external
function ble/term/enter {
  [[ $_ble_term_state == internal ]] && return
  ble/term/stty/enter
  ble/term/bracketed-paste-mode/enter
  ble/term/modifyOtherKeys/enter
  ble/term/cursor-state/.update "$_ble_term_cursor_internal"
  ble/term/cursor-state/.update-hidden "$_ble_term_cursor_hidden_internal"
  ble/term/rl-convert-meta/enter
  _ble_term_state=internal
}
function ble/term/leave {
  [[ $_ble_term_state == external ]] && return
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
  ble/term/enter
}

#------------------------------------------------------------------------------
# String manipulations

_ble_util_s2c_table_enabled=
if ((_ble_bash>=40100)); then
  # - printf "'c" で Unicode が読める (どの LC_CTYPE でも Unicode になる)
  function ble/util/s2c {
    builtin printf -v ret '%d' "'${1:$2:1}"
  }
elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_util_s2c_table
  _ble_util_s2c_table_enabled=1
  function ble/util/s2c {
    [[ $_ble_util_cache_locale != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
      ble/util/.cache/update-locale

    local s=${1:$2:1}
    ret=${_ble_util_s2c_table[x$s]}
    [[ $ret ]] && return

    ble/util/sprintf ret %d "'$s"
    _ble_util_s2c_table[x$s]=$ret
  }
elif ((_ble_bash>=40000)); then
  function ble/util/s2c {
    ble/util/sprintf ret %d "'${1:$2:1}"
  }
else
  # bash-3 では printf %d "'あ" 等としても
  # "あ" を構成する先頭バイトの値が表示されるだけである。
  # 何とかして unicode 値に変換するコマンドを見つけるか、
  # 各バイトを取り出して unicode に変換するかする必要がある。
  # bash-3 では read -n 1 を用いてバイト単位で読み取れる。これを利用する。
  function ble/util/s2c {
    local s=${1:$2:1}
    if [[ $s == [''-''] ]]; then
      ble/util/sprintf ret %d "'$s"
      return
    fi

    local bytes byte
    ble/util/assign bytes '
      while IFS= builtin read -r -n 1 byte; do
        builtin printf "%d " "'\''$byte"
      done <<< "$s"
    '
    "ble/encoding:$bleopt_input_encoding/b2c" $bytes
  }
fi

# ble/util/c2s
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
  if ble/util/.has-bashbug-printf-uffff; then
    function ble/util/c2s-impl {
      if ((0xE000<=$1&&$1<=0xFFFF)) && [[ $_ble_util_cache_ctype == *.utf-8 || $_ble_util_cache_ctype == *.utf8 ]]; then
        builtin printf -v ret '\\x%02x' $((0xE0|$1>>12&0x0F)) $((0x80|$1>>6&0x3F)) $((0x80|$1&0x3F))
      else
        builtin printf -v ret '\\U%08x' "$1"
      fi
      builtin eval "ret=\$'$ret'"
    }
  else
    function ble/util/c2s-impl {
      builtin printf -v ret '\\U%08x' "$1"
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
  function ble/util/c2s-impl {
    if (($1<0x80)); then
      builtin eval "ret=\$'\\x${_ble_text_hexmap[$1]}'"
      return
    fi

    local bytes i iN seq=
    ble/encoding:UTF-8/c2b "$1"
    for ((i=0,iN=${#bytes[@]};i<iN;i++)); do
      seq="$seq\\x${_ble_text_hexmap[bytes[i]&0xFF]}"
    done
    builtin eval "ret=\$'$seq'"
  }
fi

# どうもキャッシュするのが一番速い様だ
_ble_util_c2s_table=()
function ble/util/c2s {
  [[ $_ble_util_cache_locale != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
    ble/util/.cache/update-locale

  ret=${_ble_util_c2s_table[$1]-}
  if [[ ! $ret ]]; then
    ble/util/c2s-impl "$1"
    _ble_util_c2s_table[$1]=$ret
  fi
}

## 関数 ble/util/c2bc
##   gets a byte count of the encoded data of the char
##   指定した文字を現在の符号化方式で符号化した時のバイト数を取得します。
##   @param[in]  $1 = code
##   @param[out] ret
function ble/util/c2bc {
  "ble/encoding:$bleopt_input_encoding/c2bc" "$1"
}

## 関数 ble/util/.cache/update-locale
##
##  使い方
##
##    [[ $_ble_util_cache_locale != "$LC_ALL:$LC_CTYPE:$LANG" ]] &&
##      ble/util/.cache/update-locale
##
_ble_util_cache_locale=
_ble_util_cache_ctype=
function ble/util/.cache/update-locale {
  _ble_util_cache_locale=$LC_ALL:$LC_CTYPE:$LANG

  # clear cache if LC_CTYPE is changed
  local ret; ble/string#tolower "${LC_ALL:-${LC_CTYPE:-$LANG}}"
  if [[ $_ble_util_cache_ctype != "$ret" ]]; then
    _ble_util_cache_ctype=$ret
    _ble_util_c2s_table=()
    [[ $_ble_util_s2c_table_enabled ]] &&
      _ble_util_s2c_table=()
  fi
}

#------------------------------------------------------------------------------

## 関数 ble/encoding:UTF-8/b2c
##   @var[out] ret
function ble/encoding:UTF-8/b2c {
  local bytes b0 n i
  bytes=("$@")
  ret=0
  ((b0=bytes[0]&0xFF,
    n=b0>0xF0
    ?(b0>0xFC?5:(b0>0xF8?4:3))
    :(b0>0xE0?2:(b0>0xC0?1:0)),
    ret=b0&0x3F>>n))
  for ((i=1;i<=n;i++)); do
    ((ret=ret<<6|0x3F&bytes[i]))
  done
}

## 関数 ble/encoding:UTF-8/c2b
##   @var[out] bytes[]
function ble/encoding:UTF-8/c2b {
  local code=$1 n i
  ((code=code&0x7FFFFFFF,
    n=code<0x80?0:(
      code<0x800?1:(
        code<0x10000?2:(
          code<0x200000?3:(
            code<0x4000000?4:5))))))
  if ((n==0)); then
    bytes=(code)
  else
    bytes=()
    for ((i=n;i;i--)); do
      ((bytes[i]=0x80|code&0x3F,
        code>>=6))
    done
    ((bytes[0]=code&0x3F>>n|0xFF80>>n))
  fi
}

function ble/encoding:C/b2c {
  local byte=$1
  ((ret=byte&0xFF))
}
function ble/encoding:C/c2b {
  local code=$1
  bytes=($((code&0xFF)))
}
