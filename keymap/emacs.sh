#!/bin/bash

# include guard
ble/util/isfunction ble-edit/load-keymap-definition:emacs && return
function ble-edit/load-keymap-definition:emacs { :; }

# 2015-12-09 keymap cache should be updated due to the refactoring.

#------------------------------------------------------------------------------

function ble/widget/emacs/append-arg {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ((code==0)) && return 1
  local ret; ble/util/c2s "$code"; local ch=$ret

  if 
    if [[ $_ble_edit_arg ]]; then
      [[ $ch == [0-9] ]]
    else
      ((KEYS[0]&ble_decode_MaskFlag))
    fi
  then
    _ble_edit_arg=$_ble_edit_arg$ch
  else
    ble/widget/self-insert
  fi
}

_ble_keymap_emacs_white_list=(
  self-insert
  nop
  magic-space
  copy{,-forward,-backward}-{c,f,s,u}word
  copy-region{,-or}
  clear-screen
  command-help
  display-shell-version
  redraw-line
  # delete-backward-{c,f,s,u}word
  # delete-bacward-char
)
function ble/keymap:emacs/is-command-white {
  if [[ $1 == ble/widget/self-insert ]]; then
    # frequently used command is checked first
    return 0
  elif [[ $1 == ble/widget/* ]]; then
    local cmd=${1#ble/widget/}; cmd=${cmd%%[$' \t\n']*}
    [[ $cmd == emacs/* || " ${_ble_keymap_emacs_white_list[*]} " == *" $cmd "*  ]] && return 0
  fi
  return 1
}

function ble/widget/emacs/__before_command__ {
  if ! ble/keymap:emacs/is-command-white "$WIDGET"; then
    ble-edit/undo/add
  fi
}

#------------------------------------------------------------------------------
# 注意: ble/widget/emacs/* の名称の編集関数では、
# 必要に応じて手動で ble-edit/undo/add を呼び出さなければならない。

function ble/widget/emacs/undo {
  local arg; ble-edit/content/get-arg 1
  ble-edit/undo/undo "$arg" || ble/widget/.bell 'no more older undo history'
}
function ble/widget/emacs/redo {
  local arg; ble-edit/content/get-arg 1
  ble-edit/undo/redo "$arg" || ble/widget/.bell 'no more recent undo history'
}
function ble/widget/emacs/revert {
  local arg; ble-edit/content/clear-arg
  ble-edit/undo/revert
}

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

  ble-bind -f __attach__         safe/__attach__
  ble-bind -f __before_command__ emacs/__before_command__

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

  #----------------------------------------------------------------------------

  ble-bind -f M-- emacs/append-arg
  ble-bind -f M-0 emacs/append-arg
  ble-bind -f M-1 emacs/append-arg
  ble-bind -f M-2 emacs/append-arg
  ble-bind -f M-3 emacs/append-arg
  ble-bind -f M-4 emacs/append-arg
  ble-bind -f M-5 emacs/append-arg
  ble-bind -f M-6 emacs/append-arg
  ble-bind -f M-7 emacs/append-arg
  ble-bind -f M-8 emacs/append-arg
  ble-bind -f M-9 emacs/append-arg

  ble-bind -f C-- emacs/append-arg
  ble-bind -f C-0 emacs/append-arg
  ble-bind -f C-1 emacs/append-arg
  ble-bind -f C-2 emacs/append-arg
  ble-bind -f C-3 emacs/append-arg
  ble-bind -f C-4 emacs/append-arg
  ble-bind -f C-5 emacs/append-arg
  ble-bind -f C-6 emacs/append-arg
  ble-bind -f C-7 emacs/append-arg
  ble-bind -f C-8 emacs/append-arg
  ble-bind -f C-9 emacs/append-arg

  ble-bind -f - emacs/append-arg
  ble-bind -f 0 emacs/append-arg
  ble-bind -f 1 emacs/append-arg
  ble-bind -f 2 emacs/append-arg
  ble-bind -f 3 emacs/append-arg
  ble-bind -f 4 emacs/append-arg
  ble-bind -f 5 emacs/append-arg
  ble-bind -f 6 emacs/append-arg
  ble-bind -f 7 emacs/append-arg
  ble-bind -f 8 emacs/append-arg
  ble-bind -f 9 emacs/append-arg

  ble-bind -f 'C-_'       emacs/undo
  ble-bind -f 'C-DEL'     emacs/undo
  ble-bind -f 'C-/'       emacs/undo
  ble-bind -f 'C-x u'     emacs/undo
  ble-bind -f 'C-x C-u'   emacs/undo
  ble-bind -f 'C-x U'     emacs/redo
  ble-bind -f 'C-x C-S-u' emacs/redo
  ble-bind -f 'M-r'       emacs/revert
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
