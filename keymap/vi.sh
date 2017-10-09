#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されうるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
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
# vi-insert/default, vi-command/decompose-meta

function ble/widget/vi-insert/default {
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    local esc=27 # ESC
    # local esc=$((ble_decode_Ctrl|0x5b)) # もしくは C-[
    ble-decode-key "$esc" "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
    return 0
  fi

  # Control 修飾された文字 C-@ - C-\, C-? は制御文字 \000 - \037, \177 に戻して挿入
  if local ret; ble/keymap:vi/k2c "${KEYS[0]}"; then
    local -a KEYS=("$ret")
    ble/widget/self-insert
    return 0
  fi

  return 1
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

  return 1
}

function ble/widget/vi_omap/default {
  ble/widget/vi-command/decompose-meta || ble/widget/vi-command/bell
  return 0
}


#------------------------------------------------------------------------------
# repeat

## 変数 _ble_keymap_vi_repeat
##   挿入モードに入る時に指定された引数を記録する。
_ble_keymap_vi_repeat=

## 配列 _ble_keymap_vi_repeat_keylog
##   挿入モードに入るときに指定された引数が 1 より大きい時、
##   後でキーボード操作を繰り返すためにキーの列を記録する配列。
_ble_keymap_vi_repeat_keylog=()

function ble/widget/vi-insert/.reset-repeat {
  local arg=$1
  _ble_keymap_vi_repeat=
  _ble_keymap_vi_repeat_keylog=()
  ((arg>1)) && _ble_keymap_vi_repeat=$1
}
function ble/widget/vi-insert/.process-repeat {
  if [[ $_ble_keymap_vi_repeat ]]; then
    local repeat=$_ble_keymap_vi_repeat
    local key_count=$((${#_ble_keymap_vi_repeat_keylog[@]}-${#KEYS[@]}))
    local -a key_codes=("${_ble_keymap_vi_repeat_keylog[@]::key_count}")
    ble/widget/vi-insert/.reset-repeat

    local i
    for ((i=1;i<repeat;i++)); do
      ble-decode-key "${key_codes[@]}"
    done
  else
    ble/widget/vi-insert/.reset-repeat
  fi
}

## [[obsoleted]]
function ble/widget/vi-insert/@norepeat {
  ble/widget/vi-insert/.reset-repeat
  ble/widget/"$@"
}

## 配列 _ble_keymap_vi_imap_white_list
##   引数を指定して入った挿入モードを抜けるときの繰り返しで許されるコマンドのリスト
_ble_keymap_vi_imap_white_list=(
  self-insert
  quoted-insert
  delete-backward-{c,f,s,u}word
  copy{,-forward,-backward}-{c,f,s,u}word
  copy-region{,-or}
  clear-screen
  command-help
  display-shell-version
  redraw-line
)
function ble/widget/vi-insert/.before_command {
  if [[ $_ble_keymap_vi_repeat ]]; then
    local white=
    if [[ $COMMAND == ble/widget/* ]]; then
      local command=${COMMAND#ble/widget/}; command=${command%%[$' \t\n']*}
      if [[ $command == vi-insert/* || " ${_ble_keymap_vi_imap_white_list[*]} " == *" $command "*  ]]; then
        white=1
      fi
    fi

    if [[ $white ]]; then
      ble/array#push _ble_keymap_vi_repeat_keylog "${KEYS[@]}"
    else
      ble/widget/vi-insert/.reset-repeat
    fi
  fi
}

#------------------------------------------------------------------------------
# modes

## 変数 _ble_keymap_vi_insert_mark
##   最後に vi-insert を抜けた位置
##   ToDo: 現在は使用していない。将来的には gi などで使う。
_ble_keymap_vi_insert_mark=

## 変数 _ble_keymap_vi_insert_overwrite
##   挿入モードに入った時の上書き文字
_ble_keymap_vi_insert_overwrite=

## 変数 _ble_keymap_vi_single_command
##   ノーマルモードにおいて 1 つコマンドを実行したら
##   元の挿入モードに戻るモード (C-o) にいるかどうかを表します。
_ble_keymap_vi_single_command=
_ble_keymap_vi_single_command_overwrite=

## オプション bleopt_keymap_vi_normal_mode_name
##   ノーマルモードの時に表示する文字列を指定します。
##   空文字列を指定したときは何も表示しません。
: ${bleopt_keymap_vi_normal_mode_name:=$'\e[1m~\e[m'}

function ble/keymap:vi/update-mode-name {
  local kmap=$_ble_decode_key__kmap
  local show= overwrite=
  if [[ $kmap == vi_insert ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && ( $kmap == vi_command || $kmap == vi_omap ) ]]; then
    show=1 overwrite=$_ble_keymap_vi_single_command_overwrite
  elif [[ $kmap == vi_xmap ]]; then
    show=x overwrite=$_ble_keymap_vi_single_command_overwrite
  fi

  local name=$bleopt_keymap_vi_normal_mode_name
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
      local visual_name=
      if [[ $_ble_edit_mark_active == line ]]; then
        visual_name='VISUAL LINE'
      elif [[ $_ble_edit_mark_active == block ]]; then
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

function ble/widget/vi-insert/.normal-mode {
  _ble_keymap_vi_insert_mark=$_ble_edit_ind
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  ble-edit/content/bolp || ble/widget/.goto-char _ble_edit_ind-1
  ble-decode/keymap/push vi_command
  ble/keymap:vi/update-mode-name
}
function ble/widget/vi-insert/normal-mode {
  ble/widget/vi-insert/.process-repeat
  ble/widget/vi-insert/.normal-mode
}
function ble/widget/vi-insert/normal-mode-norepeat {
  ble/widget/vi-insert/.reset-repeat
  ble/widget/vi-insert/.normal-mode
}
function ble/widget/vi-insert/single-command-mode {
  ble/widget/vi-insert/.reset-repeat
  _ble_keymap_vi_insert_mark=$_ble_edit_ind
  _ble_keymap_vi_single_command=1
  _ble_keymap_vi_single_command_overwrite=$_ble_edit_overwrite_mode
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  ble-edit/content/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
  ble-edit/content/eolp && _ble_keymap_vi_single_command=2
  ble-decode/keymap/push vi_command
  ble/keymap:vi/update-mode-name
}

## 関数 ble/keymap:vi/needs-eol-fix
##
##   Note: この関数を使った後は ble/keymap:vi/adjust-command-mode を呼び出す必要がある。
##     そうしないとノーマルモードにおいてありえない位置にカーソルが来ることになる。
##
function ble/keymap:vi/needs-eol-fix {
  [[ $_ble_decode_key__kmap == vi_command || $_ble_decode_key__kmap == vi_omap ]] || return 1
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/content/nonbol-eolp "$index"
}
function ble/keymap:vi/adjust-command-mode {
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    # 移動コマンドが来たら末尾拡張を無効にする。
    # 移動コマンドはここを通るはず…。
    _ble_keymap_vi_xmap_eol_extended=
  fi

  local kmap_popped=
  if [[ $_ble_decode_key__kmap == vi_omap ]]; then
    ble-decode/keymap/pop
    kmap_popped=1
  fi

  # search による mark の設定・解除
  if [[ $_ble_keymap_vicmd_search_activate ]]; then
    _ble_edit_mark_active=$_ble_keymap_vicmd_search_activate
    _ble_keymap_vicmd_search_activate=
  elif [[ $_ble_edit_mark_active == search ]]; then
    _ble_edit_mark_active=
  fi

  if [[ $_ble_decode_key__kmap == vi_command && $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/content/nonbol-eolp "$index" && ble/widget/.goto-char index
    fi
    ble/widget/vi-command/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite"
  elif [[ $kmap_popped ]]; then
    ble/keymap:vi/update-mode-name
  fi

  return 0
}
function ble/widget/vi-command/bell {
  ble/widget/.bell "$1"
  ble/keymap:vi/adjust-command-mode
}


function ble/widget/vi-command/.insert-mode {
  [[ $_ble_decode_key__kmap == vi_xmap ]] && ble-decode/keymap/pop
  [[ $_ble_decode_key__kmap == vi_omap ]] && ble-decode/keymap/pop
  local arg=$1 overwrite=$2
  ble/widget/vi-insert/.reset-repeat "$arg"
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=$overwrite
  _ble_keymap_vi_insert_overwrite=$overwrite
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name
}
function ble/widget/vi-command/insert-mode {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/append-mode {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    if ! ble-edit/content/eolp; then
      ble/widget/.goto-char "$((_ble_edit_ind+1))"
    fi
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/append-mode-at-end-of-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local ret; ble-edit/content/find-logical-eol
    ble/widget/.goto-char "$ret"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-mode-at-beginning-of-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local ret; ble-edit/content/find-logical-bol
    ble/widget/.goto-char "$ret"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-mode-at-first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    ble/widget/vi-command/first-non-space
    [[ ${_ble_edit_str:_ble_edit_ind:1} == [$' \t'] ]] &&
      ble/widget/.goto-char _ble_edit_ind+1 # 逆eol補正
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/replace-mode {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    ble/widget/vi-command/.insert-mode "$arg" R
  fi
}
function ble/widget/vi-command/virtual-replace-mode {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    ble/widget/vi-command/.insert-mode "$arg" 1
  fi
}
function ble/widget/vi-command/accept-line {
  ble/keymap:vi/clear-arg
  ble/widget/vi-command/.insert-mode
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

## 関数 ble/keymap:vi/get-arg [default_value]
function ble/keymap:vi/get-arg {
  local default_value=$1
  flag=$_ble_keymap_vi_opfunc
  if [[ ! $_ble_edit_arg && ! $_ble_keymap_vi_oparg ]]; then
    arg=$default_value
  else
    arg=$((10#${_ble_edit_arg:-1}*10#${_ble_keymap_vi_oparg:-1}))
  fi
  ble/keymap:vi/clear-arg
}
function ble/keymap:vi/clear-arg {
  _ble_edit_arg=
  _ble_keymap_vi_oparg=
  _ble_keymap_vi_opfunc=
}

function ble/widget/vi-command/append-arg {
  local ret ch=$1
  if [[ ! $ch ]]; then
    local code=$((KEYS[0]&ble_decode_MaskChar))
    ((code==0)) && return
    ble/util/c2s "$code"; ch=$ret
  fi
  ble-assert '[[ ! ${ch//[0-9]} ]]'

  # 0
  if [[ $ch == 0 && ! $_ble_edit_arg ]]; then
    ble/widget/vi-command/beginning-of-line
    return
  fi

  _ble_edit_arg="$_ble_edit_arg$ch"
}

function ble/widget/vi-command/operator {
  local ret opname=$1

  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    local arg flag; ble/keymap:vi/get-arg ''
    # ※flag はユーザにより設定されているかもしれないが無視

    local a=$_ble_edit_ind b=$_ble_edit_mark
    ((a<=b||(a=_ble_edit_mark,b=_ble_edit_ind)))

    ble/widget/vi_xmap/.save-visual-state
    local mark_type=$_ble_edit_mark_active
    ble/widget/vi_xmap/exit

    if [[ $mark_type == line ]]; then
      ble/keymap:vi/call-operator-linewise "$opname" "$a" "$b" $arg
    elif [[ $mark_type == block ]]; then
      ble/keymap:vi/call-operator-blockwise "$opname" "$a" "$b" $arg
    else
      local end=$b
      ((end<${#_ble_edit_str}&&end++))
      ble/keymap:vi/call-operator-charwise "$opname" "$a" "$end" $arg
    fi || ble/widget/.bell

    ble/keymap:vi/adjust-command-mode
    return 0
  elif [[ $_ble_decode_key__kmap == vi_command ]]; then
    ble-decode/keymap/push vi_omap
    _ble_keymap_vi_oparg=$_ble_edit_arg
    _ble_keymap_vi_opfunc=$opname
    _ble_edit_arg=

  elif [[ $_ble_decode_key__kmap == vi_omap ]]; then
    if [[ $opname == "$_ble_keymap_vi_opfunc" ]]; then
      # 2つの同じオペレータ (yy, dd, cc, etc.) = 行指向の処理
      local arg flag; ble/keymap:vi/get-arg 1 # _ble_edit_arg is consumed here
      if ((arg==1)) || [[ ${_ble_edit_str:_ble_edit_ind} == *$'\n'* ]]; then
        if ble/keymap:vi/call-operator-linewise "$opname" "$_ble_edit_ind" "$_ble_edit_ind:$((arg-1))"; then
          ble/keymap:vi/adjust-command-mode
          return 0
        fi
      fi
    else
      ble/keymap:vi/clear-arg
      ble/widget/vi-command/bell
    fi
    return 1
  fi
}

function ble/widget/vi-command/copy-current-line {
  local arg flag; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.copy-range "$beg" "$end" 1 L
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/kill-current-line {
  local arg flag; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.kill-range "$beg" "$end" 1 L
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/kill-current-line-and-insert {
  ble/widget/vi-command/kill-current-line
  ble/widget/vi-command/.insert-mode
}

# nmap: 0, <home>
function ble/widget/vi-command/beginning-of-line {
  local arg flag; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-bol; local beg=$ret
  if [[ $flag == y ]]; then
    ble/widget/.copy-range "$beg" "$_ble_edit_ind" 1
    ble/widget/.goto-char "$beg"
  elif [[ $flag == [cd] ]]; then
    ble/widget/.kill-range "$beg" "$_ble_edit_ind" 1
    [[ $flag == c ]] && ble/widget/vi-command/.insert-mode
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/.goto-char "$beg"
  fi
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# operators / movements

## オペレータは以下の形式の関数として定義される。
##
## 関数 ble/keymap:vi/operator:名称 a b type [count]
##
##   @param[in] a b
##     範囲の開始点と終了点。終了点は開始点以降にあることが保証される。
##     type が 'line' のとき、それぞれ行頭・行末にあることが保証される。
##     ただし、行末に改行があるときは b は次の行頭を指す。
##
##   @param[in] type
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
##
## オペレータは現在以下の三箇所で呼び出されている。
##
## - ble/widget/vi-command/linewise-range.impl
## - ble/keymap:vi/call-operator-charwise
## - ble/keymap:vi/call-operator-linewise
##

function ble/keymap:vi/call-operator-charwise {
  local ch=$1 beg=$2 end=$3 arg=$4
  ((beg<=end||(beg=$3,end=$2)))
  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    local _ble_keymap_vi_operator_delayed=
    ble/keymap:vi/operator:"$ch" "$beg" "$end" char "$arg"
    [[ $_ble_keymap_vi_operator_delayed ]] && return
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
    return 0
  else
    return 1
  fi
}

function ble/keymap:vi/call-operator-linewise {
  local ch=$1 a=$2 b=$3 arg=$4 ia=0 ib=0
  [[ $a == *:* ]] && local a=${a%%:*} ia=${a#*:}
  [[ $b == *:* ]] && local b=${b%%:*} ib=${b#*:}
  local ret
  ble-edit/content/find-logical-bol "$a" "$ia"; local beg=$ret
  ble-edit/content/find-logical-eol "$b" "$ib"; local end=$ret

  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    ((end<${#_ble_edit_str}&&end++))
    local _ble_keymap_vi_operator_delayed=
    ble/keymap:vi/operator:"$ch" "$beg" "$end" line "$arg"
    [[ $_ble_keymap_vi_operator_delayed ]] && return
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
  local ch=$1 beg=$2 end=$3 arg=$4
  if ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block "$beg" "$end"
    local nrange=${#sub_ranges[@]}
    ((nrange)) || return 1

    local beg=${sub_ranges[0]}; beg=${beg%%:*}
    local end=${sub_ranges[nrange-1]}; end=${end#*:}; end=${end%%:*}
    local _ble_keymap_vi_operator_delayed=
    ble/keymap:vi/operator:"$ch" "$beg" "$end" block "$arg"
    [[ $_ble_keymap_vi_operator_delayed ]] && return

    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
    return 0
  else
    return 1
  fi
}



function ble/keymap:vi/operator:d {
  if [[ $3 == line ]]; then
    ((end==${#_ble_edit_str}&&beg>0&&beg--)) # fix start position
    ble/widget/.copy-range "$1" "$2" 1 L
    ble/widget/.delete-range "$beg" "$end"
  elif [[ $3 == block ]]; then
    ble/keymap:vi/operator:y "$@"
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
    ble/widget/.kill-range "$1" "$2" 0
  fi
}
function ble/keymap:vi/operator:c {
  if [[ $3 == line ]]; then
    local beg=$1 end=$2
    ((end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

    local indent=
    ble-edit/content/find-non-space "$beg"; local nol=$ret
    ((beg<nol)) && indent=${_ble_edit_str:beg:nol-beg}

    ble/widget/.kill-range "$beg" "$end" 1 L
    [[ $indent ]] && ble/widget/.replace-range "$beg" "$beg" "$indent" 1
    ble/widget/vi-command/.insert-mode
  elif [[ $3 == block ]]; then
    ble/keymap:vi/operator:d "$@" # @var beg will be overwritten here
    ble/widget/vi-command/.insert-mode
  else
    ble/widget/.kill-range "$1" "$2" 0
    ble/widget/vi-command/.insert-mode
  fi
}
function ble/keymap:vi/operator:y {
  if [[ $3 == line ]]; then
    ble/widget/.copy-range "$1" "$2" 1 L
  elif [[ $3 == block ]]; then
    local sub afill atext
    for sub in "${sub_ranges[@]}"; do
      local sub4=${sub#*:*:*:*:}
      local sfill=${sub4%%:*} stext=${sub4#*:}
      ble/array#push afill "$sfill"
      ble/array#push atext "$stext"
    done

    IFS=$'\n' eval '_ble_edit_kill_ring=${atext[*]}'
    _ble_edit_kill_type=B:${afill[*]}
  else
    ble/widget/.copy-range "$1" "$2" 1
  fi
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

function ble/keymap:vi/string#increase-indent {
  local text=$1 delta=$2
  local space=$' \t'
  local arr; ble/string#split-lines arr "$text"
  local arr2 line indent i len x r
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
          ((x=(x+8)/8*8))
        fi
      done
    fi

    ((x+=delta,x<0&&(x=0)))

    indent=
    if ((x)); then
      if ((r=x/8)); then
        ble/string#repeat $'\t' "$r"
        indent=$ret
      fi
      if ((r=x%8)); then
        ble/string#repeat ' ' "$r"
        indent=$indent$ret
      fi
    fi

    ble/array#push arr2 "$indent$line"
  done

  IFS=$'\n' eval 'ret=${arr2[*]}'
}
function ble/keymap:vi/operator:increase-indent {
  local delta=$1 context=$2
  [[ $context == char ]] && ble/keymap:vi/expand-range-for-linewise-operator
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))

  ble/keymap:vi/string#increase-indent "${_ble_edit_str:beg:end-beg}" "$delta"; local content=$ret
  ble/widget/.replace-range "$beg" "$end" "$content" 1

  if [[ $context == char ]]; then
    ble-edit/content/find-non-space "$beg"; beg=$ret
  fi
}
function ble/keymap:vi/operator:left {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:increase-indent $((-8*arg)) "$context"
}
function ble/keymap:vi/operator:right {
  local context=$3 arg=${4:-1}
  ble/keymap:vi/operator:increase-indent $((8*arg)) "$context"
}

## 関数 ble/widget/vi-command/exclusive-range.impl src dst flag nobell
##   @param[in] src, dst
##   @param[in] flag
##   @param[in] nobell
function ble/widget/vi-command/exclusive-range.impl {
  local src=$1 dst=$2 flag=$3 nobell=$4
  if [[ $flag ]]; then
    ble/keymap:vi/call-operator-charwise "$flag" "$src" "$dst" || ble/widget/.bell
  else
    ble/keymap:vi/needs-eol-fix "$dst" && ((dst--))
    if ((dst!=_ble_edit_ind)); then
      ble/widget/.goto-char dst
    else
      ((nobell)) || ble/widget/.bell
    fi
  fi
  ble/keymap:vi/adjust-command-mode
}

## 関数 ble/widget/vi-command/exclusive-goto.impl index flag nobell
##   @param[in] index
##   @param[in] flag
##   @param[in] nobell
function ble/widget/vi-command/exclusive-goto.impl {
  ble/widget/vi-command/exclusive-range.impl "$_ble_edit_ind" "$@"
}

function ble/widget/vi-command/inclusive-goto.impl {
  local index=$1 flag=$2 nobell=$3
  if [[ $flag ]]; then
    if ((_ble_edit_ind<=index)); then
      ble-edit/content/eolp "$index" || ((index++))
    else
      ble-edit/content/eolp || ble/widget/.goto-char _ble_edit_ind+1
    fi
  fi
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" "$nobell"
}

## 関数 ble/widget/vi-command/linewise-range.impl p q flag opts
## 関数 ble/widget/vi-command/linewise-goto.impl index flag opts
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
##
##   @param[in] opts
##     以下のフィールドを似にに含むコロン区切りのリスト
##
##     preserve_column
##     require_multiline
##
##   @var[in] bolx
##     既に計算済みの移動先 (index, q) の行の行頭がある場合はここに指定します。
##
##   @var[in] nolx
##     既に計算済みの移動先 (index, q) の行の非空白行頭位置がある場合はここに指定します。
##
function ble/widget/vi-command/linewise-range.impl {
  local p=$1 q=$2 flag=$3 opts=$4
  local ret
  if [[ $q == *:* ]]; then
    local qbase=${q%%:*} qline=${q#*:}
  else
    local qbase=$q qline=0
  fi

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
        return
      fi
    fi

    ((end<${#_ble_edit_str}&&end++))
    if ble/util/isfunction ble/keymap:vi/operator:"$flag"; then
      # オペレータ呼び出し
      local _ble_keymap_vi_operator_delayed=
      ble/keymap:vi/operator:"$flag" "$beg" "$end" line
      [[ $_ble_keymap_vi_operator_delayed ]] && return

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
        ((ret)) && ble/widget/vi-command/.relative-line "$ret"
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
    else
      ble/widget/vi-command/bell
    fi
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
  fi
}
function ble/widget/vi-command/linewise-goto.impl {
  local index=$1 flag=$2 opts=$3
  ble/widget/vi-command/linewise-range.impl "$_ble_edit_ind" "$index" "$flag" "$opts"
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
  local arg flag; ble/keymap:vi/get-arg 1

  local index
  if [[ $1 == m ]]; then
    # SP
    local width=$arg line
    while ((width<=${#_ble_edit_str}-_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=arg)) && break
      ((width+=arg-${#line}))
    done
    ((index=_ble_edit_ind+width,index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
    if [[ $_ble_decode_key__kmap != vi_xmap ]]; then
      ((index<${#_ble_edit_str})) && ble-edit/content/nonbol-eolp "$index" && ((index++))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind:arg}
    line=${line%%$'\n'*}
    ((index=_ble_edit_ind+${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
}

function ble/widget/vi-command/backward-char {
  local arg flag; ble/keymap:vi/get-arg 1

  local index
  ((arg>_ble_edit_ind&&(arg=_ble_edit_ind)))
  if [[ $1 == m ]]; then
    # DEL
    local width=$arg line
    while ((width<=_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind-width:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=arg)) && break
      ((width+=arg-${#line}))
    done
    ((index=_ble_edit_ind-width,index<0&&(index=0)))
    if [[ $_ble_decode_key__kmap != vi_xmap ]]; then
      ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    fi
  else
    local line=${_ble_edit_str:_ble_edit_ind-arg:arg}
    line=${line##*$'\n'}
    ((index=_ble_edit_ind-${#line}))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
}

function ble/widget/vi-command/forward-char-toggle-case {
  local arg flag; ble/keymap:vi/get-arg 1

  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local line=${_ble_edit_str:_ble_edit_ind:arg}
    line=${line%%$'\n'*}
    local len=${#line}
    local index=$((_ble_edit_ind+len))
    if ((len)); then
      local ret; ble/string#toggle-case "${_ble_edit_str:_ble_edit_ind:${#line}}"
      ble/widget/.replace-range "$_ble_edit_ind" "$index" "$ret" 1
    fi
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/.goto-char "$index"
    ble/keymap:vi/adjust-command-mode
  fi
}

#------------------------------------------------------------------------------
# command: [cdy]?[jk]

## 関数 ble/widget/vi-command/.history-relative-line arg
##
##   @param[in] arg
##     移動する相対行数を指定する。負の値は前に移動することを表し、
##     正の値は後に移動することを表す。
##
##   @exit
##     全く移動しなかった場合は 1 を返します。
##     それ以外の場合は 0 を返します。
##
function ble/widget/vi-command/.history-relative-line {
  local arg=$1
  ((arg)) || return 0

  # 履歴が初期化されていないとき最終行にいる。
  if [[ ! $_ble_edit_history_loaded ]]; then
    ((arg<0)) || return 1
    ble-edit/history/load # to use _ble_edit_history_ind
  fi

  local ret count=$((arg<0?-arg:arg)) exit=1
  ((count--))
  while ((count>=0)); do
    if ((arg<0)); then
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
    if ((arg<0)); then
      ble-edit/content/find-logical-eol 0 "$((nline-count-1))"
      ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    else
      ble-edit/content/find-logical-bol 0 "$count"
    fi
    ble/widget/.goto-char "$ret"
  fi
}

## 関数 ble/widget/vi-command/.relative-line arg flag opts
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
##   todo: 移動開始時の相対表示位置の記録は現在行っていない。
##
##   @param[in] arg flag
##
##   @param[in] opts
##     以下の値をコロンで区切って繋げた物を指定する。
##
##     history
##       現在の履歴項目内で要求された行数だけ移動できないとき、
##       履歴項目内の論理行を移動する。
##       但し flag がある場合は履歴項目の移動は行わない。
##
function ble/widget/vi-command/.relative-line {
  local arg=$1 flag=$2 opts=$3
  ((arg==0)) && return
  if [[ $flag ]]; then
    local bolx= nolx=
    ble/widget/vi-command/linewise-goto.impl "$_ble_edit_ind:$arg" "$flag" preserve_column:require_multiline
    return
  fi

  # 現在の履歴項目内での探索
  local count=$((arg<0?-arg:arg))
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/content/find-logical-bol "$ind" "$arg"; local bol2=$ret
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
    ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char _ble_edit_ind-1
    return
  fi

  # 履歴項目を行数を数えつつ移動
  if [[ $_ble_decode_key__kmap == vi_command && :$opts: == *:history:* ]]; then
    ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count)) || ((nmove)) || ble/widget/.bell
  else
    ble/widget/.bell
  fi
}
function ble/widget/vi-command/forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-line "$arg" "$flag" history
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command/backward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-line $((-arg)) "$flag" history
  ble/keymap:vi/adjust-command-mode
}

## 関数 ble/widget/vi-command/graphical-relative-line.impl arg flag opts
## 編集関数 vi-command/graphical-forward-line  # nmap gj
## 編集関数 vi-command/graphical-backward-line # nmap gk
##
##   @param[in] arg
##     移動する相対行数。負の値は上の行へ行くことを表す。正の値は下の行へ行くことを表す。
##   @param[in] flag
##     オペレータを指定する。
##   @param[in] opts
##     以下のオプションをコロンで繋げたものを指定する。
##
##     history
##
function ble/widget/vi-command/graphical-relative-line.impl {
  local arg=$1 flag=$2 opts=$3
  local index move
  if ble/keymap:vi/use-textmap; then
    local x y ax ay
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ((ax=x,ay=y+arg,
      ay<_ble_textmap_begy?(ay=_ble_textmap_begy):
      (ay>_ble_textmap_endy?(ay=_ble_textmap_endy):0)))
    ble/textmap#get-index-at "$ax" "$ay"
    ble/textmap#getxy.cur --prefix=a "$index"
    ((arg-=move=ay-y))
  else
    local ind=$_ble_edit_ind
    ble-edit/content/find-logical-bol "$ind" 0; local bol1=$ret
    ble-edit/content/find-logical-bol "$ind" "$arg"; local bol2=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    ((index=bol2+ind-bol1,index>eol2&&(index=eol2)))

    local ret
    if ((index>ind)); then
      ble/string#count-char "${_ble_edit_str:ind:index-ind}" $'\n'
      ((arg+=move=-ret))
    elif ((index<ind)); then
      ble/string#count-char "${_ble_edit_str:index:ind-index}" $'\n'
      ((arg+=move=ret))
    fi
  fi

  if ((arg==0)); then
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
    return
  fi

  if [[ ! $flag && $_ble_decode_key__kmap == vi_command && :$opts: == *:history:* ]]; then
    if ble/widget/vi-command/.history-relative-line "$arg"; then
      ble/keymap:vi/adjust-command-mode
      return
    fi
  fi

  # 失敗: オペレータは実行されないが移動はする。
  ((move)) && ble/widget/vi-command/exclusive-goto.impl "$index"
  ble/widget/vi-command/bell
}
function ble/widget/vi-command/graphical-forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl "$arg" "$flag"
}
function ble/widget/vi-command/graphical-backward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/graphical-relative-line.impl $((-arg)) "$flag"
}

#------------------------------------------------------------------------------
# command: ^ + - _ $

function ble/widget/vi-command/relative-first-non-space.impl {
  local arg=$1 flag=$2
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" "$arg"; local bolx=$ret
  ble-edit/content/find-non-space "$bolx"; local nolx=$ret

  # 2017-09-12 何故か分からないが vim はこういう振る舞いに見える。
  ((_ble_keymap_vi_single_command==2&&_ble_keymap_vi_single_command--))

  if [[ $flag ]]; then
    if ((arg==0)); then
      # command: ^
      ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
      ble/widget/vi-command/exclusive-goto.impl "$nolx" "$flag" 1
    else
      # command: + -
      # Note: bolx nolx (required by linewise-goto.impl) is already defined
      ble/widget/vi-command/linewise-goto.impl "$nolx" "$flag" require_multiline
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
    return
  fi

  # 履歴項目の移動
  if [[ $_ble_decode_key__kmap == vi_command ]] && ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count)); then
    ble/widget/vi-command/first-non-space
  elif ((nmove)); then
    ble/widget/vi-command/first-non-space
  else
    ble/widget/vi-command/bell
  fi
}
# nmap ^
function ble/widget/vi-command/first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl 0 "$flag"
}
# nmap +
function ble/widget/vi-command/forward-first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$arg" "$flag"
}
# nmap -
function ble/widget/vi-command/backward-first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl "$((-arg))" "$flag"
}
# nmap _
function ble/widget/vi-command/first-non-space-forward {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/relative-first-non-space.impl $((arg-1)) "$flag"
}
# nmap $
function ble/widget/vi-command/forward-eol {
  local arg flag; ble/keymap:vi/get-arg 1
  if ((arg>1)) && [[ ${_ble_edit_str:_ble_edit_ind}  != *$'\n'* ]]; then
    ble/widget/vi-command/bell
    return
  fi

  local ret index
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((arg-1)); index=$ret
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
  [[ $_ble_decode_key__kmap == vi_xmap ]] &&
    _ble_keymap_vi_xmap_eol_extended=1 # 末尾拡張
}
# nmap g0 g<home>
function ble/widget/vi-command/beginning-of-graphical-line {
  if ble/keymap:vi/use-textmap; then
    local arg flag; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" 1
  else
    ble/widget/vi-command/beginning-of-line
  fi
}
# nmap g^
function ble/widget/vi-command/graphical-first-non-space {
  if ble/keymap:vi/use-textmap; then
    local arg flag; ble/keymap:vi/get-arg 1
    local x y index ret
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ble-edit/content/find-non-space "$index"
    ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    ble/widget/vi-command/exclusive-goto.impl "$ret" "$flag" 1
  else
    ble/widget/vi-command/first-non-space
  fi
}
# nmap g$ g<end>
function ble/widget/vi-command/graphical-forward-eol {
  if ble/keymap:vi/use-textmap; then
    local arg flag; ble/keymap:vi/get-arg 1
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at $((_ble_textmap_cols-1)) $((y+arg-1))
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
  else
    ble/widget/vi-command/forward-eol
  fi
}
# nmap gm
function ble/widget/vi-command/middle-of-graphical-line {
  local arg flag; ble/keymap:vi/get-arg 1
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
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" 1
}
# nmap g_
function ble/widget/vi-command/last-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  local ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((arg-1)); local index=$ret
  local rex=$'([^ \t\n]?[ \t]+|[^ \t\n])$'
  [[ ${_ble_edit_str::index} =~ $rex ]] && ((index-=${#BASH_REMATCH}))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
}

#------------------------------------------------------------------------------
# command: p P

## 関数 ble/widget/vi-command/paste.impl/paste-block.impl arg [type]
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
function ble/widget/vi-command/paste.impl/paste-block.impl {
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

  local i ins_beg ins_end ins_text is_newline=
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
  local i=${#ins_beg[@]}
  while ((i--)); do
    local ibeg=${ins_beg[i]} iend=${ins_end[i]} text=${ins_text[i]}
    ble/widget/.replace-range "$ibeg" "$iend" "$text" 1
  done

  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/paste.impl {
  local arg=$1 flag=$2 is_after=$3
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  [[ $_ble_edit_kill_ring ]] || return 0
  local ret
  if [[ $_ble_edit_kill_type == L ]]; then
    if ((is_after)); then
      ble-edit/content/find-logical-eol
      if ((ret==${#_ble_edit_str})); then
        ble/widget/.goto-char ret
        ble/widget/insert-string $'\n'
      else
        ble/widget/.goto-char ret+1
      fi
    else
      ble-edit/content/find-logical-bol
      ble/widget/.goto-char "$ret"
    fi
    local ind=$_ble_edit_ind
    ble/string#repeat "${_ble_edit_kill_ring%$_ble_term_nl}$_ble_term_nl" "$arg"
    ble/widget/insert-string "$ret"
    ble/widget/.goto-char ind
    ble/widget/vi-command/first-non-space
  elif [[ $_ble_edit_kill_type == B:* ]]; then
    if ((is_after)) && ! ble-edit/content/eolp; then
      ble/widget/.goto-char $((_ble_edit_ind+1))
    fi
    ble/widget/vi-command/paste.impl/paste-block.impl "$arg"
  else
    if ((is_after)) && ! ble-edit/content/eolp; then
      ble/widget/.goto-char $((_ble_edit_ind+1))
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    ble/widget/insert-string "$ret"
    [[ $_ble_keymap_vi_single_command ]] || ble/widget/.goto-char $((_ble_edit_ind-1))
    ble/keymap:vi/adjust-command-mode
  fi
}

function ble/widget/vi-command/paste-after {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/paste.impl "$arg" "$flag" 1
}
function ble/widget/vi-command/paste-before {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/paste.impl "$arg" "$flag" 0
}

#------------------------------------------------------------------------------
# command: x s X C D

function ble/widget/vi-command/kill-forward-char {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=d
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-forward-char-and-insert {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=c
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-backward-char {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=d
    ble/widget/vi-command/backward-char
  fi
}
function ble/widget/vi-command/kill-forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=d
    ble/widget/vi-command/forward-eol
  fi
}
function ble/widget/vi-command/kill-forward-line-and-insert {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=c
    ble/widget/vi-command/forward-eol
  fi
}

#------------------------------------------------------------------------------
# command: w W b B e E

function ble/widget/vi-command/forward-word.impl {
  local arg=$1 flag=$2 rex_word=$3
  local b=$'[ \t]' n=$'\n'
  local rex="^((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
}
function ble/widget/vi-command/forward-word-end.impl {
  local arg=$1 flag=$2 rex_word=$3
  local IFS=$' \t\n'
  local rex="^([$IFS]*($rex_word)?){0,$arg}" # 単語末端に止まる。空行には止まらない
  [[ ${_ble_edit_str:_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  [[ $BASH_REMATCH && ${_ble_edit_str:index:1} == [$IFS] ]] && ble/widget/.bell
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 0
}
function ble/widget/vi-command/backward-word.impl {
  local arg=$1 flag=$2 rex_word=$3
  local b=$'[ \t]' n=$'\n'
  local rex="((($rex_word)$n?|$b+$n?|$n)($b+$n)*$b*){0,$arg}\$" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind-${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
}
function ble/widget/vi-command/backward-word-end.impl {
  local arg=$1 flag=$2 rex_word=$3
  local i=$'[ \t\n]' b=$'[ \t]' n=$'\n' w="($rex_word)"
  local rex1="(^|$w$n?|$n)($b+$n)*$b*"
  local rex="($rex1)($rex1){$((arg-1))}($rex_word|$i)\$" # 単語末端または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+1-${#BASH_REMATCH}))
  local rematch3=${BASH_REMATCH[3]} # 最初の ($rex_word)
  [[ $rematch3 ]] && ((index+=${#rematch3}-1))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 0
}

function ble/widget/vi-command/forward-vword {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/forward-vword-end {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/backward-vword {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/backward-vword-end {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/forward-uword {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word.impl "$arg" "$flag" $'[^ \t\n]+'
}
function ble/widget/vi-command/forward-uword-end {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" $'[^ \t\n]+'
}
function ble/widget/vi-command/backward-uword {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word.impl "$arg" "$flag" $'[^ \t\n]+'
}
function ble/widget/vi-command/backward-uword-end {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/backward-word-end.impl "$arg" "$flag" $'[^ \t\n]+'
}

#------------------------------------------------------------------------------
# command: [cdy]?[|HL] G gg

# nmap |
function ble/widget/vi-command/nth-column {
  local arg flag; ble/keymap:vi/get-arg 1

  local ret index
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble/keymap:vi/use-textmap; then
    local bx by; ble/textmap#getxy.cur --prefix=b "$bol" # Note: 先頭行はプロンプトにより bx!=0
    local ex ey; ble/textmap#getxy.cur --prefix=e "$eol"
    local dstx=$((bx+arg-1)) dsty=$by cols=${COLUMNS:-80}
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
    ((index=bol+arg-1,index>eol?(index=eol)))
  fi

  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" 1
}

function ble/widget/vi-command/nth-line {
  local arg flag bolx= nolx=; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/linewise-goto.impl 0:$((arg-1)) "$flag"
}

function ble/widget/vi-command/nth-last-line {
  local arg flag bolx= nolx=; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/linewise-goto.impl ${#_ble_edit_str}:$((-(arg-1))) "$flag"
}

function ble/widget/vi-command/history-beginning {
  local arg flag; ble/keymap:vi/get-arg 0
  if [[ $flag ]]; then
    if ((arg)); then
      _ble_keymap_vi_oparg=$arg
      _ble_keymap_vi_opfunc=$flag
    else
      _ble_keymap_vi_oparg=
      _ble_keymap_vi_opfunc=$flag
    fi
    ble/widget/vi-command/nth-line
    return
  fi

  if ((arg)); then
    ble-edit/history/goto $((arg-1))
  else
    ble/widget/history-beginning
  fi
  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/keymap:vi/adjust-command-mode
}

# G in history
function ble/widget/vi-command/history-end {
  local arg flag; ble/keymap:vi/get-arg 0
  if [[ $flag ]]; then
    if ((arg)); then
      _ble_keymap_vi_oparg=$arg
      _ble_keymap_vi_opfunc=$flag
      ble/widget/vi-command/nth-line
    else
      _ble_keymap_vi_oparg=
      _ble_keymap_vi_opfunc=$flag
      ble/widget/vi-command/nth-last-line
    fi
    return
  fi

  if ((arg)); then
    ble-edit/history/goto $((arg-1))
  else
    ble/widget/history-end
  fi
  ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble/keymap:vi/adjust-command-mode
}

# G in the current history entry
function ble/widget/vi-command/last-line {
  local bolx= nolx= arg flag; ble/keymap:vi/get-arg 0
  if ((arg)); then
    ble/widget/vi-command/linewise-goto.impl 0:$((arg-1)) "$flag"
  else
    ble/widget/vi-command/linewise-goto.impl ${#_ble_edit_str}:0 "$flag"
  fi
}

function ble/widget/vi-command/clear-screen-and-first-non-space {
  ble/widget/vi-command/first-non-space
  ble/widget/clear-screen
}
function ble/widget/vi-command/redraw-line-and-first-non-space {
  ble/widget/vi-command/first-non-space
  ble/widget/redraw-line
}
function ble/widget/vi-command/clear-screen-and-last-line {
  ble/widget/vi-command/last-line
  ble/widget/redraw-line
}

#------------------------------------------------------------------------------
# command: r gr

## 関数 ble/widget/vi-command/replace-char.impl code [overwrite_mode]
##   @param[in] overwrite_mode
##     置換する文字の挿入方法を指定します。
function ble/widget/vi-command/replace-char.impl {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=
  local arg flag ret; ble/keymap:vi/get-arg 1
  if [[ $flag ]] || ! ble/keymap:vi/k2c "$key"; then
    ble/widget/vi-command/bell
    return
  fi

  local pos=$_ble_edit_ind

  local -a KEYS=("$ret")
  local _ble_edit_arg=$arg
  local _ble_edit_overwrite_mode=$overwrite_mode
  local ble_widget_self_insert_opts=nolineext
  ble/widget/self-insert

  ((pos<_ble_edit_ind)) && ble/widget/.goto-char _ble_edit_ind-1
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/replace-char/.hook {
  ble/widget/vi-command/replace-char.impl "$1" R
}
function ble/widget/vi-command/replace-char {
  _ble_edit_overwrite_mode=R
  ble/keymap:vi/async-read-char ble/widget/vi-command/replace-char/.hook
}
function ble/widget/vi-command/virtual-replace-char/.hook {
  ble/widget/vi-command/replace-char.impl "$1" 1
}
function ble/widget/vi-command/virtual-replace-char {
  _ble_edit_overwrite_mode=1
  ble/keymap:vi/async-read-char ble/widget/vi-command/virtual-replace-char/.hook
}

#------------------------------------------------------------------------------
# command: J gJ o O

function ble/widget/vi-command/connect-line-with-space {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/content/find-logical-eol; local eol=$ret
    if ((eol<${#_ble_edit_str})); then
      ble/widget/.replace-range "$eol" $((eol+1)) ' ' 1
      ble/widget/.goto-char "$eol"
    else
      ble/widget/.bell
    fi
  fi
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command/connect-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/content/find-logical-eol; local eol=$ret
    if ((eol<${#_ble_edit_str})); then
      ble/widget/.delete-range "$eol" $((eol+1))
      ble/widget/.goto-char "$eol"
    else
      ble/widget/.bell
    fi
  fi
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/insert-mode-at-forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-logical-eol; local eol=$ret
    ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
    ble/widget/.goto-char "$eol"
    ble/widget/insert-string $'\n'"$indent"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-mode-at-backward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-non-space "$bol"; local indent=${_ble_edit_str:bol:ret-bol}
    ble/widget/.goto-char "$bol"
    ble/widget/insert-string "$indent"$'\n'
    ble/widget/.goto-char $((bol+${#indent}))
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}

#------------------------------------------------------------------------------
# command: f F t F


## 変数 _ble_keymap_vi_search_char
##   前回の ble/widget/vi-command/search-char.impl/core の検索を記録します。
_ble_keymap_vi_search_char=

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
  local arg flag; ble/keymap:vi/get-arg 1

  local ret c
  [[ $opts != *p* ]]; local isprev=$?
  [[ $opts != *r* ]]; local isrepeat=$?
  if ((isrepeat)); then
    c=$key
  else
    ble/keymap:vi/k2c "$key" || return 1
    ble/util/c2s "$ret"; local c=$ret
  fi
  [[ $c ]] || return 1

  ((isrepeat)) || _ble_keymap_vi_search_char=$c$opts

  local index
  if [[ $opts == *b* ]]; then
    # backward search
    ble-edit/content/find-logical-bol; local bol=$ret
    local base=$_ble_edit_ind
    ((isrepeat&&isprev&&base--,base>bol)) || return 1
    local line=${_ble_edit_str:bol:base-bol}
    ble/string#last-index-of "$line" "$c" "$arg"
    ((ret>=0)) || return 1

    ((index=bol+ret,isprev&&index++))
    ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" 1
  else
    # forward search
    ble-edit/content/find-logical-eol; local eol=$ret
    local base=$((_ble_edit_ind+1))
    ((isrepeat&&isprev&&base++,base<eol)) || return 1

    local line=${_ble_edit_str:base:eol-base}
    ble/string#index-of "$line" "$c" "$arg"
    ((ret>=0)) || return 1

    ((index=base+ret,isprev&&index--))
    ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
  fi
  return 0
}
function ble/widget/vi-command/search-char.impl {
  ble/widget/vi-command/search-char.impl/core "$1" "$2" || ble/widget/.bell
  ble/keymap:vi/adjust-command-mode
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
  [[ $_ble_keymap_vi_search_char ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_search_char::1} opts=${_ble_keymap_vi_search_char:1}
  ble/widget/vi-command/search-char.impl "r$opts" "$c"
}
function ble/widget/vi-command/search-char-reverse-repeat {
  [[ $_ble_keymap_vi_search_char ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_search_char::1} opts=${_ble_keymap_vi_search_char:1}
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
  local arg flag; ble/keymap:vi/get-arg -1
  if ((arg>=0)); then
    _ble_keymap_vi_oparg=$arg
    _ble_keymap_vi_opfunc=$flag
    ble/widget/"$@"
    return
  fi

  local open='({[' close=')}]'

  local ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ! ble/string#index-of-chars "${_ble_edit_str::eol}" '(){}[]' "$_ble_edit_ind"; then
    ble/keymap:vi/adjust-command-mode
    return
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
    return
  fi

  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
}

function ble/widget/vi-command/percentage-line {
  local arg flag; ble/keymap:vi/get-arg 0
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
  local iline=$(((arg*nline+99)/100))
  ble/widget/vi-command/linewise-goto.impl 0:$((iline-1)) "$flag"
}

#------------------------------------------------------------------------------
# command: go

function ble/widget/vi-command/nth-byte {
  local arg flag; ble/keymap:vi/get-arg 1
  ((arg--))
  local offset=0 text=$_ble_edit_str len=${#_ble_edit_str}
  local left nleft
  while ((arg>0&&len>1)); do
    left=${text::len/2}
    LC_ALL=C builtin eval 'nleft=${#left}'
    if ((arg<nleft)); then
      text=$left
      ((len/=2))
    else
      text=${text:len/2}
      ((offset+=len/2,
        arg-=nleft,
        len-=len/2))
    fi
  done
  ble/keymap:vi/needs-eol-fix "$offset" && ((offset--))
  ble/widget/vi-command/exclusive-goto.impl "$offset" "$flag" 1
}

#------------------------------------------------------------------------------
# text objects

_ble_keymap_vi_text_object=

## 関数 ble/keymap:vi/text-object/word.impl arg flag type
## 関数 ble/keymap:vi/text-object/quote.impl arg flag type
## 関数 ble/keymap:vi/text-object/block.impl arg flag type
## 関数 ble/keymap:vi/text-object/tag.impl arg flag type
## 関数 ble/keymap:vi/text-object/sentence.impl arg flag type
## 関数 ble/keymap:vi/text-object/paragraph.impl arg flag type
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##

function ble/keymap:vi/text-object/word.impl {
  local arg=$1 flag=$2 type=$3

  local space=$' \t' nl=$'\n' ifs=$' \t\n'

  local rex_word
  if [[ $type == ?W ]]; then
    rex_word="[^$ifs]+"
  else
    rex_word="[A-Za-z_]+|[^A-Za-z_$space]+"
  fi

  local rex="(($rex_word)|[$space]+)\$"
  [[ ${_ble_edit_str::_ble_edit_ind+1} =~ $rex ]]
  local beg=$((_ble_edit_ind+1-${#BASH_REMATCH}))

  if [[ $type == i* ]]; then
    rex="(($rex_word)$nl?|[$space]+$nl?){$arg}"
  else
    local rex1=
    ((arg>1)) && rex1="(($rex_word)[$ifs]+){$((arg-1))}"
    rex="([$ifs]+($rex_word)){$arg}|$rex1($rex_word)[$space]*"
  fi
  if ! [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]; then
    local index=${#_ble_edit_str}
    ble-edit/content/nonbol-eolp "$index" && ((index--))
    ble/widget/.goto-char "$index"
    ble/widget/vi-command/bell
    return 1
  fi

  local end=$((_ble_edit_ind+${#BASH_REMATCH}))
  [[ ${_ble_edit_str:end-1:1} == "$nl" ]] && ((end--))
  if [[ $_ble_decode_key__kmap == vi_xmap ]]; then
    ble/widget/vi-command/exclusive-goto.impl "$end"
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
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
  local arg=$1 flag=$2 type=$3
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
      ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
    fi
  else
    ble/widget/vi-command/bell
    return 1
  fi
}

function ble/keymap:vi/text-object/block.impl {
  local arg=$1 flag=$2 type=$3
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
    local nolx= bolx=
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
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
  local arg=$1 flag=$2 type=$3
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
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
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
  local arg=$1 flag=$2 type=$3
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
    local bolx= nolx=
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag" goto_bol
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
  fi
}

function ble/keymap:vi/text-object/paragraph.impl {
  local arg=$1 flag=$2 type=$3
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
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
  fi
}

## 関数 ble/keymap:vi/text-object.impl
##
##   @exit テキストオブジェクトの処理が完了したときに 0 を返します。
##
function ble/keymap:vi/text-object.impl {
  local arg=$1 flag=$2 type=$3
  case "$type" in
  ([ia][wW]) ble/keymap:vi/text-object/word.impl "$arg" "$flag" "$type" ;;
  ([ia][\"\'\`]) ble/keymap:vi/text-object/quote.impl "$arg" "$flag" "$type" ;;
  ([ia]['b()']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "${type::1}()" ;;
  ([ia]['B{}']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "${type::1}{}" ;;
  ([ia]['<>']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "${type::1}<>" ;;
  ([ia]['][']) ble/keymap:vi/text-object/block.impl "$arg" "$flag" "${type::1}[]" ;;
  ([ia]t) ble/keymap:vi/text-object/tag.impl "$arg" "$flag" "$type" ;;
  ([ia]s) ble/keymap:vi/text-object/sentence.impl "$arg" "$flag" "$type" ;;
  ([ia]p) ble/keymap:vi/text-object/paragraph.impl "$arg" "$flag" "$type" ;;
  (*)
    ble/widget/vi-command/bell
    return 1;;
  esac
}

function ble/keymap:vi/text-object.hook {
  local key=$1
  local arg flag; ble/keymap:vi/get-arg 1
  if ! ble-decode-key/ischar "$key"; then
    ble/widget/vi-command/bell
    return
  fi

  local ret; ble/util/c2s "$key"
  local type=$_ble_keymap_vi_text_object$ret
  ble/keymap:vi/text-object.impl "$arg" "$flag" "$type"
  return 0
}

function ble/keymap:vi/.check-text-object {
  ble-decode-key/ischar "${KEYS[0]}" || return 1

  local ret; ble/util/c2s "${KEYS[0]}"; local c="$ret"
  [[ $c == [ia] ]] || return 1

  local arg flag; ble/keymap:vi/get-arg 1
  _ble_keymap_vi_oparg=$arg
  _ble_keymap_vi_opfunc=$flag
  [[ $flag || $_ble_decode_key__kmap == vi_xmap ]] || return 1

  _ble_keymap_vi_text_object=$c
  _ble_decode_key__hook=ble/keymap:vi/text-object.hook
  return 0
}

function ble/widget/vi-command/text-object {
  ble/keymap:vi/.check-text-object || ble/widget/vi-command/bell
}

#------------------------------------------------------------------------------
# Command
#
# map: :cmd

function ble/widget/vi-command/commandline {
  ble/keymap:vi/async-commandline-mode ble/widget/vi-command/commandline.hook
  _ble_edit_PS1=:
}
function ble/widget/vi-command/commandline.hook {
  local command
  ble/string#split command $' \t\n' "$1"
  local cmd="ble/widget/vi-command:${command[0]}"
  if ble/util/isfunction "$cmd"; then
    "$cmd" "${command[@]:1}"
  else
    ble/widget/vi-command/bell "unknown command $1"
  fi
}

function ble/widget/vi-command:w {
  if [[ $1 ]]; then
    history -a "$1"
    local file=$1
  else
    history -a
    local file=${HISTFILE:-'~/.bash_history'}
  fi
  local wc; ble/util/assign wc 'wc "$file"'; wc=($wc)
  ble-edit/info/show text "\"$file\" ${wc[0]}L, ${wc[2]}C written"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command:q! {
  ble/widget/exit force
}
function ble/widget/vi-command:q {
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
}
function ble/widget/vi-command:wq {
  ble/widget/vi-command:w "$@"
  ble/widget/exit
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# Search
#
# map: / ? n N

_ble_keymap_vicmd_search_obackward=
_ble_keymap_vicmd_search_ohistory=
_ble_keymap_vicmd_search_needle=
_ble_keymap_vicmd_search_activate=
function ble-highlight-layer:region/mark:search/get-selection {
  ble-highlight-layer:region/mark:char/get-selection
}
function ble/keymap:vi/search/.before_command {
  if [[ ! $_ble_edit_str ]] && ((KEYS[0]==127||KEYS[0]==(104|ble_decode_Ctrl))); then # DEL or C-h
    ble/widget/vi_cmap/cancel
    COMMAND=
  fi
}
function ble/keymap:vi/search/invoke-search {
  local ind=$_ble_edit_ind

  # 検索開始位置
  if ((opt_optional_next)); then
    if ((!opt_backward)); then
      ((_ble_edit_ind<${#_ble_edit_str}&&_ble_edit_ind++))
    fi
  elif ((opt_locate)) || [[ $_ble_edit_mark_active != search && ! $_ble_keymap_vicmd_search_activate ]]; then
    # 何にも一致していない状態から
    if ((opt_backward)); then
      ble-edit/content/eolp || ((_ble_edit_ind++))
    fi
  else
    # _ble_edit_ind .. _ble_edit_mark[+1] に一致しているとき
    if ((!opt_backward)); then
      ((_ble_edit_ind=_ble_edit_mark))
      ble-edit/content/eolp || ((_ble_edit_ind++))
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
      _ble_edit_mark=$end
      _ble_keymap_vicmd_search_activate=search
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
      _ble_keymap_vicmd_search_activate=search
    fi
  fi
  return 1
}
function ble/widget/vi-command/search.impl {
  local arg flag; ble/keymap:vi/get-arg 1

  local opts=$1 needle=$2
  [[ :$opts: != *:repeat:* ]]; local opt_repeat=$? # 再検索 n N
  [[ :$opts: != *:history:* ]]; local opt_history=$? # 履歴検索が有効か
  [[ :$opts: != *:-:* ]]; local opt_backward=$? # 逆方向
  local opt_locate=0
  local opt_optional_next=0
  if ((opt_repeat)); then
    # n N
    if [[ $_ble_keymap_vicmd_search_needle ]]; then
      needle=$_ble_keymap_vicmd_search_needle
      ((opt_backward^=_ble_keymap_vicmd_search_obackward,
        opt_history=_ble_keymap_vicmd_search_ohistory))
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  else
    # / ?
    if [[ $needle ]]; then
      _ble_keymap_vicmd_search_needle=$needle
      _ble_keymap_vicmd_search_obackward=$opt_backward
      _ble_keymap_vicmd_search_ohistory=$opt_history
    elif [[ $_ble_keymap_vicmd_search_needle ]]; then
      needle=$_ble_keymap_vicmd_search_needle
      _ble_keymap_vicmd_search_obackward=$opt_backward
      _ble_keymap_vicmd_search_ohistory=$opt_history
    else
      ble/widget/vi-command/bell 'no previous search'
      return 1
    fi
  fi

  if [[ $flag ]]; then
    local original_ind=$_ble_edit_ind
    opt_history=0
  fi

  local start= # 初めの履歴番号。search.core 内で最初に履歴を読み込んだあとで設定される。
  local dir=+; ((opt_backward)) && dir=-
  local ntask=$arg
  while ((ntask)); do
    ble/widget/vi-command/search.core || break
    ((ntask--))
  done

  if [[ $flag ]]; then
    if ((ntask)); then
      # 検索対象が見つからなかったとき
      _ble_keymap_vicmd_search_activate=
      ble/widget/.goto-char "$original_ind"
      ble/keymap:vi/adjust-command-mode
    else
      # 見つかったとき
      if ((_ble_edit_ind==original_index)); then
        # 範囲が空のときは次の一致場所まで。
        # 次の一致場所がないとき (自分自身のとき) は空領域になる。
        opt_optional_next=1 ble/widget/vi-command/search.core
      fi
      local index=$_ble_edit_ind

      _ble_keymap_vicmd_search_activate=
      ble/widget/.goto-char "$original_ind"
      ble/widget/vi-command/exclusive-goto.impl "$index" "$flag" 1
    fi
  else
    if ((ntask<arg)) && ble/keymap:vi/needs-eol-fix; then
      if ((!opt_backward&&_ble_edit_ind<_ble_edit_mark)); then
        ble/widget/.goto-char $((_ble_edit_ind+1))
      else
        ble/widget/.goto-char $((_ble_edit_ind-1))
      fi
    fi
    ble/keymap:vi/adjust-command-mode
  fi
}
function ble/widget/vi-command/search-forward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl +:history'
  _ble_edit_PS1='/'
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/search/.before_command
}
function ble/widget/vi-command/search-backward {
  ble/keymap:vi/async-commandline-mode 'ble/widget/vi-command/search.impl -:history'
  _ble_edit_PS1='?'
  _ble_keymap_vi_cmap_before_command=ble/keymap:vi/search/.before_command
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
  ble-bind -f '<' 'vi-command/operator left'
  ble-bind -f '>' 'vi-command/operator right'
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
  ble-bind -f C-h   'vi-command/backward-char m'
  ble-bind -f DEL   'vi-command/backward-char m'
  ble-bind -f SP    'vi-command/forward-char m'

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
}

function ble-decode-keymap:vi_omap/define {
  local ble_bind_keymap=vi_omap
  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi_omap/default

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
  else
    ble/widget/exit
    ble/keymap:vi/adjust-command-mode # ジョブがあるときは終了しないので。
  fi
}

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command

  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi-command/decompose-meta
  ble-bind -f 'ESC' vi-command/bell
  ble-bind -f 'C-[' vi-command/bell

  ble-bind -f a      vi-command/append-mode
  ble-bind -f A      vi-command/append-mode-at-end-of-line
  ble-bind -f i      vi-command/insert-mode
  ble-bind -f insert vi-command/insert-mode
  ble-bind -f I      vi-command/insert-mode-at-first-non-space
  ble-bind -f 'g I'  vi-command/insert-mode-at-beginning-of-line
  ble-bind -f o      vi-command/insert-mode-at-forward-line
  ble-bind -f O      vi-command/insert-mode-at-backward-line
  ble-bind -f R      vi-command/replace-mode
  ble-bind -f 'g R'  vi-command/virtual-replace-mode

  ble-bind -f '~'    vi-command/forward-char-toggle-case

  ble-bind -f Y vi-command/copy-current-line
  ble-bind -f S vi-command/kill-current-line-and-insert
  ble-bind -f D vi-command/kill-forward-line
  ble-bind -f C vi-command/kill-forward-line-and-insert

  ble-bind -f p vi-command/paste-after
  ble-bind -f P vi-command/paste-before

  ble-bind -f x      vi-command/kill-forward-char
  ble-bind -f s      vi-command/kill-forward-char-and-insert
  ble-bind -f X      vi-command/kill-backward-char
  ble-bind -f delete vi-command/kill-forward-char

  ble-bind -f 'r'   vi-command/replace-char
  ble-bind -f 'g r' vi-command/virtual-replace-char # vim で実際に試すとこの機能はない

  ble-bind -f J     vi-command/connect-line-with-space
  ble-bind -f 'g J' vi-command/connect-line

  ble-bind -f K command-help

  ble-bind -f 'z t'   clear-screen
  ble-bind -f 'z z'   redraw-line # 中央
  ble-bind -f 'z b'   redraw-line # 最下行

  ble-bind -f 'z RET' vi-command/clear-screen-and-first-non-space
  ble-bind -f 'z C-m' vi-command/clear-screen-and-first-non-space
  ble-bind -f 'z +'   vi-command/clear-screen-and-last-line
  ble-bind -f 'z -'   vi-command/redraw-line-and-first-non-space # 中央
  ble-bind -f 'z .'   vi-command/redraw-line-and-first-non-space # 最下行

  ble-bind -f v   vi-command/charwise-visual-mode
  ble-bind -f V   vi-command/linewise-visual-mode
  ble-bind -f C-v vi-command/blockwise-visual-mode

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-q' quoted-insert
  # ble-bind -f 'C-v' quoted-insert

  ble-bind -f 'C-j' 'vi-command/accept-line'
  ble-bind -f 'C-m' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'
  ble-bind -f 'RET' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'

  ble-bind -f 'C-g' bell
  ble-bind -f 'C-l' clear-screen

  ble-bind -f C-d vi-command/exit-on-empty-line
}

#------------------------------------------------------------------------------
# Visual mode


_ble_keymap_vi_xmap_eol_extended=

# 矩形範囲の抽出

## 関数 local p0 q0 lx ly rx ry; ble/keymap:vi/get-graphical-rectangle [index1 [index2]]
## 関数 local p0 q0 lx rx      ; ble/keymap:vi/get-logical-rectangle   [index1 [index2]]
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
  lx=$p rx=$((q+1))
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
    if [[ $_ble_keymap_vi_xmap_eol_extended ]]; then
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
        # ここに来るのは [[ $_ble_keymap_vi_xmap_eol_extended ]] のときのみの筈
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
    if [[ $_ble_keymap_vi_xmap_eol_extended ]]; then
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
  local p0 q0 lx rx
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


# 前回の選択範囲の記録

_ble_keymap_vi_visual_prev=char:1:1
function ble/widget/vi_xmap/.save-visual-state {
  local nline nchar
  if [[ $_ble_edit_mark_active == block ]]; then
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
    if ((nline==1)) && [[ $_ble_edit_mark_active != line ]]; then
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

  [[ $_ble_keymap_vi_xmap_eol_extended ]] && nchar='$'
  _ble_keymap_vi_visual_prev=$_ble_edit_mark_active:$nchar:$nline
}
function ble/widget/vi_xmap/.restore-visual-state {
  local arg=$1
  local prev; ble/string#split prev : "$_ble_keymap_vi_visual_prev"
  _ble_edit_mark_active=${prev[0]:-char}
  local nchar=${prev[1]:-1}
  local nline=${prev[2]:-1}
  [[ $nchar == '$' ]] && nchar=1 _ble_keymap_vi_xmap_eol_extended=1
  ((nchar<1&&(nchar=1),nline<1&&(nline=1)))

  local is_x_relative=0
  if [[ $_ble_edit_mark_active == block ]]; then
    ((is_x_relative=1,nchar*=arg,nline*=arg))
  elif [[ $_ble_edit_mark_active == line ]]; then
    ((nline*=arg,is_x_relative=1,nchar=1))
  else
    ((nline==1?(is_x_relative=1,nchar*=arg):(nline*=arg)))
  fi
  ((nchar--,nline--))

  local index
  ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local b1=$ret
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$nline"; local b2=$ret
  ble-edit/content/find-logical-eol "$b2"; local e2=$ret
  if [[ $_ble_keymap_vi_xmap_eol_extended ]]; then
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

  ble/widget/.goto-char "$index"
}


# モード遷移

function ble/widget/vi-command/visual-mode.impl {
  local visual_type=$1
  local arg flag; ble/keymap:vi/get-arg 0
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
    return 1
  fi

  _ble_edit_overwrite_mode=
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=$visual_type
  _ble_keymap_vi_xmap_eol_extended=

  ((arg)) && ble/widget/vi_xmap/.restore-visual-state "$arg"

  ble-decode/keymap/push vi_xmap
  ble/keymap:vi/update-mode-name
}
function ble/widget/vi-command/charwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl char
}
function ble/widget/vi-command/linewise-visual-mode {
  ble/widget/vi-command/visual-mode.impl line
}
function ble/widget/vi-command/blockwise-visual-mode {
  ble/widget/vi-command/visual-mode.impl block
}
function ble/widget/vi_xmap/exit {
  _ble_edit_mark_active=
  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi_xmap/cancel {
  # もし single-command-mode にいたとしても消去して normal へ移動する

  _ble_edit_mark_active=
  _ble_keymap_vi_single_command=
  _ble_keymap_vi_single_command_overwrite=
  ble-edit/content/nonbol-eolp && ble/widget/.goto-char $((_ble_edit_ind-1))
  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name
}
function ble/widget/vi_xmap/switch-visual-mode.impl {
  local visual_type=$1
  local arg flag; ble/keymap:vi/get-arg 0
  if [[ $flag ]]; then
    ble/widget/.bell
    return
  fi

  if [[ $_ble_edit_mark_active == $visual_type ]]; then
    ble/widget/vi_xmap/cancel
  else
    _ble_edit_mark_active=$visual_type
    ble/keymap:vi/update-mode-name
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

# xmap r{char}
function ble/widget/vi_xmap/visual-replace-char.hook {
  local key=$1 overwrite_mode=${2:-R}
  _ble_edit_overwrite_mode=
  local arg flag; ble/keymap:vi/get-arg 1

  local ret
  if [[ $flag ]] || ! ble/keymap:vi/k2c "$key"; then
    ble/widget/.bell
    return
  fi
  local c=$ret
  ble/util/c2s "$c"; local s=$ret

  local mark_type=$_ble_edit_mark_active
  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit
  if [[ $mark_type == block ]]; then
    ble/util/c2w "$c"; local w=$ret
    ((w<=0)) && w=1

    local sub_ranges sub_x1 sub_x2
    ble/keymap:vi/extract-block "$beg" "$end"

    # create ins
    local width=$((sub_x2-sub_x1))
    local count=$((width/w))
    ble/string#repeat "$s" "$count"; local ins=$ret
    local pad=$((width-count*w))
    if ((pad)); then
      ble/string#repeat ' ' "$pad"; ins=$ins$ret
    fi

    local i=${#sub_ranges[@]} sub smin=0
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

    local ins=${_ble_edit_str//[^$'\n']/"$s"}
    ble/widget/.replace-range "$beg" "$end" "$ins" 1
    ble/keymap:vi/needs-eol-fix "$beg" && ((beg--))
    ble/widget/.goto-char "$beg"
  fi
}
function ble/widget/vi_xmap/visual-replace-char {
  ble/keymap:vi/async-read-char ble/widget/vi_xmap/visual-replace-char.hook
}

function ble/widget/vi_xmap/linewise-operator.impl {
  local op=$1 opts=$2
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell 'wrong keymap: xmap ではオペレータは設定されないはず'
    return
  fi

  local mark_type=$_ble_edit_mark_active
  local beg=$_ble_edit_mark end=$_ble_edit_ind
  ((beg<=end)) || local beg=$end end=$beg

  ble/widget/vi_xmap/.save-visual-state
  ble/widget/vi_xmap/exit
  if [[ :$opts: != *:force_line:* && $mark_type == block ]]; then
    [[ :$opts: == *:extend:* ]] && _ble_keymap_vi_xmap_eol_extended=1
    ble/keymap:vi/call-operator-blockwise "$op" "$beg" "$end" $arg
  else
    ble/keymap:vi/call-operator-linewise "$op" "$beg" "$end" $arg
  fi
  ble/keymap:vi/adjust-command-mode
}

# xmap C
function ble/widget/vi_xmap/replace-block-lines { ble/widget/vi_xmap/linewise-operator.impl c extend; }
# xmap D X
function ble/widget/vi_xmap/delete-block-lines { ble/widget/vi_xmap/linewise-operator.impl d extend; }
# xmap R S
function ble/widget/vi_xmap/delete-lines { ble/widget/vi_xmap/linewise-operator.impl d force_line; }
# xmap Y
function ble/widget/vi_xmap/copy-block-or-lines { ble/widget/vi_xmap/linewise-operator.impl y; }


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
  ble-bind -f v   vi_xmap/switch-to-charwise
  ble-bind -f V   vi_xmap/switch-to-linewise
  ble-bind -f C-v vi_xmap/switch-to-blockwise

  ble-bind -f '~' 'vi-command/operator toggle_case'
  ble-bind -f 'u' 'vi-command/operator u'
  ble-bind -f 'U' 'vi-command/operator U'
  ble-bind -f '?' 'vi-command/operator rot13'

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
}

#------------------------------------------------------------------------------
# vi-insert

function ble/widget/vi-insert/.attach {
  ble/keymap:vi/update-mode-name
}
function ble/widget/vi-insert/magic-space {
  if [[ $_ble_keymap_vi_repeat ]]; then
    ble/widget/self-insert
  else
    ble/widget/vi-insert/.reset-repeat
    ble/widget/magic-space
  fi
}
function ble/widget/vi-insert/accept-single-line-or {
  if ble/widget/accept-single-line-or/accepts; then
    ble/widget/vi-insert/.reset-repeat
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi-insert/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/vi-insert/.reset-repeat
    ble/widget/delete-region
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi-insert/overwrite-mode {
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=${_ble_keymap_vi_insert_overwrite:-R}
  fi
  ble/keymap:vi/update-mode-name
}

#------------------------------------------------------------------------------
# imap: C-k (digraph)

function ble/widget/vi-insert/insert-digraph.hook {
  local -a KEYS=("$1")
  ble/widget/self-insert
}

function ble/widget/vi-insert/insert-digraph {
  ble-decode/keymap/push vi_digraph
  _ble_keymap_vi_digraph__hook=ble/widget/vi-insert/insert-digraph.hook
}

# imap: CR, LF (newline)
function ble/widget/vi-insert/newline {
  local ret
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-non-space "$bol"; local nol=$ret
  ble/widget/newline
  ((bol<nol)) && ble/widget/insert-string "${_ble_edit_str:bol:nol-bol}"
}

# imap: C-h, DEL
function ble/widget/vi-insert/delete-backward-indent-or {
  local rex=$'(^|\n)([ \t]+)$'
  if [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
    local rematch2=${BASH_REMATCH[2]} # Note: for bash-3.1 ${#arr[n]} bug
    ble/widget/.delete-range $((_ble_edit_ind-${#rematch2})) "$_ble_edit_ind"
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi_insert/define {
  local ble_bind_keymap=vi_insert

  ble-bind -f __attach__         vi-insert/.attach
  ble-bind -f __defchar__        self-insert
  ble-bind -f __default__        vi-insert/default
  ble-bind -f __before_command__ vi-insert/.before_command

  ble-bind -f 'ESC' vi-insert/normal-mode
  ble-bind -f 'C-[' vi-insert/normal-mode
  ble-bind -f 'C-c' vi-insert/normal-mode-norepeat

  ble-bind -f insert vi-insert/overwrite-mode

  ble-bind -f 'C-w' 'delete-backward-cword' # vword?

  ble-bind -f 'C-o' 'vi-insert/single-command-mode'

  # settings overwritten by bash key bindings

  # ble-bind -f 'C-l' vi-insert/normal-mode
  # ble-bind -f 'C-k' vi-insert/insert-digraph

  #----------------------------------------------------------------------------
  # bash

  # ins
  ble-bind -f 'C-q'   quoted-insert
  ble-bind -f 'C-v'   quoted-insert
  ble-bind -f 'C-RET' newline

  # shell
  ble-bind -f 'C-m' 'vi-insert/accept-single-line-or vi-insert/newline'
  ble-bind -f 'RET' 'vi-insert/accept-single-line-or vi-insert/newline'
  ble-bind -f 'C-i'  complete
  ble-bind -f 'TAB'  complete

  # history
  ble-bind -f 'C-r'     history-isearch-backward
  ble-bind -f 'C-s'     history-isearch-forward
  ble-bind -f 'C-prior' history-beginning
  ble-bind -f 'C-next'  history-end
  ble-bind -f 'SP'      vi-insert/magic-space

  ble-bind -f 'C-l' clear-screen
  ble-bind -f 'C-k' kill-forward-line

  # ble-bind -f  'C-o' accept-and-next

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
  # ble-bind -f C-w      kill-region-or uword
  # ble-bind -f M-SP     set-mark
  # ble-bind -f M-w      copy-region-or uword

  # spaces
  # ble-bind -f 'M-\'      delete-horizontal-space

  # charwise operations
  ble-bind -f 'C-f'      'nomarked forward-char'
  ble-bind -f 'C-b'      'nomarked backward-char'
  ble-bind -f 'right'    'nomarked forward-char'
  ble-bind -f 'left'     'nomarked backward-char'
  ble-bind -f 'S-C-f'    'marked forward-char'
  ble-bind -f 'S-C-b'    'marked backward-char'
  ble-bind -f 'S-right'  'marked forward-char'
  ble-bind -f 'S-left'   'marked backward-char'
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'C-h'      'vi-insert/delete-region-or vi-insert/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'DEL'      'vi-insert/delete-region-or vi-insert/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'C-t'      'transpose-chars'

  # wordwise operations
  ble-bind -f 'C-right'   'nomarked forward-cword'
  ble-bind -f 'C-left'    'nomarked backward-cword'
  ble-bind -f 'S-C-right' 'marked forward-cword'
  ble-bind -f 'S-C-left'  'marked backward-cword'
  ble-bind -f 'C-delete'  'delete-forward-cword'
  ble-bind -f 'C-_'       'delete-backward-cword'
  # ble-bind -f 'M-right'   'nomarked forward-sword'
  # ble-bind -f 'M-left'    'nomarked backward-sword'
  # ble-bind -f 'S-M-right' 'marked forward-sword'
  # ble-bind -f 'S-M-left'  'marked backward-sword'
  # ble-bind -f 'M-d'       'kill-forward-cword'
  # ble-bind -f 'M-h'       'kill-backward-cword'
  # ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  # ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  # ble-bind -f 'M-f'       'nomarked forward-cword'
  # ble-bind -f 'M-b'       'nomarked backward-cword'
  # ble-bind -f 'M-F'       'marked forward-cword'
  # ble-bind -f 'M-B'       'marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'      'nomarked beginning-of-line'
  ble-bind -f 'C-e'      'nomarked end-of-line'
  ble-bind -f 'home'     'nomarked beginning-of-line'
  ble-bind -f 'end'      'nomarked end-of-line'
  ble-bind -f 'S-C-a'    'marked beginning-of-line'
  ble-bind -f 'S-C-e'    'marked end-of-line'
  ble-bind -f 'S-home'   'marked beginning-of-line'
  ble-bind -f 'S-end'    'marked end-of-line'
  ble-bind -f 'C-u'      'kill-backward-line'
  # ble-bind -f 'M-m'      'nomarked beginning-of-line'
  # ble-bind -f 'S-M-m'    'marked beginning-of-line'

  ble-bind -f 'C-p'      'nomarked backward-line-or-history-prev'
  ble-bind -f 'up'       'nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'      'nomarked forward-line-or-history-next'
  ble-bind -f 'down'     'nomarked forward-line-or-history-next'
  ble-bind -f 'S-C-p'    'marked backward-line'
  ble-bind -f 'S-up'     'marked backward-line'
  ble-bind -f 'S-C-n'    'marked forward-line'
  ble-bind -f 'S-down'   'marked forward-line'

  ble-bind -f 'C-home'   'nomarked beginning-of-text'
  ble-bind -f 'C-end'    'nomarked end-of-text'
  ble-bind -f 'S-C-home' 'marked beginning-of-text'
  ble-bind -f 'S-C-end'  'marked end-of-text'

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
  ble-edit/info/default text ''

  # 初期化
  _ble_textarea_panel=2
  _ble_syntax_lang=text
  _ble_edit_PS1=$PS2
  _ble_edit_prompt=("" 0 0 0 32 0 "" "")
  _ble_highlight_layer__list=(plain region overwrite_mode)

  # from ble/widget/.newline
  [[ $_ble_edit_overwrite_mode ]] && ble/util/buffer $'\e[?25h'
  _ble_edit_str.reset ''
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
  _ble_edit_arg=

  ble/textarea#invalidate
  ble-decode/keymap/push vi_cmap
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
  [[ $_ble_edit_overwrite_mode ]] && ble/util/buffer $'\e[?25l'

  ble-decode/keymap/pop
  ble/keymap:vi/update-mode-name
  if [[ $hook ]]; then
    eval "$hook \"\$result\""
  else
    ble/keymap:vi/adjust-command-mode
  fi
}

function ble/widget/vi_cmap/cancel {
  _ble_keymap_vi_cmap_hook=
  ble/widget/vi_cmap/accept
}

function ble/widget/vi_cmap/.before_command {
  if [[ $_ble_keymap_vi_cmap_before_command ]]; then
    eval "$_ble_keymap_vi_cmap_before_command"
  fi
}

function ble-decode-keymap:vi_cmap/define {
  local ble_bind_keymap=vi_cmap

  ble-bind -f __before_command__ vi_cmap/.before_command

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
  ble-bind -f 'C-f'      'nomarked forward-char'
  ble-bind -f 'C-b'      'nomarked backward-char'
  ble-bind -f 'right'    'nomarked forward-char'
  ble-bind -f 'left'     'nomarked backward-char'
  ble-bind -f 'S-C-f'    'marked forward-char'
  ble-bind -f 'S-C-b'    'marked backward-char'
  ble-bind -f 'S-right'  'marked forward-char'
  ble-bind -f 'S-left'   'marked backward-char'
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'
  ble-bind -f 'C-h'      'delete-region-or backward-char'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'DEL'      'delete-region-or backward-char'
  ble-bind -f 'C-t'      transpose-chars

  # wordwise operations
  ble-bind -f 'C-right'   'nomarked forward-cword'
  ble-bind -f 'C-left'    'nomarked backward-cword'
  ble-bind -f 'M-right'   'nomarked forward-sword'
  ble-bind -f 'M-left'    'nomarked backward-sword'
  ble-bind -f 'S-C-right' 'marked forward-cword'
  ble-bind -f 'S-C-left'  'marked backward-cword'
  ble-bind -f 'S-M-right' 'marked forward-sword'
  ble-bind -f 'S-M-left'  'marked backward-sword'
  ble-bind -f 'M-d'       kill-forward-cword
  ble-bind -f 'M-h'       kill-backward-cword
  ble-bind -f 'C-delete'  delete-forward-cword  # C-delete
  ble-bind -f 'C-_'       delete-backward-cword # C-BS
  ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  ble-bind -f 'M-f'       'nomarked forward-cword'
  ble-bind -f 'M-b'       'nomarked backward-cword'
  ble-bind -f 'M-F'       'marked forward-cword'
  ble-bind -f 'M-B'       'marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'       'nomarked beginning-of-line'
  ble-bind -f 'C-e'       'nomarked end-of-line'
  ble-bind -f 'home'      'nomarked beginning-of-line'
  ble-bind -f 'end'       'nomarked end-of-line'
  ble-bind -f 'M-m'       'nomarked beginning-of-line'
  ble-bind -f 'S-C-a'     'marked beginning-of-line'
  ble-bind -f 'S-C-e'     'marked end-of-line'
  ble-bind -f 'S-home'    'marked beginning-of-line'
  ble-bind -f 'S-end'     'marked end-of-line'
  ble-bind -f 'S-M-m'     'marked beginning-of-line'
  ble-bind -f 'C-k'       kill-forward-line
  ble-bind -f 'C-u'       kill-backward-line

  # ble-bind -f 'C-p'    'nomarked backward-line-or-history-prev'
  # ble-bind -f 'up'     'nomarked backward-line-or-history-prev'
  # ble-bind -f 'C-n'    'nomarked forward-line-or-history-next'
  # ble-bind -f 'down'   'nomarked forward-line-or-history-next'
  ble-bind -f 'C-p'    'nomarked backward-line'
  ble-bind -f 'up'     'nomarked backward-line'
  ble-bind -f 'C-n'    'nomarked forward-line'
  ble-bind -f 'down'   'nomarked forward-line'
  ble-bind -f 'S-C-p'  'marked backward-line'
  ble-bind -f 'S-up'   'marked backward-line'
  ble-bind -f 'S-C-n'  'marked forward-line'
  ble-bind -f 'S-down' 'marked forward-line'

  ble-bind -f 'C-home'   'nomarked beginning-of-text'
  ble-bind -f 'C-end'    'nomarked end-of-text'
  ble-bind -f 'S-C-home' 'marked beginning-of-text'
  ble-bind -f 'S-C-end'  'marked end-of-text'

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

  source "$_ble_base/keymap/isearch.sh"

  echo -n "ble.sh: updating cache/keymap.vi... $_ble_term_cr" >&2

  ble-decode-keymap:isearch/define
  ble-decode-keymap:vi_insert/define
  ble-decode-keymap:vi_command/define
  ble-decode-keymap:vi_omap/define
  ble-decode-keymap:vi_xmap/define
  ble-decode-keymap:vi_cmap/define

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_insert  >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_command >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_omap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_xmap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_cmap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump isearch    >> "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.vi... done" >&2
}

ble-decode-keymap:vi/initialize
