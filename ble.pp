#!/bin/bash
#%$> out/ble.sh
#%[release = 0]
#%[use_gawk = 0]
#%[measure_load_time = 0]
#%[debug_keylogger = 1]
#%#----------------------------------------------------------------------------
#%m inc
#%%[guard = "@_included".replace("[^_a-zA-Z0-9]", "_")]
#%%if @_included != 1
#%%%[@_included = 1]
###############################################################################
# Included from ble-@.sh

#%%%if measure_load_time
time {
echo ble-@.sh >&2
#%%%%include ble-@.sh
}
#%%%else
#%%%%include ble-@.sh
#%%%end
#%%end
#%end
#%#----------------------------------------------------------------------------
# bash script to souce from interactive shell sessions
#
# ble - bash line editor
#
# Author: 2013, 2015-2017, K. Murase <myoga.murase@gmail.com>
#

#%if measure_load_time
time {
# load_time (2015-12-03)
#   core           12ms
#   decode         10ms
#   color           2ms
#   edit            9ms
#   syntax          5ms
#   ble-initialize 14ms
time {
echo prologue >&2
#%end
#------------------------------------------------------------------------------
# check shell

if [ -z "$BASH_VERSION" ]; then
  echo "ble.sh: This is not a bash. Please use this script with bash." >&2
  return 1 2>/dev/null || exit 1
fi

if [ -n "${-##*i*}" ]; then
  echo "ble.sh: This is not an interactive session." >&2
  return 1 2>/dev/null || exit 1
fi

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))

if [ "$_ble_bash" -lt 30000 ]; then
  unset _ble_bash
  echo "ble.sh: bash with a version under 3.0 is not supported." >&2
  return 1 2>/dev/null || exit 1
fi

_ble_bash_setu=
_ble_bash_setv=
_ble_bash_options_adjusted=
function ble/adjust-bash-options {
  [[ $_ble_bash_options_adjusted ]] && return 1
  _ble_bash_options_adjusted=1
  _ble_bash_setv=; [[ -o verbose ]] && _ble_bash_setv=1 && set +v
  _ble_bash_setu=; [[ -o nounset ]] && _ble_bash_setu=1 && set +u
}
function ble/restore-bash-options {
  [[ $_ble_bash_options_adjusted ]] || return 1
  _ble_bash_options_adjusted=
  [[ $_ble_bash_setv && ! -o verbose ]] && set -v
  [[ $_ble_bash_setu && ! -o nounset ]] && set -u
}
ble/adjust-bash-options

if [[ -o posix ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used in bash POSIX modes (--posix)." >&2
  return 1 2>/dev/null || exit 1
fi

bind &>/dev/null # force to load .inputrc
if [[ ! -o emacs && ! -o vi ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  return 1
fi

if shopt -q restricted_shell; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  return 1
fi

_ble_init_original_IFS=$IFS
IFS=$' \t\n'

# check environment

function ble/.check-environment {
  local posixCommandList='sed date rm mkdir mkfifo sleep stty sort awk chmod grep man cat wc'
  if ! type $posixCommandList &>/dev/null; then
    local cmd commandMissing=
    for cmd in $posixCommandList; do
      if ! type "$cmd" &>/dev/null; then
        commandMissing="$commandMissing\`$cmd', "
      fi
    done
    echo "ble.sh: Insane environment: The command(s), ${commandMissing}not found. Check your environment variable PATH." >&2

    # try to fix PATH
    local default_path=$(command -p getconf PATH 2>/dev/null)
    local original_path=$PATH
    export PATH=${PATH}${PATH:+:}${default_path}
    [[ :$PATH: == *:/usr/bin:* ]] || PATH=$PATH${PATH:+:}/usr/bin
    [[ :$PATH: == *:/bin:* ]] || PATH=$PATH${PATH:+:}/bin
    if ! type $posixCommandList &>/dev/null; then
      PATH=$original_path
      return 1
    fi

    echo "ble.sh: modified PATH=\$PATH${PATH:${#original_path}}" >&2
  fi

#%if use_gawk
  if ! type gawk &>/dev/null; then
    echo "ble.sh: \`gawk' not found. Please install gawk (GNU awk), or check your environment variable PATH." >&2
    return 1
  fi
#%end

  return 0
}
if ! ble/.check-environment; then
  _ble_bash=
  return 1
fi

if [[ $_ble_base ]]; then
  echo "ble.sh: ble.sh seems to be already loaded." >&2
  return 1
fi

#------------------------------------------------------------------------------

_ble_bash_loaded_in_function=0
[[ ${FUNCNAME+set} ]] && _ble_bash_loaded_in_function=1

# readlink -f (taken from akinomyoga/mshex.git)
function ble/util/readlink {
  local path=$1
  case "$OSTYPE" in
  (cygwin|linux-gnu)
    # 少なくとも cygwin, GNU/Linux では readlink -f が使える
    PATH=/bin:/usr/bin readlink -f "$path" ;;
  (darwin*|*)
    # Mac OSX には readlink -f がない。
    local PWD=$PWD OLDPWD=$OLDPWD
    while [[ -h $path ]]; do
      local link=$(PATH=/bin:/usr/bin readlink "$path" 2>/dev/null || true)
      [[ $link ]] || break

      if [[ $link = /* || $path != */* ]]; then
        # * $link ~ 絶対パス の時
        # * $link ~ 相対パス かつ ( $path が現在のディレクトリにある ) の時
        path=$link
      else
        local dir=${path%/*}
        path=${dir%/}/$link
      fi
    done
    echo -n "$path" ;;
  esac
}

function ble/base/.create-user-directory {
  local var=$1 dir=$2
  if [[ ! -d $dir ]]; then
    # dangling symlinks are silently removed
    [[ ! -e $dir && -h $dir ]] && command rm -f "$dir"
    if [[ -e $dir || -h $dir ]]; then
      echo "ble.sh: cannot create a directory '$dir' since there is already a file." >&2
      return 1
    fi
    if ! (umask 077; command mkdir -p "$dir"); then
      echo "ble.sh: failed to create a directory '$dir'." >&2
      return 1
    fi
  elif ! [[ -r $dir && -w $dir && -x $dir ]]; then
    echo "ble.sh: permision of '$tmpdir' is not correct." >&2
    return 1
  fi
  eval "$var=\$dir"
}

##
## @var _ble_base
##
##   ble.sh のインストール先ディレクトリ。
##   読み込んだ ble.sh の実体があるディレクトリとして解決される。
##
function ble/base/initialize-base-directory {
  local src=$1
  local defaultDir=$2

  # resolve symlink
  if [[ -h $src ]] && type -t readlink &>/dev/null; then
    src=$(ble/util/readlink $src)
  fi

  local dir=${src%/*}
  if [[ $dir != "$src" ]]; then
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

  [[ -d $_ble_base ]]
}
if ! ble/base/initialize-base-directory "${BASH_SOURCE[0]}"; then
  echo "ble.sh: ble base directory not found!" 1>&2
  return 1
fi

##
## @var _ble_base_run
##
##   実行時の一時ファイルを格納するディレクトリ。以下の手順で決定する。
##   
##   1. ${XDG_RUNTIME_DIR:=/run/user/$UID} が存在すればその下に blesh を作成して使う。
##   2. /tmp/blesh/$UID を作成可能ならば、それを使う。
##   3. $_ble_base/tmp/$UID を使う。
##
function ble/base/initialize-runtime-directory/.xdg {
  [[ $_ble_base != */out ]] || return

  local runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}
  if [[ ! -d $runtime_dir ]]; then
    [[ $XDG_RUNTIME_DIR ]] &&
      echo "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' is not a directory." >&2
    return 1
  fi
  if ! [[ -r $runtime_dir && -w $runtime_dir && -x $runtime_dir ]]; then
    [[ $XDG_RUNTIME_DIR ]] &&
      echo "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' doesn't have a proper permission." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$runtime_dir/blesh"
}
function ble/base/initialize-runtime-directory/.tmp {
  [[ -r /tmp && -w /tmp && -x /tmp ]] || return

  local tmp_dir=/tmp/blesh
  if [[ ! -d $tmp_dir ]]; then
    [[ ! -e $tmp_dir && -h $tmp_dir ]] && command rm -f "$tmp_dir"
    if [[ -e $tmp_dir || -h $tmp_dir ]]; then
      echo "ble.sh: cannot create a directory '$tmp_dir' since there is already a file." >&2
      return 1
    fi
    command mkdir -p "$tmp_dir" || return
    command chmod a+rwxt "$tmp_dir" || return
  elif ! [[ -r $tmp_dir && -w $tmp_dir && -x $tmp_dir ]]; then
    echo "ble.sh: permision of '$tmp_dir' is not correct." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$tmp_dir/$UID"
}
function ble/base/initialize-runtime-directory {
  ble/base/initialize-runtime-directory/.xdg && return
  ble/base/initialize-runtime-directory/.tmp && return

  # fallback
  local tmp_dir=$_ble_base/tmp
  if [[ ! -d $tmp_dir ]]; then
    command mkdir -p "$tmp_dir" || return
    command chmod a+rwxt "$tmp_dir" || return
  fi
  ble/base/.create-user-directory _ble_base_run "$tmp_dir/$UID"
}
if ! ble/base/initialize-runtime-directory; then
  echo "ble.sh: failed to initialize \$_ble_base_run." 1>&2
  return 1
fi

function ble/base/clean-up-runtime-directory {
  local file pid mark removed
  mark=() removed=()
  for file in "$_ble_base_run"/[1-9]*.*; do
    [[ -e $file ]] || continue
    pid=${file##*/}; pid=${pid%%.*}
    [[ ${mark[pid]} ]] && continue
    mark[pid]=1
    if ! kill -0 "$pid" &>/dev/null; then
      removed=("${removed[@]}" "$_ble_base_run/$pid."*)
    fi
  done
  ((${#removed[@]})) && command rm -f "${removed[@]}"
}

# initialization time = 9ms (for 70 files)
if shopt -q failglob &>/dev/null; then
  shopt -u failglob
  ble/base/clean-up-runtime-directory
  shopt -s failglob
else
  ble/base/clean-up-runtime-directory
fi

##
## @var _ble_base_cache
##
##   環境毎の初期化ファイルを格納するディレクトリ。以下の手順で決定する。
##
##   1. ${XDG_CACHE_HOME:=$HOME/.cache} が存在すればその下に blesh を作成して使う。
##   2. $_ble_base/cache.d/$UID を使う。
##
function ble/base/initialize-cache-directory/.xdg {
  [[ $_ble_base != */out ]] || return

  local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
  if [[ ! -d $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      echo "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' is not a directory." >&2
    return 1
  fi
  if ! [[ -r $cache_dir && -w $cache_dir && -x $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      echo "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' doesn't have a proper permission." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_cache "$cache_dir/blesh"
}
function ble/base/initialize-cache-directory {
  ble/base/initialize-cache-directory/.xdg && return

  # fallback
  local cache_dir=$_ble_base/cache.d
  if [[ ! -d $cache_dir ]]; then
    command mkdir -p "$cache_dir" || return
    command chmod a+rwxt "$cache_dir" || return

    # relocate an old cache directory if any
    local old_cache_dir=$_ble_base/cache
    if [[ -d $old_cache_dir && ! -h $old_cache_dir ]]; then
      mv "$old_cache_dir" "$cache_dir/$UID"
      ln -s "$cache_dir/$UID" "$old_cache_dir"
    fi
  fi
  ble/base/.create-user-directory _ble_base_cache "$cache_dir/$UID"
}
if ! ble/base/initialize-cache-directory; then
  echo "ble.sh: failed to initialize \$_ble_base_cache." 1>&2
  return 1
fi

#%if measure_load_time
}
#%end

##%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/color/
#%x inc.r/@/edit/
#%x inc.r/@/form/
#%x inc.r/@/syntax/
#------------------------------------------------------------------------------
# function .ble-time { echo "$*"; time "$@"; }

function ble-initialize {
  ble-decode-initialize # 54ms
  ble-edit-initialize # 4ms
}

_ble_attached=
function ble-attach {
  [[ $_ble_attached ]] && return

  local IFS=$' \t\n'
  ble-decode-attach || return 1 # 53ms
  _ble_attached=1
  _ble_edit_detach_flag= # do not detach or exit

  ble-edit-attach # 0ms
  ble-edit/info/reveal
  ble/textarea#redraw # 34ms
  ble-edit/bind/stdout.off
}

function ble-detach {
  [[ $_ble_attached ]] || return
  _ble_attached=
  _ble_edit_detach_flag=${1:-detach} # schedule detach
}

#%if measure_load_time
echo ble-initialize >&2
time ble-initialize
#%else
ble-initialize
#%end

IFS=$_ble_init_original_IFS
unset _ble_init_original_IFS
[[ $1 != noattach ]] && ble-attach
#%if measure_load_time
}
#%end

return 0
###############################################################################
