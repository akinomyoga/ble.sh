# -*- mode:sh;mode:sh-bash -*-
# bash script to be sourced from interactive shell

## オプション bleopt_input_encoding
: ${bleopt_input_encoding:=UTF-8}

function bleopt/check:input_encoding {
  if ! ble/util/isfunction "ble-decode-byte+$value"; then
    echo "bleopt: Invalid value input_encoding='$value'. A function 'ble-decode-byte+$value' is not defined." >&2
    return 1
  elif ! ble/util/isfunction "ble-text-b2c+$value"; then
    echo "bleopt: Invalid value input_encoding='$value'. A function 'ble-text-b2c+$value' is not defined." >&2
    return 1
  elif ! ble/util/isfunction "ble-text-c2bc+$value"; then
    echo "bleopt: Invalid value input_encoding='$value'. A function 'ble-text-c2bc+$value' is not defined." >&2
    return 1
  fi
}


## オプション bleopt_stackdump_enabled
##   エラーが起こった時に関数呼出の構造を標準エラー出力に出力するかどうかを制御する。
##   算術式評価によって非零の値になる場合にエラーを出力する。
##   それ以外の場合にはエラーを出力しない。
: ${bleopt_stackdump_enabled=0}

## オプション bleopt_openat_base
##   bash-4.1 未満で exec {var}>foo が使えない時に ble.sh で内部的に fd を割り当てる。
##   この時の fd の base を指定する。bleopt_openat_base, bleopt_openat_base+1, ...
##   という具合に順番に使用される。既定値は 30 である。
: ${bleopt_openat_base:=30}

shopt -s checkwinsize

#------------------------------------------------------------------------------
# util

ble_util_upvar_setup='local var=ret ret; [[ $1 == -v ]] && var="$2" && shift 2'
ble_util_upvar='local "${var%%\[*\]}" && ble/util/upvar "$var" "$ret"'
function ble/util/upvar { builtin unset "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
function ble/util/uparr { builtin unset "$1" && builtin eval "$1=(\"\${@:2}\")"; }

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

#
# array and strings
#

_ble_util_array_prototype=()
function _ble_util_array_prototype.reserve {
  local -i n="$1" i
  for ((i=${#_ble_util_array_prototype[@]};i<n;i++)); do
    _ble_util_array_prototype[i]=
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
function ble/is-array { compgen -A arrayvar -X \!"$1" "$1" &>/dev/null; }

## 関数 ble/array#push arr value...
if ((_ble_bash>=30100)); then
  function ble/array#push {
    builtin eval "$1+=(\"\${@:2}\")"
  }
else
  function ble/array#push {
    while
      builtin eval "$1[\${#$1[@]}]=\"\$2\""
      (($#>=3))
    do
      set -- "$1" "${@:3}"
    done
  }
fi
## 関数 ble/array#reverse arr
function ble/array#reverse {
  builtin eval "
  set -- \"\${$1[@]}\"; $1=()
  local e$1 i$1=\$#
  for e$1; do $1[--i$1]=\"\$e$1\"; done"
}

_ble_util_string_prototype='        '
function _ble_util_string_prototype.reserve {
  local -i n="$1" c
  for ((c=${#_ble_util_string_prototype};c<n;c*=2)); do
    _ble_util_string_prototype="$_ble_util_string_prototype$_ble_util_string_prototype"
  done
}

## 関数 ble/string#repeat str count
##   @param[in] str
##   @param[in] count
##   @var[out] ret
function ble/string#repeat {
  _ble_util_string_prototype.reserve "$2"
  ret="${_ble_util_string_prototype::$2}"
  ret="${ret// /$1}"
}

## 関数 ble/string#common-prefix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-prefix {
  local a="$1" b="$2"
  ((${#a}>${#b})) && local a="$b" b="$a"
  b="${b::${#a}}"
  if [[ $a == $b ]]; then
    ret="$a"
    return
  fi

  # l <= 解 < u, (${a:u}: 一致しない, ${a:l} 一致する)
  local l=0 u="${#a}" m
  while ((l+1<u)); do
    ((m=(l+u)/2))
    if [[ ${a::m} == ${b::m} ]]; then
      ((l=m))
    else
      ((u=m))
    fi
  done

  ret="${a::l}"
}

## 関数 ble/string#common-suffix a b
##   @param[in] a b
##   @var[out] ret
function ble/string#common-suffix {
  local a="$1" b="$2"
  ((${#a}>${#b})) && local a="$b" b="$a"
  b="${b:${#b}-${#a}}"
  if [[ $a == $b ]]; then
    ret="$a"
    return
  fi

  # l < 解 <= u, (${a:l}: 一致しない, ${a:u} 一致する)
  local l=0 u="${#a}" m
  while ((l+1<u)); do
    ((m=(l+u+1)/2))
    if [[ ${a:m} == ${b:m} ]]; then
      ((u=m))
    else
      ((l=m))
    fi
  done

  ret="${a:u}"
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
  if shopt -q nullglob &>/dev/null; then
    # Note: GLOBIGNORE を設定していても nullglob の効果は有効である。
    #   この時 [..] や * や ? が一文字でも含まれるとその要素は必ず消滅する。
    # Note: 末尾の sep が無視されない様に、末尾に手で sep を 1 個追加している。
    shopt -u nullglob
    GLOBIGNORE='*' IFS=$2 builtin eval "$1=(\${*:3}\$2)"
    shopt -s nullglob
  else
    GLOBIGNORE='*' IFS=$2 builtin eval "$1=(\${*:3}\$2)"
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
  local text=$*
  local -a buff ch
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
  IFS= eval 'ret=${buff[*]}'
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
    IFS= eval 'ret=${buff[*]}'
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
    IFS= eval 'ret=${buff[*]}'
  }
fi

function ble/string#escape-for-sed-regex {
  ret="$*"
  if [[ $ret == *['\.[*^$/']* ]]; then
    local a b
    for a in \\ \. \[ \* \^ \$ \/; do
      b="\\$a" ret="${ret//"$a"/$b}"
    done
  fi
}
function ble/string#escape-for-bash-regex {
  ret="$*"
  if [[ $ret == *['\.[*?+^$(){}']* ]]; then
    local a b
    for a in \\ \. \[ \* \? \+ \^ \$ \( \) \{ \}; do
      b="\\$a" ret="${ret//"$a"/$b}"
    done
  fi
}

#
# miscallaneous utils
#

## 関数 ble/util/readfile var filename
##   ファイルの内容を変数に読み取ります。
##
##   @param[in] var
##     読み取った内容の格納先の変数名を指定します。
##   @param[in] filename
##     読み取るファイルの場所を指定します。
##
function ble/util/readfile {
  IFS= read -r -d '' "$1" < "$2"
}


## 関数 ble/util/assign var command...
##   var=$(command ...) の高速な代替です。
##   command はサブシェルではなく現在のシェルで実行されます。
##
##   @param[in] var
##     代入先の変数名を指定します。
##   @param[in] command...
##     実行するコマンドを指定します。
##
_ble_util_read_stdout_tmp="$_ble_base_tmp/$$.ble_util_assign.tmp"
function ble/util/assign {
  builtin eval "${@:2}" >| "$_ble_util_read_stdout_tmp"
  local _ret="$?"
  IFS= read -r -d '' "$1" < "$_ble_util_read_stdout_tmp"
  return "$_ret"
}

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

function ble/util/type {
  _cmd="$2" ble/util/assign "$1" 'builtin type -t "$_cmd" 2>/dev/null'
  builtin eval "$1=\"\${$1%$_ble_term_nl}\""
}

if ((_ble_bash>=30200)); then
  function ble/util/isfunction {
    builtin declare -F "$1" &>/dev/null
  }
else
  # bash-3.1 has bug in declare -f.
  # it does not accept a function name containing non-alnum chars.
  function ble/util/isfunction {
    local type
    ble/util/type type "$1"
    [[ $type == function ]]
  }
fi

if ((_ble_bash>=40000)); then
  function ble/util/is-stdin-ready { IFS= LC_ALL=C read -t 0; } &>/dev/null
else
  function ble/util/is-stdin-ready { false; }
fi

# exec {var}>foo
if ((_ble_bash>=40100)); then
  function ble/util/openat {
    local _fdvar="$1" _redirect="$2"
    builtin eval "exec {$_fdvar}$_redirect"
  }
else
  _ble_util_openat_nextfd="$bleopt_openat_base"
  function ble/util/openat {
    local _fdvar="$1" _redirect="$2"
    (($_fdvar=_ble_util_openat_nextfd++))
    builtin eval "exec ${!_fdvar}$_redirect"
  }
fi

function ble/util/declare-print-definitions {
  if [[ $# -gt 0 ]]; then
    declare -p "$@" | command awk -v _ble_bash="$_ble_bash" '
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

# 正規表現は _ble_bash>=30000
_ble_rex_isprint='^[ -~]+'
## 関数 ble/util/isprint+ str
##
##   @var[out] BASH_REMATCH ble-exit/text/update/position で使用する。
function ble/util/isprint+ {
  # LC_COLLATE=C ...  &>/dev/null for cygwin collation
  LC_COLLATE=C ble/util/isprint+.impl "$@" &>/dev/null
}
function ble/util/isprint+.impl {
  [[ $1 =~ $_ble_rex_isprint ]]
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
      local _result="$(command date +"$3" $4)"
      builtin eval "$2=\"\$_result\""
    else
      command date +"$1" $2
    fi
  }
fi

if ((_ble_bash>=40000)); then
  # 遅延初期化
  _ble_util_sleep_fd=
  _ble_util_sleep_tmp=
  function ble/util/sleep {
    function ble/util/sleep { local REPLY=; ! read -u "$_ble_util_sleep_fd" -t "$1"; } &>/dev/null

    if [[ $OSTYPE == cygwin* ]]; then
      # Cygwin work around

      ble/util/openat _ble_util_sleep_fd '< <(
        [[ $- == *i* ]] && trap -- '' INT QUIT
        while kill -0 $$; do command sleep 300; done &>/dev/null
      )'
    else
      _ble_util_sleep_tmp="$_ble_base_tmp/$$.ble_util_sleep.pipe"
      if [[ ! -p $_ble_util_sleep_tmp ]]; then
        [[ -e $_ble_util_sleep_tmp ]] && command rm -rf "$_ble_util_sleep_tmp"
        command mkfifo "$_ble_util_sleep_tmp"
      fi
      ble/util/openat _ble_util_sleep_fd "<> $_ble_util_sleep_tmp"
    fi

    ble/util/sleep "$1"
  }
elif type sleepenh &>/dev/null; then
  function ble/util/sleep { command sleepenh "$1" &>/dev/null; }
elif type usleep &>/dev/null; then
  function ble/util/sleep {
    if [[ $1 == *.* ]]; then
      local sec=${1%%.*} sub=${1#*.}000000
      if (($sec)); then
        command usleep "$sec${sub::6}"
      else
        command usleep "$((10#${sub::6}))"
      fi
    else
      command usleep "${1}000000"
    fi
  }
else
  function ble/util/sleep { command sleep "$1"; }
fi

## 関数 ble/util/cat
##   cat の代替。但し、ファイル内に \0 が含まれる場合は駄目。
function ble/util/cat {
  local content=
  if [[ $1 && $1 != - ]]; then
    IFS= read -r -d '' content < "$1"
  else
    IFS= read -r -d '' content
  fi
  echo -n "$content"
}

_ble_util_less_fallback=
function ble/util/less {
  if [[ ! $_ble_util_less_fallback ]]; then
    if type less &>/dev/null; then
      _ble_util_less_fallback=less
    elif type more &>/dev/null; then
      _ble_util_less_fallback=more
    else
      _ble_util_less_fallback=cat
    fi
  fi

  "${PAGER:-$_ble_util_less_fallback}"
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
ble/util/isfunction ble/util/getmtime ||
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
  IFS= builtin eval 'builtin echo -n "${_ble_util_buffer[*]}"'
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
    _prefix="${1#--prefix=}"
    ((beg=${_prefix}beg,
      end=${_prefix}end,
      end0=${_prefix}end0))
  fi
}

function ble/dirty-range#clear {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
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
    _prefix="${1#--prefix=}"
    shift
    [[ $_prefix ]] && local beg end end0
  fi

  local begB="$1" endB="$2" endB0="$3"
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
  ble/util/assign jobs0 jobs
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
  ble/util/joblist.split list "${lines[@]}"

  # check changed jobs from _ble_util_joblist_list to list
  if [[ $jobs0 != "$_ble_util_joblist_jobs" ]]; then
    for ijob in "${!list[@]}"; do
      if [[ ${_ble_util_joblist_list[ijob]} && ${list[ijob]#'['*']'[-+ ]} != "${_ble_util_joblist_list[ijob]#'['*']'[-+ ]}" ]]; then
        ble/array#push _ble_util_joblist_events "${list[ijob]}"
        list[ijob]=
      fi
    done
  fi

  ble/util/assign _ble_util_joblist_jobs jobs
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
      _ble_util_joblist_list[ijob]="${list[ijob]}"
    done
  fi
  joblist=("${_ble_util_joblist_list[@]}")
} 2>/dev/null

function ble/util/joblist.split {
  local arr="$1"; shift
  local line ijob rex_ijob='^\[([0-9]+)\]'
  for line; do
    [[ $line =~ $rex_ijob ]] && ijob="${BASH_REMATCH[1]}"
    [[ $ijob ]] && eval "$arr[ijob]=\"\${$arr[ijob]}\${$arr[ijob]:+\$_ble_term_nl}\$line\""
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
#------------------------------------------------------------------------------


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
function ble-autoload {
  local apos="'" APOS="'\\''" file="$1" funcname
  shift

  # ※$FUNCNAME は元から環境変数に設定されている場合、
  #   特別変数として定義されない。
  #   この場合無闇にコマンドとして実行するのは危険である。

  for funcname in "$@"; do
    builtin eval "function $funcname {
      unset -f $funcname
      ble-load '${file//$apos/$APOS}'
      $funcname \"\$@\"
    }"
  done
}
function ble-load {
  local file="$1"
  if [[ $file == /* ]]; then
    source "$file"
  elif [[ -f $_ble_base/local/$file ]]; then
    source "$_ble_base/local/$file"
  elif [[ -f $_ble_base/share/$file ]]; then
    source "$_ble_base/share/$file"
  else
    return 1
  fi
}

_ble_stackdump_title=stackdump
function ble-stackdump {
  ((bleopt_stackdump_enabled)) || return
  # builtin echo "${BASH_SOURCE[1]} (${FUNCNAME[1]}): assertion failure $*" >&2
  local i nl=$'\n'
  local message="$_ble_term_sgr0$_ble_stackdump_title: $*$nl"
  for ((i=1;i<${#FUNCNAME[*]};i++)); do
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i]} (${FUNCNAME[i]})$nl"
  done
  builtin echo -n "$message" >&2
}
function ble-assert {
  local expr="$1"
  local _ble_stackdump_title='assertion failure'
  if ! builtin eval -- "$expr"; then
    shift
    ble-stackdump "$expr$_ble_term_nl$*"
    return 1
  else
    return 0
  fi
}

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
        if ble/util/isfunction bleopt/check:"${var#bleopt_}"; then
          if ! bleopt/check:"${var#bleopt_}"; then
            error_flag=1
            continue
          fi
        fi
        eval "$var=\"\$value\"" ;;
      (p*) pvars[ip++]="$var" ;;
      (*)  echo "bleopt: unknown type '$type' of the argument \`$spec'" >&2 ;;
      esac
    done
  fi

  if ((${#pvars[@]})); then
    local q="'" Q="'\''" var
    for var in "${pvars[@]}"; do
      builtin printf '%s\n' "${var#bleopt_}='${!var//$q/$Q}'"
    done
  fi

  [[ ! $error_flag ]]
}

#------------------------------------------------------------------------------
# **** terminal controls ****

: ${bleopt_vbell_default_message=' Wuff, -- Wuff!! '}
: ${bleopt_vbell_duration=2000}

function ble-term/.initialize {
  if [[ $_ble_base/term.sh -nt $_ble_base_cache/$TERM.term ]]; then
    source "$_ble_base/term.sh"
  else
    source "$_ble_base_cache/$TERM.term"
  fi

  _ble_util_string_prototype.reserve "$_ble_term_it"
}

ble-term/.initialize

function ble-term/put {
  BUFF[${#BUFF[@]}]="$1"
}
function ble-term/cup {
  local x="$1" y="$2" esc="$_ble_term_cup"
  esc="${esc//'%x'/$x}"
  esc="${esc//'%y'/$y}"
  esc="${esc//'%c'/$((x+1))}"
  esc="${esc//'%l'/$((y+1))}"
  BUFF[${#BUFF[@]}]="$esc"
}
function ble-term/flush {
  IFS= builtin eval 'builtin echo -n "${BUFF[*]}"'
  BUFF=()
}

# **** vbell/abell ****

function _ble_base_tmp.wipe {
  local file pid mark removed
  mark=() removed=()
  for file in "$_ble_base_tmp"/[1-9]*.*; do
    [[ -e $file ]] || continue
    pid=${file##*/}; pid=${pid%%.*}
    [[ ${mark[pid]} ]] && continue
    mark[pid]=1
    if ! kill -0 "$pid" &>/dev/null; then
      removed=("${removed[@]}" "$_ble_base_tmp/$pid."*)
    fi
  done
  ((${#removed[@]})) && command rm -f "${removed[@]}"
}

# initialization time = 9ms (for 70 files)
_ble_base_tmp.wipe

function ble-term/visible-bell/.initialize {
  _ble_term_visible_bell__ftime="$_ble_base_tmp/$$.visible-bell.time"

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

ble-term/visible-bell/.initialize


function ble-term/audible-bell {
  builtin echo -n '' 1>&2
}
function ble-term/visible-bell {
  local _count=$((++_ble_term_visible_bell__count))
  local cols="${LINES:-25}"
  local lines="${COLUMNS:-80}"
  local message="$*"
  message="${message:-$bleopt_vbell_default_message}"

  builtin echo -n "${_ble_term_visible_bell_show//'%message%'/${_ble_term_setaf[2]}$_ble_term_rev${message::cols}}" >&2
  (
    {
      # Note: ble/util/assign は使えない。本体の ble/util/assign と一時ファイルが衝突する可能性がある。

      ble/util/sleep 0.05
      builtin echo -n "${_ble_term_visible_bell_show//'%message%'/$_ble_term_rev${message::cols}}" >&2

      # load time duration settings
      declare msec=$bleopt_vbell_duration
      declare sec=$(builtin printf '%d.%03d' "$((msec/1000))" "$((msec%1000))")

      # wait
      >| "$_ble_term_visible_bell__ftime"
      ble/util/sleep "$sec"

      # check and clear
      declare -a time1 time2
      time1=($(ble/util/getmtime "$_ble_term_visible_bell__ftime"))
      time2=($(command date +'%s %N' 2>/dev/null)) # ※ble/util/strftime だとミリ秒まで取れない
      if (((time2[0]-time1[0])*1000+(10#0${time2[1]::3}-10#0${time1[1]::3})>=msec)); then
        builtin echo -n "$_ble_term_visible_bell_clear" >&2
      fi
    } &
  )
}
function ble-term/visible-bell/cancel-erasure {
  >| "$_ble_term_visible_bell__ftime"
}
#------------------------------------------------------------------------------
# String manipulations

if ((_ble_bash>=40100)); then
  # - printf "'c" で unicode が読める
  function ble/util/s2c {
    builtin printf -v ret '%d' "'${1:$2:1}"
  }
elif ((_ble_bash>=40000&&_ble_bash_loaded_in_function&&!_ble_bash_loaded_in_function)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_text_s2c_table
  function ble/util/s2c {
    local s=${1:$2:1}
    ret=${_ble_text_s2c_table[x$s]}
    [[ $ret ]] && return

    ble/util/sprintf ret %d "'$s"
    _ble_text_s2c_table[x$s]=$ret
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
      while IFS= read -r -n 1 byte; do
        builtin printf "%d " "'\''$byte"
      done <<< "$s"
    '
    "ble-text-b2c+$bleopt_input_encoding" $bytes
  }
fi

function ble-text.s2c {
  local _var="$ret"
  if [[ $1 == -v && $# -ge 3 ]]; then
    local ret
    ble/util/s2c "$3" "$4"
    (($2=ret))
  else
    ble/util/s2c "$@"
  fi
}

# ble/util/c2s
if ((_ble_bash>=40200)); then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.

  # work arounds of bashbug that printf '\uFFFF' results in a broken surrogate
  # pair in systems where sizeof(wchar_t) == 2.
  function ble/util/.has-bashbug-printf-uffff {
    ((40200<=_ble_bash&&_ble_bash<40500)) || return 1
    local ret
    builtin printf -v ret '\uFFFF'
    ((${#ret}==2))
  }
  if ble/util/.has-bashbug-printf-uffff; then
    function ble/util/c2s-impl {
      if ((0xE000<=$1&&$1<=0xFFFF)); then
        builtin printf -v ret '\\x%02x' "$((0xE0|$1>>12&0x0F))" "$((0x80|$1>>6&0x3F))" "$((0x80|$1&0x3F))"
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
    _ble_text_hexmap[i]="${_ble_text_xdigit[i>>4&0xF]}${_ble_text_xdigit[i&0xF]}"
  done

  # 動作確認済 3.1, 3.2, 4.0, 4.2, 4.3
  function ble/util/c2s-impl {
    if (($1<0x80)); then
      builtin eval "ret=\$'\\x${_ble_text_hexmap[$1]}'"
      return
    fi

    local bytes i iN seq=
    ble-text-c2b+UTF-8 "$1"
    for ((i=0,iN=${#bytes[@]};i<iN;i++)); do
      seq="$seq\\x${_ble_text_hexmap[bytes[i]&0xFF]}"
    done
    builtin eval "ret=\$'$seq'"
  }
fi


# どうもキャッシュするのが一番速い様だ
_ble_text_c2s_table=()
function ble/util/c2s {
  ret="${_ble_text_c2s_table[$1]}"
  if [[ ! $ret ]]; then
    ble/util/c2s-impl "$1"
    _ble_text_c2s_table[$1]="$ret"
  fi
}

## 関数 ble-text-c2bc
##   gets a byte count of the encoded data of the char
##   指定した文字を現在の符号化方式で符号化した時のバイト数を取得します。
##   @param[in]  $1 = code
##   @param[out] ret
function ble-text-c2bc {
  "ble-text-c2bc+$bleopt_input_encoding" "$1"
}

#------------------------------------------------------------------------------

## 関数 ble-text-b2c+UTF-8
##   @var[out] ret
function ble-text-b2c+UTF-8 {
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

## 関数 ble-text-c2b+UTF-8
##   @var[out] bytes[]
function ble-text-c2b+UTF-8 {
  local code="$1" n i
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

function ble-text-b2c+C {
  local -i byte="$1"
  ((ret=byte&0xFF))
}
function ble-text-c2b+C {
  local -i code="$1"
  bytes=($((code&0xFF)))
}
