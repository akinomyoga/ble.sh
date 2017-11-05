#!/bin/bash

# 2015-12-09 keymap cache should be updated due to the refactoring.

#
# $_ble_base_cache/ble-decode-keymap.emacs
#

function ble-decode-keymap:emacs/define {
  local ble_bind_keymap=emacs

  ble-bind -f __attach__  emacs/.attach

  ble-bind -f insert      overwrite-mode

  # ins
  ble-bind -f __defchar__ self-insert
  ble-bind -f 'C-q'       quoted-insert
  ble-bind -f 'C-v'       quoted-insert
  ble-bind -f 'C-M-m'     newline
  ble-bind -f 'M-RET'     newline

  # shell function
  ble-bind -f  'C-c'     discard-line
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

  ble-bind -f 'C-p'    '@nomarked backward-line-or-history-prev'
  ble-bind -f 'up'     '@nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'    '@nomarked forward-line-or-history-next'
  ble-bind -f 'down'   '@nomarked forward-line-or-history-next'
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

function ble-decode-keymap:emacs/generate {
  ble-decode-bind/cmap/initialize
  source "$_ble_base/keymap/isearch.sh"

  echo -n "ble.sh: updating cache/keymap.emacs... $_ble_term_cr" >&2

  local cache="$_ble_base_cache/keymap.emacs"
  ble-decode-keymap:isearch/define
  ble-decode-keymap:emacs/define

  : >| "$cache"
  ble-decode/keymap/dump emacs   >> "$cache"
  ble-decode/keymap/dump isearch >> "$cache"

  echo "ble.sh: updating cache/keymap.emacs... done" >&2
}

ble-decode-keymap:emacs/generate
