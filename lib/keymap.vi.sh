#!/bin/bash

# Note: bind (INITIALIZE_DEFMAP) の中から再帰的に呼び出されうるので、
# 先に ble-edit/bind/load-editing-mode:vi を上書きする必要がある。
ble/is-function ble-edit/bind/load-editing-mode:vi && return 0
function ble-edit/bind/load-editing-mode:vi { :; }

# 2020-04-29 force update (rename ble-decode/keymap/.register)
# 2021-01-25 force update (change mapping of C-w and M-w)
# 2021-04-26 force update (rename ble/decode/keymap#.register)
# 2021-09-23 force update (change to nsearch and bind-history)

source "$_ble_base/lib/keymap.vi_digraph.sh"

## @bleopt keymap_vi_macro_depth
bleopt/declare -n keymap_vi_macro_depth 64

## @fn ble/keymap:vi/k2c key
##   @var[out] ret
function ble/keymap:vi/k2c {
  local key=$1
  local flag=$((key&_ble_decode_MaskFlag)) char=$((key&_ble_decode_MaskChar))
  if ((flag==0&&(32<=char&&char<_ble_decode_FunctionKeyBase))); then
    ret=$char
    return 0
  elif ((flag==_ble_decode_Ctrl&&63<=char&&char<128&&(char&0x1F)!=0)); then
    ((char=char==63?127:char&0x1F))
    ret=$char
    return 0
  else
    return 1
  fi
}

#------------------------------------------------------------------------------
# utils

## @fn ble/string#index-of-chars text chars [index]
##   文字集合に含まれる文字を、文字列中で順方向に探索します。
## @fn ble/string#last-index-of-chars text chars [index]
##   文字集合に含まれる文字を、文字列中で逆方向に探索します。
##
##   @param[in] text
##     検索する対象の文字列を指定します。
##   @param[in] chars
##     検索する文字の集合を指定します
##   @param[in] index
##     text の内の検索開始位置を指定します。
##   @var[out] ret
##
function ble/string#index-of-chars {
  local chars=$2 index=${3:-0}
  local text=${1:index}
  local cut=${text%%["$chars"]*}
  if ((${#cut}<${#text})); then
    ((ret=index+${#cut}))
    return 0
  else
    ret=-1
    return 1
  fi
}
function ble/string#last-index-of-chars {
  local text=$1 chars=$2 index=$3
  [[ $index ]] && text=${text::index}
  local cut=${text%["$chars"]*}
  if ((${#cut}<${#text})); then
    ((ret=${#cut}))
    return 0
  else
    ret=-1
    return 1
  fi
}

## @fn ble-edit/content/nonbol-eolp text
##   @var[out] ret
function ble-edit/content/nonbol-eolp {
  local pos=${1:-$_ble_edit_ind}
  ! ble-edit/content/bolp "$pos" && ble-edit/content/eolp "$pos"
}

## @fn ble/keymap:vi/string#encode-rot13 text
##   @var[out] ret
function ble/keymap:vi/string#encode-rot13 {
  local text=$1
  local -a buff=() ch
  for ((i=0;i<${#text};i++)); do
    ch=${text:i:1}
    if ble/string#isupper "$ch"; then
      ch=${_ble_util_string_upper_list%%"$ch"*}
      ch=${_ble_util_string_upper_list:(${#ch}+13)%26:1}
    elif ble/string#islower "$ch"; then
      ch=${_ble_util_string_lower_list%%"$ch"*}
      ch=${_ble_util_string_lower_list:(${#ch}+13)%26:1}
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]-}"'
}

#------------------------------------------------------------------------------
# constants

_ble_keymap_vi_REX_WORD=$'[_a-zA-Z0-9]+|[!-/:-@[-`{-~]+|[^ \t\na-zA-Z0-9!-/:-@[-`{-~]+'

#------------------------------------------------------------------------------
# vi_imap/__default__, vi-command/decompose-meta

function ble/widget/vi_imap/__default__ {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag)) code=$((KEYS[0]&_ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&_ble_decode_Meta)); then
    ble/keymap:vi/imap-repeat/pop

    local esc=27 # ESC
    # local esc=$((_ble_decode_Ctrl|0x5b)) # もしくは C-[
    ble/decode/widget/skip-lastwidget
    ((flag&=~_ble_decode_Meta))
    ((flag==_ble_decode_Shft&&0x61<=code&&code<=0x7A&&(flag=0,code-=0x20)))
    ble/decode/widget/redispatch-by-keys "$esc" "$((flag|code))" "${KEYS[@]:1}"
    return 0
  fi

  # Control 修飾された文字 C-@ - C-\, C-? は制御文字 \000 - \037, \177 に戻して挿入
  if local ret; ble/keymap:vi/k2c "${KEYS[0]}"; then
    local -a KEYS; KEYS=("$ret")
    ble/widget/self-insert
    return 0
  fi

  return 125
}

function ble/widget/vi-command/decompose-meta {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag)) code=$((KEYS[0]&_ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&_ble_decode_Meta)); then
    local esc=$((_ble_decode_Ctrl|0x5b)) # C-[ (もしくは esc=27 ESC?)
    ble/decode/widget/skip-lastwidget
    ((flag&=~_ble_decode_Meta))
    ((flag==_ble_decode_Shft&&0x61<=code&&code<=0x7A&&(flag=0,code-=0x20)))
    ble/decode/widget/redispatch-by-keys "$esc" "$((flag|code))" "${KEYS[@]:1}"
    return 0
  fi

  return 125
}

function ble/widget/vi_omap/__default__ {
  ble/widget/vi-command/decompose-meta || ble/widget/vi-command/bell
  return 0
}
function ble/widget/vi_omap/cancel {
  ble/keymap:vi/adjust-command-mode
  return 0
}

#------------------------------------------------------------------------------
# repeat

## @var _ble_keymap_vi_irepeat_count
##   挿入モードに入る時に指定された引数を記録する。
_ble_keymap_vi_irepeat_count=

## @arr _ble_keymap_vi_irepeat
##   挿入モードに入るときに指定された引数が 1 より大きい時、
##   後で操作を繰り返すために操作内容を記録する配列。
##
##   各要素は keys:widget の形式を持つ。
##   keys は空白区切りの key (整数値) の列、つまり ${KEYS[*]} である。
##   widget は実際に呼び出す WIDGET の内容である。
##
_ble_keymap_vi_irepeat=()

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_irepeat_count \
               _ble_keymap_vi_irepeat

function ble/keymap:vi/imap-repeat/pop {
  local top_index=$((${#_ble_keymap_vi_irepeat[*]}-1))
  ((top_index>=0)) && builtin unset -v '_ble_keymap_vi_irepeat[top_index]'
}
function ble/keymap:vi/imap-repeat/push {
  local IFS=$_ble_term_IFS
  ble/array#push _ble_keymap_vi_irepeat "${KEYS[*]-}:$WIDGET"
}

function ble/keymap:vi/imap-repeat/reset {
  local count=${1-}
  _ble_keymap_vi_irepeat_count=
  _ble_keymap_vi_irepeat=()
  ((count>1)) && _ble_keymap_vi_irepeat_count=$count
}
function ble/keymap:vi/imap-repeat/process {
  if ((_ble_keymap_vi_irepeat_count>1)); then
    local repeat=$_ble_keymap_vi_irepeat_count
    local -a widgets; widgets=("${_ble_keymap_vi_irepeat[@]}")

    local i widget
    for ((i=1;i<repeat;i++)); do
      for widget in "${widgets[@]}"; do
        ble/decode/widget/call "${widget#*:}" ${widget%%:*}
      done
    done
  fi
}

function ble/keymap:vi/imap/invoke-widget {
  local WIDGET=$1
  local -a KEYS; KEYS=("${@:2}")
  ble/keymap:vi/imap-repeat/push
  builtin eval -- "$WIDGET"
}

## @arr _ble_keymap_vi_imap_white_list
##   引数を指定して入った挿入モードを抜けるときの繰り返しで許されるコマンドのリスト
_ble_keymap_vi_imap_white_list=(
  self-insert
  batch-insert
  nop
  magic-space magic-slash
  delete-backward-{c,f,s,u}word
  copy{,-forward,-backward}-{c,f,s,u}word
  copy-region{,-or}
  clear-screen
  command-help
  display-shell-version
  redraw-line
)
function ble/keymap:vi/imap/is-command-white {
  if [[ $1 == ble/widget/self-insert ]]; then
    # frequently used command is checked first
    return 0
  elif [[ $1 == ble/widget/* ]]; then
    local IFS=$_ble_term_IFS
    local cmd=${1#ble/widget/}; cmd=${cmd%%["$_ble_term_IFS"]*}
    [[ $cmd == vi_imap/* || " ${_ble_keymap_vi_imap_white_list[*]} " == *" $cmd "*  ]] && return 0
  fi
  return 1
}

function ble/widget/vi_imap/__before_widget__ {
  if ble/keymap:vi/imap/is-command-white "$WIDGET"; then
    ble/keymap:vi/imap-repeat/push
  else
    if ((_ble_keymap_vi_mark_edit_dbeg>=0)); then
      ble/keymap:vi/mark/end-edit-area
      ble/keymap:vi/repeat/record-insert
      ble/keymap:vi/mark/start-edit-area
    fi
    ble/keymap:vi/imap-repeat/reset
  fi
}

#------------------------------------------------------------------------------
# vi_imap/complete

function ble/widget/vi_imap/complete {
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/undo/add more
  ble/widget/complete "$@"
}
function ble/keymap:vi/complete/insert.hook {
  [[ $_ble_decode_keymap == vi_imap ||
       $_ble_decode_keymap == auto_complete ]] || return 1

  local original=${comp_text:insert_beg:insert_end-insert_beg}
  local q="'" Q="'\''"
  local WIDGET="ble/widget/complete-insert '${original//$q/$Q}' '${insert//$q/$Q}' '${suffix//$q/$Q}'"
  ble/keymap:vi/imap-repeat/push
  [[ $_ble_decode_keymap == vi_imap ]] &&
    ble/keymap:vi/undo/add more
}
blehook complete_insert!=ble/keymap:vi/complete/insert.hook

function ble-decode/keymap:vi_imap/bind-complete {
  ble-bind -f 'C-i'                 'vi_imap/complete'
  ble-bind -f 'TAB'                 'vi_imap/complete'
  ble-bind -f 'C-TAB'               'menu-complete'
  ble-bind -f 'S-C-i'               'menu-complete backward'
  ble-bind -f 'S-TAB'               'menu-complete backward'
  ble-bind -f 'auto_complete_enter' 'auto-complete-enter'

  ble-bind -f 'C-x /' 'menu-complete context=filename'
  ble-bind -f 'C-x ~' 'menu-complete context=username'
  ble-bind -f 'C-x $' 'menu-complete context=variable'
  ble-bind -f 'C-x @' 'menu-complete context=hostname'
  ble-bind -f 'C-x !' 'menu-complete context=command'

  ble-bind -f 'C-]'     'sabbrev-expand'
  ble-bind -f 'C-x C-r' 'dabbrev-expand'

  ble-bind -f 'C-x *' 'complete insert_all:context=glob'
  ble-bind -f 'C-x g' 'complete show_menu:context=glob'
}

#------------------------------------------------------------------------------
# modes

## @var _ble_keymap_vi_insert_overwrite
##   挿入モードに入った時の上書き文字
_ble_keymap_vi_insert_overwrite=

## @var _ble_keymap_vi_insert_leave
##   挿入モードから抜ける時に実行する関数を設定します
_ble_keymap_vi_insert_leave=

## @var _ble_keymap_vi_single_command
##   ノーマルモードにおいて 1 つコマンドを実行したら
##   元の挿入モードに戻るモード (C-o) にいるかどうかを表します。
_ble_keymap_vi_single_command=
_ble_keymap_vi_single_command_overwrite=

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_insert_overwrite \
               _ble_keymap_vi_insert_leave \
               _ble_keymap_vi_single_command \
               _ble_keymap_vi_single_command_overwrite

## @bleopt keymap_vi_mode_string_nmap
##   ノーマルモードの時に表示する文字列を指定します。
##   空文字列を指定したときは何も表示しません。
bleopt/declare -n keymap_vi_mode_string_nmap $'\e[1m~\e[m'
bleopt/declare -o keymap_vi_nmap_name keymap_vi_mode_string_nmap

bleopt/declare -v term_vi_imap ''
bleopt/declare -v term_vi_nmap ''
bleopt/declare -v term_vi_omap ''
bleopt/declare -v term_vi_xmap ''
bleopt/declare -v term_vi_smap ''
bleopt/declare -v term_vi_cmap ''

bleopt/declare -v keymap_vi_imap_cursor ''
bleopt/declare -v keymap_vi_nmap_cursor ''
bleopt/declare -v keymap_vi_omap_cursor ''
bleopt/declare -v keymap_vi_xmap_cursor ''
bleopt/declare -v keymap_vi_smap_cursor ''
bleopt/declare -v keymap_vi_cmap_cursor ''
function ble/keymap:vi/.process-cursor-options {
  local keymap=${FUNCNAME[1]#bleopt/check:keymap_}; keymap=${keymap%_cursor}
  ble-bind -m "$keymap" --cursor "$value"
  local locate=$'\e[32m'$bleopt_source:$bleopt_lineno$'\e[m'
  ble/util/print-lines \
    "bleopt ($locate): The option 'keymap_${keymap}_cursor' has been removed." \
    "  Please use 'ble-bind -m $keymap --cursor $value' instead." >&2
}
function bleopt/check:keymap_vi_imap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_nmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_omap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_xmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_smap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/check:keymap_vi_cmap_cursor { ble/keymap:vi/.process-cursor-options; }
function bleopt/obsolete:keymap_vi_imap_cursor { :; }
function bleopt/obsolete:keymap_vi_nmap_cursor { :; }
function bleopt/obsolete:keymap_vi_omap_cursor { :; }
function bleopt/obsolete:keymap_vi_xmap_cursor { :; }
function bleopt/obsolete:keymap_vi_smap_cursor { :; }
function bleopt/obsolete:keymap_vi_cmap_cursor { :; }

bleopt/declare -v keymap_vi_mode_show 1
function bleopt/check:keymap_vi_mode_show {
  local bleopt_keymap_vi_mode_show=$value
  [[ $_ble_attached ]] &&
    ble/keymap:vi/update-mode-indicator
  return 0
}

bleopt/declare -v keymap_vi_mode_update_prompt ''
bleopt/declare -v keymap_vi_mode_name_insert    'INSERT'
bleopt/declare -v keymap_vi_mode_name_replace   'REPLACE'
bleopt/declare -v keymap_vi_mode_name_vreplace  'VREPLACE'
bleopt/declare -v keymap_vi_mode_name_visual    'VISUAL'
bleopt/declare -v keymap_vi_mode_name_select    'SELECT'
bleopt/declare -v keymap_vi_mode_name_linewise  'LINE'
bleopt/declare -v keymap_vi_mode_name_blockwise 'BLOCK'
function bleopt/check:keymap_vi_mode_name_insert    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_replace   { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_vreplace  { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_visual    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_select    { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_linewise  { ble/keymap:vi/update-mode-indicator; }
function bleopt/check:keymap_vi_mode_name_blockwise { ble/keymap:vi/update-mode-indicator; }


## @fn ble/keymap:vi/script/get-vi-keymap
##   現在の vi キーマップ名 (vi_?map) を取得します。
##   もし現在 vi キーマップにない場合には失敗します。
function ble/keymap:vi/script/get-vi-keymap {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  local i=${#_ble_decode_keymap_stack[@]}

  keymap=$_ble_decode_keymap
  while [[ $keymap != vi_?map && $keymap != emacs ]]; do
    ((i--)) || return 1
    keymap=${_ble_decode_keymap_stack[i]}
  done
  [[ $keymap == vi_?map ]]
}

## @fn ble/keymap:vi/script/get-mode
##   @var[out] mode
function ble/keymap:vi/script/get-mode {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  ble/prompt/unit/add-hash '$_ble_keymap_vi_single_command,$_ble_edit_mark_active'

  mode=

  local keymap; ble/keymap:vi/script/get-vi-keymap

  # /[iR^R]?/
  if [[ $_ble_keymap_vi_single_command || $keymap == vi_imap ]]; then
    local overwrite=
    if [[ $keymap == vi_imap ]]; then
      overwrite=$_ble_edit_overwrite_mode
    elif [[ $keymap == vi_[noxs]map ]]; then
      overwrite=$_ble_keymap_vi_single_command_overwrite
    fi
    case $overwrite in
    ('') mode=i ;;
    (R)  mode=R ;;
    (*)  mode=$'\x12' ;; # C-r
    esac
  fi

  # /[nvV^VsS^S]?/
  case $keymap:${_ble_edit_mark_active%+} in
  (vi_xmap:vi_line) mode=$mode'V' ;;
  (vi_xmap:vi_block)mode=$mode$'\x16' ;; # C-v
  (vi_xmap:*)       mode=$mode'v' ;;
  (vi_smap:vi_line) mode=$mode'S' ;;
  (vi_smap:vi_block)mode=$mode$'\x13' ;; # C-s
  (vi_smap:*)       mode=$mode's' ;;
  (vi_[no]map:*)    mode=$mode'n' ;;
  (vi_cmap:*)       mode=$mode'c' ;;
  (vi_imap:*) ;;
  (*:*)             mode=$mode'?' ;;
  esac
}

_ble_keymap_vi_mode_name_dirty=
function ble/keymap:vi/info_reveal.hook {
  [[ $_ble_keymap_vi_mode_name_dirty ]] || return 0
  _ble_keymap_vi_mode_name_dirty=
  ble/keymap:vi/update-mode-indicator
}
blehook info_reveal!=ble/keymap:vi/info_reveal.hook

bleopt/declare -v prompt_vi_mode_indicator '\q{keymap:vi/mode-indicator}'
function bleopt/check:prompt_vi_mode_indicator {
  local bleopt_prompt_vi_mode_indicator=$value
  [[ $_ble_attached ]] && ble/keymap:vi/update-mode-indicator
  return 0
}

_ble_keymap_vi_mode_indicator_data=()
function ble/prompt/unit:_ble_keymap_vi_mode_indicator/update {
  local trace_opts=truncate:relative:noscrc:ansi
  local prompt_rows=1
  local prompt_cols=${COLUMNS:-80}
  ((prompt_cols&&prompt_cols--))
  local "${_ble_prompt_cache_vars[@]/%/=}" # WA #D1570 checked
  ble/prompt/unit:{section}/update _ble_keymap_vi_mode_indicator "$bleopt_prompt_vi_mode_indicator" "$trace_opts"
}

function ble/keymap:vi/update-mode-indicator {
  if [[ ! $_ble_attached ]] || ble/edit/is-command-layout; then
    _ble_keymap_vi_mode_name_dirty=1
    return 0
  fi

  local keymap
  ble/keymap:vi/script/get-vi-keymap || return 0

  if [[ $keymap == vi_imap ]]; then
    ble/util/buffer "$bleopt_term_vi_imap"
  elif [[ $keymap == vi_nmap ]]; then
    ble/util/buffer "$bleopt_term_vi_nmap"
  elif [[ $keymap == vi_xmap ]]; then
    ble/util/buffer "$bleopt_term_vi_xmap"
  elif [[ $keymap == vi_smap ]]; then
    ble/util/buffer "$bleopt_term_vi_smap"
  elif [[ $keymap == vi_omap ]]; then
    ble/util/buffer "$bleopt_term_vi_omap"
  elif [[ $keymap == vi_cmap ]]; then
    ble/edit/info/default text ''
    ble/util/buffer "$bleopt_term_vi_cmap"
    return 0
  fi

  [[ $bleopt_keymap_vi_mode_update_prompt ]] && ble/prompt/clear

  # prompt_vi_mode_indicator
  local prompt_vi_keymap=$keymap
  local version=$COLUMNS,$_ble_edit_lineno,$_ble_history_count,$_ble_edit_CMD
  local prompt_hashref_base='$version'
  ble/prompt/unit#update _ble_keymap_vi_mode_indicator
  local ret; ble/prompt/unit:{section}/get _ble_keymap_vi_mode_indicator; local mode=$ret

  local str=$mode
  if [[ $_ble_keymap_vi_reg_record ]]; then
    str=$str${str:+' '}$'\e[1;31mREC @'$_ble_keymap_vi_reg_record_char$'\e[m'
  elif [[ $_ble_edit_kbdmacro_record ]]; then
    str=$str${str:+' '}$'\e[1;31mREC\e[m'
  fi

  # Note #D2062: mc-4.8.29 以降ではコマンド終了直後に "-- INSERT --" 等の mode
  # indicator を出力すると、それをプロンプトと勘違いして抽出してしまう。仕方が
  # ないので mc の中では imap に対しては mode indicator は表示しない様にする。
  if [[ $_ble_edit_integration_mc_precmd_stop && $keymap == vi_imap ]]; then
    ble/edit/info/clear
    return 0
  fi

  ble/edit/info/default ansi "$str" # 6ms
}
blehook internal_PRECMD!=ble/keymap:vi/update-mode-indicator

## @fn ble/prompt/backslash:keymap:vi/mode-indicator
##   @var[in,opt] prompt_vi_keymap
##     ble/keymap:vi/script/get-vi-keymap のキャッシュ
function ble/prompt/backslash:keymap:vi/mode-indicator {
  [[ $bleopt_keymap_vi_mode_show ]] || return 0

  local keymap=${prompt_vi_keymap-}
  if [[ $keymap ]]; then
    ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  else
    ble/keymap:vi/script/get-vi-keymap || return 0
  fi

  local name= show= overwrite=
  ble/prompt/unit/add-hash '$_ble_edit_overwrite_mode,$_ble_keymap_vi_single_command,$_ble_keymap_vi_single_command_overwrite'
  if [[ $keymap == vi_imap ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && ( $keymap == vi_nmap || $keymap == vi_omap ) ]]; then
    show=1 overwrite=$_ble_keymap_vi_single_command_overwrite
  elif [[ $keymap == vi_[xs]map ]]; then
    show=x overwrite=$_ble_keymap_vi_single_command_overwrite
  else
    name=$bleopt_keymap_vi_mode_string_nmap
  fi

  if [[ $show ]]; then
    if [[ $overwrite == R ]]; then
      name=$bleopt_keymap_vi_mode_name_replace
    elif [[ $overwrite ]]; then
      name=$bleopt_keymap_vi_mode_name_vreplace
    else
      name=$bleopt_keymap_vi_mode_name_insert
    fi

    if [[ $_ble_keymap_vi_single_command ]]; then
      local ret; ble/string#tolower "$name"; name="($ret)"
    fi

    if [[ $show == x ]]; then
      ble/prompt/unit/add-hash '${_ble_edit_mark_active%+}'
      local mark_type=${_ble_edit_mark_active%+}
      local visual_name=$bleopt_keymap_vi_mode_name_visual
      [[ $keymap == vi_smap ]] && visual_name=$bleopt_keymap_vi_mode_name_select
      if [[ $mark_type == vi_line ]]; then
        visual_name=$visual_name' '$bleopt_keymap_vi_mode_name_linewise
      elif [[ $mark_type == vi_block ]]; then
        visual_name=$visual_name' '$bleopt_keymap_vi_mode_name_blockwise
      fi

      if [[ $_ble_keymap_vi_single_command ]]; then
        name="$name $visual_name"
      else
        name=$visual_name
      fi
    fi

    name=$'\e[1m-- '$name$' --\e[m'
  fi

  [[ ! $name ]] || ble/prompt/print "$name"
}

function ble/widget/vi_imap/normal-mode.impl {
  local opts=$1

  # finalize insert mode
  ble/keymap:vi/mark/set-local-mark 94 "$_ble_edit_ind" # `^
  ble/keymap:vi/mark/end-edit-area
  [[ :$opts: == *:InsertLeave:* ]] && builtin eval -- "$_ble_keymap_vi_insert_leave"

  # set up normal mode
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/bolp || ((_ble_edit_ind--))
  ble/decode/keymap/push vi_nmap
}
function ble/widget/vi_imap/normal-mode {
  ble-edit/content/clear-arg
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/imap-repeat/process
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl InsertLeave
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/normal-mode-without-insert-leave {
  ble-edit/content/clear-arg
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/single-command-mode {
  ble-edit/content/clear-arg
  local single_command=1
  local single_command_overwrite=$_ble_edit_overwrite_mode
  ble-edit/content/eolp && _ble_keymap_vi_single_command=2

  ble/keymap:vi/imap-repeat/pop
  ble/widget/vi_imap/normal-mode.impl
  _ble_keymap_vi_single_command=$single_command
  _ble_keymap_vi_single_command_overwrite=$single_command_overwrite
  ble/keymap:vi/update-mode-indicator
  return 0
}

## @fn ble/keymap:vi/needs-eol-fix
##
##   Note: この関数を使った後は ble/keymap:vi/adjust-command-mode を呼び出す必要がある。
##     そうしないとノーマルモードにおいてありえない位置にカーソルが来ることになる。
##
function ble/keymap:vi/needs-eol-fix {
  [[ $_ble_decode_keymap == vi_nmap || $_ble_decode_keymap == vi_omap ]] || return 1
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/content/nonbol-eolp "$index"
}
function ble/keymap:vi/adjust-command-mode {
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    # 移動コマンドが来たら末尾拡張を無効にする。
    # 移動コマンドはここを通るはず…
    ble/keymap:vi/xmap/remove-eol-extension
  fi

  local kmap_popped=
  if [[ $_ble_decode_keymap == vi_omap ]]; then
    ble/decode/keymap/pop
    kmap_popped=1
  fi

  # search による mark の設定・解除
  if [[ $_ble_keymap_vi_search_activate ]]; then
    if [[ $_ble_decode_keymap != vi_[xs]map ]]; then
      _ble_edit_mark_active=$_ble_keymap_vi_search_activate
    fi
    _ble_keymap_vi_search_matched=1
    _ble_keymap_vi_search_activate=
  else
    [[ $_ble_edit_mark_active == vi_search ]] && _ble_edit_mark_active=
    ((_ble_keymap_vi_search_matched)) && _ble_keymap_vi_search_matched=
  fi

  if [[ $_ble_decode_keymap == vi_nmap && $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/content/nonbol-eolp "$index" && _ble_edit_ind=$index
    fi
    ble/widget/vi_nmap/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite" resume
    ble/keymap:vi/repeat/clear-insert
  elif [[ $kmap_popped ]]; then
    ble/keymap:vi/update-mode-indicator
  fi

  return 0
}
function ble/widget/vi-command/bell {
  ble/widget/.bell "$1"
  ble/keymap:vi/adjust-command-mode
  return 0
}

## @fn ble/widget/vi_nmap/.insert-mode [arg [overwrite [opts]]]
##   @param[in] arg
##   @param[in] overwrite
##   @param[in] opts
function ble/widget/vi_nmap/.insert-mode {
  [[ $_ble_decode_keymap == vi_[xs]map ]] && ble/decode/keymap/pop
  [[ $_ble_decode_keymap == vi_omap ]] && ble/decode/keymap/pop
  local arg=$1 overwrite=$2
  ble/keymap:vi/imap-repeat/reset "$arg"
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=$overwrite
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_insert_overwrite=$overwrite
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble/keymap:vi/search/clear-matched
  ble/decode/keymap/pop
  ble/keymap:vi/update-mode-indicator

  ble/keymap:vi/mark/start-edit-area
  if [[ :$opts: != *:resume:* ]]; then
    ble/keymap:vi/mark/commit-edit-area "$_ble_edit_ind" "$_ble_edit_ind"
  fi
}
function ble/widget/vi_nmap/insert-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/append-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ! ble-edit/content/eolp; then
    ((_ble_edit_ind++))
  fi
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/append-mode-at-end-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-eol
  _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-beginning-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-bol
  _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/first-non-space
  [[ ${_ble_edit_str:_ble_edit_ind:1} == [$' \t'] ]] &&
    ((_ble_edit_ind++)) # 逆eol補正
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
# nmap: gi
function ble/widget/vi_nmap/insert-mode-at-previous-point {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble/keymap:vi/mark/get-local-mark 94 && _ble_edit_ind=$ret
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/replace-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG" R
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/virtual-replace-mode {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/.insert-mode "$ARG" 1
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/accept-line {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  [[ $_ble_keymap_vi_reg_record ]] &&
    ble/widget/vi_nmap/record-register
  ble/widget/default/accept-line
}
function ble/widget/vi-command/edit-and-execute-command {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  [[ $_ble_keymap_vi_reg_record ]] &&
    ble/widget/vi_nmap/record-register
  ble/widget/edit-and-execute-command
}

#------------------------------------------------------------------------------
# args
#
# arg     : 0-9 d y c
# command : dd yy cc [dyc]0 Y S

_ble_keymap_vi_oparg=
_ble_keymap_vi_opfunc=
_ble_keymap_vi_reg=

ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_oparg \
               _ble_keymap_vi_opfunc \
               _ble_keymap_vi_reg

# ble/keymap:vi における _ble_edit_kill_ring の扱いついて
#
# _ble_edit_kill_type=L のとき
#   行指向の切り取り文字列であることを表し、
#   _ble_edit_kill_ring の末端には必ず改行文字が来ると仮定して良い。
#
# _ble_edit_kill_type=B:* の形式をしているとき、
#   矩形の切り取り文字列であることを表し、
#   _ble_edit_kill_ring は改行区切りで各行を連結したものである。
#   末端には改行文字は付加しない。末端に改行文字があるときは、
#   それは付加された改行ではなく、最後に空行があることを意味する。
#
#   _ble_edit_kill_type の 2 文字目以降は数字を空白区切りで並べたもので、
#   各数字は _ble_edit_kill_ring 内の各行に対応する。
#   意味は、行の途中に挿入する際に矩形を保つために右に補填するべき空白の数である。
#   行末に挿入する際にはこの空白の補填は起こらないことに注意する。
#
# _ble_edit_kill_type= (空文字列) もしくは それ意外の場合は
#   通常の切り取り文字列であることを表す。
#   _ble_edit_kill_ring は任意の文字列である。
#
_ble_keymap_vi_register=()
_ble_keymap_vi_register_onplay=

## @fn ble/keymap:vi/clear-arg
function ble/keymap:vi/clear-arg {
  _ble_edit_arg=
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
  _ble_keymap_vi_reg=
}
## @fn ble/keymap:vi/get-arg [default_value]; ARG FLAG REG
##
## 引数の内容について
##   vi_nmap, vi_xmap, vi_smap においては FLAG は空であると仮定して良い。
##   vi_omap においては FLAG は非空である。
##   get-arg{,-reg} を呼び出すことによって空になる。
##   つまり vi_omap においてこの関数を呼び出したとき、vi_omap から vi_nmap に戻る必要がある。
##   これは通例 ble/keymap:vi/adjust-command-mode によって実施される。
##
function ble/keymap:vi/get-arg {
  local default_value=$1
  REG=$_ble_keymap_vi_reg
  FLAG=$_ble_keymap_vi_opfunc
  if [[ ! $_ble_edit_arg && ! $_ble_keymap_vi_oparg ]]; then
    ARG=$default_value
  else
    ARG=$((10#0${_ble_edit_arg:-1}*10#0${_ble_keymap_vi_oparg:-1}))
  fi
  ble/keymap:vi/clear-arg
}
## @fn ble/keymap:vi/register#load reg
function ble/keymap:vi/register#load {
  local reg=$1
  if [[ $reg ]] && ((reg!=34)); then
    if [[ $reg == 37 ]]; then # "%
      ble-edit/content/push-kill-ring "$HISTFILE" ''
      return 0
    fi

    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      ble-edit/content/push-kill-ring "${value#*/}" "${value%%/*}"
      return 0
    else
      ble-edit/content/push-kill-ring
      return 1
    fi
  fi
}
## @fn ble/keymap:vi/register#set reg type content
function ble/keymap:vi/register#set {
  local reg=$1 type=$2 content=$3

  # type = L は行指向の値
  # type = B は矩形指向の値
  # type = '' は文字指向の値
  # type = q はキーボードマクロ
  #
  # Note: 実際に記録される type は以下の何れかである。
  #  type = L
  #  type = B:*
  #  type = ''

  # 追記の場合
  if [[ $reg == +* ]]; then
    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      local otype=${value%%/*}
      local oring=${value#*/}

      if [[ $otype == L ]]; then
        if [[ $type == q ]]; then
          type=L content=${oring%$'\n'}$content # V + * → V
        else
          type=L content=$oring$content # V + * → V
        fi
      elif [[ $type == L ]]; then
        type=L content=$oring$'\n'$content # C-v + V, v + V → V
      elif [[ $otype == B:* ]]; then
        if [[ $type == B:* ]]; then
          type=$otype' '${type#B:}
          content=$oring$'\n'$content # C-v + C-v → C-v
        elif [[ $type == q ]]; then
          local ret; ble/string#count-char "$content" $'\n'
          ble/string#repeat ' 0' "$ret"
          type=$otype$ret
          content=$oring$$content # C-v + q → C-v
        else
          local ret; ble/string#count-char "$content" $'\n'
          ble/string#repeat ' 0' "$((ret+1))"
          type=$otype$ret
          content=$oring$'\n'$content # C-v + v → C-v
        fi
      else
        type= content=$oring$content # v + C-v, v + v, v + q → v
      fi
    fi
  fi

  [[ $type == L && $content != *$'\n' ]] && content=$content$'\n'

  local suppress_default=
  [[ $type == q ]] && type= suppress_default=1

  if [[ ! $reg ]] || ((reg==34)); then # ""
    # unnamed register
    ble-edit/content/push-kill-ring "$content" "$type"
    return 0
  elif ((reg==58||reg==46||reg==37||reg==126)); then # ": ". "% "~
    # read only register
    ble/widget/.bell "attempted to write on a read-only register #$reg"
    return 1
  elif ((reg==95)); then # "_
    # black hole register
    return 0
  else
    if [[ ! $suppress_default ]]; then
      ble-edit/content/push-kill-ring "$content" "$type"
    fi
    _ble_keymap_vi_register[reg]=$type/$content
    return 0
  fi
}

## @fn ble/keymap:vi/register#set-yank reg type content
##   レジスタ "0 に文字列を登録します。
##
function ble/keymap:vi/register#set-yank {
  ble/keymap:vi/register#set "$@" || return 1
  local reg=$1 type=$2 content=$3
  if [[ $reg == '' || $reg == 34 ]]; then
    ble/keymap:vi/register#set 48 "$type" "$content" # "0
  fi
}
## @fn ble/keymap:vi/register#set-edit reg type content
##   レジスタ "1 に文字列を登録します。
##
##   content に改行が含まれる場合、または、特定の WIDGET の時、
##   元々レジスタ "1 - "8 にあった内容をレジスタ "2 - "9 に移動し、
##   新しい文字列をレジスタ "1 に登録します。
##   それ以外の時、新しい文字列はレジスタ "- に登録します。
##
_ble_keymap_vi_register_49_widget_list=(
  # %
  ble/widget/vi-command/search-matchpair-or
  ble/widget/vi-command/percentage-line

  # `
  ble/widget/vi-command/goto-mark

  # / ? n N
  ble/widget/vi-command/search-forward
  ble/widget/vi-command/search-backward
  ble/widget/vi-command/search-repeat
  ble/widget/vi-command/search-reverse-repeat

  # ( ) { }
  # ToDo
)
function ble/keymap:vi/register#set-edit {
  ble/keymap:vi/register#set "$@" || return 1
  local reg=$1 type=$2 content=$3
  if [[ $reg == '' || $reg == 34 ]]; then
    local IFS=$_ble_term_IFS
    local widget=${WIDGET%%["$_ble_term_IFS"]*}
    if [[ $content == *$'\n'* || " $widget " == " ${_ble_keymap_vi_register_49_widget_list[*]} " ]]; then
      local n
      for ((n=9;n>=2;n--)); do
        _ble_keymap_vi_register[48+n]=${_ble_keymap_vi_register[48+n-1]}
      done
      ble/keymap:vi/register#set 49 "$type" "$content" # "1
    else
      ble/keymap:vi/register#set 45 "$type" "$content" # "-
    fi
  fi
}

function ble/keymap:vi/register#play {
  local reg=$1 value
  if [[ $reg ]] && ((reg!=34)); then
    value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      value=${value#*/}
    else
      value=
      return 1
    fi
  else
    value=$_ble_edit_kill_ring
  fi

  local _ble_keymap_vi_register_onplay=1
  local ret; ble/decode/charlog#decode "$value"
  ble/widget/.MACRO "${ret[@]}"
  return 0
}
## @fn ble/keymap:vi/register#dump/escape text
##   @var[out] ret
function ble/keymap:vi/register#dump/escape {
  local text=$1
  local out= i=0 iN=${#text}
  while ((i<iN)); do
    local tail=${text:i}
    if ble/util/isprint+ "$tail"; then
      out=$out$BASH_REMATCH
      ((i+=${#BASH_REMATCH}))
    else
      ble/util/s2c "$tail"
      local code=$ret
      if ((code<32)); then
        ble/util/c2s "$((code+64))"
        out=$out$_ble_term_rev^$ret$_ble_term_sgr0
      elif ((code==127)); then
        out=$out$_ble_term_rev^?$_ble_term_sgr0
      elif ((128<=code&&code<160)); then
        ble/util/c2s "$((code-64))"
        out=$out${_ble_term_rev}M-^$ret$_ble_term_sgr0
      else
        out=$out${tail::1}
      fi
      ((i++))
    fi
  done
  ret=$out
}
function ble/keymap:vi/register#dump {
  local k ret out=
  local value type content
  for k in 34 "${!_ble_keymap_vi_register[@]}"; do
    if ((k==34)); then
      type=$_ble_edit_kill_type
      content=$_ble_edit_kill_ring
    else
      value=${_ble_keymap_vi_register[k]}
      type=${value%%/*} content=${value#*/}
    fi

    ble/util/c2s "$k"; k=$ret
    case $type in
    (L)   type=line ;;
    (B:*) type=block ;;
    (*)   type=char ;;
    esac
    ble/keymap:vi/register#dump/escape "$content"; content=$ret

    out=$out'"'$k' ('$type') '$content$'\n'
  done
  ble/edit/info/show ansi "$out"
  return 0
}
function ble/widget/vi-command:reg { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:regi { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:regis { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:regist { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:registe { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:register { ble/keymap:vi/register#dump; }
function ble/widget/vi-command:registers { ble/keymap:vi/register#dump; }

function ble/widget/vi-command/append-arg {
  local ret ch=$1
  if [[ ! $ch ]]; then
    local n=${#KEYS[@]}
    local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
    ((code==0)) && return 1
    ble/util/c2s "$code"; ch=$ret
  fi
  ble/util/assert '[[ ! ${ch//[0-9]} ]]'

  # 0
  if [[ $ch == 0 && ! $_ble_edit_arg ]]; then
    ble/widget/vi-command/beginning-of-line
    return "$?"
  fi

  _ble_edit_arg="$_ble_edit_arg$ch"
  return 0
}
function ble/widget/vi-command/register {
  _ble_decode_key__hook="ble/widget/vi-command/register.hook"
}
function ble/widget/vi-command/register.hook {
  local key=$1
  ble/keymap:vi/clear-arg
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      _ble_keymap_vi_reg=+$((c+32))
      return 0
    elif ((97<=c&&c<123||48<=c&&c<58||c==45||c==58||c==46||c==37||c==35||c==61||c==42||c==43||c==126||c==95||c==47)); then # a-z 0-9 - : . % # = * + ~ _ /
      _ble_keymap_vi_reg=$c
      return 0
    elif ((c==34)); then # ""
      # Note: vim の内部的には "" を指定するのと何も指定しないのは区別される。
      # 例えば diw"y. は "y に記録されるが ""diw"y. は "" に記録される。
      _ble_keymap_vi_reg=$c
      return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

_ble_keymap_vi_reg_record=
_ble_keymap_vi_reg_record_char=
_ble_keymap_vi_reg_record_play=0
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_reg_record \
               _ble_keymap_vi_reg_record_char \
               _ble_keymap_vi_reg_record_play

# nmap q
function ble/widget/vi_nmap/record-register {
  # レジスタに含まれる q は再生中には何も起こさない
  if [[ $_ble_keymap_vi_register_onplay ]]; then
    ble/keymap:vi/clear-arg
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  if [[ $_ble_keymap_vi_reg_record ]]; then
    ble/keymap:vi/clear-arg
    local -a ret
    ble/decode/charlog#end-exclusive-depth1
    ble/decode/charlog#encode "${ret[@]}"
    ble/keymap:vi/register#set "$_ble_keymap_vi_reg_record" q "$ret"

    _ble_keymap_vi_reg_record=
    ble/keymap:vi/update-mode-indicator
  else
    _ble_decode_key__hook="ble/widget/vi_nmap/record-register.hook"
  fi
}
function ble/widget/vi_nmap/record-register.hook {
  local key=$1 ret
  ble/keymap:vi/clear-arg

  # check register
  local reg= c=
  if ble/keymap:vi/k2c "$key" && c=$ret; then
    if ((65<=c&&c<91)); then # q{A-Z}
      reg=+$((c+32))
    elif ((48<=c&&c<58||97<=c&&c<123)); then # q{0-9a-z}
      reg=$c
    elif ((c==34)); then # q"
      reg=$c
    fi
  fi
  if [[ ! $reg ]]; then
    ble/widget/vi-command/bell "invalid register key=$key"
    return 1
  fi

  # start logging
  if ! ble/decode/charlog#start vi-macro; then
    ble/widget/.bell 'vi-macro: the logging system is currently busy'
    return 1
  fi

  # update status
  ble/util/c2s "$c"
  _ble_keymap_vi_reg_record=$reg
  _ble_keymap_vi_reg_record_char=$ret
  ble/keymap:vi/update-mode-indicator
  return 0
}
# nmap @
function ble/widget/vi_nmap/play-register {
  _ble_decode_key__hook="ble/widget/vi_nmap/play-register.hook"
}
function ble/widget/vi_nmap/play-register.hook {
  ble/keymap:vi/clear-arg

  local depth=$_ble_keymap_vi_reg_record_play
  if ((depth>=bleopt_keymap_vi_macro_depth)) || ble/util/is-stdin-ready; then
    return 1 # 無限ループを防ぐため
  fi

  local _ble_keymap_vi_reg_record_play=$((depth+1))
  local key=$1
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    ((65<=c&&c<91)) && ((c+=32)) # A-Z -> a-z
    if ((48<=c&&c<58||97<=c&&c<123)); then # 0-9a-z
      ble/keymap:vi/register#play "$c" && return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/operator {
  local ret opname=$1

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    local ARG FLAG REG; ble/keymap:vi/get-arg ''
    # ※FLAG はユーザにより設定されているかもしれないが無視

    local a=$_ble_edit_ind b=$_ble_edit_mark
    ((a<=b||(a=_ble_edit_mark,b=_ble_edit_ind)))

    ble/widget/vi_xmap/.save-visual-state
    local ble_keymap_vi_mark_active=$_ble_edit_mark_active # used in call-operator-blockwise
    local mark_type=${_ble_edit_mark_active%+}
    ble/widget/vi_xmap/exit

    local ble_keymap_vi_opmode=$mark_type
    if [[ $mark_type == vi_line ]]; then
      ble/keymap:vi/call-operator-linewise "$opname" "$a" "$b" "$ARG" "$REG"
    elif [[ $mark_type == vi_block ]]; then
      ble/keymap:vi/call-operator-blockwise "$opname" "$a" "$b" "$ARG" "$REG"
    else
      local end=$b
      ((end<${#_ble_edit_str}&&end++))
      ble/keymap:vi/call-operator-charwise "$opname" "$a" "$end" "$ARG" "$REG"
    fi; local ext=$?
    ((ext==147)) && return 147
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/decode/keymap/push vi_omap
    _ble_keymap_vi_oparg=$_ble_edit_arg
    _ble_keymap_vi_opfunc=$opname
    _ble_edit_arg=
    ble/keymap:vi/update-mode-indicator

  elif [[ $_ble_decode_keymap == vi_omap ]]; then
    local opname1=${_ble_keymap_vi_opfunc%%:*}
    if [[ $opname == "$opname1" ]]; then
      # 2つの同じオペレータ (yy, dd, cc, etc.) = 行指向の処理
      ble/widget/vi_nmap/linewise-operator "$_ble_keymap_vi_opfunc"
    else
      ble/keymap:vi/clear-arg
      ble/widget/vi-command/bell
      return 1
    fi
  fi
  return 0
}

function ble/widget/vi_nmap/linewise-operator {
  local opname=${1%%:*} opflags=${1#*:}
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # _ble_edit_arg is consumed here
  if ((ARG==1)) || [[ ${_ble_edit_str:_ble_edit_ind} == *$'\n'* ]]; then
    if [[ :$opflags: == *:vi_char:* || :$opflags: == *:vi_block:* ]]; then
      local beg=$_ble_edit_ind
      local ret; ble-edit/content/find-logical-bol "$beg" "$((ARG-1))"; local end=$ret
      ((beg<=end)) || local beg=$end end=$beg
      if [[ :$opflags: == *:vi_block:* ]]; then
        ble/keymap:vi/call-operator-blockwise "$opname" "$beg" "$end" '' "$REG"
      else
        ble/keymap:vi/call-operator-charwise "$opname" "$beg" "$end" '' "$REG"
      fi
    else
      ble/keymap:vi/call-operator-linewise "$opname" "$_ble_edit_ind" "$_ble_edit_ind:$((ARG-1))" '' "$REG"; local ext=$?
    fi
    if ((ext==0)); then
      ble/keymap:vi/adjust-command-mode
      return 0
    elif ((ext==147)); then
      return 147
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}
# nmap Y
function ble/widget/vi_nmap/copy-current-line {
  ble/widget/vi_nmap/linewise-operator y
}
function ble/widget/vi_nmap/kill-current-line {
  ble/widget/vi_nmap/linewise-operator d
}
# nmap S
function ble/widget/vi_nmap/kill-current-line-and-insert {
  ble/widget/vi_nmap/linewise-operator c
}

# nmap: 0, <home>
function ble/widget/vi-command/beginning-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-bol; local beg=$ret
  ble/widget/vi-command/exclusive-goto.impl "$beg" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# Operators

## オペレータは以下の形式の関数として定義される。
##
## @fn ble/keymap:vi/operator:名称 a b context [count [reg]]
##
##   @param[in] a b
##     範囲の開始点と終了点。終了点は開始点以降にあることが保証される。
##     context が 'line' のとき、それぞれ行頭・行末にあることが保証される。
##     ただし、行末に改行があるときは b は次の行頭を指す。
##
##   @param[in] context
##     範囲の種類を表す文字列。char, line, block の何れか。
##
##   @param[in] count
##     オペレータの操作に対する引数。
##     これはビジュアルモードで指定される。
##
##   @var[in,out] beg end
##     範囲の開始点と終了点。a b と同一の値。
##     行指向オペレータのとき範囲が拡大されることがある。
##     その時 beg に拡大後の開始点を返す。
##
##   @var[out] ble_keymap_vi_operator_index
##     オペレータ作用後のカーソル位置を明示するとき、
##     オペレータ内部でこの変数に値を設定する。
##
##   @exit
##     operator 関数が終了ステータス 147 を返したとき、
##     operator が非同期に入力を読み取ることを表す。
##     147 を返した operator は、実際に操作が完了した時に:
##
##     1 ble/keymap:vi/mark/end-edit-area を呼び出す必要がある。
##     2 適切な位置にカーソルを移動する必要がある。
##
##
## オペレータは現在以下の4箇所で呼び出されている。
##
## - ble/widget/vi-command/linewise-range.impl
## - ble/keymap:vi/call-operator
## - ble/keymap:vi/call-operator-charwise
## - ble/keymap:vi/call-operator-linewise
## - ble/keymap:vi/call-operator-blockwise


## @fn ble/keymap:vi/call-operator op beg end type arg reg
## @fn ble/keymap:vi/call-operator-charwise op beg end arg reg
## @fn ble/keymap:vi/call-operator-linewise op beg end arg reg
## @fn ble/keymap:vi/call-operator-blockwise op beg end arg reg
##
##   @var[in] ble_keymap_vi_mark_active
##     オペレータ作用前の $_ble_edit_mark_active を指定する。
##     call-operator-blockwise での矩形領域を決定するのに用いる。
##     演算子の呼び出し時には既に $_ble_edit_mark_active は
##     作用後の値に変わっていることに注意する。
##
function ble/keymap:vi/call-operator {
  ble/keymap:vi/mark/start-edit-area
  local _ble_keymap_vi_mark_suppress_edit=1
  ble/keymap:vi/operator:"$@"; local ext=$?
  ble/util/unlocal _ble_keymap_vi_mark_suppress_edit
  ble/keymap:vi/mark/end-edit-area
  if ((ext==0)); then
    if ble/is-function ble/keymap:vi/operator:"$1".record; then
      ble/keymap:vi/operator:"$1".record
    else
      ble/keymap:vi/repeat/record
    fi
  fi
  return "$ext"
}
function ble/keymap:vi/call-operator-charwise {
  local ch=$1 beg=$2 end=$3 arg=$4 reg=$5
  ((beg<=end||(beg=$3,end=$2)))
  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local ble_keymap_vi_operator_index=
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" char "$arg" "$reg"; local ext=$?
    ((ext==147)) && return 147

    local index=${ble_keymap_vi_operator_index:-$beg}
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}
function ble/keymap:vi/call-operator-linewise {
  local ch=$1 a=$2 b=$3 arg=$4 reg=$5 ia=0 ib=0
  [[ $a == *:* ]] && local a=${a%%:*} ia=${a#*:}
  [[ $b == *:* ]] && local b=${b%%:*} ib=${b#*:}
  local ret
  ble-edit/content/find-logical-bol "$a" "$ia"; local beg=$ret
  ble-edit/content/find-logical-eol "$b" "$ib"; local end=$ret

  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local ble_keymap_vi_operator_index=
    ((end<${#_ble_edit_str}&&end++))
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" line "$arg" "$reg"; local ext=$?
    ((ext==147)) && return 147

    # index
    if [[ $ble_keymap_vi_operator_index ]]; then
      local index=$ble_keymap_vi_operator_index
    else
      ble-edit/content/find-logical-bol "$beg"; beg=$ret # operator 中で beg が変更されているかも
      ble-edit/content/find-non-space "$beg"; local index=$ret
    fi
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}
function ble/keymap:vi/call-operator-blockwise {
  local ch=$1 beg=$2 end=$3 arg=$4 reg=$5
  if ble/is-function ble/keymap:vi/operator:"$ch"; then
    local mark_active=${ble_keymap_vi_mark_active:-vi_block}
    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$mark_active ble/keymap:vi/extract-block "$beg" "$end"
    local nrange=${#sub_ranges[@]}
    ((nrange)) || return 1

    local ble_keymap_vi_operator_index=
    local beg=${sub_ranges[0]}; beg=${beg%%:*}
    local end=${sub_ranges[nrange-1]}; end=${end#*:}; end=${end%%:*}
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" block "$arg" "$reg"
    ((ext==147)) && return 147

    local index=${ble_keymap_vi_operator_index:-$beg}
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    return 0
  else
    return 1
  fi
}


function ble/keymap:vi/operator:d {
  local context=$3 arg=$4 reg=$5 # beg end は上書きする
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set-edit "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1

    # 最後の行が削除される時は前の行の非空白行頭まで後退
    if ((end==${#_ble_edit_str}&&beg>0)); then
      # fix start position
      local ret
      ((beg--))
      ble-edit/content/find-logical-bol "$beg"
      ble-edit/content/find-non-space "$ret"
      ble_keymap_vi_operator_index=$ret
    fi

    ble/widget/.delete-range "$beg" "$end"
  elif [[ $context == block ]]; then
    local -a afill=() atext=() arep=()
    local sub shift=0 slpad0=
    local smin smax slpad srpad sfill stext
    for sub in "${sub_ranges[@]}"; do
      stext=${sub#*:*:*:*:*:}
      ble/string#split sub : "$sub"
      smin=${sub[0]} smax=${sub[1]}
      slpad=${sub[2]} srpad=${sub[3]}
      sfill=${sub[4]}

      [[ $slpad0 ]] || slpad0=$slpad # 最初の slpad

      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
      local ret; ble/string#repeat ' ' "$((slpad+srpad))"
      ble/array#push arep "$((smin+shift)):$((smax+shift)):$ret"
      ((shift+=(slpad+srpad)-(smax-smin)))
    done

    # yank
    IFS=$'\n' builtin eval 'local yank_content="${atext[*]-}"'
    local IFS=$_ble_term_IFS
    local yank_type=B:"${afill[*]-}"
    ble/keymap:vi/register#set-edit "$reg" "$yank_type" "$yank_content" || return 1

    # delete
    local rep
    for rep in "${arep[@]}"; do
      smin=${rep%%:*}; rep=${rep:${#smin}+1}
      smax=${rep%%:*}; rep=${rep:${#smax}+1}
      ble/widget/.replace-range "$smin" "$smax" "$rep"
    done
    ((beg+=slpad)) # fix start position
  else
    if ((beg<end)); then

      if [[ $ble_keymap_vi_opmode != vi_char && ${_ble_edit_str:beg:end-beg} == *$'\n'* ]]; then
        # d の例外動作: 文字単位で開始点と終了点が異なる行で、
        #   開始点より前・終了点より後に空白しかない時、行指向で処理する。
        if local rex=$'(^|\n)([ \t]*)$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
          local prefix=${BASH_REMATCH[2]}
          if rex=$'^[ \t]*(\n|$)'; [[ ${_ble_edit_str:end} =~ $rex ]]; then
            local suffix=$BASH_REMATCH
            ((beg-=${#prefix},end+=${#suffix}))
            ble/keymap:vi/operator:d "$beg" "$end" line "$arg" "$reg"
            return "$?"
          fi
        fi
      fi

      ble/keymap:vi/register#set-edit "$reg" '' "${_ble_edit_str:beg:end-beg}" || return 1
      ble/widget/.delete-range "$beg" "$end"
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:c {
  local context=$3 arg=$4 reg=$5 # beg は上書き対象
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set-edit "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1

    local end2=$end
    ((end2)) && [[ ${_ble_edit_str:end2-1:1} == $'\n' ]] && ((end2--))

    local indent= ret
    ble-edit/content/find-non-space "$beg"; local nol=$ret
    ((beg<nol)) && indent=${_ble_edit_str:beg:nol-beg}

    ble/widget/.replace-range "$beg" "$end2" "$indent"
    ble/widget/vi_nmap/.insert-mode
  elif [[ $context == block ]]; then
    ble/keymap:vi/operator:d "$@" || return 1 # @var beg will be overwritten here

    # operator:d によってずれた矩形領域を修正する。
    # 一から計算し直すのは面倒なので sub_ranges を直接弄る。
    # 実のところ block-insert-mode insert は sub_ranges[0] の smin と sub_x1
    # しか参照しないので、sub_ranges[0] だけ修正すれば良い。
    local sub=${sub_ranges[0]}
    local smin=${sub%%:*} sub=${sub#*:}
    local smax=${sub%%:*} sub=${sub#*:}
    local slpad=${sub%%:*} sub=${sub#*:}
    ((smin+=slpad,smax=smin,slpad=0))
    sub_ranges[0]=$smin:$smax:$slpad:$sub

    ble/widget/vi_xmap/block-insert-mode.impl insert
  else
    local ble_keymap_vi_opmode=vi_char
    ble/keymap:vi/operator:d "$@" || return 1
    ble/widget/vi_nmap/.insert-mode
  fi
  return 0
}
function ble/keymap:vi/operator:y.record { :; }
function ble/keymap:vi/operator:y {
  local beg=$1 end=$2 context=$3 arg=$4 reg=$5
  local yank_type= yank_content=
  if [[ $context == line ]]; then
    ble_keymap_vi_operator_index=$_ble_edit_ind # operator:y では現在位置を動かさない
    yank_type=L
    yank_content=${_ble_edit_str:beg:end-beg}
  elif [[ $context == block ]]; then
    local sub
    local -a afill=() atext=()
    for sub in "${sub_ranges[@]}"; do
      local sub4=${sub#*:*:*:*:}
      local sfill=${sub4%%:*} stext=${sub4#*:}
      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
    done

    IFS=$'\n' builtin eval 'local yank_content="${atext[*]-}"'
    local IFS=$_ble_term_IFS
    yank_type=B:"${afill[*]-}"
  else
    yank_type=
    yank_content=${_ble_edit_str:beg:end-beg}
  fi

  ble/keymap:vi/register#set-yank "$reg" "$yank_type" "$yank_content" || return 1
  ble/keymap:vi/mark/commit-edit-area "$beg" "$end"
  return 0
}
function ble/keymap:vi/operator:tr.impl {
  local beg=$1 end=$2 context=$3 filter=$4
  if [[ $context == block ]]; then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      ble/string#split sub : "${sub_ranges[isub]}"
      local smin=${sub[0]} smax=${sub[1]}
      local ret; "$filter" "${_ble_edit_str:smin:smax-smin}"
      ble/widget/.replace-range "$smin" "$smax" "$ret"
    done
  else
    local ret; "$filter" "${_ble_edit_str:beg:end-beg}"
    ble/widget/.replace-range "$beg" "$end" "$ret"
  fi
  return 0
}
function ble/keymap:vi/operator:u {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#tolower
}
function ble/keymap:vi/operator:U {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#toupper
}
function ble/keymap:vi/operator:toggle_case {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/string#toggle-case
}
function ble/keymap:vi/operator:rot13 {
  ble/keymap:vi/operator:tr.impl "$1" "$2" "$3" ble/keymap:vi/string#encode-rot13
}

## @fn ble/keymap:vi/expand-range-for-linewise-operator
##   @var[in,out] beg, end
function ble/keymap:vi/expand-range-for-linewise-operator {
  local ret

  # 行頭補正:
  ble-edit/content/find-logical-bol "$beg"; beg=$ret

  # 行末補正:
  #   行前進時は非空白行頭以前に end がある場合はその行は無視
  #   行後退時は行頭に end (_ble_edit_ind) がある場合はその行は無視
  #   同一行内の移動の場合は無条件にその行は含まれる。
  ble-edit/content/find-logical-bol "$end"; local bol2=$ret
  ble-edit/content/find-non-space "$bol2"; local nol2=$ret
  if ((beg<bol2&&_ble_edit_ind<=bol2&&end<=nol2)); then
    end=$bol2
  else
    ble-edit/content/find-logical-eol "$end"; end=$ret
    [[ ${_ble_edit_str:end:1} == $'\n' ]] && ((end++))
  fi
}

#--------------------------------------
# Indent operators < >

## @fn ble/keymap:vi/string#increase-indent
##   @var[out] ret
function ble/keymap:vi/string#increase-indent {
  local text=$1 delta=$2
  local space=$' \t' it=${bleopt_tab_width:-$_ble_term_it}
  local arr; ble/string#split-lines arr "$text"
  local -a arr2=()
  local line indent i len x r
  for line in "${arr[@]}"; do
    indent=${line%%[!$space]*}
    line=${line:${#indent}}

    ((x=0))
    if [[ $indent ]]; then
      ((len=${#indent}))
      for ((i=0;i<len;i++)); do
        if [[ ${indent:i:1} == ' ' ]]; then
          ((x++))
        else
          ((x=(x+it)/it*it))
        fi
      done
    fi

    ((x+=delta,x<0&&(x=0)))

    indent=
    if ((x)); then
      if ((bleopt_indent_tabs&&(r=x/it))); then
        ble/string#repeat $'\t' "$r"
        indent=$ret
        ((x%=it))
      fi
      if ((x)); then
        ble/string#repeat ' ' "$x"
        indent=$indent$ret
      fi
    fi

    ble/array#push arr2 "$indent$line"
  done

  IFS=$'\n' builtin eval 'ret="${arr2[*]-}"'
}
## @fn ble/keymap:vi/operator:indent.impl/increase-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/increase-block-indent {
  local width=$1
  local isub=${#sub_ranges[@]}
  local sub smin slpad ret
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]} slpad=${sub[2]}
    ble/string#repeat ' ' "$((slpad+width))"
    ble/widget/.replace-range "$smin" "$smin" "$ret"
  done
}
## @fn ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent {
  local width=$1
  local it=${bleopt_tab_width:-$_ble_term_it} cols=$_ble_textmap_cols
  local sub smin slpad ret
  local -a replaces=()
  local isub=${#sub_ranges[@]}
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]} slpad=${sub[2]}
    ble-edit/content/find-non-space "$smin"; local nsp=$ret
    ((smin<nsp)) || continue

    local ax ay bx by
    ble/textmap#getxy.out --prefix=a "$smin"
    ble/textmap#getxy.out --prefix=b "$nsp"
    local w=$(((bx-ax)-(by-ay)*cols-width))
    ((w<slpad)) && w=$slpad

    local ins=
    if ((w)); then
      local r
      if ((bleopt_indent_tabs&&(r=(ax+w)/it-ax/it))); then
        ble/string#repeat $'\t' "$r"; ins=$ret
        ((w=(ax+w)%it))
      fi
      if ((w)); then
        ble/string#repeat ' ' "$w"
        ins=$ins$ret
      fi
    fi

    ble/array#push replaces "$smin:$nsp:$ins"
  done

  local rep
  for rep in "${replaces[@]}"; do
    ble/string#split rep : "$rep"
    ble/widget/.replace-range "${rep[@]::3}"
  done
}
## @fn ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent {
  # タブは幅 it で固定と見做して削除する
  local width=$1
  local it=${bleopt_tab_width:-$_ble_term_it}
  local sub smin ret nsp
  local isub=${#sub_ranges[@]}
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]}
    ble-edit/content/find-non-space "$smin"; nsp=$ret
    ((smin<nsp)) || continue

    local stext=${_ble_edit_str:smin:nsp-smin}
    local i=0 n=${#stext} c=0 pad=0
    for ((i=0;i<n;i++)); do
      if [[ ${stext:i:1} == $'\t' ]]; then
        ((c+=it))
      else
        ((c++))
      fi
      if ((c>=width)); then
        pad=$((c-width))
        nsp=$((smin+i+1))
        break
      fi
    done

    local padding=
    ((pad)) && { ble/string#repeat ' ' "$pad"; padding=$ret; }
    ble/widget/.replace-range "$smin" "$nsp" "$padding"
  done
}
function ble/keymap:vi/operator:indent.impl {
  local delta=$1 context=$2
  ((delta)) || return 0
  if [[ $context == block ]]; then
    if ((delta>=0)); then
      ble/keymap:vi/operator:indent.impl/increase-block-indent "$delta"
    elif ble/edit/use-textmap; then
      ble/keymap:vi/operator:indent.impl/decrease-graphical-block-indent "$((-delta))"
    else
      ble/keymap:vi/operator:indent.impl/decrease-logical-block-indent "$((-delta))"
    fi
  else
    [[ $context == char ]] && ble/keymap:vi/expand-range-for-linewise-operator
    ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

    local ret
    ble/keymap:vi/string#increase-indent "${_ble_edit_str:beg:end-beg}" "$delta"; local content=$ret
    ble/widget/.replace-range "$beg" "$end" "$content"

    if [[ $context == char ]]; then
      ble-edit/content/find-non-space "$beg"
      ble_keymap_vi_operator_index=$ret
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:indent-left {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:indent.impl "$((-bleopt_indent_offset*arg))" "$context"
}
function ble/keymap:vi/operator:indent-right {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:indent.impl "$((bleopt_indent_offset*arg))" "$context"
}

#--------------------------------------
# Fold operators gq gw

## @fn ble/keymap:vi/string#measure-width text
##   指定した文字列の表示上の幅を計測します。
##
##   @param[in] text
##   @var[out] ret
##
##   折り返し処理は行いません。
##   タブや改行などの特別処理は行いません。
##   C0 文字は 2 文字として取り扱います。
##   C1 文字は 4 文字として取り扱います。
function ble/keymap:vi/string#measure-width {
  local text=$1 iN=${#1} i=0 s=0
  while ((i<iN)); do
    if ble/util/isprint+ "${text:i}"; then
      ((s+=${#BASH_REMATCH},
        i+=${#BASH_REMATCH}))
    else
      ble/util/s2c "${text:i:1}"
      ble/util/c2w-edit "$ret"
      ((s+=ret,i++))
    fi
  done
  ret=$s
}
## @fn ble/keymap:vi/string#fold/.get-interval text x
##   単語間のスペースの表示上の幅を計算します。
##
##   @param[in] text
##     スペース・タブで構成される文字列を指定します。
##   @param[in] x
##     画面上の初期位置を指定します。
##   @var[out] ret
##
function ble/keymap:vi/string#fold/.get-interval {
  local text=$1 x=$2
  local it=${bleopt_tab_width:-${_ble_term_it:-8}}

  local i=0 iN=${#text}
  for ((i=0;i<iN;i++)); do
    if [[ ${text:i:1} == $'\t' ]]; then
      ((x=(x/it+1)*it))
    else
      ((x++))
    fi
  done
  ret=$((x-$2))
}
## @fn ble/keymap:vi/string#fold text [cols]
##   @param[in]     text
##   @param[in,opt] cols [既定値 ${COLUMNS:-80}]
##     折り返す幅を指定します。
##     cols-1 列以内に表示文字が収まる様に折り返し処理されます。
##     但し長い単語の途中で折り返しは起こりません。
##   @var[out] ret
function ble/keymap:vi/string#fold {
  local text=$1
  local cols=${2:-${COLUMNS-80}}
  local sp=$' \t' nl=$'\n'

  # 途中状態について
  #   @var i       text 内の現在処理している位置
  #   @var out     今までに確定した結果文字列
  #   @var otmp    保留中の単語間スペース。次の単語が来て初めて確定する。
  #   @var x       $out を処理した後の表示横位置
  #   @var xtmp    $out$otmp を処理した後の表示横位置
  #   @var isfirst 初回の正規表現一致かどうか
  #   @var indent  インデント (改行直後に挿入する空白類)
  #   @var xindent インデント挿入直後の表示横位置
  local i=0 out= otmp= x=0 xtmp=0
  local isfirst=1 indent= xindent=0

  local rex='^([^'$nl$sp']+)|^(['$sp']+)|^.'
  while [[ ${text:i} =~ $rex ]]; do
    ((i+=${#BASH_REMATCH}))
    if [[ ${BASH_REMATCH[1]} ]]; then
      # 単語
      local word=${BASH_REMATCH[1]}
      ble/keymap:vi/string#measure-width "$word"
      if ((xtmp+ret<cols||xtmp<=xindent)); then
        out=$out$otmp$word
        ((x=xtmp+=ret))
      else
        out=$out$'\n'$indent$word
        ((x=xtmp=xindent+ret))
      fi
      otmp=
    else
      local w=1
      if [[ ${BASH_REMATCH[2]} ]]; then
        [[ $otmp ]] && continue # 改行直後の空白は無視
        # 単語間のスペース
        otmp=${BASH_REMATCH[2]}
        ble/keymap:vi/string#fold/.get-interval "$otmp" "$x"; w=$ret
        [[ $isfirst ]] && indent=$otmp xindent=$ret # インデント記録
      else
        # 改行は空白に置換。既存の空白 otmp は消去。
        otmp=' ' w=1
      fi

      if ((x+w<cols)); then
        ((xtmp=x+w))
      else
        ((xtmp=xindent))
        otmp=$'\n'$indent
      fi
    fi
    isfirst=
  done
  ret=$out
}
## @fn ble/keymap:vi/operator:fold/.fold-paragraphwise text [cols]
##   @var[out] ret
function ble/keymap:vi/operator:fold/.fold-paragraphwise {
  local text=$1
  local cols=${2:-${COLUMNS:-80}}

  local nl=$'\n' sp=$' \t'
  local rex_paragraph='^((['$sp']*'$nl')*)(['$sp']*[^'$sp$nl'][^'$nl']*('$nl'|$))+'

  local i=0 out=
  while [[ ${text:i} =~ $rex_paragraph ]]; do
    ((i+=${#BASH_REMATCH}))
    local rematch1=${BASH_REMATCH[1]}
    local len1=${#rematch1}
    local paragraph=${BASH_REMATCH:len1}

    # fold (実はここだけ変えれば paragraphwise の様々な処理を実装できる)
    ble/keymap:vi/string#fold "$paragraph" "$cols"
    paragraph=${ret%$'\n'}$'\n'

    out=$out$rematch1$paragraph
  done
  ret=$out${text:i}
}

function ble/keymap:vi/operator:fold.impl {
  local context=$1 opts=$2
  local ret

  [[ $context != line ]] && ble/keymap:vi/expand-range-for-linewise-operator
  local old=${_ble_edit_str:beg:end-beg} oind=$_ble_edit_ind

  local cols=${COLUMNS:-80}; ((cols>80&&(cols=80)))
  ble/keymap:vi/operator:fold/.fold-paragraphwise "$old" "$cols"; local new=$ret
  ble/widget/.replace-range "$beg" "$end" "$new"

  # 変換後のカーソル位置を修正。
  if [[ :$opts: == *:preserve_point:* ]]; then
    # gw: もともとカーソルが合った文字に移動。
    if ((end<=oind)); then
      ble_keymap_vi_operator_index=$((beg+${#new}))
    elif ((beg<oind)); then
      ble/keymap:vi/operator:fold/.fold-paragraphwise "${old::oind-beg}" "$cols"
      ble_keymap_vi_operator_index=$((beg+${#ret}))
    fi
  else
    # gq: 最終行の非空白行頭 (gq) に移動。
    if [[ $new ]]; then
      ble-edit/content/find-logical-bol "$((beg+${#new}-1))"
      ble-edit/content/find-non-space "$ret"
      ble_keymap_vi_operator_index=$ret
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:fold {
  local context=$3
  ble/keymap:vi/operator:fold.impl "$context"
}
function ble/keymap:vi/operator:fold-preserve-point {
  local context=$3
  ble/keymap:vi/operator:fold.impl "$context" preserve_point
}

#--------------------------------------
# Filter operator: !

_ble_keymap_vi_filter_args=()
_ble_keymap_vi_filter_repeat=()

_ble_keymap_vi_filter_history=()
_ble_keymap_vi_filter_history_edit=()
_ble_keymap_vi_filter_history_dirt=()
_ble_keymap_vi_filter_history_index=0

function ble/highlight/layer:region/mark:vi_filter/get-face {
  face=region_target
}
function ble/keymap:vi/operator:filter/.cache-repeat {
  local -a _ble_keymap_vi_repeat _ble_keymap_vi_repeat_irepeat
  ble/keymap:vi/repeat/record-normal
  _ble_keymap_vi_filter_repeat=("${_ble_keymap_vi_repeat[@]}")
}
function ble/keymap:vi/operator:filter/.record-repeat {
  ble/keymap:vi/repeat/record-special && return 0
  local command=$1
  _ble_keymap_vi_repeat=("${_ble_keymap_vi_filter_repeat[@]}")
  _ble_keymap_vi_repeat_irepeat=()
  _ble_keymap_vi_repeat[10]=$command
}
function ble/keymap:vi/operator:filter {
  local context=$3
  [[ $context != line ]] && ble/keymap:vi/expand-range-for-linewise-operator
  _ble_keymap_vi_filter_args=("$beg" "$end" "${@:3}")

  if [[ $_ble_keymap_vi_repeat_invoke ]]; then
    # nmap . によって繰り返しが要求された時
    local command=${_ble_keymap_vi_repeat[10]}
    ble/keymap:vi/operator:filter/.hook "$command"
    return "$?"
  else
    # 通常の呼び出し時
    ble/keymap:vi/operator:filter/.cache-repeat
    _ble_edit_ind=$beg
    _ble_edit_mark=$end
    _ble_edit_mark_active=vi_filter
    ble/keymap:vi/async-commandline-mode 'ble/keymap:vi/operator:filter/.hook'
    _ble_edit_PS1='!'
    ble/history/set-prefix _ble_keymap_vi_filter
    _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/before-command.hook
    _ble_keymap_vi_cmap_cancel_hook=ble/keymap:vi/operator:filter/cancel.hook
    _ble_syntax_lang=bash
    _ble_highlight_layer_list=(plain syntax region overwrite_mode)
    return 147
  fi
}
function ble/keymap:vi/operator:filter/cancel.hook {
  _ble_edit_mark_active= # clear mark:vi_filter
}
function ble/keymap:vi/operator:filter/.hook {
  local command=$1 # 入力されたコマンド
  if [[ ! $command ]]; then
    ble/widget/vi-command/bell
    return 1
  fi
  local beg=${_ble_keymap_vi_filter_args[0]}
  local end=${_ble_keymap_vi_filter_args[1]}
  local context=${_ble_keymap_vi_filter_args[2]}

  _ble_edit_mark_active= # clear mark:vi_filter

  local old=${_ble_edit_str:beg:end-beg} new
  old=${old%$'\n'}
  if ! ble/util/assign new 'builtin eval -- "$command" <<< "$old" 2>/dev/null'; then
    ble/widget/vi-command/bell
    return 1
  fi
  new=${new%$'\n'}
  ((end<${#_ble_edit_str})) && new=$new$'\n'
  ble/widget/.replace-range "$beg" "$end" "$new"

  _ble_edit_ind=$beg
  if [[ $context == line ]]; then
    ble/widget/vi-command/first-non-space
  else
    ble/keymap:vi/adjust-command-mode
  fi

  ble/keymap:vi/mark/set-previous-edit-area "$beg" "$((beg+${#new}))"
  ble/keymap:vi/operator:filter/.record-repeat "$command"
  return 0
}

#--------------------------------------
# User operator: g@

bleopt/declare -v keymap_vi_operatorfunc ''

function ble/keymap:vi/operator:map {
  local context=$3
  if [[ $bleopt_keymap_vi_operatorfunc ]]; then
    local opfunc=ble/keymap:vi/operator:$bleopt_keymap_vi_operatorfunc
    if ble/is-function "$opfunc"; then
      "$opfunc" "$@"
      return "$?"
    fi
  fi
  return 1
}

#------------------------------------------------------------------------------
# Motions

#--------------------------------------
# Primitive motion

## @fn ble/widget/vi-command/exclusive-range.impl src dst flag reg nobell
## @fn ble/widget/vi-command/exclusive-goto.impl index flag reg nobell
## @fn ble/widget/vi-command/inclusive-goto.impl index flag reg nobell
##
##   @param[in] src, dst
##     移動前の位置と移動先の位置を指定します。
##
##   @param[in] flag
##     オペレータ名を指定します。
##
##   @param[in] reg
##     レジスタ番号を指定します。
##
##   @param[in] opts
##     コロン区切りのオプションです。
##     nobell    移動前と移動後の位置が同じときにベルを鳴らしません。
##     inclusive 移動の既定の動作が inclusive である事を示します。
##
function ble/widget/vi-command/exclusive-range.impl {
  local src=$1 dst=$2 flag=$3 reg=$4 opts=$5
  if [[ $flag ]]; then
    local opname=${flag%%:*} opflags=${flag#*:}
    if [[ :$opflags: == *:vi_line:* ]]; then
      local ble_keymap_vi_opmode=vi_line
      ble/keymap:vi/call-operator-linewise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    elif [[ :$opflags: == *:vi_block:* ]]; then
      local ble_keymap_vi_opmode=vi_line
      ble/keymap:vi/call-operator-blockwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    elif [[ :$opflags: == *:vi_char:* ]]; then
      local ble_keymap_vi_opmode=vi_char

      # 規則 o_v (omap v) の toggle inclusive/exclusive
      if [[ :$opts: == *:inclusive:* ]]; then
        ((src<dst?dst--:(dst<src&&src--)))
      else
        if ((src<=dst)); then
          ((dst<${#_ble_edit_str})) &&
            [[ ${_ble_edit_str:dst:1} != $'\n' ]] &&
            ((dst++))
        else
          ((src<${#_ble_edit_str})) &&
            [[ ${_ble_edit_str:src:1} != $'\n' ]] &&
            ((src++))
        fi
      fi

      ble/keymap:vi/call-operator-charwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    else
      local ble_keymap_vi_opmode=
      ble/keymap:vi/call-operator-charwise "$opname" "$src" "$dst" '' "$reg"; local ext=$?
    fi
    ((ext==147)) && return 147
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  else
    ble/keymap:vi/needs-eol-fix "$dst" && ((dst--))
    if ((dst!=_ble_edit_ind)); then
      _ble_edit_ind=$dst
    elif [[ :$opts: != *:nobell:* ]]; then
      ble/widget/vi-command/bell
      return 1
    fi
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/exclusive-goto.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  if [[ $flag ]]; then
    if ble-edit/content/bolp "$index"; then
      local is_linewise=
      if ((_ble_edit_ind<index)); then
        # :help exclusive-linewise の規則1 (src<ind の時のみ)
        ((index--))
        # :help exclusive-linewise の規則2
        rex=$'(^|\n)[ \t]*$'
        [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
          is_linewise=1
      elif ((index<_ble_edit_ind)); then
        # :help exclusive-linewise の規則2 (条件が異なる)
        ble-edit/content/bolp &&
          is_linewise=1
      fi

      if [[ $is_linewise ]]; then
        ble/widget/vi-command/linewise-goto.impl "$index" "$flag" "$reg"
        return "$?"
      fi
    fi
  fi
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$index" "$flag" "$reg" "$opts"
}
function ble/widget/vi-command/inclusive-goto.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  if [[ $flag ]]; then
    if ((_ble_edit_ind<=index)); then
      ble-edit/content/eolp "$index" || ((index++))
    else
      ble-edit/content/eolp || ((_ble_edit_ind++))
    fi
  fi
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$index" "$flag" "$reg" "$opts:inclusive"
}

## @fn ble/widget/vi-command/linewise-range.impl p q flag reg opts
## @fn ble/widget/vi-command/linewise-goto.impl index flag reg opts
##
##   @param[in] p, q
##     開始位置と終了位置を指定します。
##     flag が設定されていない場合は q に移動します。
##
##   @param[in] index
##     開始位置を _ble_edit_ind とし、
##     移動先または終了位置を指定します。
##
##     index=indx:linex の形をしているとき、
##     基準の位置 indx から linex 行目を移動先とします。
##     index=整数 の場合 index を含む行を移動先とします。
##
##   @param[in] flag
##   @param[in] reg
##
##   @param[in] opts
##     以下のフィールドを似にに含むコロン区切りのリスト
##
##     preserve_column
##     require_multiline
##     goto_bol
##
##     bolx=NUMBER
##       既に計算済みの移動先 (index, q) の行の行頭がある場合はここに指定します。
##
##     nolx=NUMBER
##       既に計算済みの移動先 (index, q) の行の非空白行頭位置がある場合はここに指定します。
##
function ble/widget/vi-command/linewise-range.impl {
  local p=$1 q=$2 flag=$3 reg=$4 opts=$5
  local ret
  if [[ $q == *:* ]]; then
    local qbase=${q%%:*} qline=${q#*:}
  else
    local qbase=$q qline=0
  fi

  local bolx=; local rex=':bolx=([0-9]+):'; [[ :$opts: =~ $rex ]] && bolx=${BASH_REMATCH[1]}
  local nolx=; local rex=':nolx=([0-9]+):'; [[ :$opts: =~ $rex ]] && nolx=${BASH_REMATCH[1]}

  # 移動時 (オペレータが設定されていない時)
  if [[ ! $flag ]]; then
    if [[ ! $nolx ]]; then
      if [[ ! $bolx ]]; then
        ble-edit/content/find-logical-bol "$qbase" "$qline"; bolx=$ret
      fi
      ble-edit/content/find-non-space "$bolx"; nolx=$ret
    fi
    ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  local opname=${flag%%:*} opflags=${flag#*:}
  if ! ble/is-function ble/keymap:vi/operator:"$opname"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local bolp bolq=$bolx nolq=$nolx
  ble-edit/content/find-logical-bol "$p"; bolp=$ret
  [[ $bolq ]] || { ble-edit/content/find-logical-bol "$qbase" "$qline"; bolq=$ret; }

  # jk+- で1行も移動できない場合は操作をキャンセルする。
  # Note: qline を用いる場合は必ずしも望みどおり
  #   qline 行目が存在するとは限らないことに注意する。
  if [[ :$opts: == *:require_multiline:* ]]; then
    if ((bolq==bolp)); then
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  # オペレータ呼び出し
  if [[ :$opflags: == *:vi_char:* || :$opflags: == *:vi_block:* ]]; then
    # 行き先の決定
    local beg=$p end
    if [[ :$opts: == *:preserve_column:* ]]; then
      local index
      ble/keymap:vi/get-index-of-relative-line "$qbase" "$qline"; end=$index
    elif [[ :$opts: == *:goto_bol:* ]]; then
      end=$bolq
    else
      [[ $nolq ]] || { ble-edit/content/find-non-space "$bolq"; nolq=$ret; }
      end=$nolq
    fi
    ((beg<=end)) || local beg=$end end=$beg

    if [[ :$opflags: == *:vi_block:* ]]; then
      local ble_keymap_vi_opmode=vi_block
      ble/keymap:vi/call-operator "$opname" "$beg" "$end" block '' "$reg"; local ext=$?
    else
      local ble_keymap_vi_opmode=vi_char
      ble/keymap:vi/call-operator "$opname" "$beg" "$end" char '' "$reg"; local ext=$?
    fi
    if ((ext)); then
      ((ext==147)) && return 147
      ble/widget/vi-command/bell
      return "$ext"
    fi
  else
    # 行指向の処理 (既定)

    # 最初の行の行頭 beg と最後の行の行末 end
    local beg end
    if ((bolp<=bolq)); then
      ble-edit/content/find-logical-eol "$bolq"; beg=$bolp end=$ret
    else
      ble-edit/content/find-logical-eol "$bolp"; beg=$bolq end=$ret
    fi
    ((end<${#_ble_edit_str}&&end++))

    local ble_keymap_vi_opmode=
    [[ :$opflags: == *:vi_line:* ]] && ble_keymap_vi_opmode=vi_line
    ble/keymap:vi/call-operator "$opname" "$beg" "$end" line '' "$reg"; local ext=$?
    if ((ext)); then
      ((ext==147)) && return 147
      ble/widget/vi-command/bell
      return "$ext"
    fi

    # 範囲の先頭に移動
    local ind=$_ble_edit_ind
    if [[ $opname == [cd] ]]; then
      # これらは常に first-non-space になる。
      _ble_edit_ind=$beg
      ble/widget/vi-command/first-non-space
    elif [[ :$opts: == *:preserve_column:* ]]; then # j k
      if ((beg<ind)); then
        ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
        ((ret=-ret))
      elif ((ind<beg)); then
        ble/string#count-char "${_ble_edit_str:ind:beg-ind}" $'\n'
      else
        ret=0
      fi

      if ((ret)); then
        local index; ble/keymap:vi/get-index-of-relative-line "$_ble_edit_ind" "$ret"
        ble/keymap:vi/needs-eol-fix "$index" && ((index--))
        _ble_edit_ind=$index
      fi
    elif [[ :$opts: == *:goto_bol:* ]]; then # 行指向 yis
      _ble_edit_ind=$beg
    else # + - gg G L H
      if ((beg==bolq||ind<beg)) || [[ ${_ble_edit_str:beg:ind-beg} == *$'\n'* ]] ; then
        # 先頭行の非空白行頭に移動する
        if ((bolq<=bolp)) && [[ $nolq ]]; then
          local nolb=$nolq
        else
          ble-edit/content/find-non-space "$beg"; local nolb=$ret
        fi
        ble-edit/content/nonbol-eolp "$nolb" && ((nolb--))
        ((ind<beg||nolb<ind)) && _ble_edit_ind=$nolb
      fi
    fi
  fi
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-command/linewise-goto.impl {
  ble/widget/vi-command/linewise-range.impl "$_ble_edit_ind" "$@"
}

#------------------------------------------------------------------------------
# single char arguments

function ble/keymap:vi/async-read-char.hook {
  local IFS=$_ble_term_IFS
  local command="${*:1:$#-1}" key="${*:$#}"
  if ((key==(_ble_decode_Ctrl|0x6B))); then # C-k
    ble/decode/keymap/push vi_digraph
    _ble_keymap_vi_digraph__hook="$command"
  else
    builtin eval -- "$command $key"
  fi
}

function ble/keymap:vi/async-read-char {
  local IFS=$_ble_term_IFS
  _ble_decode_key__hook="ble/keymap:vi/async-read-char.hook $*"
  return 147
}

#------------------------------------------------------------------------------
# marks

## @arr _ble_keymap_vi_mark_local
##   添字は mark の文字コードで指定する。
##   各要素は point:bytes の形をしている。
## @arr _ble_keymap_vi_mark_global
##   添字は mark の文字コードで指定する。
##   各要素は hindex:point:bytes の形をしている。
_ble_keymap_vi_mark_Offset=32
_ble_keymap_vi_mark_hindex=
_ble_keymap_vi_mark_local=()
_ble_keymap_vi_mark_global=()
_ble_keymap_vi_mark_history=()
_ble_keymap_vi_mark_edit_dbeg=-1
_ble_keymap_vi_mark_edit_dend=-1
_ble_keymap_vi_mark_edit_dend0=-1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_mark_hindex \
               _ble_keymap_vi_mark_local \
               _ble_keymap_vi_mark_global \
               _ble_keymap_vi_mark_history \
               _ble_keymap_vi_mark_edit_dbeg \
               _ble_keymap_vi_mark_edit_dend \
               _ble_keymap_vi_mark_edit_dend0

# mark 番号と用途の対応
#
#
#   1     内部使用。矩形挿入モードの開始点を記録するためのもの
#   91 93 `[ と `]。編集・ヤンク範囲を保持する。
#   96 39 `` と `'。最後のジャンプ位置を保持する。39 は実際には使用されない。
#   60 62 `< と `>。最後のビジュアル範囲。
#

ble/array#push _ble_edit_dirty_observer ble/keymap:vi/mark/shift-by-dirty-range
blehook history_leave!=ble/keymap:vi/mark/history-onleave.hook

## @fn ble/keymap:vi/mark/history-onleave.hook
function ble/keymap:vi/mark/history-onleave.hook {
  if [[ $_ble_decode_keymap == vi_[inoxs]map ]]; then
    ble/keymap:vi/mark/set-local-mark 34 "$_ble_edit_ind" # `"
  fi
}

# 履歴がロードされていない時は取り敢えず _ble_history_index=0 で登録をしておく。
# 履歴がロードされた後の初めての利用のときに正しい履歴番号に修正する。
function ble/keymap:vi/mark/update-mark-history {
  local h; ble/history/get-index -v h
  if [[ ! $_ble_keymap_vi_mark_hindex ]]; then
    _ble_keymap_vi_mark_hindex=$h
  elif ((_ble_keymap_vi_mark_hindex!=h)); then
    local imark value

    # save
    local -a save=()
    for imark in "${!_ble_keymap_vi_mark_local[@]}"; do
      local value=${_ble_keymap_vi_mark_local[imark]}
      ble/array#push save "$imark:$value"
    done
    local IFS=$_ble_term_IFS
    _ble_keymap_vi_mark_history[_ble_keymap_vi_mark_hindex]="${save[*]-}"

    # load
    _ble_keymap_vi_mark_local=()
    local entry
    for entry in ${_ble_keymap_vi_mark_history[h]-}; do
      imark=${entry%%:*} value=${entry#*:}
      _ble_keymap_vi_mark_local[imark]=$value
    done

    _ble_keymap_vi_mark_hindex=$h
  fi
}
blehook history_change!=ble/keymap:vi/mark/history-change.hook
## @fn ble/keymap:vi/mark/history-change.hook 'delete' index...
## @fn ble/keymap:vi/mark/history-change.hook 'clear'
## @fn ble/keymap:vi/mark/history-change.hook 'insert' beg len
##   @param[in] index...
##     削除する項目の番号を指定します。昇順に並んでいる事と重複がない事を仮定します。
##   @param[in] beg len
##     挿入位置と挿入項目の個数を指定します。
function ble/keymap:vi/mark/history-change.hook {
  local kind=$1; shift
  case $kind in
  (delete)
    # update _ble_keymap_vi_mark_global
    local imark
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}
      local h=${value%%:*} v=${value#*:}
      local idel shift=0
      for idel; do
        if [[ $idel == *-* ]]; then
          local b=${idel%-*} e=${idel#*-}
          ((b<=h&&h<e)) && shift= # delete
          ((h<e)) && break
          ((shift+=e-b))
        else
          ((idel==h)) && shift= # delete
          ((idel>=h)) && break
          ((shift++))
        fi
      done
      [[ $shift ]] &&
        _ble_keymap_vi_mark_global[imark]=$((h-shift)):$v
    done

    # update _ble_keymap_vi_mark_history
    ble/builtin/history/array#delete-hindex _ble_keymap_vi_mark_history "$@"

    # reset _ble_keymap_vi_mark_hindex
    _ble_keymap_vi_mark_hindex= ;;

  (clear)
    _ble_keymap_vi_mark_global=()
    _ble_keymap_vi_mark_history=()
    _ble_keymap_vi_mark_hindex= ;;

  (insert)
    local beg=$1 len=$2

    # update _ble_keymap_vi_mark_global
    local imark
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}

      local h=${value%%:*} v=${value#*:}
      ((h>=beg)) && _ble_keymap_vi_mark_global[imark]=$((h+len)):$v
    done

    # update _ble_keymap_vi_mark_history
    ble/builtin/history/array#insert-range _ble_keymap_vi_mark_history "$@"

    # reset _ble_keymap_vi_mark_hindex
    _ble_keymap_vi_mark_hindex= ;;
  esac
}

function ble/keymap:vi/mark/shift-by-dirty-range {
  local beg=$1 end=$2 end0=$3 reason=$4
  if [[ $4 == edit ]]; then
    ble/dirty-range#update --prefix=_ble_keymap_vi_mark_edit_d "${@:1:3}"
    ble/keymap:vi/xmap/update-dirty-range "$@"

    ble/keymap:vi/mark/update-mark-history
    local shift=$((end-end0))
    local imark
    for imark in "${!_ble_keymap_vi_mark_local[@]}"; do
      local value=${_ble_keymap_vi_mark_local[imark]}
      local index=${value%%:*} rest=${value#*:}
      ((index<beg)) || _ble_keymap_vi_mark_local[imark]=$((index<end0?beg:index+shift)):$rest
    done
    local h; ble/history/get-index -v h
    for imark in "${!_ble_keymap_vi_mark_global[@]}"; do
      local value=${_ble_keymap_vi_mark_global[imark]}
      [[ $value == "$h":* ]] || continue
      local h=${value%%:*}; value=${value:${#h}+1}
      local index=${value%%:*}; value=${value:${#index}+1}
      ((index<beg)) || _ble_keymap_vi_mark_global[imark]=$h:$((index<end0?beg:index+shift)):$value
    done
    ble/keymap:vi/mark/set-local-mark 46 "$beg" # `.
  else
    ble/dirty-range#clear --prefix=_ble_keymap_vi_mark_edit_d
    if [[ $4 == newline && $_ble_decode_keymap != vi_cmap ]]; then
      ble/keymap:vi/mark/set-local-mark 96 0 # ``
    fi
  fi
}
function ble/keymap:vi/mark/set-global-mark {
  local c=$1 index=$2 ret
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  local h; ble/history/get-index -v h
  _ble_keymap_vi_mark_global[c]=$h:$bol:$((index-bol))
}
function ble/keymap:vi/mark/set-local-mark {
  local c=$1 index=$2 ret
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  _ble_keymap_vi_mark_local[c]=$bol:$((index-bol))
}
## @fn ble/keymap:vi/mark/get-mark.impl index bytes
##   @param[in] index bytes
##     記録された行頭の位置と列を指定します。
##   @var[out] ret
##     マークが見つかったとき対応する位置を返します。
function ble/keymap:vi/mark/get-mark.impl {
  local index=$1 bytes=$2
  local len=${#_ble_edit_str}
  ((index>len&&(index=len)))
  ble-edit/content/find-logical-bol "$index"; index=$ret
  ble-edit/content/find-logical-eol "$index"; local eol=$ret
  ((index+=bytes,index>eol&&(index=eol))) # ToDo: calculate by byte offset
  ret=$index
  return 0
}
## @fn ble/keymap:vi/mark/get-mark.impl c
##   @param[in] c
##     mark の番号 (文字コード) を指定します。
##   @var[out] ret
##     マークが見つかったとき対応する位置を返します。
function ble/keymap:vi/mark/get-local-mark {
  local c=$1
  ble/keymap:vi/mark/update-mark-history
  local value=${_ble_keymap_vi_mark_local[c]}
  [[ $value ]] || return 1

  local data
  ble/string#split data : "$value"
  ble/keymap:vi/mark/get-mark.impl "${data[0]}" "${data[1]}" # -> ret
}

# `[ `]
_ble_keymap_vi_mark_suppress_edit=
## @fn ble/keymap:vi/mark/set-previous-edit-area beg end
##   @param[in] beg
##   @param[in] end
function ble/keymap:vi/mark/set-previous-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  local beg=$1 end=$2
  ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  ble/keymap:vi/mark/set-local-mark 91 "$beg" # `[
  ble/keymap:vi/mark/set-local-mark 93 "$end" # `]
  ble/keymap:vi/undo/add
}
function ble/keymap:vi/mark/start-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  ble/dirty-range#clear --prefix=_ble_keymap_vi_mark_edit_d
}
function ble/keymap:vi/mark/commit-edit-area {
  local beg=$1 end=$2
  ble/dirty-range#update --prefix=_ble_keymap_vi_mark_edit_d "$beg" "$end" "$end"
}
function ble/keymap:vi/mark/end-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0
  local beg=$_ble_keymap_vi_mark_edit_dbeg
  local end=$_ble_keymap_vi_mark_edit_dend
  ((beg>=0)) && ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
}

# ``
function ble/keymap:vi/mark/set-jump {
  # ToDo: jumplist?
  ble/keymap:vi/mark/set-local-mark 96 "$_ble_edit_ind"
}

function ble/widget/vi-command/set-mark {
  _ble_decode_key__hook="ble/widget/vi-command/set-mark.hook"
  return 147
}
function ble/widget/vi-command/set-mark.hook {
  local key=$1
  ble/keymap:vi/clear-arg
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      ble/keymap:vi/mark/set-global-mark "$c" "$_ble_edit_ind"
      ble/keymap:vi/adjust-command-mode
      return 0
    elif ((97<=c&&c<123||c==91||c==93||c==60||c==62||c==96||c==39)); then # a-z [ ] < > ` '
      ((c==39)) && c=96 # m' は m` に読み替える
      ble/keymap:vi/mark/set-local-mark "$c" "$_ble_edit_ind"
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/goto-mark.impl {
  local index=$1 flag=$2 reg=$3 opts=$4
  [[ $flag ]] || ble/keymap:vi/mark/set-jump # ``
  if [[ :$opts: == *:line:* ]]; then
    ble/widget/vi-command/linewise-goto.impl "$index" "$flag" "$reg"
  else
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg" nobell
  fi
}
function ble/widget/vi-command/goto-local-mark.impl {
  local c=$1 opts=$2 ret
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ble/keymap:vi/mark/get-local-mark "$c" && local index=$ret; then
    ble/widget/vi-command/goto-mark.impl "$index" "$FLAG" "$REG" "$opts"
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi-command/goto-global-mark.impl {
  local c=$1 opts=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/keymap:vi/mark/update-mark-history
  local value=${_ble_keymap_vi_mark_global[c]}
  if [[ ! $value ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  local data
  ble/string#split data : "$value"

  # find a history entry by data[0]
  local index; ble/history/get-index
  if ((index!=data[0])); then
    if [[ $FLAG ]]; then
      ble/widget/vi-command/bell
      return 1
    fi
    ble-edit/history/goto "${data[0]}"
  fi

  # find position by data[1]:data[2]
  local ret
  ble/keymap:vi/mark/get-mark.impl "${data[1]}" "${data[2]}"
  ble/widget/vi-command/goto-mark.impl "$ret" "$FLAG" "$REG" "$opts"
}

function ble/widget/vi-command/goto-mark {
  _ble_decode_key__hook="ble/widget/vi-command/goto-mark.hook ${1:-char}"
  return 147
}
function ble/widget/vi-command/goto-mark.hook {
  local opts=$1 key=$2
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      ble/widget/vi-command/goto-global-mark.impl "$c" "$opts"
      return "$?"
    elif ((_ble_keymap_vi_mark_Offset<=c)); then
      ((c==39)) && c=96 # `' は `` に読み替える
      ble/widget/vi-command/goto-local-mark.impl "$c" "$opts"
      return "$?"
    fi
  fi
  ble/keymap:vi/clear-arg
  ble/widget/vi-command/bell
  return 1
}

#------------------------------------------------------------------------------
# repeat (nmap .)

## @arr _ble_keymap_vi_repeat
## @arr _ble_keymap_vi_repeat_insert
##
##   _ble_keymap_vi_repeat が前回の操作を記録する
##   _ble_keymap_vi_repeat_insert は挿入モードにいる時に、
##   その挿入モードに突入するきっかけとなった操作を保持する。
##   これは <C-[> または <C-c> で挿入モードを完了する際に、
##   _ble_keymap_vi_repeat に書き込まれるものである。
##
##   ${_ble_keymap_vi_repeat[0]} = KEYMAP
##     呼び出し時の kmap を保持します。
##   ${_ble_keymap_vi_repeat[1]} = KEYS
##     呼び出しに用いられたキーの列を保持します。
##   ${_ble_keymap_vi_repeat[2]} = WIDGET
##     呼び出された編集コマンドを保持します。
##   ${_ble_keymap_vi_repeat[@]:3:3} = ARG FLAG REG
##     呼び出し時の修飾状態を保持します。
##   ${_ble_keymap_vi_repeat[6]} = _ble_keymap_vi_xmap_prev_edit
##     vi_xmap のとき範囲の大きさと種類を記録します。
##   ${_ble_keymap_vi_repeat[@]:10}
##     各 WIDGET が自由に使える領域
##
## @arr _ble_keymap_vi_repeat_irepeat
##
##   _ble_keymap_vi_repeat の操作によって挿入モードに入るとき、
##   そこで行われる挿入操作の列を記録する配列である。
##   形式は _ble_keymap_vi_irepeat と同じ。
##
## @var _ble_keymap_vi_repeat_invoke
##   ble/keymap:vi/repeat/invoke を通して呼び出された widget かどうかを保持するローカル変数です。
##   この変数が非空白のとき ble/keymap:vi/repeat/invoke 内部での呼び出しであることを表します。
##
_ble_keymap_vi_repeat=()
_ble_keymap_vi_repeat_insert=()
_ble_keymap_vi_repeat_irepeat=()
_ble_keymap_vi_repeat_invoke=
function ble/keymap:vi/repeat/record-special {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return 0

  if [[ $_ble_keymap_vi_repeat_invoke ]]; then
    # repeat に引数が指定されたときは以降それを使う
    [[ $repeat_arg ]] && _ble_keymap_vi_repeat[3]=$repeat_arg
    # レジスタが記録されていないときは、以降新しく指定されたレジスタを使う
    [[ ! ${_ble_keymap_vi_repeat[5]} ]] && _ble_keymap_vi_repeat[5]=$repeat_reg
    return 0
  fi

  return 1
}
function ble/keymap:vi/repeat/record-normal {
  local IFS=$_ble_term_IFS
  local -a repeat; repeat=("$KEYMAP" "${KEYS[*]-}" "$WIDGET" "$ARG" "$FLAG" "$REG" '')
  if [[ $KEYMAP == vi_[xs]map ]]; then
    repeat[6]=$_ble_keymap_vi_xmap_prev_edit
  fi
  if [[ $_ble_decode_keymap == vi_imap ]]; then
    _ble_keymap_vi_repeat_insert=("${repeat[@]}")
  else
    _ble_keymap_vi_repeat=("${repeat[@]}")
    _ble_keymap_vi_repeat_irepeat=()
  fi
}
function ble/keymap:vi/repeat/record {
  ble/keymap:vi/repeat/record-special && return 0
  ble/keymap:vi/repeat/record-normal
}
## @fn ble/keymap:vi/repeat/record-insert
##   挿入モードを抜ける時に、挿入モードに入るきっかけになった操作と、
##   挿入モードで行われた挿入操作の列を記録します。
function ble/keymap:vi/repeat/record-insert {
  ble/keymap:vi/repeat/record-special && return 0
  if [[ ${_ble_keymap_vi_repeat_insert-} ]]; then
    # 挿入モード突入操作が未だ有効ならば、挿入操作の有無に拘らず記録
    _ble_keymap_vi_repeat=("${_ble_keymap_vi_repeat_insert[@]}")
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  elif ((${#_ble_keymap_vi_irepeat[@]})); then
    # 挿入モード突入操作が初期化されていたら、挿入操作がある時のみに記録
    local IFS=$_ble_term_IFS
    _ble_keymap_vi_repeat=(vi_nmap "${KEYS[*]-}" ble/widget/vi_nmap/insert-mode 1 '' '')
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  fi
  ble/keymap:vi/repeat/clear-insert
}
## @fn ble/keymap:vi/repeat/clear-insert
##   挿入モードにおいて white list にないコマンドが実行された時に、
##   挿入モードに入るきっかけになった操作を初期化します。
function ble/keymap:vi/repeat/clear-insert {
  _ble_keymap_vi_repeat_insert=()
}

function ble/keymap:vi/repeat/invoke {
  local repeat_arg=$_ble_edit_arg
  local repeat_reg=$_ble_keymap_vi_reg
  local KEYMAP=${_ble_keymap_vi_repeat[0]}
  local -a KEYS; ble/string#split-words KEYS "${_ble_keymap_vi_repeat[1]}"
  local WIDGET=${_ble_keymap_vi_repeat[2]}

  # keymap の状態復元
  if [[ $KEYMAP != vi_[onxs]map ]]; then
    ble/widget/vi-command/bell
    return 1
  elif [[ $KEYMAP == vi_omap ]]; then
    ble/decode/keymap/push vi_omap
  elif [[ $KEYMAP == vi_[xs]map ]]; then
    local _ble_keymap_vi_xmap_prev_edit=${_ble_keymap_vi_repeat[6]}
    ble/widget/vi_xmap/.restore-visual-state
    ble/decode/keymap/push "$KEYMAP"
    # Note: vim では . によって領域の大きさは更新されない。
    #   従ってここでは敢えて _ble_keymap_vi_xmap_prev_edit を unset しない
  fi

  # ※本体の _ble_keymap_vi_repeat は成功した時にのみ repeat/record で書き換える
  _ble_edit_arg=
  _ble_keymap_vi_oparg=${_ble_keymap_vi_repeat[3]}
  _ble_keymap_vi_opfunc=${_ble_keymap_vi_repeat[4]}
  [[ $repeat_arg ]] && _ble_keymap_vi_oparg=$repeat_arg

  # vim ではレジスタは記録されたものが優先されるようだ
  local REG=${_ble_keymap_vi_repeat[5]}
  [[ $REG ]] && _ble_keymap_vi_reg=$REG

  local _ble_keymap_vi_single_command{,_overwrite}= # single-command-mode は持続させる。
  local _ble_keymap_vi_repeat_invoke=1
  local LASTWIDGET=$_ble_decode_widget_last
  _ble_decode_widget_last=$WIDGET
  builtin eval -- "$WIDGET"

  if [[ $_ble_decode_keymap == vi_imap ]]; then
    ((_ble_keymap_vi_irepeat_count<=1?(_ble_keymap_vi_irepeat_count=2):_ble_keymap_vi_irepeat_count++))
    local -a _ble_keymap_vi_irepeat
    _ble_keymap_vi_irepeat=("${_ble_keymap_vi_repeat_irepeat[@]}")

    ble/array#push _ble_keymap_vi_irepeat '0:ble/widget/dummy' # Note: normal-mode が自分自身を pop しようとするので。
    ble/widget/vi_imap/normal-mode
  fi
  ble/util/unlocal _ble_keymap_vi_single_command{,_overwrite}
}

# nmap .
function ble/widget/vi_nmap/repeat {
  ble/keymap:vi/repeat/invoke
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# command: [cdy]?[hl]

## @widget vi-command/forward-char [type]
## @widget vi-command/backward-char [type]
##
##   @param[in] type
##     type=wrap のとき複数行に亘る移動を許します。
##
function ble/widget/vi-command/forward-char {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local index
  if [[ $1 == wrap ]]; then
    # SP
    if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
      ((index=_ble_edit_ind+ARG,
        index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
    else
      local nl=$'\n'
      local rex="^([^$nl]$nl?|$nl){0,$ARG}"
      [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
      ((index=_ble_edit_ind+${#BASH_REMATCH}))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind:ARG}
    line=${line%%$'\n'*}
    ((index=_ble_edit_ind+${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

function ble/widget/vi-command/backward-char {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local index
  ((ARG>_ble_edit_ind&&(ARG=_ble_edit_ind)))
  if [[ $1 == wrap ]]; then
    # DEL
    if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
      ((index=_ble_edit_ind-ARG,index<0&&(index=0)))
    else
      local width=$ARG line
      while ((width<=_ble_edit_ind)); do
        line=${_ble_edit_str:_ble_edit_ind-width:width}
        line=${line//[!$'\n']$'\n'/x}
        ((${#line}>=ARG)) && break
        ((width+=ARG-${#line}))
      done
      ((index=_ble_edit_ind-width,index<0&&(index=0)))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind-ARG:ARG}
    line=${line##*$'\n'}
    ((index=_ble_edit_ind-${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

# nmap ~
function ble/widget/vi_nmap/forward-char-toggle-case {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local line=${_ble_edit_str:_ble_edit_ind:ARG}
  line=${line%%$'\n'*}
  local len=${#line}
  if ((len==0)); then
    ble/widget/vi-command/bell
    return 1
  fi

  local index=$((_ble_edit_ind+len))
  local ret; ble/string#toggle-case "${_ble_edit_str:_ble_edit_ind:len}"
  ble/widget/.replace-range "$_ble_edit_ind" "$index" "$ret"
  ble/keymap:vi/mark/set-previous-edit-area "$_ble_edit_ind" "$index"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  _ble_edit_ind=$index
  ble/keymap:vi/adjust-command-mode
  return 0
}

#------------------------------------------------------------------------------
# command: [cdy]?[jk]

## @fn ble/widget/vi-command/.history-relative-line offset
##
##   @param[in] offset
##     移動する相対行数を指定する。負の値は前に移動することを表し、
##     正の値は後に移動することを表す。
##
##   @exit
##     全く移動しなかった場合は 1 を返します。
##     それ以外の場合は 0 を返します。
##
function ble/widget/vi-command/.history-relative-line {
  local offset=$1
  ((offset)) || return 0

  # 履歴が初期化されていないとき最終行にいる。
  if [[ ! $_ble_history_prefix && ! $_ble_history_load_done ]]; then
    ((offset<0)) || return 1
    ble/history/initialize # to use ble/history/get-index
  fi

  local index histsize
  ble/history/get-index
  ble/history/get-count -v histsize

  local ret count=$((offset<0?-offset:offset)) exit=1
  ((count--))
  while ((count>=0)); do
    if ((offset<0)); then
      ((index>0)) || return "$exit"
      ble/widget/history-prev
      ret=${#_ble_edit_str}
      ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
      _ble_edit_ind=$ret
    else
      ((index<histsize)) || return "$exit"
      ble/widget/history-next
      _ble_edit_ind=0
    fi
    exit=0
    ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
    ((count<nline)) && break
    ((count-=nline))
  done

  if ((count)); then
    if ((offset<0)); then
      ble-edit/content/find-logical-eol 0 "$((nline-count-1))"
      ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    else
      ble-edit/content/find-logical-bol 0 "$count"
    fi
    _ble_edit_ind=$ret
  fi

  return 0
}

## @fn ble/keymap:vi/get-index-of-relative-line p offset
##   列を保持した行移動の先の位置を計算します。
##   @param[in,opt] p
##     基準となる位置を指定します。空文字列を指定した時は現在位置が使われます。
##   @param[in] offset
##     移動する行数を指定します。
##   @param[out] index
function ble/keymap:vi/get-index-of-relative-line {
  local ind=${1:-$_ble_edit_ind} offset=$2
  if ((offset==0)); then
    index=$ind
    return 0
  fi

  local count=$((offset<0?-offset:offset))
  local ret
  ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
  if ble/edit/use-textmap; then
    # 列の表示相対位置 (x,y) を保持
    local b1x b1y; ble/textmap#getxy.cur --prefix=b1 "$bol1"
    local b2x b2y; ble/textmap#getxy.cur --prefix=b2 "$bol2"

    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    local c1x c1y; ble/textmap#getxy.cur --prefix=c1 "$ind"
    local e2x e2y; ble/textmap#getxy.cur --prefix=e2 "$eol2"

    local x=$c1x y=$((b2y+c1y-b1y))
    ((y>e2y&&(x=e2x,y=e2y)))

    ble/textmap#get-index-at "$x" "$y" # local variable "index" is set here
  else
    # 論理列を保持
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))
  fi
}

## @fn ble/widget/vi-command/relative-line.impl offset flag reg opts
## @widget vi-command/forward-line  # nmap j
## @widget vi-command/backward-line # nmap k
##
##   j, k による移動の動作について。論理行を移動するとする。
##   配置情報があるとき、列は行頭からの相対表示位置 (dx,dy) を保持する。
##   配置情報がないとき、論理列を保持する。
##
##   より前の履歴項目に移った時は列は行末に移る。
##   より後の履歴項目に移った時は列は先頭に移る。
##
##   ToDo: 移動開始時の相対表示位置の記録は現在行っていない。
##
##   @param[in] offset flag
##
##   @param[in] opts
##     以下の値をコロンで区切って繋げた物を指定する。
##
##     history
##       現在の履歴項目内で要求された行数だけ移動できないとき、
##       履歴項目内の論理行を移動する。
##       但し flag がある場合は履歴項目の移動は行わない。
##
function ble/widget/vi-command/relative-line.impl {
  local offset=$1 flag=$2 reg=$3 opts=$4
  ((offset==0)) && return 0
  if [[ $flag ]]; then
    ble/widget/vi-command/linewise-goto.impl "$_ble_edit_ind:$offset" "$flag" "$reg" preserve_column:require_multiline
    return "$?"
  fi

  # 現在履歴項目内で移動できる行数の判定
  local count=$((offset<0?-offset:offset)) ret
  if ((offset<0)); then
    ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'
  else
    ble/string#count-char "${_ble_edit_str:_ble_edit_ind}" $'\n'
  fi
  ((count-=count<ret?count:ret))

  # 現在の履歴項目内での探索
  if ((count==0)); then
    local index; ble/keymap:vi/get-index-of-relative-line "$_ble_edit_ind" "$offset"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    _ble_edit_ind=$index
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # 履歴項目を行数を数えつつ移動
  if [[ $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line "$((offset>=0?count:-count))" || ((nmove)); then
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vi-command/forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-line.impl "$ARG" "$FLAG" "$REG" history
}
function ble/widget/vi-command/backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-line.impl "$((-ARG))" "$FLAG" "$REG" history
}

## @fn ble/widget/vi-command/graphical-relative-line.impl offset flag reg opts
## @widget vi-command/graphical-forward-line  # nmap gj
## @widget vi-command/graphical-backward-line # nmap gk
##
##   @param[in] offset
##     移動する相対行数。負の値は上の行へ行くことを表す。正の値は下の行へ行くことを表す。
##   @param[in] flag
##     オペレータを指定する。
##   @param[in] opts
##     以下のオプションをコロンで繋げたものを指定する。
##
##     history
##
function ble/widget/vi-command/graphical-relative-line.impl {
  local offset=$1 flag=$2 reg=$3 opts=$4
  local index move
  if ble/edit/use-textmap; then
    local x y ax ay
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((ax=x,ay=y+offset,
      ay<_ble_textmap_begy?(ay=_ble_textmap_begy):
      (ay>_ble_textmap_endy?(ay=_ble_textmap_endy):0)))
    ble/textmap#get-index-at "$ax" "$ay"
    ble/textmap#getxy.cur --prefix=a "$index"
    ((offset-=move=ay-y))
  else
    local ret ind=$_ble_edit_ind
    ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
    ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))

    if ((index>ind)); then
      ble/string#count-char "${_ble_edit_str:ind:index-ind}" $'\n'
      ((offset+=move=-ret))
    elif ((index<ind)); then
      ble/string#count-char "${_ble_edit_str:index:ind-index}" $'\n'
      ((offset+=move=ret))
    fi
  fi

  if ((offset==0)); then
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
    return "$?"
  fi

  if [[ ! $flag && $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line "$offset"; then
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  # 失敗: オペレータは実行されないが移動はする。
  ((move)) && ble/widget/vi-command/exclusive-goto.impl "$index"
  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vi-command/graphical-forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl "$ARG" "$FLAG" "$REG"
}
function ble/widget/vi-command/graphical-backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl "$((-ARG))" "$FLAG" "$REG"
}

#------------------------------------------------------------------------------
# command: ^ + - _ $

function ble/widget/vi-command/relative-first-non-space.impl {
  local arg=$1 flag=$2 reg=$3 opts=$4
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" "$arg"; local bolx=$ret
  ble-edit/content/find-non-space "$bolx"; local nolx=$ret

  # 2017-09-12 何故か分からないが vim はこういう振る舞いに見える。
  ((_ble_keymap_vi_single_command==2&&_ble_keymap_vi_single_command--))

  if [[ $flag ]]; then
    if [[ :$opts: == *:charwise:* ]]; then
      # command: ^
      ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
      ble/widget/vi-command/exclusive-goto.impl "$nolx" "$flag" "$reg" nobell
    elif [[ :$opts: == *:multiline:* ]]; then
      # command: + -
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" require_multiline:bolx="$bolx":nolx="$nolx"
    else
      # command: _
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" bolx="$bolx":nolx="$nolx"
    fi
    return "$?"
  fi

  local count=$((arg<0?-arg:arg)) nmove=0
  if ((count)); then
    local beg end; ((nolx<ind?(beg=nolx,end=ind):(beg=ind,end=nolx)))
    ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; nmove=$ret
    ((count-=nmove))
  fi

  if ((count==0)); then
    ble/keymap:vi/needs-eol-fix "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # 履歴項目の移動
  if [[ $_ble_decode_keymap == vi_nmap && :$opts: == *:history:* ]] && ble/widget/vi-command/.history-relative-line "$((arg>=0?count:-count))"; then
    ble/widget/vi-command/first-non-space
  elif ((nmove)); then
    ble/keymap:vi/needs-eol-fix "$nolx" && ((nolx--))
    _ble_edit_ind=$nolx
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
# nmap ^
function ble/widget/vi-command/first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl 0 "$FLAG" "$REG" charwise:history
}
# nmap +
function ble/widget/vi-command/forward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$ARG" "$FLAG" "$REG" multiline:history
}
# nmap -
function ble/widget/vi-command/backward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$((-ARG))" "$FLAG" "$REG" multiline:history
}
# nmap _
function ble/widget/vi-command/first-non-space-forward {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$((ARG-1))" "$FLAG" "$REG" history
}
# nmap $
function ble/widget/vi-command/forward-eol {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ((ARG>1)) && [[ ${_ble_edit_str:_ble_edit_ind}  != *$'\n'* ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  local ret index
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG-1))"; index=$ret
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  [[ $_ble_decode_keymap == vi_[xs]map ]] &&
    ble/keymap:vi/xmap/add-eol-extension # 末尾拡張
}
# nmap g0 g<home>
function ble/widget/vi-command/beginning-of-graphical-line {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/beginning-of-line
  fi
}
# nmap g^
function ble/widget/vi-command/graphical-first-non-space {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    ble/widget/vi-command/exclusive-goto.impl "$ret" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/first-non-space
  fi
}
# nmap g$ g<end>
function ble/widget/vi-command/graphical-forward-eol {
  if ble/edit/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at "$((_ble_textmap_cols-1))" "$((y+ARG-1))"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/widget/vi-command/forward-eol
  fi
}
# nmap gm
function ble/widget/vi-command/middle-of-graphical-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index
  if ble/edit/use-textmap; then
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at "$((_ble_textmap_cols/2))" "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  else
    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-logical-eol; local eol=$ret
    ((index=(bol+${COLUMNS:-eol})/2,
      index>eol&&(index=eol),
      bol<eol&&index==eol&&(index--)))
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}
# nmap g_
function ble/widget/vi-command/last-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG-1))"; local index=$ret
  if ((ARG>1)) && [[ ${_ble_edit_str:_ble_edit_ind:index-_ble_edit_ind} != *$'\n'* ]]; then
    # 行移動を起こすはずだったのに一行も進めなかった場合は失敗
    ble/widget/vi-command/bell
    return 1
  fi

  local rex=$'([^ \t\n]?[ \t]+|[^ \t\n])$'
  [[ ${_ble_edit_str::index} =~ $rex ]] && ((index-=${#BASH_REMATCH}))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell

}

#------------------------------------------------------------------------------
# vi_nmap: scroll
#   C-d, C-u, C-e, C-y
#   C-b, prior, C-f, next

_ble_keymap_vi_previous_scroll=
## @fn ble/widget/vi_nmap/scroll.impl opts
##   @arg[in] opts
##     forward
##     backward
function ble/widget/vi_nmap/scroll.impl {
  local opts=$1
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  # adjust arguments
  local ARG FLAG REG; ble/keymap:vi/get-arg "$_ble_keymap_vi_previous_scroll"
  _ble_keymap_vi_previous_scroll=$ARG
  [[ $ARG ]] || ((ARG=height/2))
  [[ :$opts: == *:backward:* ]] && ((ARG=-ARG))

  ble/widget/.update-textmap
  if [[ :$opts: == *:cursor:* ]]; then
    # move
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$((y+ARG))"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    _ble_edit_ind=$ret
    ble/keymap:vi/adjust-command-mode

    ((_ble_textmap_endy<height)) && return 0
    local ax ay
    ble/textmap#getxy.cur --prefix=a "$_ble_edit_ind"
    local max_scroll=$((_ble_textmap_endy+1-height))
    ((_ble_textarea_scroll_new+=ay-y))
    if ((_ble_textarea_scroll_new<0)); then
      _ble_textarea_scroll_new=0
    elif ((_ble_textarea_scroll_new>max_scroll)); then
      _ble_textarea_scroll_new=$max_scroll
    fi
  else
    ((_ble_textmap_endy<height)) && return 0

    local max_scroll=$((_ble_textmap_endy+1-height))
    ((_ble_textarea_scroll_new+=ARG))
    if ((_ble_textarea_scroll_new<0)); then
      _ble_textarea_scroll_new=0
    elif ((_ble_textarea_scroll_new>max_scroll)); then
      _ble_textarea_scroll_new=$max_scroll
    fi

    # ax ay 表示範囲
    local ay=$((_ble_textarea_scroll_new+_ble_textmap_begy))
    local by=$((_ble_textarea_scroll_new+height-1))
    ((_ble_textarea_scroll_new&&ay++))

    # カーソル範囲
    ((_ble_textarea_scroll_new!=0&&ay<by&&ay++,
      _ble_textarea_scroll_new!=max_scroll&&ay<by&&by--))
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    if ((y<ay?(y=ay,1):(y>by?(y=by,1):0))); then
      local index
      ble/textmap#get-index-at "$x" "$y"
      _ble_edit_ind=$index
    fi

    ble/keymap:vi/adjust-command-mode
  fi
}

# nmap C-d
function ble/widget/vi_nmap/forward-line-scroll {
  ble/widget/vi_nmap/scroll.impl forward:cursor
}
# nmap C-u
function ble/widget/vi_nmap/backward-line-scroll {
  ble/widget/vi_nmap/scroll.impl backward:cursor
}
# nmap C-e
function ble/widget/vi_nmap/forward-scroll {
  ble/widget/vi_nmap/scroll.impl forward
}
# nmap C-y
function ble/widget/vi_nmap/backward-scroll {
  ble/widget/vi_nmap/scroll.impl backward
}

# nmap C-f, next
function ble/widget/vi_nmap/pagedown {
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/widget/.update-textmap

  # 最終行以外にいる事を確認
  local x y
  ble/textmap#getxy.cur "$_ble_edit_ind"
  if ((y==_ble_textmap_endy)); then
    ble/widget/vi-command/bell
    return 1
  fi

  # 行き先を決定
  local vheight=$((height-_ble_textmap_begy-1))
  local ybase=$((_ble_textarea_scroll_new+height-1))
  local y1=$((ybase+(ARG-1)*(vheight-2)))
  local index ret
  ble/textmap#get-index-at 0 "$y1"
  ble-edit/content/bolp "$index" &&
    ble-edit/content/find-non-space "$index"; index=$ret
  _ble_edit_ind=$index

  # スクロール (現在位置が上から2行目になる様に)
  local max_scroll=$((_ble_textmap_endy+1-height))
  ble/textmap#getxy.cur "$_ble_edit_ind"
  local scroll=$((y<=_ble_textmap_begy+1?0:(y-_ble_textmap_begy-1)))
  ((scroll>max_scroll&&(scroll=max_scroll)))
  _ble_textarea_scroll_new=$scroll
  ble/keymap:vi/adjust-command-mode
}
# nmap C-b, prior
function ble/widget/vi_nmap/pageup {
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  ble/widget/.update-textmap

  # 少なくとも1行目が表示されていない事を確認
  if ((!_ble_textarea_scroll_new)); then
    ble/widget/vi-command/bell
    return 1
  fi

  # 行き先を決定
  local vheight=$((height-_ble_textmap_begy-1))
  local ybase=$((_ble_textarea_scroll_new+_ble_textmap_begy+1))
  local y1=$((ybase-(ARG-1)*(vheight-2)))
  ((y1<_ble_textmap_begy&&(y1=_ble_textmap_begy)))
  local index ret
  ble/textmap#get-index-at 0 "$y1"
  ble-edit/content/bolp "$index" &&
    ble-edit/content/find-non-space "$index"; index=$ret
  _ble_edit_ind=$index

  # スクロール (現在位置が下から2行目になる様に)
  local x y
  ble/textmap#getxy.cur "$_ble_edit_ind"
  local scroll=$((y-height+2))
  ((scroll<0&&(scroll=0)))
  _ble_textarea_scroll_new=$scroll
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi_nmap/scroll-to-center.impl {
  local opts=$1
  ble/widget/.update-textmap
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}

  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  if [[ ! $ARG && :$opts: == *:pagedown:* ]]; then
    local y1=$((_ble_textarea_scroll_new+height))
    local index
    ble/textmap#get-index-at 0 "$y1"
    ((_ble_edit_ind=index))
  fi

  local ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind"; local bol1=$ret
  if [[ $ARG || :$opts: == *:nol:* ]]; then
    if [[ $ARG ]]; then
      ble-edit/content/find-logical-bol 0 "$((ARG-1))"; local bol2=$ret
    else
      local bol2=$bol1
    fi

    if [[ :$opts: == *:nol:* ]]; then
      # 非空白行頭に移動する
      ble-edit/content/find-non-space "$bol2"
      _ble_edit_ind=$ret
    elif ((bol1!=bol2)); then
      # 行内の同じ相対位置に移動する

      # dx dy = 行頭からの相対位置
      local b1x b1y p1x p1y dx dy
      ble/textmap#getxy.cur --prefix=b1 "$bol1"
      ble/textmap#getxy.cur --prefix=p1 "$_ble_edit_ind"
      ((dx=p1x,dy=p1y-b1y))

      # index = 行き先の行 bol2 の同じ相対位置のインデックス
      local b2x b2y p2x p2y index
      ble/textmap#getxy.cur --prefix=b2 "$bol2"
      ((p2x=b2x,p2y=b2y+dy))
      ble/textmap#get-index-at "$p2x" "$p2y"

      if ble-edit/content/find-logical-bol "$index"; ((ret==bol2)); then
        _ble_edit_ind=$index
      else
        # 別の行になっている時は行末に移動
        ble-edit/content/find-logical-eol "$bol2"
        _ble_edit_ind=$ret
      fi
    fi
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  fi

  # スクロール量の計算
  if ((_ble_textmap_endy+1>height)); then
    local max_scroll=$((_ble_textmap_endy+1-height))

    local b1x b1y
    ble/textmap#getxy.cur --prefix=b1 "$bol1"

    local scroll=
    if [[ :$opts: == *:top:* ]]; then
      ((scroll=b1y-(_ble_textmap_begy+2)))
    elif [[ :$opts: == *:bottom:* ]]; then
      ((scroll=b1y-(height-2)))
    else
      local vheight=$((height-_ble_textmap_begy-1))
      ((scroll=b1y-(_ble_textmap_begy+1+vheight/2)))
    fi

    if ((scroll<0)); then
      scroll=0
    elif ((scroll>max_scroll)); then
      scroll=$max_scroll
    fi
    _ble_textarea_scroll_new=$scroll
  fi

  ble/keymap:vi/adjust-command-mode
}

# nmap zz
function ble/widget/vi_nmap/scroll-to-center-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl
  ble/widget/redraw-line
}
# nmap zt
function ble/widget/vi_nmap/scroll-to-top-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top
  ble/widget/redraw-line
}
# nmap zb
function ble/widget/vi_nmap/scroll-to-bottom-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl bottom
  ble/widget/redraw-line
}
# nmap z.
function ble/widget/vi_nmap/scroll-to-center-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl nol
  ble/widget/redraw-line
}
# nmap z<C-m>
function ble/widget/vi_nmap/scroll-to-top-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top:nol
  ble/widget/redraw-line
}
# nmap z-
function ble/widget/vi_nmap/scroll-to-bottom-non-space-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl bottom:nol
  ble/widget/redraw-line
}
# nmap z+
function ble/widget/vi_nmap/scroll-or-pagedown-and-redraw {
  ble/widget/vi_nmap/scroll-to-center.impl top:nol:pagedown
  ble/widget/redraw-line
}

#------------------------------------------------------------------------------
# command: p P

## @fn ble/widget/vi_nmap/paste.impl/block arg [type]
##
##   @param[in] arg
##     挿入する各行の繰り返し回数を指定します。
##
##   @param[in] type
##     graphical を指定すると配置情報を用いて挿入します。
##     省略したときは、配置情報があるときにそれを使用します。
##     それ以外を指定すると論理列に基いて挿入を行います。
##
##   @var[in] _ble_edit_kill_ring
##     改行区切りの文字列リストです。
##
##   @var[in] _ble_edit_kill_type == B:*
##     B: に続き空白区切りの数字のリストを保持します。
##     数字は _ble_edit_kill_ring に含まれる行の数と同じだけ指定します。
##     数字は行の途中に挿入する際に後ろに追加する空白の数を表します。
##
function ble/widget/vi_nmap/paste.impl/block {
  local arg=${1:-1} type=$2
  local graphical=
  if [[ $type ]]; then
    [[ $type == graphical ]] && graphical=1
  else
    ble/edit/use-textmap && graphical=1
  fi

  local ret cols=$_ble_textmap_cols

  local -a afill; ble/string#split-words afill "${_ble_edit_kill_type:2}"
  local atext; ble/string#split-lines atext "$_ble_edit_kill_ring"
  local ntext=${#atext[@]}

  if [[ $graphical ]]; then
    ble-edit/content/find-logical-bol; local bol=$ret
    local bx by x y c
    ble/textmap#getxy.cur --prefix=b "$bol"
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((y-=by,c=y*cols+x))
  else
    ble-edit/content/find-logical-bol; local bol=$ret
    local c=$((_ble_edit_ind-bol))
  fi

  local -a ins_beg=() ins_end=() ins_text=()
  local i is_newline=
  for ((i=0;i<ntext;i++)); do
    if ((i>0)); then
      ble-edit/content/find-logical-bol "$bol" 1
      if ((bol==ret)); then
        is_newline=1
      else
        bol=$ret
        [[ $graphical ]] && ble/textmap#getxy.cur --prefix=b "$bol"
      fi
    fi

    # 挿入文字列
    local text=${atext[i]}
    local fill=$((afill[i]))
    if ((arg>1)); then
      ret=
      ((fill)) && ble/string#repeat ' ' "$fill"
      ble/string#repeat "$text$ret" "$arg"
      text=${ret::${#ret}-fill}
    fi

    # 挿入位置と padding
    local index iend=
    if [[ $is_newline ]]; then
      index=${#_ble_edit_str}
      ble/string#repeat ' ' "$c"
      text=$'\n'$ret$text

    elif [[ $graphical ]]; then
      ble-edit/content/find-logical-eol "$bol"; local eol=$ret
      ble/textmap#get-index-at "$x" "$((by+y))"; ((index>eol&&(index=eol)))

      # left padding (行末がより左にある、または、全角文字があるとき)
      local ax ay ac; ble/textmap#getxy.out --prefix=a "$index"
      ((ay-=by,ac=ay*cols+ax))
      if ((ac<c)); then
        ble/string#repeat ' ' "$((c-ac))"
        text=$ret$text

        # タブを空白に変換
        if ((index<eol)) && [[ ${_ble_edit_str:index:1} == $'\t' ]]; then
          local rx ry rc; ble/textmap#getxy.out --prefix=r "$((index+1))"
          ((rc=(ry-by)*cols+rx))
          ble/string#repeat ' ' "$((rc-c))"
          text=$text$ret
          iend=$((index+1))
        fi
      fi

      # right padding (行末がより右にあるとき)
      if ((index<eol&&fill)); then
        ble/string#repeat ' ' "$fill"
        text=$text$ret
      fi

    else
      ble-edit/content/find-logical-eol "$bol"; local eol=$ret
      local index=$((bol+c))

      if ((index<eol)); then
        if ((fill)); then
          ble/string#repeat ' ' "$fill"
          text=$text$ret
        fi
      elif ((index>eol)); then
        ble/string#repeat ' ' "$((index-eol))"
        text=$ret$text
        index=$eol
      fi
    fi

    ble/array#push ins_beg "$index"
    ble/array#push ins_end "${iend:-$index}"
    ble/array#push ins_text "$text"
  done

  # 逆順に挿入
  ble/keymap:vi/mark/start-edit-area
  local i=${#ins_beg[@]}
  while ((i--)); do
    local ibeg=${ins_beg[i]} iend=${ins_end[i]} text=${ins_text[i]}
    ble/widget/.replace-range "$ibeg" "$iend" "$text"
  done
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi_nmap/paste.impl {
  local arg=$1 reg=$2 is_after=$3
  if [[ $reg ]]; then
    local _ble_edit_kill_ring _ble_edit_kill_type
    ble/keymap:vi/register#load "$reg"
  fi

  [[ $_ble_edit_kill_ring ]] || return 0
  local ret
  if [[ $_ble_edit_kill_type == L ]]; then
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    local content=$ret

    local index dbeg dend
    if ((is_after)); then
      ble-edit/content/find-logical-eol; index=$ret
      if ((index==${#_ble_edit_str})); then
        content=$'\n'${content%$'\n'}
        ((dbeg=index+1,dend=index+${#content}))
      else
        ((index++,dbeg=index,dend=index+${#content}-1))
      fi
    else
      ble-edit/content/find-logical-bol
      ((index=ret,dbeg=index,dend=index+${#content}-1))
    fi

    ble/widget/.replace-range "$index" "$index" "$content"
    _ble_edit_ind=$dbeg
    ble/keymap:vi/mark/set-previous-edit-area "$dbeg" "$dend"
    ble/keymap:vi/repeat/record
    ble/widget/vi-command/first-non-space
  elif [[ $_ble_edit_kill_type == B:* ]]; then
    if ((is_after)) && ! ble-edit/content/eolp; then
      ((_ble_edit_ind++))
    fi
    ble/widget/vi_nmap/paste.impl/block "$arg"
  else
    if ((is_after)) && ! ble-edit/content/eolp; then
      ((_ble_edit_ind++))
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    local beg=$_ble_edit_ind
    ble/widget/.insert-string "$ret"
    local end=$_ble_edit_ind
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
    [[ $_ble_keymap_vi_single_command ]] || ((_ble_edit_ind--))
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}

function ble/widget/vi_nmap/paste-after {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/paste.impl "$ARG" "$REG" 1
}
function ble/widget/vi_nmap/paste-before {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/paste.impl "$ARG" "$REG" 0
}

#------------------------------------------------------------------------------
# command: x s X C D

# nmap x, <delete>
function ble/widget/vi_nmap/kill-forward-char {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-char
}
# nmap s
function ble/widget/vi_nmap/kill-forward-char-and-insert {
  _ble_keymap_vi_opfunc=c
  ble/widget/vi-command/forward-char
}
# nmap X
function ble/widget/vi_nmap/kill-backward-char {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/backward-char
}
# nmap D
function ble/widget/vi_nmap/kill-forward-line {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-eol
}
# nmap C
function ble/widget/vi_nmap/kill-forward-line-and-insert {
  _ble_keymap_vi_opfunc=c
  ble/widget/vi-command/forward-eol
}

#------------------------------------------------------------------------------
# command: w W b B e E

function ble/widget/vi-command/forward-word.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local ifs=$_ble_term_IFS
  if [[ $flag == c && ${_ble_edit_str:_ble_edit_ind:1} != [$ifs] ]]; then
    # Note: cw cW は特別な動作
    #   http://vim-jp.org/vimdoc-ja/change.html#cw
    ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" "$reg" "$rex_word" allow_here
    return "$?"
  fi
  local b=$'[ \t]' n=$'\n'
  local rex="^((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  if [[ $flag ]]; then
    # :help word-motions の特別規則 (通過した最後の単語が行末にあるとき)
    local rematch1=${BASH_REMATCH[1]}
    if local rex="$n$b*\$"; [[ $rematch1 =~ $rex ]]; then
      local suffix_len=${#BASH_REMATCH}
      ((suffix_len<${#rematch1})) &&
        ((index-=suffix_len))
    fi
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/forward-word-end.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4 opts=$5
  local IFS=$_ble_term_IFS
  local rex="^([$IFS]*($rex_word)?){0,$arg}" # 単語末端に止まる。空行には止まらない
  local offset=1; [[ :$opts: == *:allow_here:* ]] && offset=0
  [[ ${_ble_edit_str:_ble_edit_ind+offset} =~ $rex ]]
  local index=$((_ble_edit_ind+offset+${#BASH_REMATCH}-1))
  ((index<_ble_edit_ind&&(index=_ble_edit_ind)))
  [[ ! $flag && $BASH_REMATCH && ${_ble_edit_str:index:1} == [$IFS] ]] && ble/widget/.bell
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/backward-word.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local b=$'[ \t]' n=$'\n'
  local rex="((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}\$" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind-${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/backward-word-end.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local i=$'[ \t\n]' b=$'[ \t]' n=$'\n' w="($rex_word)"
  local rex1="(^|$w$n?|$n)($b+$n)*$b*"
  local rex="($rex1)($rex1){$((arg-1))}($rex_word|$i)\$" # 単語末端または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+1-${#BASH_REMATCH}))
  local rematch3=${BASH_REMATCH[3]} # 最初の ($rex_word)
  [[ $rematch3 ]] && ((index+=${#rematch3}-1))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" "$reg"
}

# motion w
function ble/widget/vi-command/forward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion e
function ble/widget/vi-command/forward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion b
function ble/widget/vi-command/backward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion ge
function ble/widget/vi-command/backward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
# motion W
function ble/widget/vi-command/forward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion E
function ble/widget/vi-command/forward-uword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion B
function ble/widget/vi-command/backward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
# motion gE
function ble/widget/vi-command/backward-uword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}

#------------------------------------------------------------------------------
# command: [cdy]?[|HL] G gg

# nmap |
function ble/widget/vi-command/nth-column {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret index
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/edit/use-textmap; then
    local bx by; ble/textmap#getxy.cur --prefix=b "$bol" # Note: 先頭行はプロンプトにより bx!=0
    local ex ey; ble/textmap#getxy.cur --prefix=e "$eol"
    local dstx=$((bx+ARG-1)) dsty=$by cols=${COLUMNS:-80}
    ((dsty+=dstx/cols,dstx%=cols))
    ((dsty>ey&&(dsty=ey,dstx=ex)))
    ble/textmap#get-index-at "$dstx" "$dsty" # local variable "index" is set here

    # Note: 何故かノーマルモードで d や c を実行するときには行末に行かないのに、
    # ビジュアルモードでは行末に行くことができるようだ。
    [[ $_ble_decode_keymap != vi_[xs]map ]] &&
      ble-edit/content/nonbol-eolp "$index" && ((index--))
  else
    [[ $_ble_decode_keymap != vi_[xs]map ]] &&
      ble-edit/content/nonbol-eolp "$eol" && ((eol--))
    ((index=bol+ARG-1,index>eol&&(index=eol)))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

# nmap H
function ble/widget/vi-command/nth-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
}
# nmap L
function ble/widget/vi-command/nth-last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl "${#_ble_edit_str}:$((-(ARG-1)))" "$FLAG" "$REG"
}

# nmap gg in history
function ble/widget/vi-command/history-beginning {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    if ((ARG)); then
      _ble_keymap_vi_oparg=$ARG
    else
      _ble_keymap_vi_oparg=
    fi
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    ble/widget/vi-command/nth-line
    return "$?"
  fi

  if ((ARG)); then
    ble-edit/history/goto "$((ARG-1))"
  else
    ble/widget/history-beginning
  fi
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap G in history
function ble/widget/vi-command/history-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    if ((ARG)); then
      _ble_keymap_vi_oparg=$ARG
      ble/widget/vi-command/nth-line
    else
      _ble_keymap_vi_oparg=
      ble/widget/vi-command/nth-last-line
    fi
    return "$?"
  fi

  if ((ARG)); then
    ble-edit/history/goto "$((ARG-1))"
  else
    ble/widget/history-end
  fi
  ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap G
#   Note: vim では G はこの振る舞いだが、blesh では実際には
#     vi-command/history-end が束縛されるのでこれは既定では使われない。
function ble/widget/vi-command/last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  if ((ARG)); then
    ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
  else
    ble/widget/vi-command/linewise-goto.impl "${#_ble_edit_str}:0" "$FLAG" "$REG"
  fi
}

# nmap C-home / gg
#   Note: nth-line (H) との違いは jump でない事のみである。
#   Note: vim では gg もこの振る舞いだが、blesh では gg は
#     既定では vi-command/history-beginning に束縛される。
function ble/widget/vi-command/first-nol {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/linewise-goto.impl "0:$((ARG-1))" "$FLAG" "$REG"
}

# nmap C-end
function ble/widget/vi-command/last-eol {
  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  local ret index
  if [[ $ARG ]]; then
    ble-edit/content/find-logical-eol 0 "$((ARG-1))"; index=$ret
  else
    ble-edit/content/find-logical-eol "${#_ble_edit_str}"; index=$ret
  fi
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# command: r gr

## @fn ble/widget/vi_nmap/replace-char.impl code [overwrite_mode]
##   @param[in] overwrite_mode
##     置換する文字の挿入方法を指定します。
function ble/widget/vi_nmap/replace-char.impl {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=

  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  if ((key==(_ble_decode_Ctrl|91))); then # C-[
    ble/keymap:vi/adjust-command-mode
    return 27
  elif ! ble/keymap:vi/k2c "$key"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local pos=$_ble_edit_ind

  ble/keymap:vi/mark/start-edit-area
  {
    local -a KEYS; KEYS=("$ret")
    local _ble_edit_arg=$ARG
    local _ble_edit_overwrite_mode=$overwrite_mode
    local ble_widget_self_insert_opts=nolineext
    ble/widget/self-insert
    ble/util/unlocal KEYS
  }
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ((pos<_ble_edit_ind&&_ble_edit_ind--))
  ble/keymap:vi/adjust-command-mode
  return 0
}

function ble/widget/vi_nmap/replace-char.hook {
  ble/widget/vi_nmap/replace-char.impl "$1" R
}
function ble/widget/vi_nmap/replace-char {
  _ble_edit_overwrite_mode=R
  ble/keymap:vi/async-read-char ble/widget/vi_nmap/replace-char.hook
}
function ble/widget/vi_nmap/virtual-replace-char.hook {
  ble/widget/vi_nmap/replace-char.impl "$1" 1
}
function ble/widget/vi_nmap/virtual-replace-char {
  _ble_edit_overwrite_mode=1
  ble/keymap:vi/async-read-char ble/widget/vi_nmap/virtual-replace-char.hook
}

#------------------------------------------------------------------------------
# command: J gJ o O

# nmap J
function ble/widget/vi_nmap/connect-line-with-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol; local eol1=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG<=1?1:ARG-1))"; local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:eol2-eol1}
    text=${text//$'\n'/' '}
    ble/widget/.replace-range "$eol1" "$eol2" "$text"
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" "$eol2"
    ble/keymap:vi/repeat/record
    _ble_edit_ind=$((bol2-1))
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
# nmap gJ
function ble/widget/vi_nmap/connect-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol; local eol1=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((ARG<=1?1:ARG-1))"; local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:bol2-eol1}
    text=${text//$'\n'}
    ble/widget/.replace-range "$eol1" "$bol2" "$text"
    local delta=$((${#text}-(bol2-eol1)))
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" "$((eol2+delta))"
    ble/keymap:vi/repeat/record
    _ble_edit_ind=$((bol2+delta))
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/widget/vi_nmap/insert-mode-at-forward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
  _ble_edit_ind=$eol
  ble/widget/.insert-string $'\n'"$indent"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
  _ble_edit_ind=$bol
  ble/widget/.insert-string "$indent"$'\n'
  _ble_edit_ind=$((bol+${#indent}))
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}

#------------------------------------------------------------------------------
# command: f F t F


## @var _ble_keymap_vi_char_search
##   前回の ble/widget/vi-command/search-char.impl/core の検索を記録します。
_ble_keymap_vi_char_search=

## @fn ble/widget/vi-command/search-char.impl/core opts key|char
##
##   @param[in] opts
##     以下のフラグ文字から構成される文字列です。
##
##     b 後方検索であることを表します。
##
##     p 見つかった文字の1つ手前に移動することを表します。
##
##     r 繰り返し検索であることを表します。
##       このとき第1引数は文字 char と解釈されます。
##       これ以外のとき第1引数はキーコード key と解釈されます。
##
##   @param[in] key
##   @param[in] char
##     key は検索対象のキーコードを指定します。
##     char は検索対象の文字を指定します。
##     どちらで解釈されるかは後述する opts のフラグ r に依存します。
##
##
function ble/widget/vi-command/search-char.impl/core {
  local opts=$1 key=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret c
  [[ $opts != *p* ]]; local isprev=$?
  [[ $opts != *r* ]]; local isrepeat=$?
  if ((isrepeat)); then
    c=$key
  elif ((key==(_ble_decode_Ctrl|91))); then # C-[ -> cancel
    return 27
  else
    ble/keymap:vi/k2c "$key" || return 1
    ble/util/c2s "$ret"; local c=$ret
  fi
  [[ $c ]] || return 1

  ((isrepeat)) || _ble_keymap_vi_char_search=$c$opts

  local index
  if [[ $opts == *b* ]]; then
    # backward search
    ble-edit/content/find-logical-bol; local bol=$ret
    local base=$_ble_edit_ind
    ((isrepeat&&isprev&&base--,base>bol)) || return 1
    local line=${_ble_edit_str:bol:base-bol}
    ble/string#last-index-of "$line" "$c" "$ARG"
    ((ret>=0)) || return 1

    ((index=bol+ret,isprev&&index++))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    return "$?"
  else
    # forward search
    ble-edit/content/find-logical-eol; local eol=$ret
    local base=$((_ble_edit_ind+1))
    ((isrepeat&&isprev&&base++,base<eol)) || return 1

    local line=${_ble_edit_str:base:eol-base}
    ble/string#index-of "$line" "$c" "$ARG"
    ((ret>=0)) || return 1

    ((index=base+ret,isprev&&index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    return "$?"
  fi
}
function ble/widget/vi-command/search-char.impl {
  if ble/widget/vi-command/search-char.impl/core "$1" "$2"; then
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/widget/vi-command/search-forward-char {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl f
}
function ble/widget/vi-command/search-forward-char-prev {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl fp
}
function ble/widget/vi-command/search-backward-char {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl b
}
function ble/widget/vi-command/search-backward-char-prev {
  ble/keymap:vi/async-read-char ble/widget/vi-command/search-char.impl bp
}
function ble/widget/vi-command/search-char-repeat {
  [[ $_ble_keymap_vi_char_search ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_char_search::1} opts=${_ble_keymap_vi_char_search:1}
  ble/widget/vi-command/search-char.impl "r$opts" "$c"
}
function ble/widget/vi-command/search-char-reverse-repeat {
  [[ $_ble_keymap_vi_char_search ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_char_search::1} opts=${_ble_keymap_vi_char_search:1}
  if [[ $opts == *b* ]]; then
    opts=f${opts//b}
  else
    opts=b${opts//f}
  fi
  ble/widget/vi-command/search-char.impl "r$opts" "$c"
}

#------------------------------------------------------------------------------
# command: %

## @fn ble/widget/vi-command/search-matchpair/.search-forward
##   @var[in] _ble_edit_str, ch1, ch2, index
##   @var[out] ret
function ble/widget/vi-command/search-matchpair/.search-forward {
  ble/string#index-of-chars "$_ble_edit_str" "$ch1$ch2" "$((index+1))"
}
function ble/widget/vi-command/search-matchpair/.search-backward {
  ble/string#last-index-of-chars "$_ble_edit_str" "$ch1$ch2" "$index"
}

function ble/widget/vi-command/search-matchpair-or {
  local ARG FLAG REG; ble/keymap:vi/get-arg -1
  if ((ARG>=0)); then
    _ble_keymap_vi_oparg=$ARG
    _ble_keymap_vi_opfunc=$FLAG
    _ble_keymap_vi_reg=$REG
    ble/widget/"$@"
    return "$?"
  fi

  local open='({[' close=')}]'

  local ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ! ble/string#index-of-chars "${_ble_edit_str::eol}" '(){}[]' "$_ble_edit_ind"; then
    ble/keymap:vi/adjust-command-mode
    return 1
  fi
  local index1=$ret ch1=${_ble_edit_str:ret:1}

  if [[ $ch1 == ["$open"] ]]; then
    local i=${open%%"$ch"*}; i=${#i}
    local ch2=${close:i:1}
    local searcher=ble/widget/vi-command/search-matchpair/.search-forward
  else
    local i=${close%%"$ch"*}; i=${#i}
    local ch2=${open:i:1}
    local searcher=ble/widget/vi-command/search-matchpair/.search-backward
  fi

  local index=$index1 count=1
  while "$searcher"; do
    index=$ret
    if [[ ${_ble_edit_str:ret:1} == "$ch1" ]]; then
      ((++count))
    else
      ((--count==0)) && break
    fi
  done

  if ((count)); then
    ble/keymap:vi/adjust-command-mode
    return 1
  fi

  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" nobell
}

function ble/widget/vi-command/percentage-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  local iline=$(((ARG*nline+99)/100))
  ble/widget/vi-command/linewise-goto.impl "0:$((iline-1))" "$FLAG" "$REG"
}

#------------------------------------------------------------------------------
# command: go

function ble/widget/vi-command/nth-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ((ARG--))
  local offset=0 text=$_ble_edit_str len=${#_ble_edit_str}
  local left nleft ret
  while ((ARG>0&&len>1)); do
    left=${text::len/2}
    ble/util/strlen "$left"; nleft=$ret
    if ((ARG<nleft)); then
      text=$left
      ((len/=2))
    else
      text=${text:len/2}
      ((offset+=len/2,
        ARG-=nleft,
        len-=len/2))
    fi
  done
  ble/keymap:vi/needs-eol-fix "$offset" && ((offset--))
  ble/widget/vi-command/exclusive-goto.impl "$offset" "$FLAG" "$REG" nobell
}

#------------------------------------------------------------------------------
# text objects

_ble_keymap_vi_text_object=

## @fn ble/keymap:vi/text-object/word.impl      arg flag reg type
## @fn ble/keymap:vi/text-object/quote.impl     arg flag reg type
## @fn ble/keymap:vi/text-object/block.impl     arg flag reg type
## @fn ble/keymap:vi/text-object/tag.impl       arg flag reg type
## @fn ble/keymap:vi/text-object/sentence.impl  arg flag reg type
## @fn ble/keymap:vi/text-object/paragraph.impl arg flag reg type
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##


## @fn ble/keymap:vi/text-object/word.extend-forward
##   Note #D0855
##   @var[in] type arg
##   @var[in] rex_word nl space ifs
##   @var[in,out] beg end
##   @var[out] flags
##     A 先頭に空白が含まれる事を表す。
##     Z 末尾に空白が含まれる事を表す。
##     I 単語前半の取り込みが試みられた事を表す。
function ble/keymap:vi/text-object/word.extend-forward {
  local rex

  flags=
  [[ ${_ble_edit_str:beg:1} == ["$ifs"] ]] && flags=${flags}A
  if [[ $_ble_decode_keymap != vi_[xs]map ]]; then
    flags=${flags}I
  elif ((_ble_edit_mark==_ble_edit_ind)); then
    flags=${flags}I
  fi

  local rex_unit
  local W='('$rex_word')' b='['$space']' n=$nl
  if [[ $type == i* ]]; then
    rex_unit='^'$W'|^'$b'+|^'$n
  elif [[ $type == a* ]]; then
    rex_unit='^'$W$b'*|^'$b'+'$W'|^'$b'*'$n'('$b'+'$n')*('$n'|'$b'*'$W')'
  else
    return 1
  fi

  local i rematch=
  for ((i=0;i<arg;i++)); do
    if ((i==0)) && [[ $flags == *I* ]]; then
      # 単語前方を取り込む
      rex='('$rex_word')$|['$space']*['$ifs']$'
      [[ ${_ble_edit_str::beg+1} =~ $rex ]] &&
        ((beg-=${#BASH_REMATCH}-1,end=beg))
    else
      [[ ${_ble_edit_str:end:1} == $'\n' ]] && ((end++))
    fi

    [[ ${_ble_edit_str:end} =~ $rex_unit ]] || return 1
    rematch=$BASH_REMATCH
    ((end+=${#rematch}))

    # Note: aw に対する正規表現では二重改行を読むが後退する。
    [[ $type == a* && $rematch == *$'\n\n' ]] && ((end--))

    # Note: Vim では何故か最初の一致だけ改行を除去。
    #   最後の一致の改行は exclusive にする事で、
    #   呼び出し元に除去させている様な気がする。
    # Note: aw の時は "非空白から改行" に一致する事はない。
    if ((i==0)) && [[ $flags == *I* ]] || ((i==arg-1)); then
      [[ $type == i* && $rematch == *"$nl" ]] && ((end--))
    fi
  done

  [[ ${_ble_edit_str:end-1:1} == *["$ifs"] ]] && flags=${flags}Z

  if [[ $type == a* && $flags != *[AZ]* ]]; then
    # aw で前後に空白が含まれない時、前方の空白を取り込む
    # Note: vim の実装 (search.c (current_word)) では
    #   行頭 exclusive でも前方空白を取り込むが、
    #   aw において行頭 exclusive になる事は普通はないので謎。
    #   virtual_active() の時行の途中で oneleft() が失敗する事はあるが、
    #   この様な状況を意図してこの条件が加えられたとは思えない。
    if rex='['$space']+$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
      local p=$((beg-${#BASH_REMATCH}))
      ble-edit/content/bolp "$p" || beg=$p
    fi
  fi

  return 0
}
## @fn ble/keymap:vi/text-object/word.extend-backward
##   Note #D0855
##   @var[in,out] beg
##   @var[in] type arg
##   @var[in] rex_word nl space ifs
function ble/keymap:vi/text-object/word.extend-backward {
  local rex_unit=
  local W='('$rex_word')' b='['$space']' n=$nl
  if [[ $type == i* ]]; then
    rex_unit='('$W'|'$b'+)'$n'?$|'$n'$'
  elif [[ $type == a* ]]; then
    rex_unit=$b'*'$W$n'?$|'$W'?'$b'*('$n'('$b'+'$n')*'$b'*)?('$b$n'?|'$n')$'
  else
    return 1
  fi

  local count=$arg
  while ((count--)); do
    [[ ${_ble_edit_str::beg} =~ $rex_unit ]] || return 1
    ((beg-=${#BASH_REMATCH}))

    # Note: vim の振る舞いに倣って
    local match=${BASH_REMATCH%"$nl"}
    if ((beg==0&&${#match}>=2)); then
      if [[ $type == i* ]]; then
        [[ $match == ["$space"]* ]] && beg=1
      elif [[ $type == a* ]]; then
        [[ $match == *[!"$ifs"] ]] && beg=1
      fi
    fi
  done

  return 0
}

function ble/keymap:vi/text-object/word.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local space=$' \t' nl=$'\n' ifs=$_ble_term_IFS
  ((arg==0)) && return 0

  local rex_word
  if [[ $type == ?W ]]; then
    rex_word="[^$ifs]+"
  else
    rex_word=$_ble_keymap_vi_REX_WORD
  fi

  local index=$_ble_edit_ind
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ((index<_ble_edit_mark)); then
      local beg=$index
      if ble/keymap:vi/text-object/word.extend-backward; then
        _ble_edit_ind=$beg
      else
        _ble_edit_ind=0
        ble/widget/.bell
      fi
      ble/keymap:vi/adjust-command-mode
      return 0
    fi
  fi

  local beg=$index end=$index flags=
  if ! ble/keymap:vi/text-object/word.extend-forward; then
    # 一致失敗
    index=${#_ble_edit_str}
    ble-edit/content/nonbol-eolp "$index" && ((index--))
    _ble_edit_ind=$index
    ble/widget/vi-command/bell
    return 1
  fi

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ((end--))
    ble-edit/content/nonbol-eolp "$end" && ((end--))
    ((beg<_ble_edit_mark)) && _ble_edit_mark=$beg
    [[ $_ble_edit_mark_active == vi_line ]] &&
      _ble_edit_mark_active=vi_char
    _ble_edit_ind=$end
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:quote/is-closing-quote index
##   @var[in] quote
function ble/keymap:vi/text-object:quote/is-closing-quote {
  local index=${1:-$_ble_edit_ind}
  [[ ${_ble_edit_str:index:1} == "$quote" ]] || return 1
  local ret
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
  ((ret%2==1))
}
## @fn ble/keymap:vi/text-object:quote/.next [index]
##   @var[in] quote
##   @var[out] ret
function ble/keymap:vi/text-object:quote/.next {
  local index=${1:-$((_ble_edit_ind+1))} nl=$'\n'
  local rex="^[^$nl$quote]*$quote"
  [[ ${_ble_edit_str:index} =~ $rex ]] || return 1
  ((ret=index+${#BASH_REMATCH}-1))
  return 0
}
## @fn ble/keymap:vi/text-object:quote/.prev [index]
##   @var[in] quote
##   @var[out] ret
function ble/keymap:vi/text-object:quote/.prev {
  local index=${1:-_ble_edit_ind} nl=$'\n'
  local rex="$quote[^$nl$quote]*\$"
  [[ ${_ble_edit_str::index} =~ $rex ]] || return 1
  ((ret=index-${#BASH_REMATCH}))
  return 0
}
function ble/keymap:vi/text-object/quote.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret quote=${type:1}
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ble/keymap:vi/text-object:quote/.xmap; then
      ble/keymap:vi/adjust-command-mode
      return 0
    else
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  local beg= end=
  if [[ ${_ble_edit_str:_ble_edit_ind:1} == "$quote" ]]; then
    ble-edit/content/find-logical-bol; local bol=$ret
    ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
    if ((ret%2==1)); then
      # 現在終了引用符
      ((end=_ble_edit_ind+1))
      ble/keymap:vi/text-object:quote/.prev && beg=$ret
    else
      ((beg=_ble_edit_ind))
      ble/keymap:vi/text-object:quote/.next && end=$((ret+1))
    fi
  elif ble/keymap:vi/text-object:quote/.prev && beg=$ret; then
    ble/keymap:vi/text-object:quote/.next && end=$((ret+1))
  elif ble/keymap:vi/text-object:quote/.next && beg=$ret; then
    ble/keymap:vi/text-object:quote/.next "$((beg+1))" && end=$((ret+1))
  fi

  if [[ $beg && $end ]]; then
    [[ $type == i* || arg -gt 1 ]] && ((beg++,end--))
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
## @fn ble/keymap:vi/text-object:quote/.expand-xmap-range mode
##   @param[in] mode
##   @var[in,out] beg
##   @var[in,out] end
function ble/keymap:vi/text-object:quote/.expand-xmap-range {
  local inclusive=$1
  ((end++))
  if ((inclusive==2)); then
    local rex
    rex=$'^[ \t]+'; [[ ${_ble_edit_str:end} =~ $rex ]] && ((end+=${#BASH_REMATCH}))
  elif ((inclusive==0&&end-beg>2)); then
    ((beg++,end--))
  fi
}
## @fn ble/keymap:vi/text-object:quote/.xmap
##   @var[in] quote
function ble/keymap:vi/text-object:quote/.xmap {
  # 複数行に亘る場合は失敗
  local min=$_ble_edit_ind max=$_ble_edit_mark
  ((min>max)) && local min=$max max=$min
  [[ ${_ble_edit_str:min:max+1-min} == *$'\n'* ]] && return 1

  local inclusive=0
  if [[ $type == a* ]]; then
    inclusive=2
  elif ((arg>1)); then
    inclusive=1
  fi

  local ret
  if ((_ble_edit_ind==_ble_edit_mark)); then
    ble/keymap:vi/text-object:quote/.prev "$((_ble_edit_ind+1))" ||
      ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1
    if ble/keymap:vi/text-object:quote/is-closing-quote; then
      local end=$ret
      ble/keymap:vi/text-object:quote/.prev "$end" || return 1
      local beg=$ret
    else
      local beg=$ret
      ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1
      local end=$ret
    fi
    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    _ble_edit_mark=$beg
    _ble_edit_ind=$((end-1))
    return 0
  elif ((_ble_edit_ind>_ble_edit_mark)); then
    local updates_mark=
    if [[ ${_ble_edit_str:_ble_edit_ind:1} == "$quote" ]]; then
      # 現在位置に " があるとき。
      ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local beg=$ret
      if ble/keymap:vi/text-object:quote/.next "$((beg+1))"; then
        local end=$ret
      else
        local end=$beg beg=$_ble_edit_ind
      fi
    else
      # 現在位置以降の最初の 右" (その行の偶数番目の ") と対応する 左"
      ble-edit/content/find-logical-bol; local bol=$ret
      ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
      if ((ret%2==0)); then
        ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local beg=$ret
        ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1; local end=$ret
      else
        ble/keymap:vi/text-object:quote/.prev "$_ble_edit_ind" || return 1; local beg=$ret
        ble/keymap:vi/text-object:quote/.next "$((_ble_edit_ind+1))" || return 1; local end=$ret
      fi
      local i1=$((_ble_edit_mark?_ble_edit_mark-1:0))
      [[ ${_ble_edit_str:i1:_ble_edit_ind-i1} != *"$quote"* ]] && updates_mark=1
    fi

    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    [[ $updates_mark ]] && _ble_edit_mark=$beg
    _ble_edit_ind=$((end-1))
    return 0
  else
    ble-edit/content/find-logical-bol; local bol=$ret nl=$'\n'
    local rex="^([^$nl$quote]*$quote[^$nl$quote]*$quote)*[^$nl$quote]*$quote"
    [[ ${_ble_edit_str:bol:_ble_edit_ind-bol} =~ $rex ]] || return 1
    local beg=$((bol+${#BASH_REMATCH}-1))
    ble/keymap:vi/text-object:quote/.next "$((beg+1))" || return 1
    local end=$ret

    ble/keymap:vi/text-object:quote/.expand-xmap-range "$inclusive"
    [[ ${_ble_edit_str:_ble_edit_ind:_ble_edit_mark+2-_ble_edit_ind} != *"$quote"* ]] && _ble_edit_mark=$((end-1))
    _ble_edit_ind=$beg
    return 0
  fi
}

## @fn ble/keymap:vi/text-object:block/.prev-matching-lparen [index [depth]]
function ble/keymap:vi/text-object:block/.prev-matching-lparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#last-index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$ret
    if [[ ${_ble_edit_str:ret:1} == "$lparen" ]]; then
      ((++count==goal_count)) && return 0
    else
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.next-matching-rparen [index [depth]]
##   @var[out] ret
##     The position of the right paren is stored when the function succeeded.
##     The nesting level of the current context relative to the end of the
##     string is stored when the function failed.
function ble/keymap:vi/text-object:block/.next-matching-rparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$((ret+1))
    if [[ ${_ble_edit_str:ret:1} == "$rparen" ]]; then
      ((++count==goal_count)) && return 0
    else
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.next-matching-lparen [index [depth]]
function ble/keymap:vi/text-object:block/.next-matching-lparen {
  local index=${1:-$_ble_edit_ind} goal_count=${2:-1}

  local p=$index count=0
  while ble/string#index-of-chars "$_ble_edit_str" "$rparen$lparen" "$p"; do
    p=$((ret+1))
    if [[ ${_ble_edit_str:ret:1} == "$rparen" ]]; then
      ((++count==goal_count)) && { ret=$count; return 1; }
    else
      ((count+1==goal_count)) && return 0
      ((--count))
    fi
  done
  ret=$count
  return 1
}

## @fn ble/keymap:vi/text-object:block/.expand-one-level p1
##   @var[ref] beg end
function ble/keymap:vi/text-object:block/.expand-one-level {
  local p1=$1 beg1= end1= ret
  ble/keymap:vi/text-object:block/.prev-matching-lparen "$p1" && beg1=$ret
  ble/keymap:vi/text-object:block/.next-matching-rparen "$p1" && end1=$ret
  if [[ $beg1 && $end1 ]]; then
    beg=$beg1 end=$end1
  elif [[ $beg1 || $end1 ]]; then
    return 1
  fi
}

## @fn ble/keymap:vi/text-object:block/.get-outer-range beg end
##   @var[out] outer_beg outer_end
function ble/keymap:vi/text-object:block/.outer-range {
  outer_beg=$1 outer_end=$2
  if [[ $type == i* ]]; then
    case ${_ble_edit_str::outer_beg} in
    (*"$lparen"$'\n') ((outer_beg-=2)) ;;
    (*"$lparen") ((outer_beg--)) ;;
    esac
    case ${_ble_edit_str:outer_end+1} in
    ($'\n'"$rparen"*) ((outer_end+=2)) ;;
    ("$rparen"*) ((outer_end++)) ;;
    esac
  fi
}

## @fn ble/keymap:vi/text-object:block/.search-block min max L R [opts]
##   @var[out] beg end
function ble/keymap:vi/text-object:block/.search-block {
  local ret p1=$1 p2=$2 L=$3 R=$4 opts=$5
  [[ ${_ble_edit_str:p1:1} == "$L" ]] && ((p1++))
  if ble/keymap:vi/text-object:block/.prev-matching-lparen "$p1" "$arg"; then
    # We first attempt to search for "a surrounding pair (...)" at the
    # specified level of $arg.
    beg=$ret
    ble/keymap:vi/text-object:block/.next-matching-rparen "$p1" "$arg" || return 1
    end=$ret

    if [[ :$opts: == *:reject-empty-here:* ]]; then
      ((beg+1<end)) || return 1
    fi

    if [[ :$opts: == *:check-expand:* ]]; then
      # If the new range is essentially identical (or a prefix) to the current
      # selection, we try to capture the range upper by one level.
      local outer_beg outer_end
      ble/keymap:vi/text-object:block/.outer-range "$p1" "$p2"
      if ((outer_beg==beg&&outer_end>=end)); then
        [[ $type == i* ]] && ((p1--))
        ble/keymap:vi/text-object:block/.expand-one-level "$outer_beg" || return 1
      fi
    fi
  elif ((ret<=0&&arg==1)); then
    # When we fail to find "the surrounding pair (...)" at the top level, we
    # next try "the next pair (...)".  This is attempted only when the
    # specified level is arg=1.
    p1=$1
    [[ ${_ble_edit_str:p1:1} == "$R" ]] && ((p1++))
    ble/keymap:vi/text-object:block/.next-matching-lparen "$p1" || return 1
    beg=$ret
    ble/keymap:vi/text-object:block/.next-matching-rparen "$((beg+1))" || return 1
    end=$ret
    # Note: In Vim, ((beg+1<end)) check does not seem to be performed here.
    # See also the next Note in the code comment below.

    if [[ :$opts: == *:check-expand:* ]]; then
      if [[ $type == i* ]]; then
        local outer_end=$p2
        case ${_ble_edit_str:outer_end+1} in
        ($'\n'"$rparen"*) ((outer_end+=2)) ;;
        ("$rparen"*) ((outer_end++)) ;;
        esac
        ((outer_end<end)) || return 1
      fi
    fi
  else
    return 1
  fi
  return 0
}

## @fn ble/keymap:vi/text-object:block/.xmap
##   @var[in] lparen rparen
##   @var[in] arg
function ble/keymap:vi/text-object:block/.xmap {
  if ((_ble_edit_ind==_ble_edit_mark)); then
    local beg end p=$_ble_edit_ind
    ble/keymap:vi/text-object:block/.search-block "$p" "$p" "$lparen" "$rparen" reject-empty-here || return 1

    # i, a に応じて適切に範囲を決定する
    if [[ $type == i* ]]; then
      # Note: When ((beg + 1 == end)) with "the next pair (...)", the mark and
      # the index is reversed in Vim 9.0.  This might be a bug of Vim because
      # when ((beg + 1 == end)), the text object fails for "the surrounding
      # pair (...)"  but this check seems skipped for "the next pair (...)".
      # Nevertheless, ble.sh follows Vim's behavior.
      ((beg++,end--))
      [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    fi
    _ble_edit_mark=$beg
    _ble_edit_ind=$end
    return 0
  else
    local min=$_ble_edit_mark max=$_ble_edit_ind
    ((min<max)) || local min=$max max=$min
    ble/keymap:vi/text-object:block/.search-block "$min" "$max" "$rparen" "$lparen" reject-empty-here:check-expand || return 1

    if [[ $type == i* ]]; then
      ((beg++,end--))
      [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    fi
    _ble_edit_mark=$beg
    _ble_edit_ind=$end
    return 0
  fi
}

function ble/keymap:vi/text-object/block.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret paren=${type:1} lparen=${type:1:1} rparen=${type:2:1}
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    if ble/keymap:vi/text-object:block/.xmap; then
      ble/keymap:vi/adjust-command-mode
      return 0
    else
      ble/widget/vi-command/bell
      return 1
    fi
  fi

  local beg end p=$_ble_edit_ind
  if ! ble/keymap:vi/text-object:block/.search-block "$p" "$p" "$lparen" "$rparen"; then
    ble/widget/vi-command/bell
    return 1
  fi
  ((end++))

  local linewise=
  if [[ $type == *i* ]]; then
    ((beg++,end--))
    [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    ((beg<end)) && ble-edit/content/bolp "$end" && ((end--))
    ((beg<end)) && ble-edit/content/bolp "$beg" && ble-edit/content/eolp "$end" && linewise=1
  fi

  if [[ $linewise ]]; then
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:tag/.find-end-tag
##   @var[in] beg
##   @var[out] end
function ble/keymap:vi/text-object:tag/.find-end-tag {
  local ifs=$_ble_term_IFS ret rex

  rex="^<([^$ifs/>!]+)"; [[ ${_ble_edit_str:beg} =~ $rex ]] || return 1
  ble/string#escape-for-extended-regex "${BASH_REMATCH[1]}"; local tagname=$ret
  rex="^</?$tagname([$ifs]+([^>]*[^/])?)?>"

  end=$beg
  local count=0
  while ble/string#index-of-chars "$_ble_edit_str" '<' "$end" && end=$((ret+1)); do
    [[ ${_ble_edit_str:end-1} =~ $rex ]] || continue
    ((end+=${#BASH_REMATCH}-1))

    if [[ ${BASH_REMATCH::2} == '</' ]]; then
      ((--count==0)) && return 0
    else
      ((++count))
    fi
  done
  return 1
}
function ble/keymap:vi/text-object/tag.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret rex

  local pivot=$_ble_edit_ind ret=$_ble_edit_ind
  if [[ ${_ble_edit_str:ret:1} == '<' ]] || ble/string#last-index-of-chars "${_ble_edit_str::_ble_edit_ind}" '<>'; then
    if rex='^<[^/][^>]*>' && [[ ${_ble_edit_str:ret} =~ $rex ]]; then
      ((pivot=ret+${#BASH_REMATCH}))
    else
      ((pivot=ret+1))
    fi
  fi

  local ifs=$_ble_term_IFS

  local beg=$pivot count=$arg
  rex="<([^$ifs/>!]+([$ifs]+([^>]*[^/])?)?|/[^>]*)>\$"
  while ble/string#last-index-of-chars "${_ble_edit_str::beg}" '>' && beg=$ret; do
    [[ ${_ble_edit_str::beg+1} =~ $rex ]] || continue
    ((beg-=${#BASH_REMATCH}-1))

    if [[ ${BASH_REMATCH::2} == '</' ]]; then
      ((++count))
    else
      if ((--count==0)); then
        if ble/keymap:vi/text-object:tag/.find-end-tag "$beg" && ((_ble_edit_ind<end)); then
          break
        else
          ((count++))
        fi
      fi
    fi
  done
  if ((count)); then
    ble/widget/vi-command/bell
    return 1
  fi

  if [[ $type == i* ]]; then
    rex='^<[^>]*>'; [[ ${_ble_edit_str:beg:end-beg} =~ $rex ]] && ((beg+=${#BASH_REMATCH}))
    rex='<[^>]*>$'; [[ ${_ble_edit_str:beg:end-beg} =~ $rex ]] && ((end-=${#BASH_REMATCH}))
  fi
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object:sentence/.beg
##   @var[out] beg
##   @var[out] is_interval
##   @var[in] lf, ht
function ble/keymap:vi/text-object:sentence/.beg {
  beg= is_interval=
  local pivot=$_ble_edit_ind rex=
  if ble-edit/content/bolp && ble-edit/content/eolp; then
    if rex=$'^\n+[^\n]'; [[ ${_ble_edit_str:pivot} =~ $rex ]]; then
      # 前方に非空白が見つかればその手前の行を開始点とする
      beg=$((pivot+${#BASH_REMATCH}-2))
    else
      # 前の非空行末を基点に取り直す
      if rex=$'\n+$'; [[ ${_ble_edit_str::pivot} =~ $rex ]]; then
        ((pivot-=${#BASH_REMATCH}))
      fi
    fi
  fi
  if [[ ! $beg ]]; then
    rex="^.*((^$lf?|$lf$lf)([ $ht]*)|[.!?][])'\"]*([ $ht$lf]+))"
    if [[ ${_ble_edit_str::pivot+1} =~ $rex ]]; then
      beg=${#BASH_REMATCH}
      if ((pivot<beg)); then
        # pivot < beg は beg == pivot + 1 (終端まで一致) を意味する。
        # この時点で pivot は必ず非空行または先頭行にいるので /\n\n/ に一致することはない。
        local rematch34=${BASH_REMATCH[3]}${BASH_REMATCH[4]}
        if [[ $rematch34 ]]; then
          # /(^\n\s+|\n\n\s+|[.!?]\s+)$/
          beg=$((pivot+1-${#rematch34})) is_interval=1
        else
          # /^\n$/
          beg=$pivot
        fi
      fi
    else
      beg=0
    fi
  fi
}
## @fn ble/keymap:vi/text-object:sentence/.next {
##   @var[in,out] end
##   @var[in,out] is_interval
##   @var[in] lf, ht
function ble/keymap:vi/text-object:sentence/.next {
  if [[ $is_interval ]]; then
    is_interval=
    local rex=$'[ \t]*((\n[ \t]+)*\n[ \t]*)?'
    [[ ${_ble_edit_str:end} =~ $rex ]]
    local index=$((end+${#BASH_REMATCH}))
    ((end<index)) && [[ ${_ble_edit_str:index-1:1} == $'\n' ]] && ((index--))
    ((end=index))
  else
    is_interval=1
    if local rex=$'^\n+'; [[ ${_ble_edit_str:end} =~ $rex ]]; then
      # 連続する LF を読み切る
      ((end+=${#BASH_REMATCH}))
    elif rex="(([.!?][])\"']*)[ $ht$lf]|$lf$lf).*\$"; [[ ${_ble_edit_str:end} =~ $rex ]]; then
      # 文を次の文末記号まで
      local rematch2=${BASH_REMATCH[2]}
      end=$((${#_ble_edit_str}-${#BASH_REMATCH}+${#rematch2}))
    else
      # 最後の文
      local index=${#_ble_edit_str}
      ((end<index)) && [[ ${_ble_edit_str:index-1:1} == $'\n' ]] && ((index--))
      ((end=index))
    fi
  fi
}
function ble/keymap:vi/text-object/sentence.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local lf=$'\n' ht=$'\t'
  local rex

  local beg is_interval
  ble/keymap:vi/text-object:sentence/.beg

  local end=$beg i n=$arg
  [[ $type != i* ]] && ((n*=2))
  for ((i=0;i<n;i++)); do
    ble/keymap:vi/text-object:sentence/.next
  done
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

  # at は後方 (forward) に空白を確保できなければ前方 (backward) に空白を確保する。
  if [[ $type != i* && ! $is_interval ]]; then
    local ifs=$_ble_term_IFS
    if ((end)) && [[ ${_ble_edit_str:end-1:1} != ["$ifs"] ]]; then
      rex="^.*(^$lf$lf|[.!?][])'\"]*([ $ht$lf]))([ $ht$lf]*)\$"
      if [[ ${_ble_edit_str::beg} =~ $rex ]]; then
        local rematch2=${BASH_REMATCH[2]}
        local rematch3=${BASH_REMATCH[3]}
        ((beg-=${#rematch2}+${#rematch3}))
        [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
      fi
    fi
  fi

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  elif ble-edit/content/bolp "$beg" && [[ ${_ble_edit_str:end:1} == $'\n' ]]; then
    # 行頭から LF の手前までのときに linewise になる。
    # _ble_edit_str の末端までのときは linewise ではないことに注意する。
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

function ble/keymap:vi/text-object/paragraph.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local rex ret

  local beg= empty_start=
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  if rex=$'[ \t]*(\n|$)' ble-edit/content/eolp "$nol"; then
    # 空行のときは連続する一番初めの空行に移動する
    empty_start=1
    rex=$'(^|\n)([ \t]*\n)*$'
    [[ ${_ble_edit_str::bol} =~ $rex ]]
    local rematch1=${BASH_REMATCH[1]} # Note: for bash-3.1 ${#arr[n]} bug
    ((beg=bol-(${#BASH_REMATCH}-${#rematch1})))
  else
    # 非空行のときは最初の非空行の先頭まで移動する。
    if rex=$'^(.*\n)?[ \t]*\n'; [[ ${_ble_edit_str::bol} =~ $rex ]]; then
      ((beg=${#BASH_REMATCH}))
    else
      ((beg=0))
    fi
  fi

  local end=$beg
  local rex_empty_line=$'([ \t]*\n|[ \t]+$)' rex_paragraph_line=$'([ \t]*[^ \t\n][^\n]*(\n|$))'
  if [[ $type == i* ]]; then
    rex="$rex_empty_line+|$rex_paragraph_line+"
  elif [[ $empty_start ]]; then
    rex="$rex_empty_line*$rex_paragraph_line+"
  else
    rex="$rex_paragraph_line+$rex_empty_line*"
  fi
  local i
  for ((i=0;i<arg;i++)); do
    if [[ ${_ble_edit_str:end} =~ $rex ]]; then
      ((end+=${#BASH_REMATCH}))
    else
      # paragraph の場合は次が見つからない場合はエラー
      ble/widget/vi-command/bell
      return 1
    fi
  done

  # at で後続の空行がなければ backward の空行を取り入れる
  if [[ $type != i* && ! $empty_start ]]; then
    if rex=$'(^|\n)[ \t]*\n$'; ! [[ ${_ble_edit_str::end} =~ $rex ]]; then
      if rex=$'(^|\n)([ \t]*\n)*$'; [[ ${_ble_edit_str::beg} =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        ((beg-=${#BASH_REMATCH}-${#rematch1}))
      fi
    fi
  fi
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    _ble_edit_mark=$beg
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## @fn ble/keymap:vi/text-object.impl
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##
function ble/keymap:vi/text-object.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  case $type in
  ([ia][wW]) ble/keymap:vi/text-object/word.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia][\"\'\`]) ble/keymap:vi/text-object/quote.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]['b()']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}()" ;;
  ([ia]['B{}']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}{}" ;;
  ([ia]['<>']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}<>" ;;
  ([ia]['][']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "$reg" "${type::1}[]" ;;
  ([ia]t) ble/keymap:vi/text-object/tag.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]s) ble/keymap:vi/text-object/sentence.impl "$arg" "$flag" "$reg" "$type" ;;
  ([ia]p) ble/keymap:vi/text-object/paragraph.impl "$arg" "$flag" "$reg" "$type" ;;
  (*)
    ble/widget/vi-command/bell
    return 1;;
  esac
}

function ble/keymap:vi/text-object.hook {
  local key=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ! ble-decode-key/ischar "$key"; then
    ble/widget/vi-command/bell
    return 1
  fi

  local ret; ble/util/c2s "$key"
  local type=$_ble_keymap_vi_text_object$ret
  ble/keymap:vi/text-object.impl "$ARG" "$FLAG" "$REG" "$type"
  return 0
}

function ble/keymap:vi/.attempt-text-object {
  local c=${1:-}
  if [[ ! $c ]]; then
    # If the type is not specified, it is determined from the last key the user
    # input (i or a). This is for the backward compatibility.
    local n=${#KEYS[@]}; ((n&&n--))
    ble-decode-key/ischar "${KEYS[n]}" || return 1
    local ret; ble/util/c2s "${KEYS[n]}"; c=$ret
  fi

  [[ $c == [ia] ]] || return 1

  [[ $_ble_keymap_vi_opfunc || $_ble_decode_keymap == vi_[xs]map ]] || return 1

  _ble_keymap_vi_text_object=$c
  _ble_decode_key__hook=ble/keymap:vi/text-object.hook
  return 0
}

function ble/widget/vi-command/text-object {
  ble/keymap:vi/.attempt-text-object "$@" && return 147
  ble/widget/vi-command/bell
  return 1
}

function ble/widget/vi-command/text-object-outer {
  ble/widget/vi-command/text-object a
}

function ble/widget/vi-command/text-object-inner {
  ble/widget/vi-command/text-object i
}

#------------------------------------------------------------------------------
# Command
#
# map: :cmd

# 既定の cmap 履歴
_ble_keymap_vi_commandline_history=()
_ble_keymap_vi_commandline_history_edit=()
_ble_keymap_vi_commandline_history_dirt=()
_ble_keymap_vi_commandline_history_index=0

## @arr _ble_keymap_vi_cmap_is_cancel_key
##   コマンドラインが空の時にキャンセルに使うキーの辞書です。
_ble_keymap_vi_cmap_is_cancel_key[63|_ble_decode_Ctrl]=1  # C-?
_ble_keymap_vi_cmap_is_cancel_key[127]=1                  # DEL
_ble_keymap_vi_cmap_is_cancel_key[104|_ble_decode_Ctrl]=1 # C-h
_ble_keymap_vi_cmap_is_cancel_key[8]=1                    # BS
function ble/keymap:vi/commandline/before-command.hook {
  if [[ ! $_ble_edit_str ]] && ((_ble_keymap_vi_cmap_is_cancel_key[KEYS[0]])); then
    ble/widget/vi_cmap/cancel
    ble/decode/widget/suppress-widget
  fi
}

function ble/widget/vi-command/commandline {
  ble/keymap:vi/clear-arg
  ble/keymap:vi/async-commandline-mode ble/widget/vi-command/commandline.hook
  _ble_edit_PS1=:
  ble/history/set-prefix _ble_keymap_vi_commandline
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/before-command.hook
  return 147
}
function ble/widget/vi-command/commandline.hook {
  local command
  ble/string#split-words command "$1"
  local cmd="ble/widget/vi-command:${command[0]}"
  if ble/is-function "$cmd"; then
    "$cmd" "${command[@]:1}"; local ext=$?
  else
    ble/widget/vi-command/bell "unknown command $1"; local ext=1
  fi
  [[ $1 ]] && _ble_keymap_vi_register[58]=/$result # ":
  return "$ext"
}

function ble/widget/vi-command:w {
  local file=
  if [[ $1 ]]; then
    ble/builtin/history -a "$1"
    file=$1
  elif [[ ${HISTFILE-} ]]; then
    ble/builtin/history -a
    file=$HISTFILE
  else
    ble/widget/vi-command/bell 'w: the history filename is empty or not specified'
    return 1
  fi
  local wc
  ble/util/assign-words wc 'ble/bin/wc "$file"'
  ble/edit/info/show text "\"$file\" ${wc[0]}L, ${wc[2]}C written"
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-command:q! {
  ble/widget/exit force
  return 1
}
function ble/widget/vi-command:q {
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
  return 1
}
function ble/widget/vi-command:wq {
  ble/widget/vi-command:w "$@"
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode
  return 1
}

#------------------------------------------------------------------------------
# Search
#
# map: / ? n N

_ble_keymap_vi_search_obackward=
_ble_keymap_vi_search_ohistory=
_ble_keymap_vi_search_needle=
_ble_keymap_vi_search_activate=
_ble_keymap_vi_search_matched=

_ble_keymap_vi_search_history=()
_ble_keymap_vi_search_history_edit=()
_ble_keymap_vi_search_history_dirt=()
_ble_keymap_vi_search_history_index=0

## @bleopt keymap_vi_search_match_current
##   非空の文字列が設定されている時 /, ?, n, N で
##   現在のカーソルの下にある単語に一致します。
##   既定値は空文字列で vim の振る舞いに倣います。
bleopt/declare -v keymap_vi_search_match_current ''

function ble/highlight/layer:region/mark:vi_search/get-selection {
  ble/highlight/layer:region/mark:vi_char/get-selection
}
function ble/keymap:vi/search/matched {
  [[ $_ble_keymap_vi_search_matched || $_ble_edit_mark_active == vi_search || $_ble_keymap_vi_search_activate ]]
}
function ble/keymap:vi/search/clear-matched {
  _ble_keymap_vi_search_activate=
  _ble_keymap_vi_search_matched=
  [[ $_ble_edit_mark_active == vi_search ]] && _ble_edit_mark_active=
}
## @fn ble/keymap:vi/search/invoke-search needle
##
##   @param[in] needle
##     検索パターンを表す正規表現を指定する。
##
##   @var[out] beg end
##     一致範囲を返す。
##
##   @exit
##     一致が見つかった場合に正常終了 0。それ以外の時は 0 以外の値を返す。
##
##   @var[in] opt_optional_next
##     現在位置より後または前の一致を検索する。
##     vi_omap で呼び出した時、現在位置で一致した時に設定される。
##     keymap_vi_search_match_current が非空の時はここには来ない。
##
##   @var[in] opt_locate
##     現在位置に一致可能な検索を行う。
##     履歴を遡って検索して一致する履歴項目が見つかった時、
##     その履歴項目内で最初に見つかったものを特定する為に使われる。
##
##   @var[in] opt_backward
##     検索方向を指定する。
##
function ble/keymap:vi/search/invoke-search {
  local needle=$1
  local dir=+; ((opt_backward)) && dir=B
  local ind=$_ble_edit_ind

  # 検索開始位置
  if ((opt_optional_next)); then
    if ((!opt_backward)); then
      ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
    fi
  elif ((opt_locate)) || ! ble/keymap:vi/search/matched; then
    # 何にも一致していない状態から
    if ((opt_locate)) || [[ $bleopt_keymap_vi_search_match_current ]]; then
      # 現在位置に一致可能
      #   前方検索: @hello → @hello (そのまま)
      #   後方検索: hell@o → hello@ (ずらす)
      if ((opt_backward)); then
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    else
      # 現在位置には一致させない
      #   前方検索: @hello → h@ello (ずらす)
      #   後方検索: hell@o → hell@o (そのまま)
      if ((!opt_backward)); then
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    fi
  else
    # _ble_edit_ind .. _ble_edit_mark[+1] に一致しているとき
    if ((!opt_backward)); then
      if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
        # vi_xmap, vi_smap では _ble_edit_mark は別の用途に使われていて
        # 終端点の情報が失われているので再度一致を試みる。
        if ble-edit/isearch/search "$@" && ((beg==_ble_edit_ind)); then
          _ble_edit_ind=$end
        else
          ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
        fi
      else
        ((_ble_edit_ind=_ble_edit_mark))
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    else
      # 2回目以降の一致では opts=- で検索する。
      dir=-
    fi
  fi

  ble-edit/isearch/search "$needle" "$dir":regex; local ret=$?
  _ble_edit_ind=$ind
  return "$ret"
}

## @fn ble/widget/vi-command/search.core
##
##   @var[in] needle
##   @var[in] opt_backward
##   @var[in] opt_history
##   @var[in] opt_locate
##   @var[in] start
##   @var[in] ntask
##
function ble/widget/vi-command/search.core {
  local beg= end= is_empty_match=
  if ble/keymap:vi/search/invoke-search "$needle"; then
    if ((beg<end)); then
      ble-edit/content/bolp "$end" || ((end--))
      _ble_edit_ind=$beg # eol 補正は search.impl 側で最後に行う
      [[ $_ble_decode_keymap != vi_[xs]map ]] && _ble_edit_mark=$end
      _ble_keymap_vi_search_activate=vi_search
      return 0
    else
      # vim では空一致は即座に失敗のようだ。
      # 続きを検索するということはしない。
      opt_history=
      is_empty_match=1
    fi
  fi

  if ((opt_history)) && [[ $_ble_history_load_done || opt_backward -ne 0 ]]; then
    ble/history/initialize
    local index; ble/history/get-index
    [[ $start ]] || start=$index
    if ((opt_backward)); then
      ((index--))
    else
      ((index++))
    fi

    local _ble_edit_isearch_dir=+; ((opt_backward)) && _ble_edit_isearch_dir=-
    local _ble_edit_isearch_str=$needle
    local isearch_ntask=$ntask
    local isearch_time=0
    local isearch_progress_callback=ble-edit/isearch/.show-status-with-progress.fib
    if ((opt_backward)); then
      ble/history/isearch-backward-blockwise regex:progress
    else
      ble/history/isearch-forward regex:progress
    fi; local r=$?
    ble/edit/info/default

    if ((r==0)); then
      local new_index; ble/history/get-index -v new_index
      [[ $index != "$new_index" ]] &&
        ble-edit/history/goto "$index"
      if ((opt_backward)); then
        local i=${#_ble_edit_str}
        ble/keymap:vi/needs-eol-fix "$i" && ((i--))
        _ble_edit_ind=$i
      else
        _ble_edit_ind=0
      fi

      opt_locate=1 opt_history=0 ble/widget/vi-command/search.core
      return "$?"
    fi
  fi

  if ((!opt_optional_next)); then
    if [[ $is_empty_match ]]; then
      ble/widget/.bell "search: empty match"
    else
      ble/widget/.bell "search: not found"
    fi
    if [[ $_ble_edit_mark_active == vi_search ]]; then
      _ble_keymap_vi_search_activate=vi_search
    fi
  fi
  return 1
}
function ble/widget/vi-command/search.impl {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local opts=$1 needle=$2
  [[ :$opts: != *:repeat:* ]]; local opt_repeat=$? # 再検索 n N
  [[ :$opts: != *:history:* ]]; local opt_history=$? # 履歴検索が有効か
  [[ :$opts: != *:-:* ]]; local opt_backward=$? # 逆方向
  local opt_locate=0
  local opt_optional_next=0
  if ((opt_repeat)); then
    # n N
    if [[ $_ble_keymap_vi_search_needle ]]; then
      needle=$_ble_keymap_vi_search_needle
      ((opt_backward^=_ble_keymap_vi_search_obackward,
        opt_history=_ble_keymap_vi_search_ohistory))
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  else
    # / ? * #
    ble/keymap:vi/search/clear-matched
    if [[ $needle ]]; then
      _ble_keymap_vi_search_needle=$needle
      _ble_keymap_vi_search_obackward=$opt_backward
      _ble_keymap_vi_search_ohistory=$opt_history
    elif [[ $_ble_keymap_vi_search_needle ]]; then
      needle=$_ble_keymap_vi_search_needle
      _ble_keymap_vi_search_obackward=$opt_backward
      _ble_keymap_vi_search_ohistory=$opt_history
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  fi

  local original_ind=$_ble_edit_ind
  if [[ $FLAG || $_ble_decode_keymap == vi_[xs]map ]]; then
    opt_history=0
  else
    local old_hindex; ble/history/get-index -v old_hindex
  fi

  local start= # 初めの履歴番号。search.core 内で最初に履歴を読み込んだあとで設定される。
  local ntask=$ARG
  while ((ntask)); do
    ble/widget/vi-command/search.core || break
    ((ntask--))
  done

  if [[ $FLAG ]]; then
    if ((ntask)); then
      # 検索対象が見つからなかったとき
      _ble_keymap_vi_search_activate=
      _ble_edit_ind=$original_ind
      ble/keymap:vi/adjust-command-mode
      return 1
    else
      # 見つかったとき
      if ((_ble_edit_ind==original_index)); then
        # 範囲が空のときは次の一致場所まで。
        # 次の一致場所がないとき (自分自身のとき) は空領域になる。
        opt_optional_next=1 ble/widget/vi-command/search.core
      fi
      local index=$_ble_edit_ind

      _ble_keymap_vi_search_activate=
      _ble_edit_ind=$original_ind
      ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
    fi
  else
    if ((ntask<ARG)); then
      # 同じ履歴項目内でのジャンプ
      if ((opt_history)); then
        local new_hindex; ble/history/get-index -v new_hindex
        ((new_hindex==old_hindex))
      fi && ble/keymap:vi/mark/set-local-mark 96 "$original_index" # ``

      # 行末補正
      if ble/keymap:vi/needs-eol-fix; then
        if ((!opt_backward&&_ble_edit_ind<_ble_edit_mark)); then
          ((_ble_edit_ind++))
        else
          ((_ble_edit_ind--))
        fi
      fi
    fi
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/search-forward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl +:history'
  _ble_edit_PS1='/'
  ble/history/set-prefix _ble_keymap_vi_search
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/before-command.hook
  return 147
}
function ble/widget/vi-command/search-backward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl -:history'
  _ble_edit_PS1='?'
  ble/history/set-prefix _ble_keymap_vi_search
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/before-command.hook
  return 147
}
function ble/widget/vi-command/search-repeat {
  ble/widget/vi-command/search.impl repeat:+
}
function ble/widget/vi-command/search-reverse-repeat {
  ble/widget/vi-command/search.impl repeat:-
}

function ble/widget/vi-command/search-word.impl {
  local opts=$1
  local rex=$'^([^[:alnum:]_\n]*)([[:alnum:]_]*)'
  if ! [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]; then
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/bell 'word is not found'
    return 1
  fi

  local end=$((_ble_edit_ind+${#BASH_REMATCH}))
  local word=${BASH_REMATCH[2]}
  if [[ ! ${BASH_REMATCH[1]} ]]; then
    rex=$'[[:alnum:]_]+$'
    [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
      word=$BASH_REMATCH$word
  fi

  # Note: Bash 正規表現は <regex.h> を用いるので、
  #   必ずしも非 POSIX ERE \<\> に対応しているとは限らない。
  #   また [[:alnum:]_] と符合しているかも分からない。
  #   従って適用できるか確認してから境界に一致することを要求する。
  local needle=$word
  rex='\<'$needle; [[ $word =~ $rex ]] && needle=$rex
  rex=$needle'\>'; [[ $word =~ $rex ]] && needle=$rex

  if [[ $opts == backward ]]; then
    ble/widget/vi-command/search.impl -:history "$needle"
  else
    local original_ind=$_ble_edit_ind
    _ble_edit_ind=$((end-1))
    ble/widget/vi-command/search.impl +:history "$needle" && return 0
    _ble_edit_ind=$original_ind
    return 1
  fi
}
# nmap *
function ble/widget/vi-command/search-word-forward {
  ble/widget/vi-command/search-word.impl forward
}
# nmap #
function ble/widget/vi-command/search-word-backward {
  ble/widget/vi-command/search-word.impl backward
}

#------------------------------------------------------------------------------
# command-help

# nmap K
function ble/widget/vi_nmap/command-help {
  ble/keymap:vi/clear-arg
  ble/widget/command-help; local ext=$?
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}
function ble/widget/vi_xmap/command-help.core {
  ble/keymap:vi/clear-arg
  local get_selection=ble/highlight/layer:region/mark:$_ble_edit_mark_active/get-selection
  ble/is-function "$get_selection" || return 1

  local selection
  "$get_selection" || return 1
  ((${#selection[*]}==2)) || return 1

  local comp_cword=0 comp_line=$_ble_edit_str comp_point=$_ble_edit_ind
  local -a comp_words; comp_words=("$cmd")
  local cmd=${_ble_edit_str:selection[0]:selection[1]-selection[0]}
  ble/widget/command-help.impl "$cmd"; local ext=$?
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}
function ble/widget/vi_xmap/command-help {
  if ! ble/widget/vi_xmap/command-help.core; then
    ble/widget/vi-command/bell
    return 1
  fi
}

#------------------------------------------------------------------------------

## @fn ble/keymap:vi/set-up-command-map
##   @var[in] ble_bind_keymap
function ble/keymap:vi/set-up-command-map {
  ble-bind -f 0 vi-command/append-arg
  ble-bind -f 1 vi-command/append-arg
  ble-bind -f 2 vi-command/append-arg
  ble-bind -f 3 vi-command/append-arg
  ble-bind -f 4 vi-command/append-arg
  ble-bind -f 5 vi-command/append-arg
  ble-bind -f 6 vi-command/append-arg
  ble-bind -f 7 vi-command/append-arg
  ble-bind -f 8 vi-command/append-arg
  ble-bind -f 9 vi-command/append-arg
  ble-bind -f y 'vi-command/operator y'
  ble-bind -f d 'vi-command/operator d'
  ble-bind -f c 'vi-command/operator c'
  ble-bind -f '<' 'vi-command/operator indent-left'
  ble-bind -f '>' 'vi-command/operator indent-right'
  ble-bind -f '!' 'vi-command/operator filter'
  ble-bind -f 'g ~' 'vi-command/operator toggle_case'
  ble-bind -f 'g u' 'vi-command/operator u'
  ble-bind -f 'g U' 'vi-command/operator U'
  ble-bind -f 'g ?' 'vi-command/operator rot13'
  ble-bind -f 'g q' 'vi-command/operator fold'
  ble-bind -f 'g w' 'vi-command/operator fold-preserve-point'
  ble-bind -f 'g @' 'vi-command/operator map'
  # ble-bind -f '='   'vi-command/operator =' # インデント (equalprg, ep)
  # ble-bind -f 'z f' 'vi-command/operator f'

  ble-bind -f paste_begin vi-command/bracketed-paste

  ble-bind -f 'home'    vi-command/beginning-of-line
  ble-bind -f '$'       vi-command/forward-eol
  ble-bind -f 'end'     vi-command/forward-eol
  ble-bind -f '^'       vi-command/first-non-space
  ble-bind -f '_'       vi-command/first-non-space-forward
  ble-bind -f '+'       vi-command/forward-first-non-space
  ble-bind -f 'C-m'     vi-command/forward-first-non-space
  ble-bind -f 'RET'     vi-command/forward-first-non-space
  ble-bind -f '-'       vi-command/backward-first-non-space
  ble-bind -f 'g 0'     vi-command/beginning-of-graphical-line
  ble-bind -f 'g home'  vi-command/beginning-of-graphical-line
  ble-bind -f 'g ^'     vi-command/graphical-first-non-space
  ble-bind -f 'g $'     vi-command/graphical-forward-eol
  ble-bind -f 'g end'   vi-command/graphical-forward-eol
  ble-bind -f 'g m'     vi-command/middle-of-graphical-line
  ble-bind -f 'g _'     vi-command/last-non-space

  ble-bind -f h     vi-command/backward-char
  ble-bind -f l     vi-command/forward-char
  ble-bind -f left  vi-command/backward-char
  ble-bind -f right vi-command/forward-char
  ble-bind -f 'C-?' 'vi-command/backward-char wrap'
  ble-bind -f 'DEL' 'vi-command/backward-char wrap'
  ble-bind -f 'C-h' 'vi-command/backward-char wrap'
  ble-bind -f 'BS'  'vi-command/backward-char wrap'
  ble-bind -f SP    'vi-command/forward-char wrap'

  ble-bind -f j     vi-command/forward-line
  ble-bind -f down  vi-command/forward-line
  ble-bind -f C-n   vi-command/forward-line
  ble-bind -f C-j   vi-command/forward-line
  ble-bind -f k     vi-command/backward-line
  ble-bind -f up    vi-command/backward-line
  ble-bind -f C-p   vi-command/backward-line
  ble-bind -f 'g j'    vi-command/graphical-forward-line
  ble-bind -f 'g down' vi-command/graphical-forward-line
  ble-bind -f 'g k'    vi-command/graphical-backward-line
  ble-bind -f 'g up'   vi-command/graphical-backward-line

  ble-bind -f w       vi-command/forward-vword
  ble-bind -f W       vi-command/forward-uword
  ble-bind -f b       vi-command/backward-vword
  ble-bind -f B       vi-command/backward-uword
  ble-bind -f e       vi-command/forward-vword-end
  ble-bind -f E       vi-command/forward-uword-end
  ble-bind -f 'g e'   vi-command/backward-vword-end
  ble-bind -f 'g E'   vi-command/backward-uword-end
  ble-bind -f C-right vi-command/forward-vword
  ble-bind -f S-right vi-command/forward-vword
  ble-bind -f C-left  vi-command/backward-vword
  ble-bind -f S-left  vi-command/backward-vword

  ble-bind -f 'g o'  vi-command/nth-byte
  ble-bind -f '|'    vi-command/nth-column
  ble-bind -f H      vi-command/nth-line
  ble-bind -f L      vi-command/nth-last-line
  ble-bind -f 'g g'  vi-command/history-beginning
  ble-bind -f G      vi-command/history-end
  ble-bind -f C-home vi-command/first-nol
  ble-bind -f C-end  vi-command/last-eol

  ble-bind -f 'f' vi-command/search-forward-char
  ble-bind -f 'F' vi-command/search-backward-char
  ble-bind -f 't' vi-command/search-forward-char-prev
  ble-bind -f 'T' vi-command/search-backward-char-prev
  ble-bind -f ';' vi-command/search-char-repeat
  ble-bind -f ',' vi-command/search-char-reverse-repeat

  ble-bind -f '%' 'vi-command/search-matchpair-or vi-command/percentage-line'

  ble-bind -f 'C-\ C-n' nop

  ble-bind -f ':' vi-command/commandline
  ble-bind -f '/' vi-command/search-forward
  ble-bind -f '?' vi-command/search-backward
  ble-bind -f 'n' vi-command/search-repeat
  ble-bind -f 'N' vi-command/search-reverse-repeat
  ble-bind -f '*' vi-command/search-word-forward
  ble-bind -f '#' vi-command/search-word-backward

  ble-bind -f '`' 'vi-command/goto-mark'
  ble-bind -f \'  'vi-command/goto-mark line'

  # bash
  ble-bind -c 'C-z' fg
}

#------------------------------------------------------------------------------
# Operator pending mode

function ble/widget/vi_omap/operator-rot13-or-search-backward {
  if [[ $_ble_keymap_vi_opfunc == rot13 ]]; then
    # g?? の時だけは rot13-encode lines
    ble/widget/vi-command/operator rot13
  else
    ble/widget/vi-command/search-backward
  fi
}

# o_v o_V
function ble/widget/vi_omap/switch-visual-mode.impl {
  local new_mode=$1

  local old=$_ble_keymap_vi_opfunc
  [[ $old ]] || return 1

  # clear existing visual-mode
  local new=$old:
  new=${new/:vi_char:/:}
  new=${new/:vi_line:/:}
  new=${new/:vi_block:/:}

  # add new visual-mode
  [[ $new_mode ]] && new=$new:$new_mode

  _ble_keymap_vi_opfunc=$new
}
# omap v
function ble/widget/vi_omap/switch-to-charwise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_char
}
# omap V
function ble/widget/vi_omap/switch-to-linewise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_line
}
# omap <C-v>
function ble/widget/vi_omap/switch-to-blockwise {
  ble/widget/vi_omap/switch-visual-mode.impl vi_block
}

function ble-decode/keymap:vi_omap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__ vi_omap/__default__
  ble-bind -f __line_limit__ nop
  ble-bind -f 'ESC' vi_omap/cancel
  ble-bind -f 'C-[' vi_omap/cancel
  ble-bind -f 'C-c' vi_omap/cancel

  ble-bind -f a   vi-command/text-object-outer
  ble-bind -f i   vi-command/text-object-inner

  # 範囲の種類の変更 (vim o_v o_V)
  ble-bind -f v      vi_omap/switch-to-charwise
  ble-bind -f V      vi_omap/switch-to-linewise
  ble-bind -f C-v    vi_omap/switch-to-blockwise
  ble-bind -f C-q    vi_omap/switch-to-blockwise

  # 2文字オペレータの短縮形
  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'
  ble-bind -f '?' 'vi_omap/operator-rot13-or-search-backward'
  ble-bind -f 'q' 'vi-command/operator fold'
  # Note: w は前方単語。例: {N}gww は format {N} words
  # Note: @ は omap では定義されない。例: {N}g@@ は bell
}

#------------------------------------------------------------------------------
# Normal mode

# nmap C-d
function ble/widget/vi-command/exit-on-empty-line {
  if [[ $_ble_edit_str ]]; then
    ble/widget/vi_nmap/forward-scroll
    return "$?"
  else
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
    return 1
  fi
}

# nmap C-g (show line and column)
function ble/widget/vi-command/show-line-info {
  local index count
  ble/history/get-index -v index
  ble/history/get-count -v count
  local hist_ratio=$(((100*index+count-1)/count))%
  local hist_stat=$'!\e[32m'$index$'\e[m / \e[32m'$count$'\e[m (\e[32m'$hist_ratio$'\e[m)'

  local ret
  ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$((ret+1))
  local line_ratio=$(((100*iline+nline-1)/nline))%
  local line_stat=$'line \e[34m'$iline$'\e[m / \e[34m'$nline$'\e[m --\e[34m'$line_ratio$'\e[m--'

  ble/edit/info/show ansi "\"$hist_stat\" $line_stat"
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap C-c (jobs)
function ble/widget/vi-command/cancel {
  if [[ $_ble_keymap_vi_single_command ]]; then
    _ble_keymap_vi_single_command=
    _ble_keymap_vi_single_command_overwrite=
    ble/keymap:vi/update-mode-indicator
  else
    local joblist; ble/util/joblist
    if ((${#joblist[*]})); then
      ble/array#push joblist $'Type  \e[35m:q!\e[m  and press \e[35m<Enter>\e[m to abandon all \e[31mjobs\e[m and exit Bash'
      IFS=$'\n' builtin eval 'ble/edit/info/show ansi "${joblist[*]}"'
    else
      ble/edit/info/show ansi $'Type  \e[35m:q\e[m  and press \e[35m<Enter>\e[m to exit Bash'
    fi
  fi
  ble/widget/vi-command/bell
  return 0
}

# nmap u, U, C-r
#
#   `[`] は設定する。vim と違って実際に変更のあった範囲を抽出する。
#   . は設定しない。
#
bleopt/declare -v keymap_vi_imap_undo ''
_ble_keymap_vi_undo_suppress=
function ble/keymap:vi/undo/add {
  [[ $_ble_keymap_vi_undo_suppress ]] && return 0
  [[ $1 == more && $bleopt_keymap_vi_imap_undo != more ]] && return 0
  ble-edit/undo/add
}
function ble/widget/vi_nmap/undo {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/undo "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi_nmap/redo {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/redo "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vi_nmap/revert {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_keymap_vi_undo_suppress=1
  ble/keymap:vi/mark/start-edit-area
  if ble-edit/undo/revert-toggle "$ARG"; then
    ble/keymap:vi/needs-eol-fix && ((_ble_edit_ind--))
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

# nmap C-a, C-x
function ble/widget/vi_nmap/increment.impl {
  local delta=$1
  ((delta==0)) && return 0

  # 数字の範囲の確定
  local line=${_ble_edit_str:_ble_edit_ind}
  line=${line%%$'\n'*}
  local rex='^([^0-9]*)[0-9]+'
  if ! [[ $line =~ $rex ]]; then
    # 行末にいる時(空行を意味する)にはベルは鳴らさない。
    [[ $line ]] && ble/widget/.bell 'number not found'
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
  local rematch1=${BASH_REMATCH[1]}
  local beg=$((_ble_edit_ind+${#rematch1}))
  local end=$((_ble_edit_ind+${#BASH_REMATCH}))
  rex='-?[0-9]*$'; [[ ${_ble_edit_str::beg} =~ $rex ]]
  ((beg-=${#BASH_REMATCH}))

  # 数の抽出
  local number=${_ble_edit_str:beg:end-beg}
  local abs=${number#-}
  if [[ $abs == 0?* ]]; then
    if [[ $number == -* ]]; then
      number=-$((10#0$abs))
    else
      number=$((10#0$abs))
    fi
  fi

  # 数の増加・減少
  ((number+=delta))
  if [[ $abs == 0?* ]]; then
    # Zero padding
    local wsign=$((number<0?1:0))
    local zpad=$((wsign+${#abs}-${#number}))
    if ((zpad>0)); then
      local ret; ble/string#repeat 0 "$zpad"
      number=${number::wsign}$ret${number:wsign}
    fi
  fi

  ble/widget/.replace-range "$beg" "$end" "$number"
  ble/keymap:vi/mark/set-previous-edit-area "$beg" "$((beg+${#number}))"
  ble/keymap:vi/repeat/record
  _ble_edit_ind=$((beg+${#number}-1))
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi_nmap/increment {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/increment.impl "$ARG"
}
function ble/widget/vi_nmap/decrement {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi_nmap/increment.impl "$((-ARG))"
}
function ble/widget/vi_nmap/__line_limit__.edit {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  ble/widget/edit-and-execute-command.impl "$1"
}
function ble/widget/vi_nmap/__line_limit__ {
  ble/widget/__line_limit__ vi_nmap/__line_limit__.edit
}

function ble-decode/keymap:vi_nmap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__    vi-command/decompose-meta
  ble-bind -f __line_limit__ vi_nmap/__line_limit__
  ble-bind -f 'ESC' vi-command/bell
  ble-bind -f 'C-[' vi-command/bell
  ble-bind -f 'C-c' vi-command/cancel

  ble-bind -f a      vi_nmap/append-mode
  ble-bind -f A      vi_nmap/append-mode-at-end-of-line
  ble-bind -f i      vi_nmap/insert-mode
  ble-bind -f insert vi_nmap/insert-mode
  ble-bind -f I      vi_nmap/insert-mode-at-first-non-space
  ble-bind -f 'g I'  vi_nmap/insert-mode-at-beginning-of-line
  ble-bind -f o      vi_nmap/insert-mode-at-forward-line
  ble-bind -f O      vi_nmap/insert-mode-at-backward-line
  ble-bind -f R      vi_nmap/replace-mode
  ble-bind -f 'g R'  vi_nmap/virtual-replace-mode
  ble-bind -f 'g i'  vi_nmap/insert-mode-at-previous-point

  ble-bind -f '~'    vi_nmap/forward-char-toggle-case

  ble-bind -f Y      vi_nmap/copy-current-line
  ble-bind -f S      vi_nmap/kill-current-line-and-insert
  ble-bind -f D      vi_nmap/kill-forward-line
  ble-bind -f C      vi_nmap/kill-forward-line-and-insert

  ble-bind -f p      vi_nmap/paste-after
  ble-bind -f P      vi_nmap/paste-before

  ble-bind -f x      vi_nmap/kill-forward-char
  ble-bind -f s      vi_nmap/kill-forward-char-and-insert
  ble-bind -f X      vi_nmap/kill-backward-char
  ble-bind -f delete vi_nmap/kill-forward-char

  ble-bind -f 'r'    vi_nmap/replace-char
  ble-bind -f 'g r'  vi_nmap/virtual-replace-char # vim で実際に試すとこの機能はない

  ble-bind -f J      vi_nmap/connect-line-with-space
  ble-bind -f 'g J'  vi_nmap/connect-line

  ble-bind -f v      vi_nmap/charwise-visual-mode
  ble-bind -f V      vi_nmap/linewise-visual-mode
  ble-bind -f C-v    vi_nmap/blockwise-visual-mode
  ble-bind -f C-q    vi_nmap/blockwise-visual-mode
  ble-bind -f 'g v'  vi-command/previous-visual-area
  ble-bind -f 'g h'    vi_nmap/charwise-select-mode
  ble-bind -f 'g H'    vi_nmap/linewise-select-mode
  ble-bind -f 'g C-h'  vi_nmap/blockwise-select-mode

  ble-bind -f .      vi_nmap/repeat

  ble-bind -f K      vi_nmap/command-help
  ble-bind -f f1     vi_nmap/command-help

  ble-bind -f 'C-d'   vi_nmap/forward-line-scroll
  ble-bind -f 'C-u'   vi_nmap/backward-line-scroll
  ble-bind -f 'C-e'   vi_nmap/forward-scroll
  ble-bind -f 'C-y'   vi_nmap/backward-scroll
  ble-bind -f 'C-f'   vi_nmap/pagedown
  ble-bind -f 'next'  vi_nmap/pagedown
  ble-bind -f 'C-b'   vi_nmap/pageup
  ble-bind -f 'prior' vi_nmap/pageup
  ble-bind -f 'z t'   vi_nmap/scroll-to-top-and-redraw
  ble-bind -f 'z z'   vi_nmap/scroll-to-center-and-redraw
  ble-bind -f 'z b'   vi_nmap/scroll-to-bottom-and-redraw
  ble-bind -f 'z RET' vi_nmap/scroll-to-top-non-space-and-redraw
  ble-bind -f 'z C-m' vi_nmap/scroll-to-top-non-space-and-redraw
  ble-bind -f 'z +'   vi_nmap/scroll-or-pagedown-and-redraw
  ble-bind -f 'z -'   vi_nmap/scroll-to-bottom-non-space-and-redraw
  ble-bind -f 'z .'   vi_nmap/scroll-to-center-non-space-and-redraw

  ble-bind -f m      vi-command/set-mark
  ble-bind -f '"'    vi-command/register

  ble-bind -f 'C-g' vi-command/show-line-info

  ble-bind -f 'q' vi_nmap/record-register
  ble-bind -f '@' vi_nmap/play-register

  ble-bind -f u   vi_nmap/undo
  ble-bind -f C-r vi_nmap/redo
  ble-bind -f U   vi_nmap/revert

  ble-bind -f C-a vi_nmap/increment
  ble-bind -f C-x vi_nmap/decrement

  ble-bind -f 'Z Z' 'vi-command:q'
  ble-bind -f 'Z Q' 'vi-command:q'

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-j'     'accept-line'
  ble-bind -f 'C-RET'   'accept-line'
  ble-bind -f 'C-m'     'accept-single-line-or vi-command/forward-first-non-space'
  ble-bind -f 'RET'     'accept-single-line-or vi-command/forward-first-non-space'
  #ble-bind -f 'C-x C-e' 'vi-command/edit-and-execute-command'
  ble-bind -f 'C-l'     'clear-screen'
  ble-bind -f 'C-d'     'vi-command/exit-on-empty-line' # overwrites vi_nmap/forward-scroll
  ble-bind -f 'auto_complete_enter' auto-complete-enter

  # Note #D1256: Bash vi-command 互換性の為
  ble-bind -f M-left   'vi-command/backward-vword'
  ble-bind -f M-right  'vi-command/forward-vword'
  ble-bind -f C-delete 'vi-rlfunc/kill-word'
  ble-bind -f '#'      'vi-rlfunc/insert-comment'
  ble-bind -f '&'      'vi_nmap/@edit tilde-expand'

  # ble-bind -f 'C-u' 'vi-rlfunc/unix-line-discard'
  # ble-bind -f 'C-q' 'vi-rlfunc/quoted-insert'
  # ble-bind -f 'C-v' 'vi-rlfunc/quoted-insert'
  # ble-bind -f 'C-d' 'vi-rlfunc/eof-maybe'
  # ble-bind -f '_'   'vi-rlfunc/yank-arg'
}

# lib/core-decode.vi_nmap-rlfunc.txt 用

function ble/widget/vi-rlfunc/.is-uppercase {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  ((0x41<=code&&code<=0x5a))
}

# d or D
function ble/widget/vi-rlfunc/delete-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-forward-line
  else
    ble/widget/vi-command/operator d
  fi
}
# c or C
function ble/widget/vi-rlfunc/change-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-forward-line-and-insert
  else
    ble/widget/vi-command/operator c
  fi
}
# y or Y
function ble/widget/vi-rlfunc/yank-to {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/copy-current-line
  else
    ble/widget/vi-command/operator y
  fi
}
function ble/widget/vi-rlfunc/char-search {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  ((code==0)) && return 1
  ble/util/c2s "$code"
  case $ret in
  ('f') ble/widget/vi-command/search-forward-char ;;
  ('F') ble/widget/vi-command/search-backward-char ;;
  ('t') ble/widget/vi-command/search-forward-char-prev ;;
  ('T') ble/widget/vi-command/search-backward-char-prev ;;
  (';') ble/widget/vi-command/search-char-repeat ;;
  (',') ble/widget/vi-command/search-char-reverse-repeat ;;
  (*) return 1 ;;
  esac
}
# w or W
function ble/widget/vi-rlfunc/next-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/forward-uword
  else
    ble/widget/vi-command/forward-vword
  fi
}
# b or B
function ble/widget/vi-rlfunc/prev-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/backward-uword
  else
    ble/widget/vi-command/backward-vword
  fi
}
# e or E
function ble/widget/vi-rlfunc/end-word {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/forward-uword-end
  else
    ble/widget/vi-command/forward-vword-end
  fi
}
# p or P
function ble/widget/vi-rlfunc/put {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/paste-before
  else
    ble/widget/vi_nmap/paste-after
  fi
}
# / or ?
function ble/widget/vi-rlfunc/search {
  local n=${#KEYS[@]}
  local code=$((KEYS[n?n-1:0]&_ble_decode_MaskChar))
  if ((code==63)); then
    ble/widget/vi-command/search-backward
  else
    ble/widget/vi-command/search-forward
  fi
}
# n or N
function ble/widget/vi-rlfunc/search-again {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi-command/search-reverse-repeat
  else
    ble/widget/vi-command/search-repeat
  fi
}
# s or S
function ble/widget/vi-rlfunc/subst {
  if ble/widget/vi-rlfunc/.is-uppercase; then
    ble/widget/vi_nmap/kill-current-line-and-insert
  else
    ble/widget/vi_nmap/kill-forward-char-and-insert
  fi
}
# rl_nmap C-delete
function ble/widget/vi-rlfunc/kill-word {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/forward-vword-end
}
# rl_nmap C-u
function ble/widget/vi-rlfunc/unix-line-discard {
  _ble_keymap_vi_opfunc=d
  ble/widget/vi-command/beginning-of-line
}
# rl_nmap #
function ble/widget/vi-rlfunc/insert-comment {
  local ARG FLAG REG; ble/keymap:vi/get-arg ''
  ble/keymap:vi/mark/start-edit-area
  ble/widget/insert-comment/.insert "$ARG"
  ble/keymap:vi/mark/end-edit-area
  ble/widget/vi_nmap/accept-line
}
# rl_nmap C-v, C-q
function ble/widget/vi-rlfunc/quoted-insert-char.hook {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/keymap:vi/mark/start-edit-area
  _ble_edit_arg=$ARG ble/widget/quoted-insert-char.hook
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-rlfunc/quoted-insert-char {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/vi-rlfunc/quoted-insert-char.hook
  return 147
}
function ble/widget/vi-rlfunc/quoted-insert.hook {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/keymap:vi/mark/start-edit-area
  _ble_edit_arg=$ARG ble/widget/quoted-insert.hook
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vi-rlfunc/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/vi-rlfunc/quoted-insert.hook
  return 147
}
# rl_nmap C-d
function ble/widget/vi-rlfunc/eof-maybe {
  if [[ ! $_ble_edit_str ]]; then
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
    return 1
  elif ble-edit/is-single-complete-line; then
    ble/widget/vi_nmap/accept-line
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    ble/keymap:vi/mark/start-edit-area
    _ble_edit_ind=${#_ble_edit_str}
    _ble_edit_arg=$ARG
    ble/widget/self-insert
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/adjust-command-mode
  fi
}
# rl_nmap _
function ble/widget/vi-rlfunc/yank-arg {
  ble/widget/vi_nmap/append-mode
  ble/keymap:vi/imap-repeat/reset
  local -a KEYS; KEYS=(32)
  ble/widget/self-insert
  ble/util/unlocal KEYS
  ble/widget/insert-last-argument
  return "$?"
}

# rlfunc: forward-byte, backward-byte
function ble/widget/vi-command/forward-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$ARG" || [[ $FLAG ]] || ble/widget/.bell
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}
function ble/widget/vi-command/backward-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$((-ARG))" || [[ $FLAG ]] || ble/widget/.bell
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG"
}

# rlfunc: capitalize-word, downcase-word, upcase-word
#%define 2
function ble/widget/vi_nmap/capitalize-XWORD { ble/widget/filter-word.impl XWORD ble/string#capitalize; }
function ble/widget/vi_nmap/downcase-XWORD   { ble/widget/filter-word.impl XWORD ble/string#tolower; }
function ble/widget/vi_nmap/upcase-XWORD     { ble/widget/filter-word.impl XWORD ble/string#toupper; }
#%end
#%expand 2.r/XWORD/eword/
#%expand 2.r/XWORD/cword/
#%expand 2.r/XWORD/uword/
#%expand 2.r/XWORD/sword/
#%expand 2.r/XWORD/fword/

function ble/widget/vi_nmap/@edit {
  ble/keymap:vi/clear-arg
  ble/keymap:vi/repeat/record
  ble/keymap:vi/mark/start-edit-area
  ble/widget/"$@"
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi_nmap/@adjust {
  ble/keymap:vi/clear-arg
  ble/widget/"$@"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi_nmap/@motion {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local _ble_edit_ind=$_ble_edit_ind _ble_edit_arg=$ARG
  if ble/widget/"$@"; then
    local index=$_ble_edit_ind
    ble/util/unlocal _ble_edit_ind
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" nobell
  else
    ble/keymap:vi/adjust-command-mode
  fi
}

#------------------------------------------------------------------------------
# Visual mode

# 選択の種類は _ble_edit_mark_active に設定される文字列で区別する。
#
#   _ble_edit_mark_active は vi_char, vi_line, vi_block のどれかである
#   更に末尾拡張 (行末までの選択範囲の拡張) が設定されているときには
#   vi_char+, vi_line+, vi_block+ などの様に + が末尾に付く。

function ble/keymap:vi/xmap/has-eol-extension {
  [[ $_ble_edit_mark_active == *+ ]]
}
function ble/keymap:vi/xmap/add-eol-extension {
  [[ $_ble_edit_mark_active ]] &&
    _ble_edit_mark_active=${_ble_edit_mark_active%+}+
}
function ble/keymap:vi/xmap/remove-eol-extension {
  [[ $_ble_edit_mark_active ]] &&
    _ble_edit_mark_active=${_ble_edit_mark_active%+}
}
function ble/keymap:vi/xmap/switch-type {
  local suffix; [[ $_ble_edit_mark_active == *+ ]] && suffix=+
  _ble_edit_mark_active=$1$suffix
}

#--------------------------------------
# xmap/矩形範囲の抽出

## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-graphical-rectangle [index1 [index2]]
## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-logical-rectangle   [index1 [index2]]
## @fn local p0 q0 lx ly rx ry; ble/keymap:vi/get-rectangle [index1 [index2]]
## @fn local ret              ; ble/keymap:vi/get-rectangle-height [index1 [index2]]
##
##   @param[in,opt] index1 [=_ble_edit_mark]
##   @param[in,opt] index2 [=_ble_edit_ind]
##
##   @var[out] p0 q0
##   @var[out] lx ly rx ry
##
function ble/keymap:vi/get-graphical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  local ret
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret

  local p0x p0y q0x q0y
  ble/textmap#getxy.out --prefix=p0 "$p0"
  ble/textmap#getxy.out --prefix=q0 "$q0"

  local plx ply qlx qly
  ble/textmap#getxy.cur --prefix=pl "$p"
  ble/textmap#getxy.cur --prefix=ql "$q"

  local prx=$plx pry=$ply qrx=$qlx qry=$qly
  ble-edit/content/eolp "$p" && ((prx++)) || ble/textmap#getxy.out --prefix=pr "$((p+1))"
  ble-edit/content/eolp "$q" && ((qrx++)) || ble/textmap#getxy.out --prefix=qr "$((q+1))"

  ((ply-=p0y,qly-=q0y,pry-=p0y,qry-=q0y,
    (ply<qly||ply==qly&&plx<qlx)?(lx=plx,ly=ply):(lx=qlx,ly=qly),
    (pry>qry||pry==qry&&prx>qrx)?(rx=prx,ry=pry):(rx=qrx,ry=qry)))
}
function ble/keymap:vi/get-logical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  local ret
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret
  ((p-=p0,q-=q0,p<=q)) || local p=$q q=$p
  lx=$p rx=$((q+1)) ly=0 ry=0
}
function ble/keymap:vi/get-rectangle {
  if ble/edit/use-textmap; then
    ble/keymap:vi/get-graphical-rectangle "$@"
  else
    ble/keymap:vi/get-logical-rectangle "$@"
  fi
}
## @fn ble/keymap:vi/get-rectangle-height [index1 [index2]]
##   @var[out] ret
function ble/keymap:vi/get-rectangle-height {
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-rectangle "$@"
  ble/string#count-char "${_ble_edit_str:p0:q0-p0}" $'\n'
  ((ret++))
  return 0
}


## @fn ble/keymap:vi/extract-graphical-block-by-geometry bol1 bol2 x1:y1 x2:y2 opts
## @fn ble/keymap:vi/extract-logical-block-by-geometry bol1 bol2 c1 c2 opts
##   指定した引数の範囲を元に矩形範囲を抽出します。
## @fn ble/keymap:vi/extract-graphical-block [index1 [index2 [opts]]]
## @fn ble/keymap:vi/extract-logical-block [index1 [index2 [opts]]]
## @fn ble/keymap:vi/extract-block [index1 [index2 [opts]]]
##   現在位置 (_ble_edit_ind) とマーク (_ble_edit_mark) を元に矩形範囲を抽出します。
##
##   @param[in] bol1 bol2
##     2つの行の行頭を指定します。
##   @param[in] x1:y1 x2:y2
##     2つの列を行頭からの相対位置で指定します。
##   @param[in] c1 c2
##     2つの列を論理列で指定します。
##
##   @param[in,opt] index1 [$_ble_edit_mark]
##   @param[in,opt] index2 [$_ble_edit_ind]
##     矩形の端点の文字インデックスを指定します。
##
##   @param[in,opt] opts
##     コロン区切りのフラグ指定です。
##
##     first_line
##       矩形を構成する最初の行についてだけ情報を取得します。
##       その他の行については空の情報 (':::::') を sub_ranges に格納します。
##
##     skip_middle
##       矩形を構成する最初と最後の行についてだけ情報を取得します。
##       その他の行については空の情報 (':::::') を sub_ranges に格納します。
##
##   @var[in] _ble_edit_mark_active
##     末尾拡張を行うばあいにこの引数の末端に + を指定します。
##
##   @arr[out] sub_ranges
##     矩形を構成する各行の情報を格納します。
##     各要素は以下の形式を持ちます。
##
##     smin:smax:slpad:srpad:sfill:stext
##
##     smin smax
##       選択範囲を強調するとき・切り取るときの範囲を指定します。
##     slpad srpad
##       選択範囲を切り取ったときに左右に補填する空白の数を指定します。
##     sfill
##       矩形の挿入時に右端に補填するべき空白の数を指定します。
##     stext
##       選択範囲から読み取られる文字列を指定します。
##       全角文字などが範囲の境界を跨ぐとき、
##       その文字は (範囲に被る幅と同数の) 空白に置き換えられます。
##   @var[out] sub_x1 sub_x2
##
function ble/keymap:vi/extract-graphical-block-by-geometry {
  local bol1=$1 bol2=$2 x1=$3 x2=$4 y1=0 y2=0 opts=$5
  ((bol1<=bol2||(bol1=$2,bol2=$1)))
  [[ $x1 == *:* ]] && local x1=${x1%%:*} y1=${x1#*:}
  [[ $x2 == *:* ]] && local x2=${x2%%:*} y2=${x2#*:}

  local cols=$_ble_textmap_cols
  local c1=$((cols*y1+x1)) c2=$((cols*y2+x2))
  sub_x1=$c1 sub_x2=$c2

  local ret index lx ly rx ly

  ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
  local lines; ble/string#split-lines lines "${_ble_edit_str:bol1:eol2-bol1}"

  sub_ranges=()
  local min_sfill=0
  local line bol=$bol1 eol bolx boly
  local c1l c1r c2l c2r
  for line in "${lines[@]}"; do
    ((eol=bol+${#line}))

    if [[ :$opts: == *:first_line:* ]] && ((${#sub_ranges[@]})); then
      ble/array#push sub_ranges :::::
    elif [[ :$opts: == *:skip_middle:* ]] && ((0<${#sub_ranges[@]}&&${#sub_ranges[@]}<${#lines[@]}-1)); then
      ble/array#push sub_ranges :::::
    else
      ble/textmap#getxy.out --prefix=bol "$bol"
      ble/textmap#hit out "$x1" "$((boly+y1))" "$bol" "$eol"
      local smin=$index x1l=$lx y1l=$ly x1r=$rx y1r=$ry
      if ble/keymap:vi/xmap/has-eol-extension; then
        local eolx eoly; ble/textmap#getxy.out --prefix=eol "$eol"
        local smax=$eol x2l=$eolx y2l=$eoly x2r=$eolx y2r=$eoly
      else
        ble/textmap#hit out "$x2" "$((boly+y2))" "$bol" "$eol"
        local smax=$index x2l=$lx y2l=$ly x2r=$rx y2r=$ry
      fi

      local sfill=0 slpad=0 srpad=0
      local stext=${_ble_edit_str:smin:smax-smin}
      if ((smin<smax)); then
        # 1. 左の境界 c1 を大きな文字が跨いでいるときは空白に変換する。
        ((c1l=(y1l-boly)*cols+x1l))
        if ((c1l<c1)); then
          ((slpad=c1-c1l))

          # assert: smin < smax <= eol なので行末ではない
          ble/util/assert '! ble-edit/content/eolp "$smin"'

          ((c1r=(y1r-boly)*cols+x1r))
          ble/util/assert '((c1r>c1))' || ((c1r=c1))
          ble/string#repeat ' ' "$((c1r-c1))"
          stext=$ret${stext:1}
        fi

        # 2. 右の境界 c2 を大きな文字が跨いでいるときは空白に変換する
        ((c2l=(y2l-boly)*cols+x2l))
        if ((c2l<c2)); then
          if ((smax==eol)); then
            ((sfill=c2-c2l))
          else
            ble/string#repeat ' ' "$((c2-c2l))"
            stext=$stext$ret
            ((smax++))

            ((c2r=(y2r-boly)*cols+x2r))
            ble/util/assert '((c2r>c2))' || ((c2r=c2))
            ((srpad=c2r-c2))
          fi
        elif ((c2l>c2)); then
          # ここに来るのは ble/keymap:vi/xmap/has-eol-extension のときのみの筈
          ((sfill=c2-c2l,
            sfill<min_sfill&&(min_sfill=sfill)))
        fi
      else
        if ((smin==eol)); then
          # 行末
          ((sfill=c2-c1))
        elif ((c2>c1)); then
          # 範囲の両端が単一の文字の左端または内部にある
          ble/string#repeat ' ' "$((c2-c1))"
          stext=$ret${stext:1}
          ((smax++))

          ((c1l=(y1l-boly)*cols+x1l,slpad=c1-c1l))
          ((c1r=(y1r-boly)*cols+x1r,srpad=c1r-c1))
        fi
      fi

      ble/array#push sub_ranges "$smin:$smax:$slpad:$srpad:$sfill:$stext"
    fi

    ((bol=eol+1))
  done

  if ((min_sfill<0)); then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      local sub=${sub_ranges[isub]}
      local sub45=${sub#*:*:*:*:}
      local sfill=${sub45%%:*}
      sub_ranges[isub]=${sub::${#sub}-${#sub45}}$((sfill-min_sfill))${sub45:${#sfill}}
    done
  fi
}
function ble/keymap:vi/extract-graphical-block {
  local opts=$3
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-graphical-rectangle "$@"
  ble/keymap:vi/extract-graphical-block-by-geometry "$p0" "$q0" "$lx:$ly" "$rx:$ry" "$opts"
}
function ble/keymap:vi/extract-logical-block-by-geometry {
  local bol1=$1 bol2=$2 x1=$3 x2=$4 opts=$5
  ((bol1<=bol2||(bol1=$2,bol2=$1)))
  sub_x1=$c1 sub_x2=$c2

  local ret min_sfill=0
  local bol=$bol1 eol smin smax slpad srpad sfill
  sub_ranges=()
  while :; do
    ble-edit/content/find-logical-eol "$bol"; eol=$ret
    slpad=0 srpad=0 sfill=0
    ((smin=bol+x1,smin>eol&&(smin=eol)))
    if ble/keymap:vi/xmap/has-eol-extension; then
      ((smax=eol,
        sfill=bol+x2-eol,
        sfill<min_sfill&&(min_sfill=sfill)))
    else
      ((smax=bol+x2,smax>eol&&(sfill=smax-eol,smax=eol)))
    fi

    local stext=${_ble_edit_str:smin:smax-smin}

    ble/array#push sub_ranges "$smin:$smax:$slpad:$srpad:$sfill:$stext"

    ((bol>=bol2)) && break
    ble-edit/content/find-logical-bol "$bol" 1; bol=$ret
  done

  if ((min_sfill<0)); then
    local isub=${#sub_ranges[@]}
    while ((isub--)); do
      local sub=${sub_ranges[isub]}
      local sub45=${sub#*:*:*:*:}
      local sfill=${sub45%%:*}
      sub_ranges[isub]=${sub::${#sub}-${#sub45}}$((sfill-min_sfill))${sub45:${#sfill}}
    done
  fi
}
function ble/keymap:vi/extract-logical-block {
  local opts=$3
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-logical-rectangle "$@"
  ble/keymap:vi/extract-logical-block-by-geometry "$p0" "$q0" "$lx" "$rx" "$opts"
}
function ble/keymap:vi/extract-block {
  if ble/edit/use-textmap; then
    ble/keymap:vi/extract-graphical-block "$@"
  else
    ble/keymap:vi/extract-logical-block "$@"
  fi
}

#--------------------------------------
# xmap/選択範囲の着色の設定

## @fn ble/highlight/layer:region/mark:vi_char/get-selection
## @fn ble/highlight/layer:region/mark:vi_line/get-selection
## @fn ble/highlight/layer:region/mark:vi_block/get-selection
##   @arr[out] selection
function ble/highlight/layer:region/mark:vi_char/get-selection {
  local rmin rmax
  if ((_ble_edit_mark<_ble_edit_ind)); then
    rmin=$_ble_edit_mark rmax=$_ble_edit_ind
  else
    rmin=$_ble_edit_ind rmax=$_ble_edit_mark
  fi
  ble-edit/content/eolp "$rmax" || ((rmax++))
  selection=("$rmin" "$rmax")
}
function ble/highlight/layer:region/mark:vi_line/get-selection {
  local rmin rmax
  if ((_ble_edit_mark<_ble_edit_ind)); then
    rmin=$_ble_edit_mark rmax=$_ble_edit_ind
  else
    rmin=$_ble_edit_ind rmax=$_ble_edit_mark
  fi
  local ret
  ble-edit/content/find-logical-bol "$rmin"; rmin=$ret
  ble-edit/content/find-logical-eol "$rmax"; rmax=$ret
  selection=("$rmin" "$rmax")
}
function ble/highlight/layer:region/mark:vi_block/get-selection {
  local sub_ranges sub_x1 sub_x2
  ble/keymap:vi/extract-block

  selection=()
  local sub
  for sub in "${sub_ranges[@]}"; do
    ble/string#split sub : "$sub"
    ((sub[0]<sub[1])) || continue
    ble/array#push selection "${sub[0]}" "${sub[1]}"
  done
}
function ble/highlight/layer:region/mark:vi_char+/get-selection {
  ble/highlight/layer:region/mark:vi_char/get-selection
}
function ble/highlight/layer:region/mark:vi_line+/get-selection {
  ble/highlight/layer:region/mark:vi_line/get-selection
}
function ble/highlight/layer:region/mark:vi_block+/get-selection {
  ble/highlight/layer:region/mark:vi_block/get-selection
}

function ble/highlight/layer:region/mark:vi_char/get-face   { [[ $_ble_edit_overwrite_mode ]] && face=region_target; }
function ble/highlight/layer:region/mark:vi_char+/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_line/get-face   { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_line+/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_block/get-face  { ble/highlight/layer:region/mark:vi_char/get-face; }
function ble/highlight/layer:region/mark:vi_block+/get-face { ble/highlight/layer:region/mark:vi_char/get-face; }


#--------------------------------------
# xmap/前回の選択サイズ

_ble_keymap_vi_xmap_prev_edit=vi_char:1:1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_prev_edit
function ble/widget/vi_xmap/.save-visual-state {
  local nline nchar mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local p0 q0 lx rx ly ry
    if ble/edit/use-textmap; then
      local cols=$_ble_textmap_cols
      ble/keymap:vi/get-graphical-rectangle
      ((lx+=ly*cols,rx+=ry*cols))
    else
      ble/keymap:vi/get-logical-rectangle
    fi

    nchar=$((rx-lx))

    local ret
    ((p0<=q0)) || local p0=$q0 q0=$p0
    ble/string#count-char "${_ble_edit_str:p0:q0-p0}" $'\n'
    nline=$((ret+1))

  else
    local ret
    local p=$_ble_edit_mark q=$_ble_edit_ind
    ((p<=q)) || local p=$q q=$p
    ble/string#count-char "${_ble_edit_str:p:q-p}" $'\n'
    nline=$((ret+1))

    local base
    if ((nline==1)) && [[ $mark_type != vi_line ]]; then
      base=$p
    else
      ble-edit/content/find-logical-bol "$q"; base=$ret
    fi

    if ble/edit/use-textmap; then
      local cols=$_ble_textmap_cols
      local bx by x y
      ble/textmap#getxy.cur --prefix=b "$base"
      ble/textmap#getxy.cur "$q"
      nchar=$((x-bx+(y-by)*cols+1))
    else
      nchar=$((q-base+1))
    fi
  fi

  _ble_keymap_vi_xmap_prev_edit=$_ble_edit_mark_active:$nchar:$nline
}
function ble/widget/vi_xmap/.restore-visual-state {
  local arg=$1; ((arg>0)) || arg=1
  local prev; ble/string#split prev : "$_ble_keymap_vi_xmap_prev_edit"
  _ble_edit_mark_active=${prev[0]:-vi_char}
  local nchar=${prev[1]:-1}
  local nline=${prev[2]:-1}
  ((nchar<1&&(nchar=1),nline<1&&(nline=1)))

  local is_x_relative=0
  if [[ ${_ble_edit_mark_active%+} == vi_block ]]; then
    ((is_x_relative=1,nchar*=arg,nline*=arg))
  elif [[ ${_ble_edit_mark_active%+} == vi_line ]]; then
    ((nline*=arg,is_x_relative=1,nchar=1))
  else
    ((nline==1?(is_x_relative=1,nchar*=arg):(nline*=arg)))
  fi
  ((nchar--,nline--))

  local index ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local b1=$ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$nline"; local b2=$ret
  ble-edit/content/find-logical-eol "$b2"; local e2=$ret
  if ble/keymap:vi/xmap/has-eol-extension; then
    index=$e2
  elif ble/edit/use-textmap; then
    local cols=$_ble_textmap_cols
    local b1x b1y b2x b2y x y
    ble/textmap#getxy.out --prefix=b1 "$b1"
    ble/textmap#getxy.out --prefix=b2 "$b2"
    if ((is_x_relative)); then
      ble/textmap#getxy.out "$_ble_edit_ind"
      local c=$((x+(y-b1y)*cols+nchar))
    else
      local c=$nchar
    fi
    ((y=c/cols,x=c%cols))

    local lx ly rx ry
    ble/textmap#hit out "$x" "$((b2y+y))" "$b2" "$e2"
  else
    local c=$((is_x_relative?_ble_edit_ind-b1+nchar:nchar))
    ((index=b2+c,index>e2&&(index=e2)))
  fi

  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_ind=$index
}

#--------------------------------------
# xmap/前回の選択範囲

# mark `< `>
_ble_keymap_vi_xmap_prev_visual=
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_prev_visual
function ble/keymap:vi/xmap/set-previous-visual-area {
  local beg end
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block
    local nrange=${#sub_ranges[*]}
    ((nrange)) || return 1
    local beg=${sub_ranges[0]%%:*}
    local sub2_slice1=${sub_ranges[nrange-1]#*:}
    local end=${sub2_slice1%%:*}
    ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; beg=$ret
      ble-edit/content/find-logical-eol "$end"; end=$ret
      ble-edit/content/bolp "$end" || ((end--))
    fi
  fi
  _ble_keymap_vi_xmap_prev_visual=$_ble_edit_mark_active
  ble/keymap:vi/mark/set-local-mark 60 "$beg" # `<
  ble/keymap:vi/mark/set-local-mark 62 "$end" # `>
}
# nmap/xmap gv
function ble/widget/vi-command/previous-visual-area {
  local mark=$_ble_keymap_vi_xmap_prev_visual
  local ret beg= end=
  ble/keymap:vi/mark/get-local-mark 60 && beg=$ret # `<
  ble/keymap:vi/mark/get-local-mark 62 && end=$ret # `>
  [[ $beg && $end ]] || return 1

  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ble/keymap:vi/clear-arg
    ble/keymap:vi/xmap/set-previous-visual-area
    _ble_edit_ind=$end
    _ble_edit_mark=$beg
    _ble_edit_mark_active=$mark
    ble/keymap:vi/update-mode-indicator
  else
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/visual-mode.impl vi_xmap "$mark"
    _ble_edit_ind=$end
    _ble_edit_mark=$beg
  fi
  return 0
}

#--------------------------------------
# xmap/モード遷移

function ble/widget/vi-command/visual-mode.impl {
  local keymap=$1 visual_type=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  _ble_edit_overwrite_mode=
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=$visual_type
  _ble_keymap_vi_xmap_insert_data= # ※矩形挿入の途中で更に xmap に入ったときはキャンセル

  ((ARG)) && ble/widget/vi_xmap/.restore-visual-state "$ARG"

  ble/decode/keymap/push "$keymap"
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_nmap/charwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_char
}
function ble/widget/vi_nmap/linewise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_line
}
function ble/widget/vi_nmap/blockwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl vi_xmap vi_block
}
function ble/widget/vi_nmap/charwise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_char
}
function ble/widget/vi_nmap/linewise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_line
}
function ble/widget/vi_nmap/blockwise-select-mode {
  ble/widget/vi-command/visual-mode.impl vi_smap vi_block
}

function ble/widget/vi_xmap/exit {
  # Note: xmap operator:c
  #   -> vi_xmap/block-insert-mode.impl
  #   → vi_xmap/cancel 経由で呼び出されるとき、
  #   既に vi_nmap に戻っていることがあるので、vi_xmap, vi_smap のときだけ処理する。
  if [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    ble/keymap:vi/xmap/set-previous-visual-area
    _ble_edit_mark_active=
    ble/decode/keymap/pop
    ble/keymap:vi/update-mode-indicator
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/vi_xmap/cancel {
  # もし single-command-mode にいたとしても消去して normal へ移動する

  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/nonbol-eolp && ((_ble_edit_ind--))
  ble/widget/vi_xmap/exit
}
function ble/widget/vi_xmap/switch-visual-mode.impl {
  local visual_type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  fi

  if [[ ${_ble_edit_mark_active%+} == "$visual_type" ]]; then
    ble/widget/vi_xmap/cancel
  else
    ble/keymap:vi/xmap/switch-type "$visual_type"
    ble/keymap:vi/update-mode-indicator
    return 0
  fi

}
# xmap v
function ble/widget/vi_xmap/switch-to-charwise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_char
}
# xmap V
function ble/widget/vi_xmap/switch-to-linewise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_line
}
# xmap <C-v>
function ble/widget/vi_xmap/switch-to-blockwise {
  ble/widget/vi_xmap/switch-visual-mode.impl vi_block
}
# xmap <C-g>
function ble/widget/vi_xmap/switch-to-select {
  if [[ $_ble_decode_keymap == vi_xmap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_smap
    ble/keymap:vi/update-mode-indicator
  fi
}
# smap <C-g>
function ble/widget/vi_xmap/switch-to-visual {
  if [[ $_ble_decode_keymap == vi_smap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_xmap
    ble/keymap:vi/update-mode-indicator
  fi
}
# smap <C-v>
function ble/widget/vi_xmap/switch-to-visual-blockwise {
  if [[ $_ble_decode_keymap == vi_smap ]]; then
    ble/decode/keymap/pop
    ble/decode/keymap/push vi_xmap
  fi
  if [[ ${_ble_edit_mark_active%+} != vi_block ]]; then
    ble/widget/vi_xmap/switch-to-blockwise
  else
    xble/keymap:vi/update-mode-indicator
  fi
}

## @bleopt keymap_vi_keymodel
##   選択モードにおける移動コマンドの振る舞いを制御します。
bleopt/declare -v keymap_vi_keymodel ''
function ble/widget/vi_smap/@nomarked {
  [[ ,$bleopt_keymap_vi_keymodel, == *,stopsel,* ]] &&
    ble/widget/vi_xmap/exit
  ble/widget/"$@"
}

#--------------------------------------
# xmap/各種コマンド

function ble/widget/vi_smap/self-insert {
  # Note: repeat (nmap .) についてはこの実装で良い。
  #   KEYS=(...) vi_smap/self-insert として記録されるので。
  ble/widget/vi-command/operator c
  ble/widget/self-insert
}

# xmap o
function ble/widget/vi_xmap/exchange-points {
  ble/keymap:vi/xmap/remove-eol-extension
  ble/widget/exchange-point-and-mark
  return 0
}
# xmap O
function ble/widget/vi_xmap/exchange-boundaries {
  if [[ ${_ble_edit_mark_active%+} == vi_block ]]; then
    ble/keymap:vi/xmap/remove-eol-extension

    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' skip_middle
    local nline=${#sub_ranges[@]}
    ble/util/assert '((nline))'

    local data1; ble/string#split data1 : "${sub_ranges[0]}"
    local lpos1=${data1[0]} rpos1=$((data1[4]?data1[1]:data1[1]-1))
    if ((nline==1)); then
      local lpos2=$lpos1 rpos2=$rpos1
    else
      local data2; ble/string#split data2 : "${sub_ranges[nline-1]}"
      local lpos2=${data2[0]} rpos2=$((data2[4]?data2[1]:data2[1]-1))
    fi

    # lpos2:rpos2 が _ble_edit_ind に対応していないとき swap する
    if ! ((lpos2<=_ble_edit_ind&&_ble_edit_ind<=rpos2)); then
      local lpos1=$lpos2 lpos2=$lpos1
      local rpos1=$rpos2 rpos2=$rpos1
    fi

    _ble_edit_mark=$((_ble_edit_mark==lpos1?rpos1:lpos1))
    _ble_edit_ind=$((_ble_edit_ind==lpos2?rpos2:lpos2))
    return 0
  else
    ble/widget/vi_xmap/exchange-points
  fi
}

# xmap r{char}
function ble/widget/vi_xmap/visual-replace-char.hook {
  local key=$1
  _ble_edit_overwrite_mode=
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  elif ((key==(_ble_decode_Ctrl|91))); then # C-[ -> cancel
    return 27
  elif ! ble/keymap:vi/k2c "$key"; then
    ble/widget/.bell
    return 1
  fi
  local c=$ret
  ble/util/c2s "$c"; local s=$ret

  local old_mark_active=$_ble_edit_mark_active # save
  local mark_type=${_ble_edit_mark_active%+}
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here
  if [[ $mark_type == vi_block ]]; then
    ble/util/c2w "$c"; local w=$ret
    ((w<=0)) && w=1

    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$old_mark_active ble/keymap:vi/extract-block
    local n=${#sub_ranges[@]}
    if ((n==0)); then
      ble/widget/.bell
      return 1
    fi

    # create ins
    local width=$((sub_x2-sub_x1))
    local count=$((width/w))
    ble/string#repeat "$s" "$count"; local ins=$ret
    local pad=$((width-count*w))
    if ((pad)); then
      ble/string#repeat ' ' "$pad"; ins=$ins$ret
    fi

    local i=$n sub smin=0
    ble/keymap:vi/mark/start-edit-area
    while ((i--)); do
      ble/string#split sub : "${sub_ranges[i]}"
      local smin=${sub[0]} smax=${sub[1]}
      local slpad=${sub[2]} srpad=${sub[3]} sfill=${sub[4]}

      local ins1=$ins
      ((sfill)) && ins1=${ins1::(width-sfill)/w}
      ((slpad)) && { ble/string#repeat ' ' "$slpad"; ins1=$ret$ins1; }
      ((srpad)) && { ble/string#repeat ' ' "$srpad"; ins1=$ins1$ret; }
      ble/widget/.replace-range "$smin" "$smax" "$ins1"
    done
    local beg=$smin
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    _ble_edit_ind=$beg
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/repeat/record
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      ble-edit/content/find-logical-bol "$beg"; local beg=$ret
      ble-edit/content/find-logical-eol "$end"; local end=$ret
    else
      ble-edit/content/eolp "$end" || ((end++))
    fi

    local ins=${_ble_edit_str:beg:end-beg}
    ins=${ins//[!$'\n']/"$s"}
    ble/widget/.replace-range "$beg" "$end" "$ins"
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    _ble_edit_ind=$beg
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
  fi
  return 0
}
function ble/widget/vi_xmap/visual-replace-char {
  _ble_edit_overwrite_mode=R
  ble/keymap:vi/async-read-char ble/widget/vi_xmap/visual-replace-char.hook
}

function ble/widget/vi_xmap/linewise-operator.impl {
  local op=$1 opts=$2
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if [[ $FLAG ]]; then
    ble/widget/.bell 'wrong keymap: xmap ではオペレータは設定されないはず'
    return 1
  fi

  local mark_type=${_ble_edit_mark_active%+}
  local beg=$_ble_edit_mark end=$_ble_edit_ind
  ((beg<=end)) || local beg=$end end=$beg

  local call_operator=
  if [[ :$opts: != *:force_line:* && $mark_type == vi_block ]]; then
    call_operator=ble/keymap:vi/call-operator-blockwise
    _ble_edit_mark_active=vi_block
    [[ :$opts: == *:extend:* ]] && _ble_edit_mark_active=vi_block+
  else
    call_operator=ble/keymap:vi/call-operator-linewise
    _ble_edit_mark_active=vi_line
  fi

  local ble_keymap_vi_mark_active=$_ble_edit_mark_active
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit
  "$call_operator" "$op" "$beg" "$end" "$ARG" "$REG"; local ext=$?
  ((ext==147)) && return 147
  ((ext)) && ble/widget/.bell
  ble/keymap:vi/adjust-command-mode
  return "$ext"
}

# xmap C
function ble/widget/vi_xmap/replace-block-lines { ble/widget/vi_xmap/linewise-operator.impl c extend; }
# xmap D X
function ble/widget/vi_xmap/delete-block-lines { ble/widget/vi_xmap/linewise-operator.impl d extend; }
# xmap R S
function ble/widget/vi_xmap/delete-lines { ble/widget/vi_xmap/linewise-operator.impl d force_line; }
# xmap Y
function ble/widget/vi_xmap/copy-block-or-lines { ble/widget/vi_xmap/linewise-operator.impl y; }

function ble/widget/vi_xmap/connect-line.impl {
  local name=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # ignored

  local beg=$_ble_edit_mark end=$_ble_edit_ind
  ((beg<=end)) || local beg=$end end=$beg
  local ret; ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nline=$((ret+1))

  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here

  _ble_edit_ind=$beg
  _ble_edit_arg=$nline
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
  _ble_keymap_vi_reg=
  "ble/widget/$name"
}
# xmap J
function ble/widget/vi_xmap/connect-line-with-space {
  ble/widget/vi_xmap/connect-line.impl vi_nmap/connect-line-with-space
}
# xmap gJ
function ble/widget/vi_xmap/connect-line {
  ble/widget/vi_xmap/connect-line.impl vi_nmap/connect-line
}

#--------------------------------------
# xmap/矩形挿入モード

## @var _ble_keymap_vi_xmap_insert_data
##   矩形挿入モードの情報を保持します。
##   iline:x1:width:content の形式です。
##
##   iline
##     編集を行う行の番号を保持します。
##   x1
##     挿入開始位置を表示列で保持します。
##   width
##     編集行の元々の幅を保持します。
##   nline
##     行数を保持します。
##
_ble_keymap_vi_xmap_insert_data=
_ble_keymap_vi_xmap_insert_dbeg=-1
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_keymap_vi_xmap_insert_data \
               _ble_keymap_vi_xmap_insert_dbeg
function ble/keymap:vi/xmap/update-dirty-range {
  [[ $_ble_keymap_vi_insert_leave == ble/widget/vi_xmap/block-insert-mode.onleave ]] &&
    ((_ble_keymap_vi_xmap_insert_dbeg<0||beg<_ble_keymap_vi_xmap_insert_dbeg)) &&
    _ble_keymap_vi_xmap_insert_dbeg=$beg
}

## @fn ble/widget/vi_xmap/block-insert-mode.impl
##   @var[in] sub_ranges sub_x1 sub_x2
function ble/widget/vi_xmap/block-insert-mode.impl {
  local type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local nline=${#sub_ranges[@]}
  ble/util/assert '((nline))'

  local index ins_x
  if [[ $type == append ]]; then
    local sub=${sub_ranges[0]#*:}
    local smax=${sub%%:*}
    index=$smax
    if ble/keymap:vi/xmap/has-eol-extension; then
      ins_x='$'
    else
      ins_x=$sub_x2
    fi
  else
    local sub=${sub_ranges[0]}
    local smin=${sub%%:*}
    index=$smin
    ins_x=$sub_x1
  fi

  ble/widget/vi_xmap/cancel
  _ble_edit_ind=$index
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/mark/set-local-mark 1 "$_ble_edit_ind"
  _ble_keymap_vi_xmap_insert_dbeg=-1

  local ret display_width
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/edit/use-textmap; then
    local bx by ex ey
    ble/textmap#getxy.out --prefix=b "$bol"
    ble/textmap#getxy.out --prefix=e "$eol"
    ((display_width=ex+_ble_textmap_cols*(ey-by)))
  else
    ((display_width=eol-bol))
  fi
  _ble_keymap_vi_xmap_insert_data=$iline:$ins_x:$display_width:$nline
  _ble_keymap_vi_insert_leave=ble/widget/vi_xmap/block-insert-mode.onleave
  return 0
}
function ble/widget/vi_xmap/block-insert-mode.onleave {
  local data=$_ble_keymap_vi_xmap_insert_data
  [[ $data ]] || continue
  _ble_keymap_vi_xmap_insert_data=

  ble/string#split data : "$data"

  # カーソル行が記録行と同じか
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble/string#count-char "${_ble_edit_str::bol}" $'\n'; ((ret==data[0])) || return  1 # 行番号
  ble/keymap:vi/mark/get-local-mark 1 || return 1; local mark=$ret # `[
  ble-edit/content/find-logical-bol "$mark"; ((bol==ret)) || return 1 # 記録行 `[ と同じか

  local has_textmap=
  if ble/edit/use-textmap; then
    local cols=$_ble_textmap_cols
    has_textmap=1
  fi

  # 表示幅の変量
  local new_width delta
  ble-edit/content/find-logical-eol; local eol=$ret
  if [[ $has_textmap ]]; then
    local bx by ex ey
    ble/textmap#getxy.out --prefix=b "$bol"
    ble/textmap#getxy.out --prefix=e "$eol"
    ((new_width=ex+cols*(ey-by)))
  else
    ((new_width=eol-bol))
  fi
  ((delta=new_width-data[2]))
  ((delta>0)) || return 1 # 縮んだ場合は処理しない

  # 切り出し列の決定
  local x1=${data[1]}
  [[ $x1 == '$' ]] && ((x1=data[2]))
  ((x1>new_width&&(x1=new_width)))
  if ((bol<=_ble_keymap_vi_xmap_insert_dbeg&&_ble_keymap_vi_xmap_insert_dbeg<=eol)); then
    local px py
    if [[ $has_textmap ]]; then
      ble/textmap#getxy.out --prefix=p "$_ble_keymap_vi_xmap_insert_dbeg"
      ((px+=cols*(py-by)))
    else
      ((px=_ble_keymap_vi_xmap_insert_dbeg-bol))
    fi
    ((px>x1&&(x1=px)))
  fi
  local x2=$((x1+delta))

  # 切り出し
  local ins= p1 p2
  if [[ $has_textmap ]]; then
    local index lx ly rx ry
    ble/textmap#hit out "$((x1%cols))" "$((by+x1/cols))" "$bol" "$eol"; p1=$index
    ble/textmap#hit out "$((x2%cols))" "$((by+x2/cols))" "$bol" "$eol"; p2=$index
    ((lx+=(ly-by)*cols,rx+=(ry-by)*cols,lx!=rx&&p2++))
  else
    ((p1=bol+x1,p2=bol+x2))
  fi
  ins=${_ble_edit_str:p1:p2-p1}

  # 挿入の決定
  local -a ins_beg=() ins_text=()
  local iline=1 nline=${data[3]} strlen=${#_ble_edit_str}
  for ((iline=1;iline<nline;iline++)); do
    local index= lpad=
    if ((eol<strlen)); then
      bol=$((eol+1))
      ble-edit/content/find-logical-eol "$bol"; eol=$ret
    else
      bol=$eol lpad=$'\n'
    fi

    if [[ ${data[1]} == '$' ]]; then
      index=$eol
    elif [[ $has_textmap ]]; then
      ble/textmap#getxy.out --prefix=b "$bol"
      ble/textmap#hit out "$((x1%cols))" "$((by+x1/cols))" "$bol" "$eol" # -> index

      local nfill
      if ((index==eol&&(nfill=x1-lx+(ly-by)*cols)>0)); then
        ble/string#repeat ' ' "$nfill"; lpad=$lpad$ret
      fi
    else
      index=$((bol+x1))
      if ((index>eol)); then
        ble/string#repeat ' ' "$((index-eol))"; lpad=$lpad$ret
        ((index=eol))
      fi
    fi

    ble/array#push ins_beg "$index"
    ble/array#push ins_text "$lpad$ins"
  done

  # 挿入実行
  local i=${#ins_beg[@]}
  ble/keymap:vi/mark/start-edit-area
  ble/keymap:vi/mark/commit-edit-area "$p1" "$p2"
  while ((i--)); do
    local index=${ins_beg[i]} text=${ins_text[i]}
    ble/widget/.replace-range "$index" "$index" "$text"
  done
  ble/keymap:vi/mark/end-edit-area
  # Note: この編集は record-insert 経由で記録されるので
  # ここで明示的に ble/keymap:vi/repeat/record を呼び出す必要はない。

  # 領域の最初に
  local index
  if ble/keymap:vi/mark/get-local-mark 60 && index=$ret; then
    ble/widget/vi-command/goto-mark.impl "$index"
  else
    ble-edit/content/find-logical-bol; index=$ret
  fi

  # ノーマルモードに戻る時に一文字カーソルが戻るので一文字進めておく。
  ble-edit/content/eolp || ((index++))
  _ble_edit_ind=$index
  return 0
}
# xmap I
function ble/widget/vi_xmap/insert-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' first_line
    ble/widget/vi_xmap/block-insert-mode.impl insert
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; beg=$ret
    fi

    ble/widget/vi_xmap/cancel
    _ble_edit_ind=$beg
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}
# xmap A
function ble/widget/vi_xmap/append-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block '' '' first_line
    ble/widget/vi_xmap/block-insert-mode.impl append
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      # 行指向のときは最終行の先頭か _ble_edit_ind の内、
      # 後にある文字の後に移動する。
      if ((_ble_edit_mark>_ble_edit_ind)); then
        local ret
        ble-edit/content/find-logical-bol "$end"; end=$ret
      fi
    fi
    ble-edit/content/eolp "$end" || ((end++))

    ble/widget/vi_xmap/cancel
    _ble_edit_ind=$end
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}

#--------------------------------------
# xmap/貼り付け

# xmap: p, P
function ble/widget/vi_xmap/paste.impl {
  local opts=$1
  [[ :$opts: != *:after:* ]]; local is_after=$?

  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $REG ]] && ble/keymap:vi/register#load "$REG"

  local mark_type=${_ble_edit_mark_active%+}
  local kill_ring=$_ble_edit_kill_ring
  local kill_type=$_ble_edit_kill_type

  local adjustment=
  if [[ $mark_type == vi_block ]]; then
    if [[ $kill_type == L ]]; then
      # P: V → C-v のときは C-v の最終行直後に挿入
      if ((is_after)); then
        local ret; ble/keymap:vi/get-rectangle-height; local nline=$ret
        adjustment=lastline:$nline
      fi
    elif [[ $kill_type == B:* ]]; then
      # C-v → C-v
      is_after=0
    else
      # 単純 v → C-v はブロック挿入に切り替え
      is_after=0
      if [[ $kill_ring != *$'\n'* ]]; then
        ((${#kill_ring}>=2)) && adjustment=index:$((${#kill_ring}*ARG-1))
        local ret; ble/keymap:vi/get-rectangle-height; local nline=$ret
        ble/string#repeat "$kill_ring"$'\n' "$nline"; kill_ring=${ret%$'\n'}
        ble/string#repeat '0 ' "$nline"; kill_type=B:${ret% }
      fi
    fi
  elif [[ $mark_type == vi_line ]]; then
    if [[ $kill_type == L ]]; then
      # V → V のとき
      is_after=0
    elif [[ $kill_type == B:* ]]; then
      # C-v → V のとき、行貼り付け。
      # kill_type=B:* のとき kill_ring の末端の改行は空行を意味するので、
      # 空行が消えないように $'\n' を付加する必要がある。
      is_after=0 kill_type=L kill_ring=$kill_ring$'\n'
    else
      # v → V のとき、行貼り付けになる。
      is_after=0 kill_type=L
      [[ $kill_ring == *$'\n' ]] && kill_ring=$kill_ring$'\n'
    fi
  else
    # v, V, C-v → v のとき
    is_after=0
    [[ $kill_type == L ]] && adjustment=newline
  fi

  ble/keymap:vi/mark/start-edit-area
  local _ble_keymap_vi_mark_suppress_edit=1
  {
    ble/widget/vi-command/operator d; local ext=$? # _ble_edit_kill_{ring,type} is set here
    if [[ $adjustment == newline ]]; then
      local -a KEYS=(10)
      ble/widget/self-insert
    elif [[ $adjustment == lastline:* ]]; then
      local ret
      ble-edit/content/find-logical-bol "$_ble_edit_ind" "$((${adjustment#*:}-1))"
      _ble_edit_ind=$ret
    fi
    local _ble_edit_kill_ring=$kill_ring
    local _ble_edit_kill_type=$kill_type
    ble/widget/vi_nmap/paste.impl "$ARG" '' "$is_after"
    if [[ $adjustment == index:* ]]; then
      local index=$((_ble_edit_ind+${adjustment#*:}))
      ((index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
      ble/keymap:vi/needs-eol-fix "$index" && ((index--))
      _ble_edit_ind=$index
    fi
  }
  ble/util/unlocal _ble_keymap_vi_mark_suppress_edit
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record
  return "$ext"
}
function ble/widget/vi_xmap/paste-after {
  ble/widget/vi_xmap/paste.impl after
}
function ble/widget/vi_xmap/paste-before {
  ble/widget/vi_xmap/paste.impl before
}

#--------------------------------------
# xmap <C-a>, <C-x>, g<C-a>, g<C-x>

## @fn ble/widget/vi_xmap/increment.impl opts
##
##   @param[in] opts
##     以下の項目をコロンで区切って指定したものです。
##
##     - increase [既定]
##       数字を増加させます。
##     - decrease
##       数字を減少させるます。
##     - progressive
##       k 個目の数字について増加・減少量を k 倍します。
##
function ble/widget/vi_xmap/increment.impl {
  local opts=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  fi

  local delta=$ARG
  [[ :$opts: == *:decrease:* ]] && ((delta=-delta))
  local progress=0
  [[ :$opts: == *:progressive:* ]] && progress=$delta

  local old_mark_active=$_ble_edit_mark_active # save
  local mark_type=${_ble_edit_mark_active%+}
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit # Note: _ble_edit_mark_active will be cleared here
  if [[ $mark_type == vi_block ]]; then
    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$old_mark_active ble/keymap:vi/extract-block
    if ((${#sub_ranges[@]}==0)); then
      ble/widget/.bell
      return 1
    fi
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == vi_line ]]; then
      local ret
      ble-edit/content/find-logical-bol "$beg"; local beg=$ret
      ble-edit/content/find-logical-eol "$end"; local end=$ret
    else
      ble-edit/content/eolp "$end" || ((end++))
    fi

    local -a lines
    ble/string#split-lines lines "${_ble_edit_str:beg:end-beg}"

    # sub_ranges 生成
    local line index=$beg
    local -a sub_ranges
    for line in "${lines[@]}"; do
      [[ $line ]] && ble/array#push sub_ranges "$index:::::$line"
      ((index+=${#line}+1))
    done

    ((${#sub_ranges[@]})) || return 0
  fi

  local sub rex_number='^([^0-9]*)([0-9]+)' shift=0 dmin=-1 dmax=-1
  for sub in "${sub_ranges[@]}"; do
    local stext=${sub#*:*:*:*:*:}
    [[ $stext =~ $rex_number ]] || continue

    # 元々の数
    local rematch1=${BASH_REMATCH[1]}
    local rematch2=${BASH_REMATCH[2]}
    local offset=${#rematch1} length=${#rematch2}
    local number=$((10#0$rematch2))
    [[ $rematch1 == *- ]] && ((number=-number,offset--,length++))

    # 新しい数
    ((number+=delta,delta+=progress))
    if [[ $rematch2 == 0?* ]]; then
      # Zero padding
      local wsign=$((number<0?1:0))
      local zpad=$((wsign+${#rematch2}-${#number}))
      if ((zpad>0)); then
        local ret; ble/string#repeat 0 "$zpad"
        number=${number::wsign}$ret${number:wsign}
      fi
    fi

    local smin=${sub%%:*}
    local beg=$((shift+smin+offset))
    local end=$((beg+length))
    ble/widget/.replace-range "$beg" "$end" "$number"
    ((shift+=${#number}-length,
      dmin<0&&(dmin=beg),
      dmax=beg+${#number}))
  done
  local beg=${sub_ranges[0]%%:*}
  ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
  _ble_edit_ind=$beg

  ((dmin>=0)) && ble/keymap:vi/mark/set-previous-edit-area "$dmin" "$dmax"
  ble/keymap:vi/repeat/record
  return 0
}
# xmap <C-a>
function ble/widget/vi_xmap/increment { ble/widget/vi_xmap/increment.impl increase; }
# xmap <C-x>
function ble/widget/vi_xmap/decrement { ble/widget/vi_xmap/increment.impl decrease; }
# xmap g<C-a>
function ble/widget/vi_xmap/progressive-increment { ble/widget/vi_xmap/increment.impl progressive:increase; }
# xmap g<C-x>
function ble/widget/vi_xmap/progressive-decrement { ble/widget/vi_xmap/increment.impl progressive:decrease; }

#--------------------------------------

function ble-decode/keymap:vi_xmap/define {
  ble/keymap:vi/set-up-command-map

  ble-bind -f __default__ vi-command/decompose-meta

  ble-bind -f 'ESC' vi_xmap/exit
  ble-bind -f 'C-[' vi_xmap/exit
  ble-bind -f 'C-c' vi_xmap/cancel

  ble-bind -f '"' vi-command/register

  ble-bind -f a vi-command/text-object-outer
  ble-bind -f i vi-command/text-object-inner

  ble-bind -f 'C-\ C-n' vi_xmap/cancel
  ble-bind -f 'C-\ C-g' vi_xmap/cancel
  ble-bind -f v      vi_xmap/switch-to-charwise
  ble-bind -f V      vi_xmap/switch-to-linewise
  ble-bind -f C-v    vi_xmap/switch-to-blockwise
  ble-bind -f C-q    vi_xmap/switch-to-blockwise
  ble-bind -f 'g v'  vi-command/previous-visual-area
  ble-bind -f C-g    vi_xmap/switch-to-select

  ble-bind -f o vi_xmap/exchange-points
  ble-bind -f O vi_xmap/exchange-boundaries

  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'

  ble-bind -f 's' 'vi-command/operator c'
  ble-bind -f 'x'    'vi-command/operator d'
  ble-bind -f delete 'vi-command/operator d'

  ble-bind -f r vi_xmap/visual-replace-char

  ble-bind -f C vi_xmap/replace-block-lines
  ble-bind -f D vi_xmap/delete-block-lines
  ble-bind -f X vi_xmap/delete-block-lines
  ble-bind -f S vi_xmap/delete-lines
  ble-bind -f R vi_xmap/delete-lines
  ble-bind -f Y vi_xmap/copy-block-or-lines
  ble-bind -f J     vi_xmap/connect-line-with-space
  ble-bind -f 'g J' vi_xmap/connect-line

  ble-bind -f I vi_xmap/insert-mode
  ble-bind -f A vi_xmap/append-mode
  ble-bind -f p vi_xmap/paste-after
  ble-bind -f P vi_xmap/paste-before

  ble-bind -f 'C-a'   vi_xmap/increment
  ble-bind -f 'C-x'   vi_xmap/decrement
  ble-bind -f 'g C-a' vi_xmap/progressive-increment
  ble-bind -f 'g C-x' vi_xmap/progressive-decrement

  ble-bind -f f1 vi_xmap/command-help
  ble-bind -f K  vi_xmap/command-help
}

function ble-decode/keymap:vi_smap/define {
  ble-bind -f __default__ vi-command/decompose-meta

  ble-bind -f 'ESC' vi_xmap/exit
  ble-bind -f 'C-[' vi_xmap/exit
  ble-bind -f 'C-c' vi_xmap/cancel

  ble-bind -f 'C-\ C-n' nop
  ble-bind -f 'C-\ C-n' vi_xmap/cancel
  ble-bind -f 'C-\ C-g' vi_xmap/cancel
  ble-bind -f C-v    vi_xmap/switch-to-visual-blockwise
  ble-bind -f C-q    vi_xmap/switch-to-visual-blockwise
  ble-bind -f C-g    vi_xmap/switch-to-visual

  ble-bind -f delete 'vi-command/operator d'
  ble-bind -f 'C-?'  'vi-command/operator d'
  ble-bind -f 'DEL'  'vi-command/operator d'
  ble-bind -f 'C-h'  'vi-command/operator d'
  ble-bind -f 'BS'   'vi-command/operator d'

  #----------------------------------------------------------------------------

  ble-bind -f __defchar__ vi_smap/self-insert
  ble-bind -f paste_begin vi-command/bracketed-paste

  ble-bind -f 'C-a'  vi_xmap/increment
  ble-bind -f 'C-x'  vi_xmap/decrement
  ble-bind -f f1     vi_xmap/command-help
  ble-bind -c 'C-z' fg

  #----------------------------------------------------------------------------
  # motion, etc.

  ble-bind -f home      'vi_smap/@nomarked vi-command/beginning-of-line'
  ble-bind -f end       'vi_smap/@nomarked vi-command/forward-eol'
  ble-bind -f C-m       'vi_smap/@nomarked vi-command/forward-first-non-space'
  ble-bind -f RET       'vi_smap/@nomarked vi-command/forward-first-non-space'
  ble-bind -f S-home    'vi-command/beginning-of-line'
  ble-bind -f S-end     'vi-command/forward-eol'
  ble-bind -f S-C-m     'vi-command/forward-first-non-space'
  ble-bind -f S-RET     'vi-command/forward-first-non-space'

  ble-bind -f C-right   'vi_smap/@nomarked vi-command/forward-vword'
  ble-bind -f C-left    'vi_smap/@nomarked vi-command/backward-vword'
  ble-bind -f S-C-right 'vi-command/forward-vword'
  ble-bind -f S-C-left  'vi-command/backward-vword'

  ble-bind -f left      'vi_smap/@nomarked vi-command/backward-char'
  ble-bind -f right     'vi_smap/@nomarked vi-command/forward-char'
  ble-bind -f 'C-?'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'DEL'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'C-h'     'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f 'BS'      'vi_smap/@nomarked vi-command/backward-char wrap'
  ble-bind -f SP        'vi_smap/@nomarked vi-command/forward-char wrap'
  ble-bind -f S-left    'vi-command/backward-char'
  ble-bind -f S-right   'vi-command/forward-char'
  ble-bind -f 'S-C-?'   'vi-command/backward-char wrap'
  ble-bind -f 'S-DEL'   'vi-command/backward-char wrap'
  ble-bind -f 'S-C-h'   'vi-command/backward-char wrap'
  ble-bind -f 'S-BS'    'vi-command/backward-char wrap'
  ble-bind -f S-SP      'vi-command/forward-char wrap'

  ble-bind -f down      'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f C-n       'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f C-j       'vi_smap/@nomarked vi-command/forward-line'
  ble-bind -f up        'vi_smap/@nomarked vi-command/backward-line'
  ble-bind -f C-p       'vi_smap/@nomarked vi-command/backward-line'
  ble-bind -f C-home    'vi_smap/@nomarked vi-command/first-nol'
  ble-bind -f C-end     'vi_smap/@nomarked vi-command/last-eol'
  ble-bind -f S-down    'vi-command/forward-line'
  ble-bind -f S-C-n     'vi-command/forward-line'
  ble-bind -f S-C-j     'vi-command/forward-line'
  ble-bind -f S-up      'vi-command/backward-line'
  ble-bind -f S-C-p     'vi-command/backward-line'
  ble-bind -f S-C-home  'vi-command/first-nol'
  ble-bind -f S-C-end   'vi-command/last-eol'
}

#------------------------------------------------------------------------------
# vi_imap

function ble/widget/vi_imap/__attach__ {
  ble/keymap:vi/update-mode-indicator
  return 0
}
function ble/widget/vi_imap/__detach__ {
  ble/edit/info/default clear
  ble/keymap:vi/clear-arg
  ble/keymap:vi/search/clear-matched
  return 0
}
function ble/widget/vi_imap/accept-single-line-or {
  if ble-edit/is-single-complete-line; then
    ble/keymap:vi/imap-repeat/reset
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/keymap:vi/imap-repeat/reset
    if ((_ble_edit_ind!=_ble_edit_mark)); then
      ble/keymap:vi/undo/add more
      ble/widget/delete-region
      ble/keymap:vi/undo/add more
    fi
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/overwrite-mode {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=${_ble_keymap_vi_insert_overwrite:-R}
  fi
  ble/keymap:vi/update-mode-indicator
  return 0
}

# imap C-w
function ble/widget/vi_imap/delete-backward-word {
  local space=$' \t' nl=$'\n'
  local rex="($_ble_keymap_vi_REX_WORD)[$space]*\$|[$space]+\$|$nl\$"
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local index=$((_ble_edit_ind-${#BASH_REMATCH}))
    if ((index!=_ble_edit_ind)); then
      ble/keymap:vi/undo/add more
      ble/widget/.delete-range "$index" "$_ble_edit_ind"
      ble/keymap:vi/undo/add more
    fi
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

# imap C-q, C-v
function ble/widget/vi_imap/quoted-insert-char {
  ble/keymap:vi/imap-repeat/pop
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/vi_imap/quoted-insert-char.hook
  return 147
}
function ble/widget/vi_imap/quoted-insert-char.hook {
  ble/keymap:vi/imap/invoke-widget ble/widget/self-insert "$1"
}
function ble/widget/vi_imap/quoted-insert {
  ble/keymap:vi/imap-repeat/pop
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/vi_imap/quoted-insert.hook
  return 147
}
function ble/widget/vi_imap/quoted-insert.hook {
  ble/keymap:vi/imap/invoke-widget ble/widget/quoted-insert.hook "$1"
}

# bracketed paste mode

function ble/widget/vi_imap/bracketed-paste {
  ble/keymap:vi/imap-repeat/pop
  ble/widget/bracketed-paste
  _ble_edit_bracketed_paste_proc=ble/widget/vi_imap/bracketed-paste.proc
  return 147
}
function ble/widget/vi_imap/bracketed-paste.proc {
  local WIDGET=ble/widget/batch-insert
  local -a KEYS; KEYS=("$@")
  ble/keymap:vi/imap-repeat/push
  builtin eval -- "$WIDGET"
}

_ble_keymap_vi_brackated_paste_mark_active=
function ble/widget/vi-command/bracketed-paste {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # discard args
  _ble_keymap_vi_brackated_paste_mark_active=$_ble_edit_mark_active
  _ble_edit_mark_active=
  ble/widget/bracketed-paste
  _ble_edit_bracketed_paste_proc=ble/widget/vi-command/bracketed-paste.proc
  return 147
}
function ble/widget/vi-command/bracketed-paste.proc {
  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    local isbol index=$_ble_edit_ind
    ble-edit/content/bolp && isbol=1
    ble/decode/widget/call-interactively 'ble/widget/vi_nmap/append-mode' 97
    [[ $isbol ]] && ((_ble_edit_ind=index)) # 行頭にいたときは戻る

    ble/widget/vi_imap/bracketed-paste.proc "$@"
    ble/keymap:vi/imap/invoke-widget \
      ble/widget/vi_imap/normal-mode "$((_ble_decode_Ctrl|0x5b))"
  elif [[ $_ble_decode_keymap == vi_[xs]map ]]; then
    local _ble_edit_mark_active=$_ble_keymap_vi_brackated_paste_mark_active
    ble/decode/widget/call-interactively 'ble/widget/vi-command/operator c' 99 || return 1
    ble/widget/vi_imap/bracketed-paste.proc "$@"
    ble/keymap:vi/imap/invoke-widget \
      ble/widget/vi_imap/normal-mode "$((_ble_decode_Ctrl|0x5b))"
  elif [[ $_ble_decode_keymap == vi_omap ]]; then
    ble/widget/vi_omap/cancel
    ble/widget/.bell
    return 1
  else # vi_omap
    ble/widget/.bell
    return 1
  fi
}

#------------------------------------------------------------------------------
# imap: C-k (digraph)

function ble/widget/vi_imap/insert-digraph.hook {
  local -a KEYS; KEYS=("$1")
  ble/widget/self-insert
}

function ble/widget/vi_imap/insert-digraph {
  ble/decode/keymap/push vi_digraph
  _ble_keymap_vi_digraph__hook=ble/widget/vi_imap/insert-digraph.hook
  return 0
}

# imap: CR, LF (newline)
function ble/widget/vi_imap/newline {
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  ble/widget/default/newline
  ((bol<nol)) && ble/widget/.insert-string "${_ble_edit_str:bol:nol-bol}"
  return 0
}

# imap: C-h, DEL
function ble/widget/vi_imap/delete-backward-indent-or {
  local rex=$'(^|\n)([ \t]+)$'
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local rematch2=${BASH_REMATCH[2]} # Note: for bash-3.1 ${#arr[n]} bug
    if [[ $rematch2 ]]; then
      ble/keymap:vi/undo/add more
      ble/widget/.delete-range "$((_ble_edit_ind-${#rematch2}))" "$_ble_edit_ind"
      ble/keymap:vi/undo/add more
    fi
    return 0
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------

function ble-decode/keymap:vi_imap/define {
  #----------------------------------------------------------------------------
  # common bindings

  local ble_bind_nometa=1
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/define

  ble-bind -f 'C-d'       'delete-region-or delete-forward-char-or-exit'

  ble-bind -f 'SP'        'magic-space'
  ble-bind -f '/'         'magic-slash'

  # ble-bind -f  'C-c'      'discard-line'
  ble-bind -f 'C-j'       'accept-line'
  ble-bind -f 'C-RET'     'accept-line'
  ble-bind -f 'C-m'       'accept-single-line-or-newline'
  ble-bind -f 'RET'       'accept-single-line-or-newline'
  # ble-bind -f  'C-o'      'accept-and-next'
  ble-bind -f 'C-x C-e'   'edit-and-execute-command'
  ble-bind -f 'C-g'       'bell'
  ble-bind -f 'C-x C-g'   'bell'

  ble-bind -f 'C-l'       'clear-screen'

  ble-bind -f 'f1'        'command-help'
  ble-bind -f 'C-x C-v'   'display-shell-version'
  ble-bind -c 'C-z'       'fg'

  # args
  local key
  for key in {,C-}{0..9}; do
    ble-bind -f "$key"    'append-arg'
  done

  #----------------------------------------------------------------------------
  # vi_imap modifications

  ble-bind -f insert      'vi_imap/overwrite-mode'

  # insert
  ble-bind -f 'C-q'       'vi_imap/quoted-insert'
  ble-bind -f 'C-v'       'vi_imap/quoted-insert'
  ble-bind -f 'C-RET'     'newline'
  ble-bind -f paste_begin 'vi_imap/bracketed-paste'

  # charwise operations
  ble-bind -f 'C-?'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'DEL'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'C-h'       'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'BS'        'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'

  # wordwise operations
  ble-bind -f 'C-w'       'vi_imap/delete-backward-word'

  # complete
  ble-decode/keymap:vi_imap/bind-complete

  #----------------------------------------------------------------------------
  # shell functions (from keymap emacs-standard)

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-^' bell

  #----------------------------------------------------------------------------
  # vi bindings

  ble-bind -f __attach__        vi_imap/__attach__
  ble-bind -f __detach__        vi_imap/__detach__
  ble-bind -f __default__       vi_imap/__default__
  ble-bind -f __before_widget__ vi_imap/__before_widget__
  ble-bind -f __line_limit__    __line_limit__

  ble-bind -f 'ESC' 'vi_imap/normal-mode'
  ble-bind -f 'C-[' 'vi_imap/normal-mode'
  ble-bind -f 'C-c' 'vi_imap/normal-mode-without-insert-leave'

  ble-bind -f 'C-o' 'vi_imap/single-command-mode'

  # ble-bind -f 'C-l' vi_imap/normal-mode
  # ble-bind -f 'C-k' vi_imap/insert-digraph
}

## @fn ble-decode/keymap:vi_imap/define-meta-bindings
##   M- で始まるキーバインディングを定義します。
##   ユーザから呼び出すための関数です。
function ble-decode/keymap:vi_imap/define-meta-bindings {
  local ble_bind_keymap=vi_imap

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/define

  ble-bind -f 'M-^'       'history-expand-line'
  ble-bind -f 'C-M-l'     'redraw-line'
  ble-bind -f 'M-#'       'insert-comment'
  ble-bind -f 'M-C-e'     'shell-expand-line'
  ble-bind -f 'M-&'       'tilde-expand'
  ble-bind -f 'C-M-g'     'bell'
  ble-bind -f 'M-z'       'zap-to-char'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-common

  ble-bind -f 'M-C-m'     'newline'
  ble-bind -f 'M-RET'     'newline'
  ble-bind -f 'M-SP'      'set-mark'
  ble-bind -f 'M-w'       'copy-region-or copy-uword'
  ble-bind -f 'M-y'       'yank-pop'
  ble-bind -f 'M-S-y'     'yank-pop backward'
  ble-bind -f 'M-Y'       'yank-pop backward'
  ble-bind -f 'M-\'       'delete-horizontal-space'

  ble-bind -f 'M-right'   '@nomarked forward-sword'
  ble-bind -f 'M-left'    '@nomarked backward-sword'
  ble-bind -f 'S-M-right' '@marked forward-sword'
  ble-bind -f 'S-M-left'  '@marked backward-sword'
  ble-bind -f 'M-d'       'kill-forward-cword'
  ble-bind -f 'M-h'       'kill-backward-cword'
  ble-bind -f 'M-delete'  'copy-forward-sword'
  ble-bind -f 'M-C-?'     'copy-backward-sword'
  ble-bind -f 'M-DEL'     'copy-backward-sword'
  ble-bind -f 'M-C-h'     'copy-backward-sword'
  ble-bind -f 'M-BS'      'copy-backward-sword'

  ble-bind -f 'M-f'       '@nomarked forward-cword'
  ble-bind -f 'M-b'       '@nomarked backward-cword'
  ble-bind -f 'M-F'       '@marked forward-cword'
  ble-bind -f 'M-B'       '@marked backward-cword'
  ble-bind -f 'M-S-f'     '@marked forward-cword'
  ble-bind -f 'M-S-b'     '@marked backward-cword'
  ble-bind -f 'M-c'       'capitalize-eword'
  ble-bind -f 'M-l'       'downcase-eword'
  ble-bind -f 'M-u'       'upcase-eword'
  ble-bind -f 'M-t'       'transpose-ewords'

  ble-bind -f 'M-m'       '@nomarked non-space-beginning-of-line'
  ble-bind -f 'M-S-m'     '@marked non-space-beginning-of-line'
  ble-bind -f 'M-M'       '@marked non-space-beginning-of-line'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-history

  ble-bind -f 'M-<'       'history-beginning'
  ble-bind -f 'M->'       'history-end'
  ble-bind -f 'M-.'       'insert-last-argument'
  ble-bind -f 'M-_'       'insert-last-argument'
  ble-bind -f 'M-C-y'     'insert-nth-argument'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-complete

  ble-bind -f 'M-?'       'complete show_menu'
  ble-bind -f 'M-*'       'complete insert_all'
  ble-bind -f 'M-{'       'complete insert_braces'
  ble-bind -f 'M-/'       'complete context=filename'
  ble-bind -f 'M-~'       'complete context=username'
  ble-bind -f 'M-$'       'complete context=variable'
  ble-bind -f 'M-@'       'complete context=hostname'
  ble-bind -f 'M-!'       'complete context=command'
  ble-bind -f "M-'"       'sabbrev-expand'
  ble-bind -f 'M-g'       'complete context=glob'
  ble-bind -f 'M-C-i'     'complete context=dynamic-history'
  ble-bind -f 'M-TAB'     'complete context=dynamic-history'

  #----------------------------------------------------------------------------
  # from ble-decode/keymap:safe/bind-arg

  ble-bind -f 'M-0'       'append-arg'
  ble-bind -f 'M-1'       'append-arg'
  ble-bind -f 'M-2'       'append-arg'
  ble-bind -f 'M-3'       'append-arg'
  ble-bind -f 'M-4'       'append-arg'
  ble-bind -f 'M-5'       'append-arg'
  ble-bind -f 'M-6'       'append-arg'
  ble-bind -f 'M-7'       'append-arg'
  ble-bind -f 'M-8'       'append-arg'
  ble-bind -f 'M-9'       'append-arg'
}

#------------------------------------------------------------------------------
# vi_cmap

_ble_keymap_vi_cmap_hook=
_ble_keymap_vi_cmap_cancel_hook=
_ble_keymap_vi_cmap_before_command=

# 既定の cmap 履歴
_ble_keymap_vi_cmap_history=()
_ble_keymap_vi_cmap_history_edit=()
_ble_keymap_vi_cmap_history_dirt=()
_ble_keymap_vi_cmap_history_index=0

function ble/keymap:vi/async-commandline-mode {
  local hook=$1
  _ble_keymap_vi_cmap_hook=$hook
  _ble_keymap_vi_cmap_cancel_hook=
  _ble_keymap_vi_cmap_before_command=

  # 記録
  ble/textarea#render
  ble/textarea#save-state _ble_keymap_vi_cmap
  ble/util/save-vars _ble_keymap_vi_cmap _ble_canvas_panel_focus
  _ble_keymap_vi_cmap_history_prefix=$_ble_history_prefix

  # 初期化
  ble/decode/keymap/push vi_cmap
  ble/keymap:vi/update-mode-indicator

  # textarea
  _ble_textarea_panel=1
  _ble_canvas_panel_focus=1
  ble/textarea#invalidate

  # edit/prompt
  _ble_edit_PS1=$PS2
  _ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 '' '')

  # edit
  #   Note: ble/widget/.newline/clear-content の中で
  #   ble-edit/content/reset が呼び出され、更に _ble_edit_dirty_observer が呼び出さる。
  #   ble/keymap:vi/mark/shift-by-dirty-range が呼び出されないように、
  #   _ble_edit_dirty_observer=() より後である必要がある。
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=

  # edit/undo
  ble-edit/undo/clear-all

  # edit/history
  ble/history/set-prefix _ble_keymap_vi_cmap

  # syntax, highlight
  _ble_syntax_lang=text
  _ble_highlight_layer_list=(plain region overwrite_mode)
}

function ble/widget/vi_cmap/accept {
  local hook=${_ble_keymap_vi_cmap_hook}
  _ble_keymap_vi_cmap_hook=

  local result=$_ble_edit_str
  [[ $result ]] && ble/history/add "$result" # Note: cancel でも登録する

  # 消去
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
  ble/canvas/bflush.draw

  # 復元
  ble/textarea#restore-state _ble_keymap_vi_cmap
  ble/textarea#clear-state _ble_keymap_vi_cmap
  ble/util/restore-vars _ble_keymap_vi_cmap _ble_canvas_panel_focus
  [[ $_ble_edit_overwrite_mode ]] && ble/util/buffer "$_ble_term_civis"
  ble/history/set-prefix "$_ble_keymap_vi_cmap_history_prefix"

  ble/decode/keymap/pop
  ble/keymap:vi/update-mode-indicator
  if [[ $hook ]]; then
    builtin eval -- "$hook \"\$result\""
  else
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}

function ble/widget/vi_cmap/cancel {
  _ble_keymap_vi_cmap_hook=$_ble_keymap_vi_cmap_cancel_hook
  ble/widget/vi_cmap/accept
}

function ble/widget/vi_cmap/__before_widget__ {
  if [[ $_ble_keymap_vi_cmap_before_command ]]; then
    builtin eval -- "$_ble_keymap_vi_cmap_before_command"
  fi
}

function ble/widget/vi_cmap/__line_limit__.edit {
  local content=$1
  ble/widget/edit-and-execute-command.edit "$content" no-newline; local ext=$?
  ((ext==127)) && return "$ext"
  ble-edit/content/reset "$ret"
  ble/widget/vi_cmap/accept
}
function ble/widget/vi_cmap/__line_limit__ {
  ble/widget/__line_limit__ vi_cmap/__line_limit__.edit
}

function ble-decode/keymap:vi_cmap/define {
  #----------------------------------------------------------------------------
  # common bindings + modifications

  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete

  #----------------------------------------------------------------------------

  ble-bind -f __before_widget__ vi_cmap/__before_widget__
  ble-bind -f __line_limit__    vi_cmap/__line_limit__

  # accept/cancel
  ble-bind -f 'ESC'     vi_cmap/cancel
  ble-bind -f 'C-['     vi_cmap/cancel
  ble-bind -f 'C-c'     vi_cmap/cancel
  ble-bind -f 'C-m'     vi_cmap/accept
  ble-bind -f 'RET'     vi_cmap/accept
  ble-bind -f 'C-j'     vi_cmap/accept
  ble-bind -f 'C-g'     bell
  ble-bind -f 'C-x C-g' bell
  ble-bind -f 'C-M-g'   bell

  # shell function
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'C-M-l'   redraw-line
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'M-^'     history-expand-line
  # ble-bind -f 'SP'      magic-space
  # ble-bind -f '/'       magic-slash

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-^' bell
}

#------------------------------------------------------------------------------

function ble-decode/keymap:vi/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi
  if [[ -s $fname_keymap_cache &&
          $fname_keymap_cache -nt $_ble_base/lib/keymap.vi.sh &&
          $fname_keymap_cache -nt $_ble_base/lib/init-cmap.sh ]]; then
    source "$fname_keymap_cache" && return 0
  fi

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi..."

  {
    ble/decode/keymap#load isearch dump
    ble/decode/keymap#load nsearch dump
    ble/decode/keymap#load vi_imap dump
    ble/decode/keymap#load vi_nmap dump
    ble/decode/keymap#load vi_omap dump
    ble/decode/keymap#load vi_xmap dump
    ble/decode/keymap#load vi_cmap dump
  } 3>| "$fname_keymap_cache"

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.vi... done"
}

ble-decode/keymap:vi/initialize
blehook/invoke keymap_load
blehook/invoke keymap_vi_load
return 0
