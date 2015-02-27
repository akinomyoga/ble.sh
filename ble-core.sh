# -*- mode:sh;eval:(sh-set-shell "bash") -*-
# bash script to be sourced from interactive shell

: ${ble_opt_input_encoding:=UTF-8}


## オプション bleopt_openat_base
##   bash-4.1 未満で exec {var}>foo が使えない時に ble.sh で内部的に fd を割り当てる。
##   この時の fd の base を指定する。bleopt_openat_base, bleopt_openat_base+1, ...
##   という具合に順番に使用される。既定値は 30 である。
: ${bleopt_openat_base:=30}

shopt -s checkwinsize

_ble_shopt_extglob__level=0
_ble_shopt_extglob__unset=1
function .ble-shopt-extglob-push {
  if ((_ble_shopt_extglob__level++==0)); then
    shopt extglob &>/dev/null
    _ble_shopt_extglob__unset=$?
    shopt -s extglob &>/dev/null
  fi
}
function .ble-shopt-extglob-pop {
  if ((_ble_shopt_extglob__level>0&&--_ble_shopt_extglob__level==0&&_ble_shopt_extglob__unset)); then
    shopt -u extglob
  fi
}
function .ble-shopt-extglob-pop-all {
  if ((_ble_shopt_extglob__level>0&&_ble_shopt_extglob__unset)); then
    shopt -u extglob
  fi
  _ble_shopt_extglob__level=0
}

#------------------------------------------------------------------------------
# util

if ((_ble_bash>=40100)); then
  function ble/util/sprintf {
    printf -v "$@"
  }
else
  function ble/util/sprintf {
    local _var="$1"
    shift
    local _value="$(printf "$@")"
    eval "$_var=\"\$_value\""
  }
fi

if ((_ble_bash>=30200)); then
  function ble/util/isfunction {
    builtin declare -f "$1" &>/dev/null
  }
else
  # bash-3.1 has bug in declare -f.
  # it does not accept a function name containing non-alnum chars.
  function ble/util/isfunction {
    [[ $(type -t $1) == function ]]
  }
fi

# exec {var}>foo
if ((_ble_bash>=40100)); then
  function ble/util/openat {
    local _fdvar="$1" _redirect="$2"
    eval "exec {$_fdvar}$_redirect"
  }
else
  _ble_util_openat_nextfd="$bleopt_openat_base"
  function ble/util/openat {
    local _fdvar="$1" _redirect="$2"
    (($_fdvar=_ble_util_openat_nextfd++))
    eval "exec ${!_fdvar}$_redirect"
  }
fi

if ((_ble_bash>=40200)); then
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      printf -v "$2" "%($3)T" "${4:--1}"
    else
      printf "%($1)T" "${2:--1}"
    fi
  }
else
  function ble/util/strftime {
    if [[ $1 = -v ]]; then
      local _result="$(date +"$3" $4)"
      eval "$2=\"\$_result\""
    else
      date +"$1" $2
    fi
  }
fi

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
    eval "function $funcname {
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
_ble_term_NL=$'\n'
function ble-stackdump {
  # echo "${BASH_SOURCE[1]} (${FUNCNAME[1]}): assertion failure $*" >&2
  local i nl=$'\n'
  local message="$_ble_term_sgr0$_ble_stackdump_title: $*$nl"
  for ((i=1;i<${#FUNCNAME[*]};i++)); do
    message+="  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i]} (${FUNCNAME[i]})$nl"
  done
  echo -n "$message" >&2
}
function ble-assert {
  local expr="$1"
  local _ble_stackdump_title='assertion failure'
  if ! eval -- "$expr"; then
    shift
    ble-stackdump "$expr$_ble_term_NL$*"
  fi
}

#------------------------------------------------------------------------------
# **** terminal controls ****

: ${ble_opt_vbell_default_message=' Wuff, -- Wuff!! '}
#: ${ble_opt_vbell_default_message=' (>ω<)/ わふー, わふー!! '}
: ${ble_opt_vbell_duration=2000}

function .ble-term.initialize {
  if [[ $_ble_base/term.sh -nt $_ble_base/cache/$TERM.term ]]; then
    source "$_ble_base/term.sh"
  else
    source "$_ble_base/cache/$TERM.term"
  fi

  _ble_util_string_prototype.reserve "$_ble_term_it"
}

.ble-term.initialize

function ble-term/put {
  BUFF[${#BUFF[@]}]="$1"
}
function ble-term/cup {
  local x="$1" y="$2" esc="$_ble_term_cup"
  esc="${esc//%x/$x}"
  esc="${esc//%y/$y}"
  esc="${esc//%c/$((x+1))}"
  esc="${esc//%l/$((y+1))}"
  BUFF[${#BUFF[@]}]="$esc"
}
function ble-term/flush {
  IFS= eval 'echo -n "${BUFF[*]}"'
  BUFF=()
}

# **** vbell/abell ****

function .ble-term/visible-bell/initialize {
  # 過去の .time ファイルを削除
  local now= file
  for file in "$_ble_base"/tmp/*.visible-bell.time; do
    if test -f "$file"; then
      test -z "$now" && now="$(date +%s)"
      local ft="$(date +%s -r "$file")"
      ((${now::${#now}-2}-${ft::${#now}-2}>36)) && /bin/rm "$file"
    fi
  done

  _ble_term_visible_bell__ftime="$_ble_base/tmp/$$.visible-bell.time"

  local BUFF=()
  ble-term/put "$_ble_term_ri$_ble_term_sc$_ble_term_sgr0"
  ble-term/cup 0 0
  ble-term/put "$_ble_term_el%message%$_ble_term_sgr0$_ble_term_rc${_ble_term_cud//%d/1}"
  IFS= eval '_ble_term_visible_bell_show="${BUFF[*]}"'
  
  BUFF=()
  ble-term/put "$_ble_term_sc$_ble_term_sgr0"
  ble-term/cup 0 0
  ble-term/put "$_ble_term_el2$_ble_term_rc"
  IFS= eval '_ble_term_visible_bell_clear="${BUFF[*]}"'
}

.ble-term/visible-bell/initialize


function .ble-term.audible-bell {
  echo -n '' 1>&2
}
function .ble-term.visible-bell {
  local _count=$((++_ble_term_visible_bell__count))
  local cols="${LINES:-25}"
  local lines="${COLUMNS:-80}"
  local message="$*"
  message="${message:-$ble_opt_vbell_default_message}"

  echo -n "${_ble_term_visible_bell_show//%message%/$_ble_term_setaf2$_ble_term_rev${message::cols}}" >&2
  (
    {
      sleep 0.05
      echo -n "${_ble_term_visible_bell_show//%message%/$_ble_term_rev${message::cols}}" >&2

      # load time duration settings
      declare msec=$ble_opt_vbell_duration
      declare sec=$msec
      ((sec<1000)) && sec=$(printf '%04d' $sec)
      sec=${sec%???}.${sec: -3}

      # wait
      touch "$_ble_term_visible_bell__ftime"
      sleep $sec

      # check and clear
      declare time1=($(date +'%s %N' -r "$_ble_term_visible_bell__ftime" 2>/dev/null))
      declare time2=($(date +'%s %N'))
      if (((time2[0]-time1[0])*1000+(1${time2[1]::3}-1${time1[1]::3})>=msec)); then
        echo -n "$_ble_term_visible_bell_clear" >&2
      fi
    } &
  )
}
function .ble-term.visible-bell.cancel-erasure {
  touch "$_ble_term_visible_bell__ftime"
}
#------------------------------------------------------------------------------
# String manipulations

if ((_ble_bash>=40100)); then
  # - printf "'c" で unicode が読める
  function .ble-text.s2c {
    printf -v ret '%d' "'${1:$2:1}"
  }
elif ((_ble_bash>=40000)); then
  # - 連想配列にキャッシュできる
  # - printf "'c" で unicode が読める
  declare -A _ble_text_s2c_table
  function .ble-text.s2c {
    local s="${1:$2:1}"
    ret="${_ble_text_s2c_table[x$s]}"
    [[ $ret ]] && return

    ret=$(printf '%d' "'${1:$2:1}")
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
      ret=$(printf '%d' "'$s")
      return
    fi

    "ble-text-b2c+$ble_opt_input_encoding" $(
      while IFS= read -r -n 1 byte; do
        printf '%d ' "'$byte"
      done <<<$s
    )
  }
fi

# .ble-text.c2s
if ((_ble_bash>=40200)); then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.
  function .ble-text.c2s-impl {
    printf -v ret '\\U%08x' "$1"
    eval "ret=\$'$ret'"
  }
else
  _ble_text_xdigit=(0 1 2 3 4 5 6 7 8 9 A B C D E F)
  _ble_text_hexmap=()
  for((i=0;i<256;i++)); do
    _ble_text_hexmap[i]="${_ble_text_xdigit[i>>4&0xF]}${_ble_text_xdigit[i&0xF]}"
  done

  # 動作確認済 3.1, 3.2, 4.0, 4.2, 4.3
  function .ble-text.c2s-impl {
    if (($1<0x80)); then
      eval "ret=\$'\\x${_ble_text_hexmap[$1]}'"
      return
    fi

    local bytes i iN seq=
    ble-text-c2b+UTF-8 "$1"
    for ((i=0,iN=${#bytes[@]};i<iN;i++)); do
      seq="$seq\\x${_ble_text_hexmap[bytes[i]&0xFF]}"
    done
    eval "ret=\$'$seq'"
  }
fi


# どうもキャッシュするのが一番速い様だ
declare -a _ble_text_c2s_table
function .ble-text.c2s {
  ret="${_ble_text_c2s_table[$1]}"
  if [  -z "$ret" ]; then
    .ble-text.c2s-impl "$1"
    _ble_text_c2s_table[$1]="$ret"
  fi
}

## gets a byte count of the encoded data of the char
## 指定した文字を現在の符号化方式で符号化した時のバイト数を取得します。
## \param [in]  $1 = code
## \param [out] ret
function .ble-text.c2bc {
  ".ble-text.c2bc+$ble_opt_input_encoding" "$1"
}

#------------------------------------------------------------------------------

## @var[out] ret
function ble-text-b2c+UTF-8 {
  local bytes=("$@")
  local b0 n i
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
