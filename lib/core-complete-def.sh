#!/bin/bash

ble/function#try ble/util/idle.push 'ble/util/import "$_ble_base/lib/core-complete.sh"'

#------------------------------------------------------------------------------
# 公開関数と公開関数

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
             ble/widget/complete \
             ble/widget/menu-complete \
             ble/widget/auto-complete-enter \
             ble/widget/sabbrev-expand \
             ble/widget/dabbrev-expand \
             ble-sabbrev

_ble_complete_load_hook=()
_ble_complete_insert_hook=()

if ! declare -p _ble_complete_sabbrev &>/dev/null; then # reload #D0875
  if ((_ble_bash>=40300)); then
    declare -gA _ble_complete_sabbrev=()
  elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
    declare -A _ble_complete_sabbrev=()
  fi
fi

#------------------------------------------------------------------------------
# 設定変数

bleopt/declare -n complete_polling_cycle 50
bleopt_complete_stdin_frequency='[obsoleted]'
function bleopt/check:complete_stdin_frequency {
  var=bleopt_complete_polling_cycle
  echo 'bleopt: The option "complete_stdin_frequency" is obsoleted. Please use "complete_polling_cycle".' >&2
  return 0
}

bleopt/declare -v complete_ambiguous 1
bleopt/declare -v complete_contract_function_names 1
bleopt/declare -v complete_auto_complete 1
bleopt/declare -v complete_auto_history 1
bleopt/declare -n complete_auto_delay 1

## オプション complete_menu_style
##   補完候補のリスト表示のスタイルを指定します。
##
##   dense
##   dense-nowrap
##   align
##   align-nowrap
##
bleopt/declare -n complete_menu_style align-nowrap
function bleopt/check:complete_menu_style {
  if ! ble/is-function "ble/complete/menu/style:$value/construct-page"; then
    builtin printf '%s\n' \
            "bleopt: Invalid value complete_menu_style='$value'." \
            "  A function 'ble/complete/menu/style:$value/construct-page' is not defined." >&2
    return 1
  fi
  return 0
}

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu/style:{align,dense}{,-nowrap}/construct-page \
                  ble/complete/menu/style:desc{,-raw}/construct-page

bleopt/declare -n complete_menu_align 20
bleopt/declare -v complete_menu_complete 1
bleopt/declare -v complete_menu_filter 1

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu/style:align/construct \
                  ble/complete/menu/style:align-nowrap/construct \
                  ble/complete/menu/style:dense/construct \
                  ble/complete/menu/style:dense-nowrap/construct \
                  ble-decode/keymap:auto_complete/define \
                  ble-decode/keymap:menu_complete/define \
                  ble-decode/keymap:dabbrev/define \
                  ble/complete/sabbrev/expand

#------------------------------------------------------------------------------
# 描画設定

ble-color-defface menu_complete fg=12,bg=252
ble-color-defface auto_complete bg=254,fg=238
ble-color-defface cmdinfo_cd_cdpath fg=26,bg=155
