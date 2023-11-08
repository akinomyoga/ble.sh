#!/bin/bash

# include guard
ble/is-function ble-edit/bind/load-editing-mode:emacs && return 0
function ble-edit/bind/load-editing-mode:emacs { :; }

# 2015-12-09 keymap cache should be updated due to the refactoring.
# 2019-01-18 keymap cache should be updated for recent changes
# 2019-03-21 keymap cache should be updated for recent changes
# 2020-04-29 force update (rename ble-decode/keymap/.register)
# 2021-01-25 force update (change mapping of C-w and M-w)
# 2021-04-26 force update (rename ble/decode/keymap#.register)
# 2021-09-23 force update (change to nsearch and bind-history)

# vi functions referenced from core-decode.emacs-rlfunc.txt
ble/util/autoload "$_ble_base/lib/keymap.vi.sh" \
                  ble/widget/vi-rlfunc/{prev,end,next}-word \
                  ble/widget/vi-command/{forward,backward}-{v,u}word \
                  ble/widget/vi-command/forward-{v,u}word-end

bleopt/declare -v keymap_emacs_mode_string_multiline $'\e[1m-- MULTILINE --\e[m'

#------------------------------------------------------------------------------

_ble_keymap_emacs_white_list=(
  self-insert
  batch-insert
  nop
  magic-space magic-slash
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
    local IFS=$_ble_term_IFS
    local cmd=${1#ble/widget/}; cmd=${cmd%%["$_ble_term_IFS"]*}
    [[ $cmd == emacs/* || " ${_ble_keymap_emacs_white_list[*]} " == *" $cmd "*  ]] && return 0
  fi
  return 1
}

function ble/widget/emacs/__before_widget__ {
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

#------------------------------------------------------------------------------
# mode name
#
#   mode name の更新は基本的に __after_widget__ で行う。
#   但し、_ble_decode_{char,key}__hook 経由で実行されると、
#   __after_widget__ は実行されないので、
#   その様な編集コマンドについてだけは個別に update-mode-indicator を呼び出す。
#

function ble/keymap:emacs/.get-emacs-keymap {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'
  local i=${#_ble_decode_keymap_stack[@]}
  keymap=$_ble_decode_keymap
  while [[ $keymap != vi_?map && $keymap != emacs ]]; do
    ((i--)) || return 1
    keymap=${_ble_decode_keymap_stack[i]}
  done
  [[ $keymap == emacs ]]
}

bleopt/declare -v prompt_emacs_mode_indicator '\q{keymap:emacs/mode-indicator}'
function bleopt/check:prompt_emacs_mode_indicator {
  local bleopt_prompt_emacs_mode_indicator=$value
  [[ $_ble_attached ]] && ble/keymap:emacs/update-mode-indicator
  return 0
}

_ble_keymap_emacs_mode_indicator_data=()
function ble/prompt/unit:_ble_keymap_emacs_mode_indicator/update {
  local trace_opts=truncate:relative:noscrc:ansi
  local prompt_rows=1
  local prompt_cols=${COLUMNS:-80}
  ((prompt_cols&&prompt_cols--))
  local "${_ble_prompt_cache_vars[@]/%/=}" # WA #D1570 checked
  ble/prompt/unit:{section}/update _ble_keymap_emacs_mode_indicator "$bleopt_prompt_emacs_mode_indicator" "$trace_opts"
}

function ble/keymap:emacs/update-mode-indicator {
  local keymap
  ble/keymap:emacs/.get-emacs-keymap || return 0

  # prefilter by _ble_edit_str/_ble_edit_arg/_ble_edit_kbdmacro_record
  local opt_multiline=
  [[ $_ble_edit_str == *$'\n'* ]] && opt_multiline=1
  local footprint=$opt_multiline:$_ble_edit_arg:$_ble_edit_kbdmacro_record
  [[ $footprint == "$_ble_keymap_emacs_modeline" ]] && return 0
  _ble_keymap_emacs_modeline=$footprint

  # prompt_emacs_mode_indicator
  local version=$COLUMNS,$_ble_edit_lineno,$_ble_history_count,$_ble_edit_CMD
  local prompt_hashref_base='$version'
  ble/prompt/unit#update _ble_keymap_emacs_mode_indicator
  local ret; ble/prompt/unit:{section}/get _ble_keymap_emacs_mode_indicator; local str=$ret

  [[ $_ble_edit_arg ]] &&
    str=${str:+"$str "}$'(arg: \e[1;34m'$_ble_edit_arg$'\e[m)'
  [[ $_ble_edit_kbdmacro_record ]] &&
    str=${str:+"$str "}$'\e[1;31mREC\e[m'

  ble/edit/info/default ansi "$str"
}
blehook internal_PRECMD!=ble/keymap:emacs/update-mode-indicator

## @fn ble/prompt/backslash:keymap:emacs/mode-indicator
function ble/prompt/backslash:keymap:emacs/mode-indicator {
  ble/prompt/unit/add-hash '$_ble_edit_str'
  [[ $_ble_edit_str == *$'\n'* ]] || return 0

  ble/prompt/unit/add-hash '$bleopt_keymap_emacs_mode_string_multiline'
  local str=$bleopt_keymap_emacs_mode_string_multiline

  # 他の付加情報がない時にだけ keybinding のヒントを出す
  ble/prompt/unit/add-hash '${_ble_edit_arg:+1}${_ble_edit_kbdmacro_record:+1}'
  if [[ ! ${_ble_edit_arg:+1}${_ble_edit_kbdmacro_record:+1} ]]; then
    local keybinding_C_m=${_ble_decode_emacs_kmap_[_ble_decode_Ctrl|0x6d]}
    local keybinding_C_j=${_ble_decode_emacs_kmap_[_ble_decode_Ctrl|0x6a]}
    [[ $keybinding_C_m == *:ble/widget/accept-single-line-or-newline ]] &&
      [[ $keybinding_C_j == *:ble/widget/accept-line ]] &&
      str=${str:+"$str "}$'(\e[35mRET\e[m or \e[35mC-m\e[m: insert a newline, \e[35mC-j\e[m: run)'
  fi

  [[ ! $str ]] || ble/prompt/print "$str"
}

function ble/widget/emacs/__after_widget__ {
  ble/keymap:emacs/update-mode-indicator
}

# quoted-insert
function ble/widget/emacs/quoted-insert-char {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/emacs/quoted-insert-char.hook
  return 147
}
function ble/widget/emacs/quoted-insert-char.hook {
  ble/widget/quoted-insert-char.hook
  ble/keymap:emacs/update-mode-indicator
}
function ble/widget/emacs/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/emacs/quoted-insert.hook
  return 147
}
function ble/widget/emacs/quoted-insert.hook {
  ble/widget/quoted-insert.hook
  ble/keymap:emacs/update-mode-indicator
}

function ble/widget/emacs/bracketed-paste {
  ble/widget/bracketed-paste
  _ble_edit_bracketed_paste_proc=ble/widget/emacs/bracketed-paste.proc
  return 147
}
function ble/widget/emacs/bracketed-paste.proc {
  ble/widget/bracketed-paste.proc "$@"
  ble/keymap:emacs/update-mode-indicator
}

#------------------------------------------------------------------------------

function ble-decode/keymap:emacs/define {
  #----------------------------------------------------------------------------
  # common bindings + modifications

  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete
  ble-decode/keymap:safe/bind-arg

  # charwise operations
  ble-bind -f 'C-d'      'delete-region-or delete-forward-char-or-exit'

  # history
  ble-bind -f 'M-^'      history-expand-line
  ble-bind -f 'SP'       magic-space
  ble-bind -f '/'        magic-slash

  #----------------------------------------------------------------------------

  ble-bind -f __attach__        safe/__attach__
  ble-bind -f __before_widget__ emacs/__before_widget__
  ble-bind -f __after_widget__  emacs/__after_widget__
  ble-bind -f __line_limit__    __line_limit__

  # accept/cancel
  ble-bind -f 'C-c'      discard-line
  ble-bind -f 'C-j'      accept-line
  ble-bind -f 'C-RET'    accept-line
  ble-bind -f 'C-m'      accept-single-line-or-newline
  ble-bind -f 'RET'      accept-single-line-or-newline
  ble-bind -f 'C-o'      accept-and-next
  ble-bind -f 'C-x C-e'  edit-and-execute-command
  ble-bind -f 'M-#'      insert-comment
  ble-bind -f 'M-C-e'    shell-expand-line
  ble-bind -f 'M-&'      tilde-expand
  ble-bind -f 'C-g'      bell
  ble-bind -f 'C-x C-g'  bell
  ble-bind -f 'C-M-g'    bell

  # shell functions
  ble-bind -f 'C-l'      clear-screen
  ble-bind -f 'C-M-l'    redraw-line
  ble-bind -f 'f1'       command-help
  ble-bind -f 'C-x C-v'  display-shell-version
  ble-bind -c 'C-z'      fg
  ble-bind -f 'M-z'      zap-to-char

  ble-bind -f 'C-\'      bell
  ble-bind -f 'C-^'      bell

  #----------------------------------------------------------------------------

  # undo
  ble-bind -f 'C-_'       emacs/undo
  ble-bind -f 'C-DEL'     emacs/undo
  ble-bind -f 'C-BS'      emacs/undo
  ble-bind -f 'C-/'       emacs/undo
  ble-bind -f 'C-x u'     emacs/undo
  ble-bind -f 'C-x C-u'   emacs/undo
  ble-bind -f 'C-x U'     emacs/redo
  ble-bind -f 'C-x C-S-u' emacs/redo
  ble-bind -f 'M-r'       emacs/revert

  # mode name
  ble-bind -f 'C-q'       emacs/quoted-insert
  ble-bind -f 'C-v'       emacs/quoted-insert
  ble-bind -f paste_begin emacs/bracketed-paste
}

function ble-decode/keymap:emacs/initialize {
  local fname_keymap_cache=$_ble_base_cache/keymap.emacs
  if [[ -s $fname_keymap_cache &&
          $fname_keymap_cache -nt $_ble_base/lib/keymap.emacs.sh &&
          $fname_keymap_cache -nt $_ble_base/lib/init-cmap.sh ]]; then
    source "$fname_keymap_cache" && return 0
  fi

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.emacs..."

  {
    ble/decode/keymap#load isearch dump
    ble/decode/keymap#load nsearch dump
    ble/decode/keymap#load emacs   dump
  } 3>| "$fname_keymap_cache"

  ble/edit/info/immediate-show text "ble.sh: updating cache/keymap.emacs... done"
}

ble-decode/keymap:emacs/initialize
blehook/invoke keymap_load
blehook/invoke keymap_emacs_load
return 0
