#!/bin/bash

source "$_ble_base/keymap/vi.sh"

# surround.vim (https://github.com/tpope/vim-surround) の模倣実装
#
# 現在以下のみに対応している。
#
#   nmap: ys{move}{ins}
#   nmap: yss{ins}
#   nmap: yS{move}{ins}
#   nmap: ySS{ins} または ySs{ins}
#   xmap: S{ins}
#   xmap: gS{ins}
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
#   注意: surround.vim と違って、
#     2ys3s のような引数の指定を行うことができる。
#     これは 2y3y と同様に現在行から 6 行に亘って作用する。
#
#   注意: . によってこのオペレータを繰り返すとき、
#     再度入力を求める surround.vim と違って、
#     前回使用した区切り文字を使用する。
#
#   注意: surround.vim では矩形選択の末尾拡張を判定できないため、
#     S は非末尾拡張で gS は末尾拡張として働くが、
#     この実装では S は現在末尾拡張状態を使い gS は末尾拡張を常に行う。
#
#   nmap: ds{del}
#   nmap: cs{del}{ins}
#   nmap: cS{del}{ins}
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
#   注意: . によってこの操作を繰り返すとき、
#     surround.vim では {del} を空文字列とし {ins} について入力を求めるが、
#     この実装では前回使用した {del} と {ins} を使用して動作する。
#
# 以下には対応していない。
#
#   imap: <C-S>
#   imap: <C-G>s
#   imap: <C-G>S
#

: ${bleopt_vim_surround_45:=$'$(\r)'} # ysiw-
: ${bleopt_vim_surround_61:=$'$((\r))'} # ysiw=
: ${bleopt_vim_surround_q:=\"} # ysiwQ
: ${bleopt_vim_surround_Q:=\'} # ysiwq
: ${bleopt_vim_surround_omap_bind=1}

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
    return 1
  fi

  local c=$ret
  if [[ :$mode: == *:digit:* && $c == [0-9] ]]; then
    _ble_edit_arg=$_ble_edit_arg$c
    _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook digit $hook"
    return 148
  elif [[ :$mode: == *:init:* && $c == ' ' ]]; then
    _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook space $hook"
    return 148
  fi

  if [[ $c == [$'\e\003'] ]]; then # C-[, C-c
    ble/widget/vi-command/bell
    return 1
  else
    [[ $c == \' ]] && c="'\''"
    [[ $mode == space ]] && c=' '$c
    eval "$hook '$c'"
  fi
}
function ble/lib/vim-surround.sh/async-inputtarget {
  _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook init:digit $*"
  return 148
}
function ble/lib/vim-surround.sh/async-inputtarget-noarg {
  _ble_decode_key__hook="ble/lib/vim-surround.sh/async-inputtarget.hook init $*"
  return 148
}

_ble_lib_vim_surround_previous_tag=html

## 関数 ble/lib/vim-surround.sh/load-template ins
##   @param[in] ins
##   @var[out] template
function ble/lib/vim-surround.sh/load-template {
  local ins=$1

  # read user settings

  if [[ ${ins//[0-9]} ]]; then
    local optname=bleopt_vim_surround_$ins
    template=${!optname}
    [[ $template ]] && return
  fi

  local ret; ble/util/s2c "$ins"
  local optname=bleopt_vim_surround_$ret
  template=${!optname}
  [[ $template ]] && return

  # default

  case "$ins" in
  (['<tT']*)
    local tag=${ins:1}; tag=${tag//$'\r'/' '}
    if [[ ! $tag ]]; then
      tag=$_ble_lib_vim_surround_previous_tag
    else
      tag=${tag%'>'}
      _ble_lib_vim_surround_previous_tag=$tag
    fi
    local end_tag=${tag%%[$' \t\n']*}
    template="<$tag>"$'\r'"</$end_tag>" ;;
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

## 関数 ble/lib/vim-surround.sh/surround text ins opts
##   @param[in] text
##   @param[in] ins
##   @param[in] opts
##     linewise
##       囲まれた文字列を新しい独立した業にします。
##       cS yS VS VgS などで使用します。
##     indent
##       linewise のとき、新しい行のインデントを追加します。
##
##   @var[in] beg
##   @var[out] ret
function ble/lib/vim-surround.sh/surround {
  local text=$1 ins=$2 opts=$3

  local instype=
  [[ $ins == $'\x1D' ]] && ins='}' instype=indent # C-], C-}

  local has_space=
  [[ $ins == ' '?* ]] && ins=${ins:1} has_space=1

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

  if [[ $instype == indent || :$opts: == *:linewise:* ]]; then
    ble-edit/content/find-logical-bol "$beg"; local bol=$ret
    ble-edit/content/find-non-space "$bol"; local nol=$ret
    local indent=
    if [[ $instype == indent ]] || ((bol<nol)); then
      indent=${_ble_edit_str:bol:nol-bol}
    elif [[ $has_space ]]; then
      indent=' '
    fi
    text=$indent$text
    if [[ $instype == indent || :$opts: == *:indent:* ]]; then
      ble/keymap:vi/string#increase-indent "$text" "$bleopt_indent_offset"; text=$ret
    fi
    text=$'\n'$text$'\n'$indent
    # todo: 初めから text に改行が含まれていた場合は、
    #   更にここで = による自動インデントを実行する?
  elif [[ $has_space ]]; then
    text=' '$text' '
  fi

  ret=$prefix$text$suffix
}

#------------------------------------------------------------------------------
# async-read-tagname

function ble/lib/vim-surround.sh/async-read-tagname {
  ble/keymap:vi/async-commandline-mode "$1"
  _ble_edit_PS1='<'
  _ble_keymap_vi_cmap_before_command=ble/lib/vim-surround.sh/async-read-tagname/.before-command
  return 148
}
function ble/lib/vim-surround.sh/async-read-tagname/.before-command {
  if [[ ${KEYS[0]} == 62 ]]; then # '>'
    ble/widget/self-insert
    ble/widget/vi_cmap/accept
    WIDGET=
  fi
}

#------------------------------------------------------------------------------
# ys yss yS ySS ySs vS vgS

_ble_lib_vim_surround_ys_type= # ys | yS | vS | vgS
_ble_lib_vim_surround_ys_args=()
_ble_lib_vim_surround_ys_ranges=()

function ble/lib/vim-surround.sh/operator.impl {
  _ble_lib_vim_surround_ys_type=$1; shift
  _ble_lib_vim_surround_ys_args=("$@")
  [[ $3 == block ]] && _ble_lib_vim_surround_ys_ranges=("${sub_ranges[@]}")
  ble/lib/vim-surround.sh/async-inputtarget-noarg ble/widget/vim-surround.sh/ysurround.hook1
  ble/lib/vim-surround.sh/ysurround.repeat/entry
  return 148
}
function ble/keymap:vi/operator:yS { ble/lib/vim-surround.sh/operator.impl yS "$@"; }
function ble/keymap:vi/operator:ys { ble/lib/vim-surround.sh/operator.impl ys "$@"; }
function ble/keymap:vi/operator:ySS { ble/lib/vim-surround.sh/operator.impl ySS "$@"; }
function ble/keymap:vi/operator:yss { ble/lib/vim-surround.sh/operator.impl yss "$@"; }
function ble/keymap:vi/operator:vS { ble/lib/vim-surround.sh/operator.impl vS "$@"; }
function ble/keymap:vi/operator:vgS { ble/lib/vim-surround.sh/operator.impl vgS "$@"; }
function ble/widget/vim-surround.sh/ysurround.hook1 {
  local ins=$1
  if local rex='^ ?[<tT]$'; [[ $ins =~ $rex ]]; then
    ble/lib/vim-surround.sh/async-read-tagname "ble/widget/vim-surround.sh/ysurround.hook2 '$ins'"
  else
    ble/widget/vim-surround.sh/ysurround.core "$ins"
  fi
}
function ble/widget/vim-surround.sh/ysurround.hook2 {
  local ins=$1 tagName=$2
  ble/widget/vim-surround.sh/ysurround.core "$ins$tagName"
}
function ble/widget/vim-surround.sh/ysurround.core {
  local ins=$1

  local ret

  # saved arguments
  local type=$_ble_lib_vim_surround_ys_type
  local beg=${_ble_lib_vim_surround_ys_args[0]}
  local end=${_ble_lib_vim_surround_ys_args[1]}
  local context=${_ble_lib_vim_surround_ys_args[2]}
  local sub_ranges; sub_ranges=("${_ble_lib_vim_surround_ys_ranges[@]}")
  _ble_lib_vim_surround_ys_type=
  _ble_lib_vim_surround_ys_args=()
  _ble_lib_vim_surround_ys_ranges=()

  if [[ $context == block ]]; then
    local isub=${#sub_ranges[@]} sub
    local smin= smax= slpad= srpad=
    while ((isub--)); do
      local sub=${sub_ranges[isub]}
      local stext=${sub#*:*:*:*:*:}
      ble/string#split sub : "${sub::${#sub}-${#stext}}"
      smin=${sub[0]} smax=${sub[1]}
      slpad=${sub[2]} srpad=${sub[3]}

      if ! ble/lib/vim-surround.sh/surround "$stext" "$ins"; then
        ble/widget/vi-command/bell
        return 1
      fi
      stext=$ret

      ((slpad)) && { ble/string#repeat ' ' "$slpad"; stext=$ret$stext; }
      ((srpad)) && { ble/string#repeat ' ' "$srpad"; stext=$stext$ret; }
      ble/widget/.replace-range "$smin" "$smax" "$stext" 1
    done

  else
    # text
    local text=${_ble_edit_str:beg:end-beg}
    if local rex=$'[ \t\n]+$'; [[ $text =~ $rex ]]; then
      # 範囲末端の空白は囲む対象としない
      ((end-=${#BASH_REMATCH}))
      text=${_ble_edit_str:beg:end-beg}
    fi

    # surround
    local opts=
    if [[ $type == yS || $type == ySS || $context == char && $type == vgS ]]; then
      opts=linewise:indent
    elif [[ $context == line ]]; then
      opts=linewise
    fi
    if ! ble/lib/vim-surround.sh/surround "$text" "$ins" "$opts"; then
      ble/widget/vi-command/bell
      return 1
    fi
    local text=$ret

    ble/widget/.replace-range "$beg" "$end" "$text" 1
  fi

  ble/widget/.goto-char "$beg"
  if [[ $context == line ]]; then
    ble/widget/vi-command/first-non-space
  else
    ble/keymap:vi/adjust-command-mode
  fi
  ble/keymap:vi/mark/end-edit-area
  ble/lib/vim-surround.sh/ysurround.repeat/record "$type" "$ins"
  return 0
}

function ble/widget/vim-surround.sh/ysurround-current-line {
  ble/widget/vi_nmap/linewise-operator yss
}
function ble/widget/vim-surround.sh/ySurround-current-line {
  ble/widget/vi_nmap/linewise-operator ySS
}
function ble/widget/vim-surround.sh/vsurround { # vS
  ble/widget/vi-command/operator vS
}
function ble/widget/vim-surround.sh/vgsurround { # vgS
  [[ $_ble_decode_key__kmap == vi_xmap ]] &&
    ble/keymap:vi/xmap/add-eol-extension # 末尾拡張
  ble/widget/vi-command/operator vgS
}

# repeat (nmap .) 用の変数・関数
_ble_lib_vim_surround_ys_repeat=()
function ble/lib/vim-surround.sh/ysurround.repeat/entry {
  local -a _ble_keymap_vi_repeat _ble_keymap_vi_repeat_irepeat
  ble/keymap:vi/repeat/record-normal
  _ble_lib_vim_surround_ys_repeat=("${_ble_keymap_vi_repeat[@]}")
}
function ble/lib/vim-surround.sh/ysurround.repeat/record {
  ble/keymap:vi/repeat/record-special && return
  local type=$1 ins=$2
  _ble_keymap_vi_repeat=("${_ble_lib_vim_surround_ys_repeat[@]}")
  _ble_keymap_vi_repeat_irepeat=()
  _ble_keymap_vi_repeat[10]=$type
  _ble_keymap_vi_repeat[11]=$ins
  case $type in
  (vS|vgS)
    _ble_keymap_vi_repeat[2]='ble/widget/vi-command/operator ysurround.repeat'
    _ble_keymap_vi_repeat[4]= ;;
  (yss|ySS)
    _ble_keymap_vi_repeat[2]='ble/widget/vi_nmap/linewise-operator ysurround.repeat'
    _ble_keymap_vi_repeat[4]= ;;
  (*)
    _ble_keymap_vi_repeat[4]=ysurround.repeat
  esac
}
function ble/keymap:vi/operator:ysurround.repeat {
  _ble_lib_vim_surround_ys_type=${_ble_keymap_vi_repeat[10]}
  _ble_lib_vim_surround_ys_args=("$@")
  [[ $3 == block ]] && _ble_lib_vim_surround_ys_ranges=("${sub_ranges[@]}")
  local ins=${_ble_keymap_vi_repeat[11]}
  ble/widget/vim-surround.sh/ysurround.core "$ins"
}

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
##   @var[in] surround_content
##   @var[in] surround_ins
##   @var[in] surround_trim
##   @var[in] surround_type
##     ds cs cS の何れかの値
function ble/keymap:vi/operator:surround.record { :; }
function ble/keymap:vi/operator:surround {
  local beg=$1 end=$2 context=$3
  local content=$surround_content ins=$surround_ins trims=$surround_trim

  local ret
  if [[ $trims ]]; then
    ble/string#trim "$content"; content=$ret
  fi

  local opts=; [[ $surround_type == cS ]] && opts=linewise
  if ! ble/lib/vim-surround.sh/surround "$content" "$ins" "$opts"; then
    ble/widget/vi-command/bell
    return 0
  fi
  content=$ret

  ble/widget/.replace-range "$beg" "$end" "$content"

  # if [[ $has_nl ]]; then
  #   # todo: indent
  # fi

  return 0
}

_ble_lib_vim_surround_cs_type= # ds | cs | cS
_ble_lib_vim_surround_cs_arg=
_ble_lib_vim_surround_cs_reg=
_ble_lib_vim_surround_cs_del=

function ble/widget/vim-surround.sh/nmap/csurround.core {
  local type=$1 arg=$2 reg=$3 del=$4 ins=$5

  local to1= to2=
  local surround_trim= surround_ins=$ins surround_type=$type

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
    ble/keymap:vi/text-object.impl "$arg" y '' "$to1"; local ext=$?
    ble/widget/.goto-char "$ind"
    ((ext!=0)) && return 1

    local surround_content="$_ble_edit_kill_ring"
    ble/keymap:vi/text-object.impl "$arg" surround '' "$to2" || return 1
  elif [[ $del == / ]]; then
    # /* ..  */ で囲まれた部分

    local rex='(/\*([^/]|/[^*])*/?){1,'$arg'}$'
    [[ ${_ble_edit_str::_ble_edit_ind+2} =~ $rex ]] || return 1
    local beg=$((_ble_edit_ind+2-${#BASH_REMATCH}))

    ble/string#index-of "${_ble_edit_str:beg+2}" '*/' || return 1
    local end=$((beg+ret+4))

    local surround_content=${_ble_edit_str:beg+2:end-beg-4}
    ble/keymap:vi/call-operator surround "$beg" "$end" char '' ''
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
    ble/keymap:vi/call-operator surround "$beg" "$end" char '' ''
    ble/widget/.goto-char "$beg"
  else
    ble/widget/vi-command/bell
    return 1
  fi
  ble/widget/vim-surround.sh/nmap/csurround.record "$type" "$arg" "$reg" "$del" "$ins"
  ble/keymap:vi/adjust-command-mode
  return 0
}
function ble/widget/vim-surround.sh/nmap/dsurround.hook {
  local type=$_ble_lib_vim_surround_cs_type
  local arg=$_ble_lib_vim_surround_cs_arg
  local reg=$_ble_lib_vim_surround_cs_reg
  local del=$1
  ble/widget/vim-surround.sh/nmap/csurround.core "$type" "$arg" "$reg" "$del" && return
  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vim-surround.sh/nmap/dsurround {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  _ble_lib_vim_surround_cs_type=ds
  _ble_lib_vim_surround_cs_arg=$ARG
  _ble_lib_vim_surround_cs_reg=$REG
  ble/lib/vim-surround.sh/async-inputtarget ble/widget/vim-surround.sh/nmap/dsurround.hook
}

function ble/widget/vim-surround.sh/nmap/csurround.hook3 {
  local ins=$1 tagName=$2
  local type=$_ble_lib_vim_surround_cs_type
  local arg=$_ble_lib_vim_surround_cs_arg
  local reg=$_ble_lib_vim_surround_cs_reg
  local del=$_ble_lib_vim_surround_cs_del
  ble/widget/vim-surround.sh/nmap/csurround.core "$type" "$arg" "$reg" "$del" "$ins$tagName" && return 0
  ble/widget/vi-command/bell
  return 1
}
function ble/widget/vim-surround.sh/nmap/csurround.hook2 {
  local ins=$1
  if local rex='^ ?[<tT]$'; [[ $ins =~ $rex ]]; then
    ble/lib/vim-surround.sh/async-read-tagname "ble/widget/vim-surround.sh/nmap/csurround.hook3 '$ins'"
  else
    local type=$_ble_lib_vim_surround_cs_type
    local arg=$_ble_lib_vim_surround_cs_arg
    local reg=$_ble_lib_vim_surround_cs_reg
    local del=$_ble_lib_vim_surround_cs_del
    ble/widget/vim-surround.sh/nmap/csurround.core "$type" "$arg" "$reg" "$del" "$ins" && return 0
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vim-surround.sh/nmap/csurround.hook1 {
  local del=$1
  if [[ $del ]]; then
    _ble_lib_vim_surround_cs_del=$1
    ble/lib/vim-surround.sh/async-inputtarget-noarg ble/widget/vim-surround.sh/nmap/csurround.hook2
  else
    _ble_lib_vim_surround_cs_del=
    ble/widget/vi-command/bell
    return 1
  fi
}
function ble/widget/vim-surround.sh/nmap/csurround.impl {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local type=$1
  _ble_lib_vim_surround_cs_type=$type
  _ble_lib_vim_surround_cs_arg=$ARG
  _ble_lib_vim_surround_cs_reg=$REG
  _ble_lib_vim_surround_cs_del=
  ble/lib/vim-surround.sh/async-inputtarget ble/widget/vim-surround.sh/nmap/csurround.hook1
}
function ble/widget/vim-surround.sh/nmap/csurround {
  ble/widget/vim-surround.sh/nmap/csurround.impl cs
}
function ble/widget/vim-surround.sh/nmap/cSurround {
  ble/widget/vim-surround.sh/nmap/csurround.impl cS
}

function ble/widget/vim-surround.sh/nmap/csurround.record {
  local type=$1 arg=$2 reg=$3 del=$4 ins=$5
  local WIDGET=ble/widget/vim-surround.sh/nmap/csurround.repeat ARG=$arg FLAG= REG=$reg
  ble/keymap:vi/repeat/record
  _ble_keymap_vi_repeat[10]=$type
  _ble_keymap_vi_repeat[11]=$del
  _ble_keymap_vi_repeat[12]=$ins
}
function ble/widget/vim-surround.sh/nmap/csurround.repeat {
  local ARG FLAG REG; ble/keymap:vi/get-arg 1
  local type=${_ble_keymap_vi_repeat[10]}
  local del=${_ble_keymap_vi_repeat[11]}
  local ins=${_ble_keymap_vi_repeat[12]}
  ble/widget/vim-surround.sh/nmap/csurround.core "$type" "$ARG" "$REG" "$del" "$ins" && return 0
  ble/widget/vi-command/bell
  return 1
}

#------------------------------------------------------------------------------

function ble/widget/vim-surround.sh/omap {
  local ret
  if ! ble/keymap:vi/k2c "${KEYS[0]}"; then
    ble/widget/.bell
    return 1
  fi
  ble/util/c2s "$ret"; local s=$ret

  local opfunc=$_ble_keymap_vi_opfunc$s
  case "$opfunc" in
  (y[sS])
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    _ble_edit_arg=$ARG
    _ble_keymap_vi_reg=$REG
    ble-decode/keymap/pop
    ble/widget/vi-command/operator "$opfunc" ;;
  (yss)
    ble/widget/vim-surround.sh/ysurround-current-line ;;
  (yS[sS])
    ble/widget/vim-surround.sh/ySurround-current-line ;;
  (ds) ble/widget/vim-surround.sh/nmap/dsurround ;;
  (cs) ble/widget/vim-surround.sh/nmap/csurround ;;
  (cS) ble/widget/vim-surround.sh/nmap/cSurround ;;
  (*) ble/widget/.bell ;;
  esac
}

ble-bind -m vi_xmap -f 'S'   vim-surround.sh/vsurround
ble-bind -m vi_xmap -f 'g S' vim-surround.sh/vgsurround

if [[ $bleopt_vim_surround_omap_bind ]]; then
  ble-bind -m vi_omap -f s 'vim-surround.sh/omap'
  ble-bind -m vi_omap -f S 'vim-surround.sh/omap'
else
  ble-bind -m vi_nmap -f 'y s'   'vi-command/operator ys'
  ble-bind -m vi_nmap -f 'y s s' 'vim-surround.sh/ysurround-current-line'
  ble-bind -m vi_nmap -f 'y S'   'vi-command/operator yS'
  ble-bind -m vi_nmap -f 'y S s' 'vim-surround.sh/ySurround-current-line'
  ble-bind -m vi_nmap -f 'y S S' 'vim-surround.sh/ySurround-current-line'
  ble-bind -m vi_nmap -f 'd s' 'vim-surround.sh/nmap/dsurround'
  ble-bind -m vi_nmap -f 'c s' 'vim-surround.sh/nmap/csurround'
  ble-bind -m vi_nmap -f 'c S' 'vim-surround.sh/nmap/cSurround'
fi
