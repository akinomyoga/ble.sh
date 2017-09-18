#!/bin/bash

source "$_ble_base/keymap/vi.sh"

# surround.vim (https://github.com/tpope/vim-surround) の模倣実装
#
# 現在以下のみに対応している。
#
#   nmap: ys{move}{ins}
#   nmap: yss{ins}
#
#     {ins} ~ / ?./
#
#       空白を前置した場合は、囲まれる文字列の両端に半角空白を1つずつ付加する。
#       最後の文字によって囲み文字を指定する。
#
#       <, t        (未対応) タグで囲む
#       右括弧類    括弧で囲む
#       左括弧類    括弧で囲む
#       [a-zA-Z]    エラー
#       他の文字    その文字で囲む
#
#   注意: surround.vim と違って、
#     テキストオブジェクト等に対する引数は有効である。
#     または、aw は iw と異なる位置に挿入する。
#
#   注意: surround.vim と同様に、
#     g~2~ などとは違って、
#     ys2s のような引数の指定はできない。
#
#   nmap: ds{del}
#   nmap: cs{del}{ins}
#
#     {del} ~ /([0-9]+| )?./
#
#       削除される囲み文字を指定する。
#       [0-9]+ を指定した場合は引数に対する倍率となる。
#       空白を前置した場合は囲まれた文字列の両端の空白を trim する。
#
#       最後の文字によって囲み文字を指定する。
#
#       b()B{}r[]a<>    括弧を削除する。左括弧を指定したとき囲まれた文字列は trim される。
#       wW              範囲を指定するのみで、何も削除しない。
#       ps (未対応)     範囲を指定するのみで、何も削除しない。
#       tT              タグ。T を用いたとき囲まれた文字列は trim される。
#       /               /* ... */ で囲まれた領域を削除する。
#       他の文字        その文字を、行内で左右に探して対で削除する。
#
#     {ins} ~ / ?./
#
#       代わりに挿入される囲み文字を指定する。ys, yss と同じ。
#
# 以下には対応していない。
#
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


#------------------------------------------------------------------------------
# util

function ble/string#trim {
  ret=$*
  local rex=$'^[ \t\n]+'
  [[ $ret =~ $rex ]] && ret=${ret:${#BASH_REMATCH}}
  local rex=$'[ \t\n]+$'
  [[ $ret =~ $rex ]] && ret=${ret::${#ret}-${#BASH_REMATCH}}
}

## 関数 ble/lib/vim-surround.sh/get-char-from-key key
##   @param[in] key
##   @var[out] ret
function ble/lib/vim-surround.sh/get-char-from-key {
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
  return 0
}

function ble/lib/vim-surround.sh/async-inputtarget.hook {
  local mode=$1 hook=${@:2:$#-2} key=${@:$#}
  if ! ble/lib/vim-surround.sh/get-char-from-key "$key"; then
    ble/widget/vi-command/bell
    return
  fi

  local c=$ret
  if [[ :$mode: == *:digit:* && $c == [0-9] ]]; then
    _ble_edit_arg=$_ble_edit_arg$c
    _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook digit $hook"
    return
  elif [[ :$mode: == *:init:* && $c == ' ' ]]; then
    _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook space $hook"
    return
  fi

  if [[ $c == [$'\e\003'] ]]; then # C-[, C-c
    ble/widget/vi-command/bell
  else
    [[ $c == \' ]] && c="'\''"
    [[ $mode == space ]] && c=' '$c
    eval "$hook '$c'"
  fi
}
function ble/lib/vim-surround.sh/async-inputtarget {
  _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook init:digit $*"
}
function ble/lib/vim-surround.sh/async-inputtarget-noarg {
  _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook init $*"
}

: ${bleopt_vim_surround_45:=$'$(\r)'} # ysiw-
: ${bleopt_vim_surround_61:=$'$((\r))'} # ysiw=
: ${bleopt_vim_surround_q:=\"} # ysiwQ
: ${bleopt_vim_surround_Q:=\'} # ysiwq

## 関数 ble/lib/vim-surround.sh/load-template ins
##   @param[in] ins
##   @var[out] template
function ble/lib/vim-surround.sh/load-template {
  local ins=$1

  # read user settings

  local optname=bleopt_vim_surround_$ins
  template=${!optname}
  [[ $template ]] && return

  local ret; ble/util/s2c "$ins"
  local optname=bleopt_vim_surround_$ret
  template=${!optname}
  [[ $template ]] && return

  # default

  case "$ins" in
  (['<t']) return 1 ;;
  ('(') template=$'( \r )' ;;
  ('[') template=$'[ \r ]' ;;
  ('{') template=$'{ \r }' ;;
  (['b)']) template=$'(\r)' ;;
  (['r]']) template=$'[\r]' ;;
  (['B}']) template=$'{\r}' ;;
  (['a>']) template=$'<\r>' ;;
  ([a-zA-Z]) return 1 ;;
  (*) template=$ins ;;
  esac
} &>/dev/null

## 関数 ble/lib/vim-surround.sh/surround text ins
##   @param[in] text
##   @param[in] ins
##   @var[in] beg
##   @var[out] ret
function ble/lib/vim-surround.sh/surround {
  local text=$1 ins=$2

  local instype=
  [[ $ins == $'\x1D' ]] && ins='}' instype=indent # C-], C-}

  local has_space=
  [[ $ins == ' '?* ]] && has_space=1 ins=${ins:1}

  local template=
  ble/lib/vim-surround.sh/load-template "$ins" || return 1

  local prefix= suffix=
  if [[ $template == *$'\r'* ]]; then
    prefix=${template%%$'\r'*}
    suffix=${template#*$'\r'}
  else
    prefix=$template
    suffix=$template
  fi

  if [[ $prefix == *' ' && $suffix == ' '* ]]; then
    prefix=${prefix::${#prefix}-1}
    suffix=${suffix:1}
    has_space=1
  fi

  if [[ $instype == indent ]]; then
    ble-edit/content/find-logical-bol "$beg"; local bol=$ret
    ble-edit/content/find-nol-from-bol "$bol"; local nol=$ret
    text=${_ble_edit_str:bol:nol-bol}${text}
    ble/keymap:vi/string#increase-indent "$text" 8
    text=$'\n'$ret$'\n'${_ble_edit_str:bol:nol-bol}
  fi

  [[ $has_space && $text != *$'\n'* ]] && text=' '$text' '

  ret=$prefix$text$suffix
}

#------------------------------------------------------------------------------
# ys yss

_ble_lib_vim_surround_ys=()

function ble/keymap:vi/operator:ys {
  _ble_lib_vim_surround_ys=("$@")
  _ble_keymap_vi_operator_delayed=1
  ble/lib/vim-surround.sh/async-inputtarget-noarg ble/widget/vim-surround.sh/ysurround.hook
}

function ble/widget/vim-surround.sh/ysurround.hook {
  local ins=$1

  local ret

  # saved arguments
  local beg=${_ble_lib_vim_surround_ys[0]}
  local end=${_ble_lib_vim_surround_ys[1]}
  local context=${_ble_lib_vim_surround_ys[2]}
  _ble_lib_vim_surround_ys=()

  # text
  local text=${_ble_edit_str:beg:end-beg}
  if local rex=$'[ \t\n]+$'; [[ $text =~ $rex ]]; then
    # 範囲末端の空白は囲む対象としない
    ((end-=${#BASH_REMATCH}))
    text=${_ble_edit_str:beg:end-beg}
  fi

  # surround
  if ! ble/lib/vim-surround.sh/surround "$text" "$ins"; then
    ble/widget/vi-command/bell
    return
  fi
  local text=$ret

  ble/widget/.replace-range "$beg" "$end" "$text" 1

  ble/widget/.goto-char "$beg"
  if [[ $context == line ]]; then
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


#------------------------------------------------------------------------------
# ds cs

# 仕様: surround.vim の実装は杜撰なのでここで vim-surround.sh の独自仕様を定める。
#
#   ds, cs は続いて /([0-9]+| )?./ の形式の引数を受け取る。
#
#     /[0-9]+/ が指定された時は引数に対する倍率を表す。
#
#     / / が指定された時は囲みの内側にある空白も削除することを表す。
#
#     /./ として wW を指定したときは何も削除しない。
#     c = b)B}r]a> を指定した時は text-object {arg}ic を残して {arg}ac を削除する。
#     c = ({[< を指定した時は更に内側の空白も削除する。
#     c = '"` を指定した場合には引数は無視する。ic を残して ac を削除する。
#     それ以外の c = a-zA-Z は既定として text-object {arg}ic を残し {arg}ac を削除する。
#     それ以外の文字に関しては行内で一致を検索する。
#
#     ToDo: /[pstT]/ は本体で実装が追いついていないので未対応
#
#   更に cs は続いて / ?./ の形式の引数を受け取る。
#
#     / / が指定されたtときは左右内側に空白を 1 つずつ付加する。
#
#   オリジナルの surround.vim とはところどころで振る舞いが異なる。
#   振る舞いの違いに関しては ble.sh/memo.txt #D0457 を参照のこと。
#
#   ToDo: ds, cs において囲まれている対象に改行が含まれる場合、
#     置換を行った後に関係する行を == でインデントする。
#     現在、本体で = に対応していないのでこれも未対応である。
#

## 関数 ble/keymap:vi/operator:surround
##   @var[in] $surround_content
##   @var[in] $surround_trim
function ble/keymap:vi/operator:surround {
  local beg=$1 end=$2 context=$3
  local content=$surround_content ins=$surround_ins trims=$surround_trim

  local ret
  if [[ $trims ]]; then
    ble/string#trim "$content"; content=$ret
  fi

  if ! ble/lib/vim-surround.sh/surround "$content" "$ins"; then
    ble/widget/vi-command/bell
    return
  fi
  content=$ret

  ble/widget/.replace-range "$beg" "$end" "$content"

  # if [[ $has_nl ]]; then
  #   # todo: indent
  # fi

  return 0
}

function ble/widget/vim-surround.sh/csurround.core {
  local arg=$1 del=$2 ins=$3

  local to1= to2=
  local surround_trim= surround_ins=$ins

  [[ $del == ' '?* ]] && surround_trim=1 del=${del:1}
  if [[ $del == a ]]; then
    del='>'
  elif [[ $del == r ]]; then
    del=']'
  elif [[ $del == T ]]; then
    del='t' surround_trim=1
  fi

  case "$del" in
  ([wWps])      to1=i$del to2=i$del ;;
  ([\'\"\`])    to1=i$del to2=a$del arg=1 ;;
  (['bB)}>]t']) to1=i$del to2=a$del ;;
  (['({<['])    to1=i$del to2=a$del surround_trim=1 ;;
  ([a-zA-Z])    to1=i$del to2=a$del ;;
  esac

  if [[ $to1 && $to2 ]]; then
    # テキストオブジェクトによって指定される範囲

    local ind=$_ble_edit_ind

    local _ble_edit_kill_ring _ble_edit_kill_type
    ble/keymap:vi/text-object.impl "$arg" y "$to1"; local ext=$?
    ble/widget/.goto-char "$ind"
    ((ext!=0)) && return 1

    local surround_content="$_ble_edit_kill_ring"
    ble/keymap:vi/text-object.impl "$arg" surround "$to2" || return 1
  elif [[ $del == / ]]; then
    # /* ..  */ で囲まれた部分

    local rex='(/\*([^/]|/[^*])*/?){1,'$arg'}$'
    [[ ${_ble_edit_str::_ble_edit_ind+2} =~ $rex ]] || return 1
    local beg=$((_ble_edit_ind+2-${#BASH_REMATCH}))

    ble/string#index-of "${_ble_edit_str:beg+2}" '*/' || return 1
    local end=$((beg+ret+4))

    local surround_content=${_ble_edit_str:beg+2:end-beg-4}
    ble/keymap:vi/operator:surround "$beg" "$end" char
    ble/widget/.goto-char "$beg"
  elif [[ $del ]]; then
    # 指定した文字で囲まれた部分

    local ret
    ble-edit/content/find-logical-bol; local bol=$ret
    ble-edit/content/find-logical-eol; local eol=$ret
    local line=${_ble_edit_str:bol:eol-bol}
    local ind=$((_ble_edit_ind-bol))

    # beg
    local beg
    if ble/string#last-index-of "${line::ind}" "$del"; then
      beg=$ret
    elif local base=$((ind-(2*${#del}-1))); ((base>=0||(base=0)))
         ble/string#index-of "${line:base:ind+${#del}-base}" "$del"; then
      beg=$((base+ret))
    else
      return 1
    fi

    # end
    ble/string#index-of "${line:beg+${#del}}" "$del" || return 1
    local end=$((beg+2*${#del}+ret))

    ((beg+=bol,end+=bol))

    local surround_content=${_ble_edit_str:beg+${#del}:end-beg-2*${#del}}
    ble/keymap:vi/operator:surround "$beg" "$end" char
    ble/widget/.goto-char "$beg"
  else
    ble/widget/vi-command/bell
  fi
  ble/keymap:vi/adjust-command-mode
}
function ble/widget/vim-surround.sh/dsurround.hook {
  local del=$1
  local arg flag; ble/keymap:vi/get-arg 1 # flag=ds
  ble/widget/vim-surround.sh/csurround.core "$arg" "$del" || ble/widget/vi-command/bell
}
function ble/widget/vim-surround.sh/dsurround {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}ds
    ble/lib/vim-surround.sh/async-inputtarget ble/widget/vim-surround.sh/dsurround.hook
  fi
}

_ble_lib_vim_surround_cs_del=

function ble/widget/vim-surround.sh/csurround.hook2 {
  local del=$_ble_lib_vim_surround_cs_del ins=$1
  local arg flag; ble/keymap:vi/get-arg 1 # flag=cs
  ble/widget/vim-surround.sh/csurround.core "$arg" "$del" "$ins" || ble/widget/vi-command/bell
}
function ble/widget/vim-surround.sh/csurround.hook1 {
  local del=$1
  if [[ $del ]]; then
    _ble_lib_vim_surround_cs_del=$1
    ble/lib/vim-surround.sh/async-inputtarget-noarg ble/widget/vim-surround.sh/csurround.hook2
  else
    _ble_lib_vim_surround_cs_del=
    ble/widget/vi-command/bell
  fi
}
function ble/widget/vim-surround.sh/csurround {
  local arg flag; ble/keymap:vi/get-arg 1
  if [[ $flag ]]; then
    ble/widget/vi-command/bell
  else
    _ble_edit_arg=${arg}cs
    ble/lib/vim-surround.sh/async-inputtarget ble/widget/vim-surround.sh/csurround.hook1
  fi
}

ble-bind -m vi_command -f 'd s' 'vim-surround.sh/dsurround'
ble-bind -m vi_command -f 'c s' 'vim-surround.sh/csurround'
