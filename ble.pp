#!/bin/bash
#%$> ble.sh
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
# Author: K. Murase <myoga.murase@gmail.com>
#
if test -n "${-##*i*}"; then
  echo "ble.sh: this is not an interactive session."
  return 1
fi

[ -n "$_ble_bash" ] || declare -ir _ble_bash='BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]'

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
if test ! -d "$_ble_base/ble.d"; then
  echo "ble.sh: ble.d not found!" 1>&2
  return 1
  #mkdir -p "$_ble_base/ble.d"
fi

# tmpdir
if test ! -d "$_ble_base/ble.d/tmp"; then
  mkdir -p "$_ble_base/ble.d/tmp"
  chmod a+rwxt "$_ble_base/ble.d/tmp"
fi

#%x inc.r/@/getopt/
#%x inc.r/@/core/
#%x inc.r/@/decode/
#%x inc.r/@/edit/
#%x inc.r/@/color/

#------------------------------------------------------------------------------
# function .ble-time { echo "$*"; time "$@"; }
function .ble-time { eval "$@"; }

.ble-time ble-decode-bind.cmap
.ble-time ble-decode-bind
.ble-time .ble-edit-initialize
.ble-time .ble-edit.default-key-bindings
.ble-time .ble-edit-draw.redraw
.ble-time .ble-edit/stdout/off

###############################################################################
