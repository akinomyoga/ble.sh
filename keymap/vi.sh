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
function ble/widget/vi-command/replace-mode {
  ble/widget/vi-command/insert-mode
  _ble_edit_overwrite_mode=1
}

#------------------------------------------------------------------------------
# arg

function ble/widget/vi-command/.get-arg {
  local rex='^[0-9]*$'
  if [[ ! $_ble_edit_arg ]]; then
    flag= arg=
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

#------------------------------------------------------------------------------
# hjkl

function ble/widget/vi-command/forward-char {
  local arg flag; ble/widget/vi-command/.get-arg
  ((arg<=0&&(arg=1)))

  local line=${_ble_edit_str:_ble_edit_ind:arg}
  line=${line%%$'\n'*}
  local count=${#line}

  if [[ $flag == [cd] ]]; then
    if ((count)); then
      ble/widget/.kill-range $_ble_edit_ind $((_ble_edit_ind+count))
      ble-edit/text/nonbol-eolp $_ble_edit_ind && ble/widget/.goto-char $((_ble_edit_ind-1))
    fi
    [[ $flag == c ]] && ble/widget/vi-command/insert-mode
  elif [[ $flag == y ]]; then
    if ((count)); then
      ble/widget/.copy-range $_ble_edit_ind $((_ble_edit_ind+count))
    fi
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
  local arg flag; ble/widget/vi-command/.get-arg
  ((arg<=0&&(arg=1)))

  local count=$arg
  ((count>_ble_edit_ind&&(count=_ble_edit_ind)))
  local line=${_ble_edit_str:_ble_edit_ind-count:count}
  line=${line##*$'\n'}
  count=${#line}

  if [[ $flag == [cd] ]]; then
    if ((count)); then
      ble/widget/.kill-range $((_ble_edit_ind-count)) $_ble_edit_ind
    fi
    [[ $flag == c ]] && ble/widget/vi-command/insert-mode
  elif [[ $flag == y ]]; then
    if ((count)); then
      ble/widget/.copy-range $((_ble_edit_ind-count)) $_ble_edit_ind
    fi
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

## 関数 ble-edit/text/find-logical-eol [index [offset]]; ret
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の終端位置を返します。
##
##   offset が 0 の場合は位置 index を含む行の行末を返します。
##   offset が正で offset 次の行がない場合は ${#_ble_edit_str} を返します。
##
function ble-edit/text/find-logical-eol {
  local index=${1:-$_ble_edit_ind} offset=${1:-0}
  if ((offset>0)); then
    local text=${_ble_edit_str:index}
    local rex="^([^$_ble_term_nl]*$_ble_term_nl){0,$offset}[^$_ble_term_nl]*"
    [[ $text =~ $rex ]]
    ((ret=index+${#BASH_REMATCH}))
  elif ((offset<0)); then
    local text=${_ble_edit_str::index}
    local rex="($_ble_term_nl[^$_ble_term_nl]*){0,$offset}$"
    [[ $text =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index-${#BASH_REMATCH}))
    else
      ble-edit/text/find-logical-eol "$index" 0
    fi
  else
    local text=${_ble_edit_str:index}
    text=${text%%$'\n'*}
    ((ret=index+${#text}))
  fi
}
## 関数 ble/widget/vi-command/.find-logical-forward-bol [index [offset]]; ret
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の先頭位置を返します。
##
##   offset が 0 の場合は位置 index を含む行の行頭を返します。
##   offset が正で offset だけ次の行がない場合は最終行の行頭を返します。
##   特に次の行がない場合は現在の行頭を返します。
##
function ble-edit/text/find-logical-bol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local text=${_ble_edit_str:index}
    local rex="^([^$_ble_term_nl]*$_ble_term_nl){0,$offset}"
    [[ $text =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index+${#BASH_REMATCH}))
    else
      ble-edit/text/find-logical-bol "$index" 0
    fi
  elif ((offset<0)); then
    ble-edit/text/find-logical-eol "$index" "$offset"
    ble-edit/text/find-logical-bol "$ret" 0
  else
    local text=${_ble_edit_str::index}
    text=${text##*$'\n'}
    ((ret=index-${#text}))
  fi
}

## 編集関数 ble/widget/vi-command/forward-line
## 編集関数 ble/widget/vi-command/backward-line
##
##   j, k による移動の動作について。
##   論理行を移動するとする。列は行頭からの相対表示位置 (dx,dy) を保持する。
##   別の履歴項目に移った時は列は先頭に移る。
##
##   todo: 移動開始時の相対表示位置の記録は現在行っていない。
##
function ble/widget/vi-command/.forward-line {
  local arg=$1
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
    else
      ble/widget/.kill-range "$beg" "$end"
      [[ $flag == c ]] && ble/widget/vi-command/insert-mode
    fi
    return
  fi

  # 現在の履歴項目内での探索
  ble-edit/text/find-logical-bol "$ind" 0; local bol1=$ret
  ble-edit/text/find-logical-bol "$ind" "$arg"; local bol2=$ret
  local beg end; ((bol1<=bol2?(beg=bol1,end=bol2):(beg=bol2,end=bol1)))
  ble/string#count-char "${_ble_edit_str:beg:end-beg}" $'\n'; local nmove=$ret
  ((count-=nmove))
  if ((count==0)); then
    local b1x b1y; ble-edit/text/getxy.cur --prefix=b1 "$bol1"
    local b2x b2y; ble-edit/text/getxy.cur --prefix=b2 "$bol2"

    ble-edit/text/find-logical-eol "$bol2"; local eol2=$ret
    local c1x c1y; ble-edit/text/getxy.cur --prefix=c1 "$ind"
    local e2x e2y; ble-edit/text/getxy.cur --prefix=e2 "$eol2"

    local x=$c1x y=$((b2y+c1y-b1y))
    ((y>e2y&&(x=e2x,y=e2y)))

    ble-edit/text/get-index-at $x $y
    ble/widget/.goto-char "$index"
    return
  fi

  # 履歴項目を行数を数えつつ移動
  ((count--))
  while ((count>=0)); do
    if ((arg<0)); then
      ble/widget/history-prev
    else
      ble/widget/history-next
    fi
    ble/string#count-char "$_ble_edit_str" $'\n'; local nline=$((ret+1))
    ((count<nline)) && break
    ((count-=nline))
  done

  if ((count)); then
    if ((arg<0)); then
      ble-edit/text/find-logical-eol 0 "$((nline-count-1))"
    else
      ble-edit/text/find-logical-bol 0 "$count"
    fi
    ble/widget/.goto-char "$ret"
  fi
}
function ble/widget/vi-command/forward-line {
  local arg flag; ble/widget/vi-command/.get-arg
  ((arg<=0&&(arg=1)))
  ble/widget/vi-command/.forward-line "$arg"
}
function ble/widget/vi-command/backward-line {
  local arg flag; ble/widget/vi-command/.get-arg
  ((arg<=0&&(arg=1)))
  ble/widget/vi-command/.forward-line "$((-arg))"
}

function ble/widget/vi-command/yank-current-line {
  local arg flag; ble/widget/vi-command/.get-arg
  ble-assert false not-implemented
}

function ble/widget/vi-command/delete-current-line {
  local arg flag; ble/widget/vi-command/.get-arg
  ble-assert false not-implemented
}

function ble/widget/vi-command/delete-current-line-and-insert {
  local arg flag; ble/widget/vi-command/.get-arg
  ble-assert false not-implemented
}

function ble/widget/vi-command/beginning-of-line {
  local arg flag; ble/widget/vi-command/.get-arg
  ble-assert false not-implemented
}

#------------------------------------------------------------------------------

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command
  ble-bind -f i vi-command/insert-mode
  ble-bind -f a vi-command/append-mode
  ble-bind -f R vi-command/replace-mode

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

  ble-bind -f h vi-command/backward-char
  ble-bind -f j vi-command/forward-line
  ble-bind -f k vi-command/backward-line
  ble-bind -f l vi-command/forward-char
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
  ble-bind -f 'M-<'     history-beginning
  ble-bind -f 'M->'     history-end
  ble-bind -f 'C-prior' history-beginning
  ble-bind -f 'C-next'  history-end
  ble-bind -f 'SP'      magic-space

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
  ble-bind -f 'C-a'    'nomarked beginning-of-line'
  ble-bind -f 'C-e'    'nomarked end-of-line'
  ble-bind -f 'home'   'nomarked beginning-of-line'
  ble-bind -f 'end'    'nomarked end-of-line'
  ble-bind -f 'M-m'    'nomarked beginning-of-line'
  ble-bind -f 'S-C-a'  'marked beginning-of-line'
  ble-bind -f 'S-C-e'  'marked end-of-line'
  ble-bind -f 'S-home' 'marked beginning-of-line'
  ble-bind -f 'S-end'  'marked end-of-line'
  ble-bind -f 'S-M-m'  'marked beginning-of-line'
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
