#!/bin/bash
#%$> out/ble.sh
#%[release=0]
#%[use_gawk=0]
#%[measure_load_time=0]
#%#----------------------------------------------------------------------------
#%m inc (
#%%[guard="@_included".replace("[^_a-zA-Z0-9]","_")]
#%%if @_included!=1
#%% [@_included=1]
###############################################################################
# Included from ble-@.sh

#%% if measure_load_time
time {
echo ble-@.sh >&2
#%% end
#%% include ble-@.sh
#%% if measure_load_time
}
#%% end
#%%end
#%)
#%#----------------------------------------------------------------------------
# bash script to be sourced from interactive shell
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

_ble_bash_verbose_adjusted=
function ble/adjust-bash-verbose-option {
  [[ $_ble_bash_verbose_adjusted ]] && return 1
  _ble_bash_verbose_adjusted=1
  _ble_edit_SETV=
  [[ -o verbose ]] && _ble_edit_SETV=1 && set +v
}
ble/adjust-bash-verbose-option
function ble/restore-bash-verbose-option {
  [[ $_ble_bash_verbose_adjusted ]] || return 1
  _ble_bash_verbose_adjusted=
  [[ $_ble_edit_SETV && ! -o verbose ]] && set -v
}

if [[ -o posix ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used in bash POSIX modes (--posix)." >&2
  return 1 2>/dev/null || exit 1
fi

if [[ ! -o emacs && ! -o vi ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  return 1
fi

if [[ ! -o emacs ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is intended to be used in the emacs editing mode (set -o emacs)." >&2
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
  local posixCommandList='sed date rm mkdir mkfifo sleep stty sort awk chmod grep man cat'
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

function _ble_base.initialize {
  local src="$1"
  local defaultDir="$2"

  # resolve symlink
  if [[ -h $src ]] && type -t readlink &>/dev/null; then
    src="$(readlink -f "$src")"
  fi

  local dir="${src%/*}"
  if [[ $dir != "$src" ]]; then
    if [[ ! $dir ]]; then
      _ble_base=/
    elif [[ $dir != /* ]]; then
      _ble_base="$PWD/$dir"
    else
      _ble_base="$dir"
    fi
  else
    _ble_base="${defaultDir:-$PWD}"
  fi
}
_ble_base.initialize "${BASH_SOURCE[0]}"
if [[ ! -d $_ble_base ]]; then
  echo "ble.sh: ble base directory not found!" 1>&2
  return 1
fi

#
# _ble_base_tmp
#

# use /tmp/blesh if accessible
if [[ -r /tmp && -w /tmp && -x /tmp ]]; then
  if [[ ! -d /tmp/blesh ]]; then
    _ble_base_tmp=/tmp/blesh
    [[ -e $_ble_base_tmp || -h $_ble_base_tmp ]] && command rm -f "$_ble_base_tmp"
    command mkdir -p "$_ble_base_tmp"
    command chmod a+rwxt "$_ble_base_tmp"
  elif [[ -r /tmp/blesh && -w /tmp/blesh && -x /tmp/blesh ]]; then
    _ble_base_tmp=/tmp/blesh
  fi
fi

# fallback
if [[ ! $_ble_base_tmp ]]; then
  _ble_base_tmp="$_ble_base/tmp"
  if [[ ! -d $_ble_base_tmp ]]; then
    command mkdir -p "$_ble_base_tmp"
    command chmod a+rwxt "$_ble_base_tmp"
  fi
fi

_ble_base_tmp="$_ble_base_tmp/$UID"
if [[ ! -d $_ble_base_tmp ]]; then
  (umask 077; command mkdir -p "$_ble_base_tmp")
fi

#
# _ble_base_cache
#

_ble_base_cache="$_ble_base/cache.d"
if [[ ! -d $_ble_base_cache ]]; then
  command mkdir -p "$_ble_base_cache"
  command chmod a+rwxt "$_ble_base_cache"
  if [[ -d $_ble_base/cache && ! -h $_ble_base/cache ]]; then
    mv "$_ble_base/cache" "$_ble_base_cache/$UID"
    ln -s "$_ble_base_cache/$UID" "$_ble_base/cache"
  fi
fi

_ble_base_cache="$_ble_base_cache/$UID"
if [[ ! -d $_ble_base_tmp ]]; then
  command mkdir -p "$_ble_base_cache"
fi

#%if measure_load_time
}
#%end

##%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/color/
#%x inc.r/@/edit/
#%x inc.r/@/syntax/
#------------------------------------------------------------------------------
# function .ble-time { echo "$*"; time "$@"; }

function ble-initialize {
  ble-decode-initialize # 54ms
  ble-edit/load-default-key-bindings # 4ms
  ble-edit-initialize # 4ms
}

_ble_attached=
function ble-attach {
  [[ $_ble_attached ]] && return
  if [[ ! -o emacs ]]; then
    echo "ble-attach: cancelled. ble.sh is intended to be used in the emacs editing mode (set -o emacs)." >&2
    return 1
  fi

  _ble_attached=1
  _ble_edit_detach_flag= # do not detach or exit
  local IFS=$' \t\n'
  ble-decode-attach # 53ms
  ble-edit-attach # 0ms
  ble-edit/render/redraw # 34ms
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

###############################################################################
