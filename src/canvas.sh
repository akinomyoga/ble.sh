#!/bin/bash

## @bleopt tab_width
##   タブの表示幅を指定します。
##
##   bleopt_tab_width= (既定)
##     空文字列を指定したときは $(tput it) を用います。
##   bleopt_tab_width=NUM
##     数字を指定したときはその値をタブの幅として用います。
bleopt/declare -v tab_width ''
function bleopt/check:tab_width {
  if [[ $value ]] && (((value=value)<=0)); then
    ble/util/print "bleopt: an empty string or a positive value is required for tab_width." >&2
    return 1
  fi
}

#------------------------------------------------------------------------------
# ble/arithmetic

## ble/arithmetic/sum integer...
##   @var[out] ret
function ble/arithmetic/sum {
  IFS=+ builtin eval 'let "ret=$*+0"'
}

#------------------------------------------------------------------------------
# ble/util/c2w

# ※注意 [ -~] の範囲の文字は全て幅1であるという事を仮定したコードが幾らかある
#   もしこれらの範囲の文字を幅1以外で表示する端末が有ればそれらのコードを実装し
#   直す必要がある。その様な変な端末があるとは思えないが。

## @bleopt char_width_mode
##   文字の表示幅の計算方法を指定します。
##     bleopt_char_width_mode=east
##       Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 2 とします
##     bleopt_char_width_mode=west
##       Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 1 とします
##     bleopt_char_width_mode=auto
##       east または west を自動判定します。
##     bleopt_char_width_mode=emacs
##       emacs で用いられている既定の文字幅の設定です
##     定義 ble/util/c2w+$bleopt_char_width_mode
bleopt/declare -n char_width_mode auto
function bleopt/check:char_width_mode {
  if ! ble/is-function "ble/util/c2w+$value"; then
    ble/util/print "bleopt: Invalid value char_width_mode='$value'. A function 'ble/util/c2w+$value' is not defined." >&2
    return 1
  fi

  if [[ $_ble_attached && $value == auto ]]; then
    ble/util/c2w+auto/update.buff first-line
    ble/util/buffer.flush >&2
  fi
}

_ble_util_c2w=()

## @fn ble/util/c2w ccode
##   @var[out] ret
function ble/util/c2w {
  ret=${_ble_util_c2w[$1]}
  [[ $ret ]] || "ble/util/c2w+$bleopt_char_width_mode" "$1"
}
## @fn ble/util/c2w-edit ccode
##   編集画面での表示上の文字幅を返します。
##   @var[out] ret
function ble/util/c2w-edit {
  local cs=${_ble_unicode_GraphemeCluster_ControlRepresentation[$1]}
  if [[ $cs ]]; then
    ret=${#cs}
  elif (($1<32||127<=$1&&$1<160)); then
    # 制御文字は ^? と表示される。
    ret=2
    # TAB は???

    # 128-159: M-^?
    ((128<=$1&&(ret=4)))
  else
    ble/util/c2w "$1"
  fi
}
## @fn ble/util/s2w      text
## @fn ble/util/s2w-edit text [opts]
##   @param[in] text
##   @var[out] ret
function ble/util/s2w-edit {
  local text=$1 iN=${#1} flags=$2 i
  ret=0
  for ((i=0;i<iN;i++)); do
    local c w cs cb extend
    ble/unicode/GraphemeCluster/match "$text" "$i" "$flags"
    ((ret+=w,i+=extend))
  done
}
function ble/util/s2w {
  ble/util/s2w-edit "$1" R
}

# ---- 文字種判定 ----

## @arr _ble_util_c2w_zenkaku_except
_ble_util_c2w_zenkaku_min=11904 # 0x2E80
_ble_util_c2w_zenkaku_max=42192 # 0xA4D0
_ble_util_c2w_zenkaku_except=(
  # 0x2E80..0xA4D0 の範囲内で飛び地になっている全角とは限らない文字
  [0x303F]=1 # 半角スペース
)
## @fn ble/util/c2w/.determine-unambiguous
##   @var[out] ret
function ble/util/c2w/.determine-unambiguous {
  local code=$1
  if ((code<0xA0)); then
    ret=1
    return 0
  fi

  # 取り敢えず曖昧
  ret=-1

  # 以下は全角に確定している範囲
  if ((code<0xFB00)); then
    ((_ble_util_c2w_zenkaku_min<=code&&code<_ble_util_c2w_zenkaku_max&&!_ble_util_c2w_zenkaku_except[code]||
      0xAC00<=code&&code<0xD7A4||
      0xF900<=code||
      0x1100<=code&&code<0x1160||
      code==0x2329||code==0x232A)) && ret=2
  elif ((code<0x10000)); then
    ((0xFF00<=code&&code<0xFF61||
      0xFE30<=code&&code<0xFE70||
      0xFFE0<=code&&code<0xFFE7)) && ret=2
  else
    ((0x20000<=code&&code<0x2FFFE||
      0x30000<=code&&code<0x3FFFE)) && ret=2
  fi
}

## @var _ble_unicode_EmojiStatus_xmaybe
## @arr _ble_unicode_EmojiStatus_ranges
## @arr _ble_unicode_EmojiStatus_????
## @arr _ble_unicode_EmojiStatus_????_ranges
## @bleopt emoji_version
##
##   ファイル src/canvas.emoji.sh は以下のコマンドで生成する。
##   $ ./make_command.sh update-emoji-database
##
## Note: canvas.emoji.sh は _ble_util_c2w_zenkaku_except を修正するので、
## _ble_util_c2w_zenkaku_except の初期化よりも後に include する。
##
#%< canvas.emoji.sh

bleopt/declare -v emoji_width 2
bleopt/declare -v emoji_opts ri:tpvs:epvs

function bleopt/check:emoji_version {
  local rex='^0*([0-9]+)\.0*([0-9]+)$'
  if ! [[ $value =~ $rex ]]; then
    ble/util/print "bleopt: Invalid value for emoji_version: '$value'." >&2
    return 1
  fi

  local src
  ble/util/sprintf src _ble_unicode_EmojiStatus_%04d $((BASH_REMATCH[1]*100+BASH_REMATCH[2]))
  if ! ble/is-array "$src"; then
    ble/util/print "bleopt: Unsupported emoji_version '$value'." >&2
    return 1
  fi

  ble/idict#copy _ble_unicode_EmojiStatus "$src"
  builtin eval -- "_ble_unicode_EmojiStatus_ranges=(\"\${${src}_ranges[@]}\")"
  return 0
}

_ble_unicode_EmojiStatus_xIsEmoji='ret&&ret!=_ble_unicode_EmojiStatus_Unqualified'
function bleopt/check:emoji_opts {
  _ble_unicode_EmojiStatus_xIsEmoji='ret'
  [[ :$value: != *:unqualified:* ]] &&
    _ble_unicode_EmojiStatus_xIsEmoji=$_ble_unicode_EmojiStatus_xIsEmoji'&&ret!=_ble_unicode_EmojiStatus_Unqualified'
  local rex=':min=U\+([0-9a-fA-F]+):'
  [[ :$value: =~ $rex ]] &&
    _ble_unicode_EmojiStatus_xIsEmoji=$_ble_unicode_EmojiStatus_xIsEmoji'&&code>=0x'${BASH_REMATCH[1]}
  return 0
}

function ble/unicode/EmojiStatus {
  local code=$1
  ret=${_ble_unicode_EmojiStatus[code]}
  [[ $ret ]] && return 0
  ret=$_ble_unicode_EmojiStatus_None
  if ((_ble_unicode_EmojiStatus_xmaybe)); then
    local l=0 u=${#_ble_unicode_EmojiStatus_ranges[@]} m
    while ((l+1<u)); do
      ((_ble_unicode_EmojiStatus_ranges[m=(l+u)/2]<=code?(l=m):(u=m)))
    done
    ret=${_ble_unicode_EmojiStatus[_ble_unicode_EmojiStatus_ranges[l]]:-0}
  fi

  _ble_unicode_EmojiStatus[code]=$ret
  return 0
}

## @fn ble/util/c2w/is-emoji code
##   @param[in] code
function ble/util/c2w/is-emoji {
  local code=$1 ret
  ble/unicode/EmojiStatus "$code"
  ((_ble_unicode_EmojiStatus_xIsEmoji))
}

# ---- char_width_mode ----

## @fn ble/util/c2w+emacs
##   emacs-24.2.1 default char-width-table
##   @var[out] ret
_ble_util_c2w_emacs_wranges=(
 162 164 167 169 172 173 176 178 180 181 182 183 215 216 247 248 272 273 276 279
 280 282 284 286 288 290 293 295 304 305 306 308 315 316 515 516 534 535 545 546
 555 556 608 618 656 660 722 723 724 725 768 769 770 772 775 777 779 780 785 787
 794 795 797 801 805 806 807 813 814 815 820 822 829 830 850 851 864 866 870 872
 874 876 898 900 902 904 933 934 959 960 1042 1043 1065 1067 1376 1396 1536 1540 1548 1549
 1551 1553 1555 1557 1559 1561 1563 1566 1568 1569 1571 1574 1576 1577 1579 1581 1583 1585 1587 1589
 1591 1593 1595 1597 1599 1600 1602 1603 1611 1612 1696 1698 1714 1716 1724 1726 1734 1736 1739 1740
 1742 1744 1775 1776 1797 1799 1856 1857 1858 1859 1898 1899 1901 1902 1903 1904)
function ble/util/c2w+emacs {
  local code=$1 al=0 ah=0 tIndex=

  # bash-4.0 bug workaround
  #   中で使用している変数に日本語などの文字列が入っているとエラーになる。
  #   その値を参照していなくても、その分岐に入らなくても関係ない。
  #   なので ret に予め適当な値を設定しておく事にする。
  ret=1
  ((code<0xA0)) && return 0

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
    return 0
  fi

  ((
    0x3100<=code&&code<0xA4D0||0xAC00<=code&&code<0xD7A4?(
      ret=2
    ):(0x2000<=code&&code<0x2700?(
      tIndex=0x0100+code-0x2000
    ):(
      al=code&0xFF,
      ah=code/256,
      ah==0x00?(
        tIndex=al
      ):(ah==0x03?(
        ret=0xFF&((al-0x91)&~0x20),
        ret=ret<25&&ret!=17?2:1
      ):(ah==0x04?(
        ret=al==1||0x10<=al&&al<=0x50||al==0x51?2:1
      ):(ah==0x11?(
        ret=al<0x60?2:1
      ):(ah==0x2e?(
        ret=al>=0x80?2:1
      ):(ah==0x2f?(
        ret=2
      ):(ah==0x30?(
        ret=al!=0x3f?2:1
      ):(ah==0xf9||ah==0xfa?(
        ret=2
      ):(ah==0xfe?(
        ret=0x30<=al&&al<0x70?2:1
      ):(ah==0xff?(
        ret=0x01<=al&&al<0x61||0xE0<=al&&al<=0xE7?2:1
      ):(ret=1))))))))))
    ))
  ))

  [[ $tIndex ]] || return 0

  if ((tIndex<_ble_util_c2w_emacs_wranges[0])); then
    ret=1
    return 0
  fi

  local l=0 u=${#_ble_util_c2w_emacs_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_emacs_wranges[m=(l+u)/2]<=tIndex?(l=m):(u=m)))
  done
  ((ret=((l&1)==0)?2:1))
  return 0
}

## @fn ble/util/c2w+west
##   @var[out] ret
function ble/util/c2w+west {
  ble/util/c2w/.determine-unambiguous "$1"
  if ((ret<0)); then
    if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
      ((ret=bleopt_emoji_width))
    elif ((_ble_util_c2w_zenkaku_except[$1]==-2)); then
      ret=2 # (絵文字の可能性があったため曖昧だった) 全角
    else
      ret=1
    fi
  fi
}

## @fn ble/util/c2w+east
##   @var[out] ret
_ble_util_c2w_east_wranges=(
 161 162 164 165 167 169 170 171 174 175 176 181 182 187 188 192 198 199 208 209
 215 217 222 226 230 231 232 235 236 238 240 241 242 244 247 251 252 253 254 255
 257 258 273 274 275 276 283 284 294 296 299 300 305 308 312 313 319 323 324 325
 328 332 333 334 338 340 358 360 363 364 462 463 464 465 466 467 468 469 470 471
 472 473 474 475 476 477 593 594 609 610 708 709 711 712 713 716 717 718 720 721
 728 732 733 734 735 736 913 930 931 938 945 962 963 970 1025 1026 1040 1104 1105 1106
 8208 8209 8211 8215 8216 8218 8220 8222 8224 8227 8228 8232 8240 8241 8242 8244 8245 8246 8251 8252
 8254 8255 8308 8309 8319 8320 8321 8325 8364 8365 8451 8452 8453 8454 8457 8458 8467 8468 8470 8471
 8481 8483 8486 8487 8491 8492 8531 8533 8539 8543 8544 8556 8560 8570 8592 8602 8632 8634 8658 8659
 8660 8661 8679 8680 8704 8705 8706 8708 8711 8713 8715 8716 8719 8720 8721 8722 8725 8726 8730 8731
 8733 8737 8739 8740 8741 8742 8743 8749 8750 8751 8756 8760 8764 8766 8776 8777 8780 8781 8786 8787
 8800 8802 8804 8808 8810 8812 8814 8816 8834 8836 8838 8840 8853 8854 8857 8858 8869 8870 8895 8896
 8978 8979 9312 9450 9451 9548 9552 9588 9600 9616 9618 9622 9632 9634 9635 9642 9650 9652 9654 9656
 9660 9662 9664 9666 9670 9673 9675 9676 9678 9682 9698 9702 9711 9712 9733 9735 9737 9738 9742 9744
 9748 9750 9756 9757 9758 9759 9792 9793 9794 9795 9824 9826 9827 9830 9831 9835 9836 9838 9839 9840
 10045 10046 10102 10112 57344 63744 65533 65534 983040 1048574 1048576 1114110)
function ble/util/c2w+east {
  ble/util/c2w/.determine-unambiguous "$1"
  ((ret>=0)) && return 0

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
    return 0
  elif ((_ble_util_c2w_zenkaku_except[$1]==-2)); then
    ret=2 # (絵文字の可能性があったため曖昧だった) 全角
    return 0
  fi

  local code=$1
  if ((code<_ble_util_c2w_east_wranges[0])); then
    ret=1
    return 0
  fi

  local l=0 u=${#_ble_util_c2w_east_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_east_wranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done
  ((ret=((l&1)==0)?2:1))
  return 0
}

_ble_util_c2w_auto_width=1
_ble_util_c2w_auto_update_x0=0
function ble/util/c2w+auto {
  ble/util/c2w/.determine-unambiguous "$1"
  ((ret>=0)) && return 0

  if ((_ble_util_c2w_auto_width==1)); then
    ble/util/c2w+west "$1"
  else
    ble/util/c2w+east "$1"
    ((ret==2&&(ret=_ble_util_c2w_auto_width)))
  fi
}
function ble/util/c2w+auto/update.buff {
  local opts=$1
  local -a DRAW_BUFF=()
  local ret
  [[ $_ble_attached ]] && ble/canvas/panel/save-position goto-top-dock
  ble/canvas/put.draw "$_ble_term_sc"
  if ble/util/is-unicode-output; then
    local achar='▽'
    if [[ :$opts: == *:first-line:* ]]; then
      # 画面の右上で判定を行います。
      local cols=${COLUMNS:-80}
      local x0=$((cols-4)); ((x0<0)) && x0=0
      _ble_util_c2w_auto_update_x0=$x0

      ble/canvas/put-cup.draw 1 $((x0+1))
      ble/canvas/put.draw "$achar"
      ble/term/CPR/request.draw ble/util/c2w+auto/update.hook
      ble/canvas/put-cup.draw 1 $((x0+1))
      ble/canvas/put.draw "$_ble_term_el"
    else
      _ble_util_c2w_auto_update_x0=0
      ble/canvas/put.draw "$_ble_term_cr$achar"
      ble/term/CPR/request.draw ble/util/c2w+auto/update.hook
    fi
  fi
  ble/canvas/put.draw "$_ble_term_rc"
  [[ $_ble_attached ]] && ble/canvas/panel/load-position.draw "$ret"
  ble/canvas/bflush.draw
}
function ble/util/c2w+auto/update.hook {
  local l=$1 c=$2
  local w=$((c-1-_ble_util_c2w_auto_update_x0))
  ((_ble_util_c2w_auto_width=w==1?1:2))
}

bleopt/declare -v grapheme_cluster extended
function bleopt/check:grapheme_cluster {
  case $value in
  (extended|legacy|'') return 0 ;;
  (*)
    ble/util/print "bleopt: invalid value for grapheme_cluster: '$value'." >&2
    return 1 ;;
  esac
}

#%< canvas.GraphemeClusterBreak.sh

function ble/unicode/GraphemeCluster/c2break {
  local code=$1
  ret=${_ble_unicode_GraphemeClusterBreak[code]}
  [[ $ret ]] && return 0
  ((ret>_ble_unicode_GraphemeClusterBreak_MaxCode)) && { ret=0; return 0; }

  local l=0 u=${#_ble_unicode_GraphemeClusterBreak_ranges[@]} m
  while ((l+1<u)); do
    ((_ble_unicode_GraphemeClusterBreak_ranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done

  ret=${_ble_unicode_GraphemeClusterBreak[_ble_unicode_GraphemeClusterBreak_ranges[l]]:-0}
  _ble_unicode_GraphemeClusterBreak[code]=$ret
  return 0
}

## @fn ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ
##   @var[in] text i
##   @var[out] ret
function ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ {
  if [[ :$bleopt_emoji_opts: != *:zwj:* ]]; then
    ((ret=i))
    return 0
  fi

  local j=$((i-1))
  for ((j=i-1;j>0;j--)); do
    ble/util/s2c "${text:j-1:1}"
    ble/unicode/GraphemeCluster/c2break "$ret"
    ((ret==_ble_unicode_GraphemeClusterBreak_Extend)) || break
  done

  if ((j==0||ret!=_ble_unicode_GraphemeClusterBreak_Pictographic)); then
    #             sot | Extend* ZWJ | Pictographic
    # [^Pictographic] | Extend* ZWJ | Pictographic
    #                 ^--- j        ^--- i
    ((ret=i))
    return 0
  else
    #    Pictographic | Extend* ZWJ | Pictographic
    #                 ^--- j        ^--- i
    ((i=j-1,b1=ret))
    return 1
  fi
}
## @fn ble/unicode/GraphemeCluster/find-previous-boundary/.RI
##   @var[in] text i
##   @var[out] ret
function ble/unicode/GraphemeCluster/find-previous-boundary/.RI {
  if [[ :$bleopt_emoji_opts: != *:ri:* ]]; then
    ((ret=i))
    return 0
  fi

  local j=$((i-1))
  for ((j=i-1;j>0;j--)); do
    ble/util/s2c "${text:j-1:1}"
    ble/unicode/GraphemeCluster/c2break "$ret"
    ((ret==_ble_unicode_GraphemeClusterBreak_Regional_Indicator)) || break
  done

  if ((i-j==1)); then
    ((i=j,b1=_ble_unicode_GraphemeClusterBreak_Regional_Indicator))
    return 1
  else
    ((ret=(i-j)%2==1?i-1:i))
    return 0
  fi
}
function ble/unicode/GraphemeCluster/find-previous-boundary {
  local text=$1 i=$2
  if [[ $bleopt_grapheme_cluster ]] && ((i&&--i)); then
    ble/util/s2c "${text:i:1}"
    ble/unicode/GraphemeCluster/c2break "$ret"; local b1=$ret
    while ((i>0)); do
      local b2=$b1
      ble/util/s2c "${text:i-1:1}"
      ble/unicode/GraphemeCluster/c2break "$ret"; local b1=$ret
      case ${_ble_unicode_GraphemeClusterBreak_rule[b1*_ble_unicode_GraphemeClusterBreak_Count+b2]} in
      (0) break ;;
      (1) ((i--)) ;;
      (2) [[ $bleopt_grapheme_cluster != extended ]] && break; ((i--)) ;;
      (3) ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ && return 0 ;;
      (4) ble/unicode/GraphemeCluster/find-previous-boundary/.RI && return 0 ;;
      esac
    done
  fi
  ret=$i
  return 0
}

_ble_unicode_GraphemeClusterBreak_isCore=()
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_Other]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_Control]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_Regional_Indicator]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_L]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_V]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_T]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_LV]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_LVT]=1
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_Pictographic]=1

## @fn ble/unicode/GraphemeCluster/extend-ascii text i
##   @var[out] extend
function ble/unicode/GraphemeCluster/extend-ascii {
  extend=0
  [[ $_ble_util_locale_encoding != UTF-8 || ! $bleopt_grapheme_cluster ]] && return 1
  local text=$1 iN=${#1} i=$2 ret
  for ((;i<iN;i++,extend++)); do
    ble/util/s2c "${text:i:1}"
    ble/unicode/GraphemeCluster/c2break "$ret"
    case $ret in
    ("$_ble_unicode_GraphemeClusterBreak_Extend"|"$_ble_unicode_GraphemeClusterBreak_ZWJ") ;;
    ("$_ble_unicode_GraphemeClusterBreak_SpacingMark")
      [[ $bleopt_grapheme_cluster == extended ]] || break ;;
    (*) break ;;
    esac
  done
  ((extend))
}

_ble_unicode_GraphemeCluster_ControlRepresentation=()
function ble/unicode/GraphemeCluster/.get-ascii-rep {
  local c=$1
  cs=${_ble_unicode_GraphemeCluster_ControlRepresentation[c]}
  if [[ ! $cs ]]; then
    if ((c<32)); then
      ble/util/c2s $((c+64))
      cs=^$ret
    elif ((c==127)); then
      cs=^?
    elif ((128<=c&&c<160)); then
      ble/util/c2s $((c-64))
      cs=M-^$ret
    else
      ble/util/sprintf cs 'U+%X' "$c"
    fi
    _ble_unicode_GraphemeCluster_ControlRepresentation[c]=$cs
  fi
}

## @fn ble/unicode/GraphemeCluster/match text i flags
##   @param[in] text i
##   @param[in] flags
##     R が含まれている時制御文字を (ASCII 表現ではなく) そのまま cs に格納しま
##     す。幅は 0 で換算されます。
##   @var[out] c w cs cb extend
function ble/unicode/GraphemeCluster/match {
  local text=$1 iN=${#1} i=$2 j=$2 flags=$3 ret
  if ((i>=iN)); then
    c=0 w=0 cs= cb= extend=0
    return 1
  elif [[ $_ble_util_locale_encoding != UTF-8 || ! $bleopt_grapheme_cluster ]]; then
    cs=${text:i:1}
    ble/util/s2c "$cs"; c=$ret
    if [[ $flags != *R* ]] && {
         ble/unicode/GraphemeCluster/c2break "$c"
         ((ret==_ble_unicode_GraphemeClusterBreak_Control)); };  then
      ble/unicode/GraphemeCluster/.get-ascii-rep "$c"
      w=${#cs}
    else
      ble/util/c2w "$c"; w=$ret
    fi
    extend=0
    return 0
  fi

  local b0 b1 b2 c0 c2
  ble/util/s2c "${text:i:1}"; c0=$ret
  ble/unicode/GraphemeCluster/c2break "$c0"; b0=$ret

  local coreb= corec= npre=0 vs= ri=
  c2=$c0 b2=$b0
  while ((j<iN)); do
    if ((_ble_unicode_GraphemeClusterBreak_isCore[b2])); then
      [[ $coreb ]] || coreb=$b2 corec=$c2
    elif ((b2==_ble_unicode_GraphemeClusterBreak_Prepend)); then
      ((npre++))
    elif ((c2==0xFE0E)); then # Variation selector TPVS
      vs=tpvs
    elif ((c2==0xFE0F)); then # Variation selector EPVS
      vs=epvs
    fi

    ((j++))
    b1=$b2
    ble/util/s2c "${text:j:1}"; c2=$ret
    ble/unicode/GraphemeCluster/c2break "$c2"; b2=$ret
    case ${_ble_unicode_GraphemeClusterBreak_rule[b1*_ble_unicode_GraphemeClusterBreak_Count+b2]} in
    (0) break ;;
    (1) continue ;;
    (2) [[ $bleopt_grapheme_cluster != extended ]] && break ;;
    (3) [[ :$bleopt_emoji_opts: == *:zwj:* ]] &&
          ((coreb==_ble_unicode_GraphemeClusterBreak_Pictographic)) || break ;;
    (4) [[ :$bleopt_emoji_opts: == *:ri:* && ! $ri ]] || break; ri=1 ;;
    esac
  done

  c=$corec cb=$coreb cs=${text:i:j-i}
  ((extend=j-i-1))
  if [[ ! $corec ]]; then
    if [[ $flags != *R* ]]; then
      ((c=c0,cb=0,corec=0x25CC)) # 基底が存在しない時は点線円
      ble/util/c2s "$corec"
      cs=${text:i:npre}$ret${text:i+npre:j-i-npre}
    else
      ble/util/s2c "$cs"; c=$ret corec=$ret
      ble/unicode/GraphemeCluster/c2break "$c"; cb=$ret
    fi
  fi

  if ((cb==_ble_unicode_GraphemeClusterBreak_Control)); then
    if [[ $flags != *R* ]]; then
      ble/unicode/GraphemeCluster/.get-ascii-rep "$c"
      w=${#cs}
    else
      # ToDo: 全ての制御文字が幅0とは限らない。というより色々処理が必要。
      w=0
    fi

  else
    # 幅の計算 (Variation Selector を考慮に入れる)
    if [[ $vs == tpvs && :$bleopt_emoji_opts: == *:tpvs:* ]]; then
      bleopt_emoji_width= ble/util/c2w "$corec"; w=$ret
    elif [[ $vs == epvs && :$bleopt_emoji_opts: == *:epvs:* ]]; then
      w=${bleopt_emoji_width:-2}
    else
      ble/util/c2w "$corec"; w=$ret
    fi
  fi

  return 0
}

#------------------------------------------------------------------------------
# ble/canvas/attach

function ble/canvas/attach {
  [[ $bleopt_char_width_mode == auto ]] &&
    ble/util/c2w+auto/update.buff
}

#------------------------------------------------------------------------------
# ble/canvas

function ble/canvas/put.draw {
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$1
}
function ble/canvas/put-ind.draw {
  local count=${1-1} ind=$_ble_term_ind
  [[ :$2: == *:true-ind:* ]] && ind=$'\eD'
  local ret; ble/string#repeat "$ind" "$count"
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret
}
function ble/canvas/put-ri.draw {
  local count=${1-1}
  local ret; ble/string#repeat "$_ble_term_ri" "$count"
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret
}
## @fn ble/canvas/put-il.draw [nline] [opts]
## @fn ble/canvas/put-dl.draw [nline] [opts]
##   @param[in,opt] nline
##     消去・挿入する行数を指定します。
##     省略した場合は 1 と解釈されます。
##   @param[in,opt] opts
##     panel
##     vfill
##     no-lastline
##       Cygwin console 最終行バグ判定用の情報です。
function ble/canvas/put-il.draw {
  local value=${1-1}
  ((value>0)) || return 0
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_il//'%d'/$value}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
}
function ble/canvas/put-dl.draw {
  local value=${1-1}
  ((value>0)) || return 0
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
}
# Cygwin console (pcon) では最終行で IL/DL すると画面全体がクリアされるバグの対策 (#D1482)
if ((_ble_bash>=40000)) && [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $TERM == xterm-256color ]]; then
  function ble/canvas/.is-il-workaround-required {
    local value=$1 opts=$2

    # Cygwin console 以外の端末ではそもそも対策不要。
    [[ ! $_ble_term_DA2R ]] || return 1

    # 複数行挿入・削除する場合は現在位置は最終行ではない筈。
    ((value==1)) || return 1

    # 対策不要と明示されている場合は対策不要。
    [[ :$opts: == *:vfill:* || :$opts: == *:no-lastline:* ]] && return 1

    # ble/canvas/panel 内部で移動中の時は opts=panel が指定される。
    # panel 集合の最終行にいない場合は対策不要。
    [[ :$opts: == *:panel:* ]] &&
      ! ble/canvas/panel/is-last-line &&
      return 1

    return 0
  }

  function ble/canvas/put-il.draw {
    local value=${1-1} opts=$2
    ((value>0)) || return 0
    if ble/canvas/.is-il-workaround-required "$value" "$2"; then
      if [[ :$opts: == *:panel:* ]]; then
        DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2
      else
        DRAW_BUFF[${#DRAW_BUFF[*]}]=$'\e[S\e[A\e[L\e[B\e[T'
      fi
    else
      DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_il//'%d'/$value}
      DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
    fi
  }
  function ble/canvas/put-dl.draw {
    local value=${1-1} opts=$2
    ((value>0)) || return 0
    if ble/canvas/.is-il-workaround-required "$value" "$2"; then
      if [[ :$opts: == *:panel:* ]]; then
        DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2
      else
        DRAW_BUFF[${#DRAW_BUFF[*]}]=$'\e[S\e[A\e[M\e[B\e[T'
      fi
    else
      DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
      DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
    fi
  }
fi
function ble/canvas/put-cuu.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cuu//'%d'/$value}
}
function ble/canvas/put-cud.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cud//'%d'/$value}
}
function ble/canvas/put-cuf.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cuf//'%d'/$value}
}
function ble/canvas/put-cub.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cub//'%d'/$value}
}
function ble/canvas/put-cup.draw {
  local l=${1-1} c=${2-1}
  local out=$_ble_term_cup
  out=${out//'%l'/$l}
  out=${out//'%c'/$c}
  out=${out//'%y'/$((l-1))}
  out=${out//'%x'/$((c-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble/canvas/put-hpa.draw {
  local c=${1-1}
  local out=$_ble_term_hpa
  out=${out//'%c'/$c}
  out=${out//'%x'/$((c-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble/canvas/put-vpa.draw {
  local l=${1-1}
  local out=$_ble_term_vpa
  out=${out//'%l'/$l}
  out=${out//'%y'/$((l-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble/canvas/put-ech.draw {
  local value=${1:-1} esc
  if [[ $_ble_term_ech ]]; then
    esc=${_ble_term_ech/'%d'/$value}
  else
    ble/string#reserve-prototype "$value"
    esc=${_ble_string_prototype::value}${_ble_term_cub/'%d'/$value}
  fi
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$esc
}
function ble/canvas/put-spaces.draw {
  local value=${1:-1}
  ble/string#reserve-prototype "$value"
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_string_prototype::value}
}
function ble/canvas/put-move-x.draw {
  local dx=$1
  ((dx)) || return 1
  if ((dx>0)); then
    ble/canvas/put-cuf.draw "$dx"
  else
    ble/canvas/put-cub.draw $((-dx))
  fi
}
function ble/canvas/put-move-y.draw {
  local dy=$1
  ((dy)) || return 1
  if ((dy>0)); then
    if [[ $MC_SID == $$ ]]; then
      # Note #D1392: mc (midnight commander) の中だと layout が破壊されるので、
      #   必ずしも CUD で想定した行だけ移動できると限らない。
      ble/canvas/put-ind.draw "$dy" true-ind
    else
      ble/canvas/put-cud.draw "$dy"
    fi
  else
    ble/canvas/put-cuu.draw $((-dy))
  fi
}
function ble/canvas/put-move.draw {
  ble/canvas/put-move-x.draw "$1"
  ble/canvas/put-move-y.draw "$2"
}
function ble/canvas/flush.draw {
  IFS= builtin eval 'ble/util/put "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}
## @fn ble/canvas/sflush.draw [-v var]
##   @param[in] var
##     出力先の変数名を指定します。
##   @var[out] !var
function ble/canvas/sflush.draw {
  local _var=ret
  [[ $1 == -v ]] && _var=$2
  IFS= builtin eval "$_var=\"\${DRAW_BUFF[*]}\""
  DRAW_BUFF=()
}
function ble/canvas/bflush.draw {
  IFS= builtin eval 'ble/util/buffer "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}

## @fn ble/canvas/put-clear-lines.draw [old] [new] [opts]
##   @param[in,opt] old new
##     消去前と消去後の行数を指定します。
##     old を省略した場合は 1 が使われます。
##     new を省略した場合は old が使われます。
##   @param[in,opt] opts
##     panel
##     vfill
##     no-lastline
function ble/canvas/put-clear-lines.draw {
  local old=${1:-1}
  local new=${2:-$old}
  if ((old==1&&new==1)); then
    ble/canvas/put.draw "$_ble_term_el2"
  else
    ble/canvas/put-dl.draw "$old" "$3"
    ble/canvas/put-il.draw "$new" "$3"
  fi
}

#------------------------------------------------------------------------------
# ble/canvas/trace.draw
# ble/canvas/trace

## @fn ble/canvas/trace.draw text [opts]
## @fn ble/canvas/trace text [opts]
##   制御シーケンスを含む文字列を出力すると共にカーソル位置の移動を計算します。
##
##   @param[in]   text
##     出力する (制御シーケンスを含む) 文字列を指定します。
##
##   @param[in,opt] opts
##     コロン区切りのオプションの列を指定します。
##
##     [配置制御]
##
##     truncate
##       LINES COLUMNS で指定される範囲外に出た時、処理を中断します。
##
##     confine
##       LINES COLUMNS の範囲外に文字出力・移動を行いません。
##       制御シーケンスにより範囲内に戻る可能性もあります。
##
##     ellipsis
##       LINES COLUMNS の範囲外に文字を出力しようとした時に、
##       三点リーダを末尾に上書きします。
##
##     clip=X1xY1,X2xY2
##     clip=XxY+WxH
##       @param[in] X1 Y1 X2 Y2
##       @param[in] X Y W H
##       指定した矩形範囲内の描画内容だけを抽出します。
##       矩形の左上の点が出力の描画開始点であると想定します。
##
##     justify
##     justify=SEPSPEC
##       横揃えを設定します。
##
##     [範囲計測]
##
##     measure-bbox
##       @var[out] x1 x2 y1 y2
##       カーソル移動範囲を x1 x2 y1 y2 に返します。
##     measure-gbox
##       @var[out] gx1 gx2 gy1 gy2
##       描画範囲を x1 x2 y1 y2 に返します。
##     left-char
##       @var[in,out] lc lg
##       bleopt_internal_suppress_bash_output= の時、
##       出力開始時のカーソル左の文字コードを指定します。
##       出力終了時のカーソル左の文字コードが分かる場合にそれを返します。
##
##     [出力制御機能]
##
##     relative
##       x y を相対位置と考えて移動を行います。
##       改行などの制御は全て座標に基づいた移動に変換されます。
##     ansi
##       ANSI制御シーケンスで出力を構築します。
##       後で trace で再解析を行う場合などに指定できます。
##     g0 face0
##       背景色・既定属性として用いる属性値または描画設定を指定します。
##       両方指定された場合は g0 を優先させます。
##
##     [その他]
##
##     terminfo
##       ANSI制御シーケンスではなく現在の端末のシーケンスとして
##       制御機能SGRを解釈します。
##
##   @var[in,out] DRAW_BUFF[]
##     ble/canvas/trace.draw の出力先の配列です。
##   @var[out] ret
##     ble/canvas/trace の結果の格納先の変数です。
##
##   @var[in,out] x y g
##     出力の開始位置を指定します。出力終了時の位置を返します。
##
##   以下のシーケンスを認識します
##
##   - Control Characters (C0 の文字 及び DEL)
##     BS HT LF VT CR はカーソル位置の変更を行います。
##     それ以外の文字はカーソル位置の変更は行いません。
##
##   - CSI Sequence (Control Sequence)
##     | CUU   CSI A | CHB   CSI Z |
##     | CUD   CSI B | HPR   CSI a |
##     | CUF   CSI C | VPR   CSI e |
##     | CUB   CSI D | HPA   CSI ` |
##     | CNL   CSI E | VPA   CSI d |
##     | CPL   CSI F | HVP   CSI f |
##     | CHA   CSI G | SGR   CSI m |
##     | CUP   CSI H | SCOSC CSI s |
##     | CHT   CSI I | SCORC CSI u |
##     上記のシーケンスはカーソル位置の計算に含め、
##     また、端末 (TERM) に応じた出力を実施します。
##     上記以外のシーケンスはカーソル位置を変更しません。
##
##   - SOS, DCS, SOS, PM, APC, ESC k ～ ESC \
##   - ISO-2022 に含まれる 3 byte 以上のシーケンス
##     これらはそのまま通します。位置計算の考慮には入れません。
##
##   - ESC Sequence
##     DECSC DECRC IND RI NEL はカーソル位置の変更を行います。
##     それ以外はカーソル位置の変更は行いません。
##
## 内部実装で用いている変数を整理する
##
##   @var[local] xinit yinit ginit
##     初期カーソル状態を格納する。
##
##   @var x1 x2 y1 y2
##     これは measure-bbox または justify を指定した時に描画範囲を追跡するのに使っている。
##
##   @var[local] cx cy cg
##     clip 時に DRAW_BUFF 出力済みの内容のカーソル状態を追跡する変数。
##     clip 時は x y g は仮想的に clip していない時のカーソル状態を追跡している。
##   @var[local] cx1 cy1 cx2 cy2
##     clip 範囲を保持する変数
##
##

function ble/canvas/trace/.put-sgr.draw {
  local ret g=$1
  if ((g==0)); then
    ble/canvas/put.draw "$opt_sgr0"
  else
    ble/color/g.compose "$opt_g0" "$g"
    "$trace_g2sgr" "$g"
    ble/canvas/put.draw "$ret"
  fi
}

function ble/canvas/trace/.measure-point {
  if [[ $flag_bbox ]]; then
    ((x<x1?(x1=x):(x2<x&&(x2=x))))
    ((y<y1?(y1=y):(y2<y&&(y2=y))))
  fi
}
## @fn ble/canvas/trace/.goto x1 y1
##   @var[in,out] x y
##   Note: lc lg の面倒は呼び出し元で見る。
function ble/canvas/trace/.goto {
  local dstx=$1 dsty=$2
  if [[ ! $flag_clip ]]; then
    if [[ $trace_flags == *[RJ]* ]]; then
      ble/canvas/put-move.draw $((dstx-x)) $((dsty-y))
    else
      ble/canvas/put-cup.draw $((dsty+1)) $((dstx+1))
    fi
  fi
  ((x=dstx,y=dsty))
  ble/canvas/trace/.measure-point
}

function ble/canvas/trace/.implicit-move {
  local w=$1 type=$2
  # gbox は開始点と終了点を記録する。bbox の開始点は既に記録されている
  # 前提。終了点及び行折返しが発生した時の極値を此処で記録する。

  ((w>0)) || return 0

  if [[ $flag_gbox ]]; then
    if [[ ! $gx1 ]]; then
      ((gx1=gx2=x,gy1=gy2=y))
    else
      ((x<gx1?(gx1=x):(gx2<x&&(gx2=x))))
      ((y<gy1?(gy1=y):(gy2<y&&(gy2=y))))
    fi
  fi
  ((x+=w))

  if ((x<=cols)); then
    # 行内に収まった時
    [[ $flag_bbox ]] && ((x>x2)) && x2=$x
    [[ $flag_gbox ]] && ((x>gx2)) && gx2=$x
    if ((x==cols&&!xenl)); then
      ((y++,x=0))
      if [[ $flag_bbox ]]; then
        ((x<x1)) && x1=0
        ((y>y2)) && y2=$y
      fi
    fi
  else
    # 端末による折り返し
    if [[ $type == atomic ]]; then
      # [Note: 文字が横幅より大きい場合は取り敢えず次の行が
      # 一杯になると仮定しているが端末による]
      ((y++,x=w<xlimit?w:xlimit))
    else
      ((y+=x/cols,x%=cols,
        xenl&&x==0&&(y--,x=cols)))
    fi
    if [[ $flag_bbox ]]; then
      ((x1>0&&(x1=0)))
      ((x2<cols&&(x2=cols)))
      ((y>y2)) && y2=$y
    fi
    if [[ $flag_gbox ]]; then
      ((gx1>0&&(gx1=0)))
      ((gx2<cols&&(gx2=cols)))
      ((y>gy2)) && gy2=$y
    fi
  fi
  ((x==0&&(lc=32,lg=0)))
  return 0
}

function ble/canvas/trace/.put-atomic.draw {
  local c=$1 w=$2
  if [[ $flag_clip ]]; then
    ((cy1<=y&&y<cy2&&cx1<=x&&x<cx2&&x+w<=cx2)) || return 0
    if [[ $cg != "$g" ]]; then
      ble/canvas/trace/.put-sgr.draw "$g"
      cg=$g
    fi
    ble/canvas/put-move.draw $((x-cx)) $((y-cy))
    ble/canvas/put.draw "$c"
    ((cx+=x+w,cy=y))
  else
    ble/canvas/put.draw "$c"
  fi

  ble/canvas/trace/.implicit-move "$w" atomic
}
function ble/canvas/trace/.put-ascii.draw {
  local value=$1 w=${#1}
  [[ $value ]] || return

  if [[ $flag_clip ]]; then
    local xL=$x xR=$((x+w))
    ((xR<=cx1||cx2<=xL||y+1<=cy1||cy2<=y)) && return 0
    if [[ $cg != "$g" ]]; then
      ble/canvas/trace/.put-sgr.draw "$g"
      cg=$g
    fi
    ((xL<cx1)) && value=${value:cx1-xL} xL=$cx1
    ((xR>cx2)) && value=${value::${#value}-(xR-cx2)} xR=$cx2
    ble/canvas/put-move.draw $((x-cx)) $((y-cy))
    ble/canvas/put.draw "$value"
    ((cx=xR,cy=y))
  else
    ble/canvas/put.draw "$value"
  fi

  ble/canvas/trace/.implicit-move "$w"
}
function ble/canvas/trace/.process-overflow {
  [[ :$opts: == *:truncate:* ]] && i=$iN # stop
  if [[ :$opts: == *:ellipsis:* ]]; then
    if ble/util/is-unicode-output; then
      local ellipsis='…' ret
      ble/util/s2c "$ellipsis"; ble/util/c2w "$ret"; local w=$ret
    else
      local ellipsis=... w=3
    fi

    local ox=$x oy=$y
    ble/canvas/trace/.goto $((xlimit-w)) $((lines-1))
    ble/canvas/trace/.put-atomic.draw "$ellipsis" "$w"
    ble/canvas/trace/.goto "$ox" "$oy"
  fi
}

#--------------------------------------
## (trace 内部変数) justify 関連
##
##   @var[local] justify_sep
##   @arr[local] justify_fields
##   @arr[local] justify_buff
##   @arr[local] justify_out
##   @var[local] jx0 jy0
##     各フィールドの開始カーソル位置を保持する。
##   @var[local] jx1 jy1 jx2 jy2
##     measure-bbox も指定されていた時に、
##     justify 後の描画範囲追跡に用いている。
##     justify 処理中は x1 y1 x2 y2 は align 前のフィールドの描画範囲追跡に使っている。
##     関数の一番最後で jx1 jy1 jx2 jy2 で x1 y1 x2 y2 を上書きする。
##
function ble/canvas/trace/.justify/inc-quote {
  [[ $trace_flags == *J* ]] || return 0
  ((trace_sclevel++))
  flag_justify=
}
function ble/canvas/trace/.justify/dec-quote {
  [[ $trace_flags == *J* ]] || return 0
  ((--trace_sclevel)) || flag_justify=1
}
## @fn ble/canvas/trace/.justify/begin-line
##   @var[out] jx0 jy0 x1 y1 x2 y2
function ble/canvas/trace/.justify/begin-line {
  ((jx0=x1=x2=x,jy0=y1=y2=y))
  gx1= gx2= gy1= gy2=
  [[ $justify_align == *[cr]* ]] &&
    ble/canvas/trace/.justify/next-field
}
## @fn ble/canvas/trace/.justify/next-field [sep]
##   @param[in,opt] sep
##     省略時は最後のフィールドを意味する。
##   @var[out] jx0 jy0 x1 y1 x2 y2
##   @var[in,out] DRAW_BUFF justify_fields
function ble/canvas/trace/.justify/next-field {
  local sep=$1 wmin=0
  local esc; ble/canvas/sflush.draw -v esc
  [[ $sep == ' ' ]] && wmin=1
  ble/array#push justify_fields "${sep:-\$}:$wmin:$jx0,$jy0,$x,$y:$x1,$y1,$x2,$y2:$gx1,$gy1,$gx2,$gy2:$esc"
  ((x+=wmin,jx0=x1=x2=x,jy0=y1=y2=y))
}
## @fn ble/canvas/trace/.justify/unpack packed_data
##   @var[out] sep wmin xI yI xF yF x1 y1 x2 y2 esc
function ble/canvas/trace/.justify/unpack {
  local data=$1 buff
  sep=${data::1}; data=${data:2}
  wmin=${data%%:*}; data=${data#*:}
  ble/string#split buff , "${data%%:*}"; data=${data#*:}
  xI=${buff[0]} yI=${buff[1]} xF=${buff[2]} yF=${buff[3]}
  ble/string#split buff , "${data%%:*}"; data=${data#*:}
  x1=${buff[0]} y1=${buff[1]} x2=${buff[2]} y2=${buff[3]}
  ble/string#split buff , "${data%%:*}"; data=${data#*:}
  gx1=${buff[0]} gy1=${buff[1]} gx2=${buff[2]} gy2=${buff[3]}
  esc=$data
}
## @fn ble/canvas/trace/.justify/end-line
##   これまでに justify_fields に記録した各フィールドの esc を align しつつ結合
##   する。
##   @var[in,out] justify_fields DRAW_BUFF justify_buff
function ble/canvas/trace/.justify/end-line {
  # Note: 行内容がなかった場合でも行の高さだけは記録する
  # (NEL で新しい行が形成される事に注意)。
  if [[ $trace_flags == *B* ]]; then
    ((y<jy1&&(jy1=y)))
    ((y>jy2&&(jy2=y)))
  fi
  ((${#justify_fields[@]}||${#DRAW_BUFF[@]})) || return 0

  # 最後のフィールドを justify_fields に移動。
  ble/canvas/trace/.justify/next-field
  [[ $justify_align == *c* ]] &&
    ble/canvas/trace/.justify/next-field

  local i width=0 ispan=0 has_content=
  for ((i=0;i<${#justify_fields[@]};i++)); do
    local sep wmin xI yI xF yF x1 y1 x2 y2 gx1 gy1 gx2 gy2 esc
    ble/canvas/trace/.justify/unpack "${justify_fields[i]}"

    ((width+=xF-xI))
    [[ $esc ]] && has_content=1

    # Note: 最後の要素の次には余白はない。
    ((i+1==${#justify_fields[@]})) && break

    ((width+=wmin))
    ((ispan++))
  done
  [[ $has_content ]] || return 0
  local nspan=$ispan

  local -a DRAW_BUFF=()

  # fill に使える余白を計算する。
  # Note: _ble_term_xenl 及び opt_relative の時には本当の端末の右端には接触しな
  #   いと想定して範囲の右端まで使用する。
  local xlimit=$cols
  [[ $_ble_term_xenl$opt_relative ]] || ((xlimit--))
  local span=$((xlimit-width))

  x= y=
  local ispan=0 vx=0 spanx=0
  for ((i=0;i<${#justify_fields[@]};i++)); do
    local sep wmin xI yI xF yF x1 y1 x2 y2 gx1 gy1 gx2 gy2 esc
    ble/canvas/trace/.justify/unpack "${justify_fields[i]}"

    if [[ ! $x ]]; then
      x=$xI y=$yI
      if [[ $justify_align == right ]]; then
        ble/canvas/put-move-x.draw $((cols-1-x))
        ((x=cols-1))
      fi
    fi

    if [[ $esc ]]; then
      local delta=0
      ((vx+x1-xI<0)) && ((delta=-(vx+x1-xI)))
      ((vx+x2-xI>xlimit)) && ((delta=xlimit-(vx+x2-xI)))
      ble/canvas/put-move-x.draw $((vx+delta-x))
      ((x=vx+delta))
      ble/canvas/put.draw "$esc"
      if [[ $trace_flags == *B* ]]; then
        ((x+x1-xI<jx1&&(jx1=x+x1-xI)))
        ((y+y1-yI<jy1&&(jy1=y+y1-yI)))
        ((x+x2-xI>jx2&&(jx2=x+x2-xI)))
        ((y+y2-yI>jy2&&(jy2=y+y2-yI)))
      fi
      if [[ $flag_gbox && $gx1 ]]; then
        ((gx1+=x-xI,gx2+=x-xI))
        ((gy1+=y-yI,gy2+=y-yI))
        if [[ ! $jgx1 ]]; then
          ((jgx1=gx1,jgy1=gy1,jgx2=gx2,jgy2=gy2))
        else
          ((gx1<jgx1&&(jgx1=gx1)))
          ((gy1<jgy1&&(jgy1=gy1)))
          ((gx2>jgx2&&(jgx2=gx2)))
          ((gy2>jgy2&&(jgy2=gy2)))
        fi
      fi
      ((x+=xF-xI,y+=yF-yI,vx+=xF-xI))
    fi

    ((i+1==${#justify_fields[@]})) && break

    local new_spanx=$((span*++ispan/nspan))
    local wfill=$((wmin+new_spanx-spanx))
    ((vx+=wfill,spanx=new_spanx))

    # fillchar: 取り敢えず現在の実装では空白で fill
    if [[ $sep == ' ' ]]; then
      ble/string#reserve-prototype "$wfill"
      ble/canvas/put.draw "${_ble_string_prototype::wfill}"
      ((x+=wfill))
    fi
  done

  local ret
  ble/canvas/sflush.draw
  ble/array#push justify_buff "$ret"
  justify_fields=()
}

#--------------------------------------
## (trace 内部変数) sc/rc 関連
##
##   @arr[local] trace_decsc
##   @arr[local] trace_scosc
##   @arr[local] trace_brack
##
function ble/canvas/trace/.decsc {
  [[ ${trace_decsc[5]} ]] || ble/canvas/trace/.justify/inc-quote
  trace_decsc=("$x" "$y" "$g" "$lc" "$lg" active)
  if [[ ! $flag_clip ]]; then
    [[ :$opts: == *:noscrc:* ]] ||
      ble/canvas/put.draw "$_ble_term_sc"
  fi
}
function ble/canvas/trace/.decrc {
  [[ ${trace_decsc[5]} ]] && ble/canvas/trace/.justify/dec-quote
  if [[ ! $flag_clip ]]; then
    ble/canvas/trace/.put-sgr.draw "${trace_decsc[2]}" # g を明示的に復元。
    if [[ :$opts: == *:noscrc:* ]]; then
      ble/canvas/put-move.draw $((trace_decsc[0]-x)) $((trace_decsc[1]-y))
    else
      ble/canvas/put.draw "$_ble_term_rc"
    fi
  fi
  x=${trace_decsc[0]}
  y=${trace_decsc[1]}
  g=${trace_decsc[2]}
  lc=${trace_decsc[3]}
  lg=${trace_decsc[4]}
  trace_decsc[5]=
}
function ble/canvas/trace/.scosc {
  [[ ${trace_scosc[5]} ]] || ble/canvas/trace/.justify/inc-quote
  trace_scosc=("$x" "$y" "$g" "$lc" "$lg" active)
  if [[ ! $flag_clip ]]; then
    [[ :$opts: == *:noscrc:* ]] ||
      ble/canvas/put.draw "$_ble_term_sc"
  fi
}
function ble/canvas/trace/.scorc {
  [[ ${trace_scosc[5]} ]] && ble/canvas/trace/.justify/dec-quote
  if [[ ! $flag_clip ]]; then
    ble/canvas/trace/.put-sgr.draw "$g" # g は変わらない様に。
    if [[ :$opts: == *:noscrc:* ]]; then
      ble/canvas/put-move.draw $((trace_scosc[0]-x)) $((trace_scosc[1]-y))
    else
      ble/canvas/put.draw "$_ble_term_rc"
    fi
  fi
  x=${trace_scosc[0]}
  y=${trace_scosc[1]}
  lc=${trace_scosc[3]}
  lg=${trace_scosc[4]}
  trace_scosc[5]=
}
function ble/canvas/trace/.ps1sc {
  ble/canvas/trace/.justify/inc-quote
  trace_brack[${#trace_brack[*]}]="$x $y"
}
function ble/canvas/trace/.ps1rc {
  local lastIndex=$((${#trace_brack[*]}-1))
  if ((lastIndex>=0)); then
    ble/canvas/trace/.justify/dec-quote
    local -a scosc
    ble/string#split-words scosc "${trace_brack[lastIndex]}"
    ((x=scosc[0]))
    ((y=scosc[1]))
    builtin unset -v "trace_brack[$lastIndex]"
  fi
}

#--------------------------------------
function ble/canvas/trace/.NEL {
  if [[ $opt_nooverflow ]] && ((y+1>=lines)); then
    ble/canvas/trace/.process-overflow
    return 1
  fi

  [[ $flag_justify ]] &&
    ble/canvas/trace/.justify/end-line
  if [[ ! $flag_clip ]]; then
    if [[ $opt_relative ]]; then
      ((x)) && ble/canvas/put-cub.draw "$x"
      ble/canvas/put-cud.draw 1
    else
      ble/canvas/put.draw "$_ble_term_cr"
      ble/canvas/put.draw "$_ble_term_nl"
    fi
  fi
  ((y++,x=0,lc=32,lg=0))
  if [[ $flag_bbox ]]; then
    ((x<x1)) && x1=$x
    ((y>y2)) && y2=$y
  fi
  [[ $flag_justify ]] &&
    ble/canvas/trace/.justify/begin-line
  return 0
}
## @fn ble/canvas/trace/.SGR
##   @param[in] param seq
##   @var[out] DRAW_BUFF
##   @var[in,out] g
function ble/canvas/trace/.SGR {
  local param=$1 seq=$2 specs i iN
  if [[ ! $param ]]; then
    g=0
    [[ $flag_clip ]] || ble/canvas/put.draw "$opt_sgr0"
    return 0
  fi

  # update g
  if [[ $opt_terminfo ]]; then
    ble/color/read-sgrspec "$param"
  else
    ble/color/read-sgrspec "$param" ansi
  fi
  [[ $flag_clip ]] || ble/canvas/trace/.put-sgr.draw "$g"
}
function ble/canvas/trace/.process-csi-sequence {
  local seq=$1 seq1=${1:2} rex
  local char=${seq1:${#seq1}-1:1} param=${seq1::${#seq1}-1}
  if [[ ! ${param//[0-9:;]} ]]; then
    # CSI 数字引数 + 文字
    case $char in
    (m) # SGR
      ble/canvas/trace/.SGR "$param" "$seq"
      return 0 ;;
    ([ABCDEFGIZ\`ade])
      local arg=0
      [[ $param =~ ^[0-9]+$ ]] && ((arg=10#${param:-0}))
      ((arg==0&&(arg=1)))

      local ox=$x oy=$y
      if [[ $char == A ]]; then
        # CUU "CSI A"
        ((y-=arg,y<0&&(y=0)))
        ((!flag_clip&&y<oy)) && ble/canvas/put-cuu.draw $((oy-y))
      elif [[ $char == [Be] ]]; then
        # CUD "CSI B"
        # VPR "CSI e"
        ((y+=arg,y>=lines&&(y=lines-1)))
        ((!flag_clip&&y>oy)) && ble/canvas/put-cud.draw $((y-oy))
      elif [[ $char == [Ca] ]]; then
        # CUF "CSI C"
        # HPR "CSI a"
        ((x+=arg,x>=cols&&(x=cols-1)))
        ((!flag_clip&&x>ox)) && ble/canvas/put-cuf.draw $((x-ox))
      elif [[ $char == D ]]; then
        # CUB "CSI D"
        ((x-=arg,x<0&&(x=0)))
        ((!flag_clip&&x<ox)) && ble/canvas/put-cub.draw $((ox-x))
      elif [[ $char == E ]]; then
        # CNL "CSI E"
        ((y+=arg,y>=lines&&(y=lines-1),x=0))
        if [[ ! $flag_clip ]]; then
          ((y>oy)) && ble/canvas/put-cud.draw $((y-oy))
          ble/canvas/put.draw "$_ble_term_cr"
        fi
      elif [[ $char == F ]]; then
        # CPL "CSI F"
        ((y-=arg,y<0&&(y=0),x=0))
        if [[ ! $flag_clip ]]; then
          ((y<oy)) && ble/canvas/put-cuu.draw $((oy-y))
          ble/canvas/put.draw "$_ble_term_cr"
        fi
      elif [[ $char == [G\`] ]]; then
        # CHA "CSI G"
        # HPA "CSI `"
        ((x=arg-1,x<0&&(x=0),x>=cols&&(x=cols-1)))
        if [[ ! $flag_clip ]]; then
          if [[ $opt_relative ]]; then
            ble/canvas/put-move-x.draw $((x-ox))
          else
            ble/canvas/put-hpa.draw $((x+1))
          fi
        fi
      elif [[ $char == d ]]; then
        # VPA "CSI d"
        ((y=arg-1,y<0&&(y=0),y>=lines&&(y=lines-1)))
        if [[ ! $flag_clip ]]; then
          if [[ $opt_relative ]]; then
            ble/canvas/put-move-y.draw $((y-oy))
          else
            ble/canvas/put-vpa.draw $((y+1))
          fi
        fi
      elif [[ $char == I ]]; then
        # CHT "CSI I"
        local _x
        ((_x=(x/it+arg)*it,
          _x>=cols&&(_x=cols-1)))
        if ((_x>x)); then
          [[ $flag_clip ]] || ble/canvas/put-cuf.draw $((_x-x))
          ((x=_x))
        fi
      elif [[ $char == Z ]]; then
        # CHB "CSI Z"
        local _x
        ((_x=((x+it-1)/it-arg)*it,
          _x<0&&(_x=0)))
        if ((_x<x)); then
          [[ $flag_clip ]] || ble/canvas/put-cub.draw $((x-_x))
          ((x=_x))
        fi
      fi
      ble/canvas/trace/.measure-point
      lc=-1 lg=0
      return 0 ;;
    ([Hf])
      # CUP "CSI H"
      # HVP "CSI f"
      local -a params
      ble/string#split-words params "${param//[^0-9]/ }"
      params=("${params[@]/#/10#0}") # #D1570 is-array OK
      local dstx dsty
      ((dstx=params[1]-1))
      ((dsty=params[0]-1))
      ((dstx<0&&(dstx=0),dstx>=cols&&(dstx=cols-1),
        dsty<0&&(dsty=0),dsty>=lines&&(dsty=lines-1)))
      ble/canvas/trace/.goto "$dstx" "$dsty"
      lc=-1 lg=0
      return 0 ;;
    ([su]) # SCOSC SCORC
      if [[ $char == s ]]; then
        ble/canvas/trace/.scosc
      else
        ble/canvas/trace/.scorc
      fi
      return 0 ;;
    # ■その他色々?
    # ([JPX@MKL]) # 挿入削除→カーソルの位置は不変 lc?
    # ([hl]) # SM RM DECSM DECRM
    esac
  fi

  ble/canvas/put.draw "$seq"
}
function ble/canvas/trace/.process-esc-sequence {
  local seq=$1 char=${1:1}
  case $char in
  (7) # DECSC
    ble/canvas/trace/.decsc
    return 0 ;;
  (8) # DECRC
    ble/canvas/trace/.decrc
    return 0 ;;
  (D) # IND
    [[ $opt_nooverflow ]] && ((y+1>=lines)) && return 0
    if [[ $flag_clip || $opt_relative || $flag_justify ]]; then
      ((y+1>=lines)) && return 0
      ((y++))
      [[ $flag_clip ]] ||
        ble/canvas/put-cud.draw 1
    else
      ((y++))
      ble/canvas/put.draw "$_ble_term_ind"
      [[ $_ble_term_ind != $'\eD' ]] &&
        ble/canvas/put-hpa.draw $((x+1)) # tput ind が唯の改行の時がある
    fi
    lc=-1 lg=0
    ble/canvas/trace/.measure-point
    return 0 ;;
  (M) # RI
    [[ $opt_nooverflow ]] && ((y==0)) && return 0
    if [[ $flag_clip || $opt_relative || $flag_justify ]]; then
      ((y==0)) && return 0
      ((y--))
      [[ $flag_clip ]] ||
        ble/canvas/put-cuu.draw 1
    else
      ((y--))
      ble/canvas/put.draw "$_ble_term_ri"
    fi
    lc=-1 lg=0
    ble/canvas/trace/.measure-point
    return 0 ;;
  (E) # NEL
    ble/canvas/trace/.NEL
    return 0 ;;
  # (H) # HTS 面倒だから無視。
  # ([KL]) PLD PLU
  #   上付き・下付き文字 (端末における実装は色々)
  esac

  ble/canvas/put.draw "$seq"
}

function ble/canvas/trace/.impl {
  local text=$1 opts=$2

  # cygwin では LC_COLLATE=C にしないと
  # 正規表現の range expression が期待通りに動かない。
  local LC_ALL= LC_COLLATE=C

  # constants
  local cols=${COLUMNS:-80} lines=${LINES:-25}
  local it=${bleopt_tab_width:-$_ble_term_it} xenl=$_ble_term_xenl
  ble/string#reserve-prototype "$it"

  # Note: 文字符号化方式によっては対応する文字が存在しない可能性がある。
  #   その時は st='\u009C' になるはず。2文字以上のとき変換に失敗したと見做す。
  local ret rex
  ble/util/c2s 156; local st=$ret #  (ST)
  ((${#st}>=2)) && st=

  #-------------------------------------
  # Options

  local xinit=$x yinit=$y ginit=$g

  # @var trace_flags
  #   R relative
  #   B measure-bbox
  #   G measure-gbox
  #   J justify, right, center
  #   C clip
  #
  local trace_flags=

  local opt_nooverflow=; [[ :$opts: == *:truncate:* || :$opts: == *:confine:* ]] && opt_nooverflow=1
  local opt_relative=; [[ :$opts: == *:relative:* ]] && trace_flags=R$trace_flags opt_relative=1
  [[ :$opts: == *:measure-bbox:* ]] && trace_flags=B$trace_flags
  [[ :$opts: == *:measure-gbox:* ]] && trace_flags=G$trace_flags
  [[ :$opts: == *:left-char:* ]] && trace_flags=L$trace_flags
  local opt_terminfo=; [[ :$opts: == *:terminfo:* ]] && opt_terminfo=1

  if local rex=':(justify(=[^:]+)?|center|right):'; [[ :$opts: =~ $rex ]]; then
    trace_flags=J$trace_flags
    local jx0=$x jy0=$y
    local justify_sep= justify_align=
    local -a justify_buff=()
    local -a justify_fields=()
    case ${BASH_REMATCH[1]} in
    (justify*) justify_sep=${BASH_REMATCH[2]:1}${BASH_REMATCH[2]:-' '} ;;
    (center)   justify_align=c ;;
    (right)    justify_align=r ;;
    esac
  fi

  if local rex=':clip=([0-9]*),([0-9]*)([-+])([0-9]*),([0-9]*):'; [[ :$opts: =~ $rex ]]; then
    local cx1 cy1 cx2 cy2 cx cy cg
    trace_flags=C$trace_flags
    cx1=${BASH_REMATCH[1]} cy1=${BASH_REMATCH[2]}
    cx2=${BASH_REMATCH[4]} cy2=${BASH_REMATCH[5]}
    [[ ${BASH_REMATCH[3]} == + ]] && ((cx2+=cx1,cy2+=cy1))
    ((cx1<=cx2)) || local cx1=$cx2 cx2=$cx1
    ((cy1<=cy2)) || local cy1=$cy2 cy2=$cy1
    ((cx1<0)) && cx1=0
    ((cy1<0)) && cy1=0
    ((cols<cx2)) && cx2=$cols
    ((lines<cy2)) && cy2=$lines
    local cx=$cx1 cy=$cy1 cg=
  fi

  local trace_g2sgr=ble/color/g2sgr
  [[ :$opts: == *:ansi:* || $trace_flags == *C*J* ]] &&
    trace_g2sgr=ble/color/g2sgr-ansi

  local opt_g0= opt_sgr0=$_ble_term_sgr0
  if rex=':g0=([^:]+):'; [[ :$opts: =~ $rex ]]; then
    opt_g0=${BASH_REMATCH[1]}
  elif rex=':face0=([^:]+):'; [[ :$opts: =~ $rex ]]; then
    ble/color/face2g "${BASH_REMATCH[1]}"; opt_g0=$ret
  fi
  if [[ $opt_g0 ]]; then
    "$trace_g2sgr" "$opt_g0"; opt_sgr0=$ret
    ble/canvas/put.draw "$opt_sgr0"
    g=$opt_g0
  fi

  #-------------------------------------

  # CSI
  local rex_csi='^\[[ -?]*[@-~]'
  # OSC, DCS, SOS, PM, APC Sequences + "GNU screen ESC k"
  local rex_osc='^([]PX^_k])([^'$st']|+[^\'$st'])*(\\|'${st:+'|'}$st'|$)'
  # ISO-2022 関係 (3byte以上の物)
  local rex_2022='^[ -/]+[@-~]'
  # ESC ?
  local rex_esc='^[ -~]'

  # states
  local trace_sclevel=0
  local -a trace_brack=()
  local -a trace_scosc=()
  local -a trace_decsc=()

  local flag_lchar=
  if [[ $trace_flags == *L* ]]; then
    flag_lchar=1
  else
    local lc=32 lg=0
  fi

  # prepare measure
  local flag_bbox= flag_gbox=
  if [[ $trace_flags == *[BJ]* ]]; then
    flag_bbox=1
    [[ $trace_flags != *B* ]] && local x1 x2 y1 y2
    [[ $trace_flags != *G* ]] && local gx1= gx2= gy1= gy2=
    ((x1=x2=x,y1=y2=y))

    [[ $trace_flags == *J*B* ]] &&
      local jx1=$x jy1=$y jx2=$x jy2=$y
  fi
  if [[ $trace_flags == *G* ]]; then
    ((flag_gbox=1))
    gx1= gx2= gy1= gy2=
    [[ $trace_flags == *J* ]] &&
      local jgx1= jgy1= jgx2= jgy2=
  fi

  # flag_clip: justify 処理が入っている時は後で clip を処理する。
  local flag_clip=
  [[ $trace_flags == *C* && $trace_flags != *J* ]] && flag_clip=1

  # opt_relative の時には右端に接触しない前提。justify の時には、後の再配置の時
  # に xenl について処理するので、フィールド内追跡では xenl は気にしなくて良い。
  local xlimit=$cols
  [[ $opt_relative || $trace_flags == *J* ]] && xenl=1 xlimit=$((cols-1))

  local flag_justify=
  if [[ $trace_flags == *J* ]]; then
    flag_justify=1
    ble/canvas/trace/.justify/begin-line
  fi

  local i=0 iN=${#text}
  while ((i<iN)); do
    local tail=${text:i}
    local is_overflow=
    if [[ $flag_justify && $justify_sep && $tail == ["$justify_sep"]* ]]; then
      ble/canvas/trace/.justify/next-field "${tail::1}"
      ((i++))
    elif [[ $tail == [-]* ]]; then
      local s=${tail::1}
      ((i++))
      case "$s" in
      ($'\e')
        if [[ $tail =~ $rex_osc ]]; then
          # 各種メッセージ (素通り)
          s=$BASH_REMATCH
          [[ ${BASH_REMATCH[3]} ]] || s="$s\\" # 終端の追加
          ((i+=${#BASH_REMATCH}-1))
          ble/canvas/trace/.put-atomic.draw "$s" 0
        elif [[ $tail =~ $rex_csi ]]; then
          # Control sequences
          ((i+=${#BASH_REMATCH}-1))
          ble/canvas/trace/.process-csi-sequence "$BASH_REMATCH"
        elif [[ $tail =~ $rex_2022 ]]; then
          # ISO-2022 (素通り)
          ble/canvas/trace/.put-atomic.draw "$BASH_REMATCH" 0
          ((i+=${#BASH_REMATCH}-1))
        elif [[ $tail =~ $rex_esc ]]; then
          ((i+=${#BASH_REMATCH}-1))
          ble/canvas/trace/.process-esc-sequence "$BASH_REMATCH"
        else
          ble/canvas/trace/.put-atomic.draw "$s" 0
        fi ;;
      ($'\b') # BS
        if ((x>0)); then
          [[ $flag_clip ]] || ble/canvas/put.draw "$s"
          ((x--,lc=32,lg=g))
          ble/canvas/trace/.measure-point
        fi ;;
      ($'\t') # HT
        local _x
        ((_x=(x+it)/it*it,
          _x>=cols&&(_x=cols-1)))
        if ((x<_x)); then
          ((lc=32,lg=g))
          ble/canvas/trace/.put-ascii.draw "${_ble_string_prototype::_x-x}"
        fi ;;
      ($'\n') # LF = CR+LF
        ble/canvas/trace/.NEL ;;
      ($'\v') # VT
        if ((y+1<lines||!opt_nooverflow)); then
          if [[ $flag_clip || $opt_relative || $flag_justify ]]; then
            if ((y+1<lines)); then
              [[ $flag_clip ]] ||
                ble/canvas/put-cud.draw 1
              ((y++,lc=32,lg=0))
            fi
          else
            ble/canvas/put.draw "$_ble_term_cr"
            ble/canvas/put.draw "$_ble_term_nl"
            ((x)) && ble/canvas/put-cuf.draw "$x"
            ((y++,lc=32,lg=0))
          fi
          ble/canvas/trace/.measure-point
        fi ;;
      ($'\r') # CR ^M
        local ox=$x
        ((x=0,lc=-1,lg=0))
        if [[ ! $flag_clip ]]; then
          if [[ $flag_justify ]]; then
            ble/canvas/put-move-x.draw $((jx0-ox))
            ((x=jx0))
          elif [[ $opt_relative ]]; then
            ble/canvas/put-cub.draw "$ox"
          else
            ble/canvas/put.draw "$_ble_term_cr"
          fi
        fi
        ble/canvas/trace/.measure-point ;;
      # Note: \001 (^A) 及び \002 (^B) は PS1 の処理で \[ \] を意味するそうだ。#D1074
      ($'\001') [[ :$opts: == *:prompt:* ]] && ble/canvas/trace/.ps1sc ;;
      ($'\002') [[ :$opts: == *:prompt:* ]] && ble/canvas/trace/.ps1rc ;;
      # その他の制御文字は  (BEL)  (FF) も含めてゼロ幅と解釈する
      (*) ble/canvas/put.draw "$s" ;;
      esac
    elif ble/util/isprint+ "$tail"; then
      local s=$BASH_REMATCH
      [[ $flag_justify && $justify_sep ]] && s=${s%%["$justify_sep"]*}
      local w=${#s}
      if [[ $opt_nooverflow ]]; then
        local wmax=$((lines*cols-(y*cols+x)))
        ((xenl||wmax--,wmax<0&&(wmax=0)))
        ((w>wmax)) && w=$wmax is_overflow=1
      fi

      local t=${s::w}
      if [[ $flag_clip || $opt_relative || $flag_justify ]]; then
        local tlen=$w len=$((cols-x))
        if ((tlen>len)); then
          while ((tlen>len)); do
            ble/canvas/trace/.put-ascii.draw "${t::len}"
            t=${t:len}
            ((x=cols,tlen-=len,len=cols))
            ble/canvas/trace/.NEL
          done
          w=${#t}
        fi
      fi

      if [[ $flag_lchar ]]; then
        local ret
        ble/util/s2c "${s:w-1:1}"
        lc=$ret lg=$g
      fi
      ble/canvas/trace/.put-ascii.draw "$t"
      ((i+=${#s}))

      if local extend; ble/unicode/GraphemeCluster/extend-ascii "$text" "$i"; then
        ble/canvas/trace/.put-atomic.draw "${text:i:extend}" 0
        ((i+=extend))
      fi

    else
      local c w cs cb extend
      ble/unicode/GraphemeCluster/match "$text" "$i" R
      if [[ $opt_nooverflow ]] && ! ((x+w<=xlimit||y+1<lines&&w<=cols)); then
        is_overflow=1
      else
        if ((x+w>cols)); then
          if [[ $flag_clip || $opt_relative || $flag_justify ]]; then
            ble/canvas/trace/.NEL
          else
            # 行に入りきらない場合の調整
            ble/canvas/trace/.put-ascii.draw "${_ble_string_prototype::cols-x}"
          fi
        fi
        lc=$c lg=$g
        ble/canvas/trace/.put-atomic.draw "$cs" "$w"
      fi
      ((i+=1+extend))
    fi

    [[ $is_overflow ]] && ble/canvas/trace/.process-overflow
  done

  if [[ $trace_flags == *J* ]]; then
    if [[ ! $flag_justify ]]; then
      # 各種 sc により一時的に justify が無効化されていたとしても、強制的に rc
      # を出力して閉じる。
      [[ ${trace_scosc[5]} ]] && ble/canvas/trace/.scorc
      [[ ${trace_decsc[5]} ]] && ble/canvas/trace/.decrc
      while [[ ${trace_brack[0]} ]]; do ble/canvas/trace/.ps1rc; done
    fi
    ble/canvas/trace/.justify/end-line
    DRAW_BUFF=("${justify_buff[@]}")

    [[ $trace_flags == *B* ]] &&
      ((x1=jx1,y1=jy1,x2=jx2,y2=jy2))
    [[ $trace_flags == *G* ]] &&
      gx1=$jgx1 gy1=$jgy1 gx2=$jgx2 gy2=$jgy2

    if [[ $trace_flags == *C* ]]; then
      ble/canvas/sflush.draw
      x=$xinit y=$yinit g=$ginit
      local trace_opts=clip=$cx1,$cy1-$cx2,$cy2
      [[ :$opts: == *:ansi:* ]] && trace_opts=$trace_opts:ansi
      ble/canvas/trace/.impl "$ret" "$trace_opts"
      cx=$x cy=$y cg=$g
    fi
  fi

  [[ $trace_flags == *B* ]] && ((y2++))
  [[ $trace_flags == *G* ]] && ((gy2++))
  if [[ $trace_flags == *C* ]]; then
    x=$cx y=$cy g=$cg
    if [[ $trace_flags == *B* ]]; then
      ((x1<cx1)) && x1=$cx1
      ((x1>cx2)) && x1=$cx2
      ((x2<cx1)) && x2=$cx1
      ((x2>cx2)) && x2=$cx2
      ((y1<cy1)) && y1=$cy1
      ((y1>cy2)) && y1=$cy2
      ((y2<cy1)) && y2=$cy1
      ((y2>cy2)) && y2=$cy2
    fi
    if [[ $trace_flags == *G* ]]; then
      if ((gx2<=cx1||cx2<=gx1||gy2<=cy1||cy2<=gy1)); then
        gx1= gx2= gy1= gy2=
      else
        ((gx1<cx1)) && gx1=$cx1
        ((gx2>cx2)) && gx2=$cx2
        ((gy1<cy1)) && gy1=$cy1
        ((gy2>cy2)) && gy2=$cy2
      fi
    fi
  fi
}
function ble/canvas/trace.draw {
  ble/canvas/trace/.impl "$@" 2>/dev/null # Note: suppress LC_COLLATE errors #D1205 #D1341 #D1440
}
function ble/canvas/trace {
  local -a DRAW_BUFF=()
  ble/canvas/trace/.impl "$@" 2>/dev/null # Note: suppress LC_COLLATE errors #D1205 #D1341 #D1440
  ble/canvas/sflush.draw # -> ret
}

#------------------------------------------------------------------------------
# ble/canvas/construct-text

## @fn ble/canvas/trace-text/.put-atomic nchar text
##   指定した文字列を out に追加しつつ、現在位置を更新します。
##   文字列は幅 1 の文字で構成されていると仮定します。
##   @var[in,out] x y out
##   @var[in] cols lines
##
function ble/canvas/trace-text/.put-simple {
  local nchar=$1
  ((nchar)) || return 0

  local nput=$((cols*lines-!_ble_term_xenl-(y*cols+x)))
  ((nput>0)) || return 1
  ((nput>nchar)) && nput=$nchar
  out=$out${2::nput}
  ((x+=nput,y+=x/cols,x%=cols))
  ((_ble_term_xenl&&x==0&&(y--,x=cols)))
  ((nput==nchar)); return $?
}
## @fn x y cols out ; ble/canvas/trace-text/.put-atomic ( w char )+ ; x y out
##   指定した文字を out に追加しつつ、現在位置を更新します。
##   範囲に収まり切らない時に失敗します。
function ble/canvas/trace-text/.put-atomic {
  local w=$1 c=$2

  # 収まらない時は skip
  ((y*cols+x+w<=cols*lines-!_ble_term_xenl)) || return 1

  # その行に入りきらない文字は次の行へ (幅 w が2以上の文字)
  if ((x<cols&&cols<x+w)); then
    if [[ :$opts: == *:nonewline:* ]]; then
      ble/string#reserve-prototype $((cols-x))
      out=$out${_ble_string_prototype::cols-x}
      ((x=cols))
    else
      out=$out$'\n'
      ((y++,x=0))
    fi
  fi

  # w!=0 のとき行末にいたら次の行へ暗黙移動
  ((w&&x==cols&&(y++,x=0)))

  # 改行しても尚行内に収まらない時は ## で代用
  local limit=$((cols-(y+1==lines&&!_ble_term_xenl)))
  if ((x+w>limit)); then
    ble/string#reserve-prototype $((limit-x))
    local pad=${_ble_string_prototype::limit-x}
    out=$out$sgr1${pad//?/'#'}$sgr0
    x=$limit
    ((y+1<lines)); return $?
  fi

  out=$out$c
  ((x+=w,!_ble_term_xenl&&x==cols&&(y++,x=0)))
  return 0
}
## @fn x y cols out ; ble/canvas/trace-text/.put-nl-if-eol ; x y out
##   行末にいる場合次の行へ移動します。
function ble/canvas/trace-text/.put-nl-if-eol {
  if ((x==cols&&y+1<lines)); then
    [[ :$opts: == *:nonewline:* ]] && return 0
    ((_ble_term_xenl)) && out=$out$'\n'
    ((y++,x=0))
  fi
}

## @fn ble/canvas/trace-text text opts
##   指定した文字列を表示する為の制御系列に変換します。
##   @param[in] text
##   @param[in] opts
##     nonewline
##
##     external-sgr
##       @var[in] sgr0 sgr1
##       特殊文字の強調に用いる SGR シーケンスを外部から提供します。
##       sgr0 に通常文字の表示に用いる SGR を、
##       sgr1 に特殊文字の表示に用いる SGR を指定します。
##
##   @var[in] cols lines
##   @var[in,out] x y
##   @var[out] ret
##   @exit
##     指定した範囲に文字列が収まった時に成功します。
function ble/canvas/trace-text {
  local LC_ALL= LC_COLLATE=C

  local out= glob='*[! -~]*'
  local opts=$2 flag_overflow=
  [[ :$opts: == *:external-sgr:* ]] ||
    local sgr0=$_ble_term_sgr0 sgr1=$_ble_term_rev
  if [[ $1 != $glob ]]; then
    # G0 だけで構成された文字列は先に単純に処理する
    ble/canvas/trace-text/.put-simple "${#1}" "$1"
  else
    local glob='[ -~]*' globx='[! -~]*'
    local i iN=${#1} text=$1
    for ((i=0;i<iN;)); do
      local tail=${text:i}
      if [[ $tail == $glob ]]; then
        local span=${tail%%$globx}; ((i+=${#span}))
        ble/canvas/trace-text/.put-simple "${#span}" "$span"
        if local extend; ble/unicode/GraphemeCluster/extend-ascii "$text" "$i"; then
          out=$out${text:i:extend}
          ((i+=extend))
        fi
      else
        local c w cs cb extend
        ble/unicode/GraphemeCluster/match "$text" "$i"
        ((i+=1+extend))
        ((cb==_ble_unicode_GraphemeClusterBreak_Control)) &&
          cs=$sgr1$cs$sgr0
        ble/canvas/trace-text/.put-atomic "$w" "$cs"
      fi && ((y*cols+x<lines*cols)) ||
        { flag_overflow=1; break; }
    done
  fi

  ble/canvas/trace-text/.put-nl-if-eol
  ret=$out

  # 収まったかどうか
  [[ ! $flag_overflow ]]
}
# Note: suppress LC_COLLATE errors #D1205 #D1262 #1341 #D1440
ble/function#suppress-stderr ble/canvas/trace-text

#------------------------------------------------------------------------------
# ble/textmap

_ble_textmap_VARNAMES=(
  _ble_textmap_cols
  _ble_textmap_length
  _ble_textmap_begx
  _ble_textmap_begy
  _ble_textmap_endx
  _ble_textmap_endy

  _ble_textmap_pos
  _ble_textmap_glyph
  _ble_textmap_ichg

  _ble_textmap_dbeg
  _ble_textmap_dend
  _ble_textmap_dend0
  _ble_textmap_umin
  _ble_textmap_umax)

## 文字列の配置計算に関する情報
##
##   前回の配置計算の前提と結果を保持する変数群を以下に説明します。
##   以下は配置計算の前提になる情報です。
##
##   @var _ble_textmap_cols
##     配置幅を保持します。
##   @var _ble_textmap_begx
##   @var _ble_textmap_begy
##     配置の開始位置を保持します。
##   @var _ble_textmap_length
##     配置文字列の長さを保持します。
##
##   以下は配置計算の結果を保持します。
##
##   @arr _ble_textmap_pos[]
##     各文字の表示位置を保持します。
##   @arr _ble_textmap_glyph[]
##     各文字の表現を保持します。
##     例えば、制御文字は ^C や M-^C などと表されます。
##     タブは表示開始位置に応じて異なる個数の空白で表現されます。
##     行送りされた全角文字は前にパディングの空白が付加されます。
##   @arr _ble_textmap_ichg[]
##     タブや行送りなどによって標準的な表現と異なる文字
##     のインデックスのリストです。
##     標準的な表現は ble/highlight/layer:plain/update/.getch で規定されます。
##   @var _ble_textmap_endx
##   @var _ble_textmap_endy
##     最後の文字の右端の座標を保持します。
##
##   以下は前回の配置計算以降の更新範囲を保持する変数です。
##   部分更新をするために使用します。
##
##   @var _ble_textmap_dbeg
##   @var _ble_textmap_dend
##   @var _ble_textmap_dend0
##
_ble_textmap_cols=80
_ble_textmap_length=
_ble_textmap_begx=0
_ble_textmap_begy=0
_ble_textmap_endx=0
_ble_textmap_endy=0
_ble_textmap_pos=()
_ble_textmap_glyph=()
_ble_textmap_ichg=()
_ble_textmap_dbeg=-1
_ble_textmap_dend=-1
_ble_textmap_dend0=-1
_ble_textmap_umin=-1
_ble_textmap_umax=-1

function ble/textmap#update-dirty-range {
  ble/dirty-range#update --prefix=_ble_textmap_d "$@"
}
function ble/textmap#save {
  local name prefix=$1
  ble/util/save-vars "$prefix" "${_ble_textmap_VARNAMES[@]}"
}
function ble/textmap#restore {
  local name prefix=$1
  ble/util/restore-vars "$prefix" "${_ble_textmap_VARNAMES[@]}"
}

## @fn ble/textmap#update/.wrap
##   @var[in,out] cs x y changed
function ble/textmap#update/.wrap {
  if [[ :$opts: == *:relative:* ]]; then
    ((x)) && cs=$cs${_ble_term_cub//'%d'/$x}
    cs=$cs${_ble_term_cud//'%d'/1}
    changed=1
  elif ((xenl)); then
    cs=$cs$_ble_term_nl
    changed=1
  fi
  ((y++,x=0))
}

## @fn ble/textmap#update text [opts]
##   @param[in]     text
##   @param[in,opt] opts
##   @var[in,out]   x y
##   @var[in,out]   _ble_textmap_*
function ble/textmap#update {
  local IFS=$_ble_term_IFS
  local dbeg dend dend0
  ((dbeg=_ble_textmap_dbeg,
    dend=_ble_textmap_dend,
    dend0=_ble_textmap_dend0))
  ble/dirty-range#clear --prefix=_ble_textmap_d

  local text=$1 opts=$2
  local iN=${#text}

  # 初期位置 x y
  local _pos="$x $y"
  _ble_textmap_begx=$x
  _ble_textmap_begy=$y

  # ※現在は COLUMNS で決定しているが将来的には変更可能にする?
  local cols=${COLUMNS-80} xenl=$_ble_term_xenl
  ((COLUMNS&&cols<COLUMNS&&(xenl=1)))
  ble/string#reserve-prototype "$cols"
  # local cols=80 xenl=1

  local it=${bleopt_tab_width:-$_ble_term_it}
  ble/string#reserve-prototype "$it"

  if ((cols!=_ble_textmap_cols)); then
    # 表示幅が変化したときは全部再計算
    ((dbeg=0,dend0=_ble_textmap_length,dend=iN))
    _ble_textmap_pos[0]=$_pos
  elif [[ ${_ble_textmap_pos[0]} != "$_pos" ]]; then
    # 初期位置の変更がある場合は初めから計算し直し
    ((dbeg<0&&(dend=dend0=0),
      dbeg=0))
    _ble_textmap_pos[0]=$_pos
  else
    if ((dbeg<0)); then
      # 表示幅も初期位置も内容も変更がない場合はOK
      local pos
      ble/string#split-words pos "${_ble_textmap_pos[iN]}"
      ((x=pos[0]))
      ((y=pos[1]))
      _ble_textmap_endx=$x
      _ble_textmap_endy=$y
      return 0
    elif ((dbeg>0)); then
      # 途中から計算を再開
      local ret
      ble/unicode/GraphemeCluster/find-previous-boundary "$text" "$dbeg"; dbeg=$ret
      local pos
      ble/string#split-words pos "${_ble_textmap_pos[dbeg]}"
      ((x=pos[0]))
      ((y=pos[1]))
    fi
  fi

  _ble_textmap_cols=$cols
  _ble_textmap_length=$iN

#%if !release
  ble/util/assert '((dbeg<0||(dbeg<=dend&&dbeg<=dend0)))' "($dbeg $dend $dend0) <- ($_ble_textmap_dbeg $_ble_textmap_dend $_ble_textmap_dend0)"
#%end

  # shift cached data
  ble/array#reserve-prototype "$iN"
  local -a old_pos old_ichg
  old_pos=("${_ble_textmap_pos[@]:dend0:iN-dend+1}")
  old_ichg=("${_ble_textmap_ichg[@]}")
  _ble_textmap_pos=(
    "${_ble_textmap_pos[@]::dbeg+1}"
    "${_ble_array_prototype[@]::dend-dbeg}"
    "${_ble_textmap_pos[@]:dend0+1:iN-dend}")
  _ble_textmap_glyph=(
    "${_ble_textmap_glyph[@]::dbeg}"
    "${_ble_array_prototype[@]::dend-dbeg}"
    "${_ble_textmap_glyph[@]:dend0:iN-dend}")
  _ble_textmap_ichg=()

  ble/urange#shift --prefix=_ble_textmap_ "$dbeg" "$dend" "$dend0"

  local i extend
  for ((i=dbeg;i<iN;)); do
    if ble/util/isprint+ "${text:i}"; then
      local w=${#BASH_REMATCH}
      local n
      for ((n=i+w;i<n;i++)); do
        local cs=${text:i:1}
        if ((++x==cols)); then
          local changed=0
          ble/textmap#update/.wrap
          ((changed)) && ble/array#push _ble_textmap_ichg "$i"
        fi
        _ble_textmap_glyph[i]=$cs
        _ble_textmap_pos[i+1]="$x $y 0"
      done
      ble/unicode/GraphemeCluster/extend-ascii "$text" "$i"
    else
      local c w cs cb extend changed=0
      ble/unicode/GraphemeCluster/match "$text" "$i"
      if ((c<32)); then
        if ((c==9)); then
          if ((x+1>=cols)); then
            cs=' ' w=0
            ble/textmap#update/.wrap
          else
            local x2
            ((x2=(x/it+1)*it,
              x2>=cols&&(x2=cols-1),
              w=x2-x,
              w!=it&&(changed=1)))
            cs=${_ble_string_prototype::w}
          fi
        elif ((c==10)); then
          w=0
          if [[ :$opts: == *:relative:* ]]; then
            local pad=$((cols-x)) eraser=
            if ((pad)); then
              if [[ $_ble_term_ech ]]; then
                eraser=${_ble_term_ech//'%d'/$pad}
              else
                eraser=${_ble_string_prototype::cols-x}
                ((x=cols))
              fi
            fi
            local move=${_ble_term_cub//'%d'/$x}${_ble_term_cud//'%d'/1}
            cs=$eraser$move
            changed=1
          else
            cs=$_ble_term_el$_ble_term_nl
          fi
          ((y++,x=0))
        fi
      fi

      local wrapping=0
      if ((w>0)); then
        if ((x<cols&&cols<x+w)); then
          if [[ :$opts: == *:relative:* ]]; then
            cs=${_ble_term_cub//'%d'/$cols}${_ble_term_cud//'%d'/1}$cs
          elif ((xenl)); then
            cs=$_ble_term_nl$cs
          fi
          cs=${_ble_string_prototype::cols-x}$cs
          ((x=cols,changed=1,wrapping=1))
        fi

        ((x+=w))
        while ((x>cols)); do
          ((y++,x-=cols))
        done
        if ((x==cols)); then
          ble/textmap#update/.wrap
        fi
      fi

      _ble_textmap_glyph[i]=$cs
      ((changed)) && ble/array#push _ble_textmap_ichg "$i"
      _ble_textmap_pos[i+1]="$x $y $wrapping"
      ((i++))
    fi
    while ((extend--)); do
      _ble_textmap_glyph[i]=
      _ble_textmap_pos[++i]="$x $y 0"
    done

    if ((i>=dend)); then
      # 後は同じなので計算を省略
      [[ ${old_pos[i-dend]} == "${_ble_textmap_pos[i]}" ]] && break

      # x 座標が同じならば、以降は最後まで y 座標だけずらす
      if [[ ${old_pos[i-dend]%%[$IFS]*} == "${_ble_textmap_pos[i]%%[$IFS]*}" ]]; then
        local -a opos npos pos
        opos=(${old_pos[i-dend]})
        npos=(${_ble_textmap_pos[i]})
        local ydelta=$((npos[1]-opos[1]))
        while ((i<iN)); do
          ((i++))
          pos=(${_ble_textmap_pos[i]})
          ((pos[1]+=ydelta))
          _ble_textmap_pos[i]="${pos[*]}"
        done
        pos=(${_ble_textmap_pos[iN]})
        x=${pos[0]} y=${pos[1]}
        break
      fi
    fi
  done

  if ((i<iN)); then
    # 途中で一致して中断した場合は、前の iN 番目の位置を読む
    local -a pos
    pos=(${_ble_textmap_pos[iN]})
    x=${pos[0]} y=${pos[1]}
  fi

  # 前回までの文字修正位置を shift&add
  local j jN ichg
  for ((j=0,jN=${#old_ichg[@]};j<jN;j++)); do
    if ((ichg=old_ichg[j],
         (ichg>=dend0)&&(ichg+=dend-dend0),
         (0<=ichg&&ichg<dbeg||dend<=i&&ichg<iN)))
    then
      ble/array#push _ble_textmap_ichg "$ichg"
    fi
  done

  ((dbeg<i)) && ble/urange#update --prefix=_ble_textmap_ "$dbeg" "$i"

  _ble_textmap_endx=$x
  _ble_textmap_endy=$y
}

function ble/textmap#is-up-to-date {
  ((_ble_textmap_dbeg==-1))
}
## @fn ble/textmap#assert-up-to-date
##   編集文字列の文字の配置情報が最新であることを確認します。
##   以下の変数を参照する場合に事前に呼び出します。
##
##   _ble_textmap_pos
##   _ble_textmap_length
##
function ble/textmap#assert-up-to-date {
  ble/util/assert 'ble/textmap#is-up-to-date' 'dirty text positions'
}

## @fn ble/textmap#getxy.out index
##   index 番目の文字の出力開始位置を取得します。
##
##   @var[out] x y
##
##   行末に収まらない文字の場合は行末のスペースを埋める為に
##   配列 _ble_textmap_glyph において空白文字が文字本体の前に追加されます。
##   その場合には、追加される空白文字の前の位置を返すことに注意して下さい。
##   実用上は境界 index の左側の文字の終端位置と解釈できます。
##
function ble/textmap#getxy.out {
  ble/textmap#assert-up-to-date
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    shift
  fi

  local -a _pos
  _pos=(${_ble_textmap_pos[$1]})
  ((${_prefix}x=_pos[0]))
  ((${_prefix}y=_pos[1]))
}

## @fn ble/textmap#getxy.cur index
##   index 番目の文字の表示開始位置を取得します。
##
##   @var[out] x y
##
##   ble/textmap#getxy.out の異なり前置される空白は考えずに、
##   文字本体が開始する位置を取得します。
##   実用上は境界 index の右側の文字の開始位置と解釈できます。
##
function ble/textmap#getxy.cur {
  ble/textmap#assert-up-to-date
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix=${1#--prefix=}
    shift
  fi

  local -a _pos
  ble/string#split-words _pos "${_ble_textmap_pos[$1]}"

  # 追い出しされたか check
  if (($1<_ble_textmap_length)); then
    local -a _eoc
    ble/string#split-words _eoc "${_ble_textmap_pos[$1+1]}"
    ((_eoc[2])) && ((_pos[0]=0,_pos[1]++))
  fi

  ((${_prefix}x=_pos[0]))
  ((${_prefix}y=_pos[1]))
}

## @fn ble/textmap#get-index-at [-v varname] x y
##   指定した位置 x y に対応する index を求めます。
function ble/textmap#get-index-at {
  ble/textmap#assert-up-to-date
  local _var=index
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  local _x=$1 _y=$2
  if ((_y>_ble_textmap_endy)); then
    (($_var=_ble_textmap_length))
  elif ((_y<_ble_textmap_begy)); then
    (($_var=0))
  else
    # 2分法
    local _l=0 _u=$((_ble_textmap_length+1)) _m
    local _mx _my
    while ((_l+1<_u)); do
      ble/textmap#getxy.cur --prefix=_m $((_m=(_l+_u)/2))
      (((_y<_my||_y==_my&&_x<_mx)?(_u=_m):(_l=_m)))
    done
    (($_var=_l))
  fi
}

## @fn ble/textmap#hit/.getxy.out index
## @fn ble/textmap#hit/.getxy.cur index
##   @var[in,out] pos
function ble/textmap#hit/.getxy.out {
  local a
  ble/string#split-words a "${_ble_textmap_pos[$1]}"
  x=${a[0]} y=${a[1]}
}
function ble/textmap#hit/.getxy.cur {
  local index=$1 a
  ble/string#split-words a "${_ble_textmap_pos[index]}"
  x=${a[0]} y=${a[1]}
  if ((index<_ble_textmap_length)); then
    ble/string#split-words a "${_ble_textmap_pos[index+1]}"
    ((a[2])) && ((x=0,y++))
  fi
}

## @fn ble/textmap#hit type xh yh [beg [end]]
##   指定した座標に対応する境界 index を取得します。
##   指定した座標以前の最も近い境界を求めます。
##   探索範囲に対応する境界がないときは最初の境界 beg を返します。
##
##   @param[in] type
##     探索する点の種類を指定します。out または cur を指定します。
##     out を指定したときは文字終端境界を探索します。
##     cur を指定したときは文字開始境界(行送りを考慮に入れたもの)を探索します。
##   @param[in] xh yh
##     探索する点を指定します。
##   @param[in] beg end
##     探索する index の範囲を指定します。
##     beg を省略したときは最初の境界位置が使用されます。
##     end を省略したときは最後の境界位置が使用されます。
##
##   @var[out] index
##     見つかった境界の番号を返します。
##   @var[out] lx ly
##     見つかった境界の座標を返します。
##   @var[out] rx ry
##     指定した座標以後の最も近い境界を返します。
##     index が探索範囲の最後の境界のとき、または、
##     lx ly が指定した座標と一致するとき lx ly と同一です。
##
function ble/textmap#hit {
  ble/textmap#assert-up-to-date
  local getxy=ble/textmap#hit/.getxy.$1
  local xh=$2 yh=$3 beg=${4:-0} end=${5:-$_ble_textmap_length}

  local -a pos
  if "$getxy" "$end"; ((yh>y||yh==y&&xh>x)); then
    index=$end
    lx=$x ly=$y
    rx=$x ry=$y
  elif "$getxy" "$beg"; ((yh<y||yh==y&&xh<x)); then
    index=$beg
    lx=$x ly=$y
    rx=$x ry=$y
  else
    # 2分法
    local l=0 u=$((end+1)) m
    while ((l+1<u)); do
      "$getxy" $((m=(l+u)/2))
      (((yh<y||yh==y&&xh<x)?(u=m):(l=m)))
    done
    "$getxy" $((index=l))
    lx=$x ly=$y
    (((ly<yh||ly==yh&&lx<xh)&&index<end)) && "$getxy" $((index+1))
    rx=$x ry=$y
  fi
}

#------------------------------------------------------------------------------
# ble/canvas/goto.draw

## @var _ble_canvas_x
## @var _ble_canvas_y
##   現在の (描画の為に動き回る) カーソル位置を保持します。
_ble_canvas_x=0
_ble_canvas_y=0
_ble_canvas_excursion=

## @fn ble/canvas/goto.draw x y opts
##   現在位置を指定した座標へ移動する制御系列を生成します。
##   @param[in] x y
##     移動先のカーソルの座標を指定します。
##     プロンプト原点が x=0 y=0 に対応します。
function ble/canvas/goto.draw {
  local x=$1 y=$2 opts=$3

  # Note #D1392: mc (midnight commander) は
  #   sgr0 単体でもプロンプトと勘違いするので、
  #   プロンプト更新もカーソル移動も不要の時は、
  #   sgr0 も含めて何も出力しない。
  [[ :$opts: != *:sgr0:* ]] &&
    ((x==_ble_canvas_x&&y==_ble_canvas_y)) && return 0

  ble/canvas/put.draw "$_ble_term_sgr0"

  ble/canvas/put-move-y.draw $((y-_ble_canvas_y))

  local dx=$((x-_ble_canvas_x))
  if ((dx!=0)); then
    if ((x==0)); then
      ble/canvas/put.draw "$_ble_term_cr"
    else
      ble/canvas/put-move-x.draw "$dx"
    fi
  fi

  _ble_canvas_x=$x _ble_canvas_y=$y
}

_ble_canvas_excursion_x=
_ble_canvas_excursion_y=
function ble/canvas/excursion-start.draw {
  [[ $_ble_canvas_excursion ]] && return
  _ble_canvas_excursion=1
  _ble_canvas_excursion_x=$_ble_canvas_x
  _ble_canvas_excursion_y=$_ble_canvas_y
  ble/canvas/put.draw "$_ble_term_sc"
}
function ble/canvas/excursion-end.draw {
  [[ $_ble_canvas_excursion ]] || return
  _ble_canvas_excursion=
  ble/canvas/put.draw "$_ble_term_rc"
  _ble_canvas_x=$_ble_canvas_excursion_x
  _ble_canvas_y=$_ble_canvas_excursion_y
}

#------------------------------------------------------------------------------
# ble/canvas/panel

## @arr _ble_canvas_panel_class
##   各パネルを管理する関数接頭辞を保持する。
##
## @arr _ble_canvas_panel_height
##   各パネルの高さを保持する。
##   現在 panel 0 が textarea で panel 2 が info に対応する。
##
##   開始した瞬間にキー入力をすると画面に echo されてしまうので、
##   それを削除するために最初の編集文字列の行数を 1 とする。
##
## @var _ble_canvas_panel_focus
##   現在 focus のあるパネルの番号を保持する。
##   端末の現在位置はこのパネルの render が設定した位置に置かれる。
##
## @var _ble_canvas_panel_vfill
##   下部に寄せて表示されるパネルの開始番号を保持する。
##   この変数が空文字列の時は全てのパネルは上部に表示される。
_ble_canvas_panel_class=()
_ble_canvas_panel_height=(1 0 0)
_ble_canvas_panel_focus=
_ble_canvas_panel_vfill=
_ble_canvas_panel_bottom= # 現在下部に居るかどうか
_ble_canvas_panel_tmargin='LINES!=1?1:0' # for visible-bell

## @fn ble/canvas/panel/layout/.extract-heights
##   @arr[out] mins maxs
function ble/canvas/panel/layout/.extract-heights {
  local i n=${#_ble_canvas_panel_class[@]}
  for ((i=0;i<n;i++)); do
    local height=0:0
    ble/function#try "${_ble_canvas_panel_class[i]}#panel::getHeight" "$i"
    mins[i]=${height%:*}
    maxs[i]=${height#*:}
  done
}

## @fn ble/canvas/panel/layout/.determine-heights
##   最小高さ mins と希望高さ maxs から実際の高さ heights を決定します。
##   @var[in] lines
##   @arr[in] mins maxs
##   @arr[out] heights
function ble/canvas/panel/layout/.determine-heights {
  local i n=${#_ble_canvas_panel_class[@]} ret
  ble/arithmetic/sum "${mins[@]}"; local min=$ret
  ble/arithmetic/sum "${maxs[@]}"; local max=$ret
  if ((max<=lines)); then
    heights=("${maxs[@]}")
  elif ((min<=lines)); then
    local room=$((lines-min))
    heights=("${mins[@]}")
    while ((room)); do
      local count=0 min_delta=-1 delta
      for ((i=0;i<n;i++)); do
        ((delta=maxs[i]-heights[i],delta>0)) || continue
        ((count++))
        ((min_delta<0||min_delta>delta)) && min_delta=$delta
      done
      ((count==0)) && break

      if ((count*min_delta<=room)); then
        for ((i=0;i<n;i++)); do
          ((maxs[i]-heights[i]>0)) || continue
          ((heights[i]+=min_delta))
        done
        ((room-=count*min_delta))
      else
        local delta=$((room/count)) rem=$((room%count)) count=0
        for ((i=0;i<n;i++)); do
          ((maxs[i]-heights[i]>0)) || continue
          ((heights[i]+=delta))
          ((count++<rem)) && ((heights[i]++))
        done
        ((room=0))
      fi
    done
  else
    heights=("${mins[@]}")
    local excess=$((min-lines))
    for ((i=n-1;i>=0;i--)); do
      local sub=$((heights[i]-heights[i]*lines/min))
      if ((sub<excess)); then
        ((excess-=sub))
        ((heights[i]-=sub))
      else
        ((heights[i]-=excess))
        break
      fi
    done
  fi
}

## @fn ble/canvas/panel/layout/.get-available-height index
##   @var[out] ret
function ble/canvas/panel/layout/.get-available-height {
  local index=$1
  local lines=$((${LINES:-25}-_ble_canvas_panel_tmargin))
  local -a mins=() maxs=()
  ble/canvas/panel/layout/.extract-heights
  maxs[index]=${LINES:-25}
  local -a heights=()
  ble/canvas/panel/layout/.determine-heights
  ret=${heights[index]}
}

function ble/canvas/panel/reallocate-height.draw {
  local lines=$((${LINES:-25}-_ble_canvas_panel_tmargin))

  local i n=${#_ble_canvas_panel_class[@]}
  local -a mins=() maxs=()
  ble/canvas/panel/layout/.extract-heights

  local -a heights=()
  ble/canvas/panel/layout/.determine-heights

  # shrink
  for ((i=0;i<n;i++)); do
    ((heights[i]<_ble_canvas_panel_height[i])) &&
      ble/canvas/panel#set-height.draw "$i" "${heights[i]}"
  done

  # expand
  for ((i=0;i<n;i++)); do
    ((heights[i]>_ble_canvas_panel_height[i])) &&
      ble/canvas/panel#set-height.draw "$i" "${heights[i]}"
  done
}
function ble/canvas/panel/is-last-line {
  local ret
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]}"
  ((_ble_canvas_y==ret-1))
}

function ble/canvas/panel/goto-bottom-dock.draw {
  if [[ ! $_ble_canvas_panel_bottom ]]; then
    _ble_canvas_panel_bottom=1
    ble/canvas/excursion-start.draw
    ble/canvas/put-cup.draw "$LINES" 0 # 一番下の行に移動
    ble/arithmetic/sum "${_ble_canvas_panel_height[@]}"
    ((_ble_canvas_x=0,_ble_canvas_y=ret-1))
  fi
}
function ble/canvas/panel/goto-top-dock.draw {
  if [[ $_ble_canvas_panel_bottom ]]; then
    _ble_canvas_panel_bottom=
    ble/canvas/excursion-end.draw
  fi
}
function ble/canvas/panel/goto-vfill.draw {
  ble/canvas/panel/has-bottom-dock || return 1
  local ret
  ble/canvas/panel/goto-top-dock.draw
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::_ble_canvas_panel_vfill}"
  ble/canvas/goto.draw 0 "$ret" sgr0
  return 0
}
## @fn ble/canvas/panel/save-position opts
##   @var[out] ret
function ble/canvas/panel/save-position {
  ret=$_ble_canvas_x:$_ble_canvas_y:$_ble_canvas_panel_bottom
  [[ :$2: == *:goto-top-dock:* ]] &&
    ble/canvas/panel/goto-top-dock.draw
}
## @fn ble/canvas/panel/load-position x:y:bottom
##   ble/canvas/panel/save-position で記録した情報を元に
##   元の位置に戻ります。
function ble/canvas/panel/load-position {
  local -a DRAW_BUFF=()
  ble/canvas/panel/load-position.draw "$@"
  ble/canvas/bflush.draw
}
function ble/canvas/panel/load-position.draw {
  local data=$1
  local x=${data%%:*}; data=${data#*:}
  local y=${data%%:*}; data=${data#*:}
  local bottom=$data
  if [[ $bottom ]]; then
    ble/canvas/panel/goto-bottom-dock.draw
  else
    ble/canvas/panel/goto-top-dock.draw
  fi
  ble/canvas/goto.draw "$x" "$y"
}

function ble/canvas/panel/has-bottom-dock {
  local ret; ble/canvas/panel/bottom-dock#height
  ((ret))
}
function ble/canvas/panel/bottom-dock#height {
  ret=0
  [[ $_ble_canvas_panel_vfill && $_ble_term_rc ]] || return 0
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]:_ble_canvas_panel_vfill}"
}
function ble/canvas/panel/top-dock#height {
  if [[ $_ble_canvas_panel_vfill && $_ble_term_rc ]]; then
    ble/arithmetic/sum "${_ble_canvas_panel_height[@]::_ble_canvas_panel_vfill}"
  else
    ble/arithmetic/sum "${_ble_canvas_panel_height[@]}"
  fi
}
## @fn ble/canvas/panel/bottom-dock#invalidate
##   Invalidate all bottom panels (with non-zero height)
function ble/canvas/panel/bottom-dock#invalidate {
  [[ $_ble_canvas_panel_vfill && $_ble_term_rc ]] || return 0
  local index n=${#_ble_canvas_panel_class[@]}
  for ((index=_ble_canvas_panel_vfill;index<n;index++)); do
    local panel_class=${_ble_canvas_panel_class[index]}
    local panel_height=${_ble_canvas_panel_height[index]}
    ((panel_height)) &&
      ble/function#try "$panel_class#panel::invalidate" "$index" 0 "$panel_height"
  done
}
function ble/canvas/panel#is-bottom {
  [[ $_ble_canvas_panel_vfill && $_ble_term_rc ]] && (($1>=_ble_canvas_panel_vfill))
}

## @fn ble/canvas/panel#get-origin
##   @var[out] x y
function ble/canvas/panel#get-origin {
  local ret index=$1 prefix=
  [[ $2 == --prefix=* ]] && prefix=${2#*=}
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ((${prefix}x=0,${prefix}y=ret))
}
function ble/canvas/panel#goto.draw {
  local index=$1 x=${2-0} y=${3-0} opts=$4 ret
  if ble/canvas/panel#is-bottom "$index"; then
    ble/canvas/panel/goto-bottom-dock.draw
  else
    ble/canvas/panel/goto-top-dock.draw
  fi
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ble/canvas/goto.draw "$x" $((ret+y)) "$opts"
}
## @fn ble/canvas/panel#put.draw panel text x y
function ble/canvas/panel#put.draw {
  ble/canvas/put.draw "$2"
  ble/canvas/panel#report-cursor-position "$1" "$3" "$4"
}
function ble/canvas/panel#report-cursor-position {
  local index=$1 x=${2-0} y=${3-0} ret
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ((_ble_canvas_x=x,_ble_canvas_y=ret+y))
}

function ble/canvas/panel/increase-total-height.draw {
  local delta=$1
  ((delta>0)) || return 1

  local ret
  ble/canvas/panel/top-dock#height; local top_height=$ret
  ble/canvas/panel/bottom-dock#height; local bottom_height=$ret
  if ((bottom_height)); then
    ble/canvas/panel/goto-top-dock.draw
    if [[ $_ble_term_DECSTBM ]]; then
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw $'\e[1;'$((LINES-bottom_height))'r'
      ble/canvas/excursion-end.draw
      ble/canvas/goto.draw 0 $((top_height==0?0:top_height-1)) sgr0
      ble/canvas/put-ind.draw $((top_height-1+delta-_ble_canvas_y))
      ((_ble_canvas_y=top_height-1+delta))
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw $'\e[r' # Note: Kitty は CSI ; r を認識しない
      ble/canvas/excursion-end.draw
      return 0
    else
      ble/canvas/panel/bottom-dock#invalidate
    fi
  fi

  local old_height=$((top_height+bottom_height))
  local new_height=$((old_height+delta))
  ble/canvas/goto.draw 0 $((top_height==0?0:top_height-1)) sgr0
  ble/canvas/put-ind.draw $((new_height-1-_ble_canvas_y)); ((_ble_canvas_y=new_height-1))
  ble/canvas/panel/goto-vfill.draw &&
    ble/canvas/put-il.draw "$delta" vfill
}

## @fn ble/canvas/panel#set-height.draw panel height opts
##   @param[in] opts
##     shift ... 範囲の先頭で行を追加・削除します。
function ble/canvas/panel#set-height.draw {
  local index=$1 new_height=$2 opts=$3
  ((new_height<0)) && new_height=0
  local old_height=${_ble_canvas_panel_height[index]}
  local delta=$((new_height-old_height))

  if ((delta==0)); then
    if [[ :$opts: == *:clear:* ]]; then
      ble/canvas/panel#clear.draw "$index"
      return $?
    else
      return 1
    fi
  elif ((delta>0)); then
    # 新しく行を挿入
    ble/canvas/panel/increase-total-height.draw "$delta"
    ble/canvas/panel/goto-vfill.draw &&
      ble/canvas/put-dl.draw "$delta" vfill
    ((_ble_canvas_panel_height[index]=new_height))

    case :$opts: in
    (*:clear:*)
      ble/canvas/panel#goto.draw "$index" 0 0 sgr0
      ble/canvas/put-clear-lines.draw "$old_height" "$new_height" panel ;;
    (*:shift:*) # 先頭に行挿入
      ble/canvas/panel#goto.draw "$index" 0 0 sgr0
      ble/canvas/put-il.draw "$delta" panel ;;
    (*) # 末尾に行挿入
      ble/canvas/panel#goto.draw "$index" 0 "$old_height" sgr0
      ble/canvas/put-il.draw "$delta" panel ;;
    esac

  else
    ((delta=-delta))

    case :$opts: in
    (*:clear:*)
      ble/canvas/panel#goto.draw "$index" 0 0 sgr0
      ble/canvas/put-clear-lines.draw "$old_height" "$new_height" panel ;;
    (*:shift:*) # 先頭を削除
      ble/canvas/panel#goto.draw "$index" 0 0 sgr0
      ble/canvas/put-dl.draw "$delta" panel ;;
    (*) # 末尾を削除
      ble/canvas/panel#goto.draw "$index" 0 "$new_height" sgr0
      ble/canvas/put-dl.draw "$delta" panel ;;
    esac

    ((_ble_canvas_panel_height[index]=new_height))
    ble/canvas/panel/goto-vfill.draw &&
      ble/canvas/put-il.draw "$delta" vfill
  fi
  ble/function#try "${_ble_canvas_panel_class[index]}#panel::onHeightChange" "$index"

  return 0
}
function ble/canvas/panel#increase-height.draw {
  local index=$1 delta=$2 opts=$3
  ble/canvas/panel#set-height.draw "$index" $((_ble_canvas_panel_height[index]+delta)) "$opts"
}

function ble/canvas/panel#set-height-and-clear.draw {
  local index=$1 new_height=$2
  ble/canvas/panel#set-height.draw "$index" "$new_height" clear
}

function ble/canvas/panel#clear.draw {
  local index=$1
  local height=${_ble_canvas_panel_height[index]}
  if ((height)); then
    ble/canvas/panel#goto.draw "$index" 0 0 sgr0
    ble/canvas/put-clear-lines.draw "$height"
  fi
}
function ble/canvas/panel#clear-after.draw {
  local index=$1 x=$2 y=$3
  local height=${_ble_canvas_panel_height[index]}
  ((y<height)) || return 1

  ble/canvas/panel#goto.draw "$index" "$x" "$y" sgr0
  ble/canvas/put.draw "$_ble_term_el"
  local rest_lines=$((height-(y+1)))
  if ((rest_lines)); then
    ble/canvas/put.draw "$_ble_term_ind"
    [[ $_ble_term_ind != $'\eD' ]] &&
      ble/canvas/put-hpa.draw $((x+1))
    ble/canvas/put-clear-lines.draw "$rest_lines"
    ble/canvas/put-cuu.draw 1
  fi
}

## @fn ble/canvas/panel/invalidate
##   Invalidate all panels (with non-zero height)
function ble/canvas/panel/clear {
  local -a DRAW_BUFF=()
  local index n=${#_ble_canvas_panel_class[@]}
  for ((index=0;index<n;index++)); do
    local panel_class=${_ble_canvas_panel_class[index]}
    local panel_height=${_ble_canvas_panel_height[index]}
    ((panel_height)) || continue
    ble/canvas/panel#clear.draw "$index"
    ble/function#try "$panel_class#panel::invalidate" "$index" 0 "$panel_height"
  done
  ble/canvas/bflush.draw
}
function ble/canvas/panel/invalidate {
  local opts=$1
  if [[ :$opts: == *:height:* ]]; then
    local -a DRAW_BUFF=()
    ble/canvas/excursion-end.draw
    ble/canvas/put.draw "$_ble_term_cr$_ble_term_ed"
    _ble_canvas_x=0 _ble_canvas_y=0
    ble/dense-array#fill-range _ble_canvas_panel_height 0 "${#_ble_canvas_panel_height[@]}" 0
    ble/canvas/panel/reallocate-height.draw
    ble/canvas/bflush.draw
  fi

  local index n=${#_ble_canvas_panel_class[@]}
  for ((index=0;index<n;index++)); do
    local panel_class=${_ble_canvas_panel_class[index]}
    local panel_height=${_ble_canvas_panel_height[index]}
    ((panel_height)) || continue
    ble/function#try "$panel_class#panel::invalidate" "$index" 0 "$panel_height"
  done
}
function ble/canvas/panel/render {
  local index n=${#_ble_canvas_panel_class[@]} pos=
  for ((index=0;index<n;index++)); do
    local panel_class=${_ble_canvas_panel_class[index]}
    local panel_height=${_ble_canvas_panel_height[index]}
    # Note: panel::render の中で高さを更新するので panel_height==0 で
    # あっても panel::render を呼び出す。
    ble/function#try "$panel_class#panel::render" "$index" 0 "$panel_height"
    if [[ $_ble_canvas_panel_focus ]] && ((index==_ble_canvas_panel_focus)); then
      local ret; ble/canvas/panel/save-position; local pos=$ret
    fi
  done
  [[ $pos ]] && ble/canvas/panel/load-position "$pos"
  return 0
}
## @fn ble/canvas/panel/ensure-terminal-top-line
##   visible-bell で使う為
function ble/canvas/panel/ensure-tmargin.draw {
  local tmargin=$((_ble_canvas_panel_tmargin))
  ((tmargin>LINES)) && tmargin=$LINES
  ((tmargin>0)) || return 0

  local ret
  ble/canvas/panel/save-position; local pos=$ret
  ble/canvas/panel/goto-top-dock.draw

  ble/canvas/panel/top-dock#height; local top_height=$ret
  ble/canvas/panel/bottom-dock#height; local bottom_height=$ret
  if ((bottom_height)); then
    if [[ $_ble_term_DECSTBM ]]; then
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw $'\e[1;'$((LINES-bottom_height))'r'
      ble/canvas/excursion-end.draw
      ble/canvas/goto.draw 0 0 sgr0
      if [[ $_ble_term_ri ]]; then
        ble/canvas/put-ri.draw "$tmargin"
        ble/canvas/put-cud.draw "$tmargin"
      else
        # RI がない時
        ble/canvas/put-ind.draw $((top_height-1+tmargin))
        ble/canvas/put-cuu.draw $((top_height-1+tmargin))
        ble/canvas/excursion-start.draw
        ble/canvas/put-cup.draw 1 1
        ble/canvas/put-il.draw "$tmargin" no-lastline
        ble/canvas/excursion-end.draw
      fi
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw $'\e[;r'
      ble/canvas/excursion-end.draw
      ble/canvas/panel/load-position.draw "$pos"
      return 0
    else
      ble/canvas/panel/bottom-dock#invalidate
    fi
  fi

  ble/canvas/goto.draw 0 0 sgr0
  if [[ $_ble_term_ri ]]; then
    ble/canvas/put-ri.draw "$tmargin"
    ble/canvas/put-cud.draw "$tmargin"
  else
    # RI がない時
    local total_height=$((top_height+bottom_height))
    ble/canvas/put-ind.draw $((total_height-1+tmargin))
    ble/canvas/put-cuu.draw $((total_height-1+tmargin))
    if [[ $_ble_term_rc ]]; then
      ble/canvas/excursion-start.draw
      ble/canvas/put-cup.draw 1 1
      ble/canvas/put-il.draw "$tmargin" no-lastline
      ble/canvas/excursion-end.draw
    else
      ble/canvas/put-il.draw "$tmargin" no-lastline
    fi
    ble/canvas/put-cud.draw "$tmargin"
  fi
  ble/canvas/panel/load-position.draw "$pos"
}
