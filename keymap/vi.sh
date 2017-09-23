#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されうるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
function ble-edit/load-keymap-definition:vi { :; }

source "$_ble_base/keymap/vi_digraph.sh"

# utils

## 関数 ble/string#index-of-chars text chars
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
## 関数 ble/string#last-index-of-chars text chars
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
function ble-edit/content/find-nol-from-bol {
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
# vi-insert/default, vi_command/default

function ble/widget/vi-insert/default {
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    ble/widget/vi-insert/normal-mode
    ble-decode-key "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
    return 0
  fi

  # Control 修飾された文字 C-@ - C-\, C-? は制御文字 \000 - \037, \177 に戻して挿入
  if ((flag==ble_decode_Ctrl&&63<=code&&code<128&&(code&0x1F)!=0)); then
    ((code=code==63?127:code&0x1F))
    local -a KEYS=("$code")
    ble/widget/self-insert
    return 0
  fi

  return 1
}

function ble/widget/vi_command/default {
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    ble/widget/vi-command/bell
    ble-decode-key "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
    return 0
  fi

  return 1
}

function ble/widget/vi_omap/default {
  ble/widget/vi_command/default || ble/widget/vi-command/bell
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

function ble/widget/vi-insert/@norepeat {
  ble/widget/vi-insert/.reset-repeat
  ble/widget/"$@"
}

function ble/widget/vi-insert/.log-repeat {
  if [[ $_ble_keymap_vi_repeat ]]; then
    ble/array#push _ble_keymap_vi_repeat_keylog "${KEYS[@]}"
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

function ble/keymap:vi/update-mode-name {
  local kmap=$_ble_decode_key__kmap
  local show= overwrite=
  if [[ $kmap == vi_insert ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && ( $kmap == vi_command || $kmap == vi_omap ) ]]; then
    show=1 overwrite=$_ble_keymap_vi_single_command_overwrite
  fi

  local name=
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
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/content/nonbol-eolp "$index"
}
function ble/keymap:vi/adjust-command-mode {
  [[ $_ble_decode_key__kmap == vi_omap ]] && ble-decode/keymap/pop

  if [[ $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/content/nonbol-eolp "$index" && ble/widget/.goto-char index
    fi
    ble/widget/vi-command/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite"
  fi

  return 0
}
function ble/widget/vi-command/bell {
  ble/widget/.bell
  ble/keymap:vi/adjust-command-mode
}


function ble/widget/vi-command/.insert-mode {
  [[ $_ble_decode_key__kmap == vi_omap ]] && ble-decode/keymap/pop
  local arg=$1 overwrite=$2
  ble/widget/vi-insert/.reset-repeat "$arg"
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
  _ble_edit_arg=
  ble/widget/vi-command/.insert-mode
  ble/widget/accept-line
}
function ble/widget/vi-command/accept-single-line-or {
  if ble-edit/content/is-single-line; then
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

## 関数 ble/keymap:vi/get-arg [default_value]
function ble/keymap:vi/get-arg {
  local rex='^[0-9]+$' default_value=$1
  if [[ ! $_ble_edit_arg ]]; then
    flag= arg=$default_value
  elif [[ $_ble_edit_arg =~ $rex ]]; then
    flag= arg=$((10#${_ble_edit_arg:-1}))
  else
    local a=${_ble_edit_arg##*[!0-9]} b=${_ble_edit_arg%%[!0-9]*}
    flag=${_ble_edit_arg//[0-9]}
    arg=$((10#${a:-1}*10#${b:-1}))
  fi
  _ble_edit_arg=
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
  if [[ $ch == 0 && $_ble_edit_arg != *[0-9] ]]; then
    ble/widget/vi-command/beginning-of-line
    return
  fi

  _ble_edit_arg="$_ble_edit_arg$ch"
}

function ble/widget/vi-command/set-operator {
  local ret ch=$1
  ble-assert '[[ $ch != *[0-9]* ]]' "ch=$ch"

  if [[ ! ${_ble_edit_arg//[0-9]} ]]; then
    # 1つ目のオペレータ
    [[ $_ble_decode_key__kmap == vi_omap ]] ||
      ble-decode/keymap/push vi_omap

  else
    # 2つ目のオペレータ (yy dd cc)
    if [[ $_ble_edit_arg == *"$ch"* ]]; then
      if [[ $2 ]]; then
        ble/widget/vi-command/"$2" # _ble_edit_arg should be consumed here
        return
      elif ble/util/isfunction ble/keymap:vi/operator:"$ch"; then
        local arg flag; ble/keymap:vi/get-arg 1 # _ble_edit_arg is consumed here
        ble-edit/content/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
        ble-edit/content/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
        ((end<${#_ble_edit_str}&&end++))
        local _ble_keymap_vi_operator_delayed=
        ble/keymap:vi/operator:"$ch" "$beg" "$end" line
        [[ $_ble_keymap_vi_operator_delayed ]] && return
        ble/widget/vi-command/first-non-space
        return
      fi
    fi

    _ble_edit_arg=
    ble/widget/vi-command/bell
    return 1
  fi

  _ble_edit_arg="$_ble_edit_arg$ch"
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

function ble/keymap:vi/operator:y {
  if [[ $3 == line ]]; then
    ble/widget/.copy-range "$1" "$2" 1 L
  else
    ble/widget/.copy-range "$1" "$2" 1
  fi
}
function ble/keymap:vi/operator:tr.impl {
  local beg=$1 end=$2 filter=$3
  local ret; "$filter" "${_ble_edit_str:beg:end-beg}"
  _ble_edit_str.replace "$beg" "$end" "$ret"
}
function ble/keymap:vi/operator:u {
  ble/keymap:vi/operator:tr.impl "$1" "$2" ble/string#tolower
}
function ble/keymap:vi/operator:U {
  ble/keymap:vi/operator:tr.impl "$1" "$2" ble/string#toupper
}
function ble/keymap:vi/operator:~ {
  ble/keymap:vi/operator:tr.impl "$1" "$2" ble/string#toggle-case
}
function ble/keymap:vi/operator:? {
  ble/keymap:vi/operator:tr.impl "$1" "$2" ble/keymap:vi/string#encode-rot13
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
  ble-edit/content/find-nol-from-bol "$bol2"; local nol2=$ret
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
  local arr; ble/string#split arr $'\n' "$text"
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

  [[ $context == char ]] && ble-edit/content/find-nol-from-bol "$beg"; beg=$ret
}
function ble/keymap:vi/operator:left {
  ble/keymap:vi/operator:increase-indent -8 "$3"
}
function ble/keymap:vi/operator:right {
  ble/keymap:vi/operator:increase-indent 8 "$3"
}

## 関数 ble/widget/vi-command/exclusive-range.impl src dst flag nobell
##   @param[in] src, dst
##   @param[in] flag
##   @param[in] nobell
function ble/widget/vi-command/exclusive-range.impl {
  local src=$1 dst=$2 flag=$3 nobell=$4
  if [[ $flag ]]; then
    if [[ $flag == [cd] ]]; then
      ble/widget/.kill-range "$src" "$dst" 0
      if [[ $flag == c ]]; then
        ble/widget/vi-command/.insert-mode
      else
        ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char _ble_edit_ind-1
      fi
    elif ble/util/isfunction ble/keymap:vi/operator:"$flag"; then
      local beg end; ((dst<src?(beg=dst,end=src):(beg=src,end=dst)))
      local _ble_keymap_vi_operator_delayed=
      ble/keymap:vi/operator:"$flag" "$beg" "$end" char
      [[ $_ble_keymap_vi_operator_delayed ]] && return
      ((beg!=_ble_edit_ind)) && ble/widget/.goto-char "$beg"
    else
      ble/widget/.bell
    fi
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

## 関数 ble/widget/vi-command/linewise-range.impl beg end flag opts
## 関数 ble/widget/vi-command/linewise-goto.impl index flag opts
##
##   @param[in] beg, end
##     開始位置と終了位置を指定します。
##     flag が設定されていない場合は end に移動します。
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
##     既に計算済みの移動先 (index, end) の行の行頭がある場合はここに指定します。
##
##   @var[in] nolx
##     既に計算済みの移動先 (index, end) の行の非空白行頭位置がある場合はここに指定します。
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
    local reverted=$((p==qbase?qline<0:qbase<p))

    # 最初の行の行頭 beg と最後の行の行末 end
    local beg end
    if ((!reverted)); then
      ble-edit/content/find-logical-bol "$p"; beg=$ret
      ble-edit/content/find-logical-eol "$qbase" "$qline"; end=$ret
    else
      if [[ ! $bolx ]]; then
        ble-edit/content/find-logical-bol "$qbase" "$qline"; bolx=$ret
      fi
      ble-edit/content/find-logical-eol "$p"; beg=$bolx end=$ret
    fi

    # jk+- で1行も移動できない場合は操作をキャンセルする。
    # Note: qline を用いる場合は必ずしも望みどおり
    #   qline 行目になっているとは限らないことに注意する。
    if [[ :$opts: == *:require_multiline:* ]]; then
      local is_single_line=
      if ((qbase==p&&qline==0)); then
        is_single_line=1
      elif ble-edit/content/find-logical-bol "$end"; ((beg==ret)); then
        is_single_line=1
      fi

      if [[ $is_single_line ]]; then
        ble/widget/vi-command/bell
        return
      fi
    fi

    ((end<${#_ble_edit_str}&&end++))
    if [[ $flag == [cd] ]]; then
      ble/widget/.kill-range "$beg" "$end" 1 L
      ((beg!=_ble_edit_ind)) && ble/widget/.goto-char "$beg"
      if [[ $flag == c ]]; then
        ble/widget/insert-string $'\n'
        ble/widget/.goto-char "$beg"
        ble/widget/vi-command/.insert-mode
      else
        ble/widget/vi-command/first-non-space
      fi
    elif ble/util/isfunction ble/keymap:vi/operator:"$flag"; then
      # オペレータ呼び出し
      local _ble_keymap_vi_operator_delayed=
      ble/keymap:vi/operator:"$flag" "$beg" "$end" line
      [[ $_ble_keymap_vi_operator_delayed ]] && return

      # 範囲の先頭に移動
      local ind=$_ble_edit_ind
      if ((ind!=beg)); then
        if [[ :$opts: == *:preserve_column:* ]]; then
          if ((beg<ind)); then
            ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
            ((ret=-ret))
          else
            ble/string#count-char "${_ble_edit_str:ind:beg-ind}" $'\n'
          fi
          ((ret)) && ble/widget/vi-command/.relative-line "$ret"
        else
          if ((beg==bolx)) && [[ $nolx ]]; then
            local bnol=$nolx
          else
            ble-edit/content/find-nol-from-bol "$beg"; local bnol=$ret
          fi
          ble-edit/content/nonbol-eolp "$bnol" && ((bnol--))
          ble/widget/.goto-char "$bnol"
        fi
      fi

      ble/keymap:vi/adjust-command-mode
    elif [[ $flag ]]; then
      ble/widget/vi-command/bell
    fi
  else
    if [[ ! $nolx ]]; then
      if [[ ! $bolx ]]; then
        ble-edit/content/find-logical-bol "$qbase" "$qline"; bolx=$ret
      fi
      ble-edit/content/find-nol-from-bol "$bolx"; nolx=$ret
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

## 編集関数 ble/widget/vi-command/forward-char [type]
## 編集関数 ble/widget/vi-command/backward-char [type]
##
##   @param[in] type
##     type=m のとき複数行に亘る移動を許します。
##
function ble/widget/vi-command/forward-char {
  local arg flag; ble/keymap:vi/get-arg 1

  local index
  if [[ $1 == m ]]; then
    local width=$arg line
    while ((width<=${#_ble_edit_str}-_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=arg)) && break
      ((width+=arg-${#line}))
    done
    ((index=_ble_edit_ind+width,index>${#_ble_edit_str}&&(index=${#_ble_edit_str})))
    ((index<${#_ble_edit_str})) && ble-edit/content/nonbol-eolp $index && ((index++))
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
    local width=$arg line
    while ((width<=_ble_edit_ind)); do
      line=${_ble_edit_str:_ble_edit_ind-width:width}
      line=${line//[!$'\n']$'\n'/x}
      ((${#line}>=arg)) && break
      ((width+=arg-${#line}))
    done
    ((index=_ble_edit_ind-width,index<0&&(index=0)))
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
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
      _ble_edit_str.replace "$_ble_edit_ind" "$index" "$ret"
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
      ble/widget/.goto-char ${#_ble_edit_str}
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

## 編集関数 ble/widget/vi-command/forward-line
## 編集関数 ble/widget/vi-command/backward-line
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
function ble/widget/vi-command/.relative-line {
  local arg=$1 flag=$2
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
    if ble-edit/text/is-position-up-to-date; then
      # 列の表示相対位置 (x,y) を保持
      local b1x b1y; ble-edit/text/getxy.cur --prefix=b1 "$bol1"
      local b2x b2y; ble-edit/text/getxy.cur --prefix=b2 "$bol2"

      ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
      local c1x c1y; ble-edit/text/getxy.cur --prefix=c1 "$ind"
      local e2x e2y; ble-edit/text/getxy.cur --prefix=e2 "$eol2"

      local x=$c1x y=$((b2y+c1y-b1y))
      ((y>e2y&&(x=e2x,y=e2y)))

      ble-edit/text/get-index-at $x $y # local variable "index" is set here
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
  ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count)) || ((nmove)) || ble/widget/.bell
}
function ble/widget/vi-command/forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-line "$arg" "$flag"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command/backward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-line "$((-arg))" "$flag"
  ble/keymap:vi/adjust-command-mode
}

#------------------------------------------------------------------------------
# command: ^ + - $

function ble/widget/vi-command/.relative-first-non-space {
  local arg=$1 flag=$2
  local ret ind=$_ble_edit_ind
  ble-edit/content/find-logical-bol "$ind" "$arg"; local bolx=$ret
  ble-edit/content/find-nol-from-bol "$bolx"; local nolx=$ret

  # 2017-09-12 何故か分からないが vim はこういう振る舞いに見える。
  ((_ble_keymap_vi_single_command==2&&_ble_keymap_vi_single_command--))

  if [[ $flag ]]; then
    if ((arg==0)); then
      # command: ^
      ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
      ble/widget/vi-command/exclusive-goto.impl "$nolx" "$flag"
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
    ble-edit/content/nonbol-eolp "$nolx" && ((nolx--))
    ble/widget/.goto-char "$nolx"
    return
  fi

  # 履歴項目の移動
  if ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count)) || ((nmove)); then
    ble/widget/vi-command/first-non-space
  else
    ble/widget/.bell
  fi
}

function ble/widget/vi-command/first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-first-non-space 0 "$flag"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command/forward-first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-first-non-space "$arg" "$flag"
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vi-command/backward-first-non-space {
  local arg flag; ble/keymap:vi/get-arg 1
  ble/widget/vi-command/.relative-first-non-space "$((-arg))" "$flag"
  ble/keymap:vi/adjust-command-mode
}

function ble/widget/vi-command/forward-eol {
  local arg flag; ble/keymap:vi/get-arg 1
  local ret index
  ble-edit/content/find-logical-eol "$_ble_edit_ind" $((arg-1)); index=$ret
  ble/keymap:vi/needs-eol-fix "$index" && ((index--))
  ble/widget/vi-command/inclusive-goto.impl "$index" "$flag" 1
}

#------------------------------------------------------------------------------
# command: p P

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
  else
    if ((is_after&&_ble_edit_ind<${#_ble_edit_str})); then
      ble/widget/.goto-char _ble_edit_ind+1
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    ble/widget/insert-string "$ret"
    [[ $_ble_keymap_vi_single_command ]] || ble/widget/.goto-char _ble_edit_ind-1
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
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-forward-char-and-insert {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}c
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-backward-char {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/backward-char
  fi
}
function ble/widget/vi-command/kill-forward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/forward-eol
  fi
}
function ble/widget/vi-command/kill-forward-line-and-insert {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}c
    ble/widget/vi-command/forward-eol
  fi
}

#------------------------------------------------------------------------------
# command: w W b B e E

function ble/widget/vi-command/forward-word.impl {
  local arg=$1 flag=$2 rex_word=$3
  local bl=$' \t' nl=$'\n'
  local rex="^((($rex_word)$nl?|[$bl]+$nl?|$nl)([$bl]+$nl)*[$bl]*){0,$arg}" # 単語先頭または空行に止まる
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
  local bl=$' \t' nl=$'\n'
  local rex="((($rex_word)$nl?|[$bl]+$nl?|$nl)([$bl]+$nl)*[$bl]*){0,$arg}\$" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind-${#BASH_REMATCH}))
  ble/widget/vi-command/exclusive-goto.impl "$index" "$flag"
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

#------------------------------------------------------------------------------
# command: [cdy]?[|HL] G gg

function ble/widget/vi-command/nth-column {
  local arg flag; ble/keymap:vi/get-arg 1

  local ret index
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-logical-eol; local eol=$ret
  if ble-edit/text/is-position-up-to-date; then
    local bx by; ble-edit/text/getxy.cur --prefix=b "$bol" # Note: 先頭行はプロンプトにより bx!=0
    local ex ey; ble-edit/text/getxy.cur --prefix=e "$eol"
    local dstx=$((bx+arg-1)) dsty=$by cols=${COLUMNS:-80}
    ((dsty+=dstx/cols,dstx%=cols))
    ((dsty>ey&&(dsty=ey,dstx=ex)))
    ble-edit/text/get-index-at "$dstx" "$dsty" # local variable "index" is set here
    ble-edit/content/nonbol-eolp "$index" && ((index--))
  else
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
      _ble_edit_arg=$arg$flag
    else
      _ble_edit_arg=$flag
    fi
    ble/widget/vi-command/nth-line
    return
  fi

  if ((arg)); then
    ble-edit/history/goto $((arg-1))
  else
    ble/widget/history-beginning
  fi
  ble/keymap:vi/adjust-command-mode
}

# G in history
function ble/widget/vi-command/history-end {
  local arg flag; ble/keymap:vi/get-arg 0
  if [[ $flag ]]; then
    if ((arg)); then
      _ble_edit_arg=$arg$flag
      ble/widget/vi-command/nth-line
    else
      _ble_edit_arg=$flag
      ble/widget/vi-command/nth-last-line
    fi
    return
  fi

  if ((arg)); then
    ble-edit/history/goto $((arg-1))
  else
    ble/widget/history-end
  fi
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
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]] || ! ble-decode-key/ischar "$key"; then
    ble/widget/.bell
  else
    local pos=$_ble_edit_ind

    local -a KEYS=("$key")
    local _ble_edit_arg=$arg
    local _ble_edit_overwrite_mode=$overwrite_mode
    local ble_widget_self_insert_opts=nolineext
    ble/widget/self-insert

    ((pos<_ble_edit_ind)) && ble/widget/.goto-char _ble_edit_ind-1
  fi
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
      _ble_edit_str.replace eol eol+1 ' '
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
    local ret; ble-edit/content/find-logical-eol; local eol=$ret
    ble/widget/.goto-char "$eol"
    ble/widget/insert-string $'\n'
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-mode-at-backward-line {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    local ret; ble-edit/content/find-logical-bol; local bol=$ret
    ble/widget/.goto-char "$bol"
    ble/widget/insert-string $'\n'
    ble/widget/.goto-char "$bol"
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
    ble-decode-key/ischar "$key" || return 1
    ble/util/c2s "$key"; local c=$ret
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
  ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
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
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
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

  if [[ $linewise ]]; then
    local nolx= bolx=
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
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
  ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
}

## 関数 ble/keymap:vi/text-object/sentence.impl/backward-extend
##   @var[in,out] beg
##   @var[in] bop
function ble/keymap:vi/text-object/sentence.impl/backward-extend {
  local ifs=$' \t\n'
  if local rex="(^|[.!?])([$ifs]+)\$"; [[ ${_ble_edit_str:bop:beg+1-bop} =~ $rex ]]; then
    local rematch2=${BASH_REMATCH[2]} # Note:for bash-3.1 ${#arr[n]} bug
    ((beg=beg+1-${#rematch2}))
  else
    rex="^(.*[.!?])[$ifs]+"
    if [[ ${_ble_edit_str:bop:beg-bop} =~ $rex ]]; then
      beg=$((bop+${#BASH_REMATCH}))
    else
      beg=$bop
    fi
  fi
}
## 関数 ble/keymap:vi/text-object/sentence.impl/forward-extend
##   @var[in,out] end
##   @var[in] eop
function ble/keymap:vi/text-object/sentence.impl/forward-extend {
  local ifs=$' \t\n'
  if local rex="(^|[.!?])[$ifs]+\$"; [[ ${_ble_edit_str:bop:end+1-bop} =~ $rex ]]; then
    rex="^[$ifs]*"
    [[ ${_ble_edit_str:end:eop-end} =~ $rex ]]
    ((end+=${#BASH_REMATCH}))
  else
    rex="[.!?]([$ifs].*)?\$"
    if [[ ${_ble_edit_str:end:eop-end} =~ $rex ]]; then
      end=$((eop-(${#BASH_REMATCH}-1)))
    else
      end=$eop
    fi
  fi
}
function ble/keymap:vi/text-object/sentence.impl {
  local arg=$1 flag=$2 type=$3
  local rex

  local piv=$_ble_edit_ind
  if ble-edit/content/bolp && ble-edit/content/eolp; then
    # 次の非空行の前の行が対象 (is as で違いはない)
    if rex=$'^\n+[^\n]'; [[ ${_ble_edit_str:_ble_edit_ind} =~ $rex ]]; then
      local end=$((_ble_edit_ind+${#BASH_REMATCH}-2))
      local beg=$end bolx=$end nolx=
      ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
      return 0
    fi

    if rex=$'\n+$'; [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]; then
      ((piv-=${#BASH_REMATCH}))
    fi

    # 空行しかないときは全体が対象 (is as で違いはない)
    if ((piv==0)); then
      local beg=0 end=${#_ble_edit_str}
      local bolx=$end nolx=$end
      ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
      return 0
    fi
  fi

  # 二重改行で区切られた "段落" に制限する
  local ret bop=0 eop=${#_ble_edit_str}
  ble/string#last-index-of "${_ble_edit_str::piv}" $'\n\n' && bop=$((ret+2))
  ble/string#index-of "${_ble_edit_str:piv}" $'\n\n' && eop=$((piv+ret))
  ((bop<eop)) && [[ ${_ble_edit_str:eop-1:1} == $'\n' ]] && ((eop--))
  ((bop<eop)) && [[ ${_ble_edit_str:bop:1} == $'\n' ]] && ((bop++))


  local beg=$piv end=$piv
  ble/keymap:vi/text-object/sentence.impl/backward-extend
  if [[ $type == i* ]]; then
    local i
    for ((i=0;i<arg;i++)); do
      ble/keymap:vi/text-object/sentence.impl/forward-extend
    done
  else
    local i
    for ((i=0;i<arg;i++)); do
      ble/keymap:vi/text-object/sentence.impl/forward-extend
      ble/keymap:vi/text-object/sentence.impl/forward-extend
    done
  fi

  # 両端の改行は除外する
  ((beg<end)) && [[ ${_ble_edit_str:end-1:1} == $'\n' ]] && ((end--))
  ((beg<end)) && [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))

  # at は後方に空白を確保できなければ前方に空白を確保する。
  if [[ $type != i* ]]; then
    local ifs=$' \t\n'
    if [[ ${_ble_edit_str:beg:1} != ["$ifs"] && ${_ble_edit_str:end-1:1} != ["$ifs"] ]]; then
      if ((bop<beg)) && rex="(^|[.!?])([$ifs]+)\$" && [[ ${_ble_edit_str:bop:beg-bop} =~ $rex ]]; then
        local rematch2=${BASH_REMATCH[2]}
        ((beg-=${#rematch2}))
        [[ ${_ble_edit_str:beg:1} == $'\n' ]] && ((beg++))
      fi
    fi
  fi

  if ble-edit/content/bolp "$beg" && ble-edit/content/eolp "$end"; then
    local bolx= nolx=
    ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
  else
    ble/widget/vi-command/exclusive-range.impl "$beg" "$end" "$flag"
  fi
}

function ble/keymap:vi/text-object/paragraph.impl {
  local arg=$1 flag=$2 type=$3
  local rex ret

  local beg= empty_start=
  ble-edit/content/find-logical-bol; local bol=$ret
  ble-edit/content/find-nol-from-bol "$bol"; local nol=$ret
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
  ble/widget/vi-command/linewise-range.impl "$beg" "$end" "$flag"
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
  _ble_edit_arg=$arg$flag
  [[ $flag ]] || return 1

  _ble_keymap_vi_text_object=$c
  _ble_decode_key__hook=ble/keymap:vi/text-object.hook
  return 0
}

function ble/widget/vi-command/text-object {
  ble/keymap:vi/.check-text-object || ble/widget/vi-command/bell
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
  ble-bind -f y 'vi-command/set-operator y'
  ble-bind -f d 'vi-command/set-operator d kill-current-line'
  ble-bind -f c 'vi-command/set-operator c kill-current-line-and-insert'
  ble-bind -f '<' 'vi-command/set-operator left'
  ble-bind -f '>' 'vi-command/set-operator right'
  ble-bind -f 'g ~' 'vi-command/set-operator ~'
  ble-bind -f 'g u' 'vi-command/set-operator u'
  ble-bind -f 'g U' 'vi-command/set-operator U'
  ble-bind -f 'g ?' 'vi-command/set-operator ?'
  # ble-bind -f 'g @' 'vi-command/set-operator @'
  # ble-bind -f '!'   'vi-command/set-operator !'
  # ble-bind -f '='   'vi-command/set-operator ='
  # ble-bind -f 'g q' 'vi-command/set-operator q'
  # ble-bind -f 'z f' 'vi-command/set-operator f'

  ble-bind -f home  vi-command/beginning-of-line
  ble-bind -f '$'   vi-command/forward-eol
  ble-bind -f end   vi-command/forward-eol
  ble-bind -f '^'   vi-command/first-non-space
  ble-bind -f '+'   vi-command/forward-first-non-space
  ble-bind -f '-'   vi-command/backward-first-non-space

  ble-bind -f h     vi-command/backward-char
  ble-bind -f l     vi-command/forward-char
  ble-bind -f left  vi-command/backward-char
  ble-bind -f right vi-command/forward-char
  ble-bind -f C-h   'vi-command/backward-char m'
  ble-bind -f DEL   'vi-command/backward-char m'
  ble-bind -f SP    'vi-command/forward-char m'

  ble-bind -f j     vi-command/forward-line
  ble-bind -f k     vi-command/backward-line
  ble-bind -f down  vi-command/forward-line
  ble-bind -f up    vi-command/backward-line
  ble-bind -f C-n   vi-command/forward-line
  ble-bind -f C-p   vi-command/backward-line

  ble-bind -f w       vi-command/forward-vword
  ble-bind -f W       vi-command/forward-uword
  ble-bind -f b       vi-command/backward-vword
  ble-bind -f B       vi-command/backward-uword
  ble-bind -f e       vi-command/forward-vword-end
  ble-bind -f E       vi-command/forward-uword-end
  ble-bind -f C-right vi-command/forward-vword
  ble-bind -f C-left  vi-command/backward-vword

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

  ble-bind -f 'C-\ C-n' nop

  ble-bind -f 'C-m' vi-command/forward-first-non-space
  ble-bind -f 'RET' vi-command/forward-first-non-space
  ble-bind -f 'C-j' vi-command/forward-line

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f C-left  vi-command/backward-vword
  ble-bind -f M-left  vi-command/backward-uword
  ble-bind -f C-right vi-command/forward-vword-end
  ble-bind -f M-right vi-command/forward-uword-end
}

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command

  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi_command/default

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

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-q' quoted-insert
  ble-bind -f 'C-v' quoted-insert

  ble-bind -f 'C-j' 'vi-command/accept-line'
  ble-bind -f 'C-m' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'
  ble-bind -f 'RET' 'vi-command/accept-single-line-or vi-command/forward-first-non-space'

  ble-bind -f 'C-g' bell
  ble-bind -f 'C-l' clear-screen
}

function ble-decode-keymap:vi_omap/define {
  local ble_bind_keymap=vi_omap
  ble/keymap:vi/setup-map

  ble-bind -f __default__ vi_omap/default

  ble-bind -f a   vi-command/text-object
  ble-bind -f i   vi-command/text-object

  ble-bind -f '~' 'vi-command/set-operator ~'
  ble-bind -f 'u' 'vi-command/set-operator u'
  ble-bind -f 'U' 'vi-command/set-operator U'
  ble-bind -f '?' 'vi-command/set-operator ?'
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
    ble/widget/vi-insert/@norepeat magic-space
  fi
}
function ble/widget/vi-insert/accept-single-line-or {
  if ble-edit/content/is-single-line; then
    ble/widget/vi-insert/@norepeat accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi-insert/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/vi-insert/@norepeat delete-region
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
  ble-edit/content/find-nol-from-bol "$bol"; local nol=$ret
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
  ble-bind -f __before_command__ vi-insert/.log-repeat

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
  ble-bind -f 'C-i' 'vi-insert/@norepeat complete'
  ble-bind -f 'TAB' 'vi-insert/@norepeat complete'

  # history
  ble-bind -f 'C-r'     'vi-insert/@norepeat history-isearch-backward'
  ble-bind -f 'C-s'     'vi-insert/@norepeat history-isearch-forward'
  ble-bind -f 'C-prior' 'vi-insert/@norepeat history-beginning'
  ble-bind -f 'C-next'  'vi-insert/@norepeat history-end'
  ble-bind -f 'SP'      'vi-insert/magic-space'

  ble-bind -f 'C-l' clear-screen
  ble-bind -f 'C-k' 'vi-insert/@norepeat kill-forward-line'

  # ble-bind -f  'C-o' 'vi-insert/@norepeat accept-and-next'

  #----------------------------------------------------------------------------
  # from keymap emacs-standard

  # shell function
  ble-bind -f  'C-j'     'vi-insert/@norepeat accept-line'
  ble-bind -f  'C-g'     'vi-insert/@norepeat bell'
  ble-bind -f  'f1'      command-help
  ble-bind -f  'C-x C-v' display-shell-version
  ble-bind -cf 'C-z'     fg
  # ble-bind -f 'C-c'      discard-line
  # ble-bind -f  'M-l'     redraw-line
  # ble-bind -cf 'M-z'     fg

  # history
  # ble-bind -f 'C-RET'   'vi-insert/@norepeat history-expand-line'
  # ble-bind -f 'M-<'     'vi-insert/@norepeat history-beginning'
  # ble-bind -f 'M->'     'vi-insert/@norepeat history-end'

  # kill
  ble-bind -f 'C-@'      set-mark
  ble-bind -f 'C-x C-x'  'vi-insert/@norepeat exchange-point-and-mark'
  ble-bind -f 'C-y'      'vi-insert/@norepeat yank'
  # ble-bind -f 'C-w'      'vi-insert/@norepeat kill-region-or uword'
  # ble-bind -f 'M-SP'     set-mark
  # ble-bind -f 'M-w'      'copy-region-or uword'

  # spaces
  # ble-bind -f 'M-\'      'vi-insert/@norepeat delete-horizontal-space'

  # charwise operations
  ble-bind -f 'C-f'      'vi-insert/@norepeat nomarked forward-char'
  ble-bind -f 'C-b'      'vi-insert/@norepeat nomarked backward-char'
  ble-bind -f 'right'    'vi-insert/@norepeat nomarked forward-char'
  ble-bind -f 'left'     'vi-insert/@norepeat nomarked backward-char'
  ble-bind -f 'S-C-f'    'vi-insert/@norepeat marked forward-char'
  ble-bind -f 'S-C-b'    'vi-insert/@norepeat marked backward-char'
  ble-bind -f 'S-right'  'vi-insert/@norepeat marked forward-char'
  ble-bind -f 'S-left'   'vi-insert/@norepeat marked backward-char'
  ble-bind -f 'C-d'      'vi-insert/@norepeat delete-region-or forward-char-or-exit'
  ble-bind -f 'delete'   'vi-insert/@norepeat delete-region-or forward-char'
  ble-bind -f 'C-h'      'vi-insert/delete-region-or vi-insert/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'DEL'      'vi-insert/delete-region-or vi-insert/delete-backward-indent-or delete-backward-char'
  ble-bind -f 'C-t'      'vi-insert/@norepeat transpose-chars'

  # wordwise operations
  ble-bind -f 'C-right'   'vi-insert/@norepeat nomarked forward-cword'
  ble-bind -f 'C-left'    'vi-insert/@norepeat nomarked backward-cword'
  ble-bind -f 'S-C-right' 'vi-insert/@norepeat marked forward-cword'
  ble-bind -f 'S-C-left'  'vi-insert/@norepeat marked backward-cword'
  ble-bind -f 'C-delete'  'vi-insert/@norepeat delete-forward-cword'
  ble-bind -f 'C-_'       'delete-backward-cword'
  # ble-bind -f 'M-right'   'vi-insert/@norepeat nomarked forward-sword'
  # ble-bind -f 'M-left'    'vi-insert/@norepeat nomarked backward-sword'
  # ble-bind -f 'S-M-right' 'vi-insert/@norepeat marked forward-sword'
  # ble-bind -f 'S-M-left'  'vi-insert/@norepeat marked backward-sword'
  # ble-bind -f 'M-d'       'vi-insert/@norepeat kill-forward-cword'
  # ble-bind -f 'M-h'       'vi-insert/@norepeat kill-backward-cword'
  # ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  # ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  # ble-bind -f 'M-f'       'vi-insert/@norepeat nomarked forward-cword'
  # ble-bind -f 'M-b'       'vi-insert/@norepeat nomarked backward-cword'
  # ble-bind -f 'M-F'       'vi-insert/@norepeat marked forward-cword'
  # ble-bind -f 'M-B'       'vi-insert/@norepeat marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'      'vi-insert/@norepeat nomarked beginning-of-line'
  ble-bind -f 'C-e'      'vi-insert/@norepeat nomarked end-of-line'
  ble-bind -f 'home'     'vi-insert/@norepeat nomarked beginning-of-line'
  ble-bind -f 'end'      'vi-insert/@norepeat nomarked end-of-line'
  ble-bind -f 'S-C-a'    'vi-insert/@norepeat marked beginning-of-line'
  ble-bind -f 'S-C-e'    'vi-insert/@norepeat marked end-of-line'
  ble-bind -f 'S-home'   'vi-insert/@norepeat marked beginning-of-line'
  ble-bind -f 'S-end'    'vi-insert/@norepeat marked end-of-line'
  ble-bind -f 'C-u'      'vi-insert/@norepeat kill-backward-line'
  # ble-bind -f 'M-m'      'vi-insert/@norepeat nomarked beginning-of-line'
  # ble-bind -f 'S-M-m'    'vi-insert/@norepeat marked beginning-of-line'

  ble-bind -f 'C-p'      'vi-insert/@norepeat nomarked backward-line-or-history-prev'
  ble-bind -f 'up'       'vi-insert/@norepeat nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'      'vi-insert/@norepeat nomarked forward-line-or-history-next'
  ble-bind -f 'down'     'vi-insert/@norepeat nomarked forward-line-or-history-next'
  ble-bind -f 'S-C-p'    'vi-insert/@norepeat marked backward-line'
  ble-bind -f 'S-up'     'vi-insert/@norepeat marked backward-line'
  ble-bind -f 'S-C-n'    'vi-insert/@norepeat marked forward-line'
  ble-bind -f 'S-down'   'vi-insert/@norepeat marked forward-line'

  ble-bind -f 'C-home'   'vi-insert/@norepeat nomarked beginning-of-text'
  ble-bind -f 'C-end'    'vi-insert/@norepeat nomarked end-of-text'
  ble-bind -f 'S-C-home' 'vi-insert/@norepeat marked beginning-of-text'
  ble-bind -f 'S-C-end'  'vi-insert/@norepeat marked end-of-text'

  ble-bind -f 'C-\' bell
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

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

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_insert  >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_command >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_omap    >> "$fname_keymap_cache"
  ble-decode/keymap/dump isearch    >> "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.vi... done" >&2
}

ble-decode-keymap:vi/initialize
