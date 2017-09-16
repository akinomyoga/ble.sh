#!/bin/bash

source "$_ble_base/keymap/vi.sh"

# surround.vim (https://github.com/tpope/vim-surround) の模倣実装
#
# 現在以下のみに対応している。
#
#   nmap: ys{move}{char}
#   nmap: yss{char}
#
#     {char}
#
#       <, t        (未対応) タグで囲む
#       右括弧類    括弧で囲む
#       左括弧類    括弧で囲む
#       [a-zA-Z]    エラー
#       他の文字    その文字で囲む
#
#   注意: vim-surround.sh と違って、
#     テキストオブジェクト等に対する引数は有効である。
#     または、aw は iw と異なる位置に挿入する。
#
#   注意: vim-surround.sh と同様に、
#     g~2~ などとは違って、
#     ys2s のような引数の指定はできない。
#
# 以下には対応していない。
#
#   nmap: ds
#   nmap: cs
#   nmap: cS
#   nmap: yS
#   nmap: ySsd
#   nmap: ySSd
#   xmap: S
#   xmap: gS
#   imap: <C-S>
#   imap: <C-G>s
#   imap: <C-G>S
#

## 関数 ble/widget/vim-surround.sh/get-char-from-key key
##   @param[in] key
##   @var[out] ret
function ble/widget/vim-surround.sh/get-char-from-key {
  local key=$1
  if ! ble-decode-key/ischar "$key"; then
    local flag=$((key&ble_decode_MaskFlag)) code=$((key&ble_decode_MaskChar))
    if ((flag==ble_decode_Ctrl&&63<=code&&code<128&&(code&0x1F)!=0)); then
      ((key=code==63?127:code&0x1F))
    else
      return 1
    fi
  fi

  ble/util/c2s "$key"
}

_ble_lib_vim_surround_sh_ys=()

function ble/keymap:vi/operator:ys {
  _ble_lib_vim_surround_sh_ys=("$@")
  _ble_keymap_vi_operator_delayed=1
  _ble_decode_key__hook=ble/widget/vim-surround.sh/ysurround.hook
}

function ble/widget/vim-surround.sh/ysurround.hook {
  local prefix= suffix=

  local ins= instype= ret
  if (($1==(ble_decode_Ctrl|0x5D)||$1==(ble_decode_Ctrl|0x7D))); then # 0x5D = ], 0x7D = }
    ins='}' instype=indent
  elif ble/widget/vim-surround.sh/get-char-from-key "$1"; then
    ins=$ret
  fi

  if [[ ! $ins ]]; then
    ble/widget/vi-command/bell
    return
  fi

  case "$ins" in
  (['<t'])
    ble/widget/vi-command/bell
    return ;;
  ('(') prefix='( ' suffix=' )' ;;
  ('[') prefix='[ ' suffix=' ]' ;;
  ('{') prefix='{ ' suffix=' }' ;;
  (['b)']) prefix='(' suffix=')' ;;
  (['r]']) prefix='[' suffix=']' ;;
  (['B}']) prefix='{' suffix='}' ;;
  (['r>']) prefix='<' suffix='>' ;;
  ([a-zA-Z])
    ble/widget/vi-command/bell
    return ;;
  (*) prefix=$ins suffix=$ins ;;
  esac

  local beg=${_ble_lib_vim_surround_sh_ys[0]}
  local end=${_ble_lib_vim_surround_sh_ys[1]}
  local type=${_ble_lib_vim_surround_sh_ys[2]}
  _ble_lib_vim_surround_sh_ys=()

  # 範囲末端の空白は囲む対象としない
  local text=${_ble_edit_str:beg:end-beg}
  if local rex=$'[ \t\n]+$'; [[ $text =~ $rex ]]; then
    ((end-=${#BASH_REMATCH}))
    text=${_ble_edit_str:beg:end-beg}
  fi

  if [[ $instype == indent ]]; then
    ble-edit/content/find-logical-bol "$beg"; local bol=$ret
    ble-edit/content/find-nol-from-bol "$bol"; local nol=$ret
    text=${_ble_edit_str:bol:nol-bol}${text}
    ble/keymap:vi/string#increase-indent "$text" 8
    text=$'\n'$ret$'\n'${_ble_edit_str:bol:nol-bol}
  fi

  ble/widget/.replace-range "$beg" "$end" "$prefix$text$suffix" 1

  ble/widget/.goto-char "$beg"
  if [[ $type == line ]]; then
    ble/widget/vi-command/first-non-space
  else
    ble/keymap:vi/adjust-command-mode
  fi
}

function ble/widget/vim-surround.sh/ysurround-current-line {
  ble/widget/vi-command/set-operator ys
  ble/widget/vi-command/set-operator ys
}

ble-bind -m vi_command -f 'y s'   'vi-command/set-operator ys'
ble-bind -m vi_command -f 'y s s' 'vim-surround.sh/ysurround-current-line'
