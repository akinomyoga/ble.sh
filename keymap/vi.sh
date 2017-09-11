#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されうるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
function ble-edit/load-keymap-definition:vi { :; }

ble-edit/load-keymap-definition isearch

# utils

function ble-edit/text/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
function ble-edit/text/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
function ble-edit/text/nonbol-eolp {
  local pos=${1:-$_ble_edit_ind}
  ! ble-edit/text/bolp "$pos" && ble-edit/text/eolp "$pos"
}

function ble/widget/nop { :; }

#------------------------------------------------------------------------------
# vi-insert/default

function ble/widget/vi-insert/default {
  local flag=$((KEYS[0]&ble_decode_MaskFlag)) code=$((KEYS[0]&ble_decode_MaskChar))

  # メタ修飾付きの入力 M-key は ESC + key に分解する
  if ((flag&ble_decode_Meta)); then
    ble/widget/vi-insert/normal-mode
    ble-decode-key "$((KEYS[0]&~ble_decode_Meta))" "${KEYS[@]:1}"
    return 0
  fi

  # Control 修飾された文字 C-@ - C-\, C-? は制御文字 \000 - \037, \177 に戻す
  if ((flag==ble_decode_Ctrl&&63<=code&&code<128&&(code&0x1F)!=0)); then
    ((code=code==63?127:code&0x1F))
    local -a KEYS=("$code")
    ble/widget/self-insert
    return 0
  fi

  return 1
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
  local show= overwrite=
  if [[ $_ble_decode_key__kmap == vi_insert ]]; then
    show=1 overwrite=$_ble_edit_overwrite_mode
  elif [[ $_ble_keymap_vi_single_command && $_ble_decode_key__kmap == vi_command ]]; then
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
  _ble_edit_overwrite_mode=
  ble-edit/text/bolp || ble/widget/.goto-char _ble_edit_ind-1
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
  _ble_edit_overwrite_mode=
  ble-edit/text/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
  ble-edit/text/eolp && _ble_keymap_vi_single_command=2
  ble-decode/keymap/push vi_command
  ble/keymap:vi/update-mode-name
}

## 関数 ble/keymap:vi/needs-eol-fix
##
##   Note: この関数を使った後は ble/keymap:vi/check-single-command-mode を呼び出す必要がある。
##     そうしないとノーマルモードにおいてありえない位置にカーソルが来ることになる。
##
function ble/keymap:vi/needs-eol-fix {
  [[ $_ble_keymap_vi_single_command ]] && return 1
  local index=${1:-$_ble_edit_ind}
  ble-edit/text/nonbol-eolp "$index"
}
function ble/keymap:vi/check-single-command-mode {
  if [[ $_ble_keymap_vi_single_command ]]; then
    if ((_ble_keymap_vi_single_command==2)); then
      local index=$((_ble_edit_ind+1))
      ble-edit/text/nonbol-eolp "$index" && ble/widget/.goto-char index
    fi
    ble/widget/vi-command/.insert-mode 1 "$_ble_keymap_vi_single_command_overwrite"
    return 0
  else
    return 1
  fi
}

function ble/widget/vi-command/.insert-mode {
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
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/append-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    if ! ble-edit/text/eolp; then
      ble/widget/.goto-char "$((_ble_edit_ind+1))"
    fi
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/append-eol-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/text/find-logical-eol
    ble/widget/.goto-char "$ret"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-bol-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/text/find-logical-bol
    ble/widget/.goto-char "$ret"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-nol-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/vi-command/first-non-space
    [[ ${_ble_edit_str:_ble_edit_ind:1} == [$' \t'] ]] &&
      ble/widget/.goto-char _ble_edit_ind+1 # 逆eol補正
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/replace-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/vi-command/.insert-mode "$arg" R
  fi
}
function ble/widget/vi-command/virtual-replace-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/vi-command/.insert-mode "$arg" 1
  fi
}
function ble/widget/vi-command/accept-line {
  _ble_edit_arg=
  ble-decode/keymap/pop
  ble/widget/accept-line
}
function ble/widget/vi-command/accept-single-line-or {
  if ble-edit/text/is-single-line; then
    ble/widget/vi-command/accept-line
  else
    ble/widget/"$@"
  fi
}

#------------------------------------------------------------------------------
# arg     : 0-9 d y c
# command : dd yy cc [dyc]0 Y S

## 関数 ble/keymap:vi/.get-arg [default_value]
function ble/keymap:vi/.get-arg {
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

function ble/widget/vi-command/arg-append {
  local code="$((KEYS[0]&ble_decode_MaskChar))"
  ((code==0)) && return
  local ret; ble/util/c2s "$code"

  # 0
  if [[ $ret == 0 && $_ble_edit_arg != *[0-9] ]]; then
    ble/widget/vi-command/beginning-of-line
    return
  fi

  # 2つ目の非数修飾 (yy dd cc)
  if local rex='^[0-9]*$'; [[ $1 && ! ( $_ble_edit_arg =~ $rex ) ]]; then
    if [[ $_ble_edit_arg == *"$ret"* ]]; then
      ble/widget/vi-command/"$1"
      return
    else
      ble/widget/.bell
      _ble_edit_arg=
      return 1
    fi
  fi

  _ble_edit_arg="$_ble_edit_arg$ret"
}

function ble/widget/vi-command/copy-current-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  local ret
  ble-edit/text/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.copy-range "$beg" "$end" 1 L
  ble/keymap:vi/check-single-command-mode
}

function ble/widget/vi-command/kill-current-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  local ret
  ble-edit/text/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.kill-range "$beg" "$end" 1 L
  ble/keymap:vi/check-single-command-mode
}

function ble/widget/vi-command/kill-current-line-and-insert {
  ble/widget/vi-command/kill-current-line
  ble/widget/vi-command/insert-mode
}

function ble/widget/vi-command/beginning-of-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  local ret
  ble-edit/text/find-logical-bol; local beg=$ret
  if [[ $flag == y ]]; then
    ble/widget/.copy-range "$beg" "$_ble_edit_ind" 1
    ble/widget/.goto-char "$beg"
  elif [[ $flag == [cd] ]]; then
    ble/widget/.kill-range "$beg" "$_ble_edit_ind" 1
    [[ $flag == c ]] && ble/widget/vi-command/insert-mode
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/widget/.goto-char "$beg"
  fi
  ble/keymap:vi/check-single-command-mode
}

#------------------------------------------------------------------------------
# command: [cdy]?[hl]

function ble/widget/vi-command/common-goto.impl {
  local index=$1 flag=$2 nobell=$3
  if [[ $flag == [cd] ]]; then
    ble/widget/.kill-range "$_ble_edit_ind" "$index" 0
    if [[ $flag == c ]]; then
      ble/widget/vi-command/insert-mode
    else
      ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char _ble_edit_ind-1
    fi
  elif [[ $flag == y ]]; then
    ble/widget/.copy-range "$_ble_edit_ind" "$index" 1
    ((index<_ble_edit_ind)) && ble/widget/.goto-char index
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    ble/keymap:vi/needs-eol-fix "$index" && ((index--))
    if ((index!=_ble_edit_ind)); then
      ble/widget/.goto-char index
    else
      ((nobell)) || ble/widget/.bell
    fi
  fi
  ble/keymap:vi/check-single-command-mode
}

## 編集関数 ble/widget/vi-command/forward-char [type]
## 編集関数 ble/widget/vi-command/backward-char [type]
##
##   @param[in] type
##     type=m のとき複数行に亘る移動を許します。
##
function ble/widget/vi-command/forward-char {
  local arg flag; ble/keymap:vi/.get-arg 1

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
    ((index<${#_ble_edit_str})) && ble-edit/text/nonbol-eolp $index && ((index++))
  else
    local line=${_ble_edit_str:_ble_edit_ind:arg}
    line=${line%%$'\n'*}
    ((index=_ble_edit_ind+${#line}))
  fi

  ble/widget/vi-command/common-goto.impl "$index" "$flag"
}

function ble/widget/vi-command/backward-char {
  local arg flag; ble/keymap:vi/.get-arg 1

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

  ble/widget/vi-command/common-goto.impl "$index" "$flag"
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
      ble-edit/text/find-logical-eol 0 "$((nline-count-1))"
      ble/keymap:vi/needs-eol-fix "$ret" && ((ret--))
    else
      ble-edit/text/find-logical-bol 0 "$count"
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
  local count=$((arg<0?-arg:arg))
  local ret ind=$_ble_edit_ind

  # [ydc]k の処理
  if [[ $flag == [ydc] ]]; then
    local begl=0 endl=0; ((arg<0?(begl=arg):(endl=arg)))
    ble-edit/text/find-logical-bol "$ind" "$begl"; local beg=$ret
    ble-edit/text/find-logical-eol "$ind" "$endl"; local end=$ret
    if ble-edit/text/find-logical-bol "$end"; ((beg==ret)); then
      # jk で1行も移動できない場合は操作をキャンセル
      ble/widget/.bell
      return
    fi

    ((end<${#_ble_edit_str}&&end++))
    if [[ $flag == y ]]; then
      ble/widget/.copy-range "$beg" "$end" 1 L
      if ((arg<0)); then
        ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
        ble/widget/vi-command/.relative-line $((-ret))
      fi
    else
      ble/widget/.kill-range "$beg" "$end" 1 L
      if [[ $flag == c ]]; then
        ble/widget/insert-string $'\n'
        ble/widget/.goto-char _ble_edit_ind-1
        ble/widget/vi-command/insert-mode
      else
        ble/widget/vi-command/first-non-space
      fi
    fi
    return
  elif [[ $flag ]]; then
    ble/widget/.bell
    return
  fi

  # 現在の履歴項目内での探索
  ble-edit/text/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/text/find-logical-bol "$ind" "$arg"; local bol2=$ret
  local beg end; ((bol1<=bol2?(beg=bol1,end=bol2):(beg=bol2,end=bol1)))
  ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nmove=$ret
  ((count-=nmove))
  if ((count==0)); then
    local index
    if ble-edit/text/is-position-up-to-date; then
      # 列の表示相対位置 (x,y) を保持
      local b1x b1y; ble-edit/text/getxy.cur --prefix=b1 "$bol1"
      local b2x b2y; ble-edit/text/getxy.cur --prefix=b2 "$bol2"

      ble-edit/text/find-logical-eol "$bol2"; local eol2=$ret
      local c1x c1y; ble-edit/text/getxy.cur --prefix=c1 "$ind"
      local e2x e2y; ble-edit/text/getxy.cur --prefix=e2 "$eol2"

      local x=$c1x y=$((b2y+c1y-b1y))
      ((y>e2y&&(x=e2x,y=e2y)))

      ble-edit/text/get-index-at $x $y # local variable "index" is set here
    else
      # 論理列を保持
      ble-edit/text/find-logical-eol "$bol2"; local eol2=$ret
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
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/.relative-line "$arg" "$flag"
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/backward-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/.relative-line "$((-arg))" "$flag"
  ble/keymap:vi/check-single-command-mode
}

#------------------------------------------------------------------------------
# command: ^ + - $

function ble/widget/vi-command/.relative-first-non-space {
  local arg=$1 flag=$2
  local ret ind=$_ble_edit_ind
  ble-edit/text/find-logical-bol "$ind" "$arg"; local bolx=$ret
  local rex=$'^[ \t]*'
  [[ ${_ble_edit_str:bolx} =~ $rex ]]
  local nolx=$((bolx+${#BASH_REMATCH}))

  # 2017-09-12 何故か分からないが vim はこういう振る舞いに見える。
  ((_ble_keymap_vi_single_command==2&&_ble_keymap_vi_single_command--))

  if [[ $flag == [dyc] ]]; then
    if ((arg==0)); then
      ble-edit/text/nonbol-eolp "$nolx" && ((nolx--))
      local beg=$nolx end=$ind
      if [[ $flag == y ]]; then
        ble/widget/.copy-range "$beg" "$end" 1
        ((nolx<ind)) && ble/widget/.goto-char "$nolx"
      else
        ble/widget/.kill-range "$beg" "$end" 0
        [[ $flag == c ]] && ble/widget/vi-command/insert-mode
      fi
    else
      # arg!=0 (command: + -) なのに bolx と ind が同一行のときはエラー
      if ((bolx<=ind)) && [[ ${_ble_edit_str:bolx:ind-bolx} != *$'\n'* ]]; then
        ble/widget/.bell
        return
      fi

      local beg end
      if ((arg>0)); then
        ble-edit/text/find-logical-bol; beg=$ret
        ble-edit/text/find-logical-eol "$nolx" 0; end=$ret
      else
        ble-edit/text/find-logical-eol; beg=$bolx end=$ret
      fi
      ((end<${#_ble_edit_str}&&end++))

      if [[ $flag == y ]]; then
        ble/widget/.copy-range "$beg" "$end" 1 L
        if ((nolx<ind)); then
          ble-edit/text/nonbol-eolp "$nolx" && ((nolx--))
          ble/widget/.goto-char "$nolx"
        fi
      else
        ble/widget/.kill-range "$beg" "$end" 1 L
        if [[ $flag == c ]]; then
          ble/widget/insert-string $'\n'
          ble/widget/.goto-char _ble_edit_ind-1
          ble/widget/vi-command/insert-mode
        else
          ble/widget/vi-command/first-non-space
        fi
      fi
    fi
    return
  elif [[ $flag ]]; then
    ble/widget/.bell
    return
  fi

  local count=$((arg<0?-arg:arg)) nmove=0
  if ((count)); then
    local beg end; ((nolx<ind?(beg=nolx,end=ind):(beg=ind,end=nolx)))
    ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; nmove=$ret
    ((count-=nmove))
  fi

  if ((count==0)); then
    ble-edit/text/nonbol-eolp "$nolx" && ((nolx--))
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
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/.relative-first-non-space 0 "$flag"
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/forward-first-non-space {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/.relative-first-non-space "$arg" "$flag"
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/backward-first-non-space {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/.relative-first-non-space "$((-arg))" "$flag"
  ble/keymap:vi/check-single-command-mode
}

function ble/widget/vi-command/forward-eol {
  local arg flag; ble/keymap:vi/.get-arg 1

  local ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" $((arg-1)); local dst=$ret

  if [[ $flag ]]; then
    if [[ $flag == y ]]; then
      ble/widget/.copy-range "$_ble_edit_ind" "$dst" 1
    elif [[ $flag == [cd] ]]; then
      ble/widget/.kill-range "$_ble_edit_ind" "$dst" 1
      if [[ $flag == c ]]; then
        ble/widget/vi-command/insert-mode
      else
        ble/keymap:vi/needs-eol-fix && ble/widget/.goto-char _ble_edit_ind-1
      fi
    else
      ble/widget/.bell
    fi
    ble/keymap:vi/check-single-command-mode
    return
  fi

  ble/keymap:vi/needs-eol-fix "$dst" && ((dst--))
  ble/widget/.goto-char "$dst"
  ble/keymap:vi/check-single-command-mode

  # todo: (要相談) 履歴項目の移動もするか?
}

#------------------------------------------------------------------------------
# command: p P

function ble/widget/vi-command/paste.impl {
  local arg=$1 flag=$2 is_after=$3
  if [[ $flag ]]; then
    ble/widget/.bell
    return 1
  fi

  [[ $_ble_edit_kill_ring ]] || return 0
  local ret
  if [[ $_ble_edit_kill_type == L ]]; then
    if ((is_after)); then
      ble-edit/text/find-logical-eol
      if ((ret==${#_ble_edit_str})); then
        ble/widget/.goto-char ret
        ble/widget/insert-string $'\n'
      else
        ble/widget/.goto-char ret+1
      fi
    else
      ble-edit/text/find-logical-bol
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
    ble/keymap:vi/check-single-command-mode
  fi
}

function ble/widget/vi-command/paste-after {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/paste.impl "$arg" "$flag" 1
}
function ble/widget/vi-command/paste-before {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/paste.impl "$arg" "$flag" 0
}

#------------------------------------------------------------------------------
# command: x s X C D

function ble/widget/vi-command/kill-forward-char {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-forward-char-and-insert {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    _ble_edit_arg=${arg}c
    ble/widget/vi-command/forward-char
  fi
}
function ble/widget/vi-command/kill-backward-char {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/backward-char
  fi
}
function ble/widget/vi-command/kill-forward-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    _ble_edit_arg=${arg}d
    ble/widget/vi-command/forward-eol
  fi
}
function ble/widget/vi-command/kill-forward-line-and-insert {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
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
  ble/widget/vi-command/common-goto.impl "$index" "$flag"
}
function ble/widget/vi-command/forward-word-end.impl {
  local arg=$1 flag=$2 rex_word=$3
  local IFS=$' \t\n'
  local rex="^([$IFS]*($rex_word)?){0,$arg}" # 単語末端に止まる。空行には止まらない
  [[ ${_ble_edit_str:_ble_edit_ind+1} =~ $rex ]]
  local index=$((_ble_edit_ind+${#BASH_REMATCH}))
  [[ $BASH_REMATCH && ${_ble_edit_str:index:1} == [$IFS] ]] && ble/widget/.bell
  ble/widget/vi-command/common-goto.impl "$index" "$flag" 0
}
function ble/widget/vi-command/backward-word.impl {
  local arg=$1 flag=$2 rex_word=$3
  local bl=$' \t' nl=$'\n'
  local rex="((($rex_word)$nl?|[$bl]+$nl?|$nl)([$bl]+$nl)*[$bl]*){0,$arg}\$" # 単語先頭または空行に止まる
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]]
  local index=$((_ble_edit_ind-${#BASH_REMATCH}))
  ble/widget/vi-command/common-goto.impl "$index" "$flag"
}

function ble/widget/vi-command/forward-vword {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/forward-word.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/forward-vword-end {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/backward-vword {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/backward-word.impl "$arg" "$flag" $'[a-zA-Z0-9_]+|[^a-zA-Z0-9_ \t\n]+'
}
function ble/widget/vi-command/forward-uword {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/forward-word.impl "$arg" "$flag" $'[^ \t\n]+'
}
function ble/widget/vi-command/forward-uword-end {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/forward-word-end.impl "$arg" "$flag" $'[^ \t\n]+'
}
function ble/widget/vi-command/backward-uword {
  local arg flag; ble/keymap:vi/.get-arg 1
  ble/widget/vi-command/backward-word.impl "$arg" "$flag" $'[^ \t\n]+'
}

#------------------------------------------------------------------------------
# command: [cdy]?[|HL] G gg

function ble/widget/vi-command/nth-column {
  local arg flag; ble/keymap:vi/.get-arg 1

  local ret index
  ble-edit/text/find-logical-bol; local bol=$ret
  ble-edit/text/find-logical-eol; local eol=$ret
  if ble-edit/text/is-position-up-to-date; then
    local bx by; ble-edit/text/getxy.cur --prefix=b "$bol" # Note: 先頭行はプロンプトにより bx!=0
    local ex ey; ble-edit/text/getxy.cur --prefix=e "$eol"
    local dstx=$((bx+arg-1)) dsty=$by cols=${COLUMNS:-80}
    ((dsty+=dstx/cols,dstx%=cols))
    ((dsty>ey&&(dsty=ey,dstx=ex)))
    ble-edit/text/get-index-at "$dstx" "$dsty" # local variable "index" is set here
    ble-edit/text/nonbol-eolp "$index" && ((index--))
  else
    ble-edit/text/nonbol-eolp "$eol" && ((eol--))
    ((index=bol+arg-1,index>eol?(index=eol)))
  fi

  ble/widget/vi-command/common-goto.impl "$index" "$flag" 1
}

## 関数 ble/widget/vi-command/common-goto-line.impl bolx [flag]
##   指定した行の非空白行頭に移動または flag で指定した処理をします。
##
##   @param[in] bolx
##     行き先の行の行頭を指定します。
##
##   @param[in] flag
##
function ble/widget/vi-command/common-goto-line.impl {
  local bolx=$1 flag=$2
  if [[ $flag == [ydc] ]]; then
    local ind=$_ble_edit_ind

    # Note: helper/goto-relative-line / .relative-first-non-space
    #   に類似の処理があるが、統合できそうで微妙にできない。
    local beg end
    if ((ind<=bolx)); then
      ble-edit/text/find-logical-bol "$ind"; beg=$ret
      ble-edit/text/find-logical-eol "$bolx"; end=$ret
    else
      ble-edit/text/find-logical-eol "$ind"; beg=$bolx end=$ret
    fi
    ((end<${#_ble_edit_str}&&end++))

    if [[ $flag == y ]]; then
      ble/widget/.copy-range "$beg" "$end" 1 L
      if ((bolx<ind)); then
        ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
        ((ret)) && ble/widget/vi-command/.relative-line $((-ret))
      fi
      ble/keymap:vi/check-single-command-mode
    else
      ble/widget/.kill-range "$beg" "$end" 1 L
      if [[ $flag == c ]]; then
        ble/widget/insert-string $'\n'
        ble/widget/.goto-char _ble_edit_ind-1
        ble/widget/vi-command/insert-mode
      else
        ble/widget/vi-command/first-non-space
      fi
    fi
  elif [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    ble/widget/.goto-char bolx
    ble/widget/vi-command/first-non-space
  fi
}

function ble/widget/vi-command/nth-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  local ret; ble-edit/text/find-logical-bol 0 $((arg-1)); local bolx=$ret
  ble/widget/vi-command/common-goto-line.impl "$bolx" "$flag"
}

function ble/widget/vi-command/nth-last-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  local ret; ble-edit/text/find-logical-bol ${#_ble_edit_str} $((-(arg-1))); local bolx=$ret
  ble/widget/vi-command/common-goto-line.impl "$bolx" "$flag"
}

function ble/widget/vi-command/history-beginning {
  local arg flag; ble/keymap:vi/.get-arg 0
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
  ble/keymap:vi/check-single-command-mode
}

# G in history
function ble/widget/vi-command/history-end {
  local arg flag; ble/keymap:vi/.get-arg 0
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
  ble/keymap:vi/check-single-command-mode
}

# G in the current history entry
function ble/widget/vi-command/last-line {
  local arg flag; ble/keymap:vi/.get-arg 0
  local ret
  if ((arg)); then
    ble-edit/text/find-logical-bol 0 $((arg-1))
  else
    ble-edit/text/find-logical-bol ${#_ble_edit_str} 0
  fi
  ble/widget/vi-command/common-goto-line.impl "$ret" "$flag"
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
  local arg flag; ble/keymap:vi/.get-arg 1
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
  ble/keymap:vi/check-single-command-mode
}

function ble/widget/vi-command/replace-char/.hook {
  ble/widget/vi-command/replace-char.impl "$1" R
}
function ble/widget/vi-command/replace-char {
  _ble_decode_key__hook=ble/widget/vi-command/replace-char/.hook
}
function ble/widget/vi-command/virtual-replace-char/.hook {
  ble/widget/vi-command/replace-char.impl "$1" 1
}
function ble/widget/vi-command/virtual-replace-char {
  _ble_decode_key__hook=ble/widget/vi-command/virtual-replace-char/.hook
}

#------------------------------------------------------------------------------
# command: J gJ o O

function ble/widget/vi-command/connect-line-with-space {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/text/find-logical-eol; local eol=$ret
    if ((eol<${#_ble_edit_str})); then
      _ble_edit_str.replace eol eol+1 ' '
      ble/widget/.goto-char "$eol"
    else
      ble/widget/.bell
    fi
  fi
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/connect-line {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
  else
    local ret; ble-edit/text/find-logical-eol; local eol=$ret
    if ((eol<${#_ble_edit_str})); then
      ble/widget/.delete-range "$eol" $((eol+1))
      ble/widget/.goto-char "$eol"
    else
      ble/widget/.bell
    fi
  fi
  ble/keymap:vi/check-single-command-mode
}

function ble/widget/vi-command/insert-forward-line-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    local ret; ble-edit/text/find-logical-eol; local eol=$ret
    ble/widget/.goto-char "$eol"
    ble/widget/insert-string $'\n'
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}
function ble/widget/vi-command/insert-backward-line-mode {
  local arg flag; ble/keymap:vi/.get-arg 1
  if [[ $flag ]]; then
    ble/widget/.bell
    ble/keymap:vi/check-single-command-mode
  else
    local ret; ble-edit/text/find-logical-bol; local bol=$ret
    ble/widget/.goto-char "$bol"
    ble/widget/insert-string $'\n'
    ble/widget/.goto-char "$bol"
    ble/widget/vi-command/.insert-mode "$arg"
  fi
}

#------------------------------------------------------------------------------
# command: f F t F


## 変数 _ble_keymap_vi_search_char
##   前回の ble/widget/vi-command/.search-char の検索を記録します。
_ble_keymap_vi_search_char=

## 関数 ble/widget/vi-command/.search-char key|char opts
##
##   @param[in] key
##   @param[in] char
##     key は検索対象のキーコードを指定します。
##     char は検索対象の文字を指定します。
##     どちらで解釈されるかは後述する opts のフラグ r に依存します。
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
function ble/widget/vi-command/.search-char {
  local key=$1 opts=$2
  local arg flag; ble/keymap:vi/.get-arg 1

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

  local index
  if [[ $opts == *b* ]]; then
    # backward search
    ble-edit/text/find-logical-bol; local bol=$ret
    local base=$_ble_edit_ind
    ((isrepeat&&isprev&&base--,base>bol)) || return 1
    local line=${_ble_edit_str:bol:base-bol}
    ble/string#last-index-of "$line" "$c" "$arg"
    ((ret>=0)) || return 1

    ((index=bol+ret,isprev&&index++))
  else
    # forward search
    ble-edit/text/find-logical-eol; local eol=$ret
    local base=$((_ble_edit_ind+1))
    ((isrepeat&&isprev&&base++,base<eol)) || return 1

    local line=${_ble_edit_str:base:eol-base}
    ble/string#index-of "$line" "$c" "$arg"
    ((ret>=0)) || return 1

    ((index=base+ret,isprev&&index--))
    [[ $flag ]] && ((index++))
  fi
  ble/widget/vi-command/common-goto.impl "$index" "$flag" 1
  ((isrepeat)) || _ble_keymap_vi_search_char=$c$opts
  return 0
}

function ble/widget/vi-command/search-forward-char/.hook {
  ble/widget/vi-command/.search-char "$1" f || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/search-forward-char-prev/.hook {
  ble/widget/vi-command/.search-char "$1" fp || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/search-backward-char/.hook {
  ble/widget/vi-command/.search-char "$1" b || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/search-backward-char-prev/.hook {
  ble/widget/vi-command/.search-char "$1" bp || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/search-forward-char {
  _ble_decode_key__hook=ble/widget/vi-command/search-forward-char/.hook
}
function ble/widget/vi-command/search-forward-char-prev {
  _ble_decode_key__hook=ble/widget/vi-command/search-forward-char-prev/.hook
}
function ble/widget/vi-command/search-backward-char {
  _ble_decode_key__hook=ble/widget/vi-command/search-backward-char/.hook
}
function ble/widget/vi-command/search-backward-char-prev {
  _ble_decode_key__hook=ble/widget/vi-command/search-backward-char-prev/.hook
}
function ble/widget/vi-command/search-char-repeat {
  [[ $_ble_keymap_vi_search_char ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_search_char::1} opts=${_ble_keymap_vi_search_char:1}
  ble/widget/vi-command/.search-char "$c" "r$opts" || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}
function ble/widget/vi-command/search-char-reverse-repeat {
  [[ $_ble_keymap_vi_search_char ]] || ble/widget/.bell
  local c=${_ble_keymap_vi_search_char::1} opts=${_ble_keymap_vi_search_char:1}
  if [[ $opts == *b* ]]; then
    opts=f${opts//b}
  else
    opts=b${opts//f}
  fi
  ble/widget/vi-command/.search-char "$c" "r$opts" || ble/widget/.bell
  ble/keymap:vi/check-single-command-mode
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command
  ble-bind -f a      vi-command/append-mode
  ble-bind -f A      vi-command/append-eol-mode
  ble-bind -f i      vi-command/insert-mode
  ble-bind -f insert vi-command/insert-mode
  ble-bind -f I      vi-command/insert-nol-mode
  ble-bind -f 'g I'  vi-command/insert-bol-mode
  ble-bind -f o      vi-command/insert-forward-line-mode
  ble-bind -f O      vi-command/insert-backward-line-mode
  ble-bind -f R      vi-command/replace-mode
  ble-bind -f 'g R'  vi-command/virtual-replace-mode

  ble-bind -f 0 vi-command/arg-append
  ble-bind -f 1 vi-command/arg-append
  ble-bind -f 2 vi-command/arg-append
  ble-bind -f 3 vi-command/arg-append
  ble-bind -f 4 vi-command/arg-append
  ble-bind -f 5 vi-command/arg-append
  ble-bind -f 6 vi-command/arg-append
  ble-bind -f 7 vi-command/arg-append
  ble-bind -f 8 vi-command/arg-append
  ble-bind -f 9 vi-command/arg-append
  ble-bind -f y 'vi-command/arg-append copy-current-line'
  ble-bind -f d 'vi-command/arg-append kill-current-line'
  ble-bind -f c 'vi-command/arg-append kill-current-line-and-insert'

  ble-bind -f Y vi-command/copy-current-line
  ble-bind -f S vi-command/kill-current-line-and-insert
  ble-bind -f D vi-command/kill-forward-line
  ble-bind -f C vi-command/kill-forward-line-and-insert

  ble-bind -f p vi-command/paste-after
  ble-bind -f P vi-command/paste-before

  ble-bind -f home vi-command/beginning-of-line
  ble-bind -f '$' vi-command/forward-eol
  ble-bind -f end vi-command/forward-eol
  ble-bind -f '^' vi-command/first-non-space
  ble-bind -f '+' vi-command/forward-first-non-space
  ble-bind -f '-' vi-command/backward-first-non-space

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

  ble-bind -f x      vi-command/kill-forward-char
  ble-bind -f s      vi-command/kill-forward-char-and-insert
  ble-bind -f X      vi-command/kill-backward-char
  ble-bind -f delete vi-command/kill-forward-char

  ble-bind -f w vi-command/forward-vword
  ble-bind -f W vi-command/forward-uword
  ble-bind -f b vi-command/backward-vword
  ble-bind -f B vi-command/backward-uword
  ble-bind -f e vi-command/forward-vword-end
  ble-bind -f E vi-command/forward-uword-end
  ble-bind -f C-right vi-command/forward-vword
  ble-bind -f C-left  vi-command/backward-vword

  ble-bind -f '|'    vi-command/nth-column
  ble-bind -f H      vi-command/nth-line
  ble-bind -f L      vi-command/nth-last-line
  ble-bind -f 'g g'  vi-command/history-beginning
  ble-bind -f G      vi-command/history-end
  ble-bind -f C-home vi-command/nth-line
  ble-bind -f C-end  vi-command/last-line

  ble-bind -f K command-help

  ble-bind -f 'r'   vi-command/replace-char
  ble-bind -f 'g r' vi-command/virtual-replace-char # vim で実際に試すとこの機能はない

  ble-bind -f J     vi-command/connect-line-with-space
  ble-bind -f 'g J' vi-command/connect-line

  ble-bind -f 'f' vi-command/search-forward-char
  ble-bind -f 'F' vi-command/search-backward-char
  ble-bind -f 't' vi-command/search-forward-char-prev
  ble-bind -f 'T' vi-command/search-backward-char-prev
  ble-bind -f ';' vi-command/search-char-repeat
  ble-bind -f ',' vi-command/search-char-reverse-repeat

  ble-bind -f 'C-\ C-n' nop

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

  ble-bind -f C-left  vi-command/backward-vword
  ble-bind -f M-left  vi-command/backward-uword
  ble-bind -f C-right vi-command/forward-vword-end
  ble-bind -f M-right vi-command/forward-uword-end
}

#------------------------------------------------------------------------------
# vi-insert

function ble/widget/vi-insert/.attach {
  ble-edit/info/set-default raw $'\e[1m-- INSERT --\e[m'
}
function ble/widget/vi-insert/magic-space {
  if [[ $_ble_keymap_vi_repeat ]]; then
    ble/widget/self-insert
  else
    ble/widget/vi-insert/@norepeat magic-space
  fi
}
function ble/widget/vi-insert/accept-single-line-or {
  if ble-edit/text/is-single-line; then
    ble/widget/vi-insert/@norepeat accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/vi-insert/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/vi-insert/@norepeat delete-region
  else
    "ble/widget/delete-$@"
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

function ble-decode-keymap:vi_insert/define {
  local ble_bind_keymap=vi_insert

  ble-bind -f __attach__         vi-insert/.attach
  ble-bind -f __defchar__        self-insert
  ble-bind -f __default__        vi-insert/default
  ble-bind -f __before_command__ vi-insert/.log-repeat

  ble-bind -f 'ESC' vi-insert/normal-mode
  ble-bind -f 'C-[' vi-insert/normal-mode
  ble-bind -f 'C-c' vi-insert/normal-mode-norepeat
  # ble-bind -f 'C-l' vi-insert/normal-mode

  ble-bind -f insert vi-insert/overwrite-mode

  ble-bind -f 'C-w' 'delete-backward-cword' # vword?

  # ble-bind -f 'C-o' 'nop'
  ble-bind -f 'C-o' 'vi-insert/single-command-mode'

  #----------------------------------------------------------------------------
  # bash

  # ins
  ble-bind -f 'C-q'      quoted-insert
  ble-bind -f 'C-v'      quoted-insert
  ble-bind -f 'C-RET'    newline

  # shell
  ble-bind -f 'C-m' 'vi-insert/accept-single-line-or newline'
  ble-bind -f 'RET' 'vi-insert/accept-single-line-or newline'
  ble-bind -f 'C-i' 'vi-insert/@norepeat complete'
  ble-bind -f 'TAB' 'vi-insert/@norepeat complete'

  # history
  ble-bind -f 'C-r'     'vi-insert/@norepeat history-isearch-backward'
  ble-bind -f 'C-s'     'vi-insert/@norepeat history-isearch-forward'
  ble-bind -f 'C-prior' 'vi-insert/@norepeat history-beginning'
  ble-bind -f 'C-next'  'vi-insert/@norepeat history-end'
  ble-bind -f 'SP'      'vi-insert/magic-space'

  ble-bind -f 'C-l' clear-screen
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
  ble-bind -f 'C-h'      'vi-insert/delete-region-or backward-char'
  ble-bind -f 'DEL'      'vi-insert/delete-region-or backward-char'
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
  ble-bind -f 'C-k'      'vi-insert/@norepeat kill-forward-line'
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

  echo -n "ble.sh: updating cache/keymap.vi... $_ble_term_cr" >&2

  ble-decode-keymap:isearch/define
  ble-decode-keymap:vi_insert/define
  ble-decode-keymap:vi_command/define

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_insert >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_command >> "$fname_keymap_cache"
  ble-decode/keymap/dump isearch >> "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.vi... done" >&2
}

ble-decode-keymap:vi/initialize
