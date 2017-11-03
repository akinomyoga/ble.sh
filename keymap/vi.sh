#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されうるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
ble/util/isfunction ble-edit/load-keymap-definition:vi && return
function ble-edit/load-keymap-definition:vi { :; }

source "$_ble_base/keymap/vi_digraph.sh"

## オプション keymap_vi_force_update_textmap
##   1 が設定されているとき、矩形選択に先立って配置計算を強制します。
##   0 が設定されているとき、配置情報があるときにそれを使い、
##   配置情報がないときは論理行・論理列による矩形選択にフォールバックします。
##
: ${bleopt_keymap_vi_force_update_textmap:=1}

function ble/keymap:vi/use-textmap {
  ble/textmap#is-up-to-date && return 0
  ((bleopt_keymap_vi_force_update_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

function ble/keymap:vi/k2c {
  local key=$1
  local flag=$((key&ble_decode_MaskFlag)) char=$((key&ble_decode_MaskChar))
  if ((flag==0&&(32<=char&&char<ble_decode_function_key_base))); then
    ret=$char
    return 0
  elif ((flag==ble_decode_Ctrl&&63<=char&&char<128&&(char&0x1F)!=0)); then
    ((char=char==63?127:char&0x1F))
    ret=$char
    return 0
  else
    return 1
  fi
}

#------------------------------------------------------------------------------
# utils

## 関数 ble/string#index-of-chars text chars [index]
##   文字集合に含まれる文字を、文字列中で順方向に探索します。
## 関数 ble/string#last-index-of-chars text chars [index]
##   文字集合に含まれる文字を、文字列中で逆方向に探索します。
##
##   @param[in] text
##     検索する対象の文字列を指定します。
##   @param[in] chars
##     検索する文字の集合を指定します
##   @param[in] index
##     text の内の検索開始位置を指定します。
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

function ble-edit/content/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
function ble-edit/content/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
function ble-edit/content/nonbol-eolp {
  local pos=${1:-$_ble_edit_ind}
  ! ble-edit/content/bolp "$pos" && ble-edit/content/eolp "$pos"
}
function ble-edit/content/find-non-space {
  local bol=$1
  local rex=$'^[ \t]*'; [[ ${_ble_edit_str:bol} =~ $rex ]]
  ret=$((bol+${#BASH_REMATCH}))
}

function ble/widget/nop { :; }

function ble/keymap:vi/string#encode-rot13 {
  local text=$*
  local -a buff ch
  for ((i=0;i<${#text};i++)); do
    ch=${text:i:1}
    if [[ $ch == [A-Z] ]]; then
      ch=${_ble_util_string_upper_list%%"$ch"*}
      ch=${_ble_util_string_upper_list:(${#ch}+13)%26:1}
    elif [[ $ch == [a-z] ]]; then
      ch=${_ble_util_string_lower_list%%"$ch"*}
      ch=${_ble_util_string_lower_list:(${#ch}+13)%26:1}
    fi
    ble/array#push buff "$ch"
  done
  IFS= eval 'ret=${buff[*]}'
}

#------------------------------------------------------------------------------
# constants

_ble_keymap_vi_REX_WORD=$'[a-zA-Z0-9_]+|[!-/:-@[-`{-~]+|[^ \t\na-zA-Z0-9!-/:-@[-`{-~]+'

#------------------------------------------------------------------------------
# vi_imap/__default__, vi-command/decompose-meta

function ble/widget/vi_imap/__default__ {
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    ble/keymap:vi/imap-repeat/pop

    local esc=27 # ESC
    # local esc=$((ble_decode_Ctrl|0x5b)) # もしくは C-[
    ble-decode-key "$esc" "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
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
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    local esc=27 # ESC
    # local esc=$((ble_decode_Ctrl|0x5b)) # もしくは C-[
    ble-decode-key "$esc" "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
    return 0
  fi

  return 125
}

function ble/widget/vi_omap/__default__ {
  ble/widget/vi-command/decompose-meta || ble/widget/vi-command/bell
  return 0
}

#------------------------------------------------------------------------------
# repeat

## 変数 _ble_keymap_vi_irepeat_count
##   挿入モードに入る時に指定された引数を記録する。
_ble_keymap_vi_irepeat_count=

## 配列 _ble_keymap_vi_irepeat
##   挿入モードに入るときに指定された引数が 1 より大きい時、
##   後で操作を繰り返すために操作内容を記録する配列。
##
##   各要素は keys:widget の形式を持つ。
##   keys は空白区切りの key (整数値) の列、つまり ${KEYS[*]} である。
##   widget は実際に呼び出す WIDGET の内容である。
##
_ble_keymap_vi_irepeat=()

function ble/keymap:vi/imap-repeat/pop {
  local top_index=$((${#_ble_keymap_vi_irepeat[*]}-1))
  ((top_index>=0)) && unset '_ble_keymap_vi_irepeat[top_index]'
}
function ble/keymap:vi/imap-repeat/push {
  ble/array#push _ble_keymap_vi_irepeat "${KEYS[*]}:$WIDGET"
}

function ble/keymap:vi/imap-repeat/reset {
  local count=$1
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
        local -a KEYS=(${widget%%:*})
        local WIDGET=${widget#*:} KEYMAP=$_ble_decode_key__kmap
        builtin eval -- "$WIDGET"
      done
    done
  fi
}

## 配列 _ble_keymap_vi_imap_white_list
##   引数を指定して入った挿入モードを抜けるときの繰り返しで許されるコマンドのリスト
_ble_keymap_vi_imap_white_list=(
  self-insert
  nop
  magic-space
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
    local cmd=${1#ble/widget/}; cmd=${cmd%%[$' \t\n']*}
    [[ $cmd == vi_imap/* || " ${_ble_keymap_vi_imap_white_list[*]} " == *" $cmd "*  ]] && return 0
  fi
  return 1
}

function ble/widget/vi_imap/__before_command__ {
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
# modes

## 変数 _ble_keymap_vi_insert_overwrite
##   挿入モードに入った時の上書き文字
_ble_keymap_vi_insert_overwrite=

## 変数 _ble_keymap_vi_insert_leave
##   挿入モードから抜ける時に実行する関数を設定します
_ble_keymap_vi_insert_leave=

## 変数 _ble_keymap_vi_single_command
##   ノーマルモードにおいて 1 つコマンドを実行したら
##   元の挿入モードに戻るモード (C-o) にいるかどうかを表します。
_ble_keymap_vi_single_command=
_ble_keymap_vi_single_command_overwrite=

## オプション bleopt_keymap_vi_nmap_name
##   ノーマルモードの時に表示する文字列を指定します。
##   空文字列を指定したときは何も表示しません。
: ${bleopt_keymap_vi_nmap_name:=$'\e[1m~\e[m'}

: ${bleopt_term_vi_imap=}
: ${bleopt_term_vi_nmap=}
: ${bleopt_term_vi_omap=}
: ${bleopt_term_vi_xmap=}
: ${bleopt_term_vi_cmap=}

function ble/keymap:vi/update-mode-name {
  local kmap=$_ble_decode_key__kmap
  if [[ $kmap == vi_imap ]]; then
    ble/util/buffer "$bleopt_term_vi_imap"
  elif [[ $kmap == vi_nmap ]]; then
    ble/util/buffer "$bleopt_term_vi_nmap"
  elif [[ $kmap == vi_xmap ]]; then
    ble/util/buffer "$bleopt_term_vi_xmap"
  elif [[ $kmap == vi_omap ]]; then
    ble/util/buffer "$bleopt_term_vi_omap"
  elif [[ $kmap == vi_cmap ]]; then
    ble-edit/info/default text ''
    ble/util/buffer "$bleopt_term_vi_cmap"
    return
  fi

  local show= overwrite=
  if [[ $kmap == vi_imap ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && ( $kmap == vi_nmap || $kmap == vi_omap ) ]]; then
    show=1 overwrite=$_ble_keymap_vi_single_command_overwrite
  elif [[ $kmap == vi_xmap ]]; then
    show=x overwrite=$_ble_keymap_vi_single_command_overwrite
  fi

  local name=$bleopt_keymap_vi_nmap_name
  if [[ $show ]]; then
    if [[ $overwrite == R ]]; then
      name='REPLACE'
    elif [[ $overwrite ]]; then
      name='VREPLACE'
    else
      name='INSERT'
    fi

    if [[ $_ble_keymap_vi_single_command ]]; then
      local ret; ble/string#tolower "$name"; name="($ret)"
    fi

    if [[ $show == x ]]; then
      local mark_type=${_ble_edit_mark_active%+}
      local visual_name=
      if [[ $mark_type == line ]]; then
        visual_name='VISUAL LINE'
      elif [[ $mark_type == block ]]; then
        visual_name='VISUAL BLOCK'
      else
        visual_name='VISUAL'
      fi

      if [[ $_ble_keymap_vi_single_command ]]; then
        name="$name $visual_name"
      else
        name=$visual_name
      fi
    fi

    name=$'\e[1m-- '$name$' --\e[m'
  fi
  ble-edit/info/default raw "$name"
}

function ble/widget/vi_imap/normal-mode.impl {
  local opts=$1

  # finalize insert mode
  ble/keymap:vi/mark/set-local-mark 94 "$_ble_edit_ind" # `^
  ble/keymap:vi/mark/end-edit-area
  [[ :$opts: == *:InsertLeave:* ]] && eval "$_ble_keymap_vi_insert_leave"

  # setup normal mode
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/bolp || ble/widget/.goto-char $((_ble_edit_ind-1))
  ble-decode/keymap/push vi_nmap
}
function ble/widget/vi_imap/normal-mode {
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/imap-repeat/process
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl InsertLeave
  ble/keymap:vi/update-mode-name
  return 0
}
function ble/widget/vi_imap/normal-mode-without-insert-leave {
  ble/keymap:vi/imap-repeat/pop
  ble/keymap:vi/repeat/record-insert
  ble/widget/vi_imap/normal-mode.impl
  ble/keymap:vi/update-mode-name
  return 0
}
function ble/widget/vi_imap/single-command-mode {
  local single_command=1
  local single_command_overwrite=$_ble_edit_overwrite_mode
  ble-edit/content/eolp && _ble_keymap_vi_single_command=2

  ble/keymap:vi/imap-repeat/pop
  ble/widget/vi_imap/normal-mode.impl
  _ble_keymap_vi_single_command=$single_command
  _ble_keymap_vi_single_command_overwrite=$single_command_overwrite
  ble/keymap:vi/update-mode-name
  return 0
}

## 関数 ble/keymap:vi/needs-eol-fix
##
##   Note: この関数を使った後は ble/keymap:vi/adjust-command-mode を呼び出す必要がある。
##     そうしないとノーマルモードにおいてありえない位置にカーソルが来ることになる。
##
function ble/keymap:vi/needs-eol-fix {
  [[ $_ble_decode_key__kmap == vi_nmap || $_ble_decode_key__kmap == vi_omap ]] || return 1
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/content/nonbol-eolp "$index"
}
function ble/keymap:vi/adjust-command-mode {
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    # 移動コマンドが来たら末尾拡張を無効にする。
    # 移動コマンドはここを通るはず…
    ble/keymap:vi/xmap/remove-eol-extension
  fi

  local kmap_popped=
  if [[ $_ble_decode_key__kmap == vi_omap ]]; then
    ble-decode/keymap/pop
    kmap_popped=1
  fi

  # search による mark の設定・解除
  if [[ $_ble_keymap_vi_search_activate ]]; then
    if [[ $_ble_decode_key__kmap != vi_xmap ]]; then
      _ble_edit_mark_active=$_ble_keymap_vi_search_activate
    fi
    _ble_keymap_vi_search_matched=1
    _ble_keymap_vi_search_activate=
  else
    [[ $_ble_edit_mark_active == search ]] && _ble_edit_mark_active=
    ((_ble_keymap_vi_search_matched)) && _ble_keymap_vi_search_matched=
  fi

  if [[ $_ble_decode_key__kmap == vi_nmap && $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/content/nonbol-eolp "$index" && ble/widget/.goto-char index
    fi
    ble/widget/vi_nmap/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite" resume
    ble/keymap:vi/repeat/clear-insert
  elif [[ $kmap_popped ]]; then
    ble/keymap:vi/update-mode-name
  fi

  return 0
}
function ble/widget/vi-command/bell {
  ble/widget/.bell "$1"
  ble/keymap:vi/adjust-command-mode
  return 0
}

## 関数 ble/widget/vi_nmap/.insert-mode [arg [overwrite [opts]]]
##   @param[in] arg
##   @param[in] overwrite
##   @param[in] opts
function ble/widget/vi_nmap/.insert-mode {
  [[ $_ble_decode_key__kmap == vi_xmap ]] && ble-decode/keymap/pop
  [[ $_ble_decode_key__kmap == vi_omap ]] && ble-decode/keymap/pop
  local arg=$1 overwrite=$2
  ble/keymap:vi/imap-repeat/reset "$arg"
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=$overwrite
  _ble_keymap_vi_insert_leave=
  _ble_keymap_vi_insert_overwrite=$overwrite
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  _ble_keymap_vi_search_matched=
  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name

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
    ble/widget/.goto-char $((_ble_edit_ind+1))
  fi
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/append-mode-at-end-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-eol
  ble/widget/.goto-char "$ret"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-beginning-of-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret; ble-edit/content/find-logical-bol
  ble/widget/.goto-char "$ret"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/first-non-space
  [[ ${_ble_edit_str:_ble_edit_ind:1} == [$' \t'] ]] &&
    ble/widget/.goto-char _ble_edit_ind+1 # 逆eol補正
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
# nmap: gi
function ble/widget/vi_nmap/insert-mode-at-previous-point {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble/keymap:vi/mark/get-local-mark 94 && ble/widget/.goto-char "$ret"
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
function ble/widget/vi-command/accept-line {
  ble/keymap:vi/clear-arg
  ble/widget/vi_nmap/.insert-mode
  ble/keymap:vi/repeat/clear-insert
  ble/widget/accept-line
}
function ble/widget/vi-command/accept-single-line-or {
  if ble/widget/accept-single-line-or/accepts; then
    ble/widget/vi-command/accept-line
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------
# args
#
# arg     : 0-9 d y c
# command : dd yy cc [dyc]0 Y S

_ble_keymap_vi_oparg=
_ble_keymap_vi_opfunc=
_ble_keymap_vi_reg=

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

## 関数 ble/keymap:vi/clear-arg
function ble/keymap:vi/clear-arg {
  _ble_edit_arg=
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
  _ble_keymap_vi_reg=
}
## 関数 ble/keymap:vi/get-arg [default_value]; ARG FLAG REG
##
## 引数の内容について
##   vi_nmap, vi_xmap においては FLAG は空であると仮定して良い。
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
    ARG=$((10#${_ble_edit_arg:-1}*10#${_ble_keymap_vi_oparg:-1}))
  fi
  ble/keymap:vi/clear-arg
}
## 関数 ble/keymap:vi/register#load reg
function ble/keymap:vi/register#load {
  local reg=$1
  if [[ $reg ]] && ((reg!=34)); then
    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      _ble_edit_kill_type=${value%%/*}
      _ble_edit_kill_ring=${value#*/}
    else
      _ble_edit_kill_type=
      _ble_edit_kill_ring=
    fi
  fi
}
function ble/keymap:vi/register#set {
  local reg=$1 type=$2 content=$3

  # 追記の場合
  if [[ $reg == +* ]]; then
    local value=${_ble_keymap_vi_register[reg]}
    if [[ $value == */* ]]; then
      local otype=${value%%/*}
      local oring=${value#*/}

      if [[ $otype == L ]]; then
        type=L content=$oring$content # V + * → V
      elif [[ $type == L ]]; then
        type=L content=$oring$'\n'$content # C-v + V, v + V → V
      elif [[ $otype == B:* ]]; then
        if [[ $type == B:* ]]; then
          type=$otype' '${type#B:}
          content=$oring$'\n'$content # C-v + C-v → C-v
        else
          local ret; ble/string#count-char "$content" $'\n'
          ble/string#repeat ' 0' $((ret+1))
          type=$otype$ret
          content=$oring$'\n'$content # C-v + v → C-v
        fi
      else
        type= content=$oring$content # v + C-v, v + v → v
      fi
    fi
  fi

  [[ $type == L && $content != *$'\n' ]] && content=$content$'\n'

  if [[ ! $reg ]] || ((reg==34)); then # ""
    # unnamed register
    _ble_edit_kill_type=$type
    _ble_edit_kill_ring=$content
    return 0
  elif ((reg==58||reg==46||reg==37||reg==126)); then # ": ". "% "~
    # read only register
    ble/widget/.bell "attempted to write on a read-only register #$reg"
    return 1
  elif ((reg==95)); then # "_
    # black hole register
    return 0
  else
    _ble_edit_kill_type=$type
    _ble_edit_kill_ring=$content
    _ble_keymap_vi_register[reg]=$type/$content
    return 0
  fi
}

function ble/widget/vi-command/append-arg {
  local ret ch=$1
  if [[ ! $ch ]]; then
    local code=$((KEYS[0]&ble_decode_MaskChar))
    ((code==0)) && return 1
    ble/util/c2s "$code"; ch=$ret
  fi
  ble-assert '[[ ! ${ch//[0-9]} ]]'

  # 0
  if [[ $ch == 0 && ! $_ble_edit_arg ]]; then
    ble/widget/vi-command/beginning-of-line
    return
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

function ble/widget/vi-command/operator {
  local ret opname=$1

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    local ARG FLAG REG; ble/keymap:vi/get-arg ''
    # ※FLAG はユーザにより設定されているかもしれないが無視

    local a=$_ble_edit_ind b=$_ble_edit_mark
    ((a<=b||(a=_ble_edit_mark,b=_ble_edit_ind)))

    ble/widget/vi_xmap/.save-visual-state
    local old_mark_active=$_ble_edit_mark_active
    local mark_type=${_ble_edit_mark_active%+}
    ble/widget/vi_xmap/exit

    if [[ $mark_type == line ]]; then
      ble/keymap:vi/call-operator-linewise "$opname" "$a" "$b" "$ARG" "$REG"
    elif [[ $mark_type == block ]]; then
      _ble_edit_mark_active=$old_mark_active ble/keymap:vi/call-operator-blockwise "$opname" "$a" "$b" "$ARG" "$REG"
    else
      local end=$b
      ((end<${#_ble_edit_str}&&end++))
      ble/keymap:vi/call-operator-charwise "$opname" "$a" "$end" "$ARG" "$REG"
    fi; local ext=$?
    ((ext==148)) && return 148
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  elif [[ $_ble_decode_key__kmap == vi_nmap ]]; then
    ble-decode/keymap/push vi_omap
    _ble_keymap_vi_oparg=$_ble_edit_arg
    _ble_keymap_vi_opfunc=$opname
    _ble_edit_arg=
    ble/keymap:vi/update-mode-name

  elif [[ $_ble_decode_key__kmap == vi_omap ]]; then
    if [[ $opname == "$_ble_keymap_vi_opfunc" ]]; then
      # 2つの同じオペレータ (yy, dd, cc, etc.) = 行指向の処理
      ble/widget/vi_nmap/linewise-operator "$opname"
    else
      ble/keymap:vi/clear-arg
      ble/widget/vi-command/bell
      return 1
    fi
  fi
  return 0
}

function ble/widget/vi_nmap/linewise-operator {
  local opname=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1 # _ble_edit_arg is consumed here
  if ((ARG==1)) || [[ ${_ble_edit_str:_ble_edit_ind} == *$'\n'* ]]; then
    ble/keymap:vi/call-operator-linewise "$opname" "$_ble_edit_ind" "$_ble_edit_ind:$((ARG-1))" '' "$REG"; local ext=$?
    if ((ext==0)); then
      ble/keymap:vi/adjust-command-mode
      return 0
    elif ((ext==148)); then
      return 148
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
  ble/widget/vi-command/exclusive-goto.impl "$beg" "$FLAG" "$REG" 1
}

#------------------------------------------------------------------------------
# operators / movements


## オペレータは以下の形式の関数として定義される。
##
## 関数 ble/keymap:vi/operator:名称 a b context [count [reg]]
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
##   @exit
##     operator 関数が終了ステータス 148 を返したとき、
##     operator が非同期に入力を読み取ることを表します。
##     148 を返した operator は、実際に操作が完了した時に
##
##     1 ble/keymap:vi/mark/end-edit-area を呼び出す必要があります。
##     2 適切な位置にカーソルを移動する必要があります。
##
##
## オペレータは現在以下の4箇所で呼び出されている。
##
## - ble/widget/vi-command/linewise-range.impl
## - ble/keymap:vi/call-operator
## - ble/keymap:vi/call-operator-charwise
## - ble/keymap:vi/call-operator-linewise
## - ble/keymap:vi/call-operator-blockwise


## 関数 ble/keymap:vi/call-operator op beg end type arg reg
## 関数 ble/keymap:vi/call-operator-charwise op beg end arg reg
## 関数 ble/keymap:vi/call-operator-linewise op beg end arg reg
## 関数 ble/keymap:vi/call-operator-blockwise op beg end arg reg
function ble/keymap:vi/call-operator {
  ble/keymap:vi/mark/start-edit-area
  local _ble_keymap_vi_mark_suppress_edit=1
  ble/keymap:vi/operator:"$@"; local ext=$?
  unset _ble_keymap_vi_mark_suppress_edit
  ble/keymap:vi/mark/end-edit-area
  if ((ext==0)); then
    if ble/util/isfunction ble/keymap:vi/operator:"$1".record; then
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
  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" char "$arg" "$reg"; local ext=$?
    ((ext==148)) && return 148
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
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

  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    ((end<${#_ble_edit_str}&&end++))
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" line "$arg" "$reg"; local ext=$?
    ((ext==148)) && return 148
    ble-edit/content/find-logical-bol "$beg"; beg=$ret # operator 中で beg が変更されているかも
    ble-edit/content/find-non-space "$beg"; local nol=$ret
    ble/keymap:vi/needs-eol-fix "$nol" && ((nol--))
    ble/widget/.goto-char "$nol"
    return 0
  else
    return 1
  fi
}
function ble/keymap:vi/call-operator-blockwise {
  local ch=$1 beg=$2 end=$3 arg=$4 reg=$5
  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block "$beg" "$end"
    local nrange=${#sub_ranges[@]}
    ((nrange)) || return 1

    local beg=${sub_ranges[0]}; beg=${beg%%:*}
    local end=${sub_ranges[nrange-1]}; end=${end#*:}; end=${end%%:*}
    ble/keymap:vi/call-operator "$ch" "$beg" "$end" block "$arg" "$reg"
    ((ext==148)) && return 148

    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
    return 0
  else
    return 1
  fi
}


function ble/keymap:vi/operator:d {
  local context=$3 arg=$4 reg=$5 # beg end は上書きする
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1
    ((end==${#_ble_edit_str}&&beg>0&&beg--)) # fix start position
    ble/widget/.delete-range "$beg" "$end"
  elif [[ $context == block ]]; then
    ble/keymap:vi/operator:y "$@" || return 1
    local isub=${#sub_ranges[@]} sub
    local smin= smax= slpad= srpad=
    while ((isub--)); do
      ble/string#split sub : "${sub_ranges[isub]}"
      smin=${sub[0]} smax=${sub[1]}
      slpad=${sub[2]} srpad=${sub[3]}
      local ret; ble/string#repeat ' ' $((slpad+srpad))
      ble/widget/.replace-range "$smin" "$smax" "$ret" 1
    done
    ((beg+=slpad)) # fix start position
  else
    if ((beg<end)); then
      ble/keymap:vi/register#set "$reg" '' "${_ble_edit_str:beg:end-beg}" || return 1
      ble/widget/.delete-range "$beg" "$end" 0
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:c {
  local context=$3 arg=$4 reg=$5 # beg は上書き対象
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1

    local end2=$end
    ((end2)) && [[ ${_ble_edit_str:end2-1:1} == $'\n' ]] && ((end2--))

    local indent=
    ble-edit/content/find-non-space "$beg"; local nol=$ret
    ((beg<nol)) && indent=${_ble_edit_str:beg:nol-beg}

    ble/widget/.replace-range "$beg" "$end2" "$indent" 1
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
    ble/keymap:vi/operator:d "$@" || return 1 # @var beg will be overwritten here
    ble/widget/vi_nmap/.insert-mode
  fi
  return 0
}
function ble/keymap:vi/operator:y.record { :; }
function ble/keymap:vi/operator:y {
  local beg=$1 end=$2 context=$3 arg=$4 reg=$5
  if [[ $context == line ]]; then
    ble/keymap:vi/register#set "$reg" L "${_ble_edit_str:beg:end-beg}" || return 1
  elif [[ $context == block ]]; then
    local sub
    local -a afill atext
    for sub in "${sub_ranges[@]}"; do
      local sub4=${sub#*:*:*:*:}
      local sfill=${sub4%%:*} stext=${sub4#*:}
      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
    done

    IFS=$'\n' eval 'local kill_ring=${atext[*]}'
    local kill_type=B:${afill[*]}
    ble/keymap:vi/register#set "$reg" "$kill_type" "$kill_ring" || return 1
  else
    ble/keymap:vi/register#set "$reg" '' "${_ble_edit_str:beg:end-beg}" || return 1
  fi
  ble/keymap:vi/mark/commit-edit-area "$1" "$2"
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
      ble/widget/.replace-range "$smin" "$smax" "$ret" 1
    done
  else
    local ret; "$filter" "${_ble_edit_str:beg:end-beg}"
    ble/widget/.replace-range "$beg" "$end" "$ret" 1
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

## 関数 ble/keymap:vi/expand-range-for-linewise-operator
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
    ble-edit/content/find-logical-eol "$end"; local end=$ret
    [[ ${_ble_edit_str:end:1} == $'\n' ]] && ((end++))
  fi
}

#--------------------------------------
# Indent operators < >

function ble/keymap:vi/string#increase-indent {
  local text=$1 delta=$2
  local space=$' \t' it=${bleopt_tab_width:-$_ble_term_it}
  local arr; ble/string#split-lines arr "$text"
  local -a arr2
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

  IFS=$'\n' eval 'ret=${arr2[*]}'
}
## 関数 ble/keymap:vi/operator:increase-indent.impl/increase-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:increase-indent.impl/increase-block-indent {
  local width=$1
  local isub=${#sub_ranges[@]}
  local sub smin slpad ret
  while ((isub--)); do
    ble/string#split sub : "${sub_ranges[isub]}"
    smin=${sub[0]} slpad=${sub[2]}
    ble/string#repeat ' ' $((slpad+width))
    ble/widget/.replace-range "$smin" "$smin" "$ret" 1
  done
}
## 関数 ble/keymap:vi/operator:increase-indent.impl/decrease-graphical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:increase-indent.impl/decrease-graphical-block-indent {
  local width=$1
  local it=${bleopt_tab_width:-$_ble_term_it} cols=$_ble_textmap_cols
  local sub smin slpad
  local -a replaces
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
    ble/widget/.replace-range "${rep[@]::3}" 1
  done
}
## 関数 ble/keymap:vi/operator:increase-indent.impl/decrease-logical-block-indent width
##   @param[in] width
##   @var[in] sub_ranges
function ble/keymap:vi/operator:increase-indent.impl/decrease-logical-block-indent {
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
    ble/widget/.replace-range "$smin" "$nsp" "$padding" 1
  done
}
function ble/keymap:vi/operator:increase-indent.impl {
  local delta=$1 context=$2
  ((delta)) || return 0
  if [[ $context == block ]]; then
    if ((delta>=0)); then
      ble/keymap:vi/operator:increase-indent.impl/increase-block-indent "$delta"
    elif ble/keymap:vi/use-textmap; then
      ble/keymap:vi/operator:increase-indent.impl/decrease-graphical-block-indent $((-delta))
    else
      ble/keymap:vi/operator:increase-indent.impl/decrease-logical-block-indent $((-delta))
    fi
  else
    [[ $context == char ]] && ble/keymap:vi/expand-range-for-linewise-operator
    ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

    ble/keymap:vi/string#increase-indent "${_ble_edit_str:beg:end-beg}" "$delta"; local content=$ret
    ble/widget/.replace-range "$beg" "$end" "$content" 1

    if [[ $context == char ]]; then
      ble-edit/content/find-non-space "$beg"; beg=$ret
    fi
  fi
  return 0
}
function ble/keymap:vi/operator:indent-left {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:increase-indent.impl $((-bleopt_indent_offset*arg)) "$context"
}
function ble/keymap:vi/operator:indent-right {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:increase-indent.impl $((bleopt_indent_offset*arg)) "$context"
}

#--------------------------------------
# Primitive motion

## 関数 ble/widget/vi-command/exclusive-range.impl src dst flag reg nobell
## 関数 ble/widget/vi-command/exclusive-goto.impl index flag reg nobell
## 関数 ble/widget/vi-command/inclusive-goto.impl index flag reg nobell
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
##   @param[in] nobell
##     1 を指定したとき移動前と移動後の位置が同じときにベルを鳴らしません。
##
function ble/widget/vi-command/exclusive-range.impl {
  local src=$1 dst=$2 flag=$3 reg=$4 nobell=$5
  if [[ $flag ]]; then
    ble/keymap:vi/call-operator-charwise "$flag" "$src" "$dst" '' "$reg"; local ext=$?
    ((ext==148)) && return 148
    ((ext)) && ble/widget/.bell
    ble/keymap:vi/adjust-command-mode
    return "$ext"
  else
    ble/keymap:vi/needs-eol-fix "$dst" && ((dst--))
    if ((dst!=_ble_edit_ind)); then
      ble/widget/.goto-char "$dst"
    elif ((!nobell)); then
      ble/widget/vi-command/bell
      return 1
    fi
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/exclusive-goto.impl {
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$@"
}
function ble/widget/vi-command/inclusive-goto.impl {
  local index=$1 flag=$2 reg=$3 nobell=$4
  if [[ $flag ]]; then
    if ((_ble_edit_ind<=index)); then
      ble-edit/content/eolp "$index" || ((index++))
    else
      ble-edit/content/eolp || ble/widget/.goto-char $((_ble_edit_ind+1))
    fi
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg" "$nobell"
}

## 関数 ble/widget/vi-command/linewise-range.impl p q flag reg opts
## 関数 ble/widget/vi-command/linewise-goto.impl index flag reg opts
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

  if [[ $flag ]]; then
    local bolp bolq=$bolx nolq=$nolx
    ble-edit/content/find-logical-bol "$p"; bolp=$ret
    [[ $bolq ]] || { ble-edit/content/find-logical-bol "$qbase" "$qline"; bolq=$ret; }

    # 最初の行の行頭 beg と最後の行の行末 end
    local beg end
    if ((bolp<=bolq)); then
      ble-edit/content/find-logical-eol "$bolq"; beg=$bolp end=$ret
    else
      ble-edit/content/find-logical-eol "$bolp"; beg=$bolq end=$ret
    fi

    # jk+- で1行も移動できない場合は操作をキャンセルする。
    # Note: qline を用いる場合は必ずしも望みどおり
    #   qline 行目が存在するとは限らないことに注意する。
    if [[ :$opts: == *:require_multiline:* ]]; then
      local is_single_line=$((bolq==bolp))
      if ((bolq==bolp)); then
        ble/widget/vi-command/bell
        return 1
      fi
    fi

    ((end<${#_ble_edit_str}&&end++))
    if ! ble/util/isfunction ble/keymap:vi/operator:"$flag"; then
      ble/widget/vi-command/bell
      return 1
    fi

    # オペレータ呼び出し
    ble/keymap:vi/call-operator "$flag" "$beg" "$end" line '' "$reg"; local ext=$?
    if ((ext)); then
      ((ext==148)) && return 148
      ble/widget/vi-command/bell
      return "$ext"
    fi

    # 範囲の先頭に移動
    local ind=$_ble_edit_ind
    if [[ $flag == [cd] ]]; then
      # これらは常に first-non-space になる。
      ble/widget/.goto-char "$beg"
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
      ((ret)) && ble/widget/vi-command/relative-line.impl "$ret"
    elif [[ :$opts: == *:goto_bol:* ]]; then # 行指向 yis
      ble/widget/.goto-char "$beg"
    else # + - gg G L H
      if ((beg==bolq||ind<beg)) || [[ ${_ble_edit_str:beg:ind-beg} == *$'\n'* ]] ; then
        # 先頭行の非空白行頭に移動する
        if ((bolq<=bolp)) && [[ $nolq ]]; then
          local nolb=$nolq
        else
          ble-edit/content/find-non-space "$beg"; local nolb=$ret
        fi
        ble-edit/content/nonbol-eolp "$nolb" && ((nolb--))
        ((ind<beg||nolb<ind)) && ble/widget/.goto-char "$nolb"
      fi
    fi

    ble/keymap:vi/adjust-command-mode
    return 0
  else
    if [[ ! $nolx ]]; then
      if [[ ! $bolx ]]; then
        ble-edit/content/find-logical-bol "$qbase" "$qline"; bolx=$ret
      fi
      ble-edit/content/find-non-space "$bolx"; nolx=$ret
    fi
    ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
    ble/widget/.goto-char "$nolx"
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}
function ble/widget/vi-command/linewise-goto.impl {
  ble/widget/vi-command/linewise-range.impl "$_ble_edit_ind" "$@"
}

#------------------------------------------------------------------------------
# single char arguments

function ble/keymap:vi/async-read-char.hook {
  local command=${@:1:$#-1} key=${@:$#}
  if ((key==(ble_decode_Ctrl|0x6B))); then # C-k
    ble-decode/keymap/push vi_digraph
    _ble_keymap_vi_digraph__hook="$command"
  else
    eval "$command $key"
  fi
}

function ble/keymap:vi/async-read-char {
  _ble_decode_key__hook="ble/keymap:vi/async-read-char.hook $*"
  return 148
}

#------------------------------------------------------------------------------
# marks

## 配列 _ble_keymap_vi_mark_local
##   添字は mark の文字コードで指定する。
##   各要素は point:bytes の形をしている。
## 配列 _ble_keymap_vi_mark_global
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

# mark 番号と用途の対応
#
#
#   1     内部使用。矩形挿入モードの開始点を記録するためのもの
#   91 93 `[ と `]。編集・ヤンク範囲を保持する。
#   96 39 `` と `'。最後のジャンプ位置を保持する。39 は実際には使用されない。
#   60 62 `< と `>。最後のビジュアル範囲。
#

ble/array#push _ble_edit_dirty_observer ble/keymap:vi/mark/shift-by-dirty-range
ble/array#push _ble_edit_history_onleave ble/keymap:vi/mark/history-onleave.hook

function ble/keymap:vi/mark/history-onleave.hook {
  ble/keymap:vi/mark/set-local-mark 34 "$_ble_edit_ind" # `"
}

# 履歴がロードされていない時は取り敢えず _ble_edit_history_ind=0 で登録をしておく。
# 履歴がロードされた後の初めての利用のときに正しい履歴番号に修正する。
function ble/keymap:vi/mark/update-mark-history {
  local h; ble-edit/history/getindex -v h
  if [[ ! $_ble_keymap_vi_mark_hindex ]]; then
    _ble_keymap_vi_mark_hindex=$h
  elif [[ $_ble_keymap_vi_mark_hindex != $h ]]; then
    local imark value

    # save
    local -a save
    for imark in "${!_ble_keymap_vi_mark_local[@]}"; do
      local value=${_ble_keymap_vi_mark_local[imark]}
      ble/array#push save "$imark:$value"
    done
    _ble_keymap_vi_mark_history[_ble_keymap_vi_mark_hindex]=${save[*]}

    # load
    _ble_keymap_vi_mark_local=()
    local entry
    for entry in ${_ble_keymap_vi_mark_history[h]}; do
      imark=${entry%%:*} value=${entry#*:}
      _ble_keymap_vi_mark_local[imark]=$value
    done

    _ble_keymap_vi_mark_hindex=$h
  fi
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
    local h; ble-edit/history/getindex -v h
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
    if [[ $4 == newline && $_ble_decode_key__kmap != vi_cmap ]]; then
      ble/keymap:vi/mark/set-local-mark 96 0 # ``
    fi
  fi
}
function ble/keymap:vi/mark/set-global-mark {
  local c=$1 index=$2
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  local h; ble-edit/history/getindex -v h
  _ble_keymap_vi_mark_global[c]=$h:$bol:$((index-bol))
}
function ble/keymap:vi/mark/set-local-mark {
  local c=$1 index=$2
  ble/keymap:vi/mark/update-mark-history
  ble-edit/content/find-logical-bol "$index"; local bol=$ret
  _ble_keymap_vi_mark_local[c]=$bol:$((index-bol))
}
## 関数 ble/keymap:vi/mark/get-mark.impl index bytes
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
## 関数 ble/keymap:vi/mark/get-mark.impl c
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
function ble/keymap:vi/mark/set-previous-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return
  local beg=$1 end=$2
  ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  ble/keymap:vi/mark/set-local-mark 91 "$beg" # `[
  ble/keymap:vi/mark/set-local-mark 93 "$end" # `]
}
function ble/keymap:vi/mark/start-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return
  ble/dirty-range#clear --prefix=_ble_keymap_vi_mark_edit_d
}
function ble/keymap:vi/mark/commit-edit-area {
  local beg=$1 end=$2
  ble/dirty-range#update --prefix=_ble_keymap_vi_mark_edit_d "$beg" "$end" "$end"
}
function ble/keymap:vi/mark/end-edit-area {
  [[ $_ble_keymap_vi_mark_suppress_edit ]] && return
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
  return 148
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
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg" 1
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
  if [[ $_ble_edit_history_ind != ${data[0]} ]]; then
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
  return 148
}
function ble/widget/vi-command/goto-mark.hook {
  local opts=$1 key=$2
  local ret
  if ble/keymap:vi/k2c "$key" && local c=$ret; then
    if ((65<=c&&c<91)); then # A-Z
      ble/widget/vi-command/goto-global-mark.impl "$c" "$opts"
      return
    elif ((_ble_keymap_vi_mark_Offset<=c)); then
      ((c==39)) && c=96 # `' は `` に読み替える
      ble/widget/vi-command/goto-local-mark.impl "$c" "$opts"
      return
    fi
  fi
  ble/keymap:vi/clear-arg
  ble/widget/vi-command/bell
  return 1
}

#------------------------------------------------------------------------------
# repeat (nmap .)

## 配列 _ble_keymap_vi_repeat
## 配列 _ble_keymap_vi_repeat_insert
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
## 配列 _ble_keymap_vi_repeat_irepeat
##
##   _ble_keymap_vi_repeat の操作によって挿入モードに入るとき、
##   そこで行われる挿入操作の列を記録する配列である。
##   形式は _ble_keymap_vi_irepeat と同じ。
##
## 変数 _ble_keymap_vi_repeat_invoke
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
  local -a repeat; repeat=("$KEYMAP" "${KEYS[*]}" "$WIDGET" "$ARG" "$FLAG" "$REG" '')
  if [[ $KEYMAP == vi_xmap ]]; then
    repeat[6]=$_ble_keymap_vi_xmap_prev_edit
  fi
  if [[ $_ble_decode_key__kmap == vi_imap ]]; then
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
## 関数 ble/keymap:vi/repeat/record-insert
##   挿入モードを抜ける時に、挿入モードに入るきっかけになった操作と、
##   挿入モードで行われた挿入操作の列を記録します。
function ble/keymap:vi/repeat/record-insert {
  ble/keymap:vi/repeat/record-special && return 0
  if [[ $_ble_keymap_vi_repeat_insert ]]; then
    # 挿入モード突入操作が未だ有効ならば、挿入操作の有無に拘らず記録
    _ble_keymap_vi_repeat=("${_ble_keymap_vi_repeat_insert[@]}")
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  elif ((${#_ble_keymap_vi_irepeat[@]})); then
    # 挿入モード突入操作が初期化されていたら、挿入操作がある時のみに記録
    _ble_keymap_vi_repeat=(vi_nmap "${KEYS[*]}" ble/widget/vi_nmap/insert-mode 1 '' '')
    _ble_keymap_vi_repeat_irepeat=("${_ble_keymap_vi_irepeat[@]}")
  fi
  ble/keymap:vi/repeat/clear-insert
}
## 関数 ble/keymap:vi/repeat/clear-insert
##   挿入モードにおいて white list にないコマンドが実行された時に、
##   挿入モードに入るきっかけになった操作を初期化します。
function ble/keymap:vi/repeat/clear-insert {
  _ble_keymap_vi_repeat_insert=
}

function ble/keymap:vi/repeat/invoke {
  local repeat_arg=$_ble_edit_arg
  local repeat_reg=$_ble_keymap_vi_reg
  local KEYMAP=${_ble_keymap_vi_repeat[0]}
  local -a KEYS=(${_ble_keymap_vi_repeat[1]})
  local WIDGET=${_ble_keymap_vi_repeat[2]}
  if [[ $KEYMAP == vi_[onx]map ]]; then
    if [[ $KEYMAP == vi_omap ]]; then
      ble-decode/keymap/push vi_omap
    elif [[ $KEYMAP == vi_xmap ]]; then
      local _ble_keymap_vi_xmap_prev_edit=${_ble_keymap_vi_repeat[6]}
      ble/widget/vi_xmap/.restore-visual-state
      ble-decode/keymap/push vi_xmap
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
    builtin eval -- "$WIDGET"

    if [[ $_ble_decode_key__kmap == vi_imap ]]; then
      ((_ble_keymap_vi_irepeat_count<=1?(_ble_keymap_vi_irepeat_count=2):_ble_keymap_vi_irepeat_count++))
      local -a _ble_keymap_vi_irepeat
      _ble_keymap_vi_irepeat=("${_ble_keymap_vi_repeat_irepeat[@]}")

      ble/array#push _ble_keymap_vi_irepeat '0:ble/widget/dummy' # Note: normal-mode が自分自身を pop しようとするので。
      ble/widget/vi_imap/normal-mode
    fi
    unset _ble_keymap_vi_single_command{,_overwrite}
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

# nmap .
function ble/widget/vi_nmap/repeat {
  ble/keymap:vi/repeat/invoke
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# command: [cdy]?[hl]

## 編集関数 vi-command/forward-char [type]
## 編集関数 vi-command/backward-char [type]
##
##   @param[in] type
##     type=m のとき複数行に亘る移動を許します。
##
function ble/widget/vi-command/forward-char {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local index
  if [[ $1 == multiline ]]; then
    # SP
    local width=$ARG line
    while ((width<=${#_ble_edit_str}-_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=ARG)) && break
      ((width+=ARG-${#line}))
    done
    ((index=_ble_edit_ind+width,index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
    if [[ $_ble_decode_key__kmap != vi_xmap ]]; then
      ((index<${#_ble_edit_str})) && ble-edit/content/nonbol-eolp "$index" && ((index++))
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
  if [[ $1 == multiline ]]; then
    # DEL
    local width=$ARG line
    while ((width<=_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind-width:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=ARG)) && break
      ((width+=ARG-${#line}))
    done
    ((index=_ble_edit_ind-width,index<0&&(index=0)))
    if [[ $_ble_decode_key__kmap != vi_xmap ]]; then
      ble/keymap:vi/needs-eol-fix "$index" && ((index--))
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
  ble/widget/.replace-range "$_ble_edit_ind" "$index" "$ret" 1
  ble/keymap:vi/mark/set-previous-edit-area "$_ble_edit_ind" "$index"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/.goto-char "$index"
  ble/keymap:vi/adjust-command-mode
  return 0
}

#------------------------------------------------------------------------------
# command: [cdy]?[jk]

## 関数 ble/widget/vi-command/.history-relative-line offset
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
  if [[ ! $_ble_edit_history_loaded ]]; then
    ((offset<0)) || return 1
    ble-edit/history/load # to use _ble_edit_history_ind
  fi

  local ret count=$((offset<0?-offset:offset)) exit=1
  ((count--))
  while ((count>=0)); do
    if ((offset<0)); then
      ((_ble_edit_history_ind>0)) || return "$exit"
      ble/widget/history-prev
      ret=${#_ble_edit_str}
      ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
      ble/widget/.goto-char "$ret"
    else
      ((_ble_edit_history_ind<${#_ble_edit_history[@]})) || return "$exit"
      ble/widget/history-next
      ble/widget/.goto-char 0
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
    ble/widget/.goto-char "$ret"
  fi

  return 0
}

## 関数 ble/widget/vi-command/relative-line.impl offset flag reg opts
## 編集関数 vi-command/forward-line  # nmap j
## 編集関数 vi-command/backward-line # nmap k
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
  ((offset==0)) && return
  if [[ $flag ]]; then
    ble/widget/vi-command/linewise-goto.impl "$_ble_edit_ind:$offset" "$flag" "$reg" preserve_column:require_multiline
    return
  fi

  # 現在の履歴項目内での探索
  local count=$((offset<0?-offset:offset))
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
  local beg end; ((bol1<=bol2?(beg=bol1,end=bol2):(beg=bol2,end=bol1)))
  ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nmove=$ret
  ((count-=nmove))
  if ((count==0)); then
    local index
    if ble/keymap:vi/use-textmap; then
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
    ble/widget/.goto-char "$index"
    ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # 履歴項目を行数を数えつつ移動
  if [[ $_ble_decode_key__kmap == vi_nmap && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line $((offset>=0?count:-count)) || ((nmove)); then
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
  ble/widget/vi-command/relative-line.impl $((-ARG)) "$FLAG" "$REG" history
}

## 関数 ble/widget/vi-command/graphical-relative-line.impl offset flag reg opts
## 編集関数 vi-command/graphical-forward-line  # nmap gj
## 編集関数 vi-command/graphical-backward-line # nmap gk
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
  if ble/keymap:vi/use-textmap; then
    local x y ax ay
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((ax=x,ay=y+offset,
      ay<_ble_textmap_begy?(ay=_ble_textmap_begy):
      (ay>_ble_textmap_endy?(ay=_ble_textmap_endy):0)))
    ble/textmap#get-index-at "$ax" "$ay"
    ble/textmap#getxy.cur --prefix=a "$index"
    ((offset-=move=ay-y))
  else
    local ind=$_ble_edit_ind
    ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
    ble-edit/content/find-logical-bol "$ind" "$offset"; local bol2=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))

    local ret
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
    return
  fi

  if [[ ! $flag && $_ble_decode_key__kmap == vi_nmap && :$opts: == *:history:* ]]; then
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
  ble/widget/vi-command/graphical-relative-line.impl $((-ARG)) "$FLAG" "$REG"
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
      ble/widget/vi-command/exclusive-goto.impl "$nolx" "$flag" "$reg" 1
    elif [[ :$opts: == *:multiline:* ]]; then
      # command: + -
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" require_multiline:bolx="$bolx":nolx="$nolx"
    else
      # command: _
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" "$reg" bolx="$bolx":nolx="$nolx"
    fi
    return
  fi

  local count=$((arg<0?-arg:arg)) nmove=0
  if ((count)); then
    local beg end; ((nolx<ind?(beg=nolx,end=ind):(beg=ind,end=nolx)))
    ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; nmove=$ret
    ((count-=nmove))
  fi

  if ((count==0)); then
    ble/keymap:vi/needs-eol-fix "$nolx" && ((nolx--))
    ble/widget/.goto-char "$nolx"
    ble/keymap:vi/adjust-command-mode
    return 0
  fi

  # 履歴項目の移動
  if [[ $_ble_decode_key__kmap == vi_nmap ]] && ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count)); then
    ble/widget/vi-command/first-non-space
  elif ((nmove)); then
    ble/widget/vi-command/first-non-space
  else
    ble/widget/vi-command/bell
    return 1
  fi
}
# nmap ^
function ble/widget/vi-command/first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl 0 "$FLAG" "$REG" charwise
}
# nmap +
function ble/widget/vi-command/forward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$ARG" "$FLAG" "$REG" multiline
}
# nmap -
function ble/widget/vi-command/backward-first-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl $((-ARG)) "$FLAG" "$REG" multiline
}
# nmap _
function ble/widget/vi-command/first-non-space-forward {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl $((ARG-1)) "$FLAG" "$REG"
}
# nmap $
function ble/widget/vi-command/forward-eol {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  if ((ARG>1)) && [[ ${_ble_edit_str:_ble_edit_ind}  != *$'\n'* ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  local ret index
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((ARG-1)); index=$ret
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" 1
  [[ $_ble_decode_key__kmap == vi_xmap ]] &&
    ble/keymap:vi/xmap/add-eol-extension # 末尾拡張
}
# nmap g0 g<home>
function ble/widget/vi-command/beginning-of-graphical-line {
  if ble/keymap:vi/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" 1
  else
    ble/widget/vi-command/beginning-of-line
  fi
}
# nmap g^
function ble/widget/vi-command/graphical-first-non-space {
  if ble/keymap:vi/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    ble/widget/vi-command/exclusive-goto.impl "$ret" "$FLAG" "$REG" 1
  else
    ble/widget/vi-command/first-non-space
  fi
}
# nmap g$ g<end>
function ble/widget/vi-command/graphical-forward-eol {
  if ble/keymap:vi/use-textmap; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at $((_ble_textmap_cols-1)) $((y+ARG-1))
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" 1
  else
    ble/widget/vi-command/forward-eol
  fi
}
# nmap gm
function ble/widget/vi-command/middle-of-graphical-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local index
  if ble/keymap:vi/use-textmap; then
    local x y
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at $((_ble_textmap_cols/2)) "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  else
    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-logical-eol; local eol=$ret
    ((index=(bol+${COLUMNS:-eol})/2,
      index>eol&&(index=eol),
      bol<eol&&index==eol&&(index--)))
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" 1
}
# nmap g_
function ble/widget/vi-command/last-non-space {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((ARG-1)); local index=$ret
  local rex=$'([^ \t\n]?[ \t]+|[^ \t\n])$'
  [[ ${_ble_edit_str::index} =~ $rex ]] && ((index-=${#BASH_REMATCH}))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" 1
}

#------------------------------------------------------------------------------
# command: p P

## 関数 ble/widget/vi_nmap/paste.impl/block arg [type]
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
    ble/keymap:vi/use-textmap && graphical=1
  fi

  local ret cols=$_ble_textmap_cols

  local -a afill=(${_ble_edit_kill_type:2})
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

  local -a ins_beg ins_end ins_text
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
      ble/textmap#get-index-at "$x" $((by+y)); ((index>eol&&(index=eol)))

      # left padding (行末がより左にある、または、全角文字があるとき)
      local ax ay ac; ble/textmap#getxy.out --prefix=a "$index"
      ((ay-=by,ac=ay*cols+ax))
      if ((ac<c)); then
        ble/string#repeat ' ' $((c-ac))
        text=$ret$text

        # タブを空白に変換
        if ((index<eol)) && [[ ${_ble_edit_str:index:1} == $'\t' ]]; then
          local rx ry rc; ble/textmap#getxy.out --prefix=r $((index+1))
          ((rc=(ry-by)*cols+rx))
          ble/string#repeat ' ' $((rc-c))
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
        ble/string#repeat ' ' $((index-eol))
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
    ble/widget/.replace-range "$ibeg" "$iend" "$text" 1
  done
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
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

    ble/widget/.replace-range "$index" "$index" "$content" 1
    ble/widget/.goto-char "$dbeg"
    ble/keymap:vi/mark/set-previous-edit-area "$dbeg" "$dend"
    ble/keymap:vi/repeat/record
    ble/widget/vi-command/first-non-space
  elif [[ $_ble_edit_kill_type == B:* ]]; then
    if ((is_after)) && ! ble-edit/content/eolp; then
      ble/widget/.goto-char $((_ble_edit_ind+1))
    fi
    ble/widget/vi_nmap/paste.impl/block "$arg"
  else
    if ((is_after)) && ! ble-edit/content/eolp; then
      ble/widget/.goto-char $((_ble_edit_ind+1))
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    local beg=$_ble_edit_ind
    ble/widget/insert-string "$ret"
    local end=$_ble_edit_ind
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
    [[ $_ble_keymap_vi_single_command ]] || ble/widget/.goto-char $((_ble_edit_ind-1))
    ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
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
  local b=$'[ \t]' n=$'\n'
  local rex="^((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$reg"
}
function ble/widget/vi-command/forward-word-end.impl {
  local arg=$1 flag=$2 reg=$3 rex_word=$4
  local IFS=$' \t\n'
  local rex="^([$IFS]*($rex_word)?){0,$arg}" # 単語末端に止まる。空行には止まらない
  [[ ${_ble_edit_str:_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  [[ $BASH_REMATCH && ${_ble_edit_str:index:1} == [$IFS] ]] && ble/widget/.bell
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

function ble/widget/vi-command/forward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
function ble/widget/vi-command/forward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
function ble/widget/vi-command/backward-vword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
function ble/widget/vi-command/backward-vword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$ARG" "$FLAG" "$REG" "$_ble_keymap_vi_REX_WORD"
}
function ble/widget/vi-command/forward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
function ble/widget/vi-command/forward-uword-end {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
function ble/widget/vi-command/backward-uword {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$ARG" "$FLAG" "$REG" $'[^ \t\n]+'
}
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
  if ble/keymap:vi/use-textmap; then
    local bx by; ble/textmap#getxy.cur --prefix=b "$bol" # Note: 先頭行はプロンプトにより bx!=0
    local ex ey; ble/textmap#getxy.cur --prefix=e "$eol"
    local dstx=$((bx+ARG-1)) dsty=$by cols=${COLUMNS:-80}
    ((dsty+=dstx/cols,dstx%=cols))
    ((dsty>ey&&(dsty=ey,dstx=ex)))
    ble/textmap#get-index-at "$dstx" "$dsty" # local variable "index" is set here

    # Note: 何故かノーマルモードで d や c を実行するときには行末に行かないのに、
    # ビジュアルモードでは行末に行くことができるようだ。
    [[ $_ble_decode_key__kmap != vi_xmap ]] &&
      ble-edit/content/nonbol-eolp "$index" && ((index--))
  else
    [[ $_ble_decode_key__kmap != vi_xmap ]] &&
      ble-edit/content/nonbol-eolp "$eol" && ((eol--))
    ((index=bol+ARG-1,index>eol?(index=eol)))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" 1
}

# nmap H
function ble/widget/vi-command/nth-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl 0:$((ARG-1)) "$FLAG" "$REG"
}
# nmap L
function ble/widget/vi-command/nth-last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  ble/widget/vi-command/linewise-goto.impl ${#_ble_edit_str}:$((-(ARG-1))) "$FLAG" "$REG"
}

## gg in history
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
    return
  fi

  if ((ARG)); then
    ble-edit/history/goto $((ARG-1))
  else
    ble/widget/history-beginning
  fi
  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/keymap:vi/adjust-command-mode
  return 0
}

# G in history
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
    return
  fi

  if ((ARG)); then
    ble-edit/history/goto $((ARG-1))
  else
    ble/widget/history-end
  fi
  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/keymap:vi/adjust-command-mode
  return 0
}

# G in the current history entry
function ble/widget/vi-command/last-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  [[ $FLAG ]] || ble/keymap:vi/mark/set-jump # ``
  if ((ARG)); then
    ble/widget/vi-command/linewise-goto.impl 0:$((ARG-1)) "$FLAG" "$REG"
  else
    ble/widget/vi-command/linewise-goto.impl ${#_ble_edit_str}:0 "$FLAG" "$REG"
  fi
}

function ble/widget/vi-command/clear-screen-and-first-non-space {
  ble/widget/vi-command/first-non-space; local ext=$?
  ble/widget/clear-screen
  return "$ext"
}
function ble/widget/vi-command/redraw-line-and-first-non-space {
  ble/widget/vi-command/first-non-space; local ext=$?
  ble/widget/redraw-line
  return "$ext"
}
function ble/widget/vi-command/clear-screen-and-last-line {
  ble/widget/vi-command/last-line; local ext=$?
  ble/widget/redraw-line
  return "$ext"
}

#------------------------------------------------------------------------------
# command: r gr

## 関数 ble/widget/vi_nmap/replace-char.impl code [overwrite_mode]
##   @param[in] overwrite_mode
##     置換する文字の挿入方法を指定します。
function ble/widget/vi_nmap/replace-char.impl {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  if ((key==(ble_decode_Ctrl|91))); then # C-[
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
    unset KEYS
  }
  ble/keymap:vi/mark/end-edit-area
  ble/keymap:vi/repeat/record

  ((pos<_ble_edit_ind)) && ble/widget/.goto-char _ble_edit_ind-1
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
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((ARG<=1?1:ARG-1)); local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:eol2-eol1}
    text=${text//$'\n'/' '}
    ble/widget/.replace-range "$eol1" "$eol2" "$text"
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" "$eol2"
    ble/keymap:vi/repeat/record
    ble/widget/.goto-char $((bol2-1))
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
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((ARG<=1?1:ARG-1)); local eol2=$ret
  ble-edit/content/find-logical-bol "$eol2"; local bol2=$ret
  if ((eol1<eol2)); then
    local text=${_ble_edit_str:eol1:bol2-eol1}
    text=${text//$'\n'}
    ble/widget/.replace-range "$eol1" "$bol2" "$text"
    local delta=$((${#text}-(bol2-eol1)))
    ble/keymap:vi/mark/set-previous-edit-area "$eol1" $((eol2+delta))
    ble/keymap:vi/repeat/record
    ble/widget/.goto-char $((bol2+delta))
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
  ble/widget/.goto-char "$eol"
  ble/widget/insert-string $'\n'"$indent"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}
function ble/widget/vi_nmap/insert-mode-at-backward-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
  ble/widget/.goto-char "$bol"
  ble/widget/insert-string "$indent"$'\n'
  ble/widget/.goto-char $((bol+${#indent}))
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  return 0
}

#------------------------------------------------------------------------------
# command: f F t F


## 変数 _ble_keymap_vi_char_search
##   前回の ble/widget/vi-command/search-char.impl/core の検索を記録します。
_ble_keymap_vi_char_search=

## 関数 ble/widget/vi-command/search-char.impl/core opts key|char
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
  elif ((key==(ble_decode_Ctrl|91))); then # C-[ -> cancel
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
    ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" 1
    return
  else
    # forward search
    ble-edit/content/find-logical-eol; local eol=$ret
    local base=$((_ble_edit_ind+1))
    ((isrepeat&&isprev&&base++,base<eol)) || return 1

    local line=${_ble_edit_str:base:eol-base}
    ble/string#index-of "$line" "$c" "$ARG"
    ((ret>=0)) || return 1

    ((index=base+ret,isprev&&index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" 1
    return
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

## @var[in] _ble_edit_str, ch1, ch2, index
## @var[out] ret
function ble/widget/vi-command/search-matchpair/.search-forward {
  ble/string#index-of-chars "$_ble_edit_str" "$ch1$ch2" $((index+1))
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
    return
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
  ble/widget/vi-command/inclusive-goto.impl "$index" "$FLAG" "$REG" 1
}

function ble/widget/vi-command/percentage-line {
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  local iline=$(((ARG*nline+99)/100))
  ble/widget/vi-command/linewise-goto.impl 0:$((iline-1)) "$FLAG" "$REG"
}

#------------------------------------------------------------------------------
# command: go

function ble/widget/vi-command/nth-byte {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  ((ARG--))
  local offset=0 text=$_ble_edit_str len=${#_ble_edit_str}
  local left nleft
  while ((ARG>0&&len>1)); do
    left=${text::len/2}
    LC_ALL=C builtin eval 'nleft=${#left}'
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
  ble/widget/vi-command/exclusive-goto.impl "$offset" "$FLAG" "$REG" 1
}

#------------------------------------------------------------------------------
# text objects

_ble_keymap_vi_text_object=

## 関数 ble/keymap:vi/text-object/word.impl      arg flag reg type
## 関数 ble/keymap:vi/text-object/quote.impl     arg flag reg type
## 関数 ble/keymap:vi/text-object/block.impl     arg flag reg type
## 関数 ble/keymap:vi/text-object/tag.impl       arg flag reg type
## 関数 ble/keymap:vi/text-object/sentence.impl  arg flag reg type
## 関数 ble/keymap:vi/text-object/paragraph.impl arg flag reg type
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##

function ble/keymap:vi/text-object/word.impl {
  local arg=$1 flag=$2 reg=$3 type=$4

  local space=$' \t' nl=$'\n' ifs=$' \t\n'

  local rex_word
  if [[ $type == ?W ]]; then
    rex_word="[^$ifs]+"
  else
    rex_word=$_ble_keymap_vi_REX_WORD
  fi

  local rex_words
  if [[ $type == i* ]]; then
    rex_words="(($rex_word)$nl?|[$space]+$nl?){$arg}"
  else
    local rex1=
    ((arg>1)) && rex1="(($rex_word)[$ifs]+){$((arg-1))}"
    rex_words="([$ifs]+($rex_word)){$arg}|$rex1($rex_word)[$space]*"
  fi

  local index=$_ble_edit_ind
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    if ((index<_ble_edit_mark)); then
      ((index)) && [[ ${_ble_edit_str:index-1:1} == $'\n' ]] && ((index--))
      if local rex="($rex_words)\$"; [[ ${_ble_edit_str::index} =~ $rex ]]; then
        index=$((index-${#BASH_REMATCH}))
        [[ ${_ble_edit_str:index:1} == $'\n' ]] && ((index++))
      else
        index=0
        ble/widget/.bell
      fi
      ble/widget/.goto-char "$index"
      ble/keymap:vi/adjust-command-mode
      return 0
    fi

    ble-edit/content/eolp || ((index++))
    [[ ${_ble_edit_str:index:1} == $'\n' ]] && ((index++))
  fi

  local rex="(($rex_word)|[$space]+)\$"
  [[ ${_ble_edit_str::index+1} =~ $rex ]]
  local beg=$((index+1-${#BASH_REMATCH}))

  if rex="^($rex_words)"; ! [[ ${_ble_edit_str:index} =~ $rex ]]; then
    index=${#_ble_edit_str}
    ble-edit/content/nonbol-eolp "$index" && ((index--))
    ble/widget/.goto-char "$index"
    ble/widget/vi-command/bell
    return 1
  fi
  local end=$((index+${#BASH_REMATCH}))

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    ((end--))
    ble-edit/content/nonbol-eolp "$end" && ((end--))
    ble/widget/.goto-char "$end"
    ble/keymap:vi/adjust-command-mode
    return 0
  else
    [[ ${_ble_edit_str:end-1:1} == "$nl" ]] && ((end--))
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

function ble/keymap:vi/text-object/find-next-quote {
  local index=${1:-$((_ble_edit_ind+1))} nl=$'\n'
  local rex="^[^$nl$quote]*$quote"
  [[ ${_ble_edit_str:index} =~ $rex ]] || return 1
  ((ret=index+${#BASH_REMATCH}))
  return 0
}
function ble/keymap:vi/text-object/find-previous-quote {
  local index=${1:-_ble_edit_ind} nl=$'\n'
  local rex="$quote[^$nl$quote]*\$"
  [[ ${_ble_edit_str::index} =~ $rex ]] || return 1
  ((ret=index-${#BASH_REMATCH}))
  return 0
}
function ble/keymap:vi/text-object/quote.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret quote=${type:1}

  local beg= end=
  if [[ ${_ble_edit_str:_ble_edit_ind:1} == "$quote" ]]; then
    ble-edit/content/find-logical-bol; local bol=$ret
    ble/string#count-char "${_ble_edit_str:bol:_ble_edit_ind-bol}" "$quote"
    if ((ret%2==1)); then
      # 現在終了引用符
      ((end=_ble_edit_ind+1))
      ble/keymap:vi/text-object/find-previous-quote && beg=$ret
    else
      ((beg=_ble_edit_ind))
      ble/keymap:vi/text-object/find-next-quote && end=$ret
    fi
  elif ble/keymap:vi/text-object/find-previous-quote && beg=$ret; then
    ble/keymap:vi/text-object/find-next-quote && end=$ret
  elif ble/keymap:vi/text-object/find-next-quote && beg=$((ret-1)); then
    ble/keymap:vi/text-object/find-next-quote "$((beg+1))" && end=$ret
  fi

  # Note: ビジュアルモードでは繰り返し使うと範囲を拡大する (?) らしい
  if [[ $beg && $end ]]; then
    [[ $type == i* || arg -gt 1 ]] && ((beg++,end--))
    if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
      _ble_edit_mark="$beg"
      ble/widget/vi-command/exclusive-goto.impl "$end"
    else
      ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
    fi
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/keymap:vi/text-object/block.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  local ret paren=${type:1} lparen=${type:1:1} rparen=${type:2:1}
  local axis=$_ble_edit_ind
  [[ ${_ble_edit_str:axis:1} == "$lparen" ]] && ((axis++))

  local count=$arg beg=$axis
  while ble/string#last-index-of-chars "$_ble_edit_str" "$paren" "$beg"; do
    beg=$ret
    if [[ ${_ble_edit_str:beg:1} == "$lparen" ]]; then
      ((--count==0)) && break
    else
      ((++count))
    fi
  done
  if ((count)); then
    ble/widget/vi-command/bell
    return 1
  fi

  local count=$arg end=$axis
  while ble/string#index-of-chars "$_ble_edit_str" "$paren" "$end"; do
    end=$((ret+1))
    if [[ ${_ble_edit_str:end-1:1} == "$rparen" ]]; then
      ((--count==0)) && break
    else
      ((++count))
    fi
  done
  if ((count)); then
    ble/widget/vi-command/bell
    return 1
  fi

  local linewise=
  if [[ $type == *i* ]]; then
    ((beg++,end--))
    [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
    ((beg<end)) && ble-edit/content/bolp "$end" && ((end--))
    ((beg<end)) && ble-edit/content/bolp "$beg" && ble-edit/content/eolp "$end" && linewise=1
  fi

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    _ble_edit_mark="$beg"
    ble/widget/vi-command/exclusive-goto.impl "$end"
  elif [[ $linewise ]]; then
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## 関数 ble/keymap:vi/text-object/tag.impl/.find-end-tag
##   @var[in] beg
##   @var[out] end
function ble/keymap:vi/text-object/tag.impl/.find-end-tag {
  local ifs=$' \t\n' ret rex

  rex="^<([^$ifs/>!]+)"; [[ ${_ble_edit_str:beg} =~ $rex ]] || return 1
  ble/string#escape-for-bash-regex "${BASH_REMATCH[1]}"; local tagname=$ret
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

  local ifs=$' \t\n'

  local beg=$pivot count=$arg
  rex="<([^$ifs/>!]+([$ifs]+([^>]*[^/])?)?|/[^>]*)>\$"
  while ble/string#last-index-of-chars "${_ble_edit_str::beg}" '>' && beg=$ret; do
    [[ ${_ble_edit_str::beg+1} =~ $rex ]] || continue
    ((beg-=${#BASH_REMATCH}-1))

    if [[ ${BASH_REMATCH::2} == '</' ]]; then
      ((++count))
    else
      if ((--count==0)); then
        if ble/keymap:vi/text-object/tag.impl/.find-end-tag "$beg" && ((_ble_edit_ind<end)); then
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
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    _ble_edit_mark="$beg"
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## 関数 ble/keymap:vi/text-object/sentence.impl/.beg
##   @var[out] beg
##   @var[out] is_interval
##   @var[in] LF, HT
function ble/keymap:vi/text-object/sentence.impl/.beg {
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
    rex="^.*((^$LF?|$LF$LF)([ $HT]*)|[.!?][])'\"]*([ $HT$LF]+))"
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
## 関数 ble/keymap:vi/text-object/sentence.impl/.next {
##   @var[in,out] end
##   @var[in,out] is_interval
##   @var[in] LF, HT
function ble/keymap:vi/text-object/sentence.impl/.next {
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
    elif rex="(([.!?][])\"']*)[ $HT$LF]|$LF$LF).*\$"; [[ ${_ble_edit_str:end} =~ $rex ]]; then
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
  local LF=$'\n' HT=$'\t'
  local rex

  local beg is_interval
  ble/keymap:vi/text-object/sentence.impl/.beg

  local end=$beg i n=$arg
  [[ $type != i* ]] && ((n*=2))
  for ((i=0;i<n;i++)); do
    ble/keymap:vi/text-object/sentence.impl/.next
  done
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

  # at は後方 (forward) に空白を確保できなければ前方 (backward) に空白を確保する。
  if [[ $type != i* && ! $is_interval ]]; then
    local ifs=$' \t\n'
    if ((end)) && [[ ${_ble_edit_str:end-1:1} != ["$ifs"] ]]; then
      rex="^.*(^$LF?|$LF$LF|[.!?][])'\"]*([ $HT$LF]))([ $HT$LF]*)\$"
      if [[ ${_ble_edit_str::beg} =~ $rex ]]; then
        local rematch2=${BASH_REMATCH[2]}
        local rematch3=${BASH_REMATCH[3]}
        ((beg-=${#rematch2}+${#rematch3}))
        [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
      fi
    fi
  fi

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    _ble_edit_mark="$beg"
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
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    _ble_edit_mark="$beg"
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" "$reg"
  fi
}

## 関数 ble/keymap:vi/text-object.impl
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##
function ble/keymap:vi/text-object.impl {
  local arg=$1 flag=$2 reg=$3 type=$4
  case "$type" in
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

function ble/keymap:vi/.check-text-object {
  ble-decode-key/ischar "${KEYS[0]}" || return 1

  local ret; ble/util/c2s "${KEYS[0]}"; local c="$ret"
  [[ $c == [ia] ]] || return 1

  [[ $_ble_keymap_vi_opfunc || $_ble_decode_key__kmap == vi_xmap ]] || return 1

  _ble_keymap_vi_text_object=$c
  _ble_decode_key__hook=ble/keymap:vi/text-object.hook
  return 0
}

function ble/widget/vi-command/text-object {
  ble/keymap:vi/.check-text-object && return 0
  ble/widget/vi-command/bell
  return 1
}

#------------------------------------------------------------------------------
# Command
#
# map: :cmd

function ble/keymap:vi/commandline/__before_command__ {
  if [[ ! $_ble_edit_str ]] && ((KEYS[0]==127||KEYS[0]==(104|ble_decode_Ctrl))); then # DEL or C-h
    ble/widget/vi_cmap/cancel
    WIDGET=
  fi
}

function ble/widget/vi-command/commandline {
  ble/keymap:vi/async-commandline-mode ble/widget/vi-command/commandline.hook
  _ble_edit_PS1=:
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/__before_command__
  return 148
}
function ble/widget/vi-command/commandline.hook {
  local command
  ble/string#split command $' \t\n' "$1"
  local cmd="ble/widget/vi-command:${command[0]}"
  if ble/util/isfunction "$cmd"; then
    "$cmd" "${command[@]:1}"
  else
    ble/widget/vi-command/bell "unknown command $1"
    return 1
  fi
}

function ble/widget/vi-command:w {
  if [[ $1 ]]; then
    builtin history -a "$1"
    local file=$1
  else
    builtin history -a
    local file=${HISTFILE:-'~/.bash_history'}
  fi
  local wc; ble/util/assign wc 'wc "$file"'; wc=($wc)
  ble-edit/info/show text "\"$file\" ${wc[0]}L, ${wc[2]}C written"
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
function ble-highlight-layer:region/mark:search/get-selection {
  ble-highlight-layer:region/mark:char/get-selection
}
function ble/keymap:vi/search/matched {
  [[ $_ble_keymap_vi_search_matched || $_ble_edit_mark_active == search || $_ble_keymap_vi_search_activate ]]
}
## 関数 ble/keymap:vi/search/invoke-search needle opts
##   @var[in] needle
##   @var[in,opt] opts
##   @var[out] beg end
function ble/keymap:vi/search/invoke-search {
  local ind=$_ble_edit_ind

  # 検索開始位置
  if ((opt_optional_next)); then
    if ((!opt_backward)); then
      ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
    fi
  elif ((opt_locate)) || ! ble/keymap:vi/search/matched; then
    # 何にも一致していない状態から
    if ((opt_backward)); then
      ble-edit/content/eolp || ((_ble_edit_ind++))
    fi
  else
    # _ble_edit_ind .. _ble_edit_mark[+1] に一致しているとき
    if ((!opt_backward)); then
      if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
        # vi_xmap では _ble_edit_mark は別の用途に使われていて
        # 終端点の情報が失われているので再度一致を試みる。
        if ble-edit/isearch/search "$@" && ((beg==_ble_edit_ind)); then
          _ble_edit_ind=$end
        else
          ((_ble_edit_ind<${#_ble_edit_str&&_ble_edit_ind++))
        fi
      else
        ((_ble_edit_ind=_ble_edit_mark))
        ble-edit/content/eolp || ((_ble_edit_ind++))
      fi
    fi
  fi

  ble-edit/isearch/search "$@"; local ret=$?
  _ble_edit_ind=$ind
  return "$ret"
}

## 関数 ble/widget/vi-command/search.core
##
##   @var[in] needle
##   @var[in] opt_backward history
##   @var[in] opt_history
##   @var[in] opt_locate
##   @var[in] start dir
##   @var[in] ntask
##
function ble/widget/vi-command/search.core {
  local beg= end= is_empty_match=
  if ble/keymap:vi/search/invoke-search "$needle" "$dir:regex"; then
    if ((beg<end)); then
      ble-edit/content/bolp "$end" || ((end--))
      _ble_edit_ind=$beg # eol 補正は search.impl 側で最後に行う
      [[ $_ble_decode_key__kmap != vi_xmap ]] && _ble_edit_mark=$end
      _ble_keymap_vi_search_activate=search
      return 0
    else
      # vim では空一致は即座に失敗のようだ。
      # 続きを検索するということはしない。
      opt_history=
      is_empty_match=1
    fi
  fi

  if ((opt_history)) && [[ $_ble_edit_history_loaded || opt_backward -ne 0 ]]; then
    ble-edit/history/load
    local index=$_ble_edit_history_ind
    [[ $start ]] || start=$index
    if ((opt_backward)); then
      ((index--))
    else
      ((index++))
    fi

    local _ble_edit_isearch_dir=$dir
    local _ble_edit_isearch_str=$needle
    local isearch_ntask=$ntask
    local isearch_time=0
    if ((opt_backward)); then
      ble-edit/isearch/backward-search-history-blockwise regex:progress
    else
      ble-edit/isearch/forward-search-history regex:progress
    fi; local r=$?
    ble-edit/info/default

    if ((r==0)); then
      [[ $index != "$_ble_edit_history_ind" ]] &&
        ble-edit/history/goto "$index"
      if ((opt_backward)); then
        local i=${#_ble_edit_str}
        ble/keymap:vi/needs-eol-fix "$i" && ((i--))
        ble/widget/.goto-char "$i"
      else
        ble/widget/.goto-char 0
      fi

      opt_locate=1 opt_history=0 ble/widget/vi-command/search.core
      return
    fi
  fi

  if ((!opt_optional_next)); then
    if [[ $is_empty_match ]]; then
      ble/widget/.bell "search: empty match"
    else
      ble/widget/.bell "search: not found"
    fi
    if [[ $_ble_edit_mark_active == search ]]; then
      _ble_keymap_vi_search_activate=search
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
    # / ?
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
  if [[ $FLAG || $_ble_decode_key__kmap == vi_xmap ]]; then
    opt_history=0
  else
    local old_hindex; ble-edit/history/getindex -v old_hindex
  fi

  local start= # 初めの履歴番号。search.core 内で最初に履歴を読み込んだあとで設定される。
  local dir=+; ((opt_backward)) && dir=-
  local ntask=$ARG
  while ((ntask)); do
    ble/widget/vi-command/search.core || break
    ((ntask--))
  done

  if [[ $FLAG ]]; then
    if ((ntask)); then
      # 検索対象が見つからなかったとき
      _ble_keymap_vi_search_activate=
      ble/widget/.goto-char "$original_ind"
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
      ble/widget/.goto-char "$original_ind"
      ble/widget/vi-command/exclusive-goto.impl "$index" "$FLAG" "$REG" 1
    fi
  else
    if ((ntask<ARG)); then
      # 同じ履歴項目内でのジャンプ
      if ((opt_history)); then
        local new_hindex; ble-edit/history/getindex -v new_hindex
        ((new_hindex==old_hindex))
      fi && ble/keymap:vi/mark/set-local-mark 96 "$original_index" # ``

      # 行末補正
      if ble/keymap:vi/needs-eol-fix; then
        if ((!opt_backward&&_ble_edit_ind<_ble_edit_mark)); then
          ble/widget/.goto-char $((_ble_edit_ind+1))
        else
          ble/widget/.goto-char $((_ble_edit_ind-1))
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
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/__before_command__
  return 148
}
function ble/widget/vi-command/search-backward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl -:history'
  _ble_edit_PS1='?'
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/commandline/__before_command__
  return 148
}
function ble/widget/vi-command/search-repeat {
  ble/widget/vi-command/search.impl repeat:+
}
function ble/widget/vi-command/search-reverse-repeat {
  ble/widget/vi-command/search.impl repeat:-
}

#------------------------------------------------------------------------------

## 関数 ble/keymap:vi/setup-map
## @var[in] ble_bind_keymap
function ble/keymap:vi/setup-map {
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
  ble-bind -f 'g ~' 'vi-command/operator toggle_case'
  ble-bind -f 'g u' 'vi-command/operator u'
  ble-bind -f 'g U' 'vi-command/operator U'
  ble-bind -f 'g ?' 'vi-command/operator rot13'
  # ble-bind -f 'g @' 'vi-command/operator @' # (operatorfunc opfunc)
  # ble-bind -f '!'   'vi-command/operator !' # コマンド
  # ble-bind -f '='   'vi-command/operator =' # インデント (equalprg, ep)
  # ble-bind -f 'g q' 'vi-command/operator q' # 整形?
  # ble-bind -f 'z f' 'vi-command/operator f'

  ble-bind -f home  vi-command/beginning-of-line
  ble-bind -f '$'   vi-command/forward-eol
  ble-bind -f end   vi-command/forward-eol
  ble-bind -f '^'   vi-command/first-non-space
  ble-bind -f '_'   vi-command/first-non-space-forward
  ble-bind -f '+'   vi-command/forward-first-non-space
  ble-bind -f 'C-m' vi-command/forward-first-non-space
  ble-bind -f 'RET' vi-command/forward-first-non-space
  ble-bind -f '-'   vi-command/backward-first-non-space
  ble-bind -f 'g 0'    vi-command/beginning-of-graphical-line
  ble-bind -f 'g home' vi-command/beginning-of-graphical-line
  ble-bind -f 'g ^'    vi-command/graphical-first-non-space
  ble-bind -f 'g $'    vi-command/graphical-forward-eol
  ble-bind -f 'g end'  vi-command/graphical-forward-eol
  ble-bind -f 'g m'    vi-command/middle-of-graphical-line
  ble-bind -f 'g _'    vi-command/last-non-space

  ble-bind -f h     vi-command/backward-char
  ble-bind -f l     vi-command/forward-char
  ble-bind -f left  vi-command/backward-char
  ble-bind -f right vi-command/forward-char
  ble-bind -f C-h   'vi-command/backward-char multiline'
  ble-bind -f DEL   'vi-command/backward-char multiline'
  ble-bind -f SP    'vi-command/forward-char multiline'

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
  ble-bind -f C-home vi-command/nth-line
  ble-bind -f C-end  vi-command/last-line

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

  ble-bind -f '`' 'vi-command/goto-mark'
  ble-bind -f \'  'vi-command/goto-mark line'

  # bash
  ble-bind -cf 'C-z' fg
}

function ble-decode-keymap:vi_omap/define {
  local ble_bind_keymap=vi_omap
  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi_omap/__default__

  ble-bind -f a   vi-command/text-object
  ble-bind -f i   vi-command/text-object

  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'
  ble-bind -f '?' 'vi-command/operator rot13'
}

#------------------------------------------------------------------------------
# Normal mode

# nmap C-d
function ble/widget/vi-command/exit-on-empty-line {
  if [[ $_ble_edit_str ]]; then
    ble/widget/vi-command/bell
    return 1
  else
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
    return 1
  fi
}

# nmap C-g (show line and column)
function ble/widget/vi-command/show-line-info {
  local index count
  ble-edit/history/getindex -v index
  ble-edit/history/getcount -v count
  local hist_ratio=$(((100*index+count-1)/count))%
  local hist_stat=$'!\e[32m'$index$'\e[m / \e[32m'$count$'\e[m (\e[32m'$hist_ratio$'\e[m)'

  local ret
  ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$((ret+1))
  local line_ratio=$(((100*iline+nline-1)/nline))%
  local line_stat=$'line \e[34m'$iline$'\e[m / \e[34m'$nline$'\e[m --\e[34m'$line_ratio$'\e[m--'

  ble-edit/info/show raw "\"$hist_stat\" $line_stat"
  ble/keymap:vi/adjust-command-mode
  return 0
}

# nmap C-c (jobs)
function ble/widget/vi-command/cancel {
  if [[ $_ble_keymap_vi_single_command ]]; then
    _ble_keymap_vi_single_command=
    _ble_keymap_vi_single_command_overwrite=
    ble/keymap:vi/update-mode-name
  else
    local joblist; ble/util/joblist
    if ((${#joblist[*]})); then
      ble/array#push joblist $'Type  \e[35m:q!\e[m  and press \e[35m<Enter>\e[m to abandon all \e[31mjobs\e[m and exit Bash'
      IFS=$'\n' eval 'ble-edit/info/show raw "${joblist[*]}"'
    else
      ble-edit/info/show raw $'Type  \e[35m:q\e[m  and press \e[35m<Enter>\e[m to exit Bash'
    fi
  fi
  ble/widget/vi-command/bell
  return 0
}


function ble-decode-keymap:vi_nmap/define {
  local ble_bind_keymap=vi_nmap

  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi-command/decompose-meta
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

  ble-bind -f .      vi_nmap/repeat

  ble-bind -f K      command-help

  ble-bind -f 'z t'   clear-screen
  ble-bind -f 'z z'   redraw-line # 中央
  ble-bind -f 'z b'   redraw-line # 最下行
  ble-bind -f 'z RET' vi-command/clear-screen-and-first-non-space
  ble-bind -f 'z C-m' vi-command/clear-screen-and-first-non-space
  ble-bind -f 'z +'   vi-command/clear-screen-and-last-line
  ble-bind -f 'z -'   vi-command/redraw-line-and-first-non-space # 中央
  ble-bind -f 'z .'   vi-command/redraw-line-and-first-non-space # 最下行

  ble-bind -f m      vi-command/set-mark
  ble-bind -f '"'    vi-command/register

  ble-bind -f 'C-g' vi-command/show-line-info

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-j' 'vi-command/accept-line'
  ble-bind -f 'C-m' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'
  ble-bind -f 'RET' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'

  ble-bind -f 'C-l' clear-screen

  ble-bind -f C-d vi-command/exit-on-empty-line
}

#------------------------------------------------------------------------------
# Visual mode


# 選択の種類は _ble_edit_mark_active に設定される文字列で区別する。
#
#   _ble_edit_mark_active は char, line, block のどれかである
#   更に末尾拡張 (行末までの選択範囲の拡張) が設定されているときには
#   char+, line+, block+ などの様に + が末尾に付く。

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


# 矩形範囲の抽出

## 関数 local p0 q0 lx ly rx ry; ble/keymap:vi/get-graphical-rectangle [index1 [index2]]
## 関数 local p0 q0 lx ly rx ry; ble/keymap:vi/get-logical-rectangle   [index1 [index2]]
##
##   @param[in,opt] index1 [=_ble_edit_mark]
##   @param[in,opt] index2 [=_ble_edit_ind]
##
##   @var[out] p0 q0
##   @var[out] lx ly rx ry
##
function ble/keymap:vi/get-graphical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret

  local p0x p0y q0x q0y
  ble/textmap#getxy.out --prefix=p0 "$p0"
  ble/textmap#getxy.out --prefix=q0 "$q0"

  local plx ply qlx qly
  ble/textmap#getxy.cur --prefix=pl "$p"
  ble/textmap#getxy.cur --prefix=ql "$q"

  local prx=$plx pry=$ply qrx=$qlx qry=$qly
  ble-edit/content/eolp "$p" && ((prx++)) || ble/textmap#getxy.out --prefix=pr $((p+1))
  ble-edit/content/eolp "$q" && ((qrx++)) || ble/textmap#getxy.out --prefix=qr $((q+1))

  ((ply-=p0y,qly-=q0y,pry-=p0y,qry-=q0y,
    (ply<qly||ply==qly&&plx<qlx)?(lx=plx,ly=ply):(lx=qlx,ly=qly),
    (pry>qry||pry==qry&&prx>qrx)?(rx=prx,ry=pry):(rx=qrx,ry=qry)))
}
function ble/keymap:vi/get-logical-rectangle {
  local p=${1:-$_ble_edit_mark} q=${2:-$_ble_edit_ind}
  ble-edit/content/find-logical-bol "$p"; p0=$ret
  ble-edit/content/find-logical-bol "$q"; q0=$ret
  ((p-=p0,q-=q0,p<=q)) || local p=$q q=$p
  lx=$p rx=$((q+1)) ly=0 ry=0
}
function ble/keymap:vi/get-rectangle {
  if ble/keymap:vi/use-textmap; then
    ble/keymap:vi/get-graphical-rectangle
  else
    ble/keymap:vi/get-logical-rectangle
  fi
}
function ble/keymap:vi/mark/get-rectangle-height {
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-rectangle
  ble/string#count-char "${_ble_edit_str:p0:q0-p0}" $'\n'
  ((ret++))
  return 0
}


## 関数 ble/keymap:vi/extract-graphical-block-by-geometry bol1 bol2 x1:y1 x2:y2
## 関数 ble/keymap:vi/extract-logical-block-by-geometry bol1 bol2 c1 c2
##   指定した引数の範囲を元に矩形範囲を抽出します。
## 関数 ble/keymap:vi/extract-graphical-block
## 関数 ble/keymap:vi/extract-logical-block
##   現在位置 (_ble_edit_ind) とマーク (_ble_edit_mark) を元に矩形範囲を抽出します。
##
##   @param[in] bol1 bol2
##     2つの行の行頭を指定します。
##   @param[in] x1:y1 x2:y2
##     2つの列を行頭からの相対位置で指定します。
##   @param[in] c1 c2
##     2つの列を論理列で指定します。
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
  local bol1=$1 bol2=$2 x1=$3 x2=$4 y1=0 y2=0
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
        ble-assert '! ble-edit/content/eolp "$smin"'

        ((c1r=(y1r-boly)*cols+x1r))
        ble-assert '((c1r>c1))' || ((c1r=c1))
        ble/string#repeat ' ' $((c1r-c1))
        stext=$ret${stext:1}
      fi

      # 2. 右の境界 c2 を大きな文字が跨いでいるときは空白に変換する
      ((c2l=(y2l-boly)*cols+x2l))
      if ((c2l<c2)); then
        if ((smax==eol)); then
          ((sfill=c2-c2l))
        else
          ble/string#repeat ' ' $((c2-c2l))
          stext=$stext$ret
          ((smax++))

          ((c2r=(y2r-boly)*cols+x2r))
          ble-assert '((c2r>c2))' || ((c2r=c2))
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
        ble/string#repeat ' ' $((c2-c1))
        stext=$ret${stext:1}
        ((smax++))

        ((c1l=(y1l-boly)*cols+x1l,slpad=c1-c1l))
        ((c1r=(y1r-boly)*cols+x1r,srpad=c1r-c1))
      fi
    fi

    ble/array#push sub_ranges "$smin:$smax:$slpad:$srpad:$sfill:$stext"

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
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-graphical-rectangle
  ble/keymap:vi/extract-graphical-block-by-geometry "$p0" "$q0" "$lx:$ly" "$rx:$ry"
}
function ble/keymap:vi/extract-logical-block-by-geometry {
  local bol1=$1 bol2=$2 x1=$3 x2=$4
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
  local p0 q0 lx ly rx ry
  ble/keymap:vi/get-logical-rectangle
  ble/keymap:vi/extract-logical-block-by-geometry "$p0" "$q0" "$lx" "$rx"
}
function ble/keymap:vi/extract-block {
  if ble/keymap:vi/use-textmap; then
    ble/keymap:vi/extract-graphical-block "$@"
  else
    ble/keymap:vi/extract-logical-block "$@"
  fi
}

# 選択範囲の着色の設定

## 関数 ble-highlight-layer:region/mark:char/get-selection
## 関数 ble-highlight-layer:region/mark:line/get-selection
## 関数 ble-highlight-layer:region/mark:block/get-selection
##   @arr[out] selection
function ble-highlight-layer:region/mark:char/get-selection {
  local rmin rmax
  if ((_ble_edit_mark<_ble_edit_ind)); then
    rmin=$_ble_edit_mark rmax=$_ble_edit_ind
  else
    rmin=$_ble_edit_ind rmax=$_ble_edit_mark
  fi
  ble-edit/content/eolp "$rmax" || ((rmax++))
  selection=("$rmin" "$rmax")
}
function ble-highlight-layer:region/mark:line/get-selection {
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
function ble-highlight-layer:region/mark:block/get-selection {
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
function ble-highlight-layer:region/mark:char+/get-selection {
  ble-highlight-layer:region/mark:char/get-selection
}
function ble-highlight-layer:region/mark:line+/get-selection {
  ble-highlight-layer:region/mark:line/get-selection
}
function ble-highlight-layer:region/mark:block+/get-selection {
  ble-highlight-layer:region/mark:block/get-selection
}


# 前回の選択サイズ

_ble_keymap_vi_xmap_prev_edit=char:1:1
function ble/widget/vi_xmap/.save-visual-state {
  local nline nchar mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == block ]]; then
    local p0 q0 lx rx ly ry
    if ble/keymap:vi/use-textmap; then
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
    if ((nline==1)) && [[ $mark_type != line ]]; then
      base=$p
    else
      ble-edit/content/find-logical-bol "$q"; base=$ret
    fi

    if ble/keymap:vi/use-textmap; then
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
  _ble_edit_mark_active=${prev[0]:-char}
  local nchar=${prev[1]:-1}
  local nline=${prev[2]:-1}
  ((nchar<1&&(nchar=1),nline<1&&(nline=1)))

  local is_x_relative=0
  if [[ ${_ble_edit_mark_active%+} == block ]]; then
    ((is_x_relative=1,nchar*=arg,nline*=arg))
  elif [[ ${_ble_edit_mark_active%+} == line ]]; then
    ((nline*=arg,is_x_relative=1,nchar=1))
  else
    ((nline==1?(is_x_relative=1,nchar*=arg):(nline*=arg)))
  fi
  ((nchar--,nline--))

  local index
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local b1=$ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$nline"; local b2=$ret
  ble-edit/content/find-logical-eol "$b2"; local e2=$ret
  if ble/keymap:vi/xmap/has-eol-extension; then
    index=$e2
  elif ble/keymap:vi/use-textmap; then
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
  ble/widget/.goto-char "$index"
}

# 前回の選択範囲

# mark `< `>
_ble_keymap_vi_xmap_prev_visual=
function ble/keymap:vi/xmap/set-previous-visual-area {
  local beg end
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block
    local nrange=${#sub_ranges[*]}
    ((nrange)) || return
    local beg=${sub_ranges[0]%%:*}
    local sub2_slice1=${sub_ranges[nrange-1]#*:}
    local end=${sub2_slice1%%:*}
    ((beg<end)) && ! ble-edit/content/bolp "$end" && ((end--))
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == line ]]; then
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

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    ble/keymap:vi/clear-arg
    ble/keymap:vi/xmap/set-previous-visual-area
    ble/widget/.goto-char "$end"
    _ble_edit_mark=$beg
    _ble_edit_mark_active=$mark
    ble/keymap:vi/update-mode-name
  else
    ble/keymap:vi/clear-arg
    ble/widget/vi-command/visual-mode.impl "$mark"
    ble/widget/.goto-char "$end"
    _ble_edit_mark=$beg
  fi
  return 0
}

# モード遷移

function ble/widget/vi-command/visual-mode.impl {
  local visual_type=$1
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

  ble-decode/keymap/push vi_xmap
  ble/keymap:vi/update-mode-name
  return 0
}
function ble/widget/vi_nmap/charwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl char
}
function ble/widget/vi_nmap/linewise-visual-mode {
  ble/widget/vi-command/visual-mode.impl line
}
function ble/widget/vi_nmap/blockwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl block
}

function ble/widget/vi_xmap/exit {
  # Note: xmap operator:c
  #   -> vi_xmap/block-insert-mode.impl
  #   → vi_xmap/cancel 経由で呼び出されるとき、
  #   既に vi_nmap に戻っていることがあるので、vi_xmap のときだけ処理する。
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    ble/keymap:vi/xmap/set-previous-visual-area
    _ble_edit_mark_active=
    ble-decode/keymap/pop
    ble/keymap:vi/update-mode-name
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/vi_xmap/cancel {
  # もし single-command-mode にいたとしても消去して normal へ移動する

  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/nonbol-eolp && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/widget/vi_xmap/exit
}
function ble/widget/vi_xmap/switch-visual-mode.impl {
  local visual_type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 0
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  fi

  if [[ ${_ble_edit_mark_active%+} == $visual_type ]]; then
    ble/widget/vi_xmap/cancel
  else
    ble/keymap:vi/xmap/switch-type "$visual_type"
    ble/keymap:vi/update-mode-name
    return 0
  fi

}
function ble/widget/vi_xmap/switch-to-charwise {
  ble/widget/vi_xmap/switch-visual-mode.impl char
}
function ble/widget/vi_xmap/switch-to-linewise {
  ble/widget/vi_xmap/switch-visual-mode.impl line
}
function ble/widget/vi_xmap/switch-to-blockwise {
  ble/widget/vi_xmap/switch-visual-mode.impl block
}

# コマンド

# xmap o
function ble/widget/vi_xmap/exchange-points {
  ble/keymap:vi/xmap/remove-eol-extension
  ble/widget/exchange-point-and-mark
  return 0
}
# xmap O
function ble/widget/vi_xmap/exchange-boundaries {
  if [[ ${_ble_edit_mark_active%+} == block ]]; then
    ble/keymap:vi/xmap/remove-eol-extension

    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block # Optimize: 実は sub_ranges[0] と sub_ranges[最後] しか使わない
    local nline=${#sub_ranges[@]}
    ble-assert '((nline))'

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
    ble/widget/.goto-char $((_ble_edit_ind==lpos2?rpos2:lpos2))
    return 0
  else
    ble/widget/vi_xmap/exchange-points
  fi
}

# xmap r{char}
function ble/widget/vi_xmap/visual-replace-char.hook {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local ret
  if [[ $FLAG ]]; then
    ble/widget/.bell
    return 1
  elif ((key==(ble_decode_Ctrl|91))); then # C-[ -> cancel
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
  if [[ $mark_type == block ]]; then
    ble/util/c2w "$c"; local w=$ret
    ((w<=0)) && w=1

    local sub_ranges sub_x1 sub_x2
    _ble_edit_mark_active=$old_mark_active ble/keymap:vi/extract-block "$beg" "$end"
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
      ble/widget/.replace-range "$smin" "$smax" "$ins1" 1
    done
    ble/keymap:vi/mark/end-edit-area
    ble/keymap:vi/repeat/record
    local beg=$smin
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
  else
    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == line ]]; then
      ble-edit/content/find-logical-bol "$beg"; local beg=$ret
      ble-edit/content/find-logical-eol "$end"; local end=$ret
    else
      ble-edit/content/eolp "$end" || ((end++))
    fi

    local ins=${_ble_edit_str:beg:end-beg}
    ins=${ins//[^$'\n']/"$s"}
    ble/widget/.replace-range "$beg" "$end" "$ins" 1
    ble/keymap:vi/mark/set-previous-edit-area "$beg" "$end"
    ble/keymap:vi/repeat/record
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
  fi
  return 0
}
function ble/widget/vi_xmap/visual-replace-char {
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
  if [[ :$opts: != *:force_line:* && $mark_type == block ]]; then
    call_operator=ble/keymap:vi/call-operator-blockwise
    _ble_edit_mark_active=block
    [[ :$opts: == *:extend:* ]] && _ble_edit_mark_active=block+
  else
    call_operator=ble/keymap:vi/call-operator-linewise
    _ble_edit_mark_active=line
  fi

  local old_mark_active=$_ble_edit_mark_active
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit
  _ble_edit_mark_active=$old_mark_active "$call_operator" "$op" "$beg" "$end" "$ARG" "$REG"; local ext=$?
  ((ext==148)) && return 148
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

  ble/widget/.goto-char "$beg"
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

# 矩形挿入モード

## 変数 _ble_keymap_vi_xmap_insert_data
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
function ble/keymap:vi/xmap/update-dirty-range {
  [[ $_ble_keymap_vi_insert_leave == ble/widget/vi_xmap/block-insert-mode.onleave ]] &&
    ((_ble_keymap_vi_xmap_insert_dbeg<0||beg<_ble_keymap_vi_xmap_insert_dbeg)) &&
    _ble_keymap_vi_xmap_insert_dbeg=$beg
}

## 関数 ble/widget/vi_xmap/block-insert-mode.impl
##   @var[in] sub_ranges sub_x1 sub_x2
function ble/widget/vi_xmap/block-insert-mode.impl {
  local type=$1
  local ARG FLAG REG; ble/keymap:vi/get-arg 1

  local nline=${#sub_ranges[@]}
  ble-assert '((nline))'

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
  ble/widget/.goto-char "$index"
  ble/widget/vi_nmap/.insert-mode "$ARG"
  ble/keymap:vi/repeat/record
  ble/keymap:vi/mark/set-local-mark 1 "$_ble_edit_ind"
  _ble_keymap_vi_xmap_insert_dbeg=-1

  local ret display_width
  ble/string#count-char "${_ble_edit_str::_ble_edit_ind}" $'\n'; local iline=$ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/keymap:vi/use-textmap; then
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
  if ble/keymap:vi/use-textmap; then
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
    ble/textmap#hit out $((x1%cols)) $((by+x1/cols)) "$bol" "$eol"; p1=$index
    ble/textmap#hit out $((x2%cols)) $((by+x2/cols)) "$bol" "$eol"; p2=$index
    ((lx+=(ly-by)*cols,rx+=(ry-by)*cols,lx!=rx&&p2++))
  else
    ((p1=bol+x1,p2=bol+x2))
  fi
  ins=${_ble_edit_str:p1:p2-p1}

  # 挿入の決定
  local -a ins_beg ins_text
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
      ble/textmap#hit out $((x1%cols)) $((by+x1/cols)) "$bol" "$eol" # -> index

      local nfill
      if ((index==eol&&(nfill=x1-lx+(ly-by)*cols)>0)); then
        ble/string#repeat ' ' "$nfill"; lpad=$lpad$ret
      fi
    else
      index=$((bol+x1))
      if ((index>eol)); then
        ble/string#repeat ' ' $((index-eol)); lpad=$lpad$ret
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
    ble/widget/.replace-range "$index" "$index" "$text" 1
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
  ble/widget/.goto-char "$index"
  return 0
}
function ble/widget/vi_xmap/insert-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block # Optimize: 実は sub_ranges[0] しか使わない
    ble/widget/vi_xmap/block-insert-mode.impl insert
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == line ]]; then
      ble-edit/content/find-logical-bol "$beg"; beg=$ret
    fi

    ble/widget/vi_xmap/cancel
    ble/widget/.goto-char "$beg"
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}
function ble/widget/vi_xmap/append-mode {
  local mark_type=${_ble_edit_mark_active%+}
  if [[ $mark_type == block ]]; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block # Optimize: 実は sub_ranges[0] しか使わない
    ble/widget/vi_xmap/block-insert-mode.impl append
  else
    local ARG FLAG REG; ble/keymap:vi/get-arg 1

    local beg=$_ble_edit_mark end=$_ble_edit_ind
    ((beg<=end)) || local beg=$end end=$beg
    if [[ $mark_type == line ]]; then
      # 行指向のときは最終行の先頭か _ble_edit_ind の内、
      # 後にある文字の後に移動する。
      if ((_ble_edit_mark>_ble_edit_ind)); then
        ble-edit/content/find-logical-bol "$end"; end=$ret
      fi
    fi
    ble-edit/content/eolp "$end" || ((end++))

    ble/widget/vi_xmap/cancel
    ble/widget/.goto-char "$end"
    ble/widget/vi_nmap/.insert-mode "$ARG"
    ble/keymap:vi/repeat/record
    return 0
  fi
}

# 貼り付け

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
  if [[ $mark_type == block ]]; then
    if [[ $kill_type == L ]]; then
      # P: V → C-v のときは C-v の最終行直後に挿入
      if ((is_after)); then
        local ret; ble/keymap:vi/mark/get-rectangle-height; local nline=$ret
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
        local ret; ble/keymap:vi/mark/get-rectangle-height; local nline=$ret
        ble/string#repeat "$kill_ring"$'\n' "$nline"; kill_ring=${ret%$'\n'}
        ble/string#repeat '0 ' "$nline"; kill_type=B:${ret% }
      fi
    fi
  elif [[ $mark_type == line ]]; then
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
      ble-edit/content/find-logical-bol "$_ble_edit_ind" $((${adjustment#*:}-1))
      ble/widget/.goto-char "$ret"
    fi
    local _ble_edit_kill_ring=$kill_ring
    local _ble_edit_kill_type=$kill_type
    ble/widget/vi_nmap/paste.impl "$ARG" '' "$is_after"
    if [[ $adjustment == index:* ]]; then
      local index=$((_ble_edit_ind+${adjustment#*:}))
      ((index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
      ble/keymap:vi/needs-eol-fix "$index" && ((index--))
      ble/widget/.goto-char "$index"
    fi
  }
  unset _ble_keymap_vi_mark_suppress_edit
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

function ble-decode-keymap:vi_xmap/define {
  local ble_bind_keymap=vi_xmap
  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi-command/decompose-meta

  ble-bind -f 'ESC' vi_xmap/exit
  ble-bind -f 'C-[' vi_xmap/exit
  ble-bind -f 'C-c' vi_xmap/cancel

  ble-bind -f a vi-command/text-object
  ble-bind -f i vi-command/text-object

  ble-bind -f 'C-\ C-n' vi_xmap/cancel
  ble-bind -f 'C-\ C-g' vi_xmap/cancel
  ble-bind -f v      vi_xmap/switch-to-charwise
  ble-bind -f V      vi_xmap/switch-to-linewise
  ble-bind -f C-v    vi_xmap/switch-to-blockwise
  ble-bind -f C-q    vi_xmap/switch-to-blockwise
  ble-bind -f 'g v'  vi-command/previous-visual-area

  ble-bind -f o vi_xmap/exchange-points
  ble-bind -f O vi_xmap/exchange-boundaries

  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'

  ble-bind -f 's' 'vi-command/operator c'
  ble-bind -f 'x'    'vi-command/operator d'
  ble-bind -f delete 'vi-command/operator d'
  # ble-bind -f C-h    'vi-command/operator d' # for smap
  # ble-bind -f DEL    'vi-command/operator d' # for smap

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

  ble-bind -f '"' vi-command/register
}

#------------------------------------------------------------------------------
# vi_imap

function ble/widget/vi_imap/__attach__ {
  ble/keymap:vi/update-mode-name
  return 0
}
function ble/widget/vi_imap/accept-single-line-or {
  if ble/widget/accept-single-line-or/accepts; then
    ble/keymap:vi/imap-repeat/reset
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/keymap:vi/imap-repeat/reset
    ble/widget/delete-region
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi_imap/overwrite-mode {
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=${_ble_keymap_vi_insert_overwrite:-R}
  fi
  ble/keymap:vi/update-mode-name
  return 0
}

# imap C-w
function ble/widget/vi_imap/delete-backward-word {
  local space=$' \t' nl=$'\n'
  local rex="($_ble_keymap_vi_REX_WORD)[$space]*\$|[$space]+\$|$nl\$"
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local index=$((_ble_edit_ind-${#BASH_REMATCH}))
    ble/widget/.delete-range "$index" "$_ble_edit_ind"
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}

# imap C-q, C-v
function ble/widget/vi_imap/quoted-insert.hook {
  local -a KEYS=($1);
  local WIDGET=ble/widget/self-insert
  ble/keymap:vi/imap-repeat/push
  builtin eval -- "$WIDGET"
}
function ble/widget/vi_imap/quoted-insert {
  ble/keymap:vi/imap-repeat/pop
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/vi_imap/quoted-insert.hook
}

#------------------------------------------------------------------------------
# imap: C-k (digraph)

function ble/widget/vi_imap/insert-digraph.hook {
  local -a KEYS; KEYS=("$1")
  ble/widget/self-insert
}

function ble/widget/vi_imap/insert-digraph {
  ble-decode/keymap/push vi_digraph
  _ble_keymap_vi_digraph__hook=ble/widget/vi_imap/insert-digraph.hook
  return 0
}

# imap: CR, LF (newline)
function ble/widget/vi_imap/newline {
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  ble/widget/newline
  ((bol<nol)) && ble/widget/insert-string "${_ble_edit_str:bol:nol-bol}"
  return 0
}

# imap: C-h, DEL
function ble/widget/vi_imap/delete-backward-indent-or {
  local rex=$'(^|\n)([ \t]+)$'
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local rematch2=${BASH_REMATCH[2]} # Note: for bash-3.1 ${#arr[n]} bug
    ble/widget/.delete-range $((_ble_edit_ind-${#rematch2})) "$_ble_edit_ind"
    return 0
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi_imap/define {
  local ble_bind_keymap=vi_imap

  ble-bind -f __attach__         vi_imap/__attach__
  ble-bind -f __defchar__        self-insert
  ble-bind -f __default__        vi_imap/__default__
  ble-bind -f __before_command__ vi_imap/__before_command__

  ble-bind -f 'ESC' vi_imap/normal-mode
  ble-bind -f 'C-[' vi_imap/normal-mode
  ble-bind -f 'C-c' vi_imap/normal-mode-without-insert-leave

  ble-bind -f insert vi_imap/overwrite-mode

  ble-bind -f 'C-o' 'vi_imap/single-command-mode'

  # settings overwritten by bash key bindings

  ble-bind -f 'C-w' vi_imap/delete-backward-word
  # ble-bind -f 'C-l' vi_imap/normal-mode
  # ble-bind -f 'C-k' vi_imap/insert-digraph

  #----------------------------------------------------------------------------
  # bash

  # ins
  ble-bind -f 'C-q'   vi_imap/quoted-insert
  ble-bind -f 'C-v'   vi_imap/quoted-insert
  ble-bind -f 'C-RET' newline

  # shell
  ble-bind -f 'C-m' 'vi_imap/accept-single-line-or vi_imap/newline'
  ble-bind -f 'RET' 'vi_imap/accept-single-line-or vi_imap/newline'
  ble-bind -f 'C-i'  complete
  ble-bind -f 'TAB'  complete

  # history
  ble-bind -f 'C-r'     history-isearch-backward
  ble-bind -f 'C-s'     history-isearch-forward
  ble-bind -f 'C-prior' history-beginning
  ble-bind -f 'C-next'  history-end
  ble-bind -f 'SP'      magic-space

  ble-bind -f 'C-l' clear-screen
  ble-bind -f 'C-k' kill-forward-line

  # ble-bind -f 'C-o' accept-and-next
  # ble-bind -f 'C-w' 'kill-region-or uword'

  #----------------------------------------------------------------------------
  # from keymap emacs-standard

  # shell function
  ble-bind -f  'C-j'     accept-line
  ble-bind -f  'C-g'     bell
  ble-bind -f  'f1'      command-help
  ble-bind -f  'C-x C-v' display-shell-version
  ble-bind -cf 'C-z'     fg
  # ble-bind -f 'C-c'      discard-line
  # ble-bind -f  'M-l'     redraw-line
  # ble-bind -cf 'M-z'     fg

  # history
  # ble-bind -f 'C-RET'   history-expand-line
  # ble-bind -f 'M-<'     history-beginning
  # ble-bind -f 'M->'     history-end

  # kill
  ble-bind -f 'C-@'      set-mark
  ble-bind -f 'C-x C-x'  exchange-point-and-mark
  ble-bind -f 'C-y'      yank
  # ble-bind -f M-SP     set-mark
  # ble-bind -f M-w      'copy-region-or uword'

  # spaces
  # ble-bind -f 'M-\'      delete-horizontal-space

  # charwise operations
  ble-bind -f 'C-f'      '@nomarked forward-char'
  ble-bind -f 'C-b'      '@nomarked backward-char'
  ble-bind -f 'right'    '@nomarked forward-char'
  ble-bind -f 'left'     '@nomarked backward-char'
  ble-bind -f 'S-C-f'    '@marked forward-char'
  ble-bind -f 'S-C-b'    '@marked backward-char'
  ble-bind -f 'S-right'  '@marked forward-char'
  ble-bind -f 'S-left'   '@marked backward-char'
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'C-h'      'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'DEL'      'vi_imap/delete-region-or vi_imap/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'C-t'      'transpose-chars'

  # wordwise operations
  ble-bind -f 'C-right'   '@nomarked forward-cword'
  ble-bind -f 'C-left'    '@nomarked backward-cword'
  ble-bind -f 'S-C-right' '@marked forward-cword'
  ble-bind -f 'S-C-left'  '@marked backward-cword'
  ble-bind -f 'C-delete'  'delete-forward-cword'
  ble-bind -f 'C-_'       'delete-backward-cword'
  # ble-bind -f 'M-right'   '@nomarked forward-sword'
  # ble-bind -f 'M-left'    '@nomarked backward-sword'
  # ble-bind -f 'S-M-right' '@marked forward-sword'
  # ble-bind -f 'S-M-left'  '@marked backward-sword'
  # ble-bind -f 'M-d'       'kill-forward-cword'
  # ble-bind -f 'M-h'       'kill-backward-cword'
  # ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  # ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  # ble-bind -f 'M-f'       '@nomarked forward-cword'
  # ble-bind -f 'M-b'       '@nomarked backward-cword'
  # ble-bind -f 'M-F'       '@marked forward-cword'
  # ble-bind -f 'M-B'       '@marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'      '@nomarked beginning-of-line'
  ble-bind -f 'C-e'      '@nomarked end-of-line'
  ble-bind -f 'home'     '@nomarked beginning-of-line'
  ble-bind -f 'end'      '@nomarked end-of-line'
  ble-bind -f 'S-C-a'    '@marked beginning-of-line'
  ble-bind -f 'S-C-e'    '@marked end-of-line'
  ble-bind -f 'S-home'   '@marked beginning-of-line'
  ble-bind -f 'S-end'    '@marked end-of-line'
  ble-bind -f 'C-u'      'kill-backward-line'
  # ble-bind -f 'M-m'      '@nomarked beginning-of-line'
  # ble-bind -f 'S-M-m'    '@marked beginning-of-line'

  ble-bind -f 'C-p'      '@nomarked backward-line-or-history-prev'
  ble-bind -f 'up'       '@nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'      '@nomarked forward-line-or-history-next'
  ble-bind -f 'down'     '@nomarked forward-line-or-history-next'
  ble-bind -f 'S-C-p'    '@marked backward-line'
  ble-bind -f 'S-up'     '@marked backward-line'
  ble-bind -f 'S-C-n'    '@marked forward-line'
  ble-bind -f 'S-down'   '@marked forward-line'

  ble-bind -f 'C-home'   '@nomarked beginning-of-text'
  ble-bind -f 'C-end'    '@nomarked end-of-text'
  ble-bind -f 'S-C-home' '@marked beginning-of-text'
  ble-bind -f 'S-C-end'  '@marked end-of-text'

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

#------------------------------------------------------------------------------
# vi_cmap

_ble_keymap_vi_cmap_hook=
_ble_keymap_vi_cmap_before_command=

function ble/keymap:vi/async-commandline-mode {
  local hook="$1"
  _ble_keymap_vi_cmap_hook=$hook
  _ble_keymap_vi_cmap_before_command=

  ble/textarea#save-state _ble_keymap_vi_cmap

  # 初期化
  ble-decode/keymap/push vi_cmap
  ble/keymap:vi/update-mode-name
  _ble_textarea_panel=2
  _ble_syntax_lang=text
  _ble_edit_PS1=$PS2
  _ble_edit_prompt=("" 0 0 0 32 0 "" "")
  _ble_highlight_layer__list=(plain region overwrite_mode)

  _ble_edit_arg=
  _ble_edit_dirty_observer=()

  # Note: ble/widget/.newline/clear-content の中で
  #   _ble_edit_str.reset が呼び出され、更に _ble_edit_dirty_observer が呼び出さる。
  #   ble/keymap:vi/mark/shift-by-dirty-range が呼び出されないように、
  #   _ble_edit_dirty_observer=() より後である必要がある。
  ble/widget/.newline/clear-content

  ble/textarea#invalidate
}

function ble/widget/vi_cmap/accept {
  local hook=${_ble_keymap_vi_cmap_hook}
  _ble_keymap_vi_cmap_hook=

  local result=$_ble_edit_str

  # 消去
  local -a DRAW_BUFF
  ble-form/panel#set-height.draw "$_ble_textarea_panel" 0
  ble-edit/draw/bflush

  # 復元
  ble/textarea#restore-state _ble_keymap_vi_cmap
  ble/textarea#clear-state _ble_keymap_vi_cmap
  [[ $_ble_edit_overwrite_mode ]] && ble/util/buffer "$_ble_term_civis"

  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name
  if [[ $hook ]]; then
    eval "$hook \"\$result\""
  else
    ble/keymap:vi/adjust-command-mode
    return 0
  fi
}

function ble/widget/vi_cmap/cancel {
  _ble_keymap_vi_cmap_hook=
  ble/widget/vi_cmap/accept
}

function ble/widget/vi_cmap/__before_command__ {
  if [[ $_ble_keymap_vi_cmap_before_command ]]; then
    eval "$_ble_keymap_vi_cmap_before_command"
  fi
}

function ble-decode-keymap:vi_cmap/define {
  local ble_bind_keymap=vi_cmap

  ble-bind -f __before_command__ vi_cmap/__before_command__

  ble-bind -f 'ESC' vi_cmap/cancel
  ble-bind -f 'C-[' vi_cmap/cancel
  ble-bind -f 'C-c' vi_cmap/cancel
  ble-bind -f 'C-m' vi_cmap/accept
  ble-bind -f 'RET' vi_cmap/accept
  ble-bind -f 'C-j' vi_cmap/accept

  ble-bind -f insert      overwrite-mode

  # ins
  ble-bind -f __defchar__ self-insert
  ble-bind -f 'C-q'       quoted-insert
  ble-bind -f 'C-v'       quoted-insert
  ble-bind -f 'C-M-m'     newline
  ble-bind -f 'M-RET'     newline

  # shell function
  ble-bind -f  'C-g'     bell
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'M-l'     redraw-line
  # ble-bind -f  'C-i'     complete
  # ble-bind -f  'TAB'     complete
  ble-bind -f  'C-x C-v' display-shell-version

  # # history
  # ble-bind -f 'C-r'     history-isearch-backward
  # ble-bind -f 'C-s'     history-isearch-forward
  # ble-bind -f 'C-RET'   history-expand-line
  # ble-bind -f 'M-<'     history-beginning
  # ble-bind -f 'M->'     history-end
  # ble-bind -f 'C-prior' history-beginning
  # ble-bind -f 'C-next'  history-end
  # ble-bind -f 'SP'      magic-space

  # kill
  ble-bind -f 'C-@'      set-mark
  ble-bind -f 'M-SP'     set-mark
  ble-bind -f 'C-x C-x'  exchange-point-and-mark
  ble-bind -f 'C-w'      'kill-region-or uword'
  ble-bind -f 'M-w'      'copy-region-or uword'
  ble-bind -f 'C-y'      yank

  # spaces
  ble-bind -f 'M-\'      delete-horizontal-space

  # charwise operations
  ble-bind -f 'C-f'      '@nomarked forward-char'
  ble-bind -f 'C-b'      '@nomarked backward-char'
  ble-bind -f 'right'    '@nomarked forward-char'
  ble-bind -f 'left'     '@nomarked backward-char'
  ble-bind -f 'S-C-f'    '@marked forward-char'
  ble-bind -f 'S-C-b'    '@marked backward-char'
  ble-bind -f 'S-right'  '@marked forward-char'
  ble-bind -f 'S-left'   '@marked backward-char'
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'
  ble-bind -f 'C-h'      'delete-region-or backward-char'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'DEL'      'delete-region-or backward-char'
  ble-bind -f 'C-t'      transpose-chars

  # wordwise operations
  ble-bind -f 'C-right'   '@nomarked forward-cword'
  ble-bind -f 'C-left'    '@nomarked backward-cword'
  ble-bind -f 'M-right'   '@nomarked forward-sword'
  ble-bind -f 'M-left'    '@nomarked backward-sword'
  ble-bind -f 'S-C-right' '@marked forward-cword'
  ble-bind -f 'S-C-left'  '@marked backward-cword'
  ble-bind -f 'S-M-right' '@marked forward-sword'
  ble-bind -f 'S-M-left'  '@marked backward-sword'
  ble-bind -f 'M-d'       kill-forward-cword
  ble-bind -f 'M-h'       kill-backward-cword
  ble-bind -f 'C-delete'  delete-forward-cword  # C-delete
  ble-bind -f 'C-_'       delete-backward-cword # C-BS
  ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  ble-bind -f 'M-f'       '@nomarked forward-cword'
  ble-bind -f 'M-b'       '@nomarked backward-cword'
  ble-bind -f 'M-F'       '@marked forward-cword'
  ble-bind -f 'M-B'       '@marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'       '@nomarked beginning-of-line'
  ble-bind -f 'C-e'       '@nomarked end-of-line'
  ble-bind -f 'home'      '@nomarked beginning-of-line'
  ble-bind -f 'end'       '@nomarked end-of-line'
  ble-bind -f 'M-m'       '@nomarked beginning-of-line'
  ble-bind -f 'S-C-a'     '@marked beginning-of-line'
  ble-bind -f 'S-C-e'     '@marked end-of-line'
  ble-bind -f 'S-home'    '@marked beginning-of-line'
  ble-bind -f 'S-end'     '@marked end-of-line'
  ble-bind -f 'S-M-m'     '@marked beginning-of-line'
  ble-bind -f 'C-k'       kill-forward-line
  ble-bind -f 'C-u'       kill-backward-line

  # ble-bind -f 'C-p'    '@nomarked backward-line-or-history-prev'
  # ble-bind -f 'up'     '@nomarked backward-line-or-history-prev'
  # ble-bind -f 'C-n'    '@nomarked forward-line-or-history-next'
  # ble-bind -f 'down'   '@nomarked forward-line-or-history-next'
  ble-bind -f 'C-p'    '@nomarked backward-line'
  ble-bind -f 'up'     '@nomarked backward-line'
  ble-bind -f 'C-n'    '@nomarked forward-line'
  ble-bind -f 'down'   '@nomarked forward-line'
  ble-bind -f 'S-C-p'  '@marked backward-line'
  ble-bind -f 'S-up'   '@marked backward-line'
  ble-bind -f 'S-C-n'  '@marked forward-line'
  ble-bind -f 'S-down' '@marked forward-line'

  ble-bind -f 'C-home'   '@nomarked beginning-of-text'
  ble-bind -f 'C-end'    '@nomarked end-of-text'
  ble-bind -f 'S-C-home' '@marked beginning-of-text'
  ble-bind -f 'S-C-end'  '@marked end-of-text'

  # ble-bind -f 'C-x' bell
  ble-bind -f 'C-[' bell
  ble-bind -f 'C-\' bell
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi
  if [[ $fname_keymap_cache -nt $_ble_base/keymap/vi.sh &&
          $fname_keymap_cache -nt $_ble_base/keymap/isearch.sh &&
          $fname_keymap_cache -nt $_ble_base/cmap/default.sh ]]; then
    source "$fname_keymap_cache"
    return
  fi

  ble-decode-bind/cmap/initialize
  source "$_ble_base/keymap/isearch.sh"

  echo -n "ble.sh: updating cache/keymap.vi... $_ble_term_cr" >&2

  ble-decode-keymap:isearch/define
  ble-decode-keymap:vi_imap/define
  ble-decode-keymap:vi_nmap/define
  ble-decode-keymap:vi_omap/define
  ble-decode-keymap:vi_xmap/define
  ble-decode-keymap:vi_cmap/define

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_imap  >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_nmap >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_omap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_xmap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_cmap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump isearch    >> "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.vi... done" >&2
}

ble-decode-keymap:vi/initialize
