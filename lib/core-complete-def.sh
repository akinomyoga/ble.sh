#!/bin/bash

ble/function#try ble/util/idle.push 'ble-import "$_ble_base/lib/core-complete.sh"'

#------------------------------------------------------------------------------
# 公開関数と公開関数

ble-autoload "$_ble_base/lib/core-complete.sh" \
             ble/widget/complete \
             ble/widget/menu-complete \
             ble/widget/auto-complete-enter \
             ble/widget/sabbrev-expand \
             ble/widget/dabbrev-expand \
             ble-sabbrev

_ble_complete_load_hook=()
_ble_complete_insert_hook=()

if ((_ble_bash>=40200)); then
  declare -gA _ble_complete_sabbrev=()
elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  declare -A _ble_complete_sabbrev=()
fi

#------------------------------------------------------------------------------
# 設定変数

: ${bleopt_complete_stdin_frequency:=50}
: ${bleopt_complete_ambiguous:=1}
: ${bleopt_complete_contract_function_names:=1}
: ${bleopt_complete_auto_delay:=1}
: ${bleopt_complete_auto_history:=1}

## オプション complete_menu_style
##   補完候補のリスト表示のスタイルを指定します。
##
##   dense
##   dense-nowrap
##   align
##   align-nowrap
##
: ${bleopt_complete_menu_style:=align-nowrap}
: ${bleopt_complete_menu_align:=20}
: ${bleopt_complete_menu_complete:=1}

function bleopt/check:complete_menu_style {
  if ! ble/is-function "ble-complete/menu/style:$value/construct"; then
    echo "bleopt: Invalid value complete_menu_style='$value'." \
         "A function 'ble-complete/menu/style:$value/construct' is not defined." >&2
    return 1
  fi

  return 0
}
ble-autoload "$_ble_base/lib/core-complete.sh" \
             ble-complete/menu/style:align/construct \
             ble-complete/menu/style:align-nowrap/construct \
             ble-complete/menu/style:dense/construct \
             ble-complete/menu/style:dense-nowrap/construct


#------------------------------------------------------------------------------
# 描画設定

ble-color-defface menu_complete fg=12,bg=252
ble-color-defface auto_complete bg=254,fg=238
