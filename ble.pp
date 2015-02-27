#!/bin/bash
#%$> out/ble.sh
#%[debug=1]
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
  _ble_bash=0
  echo "ble.sh: A bash with a version under 3.1 is not supported" >&2
  return 1 2>/dev/null || exit 1
fi

#------------------------------------------------------------------------------

function _ble_base.initialize {
  local src="$1"
  local defaultDir="$2"

  # resolve symlink
  if test -h "$src" && type -t readlink &>/dev/null; then
    src="$(readlink -f "$src")"
  fi

  local dir="${src%/*}"
  if test "$dir" != "$src"; then
    if test -z "$dir"; then
      _ble_base=/
    elif test "x${dir::1}" != x/; then
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

# tmpdir
if [[ ! -d $_ble_base/tmp ]]; then
  mkdir -p "$_ble_base/tmp"
  chmod a+rwxt "$_ble_base/tmp"
fi

if [[ ! -d $_ble_base/cache ]]; then
  mkdir -p "$_ble_base/cache"
fi

#%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/edit/
#%x inc.r/@/color/
#%x inc.r/@/syntax/

#------------------------------------------------------------------------------
# function .ble-time { echo "$*"; time "$@"; }

function ble-initialize {
  ble-decode-initialize
  .ble-edit.default-key-bindings
  ble-edit-initialize
}

function ble-attach {
  _ble_edit_detach_flag=
  ble-decode-attach
  ble-edit-attach
  .ble-edit-draw.redraw
  .ble-edit/stdout/off
}

function ble-detach {
  _ble_edit_detach_flag=detach
}

ble-initialize
[[ $1 != noattach ]] && ble-attach

###############################################################################
