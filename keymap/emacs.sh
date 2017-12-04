#!/bin/bash

# include guard
ble/util/isfunction ble-edit/load-keymap-definition:emacs && return
function ble-edit/load-keymap-definition:emacs { :; }

# 2015-12-09 keymap cache should be updated due to the refactoring.

#------------------------------------------------------------------------------

function ble-decode/keymap:emacs/define {
  local ble_bind_keymap=emacs

  #----------------------------------------------------------------------------
  # common bindings + modifications

  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history

  # charwise operations
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'

  # history
  ble-bind -f 'C-RET'    history-expand-line
  ble-bind -f 'SP'       magic-space

  #----------------------------------------------------------------------------

  ble-bind -f __attach__ safe/__attach__

  # accept/cancel
  ble-bind -f  'C-c'     discard-line
  ble-bind -f  'C-j'     accept-line
  ble-bind -f  'C-m'     accept-single-line-or-newline
  ble-bind -f  'RET'     accept-single-line-or-newline
  ble-bind -f  'C-o'     accept-and-next
  ble-bind -f  'C-g'     bell

  # shell functions
  ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'M-l'     redraw-line
  ble-bind -f  'C-i'     complete
  ble-bind -f  'TAB'     complete
  ble-bind -f  'f1'      command-help
  ble-bind -f  'C-x C-v' display-shell-version
  ble-bind -cf 'C-z'     fg
  ble-bind -cf 'M-z'     fg

  # ble-bind -f 'C-x'      bell
  ble-bind -f 'C-['      bell
  ble-bind -f 'C-\'      bell
  ble-bind -f 'C-]'      bell
  ble-bind -f 'C-^'      bell
}

function ble-decode/keymap:emacs/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.emacs
  if [[ $fname_keymap_cache -nt $_ble_base/keymap/emacs.sh &&
          $fname_keymap_cache -nt $_ble_base/cmap/default.sh ]]; then
    source "$fname_keymap_cache" && return
  fi

  printf %s "ble.sh: updating cache/keymap.emacs... $_ble_term_cr" >&2

  ble-decode/keymap:isearch/define
  ble-decode/keymap:emacs/define

  {
    ble-decode/keymap/dump isearch
    ble-decode/keymap/dump emacs
  } >| "$fname_keymap_cache"

  echo "ble.sh: updating cache/keymap.emacs... done" >&2
}

ble-decode/keymap:emacs/initialize
