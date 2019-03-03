#!/bin/bash

# 本体は lib/core-syntax.sh にある。遅延読み込みする。

#------------------------------------------------------------------------------
# 公開変数

# exported variables
_ble_syntax_VARNAMES=(
  _ble_syntax_text
  _ble_syntax_lang
  _ble_syntax_attr_umin
  _ble_syntax_attr_umax
  _ble_syntax_word_umin
  _ble_syntax_word_umax
  _ble_syntax_vanishing_word_umin
  _ble_syntax_vanishing_word_umax
  _ble_syntax_dbeg
  _ble_syntax_dend)
_ble_syntax_ARRNAMES=(
  _ble_syntax_stat
  _ble_syntax_nest
  _ble_syntax_tree
  _ble_syntax_attr)
_ble_syntax_lang=bash

#------------------------------------------------------------------------------
# 公開関数

# 関数 ble-syntax/parse は実際に import されるまで定義しない

# 関数 ble/highlight/layer:syntax/* は import されるまではダミーの実装にする

## 関数 ble/highlight/layer:syntax/update (暫定)
##   PREV_BUFF, PREV_UMIN, PREV_UMAX を変更せずにそのまま戻れば良い。
function ble/highlight/layer:syntax/update { return; }
## 関数 ble/highlight/layer:region/getg (暫定)
##   g を設定せず戻ればそのまま上のレイヤーに問い合わせが行く。
function ble/highlight/layer:syntax/getg { return; }


## 関数 ble-syntax:bash/is-complete
##   sytax がロードされる迄は常に真値。
function ble-syntax:bash/is-complete { true; }


# 以下の関数に関しては遅延せずにその場で lib/core-syntax.sh をロードする
ble/util/autoload "$_ble_base/lib/core-syntax.sh" \
             ble-syntax/completion-context/generate \
             ble-syntax:bash/is-complete \
             ble-syntax:bash/extract-command \
             ble-syntax:bash/simple-word/eval \
             ble-syntax:bash/simple-word/is-simple \
             ble-syntax:bash/simple-word/reconstruct-incomplete-word

#------------------------------------------------------------------------------
# 遅延読み込みの設定

# lib/core-syntax.sh の変数または ble-syntax/parse を使用する必要がある場合は、
# 以下の関数を用いて lib/core-syntax.sh を必ずロードする様にする。
function ble-syntax/import {
  ble/util/import "$_ble_base/lib/core-syntax.sh"
}

ble/function#try ble/util/idle.push ble-syntax/import ||
  ble-syntax/import

#------------------------------------------------------------------------------
# グローバル変数の定義 (関数内からではできないのでここで先に定義)

bleopt/declare -v filename_ls_colors ''

if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  if ((_ble_bash>=40200)); then
    declare -gA _ble_syntax_highlight_filetype=()
    declare -gA _ble_syntax_highlight_lscolors_ext=()
  else
    declare -A _ble_syntax_highlight_filetype=()
    declare -A _ble_syntax_highlight_lscolors_ext=()
  fi
fi
