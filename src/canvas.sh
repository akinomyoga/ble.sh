#!/bin/bash

## オプション tab_width
##   タブの表示幅を指定します。
##
##   bleopt_tab_width= (既定)
##     空文字列を指定したときは $(tput it) を用います。
##   bleopt_tab_width=NUM
##     数字を指定したときはその値をタブの幅として用います。
: ${bleopt_tab_width:=}

function bleopt/check:tab_width {
  if [[ $value ]] && (((value=value)<=0)); then
    echo "bleopt: an empty string or a positive value is required for tab_width." >&2
    return 1
  fi
}

#------------------------------------------------------------------------------
# ble/arithmetic

function ble/arithmetic/sum {
  IFS=+ eval 'let "ret=$*+0"'
}

#------------------------------------------------------------------------------
# ble/util/c2w

# ※注意 [ -~] の範囲の文字は全て幅1であるという事を仮定したコードが幾らかある
#   もしこれらの範囲の文字を幅1以外で表示する端末が有ればそれらのコードを実装し
#   直す必要がある。その様な変な端末があるとは思えないが。

## オプション char_width_mode
##   文字の表示幅の計算方法を指定します。
## bleopt_char_width_mode=east
##   Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 2 とします
## bleopt_char_width_mode=west
##   Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 1 とします
## bleopt_char_width_mode=emacs
##   emacs で用いられている既定の文字幅の設定です
## 定義 ble/util/c2w+$bleopt_char_width_mode
: ${bleopt_char_width_mode:=east}
: ${bleopt_emoji_width:=2}

function bleopt/check:char_width_mode {
  if ! ble/is-function "ble/util/c2w+$value"; then
    echo "bleopt: Invalid value char_width_mode='$value'. A function 'ble/util/c2w+$value' is not defined." >&2
    return 1
  fi
}

_ble_util_c2w_table=()

## 関数 ble/util/c2w ccode
##   @var[out] ret
function ble/util/c2w {
  # ret=${_ble_util_c2w_table[$1]}
  # [[ $ret ]] && return
  "ble/util/c2w+$bleopt_char_width_mode" "$1"
  # _ble_util_c2w_table[$1]=$ret
}
## 関数 ble/util/c2w-edit ccode
##   編集画面での表示上の文字幅を返します。
##   @var[out] ret
function ble/util/c2w-edit {
  if (($1<32||127<=$1&&$1<160)); then
    # 制御文字は ^? と表示される。
    ret=2
    # TAB は???

    # 128-159: M-^?
    ((128<=$1&&(ret=4)))
  else
    ble/util/c2w "$1"
  fi
}
# ## 関数 ble/util/c2w-edit ccode
# ##   @var[out] ret
# function ble/util/s2w {
#   ble/util/s2c "$1" "$2"
#   "ble/util/c2w+$bleopt_char_width_mode" "$ret"
# }

# ---- 文字種判定 -------------------------------------------------------------

## 配列 _ble_util_c2w_non_zenkaku
##   飛び地になっている全角でない文字
_ble_util_c2w_non_zenkaku=(
  [0x303F]=1 # 半角スペース
  [0x3030]=-2 [0x303d]=-2 [0x3297]=-2 [0x3299]=-2 # 絵文字
)
## 関数 ble/util/c2w/.determine-unambiguous
##   @var[out] ret
function ble/util/c2w/.determine-unambiguous {
  local code=$1
  if ((code<0xA0)); then
    ret=1
    return
  fi

  # 取り敢えず曖昧
  ret=-1

  # 以下は全角に確定している範囲
  if ((code<0xFB00)); then
    ((0x2E80<=code&&code<0xA4D0&&!_ble_util_c2w_non_zenkaku[code]||
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

## 配列 _ble_util_c2w_emoji_wranges
##
##   https://github.com/vim-jp/issues/issues/1086 にある表を
##   以下の関数で加工した。
##
##   function process {
##     local begin=$1 end=$(($2+1))
##     printf ' %s %s' "$begin" "$end"
##   }
##
_ble_util_c2w_emoji_wranges=(
  8252 8253 8265 8266 8482 8483 8505 8506 8596 8602 8617 8619 8986 8988
  9000 9001 9167 9168 9193 9204 9208 9211 9410 9411 9642 9644 9654 9655
  9664 9665 9723 9727 9728 9733 9742 9743 9745 9746 9748 9750 9752 9753
  9757 9758 9760 9761 9762 9764 9766 9767 9770 9771 9774 9776 9784 9787
  9792 9793 9794 9795 9800 9812 9824 9825 9827 9828 9829 9831 9832 9833
  9851 9852 9855 9856 9874 9880 9881 9882 9883 9885 9888 9890 9898 9900
  9904 9906 9917 9919 9924 9926 9928 9929 9934 9936 9937 9938 9939 9941
  9961 9963 9968 9974 9975 9979 9981 9982 9986 9987 9989 9990 9992 9998
  9999 10000 10002 10003 10004 10005 10006 10007 10013 10014 10017 10018
  10024 10025 10035 10037 10052 10053 10055 10056 10060 10061 10062 10063
  10067 10070 10071 10072 10083 10085 10133 10136 10145 10146 10160 10161
  10175 10176 10548 10550 11013 11016 11035 11037 11088 11089 11093 11094
  # 12336 12337 12349 12350 12951 12952 12953 12954 これらは特別に処理する。
  126980 126981
  127183 127184 127344 127346 127358 127360 127374 127375 127377 127387
  127462 127488 127489 127491 127514 127515 127535 127536 127538 127547
  127568 127570 127744 127778 127780 127892 127894 127896 127897 127900
  127902 127985 127987 127990 127991 128254 128255 128318 128329 128335
  128336 128360 128367 128369 128371 128379 128391 128392 128394 128398
  128400 128401 128405 128407 128420 128422 128424 128425 128433 128435
  128444 128445 128450 128453 128465 128468 128476 128479 128481 128482
  128483 128484 128488 128489 128495 128496 128499 128500 128506 128592
  128640 128710 128715 128723 128736 128742 128745 128746 128747 128749
  128752 128753 128755 128761 129296 129339 129340 129343 129344 129350
  129351 129357 129360 129388 129408 129432 129472 129473 129488 129511)

## 関数 ble/util/c2w/is-emoji code
##   @param[in] code
function ble/util/c2w/is-emoji {
  local code=$1
  ((8252<=code&&code<=0x2b55||0x1f004<code&&code<=0x1f9e6)) || return 1

  # 0x3030 - 0x3299
  ((0x3030<=code&&code<=0x3299&&_ble_util_c2w_non_zenkaku[code]!=-2)) && return 1

  local l=0 u=${#_ble_util_c2w_emoji_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_emoji_wranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done

  (((l&1)==0)); return
}

# ---- char_width_mode ---------------------------------------------------------

## 関数 ble/util/c2w+emacs
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
  ((code<0xA0)) && return

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
    return
  fi

  (('
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
  '))

  [[ $tIndex ]] || return 0

  if ((tIndex<_ble_util_c2w_emacs_wranges[0])); then
    ret=1
    return
  fi

  local l=0 u=${#_ble_util_c2w_emacs_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_emacs_wranges[m=(l+u)/2]<=tIndex?(l=m):(u=m)))
  done
  ((ret=((l&1)==0)?2:1))
  return 0
}

## 関数 ble/util/c2w+west
##   @var[out] ret
function ble/util/c2w+west {
  ble/util/c2w/.determine-unambiguous "$1"
  if ((ret<0)); then
    if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
      ((ret=bleopt_emoji_width))
    else
      ((ret=1))
    fi
  fi
}

## 関数 ble/util/c2w+east
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
  ((ret>=0)) && return

  if [[ $bleopt_emoji_width ]] && ble/util/c2w/is-emoji "$1"; then
    ((ret=bleopt_emoji_width))
    return
  fi

  local code=$1
  if ((code<_ble_util_c2w_east_wranges[0])); then
    ret=1
    return
  fi

  local l=0 u=${#_ble_util_c2w_east_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_util_c2w_east_wranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done
  ((ret=((l&1)==0)?2:1))
}

#------------------------------------------------------------------------------
# ble/canvas

function ble/canvas/put.draw {
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$*"
}
function ble/canvas/put-ind.draw {
  local count=${1-1}
  local ret; ble/string#repeat "${_ble_term_ind}" "$count"
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret
}
function ble/canvas/put-il.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_il//'%d'/$value}
}
function ble/canvas/put-dl.draw {
  local value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
}
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
function ble/canvas/flush.draw {
  IFS= builtin eval 'builtin echo -n "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}
## 関数 ble/canvas/sflush.draw [-v var]
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

## 関数 ble/canvas/trace.draw text
##   制御シーケンスを含む文字列を出力すると共にカーソル位置の移動を計算します。
##
##   @param[in]   text
##     出力する (制御シーケンスを含む) 文字列を指定します。
##   @var[in,out] DRAW_BUFF[]
##     出力先の配列を指定します。
##   @var[in,out] x y g
##     出力の開始位置を指定します。出力終了時の位置を返します。
##   @var[in,out] lc lg
##     bleopt_internal_suppress_bash_output= の時、
##     出力開始時のカーソル左の文字コードを指定します。
##     出力終了時のカーソル左の文字コードが分かる場合にそれを返します。
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

function ble/canvas/trace/.SC {
  trace_scosc="$x $y $g $lc $lg"
  ble/canvas/put.draw "$_ble_term_sc"
}
function ble/canvas/trace/.RC {
  local -a scosc
  scosc=($trace_scosc)
  x=${scosc[0]}
  y=${scosc[1]}
  g=${scosc[2]}
  lc=${scosc[3]}
  lg=${scosc[4]}
  ble/canvas/put.draw "$_ble_term_rc"
}
function ble/canvas/trace/.NEL {
  ble/canvas/put.draw "$_ble_term_cr"
  ble/canvas/put.draw "$_ble_term_nl"
  ((y++,x=0,lc=32,lg=0))
}
## 関数 ble/canvas/trace/.SGR/arg_next
##   @var[in    ] f
##   @var[in,out] j
##   @var[   out] arg
function ble/canvas/trace/.SGR/arg_next {
  local _var=arg _ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  if ((j<${#f[*]})); then
    _ret=${f[j++]}
  else
    ((i++))
    _ret=${specs[i]%%:*}
  fi

  (($_var=_ret))
}
## 関数 ble/canvas/trace/.SGR
##   @param[in] param seq
##   @var[out] DRAW_BUFF
##   @var[in,out] g
function ble/canvas/trace/.SGR {
  local param=$1 seq=$2 specs i iN
  if [[ ! $param ]]; then
    g=0
    ble/canvas/put.draw "$_ble_term_sgr0"
    return
  fi

  # update g
  ble/color/read-sgrspec "$param" ansi

  local ret
  ble-color-g2sgr "$g"
  ble/canvas/put.draw "$ret"
}
function ble/canvas/trace/.process-csi-sequence {
  local seq=$1 seq1=${1:2} rex
  local char=${seq1:${#seq1}-1:1} param=${seq1::${#seq1}-1}
  if [[ ! ${param//[0-9:;]} ]]; then
    # CSI 数字引数 + 文字
    case "$char" in
    (m) # SGR
      ble/canvas/trace/.SGR "$param" "$seq"
      return ;;
    ([ABCDEFGIZ\`ade])
      local arg=0
      [[ $param =~ ^[0-9]+$ ]] && arg=$param
      ((arg==0&&(arg=1)))

      local x0=$x y0=$y
      if [[ $char == A ]]; then
        # CUU "CSI A"
        ((y-=arg,y<0&&(y=0)))
        ((y<y0)) && ble/canvas/put-cuu.draw $((y0-y))
      elif [[ $char == [Be] ]]; then
        # CUD "CSI B"
        # VPR "CSI e"
        ((y+=arg,y>=lines&&(y=lines-1)))
        ((y>y0)) && ble/canvas/put-cud.draw $((y-y0))
      elif [[ $char == [Ca] ]]; then
        # CUF "CSI C"
        # HPR "CSI a"
        ((x+=arg,x>=cols&&(x=cols-1)))
        ((x>x0)) && ble/canvas/put-cuf.draw $((x-x0))
      elif [[ $char == D ]]; then
        # CUB "CSI D"
        ((x-=arg,x<0&&(x=0)))
        ((x<x0)) && ble/canvas/put-cub.draw $((x0-x))
      elif [[ $char == E ]]; then
        # CNL "CSI E"
        ((y+=arg,y>=lines&&(y=lines-1),x=0))
        ((y>y0)) && ble/canvas/put-cud.draw $((y-y0))
        ble/canvas/put.draw "$_ble_term_cr"
      elif [[ $char == F ]]; then
        # CPL "CSI F"
        ((y-=arg,y<0&&(y=0),x=0))
        ((y<y0)) && ble/canvas/put-cuu.draw $((y0-y))
        ble/canvas/put.draw "$_ble_term_cr"
      elif [[ $char == [G\`] ]]; then
        # CHA "CSI G"
        # HPA "CSI `"
        ((x=arg-1,x<0&&(x=0),x>=cols&&(x=cols-1)))
        ble/canvas/put-hpa.draw $((x+1))
      elif [[ $char == d ]]; then
        # VPA "CSI d"
        ((y=arg-1,y<0&&(y=0),y>=lines&&(y=lines-1)))
        ble/canvas/put-vpa.draw $((y+1))
      elif [[ $char == I ]]; then
        # CHT "CSI I"
        local _x
        ((_x=(x/it+arg)*it,
          _x>=cols&&(_x=cols-1)))
        if ((_x>x)); then
          ble/canvas/put-cuf.draw $((_x-x))
          ((x=_x))
        fi
      elif [[ $char == Z ]]; then
        # CHB "CSI Z"
        local _x
        ((_x=((x+it-1)/it-arg)*it,
          _x<0&&(_x=0)))
        if ((_x<x)); then
          ble/canvas/put-cub.draw $((x-_x))
          ((x=_x))
        fi
      fi
      lc=-1 lg=0
      return ;;
    ([Hf])
      # CUP "CSI H"
      # HVP "CSI f"
      local -a params
      params=(${param//[^0-9]/ })
      ((x=params[1]-1))
      ((y=params[0]-1))
      ((x<0&&(x=0),x>=cols&&(x=cols-1),
        y<0&&(y=0),y>=lines&&(y=lines-1)))
      ble/canvas/put-cup.draw $((y+1)) $((x+1))
      lc=-1 lg=0
      return ;;
    ([su]) # SCOSC SCORC
      if [[ $param == 99 ]]; then
        # PS1 の \[ ... \] の処理。
        # ble-edit/prompt/update で \e[99s, \e[99u に変換している。
        if [[ $char == s ]]; then
          trace_brack[${#trace_brack[*]}]="$x $y"
        else
          local lastIndex=$((${#trace_brack[*]}-1))
          if ((lastIndex>=0)); then
            local -a scosc
            scosc=(${trace_brack[lastIndex]})
            ((x=scosc[0]))
            ((y=scosc[1]))
            unset -v "trace_brack[$lastIndex]"
          fi
        fi
        return
      else
        if [[ $char == s ]]; then
          ble/canvas/trace/.SC
        else
          ble/canvas/trace/.RC
        fi
        return
      fi ;;
    # ■その他色々?
    # ([JPX@MKL]) # 挿入削除→カーソルの位置は不変 lc?
    # ([hl]) # SM RM DECSM DECRM
    esac
  fi

  ble/canvas/put.draw "$seq"
}
function ble/canvas/trace/.process-esc-sequence {
  local seq=$1 char=${1:1}
  case "$char" in
  (7) # DECSC
    ble/canvas/trace/.SC
    return ;;
  (8) # DECRC
    ble/canvas/trace/.RC
    return ;;
  (D) # IND
    ((y++))
    ble/canvas/put.draw "$_ble_term_ind"
    [[ $_ble_term_ind != $'\eD' ]] &&
      ble/canvas/put-hpa.draw $((x+1)) # tput ind が唯の改行の時がある
    lc=-1 lg=0
    return ;;
  (M) # RI
    ((y--,y<0&&(y=0)))
    ble/canvas/put.draw "$_ble_term_ri"
    lc=-1 lg=0
    return ;;
  (E) # NEL
    ble/canvas/trace/.NEL
    lc=32 lg=0
    return ;;
  # (H) # HTS 面倒だから無視。
  # ([KL]) PLD PLU は何か?
  esac

  ble/canvas/put.draw "$seq"
}

function ble/canvas/trace/.impl {
  local text=$1

  # Note: 文字符号化方式によっては対応する文字が存在しない可能性がある。
  #   その時は st='\u009C' になるはず。2文字以上のとき変換に失敗したと見做す。
  local ret
  ble/util/c2s 156; local st=$ret #  (ST)
  ((${#st}>=2)) && st=

  # constants
  local cols=${COLUMNS:-80} lines=${LINES:-25}
  local it=${bleopt_tab_width:-$_ble_term_it} xenl=$_ble_term_xenl
  ble/string#reserve-prototype "$it"
  # CSI
  local rex_csi='^\[[ -?]*[@-~]'
  # OSC, DCS, SOS, PM, APC Sequences + "GNU screen ESC k"
  local rex_osc='^([]PX^_k])([^'$st']|+[^\'$st'])*(\\|'${st:+'|'}$st'|$)'
  # ISO-2022 関係 (3byte以上の物)
  local rex_2022='^[ -/]+[@-~]'
  # ESC ?
  local rex_esc='^[ -~]'

  # variables
  local -a trace_brack=()
  local trace_scosc=

  local i=0 iN=${#text}
  while ((i<iN)); do
    local tail=${text:i}
    local w=0
    if [[ $tail == [-]* ]]; then
      local s=${tail::1}
      ((i++))
      case "$s" in
      ('')
        if [[ $tail =~ $rex_osc ]]; then
          # 各種メッセージ (素通り)
          s=$BASH_REMATCH
          [[ ${BASH_REMATCH[3]} ]] || s="$s\\" # 終端の追加
          ((i+=${#BASH_REMATCH}-1))
        elif [[ $tail =~ $rex_csi ]]; then
          # Control sequences
          s=
          ((i+=${#BASH_REMATCH}-1))
          ble/canvas/trace/.process-csi-sequence "$BASH_REMATCH"
        elif [[ $tail =~ $rex_2022 ]]; then
          # ISO-2022 (素通り)
          s=$BASH_REMATCH
          ((i+=${#BASH_REMATCH}-1))
        elif [[ $tail =~ $rex_esc ]]; then
          s=
          ((i+=${#BASH_REMATCH}-1))
          ble/canvas/trace/.process-esc-sequence "$BASH_REMATCH"
        fi ;;
      ('') # BS
        ((x>0&&(x--,lc=32,lg=g))) ;;
      ($'\t') # HT
        local _x
        ((_x=(x+it)/it*it,
          _x>=cols&&(_x=cols-1)))
        if ((x<_x)); then
          s=${_ble_string_prototype::_x-x}
          ((x=_x,lc=32,lg=g))
        else
          s=
        fi ;;
      ($'\n') # LF = CR+LF
        s=
        ble/canvas/trace/.NEL ;;
      ('') # VT
        s=
        ble/canvas/put.draw "$_ble_term_cr"
        ble/canvas/put.draw "$_ble_term_nl"
        ((x)) && ble/canvas/put-cuf.draw "$x"
        ((y++,lc=32,lg=0)) ;;
      ($'\r') # CR ^M
        s=$_ble_term_cr
        ((x=0,lc=-1,lg=0)) ;;
      # その他の制御文字は  (BEL)  (FF) も含めてゼロ幅と解釈する
      esac
      [[ $s ]] && ble/canvas/put.draw "$s"
    elif ble/util/isprint+ "$tail"; then
      w=${#BASH_REMATCH}
      ble/canvas/put.draw "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
      if [[ ! $bleopt_internal_suppress_bash_output ]]; then
        local ret
        ble/util/s2c "$BASH_REMATCH" $((w-1))
        lc=$ret lg=$g
      fi
    else
      local w ret
      ble/util/s2c "$tail" 0
      lc=$ret lg=$g
      ble/util/c2w "$lc"
      w=$ret
      if ((w>=2&&x+w>cols)); then
        # 行に入りきらない場合の調整
        ble/canvas/put.draw "${_ble_string_prototype::x+w-cols}"
        ((x=cols))
      fi
      ble/canvas/put.draw "${tail::1}"
      ((i++))
    fi

    if ((w>0)); then
      ((x+=w,y+=x/cols,x%=cols,
        xenl&&x==0&&(y--,x=cols)))
      ((x==0&&(lc=32,lg=0)))
    fi
  done
}
function ble/canvas/trace.draw {
  # cygwin では LC_COLLATE=C にしないと
  # 正規表現の range expression が期待通りに動かない。
  LC_COLLATE=C ble/canvas/trace/.impl "$@" &>/dev/null
}

#------------------------------------------------------------------------------
# ble/textmap

_ble_textmap_VARNAMES=(_ble_textmap_{cols,length,{beg,end}{x,y},d{beg,end,end0},u{min,max}})
_ble_textmap_ARRNAMES=(_ble_textmap_{pos,glyph,ichg})

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
  ble/util/save-arrs "$prefix" "${_ble_textmap_ARRNAMES[@]}"
}
function ble/textmap#restore {
  local name prefix=$1
  ble/util/restore-vars "$prefix" "${_ble_textmap_VARNAMES[@]}"
  ble/util/restore-arrs "$prefix" "${_ble_textmap_ARRNAMES[@]}"
}

## 関数 ble/textmap#update
##   @var[in    ] text
##   @var[in,out] x y
##   @var[in,out] _ble_textmap_*
function ble/textmap#update {
  local IFS=$' \t\n'
  local dbeg dend dend0
  ((dbeg=_ble_textmap_dbeg,
    dend=_ble_textmap_dend,
    dend0=_ble_textmap_dend0))
  ble/dirty-range#clear --prefix=_ble_textmap_d

  local iN=${#text}

  # 初期位置 x y
  local _pos="$x $y"
  _ble_textmap_begx=$x
  _ble_textmap_begy=$y

  # ※現在は COLUMNS で決定しているが将来的には変更可能にする?
  local cols=${COLUMNS-80} xenl=$_ble_term_xenl
  ((COLUMNS&&cols<COLUMNS&&(xenl=1)))
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
      local -a pos
      pos=(${_ble_textmap_pos[iN]})
      ((x=pos[0]))
      ((y=pos[1]))
      _ble_textmap_endx=$x
      _ble_textmap_endy=$y
      return
    elif ((dbeg>0)); then
      # 途中から計算を再開
      local -a pos
      pos=(${_ble_textmap_pos[dbeg]})
      ((x=pos[0]))
      ((y=pos[1]))
    fi
  fi

  _ble_textmap_cols=$cols
  _ble_textmap_length=$iN

#%if !release
  ble-assert '((dbeg<0||(dbeg<=dend&&dbeg<=dend0)))' "($dbeg $dend $dend0) <- ($_ble_textmap_dbeg $_ble_textmap_dend $_ble_textmap_dend0)"
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

  local i
  for ((i=dbeg;i<iN;)); do
    if ble/util/isprint+ "${text:i}"; then
      local w=${#BASH_REMATCH}
      local n
      for ((n=i+w;i<n;i++)); do
        local cs=${text:i:1}
        if (((++x==cols)&&(y++,x=0,xenl))); then
          cs=$cs$_ble_term_nl
          ble/array#push _ble_textmap_ichg "$i"
        fi
        _ble_textmap_glyph[i]=$cs
        _ble_textmap_pos[i+1]="$x $y 0"
      done
    else
      local ret
      ble/util/s2c "$text" "$i"
      local code=$ret

      local w=0 cs= changed=0
      if ((code<32)); then
        if ((code==9)); then
          if ((x+1>=cols)); then
            cs=' '
            ((xenl)) && cs=$cs$_ble_term_nl
            changed=1
            ((y++,x=0))
          else
            local x2
            ((x2=(x/it+1)*it,
              x2>=cols&&(x2=cols-1),
              w=x2-x,
              w!=it&&(changed=1)))
            cs=${_ble_string_prototype::w}
          fi
        elif ((code==10)); then
          ((y++,x=0))
          cs=$_ble_term_el$_ble_term_nl
        else
          ((w=2))
          ble/util/c2s $((code+64))
          cs="^$ret"
        fi
      elif ((code==127)); then
        w=2 cs="^?"
      elif ((128<=code&&code<160)); then
        ble/util/c2s $((code-64))
        w=4 cs="M-^$ret"
      else
        ble/util/c2w "$code"
        w=$ret cs=${text:i:1}
      fi

      local wrapping=0
      if ((w>0)); then
        if ((x<cols&&cols<x+w)); then
          ((xenl)) && cs=$_ble_term_nl$cs
          cs=${_ble_string_prototype::cols-x}$cs
          ((x=cols,changed=1,wrapping=1))
        fi

        ((x+=w))
        while ((x>cols)); do
          ((y++,x-=cols))
        done
        if ((x==cols)); then
          if ((xenl)); then
            cs=$cs$_ble_term_nl
            changed=1
          fi
          ((y++,x=0))
        fi
      fi

      _ble_textmap_glyph[i]=$cs
      ((changed)) && ble/array#push _ble_textmap_ichg "$i"
      _ble_textmap_pos[i+1]="$x $y $wrapping"
      ((i++))
    fi

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
## 関数 ble/textmap#assert-up-to-date
##   編集文字列の文字の配置情報が最新であることを確認します。
##   以下の変数を参照する場合に事前に呼び出します。
##
##   _ble_textmap_pos
##   _ble_textmap_length
##
function ble/textmap#assert-up-to-date {
  ble-assert 'ble/textmap#is-up-to-date' 'dirty text positions'
}

## 関数 ble/textmap#getxy.out index
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

## 関数 ble/textmap#getxy.cur index
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
  _pos=(${_ble_textmap_pos[$1]})

  # 追い出しされたか check
  if (($1<_ble_textmap_length)); then
    local -a _eoc
    _eoc=(${_ble_textmap_pos[$1+1]})
    ((_eoc[2])) && ((_pos[0]=0,_pos[1]++))
  fi

  ((${_prefix}x=_pos[0]))
  ((${_prefix}y=_pos[1]))
}

## 関数 ble/textmap#get-index-at [-v varname] x y
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

## 関数 ble/textmap#hit/.getxy.out index
## 関数 ble/textmap#hit/.getxy.cur index
##   @var[in,out] pos
function ble/textmap#hit/.getxy.out {
  set -- ${_ble_textmap_pos[$1]}
  x=$1 y=$2
}
function ble/textmap#hit/.getxy.cur {
  local index=$1
  set -- ${_ble_textmap_pos[index]}
  x=$1 y=$2
  if ((index<_ble_textmap_length)); then
    set -- ${_ble_textmap_pos[index+1]}
    (($3)) && ((x=0,y++))
  fi
}

## 関数 ble/textmap#hit type xh yh [beg [end]]
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
_ble_canvas_x=0 _ble_canvas_y=0

## 関数 ble/canvas/goto.draw x y
##   現在位置を指定した座標へ移動する制御系列を生成します。
## @param[in] x y
##   移動先のカーソルの座標を指定します。
##   プロンプト原点が x=0 y=0 に対応します。
function ble/canvas/goto.draw {
  local x=$1 y=$2
  ble/canvas/put.draw "$_ble_term_sgr0"

  local dy=$((y-_ble_canvas_y))
  if ((dy!=0)); then
    if ((dy>0)); then
      ble/canvas/put.draw "${_ble_term_cud//'%d'/$dy}"
    else
      ble/canvas/put.draw "${_ble_term_cuu//'%d'/$((-dy))}"
    fi
  fi

  local dx=$((x-_ble_canvas_x))
  if ((dx!=0)); then
    if ((x==0)); then
      ble/canvas/put.draw "$_ble_term_cr"
    elif ((dx>0)); then
      ble/canvas/put.draw "${_ble_term_cuf//'%d'/$dx}"
    else
      ble/canvas/put.draw "${_ble_term_cub//'%d'/$((-dx))}"
    fi
  fi

  _ble_canvas_x=$x _ble_canvas_y=$y
}

#------------------------------------------------------------------------------
# ble/canvas/panel

## 配列 _ble_canvas_panel_type
##   各パネルを管理する関数接頭辞を保持する。
##
## 配列 _ble_canvas_panel_height
##   各パネルの高さを保持する。
##   現在 panel 0 が textarea で panel 2 が info に対応する。
##
##   開始した瞬間にキー入力をすると画面に echo されてしまうので、
##   それを削除するために最初の編集文字列の行数を 1 とする。
_ble_canvas_panel_type=(ble/textarea/panel ble/textarea/panel ble-edit/info)
_ble_canvas_panel_height=(1 0 0)

## 関数 ble/canvas/panel/layout/.extract-heights
##   @arr[out] mins maxs
function ble/canvas/panel/layout/.extract-heights {
  local i n=${#_ble_canvas_panel_type[@]}
  for ((i=0;i<n;i++)); do
    local height
    "${_ble_canvas_panel_type[i]}#get-height" "$i"
    mins[i]=${height%:*}
    maxs[i]=${height#*:}
  done
}

## 関数 ble/canvas/panel/layout/.determine-heights
##   最小高さ mins と希望高さ maxs から実際の高さ heights を決定します。
##   @var[in] lines
##   @arr[in] mins maxs
##   @arr[out] heights
function ble/canvas/panel/layout/.determine-heights {
  local i n=${#_ble_canvas_panel_type[@]}
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
          ((count++<rem&&heights[i]++))
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

## 関数 ble/canvas/panel/layout/.get-available-height index
##   @var[out] ret
function ble/canvas/panel/layout/.get-available-height {
  local index=$1
  local lines=$((${LINES:-25}-1)) # Note: bell の為に一行余裕を入れる
  local -a mins=() maxs=()
  ble/canvas/panel/layout/.extract-heights
  maxs[index]=${LINES:-25}
  local -a heights=()
  ble/canvas/panel/layout/.determine-heights
  ret=${heights[index]}
}

function ble/canvas/panel#reallocate-height.draw {
  local lines=$((${LINES:-25}-1)) # Note: bell の為に一行余裕を入れる

  local i n=${#_ble_canvas_panel_type[@]}
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

## 関数 ble/canvas/panel#get-origin
##   @var[out] x y
function ble/canvas/panel#get-origin {
  local ret index=$1 prefix=
  [[ $2 == --prefix=* ]] && prefix=${2#*=}
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ((${prefix}x=0,${prefix}y=ret))
}
function ble/canvas/panel#goto.draw {
  local index=$1 x=${2-0} y=${3-0} ret
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ble/canvas/goto.draw "$x" $((ret+y))
}
function ble/canvas/panel#report-cursor-position {
  local index=$1 x=${2-0} y=${3-0} ret
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"
  ((_ble_canvas_x=x,_ble_canvas_y=ret+y))
}

function ble/canvas/panel#increase-total-height.draw {
  local delta=$1
  ((delta>0)) || return

  local ret
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]}"; local old_total_height=$ret
  # 下に余白を確保
  if ((old_total_height>0)); then
    ble/canvas/goto.draw 0 $((old_total_height-1))
    ble/canvas/put-ind.draw "$delta"; ((_ble_canvas_y+=delta))
  else
    ble/canvas/goto.draw 0 0
    ble/canvas/put-ind.draw $((delta-1)); ((_ble_canvas_y+=delta-1))
  fi
}

function ble/canvas/panel#set-height.draw {
  local index=$1 new_height=$2
  local delta=$((new_height-_ble_canvas_panel_height[index]))
  ((delta)) || return

  local ret
  if ((delta>0)); then
    # 新しく行を挿入
    ble/canvas/panel#increase-total-height.draw "$delta"

    ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index+1}"; local ins_offset=$ret
    ble/canvas/goto.draw 0 "$ins_offset"
    ble/canvas/put-il.draw "$delta"
  else
    # 行を削除
    ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index+1}"; local ins_offset=$ret
    ble/canvas/goto.draw 0 $((ins_offset+delta))
    ble/canvas/put-dl.draw $((-delta))
  fi

  ((_ble_canvas_panel_height[index]=new_height))
  ble/function#try "${_ble_canvas_panel_type[index]}#on-height-change" "$index"
  return 0
}
function ble/canvas/panel#increase-height.draw {
  local index=$1 delta=$2
  ble/canvas/panel#set-height.draw "$index" $((_ble_canvas_panel_height[index]+delta))
}

function ble/canvas/panel#set-height-and-clear.draw {
  local index=$1 new_height=$2
  local old_height=${_ble_canvas_panel_height[index]}
  ((old_height||new_height)) || return

  local ret
  ble/canvas/panel#increase-total-height.draw $((new_height-old_height))
  ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"; local ins_offset=$ret
  ble/canvas/goto.draw 0 "$ins_offset"
  ((old_height)) && ble/canvas/put-dl.draw "$old_height"
  ((new_height)) && ble/canvas/put-il.draw "$new_height"

  ((_ble_canvas_panel_height[index]=new_height))
}

function ble/canvas/panel#clear.draw {
  local index=$1
  local height=${_ble_canvas_panel_height[index]}
  if ((height)); then
    local ret
    ble/arithmetic/sum "${_ble_canvas_panel_height[@]::index}"; local ins_offset=$ret
    ble/canvas/goto.draw 0 "$ins_offset"
    if ((height==1)); then
      ble/canvas/put.draw "$_ble_term_el2"
    else
      ble/canvas/put-dl.draw "$height"
      ble/canvas/put-il.draw "$height"
    fi
  fi
}
function ble/canvas/panel#clear-after.draw {
  local index=$1 x=$2 y=$3
  local height=${_ble_canvas_panel_height[index]}
  ((y<height)) || return

  ble/canvas/panel#goto.draw "$index" "$x" "$y"
  ble/canvas/put.draw "$_ble_term_el"
  local rest_lines=$((height-(y+1)))
  if ((rest_lines)); then
    ble/canvas/put.draw "$_ble_term_ind"
    ble/canvas/put-dl.draw "$rest_lines"
    ble/canvas/put-il.draw "$rest_lines"
    ble/canvas/put.draw "$_ble_term_ri"
  fi
}
