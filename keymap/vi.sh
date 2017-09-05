#!/bin/bash

# Note: bind (DEFAULT_KEYMAP) の中から再帰的に呼び出されるので、
# 先に ble-edit/load-keymap-definition:vi を上書きする必要がある。
function ble-edit/load-keymap-definition:vi { :; }

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

function ble/widget/vi-insert/normal-mode {
  _ble_edit_overwrite_mode=
  if ((_ble_edit_ind>=0)) && [[ ${_ble_edit_str[_ble_edit_ind-1]} != $'\n' ]]; then
    ble/widget/.goto-char "$((_ble_edit_ind-1))"
  fi
  ble-decode/keymap/push vi_command
}
function ble/widget/vi-command/insert-mode {
  ble-decode/keymap/pop
}
function ble/widget/vi-command/append-mode {
  if ((_ble_edit_ind<${#_ble_edit_str})) && [[ ${_ble_edit_str[_ble_edit_ind]} != $'\n' ]]; then
    ble/widget/.goto-char "$((_ble_edit_ind+1))"
  fi
  ble-decode/keymap/pop
}
function ble/widget/vi-command/replace-mode {
  ble/widget/vi-command/insert-mode
  _ble_edit_overwrite_mode=1
}

function ble-decode-keymap:vi_command/define {
  local ble_bind_keymap=vi_command
  ble-bind -f i vi-command/insert-mode
  ble-bind -f a vi-command/append-mode
  ble-bind -f R vi-command/replace-mode
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
