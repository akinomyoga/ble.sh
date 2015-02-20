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
  function .ble-text.sprintf {
    printf -v "$@"
  }
else
  function .ble-text.sprintf {
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

_ble_util_array_prototype=()
function _ble_util_array_prototype.reserve {
  local n="$1" i
  for ((i=${#_ble_util_array_prototype[@]};i<n;i++)); do
    _ble_util_array_prototype[i]=
  done
}

#------------------------------------------------------------------------------
# **** terminal controls ****

: ${ble_opt_vbell_default_message=' Wuff, -- Wuff!! '}
#: ${ble_opt_vbell_default_message=' (>ω<)/ わふー, わふー!! '}
: ${ble_opt_vbell_duration=2000}

_ble_term_xenl=1
_ble_term_it=8
_ble_term_sc='[s'
_ble_term_rc='[u'
_ble_term_sgr_fghr='[91m'
_ble_term_sgr_fghb='[94m'
_ble_term_sgr0='[m'

function .ble-term.initialize {

  # end of line behavior
  if tput xenl &>/dev/null; then
    _ble_term_xenl=1
  else
    _ble_term_xenl=0
  fi

  # tab width
  local tmp=$(tput it)
  _ble_term_it="${tmp-8}"

  # for visible-bell

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
}
.ble-term.initialize

# **** vbell/abell ****

function .ble-term.audible-bell {
  echo -n '' 1>&2
}
function .ble-term.visible-bell {
  local _count=$((++_ble_term_visible_bell__count))
  local cols="${LINES:-25}" _sc="$_ble_term_sc$_ble_term_sgr0" _rc="$_ble_term_rc"
  local lines="${COLUMNS:-80}"
  local message="$*"
  local message="${message:-$ble_opt_vbell_default_message}"
  echo -n "M$_sc[1;1H[K[32;7m${message::cols}[m$_rc[B" 1>&2
  # echo -n "D$_sc[${lines};1H[K[7m${message::cols}[m$_rc[A" 1>&2
  (
    {
      sleep 0.05
      echo -n "M$_sc[1;1H[K[7m${message::cols}[m$_rc[B" 1>&2

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
        echo -n "$_sc[1;1H[2K$_rc" 1>&2
        # echo -n "$_sc[${lines};1H[2K$_rc" 1>&2
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
