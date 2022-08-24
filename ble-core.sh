# -*- mode:sh;mode:sh-bash -*-
# bash script to be sourced from interactive shell

: ${bleopt_input_encoding:=UTF-8}


## オプション bleopt_openat_base
##   bash-4.1 未満で exec {var}>foo が使えない時に ble.sh で内部的に fd を割り当てる。
##   この時の fd の base を指定する。bleopt_openat_base, bleopt_openat_base+1, ...
##   という具合に順番に使用される。既定値は 30 である。
: ${bleopt_openat_base:=30}

shopt -s checkwinsize

#------------------------------------------------------------------------------
# util

function ble/util/unlocal { builtin unset "$@"; }

_ble_util_read_stdout_tmp="$_ble_base_tmp/$$.read-stdout.tmp"
# function ble/util/assign { builtin eval "$1=\"\$(${@:2})\""; }
function ble/util/assign {
  builtin eval "${@:2}" > "$_ble_util_read_stdout_tmp"
  local _ret="$?"
  TMOUT= IFS= read -r -d '' "$1" < "$_ble_util_read_stdout_tmp"
  return "$_ret"
}

if ((_ble_bash>=40000)); then
  function ble/util/is-stdin-ready {
    local IFS= LC_ALL= LC_CTYPE=C
    read -t 0
  } 2>/dev/null
else
  function ble/util/is-stdin-ready { false; }
fi

# Note: BASHPID は Bash-4.0 以上
if ((_ble_bash>=40000)); then
  function ble/util/is-running-in-subshell { [[ $$ != $BASHPID ]]; }
else
  function ble/util/is-running-in-subshell {
    ((BASH_SUBSHELL)) && return 0
    local bashpid= command='echo $PPID'
    ble/util/assign bashpid 'sh -c "$command"'
    [[ $$ != $bashpid ]]
  }
fi

## 関数 ble/builtin/trap/set-readline-signal sig handler
##   ble.sh 内部で使用するハンドラを登録します。
##
##   Note #D1345: ble.sh の内部で "builtin trap -- WINCH" 等とすると
##   readline の処理が行われなくなってしまう (COLUMNS, LINES が更新さ
##   れない)。
##
##   Bash では TSTP, TTIN, TTOU, INT, TERM, HUP, QUIT, WINCH について
##   は readline が処理を追加している。builtin trap を実行すると、一旦
##   は trap の設定した trap_handler が設定されるが、"コマンド実行後"
##   に readline が rl_maybe_set_sighandler という関数を用いて上書きし
##   てreadline 特有の処理を挿入する。ble.sh は readline の "コマンド
##   実行"を使わないので、readline による追加処理が消滅する。
##
##   対策として、今から登録しようとしている文字列が既に登録されている
##   物と一致する場合には、builtin trap の呼び出しを省略する。現状では
##   問題になっているのは WINCH だけなので取り敢えず WINCH だけ対策を
##   する。
##
function ble/builtin/trap/set-readline-signal {
  local sig=${1#SIG} handler=$2 trap
  if ble/util/is-running-in-subshell; then
    builtin trap -- "$handler" "$sig"
    return
  fi

  # Skip if already registered
  ble/util/assign trap "builtin trap -p $sig"
  local cmd="trap -- '$handler' SIG$sig"
  [[ $cmd == "$trap" ]] && return 0
  eval "builtin $cmd"
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

## 関数 ble/util/openat fdvar redirect
##   "exec {fdvar}>foo" に該当する操作を実行します。
##   @param[out] fdvar
##     指定した変数に使用されたファイルディスクリプタを代入します。
##   @param[in] redirect
##     リダイレクトを指定します。
if ((_ble_bash>=40100)); then
  function ble/util/openat {
    local _fdvar="$1" _redirect="$2"
    builtin eval "exec {$_fdvar}$_redirect"
  }
else
  _ble_util_openat_nextfd="$bleopt_openat_base"
  function ble/util/openat/.nextfd {
    if ((30100<=_ble_bash&&_ble_bash<30200)); then
      # Bash 3.1 では exec fd>&- で明示的に閉じても駄目。
      # 開いた後に読み取りプロセスで読み取りに失敗する。
      # なので開いていない fd を /dev か /proc で調べる。#D0992
      while [[ -e /dev/fd/$_ble_util_openat_nextfd || -e /proc/self/fd/$_ble_util_openat_nextfd ]]; do
        ((_ble_util_openat_nextfd++))
      done
    fi
    (($1=_ble_util_openat_nextfd++))
  }
  function ble/util/openat {
    ble/util/openat/.nextfd "$1"
    # Note: Bash 3.2/3.1 のバグを避けるため、
    #   >&- を用いて一旦明示的に閉じる必要がある #D0857
    builtin eval "exec ${!1}>&- ${!1}$2"
  }
fi

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
      ble/util/assign "$2" 'date +"$fmt" $time'
    else
      date +"$1" $2
    fi
  }
fi

if ((_ble_bash>=30100)); then
  function ble/util/array-push {
    IFS=' ' builtin eval "$1+=(\"\${@:2}\")"
  }
else
  function ble/util/array-push {
    while (($#>=2)); do
      builtin eval "$1[\${#$1[@]}]=\"\$2\""
      set -- "$1" "${@:3}"
    done
  }
fi
function ble/util/array-reverse {
  builtin eval "
    local i$1 j$1 t$1
    for ((i$1=0,j$1=\${#$1[@]}-1;i$1<j$1;i$1++,j$1--)); do
      t$1=\"\${$1[i$1]}\"
      $1[i$1]=\"\${$1[j$1]}\"
      $1[j$1]=\"\$t$1\"
    done
  "
}

function ble/util/array-fill-range {
  _ble_util_array_prototype.reserve $(($2-$1))
  local _ble_script='
    local -a sARR; sARR=("${_ble_util_array_prototype[@]::$3-$2}")
    ARR=("${ARR[@]::$2}" "${sARR[@]/#/$4}" "${ARR[@]:$3}")'
  builtin eval -- "${_ble_script//ARR/$1}"
}

function ble/util/declare-print-definitions {
  if [[ $# -gt 0 ]]; then
    declare -p "$@" | awk -v _ble_bash="$_ble_bash" -v OSTYPE="$OSTYPE" '
      BEGIN {
        decl = "";
        flag_escape_cr = OSTYPE == "msys";
      }
      function declflush(_, isArray){
        if (decl) {
          isArray = (decl ~ /declare +-[fFgilrtux]*[aA]/);

          # bash-3.0 の declare -p は改行について誤った出力をする。
          if(_ble_bash<30100)gsub(/\\\n/,"\n",decl);

          if (_ble_bash < 40000) {
            # #D1238 bash-3.2 以前の declare -p は ^A, ^? を
            #   ^A^A, ^A^? と出力してしまうので補正する。
            gsub(/\001\001/, "${_ble_term_SOH}", decl);
            gsub(/\001\177/, "${_ble_term_DEL}", decl);
          }
          if (flag_escape_cr)
            gsub(/\015/, "${_ble_term_CR}", decl);

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

_ble_util_array_prototype=()
function _ble_util_array_prototype.reserve {
  local -i n="$1" i
  for ((i=${#_ble_util_array_prototype[@]};i<n;i++)); do
    _ble_util_array_prototype[i]=
  done
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
  ret=${_ble_util_string_prototype::$2}
  ret="${ret// /$1}"
}

function ble/string#common-prefix {
  local a="$1" b="$2"
  ((${#a}>${#b})) && local a="$b" b="$a"
  b="${b::${#a}}"
  if [[ $a == "$b" ]]; then
    ret="$a"
    return
  fi

  # l <= 解 < u, (${a:u}: 一致しない, ${a:l} 一致する)
  local l=0 u="${#a}" m
  while ((l+1<u)); do
    ((m=(l+u)/2))
    if [[ ${a::m} == "${b::m}" ]]; then
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
  if [[ $a == "$b" ]]; then
    ret="$a"
    return
  fi

  # l < 解 <= u, (${a:l}: 一致しない, ${a:u} 一致する)
  local l=0 u="${#a}" m
  while ((l+1<u)); do
    ((m=(l+u+1)/2))
    if [[ ${a:m} == "${b:m}" ]]; then
      ((u=m))
    else
      ((l=m))
    fi
  done

  ret="${a:u}"
}

## 関数 ble/string#split arr split str
##   文字列を分割します。
##   @param[out] arr   分割した文字列を格納する配列名を指定します。
##   @param[in]  split 分割に使用する文字を指定します。
##   @param[in]  str   分割する文字列を指定します。
function ble/string#split {
  local IFS=$2
  if [[ -o noglob ]]; then
    builtin eval "$1=(\$3\$2)"
  else
    set -f
    builtin eval "$1=(\$3\$2)"
    set +f
  fi
}

# 正規表現は _ble_bash>=30000
_ble_rex_isprint='^[ -~]+'
function ble/util/isprint+ {
  local LC_ALL= LC_COLLATE=C # for cygwin collation
  [[ $1 =~ $_ble_rex_isprint ]]
} 2>/dev/null # Note: suppress LC_COLLATE errors #D1205

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
  # builtin echo "${BASH_SOURCE[1]} (${FUNCNAME[1]}): assertion failure $*" >&2
  local i nl=$'\n' IFS=$_ble_term_IFS
  local message="$_ble_term_sgr0$_ble_stackdump_title: $*$nl"
  for ((i=1;i<${#FUNCNAME[*]};i++)); do
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i-1]} (${FUNCNAME[i]})$nl"
  done
  builtin echo -n "$message" >&2
}
function ble-assert {
  local expr="$1"
  local _ble_stackdump_title='assertion failure'
  if ! builtin eval -- "$expr"; then
    shift
    local IFS=$_ble_term_IFS
    ble-stackdump "$expr$_ble_term_nl$*"
    return 1
  else
    return 0
  fi
}

function bleopt {
  local pvars
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
        if eval "[[ \${$var+set} ]]"; then
          printf "%s=%q" "${var#bleopt_}" "${!var}"
          pvars[ip++]="$var"
        else
          echo "bleopt: unknown bleopt option \`${var#bleopt_}'"
        fi
      fi
    done
  fi

  if ((${#pvars[@]})); then
    declare -p "${pvars[@]}" | sed 's/^declare[[:space:]]\{1,\}\(-[^[:space:]]*[[:space:]]\{1,\}\)*bleopt_//'
  fi
}

#------------------------------------------------------------------------------
# **** terminal controls ****

: ${bleopt_vbell_default_message=' Wuff, -- Wuff!! '}
: ${bleopt_vbell_duration=2000}

function .ble-term.initialize {
  _ble_term_nl=$'\n'
  _ble_term_FS=$'\034'
  _ble_term_SOH=$'\001'
  _ble_term_DEL=$'\177'
  _ble_term_IFS=$' \t\n'
  _ble_term_CR=$'\r'

  if [[ -s $_ble_base/cache/$TERM.term && $_ble_base/cache/$TERM.term -nt $_ble_base/term.sh ]]; then
    source "$_ble_base/cache/$TERM.term"
  else
    source "$_ble_base/term.sh"
  fi

  _ble_util_string_prototype.reserve "$_ble_term_it"
}

.ble-term.initialize

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
  local file pid mark rex_tmpfile='^.*/([0-9]+)\.[^/]+$'
  mark=()
  for file in "$_ble_base_tmp"/[1-9]*.*; do
    [[ -e $file && $file =~ $rex_tmpfile ]] || continue
    pid="${BASH_REMATCH[1]}"
    [[ ${mark[pid]} ]] && continue
    mark[pid]=1
    if ! kill -0 "$pid" &>/dev/null; then
      rm -f "$_ble_base_tmp/$pid."*
    fi
  done
}

_ble_base_tmp.wipe

function .ble-term/visible-bell/initialize {
  # # 過去の .time ファイルを削除
  # local now= file
  # for file in "$_ble_base_tmp"/*.visible-bell.time; do
  #   if [[ -f $file ]]; then
  #     [[ $now ]] || now="$(date +%s)"
  #     local ft="$(date +%s -r "$file")"
  #     ((${now::${#now}-2}-${ft::${#ft}-2}>36)) && /bin/rm "$file"
  #   fi
  # done

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

.ble-term/visible-bell/initialize


function .ble-term.audible-bell {
  builtin echo -n '' 1>&2
}
function .ble-term.visible-bell.worker {
  sleep 0.05
  builtin echo -n "${_ble_term_visible_bell_show//'%message%'/$_ble_term_rev${message::cols}}" >&2

  # load time duration settings
  declare msec=$bleopt_vbell_duration
  declare sec=$msec
  ((sec<1000)) && sec=$(builtin printf '%04d' $sec)
  sec=${sec%???}.${sec: -3}

  # wait
  > "$_ble_term_visible_bell__ftime"
  sleep $sec

  # check and clear
  declare -a time1 time2
  time1=($(date +'%s %N' -r "$_ble_term_visible_bell__ftime" 2>/dev/null))
  time2=($(date +'%s %N'))
  if (((time2[0]-time1[0])*1000+(1${time2[1]::3}-1${time1[1]::3})>=msec)); then
    builtin echo -n "$_ble_term_visible_bell_clear" >&2
  fi
}
function .ble-term.visible-bell {
  local _count=$((++_ble_term_visible_bell__count))
  local cols=${COLUMNS:-80}
  local message=$1
  message="${message:-$bleopt_vbell_default_message}"

  builtin echo -n "${_ble_term_visible_bell_show//'%message%'/${_ble_term_setaf[2]}$_ble_term_rev${message::cols}}" >&2
  ( .ble-term.visible-bell.worker 1>/dev/null & )
}
function .ble-term.visible-bell.cancel-erasure {
  > "$_ble_term_visible_bell__ftime"
}
#------------------------------------------------------------------------------
# String manipulations

if ((_ble_bash>=40100)); then
  # - printf "'c" で unicode が読める
  function .ble-text.s2c {
    builtin printf -v ret '%d' "'${1:$2:1}"
  }
elif ((_ble_bash>=40000)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_text_s2c_table
  function .ble-text.s2c {
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
  function .ble-text.s2c {
    local s="${1:$2:1}"
    if [[ $s == [''-''] ]]; then
      ret=$(builtin printf '%d' "'$s")
      return
    fi

    "ble-text-b2c+$bleopt_input_encoding" $(
      while TMOUT= IFS= read -r -n 1 byte; do
        builtin printf '%d ' "'$byte"
      done <<<$s
    )
  }
fi

function ble-text.s2c {
  local _var="$ret"
  if [[ $1 == -v && $# -ge 3 ]]; then
    local ret
    .ble-text.s2c "$3" "$4"
    (($2=ret))
  else
    .ble-text.s2c "$@"
  fi
}

# .ble-text.c2s
if ((_ble_bash>=40200)); then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.
  function .ble-text.c2s-impl {
    builtin printf -v ret '\\U%08x' "$1"
    builtin eval "ret=\$'$ret'"
  }
else
  _ble_text_xdigit=(0 1 2 3 4 5 6 7 8 9 A B C D E F)
  _ble_text_hexmap=()
  for ((i=0;i<256;i++)); do
    _ble_text_hexmap[i]="${_ble_text_xdigit[i>>4&0xF]}${_ble_text_xdigit[i&0xF]}"
  done

  # 動作確認済 3.1, 3.2, 4.0, 4.2, 4.3
  function .ble-text.c2s-impl {
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
function .ble-text.c2s {
  ret="${_ble_text_c2s_table[$1]}"
  if [[ ! $ret ]]; then
    .ble-text.c2s-impl "$1"
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
  ((b0=bytes[0]&0xFF))
  ((n=b0>0xF0
    ?(b0>0xFC?5:(b0>0xF8?4:3))
    :(b0>0xE0?2:(b0>0xC0?1:0)),
    ret=n?b0&0x7F>>n:b0))
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
    ((bytes[0]=code&0x3F>>n|0xFF80>>n&0xFF))
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
