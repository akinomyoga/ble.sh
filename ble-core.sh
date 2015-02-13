# -*- mode:sh;eval:(sh-set-shell "bash") -*-
# bash script to be sourced from interactive shell

: ${ble_opt_input_encoding:=UTF-8}

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

if test "${_ble_bash:-0}" -ge 40100; then
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
  for file in "$_ble_base"/ble.d/tmp/*.visible-bell.time; do
    if test -f "$file"; then
      test -z "$now" && now="$(date +%s)"
      local ft="$(date +%s -r "$file")"
      ((${now::${#now}-2}-${ft::${#now}-2}>36)) && /bin/rm "$file"
    fi
  done

  _ble_term_visible_bell__ftime="$_ble_base/ble.d/tmp/$$.visible-bell.time"
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

if test "${_ble_bash:-0}" -ge 40100; then
  function .ble-text.s2c {
    printf -v ret '%d' "'${1:$2:1}"
  }
else
  function .ble-text.s2c {
    ret=$(printf '%d' "'${1:$2:1}")
  }
fi

# .ble-text.c2s
if test "${_ble_bash:-0}" -ge 40200; then
  # $'...' in bash-4.2 supports \uXXXX and \UXXXXXXXX sequences.
  function .ble-text.c2s-impl {
    printf -v ret '\\U%08x' "$1"
    eval "ret=\$'$ret'"
  }
else
  if [ "$(/usr/bin/printf '\U00003042' 2>/dev/null)" = 'あ' ]; then
    # /bin/printf of GNU coreutils supports \uXXXX and \UXXXXXXXX
    # when it is compiled with glibc-2.2 or later version.
    function .ble-text.c2s-hex {
      local hex="$1"
      ret="$(/usr/bin/printf "\\U$hex")"
    }
    # Note: $(/usr/bin/printf '\U00000041') becomes error.
    # it seems that ordinary ascii characters do not allowed to
    # be specified with the universal character sequences in /usr/bin/printf.
  elif [ "$(awk 'BEGIN{printf "%c",12354}' /dev/null)" = 'あ' ]; then
    function .ble-text.c2s-hex {
      local hex="$1"
      ret="$(awk 'BEGIN{printf "%c",0x'$hex'}' /dev/null)"
    }
  else
    echo "ble.sh: there is no way to convert an unicode to the character!" 1>&2
    return 1
  fi

  if [ "${_ble_bash:-0}" -ge 40100 ]; then
    function .ble-text.c2s-impl {
      if ((${1:-0}<0x100)); then
        printf -v ret '\\%03o' "$1"
        eval "ret=\$'$ret'"
      else
        printf -v ret '%08x' "$1"
        .ble-text.c2s-hex "$ret"
      fi
    }
  else
    function .ble-text.c2s-impl {
      if ((${1:-0}<0x100)); then
        ret=$(printf '\\%03o' "$1")
        eval "ret=\$'$ret'"
      else
        ret=$(printf '%08x' "$1")
        .ble-text.c2s-hex "$ret"
      fi
    }
  fi
fi

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
