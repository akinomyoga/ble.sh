#!/bin/bash

function ble-edit/bind/load-keymap-definition:vi_digraph { :; }

_ble_keymap_vi_digraph__hook=

function ble/widget/vi_digraph/.proc {
  local code=$1
  local hook=${_ble_keymap_vi_digraph__hook:-ble-decode-key}
  _ble_keymap_vi_digraph__hook=
  ble-decode/keymap/pop
  eval "$hook $code"
}

function ble/widget/vi_digraph/defchar {
  ble/widget/vi_digraph/.proc "${KEYS[0]}"
}

function ble/widget/vi_digraph/default {
  local kcode=${KEYS[0]}
  local flag=$((kcode&ble_decode_MaskFlag)) char=$((kcode&ble_decode_MaskChar))
  if ((flag==ble_decode_Ctrl&&63<=char&&char<128&&(char&0x1F)!=0)); then
    ((char=char==63?127:char&0x1F))
    ble/widget/vi_digraph/.proc "$char"
    return 0
  fi

  ble/widget/.bell
  return 0
}

function ble-decode/keymap:vi_digraph/define {
  local ble_bind_keymap=vi_digraph

  ble-bind -f __defchar__ vi_digraph/defchar
  ble-bind -f __default__ vi_digraph/default

  local lines; ble/util/mapfile lines < "$_ble_base/keymap/vi_digraph.txt"

  local line field ch1 ch2 code
  for line in "${lines[@]}"; do
    [[ $line == ??' '* ]] || continue
    ch1=${line::1}
    ch2=${line:1:1}
    code=${line:3}
    ble-bind -f "$ch1 $ch2" "vi_digraph/.proc $code"
  done
}

function ble-decode/keymap:vi_digraph/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi_digraph
  if [[ -s $fname_keymap_cache &&
          $fname_keymap_cache -nt $_ble_base/keymap/vi_digraph.sh &&
          $fname_keymap_cache -nt $_ble_base/keymap/vi_digraph.txt ]]; then
    source "$fname_keymap_cache"
    return
  fi

  ble-edit/info/show text "ble.sh: updating cache/keymap.vi_digraph..."

  ble-decode/keymap:vi_digraph/define

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_digraph >> "$fname_keymap_cache"

  ble-edit/info/show text "ble.sh: updating cache/keymap.vi_digraph... done"
}

ble-decode/keymap:vi_digraph/initialize
