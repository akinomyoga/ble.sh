# -*- mode:sh;mode:sh-bash -*-
# bash script to be sourced from interactive shell

## オプション bleopt_input_encoding
: ${bleopt_input_encoding:=UTF-8}

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

function ble/string#repeat {
  _ble_util_string_prototype.reserve "$2"
  ret="${_ble_util_string_prototype::$2}"
  ret="${ret// /$1}"
}

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
## 関数 ble/string#split arr split str...
##   文字列を分割します。
##   @var[out] arr   分割した文字列を格納する配列名を指定します。
##   @var[in]  split 分割に使用する文字を指定します。
##   @var[in]  str   分割する文字列を指定します。
function ble/string#split {
  GLOBIGNORE='*' IFS="$2" builtin eval "$1=(\${*:3})"
}

#
# miscallaneous utils
#

## 関数 ble/util/assign
_ble_util_read_stdout_tmp="$_ble_base_tmp/$$.ble_util_assign.tmp"
# function ble/util/assign { builtin eval "$1=\"\$(${@:2})\""; }
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
    local -a _args
    _args=("${@:2}")
    ble/util/assign "$1" 'builtin printf "${_args[@]}"'
  }
fi

function ble/util/upvar { builtin unset "${1%%\[*\]}" && builtin eval "$1=\"\$2\""; }
function ble/util/uparr { builtin unset "$1" && builtin eval "$1=(\"\${@:2}\")"; }

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
  function ble/util/is-stdin-ready { IFS= LC_ALL=C read -t 0; }
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
      BEGIN{decl="";}
      function declflush( isArray){
        if(decl){
          isArray=(decl~/declare +-[fFgilrtux]*[aA]/);

          # bash-3.0 の declare -p は改行について誤った出力をする。
          if(_ble_bash<30100)gsub(/\\\n/,"\n",decl);

          # declare 除去
          sub(/^declare +(-[-aAfFgilrtux]+ +)?(-- +)?/,"",decl);
          if(isArray){
            if(decl~/^([[:alpha:]_][[:alnum:]_]*)='\''\(.*\)'\''$/){
              sub(/='\''\(/,"=(",decl);
              sub(/\)'\''$/,")",decl);
              gsub(/'\'\\\\\'\''/,"'\''",decl);
            }
          }
          print decl;
          decl="";
        }
      }
      /^declare /{
        declflush();
        decl=$0;
        next;
      }
      {decl=decl "\n" $0;}
      END{declflush();}
    '
  fi
}

# 正規表現は _ble_bash>=30000
_ble_rex_isprint='^[ -~]+'
function ble/util/isprint+ {
  local LC_COLLATE=C # for cygwin collation
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
        while :; do command sleep 2147483647; done &>/dev/null
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

## 関数 ble/util/joblist.clear
##   bash 自身によってジョブ状態変化が出力される場合には比較用のバッファを clear する。
function ble/util/joblist.clear {
  _ble_util_joblist_jobs=
  _ble_util_joblist_list=()
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

function bleopt {
  local -a pvars
  if (($#==0)); then
    pvars=("${!bleopt_@}")
  else
    local spec var value ip=0
    pvars=()
    for spec in "$@"; do
      if [[ $spec == *=* ]]; then
        var="${spec%%=*}"
        var="bleopt_${var#bleopt_}"
        value="${spec#*=}"
        if eval "[[ \${$var+set} ]]"; then
          eval "$var=\"\$value\""
        else
          echo "bleopt: unknown bleopt option \`${var#bleopt_}'"
        fi
      else
        var="bleopt_${spec#bleopt_}"
        if [[ ${!var+set} ]]; then
          pvars[ip++]="$var"
        else
          echo "bleopt: unknown bleopt option \`${var#bleopt_}'"
        fi
      fi
    done
  fi

  if ((${#pvars[@]})); then
    local q="'" Q="'\''" var
    for var in "${pvars[@]}"; do
      echo "${var#bleopt_}='${!var//$q/$Q}'"
    done
  fi
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
elif ((_ble_bash>=40000)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_text_s2c_table
  function ble/util/s2c {
    local s="${1:$2:1}"
    ret="${_ble_text_s2c_table[x$s]}"
    [[ $ret ]] && return

    ret=$(builtin printf '%d' "'${1:$2:1}")
    _ble_text_s2c_table[x$s]="$ret"
  }
else
  # bash-3 では printf %d "'あ" 等としても
  # "あ" を構成する先頭バイトの値が表示されるだけである。
  # 何とかして unicode 値に変換するコマンドを見つけるか、
  # 各バイトを取り出して unicode に変換するかする必要がある。
  # bash-3 では read -n 1 を用いてバイト単位で読み取れる。これを利用する。
  function ble/util/s2c {
    local s="${1:$2:1}"
    if [[ $s == [''-''] ]]; then
      ret=$(builtin printf '%d' "'$s")
      return
    fi

    "ble-text-b2c+$bleopt_input_encoding" $(
      while IFS= read -r -n 1 byte; do
        builtin printf '%d ' "'$byte"
      done <<<$s
    )
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
declare -a _ble_text_c2s_table
function ble/util/c2s {
  ret="${_ble_text_c2s_table[$1]}"
  if [[ ! $ret ]]; then
    ble/util/c2s-impl "$1"
    _ble_text_c2s_table[$1]="$ret"
  fi
}

## gets a byte count of the encoded data of the char
## 指定した文字を現在の符号化方式で符号化した時のバイト数を取得します。
## \param [in]  $1 = code
## \param [out] ret
function ble-text-c2bc {
  "ble-text-c2bc+$bleopt_input_encoding" "$1"
}

#------------------------------------------------------------------------------

## @var[out] ret
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

## @var[out] bytes[]
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
