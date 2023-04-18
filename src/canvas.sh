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

_ble_util_c2w=()
_ble_util_c2w_cache=()
function ble/util/c2w/clear-cache {
  _ble_util_c2w_cache=()
}

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
##     定義 ble/util/c2w:$bleopt_char_width_mode
bleopt/declare -n char_width_mode auto
function bleopt/check:char_width_mode {
  if ! ble/is-function "ble/util/c2w:$value"; then
    ble/util/print "bleopt: Invalid value char_width_mode='$value'. A function 'ble/util/c2w:$value' is not defined." >&2
    return 1
  fi

  case $value in
  (auto)
    _ble_unicode_c2w_ambiguous=1
    ble && ble/util/c2w:auto/test.buff first-line ;;
  (west) _ble_unicode_c2w_ambiguous=1 ;;
  (east) _ble_unicode_c2w_ambiguous=2 ;;
  esac
  ((_ble_prompt_version++))
  ble/util/c2w/clear-cache
}

## @fn ble/util/c2w ccode
##   @var[out] ret
function ble/util/c2w {
  ret=${_ble_util_c2w_cache[$1]:-${_ble_util_c2w[$1]}}
  if [[ ! $ret ]]; then
    "ble/util/c2w:$bleopt_char_width_mode" "$1"
    _ble_util_c2w_cache[$1]=$ret
  fi
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

#%< canvas.c2w.sh
_ble_unicode_c2w_version=14
_ble_unicode_c2w_ambiguous=1
_ble_unicode_c2w_invalid=1
_ble_unicode_c2w_custom=()

bleopt/declare -n char_width_version auto
function bleopt/check:char_width_version {
  if [[ $value == auto ]]; then
    ble && ble/util/c2w:auto/test.buff first-line
    ((_ble_prompt_version++))
    ble/util/c2w/clear-cache
    return 0
  elif local ret; ble/unicode/c2w/version2index "$value"; then
    _ble_unicode_c2w_version=$ret
    ((_ble_prompt_version++))
    ble/util/c2w/clear-cache
    return 0
  else
    ble/util/print "bleopt: char_width_version: invalid value '$value'." >&2
    return 1
  fi
}

# wcwdith 例外 (Unicode 特性からは予想できない値を持っている物)
# この表は make/canvas.c2w.wcwidth.exe compare_eaw の出力より。
_ble_unicode_c2w_custom[173]=1                    # U+00ad       Cf A SHY(soft-hyphen)
let '_ble_unicode_c2w_custom['{1536..1541}']=1'   # U+0600..0605 Cf 1 アラブの数字?
_ble_unicode_c2w_custom[1757]=1                   # U+06dd       Cf 1 ARABIC END OF AYAH
_ble_unicode_c2w_custom[1807]=1                   # U+070f       Cf 1 SYRIAC ABBREVIATION MARK
_ble_unicode_c2w_custom[2274]=1                   # U+08e2       Cf 1 ARABIC DISPUTED END OF AYAH
_ble_unicode_c2w_custom[69821]=1                  # U+110bd      Cf 1 KAITHI NUMBER SIGN
_ble_unicode_c2w_custom[69837]=1                  # U+110cd      Cf 1 KAITHI NUMBER SIGN ABOVE
let '_ble_unicode_c2w_custom['{12872..12879}']=2' # U+3248..324f No A 囲み文字10-80 (8字)
let '_ble_unicode_c2w_custom['{19904..19967}']=2' # U+4dc0..4dff So 1 易経記号 (6字)
let '_ble_unicode_c2w_custom['{4448..4607}']=0'   # U+1160..11ff Lo 1 HANGUL JAMO (160字)
let '_ble_unicode_c2w_custom['{55216..55238}']=0' # U+d7b0..d7c6 Lo 1 HANGUL JAMO EXTENDED-B (1) (23字)
let '_ble_unicode_c2w_custom['{55243..55291}']=0' # U+d7cb..d7fb Lo 1 HANGUL JAMO EXTENDED-B (2) (49字)

function ble/unicode/c2w {
  local c=$1
  ret=${_ble_unicode_c2w_custom[c]}
  [[ $ret ]] && return 0

  ret=${_ble_unicode_c2w[c]}
  if [[ ! $ret ]]; then
    ret=${_ble_unicode_c2w_index[c<0x20000?c>>8:((c>>12)-32+512)]}
    if [[ $ret == *:* ]]; then
      local l=${ret%:*} u=${ret#*:} m
      while ((l+1<u)); do
        ((m=(l+u)/2))
        if ((_ble_unicode_c2w_ranges[m]<=c)); then
          l=$m
        else
          u=$m
        fi
      done
      ret=${_ble_unicode_c2w[_ble_unicode_c2w_ranges[l]]}
    fi
  fi
  ret=${_ble_unicode_c2w_UnicodeVersionMapping[ret*_ble_unicode_c2w_UnicodeVersionCount+_ble_unicode_c2w_version]}
  ((ret<0)) && ret=${_ble_unicode_c2w_invalid:-$((-ret))}
  ((ret==3)) &&
    ret=${_ble_unicode_c2w_ambiguous:-1}
  return 0
}


## @const _ble_unicode_EmojiStatus_*
##
## @var _ble_unicode_EmojiStatus_xmaybe
## @arr _ble_unicode_EmojiStatus
## @arr _ble_unicode_EmojiStatus_ranges
## @var _ble_unicode_EmojiStatus_version
## @bleopt emoji_version
##
##   ファイル src/canvas.emoji.sh は以下のコマンドで生成する。
##   $ ./make_command.sh update-emoji-database
##
#%< canvas.emoji.sh

bleopt/declare -v emoji_width 2
bleopt/declare -v emoji_opts ri

function bleopt/check:emoji_version {
  local ret
  if ! ble/unicode/EmojiStatus/version2index "$value"; then
    local rex='^0*([0-9]+)\.0*([0-9]+)$'
    if ! [[ $value =~ $rex ]]; then
      ble/util/print "bleopt: Invalid format for emoji_version: '$value'." >&2
      return 1
    else
      ble/util/print "bleopt: Unsupported emoji_version: '$value'." >&2
      return 1
    fi
  fi

  _ble_unicode_EmojiStatus_version=$ret
  ((_ble_prompt_version++))
  ble/util/c2w/clear-cache
  return 0
}
function bleopt/check:emoji_width { ble/util/c2w/clear-cache; }

# 2021-06-18 unqualified は絵文字に含めない。多くの場合は既定では通常文字で
# EPVS によって絵文字として表示する様である。component は肌の色(Extend) と髪
# (Pictographic) の2種類がある。取り敢えず幅2で計算する。
_ble_unicode_EmojiStatus_xIsEmoji='ret&&ret!=_ble_unicode_EmojiStatus_Unqualified'
function bleopt/check:emoji_opts {
  _ble_unicode_EmojiStatus_xIsEmoji='ret'
  [[ :$value: != *:unqualified:* ]] &&
    _ble_unicode_EmojiStatus_xIsEmoji=$_ble_unicode_EmojiStatus_xIsEmoji'&&ret!=_ble_unicode_EmojiStatus_Unqualified'
  local rex=':min=U\+([0-9a-fA-F]+):'
  [[ :$value: =~ $rex ]] &&
    _ble_unicode_EmojiStatus_xIsEmoji=$_ble_unicode_EmojiStatus_xIsEmoji'&&code>=0x'${BASH_REMATCH[1]}
  ((_ble_prompt_version++))
  ble/util/c2w/clear-cache
  return 0
}

function ble/unicode/EmojiStatus {
  local code=$1 V=$_ble_unicode_EmojiStatus_version
  ret=${_ble_unicode_EmojiStatus[code]}
  if [[ ! $ret ]]; then
    ret=$_ble_unicode_EmojiStatus_None
    if ((_ble_unicode_EmojiStatus_xmaybe)); then
      local l=0 u=${#_ble_unicode_EmojiStatus_ranges[@]} m
      while ((l+1<u)); do
        ((_ble_unicode_EmojiStatus_ranges[m=(l+u)/2]<=code?(l=m):(u=m)))
      done
      ret=${_ble_unicode_EmojiStatus[_ble_unicode_EmojiStatus_ranges[l]]:-0}
    fi
    _ble_unicode_EmojiStatus[code]=$ret
  fi
  ((ret=ret))
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

function ble/util/c2w:west {
  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
  else
    ble/unicode/c2w "$1"
  fi
}

function ble/util/c2w:east {
  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
  else
    ble/unicode/c2w "$1"
  fi
}

## @fn ble/util/c2w:emacs
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

function ble/util/c2w:emacs {
  local code=$1

  # bash-4.0 bug workaround
  #   中で使用している変数に日本語などの文字列が入っているとエラーになる。
  #   その値を参照していなくても、その分岐に入らなくても関係ない。
  #   なので ret に予め適当な値を設定しておく事にする。
  ret=1
  ((code<0xA0)) && return 0

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$code"; then
    ((ret=bleopt_emoji_width))
    return 0
  fi

  # Note: ble/unicode/c2w を使うとずれる。考えてみれば emacs は各端末
  # で同じテーブルを使って実装しているので ble/unicode/c2w 等外部の物
  # を参照せずに実装するべきなのであった。
  #ble/unicode/c2w "$1"
  #((ret==3)) || return 0

  # 実は EastAsianWidth=A だけ考えれば良いので下の条件式は単純化できる筈
  local al=0 ah=0 tIndex=
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

#%< canvas.c2w.musl.sh

function ble/util/c2w:musl {
  local code=$1

  ret=1
  ((code&&code<0x300)) && return 0

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$code"; then
    ((ret=bleopt_emoji_width))
    return 0
  fi

  local l=0 u=${#_ble_util_c2w_musl_ranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_musl_ranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done
  ret=${_ble_util_c2w_musl[_ble_util_c2w_musl_ranges[l]]}
}

_ble_util_c2w_auto_update_x0=0
_ble_util_c2w_auto_update_result=()
_ble_util_c2w_auto_update_processing=0
function ble/util/c2w:auto {
  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
  else
    ble/unicode/c2w "$1"
  fi
}

function ble/util/c2w:auto/check {
  [[ $bleopt_char_width_mode == auto || $bleopt_char_width_version == auto ]] &&
    ble/util/c2w:auto/test.buff
  return 0
}

function ble/util/c2w:auto/test.buff {
  local opts=$1
  local -a DRAW_BUFF=()
  local ret saved_pos=

  # 現在既に処理中の場合 DSR は省略。char_width_@=auto 等で一括して要
  # 求した時などに一回だけ実行する為。
  ((_ble_util_c2w_auto_update_processing)) && return 0

  [[ $_ble_attached ]] && { ble/canvas/panel/save-position goto-top-dock; saved_pos=$ret; }
  ble/canvas/put.draw "$_ble_term_sc"
  if ble/util/is-unicode-output; then

    local -a codes=(
      # index=0,1 [EastAsianWidth=A 判定]
      0x25bd 0x25b6

      # index=2..15 [Unicode version 判定] #D1645 #D1668
      #   判定用の文字コードは "source
      #   make/canvas.c2w.list-ucsver-detection-codes.sh" を用いて生
      #   成されたリストから選択した。新しい Unicode version が出たら
      #   再びこれを実行して判定コードを書く事になる。
      0x9FBC 0x9FC4 0x31B8 0xD7B0 0x3099
      0x9FCD 0x1F93B 0x312E 0x312F 0x16FE2
      0x32FF 0x31BB 0x9FFD 0x1B132)

    _ble_util_c2w_auto_update_processing=${#codes[@]}
    _ble_util_c2w_auto_update_result=()
    if [[ :$opts: == *:first-line:* ]]; then
      # 画面の右上で判定を行います。
      local cols=${COLUMNS:-80}
      local x0=$((cols-4)); ((x0<0)) && x0=0
      _ble_util_c2w_auto_update_x0=$x0

      local code index=0
      for code in "${codes[@]}"; do
        ble/canvas/put-cup.draw 1 "$((x0+1))"
        ble/canvas/put.draw "$_ble_term_el"
        ble/util/c2s "$((code))"
        ble/canvas/put.draw "$ret"
        ble/term/CPR/request.draw "ble/util/c2w/test.hook $((index++))"
      done
      ble/canvas/put-cup.draw 1 "$((x0+1))"
      ble/canvas/put.draw "$_ble_term_el"
    else
      _ble_util_c2w_auto_update_x0=2
      local code index=0
      for code in "${codes[@]}"; do
        ble/util/c2s "$((code))"
        ble/canvas/put.draw "$_ble_term_cr$_ble_term_el[$ret]"
        ble/term/CPR/request.draw "ble/util/c2w/test.hook $((index++))"
      done
      ble/canvas/put.draw "$_ble_term_cr$_ble_term_el"
    fi
  fi
  ble/canvas/put.draw "$_ble_term_rc"
  [[ $_ble_attached ]] && ble/canvas/panel/load-position.draw "$saved_pos"
  ble/canvas/bflush.draw
}
function ble/util/c2w/test.hook {
  local index=$1 l=$2 c=$3
  local w=$((c-1-_ble_util_c2w_auto_update_x0))
  _ble_util_c2w_auto_update_result[index]=$w
  ((index==_ble_util_c2w_auto_update_processing-1)) || return 0
  _ble_util_c2w_auto_update_processing=0

  local ws
  if [[ $bleopt_char_width_version == auto ]]; then
    ws=("${_ble_util_c2w_auto_update_result[@]:2}")
    if ((ws[13]==2)); then
      bleopt char_width_version=15.0
    elif ((ws[11]==2)); then
      if ((ws[12]==2)); then
        bleopt char_width_version=14.0
      else
        bleopt char_width_version=13.0
      fi
    elif ((ws[10]==2)); then
      bleopt char_width_version=12.1
    elif ((ws[9]==2)); then
      bleopt char_width_version=12.0
    elif ((ws[8]==2)); then
      bleopt char_width_version=11.0
    elif ((ws[7]==2)); then
      bleopt char_width_version=10.0
    elif ((ws[6]==2)); then
      bleopt char_width_version=9.0
    elif ((ws[4]==0)); then
      if ((ws[5]==2)); then
        bleopt char_width_version=8.0
      else
        bleopt char_width_version=7.0
      fi
    elif ((ws[3]==1&&ws[1]==2)); then
      bleopt char_width_version=6.3 # or 6.2
    elif ((ws[2]==2)); then
      bleopt char_width_version=6.1 # or 6.0
    elif ((ws[1]==2)); then
      bleopt char_width_version=5.2
    elif ((ws[0]==2)); then
      bleopt char_width_version=5.0
    else
      bleopt char_width_version=4.1
    fi
  fi

  # 先に char_width_version を確定してから musl の判定でそれを参照する。
  if [[ $bleopt_char_width_mode == auto ]]; then
    IFS=: builtin eval 'ws="${_ble_util_c2w_auto_update_result[*]::2}:${_ble_util_c2w_auto_update_result[*]:5:2}"'
    case $ws in
    (2:2:*:*) bleopt char_width_mode=east ;;
    (2:1:*:*) bleopt char_width_mode=emacs ;;
    (1:1:2:0)
      if [[ $bleopt_char_width_version == 10.0 ]]; then
        bleopt char_width_mode=musl
      else
        bleopt char_width_mode=west
      fi ;;
    (*) bleopt char_width_mode=west ;;
    esac
  fi

  return 0
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

_ble_unicode_GraphemeCluster_bomlen=1
_ble_unicode_GraphemeCluster_ucs4len=1
function ble/unicode/GraphemeCluster/s2break/.initialize {
  local LC_ALL=C.UTF-8
  builtin eval "local v1=\$'\\uFE0F' v2=\$'\\U1F6D1'"
  _ble_unicode_GraphemeCluster_bomlen=${#v1}
  _ble_unicode_GraphemeCluster_ucs4len=${#v2}
  ble/util/unlocal LC_ALL
  builtin unset -f "$FUNCNAME"
} 2>/dev/null # suppress locale error #D1440
ble/unicode/GraphemeCluster/s2break/.initialize

## @fn ble/unicode/GraphemeCluster/s2break/.combine-surrogate code1 code2 str
##   @var[out] c
function ble/unicode/GraphemeCluster/s2break/.combine-surrogate {
  local code1=$1 code2=$2 s=$3
  if ((0xDC00<=code2&&code2<=0xDFFF)); then
    ((c=0x10000+(code1-0xD800)*1024+(code2&0x3FF)))
  else
    local ret
    ble/util/s2bytes "$s"
    ble/encoding:UTF-8/b2c "${ret[@]}"
    c=$ret
  fi
}
## @fn ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF code
##   (#D1881) Bash 4.3, 4.4 [sizeof(wchar_t) == 2] で $'\uE000'.. $'\uFFFF' が
##   壊れたサロゲートになるバグに対する対策。この時、前半サロゲートは不正な値
##   U+D7F8..D7FF になるが、これはハングル字母などと被る。U+D7F8..D7FF の時は、
##   次の文字が後半サロゲートの時に限り前半サロゲートとして取り扱う。
##
##   @param[in] code
##     壊れた前半サロゲータの可能性がある文字コード
##   @var[in,out] ret
##     調整前後の GraphemeClusterBreak 値
##   @exit
##     調整が行われた時に成功です (0)。それ以外の時は失敗 (1) です。
##
if ((_ble_unicode_GraphemeCluster_bomlen==2&&40300<=_ble_bash&&_ble_bash<50000)); then
  function ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF {
    local code=$1
    ((0xD7F8<=code&&code<0xD800)) && ble/util/is-unicode-output &&
      ret=$_ble_unicode_GraphemeClusterBreak_HighSurrogate
  }
else
  function ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF { ((0)); }
fi
## @fn ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG code
##   (#D1881) Cygwin では UCS-2 に入らないコードポイントの後半サロゲートをs2cで
##   取ろうとしても 0 になってしまう (Bash 5.0 以降では 4-byte UTF-8 の最後のバ
##   イト値) ので、後半について code == 0 の場合も前半サロゲートをチェックする。
##
##   @param[in] code
##     UCS-4 の後半サロゲートの可能性がある文字コード
##   @var[in,out] ret
##     調整前後の GraphemeClusterBreak 値
##   @exit
##     調整が行われた時に成功です (0)。それ以外の時は失敗 (1) です。
##
if ((_ble_unicode_GraphemeCluster_ucs4len==2)); then
  if ((_ble_bash<50000)); then
    function ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG {
      local code=$1
      ((code==0)) && ble/util/is-unicode-output &&
        ret=$_ble_unicode_GraphemeClusterBreak_LowSurrogate
    }
  else
    function ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG {
      local code=$1
      ((0x80<=code&&code<0xC0)) && ble/util/is-unicode-output &&
        ret=$_ble_unicode_GraphemeClusterBreak_LowSurrogate
    }
  fi
else
  function ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG { ((0)); }
fi

## @fn ble/unicode/GraphemeCluster/s2break-left str index [opts]
## @fn ble/unicode/GraphemeCluster/s2break-right str index [opts]
##   指定した文字列の指定した境界の左右の code point の GraphemeCulsterBreak 値
##   を求めます。単に bash の文字単位ではなく、サロゲートペアも考慮に入れたコー
##   ドポイント単位で処理を行います。
##
##   @param str
##   @param index
##   @param[opt] opts
##   @var[out] ret
##     GraphemeCulsterBreak 値を返します。
##   @var[out,opt] shift
##     opts に shift が指定された時に対象の code point の文字数を返します。
##     surrogate pair の時に 2 になります。それ以外の時は 1 です。
##   @var[out,opt] code
##     opts に code が指定された時に対象の code point を返します。
##
## * Note2 (#D1881): ${s:i-1:2} 等として 2 文字切り出すのは、Cygwin では
##   ${s:i-1:1} として最初の文字を切り出そうとすると UCS-2 に入らない code
##   point の文字が破壊されてしまって surrogate 前半すら取り出せなくなる為。少
##   なくとも wchar_t*2 の分だけ渡せば printf %d '$1 で surrogate 前半の code
##   point を取り出す事ができる。
function ble/unicode/GraphemeCluster/s2break-left {
  ret=0
  local s=$1 N=${#1} i=$2 opts=$3 sh=1
  ((i>0)) && ble/util/s2c "${s:i-1:2}"; local c=$ret code2=$ret # Note2 (上述)
  ble/unicode/GraphemeCluster/c2break "$code2"; local break=$ret

  # process surrogate pairs
  ((i-1<N)) && ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG "$code2"
  if ((i-2>=0&&ret==_ble_unicode_GraphemeClusterBreak_LowSurrogate)); then
    ble/util/s2c "${s:i-2:2}"; local code1=$ret # Note2 (上述)
    ble/unicode/GraphemeCluster/c2break "$code1"
    ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF "$code1"
    if ((ret==_ble_unicode_GraphemeClusterBreak_HighSurrogate)); then
      ble/unicode/GraphemeCluster/s2break/.combine-surrogate "$code1" "$code2" "${s:i-2:2}"
      ble/unicode/GraphemeCluster/c2break "$c"
      break=$ret
      sh=2
    fi
  elif ((i<N)) && ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF "$code2"; then
    # 壊れた前半サロゲートの可能性があるので次の文字を確認して break を確定する。
    # (Note: 壊れたサロゲートペアの場合には UTF-8 4B 表現になる事はないので
    # Cygwin で code_next==0 になる可能性は考えなくて良い。)
    ble/util/s2c "${s:i:1}"; local code_next=$ret
    ble/unicode/GraphemeCluster/c2break "$code_next"
    ((ret==_ble_unicode_GraphemeClusterBreak_LowSurrogate)) &&
      break=$_ble_unicode_GraphemeClusterBreak_HighSurrogate
  fi

  [[ :$opts: == *:shift:* ]] && shift=$sh
  [[ :$opts: == *:code:* ]] && code=$c
  ret=$break
}
function ble/unicode/GraphemeCluster/s2break-right {
  ret=0
  local s=$1 N=${#1} i=$2 opts=$3 sh=1
  ble/util/s2c "${s:i:2}"; local c=$ret code1=$ret # Note2 (上述)
  ble/unicode/GraphemeCluster/c2break "$code1"; local break=$ret

  # process surrogate pairs
  ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF "$code1"
  if ((i+1<N&&ret==_ble_unicode_GraphemeClusterBreak_HighSurrogate)); then
    ble/util/s2c "${s:i+1:1}"; local code2=$ret
    ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG "$code2" ||
      ble/unicode/GraphemeCluster/c2break "$code2"

    if ((ret==_ble_unicode_GraphemeClusterBreak_LowSurrogate)); then
      ble/unicode/GraphemeCluster/s2break/.combine-surrogate "$code1" "$code2" "${s:i:2}"
      ble/unicode/GraphemeCluster/c2break "$c"
      break=$ret
      sh=2
    fi
  elif ((0<i&&i<N)) && ble/unicode/GraphemeCluster/s2break/.wa-cygwin-LSG "$code1"; then
    # Note #D1881: Cygwin では UCS-2 に入らない code point の surrogate 後半を
    # s2c で取ろうとしても 0 になってしまうので code1==0 の時は念入りに調べる。
    # 前に HighSurrogate がない時は通常文字と同様に取り扱って問題ない。
    ble/util/s2c "${s:i-1:1}"; local code_prev=$ret
    ble/unicode/GraphemeCluster/c2break "$code_prev"
    ble/unicode/GraphemeCluster/s2break/.wa-bash43bug-uFFFF "$code_prev"
    if ((ret==_ble_unicode_GraphemeClusterBreak_HighSurrogate)); then
      break=$_ble_unicode_GraphemeClusterBreak_LowSurrogate
      if [[ :$opts: == *:code:* ]]; then
        ble/util/s2bytes "${s:i-1:2}"
        ble/encoding:UTF-8/b2c "${ret[@]}"
        ((c=0xDC00|ret&0x3FF))
      else
        c=0
      fi
    fi
  fi

  [[ :$opts: == *:shift:* ]] && shift=$sh
  [[ :$opts: == *:code:* ]] && code=$c
  ret=$break
}

## @fn ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ
##   @var[in] text i
##   @var[out] ret
function ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ {
  if [[ :$bleopt_emoji_opts: != *:zwj:* ]]; then
    ((ret=i))
    return 0
  fi

  local j=$((i-1)) shift=1
  for ((j=i-1;j>0;j-=shift)); do
    ble/unicode/GraphemeCluster/s2break-left "$text" "$j" shift
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
    ((i=j-shift,b1=ret))
    return 1
  fi
}
## @fn ble/unicode/GraphemeCluster/find-previous-boundary/.RI
##   @var[in] text i shift
##   @var[out] ret
function ble/unicode/GraphemeCluster/find-previous-boundary/.RI {
  if [[ :$bleopt_emoji_opts: != *:ri:* ]]; then
    ((ret=i))
    return 0
  fi
  local j1=$((i-shift))
  local j shift=1 countRI=1
  for ((j=j1;j>0;j-=shift,countRI++)); do
    ble/unicode/GraphemeCluster/s2break-left "$text" "$j" shift
    ((ret==_ble_unicode_GraphemeClusterBreak_Regional_Indicator)) || break
  done

  if ((j==j1)); then
    ((i=j,b1=_ble_unicode_GraphemeClusterBreak_Regional_Indicator))
    return 1
  else
    ((ret=countRI%2==1?j1:i))
    return 0
  fi
}
function ble/unicode/GraphemeCluster/find-previous-boundary {
  local text=$1 i=$2 shift
  if [[ $bleopt_grapheme_cluster ]] && ((i&&--i)); then
    ble/unicode/GraphemeCluster/s2break-right "$text" "$i" shift; local b1=$ret
    while ((i>0)); do
      local b2=$b1
      ble/unicode/GraphemeCluster/s2break-left "$text" "$i" shift; local b1=$ret
      case ${_ble_unicode_GraphemeClusterBreak_rule[b1*_ble_unicode_GraphemeClusterBreak_Count+b2]} in
      (0) break ;;
      (1) ((i-=shift)) ;;
      (2) [[ $bleopt_grapheme_cluster != extended ]] && break; ((i-=shift)) ;;
      (3) ble/unicode/GraphemeCluster/find-previous-boundary/.ZWJ && return 0 ;;
      (4) ble/unicode/GraphemeCluster/find-previous-boundary/.RI && return 0 ;;
      (5)
        # surrogate pair の間にいた時は GraphemeClusterBreak を取得し直す
        ((i-=shift))
        ble/unicode/GraphemeCluster/s2break-right "$text" "$i"; b1=$ret ;;
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
_ble_unicode_GraphemeClusterBreak_isCore[_ble_unicode_GraphemeClusterBreak_HighSurrogate]=1

## @fn ble/unicode/GraphemeCluster/extend-ascii text i
##   @var[out] extend
function ble/unicode/GraphemeCluster/extend-ascii {
  extend=0
  [[ $_ble_util_locale_encoding != UTF-8 || ! $bleopt_grapheme_cluster ]] && return 1
  local text=$1 iN=${#1} i=$2 ret shift=1
  for ((;i<iN;i+=shift,extend+=shift)); do
    ble/unicode/GraphemeCluster/s2break-right "$text" "$i" shift
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
      ble/util/c2s "$((c+64))"
      cs=^$ret
    elif ((c==127)); then
      cs=^?
    elif ((128<=c&&c<160)); then
      ble/util/c2s "$((c-64))"
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
  elif ! ble/util/is-unicode-output || [[ ! $bleopt_grapheme_cluster ]]; then
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

  local b0 b1 b2 c0 c2 shift code
  ble/unicode/GraphemeCluster/s2break-right "$text" "$i" code:shift; c0=$code b0=$ret

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

    ((j+=shift))
    b1=$b2
    ble/unicode/GraphemeCluster/s2break-right "$text" "$j" code:shift; c2=$code b2=$ret
    case ${_ble_unicode_GraphemeClusterBreak_rule[b1*_ble_unicode_GraphemeClusterBreak_Count+b2]} in
    (0) break ;;
    (1) continue ;;
    (2) [[ $bleopt_grapheme_cluster != extended ]] && break ;;
    (3) [[ :$bleopt_emoji_opts: == *:zwj:* ]] &&
          ((coreb==_ble_unicode_GraphemeClusterBreak_Pictographic)) || break ;;
    (4) [[ :$bleopt_emoji_opts: == *:ri:* && ! $ri ]] || break; ri=1 ;;
    (5)
      # surrogate pair の間にいた時は GraphemeClusterBreak を取得し直す
      ble/unicode/GraphemeCluster/s2break-left "$text" "$((j+shift))" code; c2=$code b2=$ret ;;
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
      local code
      ble/unicode/GraphemeCluster/s2break-right "$cs" 0 code
      c=$code corec=$code cb=$ret
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
  ble/util/c2w:auto/check
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
    esc=${_ble_term_ech//'%d'/$value}
  else
    ble/string#reserve-prototype "$value"
    esc=${_ble_string_prototype::value}${_ble_term_cub//'%d'/$value}
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
    ble/canvas/put-cub.draw "$((-dx))"
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
    ble/canvas/put-cuu.draw "$((-dy))"
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
  local _ble_local_var=ret
  [[ $1 == -v ]] && _ble_local_var=$2
  IFS= builtin eval "$_ble_local_var=\"\${DRAW_BUFF[*]}\""
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
      ble/canvas/put-move.draw "$((dstx-x))" "$((dsty-y))"
    else
      ble/canvas/put-cup.draw "$((dsty+1))" "$((dstx+1))"
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
      # [Note: 文字が横幅より大きい場合は取り敢えず次の行が一杯になると仮定して
      # いるが端末による。端末によっては更に次の行にカーソルが移動するのではな
      # いかとも思われる。]
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
    ble/canvas/put-move.draw "$((x-cx))" "$((y-cy))"
    ble/canvas/put.draw "$c"
    ((cx+=x+w,cy=y))
  else
    ble/canvas/put.draw "$c"
  fi

  ble/canvas/trace/.implicit-move "$w" atomic
}
function ble/canvas/trace/.put-ascii.draw {
  local value=$1 w=${#1}
  [[ $value ]] || return 0

  if [[ $flag_clip ]]; then
    local xL=$x xR=$((x+w))
    ((xR<=cx1||cx2<=xL||y+1<=cy1||cy2<=y)) && return 0
    if [[ $cg != "$g" ]]; then
      ble/canvas/trace/.put-sgr.draw "$g"
      cg=$g
    fi
    ((xL<cx1)) && value=${value:cx1-xL} xL=$cx1
    ((xR>cx2)) && value=${value::${#value}-(xR-cx2)} xR=$cx2
    ble/canvas/put-move.draw "$((x-cx))" "$((y-cy))"
    ble/canvas/put.draw "$value"
    ((cx=xR,cy=y))
  else
    ble/canvas/put.draw "$value"
  fi

  ble/canvas/trace/.implicit-move "$w"
}
function ble/canvas/trace/.process-overflow {
  [[ :$opts: == *:truncate:* ]] && i=$iN # stop
  if ((y+1==lines)) && [[ :$opts: == *:ellipsis:* ]]; then
    local ellipsis=... w=3 wmax=$xlimit
    ((w>wmax)) && ellipsis=${ellipsis::wmax} w=$wmax
    if ble/util/is-unicode-output; then
      local symbol='…' ret
      ble/util/s2c "$symbol"
      ble/util/c2w "$ret"
      ((ret<=wmax)) && ellipsis=$symbol w=$ret
    fi

    local ox=$x oy=$y
    ble/canvas/trace/.goto "$((wmax-w))" "$((lines-1))"
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
  if [[ ! $has_content ]]; then
    justify_fields=()
    return 0
  fi

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
        ble/canvas/put-move-x.draw "$((cols-1-x))"
        ((x=cols-1))
      fi
    fi

    if [[ $esc ]]; then
      local delta=0
      ((vx+x1-xI<0)) && ((delta=-(vx+x1-xI)))
      ((vx+x2-xI>xlimit)) && ((delta=xlimit-(vx+x2-xI)))
      ble/canvas/put-move-x.draw "$((vx+delta-x))"
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
      ble/canvas/put-move.draw "$((trace_decsc[0]-x))" "$((trace_decsc[1]-y))"
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
      ble/canvas/put-move.draw "$((trace_scosc[0]-x))" "$((trace_scosc[1]-y))"
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
      [[ $param =~ ^[0-9]+$ ]] && ((arg=10#0$param))
      ((arg==0&&(arg=1)))

      local ox=$x oy=$y
      if [[ $char == A ]]; then
        # CUU "CSI A"
        ((y-=arg,y<0&&(y=0)))
        ((!flag_clip&&y<oy)) && ble/canvas/put-cuu.draw "$((oy-y))"
      elif [[ $char == [Be] ]]; then
        # CUD "CSI B"
        # VPR "CSI e"
        ((y+=arg,y>=lines&&(y=lines-1)))
        ((!flag_clip&&y>oy)) && ble/canvas/put-cud.draw "$((y-oy))"
      elif [[ $char == [Ca] ]]; then
        # CUF "CSI C"
        # HPR "CSI a"
        ((x+=arg,x>=cols&&(x=cols-1)))
        ((!flag_clip&&x>ox)) && ble/canvas/put-cuf.draw "$((x-ox))"
      elif [[ $char == D ]]; then
        # CUB "CSI D"
        ((x-=arg,x<0&&(x=0)))
        ((!flag_clip&&x<ox)) && ble/canvas/put-cub.draw "$((ox-x))"
      elif [[ $char == E ]]; then
        # CNL "CSI E"
        ((y+=arg,y>=lines&&(y=lines-1),x=0))
        if [[ ! $flag_clip ]]; then
          ((y>oy)) && ble/canvas/put-cud.draw "$((y-oy))"
          ble/canvas/put.draw "$_ble_term_cr"
        fi
      elif [[ $char == F ]]; then
        # CPL "CSI F"
        ((y-=arg,y<0&&(y=0),x=0))
        if [[ ! $flag_clip ]]; then
          ((y<oy)) && ble/canvas/put-cuu.draw "$((oy-y))"
          ble/canvas/put.draw "$_ble_term_cr"
        fi
      elif [[ $char == [G\`] ]]; then
        # CHA "CSI G"
        # HPA "CSI `"
        ((x=arg-1,x<0&&(x=0),x>=cols&&(x=cols-1)))
        if [[ ! $flag_clip ]]; then
          if [[ $opt_relative ]]; then
            ble/canvas/put-move-x.draw "$((x-ox))"
          else
            ble/canvas/put-hpa.draw "$((x+1))"
          fi
        fi
      elif [[ $char == d ]]; then
        # VPA "CSI d"
        ((y=arg-1,y<0&&(y=0),y>=lines&&(y=lines-1)))
        if [[ ! $flag_clip ]]; then
          if [[ $opt_relative ]]; then
            ble/canvas/put-move-y.draw "$((y-oy))"
          else
            ble/canvas/put-vpa.draw "$((y+1))"
          fi
        fi
      elif [[ $char == I ]]; then
        # CHT "CSI I"
        local tx
        ((tx=(x/it+arg)*it,
          tx>=cols&&(tx=cols-1)))
        if ((tx>x)); then
          [[ $flag_clip ]] || ble/canvas/put-cuf.draw "$((tx-x))"
          ((x=tx))
        fi
      elif [[ $char == Z ]]; then
        # CHB "CSI Z"
        local tx
        ((tx=((x+it-1)/it-arg)*it,
          tx<0&&(tx=0)))
        if ((tx<x)); then
          [[ $flag_clip ]] || ble/canvas/put-cub.draw "$((x-tx))"
          ((x=tx))
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
      params=("${params[@]/#/10#0}") # WA #D1570 checked (is-array)
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
        ble/canvas/put-hpa.draw "$((x+1))" # tput ind が唯の改行の時がある
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
  local xenl=$_ble_term_xenl
  [[ $opt_relative || $trace_flags == *J* ]] && xenl=1
  local xlimit=$((xenl?cols:cols-1))

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
      case $s in
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
        local tx
        ((tx=(x+it)/it*it,
          tx>=cols&&(tx=cols-1)))
        if ((x<tx)); then
          ((lc=32,lg=g))
          ble/canvas/trace/.put-ascii.draw "${_ble_string_prototype::tx-x}"
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
            ble/canvas/put-move-x.draw "$((jx0-ox))"
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
  ((nput==nchar)); return "$?"
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
      ble/string#reserve-prototype "$((cols-x))"
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
    ble/string#reserve-prototype "$((limit-x))"
    local pad=${_ble_string_prototype::limit-x}
    out=$out$sgr1${pad//?/'#'}$sgr0
    x=$limit
    ((y+1<lines)); return "$?"
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
    # Note #D1745: 自動改行は CR で表現する事にする。この CR は実際の
    # 出力時に LF または空文字列に置換する。
    cs=$cs$_ble_term_cr
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
  local pos0="$x $y"
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
    _ble_textmap_pos[0]=$pos0
  elif [[ ${_ble_textmap_pos[0]} != "$pos0" ]]; then
    # 初期位置の変更がある場合は初めから計算し直し
    ((dbeg<0&&(dend=dend0=0),
      dbeg=0))
    _ble_textmap_pos[0]=$pos0
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
                eraser=${_ble_string_prototype::pad}
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
            # Note #D1745: 自動改行は CR で表現する事にする。この CR
            # は実際の出力時に LF または空文字列に置換する。
            cs=$_ble_term_cr$cs
          fi
          local pad=$((cols-x))
          if ((pad)); then
            if [[ $_ble_term_ech ]]; then
              cs=${_ble_term_ech//'%d'/$pad}$cs
            else
              cs=${_ble_string_prototype::pad}$cs
            fi
          fi
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
  local _ble_local_prefix=
  if [[ $1 == --prefix=* ]]; then
    _ble_local_prefix=${1#--prefix=}
    shift
  fi

  local -a pos
  ble/string#split-words pos "${_ble_textmap_pos[$1]}"
  ((${_ble_local_prefix}x=pos[0]))
  ((${_ble_local_prefix}y=pos[1]))
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
  local _ble_local_prefix=
  if [[ $1 == --prefix=* ]]; then
    _ble_local_prefix=${1#--prefix=}
    shift
  fi

  local -a pos
  ble/string#split-words pos "${_ble_textmap_pos[$1]}"

  # 追い出しされたか check
  if (($1<_ble_textmap_length)); then
    local -a eoc
    ble/string#split-words eoc "${_ble_textmap_pos[$1+1]}"
    ((eoc[2])) && ((pos[0]=0,pos[1]++))
  fi

  ((${_ble_local_prefix}x=pos[0]))
  ((${_ble_local_prefix}y=pos[1]))
}

## @fn ble/textmap#get-index-at [-v varname] x y
##   指定した位置 x y に対応する index を求めます。
function ble/textmap#get-index-at {
  ble/textmap#assert-up-to-date
  local __ble_var=index
  if [[ $1 == -v ]]; then
    __ble_var=$2
    shift 2
  fi

  local __ble_x=$1 __ble_y=$2
  if ((__ble_y>_ble_textmap_endy)); then
    (($__ble_var=_ble_textmap_length))
  elif ((__ble_y<_ble_textmap_begy)); then
    (($__ble_var=0))
  else
    # 2分法
    local __ble_l=0 __ble_u=$((_ble_textmap_length+1))
    local m mx my
    while ((__ble_l+1<__ble_u)); do
      ble/textmap#getxy.cur --prefix=m "$((m=(__ble_l+__ble_u)/2))"
      (((__ble_y<my||__ble_y==my&&__ble_x<mx)?(__ble_u=m):(__ble_l=m)))
    done
    ble/util/unlocal m mx my
    (($__ble_var=__ble_l))
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
      "$getxy" "$((m=(l+u)/2))"
      (((yh<y||yh==y&&xh<x)?(u=m):(l=m)))
    done
    "$getxy" "$((index=l))"
    lx=$x ly=$y
    (((ly<yh||ly==yh&&lx<xh)&&index<end)) && "$getxy" "$((index+1))"
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

  ble/canvas/put-move-y.draw "$((y-_ble_canvas_y))"

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
  [[ $_ble_canvas_excursion ]] && return 1
  _ble_canvas_excursion=1
  _ble_canvas_excursion_x=$_ble_canvas_x
  _ble_canvas_excursion_y=$_ble_canvas_y
  ble/canvas/put.draw "$_ble_term_sc"
}
function ble/canvas/excursion-end.draw {
  [[ $_ble_canvas_excursion ]] || return 1
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
  ble/canvas/goto.draw "$x" "$((ret+y))" "$opts"
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
      ble/canvas/goto.draw 0 "$((top_height==0?0:top_height-1))" sgr0
      ble/canvas/put-ind.draw "$((top_height-1+delta-_ble_canvas_y))"
      ((_ble_canvas_y=top_height-1+delta))
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw "$_ble_term_DECSTBM_reset"
      ble/canvas/excursion-end.draw
      return 0
    else
      ble/canvas/panel/bottom-dock#invalidate
    fi
  fi

  local old_height=$((top_height+bottom_height))
  local new_height=$((old_height+delta))
  ble/canvas/goto.draw 0 "$((top_height==0?0:top_height-1))" sgr0
  ble/canvas/put-ind.draw "$((new_height-1-_ble_canvas_y))"; ((_ble_canvas_y=new_height-1))
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
      return "$?"
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
  ble/canvas/panel#set-height.draw "$index" "$((_ble_canvas_panel_height[index]+delta))" "$opts"
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
      ble/canvas/put-hpa.draw "$((x+1))"
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
    ble/array#fill-range _ble_canvas_panel_height 0 "${#_ble_canvas_panel_height[@]}" 0
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
        ble/canvas/put-ind.draw "$((top_height-1+tmargin))"
        ble/canvas/put-cuu.draw "$((top_height-1+tmargin))"
        ble/canvas/excursion-start.draw
        ble/canvas/put-cup.draw 1 1
        ble/canvas/put-il.draw "$tmargin" no-lastline
        ble/canvas/excursion-end.draw
      fi
      ble/canvas/excursion-start.draw
      ble/canvas/put.draw "$_ble_term_DECSTBM_reset"
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
    ble/canvas/put-ind.draw "$((total_height-1+tmargin))"
    ble/canvas/put-cuu.draw "$((total_height-1+tmargin))"
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
