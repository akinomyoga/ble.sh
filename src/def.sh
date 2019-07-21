# -*- mode: sh; mode: sh-bash -*-

function blehook/declare {
  local name=$1
  eval "_ble_hook_h_$name=()"
  eval "_ble_hook_c_$name=0"
}

# ble.pp

blehook/declare EXIT

# util.sh

blehook/declare DA1R
blehook/declare DA2R

# color.sh

blehook/declare color_init_defface
blehook/declare color_init_setface

# history.sh

blehook/declare ADDHISTORY
blehook/declare history_reset_background
blehook/declare history_onleave
blehook/declare history_delete
blehook/declare history_clear
blehook/declare history_message

# edit.sh

blehook/declare CHPWD
blehook/declare PRECMD
blehook/declare PREEXEC
blehook/declare POSTEXEC
blehook/declare widget_bell

# keymap

blehook/declare keymap_load
blehook/declare keymap_vi_load
blehook/declare keymap_emacs_load

# core-complete.sh

blehook/declare complete_load
blehook/declare complete_insert

# for compatibility:
function blehook/.compatibility-ble-0.3 {
  blehook keymap_load+='ble/util/invoke-hook _ble_keymap_default_load_hook'
  blehook keymap_emacs_load+='ble/util/invoke-hook _ble_keymap_emacs_load_hook'
  blehook keymap_vi_load+='ble/util/invoke-hook _ble_keymap_vi_load_hook'
  blehook complete_load+='ble/util/invoke-hook _ble_complete_load_hook'
}
function blehook/.compatibility-ble-0.3/check {
  if ble/is-array _ble_keymap_default_load_hook ||
      ble/is-array _ble_keymap_vi_load_hook ||
      ble/is-array _ble_keymap_emacs_load_hook ||
      ble/is-array _ble_complete_load_hook
  then
    ble/bin/cat << EOF
# [Change in ble-0.4.0]
#
# Please update your blerc settings for ble-0.4.
# In ble-0.4, use the following form:
# 
#   blehook/eval-after-load keymap SHELL-COMMAND
#   blehook/eval-after-load keymap_vi SHELL-COMMAND
#   blehook/eval-after-load keymap_emacs SHELL-COMMAND
#   blehook/eval-after-load complete SHELL-COMMAND
# 
# instead of the following older form:
# 
#   ble/array#push _ble_keymap_default_load_hook SHELL-COMMAND
#   ble/array#push _ble_keymap_vi_load_hook SHELL-COMMAND
#   ble/array#push _ble_keymap_emacs_load_hook SHELL-COMMAND
#   ble/array#push _ble_complete_load_hook SHELL-COMMAND
# 
# Note: "blehook/eval-after-load" should be called
#   after you defined SHELL-COMMAND.
#
EOF
  fi
}
