#!/bin/bash

# 2020-04-29 force update (rename ble-decode/keymap/.register)
# 2021-04-26 force update (rename ble/decode/keymap#.register)

_ble_keymap_vi_digraph__hook=

function ble/widget/vi_digraph/.proc {
  local code=$1
  local hook=${_ble_keymap_vi_digraph__hook:-ble-decode-key}
  _ble_keymap_vi_digraph__hook=
  ble/decode/keymap/pop
  builtin eval -- "$hook $code"
}

function ble/widget/vi_digraph/defchar {
  ble/widget/vi_digraph/.proc "${KEYS[0]}"
}

function ble/widget/vi_digraph/default {
  local key=${KEYS[0]}
  local flag=$((key&_ble_decode_MaskFlag)) char=$((key&_ble_decode_MaskChar))
  if ((flag==_ble_decode_Ctrl&&63<=char&&char<128&&(char&0x1F)!=0)); then
    ((char=char==63?127:char&0x1F))
    ble/widget/vi_digraph/.proc "$char"
    return 0
  fi

  ble/widget/.bell
  return 0
}

function ble-decode/keymap:vi_digraph/define {
  ble-bind -f __defchar__ vi_digraph/defchar
  ble-bind -f __default__ vi_digraph/default
  ble-bind -f __line_limit__ nop

  local lines; ble/util/mapfile lines < "$_ble_base/lib/keymap.vi_digraph.txt"

  local line field ch1 ch2 code
  for line in "${lines[@]}"; do
    [[ $line == ??' '* ]] || continue
    [[ $OSTYPE == msys* ]] && line=${line%$'\r'}
    ch1=${line::1}
    ch2=${line:1:1}
    code=${line:3}
    ble-bind -f "$ch1 $ch2" "vi_digraph/.proc $code"
  done
}

function ble-decode/keymap:vi_digraph/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi_digraph
  if [[ -s $fname_keymap_cache &&
          $fname_keymap_cache -nt $_ble_base/lib/keymap.vi_digraph.sh &&
          $fname_keymap_cache -nt $_ble_base/lib/keymap.vi_digraph.txt ]]; then
    source "$fname_keymap_cache"
    return 0
  fi

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi_digraph..."

  : >| "$fname_keymap_cache"
  ble/decode/keymap#load vi_digraph dump 3>> "$fname_keymap_cache"

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi_digraph... done"
}

ble-decode/keymap:vi_digraph/initialize
