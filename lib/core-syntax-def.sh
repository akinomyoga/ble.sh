# -*- mode: sh; mode: sh-bash -*-

# 本体は lib/core-syntax.sh にある。遅延読み込みする。

#------------------------------------------------------------------------------
# 公開変数

# exported variables
_ble_syntax_VARNAMES=(
  _ble_syntax_text
  _ble_syntax_lang
  _ble_syntax_stat
  _ble_syntax_nest
  _ble_syntax_tree
  _ble_syntax_attr
  _ble_syntax_attr_umin
  _ble_syntax_attr_umax
  _ble_syntax_word_umin
  _ble_syntax_word_umax
  _ble_syntax_vanishing_word_umin
  _ble_syntax_vanishing_word_umax
  _ble_syntax_dbeg
  _ble_syntax_dend)
_ble_syntax_lang=bash

function ble/syntax/initialize-vars {
  _ble_syntax_text=
  _ble_syntax_lang=bash
  _ble_syntax_stat=()
  _ble_syntax_nest=()
  _ble_syntax_tree=()
  _ble_syntax_attr=()

  _ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
  _ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
  _ble_syntax_vanishing_word_umin=-1
  _ble_syntax_vanishing_word_umax=-1
  _ble_syntax_dbeg=-1 _ble_syntax_dend=-1
}

#------------------------------------------------------------------------------
# 公開関数

# 関数 ble/syntax/parse は実際に import されるまで定義しない

# 関数 ble/highlight/layer:syntax/* は import されるまではダミーの実装にする

## @fn ble/highlight/layer:syntax/update (暫定)
##   PREV_BUFF, PREV_UMIN, PREV_UMAX を変更せずにそのまま戻れば良い。
function ble/highlight/layer:syntax/update { true; }
## @fn ble/highlight/layer:region/getg (暫定)
##   g を設定せず戻ればそのまま上のレイヤーに問い合わせが行く。
function ble/highlight/layer:syntax/getg { true; }


## @fn ble/syntax:bash/is-complete
##   syntax がロードされる迄は常に真値。
function ble/syntax:bash/is-complete { true; }


# 以下の関数に関しては遅延せずにその場で lib/core-syntax.sh をロードする
ble/util/autoload "$_ble_base/lib/core-syntax.sh" \
  ble/syntax/parse \
  ble/syntax/highlight \
  ble/syntax/tree-enumerate \
  ble/syntax/tree-enumerate-children \
  ble/syntax/completion-context/generate \
  ble/syntax/highlight/cmdtype \
  ble/syntax/highlight/cmdtype1 \
  ble/syntax/highlight/filetype \
  ble/syntax/highlight/getg-from-filename \
  ble/syntax:bash/extract-command \
  ble/syntax:bash/simple-word/eval \
  ble/syntax:bash/simple-word/evaluate-path-spec \
  ble/syntax:bash/simple-word/is-never-word \
  ble/syntax:bash/simple-word/is-simple \
  ble/syntax:bash/simple-word/is-simple-or-open-simple \
  ble/syntax:bash/simple-word/reconstruct-incomplete-word \
  ble/syntax:bash/simple-word/get-rex_element

#------------------------------------------------------------------------------
# グローバル変数の定義 (関数内からではできないのでここで先に定義)

bleopt/declare -v syntax_debug ''

bleopt/declare -v filename_ls_colors ''

bleopt/declare -v highlight_syntax 1
bleopt/declare -v highlight_filename 1
bleopt/declare -v highlight_variable 1
bleopt/declare -v highlight_timeout_sync 50
bleopt/declare -v highlight_timeout_async 5000
bleopt/declare -v syntax_eval_polling_interval 50

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_syntax_highlight_filetype}"
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_syntax_highlight_lscolors_ext}"
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_syntax_bash_simple_eval}"
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_syntax_bash_simple_eval_full}"

#------------------------------------------------------------------------------
# face の定義
#
# プロンプトで face を参照していると最初のプロンプト表示時に initialize-faces
# が実行され、ユーザーが blerc に設定した setface も実行される。この時点では
# core-syntax.sh は未だ読み込まれていないので、face の定義が core-syntax.sh の
# 中にあると face が見つからないエラーになる。

function ble/syntax/attr2g { ble/color/initialize-faces && ble/syntax/attr2g "$@"; }

function ble/syntax/defface.onload {
  function ble/syntax/attr2g {
    local iface=${_ble_syntax_attr2iface[$1]:-_ble_faces__syntax_default}
    g=${_ble_faces[iface]}
  }

  # Note: navy was replaced by 26 for dark background
  # Note: gray was replaced by 242 for dark background

  ble/color/defface syntax_default           none
  ble/color/defface syntax_command           fg=brown
  ble/color/defface syntax_quoted            fg=green
  ble/color/defface syntax_quotation         fg=green,bold
  ble/color/defface syntax_escape            fg=magenta
  ble/color/defface syntax_expr              fg=26
  ble/color/defface syntax_error             bg=203,fg=231 # bg=224
  ble/color/defface syntax_varname           fg=202
  ble/color/defface syntax_delimiter         bold
  ble/color/defface syntax_param_expansion   fg=purple
  ble/color/defface syntax_history_expansion bg=94,fg=231
  ble/color/defface syntax_function_name     fg=92,bold # fg=purple
  ble/color/defface syntax_comment           fg=242
  ble/color/defface syntax_glob              fg=198,bold
  ble/color/defface syntax_brace             fg=37,bold
  ble/color/defface syntax_tilde             fg=navy,bold
  ble/color/defface syntax_document          fg=94
  ble/color/defface syntax_document_begin    fg=94,bold

  ble/color/defface command_builtin_dot fg=red,bold
  ble/color/defface command_builtin     fg=red
  ble/color/defface command_alias       fg=teal
  ble/color/defface command_function    fg=92 # fg=purple
  ble/color/defface command_file        fg=green
  ble/color/defface command_keyword     fg=blue
  ble/color/defface command_jobs        fg=red,bold
  ble/color/defface command_directory   fg=26,underline
  ble/color/defface command_suffix      fg=white,bg=green
  ble/color/defface command_suffix_new  fg=white,bg=brown
  ble/color/defface filename_directory        underline,fg=26
  ble/color/defface filename_directory_sticky underline,fg=white,bg=26
  ble/color/defface filename_link             underline,fg=teal
  ble/color/defface filename_orphan           underline,fg=teal,bg=224
  ble/color/defface filename_setuid           underline,fg=black,bg=220
  ble/color/defface filename_setgid           underline,fg=black,bg=191
  ble/color/defface filename_executable       underline,fg=green
  ble/color/defface filename_other            underline
  ble/color/defface filename_socket           underline,fg=cyan,bg=black
  ble/color/defface filename_pipe             underline,fg=lime,bg=black
  ble/color/defface filename_character        underline,fg=white,bg=black
  ble/color/defface filename_block            underline,fg=yellow,bg=black
  ble/color/defface filename_warning          underline,fg=red
  ble/color/defface filename_url              underline,fg=blue
  ble/color/defface filename_ls_colors        underline
  ble/color/defface varname_unset     fg=124
  ble/color/defface varname_empty     fg=31
  ble/color/defface varname_number    fg=64
  ble/color/defface varname_expr      fg=92,bold
  ble/color/defface varname_array     fg=orange,bold
  ble/color/defface varname_hash      fg=70,bold
  ble/color/defface varname_readonly  fg=200
  ble/color/defface varname_transform fg=29,bold
  ble/color/defface varname_export    fg=200,bold
  ble/color/defface argument_option   fg=teal
  ble/color/defface argument_error    fg=black,bg=225
}
blehook/eval-after-load color_defface ble/syntax/defface.onload

#------------------------------------------------------------------------------
# 遅延読み込みの設定

# lib/core-syntax.sh の変数または ble/syntax/parse を使用する必要がある場合は、
# 以下の関数を用いて lib/core-syntax.sh を必ずロードする様にする。
function ble/syntax/import {
  ble/util/import "$_ble_base/lib/core-syntax.sh"
}

# Note: 初期化順序の都合で一番最後に実行する。lib/core-syntax 内で登録
# している ble/syntax/attr2iface/color_defface.onload は、上記で登録し
# ている ble/syntax/defface.onload よりも後に実行する必要がある為。
ble-import -d lib/core-syntax
