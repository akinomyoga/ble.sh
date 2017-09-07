#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
function ble-edit/load-keymap-definition:vi { :; }

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
# modes

function ble/widget/vi-insert/normal-mode {
  _ble_edit_overwrite_mode=
  if ! ble-edit/text/bolp; then
    ble/widget/.goto-char "$((_ble_edit_ind-1))"
  fi
  ble-decode/keymap/push vi_command
}
function ble/widget/vi-command/insert-mode {
  ble-decode/keymap/pop
}
function ble/widget/vi-command/append-mode {
  if ! ble-edit/text/eolp; then
    ble/widget/.goto-char "$((_ble_edit_ind+1))"
  fi
  ble-decode/keymap/pop
}
function ble/widget/vi-command/append-eol-mode {
  local ret; ble-edit/text/find-logical-eol
  ble/widget/.goto-char "$ret"
  ble-decode/keymap/pop
}
function ble/widget/vi-command/replace-mode {
  ble/widget/vi-command/insert-mode
  _ble_edit_overwrite_mode=1
}

#------------------------------------------------------------------------------
# arg     : 0-9 d y c
# command : dd yy cc [dyc]0

## 関数 ble/widget/vi-command/.get-arg [default_value]
function ble/widget/vi-command/.get-arg {
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

_ble_edit_arg=
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

function ble/widget/vi-command/yank-current-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  local ret
  ble-edit/text/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.copy-range "$beg" "$end" 1 L
}

function ble/widget/vi-command/delete-current-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  local ret
  ble-edit/text/find-logical-bol "$_ble_edit_ind" 0; local beg=$ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" "$((arg-1))"; local end=$ret
  ((end<${#_ble_edit_str}&&end++))
  ble/widget/.kill-range "$beg" "$end" 1 L
}

function ble/widget/vi-command/delete-current-line-and-insert {
  ble/widget/vi-command/delete-current-line
  ble/widget/vi-command/insert-mode
}

function ble/widget/vi-command/beginning-of-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
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
}

#------------------------------------------------------------------------------
# command: [cdy]?[hjkl]

function ble/widget/vi-command/forward-char {
  local arg flag; ble/widget/vi-command/.get-arg 1

  local line=${_ble_edit_str:_ble_edit_ind:arg}
  line=${line%%$'\n'*}
  local count=${#line}

  if [[ $flag == [cd] ]]; then
    ((count)) && ble/widget/.kill-range $_ble_edit_ind $((_ble_edit_ind+count))
    if [[ $flag == c ]]; then
      ble/widget/vi-command/insert-mode
    else
      ble-edit/text/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
    fi
  elif [[ $flag == y ]]; then
    ble/widget/.copy-range $_ble_edit_ind $((_ble_edit_ind+count)) 1
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    ((count)) && ble-edit/text/nonbol-eolp $((_ble_edit_ind+count)) && ((count--))
    if ((count)); then
      ble/widget/.goto-char _ble_edit_ind+count
    else
      ble/widget/.bell
    fi
  fi
}

function ble/widget/vi-command/backward-char {
  local arg flag; ble/widget/vi-command/.get-arg 1

  local count=$arg
  ((count>_ble_edit_ind&&(count=_ble_edit_ind)))
  local line=${_ble_edit_str:_ble_edit_ind-count:count}
  line=${line##*$'\n'}
  count=${#line}

  if [[ $flag == [cd] ]]; then
    ((count)) && ble/widget/.kill-range $((_ble_edit_ind-count)) $_ble_edit_ind
    [[ $flag == c ]] && ble/widget/vi-command/insert-mode
  elif [[ $flag == y ]]; then
    ble/widget/.copy-range $((_ble_edit_ind-count)) $_ble_edit_ind 1
    ble/widget/.goto-char _ble_edit_ind-count
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    if ((count)); then
      ble/widget/.goto-char _ble_edit_ind-count
    else
      ble/widget/.bell
    fi
  fi
}

function ble/string#count-char {
  local text=$1 char=$2
  text=${text//[!$char]}
  ret=${#text}
}

function ble/widget/vi-command/.history-relative-line {
  local arg=$1 type=$2
  local ret count=$((arg<0?-arg:arg))
  ((count--))
  while ((count>=0)); do
    if ((arg<0)); then
      ((_ble_edit_history_ind>0||(count=0))) || break
      ble/widget/history-prev
    else
      ((_ble_edit_history_ind<${#_ble_edit_history[@]}||(count=0))) || break
      ble/widget/history-next
    fi
    ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
    ((count<nline)) && break
    ((count-=nline))
  done

  if ((count)); then
    if ((arg<0)); then
      ble-edit/text/find-logical-eol 0 "$((nline-count-1))"
      ble-edit/text/nonbol-eolp && ((ret--))
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
  local count=$((arg<0?-arg:arg))
  local ret ind=$_ble_edit_ind

  # [ydc]k の処理
  if [[ $flag == [ydc] ]]; then
    local begl=0 endl=0; ((arg<0?(begl=arg):(endl=arg)))
    ble-edit/text/find-logical-bol "$ind" "$begl"; local beg=$ret
    ble-edit/text/find-logical-eol "$ind" "$endl"; local end=$ret
    ((end<${#_ble_edit_str}&&end++))
    if [[ $flag == y ]]; then
      ble/widget/.copy-range "$beg" "$end"
      if ((arg<0)); then
        ble/string#count-char "${_ble_edit_str:beg:ind-beg}" $'\n'
        ((ret)) && ble/widget/vi-command/.relative-line $((-ret))
      fi
    else
      ble/widget/.kill-range "$beg" "$end"
      [[ $flag == c ]] && ble/widget/vi-command/insert-mode
    fi
    return
  elif [[ $flag ]]; then
    ble/widget/.bell
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
    ble-edit/text/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
    return
  fi

  # 履歴項目を行数を数えつつ移動
  ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count))
}
function ble/widget/vi-command/forward-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.relative-line "$arg" "$flag"
}
function ble/widget/vi-command/backward-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.relative-line "$((-arg))" "$flag"
}

#------------------------------------------------------------------------------
# command: ^ + - $

function ble/widget/vi-command/.first-non-space-of-relative-line {
  local arg=$1 flag=$2
  local ret ind=$_ble_edit_ind
  ble-edit/text/find-logical-bol "$ind" "$arg"; local bolx=$ret
  local rex=$'^[ \t\n]*'
  [[ ${_ble_edit_str:bolx} =~ $rex ]]
  local nolx=$((bolx+${#BASH_REMATCH}))

  if [[ $flag == [dyc] ]]; then
    if ((arg==0)); then
      local beg=$nolx end=$ind
    else
      if ((arg>0)); then
        ble-edit/text/find-logical-bol; local bol1=$ret
        ble-edit/text/find-logical-eol "$nolx" 0; local eol2=$ret
      else
        local bol1=$bolx
        ble-edit/text/find-logical-eol; local eol2=$ret
      fi
      ((eol2<${#_ble_edit_str}&&eol2++))
      local beg=$bol1 end=$eol2
    fi

    if [[ $flag == y ]]; then
      ble/widget/.copy-range "$beg" "$end" 1
      if ((nolx<ind)); then
        ble-edit/text/nonbol-eolp "$nolx" && ((nolx--))
        ble/widget/.goto-char "$nolx"
      fi
    else
      ble/widget/.kill-range "$beg" "$end" 1
      if [[ $flag == c ]]; then
        ble/widget/vi-command/insert-mode
      else
        ble-edit/text/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
      fi
    fi
    return
  elif [[ $flag ]]; then
    ble/widget/.bell
  fi

  local count=$((arg<0?-arg:arg))
  if ((count)); then
    local beg end; ((nolx<ind?(beg=nolx,end=ind):(beg=ind,end=nolx)))
    ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nmove=$ret
    ((count-=nmove))
  fi

  if ((count==0)); then
    ble-edit/text/nonbol-eolp "$nolx" && ((nolx--))
    ble/widget/.goto-char "$nolx"
    return
  fi

  # 履歴項目の移動
  ble/widget/vi-command/.history-relative-line $((arg>=0?count:-count))
  ble/widget/vi-command/first-non-space-of-line
}

function ble/widget/vi-command/first-non-space-of-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.first-non-space-of-relative-line 0 "$flag"
}
function ble/widget/vi-command/first-non-space-of-forward-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.first-non-space-of-relative-line "$arg" "$flag"
}
function ble/widget/vi-command/first-non-space-of-backward-line {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.first-non-space-of-relative-line "$((-arg))" "$flag"
}

function ble/widget/vi-command/forward-eol {
  local arg flag; ble/widget/vi-command/.get-arg 1

  local ret
  ble-edit/text/find-logical-eol "$_ble_edit_ind" $((arg-1)); local dst=$ret

  if [[ $flag == y ]]; then
    ble/widget/.copy-range "$_ble_edit_ind" "$dst" 1
  elif [[ $flag == [cd] ]]; then
    ble/widget/.kill-range "$_ble_edit_ind" "$dst" 1
    if [[ $flag == c ]]; then
      ble/widget/vi-command/insert-mode
    else
      ble-edit/text/nonbol-eolp && ble/widget/.goto-char _ble_edit_ind-1
    fi
  elif [[ $flag ]]; then
    ble/widget/.bell
  else
    ble-edit/text/nonbol-eolp "$dst" && ((dst--))
    ble/widget/.goto-char "$dst"
  fi

  # todo: (要相談) 履歴項目の移動もするか?
}

#------------------------------------------------------------------------------
# command: p P

function ble/widget/vi-command/.paste {
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
    ble/widget/vi-command/first-non-space-of-line
  else
    if ((is_after&&_ble_edit_ind<${#_ble_edit_str})); then
      ble/widget/.goto-char _ble_edit_ind+1
    fi
    ble/string#repeat "$_ble_edit_kill_ring" "$arg"
    ble/widget/insert-string "$ret"
    ble/widget/.goto-char _ble_edit_ind-1
  fi
}

function ble/widget/vi-command/paste-after {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.paste "$arg" "$flag" 1
}
function ble/widget/vi-command/paste-before {
  local arg flag; ble/widget/vi-command/.get-arg 1
  ble/widget/vi-command/.paste "$arg" "$flag" 0
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command
  ble-bind -f i vi-command/insert-mode
  ble-bind -f R vi-command/replace-mode
  ble-bind -f a vi-command/append-mode
  ble-bind -f A vi-command/append-eol-mode

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
  ble-bind -f y 'vi-command/arg-append yank-current-line'
  ble-bind -f d 'vi-command/arg-append delete-current-line'
  ble-bind -f c 'vi-command/arg-append delete-current-line-and-insert'

  ble-bind -f p vi-command/paste-after
  ble-bind -f P vi-command/paste-before

  ble-bind -f home vi-command/beginning-of-line
  ble-bind -f '$' vi-command/forward-eol
  ble-bind -f end vi-command/forward-eol
  ble-bind -f '^' vi-command/first-non-space-of-line
  ble-bind -f '+' vi-command/first-non-space-of-forward-line
  ble-bind -f '-' vi-command/first-non-space-of-backward-line

  ble-bind -f h     vi-command/backward-char
  ble-bind -f l     vi-command/forward-char
  ble-bind -f left  vi-command/backward-char
  ble-bind -f right vi-command/forward-char

  ble-bind -f j     vi-command/forward-line
  ble-bind -f k     vi-command/backward-line
  ble-bind -f down  vi-command/forward-line
  ble-bind -f up    vi-command/backward-line
  ble-bind -f C-n   vi-command/forward-line
  ble-bind -f C-p   vi-command/backward-line

  #----------------------------------------------------------------------------
  # temporary implementations

  # ble-bind -f C-h   vi-command/backward-char + 行頭にいるとき前の行に
  # ble-bind -f DEL   vi-command/backward-char + 行頭にいるとき前の行に
  # ble-bind -f SP    vi-command/forward-char + 行末にいるとき次の行に

  # ble-bind -f C-h backward-char
  # ble-bind -f DEL backward-char
  # ble-bind -f SP  forward-char

  #----------------------------------------------------------------------------
  # bash

  ble-bind -f 'C-q' quoted-insert
  ble-bind -f 'C-v' quoted-insert

  ble-bind -f 'C-j' accept-line
  ble-bind -f 'C-m' accept-single-line-or-newline
  ble-bind -f 'RET' accept-single-line-or-newline
  ble-bind -f 'C-g' bell
  ble-bind -f 'C-l' clear-screen
}

function ble-decode-keymap:vi_insert/define {
  local ble_bind_keymap=vi_insert

  ble-bind -f __defchar__ self-insert
  ble-bind -f __default__ vi-insert/default

  ble-bind -f 'ESC' vi-insert/normal-mode
  ble-bind -f 'C-[' vi-insert/normal-mode
  ble-bind -f 'C-c' vi-insert/normal-mode

  ble-bind -f insert overwrite-mode

  #----------------------------------------------------------------------------
  # from keymap emacs-standard

  # C-o http://qiita.com/takasianpride/items/6900eebb7cde9fbb5298

  # ins
  ble-bind -f 'C-q'       quoted-insert
  ble-bind -f 'C-v'       quoted-insert

  # shell function
  # ble-bind -f 'C-c' discard-line
  ble-bind -f  'C-j'     accept-line
  ble-bind -f  'C-m'     accept-single-line-or-newline
  ble-bind -f  'RET'     accept-single-line-or-newline
  ble-bind -f  'C-o'     accept-and-next
  ble-bind -f  'C-g'     bell
  ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'M-l'     redraw-line
  ble-bind -f  'C-i'     complete
  ble-bind -f  'TAB'     complete
  ble-bind -f  'f1'      command-help
  ble-bind -f  'C-x C-v' display-shell-version
  ble-bind -cf 'C-z'     fg
  ble-bind -cf 'M-z'     fg

  # history
  ble-bind -f 'C-r'     history-isearch-backward
  ble-bind -f 'C-s'     history-isearch-forward
  ble-bind -f 'C-RET'   history-expand-line
  # ble-bind -f 'M-<'     history-beginning
  # ble-bind -f 'M->'     history-end
  ble-bind -f 'C-prior' history-beginning
  ble-bind -f 'C-next'  history-end
  ble-bind -f 'SP'      magic-space

  # kill
  ble-bind -f 'C-@'      set-mark
  # ble-bind -f 'M-SP'     set-mark
  ble-bind -f 'C-x C-x'  exchange-point-and-mark
  ble-bind -f 'C-w'      'kill-region-or uword'
  # ble-bind -f 'M-w'      'copy-region-or uword'
  ble-bind -f 'C-y'      yank

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
  ble-bind -f 'C-h'      'delete-region-or backward-char'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'DEL'      'delete-region-or backward-char'
  ble-bind -f 'C-t'      transpose-chars

  # wordwise operations
  ble-bind -f 'C-right'   'nomarked forward-cword'
  ble-bind -f 'C-left'    'nomarked backward-cword'
  # ble-bind -f 'M-right'   'nomarked forward-sword'
  # ble-bind -f 'M-left'    'nomarked backward-sword'
  ble-bind -f 'S-C-right' 'marked forward-cword'
  ble-bind -f 'S-C-left'  'marked backward-cword'
  # ble-bind -f 'S-M-right' 'marked forward-sword'
  # ble-bind -f 'S-M-left'  'marked backward-sword'
  # ble-bind -f 'M-d'       kill-forward-cword
  # ble-bind -f 'M-h'       kill-backward-cword
  ble-bind -f 'C-delete'  delete-forward-cword  # C-delete
  ble-bind -f 'C-_'       delete-backward-cword # C-BS
  # ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  # ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  # ble-bind -f 'M-f'       'nomarked forward-cword'
  # ble-bind -f 'M-b'       'nomarked backward-cword'
  # ble-bind -f 'M-F'       'marked forward-cword'
  # ble-bind -f 'M-B'       'marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'    'nomarked beginning-of-line'
  ble-bind -f 'C-e'    'nomarked end-of-line'
  ble-bind -f 'home'   'nomarked beginning-of-line'
  ble-bind -f 'end'    'nomarked end-of-line'
  # ble-bind -f 'M-m'    'nomarked beginning-of-line'
  ble-bind -f 'S-C-a'  'marked beginning-of-line'
  ble-bind -f 'S-C-e'  'marked end-of-line'
  ble-bind -f 'S-home' 'marked beginning-of-line'
  ble-bind -f 'S-end'  'marked end-of-line'
  # ble-bind -f 'S-M-m'  'marked beginning-of-line'
  ble-bind -f 'C-k'    kill-forward-line
  ble-bind -f 'C-u'    kill-backward-line

  ble-bind -f 'C-p'    'nomarked backward-line-or-history-prev'
  ble-bind -f 'up'     'nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'    'nomarked forward-line-or-history-next'
  ble-bind -f 'down'   'nomarked forward-line-or-history-next'
  ble-bind -f 'S-C-p'  'marked backward-line'
  ble-bind -f 'S-up'   'marked backward-line'
  ble-bind -f 'S-C-n'  'marked forward-line'
  ble-bind -f 'S-down' 'marked forward-line'

  ble-bind -f 'C-home'   'nomarked beginning-of-text'
  ble-bind -f 'C-end'    'nomarked end-of-text'
  ble-bind -f 'S-C-home' 'marked beginning-of-text'
  ble-bind -f 'S-C-end'  'marked end-of-text'

  # ble-bind -f 'C-x' bell
  ble-bind -f 'C-\' bell
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

function ble-decode-keymap:vi/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.vi
  if [[ $fname_keymap_cache -nt $_ble_base/keymap/vi.sh &&
          $fname_keymap_cache -nt $_ble_base/cmap/default.sh ]]; then
    source "$fname_keymap_cache"
    return
  fi

  echo -n "ble.sh: updating cache/keymap.vi... $_ble_term_cr" >&2

  ble-decode-keymap:vi_insert/define
  ble-decode-keymap:vi_command/define

  : >| "$fname_keymap_cache"
  ble-decode/keymap/dump vi_insert >> "$fname_keymap_cache"
  ble-decode/keymap/dump vi_command >> "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.vi... done" >&2
}

ble-decode-keymap:vi/initialize
