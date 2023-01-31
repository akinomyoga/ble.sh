#!/bin/bash
#%$> out/ble.sh
#%[release=1]
#%[use_gawk=0]
#%m inc (
#%%[guard="@_included".replace("[^_a-zA-Z0-9]","_")]
#%%if @_included!=1 (
#%% [@_included=1]
###############################################################################
# Included from ble-@.sh

#%% include ble-@.sh
#%%)
#%)
# bash script to source from interactive shell
#
# ble - bash line editor
#
# Author: 2013, 2015, K. Murase <myoga.murase@gmail.com>
#

#------------------------------------------------------------------------------
# check shell

if [ -z "${BASH_VERSION-}" ]; then
  echo "ble.sh: This is not a bash. Please use this script with bash." >&2
  return 1 2>/dev/null || exit 1
fi

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))

if [ "$_ble_bash" -lt 30000 ]; then
  unset -v _ble_bash
  echo "ble.sh: A bash with a version under 3.0 is not supported" >&2
  return 1 2>/dev/null || exit 1
fi

# DEBUG version の Bash では遅いという通知
case ${BASH_VERSINFO[4]} in
(alp*|bet*|dev*|rc*|releng*|maint*)
  printf '%s\n' \
    "ble.sh may become very slow because this is a debug version of Bash" \
    "  (version '$BASH_VERSION', release status: '${BASH_VERSINFO[4]}')." \
    "  We recommend using ble.sh with a release version of Bash." >&2 ;;
esac

if ((BASH_SUBSHELL)); then
  unset -v _ble_bash
  builtin echo "ble.sh: ble.sh cannot be loaded into a subshell." >&2
  return 1 2>/dev/null || builtin exit 1
elif [[ $- != *i* ]]; then
  unset -v _ble_bash
  case " ${BASH_SOURCE[*]##*/} " in
  (*' .bashrc '* | *' .bash_profile '* | *' .profile '* | *' bashrc '* | *' profile '*) false ;;
  esac  &&
    builtin echo "ble.sh: This is not an interactive session." >&2 || ((1))
  return 1 2>/dev/null || builtin exit 1
elif ! [[ -t 0 && -t 1 ]]; then
  unset -v _ble_bash
  builtin echo "ble.sh: cannot find the correct TTY/PTY in this session." >&2
  return 1 2>/dev/null || builtin exit 1
fi

_ble_init_original_IFS_set=${IFS+set}
_ble_init_original_IFS=$IFS
IFS=$' \t\n'
function ble/init/restore-IFS {
  # 状態復元
  if [[ $_ble_init_original_IFS_set ]]; then
    IFS=$_ble_init_original_IFS
  else
    builtin unset -v IFS
  fi
  builtin unset -v _ble_init_original_IFS_set
  builtin unset -v _ble_init_original_IFS
}

#------------------------------------------------------------------------------
# check environment

function ble/util/put { builtin printf '%s' "$1"; }
function ble/util/print { builtin printf '%s\n' "$1"; }

# will be overwritten by src/util.sh
function ble/util/assign { builtin eval "$1=\$(builtin eval -- \"\${@:2}\")"; }

## 関数 ble/bin/.freeze-utility-path commands...
##   PATH が破壊された後でも ble が動作を続けられる様に、
##   現在の PATH で基本コマンドのパスを固定して ble/bin/* から使える様にする。
##
##   実装に ble/util/assign を使用しているので ble-core 初期化後に実行する必要がある。
##
function ble/bin/.freeze-utility-path {
  local cmd path q=\' Q="'\''" fail=
  for cmd; do
    if ble/util/assign path "builtin type -P -- $cmd 2>/dev/null" && [[ $path ]]; then
      eval "function ble/bin/$cmd { '${path//$q/$Q}' \"\$@\"; }"
    else
      fail=1
    fi
  done
  ((!fail))
}

if ((_ble_bash>=40000)); then
  function ble/bin#has { type -t "$@" &>/dev/null; }
else
  function ble/bin#has {
    local cmd
    for cmd; do type -t "$cmd" || return 1; done &>/dev/null
    return 0
  }
fi

function ble/.check-environment {
  local posixCommandList='sed date rm mkdir mkfifo sleep stty tput sort awk chmod'
  if ! ble/bin#has $posixCommandList &>/dev/null; then
    local cmd commandMissing=
    for cmd in $posixCommandList; do
      if ! type "$cmd" &>/dev/null; then
        commandMissing="$commandMissing\`$cmd', "
      fi
    done
    echo "ble.sh: Insane environment: The command(s), ${commandMissing}not found. Check your environment variable PATH." >&2
    return 1
#%if use_gawk
  elif ! type gawk &>/dev/null; then
    echo "ble.sh: \`gawk' not found. Please install gawk (GNU awk), or check your environment variable PATH." >&2
    return 1
#%end
  fi

  if [[ ! ${USER-} ]]; then
    ble/util/print "ble.sh: Insane environment: \$USER is empty." >&2
    if USER=$(id -un 2>/dev/null) && [[ $USER ]]; then
      export USER
      ble/util/print "ble.sh: modified USER=$USER" >&2
    fi
  fi
  _ble_base_env_USER=$USER

  if [[ ! ${HOSTNAME-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$HOSTNAME is empty."
    if HOSTNAME=$(uname -n 2>/dev/null) && [[ $HOSTNAME ]]; then
      export HOSTNAME
      ble/util/print "ble.sh: fixed HOSTNAME=$HOSTNAME" >&2
    fi
  fi
  _ble_base_env_HOSTNAME=$HOSTNAME

  if [[ ! ${LANG-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$LANG is empty." >&2
  fi

  return 0
}

if [[ $_ble_base ]]; then
  echo "ble.sh: ble.sh seems to be already loaded." >&2
  ble/init/restore-IFS
  return 1
fi

if ! ble/.check-environment; then
  unset -v _ble_bash
  ble/init/restore-IFS
  return 1
fi

#------------------------------------------------------------------------------
# readlink -f (Originally taken from akinomyoga/mshex.git)

## @fn ble/util/readlink path
##   @var[out] ret

if ((_ble_bash>=40000)); then
  _ble_util_readlink_visited_init='local -A visited=()'
  function ble/util/readlink/.visited {
    [[ ${visited[$1]+set} ]] && return 0
    visited[$1]=1
    return 1
  }
else
  _ble_util_readlink_visited_init="local -a visited=()"
  function ble/util/readlink/.visited {
    local key
    for key in "${visited[@]}"; do
      [[ $1 == "$key" ]] && return 0
    done
    visited=("$1" "${visited[@]}")
    return 1
  }
fi

## @fn ble/util/readlink/.readlink path
##   @var[out] link
function ble/util/readlink/.readlink {
  local path=$1
  if ble/bin#has ble/bin/readlink; then
    ble/util/assign link 'ble/bin/readlink -- "$path"'
    [[ $link ]]
  elif ble/bin#has ble/bin/ls; then
    ble/util/assign link 'ble/bin/ls -ld -- "$path"' &&
      [[ $link == *" $path -> "?* ]] &&
      link=${link#*" $path -> "}
  else
    false
  fi
} 2>/dev/null
## @fn  ble/util/readlink/.resolve-physical-directory
##   @var[in,out] path
function ble/util/readlink/.resolve-physical-directory {
  [[ $path == */?* ]] || return 0
  local PWD=$PWD OLDPWD=$OLDPWD CDPATH=
  if builtin cd -L .; then
    local pwd=$PWD
    builtin cd -P "${path%/*}/" &&
      path=${PWD%/}/${path##*/}

    # Note #D1849: 現在ディレクトリが他者により改名されている場合や PWD がユー
    #   ザーに書き換えられている場合にも元のディレクトリに戻る為、cd -L . した
    #   後のパスに cd する。但し pwd の結果はこの関数の呼び出し前と変わってしま
    #   う (が実際にはこの方が良いだろう)。PWD は local にして元の値に戻すので
    #   変わらない。
    builtin cd "$pwd"
  fi
  return 0
}
function ble/util/readlink/.resolve-loop {
  local path=$ret
  while [[ $path == ?*/ ]]; do path=${path%/}; done
  builtin eval -- "$_ble_util_readlink_visited_init"
  while [[ -h $path ]]; do
    local link
    ble/util/readlink/.visited "$path" && break
    ble/util/readlink/.readlink "$path" || break
    if [[ $link == /* || $path != */* ]]; then
      path=$link
    else
      # 相対パス ../ は物理ディレクトリ構造に従って遡る。
      ble/util/readlink/.resolve-physical-directory
      path=${path%/*}/$link
    fi
    while [[ $path == ?*/ ]]; do path=${path%/}; done
  done
  ret=$path
}
function ble/util/readlink/.resolve {
  # 初回呼び出し時に実装を選択
  _ble_util_readlink_type=

  # より効率的な実装が可能な場合は ble/util/readlink/.resolve を独自定義。
  case $OSTYPE in
  (cygwin | msys | linux-gnu)
    # これらのシステムの標準 readlink では readlink -f が使える。
    #
    # Note: 例えば NixOS では標準の readlink を使おうとすると問題が起こるらしい
    #   ので、見えている readlink を使う。見えている readlink が非標準の時は -f
    #   が使えるか分からないので readlink -f による実装は有効化しない。
    #
    local readlink
    ble/util/assign readlink 'type -P readlink'
    case $readlink in
    (/bin/readlink | /usr/bin/readlink)
      _ble_util_readlink_type=readlink-f
      builtin eval "function ble/util/readlink/.resolve { ble/util/assign ret '$readlink -f -- \"\$ret\"'; }" ;;
    esac ;;
  esac

  if [[ ! $_ble_util_readlink_type ]]; then
    _ble_util_readlink_type=loop
    ble/bin/.freeze-utility-path readlink ls
    function ble/util/readlink/.resolve { ble/util/readlink/.resolve-loop; }
  fi

  ble/util/readlink/.resolve
}
function ble/util/readlink {
  ret=$1
  if [[ -h $ret ]]; then ble/util/readlink/.resolve; fi
}

#---------------------------------------

function _ble_base.initialize {
  local src=$1
  local defaultDir=$2

  # resolve symlink
  if [[ -h $src ]] && type -t readlink &>/dev/null; then
    src=$(ble/util/readlink $src)
  fi

  if [[ -s $src && $src != */* ]]; then
    _ble_base=$PWD
  elif [[ $src == */* ]]; then
    local dir=${src%/*}
    if [[ ! $dir ]]; then
      _ble_base=/
    elif [[ $dir != /* ]]; then
      _ble_base=$PWD/$dir
    else
      _ble_base=$dir
    fi
  else
    _ble_base=${defaultDir:-$HOME/.local/share/blesh}
  fi
}
_ble_base.initialize "${BASH_SOURCE[0]}"
if [[ ! -d $_ble_base ]]; then
  unset -v _ble_bash
  echo "ble.sh: ble base directory not found!" 1>&2
  ble/init/restore-IFS
  return 1
fi

# tmpdir
if [[ ! -d $_ble_base/tmp ]]; then
  mkdir -p "$_ble_base/tmp"
  chmod a+rwxt "$_ble_base/tmp"
fi

_ble_base_tmp="$_ble_base/tmp/${USER:-$UID}@$HOSTNAME"
if [[ ! -d $_ble_base_tmp ]]; then
  (umask 077; mkdir -p "$_ble_base_tmp")
fi

if [[ ! -d $_ble_base/cache ]]; then
  mkdir -p "$_ble_base/cache"
fi

# loading time
#   core    2ms
#   decode  8ms
#   edit    7ms
#   color   3ms
#   syntax 19ms

##%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/color/
#%x inc.r/@/edit/
#%x inc.r/@/syntax/
#------------------------------------------------------------------------------

function ble-initialize {
  ble-decode-initialize # 54ms
  .ble-edit.default-key-bindings # 4ms
  ble-edit-initialize # 4ms
}

function ble-attach {
  _ble_edit_detach_flag=
  ble-decode-attach # 53ms
  ble-edit-attach # 0ms
  .ble-edit-draw.redraw # 34ms
  .ble-edit/stdout/off
}

function ble-detach {
  _ble_edit_detach_flag=detach
}

ble-initialize
ble/init/restore-IFS
[[ $1 != noattach ]] && ble-attach

###############################################################################
