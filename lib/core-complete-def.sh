#!/bin/bash

ble/function#try ble/util/idle.push 'ble/util/import "$_ble_base/lib/core-complete.sh"'

#------------------------------------------------------------------------------
# 公開関数と公開関数

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/widget/complete \
                  ble/widget/menu-complete \
                  ble/widget/auto-complete-enter \
                  ble/widget/sabbrev-expand \
                  ble/widget/dabbrev-expand

function ble-sabbrev {
  local ret; ble/string#quote-command "$FUNCNAME" "$@"
  blehook/eval-after-load complete "$ret"
}

if ! declare -p _ble_complete_sabbrev &>/dev/null; then # reload #D0875
  if ((_ble_bash>=40200)); then
    declare -gA _ble_complete_sabbrev=()
  elif ((_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
    declare -A _ble_complete_sabbrev=()
  fi
fi

#------------------------------------------------------------------------------
# 設定変数

bleopt/declare -n complete_polling_cycle 50
bleopt/declare -o complete_stdin_frequency complete_polling_cycle

bleopt/declare -v complete_ambiguous 1
bleopt/declare -v complete_contract_function_names 1
bleopt/declare -v complete_auto_complete 1
bleopt/declare -v complete_auto_history 1
bleopt/declare -n complete_auto_delay 1
bleopt/declare -v complete_auto_wordbreaks $' \t\n'
bleopt/declare -v complete_auto_menu ''
bleopt/declare -v complete_allow_reduction ''

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
  if ! ble/is-function "ble/complete/menu-style:$value/construct-page"; then
    builtin printf '%s\n' \
            "bleopt: Invalid value complete_menu_style='$value'." \
            "  A function 'ble/complete/menu-style:$value/construct-page' is not defined." >&2
    return 1
  fi
  return 0
}

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu-style:{align,dense}{,-nowrap}/construct-page \
                  ble/complete/menu-style:linewise/construct-page \
                  ble/complete/menu-style:desc{,-raw}/construct-page

bleopt/declare -v menu_linewise_prefix ''
bleopt/declare -n complete_menu_align 20
bleopt/declare -v complete_menu_complete 1
bleopt/declare -v complete_menu_filter 1
bleopt/declare -v complete_menu_maxlines '-1'

ble/util/autoload "$_ble_base/lib/core-complete.sh" \
                  ble/complete/menu#start \
                  ble-decode/keymap:menu/define \
                  ble-decode/keymap:auto_complete/define \
                  ble-decode/keymap:menu_complete/define \
                  ble-decode/keymap:dabbrev/define \
                  ble/complete/sabbrev/expand

#------------------------------------------------------------------------------
# 描画設定

ble-color-defface auto_complete bg=254,fg=238
