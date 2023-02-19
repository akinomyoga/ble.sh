#!/bin/bash

# **** sections ****
#
# @text.c2w
# @edit/draw
# @line.ps1
# @textmap
# @line.text
# @line.info
# @edit
# @edit.ps1
# @textarea
# @textarea.buffer
# @textarea.render
# @widget.clear
# @widget.mark
# @edit.bell
# @edit.insert
# @edit.delete
# @edit.cursor
# @edit.word
# @edit.exec
# @edit.accept
# @history
# @history.isearch
# @comp
# @bind
# @bind.bind

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
  if ! ble/util/isfunction "ble/util/c2w+$value"; then
    echo "bleopt: Invalid value char_width_mode='$value'. A function 'ble/util/c2w+$value' is not defined." >&2
    return 1
  fi
}

## オプション edit_vbell
##   編集時の visible bell の有効・無効を設定します。
## bleopt_edit_vbell=1
##   有効です。
## bleopt_edit_vbell=
##   無効です。
: ${bleopt_edit_vbell=}

## オプション edit_abell
##   編集時の audible bell (BEL 文字出力) の有効・無効を設定します。
## bleopt_edit_abell=1
##   有効です。
## bleopt_edit_abell=
##   無効です。
: ${bleopt_edit_abell=1}

## オプション history_lazyload
## bleopt_history_lazyload=1
##   ble-attach 後、初めて必要になった時に履歴の読込を行います。
## bleopt_history_lazyload=
##   ble-attach 時に履歴の読込を行います。
##
## bash-3.1 未満では history -s が思い通りに動作しないので、
## このオプションの値に関係なく ble-attach の時に履歴の読み込みを行います。
: ${bleopt_history_lazyload=1}

## オプション delete_selection_mode
##   文字挿入時に選択範囲をどうするかについて設定します。
## bleopt_delete_selection_mode=1 (既定)
##   選択範囲の内容を新しい文字で置き換えます。
## bleopt_delete_selection_mode=
##   選択範囲を解除して現在位置に新しい文字を挿入します。
: ${bleopt_delete_selection_mode=1}

## オプション default_keymap
##   既定の編集モードに使われるキーマップを指定します。
## bleopt_default_keymap=auto
##   [[ -o emacs/vi ]] の状態に応じて emacs/vi を切り替えます。
## bleopt_default_keymap=emacs
##   emacs と同様の編集モードを使用します。
## bleopt_default_keymap=vi
##   vi と同様の編集モードを使用します。
: ${bleopt_default_keymap:=auto}

function bleopt/check:default_keymap {
  case $value in
  (auto|emacs|vi|safe) ;;
  (*)
    echo "bleopt: Invalid value default_keymap='value'. The value should be one of \`auto', \`emacs', \`vi'." >&2
    return 1 ;;
  esac
}

## オプション indent_offset
##   シェルのインデント幅を指定します。既定では 4 です。
: ${bleopt_indent_offset:=4}

## オプション indent_tabs
##   インデントにタブを使用するかどうかを指定します。
##   0 を指定するとインデントに空白だけを用います。
##   それ以外の場合はインデントにタブを使用します。
: ${bleopt_indent_tabs:=1}

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

## オプション undo_point
##   undo/redo 実行直後のカーソル位置を設定します。
##
##   undo_point=beg
##     undo/redo によって変化のあった範囲の先頭に移動します。
##   undo_point=end
##     undo/redo によって変化のあった範囲の末端に移動します。
##   その他の時
##     undo/redo 後の状態が記録された時のカーソル位置を復元します。
##
: ${bleopt_undo_point=end}

## オプション edit_forced_textmap
##   1 が設定されているとき、矩形選択に先立って配置計算を強制します。
##   0 が設定されているとき、配置情報があるときにそれを使い、
##   配置情報がないときは論理行・論理列による矩形選択にフォールバックします。
##
: ${bleopt_edit_forced_textmap:=1}

function ble/edit/use-textmap {
  ble/textmap#is-up-to-date && return 0
  ((bleopt_edit_forced_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

## オプション exec_type (内部使用)
##   コマンドの実行の方法を指定します。
##
##   exec_type=exec
##     関数内で実行します (従来の方法です。将来的に削除されます)
##   exec_type=gexec
##     グローバルな文脈で実行します (新しい方法です)
##
## 要件: 関数 ble-edit/exec:$bleopt_exec_type/process が定義されていること。
: ${bleopt_exec_type:=gexec}

function bleopt/check:exec_type {
  if ! ble/util/isfunction "ble-edit/exec:$value/process"; then
    echo "bleopt: Invalid value exec_type='$value'. A function 'ble-edit/exec:$value/process' is not defined." >&2
    return 1
  fi
}

## オプション suppress_bash_output (内部使用)
##   bash 自体の出力を抑制するかどうかを指定します。
## bleopt_suppress_bash_output=1
##   抑制します。bash のエラーメッセージは visible-bell で表示します。
## bleopt_suppress_bash_output=
##   抑制しません。bash のメッセージは全て端末に出力されます。
##   これはデバグ用の設定です。bash の出力を制御するためにちらつきが発生する事があります。
##   bash-3 ではこの設定では C-d を捕捉できません。
: ${bleopt_suppress_bash_output=1}

## オプション ignoreeof_message (内部使用)
##   bash-3.0 の時に使用します。C-d を捕捉するのに用いるメッセージです。
##   これは自分の bash の設定に合わせる必要があります。
: ${bleopt_ignoreeof_message:='Use "exit" to leave the shell.'}

# 
#------------------------------------------------------------------------------
# **** char width ****                                                @text.c2w

# ※注意 [ -~] の範囲の文字は全て幅1であるという事を仮定したコードが幾らかある
#   もしこれらの範囲の文字を幅1以外で表示する端末が有ればそれらのコードを実装し
#   直す必要がある。その様な変な端末があるとは思えないが。

## 関数 ble/util/c2w ccode
##   @var[out] ret
function ble/util/c2w {
  "ble/util/c2w+$bleopt_char_width_mode" "$1"
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

## 配列 _ble_text_c2w_emoji_wranges
##
##   https://github.com/vim-jp/issues/issues/1086 にある表を
##   以下の関数で加工した。
##
##   function process {
##     local -i begin=$1 end=$(($2+1))
##     printf ' %s %s' "$begin" "$end"
##   }
##
_ble_text_c2w_emoji_wranges=(
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

  local l=0 u=${#_ble_text_c2w_emoji_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_text_c2w_emoji_wranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done

  (((l&1)==0)); return
}

# ---- char_width_mode ---------------------------------------------------------

## 関数 ble/util/c2w+emacs
##   emacs-24.2.1 default char-width-table
##   @var[out] ret
_ble_text_c2w__emacs_wranges=(
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

  if ((tIndex<_ble_text_c2w__emacs_wranges[0])); then
    ret=1
    return
  fi

  local l=0 u=${#_ble_text_c2w__emacs_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_text_c2w__emacs_wranges[m=(l+u)/2]<=tIndex?(l=m):(u=m)))
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
_ble_text_c2w__east_wranges=(
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
  if ((code<_ble_text_c2w__east_wranges[0])); then
    ret=1
    return
  fi

  local l=0 u=${#_ble_text_c2w__east_wranges[@]} m
  while ((l+1<u)); do
    ((_ble_text_c2w__east_wranges[m=(l+u)/2]<=code?(l=m):(u=m)))
  done
  ((ret=((l&1)==0)?2:1))
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/draw ****                                            @edit/draw

function ble-edit/draw/put {
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$1
}
function ble-edit/draw/put.ind {
  local -i count=${1-1}
  local ret; ble/string#repeat "${_ble_term_ind}" "$count"
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$ret
}
function ble-edit/draw/put.il {
  local -i value=${1-1}
  ((value>0)) || return 0
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_il//'%d'/$value}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
}
function ble-edit/draw/put.dl {
  local -i value=${1-1}
  ((value>0)) || return 0
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$_ble_term_el2 # Note #D1214: 最終行対策 cygwin, linux
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_dl//'%d'/$value}
}
function ble-edit/draw/put.cuu {
  local -i value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cuu//'%d'/$value}
}
function ble-edit/draw/put.cud {
  local -i value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cud//'%d'/$value}
}
function ble-edit/draw/put.cuf {
  local -i value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cuf//'%d'/$value}
}
function ble-edit/draw/put.cub {
  local -i value=${1-1}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=${_ble_term_cub//'%d'/$value}
}
function ble-edit/draw/put.cup {
  local -i l=${1-1} c=${2-1}
  local out=$_ble_term_cup
  out=${out//'%l'/$l}
  out=${out//'%c'/$c}
  out=${out//'%y'/$((l-1))}
  out=${out//'%x'/$((c-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble-edit/draw/put.hpa {
  local -i c=${1-1}
  local out=$_ble_term_hpa
  out=${out//'%c'/$c}
  out=${out//'%x'/$((c-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble-edit/draw/put.vpa {
  local -i l=${1-1}
  local out=$_ble_term_vpa
  out=${out//'%l'/$l}
  out=${out//'%y'/$((l-1))}
  DRAW_BUFF[${#DRAW_BUFF[*]}]=$out
}
function ble-edit/draw/flush {
  IFS= builtin eval 'builtin echo -n "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}
## 関数 ble-edit/draw/sflush [-v var]
##   @param[in] var
##     出力先の変数名を指定します。
##   @var[out] !var
function ble-edit/draw/sflush {
  local _var=ret
  [[ $1 == -v ]] && _var=$2
  IFS= builtin eval "$_var=\"\${DRAW_BUFF[*]}\""
  DRAW_BUFF=()
}
function ble-edit/draw/bflush {
  IFS= builtin eval 'ble/util/buffer "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}

function ble-edit/draw/trace/SC {
  trace_scosc="$x $y $g $lc $lg"
  ble-edit/draw/put "$_ble_term_sc"
}
function ble-edit/draw/trace/RC {
  local -a scosc
  scosc=($trace_scosc)
  x=${scosc[0]}
  y=${scosc[1]}
  g=${scosc[2]}
  lc=${scosc[3]}
  lg=${scosc[4]}
  ble-edit/draw/put "$_ble_term_rc"
}
function ble-edit/draw/trace/NEL {
  ble-edit/draw/put "$_ble_term_cr"
  ble-edit/draw/put "$_ble_term_nl"
  ((y++,x=0,lc=32,lg=0))
}
## 関数 ble-edit/draw/trace/SGR/arg_next
##   @var[in    ] f
##   @var[in,out] j
##   @var[   out] arg
function ble-edit/draw/trace/SGR/arg_next {
  local _var=arg _ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  if ((j<${#f[*]})); then
    ((_ret=10#0${f[j++]}))
  else
    ((i++))
    ((_ret=10#0${specs[i]%%:*}))
  fi

  (($_var=_ret))
}
function ble-edit/draw/trace/SGR {
  local param=$1 seq=$2 specs i iN
  ble/string#split specs \; "$param"
  if ((${#specs[*]}==0)); then
    g=0
    ble-edit/draw/put "$_ble_term_sgr0"
    return
  fi

  for ((i=0,iN=${#specs[@]};i<iN;i++)); do
    local spec=${specs[i]} f
    ble/string#split f : "$spec"
    local arg=$((10#0${f[0]}))
    if ((30<=arg&&arg<50)); then
      # colors
      if ((30<=arg&&arg<38)); then
        local color=$((arg-30))
        ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
      elif ((40<=arg&&arg<48)); then
        local color=$((arg-40))
        ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
      elif ((arg==38)); then
        local j=1 color cspace
        ble-edit/draw/trace/SGR/arg_next -v cspace
        if ((cspace==5)); then
          ble-edit/draw/trace/SGR/arg_next -v color
          ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
        fi
      elif ((arg==48)); then
        local j=1 color cspace
        ble-edit/draw/trace/SGR/arg_next -v cspace
        if ((cspace==5)); then
          ble-edit/draw/trace/SGR/arg_next -v color
          ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
        fi
      elif ((arg==39)); then
        ((g&=~(_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor)))
      elif ((arg==49)); then
        ((g&=~(_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor)))
      fi
    elif ((90<=arg&&arg<98)); then
      local color=$((arg-90+8))
      ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
    elif ((100<=arg&&arg<108)); then
      local color=$((arg-100+8))
      ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
    elif ((arg==0)); then
      g=0
    elif ((arg==1)); then
      ((g|=_ble_color_gflags_Bold))
    elif ((arg==22)); then
      ((g&=~_ble_color_gflags_Bold))
    elif ((arg==4)); then
      ((g|=_ble_color_gflags_Underline))
    elif ((arg==24)); then
      ((g&=~_ble_color_gflags_Underline))
    elif ((arg==7)); then
      ((g|=_ble_color_gflags_Revert))
    elif ((arg==27)); then
      ((g&=~_ble_color_gflags_Revert))
    elif ((arg==3)); then
      ((g|=_ble_color_gflags_Italic))
    elif ((arg==23)); then
      ((g&=~_ble_color_gflags_Italic))
    elif ((arg==5)); then
      ((g|=_ble_color_gflags_Blink))
    elif ((arg==25)); then
      ((g&=~_ble_color_gflags_Blink))
    elif ((arg==8)); then
      ((g|=_ble_color_gflags_Invisible))
    elif ((arg==28)); then
      ((g&=~_ble_color_gflags_Invisible))
    elif ((arg==9)); then
      ((g|=_ble_color_gflags_Strike))
    elif ((arg==29)); then
      ((g&=~_ble_color_gflags_Strike))
    fi
  done

  ble-color-g2sgr -v seq "$g"
  ble-edit/draw/put "$seq"
}
function ble-edit/draw/trace/process-csi-sequence {
  local seq=$1 seq1=${1:2} rex
  local char=${seq1:${#seq1}-1:1} param=${seq1::${#seq1}-1}
  if [[ ! ${param//[0-9:;]} ]]; then
    # CSI 数字引数 + 文字
    case "$char" in
    (m) # SGR
      ble-edit/draw/trace/SGR "$param" "$seq"
      return ;;
    ([ABCDEFGIZ\`ade])
      local arg=0
      [[ $param =~ ^[0-9]+$ ]] && ((arg=10#0$param))
      ((arg==0&&(arg=1)))

      local x0=$x y0=$y
      if [[ $char == A ]]; then
        # CUU "CSI A"
        ((y-=arg,y<0&&(y=0)))
        ((y<y0)) && ble-edit/draw/put.cuu $((y0-y))
      elif [[ $char == [Be] ]]; then
        # CUD "CSI B"
        # VPR "CSI e"
        ((y+=arg,y>=lines&&(y=lines-1)))
        ((y>y0)) && ble-edit/draw/put.cud $((y-y0))
      elif [[ $char == [Ca] ]]; then
        # CUF "CSI C"
        # HPR "CSI a"
        ((x+=arg,x>=cols&&(x=cols-1)))
        ((x>x0)) && ble-edit/draw/put.cuf $((x-x0))
      elif [[ $char == D ]]; then
        # CUB "CSI D"
        ((x-=arg,x<0&&(x=0)))
        ((x<x0)) && ble-edit/draw/put.cub $((x0-x))
      elif [[ $char == E ]]; then
        # CNL "CSI E"
        ((y+=arg,y>=lines&&(y=lines-1),x=0))
        ((y>y0)) && ble-edit/draw/put.cud $((y-y0))
        ble-edit/draw/put "$_ble_term_cr"
      elif [[ $char == F ]]; then
        # CPL "CSI F"
        ((y-=arg,y<0&&(y=0),x=0))
        ((y<y0)) && ble-edit/draw/put.cuu $((y0-y))
        ble-edit/draw/put "$_ble_term_cr"
      elif [[ $char == [G\`] ]]; then
        # CHA "CSI G"
        # HPA "CSI `"
        ((x=arg-1,x<0&&(x=0),x>=cols&&(x=cols-1)))
        ble-edit/draw/put.hpa $((x+1))
      elif [[ $char == d ]]; then
        # VPA "CSI d"
        ((y=arg-1,y<0&&(y=0),y>=lines&&(y=lines-1)))
        ble-edit/draw/put.vpa $((y+1))
      elif [[ $char == I ]]; then
        # CHT "CSI I"
        local _x
        ((_x=(x/it+arg)*it,
          _x>=cols&&(_x=cols-1)))
        if ((_x>x)); then
          ble-edit/draw/put.cuf $((_x-x))
          ((x=_x))
        fi
      elif [[ $char == Z ]]; then
        # CHB "CSI Z"
        local _x
        ((_x=((x+it-1)/it-arg)*it,
          _x<0&&(_x=0)))
        if ((_x<x)); then
          ble-edit/draw/put.cub $((x-_x))
          ((x=_x))
        fi
      fi
      lc=-1 lg=0
      return ;;
    ([Hf])
      # CUP "CSI H"
      # HVP "CSI f"
      local -a params
      ble/string#split-words params "${param//[^0-9]/ }"
      params=("${params[@]/#/10#0}")
      ((x=params[1]-1))
      ((y=params[0]-1))
      ((x<0&&(x=0),x>=cols&&(x=cols-1),
        y<0&&(y=0),y>=lines&&(y=lines-1)))
      ble-edit/draw/put.cup $((y+1)) $((x+1))
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
            unset "trace_brack[$lastIndex]"
          fi
        fi
        return
      else
        if [[ $char == s ]]; then
          ble-edit/draw/trace/SC
        else
          ble-edit/draw/trace/RC
        fi
        return
      fi ;;
    # ■その他色々?
    # ([JPX@MKL]) # 挿入削除→カーソルの位置は不変 lc?
    # ([hl]) # SM RM DECSM DECRM
    esac
  fi

  ble-edit/draw/put "$seq"
}
function ble-edit/draw/trace/process-esc-sequence {
  local seq=$1 char=${1:1}
  case "$char" in
  (7) # DECSC
    ble-edit/draw/trace/SC
    return ;;
  (8) # DECRC
    ble-edit/draw/trace/RC
    return ;;
  (D) # IND
    ((y++))
    ble-edit/draw/put "$_ble_term_ind"
    [[ $_ble_term_ind != $'\eD' ]] &&
      ble-edit/draw/put.hpa $((x+1)) # tput ind が唯の改行の時がある
    lc=-1 lg=0
    return ;;
  (M) # RI
    ((y--,y<0&&(y=0)))
    ble-edit/draw/put "$_ble_term_ri"
    lc=-1 lg=0
    return ;;
  (E) # NEL
    ble-edit/draw/trace/NEL
    lc=32 lg=0
    return ;;
  # (H) # HTS 面倒だから無視。
  # ([KL]) PLD PLU は何か?
  esac

  ble-edit/draw/put "$seq"
}

## 関数 ble-edit/draw/trace text
##   制御シーケンスを含む文字列を出力すると共にカーソル位置の移動を計算します。
##
##   @param[in]   text
##     出力する (制御シーケンスを含む) 文字列を指定します。
##   @var[in,out] DRAW_BUFF[]
##     出力先の配列を指定します。
##   @var[in,out] x y g
##     出力の開始位置を指定します。出力終了時の位置を返します。
##   @var[in,out] lc lg
##     bleopt_suppress_bash_output= の時、
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
function ble-edit/draw/trace {
  local LC_ALL= LC_COLLATE=C
  # cygwin では LC_COLLATE=C にしないと
  # 正規表現の range expression が期待通りに動かない。
  ble-edit/draw/trace.impl "$@"
} 2>/dev/null
function ble-edit/draw/trace.impl {
  local text=$1

  # Note: 文字符号化方式によっては対応する文字が存在しない可能性がある。
  #   その時は st='\u009C' になるはず。2文字以上のとき変換に失敗したと見做す。
  local ret
  ble/util/c2s 156; local st=$ret #  (ST)
  ((${#st}>=2)) && st=

  # constants
  local cols=${COLUMNS:-80} lines=${LINES:-25}
  local it=${bleopt_tab_width:-$_ble_term_it} xenl=$_ble_term_xenl
  _ble_util_string_prototype.reserve "$it"
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
          ble-edit/draw/trace/process-csi-sequence "$BASH_REMATCH"
        elif [[ $tail =~ $rex_2022 ]]; then
          # ISO-2022 (素通り)
          s=$BASH_REMATCH
          ((i+=${#BASH_REMATCH}-1))
        elif [[ $tail =~ $rex_esc ]]; then
          s=
          ((i+=${#BASH_REMATCH}-1))
          ble-edit/draw/trace/process-esc-sequence "$BASH_REMATCH"
        fi ;;
      ('') # BS
        ((x>0&&(x--,lc=32,lg=g))) ;;
      ($'\t') # HT
        local _x
        ((_x=(x+it)/it*it,
          _x>=cols&&(_x=cols-1)))
        if ((x<_x)); then
          s=${_ble_util_string_prototype::_x-x}
          ((x=_x,lc=32,lg=g))
        else
          s=
        fi ;;
      ($'\n') # LF = CR+LF
        s=
        ble-edit/draw/trace/NEL ;;
      ('') # VT
        s=
        ble-edit/draw/put "$_ble_term_cr"
        ble-edit/draw/put "$_ble_term_nl"
        ((x)) && ble-edit/draw/put.cuf "$x"
        ((y++,lc=32,lg=0)) ;;
      ($'\r') # CR ^M
        s=$_ble_term_cr
        ((x=0,lc=-1,lg=0)) ;;
      # その他の制御文字は  (BEL)  (FF) も含めてゼロ幅と解釈する
      esac
      [[ $s ]] && ble-edit/draw/put "$s"
    elif ble/util/isprint+ "$tail"; then
      w=${#BASH_REMATCH}
      ble-edit/draw/put "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
      if [[ ! $bleopt_suppress_bash_output ]]; then
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
        ble-edit/draw/put "${_ble_util_string_prototype::x+w-cols}"
        ((x=cols))
      fi
      ble-edit/draw/put "${tail::1}"
      ((i++))
    fi

    if ((w>0)); then
      ((x+=w,y+=x/cols,x%=cols,
        xenl&&x==0&&(y--,x=cols)))
      ((x==0&&(lc=32,lg=0)))
    fi
  done
}

# **** prompt ****                                                    @line.ps1

## called by ble-edit-initialize
function ble-edit/prompt/initialize {
  # hostname
  _ble_edit_prompt__string_H=${HOSTNAME:-$_ble_base_env_HOSTNAME}
  if local rex='^[0-9]+(\.[0-9]){3}$'; [[ $_ble_edit_prompt__string_H =~ $rex ]]; then
    # IPv4 の形式の場合には省略しない
    _ble_edit_prompt__string_h=$_ble_edit_prompt__string_H
  else
    _ble_edit_prompt__string_h=${_ble_edit_prompt__string_H%%.*}
  fi

  # tty basename
  local tmp; ble/util/assign tmp 'tty 2>/dev/null'
  _ble_edit_prompt__string_l=${tmp##*/}

  # command name
  _ble_edit_prompt__string_s=${0##*/}

  # user
  _ble_edit_prompt__string_u=${USER:-$_ble_base_env_USER}

  # bash versions
  ble/util/sprintf _ble_edit_prompt__string_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  ble/util/sprintf _ble_edit_prompt__string_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if [[ $EUID -eq 0 ]]; then
    _ble_edit_prompt__string_root='#'
  else
    _ble_edit_prompt__string_root='$'
  fi

  if [[ $OSTYPE == cygwin* ]]; then
    local windir=/cygdrive/c/Windows
    if [[ $WINDIR == [A-Za-z]:\\* ]]; then
      local bsl='\' sl=/
      local c=${WINDIR::1} path=${WINDIR:3}
      if [[ $c == [A-Z] ]]; then
        if ((_ble_bash>=40000)); then
          c=${c,?}
        else
          local ret
          ble/util/s2c "$c"
          ble/util/c2s $((ret+32))
          c=$ret
        fi
      fi
      windir=/cygdrive/$c/${path//"$bsl"/"$sl"}
    fi

    if [[ -e $windir && -w $windir ]]; then
      _ble_edit_prompt__string_root='#'
    fi
  elif [[ $OSTYPE == msys* ]]; then
    # msys64/etc/bash.bashrc に倣う
    if ble/bin#has id getent &>/dev/null; then
      local id getent
      ble/util/assign id 'id -G'
      ble/util/assign getent 'getent -w group S-1-16-12288'
      ble/string#split getent : "$getent"
      [[ " $id " == *" ${getent[1]} "* ]] &&
        _ble_edit_prompt__string_root='#'
    fi
  fi
}

## 変数 _ble_edit_prompt
##   構築した prompt の情報をキャッシュします。
##   @var _ble_edit_prompt[0]    version
##     prompt 情報を作成した時の _ble_edit_LINENO を表します。
##   @var _ble_edit_prompt[1..3] x y g
##     prompt を表示し終わった時のカーソルの位置と描画属性を表します。
##   @var _ble_edit_prompt[4..5] lc lg
##     bleopt_suppress_bash_output= の時、
##     prompt を表示し終わった時の左側にある文字とその描画属性を表します。
##     それ以外の時はこの値は使われません。
##   @var _ble_edit_prompt[6]    ps1out
##     prompt を表示する為に出力する制御シーケンスを含んだ文字列です。
##   @var _ble_edit_prompt[7]    COLUMNS:ps1esc
##     調整前の ps1out を格納します。ps1out の計算を省略する為に使用します。
_ble_edit_prompt=("" 0 0 0 32 0 "" "")


## 関数 _ble_edit_prompt.load
##   @var[out] x y g
##   @var[out] lc lg
##   @var[out] ret
##     プロンプトを描画するための文字列
function _ble_edit_prompt.load {
  x=${_ble_edit_prompt[1]}
  y=${_ble_edit_prompt[2]}
  g=${_ble_edit_prompt[3]}
  lc=${_ble_edit_prompt[4]}
  lg=${_ble_edit_prompt[5]}
  ret=${_ble_edit_prompt[6]}
}

## 関数 ble-edit/prompt/update/append text
##   指定された文字列を "" 内に入れる為のエスケープをして出力します。
##   @param[in] text
##     エスケープされる文字列を指定します。
##   @var[out]  DRAW_BUFF[]
##     出力先の配列です。
function ble-edit/prompt/update/append {
  local text=$1 a b
  if [[ $text == *['$\"`']* ]]; then
    a='\' b='\'$a text=${text//"$a"/"$b"}
    a='$' b='\'$a text=${text//"$a"/"$b"}
    a='"' b='\'$a text=${text//"$a"/"$b"}
    a='`' b='\'$a text=${text//"$a"/"$b"}
  fi
  ble-edit/draw/put "$text"
}
function ble-edit/prompt/update/process-text {
  local text=$1 a b
  if [[ $text == *'"'* ]]; then
    a='"' b='\"' text=${text//"$a"/"$b"}
  fi
  ble-edit/draw/put "$text"
}

## 関数 ble-edit/prompt/update/process-backslash
##   @var[in]     tail
##   @var[in.out] DRAW_BUFF
function ble-edit/prompt/update/process-backslash {
  ((i+=2))

  # \\ の次の文字
  local c=${tail:1:1} pat='[]#!$\'
  if [[ ! ${pat##*"$c"*} ]]; then
    case "$c" in
    (\[) ble-edit/draw/put $'\e[99s' ;; # \[ \] は後処理の為、適当な識別用の文字列を出力する。
    (\]) ble-edit/draw/put $'\e[99u' ;;
    ('#') # コマンド番号 (本当は history に入らない物もある…)
      ble-edit/draw/put "$_ble_edit_CMD" ;;
    (\!) # 編集行の履歴番号
      local count
      ble-edit/history/get-count -v count
      ble-edit/draw/put $((count+1)) ;;
    ('$') # # or $
      ble-edit/prompt/update/append "$_ble_edit_prompt__string_root" ;;
    (\\)
      # '\\' は '\' と出力された後に、更に "" 内で評価された時に次の文字をエスケープする。
      # 例えば '\\$' は一旦 '\$' となり、更に展開されて '$' となる。'\\\\' も同様に '\' になる。
      ble-edit/draw/put '\' ;;
    esac
  elif local handler=ble-edit/prompt/update/backslash:$c && ble/util/isfunction "$handler"; then
    "$handler"
  else
    # その他の文字はそのまま出力される。
    # - '\"' '\`' はそのまま出力された後に "" 内で評価され '"' '`' となる。
    # - それ以外の場合は '\?' がそのまま出力された後に、"" 内で評価されても変わらず '\?' 等となる。
    ble-edit/draw/put "\\$c"
  fi
}

function ble-edit/prompt/update/backslash:0 { # 8進表現
  local rex='^\\[0-7]{1,3}'
  if [[ $tail =~ $rex ]]; then
    local seq=${BASH_REMATCH[0]}
    ((i+=${#seq}-2))
    builtin eval "c=\$'$seq'"
  fi
  ble-edit/prompt/update/append "$c"
}
function ble-edit/prompt/update/backslash:1 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:2 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:3 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:4 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:5 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:6 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:7 { ble-edit/prompt/update/backslash:0; }
function ble-edit/prompt/update/backslash:a { # 0 BEL
  ble-edit/draw/put ""
}
function ble-edit/prompt/update/backslash:d { # ? 日付
  [[ $cache_d ]] || ble/util/strftime -v cache_d '%a %b %d'
  ble-edit/prompt/update/append "$cache_d"
}
function ble-edit/prompt/update/backslash:t { # 8 時刻
  [[ $cache_t ]] || ble/util/strftime -v cache_t '%H:%M:%S'
  ble-edit/prompt/update/append "$cache_t"
}
function ble-edit/prompt/update/backslash:A { # 5 時刻
  [[ $cache_A ]] || ble/util/strftime -v cache_A '%H:%M'
  ble-edit/prompt/update/append "$cache_A"
}
function ble-edit/prompt/update/backslash:T { # 8 時刻
  [[ $cache_T ]] || ble/util/strftime -v cache_T '%I:%M:%S'
  ble-edit/prompt/update/append "$cache_T"
}
function ble-edit/prompt/update/backslash:@ { # ? 時刻
  [[ $cache_at ]] || ble/util/strftime -v cache_at '%I:%M %p'
  ble-edit/prompt/update/append "$cache_at"
}
function ble-edit/prompt/update/backslash:D {
  local rex='^\\D\{([^{}]*)\}' cache_D
  if [[ $tail =~ $rex ]]; then
    ble/util/strftime -v cache_D "${BASH_REMATCH[1]}"
    ble-edit/prompt/update/append "$cache_D"
    ((i+=${#BASH_REMATCH}-2))
  else
    ble-edit/prompt/update/append "\\$c"
  fi
}
function ble-edit/prompt/update/backslash:e {
  ble-edit/draw/put $'\e'
}
function ble-edit/prompt/update/backslash:h { # = ホスト名
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_h"
}
function ble-edit/prompt/update/backslash:H { # = ホスト名
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_H"
}
function ble-edit/prompt/update/backslash:j { #   ジョブの数
  if [[ ! $cache_j ]]; then
    local joblist
    ble/util/joblist
    cache_j=${#joblist[@]}
  fi
  ble-edit/draw/put "$cache_j"
}
function ble-edit/prompt/update/backslash:l { #   tty basename
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_l"
}
function ble-edit/prompt/update/backslash:n {
  ble-edit/draw/put $'\n'
}
function ble-edit/prompt/update/backslash:r {
  ble-edit/draw/put "$_ble_term_cr"
}
function ble-edit/prompt/update/backslash:s { # 4 "bash"
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_s"
}
function ble-edit/prompt/update/backslash:u { # = ユーザ名
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_u"
}
function ble-edit/prompt/update/backslash:v { # = bash version %d.%d
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_v"
}
function ble-edit/prompt/update/backslash:V { # = bash version %d.%d.%d
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_V"
}
function ble-edit/prompt/update/backslash:w { # PWD
  ble-edit/prompt/update/update-cache_wd
  ble-edit/prompt/update/append "$cache_wd"
}
function ble-edit/prompt/update/backslash:W { # PWD短縮
  if [[ ! ${PWD//'/'} ]]; then
    ble-edit/prompt/update/append "$PWD"
  else
    ble-edit/prompt/update/update-cache_wd
    ble-edit/prompt/update/append "${cache_wd##*/}"
  fi
}
## 関数 ble-edit/prompt/update/update-cache_wd
##   @var[in,out] cache_wd
function ble-edit/prompt/update/update-cache_wd {
  [[ $cache_wd ]] && return

  if [[ ! ${PWD//'/'} ]]; then
    cache_wd=$PWD
    return
  fi

  local head= body=${PWD%/}
  if [[ $body == "$HOME" ]]; then
    cache_wd='~'
    return
  elif [[ $body == "$HOME"/* ]]; then
    head='~/'
    body=${body#"$HOME"/}
  fi

  if [[ $PROMPT_DIRTRIM ]]; then
    local dirtrim=$((PROMPT_DIRTRIM))
    local pat='[^/]'
    local count=${body//$pat}
    if ((${#count}>=dirtrim)); then
      local ret
      ble/string#repeat '/*' "$dirtrim"
      local omit=${body%$ret}
      ((${#omit}>3)) &&
        body=...${body:${#omit}}
    fi
  fi

  cache_wd=$head$body
}

function ble-edit/prompt/update/eval-prompt_command {
  # return 等と記述されていた時対策として関数内評価。
  eval "$PROMPT_COMMAND"
}

## 関数 ble-edit/prompt/update
##   _ble_edit_PS1 からプロンプトを構築します。
##   @var[in]  _ble_edit_PS1
##     構築されるプロンプトの内容を指定します。
##   @var[out] _ble_edit_prompt
##     構築したプロンプトの情報を格納します。
##   @var[out] ret
##     プロンプトを描画する為の文字列を返します。
##   @var[in,out] x y g
##     プロンプトの描画開始点を指定します。
##     プロンプトを描画した後の位置を返します。
##   @var[in,out] lc lg
##     bleopt_suppress_bash_output= の際に、
##     描画開始点の左の文字コードを指定します。
##     描画終了点の左の文字コードが分かる場合にそれを返します。
function ble-edit/prompt/update {
  local version=$COLUMNS:$_ble_edit_LINENO
  if [[ ${_ble_edit_prompt[0]} == "$version" ]]; then
    _ble_edit_prompt.load
    return
  fi

  if ((_ble_textarea_panel==0)); then # 補助プロンプトに対しては PROMPT_COMMAND は実行しない
    if [[ $PROMPT_COMMAND ]]; then
      ((_ble_edit_attached)) && ble-edit/restore-PS1
      ble-edit/prompt/update/eval-prompt_command
      ((_ble_edit_attached)) && ble-edit/adjust-PS1
    fi
  fi
  local ps1=$_ble_edit_PS1

  local cache_d= cache_t= cache_A= cache_T= cache_at= cache_j= cache_wd=

  # 1 特別な Escape \? を処理
  local i=0 iN=${#ps1}
  local -a DRAW_BUFF=()
  local rex_letters='^[^\]+|\\$'
  while ((i<iN)); do
    local tail=${ps1:i}
    if [[ $tail == '\'?* ]]; then
      ble-edit/prompt/update/process-backslash
    elif [[ $tail =~ $rex_letters ]]; then
      ble-edit/prompt/update/process-text "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
    else
      # ? ここには本来来ないはず。
      ble-edit/draw/put "${tail::1}"
      ((i++))
    fi
  done

  # 2 eval 'ps1esc="..."'
  local ps1esc
  ble-edit/draw/sflush -v ps1esc
  ble-edit/exec/.setexit "$_ble_edit_exec_lastarg"
  builtin eval "ps1esc=\"$ps1esc\""
  local trace_hash=$LINES,$COLUMNS:$bleopt_char_width_mode:$ps1esc
  if [[ $trace_hash == "${_ble_edit_prompt[7]}" ]]; then
    # 前回と同じ ps1esc の場合は計測処理は省略
    _ble_edit_prompt[0]=$version
    _ble_edit_prompt.load
    return
  fi

  # 3 計測
  x=0 y=0 g=0 lc=32 lg=0
  ble-edit/draw/trace "$ps1esc"
  ((lc<0&&(lc=0)))

  #echo "ps1=$ps1" >> 1.tmp
  #echo "ps1esc=$ps1esc" >> 1.tmp
  #declare -p DRAW_BUFF >> 1.tmp

  # 4 出力
  local ps1out
  ble-edit/draw/sflush -v ps1out
  ret=$ps1out
  _ble_edit_prompt=("$version" "$x" "$y" "$g" "$lc" "$lg" "$ps1out" "$trace_hash")
}

# 
# **** textmap ****                                                    @textmap

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

## 関数 text x y; ble/textmap#update; x y
##   @var[in    ] text
##   @var[in,out] x y
##   @var[in,out] _ble_textmap_*
function ble/textmap#update {
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
  _ble_util_string_prototype.reserve "$it"

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
  _ble_util_array_prototype.reserve "$iN"
  local -a old_pos old_ichg
  old_pos=("${_ble_textmap_pos[@]:dend0:iN-dend+1}")
  old_ichg=("${_ble_textmap_ichg[@]}")
  _ble_textmap_pos=(
    "${_ble_textmap_pos[@]::dbeg+1}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
    "${_ble_textmap_pos[@]:dend0+1:iN-dend}")
  _ble_textmap_glyph=(
    "${_ble_textmap_glyph[@]::dbeg}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
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
            cs=${_ble_util_string_prototype::w}
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
          cs=${_ble_util_string_prototype::cols-x}$cs
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

    # 後は同じなので計算を省略
    ((i>=dend)) && [[ ${old_pos[i-dend]} == "${_ble_textmap_pos[i]}" ]] && break
  done

  if ((i<iN)); then
    # 途中で一致して中断した場合は、前の iN 番目の位置を読む
    local -a pos
    pos=(${_ble_textmap_pos[iN]})
    ((x=pos[0]))
    ((y=pos[1]))
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
  ble/string#split-words _pos "${_ble_textmap_pos[$1]}"
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

# 
# **** information pane ****                                         @line.info

## 関数 x y cols out ; ble-edit/info/.put-atomic ( nchar text )+ ; x y out
##   指定した文字列を out に追加しつつ、現在位置を更新します。
##   文字列は幅 1 の文字で構成されていると仮定します。
function ble-edit/info/.put-simple {
  local nchar=$1

  if ((y+(x+nchar)/cols<lines)); then
    out=$out$2
    ((x+=nchar%cols,
      y+=nchar/cols,
      (_ble_term_xenl?x>cols:x>=cols)&&(y++,x-=cols)))
  else
    # 画面をはみ出る場合
    out=$out${2::lines*cols-(y*cols+x)}
    ((x=cols,y=lines-1))
    ble-edit/info/.put-nl-if-eol
  fi
}
## 関数 x y cols out ; ble-edit/info/.put-atomic ( w char )+ ; x y out
##   指定した文字を out に追加しつつ、現在位置を更新します。
function ble-edit/info/.put-atomic {
  local w c
  w=$1

  # その行に入りきらない文字は次の行へ (幅 w が2以上の文字)
  if ((x<cols&&cols<x+w)); then
    _ble_util_string_prototype.reserve $((cols-x))
    out=$out${_ble_util_string_prototype::cols-x}
    ((x=cols))
  fi

  out=$out$2

  # 移動
  if ((w>0)); then
    ((x+=w))
    while ((_ble_term_xenl?x>cols:x>=cols)); do
      ((y++,x-=cols))
    done
  fi
}
## 関数 x y cols out ; ble-edit/info/.put-nl-if-eol ; x y out
##   行末にいる場合次の行へ移動します。
function ble-edit/info/.put-nl-if-eol {
  if ((x==cols)); then
    ((_ble_term_xenl)) && out=$out$'\n'
    ((y++,x=0))
  fi
}

## 関数 x y; ble-edit/info/.construct-text text ; ret
##   指定した文字列を表示する為の制御系列に変換します。
function ble-edit/info/.construct-text {
  local cols=${COLUMNS-80}
  local lines=$(((LINES?LINES:0)-_ble_textarea_gendy-2))

  local text=$1 out=
  local i iN=${#text}
  for ((i=0;i<iN;)); do
    local tail=${text:i}

    if ble/util/isprint+ "$tail"; then
      ble-edit/info/.put-simple "${#BASH_REMATCH}" "${BASH_REMATCH[0]}"
      ((i+=${#BASH_REMATCH}))
    else
      ble/util/s2c "$text" "$i"
      local code=$ret w=0
      if ((code<32)); then
        ble/util/c2s $((code+64))
        ble-edit/info/.put-atomic 2 "$_ble_term_rev^$ret$_ble_term_sgr0"
      elif ((code==127)); then
        ble-edit/info/.put-atomic 2 '$_ble_term_rev^?$_ble_term_sgr0'
      elif ((128<=code&&code<160)); then
        ble/util/c2s $((code-64))
        ble-edit/info/.put-atomic 4 "${_ble_term_rev}M-^$ret$_ble_term_sgr0"
      else
        ble/util/c2w "$code"
        ble-edit/info/.put-atomic "$ret" "${text:i:1}"
      fi

      ((y>=lines)) && break
      ((i++))
    fi
  done

  ble-edit/info/.put-nl-if-eol

  ret=$out
}

## 関数 ble-edit/info/.construct-content type text
##   @var[in,out] x y
##   @var[out]    content
function ble-edit/info/.construct-content {
  local type=$1 text=$2
  case "$1" in
  (raw)
    local lc=32 lg=0 g=0
    local -a DRAW_BUFF=()
    ble-edit/draw/trace "$text"
    ble-edit/draw/sflush -v content ;;
  (text)
    local lc=32 ret
    ble-edit/info/.construct-text "$text"
    content=$ret ;;
  (*)
    echo "usage: ble-edit/info/.construct-content type text" >&2 ;;
  esac
}


_ble_line_info=(0 0 "")

function ble-edit/info/.clear-content {
  [[ ${_ble_line_info[2]} ]] || return

  local -a DRAW_BUFF=()
  ble-form/panel#set-height.draw 1 0
  ble-edit/draw/bflush

  _ble_line_info=(0 0 "")
}

## 関数 ble-edit/info/.render-content x y content
##   @param[in] x y content
function ble-edit/info/.render-content {
  local x=$1 y=$2 content=$3

  # 既に同じ内容で表示されているとき…。
  [[ $content == "${_ble_line_info[2]}" ]] && return

  if [[ ! $content ]]; then
    ble-edit/info/.clear-content
    return
  fi

  local -a DRAW_BUFF=()
  ble-form/panel#set-height-and-clear.draw 1 $((y+1))
  ble-form/panel#goto.draw 1
  ble-edit/draw/put "$content"
  ble-edit/draw/bflush
  ((_ble_line_y+=y,_ble_line_x=x))
  _ble_line_info=("$x" "$y" "$content")
}

_ble_line_info_default=(0 0 "")
_ble_line_info_scene=default

## 関数 ble-edit/info/show type text
##
##   @param[in] type
##
##     以下の2つの内の何れかを指定する。
##
##     type=text
##     type=raw
##
##   @param[in] text
##
##     type=text のとき、引数 text は表示する文字列を含む。
##     改行などの制御文字は代替表現に置き換えられる。
##     画面からはみ出る文字列に関しては自動で truncate される。
##
##     type=raw のとき、引数 text は制御シーケンスを含む文字列を指定する。
##     画面からはみ出る様なシーケンスに対する対策はない。
##     シーケンスを生成する側でその様なことがない様にする必要がある。
##
function ble-edit/info/show {
  local type=$1 text=$2
  if [[ $text ]]; then
    local x=0 y=0 content=
    ble-edit/info/.construct-content "$type" "$text"
    ble-edit/info/.render-content "$x" "$y" "$content"
    ble/util/buffer.flush >&2
    _ble_line_info_scene=show
  else
    ble-edit/info/default
  fi
}
function ble-edit/info/set-default {
  local type=$1 text=$2
  local x=0 y=0 content
  ble-edit/info/.construct-content "$type" "$text"
  _ble_line_info_default=("$x" "$y" "$content")
}
function ble-edit/info/default {
  _ble_line_info_scene=default
  (($#)) && ble-edit/info/set-default "$@"
  return 0
}
function ble-edit/info/clear {
  ble-edit/info/default
}

## 関数 ble-edit/info/hide
## 関数 ble-edit/info/reveal
##
##   これらの関数は .newline 前後に一時的に info の表示を抑制するための関数である。
##   この関数の呼び出しの後に flush が入ることを想定して ble/util/buffer.flush は実行しない。
##
function ble-edit/info/hide {
  ble-edit/info/.clear-content
}
function ble-edit/info/reveal {
  if [[ $_ble_line_info_scene == default ]]; then
    ble-edit/info/.render-content "${_ble_line_info_default[@]}"
  fi
}

function ble-edit/info/immediate-show {
  local x=$_ble_line_x y=$_ble_line_y
  ble-edit/info/show "$@"
  local -a DRAW_BUFF=()
  ble-form/goto.draw "$x" "$y"
  ble-edit/draw/bflush
  ble/util/buffer.flush >&2
}
function ble-edit/info/immediate-clear {
  local x=$_ble_line_x y=$_ble_line_y
  ble-edit/info/clear
  ble-edit/info/reveal
  local -a DRAW_BUFF=()
  ble-form/goto.draw "$x" "$y"
  ble-edit/draw/bflush
  ble/util/buffer.flush >&2
}

# 
#------------------------------------------------------------------------------
# **** edit ****                                                          @edit

_ble_edit_VARNAMES=(
  _ble_edit_{str,ind,mark{,_active},overwrite_mode,line_disabled,arg}
  _ble_edit_kill_{ring,type}
  _ble_edit_dirty_{draw,syntax}_{beg,end,end0}
  _ble_edit_dirty_observer)
_ble_edit_ARRNAMES=()

# 現在の編集状態は以下の変数で表現される
_ble_edit_str=
_ble_edit_ind=0
_ble_edit_mark=0
_ble_edit_mark_active=
_ble_edit_overwrite_mode=
_ble_edit_line_disabled=
_ble_edit_arg=

# 以下は複数の編集文字列が合ったとして全体で共有して良いもの
_ble_edit_kill_ring=
_ble_edit_kill_type=

# _ble_edit_str は以下の関数を通して変更する。
# 変更範囲を追跡する為。
function _ble_edit_str.replace {
  local -i beg=$1 end=$2
  local ins=$3 reason=${4:-edit}

  # cf. Note#1
  _ble_edit_str="${_ble_edit_str::beg}""$ins""${_ble_edit_str:end}"
  _ble_edit_str/update-dirty-range "$beg" $((beg+${#ins})) "$end" "$reason"
#%if !release
  # Note: 何処かのバグで _ble_edit_ind に変な値が入ってエラーになるので、
  #   ここで誤り訂正を行う。想定として、この関数を呼出した時の _ble_edit_ind の値は、
  #   replace を実行する前の値とする。この関数の呼び出し元では、
  #   _ble_edit_ind の更新はこの関数の呼び出しより後で行う様にする必要がある。
  # Note: このバグは恐らく #D0411 で解決したが暫く様子見する。
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble-stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; beg=$beg, end=$end, ins(${#ins})=$ins"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end=${#_ble_edit_str}
    local olen=$((${#_ble_edit_str}-${#ins}+end-beg))
    ((olen<0&&(olen=0),
      _ble_edit_ind>olen&&(_ble_edit_ind=olen),
      _ble_edit_mark>olen&&(_ble_edit_mark=olen)))
  fi
#%end
}
function _ble_edit_str.reset {
  local str=$1 reason=${2:-edit}
  local beg=0 end=${#str} end0=${#_ble_edit_str}
  _ble_edit_str=$str
  _ble_edit_str/update-dirty-range "$beg" "$end" "$end0" "$reason"
#%if !release
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble-stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; str(${#str})=$str"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end=${#_ble_edit_str}
  fi
#%end
}
function _ble_edit_str.reset-and-check-dirty {
  local str=$1 reason=${2:-edit}
  [[ $_ble_edit_str == "$str" ]] && return

  local ret pref suff
  ble/string#common-prefix "$_ble_edit_str" "$str"; pref=$ret
  local dmin=${#pref}
  ble/string#common-suffix "${_ble_edit_str:dmin}" "${str:dmin}"; suff=$ret
  local dmax0=$((${#_ble_edit_str}-${#suff})) dmax=$((${#str}-${#suff}))

  _ble_edit_str=$str
  _ble_edit_str/update-dirty-range "$dmin" "$dmax" "$dmax0" "$reason"
}

_ble_edit_dirty_draw_beg=-1
_ble_edit_dirty_draw_end=-1
_ble_edit_dirty_draw_end0=-1

_ble_edit_dirty_syntax_beg=0
_ble_edit_dirty_syntax_end=0
_ble_edit_dirty_syntax_end0=1

_ble_edit_dirty_observer=()
## 関数 _ble_edit_str/update-dirty-range beg end end0 [reason]
##  @param[in] beg end end0
##    変更範囲を指定します。
##  @param[in] reason
##    変更の理由を表す文字列を指定します。
function _ble_edit_str/update-dirty-range {
  ble/dirty-range#update --prefix=_ble_edit_dirty_draw_ "${@:1:3}"
  ble/dirty-range#update --prefix=_ble_edit_dirty_syntax_ "${@:1:3}"
  ble/textmap#update-dirty-range "${@:1:3}"

  local obs
  for obs in "${_ble_edit_dirty_observer[@]}"; do "$obs" "$@"; done
  # ble-assert '((
  #   _ble_edit_dirty_draw_beg==_ble_edit_dirty_syntax_beg&&
  #   _ble_edit_dirty_draw_end==_ble_edit_dirty_syntax_end&&
  #   _ble_edit_dirty_draw_end0==_ble_edit_dirty_syntax_end0))'
}

function _ble_edit_str.update-syntax {
  if ble/util/isfunction ble-syntax/parse; then
    local beg end end0
    ble/dirty-range#load --prefix=_ble_edit_dirty_syntax_
    if ((beg>=0)); then
      ble/dirty-range#clear --prefix=_ble_edit_dirty_syntax_
      ble-syntax/parse "$_ble_edit_str" "$beg" "$end" "$end0"
    fi
  fi
}

## 関数 ble-edit/content/bolp
##   現在カーソルが行頭に位置しているかどうかを判定します。
function ble-edit/content/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
## 関数 ble-edit/content/bolp
##   現在カーソルが行末に位置しているかどうかを判定します。
function ble-edit/content/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
## 関数 ble-edit/content/find-logical-eol [index [offset]]; ret
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の終端位置を返します。
##
##   offset が 0 の場合は位置 index を含む行の行末を返します。
##   offset が正で offset 次の行がない場合は ${#_ble_edit_str} を返します。
##
function ble-edit/content/find-logical-eol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local text=${_ble_edit_str:index}
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?[^\n]*'
    [[ $text =~ $rex ]]
    ((ret=index+${#BASH_REMATCH}))
    [[ ${BASH_REMATCH[2]} ]]
  elif ((offset<0)); then
    local text=${_ble_edit_str::index}
    local rex=$'(\n[^\n]*){0,'$((-offset-1))$'}(\n[^\n]*)?$'
    [[ $text =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index-${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-eol "$index" 0
      return 1
    fi
  else
    local text=${_ble_edit_str:index}
    text=${text%%$'\n'*}
    ((ret=index+${#text}))
    return 0
  fi
}
## 関数 ble-edit/content/find-logical-bol [index [offset]]; ret
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の先頭位置を返します。
##
##   offset が 0 の場合は位置 index を含む行の行頭を返します。
##   offset が正で offset だけ次の行がない場合は最終行の行頭を返します。
##   特に次の行がない場合は現在の行頭を返します。
##
function ble-edit/content/find-logical-bol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?'
    [[ ${_ble_edit_str:index} =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index+${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-bol "$index" 0
      return 1
    fi
  elif ((offset<0)); then
    ble-edit/content/find-logical-eol "$index" "$offset"; local ext=$?
    ble-edit/content/find-logical-bol "$ret" 0
    return "$ext"
  else
    local text=${_ble_edit_str::index}
    text=${text##*$'\n'}
    ((ret=index-${#text}))
    return 0
  fi
}

## 関数 ble-edit/content/is-single-line
function ble-edit/content/is-single-line {
  [[ $_ble_edit_str != *$'\n'* ]]
}

function ble-edit/content/get-arg {
  eval "${ble_util_upvar_setup//ret/arg}"

  local default_value=$1
  if [[ $_ble_edit_arg == -* ]]; then
    if [[ $_ble_edit_arg == - ]]; then
      arg=-1
    else
      arg=$((-10#0${_ble_edit_arg#-}))
    fi
  else
    if [[ $_ble_edit_arg ]]; then
      arg=$((10#0$_ble_edit_arg))
    else
      arg=$default_value
    fi
  fi
  _ble_edit_arg=

  eval "${ble_util_upvar//ret/arg}"
}
function ble-edit/content/clear-arg {
  _ble_edit_arg=
}

# **** PS1/LINENO ****                                                @edit.ps1
#
# 内部使用変数
## @var _ble_edit_LINENO
##   LINENO の値を保持します。
##   コマンドラインで処理・キャンセルした行数の合計です。
## @var _ble_edit_CMD
##   プロンプトで \# として参照される変数です。
##   実際のコマンド実行の回数を保持します。
##   PS0 の評価後に増加します。
## @var _ble_edit_PS1

_ble_edit_PS1_adjusted=
_ble_edit_PS1='\s-\v\$ '
function ble-edit/adjust-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] && return
  _ble_edit_PS1_adjusted=1
  _ble_edit_PS1=$PS1
  [[ $bleopt_suppress_bash_output ]] || PS1=
}
function ble-edit/restore-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] || return
  _ble_edit_PS1_adjusted=
  PS1=$_ble_edit_PS1
}

function ble-edit/attach/TRAPWINCH {
  local IFS=$' \t\n'
  if ((_ble_edit_attached)); then
    if [[ ! $_ble_textarea_invalidated && $_ble_term_state == internal ]]; then
      _ble_textmap_pos=()
      ble/util/joblist.check
      ble-edit/bind/stdout.on
      ble-edit/info/hide
      ble/util/buffer "$_ble_term_ed"
      ble-edit/info/reveal
      ble/textarea#redraw
      ble-edit/bind/stdout.off
      ble/util/joblist.check ignore-volatile-jobs
    fi
  fi
}

## called by ble-edit-attach
_ble_edit_attached=0
function ble-edit/attach {
  ((_ble_edit_attached)) && return
  _ble_edit_attached=1

  if [[ ! ${_ble_edit_LINENO+set} ]]; then
    _ble_edit_LINENO=${BASH_LINENO[${#BASH_LINENO[@]}-1]}
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0
    unset LINENO; LINENO=$_ble_edit_LINENO
    _ble_edit_CMD=$_ble_edit_LINENO
  fi

  ble/builtin/trap/set-readline-signal WINCH ble-edit/attach/TRAPWINCH

  ble-edit/adjust-PS1
  [[ $bleopt_exec_type == exec ]] && _ble_edit_IFS=$IFS
}

function ble-edit/detach {
  ((!_ble_edit_attached)) && return
  ble-edit/restore-PS1
  [[ $bleopt_exec_type == exec ]] && IFS=$_ble_edit_IFS
  _ble_edit_attached=0
}


# 
#------------------------------------------------------------------------------
# **** textarea ****                                                  @textarea

_ble_textarea_VARNAMES=(_ble_textarea_{bufferName,scroll,gendx,gendy,invalidated,caret_state,panel})
_ble_textarea_ARRNAMES=(_ble_textarea_{buffer,cur,cache})

# **** textarea.buffer ****                                    @textarea.buffer

_ble_textarea_buffer=()
_ble_textarea_bufferName=

## 関数 lc lg; ble/textarea#update-text-buffer; cx cy lc lg
##
##   @param[in    ] text  編集文字列
##   @param[in    ] index カーソルの index
##   @param[in,out] x     編集文字列開始位置、終了位置。
##   @param[in,out] y     編集文字列開始位置、終了位置。
##   @param[in,out] lc lg
##     カーソル左の文字のコードと gflag を返します。
##     カーソルが先頭にある場合は、編集文字列開始位置の左(プロンプトの最後の文字)について記述します。
##   @var  [   out] umin umax
##     umin,umax は再描画の必要な範囲を文字インデックスで返します。
##
##   @var[in] _ble_textmap_*
##     配置情報が最新であることを要求します。
##
function ble/textarea#update-text-buffer {
  local iN=${#text}

  # highlight -> HIGHLIGHT_BUFF
  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble-highlight-layer/update "$text"
  ble/urange#update "$HIGHLIGHT_UMIN" "$HIGHLIGHT_UMAX"

  # 変更文字の適用
  if ((${#_ble_textmap_ichg[@]})); then
    local ichg g sgr
    builtin eval "_ble_textarea_buffer=(\"\${$HIGHLIGHT_BUFF[@]}\")"
    HIGHLIGHT_BUFF=_ble_textarea_buffer
    for ichg in "${_ble_textmap_ichg[@]}"; do
      ble-highlight-layer/getg "$ichg"
      ble-color-g2sgr -v sgr "$g"
      _ble_textarea_buffer[ichg]=$sgr${_ble_textmap_glyph[ichg]}
    done
  fi

  _ble_textarea_bufferName=$HIGHLIGHT_BUFF

  # update lc, lg
  #
  #   lc, lg は bleopt_suppress_bash_output= の時に bash に出力させる文字と
  #   その属性を表す。READLINE_LINE が空だと C-d を押した時にその場でログアウト
  #   してしまったり、エラーメッセージが表示されたりする。その為 READLINE_LINE
  #   に有限の長さの文字列を設定したいが、そうするとそれが画面に出てしまう。
  #   そこで、ble.sh では現在のカーソル位置にある文字と同じ文字を READLINE_LINE
  #   に設定する事で、bash が文字を出力しても見た目に問題がない様にしている。
  #
  #   cx==0 の時には現在のカーソル位置の右にある文字を READLINE_LINE に設定し
  #   READLINE_POINT=0 とする。cx>0 の時には現在のカーソル位置の左にある文字を
  #   READLINE_LINE に設定し READLINE_POINT=(左の文字のバイト数) とする。
  #   (READLINE_POINT は文字数ではなくバイトオフセットである事に注意する。)
  #
  if [[ $bleopt_suppress_bash_output ]]; then
    lc=32 lg=0
  else
    # index==0 の場合は受け取った lc lg をそのまま返す
    if ((index>0)); then
      local cx cy
      ble/textmap#getxy.cur --prefix=c "$index"

      local lcs ret
      if ((cx==0)); then
        # 次の文字
        if ((index==iN)); then
          # 次の文字がない時は空白
          ret=32
        else
          lcs=${_ble_textmap_glyph[index]}
          ble/util/s2c "$lcs" 0
        fi

        # 次が改行の時は空白にする
        ble-highlight-layer/getg -v lg "$index"
        ((lc=ret==10?32:ret))
      else
        # 前の文字
        lcs=${_ble_textmap_glyph[index-1]}
        ble/util/s2c "$lcs" $((${#lcs}-1))
        ble-highlight-layer/getg -v lg $((index-1))
        ((lc=ret))
      fi
    fi
  fi
}
## 関数 ble/textarea#slice-text-buffer [beg [end]]
##   @var [out] ret
function ble/textarea#slice-text-buffer {
  ble/textmap#assert-up-to-date
  local iN=$_ble_textmap_length
  local i1=${1:-0} i2=${2:-$iN}
  ((i1<0&&(i1+=iN,i1<0&&(i1=0)),
    i2<0&&(i2+=iN)))
  if ((i1<i2&&i1<iN)); then
    local g sgr
    ble-highlight-layer/getg -v g "$i1"
    ble-color-g2sgr -v sgr "$g"
    IFS= builtin eval "ret=\"\$sgr\${$_ble_textarea_bufferName[*]:i1:i2-i1}\""
  else
    ret=
  fi
}

# 
# **** textarea.render ****                                    @textarea.render

#
# 大域変数
#

## 配列 _ble_textarea_cur
##     キャレット位置 (ユーザに対して呈示するカーソル) と其処の文字の情報を保持します。
##   _ble_textarea_cur[0] x   キャレット描画位置の y 座標を保持します。
##   _ble_textarea_cur[1] y   キャレット描画位置の y 座標を保持します。
##   _ble_textarea_cur[2] lc
##     キャレット位置の左側の文字の文字コードを整数で保持します。
##     キャレットが最も左の列にある場合は右側の文字を保持します。
##   _ble_textarea_cur[3] lg
##     キャレット位置の左側の SGR フラグを保持します。
##     キャレットが最も左の列にある場合は右側の文字に適用される SGR フラグを保持します。
_ble_textarea_cur=(0 0 32 0)

_ble_textarea_panel=0
_ble_textarea_scroll=
_ble_textarea_gendx=0
_ble_textarea_gendy=0

#
# 表示関数
#

## 変数 _ble_textarea_invalidated
##   完全再描画 (プロンプトも含めた) を要求されたことを記録します。
##   完全再描画の要求前に空文字列で、要求後に 1 の値を持ちます。
_ble_textarea_invalidated=1

function ble/textarea#invalidate {
  _ble_textarea_invalidated=1
}


## 関数 ble/textarea#render/.determine-scroll
##   新しい表示高さとスクロール位置を決定します。
##   ble/textarea#render から呼び出されることを想定します。
##
##   @var[in,out] scroll
##     現在のスクロール量を指定します。調整後のスクロール量を指定します。
##   @var[in,out] height
##     最大の表示高さを指定します。実際の表示高さを返します。
##   @var[in,out] umin umax
##     描画範囲を表示領域に制限して返します。
##
##   @var[in] cols
##   @var[in] begx begy endx endy cx cy
##     それぞれ編集文字列の先端・末端・現在カーソル位置の表示座標を指定します。
##
function ble/textarea#render/.determine-scroll {
  local nline=$((endy+1))
  if ((nline>height)); then
    ((scroll<=nline-height)) || ((scroll=nline-height))

    local _height=$((height-begy)) _nline=$((nline-begy)) _cy=$((cy-begy))
    local margin=$((_height>=6&&_nline>_height+2?2:1))
    local smin smax
    ((smin=_cy-_height+margin,
      smin>nline-height&&(smin=nline-height),
      smax=_cy-margin,
      smax<0&&(smax=0)))
    if ((scroll>smax)); then
      scroll=$smax
    elif ((scroll<smin)); then
      scroll=$smin
    fi

    # [umin, umax] を表示範囲で制限する。
    #
    # Note: scroll == 0 の時は表示1行目から表示する。
    #   scroll > 0 の時は表示1行目には ... だけを表示し、
    #   表示2行目から表示する。
    #
    local wmin=0 wmax index
    if ((scroll)); then
      ble/textmap#get-index-at 0 $((scroll+begy+1)); wmin=$index
    fi
    ble/textmap#get-index-at "$cols" $((scroll+height-1)); wmax=$index
    ((umin<umax)) &&
      ((umin<wmin&&(umin=wmin),
        umax>wmax&&(umax=wmax)))
  else
    scroll=
    height=$nline
  fi
}
## 関数 ble/textarea#render/.perform-scroll
##
##   @var[out] DRAW_BUFF
##     スクロールを実行するシーケンスの出力先です。
##
##   @var[in] height cols
##   @var[in] begx begy
##
function ble/textarea#render/.perform-scroll {
  local new_scroll=$1
  if ((new_scroll!=_ble_textarea_scroll)); then
    local scry=$((begy+1))
    local scrh=$((height-scry))

    # 行の削除と挿入および新しい領域 [fmin, fmax] の決定
    local fmin fmax index
    if ((_ble_textarea_scroll>new_scroll)); then
      local shift=$((_ble_textarea_scroll-new_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble-form/panel#goto.draw "$_ble_textarea_panel" 0 $((height-draw_shift))
      ble-edit/draw/put.dl "$draw_shift"
      ble-form/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble-edit/draw/put.il "$draw_shift"

      if ((new_scroll==0)); then
        fmin=0
      else
        ble/textmap#get-index-at 0 $((scry+new_scroll)); fmin=$index
      fi
      ble/textmap#get-index-at "$cols" $((scry+new_scroll+draw_shift-1)); fmax=$index
    else
      local shift=$((new_scroll-_ble_textarea_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble-form/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble-edit/draw/put.dl "$draw_shift"
      ble-form/panel#goto.draw "$_ble_textarea_panel" 0 $((height-draw_shift))
      ble-edit/draw/put.il "$draw_shift"

      ble/textmap#get-index-at 0 $((new_scroll+height-draw_shift)); fmin=$index
      ble/textmap#get-index-at "$cols" $((new_scroll+height-1)); fmax=$index
    fi

    # 新しく現れた範囲 [fmin, fmax] を埋める
    if ((fmin<fmax)); then
      local fmaxx fmaxy fminx fminy
      ble/textmap#getxy.out --prefix=fmin "$fmin"
      ble/textmap#getxy.out --prefix=fmax "$fmax"

      ble-form/panel#goto.draw "$_ble_textarea_panel" "$fminx" $((fminy-new_scroll))
      ((new_scroll==0)) && ble-edit/draw/put "$_ble_term_sgr0$_ble_term_el" # ... を消す
      local ret; ble/textarea#slice-text-buffer "$fmin" "$fmax"
      ble-edit/draw/put "$ret"
      ((_ble_line_x=fmaxx,
        _ble_line_y+=fmaxy-fminy))

      ((umin<umax)) &&
        ((fmin<=umin&&umin<fmax&&(umin=fmax),
          fmin<umax&&umax<=fmax&&(umax=fmin)))
    fi

    _ble_textarea_scroll=$new_scroll

    ble/textarea#render/.show-scroll-at-first-line
  fi
}
## 関数 ble/textarea#render/.show-scroll-at-first-line
##   スクロール時 "(line 3) ..." などの表示
##
##   @var[in] _ble_textarea_scroll
##   @var[in,out] DRAW_BUFF _ble_line_x _ble_line_y
##
function ble/textarea#render/.show-scroll-at-first-line {
  if ((_ble_textarea_scroll!=0)); then
    ble-form/panel#goto.draw "$_ble_textarea_panel" "$begx" "$begy"
    local scroll_status="(line $((_ble_textarea_scroll+2))) ..."
    scroll_status=${scroll_status::cols-1-begx}
    ble-edit/draw/put "$_ble_term_sgr0$_ble_term_el$_ble_term_bold$scroll_status$_ble_term_sgr0"
    ((_ble_line_x+=${#scroll_status}))
  fi
}

## 関数 ble/textarea#focus
##   プロンプト・編集文字列の現在位置に端末のカーソルを移動します。
function ble/textarea#focus {
  local -a DRAW_BUFF=()
  ble-form/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
  ble-edit/draw/bflush
}

## 関数 ble/textarea#render
##   プロンプト・編集文字列の表示更新を ble/util/buffer に対して行う。
##   Post-condition: カーソル位置 (x y) = (_ble_textarea_cur[0] _ble_textarea_cur[1]) に移動する
##   Post-condition: 編集文字列部分の再描画を実行する
##
##   @var _ble_textarea_caret_state := inds ':' mark ':' mark_active ':' line_disabled ':' overwrite_mode
##     ble/textarea#render で用いる変数です。
##     現在の表示内容のカーソル位置・ポイント位置の情報を記録します。
##
_ble_textarea_caret_state=::
function ble/textarea#render {
  local caret_state=$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active:$_ble_edit_line_disabled:$_ble_edit_overwrite_mode
  if [[ $_ble_edit_dirty_draw_beg -lt 0 && ! $_ble_textarea_invalidated && $_ble_textarea_caret_state == "$caret_state" ]]; then
    ble/textarea#focus
    return
  fi

  #-------------------
  # 描画内容の計算 (配置情報、着色文字列)

  local ret

  local x y g lc lg=0
  ble-edit/prompt/update # x y lc ret
  local prox=$x proy=$y prolc=$lc esc_prompt=$ret

  # BLELINE_RANGE_UPDATE → ble/textarea#update-text-buffer 内でこれを見て update を済ませる
  local -a BLELINE_RANGE_UPDATE
  BLELINE_RANGE_UPDATE=("$_ble_edit_dirty_draw_beg" "$_ble_edit_dirty_draw_end" "$_ble_edit_dirty_draw_end0")
  ble/dirty-range#clear --prefix=_ble_edit_dirty_draw_
#%if !release
  ble-assert '((BLELINE_RANGE_UPDATE[0]<0||(
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[1]&&
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[2])))' "(${BLELINE_RANGE_UPDATE[*]})"
#%end

  # local graphic_dbeg graphic_dend graphic_dend0
  # ble/dirty-range#update --prefix=graphic_d

  # 編集内容の構築
  local text=$_ble_edit_str index=$_ble_edit_ind
  local iN=${#text}
  ((index<0?(index=0):(index>iN&&(index=iN))))

  local umin=-1 umax=-1

  # 配置情報の更新
  ble/textmap#update # text x y → x y
  ble/urange#update "$_ble_textmap_umin" "$_ble_textmap_umax"
  ble/urange#clear --prefix=_ble_textmap_

  # 着色の更新
  ble/textarea#update-text-buffer # text index -> lc lg

  #-------------------
  # 描画領域の決定とスクロール

  local -a DRAW_BUFF=()

  # 1 描画領域の決定
  local begx=$_ble_textmap_begx begy=$_ble_textmap_begy
  local endx=$_ble_textmap_endx endy=$_ble_textmap_endy
  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index" # → cx cy

  local cols=$_ble_textmap_cols
  local height=$((LINES-1)) # ToDo: info の高さも考慮に入れる
  local scroll=$_ble_textarea_scroll
  ble/textarea#render/.determine-scroll # update: height scroll umin umax
  ble-form/panel#set-height.draw "$_ble_textarea_panel" "$height"

  local gend gendx gendy
  if [[ $scroll ]]; then
    ble/textmap#get-index-at "$cols" $((height+scroll-1)); gend=$index
    ble/textmap#getxy.out --prefix=gend "$gend"
    ((gendy-=scroll))
  else
    gend=$iN gendx=$endx gendy=$endy
  fi
  _ble_textarea_gendx=$gendx _ble_textarea_gendy=$gendy

  #-------------------
  # 出力

  # 2 表示内容
  local ret esc_line= esc_line_set=
  if [[ ! $_ble_textarea_invalidated ]]; then
    # 部分更新の場合

    ble/textarea#render/.perform-scroll "$scroll" # update: umin umax

    # 編集文字列の一部を描画する場合
    if ((umin<umax)); then
      local uminx uminy umaxx umaxy
      ble/textmap#getxy.out --prefix=umin "$umin"
      ble/textmap#getxy.out --prefix=umax "$umax"

      ble-form/panel#goto.draw "$_ble_textarea_panel" "$uminx" $((uminy-_ble_textarea_scroll))
      ble/textarea#slice-text-buffer "$umin" "$umax"
      ble-edit/draw/put "$ret"
      ble-form/panel#report-cursor-position "$_ble_textarea_panel" "$umaxx" $((umaxy-_ble_textarea_scroll))
    fi

    if ((BLELINE_RANGE_UPDATE[0]>=0)); then
      local endY=$((endy-_ble_textarea_scroll))
      ((endY<height)) && ble-form/panel#clear-after.draw "$_ble_textarea_panel" "$endx" "$endY"
    fi
  else
    # 全体更新
    ble-form/panel#clear.draw "$_ble_textarea_panel"

    # プロンプト描画
    ble-form/panel#goto.draw "$_ble_textarea_panel"
    ble-edit/draw/put "$esc_prompt"
    ble-form/panel#report-cursor-position "$_ble_textarea_panel" "$prox" "$proy"

    # 全体描画
    _ble_textarea_scroll=$scroll
    if [[ ! $_ble_textarea_scroll ]]; then
      ble/textarea#slice-text-buffer # → ret
      esc_line=$ret esc_line_set=1
      ble-edit/draw/put "$ret"
      ble-form/panel#report-cursor-position "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    else
      ble/textarea#render/.show-scroll-at-first-line

      local gbeg=0
      if ((_ble_textarea_scroll)); then
        ble/textmap#get-index-at 0 $((_ble_textarea_scroll+begy+1)); gbeg=$index
      fi

      local gbegx gbegy
      ble/textmap#getxy.out --prefix=gbeg "$gbeg"
      ((gbegy-=_ble_textarea_scroll))

      ble-form/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
      ((_ble_textarea_scroll==0)) && ble-edit/draw/put "$_ble_term_sgr0$_ble_term_el" # ... を消す
      ble/textarea#slice-text-buffer "$gbeg" "$gend"
      ble-edit/draw/put "$ret"
      ble-form/panel#report-cursor-position "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    fi
  fi

  # 3 移動
  local gcx=$cx gcy=$((cy-_ble_textarea_scroll))
  ble-form/panel#goto.draw "$_ble_textarea_panel" "$gcx" "$gcy"
  ble-edit/draw/bflush

  # 4 後で使う情報の記録
  _ble_textarea_cur=("$gcx" "$gcy" "$lc" "$lg")
  _ble_textarea_invalidated= _ble_textarea_caret_state=$caret_state

  if [[ ! $bleopt_suppress_bash_output ]]; then
    if [[ ! $esc_line_set ]]; then
      if [[ ! $_ble_textarea_scroll ]]; then
        ble/textarea#slice-text-buffer
        esc_line=$ret
      else
        local _ble_line_x=$begx _ble_line_y=$begy
        DRAW_BUFF=()

        ble/textarea#render/.show-scroll-at-first-line

        local gbeg=0
        if ((_ble_textarea_scroll)); then
          ble/textmap#get-index-at 0 $((_ble_textarea_scroll+begy+1)); gbeg=$index
        fi
        local gbegx gbegy
        ble/textmap#getxy.out --prefix=gbeg "$gbeg"
        ((gbegy-=_ble_textarea_scroll))

        ble-form/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
        ((_ble_textarea_scroll==0)) && ble-edit/draw/put "$_ble_term_sgr0$_ble_term_el" # ... を消す
        ble/textarea#slice-text-buffer "$gbeg" "$gend"
        ble-edit/draw/put "$ret"

        ble-edit/draw/sflush -v esc_line
      fi
    fi

    _ble_textarea_cache=(
      "$esc_prompt$esc_line"
      "${_ble_textarea_cur[@]}"
      "$_ble_textarea_gendx" "$_ble_textarea_gendy")
  fi
}
function ble/textarea#redraw {
  ble/textarea#invalidate
  ble/textarea#render
}

## 配列 _ble_textarea_cache
##   現在表示している内容のキャッシュです。
##   ble/textarea#render で値が設定されます。
##   ble/textarea#redraw-cache はこの情報を元に再描画を行います。
## _ble_textarea_cache[0]:        表示内容
## _ble_textarea_cache[1]: curx   カーソル位置 x
## _ble_textarea_cache[2]: cury   カーソル位置 y
## _ble_textarea_cache[3]: curlc  カーソル位置の文字の文字コード
## _ble_textarea_cache[4]: curlg  カーソル位置の文字の SGR フラグ
## _ble_textarea_cache[5]: gendx  表示末端位置 x
## _ble_textarea_cache[6]: gendy  表示末端位置 y
_ble_textarea_cache=()

function ble/textarea#redraw-cache {
  if [[ ! $_ble_textarea_scroll && ${_ble_textarea_cache[0]+set} ]]; then
    local -a d; d=("${_ble_textarea_cache[@]}")

    local -a DRAW_BUFF=()

    ble-form/panel#clear.draw "$_ble_textarea_panel"
    ble-form/panel#goto.draw "$_ble_textarea_panel"
    ble-edit/draw/put "${d[0]}"
    ble-form/panel#report-cursor-position "$_ble_textarea_panel" "${d[5]}" "${d[6]}"
    _ble_textarea_gendx=${d[5]}
    _ble_textarea_gendy=${d[6]}

    _ble_textarea_cur=("${d[@]:1:4}")
    ble-form/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble-edit/draw/bflush
  else
    ble/textarea#redraw
  fi
}

## 関数 ble/textarea#adjust-for-bash-bind
##   プロンプト・編集文字列の表示位置修正を行う。
##
## @remarks
##   この関数は bind -x される関数から呼び出される事を想定している。
##   通常のコマンドとして実行される関数から呼び出す事は想定していない。
##   内部で PS1= 等の設定を行うのでプロンプトの情報が失われる。
##   また、READLINE_LINE, READLINE_POINT 等のグローバル変数の値を変更する。
##
## 2018-03-19
##   どうやら stty -echo の時には READLINE_LINE に値が設定されていても、
##   Bash は何も出力しないという事の様である。
##   従って、単に FEADLINE_LINE に文字を設定すれば良い。
##
function ble/textarea#adjust-for-bash-bind {
  if [[ $bleopt_suppress_bash_output ]]; then
    PS1= READLINE_LINE=$'\n' READLINE_POINT=0
  else
    # bash が表示するプロンプトを見えなくする
    # (現在のカーソルの左側にある文字を再度上書きさせる)
    local -a DRAW_BUFF=()
    PS1=
    local ret lc=${_ble_textarea_cur[2]} lg=${_ble_textarea_cur[3]}
    ble/util/c2s "$lc"
    READLINE_LINE=$ret
    if ((_ble_textarea_cur[0]==0)); then
      READLINE_POINT=0
    else
      ble/util/c2w "$lc"
      ((ret>0)) && ble-edit/draw/put.cub "$ret"
      ble-text-c2bc "$lc"
      READLINE_POINT=$ret
    fi

    ble-color-g2sgr "$lg"
    ble-edit/draw/put "$ret"

    # 2018-03-19 stty -echo の時は Bash は何も出力しないので調整は不要
    #ble-edit/draw/bflush
  fi
}

function ble/textarea#save-state {
  local prefix=$1
  local -a vars=() arrs=()

  # _ble_edit_prompt
  ble/array#push arrs _ble_edit_prompt
  ble/array#push vars _ble_edit_PS1

  # _ble_edit_*
  ble/array#push vars "${_ble_edit_VARNAMES[@]}"
  ble/array#push arrs "${_ble_edit_ARRNAMES[@]}"

  # _ble_edit_undo_*
  ble/array#push vars "${_ble_edit_undo_VARNAMES[@]}"
  ble/array#push arrs "${_ble_edit_undo_ARRNAMES[@]}"

  # _ble_textmap_*
  ble/array#push vars "${_ble_textmap_VARNAMES[@]}"
  ble/array#push arrs "${_ble_textmap_ARRNAMES[@]}"

  # _ble_highlight_layer_*
  ble/array#push arrs _ble_highlight_layer__list
  local layer names
  for layer in "${_ble_highlight_layer__list[@]}"; do
    eval "names=(\"\${!_ble_highlight_layer_$layer@}\")"
    for name in "${names[@]}"; do
      if ble/is-array "$name"; then
        ble/array#push arrs "$name"
      else
        ble/array#push vars "$name"
      fi
    done
  done

  # _ble_textarea_*
  ble/array#push vars "${_ble_textarea_VARNAMES[@]}"
  ble/array#push arrs "${_ble_textarea_ARRNAMES[@]}"

  # _ble_syntax_*
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"
  ble/array#push arrs "${_ble_syntax_ARRNAMES[@]}"

  eval "${prefix}_VARNAMES=(\"\${vars[@]}\")"
  eval "${prefix}_ARRNAMES=(\"\${arrs[@]}\")"
  ble/util/save-vars "$prefix" "${vars[@]}"
  ble/util/save-arrs "$prefix" "${arrs[@]}"
}
function ble/textarea#restore-state {
  local prefix=$1
  if eval "[[ \$prefix && \${${prefix}_VARNAMES+set} && \${${prefix}_ARRNAMES+set} ]]"; then
    eval "ble/util/restore-vars $prefix \"\${${prefix}_VARNAMES[@]}\""
    eval "ble/util/restore-arrs $prefix \"\${${prefix}_ARRNAMES[@]}\""
  else
    echo "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}
function ble/textarea#clear-state {
  local prefix=$1
  if [[ $prefix ]]; then
    local vars=${prefix}_VARNAMES arrs=${prefix}_ARRNAMES
    eval "unset \"\${$vars[@]/#/$prefix}\" \"\${$arrs[@]/#/$prefix}\" $vars $arrs"
  else
    echo "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}

# 
# **** redraw, clear-screen, etc ****                             @widget.clear

function ble/widget/.update-textmap {
  local text=$_ble_edit_str x=$_ble_textmap_begx y=$_ble_textmap_begy
  ble/textmap#update
}
function ble/widget/redraw-line {
  ble-edit/content/clear-arg
  ble/textarea#invalidate
}
function ble/widget/clear-screen {
  ble-edit/content/clear-arg
  ble-edit/info/hide
  ble/textarea#invalidate
  ble/util/buffer "$_ble_term_clear"
  _ble_line_x=0 _ble_line_y=0
  ble/term/visible-bell/cancel-erasure
}
function ble/widget/display-shell-version {
  ble-edit/content/clear-arg
  ble/widget/.SHELL_COMMAND 'builtin echo "GNU bash, version $BASH_VERSION ($MACHTYPE) with ble.sh"'
}

# 
# **** mark, kill, copy ****                                       @widget.mark

function ble/widget/overwrite-mode {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=1
  fi
}

function ble/widget/set-mark {
  ble-edit/content/clear-arg
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=1
}
function ble/widget/kill-forward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind>=${#_ble_edit_str})) && return

  _ble_edit_kill_ring=${_ble_edit_str:_ble_edit_ind}
  _ble_edit_kill_type=
  _ble_edit_str.replace "$_ble_edit_ind" "${#_ble_edit_str}" ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble/widget/kill-backward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind==0)) && return
  _ble_edit_kill_ring=${_ble_edit_str::_ble_edit_ind}
  _ble_edit_kill_type=
  _ble_edit_str.replace 0 _ble_edit_ind ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble/widget/exchange-point-and-mark {
  ble-edit/content/clear-arg
  local m=$_ble_edit_mark p=$_ble_edit_ind
  _ble_edit_ind=$m _ble_edit_mark=$p
}
function ble/widget/yank {
  ble-edit/content/clear-arg
  ble/widget/.insert-string "$_ble_edit_kill_ring"
}
function ble/widget/@marked {
  if [[ $_ble_edit_mark_active != S ]]; then
    _ble_edit_mark=$_ble_edit_ind
    _ble_edit_mark_active=S
  fi
  "ble/widget/$@"
}
function ble/widget/@nomarked {
  if [[ $_ble_edit_mark_active == S ]]; then
    _ble_edit_mark_active=
  fi
  "ble/widget/$@"
}

## 関数 ble/widget/.process-range-argument P0 P1; p0 p1 len ?
## @param[in]  P0  範囲の端点を指定します。
## @param[in]  P1  もう一つの範囲の端点を指定します。
## @param[out] p0  範囲の開始点を返します。
## @param[out] p1  範囲の終端点を返します。
## @param[out] len 範囲の長さを返します。
## @param[out] $?
##   範囲が有限の長さを持つ場合に正常終了します。
##   範囲が空の場合に 1 を返します。
function ble/widget/.process-range-argument {
  p0=$1 p1=$2 len=${#_ble_edit_str}
  local pt
  ((
    p0>len?(p0=len):p0<0&&(p0=0),
    p1>len?(p1=len):p0<0&&(p1=0),
    p1<p0&&(pt=p1,p1=p0,p0=pt),
    (len=p1-p0)>0
  ))
}
## 関数 ble/widget/.delete-range P0 P1 [allow_empty]
function ble/widget/.delete-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

  # delete
  if ((len)); then
    _ble_edit_str.replace p0 p1 ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## 関数 ble/widget/.kill-range P0 P1 [allow_empty [kill_type]]
function ble/widget/.kill-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

  # copy
  _ble_edit_kill_ring=${_ble_edit_str:p0:len}
  _ble_edit_kill_type=$4

  # delete
  if ((len)); then
    _ble_edit_str.replace p0 p1 ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## 関数 ble/widget/.copy-range P0 P1 [allow_empty [kill_type]]
function ble/widget/.copy-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

  # copy
  _ble_edit_kill_ring=${_ble_edit_str:p0:len}
  _ble_edit_kill_type=$4
}
## 関数 ble/widget/.replace-range P0 P1 string [allow_empty]
function ble/widget/.replace-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($4)) || return 1
  local str=$3 strlen=${#3}

  _ble_edit_str.replace p0 p1 "$str"
  local delta
  ((delta=strlen-len)) &&
    ((_ble_edit_ind>p1?(_ble_edit_ind+=delta):
      _ble_edit_ind>p0+strlen&&(_ble_edit_ind=p0+strlen),
      _ble_edit_mark>p1?(_ble_edit_mark+=delta):
      _ble_edit_mark>p0+strlen&&(_ble_edit_mark=p0+strlen)))
  return 0
}
## 関数 ble/widget/delete-region
##   領域を削除します。
function ble/widget/delete-region {
  ble-edit/content/clear-arg
  ble/widget/.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/kill-region
##   領域を切り取ります。
function ble/widget/kill-region {
  ble-edit/content/clear-arg
  ble/widget/.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/copy-region
##   領域を転写します。
function ble/widget/copy-region {
  ble-edit/content/clear-arg
  ble/widget/.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/delete-region-or widget
##   mark が active の時に領域を削除します。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/delete-region
  else
    "ble/widget/$@"
  fi
}
## 関数 ble/widget/kill-region-or widget
##   mark が active の時に領域を切り取ります。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/kill-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/kill-region
  else
    "ble/widget/$@"
  fi
}
## 関数 ble/widget/copy-region-or widget
##   mark が active の時に領域を転写します。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/copy-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/copy-region
  else
    "ble/widget/$@"
  fi
}

# 
# **** bell ****                                                     @edit.bell

function ble/widget/.bell {
  [[ $bleopt_edit_vbell ]] && ble/term/visible-bell "$1"
  [[ $bleopt_edit_abell ]] && ble/term/audible-bell
  return 0
}
function ble/widget/bell {
  ble-edit/content/clear-arg
  ble/widget/.bell
  _ble_edit_mark_active=
  _ble_edit_arg=
}

# 
# **** insert ****                                                 @edit.insert

function ble/widget/insert-string {
  local IFS=$_ble_term_IFS
  local content="$*"
  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repitition number $arg"
    return 1
  elif ((arg==0)); then
    return 0
  elif ((arg>1)); then
    local ret; ble/string#repeat "$content" "$arg"; content=$ret
  fi
  ble/widget/.insert-string "$content"
}
function ble/widget/.insert-string {
  local insert=$1
  [[ $insert ]] || return 1

  local dx=${#insert}
  _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_ind" "$insert"
  ((
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  ))
  _ble_edit_mark_active=
}

## 編集関数 self-insert
##   文字を挿入する。
##
##   @var[in] _ble_edit_arg
##     繰り返し回数を指定する。
##
##   @var[in] ble_widget_self_insert_opts
##     コロン区切りの設定のリストを指定する。
##
##     nolineext は上書きモードにおいて、行の長さを拡張しない。
##     行の長さが足りない場合は操作をキャンセルする。
##     vi.sh の r, gr による挿入を想定する。
##
function ble/widget/self-insert {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ((code==0)) && return

  local ibeg=$_ble_edit_ind iend=$_ble_edit_ind
  local ret ins; ble/util/c2s "$code"; ins=$ret

  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repitition number $arg"
    return 1
  elif ((arg==0)) || [[ ! $ins ]]; then
    arg=0 ins=
  elif ((arg>1)); then
    ble/string#repeat "$ins" "$arg"; ins=$ret
  fi
  # Note: arg はこの時点での ins の文字数になっているとは限らない。
  #   現在の LC_CTYPE で対応する文字がない場合 \uXXXX 等に変換される為。

  if [[ $bleopt_delete_selection_mode && $_ble_edit_mark_active ]]; then
    # 選択範囲を置き換える。
    ((_ble_edit_mark<_ble_edit_ind?(ibeg=_ble_edit_mark):(iend=_ble_edit_mark),
      _ble_edit_ind=ibeg))
    ((arg==0&&ibeg==iend)) && return
  elif [[ $_ble_edit_overwrite_mode ]] && ((code!=10&&code!=9)); then
    ((arg==0)) && return

    local removed_width
    if [[ $_ble_edit_overwrite_mode == R ]]; then
      local removed_text=${_ble_edit_str:ibeg:arg}
      removed_text=${removed_text%%[$'\n\t']*}
      removed_width=${#removed_text}
      ((iend+=removed_width))
    else
      # 上書きモードの時は Unicode 文字幅を考慮して既存の文字を置き換える。
      # ※現在の LC_CTYPE で対応する文字がない場合でも、意図しない動作を防ぐために、
      #   対応していたと想定した時の文字幅で削除する。
      local ret w; ble/util/c2w-edit "$code"; w=$((arg*ret))

      local iN=${#_ble_edit_str}
      for ((removed_width=0;removed_width<w&&iend<iN;iend++)); do
        local c1 w1
        ble/util/s2c "$_ble_edit_str" "$iend"; c1=$ret
        [[ $c1 == 0 || $c1 == 10 || $c1 == 9 ]] && break
        ble/util/c2w-edit "$c1"; w1=$ret
        ((removed_width+=w1))
      done

      ((removed_width>w)) && ins=$ins${_ble_util_string_prototype::removed_width-w}
    fi

    # これは vi.sh の r gr で設定する変数
    if [[ :$ble_widget_self_insert_opts: == *:nolineext:* ]]; then
      if ((removed_width<arg)); then
        ble/widget/.bell
        return 0
      fi
    fi
  fi

  _ble_edit_str.replace ibeg iend "$ins"
  ((_ble_edit_ind+=${#ins},
    _ble_edit_mark>ibeg&&(
      _ble_edit_mark<iend?(
        _ble_edit_mark=_ble_edit_ind
      ):(
        _ble_edit_mark+=${#ins}-(iend-ibeg)))))
  _ble_edit_mark_active=
  return 0
}

# quoted insert
function ble/widget/quoted-insert.hook {
  local WIDGET=ble/widget/self-insert
  ble/widget/self-insert
}
function ble/widget/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/quoted-insert.hook
  return 148
}

function ble/widget/transpose-chars {
  local arg; ble-edit/content/get-arg ''
  if ((arg==0)); then
    [[ ! $arg ]] && ble-edit/content/eolp &&
      ((_ble_edit_ind>0&&_ble_edit_ind--))
    arg=1
  fi

  local p q r
  if ((arg>0)); then
    ((p=_ble_edit_ind-1,
      q=_ble_edit_ind,
      r=_ble_edit_ind+arg))
  else # arg<0
    ((p=_ble_edit_ind-1+arg,
      q=_ble_edit_ind,
      r=_ble_edit_ind+1))
  fi

  if ((p<0||${#_ble_edit_str}<r)); then
    ((_ble_edit_ind=arg<0?0:${#_ble_edit_str}))
    ble/widget/.bell
    return 1
  fi

  local a=${_ble_edit_str:p:q-p}
  local b=${_ble_edit_str:q:r-q}
  _ble_edit_str.replace "$p" "$r" "$b$a"
  ((_ble_edit_ind+=arg))
  return 0
}

_ble_edit_bracketed_paste=
_ble_edit_bracketed_paste_proc=
function ble/widget/bracketed-paste {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_bracketed_paste=()
  _ble_edit_bracketed_paste_proc=ble/widget/bracketed-paste.proc
  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 148
}
function ble/widget/bracketed-paste.hook {
  _ble_edit_bracketed_paste=$_ble_edit_bracketed_paste:$1

  # check terminater
  local is_end= chars=
  if chars=${_ble_edit_bracketed_paste%:27:91:50:48:49:126} # ESC [ 2 0 1 ~
     [[ $chars != $_ble_edit_bracketed_paste ]]; then is_end=1
  elif chars=${_ble_edit_bracketed_paste%:155:50:48:49:126} # CSI 2 0 1 ~
       [[ $chars != $_ble_edit_bracketed_paste ]]; then is_end=1
  fi

  if [[ ! $is_end ]]; then
    _ble_decode_char__hook=ble/widget/bracketed-paste.hook
    return 148
  fi

  chars=:${chars//:/::}:
  chars=${chars//:13::10:/:10:} # CR LF -> LF
  chars=${chars//:13:/:10:} # CR -> LF
  ble/string#split-words chars "${chars//:/ }"

  local proc=$_ble_edit_bracketed_paste_proc
  _ble_edit_bracketed_paste_proc=
  [[ $proc ]] && builtin eval -- "$proc \"\${chars[@]}\""
}
function ble/widget/bracketed-paste.proc {
  local -a KEYS
  local char WIDGET=ble/widget/self-insert
  for char; do
    KEYS=("$char")
    "$WIDGET"
  done
}

# 
# **** delete-char ****                                            @edit.delete

function ble/widget/.delete-backward-char {
  local a=${1:-1}
  if ((_ble_edit_ind-a<0)); then
    return 1
  fi

  local ins=
  if [[ $_ble_edit_overwrite_mode ]]; then
    local next=${_ble_edit_str:_ble_edit_ind:1}
    if [[ $next && $next != [$'\n\t'] ]]; then
      if [[ $_ble_edit_overwrite_mode == R ]]; then
        local w=$a
      else
        local w=0 ret i
        for ((i=0;i<a;i++)); do
          ble/util/s2c "$_ble_edit_str" $((_ble_edit_ind-a+i))
          ble/util/c2w-edit "$ret"
          ((w+=ret))
        done
      fi
      if ((w)); then
        local ret; ble/string#repeat ' ' "$w"; ins=$ret
        ((_ble_edit_mark>=_ble_edit_ind&&(_ble_edit_mark+=w)))
      fi
    fi
  fi

  _ble_edit_str.replace $((_ble_edit_ind-a)) "$_ble_edit_ind" "$ins"
  ((_ble_edit_ind-=a,
    _ble_edit_ind+a<_ble_edit_mark?(_ble_edit_mark-=a):
    _ble_edit_ind<_ble_edit_mark&&(_ble_edit_mark=_ble_edit_ind)))
  return 0
}

function ble/widget/.delete-char {
  local a=${1:-1}
  if ((a>0)); then
    # delete-forward-char
    if ((${#_ble_edit_str}<_ble_edit_ind+a)); then
      return 1
    else
      _ble_edit_str.replace "$_ble_edit_ind" $((_ble_edit_ind+a)) ''
    fi
  elif ((a<0)); then
    # delete-backward-char
    ble/widget/.delete-backward-char $((-a))
    return
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      _ble_edit_str.replace "$_ble_edit_ind" $((_ble_edit_ind+1)) ''
    else
      _ble_edit_ind=${#_ble_edit_str}
      ble/widget/.delete-backward-char 1
      return
    fi
  fi

  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
  return 0
}
function ble/widget/delete-forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.delete-char "$arg" || ble/widget/.bell
}
function ble/widget/delete-backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.delete-char $((-arg)) || ble/widget/.bell
}
function ble/widget/exit {
  ble-edit/content/clear-arg
  local opts=$1

  if [[ :$opts: != *:force:* ]]; then
    # job が残っている場合
    local joblist
    ble/util/joblist
    if ((${#joblist[@]})); then
      ble/widget/.bell "(exit) ジョブが残っています!"
      ble/widget/.SHELL_COMMAND jobs
      return
    fi
  fi

  #_ble_edit_detach_flag=exit

  #ble/term/visible-bell ' Bye!! ' # 最後に vbell を出すと一時ファイルが残る
  _ble_edit_line_disabled=1 ble/textarea#render

  # Note: ble_debug=1 の時 ble/textarea#render の中で info が設定されるので、
  #   これは ble/textarea#render より後である必要がある。
  ble-edit/info/hide

  local -a DRAW_BUFF=()
  ble-form/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
  ble-edit/draw/bflush
  ble/util/buffer.print "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0"
  ble/util/buffer.flush >&2
  exit
}
function ble/widget/delete-forward-char-or-exit {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/exit
  fi
}
function ble/widget/delete-forward-backward-char {
  ble-edit/content/clear-arg
  ble/widget/.delete-char 0 || ble/widget/.bell
}


function ble/widget/delete-horizontal-space {
  local arg; ble-edit/content/get-arg ''

  local b=0 rex=$'[ \t]+$'
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
    b=${#BASH_REMATCH}

  local a=0 rex=$'^[ \t]+'
  [[ ! $arg && ${_ble_edit_str:_ble_edit_ind} =~ $rex ]] &&
    a=${#BASH_REMATCH}

  ble/widget/.delete-range $((_ble_edit_ind-b)) $((_ble_edit_ind+a))
}

# 
# **** cursor move ****                                            @edit.cursor

function ble/widget/.forward-char {
  ((_ble_edit_ind+=${1:-1}))
  if ((_ble_edit_ind>${#_ble_edit_str})); then
    _ble_edit_ind=${#_ble_edit_str}
    return 1
  elif ((_ble_edit_ind<0)); then
    _ble_edit_ind=0
    return 1
  fi
}
function ble/widget/forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return
  ble/widget/.forward-char "$arg" || ble/widget/.bell
}
function ble/widget/backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return
  ble/widget/.forward-char $((-arg)) || ble/widget/.bell
}
function ble/widget/end-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=0
    else
      ((arg<0&&(arg=0)))
      local index=$(((19-2*arg)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=${#_ble_edit_str}
  fi
}
function ble/widget/beginning-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=${#_ble_edit_str}
    else
      ((arg<0&&(arg=0)))
      local index=$(((2*arg+1)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=0
  fi
}

function ble/widget/beginning-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}
function ble/widget/end-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}

## 編集関数 ble/widget/kill-backward-logical-line
##
##   現在の行の行頭まで削除する。
##   既に行頭にいる場合には直前の改行を削除する。
##   引数 arg を与えたときは arg 行前の行末まで削除する。
##
function ble/widget/kill-backward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" $((-arg)); local index=$ret
    if ((arg>0)); then
      if ((_ble_edit_ind<=index)); then
        index=0
      else
        ble/string#count-char "${_ble_edit_str:index:_ble_edit_ind-index}" $'\n'
        ((ret<arg)) && index=0
      fi
      [[ $flag_beg ]] && index=0
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-bol
    # 行頭にいるとき無引数で呼び出すと、直前の改行を削除
    ((0<ret&&ret==_ble_edit_ind&&ret--))
  fi
  ble/widget/.kill-range "$ret" "$_ble_edit_ind"
}
## 編集関数 ble/widget/kill-forward-logical-line
##
##   現在の行の行末まで削除する。
##   既に行末にいる場合は直後の改行を削除する。
##   引数 arg を与えたときは arg 行次の行頭まで削除する。
##
function ble/widget/kill-forward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" "$arg"; local index=$ret
    if ((arg>0)); then
      if ((index<=_ble_edit_ind)); then
        index=${#_ble_edit_str}
      else
        ble/string#count-char "${_ble_edit_str:_ble_edit_ind:index-_ble_edit_ind}" $'\n'
        ((ret<arg)) && index=${#_ble_edit_str}
      fi
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-eol
    # 行末にいるとき無引数で呼び出すと、直後の改行を削除
    ((ret<${#_ble_edit_str}&&_ble_edit_ind==ret&&ret++))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$ret"
}

function ble/widget/forward-history-line.impl {
  local arg=$1
  ((arg==0)) && return 0

  local rest=$((arg>0?arg:-arg))
  if ((arg>0)); then
    if [[ ! $_ble_edit_history_prefix && ! $_ble_edit_history_loaded ]]; then
      # 履歴を未だロードしていないので次の項目は存在しない
      ble/widget/.bell 'end of history'
      return 1
    fi
  fi

  local index; ble-edit/history/get-index

  local expr_next='--index>=0'
  if ((arg>0)); then
    local count; ble-edit/history/get-count
    expr_next="++index<=$count"
  fi

  while ((expr_next)); do
    if ((--rest<=0)); then
      ble-edit/history/goto "$index" # 位置は goto に任せる
      return
    fi

    local entry; ble-edit/history/get-editted-entry "$index"
    if [[ $entry == *$'\n'* ]]; then
      local ret; ble/string#count-char "$entry" $'\n'
      if ((rest<=ret)); then
        ble-edit/history/goto "$index"
        if ((arg>0)); then
          ble-edit/content/find-logical-eol 0 "$rest"
        else
          ble-edit/content/find-logical-eol ${#entry} $((-rest))
        fi
        _ble_edit_ind=$ret
        return
      fi
      ((rest-=ret))
    fi
  done

  if ((arg>0)); then
    ble-edit/history/goto "$count"
    _ble_edit_ind=${#_ble_edit_str}
    ble/widget/.bell 'end of history'
  else
    ble-edit/history/goto 0
    _ble_edit_ind=0
    ble/widget/.bell 'beginning of history'
  fi
  return 0
}

## 関数 ble/widget/forward-logical-line.impl arg opts
##
##   @param arg
##     移動量を表す整数を指定する。
##   @param opts
##     コロン区切りでオプションを指定する。
##
function ble/widget/forward-logical-line.impl {
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  # 事前チェック
  local ind=$_ble_edit_ind
  if ((arg>0)); then
    ((ind<${#_ble_edit_str})) || return 1
  else
    ((ind>0)) || return 1
  fi

  local ret; ble-edit/content/find-logical-bol "$ind" "$arg"; local bol2=$ret
  if ((arg>0)); then
    if ((ind<bol2)); then
      ble/string#count-char "${_ble_edit_str:ind:bol2-ind}" $'\n'
      ((arg-=ret))
    fi
  else
    if ((ind>bol2)); then
      ble/string#count-char "${_ble_edit_str:bol2:ind-bol2}" $'\n'
      ((arg+=ret))
    fi
  fi

  # 同じ履歴項目内に移動先行が見つかった場合
  if ((arg==0)); then
    # 元と同じ列に移動して戻る。
    ble-edit/content/find-logical-bol "$ind" ; local bol1=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    local dst=$((bol2+ind-bol1))
    ((_ble_edit_ind=dst<eol2?dst:eol2))
    return 0
  fi

  # 取り敢えず移動できる所まで移動する
  if ((arg>0)); then
    ble-edit/content/find-logical-eol "$bol2"
  else
    ret=$bol2
  fi
  _ble_edit_ind=$ret

  # 履歴項目の移動を行う場合
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg"
    return
  fi

  # 移動先行がない場合は bell
  if ((arg>0)); then
    ble/widget/.bell 'end of string'
  else
    ble/widget/.bell 'beginning of string'
  fi
  return 0
}
function ble/widget/forward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl "$arg" "$opts"
}
function ble/widget/backward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl $((-arg)) "$opts"
}

## 関数 ble/keymap:emacs/find-graphical-eol [index [offset]]
function ble/keymap:emacs/find-graphical-eol {
  local axis=${1:-$_ble_edit_ind} arg=${2:-0}
  local x y index
  ble/textmap#getxy.cur "$axis"
  ble/textmap#get-index-at 0 $((y+arg+1))
  if ((index>0)); then
    local ax ay
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y+arg&&index--))
  fi
  ret=$index
}

function ble/widget/beginning-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local x y index
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 $((y+arg-1))
  _ble_edit_ind=$index
}
function ble/widget/end-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local ret; ble/keymap:emacs/find-graphical-eol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}

## 編集関数 ble/widget/kill-backward-graphical-line
##   現在の行の表示行頭まで削除する。
##   既に表示行頭にいる場合には直前の文字を削除する。
##   引数 arg を与えたときは arg 行前の表示行末まで削除する。
function ble/widget/kill-backward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  if [[ ! $arg ]]; then
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ((index==_ble_edit_ind&&index>0&&index--))
    ble/widget/.kill-range "$index" "$_ble_edit_ind"
  else
    local ret; ble/keymap:emacs/find-graphical-eol "$_ble_edit_ind" $((-arg))
    ble/widget/.kill-range "$ret" "$_ble_edit_ind"
  fi
}
## 編集関数 ble/widget/kill-forward-graphical-line
##   現在の行の表示行末まで削除する。
##   既に表示行末 (折り返し時は行の最後の文字の手前) にいる場合は直後の文字を削除する。
##   引数 arg を与えたときは arg 行後の表示行頭まで削除する。
function ble/widget/kill-forward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 $((y+${arg:-1}))
  if [[ ! $arg ]] && ((_ble_edit_ind<index-1)); then
    # 無引数でかつ行末より前にいた時、
    # 行頭までではなくその前の行末までしか消さない。
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y&&index--))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$index"
}

function ble/widget/forward-graphical-line.impl {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at "$x" $((y+arg))
  ble/textmap#getxy.cur --prefix=a "$index"
  ((arg-=ay-y))
  _ble_edit_ind=$index # 何れにしても移動は行う

  # 現在の履歴項目内で移動が完結する場合
  ((arg==0)) && return 0

  # 履歴項目の移動を行う場合
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg"
    return
  fi

  if ((arg>0)); then
    ble/widget/.bell 'end of string'
  else
    ble/widget/.bell 'beginning of string'
  fi
  return 0
}

function ble/widget/forward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl "$arg" "$opts"
}
function ble/widget/backward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl $((-arg)) "$opts"
}

function ble/widget/beginning-of-line {
  if ble/edit/use-textmap; then
    ble/widget/beginning-of-graphical-line
  else
    ble/widget/beginning-of-logical-line
  fi
}
function ble/widget/end-of-line {
  if ble/edit/use-textmap; then
    ble/widget/end-of-graphical-line
  else
    ble/widget/end-of-logical-line
  fi
}
function ble/widget/kill-backward-line {
  if ble/edit/use-textmap; then
    ble/widget/kill-backward-graphical-line
  else
    ble/widget/kill-backward-logical-line
  fi
}
function ble/widget/kill-forward-line {
  if ble/edit/use-textmap; then
    ble/widget/kill-forward-graphical-line
  else
    ble/widget/kill-forward-logical-line
  fi
}
function ble/widget/forward-line {
  if ble/edit/use-textmap; then
    ble/widget/forward-graphical-line "$@"
  else
    ble/widget/forward-logical-line "$@"
  fi
}
function ble/widget/backward-line {
  if ble/edit/use-textmap; then
    ble/widget/backward-graphical-line "$@"
  else
    ble/widget/backward-logical-line "$@"
  fi
}

# 
# **** word location ****                                            @edit.word

function ble/widget/.genword-setup-cword {
  WSET='_a-zA-Z0-9'; WSEP="^$WSET"
}
function ble/widget/.genword-setup-uword {
  WSEP="${IFS:-$' \t\n'}"; WSET="^$WSEP"
}
function ble/widget/.genword-setup-sword {
  WSEP=$'|&;()<> \t\n'; WSET="^$WSEP"
}
function ble/widget/.genword-setup-fword {
  WSEP="/${IFS:-$' \t\n'}"; WSET="^$WSEP"
}

## 関数 ble/widget/.locate-backward-genword; a b c
##   後方の単語を探索します。
##
##   |---|www|---|
##   a   b   c   x
##
##   @var[in] WSET,WSEP
##   @var[out] a,b,c
##
function ble/widget/.locate-backward-genword {
  local x=${1:-$_ble_edit_ind}
  c=${_ble_edit_str::x}; c=${c##*[$WSET]}; c=$((x-${#c}))
  b=${_ble_edit_str::c}; b=${b##*[$WSEP]}; b=$((c-${#b}))
  a=${_ble_edit_str::b}; a=${a##*[$WSET]}; a=$((b-${#a}))
}
## 関数 ble/widget/.locate-backward-genword; s t u
##   前方の単語を探索します。
##
##   |---|www|---|
##   x   s   t   u
##
##   @var[in] WSET,WSEP
##   @var[out] s,t,u
##
function ble/widget/.locate-forward-genword {
  local x=${1:-$_ble_edit_ind}
  s=${_ble_edit_str:x}; s=${s%%[$WSET]*}; s=$((x+${#s}))
  t=${_ble_edit_str:s}; t=${t%%[$WSEP]*}; t=$((s+${#t}))
  u=${_ble_edit_str:t}; u=${u%%[$WSET]*}; u=$((t+${#u}))
}
## 関数 ble/widget/.locate-backward-genword; s t u
##   現在位置の単語を探索します。
##
##   |---|wwww|---|
##   r   s    t   u
##        <- x --->
##
##   @var[in] WSET,WSEP
##   @var[out] s,t,u
##
function ble/widget/.locate-current-genword {
  local x=${1:-$_ble_edit_ind}

  local a b c # <a> *<b>w*<c> *<x>
  ble/widget/.locate-backward-genword

  r=$a
  ble/widget/.locate-forward-genword "$r"
}


## 関数 ble/widget/.delete-forward-genword
##   前方の unix word を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-forward-genword {
  # |---|www|---|
  # x   s   t   u
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  if ((x!=t)); then
    ble/widget/.delete-range "$x" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.delete-backward-genword
##   後方の単語を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-backward-genword {
  # |---|www|---|
  # a   b   c   x
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  if ((x>c&&(c=x),b!=c)); then
    ble/widget/.delete-range "$b" "$c"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.delete-genword
##   現在位置の単語を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  if ((x>t&&(t=x),r!=t)); then
    ble/widget/.delete-range "$r" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-forward-genword
##   前方の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-forward-genword {
  # <x> *<s>w*<t> *<u>
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  if ((x!=t)); then
    ble/widget/.kill-range "$x" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-backward-genword
##   後方の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-backward-genword {
  # <a> *<b>w*<c> *<x>
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  if ((x>c&&(c=x),b!=c)); then
    ble/widget/.kill-range "$b" "$c"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-genword
##   現在位置の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  if ((x>t&&(t=x),r!=t)); then
    ble/widget/.kill-range "$r" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.copy-forward-genword
##   前方の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-forward-genword {
  # <x> *<s>w*<t> *<u>
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  ble/widget/.copy-range "$x" "$t"
}
## 関数 ble/widget/.copy-backward-genword
##   後方の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-backward-genword {
  # <a> *<b>w*<c> *<x>
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  ble/widget/.copy-range "$b" $((c>x?c:x))
}
## 関数 ble/widget/.copy-genword
##   現在位置の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  ble/widget/.copy-range "$r" $((t>x?t:x))
}
## 関数 ble/widget/.forward-genword
##
##   @var[in] WSET,WSEP
##
function ble/widget/.forward-genword {
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword "$x"
  if ((x==t)); then
    ble/widget/.bell
  else
    _ble_edit_ind=$t
  fi
}
## 関数 ble/widget/.backward-genword
##
##   @var[in] WSET,WSEP
##
function ble/widget/.backward-genword {
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword "$x"
  if ((x==b)); then
    ble/widget/.bell
  else
    _ble_edit_ind=$b
  fi
}

# 
#%m kill-xword

# generic word

## 関数 ble/widget/delete-forward-xword
##   前方の generic word を削除します。
function ble/widget/delete-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-forward-genword "$@"
}
## 関数 ble/widget/delete-backward-xword
##   後方の generic word を削除します。
function ble/widget/delete-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-backward-genword "$@"
}
## 関数 ble/widget/delete-xword
##   現在位置の generic word を削除します。
function ble/widget/delete-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-genword "$@"
}
## 関数 ble/widget/kill-forward-xword
##   前方の generic word を切り取ります。
function ble/widget/kill-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-forward-genword "$@"
}
## 関数 ble/widget/kill-backward-xword
##   後方の generic word を切り取ります。
function ble/widget/kill-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-backward-genword "$@"
}
## 関数 ble/widget/kill-xword
##   現在位置の generic word を切り取ります。
function ble/widget/kill-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-genword "$@"
}
## 関数 ble/widget/copy-forward-xword
##   前方の generic word を転写します。
function ble/widget/copy-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-forward-genword "$@"
}
## 関数 ble/widget/copy-backward-xword
##   後方の generic word を転写します。
function ble/widget/copy-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-backward-genword "$@"
}
## 関数 ble/widget/copy-xword
##   現在位置の generic word を転写します。
function ble/widget/copy-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-genword "$@"
}
#%end
#%x kill-xword .r/generic word/unix word/  .r/xword/cword/
#%x kill-xword .r/generic word/c word/     .r/xword/uword/
#%x kill-xword .r/generic word/shell word/ .r/xword/sword/
#%x kill-xword .r/generic word/filename/   .r/xword/fword/

#%m forward-xword (
function ble/widget/forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.forward-genword "$@"
}
function ble/widget/backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.backward-genword "$@"
}
#%)
#%x forward-xword .r/generic word/unix word/  .r/xword/cword/
#%x forward-xword .r/generic word/c word/     .r/xword/uword/
#%x forward-xword .r/generic word/shell word/ .r/xword/sword/

#------------------------------------------------------------------------------
# **** ble-edit/exec ****                                            @edit.exec

_ble_edit_exec_lines=()
_ble_edit_exec_lastexit=0
_ble_edit_exec_lastarg=$BASH
function ble-edit/exec/register {
  ble/array#push _ble_edit_exec_lines "$1"
}
function ble-edit/exec/has-pending-commands {
  ((${#_ble_edit_exec_lines[@]}))
}
function ble-edit/exec/.setexit {
  # $? 変数の設定
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec/.adjust-eol {
  # 文末調整
  local cols=${COLUMNS:-80}
  local -a DRAW_BUFF=()
  ble-edit/draw/put "$_ble_term_sc"
  ble-edit/draw/put "${_ble_term_setaf[12]}[ble: EOF]$_ble_term_sgr0"
  ble-edit/draw/put "$_ble_term_rc"
  ble-edit/draw/put.cuf $((_ble_term_xenl?cols-2:cols-3))
  ble-edit/draw/put "  $_ble_term_cr$_ble_term_el"
  ble-edit/draw/bflush
}

_ble_edit_exec_BASH_REMATCH=()
_ble_edit_exec_BASH_REMATCH_rex=none

## 関数 ble-edit/exec/.save-BASH_REMATCH/increase delta
##   @param[in] delta
##   @var[in,out] i rex
function ble-edit/exec/save-BASH_REMATCH/increase {
  local delta=$1
  ((delta)) || return
  ((i+=delta))
  if ((delta==1)); then
    rex=$rex.
  else
    rex=$rex.{$delta}
  fi
}
function ble-edit/exec/save-BASH_REMATCH/is-updated {
  local i n=${#_ble_edit_exec_BASH_REMATCH[@]}
  ((n!=${#BASH_REMATCH[@]})) && return 0
  for ((i=0;i<n;i++)); do
    [[ ${_ble_edit_exec_BASH_REMATCH[i]} != "${BASH_REMATCH[i]}" ]] && return 0
  done
  return 1
}
function ble-edit/exec/save-BASH_REMATCH {
  ble-edit/exec/save-BASH_REMATCH/is-updated || return

  local size=${#BASH_REMATCH[@]}
  if ((size==0)); then
    _ble_edit_exec_BASH_REMATCH=()
    _ble_edit_exec_BASH_REMATCH_rex=none
    return
  fi

  local rex= i=0
  local text=$BASH_REMATCH sub ret isub

  local -a rparens=()
  local isub rex i=0
  for ((isub=1;isub<size;isub++)); do
    local sub=${BASH_REMATCH[isub]}

    # 既存の子一致の孫一致になるか確認
    local r rN=${#rparens[@]}
    for ((r=rN-1;r>=0;r--)); do
      local end=${rparens[r]}
      if ble/string#index-of "${text:i:end-i}" "$sub"; then
        ble-edit/exec/save-BASH_REMATCH/increase "$ret"
        ble/array#push rparens $((i+${#sub}))
        rex=$rex'('
        break
      else
        ble-edit/exec/save-BASH_REMATCH/increase $((end-i))
        rex=$rex')'
        unset 'rparens[r]'
      fi
    done

    ((r>=0)) && continue

    # 新しい子一致
    if ble/string#index-of "${text:i}" "$sub"; then
      ble-edit/exec/save-BASH_REMATCH/increase "$ret"
      ble/array#push rparens $((i+${#sub}))
      rex=$rex'('
    else
      break # 復元失敗
    fi
  done

  local r rN=${#rparens[@]}
  for ((r=rN-1;r>=0;r--)); do
    local end=${rparens[r]}
    ble-edit/exec/save-BASH_REMATCH/increase $((end-i))
    rex=$rex')'
    unset 'rparens[r]'
  done

  ble-edit/exec/save-BASH_REMATCH/increase $((${#text}-i))

  _ble_edit_exec_BASH_REMATCH=("${BASH_REMATCH[@]}")
  _ble_edit_exec_BASH_REMATCH_rex=$rex
}
function ble-edit/exec/restore-BASH_REMATCH {
  [[ $_ble_edit_exec_BASH_REMATCH =~ $_ble_edit_exec_BASH_REMATCH_rex ]]
}


## 関数 _ble_edit_exec_lines= ble-edit/exec:$bleopt_exec_type/process;
##   指定したコマンドを実行します。
## @param[in,out] _ble_edit_exec_lines
##   実行するコマンドの配列を指定します。実行したコマンドは削除するか空文字列を代入します。
## @return
##   戻り値が 0 の場合、終端 (ble-edit/bind/.tail) に対する処理も行われた事を意味します。
##   つまり、そのまま ble-decode/.hook から抜ける事を期待します。
##   それ以外の場合には終端処理をしていない事を表します。

#--------------------------------------
# bleopt_exec_type = exec
#--------------------------------------

function ble-edit/exec:exec/.eval-TRAPINT {
  builtin echo >&2
  # echo "SIGINT ${FUNCNAME[1]}"
  if ((_ble_bash>=40300)); then
    _ble_edit_exec_INT=130
  else
    _ble_edit_exec_INT=128
  fi
  trap 'ble-edit/exec:exec/.eval-TRAPDEBUG SIGINT "$*" && return' DEBUG
}
function ble-edit/exec:exec/.eval-TRAPDEBUG {
  # 一旦 DEBUG を設定すると bind -x を抜けるまで削除できない様なので、
  # _ble_edit_exec_INT のチェックと _ble_edit_exec_in_eval のチェックを行う。
  if ((_ble_edit_exec_INT&&_ble_edit_exec_in_eval)); then
    builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2" >&2
    return 0
  else
    trap - DEBUG # 何故か効かない
    return 1
  fi
}

function ble-edit/exec:exec/.eval-prologue {
  ble-edit/exec/restore-BASH_REMATCH
  ble/restore-bash-options

  set -H

  # C-c に対して
  trap 'ble-edit/exec:exec/.eval-TRAPINT; return 128' INT
  # trap '_ble_edit_exec_INT=126; return 126' TSTP
}
function ble-edit/exec:exec/.save-last-arg {
  _ble_edit_exec_lastarg=$_ _ble_edit_exec_lastexit=$?
  ble/adjust-bash-options
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec:exec/.eval {
  # BASH_COMMAND に return が含まれていても大丈夫な様に関数内で評価
  local _ble_edit_exec_in_eval=1 nl=$'\n'
  ble-edit/exec/.setexit "$_ble_edit_exec_lastarg" # set $? and $_
  builtin eval -- "$BASH_COMMAND${nl}ble-edit/exec:exec/.save-last-arg"
}
function ble-edit/exec:exec/.eval-epilogue {
  trap - INT DEBUG # DEBUG 削除が何故か効かない

  ble/adjust-bash-options
  _ble_edit_PS1=$PS1
  _ble_edit_IFS=$IFS
  ble-edit/exec/save-BASH_REMATCH
  ble-edit/exec/.adjust-eol

  # lastexit
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit=$_ble_edit_exec_INT
  fi
  if [ "$_ble_edit_exec_lastexit" -ne 0 ]; then
    # SIGERR処理
    if type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      builtin echo "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0" >&2
    fi
  fi
}

## 関数 ble-edit/exec:exec/.recursive index
##   index 番目のコマンドを実行し、引数 index+1 で自己再帰します。
##   コマンドがこれ以上ない場合は何もせずに終了します。
## @param[in] index
function ble-edit/exec:exec/.recursive {
  (($1>=${#_ble_edit_exec_lines})) && return

  local BASH_COMMAND=${_ble_edit_exec_lines[$1]}
  _ble_edit_exec_lines[$1]=
  if [[ ${BASH_COMMAND//[ 	]/} ]]; then
    # 実行
    local PS1=$_ble_edit_PS1
    local IFS=$_ble_edit_IFS
    local HISTCMD
    ble-edit/history/get-count -v HISTCMD

    local _ble_edit_exec_INT=0
    ble-edit/exec:exec/.eval-prologue
    ble-edit/exec:exec/.eval
    _ble_edit_exec_lastexit=$?
    ble-edit/exec:exec/.eval-epilogue
  fi

  ble-edit/exec:exec/.recursive $(($1+1))
}

_ble_edit_exec_replacedDeclare=
_ble_edit_exec_replacedTypeset=
function ble-edit/exec:exec/.isGlobalContext {
  local offset=$1

  local path
  for path in "${FUNCNAME[@]:offset+1}"; do
    # source or . が続く限りは遡る (. で呼び出しても FUNCNAME には source が入る様だ。)
    if [[ $path = ble-edit/exec:exec/.eval ]]; then
      return 0
    elif [[ $path != source ]]; then
      # source という名の関数を定義して呼び出している場合、source と区別が付かない。
      # しかし関数と組込では、組込という判定を優先する。
      # (理由は (1) 関数内では普通 local を使う事
      # (2) local になるべき物が global になるのと、
      # global になるべき物が local になるのでは前者の方がまし、という事)
      return 1
    fi
  done

  # BASH_SOURCE は source が関数か builtin か判定するのには使えない
  # local i iN=${#FUNCNAME[@]}
  # for ((i=offset;i<iN;i++)); do
  #   local func=${FUNCNAME[i]}
  #   local path=${BASH_SOURCE[i]}
  #   if [[ $func == ble-edit/exec:exec/.eval && $path == "$BASH_SOURCE" ]]; then
  #     return 0
  #   elif [[ $path != source && $path != "$BASH_SOURCE" ]]; then
  #     # source ble.sh の中の declare が全て local になるので上だと駄目。
  #     # しかしそもそも二重にロードしても大丈夫な物かは謎。
  #     return 1
  #   fi
  # done

  return 0
}

function ble-edit/exec:exec {
  [[ ${#_ble_edit_exec_lines[@]} -eq 0 ]] && return

  # コマンド内部で declare してもグローバルに定義されない。
  # bash-4.2 以降では -g オプションがあるので declare を上書きする。
  #
  # - -g は変数の作成・変更以外の場合は無視されると man に書かれているので、
  #   変数定義の参照などの場合に影響は与えない。
  # - 既に declare が定義されている場合には上書きはしない。
  #   custom declare に -g を渡す様に書き換えても良いが、
  #   custom declare に -g を指定した時に何が起こるか分からない。
  #   また、custom declare を待避・定義しなければならず実装が面倒。
  # - コマンド内で直接 declare をしているのか、
  #   関数内で declare をしているのかを判定する為に FUNCNAME 変数を使っている。
  #   但し、source という名の関数を定義して呼び出している場合は
  #   source している場合と区別が付かない。この場合は source しているとの解釈を優先させる。
  #
  # ※内部で declare() を上書きされた場合に対応していない。
  # ※builtin declare と呼び出された場合に対しては流石に対応しない
  #
  if ((_ble_bash>=40200)); then
    if ! builtin declare -f declare &>/dev/null; then
      _ble_edit_exec_replacedDeclare=1
      # declare() { builtin declare -g "$@"; }
      declare() {
        if ble-edit/exec:exec/.isGlobalContext 1; then
          builtin declare -g "$@"
        else
          builtin declare "$@"
        fi
      }
    fi
    if ! builtin declare -f typeset &>/dev/null; then
      _ble_edit_exec_replacedTypeset=1
      # typeset() { builtin typeset -g "$@"; }
      typeset() {
        if ble-edit/exec:exec/.isGlobalContext 1; then
          builtin typeset -g "$@"
        else
          builtin typeset "$@"
        fi
      }
    fi
  fi

  # ローカル変数を宣言すると実行されるコマンドから見えてしまう。
  # また、実行されるコマンドで定義される変数のスコープを制限する事にもなるので、
  # ローカル変数はできるだけ定義しない。
  # どうしても定義する場合は、予約識別子名として _ble_ で始まる名前にする。

  # 以下、配列 _ble_edit_exec_lines に登録されている各コマンドを順に実行する。
  # ループ構文を使うと、ループ構文自体がユーザの入力した C-z (SIGTSTP)
  # を受信して(?)停止してしまう様なので、再帰でループする必要がある。
  ble/term/leave
  ble/util/buffer.flush >&2
  ble-edit/exec:exec/.recursive 0
  ble/term/enter

  _ble_edit_exec_lines=()

  # C-c で中断した場合など以下が実行されないかもしれないが
  # 次の呼出の際にここが実行されるのでまあ許容する。
  if [[ $_ble_edit_exec_replacedDeclare ]]; then
    _ble_edit_exec_replacedDeclare=
    unset -f declare
  fi
  if [[ $_ble_edit_exec_replacedTypeset ]]; then
    _ble_edit_exec_replacedTypeset=
    unset -f typeset
  fi
}

function ble-edit/exec:exec/process {
  ble-edit/exec:exec
  ble-edit/bind/.check-detach
  return "$?"
}

#--------------------------------------
# bleopt_exec_type = gexec
#--------------------------------------

function ble-edit/exec:gexec/.eval-TRAPINT {
  builtin echo >&2
  if ((_ble_bash>=40300)); then
    _ble_edit_exec_INT=130
  else
    _ble_edit_exec_INT=128
  fi
  trap 'ble-edit/exec:gexec/.eval-TRAPDEBUG SIGINT "$*" && { return &>/dev/null || break &>/dev/null;}' DEBUG
}
function ble-edit/exec:gexec/.eval-TRAPDEBUG {
  if ((_ble_edit_exec_INT!=0)); then
    # エラーが起きている時

    local IFS=$_ble_term_IFS
    local depth=${#FUNCNAME[*]}
    local rex='^ble-edit/exec:gexec/.'
    if ((depth>=2)) && ! [[ ${FUNCNAME[*]:depth-1} =~ $rex ]]; then
      # 関数内にいるが、ble-edit/exec:gexec/. の中ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2" >&2
      return 0
    fi

    local rex='^(ble-edit/exec:gexec/.|trap - )'
    if ((depth==1)) && ! [[ $BASH_COMMAND =~ $rex ]]; then
      # 一番外側で、ble-edit/exec:gexec/. 関数ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 $BASH_COMMAND $2" >&2
      return 0
    fi
  fi

  trap - DEBUG # 何故か効かない
  return 1
}
function ble-edit/exec:gexec/.begin {
  local IFS=$' \t\n'
  _ble_decode_bind_hook=
  ble/term/leave
  ble/util/buffer.flush >&2
  ble-edit/bind/stdout.on

  # C-c に対して
  trap 'ble-edit/exec:gexec/.eval-TRAPINT' INT
}
function ble-edit/exec:gexec/.end {
  local IFS=$' \t\n'
  trap - INT DEBUG
  # ↑何故か効かないので、
  #   end の呼び出しと同じレベルで明示的に実行する。

  ble/util/joblist.flush >&2
  ble-edit/bind/.check-detach && return 0
  ble/term/enter
  ble-edit/bind/.tail # flush will be called here
}
function ble-edit/exec:gexec/.eval-prologue {
  local IFS=$' \t\n'
  BASH_COMMAND=$1
  ble-edit/restore-PS1
  unset HISTCMD; ble-edit/history/get-count -v HISTCMD
  _ble_edit_exec_INT=0
  ble/util/joblist.clear
  ((++_ble_edit_CMD))

  ble-edit/exec/restore-BASH_REMATCH
  ble/restore-bash-options
  ble-edit/exec/.setexit # set $?
}
function ble-edit/exec:gexec/.save-last-arg {
  _ble_edit_exec_lastarg=$_ _ble_edit_exec_lastexit=$?
  ble/adjust-bash-options
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec:gexec/.eval-epilogue {
  # lastexit
  _ble_edit_exec_lastexit=$?
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit=$_ble_edit_exec_INT
  fi
  _ble_edit_exec_INT=0

  unset -f builtin unset
  builtin unset -f builtin unset
  builtin unset -f return break continue declare typeset local : readonly eval exec echo set

  local IFS=$' \t\n'
  trap - DEBUG # DEBUG 削除が何故か効かない

  ble/adjust-bash-options
  ble-edit/adjust-PS1
  ble-edit/exec/save-BASH_REMATCH
  ble-edit/exec/.adjust-eol

  if ((_ble_edit_exec_lastexit)); then
    # SIGERR処理
    if builtin type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      builtin echo "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0" >&2
    fi
  fi
}
function ble-edit/exec:gexec/.setup {
  # コマンドを _ble_decode_bind_hook に設定してグローバルで評価する。
  #
  # ※ユーザの入力したコマンドをグローバルではなく関数内で評価すると
  #   declare した変数がコマンドローカルになってしまう。
  #   配列でない単純な変数に関しては declare を上書きする事で何とか誤魔化していたが、
  #   declare -a arr=(a b c) の様な特殊な構文の物は上書きできない。
  #   この所為で、例えば source 内で declare した配列などが壊れる。
  #
  ((${#_ble_edit_exec_lines[@]}==0)) && return 1
  ble/util/buffer.flush >&2

  local q=\' Q="'\\''"
  local cmd
  local -a buff
  local count=0
  buff[${#buff[@]}]=ble-edit/exec:gexec/.begin
  for cmd in "${_ble_edit_exec_lines[@]}"; do
    if [[ "$cmd" == *[^' 	']* ]]; then
      # Note: $_ble_edit_exec_lastarg は $_ を設定するためのものである。
      local prologue="ble-edit/exec:gexec/.eval-prologue '${cmd//$q/$Q}' \"\$_ble_edit_exec_lastarg\""
      buff[${#buff[@]}]="builtin eval -- '${prologue//$q/$Q}"
      buff[${#buff[@]}]="${cmd//$q/$Q}"
      buff[${#buff[@]}]="ble-edit/exec:gexec/.save-last-arg'"
      buff[${#buff[@]}]="ble-edit/exec:gexec/.eval-epilogue"
      ((count++))

      # ※直接 $cmd と書き込むと文法的に破綻した物を入れた時に
      #   続きの行が実行されない事になってしまう。
    fi
  done
  _ble_edit_exec_lines=()

  ((count==0)) && return 1

  buff[${#buff[@]}]='trap - INT DEBUG' # trap - は一番外側でないと効かない様だ
  buff[${#buff[@]}]=ble-edit/exec:gexec/.end

  IFS=$'\n' builtin eval '_ble_decode_bind_hook="${buff[*]}"'
  return 0
}

function ble-edit/exec:gexec/process {
  ble-edit/exec:gexec/.setup
  return "$?"
}

# **** accept-line ****                                            @edit.accept

function ble/widget/.insert-newline {
  # 最終状態の描画
  ble-edit/info/hide
  ble/textarea#render

  # 新しい描画領域
  local -a DRAW_BUFF=()
  ble-form/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy" sgr0
  ble-edit/draw/put "$_ble_term_nl"
  ble-edit/draw/bflush
  ble/util/joblist.bflush

  # 描画領域情報の初期化
  ble/textarea#invalidate
  _ble_line_x=0 _ble_line_y=0
  _ble_textarea_gendx=0 _ble_textarea_gendy=0
  _ble_form_window_height[_ble_textarea_panel]=0
}

function ble/widget/.newline/clear-content {
  # カーソルを表示する。
  # layer:overwrite でカーソルを消している時の為。
  [[ $_ble_edit_overwrite_mode ]] &&
    ble/term/cursor-state/reveal

  # 行内容の初期化
  _ble_edit_str.reset '' newline
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
}

function ble/widget/.newline {
  _ble_edit_mark_active=
  ble/widget/.insert-newline

  # update LINENO
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'
  ((_ble_edit_LINENO+=1+ret))
  ((LINENO=_ble_edit_LINENO))

  ble-edit/history/onleave.fire
  ble/widget/.newline/clear-content
}

function ble/widget/discard-line {
  ble-edit/content/clear-arg
  _ble_edit_line_disabled=1 ble/widget/.newline
}


if ((_ble_bash>=30100)); then
  function ble/edit/hist_expanded/.core {
    builtin history -p -- "$BASH_COMMAND"
  }
else
  # Workaround for bash-3.0 bug (see memo.txt#D0233, #D0801)
  function ble/edit/hist_expanded/.core {
    # Note: history -p '' によって 履歴項目が減少するかどうかをチェックし、
    #   もし履歴項目が減る状態になっている場合は履歴項目を増やしてから history -p を実行する。
    #   嘗てはサブシェルで評価していたが、そうすると置換指示子が記録されず
    #   :& が正しく実行されないことになるのでこちらの実装に切り替える。
    local line1= line2=
    ble/util/assign line1 'HISTTIMEFORMAT= builtin history 1'
    builtin history -p -- '' &>/dev/null
    ble/util/assign line2 'HISTTIMEFORMAT= builtin history 1'
    if [[ $line1 != "$line2" ]]; then
      local rex_head='^[[:space:]]*[0-9]+\*?[[:space:]]*'
      [[ $line1 =~ $rex_head ]] &&
        line1=${line1:${#BASH_REMATCH}}

      local tmp=$_ble_base_run/$$.ble_edit_history_add.txt
      printf '%s\n' "$line1" "$line1" >| "$tmp"
      builtin history -r "$tmp"
    fi

    builtin history -p -- "$BASH_COMMAND"
  }
fi

function ble-edit/hist_expanded/.expand {
  ble/edit/hist_expanded/.core 2>/dev/null; local ext=$?
  ((ext)) && echo "$BASH_COMMAND"
  builtin echo -n :
  return "$ext"
}

## @var[out] hist_expanded
function ble-edit/hist_expanded.update {
  local BASH_COMMAND=$1
  if [[ ! -o histexpand || ! ${BASH_COMMAND//[ 	]} ]]; then
    hist_expanded=$BASH_COMMAND
    return 0
  elif ble/util/assign hist_expanded ble-edit/hist_expanded/.expand; then
    hist_expanded=${hist_expanded%$_ble_term_nl:}
    return 0
  else
    hist_expanded=$BASH_COMMAND
    return 1
  fi
}

function ble/widget/accept-line {
  # 文法的に不完全の時は改行挿入
  # Note: mc (midnight commander) が改行を含むコマンドを書き込んでくる #D1392
  if [[ :$1: == *:syntax:* || $MC_SID == $$ && $LINENO == 0 ]]; then
    _ble_edit_str.update-syntax
    if ! ble-syntax:bash/is-complete; then
      ble/widget/newline
      return "$?"
    fi
  fi

  ble-edit/content/clear-arg
  local BASH_COMMAND=$_ble_edit_str

  if [[ ! ${BASH_COMMAND//["$_ble_term_IFS"]} ]]; then
    ble/widget/.newline
    return
  fi

  # 履歴展開
  local hist_expanded
  if ! ble-edit/hist_expanded.update "$BASH_COMMAND"; then
    _ble_edit_line_disabled=1 ble/widget/.insert-newline
    shopt -q histreedit &>/dev/null || ble/widget/.newline/clear-content
    ble/util/buffer.flush >&2
    ble/edit/hist_expanded/.core 1>/dev/null # エラーメッセージを表示
    return
  fi

  local hist_is_expanded=
  if [[ $hist_expanded != "$BASH_COMMAND" ]]; then
    if shopt -q histverify &>/dev/null; then
      _ble_edit_line_disabled=1 ble/widget/.insert-newline
      _ble_edit_str.reset-and-check-dirty "$hist_expanded"
      _ble_edit_ind=${#hist_expanded}
      _ble_edit_mark=0
      _ble_edit_mark_active=
      return
    fi

    BASH_COMMAND=$hist_expanded
    hist_is_expanded=1
  fi

  ble/widget/.newline

  [[ $hist_is_expanded ]] && ble/util/buffer.print "${_ble_term_setaf[12]}[ble: expand]$_ble_term_sgr0 $BASH_COMMAND"

  # 編集文字列を履歴に追加
  ble-edit/history/add "$BASH_COMMAND"

  # 実行を登録
  ble-edit/exec/register "$BASH_COMMAND"
}

function ble/widget/accept-and-next {
  ble-edit/content/clear-arg
  local index count
  ble-edit/history/get-index -v index
  ble-edit/history/get-count -v count

  if ((index+1<count)); then
    local HISTINDEX_NEXT=$((index+1)) # to be modified in accept-line
    ble/widget/accept-line
    ble-edit/history/goto "$HISTINDEX_NEXT"
  else
    local content=$_ble_edit_str
    ble/widget/accept-line

    ble-edit/history/get-count -v count
    if ((count)); then
      local entry; ble-edit/history/get-entry $((count-1))
      if [[ $entry == "$content" ]]; then
        ble-edit/history/goto $((count-1))
      fi
    fi

    [[ $_ble_edit_str != "$content" ]] &&
      _ble_edit_str.reset "$content"
  fi
}
function ble/widget/newline {
  local -a KEYS=(10)
  ble/widget/self-insert
}
function ble/widget/accept-single-line-or/accepts {
  ble-edit/content/is-single-line || return 1
  [[ $_ble_edit_str ]] && ble/util/is-stdin-ready && return 1
  shopt -q cmdhist &>/dev/null && ! ble-syntax:bash/is-complete && return 1
  return 0
}
function ble/widget/accept-single-line-or {
  if ble/widget/accept-single-line-or/accepts; then
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/accept-single-line-or-newline {
  ble/widget/accept-single-line-or newline
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/undo ****                                            @edit.undo

## @var _ble_edit_undo_hindex=
##   現在の _ble_edit_undo が保持する情報の履歴項目番号。
##   初期は空文字列でどの履歴項目でもない状態を表す。
##

_ble_edit_undo_VARNAMES=(_ble_edit_undo _ble_edit_undo_history)
_ble_edit_undo_ARRNAMES=(_ble_edit_undo_index _ble_edit_undo_hindex)

_ble_edit_undo=()
_ble_edit_undo_index=0
_ble_edit_undo_history=()
_ble_edit_undo_hindex=

function ble-edit/undo/.check-hindex {
  local hindex; ble-edit/history/get-index -v hindex
  [[ $_ble_edit_undo_hindex == $hindex ]] && return 0

  # save
  if [[ $_ble_edit_undo_hindex ]]; then
    local uindex=${_ble_edit_undo_index:-${#_ble_edit_undo[@]}}
    local q=\' Q="'\''" value
    ble/util/sprintf value "'%s' " "$uindex" "${_ble_edit_undo[@]//$q/$Q}"
    _ble_edit_undo_history[_ble_edit_undo_hindex]=$value
  fi

  # load
  if [[ ${_ble_edit_undo_history[hindex]} ]]; then
    local data; builtin eval -- "data=(${_ble_edit_undo_history[hindex]})"
    _ble_edit_undo=("${data[@]:1}")
    _ble_edit_undo_index=${data[0]}
  else
    _ble_edit_undo=()
    _ble_edit_undo_index=0
  fi
  _ble_edit_undo_hindex=$hindex
}
function ble-edit/undo/clear-all {
  _ble_edit_undo=()
  _ble_edit_undo_index=0
  _ble_edit_undo_history=()
  _ble_edit_undo_hindex=
}

## 関数 ble-edit/undo/.get-current-state
##   @var[out] str ind
function ble-edit/undo/.get-current-state {
  if ((_ble_edit_undo_index==0)); then
    str=
    if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
      local index; ble-edit/history/get-index
      ble-edit/history/get-entry -v str "$index"
    fi
    ind=${#entry}
  else
    local entry=${_ble_edit_undo[_ble_edit_undo_index-1]}
    str=${entry#*:} ind=${entry%%:*}
  fi
}

function ble-edit/undo/add {
  ble-edit/undo/.check-hindex

  # 変更がない場合は記録しない
  local str ind; ble-edit/undo/.get-current-state
  [[ $str == "$_ble_edit_str" ]] && return 0

  _ble_edit_undo[_ble_edit_undo_index++]=$_ble_edit_ind:$_ble_edit_str
  if ((${#_ble_edit_undo[@]}>_ble_edit_undo_index)); then
    _ble_edit_undo=("${_ble_edit_undo[@]::_ble_edit_undo_index}")
  fi
}
function ble-edit/undo/.load {
  local str ind; ble-edit/undo/.get-current-state

  if [[ $bleopt_undo_point == end || $bleopt_undo_point == beg ]]; then
    local ret
    ble/string#common-prefix "$_ble_edit_str" "$str"
    local beg=${#ret}
    ble/string#common-suffix "${_ble_edit_str:beg}" "${str:beg}"
    local end0=$((${#_ble_edit_str}-${#ret}))
    local end=$((${#str}-${#ret}))
    _ble_edit_str.replace "$beg" "$end0" "${str:beg:end-beg}"

    if [[ $bleopt_undo_point == end ]]; then
      ind=$end
    else
      ind=$beg
    fi
  else
    _ble_edit_str.reset-and-check-dirty "$str"
  fi

  _ble_edit_ind=$ind
  return
}
function ble-edit/undo/undo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index-=arg))
  ((_ble_edit_undo_index<0&&(_ble_edit_undo_index=0)))
  ble-edit/undo/.load
}
function ble-edit/undo/redo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  local ucount=${#_ble_edit_undo[@]}
  ((_ble_edit_undo_index<ucount)) || return 1
  ((_ble_edit_undo_index+=arg))
  ((_ble_edit_undo_index>=ucount&&(_ble_edit_undo_index=ucount)))
  ble-edit/undo/.load
}
function ble-edit/undo/revert {
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index=0))
  ble-edit/undo/.load
}
function ble-edit/undo/revert-toggle {
  local arg=${1:-1}
  ((arg%2==0)) && return 0
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  if ((_ble_edit_undo_index)); then
    ((_ble_edit_undo_index=0))
    ble-edit/undo/.load
  elif ((${#_ble_edit_undo[@]})); then
    ((_ble_edit_undo_index=${#_ble_edit_undo[@]}))
    ble-edit/undo/.load
  else
    return 1
  fi
}

# 
#------------------------------------------------------------------------------
# **** history ****                                                    @history

: ${bleopt_history_preserve_point=}

## @arr _ble_edit_history
##   コマンド履歴項目を保持する。
##
## @arr _ble_edit_history_edit
## @arr _ble_edit_history_dirt
##   _ble_edit_history_edit 編集されたコマンド履歴項目を保持する。
##   _ble_edit_history の各項目と対応し、必ず同じ数・添字の要素を持つ。
##   _ble_edit_history_dirt は編集されたかどうかを保持する。
##   _ble_edit_history の各項目と対応し、変更のあったい要素にのみ値 1 を持つ。
##
## @var _ble_edit_history_ind
##   現在の履歴項目の番号
##
## @arr _ble_edit_history_onleave
##   履歴移動の通知先を格納する配列
##
_ble_edit_history=()
_ble_edit_history_edit=()
_ble_edit_history_dirt=()
_ble_edit_history_ind=0
_ble_edit_history_onleave=()

## @var _ble_edit_history_prefix
##
##   現在どの履歴を対象としているかを保持する。
##   空文字列の時、コマンド履歴を対象とする。以下の変数を用いる。
##
##     _ble_edit_history
##     _ble_edit_history_ind
##     _ble_edit_history_edit
##     _ble_edit_history_dirt
##     _ble_edit_history_onleave
##
##   空でない文字列 prefix のとき、以下の変数を操作対象とする。
##
##     ${prefix}_history
##     ${prefix}_history_ind
##     ${prefix}_history_edit
##     ${prefix}_history_dirt
##     ${prefix}_history_onleave
##
##   何れの関数も _ble_edit_history_prefix を適切に処理する必要がある。
##
##   実装のために配列 _ble_edit_history_edit などを
##   ローカルに定義して処理するときは、以下の注意点を守る必要がある。
##
##   - その関数自身またはそこから呼び出される関数が、
##     履歴項目に対して副作用を持ってはならない。
##
##   この要請の下で、各関数は呼び出し元のすり替えを意識せずに動作できる。
##
_ble_edit_history_prefix=

## @var _ble_edit_history_loaded
## @var _ble_edit_history_count
##
##   これらの変数はコマンド履歴を対象としているときにのみ用いる。
##
_ble_edit_history_loaded=
_ble_edit_history_count=

function ble-edit/history/onleave.fire {
  local -a observers
  eval "observers=(\"\${${_ble_edit_history_prefix:-_ble_edit}_history_onleave[@]}\")"
  local obs; for obs in "${observers[@]}"; do "$obs" "$@"; done
}

function ble-edit/history/get-index {
  local _var=index
  [[ $1 == -v ]] && { _var=$2; shift 2; }
  if [[ $_ble_edit_history_prefix ]]; then
    (($_var=${_ble_edit_history_prefix}_history_ind))
  elif [[ $_ble_edit_history_loaded ]]; then
    (($_var=_ble_edit_history_ind))
  else
    ble-edit/history/get-count -v "$_var"
  fi
}
function ble-edit/history/get-count {
  local _var=count _ret
  [[ $1 == -v ]] && { _var=$2; shift 2; }

  if [[ $_ble_edit_history_prefix ]]; then
    eval "_ret=\${#${_ble_edit_history_prefix}_history[@]}"
  elif [[ $_ble_edit_history_loaded ]]; then
    _ret=${#_ble_edit_history[@]}
  else
    if [[ ! $_ble_edit_history_count ]]; then
      local history_line
      ble/util/assign history_line 'builtin history 1'
      ble/string#split-words history_line "$history_line"
      history_line=${history_line/'*'}
      _ble_edit_history_count=${history_line[0]}
    fi
    _ret=$_ble_edit_history_count
  fi

  (($_var=_ret))
}
function ble-edit/history/get-entry {
  ble-edit/history/load
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  eval "$__var=\${${_ble_edit_history_prefix:-_ble_edit}_history[\$1]}"
}
function ble-edit/history/get-editted-entry {
  ble-edit/history/load
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  eval "$__var=\${${_ble_edit_history_prefix:-_ble_edit}_history_edit[\$1]}"
}

## 関数 ble-edit/history/load
if ((_ble_bash>=40000)); then
  # _ble_bash>=40000 で以下の機能を利用する
  #   ble/util/is-stdin-ready
  #   ble/util/mapfile

  _ble_edit_history_loading=0
  _ble_edit_history_loading_bgpid=

  # history > tmp
  function ble-edit/history/load/.background-initialize {
    if ! builtin history -p '!1' &>/dev/null; then
      # Note: rcfile から呼び出すと history が未ロードなのでロードする。
      #
      # Note: 当初は親プロセスで history -n にした方が二度手間にならず効率的と考えたが
      #   以下の様な問題が生じたので、やはりサブシェルの中で history -n する事にした。
      #
      #   問題1: bashrc の謎の遅延 (memo.txt#D0702)
      #     shopt -s histappend の状態で親シェルで history -n を呼び出すと、
      #     bashrc を抜けてから Bash 本体によるプロンプトが表示されて、
      #     入力を受け付けられる様になる迄に、謎の遅延が発生する。
      #     特に履歴項目の数が HISTSIZE の丁度半分より多い時に起こる様である。
      #
      #     history -n を呼び出す瞬間だけ shopt -u histappend して
      #     直後に shopt -s histappend とすると、遅延は解消するが、
      #     実際の動作を観察すると histappend が無効になってしまっている。
      #
      #     対策として、一時的に HISTSIZE を大きくして bashrc を抜けて、
      #     最初のユーザからの入力の時に HISTSIZE を復元する事にした。
      #     これで遅延は解消できる様である。
      #
      #   問題2: 履歴の数が倍加する問題 (memo.txt#D0732)
      #     親シェルで history -n を実行すると、
      #     shopt -s histappend の状態だと履歴項目の数が2倍になってしまう。
      #     bashrc を抜ける直前から最初にユーザの入力を受けるまでに倍加する。
      #     bashrc から抜けた後に Readline が独自に履歴を読み取るのだろう。
      #     一方で shopt -u histappend の状態だとシェルが動作している内は問題ないが、
      #     シェルを終了した時に2倍に .bash_history の内容が倍になってしまう。
      #
      #     これの解決方法は不明。(HISTFILE 等を弄ったりすれば可能かもれないが試していない)
      #
      builtin history -n
    fi
    local -x HISTTIMEFORMAT=__ble_ext__
    local -x INDEX_FILE=$history_indfile
    local opt_cygwin=; [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && opt_cygwin=1

    local apos=\'
    # 482ms for 37002 entries
    builtin history | ble/bin/awk -v apos="$apos" -v opt_cygwin="$opt_cygwin" '
      BEGIN {
        n = 0;
        hindex = 0;
        INDEX_FILE = ENVIRON["INDEX_FILE"];
        printf("") > INDEX_FILE; # create file
        if (opt_cygwin) print "_ble_edit_history=(";
      }
  
      function flush_line() {
        if (n < 1) return;

        if (n == 1) {
          if (t ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
            print hindex > INDEX_FILE;
          hindex++;
        } else {
          gsub(/['$apos'\\]/, "\\\\&", t);
          gsub(/\n/, "\\n", t);
          print hindex > INDEX_FILE;
          t = "eval -- $" apos t apos;
          hindex++;
        }

        if (opt_cygwin) {
          gsub(/'$apos'/, "'$apos'\\'$apos$apos'", t);
          t = apos t apos;
        }

        print t;
        n = 0;
        t = "";
      }
  
      {
        if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0))
          flush_line();
        t = ++n == 1 ? $0 : t "\n" $0;
      }
  
      END {
        flush_line();
        if (opt_cygwin) print ")";
      }
    ' >| "$history_tmpfile.part"
    ble/bin/mv -f "$history_tmpfile.part" "$history_tmpfile"
  }

  ## 関数 ble-edit/history/string#create-unicode-progress-bar
  ##   @var[out] ret
  function ble-edit/history/string#create-unicode-progress-bar {
    local value=$1 max=$2 width=$3
    local progress=$((value*8*width/max))
    local progress_fraction=$((progress%8)) progress_integral=$((progress/8))

    local out=
    if ((progress_integral)); then
      ble/util/c2s $((0x2588))
      ((${#ret}==1)) || ret='*' # LC_CTYPE が非対応の文字の時
      ble/string#repeat "$ret" "$progress_integral"
      out=$ret
    fi

    if ((progress_fraction)); then
      ble/util/c2s $((0x2590-progress_fraction))
      ((${#ret}==1)) || ret=$progress_fraction # LC_CTYPE が非対応の文字の時
      out=$out$ret
      ((progress_integral++))
    fi

    if ((progress_integral<width)); then
      ble/util/c2w $((0x2588))
      ble/string#repeat ' ' $((ret*(width-progress_integral)))
      out=$out$ret
    fi

    ret=$out
  }

  function ble-edit/history/load {
    [[ $_ble_edit_history_prefix ]] && return
    [[ $_ble_edit_history_loaded ]] && return
  
    local opt_async=; [[ $1 == async ]] && opt_async=1
    local opt_info=; ((_ble_edit_attached)) && [[ ! $opt_async ]] && opt_info=1
    local opt_cygwin=; [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && opt_cygwin=1
  
    local history_tmpfile=$_ble_base_run/$$.edit-history-load
    local history_indfile=$_ble_base_run/$$.edit-history-load-multiline-index
    while :; do
      case $_ble_edit_history_loading in

      # 42ms 履歴の読み込み
      (0) [[ $opt_info ]] && ble-edit/info/immediate-show text "loading history..."

          # 履歴ファイル生成を Background で開始
          : >| "$history_tmpfile"

          if [[ $opt_async ]]; then
            _ble_edit_history_loading_bgpid=$(
              shopt -u huponexit; ble-edit/history/load/.background-initialize </dev/null &>/dev/null & echo $!)
            ((_ble_edit_history_loading++))
          else
            ble-edit/history/load/.background-initialize
            ((_ble_edit_history_loading+=2))
          fi ;;

      # 515ms ble-edit/history/load/.background-initialize 待機
      (1) while [[ ! -s $history_tmpfile ]] && kill -0 "$_ble_edit_history_loading_bgpid"; do
            ble/util/sleep 0.050
            [[ $opt_async ]] && ble/util/is-stdin-ready && return 148
          done
          ((_ble_edit_history_loading++)) ;;
  
      # 47ms _ble_edit_history 初期化 (37000項目)
      (2) if [[ $opt_cygwin ]]; then
            # 620ms Cygwin (99000項目)
            source "$history_tmpfile"
          else
            ble/util/mapfile _ble_edit_history < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;
  
      # 47ms _ble_edit_history_edit 初期化 (37000項目)
      (3) if [[ $opt_cygwin ]]; then
            # 504ms Cygwin (99000項目)
            _ble_edit_history_edit=("${_ble_edit_history[@]}")
          else
            ble/util/mapfile _ble_edit_history_edit < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;
  
      # 11ms 複数行履歴修正 (107/37000項目)
      (4) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_edit_history[i]} =~ $rex ]] &&
              eval "_ble_edit_history[i]=${_ble_edit_history[i]:8}"
          done
          ((_ble_edit_history_loading++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (5) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_edit_history_edit[i]} =~ $rex ]] &&
              eval "_ble_edit_history_edit[i]=${_ble_edit_history_edit[i]:8}"
          done

          _ble_edit_history_count=${#_ble_edit_history[@]}
          _ble_edit_history_ind=$_ble_edit_history_count
          _ble_edit_history_loaded=1
          [[ $opt_info ]] && ble-edit/info/immediate-clear
          ((_ble_edit_history_loading++))
          return 0 ;;
  
      (*) return 1 ;;
      esac
  
      [[ $opt_async ]] && ble/util/is-stdin-ready && return 148
    done
  }
  function ble-edit/history/clear-background-load {
    _ble_edit_history_loading=0
  }
else
  function ble-edit/history/.generate-source-to-load-history {
    if ! builtin history -p '!1' &>/dev/null; then
      # rcfile として起動すると history が未だロードされていない。
      builtin history -n
    fi
    HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    builtin history | ble/bin/awk -v apos="'" '
      BEGIN{
        n="";
        print "_ble_edit_history=("
      }

#%    # ※rcfile として読み込むと HISTTIMEFORMAT が ?? に化ける。
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)/ {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        n = $1; t = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0);
      }
      {
        line = $0;
        if (line ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
          line = apos substr(line, 9) apos;
        else
          gsub(apos, apos "\\" apos apos, line);

#%      # 対策 #D1239: bash-3.2 以前では ^A, ^? が ^A^A, ^A^? に化ける
        gsub(/\001/, "'$apos'${_ble_term_SOH}'$apos'", line);
        gsub(/\177/, "'$apos'${_ble_term_DEL}'$apos'", line);

#%      # 対策 #D1270: MSYS2 で ^M を代入すると消える
        gsub(/\015/, "'$apos'${_ble_term_CR}'$apos'", line);

        t = t != "" ? t "\n" line : line;
      }
      END {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        print ")"
      }
    '
  }

  ## called by ble-edit-initialize
  function ble-edit/history/load {
    [[ $_ble_edit_history_prefix ]] && return
    [[ $_ble_edit_history_loaded ]] && return
    _ble_edit_history_loaded=1

    ((_ble_edit_attached)) &&
      ble-edit/info/immediate-show text "loading history..."

    # * プロセス置換にしてもファイルに書き出しても大した違いはない。
    #   270ms for 16437 entries (generate-source の時間は除く)
    # * プロセス置換×source は bash-3 で動かない。eval に変更する。
    builtin eval -- "$(ble-edit/history/.generate-source-to-load-history)"
    _ble_edit_history_edit=("${_ble_edit_history[@]}")
    _ble_edit_history_count=${#_ble_edit_history[@]}
    _ble_edit_history_ind=$_ble_edit_history_count
    if ((_ble_edit_attached)); then
      ble-edit/info/clear
    fi
  }
  function ble-edit/history/clear-background-load { :; }
fi

# @var[in,out] HISTINDEX_NEXT
#   used by ble/widget/accept-and-next to get modified next-entry positions
function ble-edit/history/add/.command-history {
  # 注意: bash-3.2 未満では何故か bind -x の中では常に history off になっている。
  [[ -o history ]] || ((_ble_bash<30200)) || return

  if [[ $_ble_edit_history_loaded ]]; then
    # 登録・不登録に拘わらず取り敢えず初期化
    _ble_edit_history_ind=${#_ble_edit_history[@]}

    # _ble_edit_history_edit を未編集状態に戻す
    local index
    for index in "${!_ble_edit_history_dirt[@]}"; do
      _ble_edit_history_edit[index]=${_ble_edit_history[index]}
    done
    _ble_edit_history_dirt=()

    # 同時に _ble_edit_undo も初期化する。
    ble-edit/undo/clear-all
  fi

  local cmd=$1
  if [[ $HISTIGNORE ]]; then
    local pats pat
    ble/string#split pats : "$HISTIGNORE"
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return
    done
  fi

  local use_bash300wa=
  if [[ $_ble_edit_history_loaded ]]; then
    if [[ $HISTCONTROL ]]; then
      local ignorespace ignoredups erasedups spec
      for spec in ${HISTCONTROL//:/ }; do
        case "$spec" in
        (ignorespace) ignorespace=1 ;;
        (ignoredups)  ignoredups=1 ;;
        (ignoreboth)  ignorespace=1 ignoredups=1 ;;
        (erasedups)   erasedups=1 ;;
        esac
      done

      if [[ $ignorespace ]]; then
        [[ $cmd == [' 	']* ]] && return
      fi
      if [[ $ignoredups ]]; then
        local lastIndex=$((${#_ble_edit_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_edit_history[lastIndex]}" ]] && return
      fi
      if [[ $erasedups ]]; then
        local indexNext=$HISTINDEX_NEXT
        local i n=-1 N=${#_ble_edit_history[@]}
        for ((i=0;i<N;i++)); do
          if [[ ${_ble_edit_history[i]} != "$cmd" ]]; then
            if ((++n!=i)); then
              _ble_edit_history[n]=${_ble_edit_history[i]}
              _ble_edit_history_edit[n]=${_ble_edit_history_edit[i]}
            fi
          else
            ((i<HISTINDEX_NEXT&&HISTINDEX_NEXT--))
          fi
        done
        for ((i=N-1;i>n;i--)); do
          unset '_ble_edit_history[i]'
          unset '_ble_edit_history_edit[i]'
        done
        [[ ${HISTINDEX_NEXT+set} ]] && HISTINDEX_NEXT=$indexNext
      fi
    fi
    local topIndex=${#_ble_edit_history[@]}
    _ble_edit_history[topIndex]=$cmd
    _ble_edit_history_edit[topIndex]=$cmd
    _ble_edit_history_count=$((topIndex+1))
    _ble_edit_history_ind=$_ble_edit_history_count

    # _ble_bash<30100 の時は必ずここを通る。
    # 初期化時に _ble_edit_history_loaded=1 になるので。
    ((_ble_bash<30100)) && use_bash300wa=1
  else
    if [[ $HISTCONTROL ]]; then
      # 未だ履歴が初期化されていない場合は取り敢えず history -s に渡す。
      # history -s でも HISTCONTROL に対するフィルタはされる。
      # history -s で項目が追加されたかどうかはスクリプトからは分からないので
      # _ble_edit_history_count は一旦クリアする。
      _ble_edit_history_count=
    else
      # HISTCONTROL がなければ多分 history -s で必ず追加される。
      # _ble_edit_history_count 取得済ならば更新。
      [[ $_ble_edit_history_count ]] &&
        ((_ble_edit_history_count++))
    fi
  fi

  if [[ $cmd == *$'\n'* ]]; then
    # Note: 改行を含む場合は %q は常に $'' の形式になる。
    ble/util/sprintf cmd 'eval -- %q' "$cmd"
  fi

  if [[ $use_bash300wa ]]; then
    # bash-3.1 workaround
    local tmp=$_ble_base_run/$$.ble_edit_history_add.txt
    [[ ${HISTFILE-} ]] && builtin printf '%s\n' "$cmd" >> "${HISTFILE-}"
    builtin printf '%s\n' "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble-edit/history/clear-background-load
    builtin history -s -- "$cmd"
  fi
}

function ble-edit/history/add {
  local command=$1
  if [[ $_ble_edit_history_prefix ]]; then
    local code='
#%    # PREFIX_history_edit を未編集状態に戻す
      local index
      for index in "${!PREFIX_history_dirt[@]}"; do
        PREFIX_history_edit[index]=${PREFIX_history[index]}
      done
      PREFIX_history_dirt=()

      local topIndex=${#PREFIX_history[@]}
      PREFIX_history[topIndex]=$command
      PREFIX_history_edit[topIndex]=$command
      PREFIX_history_ind=$((topIndex+1))'
    eval "${code//PREFIX/$_ble_edit_history_prefix}"
  else
    ble-edit/history/add/.command-history "$command"
  fi
}

function ble-edit/history/goto {
  ble-edit/history/load

  local histlen= index0= index1=$1
  ble-edit/history/get-count -v histlen
  ble-edit/history/get-index -v index0

  ((index0==index1)) && return

  if ((index1>histlen)); then
    index1=histlen
    ble/widget/.bell
  elif ((index1<0)); then
    index1=0
    ble/widget/.bell
  fi

  ((index0==index1)) && return

  local code='
    # store
    if [[ ${PREFIX_history_edit[index0]} != "$_ble_edit_str" ]]; then
      PREFIX_history_edit[index0]=$_ble_edit_str
      PREFIX_history_dirt[index0]=1
    fi

    # restore
    ble-edit/history/onleave.fire
    PREFIX_history_ind=$index1
    _ble_edit_str.reset "${PREFIX_history_edit[index1]}" history'
  eval "${code//PREFIX/${_ble_edit_history_prefix:-_ble_edit}}"

  # point
  if [[ $bleopt_history_preserve_point ]]; then
    if ((_ble_edit_ind>${#_ble_edit_str})); then
      _ble_edit_ind=${#_ble_edit_str}
    fi
  else
    if ((index1<index0)); then
      # 遡ったときは最後の行の末尾
      _ble_edit_ind=${#_ble_edit_str}
    else
      # 進んだときは最初の行の末尾
      local first_line=${_ble_edit_str%%$'\n'*}
      _ble_edit_ind=${#first_line}
    fi
  fi
  _ble_edit_mark=0
  _ble_edit_mark_active=
}

function ble/widget/history-next {
  if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
    local arg; ble-edit/content/get-arg 1
    local index; ble-edit/history/get-index
    ble-edit/history/goto $((index+arg))
  else
    ble-edit/content/clear-arg
    ble/widget/.bell
  fi
}
function ble/widget/history-prev {
  local arg; ble-edit/content/get-arg 1
  local index; ble-edit/history/get-index
  ble-edit/history/goto $((index-arg))
}
function ble/widget/history-beginning {
  ble-edit/content/clear-arg
  ble-edit/history/goto 0
}
function ble/widget/history-end {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
    local count; ble-edit/history/get-count
    ble-edit/history/goto "$count"
  else
    ble/widget/.bell
  fi
}

function ble/widget/history-expand-line {
  ble-edit/content/clear-arg
  local hist_expanded
  ble-edit/hist_expanded.update "$_ble_edit_str" || return
  [[ $_ble_edit_str == "$hist_expanded" ]] && return

  _ble_edit_str.reset-and-check-dirty "$hist_expanded"
  _ble_edit_ind=${#hist_expanded}
  _ble_edit_mark=0
  _ble_edit_mark_active=
}
function ble/widget/history-expand-backward-line {
  ble-edit/content/clear-arg
  local prevline=${_ble_edit_str::_ble_edit_ind} hist_expanded
  ble-edit/hist_expanded.update "$prevline" || return
  [[ $prevline == "$hist_expanded" ]] && return

  local ret
  ble/string#common-prefix "$prevline" "$hist_expanded"; local dmin=${#ret}
  _ble_edit_str.replace "$dmin" "$_ble_edit_ind" "${hist_expanded:dmin}"
  _ble_edit_ind=${#hist_expanded}
  _ble_edit_mark=0
  _ble_edit_mark_active=
}
function ble/widget/magic-space {
  local arg; ble-edit/content/get-arg ''
  ble/widget/history-expand-backward-line
  local -a KEYS=(32)
  _ble_edit_arg=$arg
  ble/widget/self-insert
}

# 
#------------------------------------------------------------------------------
# **** incremental search ****                                 @history.isearch

## 変数 _ble_edit_isearch_str
##   一致した文字列
## 変数 _ble_edit_isearch_dir
##   現在・直前の検索方法
## 配列 _ble_edit_isearch_arr[]
##   インクリメンタル検索の過程を記録する。
##   各要素は ind:dir:beg:end:needle の形式をしている。
##   ind は履歴項目の番号を表す。dir は履歴検索の方向を表す。
##   beg, end はそれぞれ一致開始位置と終了位置を表す。
##   丁度 _ble_edit_ind 及び _ble_edit_mark に対応する。
##   needle は検索に使用した文字列を表す。
## 配列 _ble_edit_isearch_que
##   未処理の操作
_ble_edit_isearch_str=
_ble_edit_isearch_dir=-
_ble_edit_isearch_arr=()
_ble_edit_isearch_que=()

## @var[in] isearch_ntask
function ble-edit/isearch/.draw-line-with-progress {
  # 出力
  local ll rr
  if [[ $_ble_edit_isearch_dir == - ]]; then
    # Emacs workaround: '<<' や "<<" と書けない。
    ll=\<\< rr="  "
  else
    ll="  " rr=">>"
    text="  >>)"
  fi
  local index; ble-edit/history/get-index
  local count; ble-edit/history/get-count
  local histIndex='!'$((index+1))
  local text="(${#_ble_edit_isearch_arr[@]}: $ll $histIndex $rr) \`$_ble_edit_isearch_str'"

  if [[ $1 ]]; then
    local pos=$1
    local percentage=$((count?pos*1000/count:1000))
    text="$text searching... @$pos ($((percentage/10)).$((percentage%10))%)"
    ((isearch_ntask)) && text="$text *$isearch_ntask"
  fi

  ble-edit/info/show text "$text"
}

function ble-edit/isearch/.draw-line {
  ble-edit/isearch/.draw-line-with-progress
}
function ble-edit/isearch/.erase-line {
  ble-edit/info/default
}
function ble-edit/isearch/.set-region {
  local beg=$1 end=$2
  if ((beg<end)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      _ble_edit_ind=$beg
      _ble_edit_mark=$end
    else
      _ble_edit_ind=$end
      _ble_edit_mark=$beg
    fi
    _ble_edit_mark_active=S
  else
    _ble_edit_mark_active=
  fi
}
## 関数 ble-edit/isearch/.push-isearch-array
##   現在の isearch の情報を配列 _ble_edit_isearch_arr に待避する。
##
##   これから登録しようとしている情報が現在のものと同じならば何もしない。
##   これから登録しようとしている情報が配列の最上にある場合は、
##   検索の巻き戻しと解釈して配列の最上の要素を削除する。
##   それ以外の場合は、現在の情報を配列に追加する。
##   @var[in] ind beg end needle
##     これから登録しようとしている isearch の情報。
function ble-edit/isearch/.push-isearch-array {
  local hash=$beg:$end:$needle

  # [... A | B] -> A と来た時 (A を _ble_edit_isearch_arr から削除) [... | A] になる。
  local ilast=$((${#_ble_edit_isearch_arr[@]}-1))
  if ((ilast>=0)) && [[ ${_ble_edit_isearch_arr[ilast]} == "$ind:"[-+]":$hash" ]]; then
    unset "_ble_edit_isearch_arr[$ilast]"
    return
  fi

  local oind; ble-edit/history/get-index -v oind
  local obeg=$_ble_edit_ind oend=$_ble_edit_mark tmp
  [[ $_ble_edit_mark_active ]] || oend=$obeg
  ((obeg<=oend||(tmp=obeg,obeg=oend,oend=tmp)))
  local oneedle=$_ble_edit_isearch_str
  local ohash=$obeg:$oend:$oneedle

  # [... A | B] -> B と来た時 (何もしない) [... A | B] になる。
  [[ $ind == "$oind" && $hash == "$ohash" ]] && return

  # [... A | B] -> C と来た時 (B を _ble_edit_isearch_arr に移動) [... A B | C] になる。
  ble/array#push _ble_edit_isearch_arr "$oind:$_ble_edit_isearch_dir:$ohash"
}
function ble-edit/isearch/.goto-match {
  local ind=$1 beg=$2 end=$3 needle=$4
  ((beg==end&&(beg=end=-1)))

  # 検索履歴に待避 (変数 ind beg end needle 使用)
  ble-edit/isearch/.push-isearch-array

  # 状態を更新
  _ble_edit_isearch_str=$needle
  local oind; ble-edit/history/get-index -v oind
  ((oind!=ind)) && ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"

  # isearch 表示
  ble-edit/isearch/.draw-line
  _ble_edit_bind_force_draw=1
}

# ---- basic isearch functions ------------------------------------------------

## 関数 ble-edit/isearch/search needle opts ; beg end
##   @param[in] needle
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     + ... forward に検索します (既定)
##     - ... backward に検索します。終端位置が現在位置以前にあるものに一致します。
##     B ... backward に検索します。開始位置が現在位置より前のものに一致します。
##
##     regex
##       正規表現による一致を試みます
##
##     extend
##       これが指定された時、現在位置における一致の伸長が試みられます。
##       指定されなかったとき、現在一致範囲と重複のない新しい一致が試みられます。
##
##   @var[out] beg end
##     検索対象が見つかった時に一致範囲の先頭と終端を返します。
##
##   @exit
##     検索対象が見つかった時に 0 を返します。
##     それ以外のときに 1 を返します。
function ble-edit/isearch/search {
  local needle=$1 opts=$2
  beg= end=
  [[ :$opts: != *:regex:* ]]; local has_regex=$?
  [[ :$opts: != *:extend:* ]]; local has_extend=$?

  if [[ :$opts: == *:-:* ]]; then
    local start=$((has_extend?_ble_edit_mark+1:_ble_edit_ind))

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.*($needle)" padding=$((${#_ble_edit_str}-start))
      ((padding)) && rex="$rex.{$padding}"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        end=$((${#BASH_REMATCH}-padding))
        beg=$((end-${#rematch1}))
        return 0
      fi
    else
      local target=${_ble_edit_str::start}
      local m=${target%"$needle"*}
      if [[ $target != "$m" ]]; then
        beg=${#m}
        end=$((beg+${#needle}))
        return 0
      fi
    fi
  elif [[ :$opts: == *:B:* ]]; then
    local start=$((has_extend?_ble_edit_ind:_ble_edit_ind-1))
    ((start<0)) && return 1

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.{0,$start}($needle)"
      ((start==0)) && rex="^($needle)"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        end=${#BASH_REMATCH}
        beg=$((end-${#rematch1}))
        return 0
      fi
    else
      local target=${_ble_edit_str::start+${#needle}}
      local m=${target%"$needle"*}
      if [[ $target != "$m" ]]; then
        beg=${#m}
        end=$((beg+${#needle}))
        return 0
      fi
    fi
  else
    local start=$((has_extend?_ble_edit_mark:_ble_edit_ind))
    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="($needle).*\$"
      ((start)) && rex=".{$start}$rex"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        beg=$((${#_ble_edit_str}-${#BASH_REMATCH}+start))
        end=$((beg+${#rematch1}))
        return 0
      fi
    else
      local target=${_ble_edit_str:start}
      local m=${target#*"$needle"}
      if [[ $target != "$m" ]]; then
        end=$((${#_ble_edit_str}-${#m}))
        beg=$((end-${#needle}))
        return 0
      fi
    fi
  fi
  return 1
}
## 関数 ble-edit/isearch/.shift-backward-references
##   @var[in,out] needle
##     処理する正規表現を指定します。
##     後方参照をおきかえた正規表現を返します。
function ble-edit/isearch/.shift-backward-references {
    # 後方参照 (backward references) の番号を 1 ずつ増やす。
    # bash 正規表現は 2 桁以上の後方参照に対応していないので、
    # \1 - \8 を \2-\9 にずらすだけにする (\9 が存在するときに問題になるが仕方がない)。
    local rex_cc='\[[@][^]@]+[@]\]' # [:space:] [=a=] [.a.] など。
    local rex_bracket_expr='\[\^?]?('${rex_cc//@/:}'|'${rex_cc//@/=}'|'${rex_cc//@/.}'|[^][]|\[[^]:=.])*\[?\]'
    local rex='^('$rex_bracket_expr'|\\[^1-8])*\\[1-8]'
    local buff=
    while [[ $needle =~ $rex ]]; do
      local mlen=${#BASH_REMATCH}
      buff=$buff${BASH_REMATCH::mlen-1}$((10#0${BASH_REMATCH:mlen-1}+1))
      needle=${needle:mlen}
    done
    needle=$buff$needle
}

## 関数 ble-edit/isearch/forward-search-history opts
## 関数 ble-edit/isearch/backward-search-history opts
## 関数 ble-edit/isearch/backward-search-history-blockwise opts
##
##   backward-search-history-blockwise does blockwise search
##   as a workaround for bash slow array access
##
##   @param[in] opts
##     コロン区切りのオプション
##     regex 正規表現による検索
##     stop_check
##     progress
##
##   @var[in] _ble_edit_history_edit
##     検索対象の配列と全体の検索開始位置
##   @var[in] start
##     全体の検索開始位置を指定します。
##   @var[in] needle
##     検索文字列を指定します。
##
##   @var[in,out] index
##     今回の呼び出しの検索開始位置を指定します。
##     一致が成功したとき見つかった位置を返します。
##     一致が中断されたとき次の位置 (再開時に最初に検査する位置) を返します。
##
##   @var[in,out] isearch_time
##
##   @var[in] isearch_ntask
##     progress 表示に使用
##
##   @exit
##     見つかったときに 0 を返します。
##     見つからなかったときに 1 を返します。
##     中断された時に 148 を返します。
##
function ble-edit/isearch/backward-search-history-blockwise {
  local opts=$1
  [[ :$opts: != *:regex:* ]]; local has_regex=$?
  [[ :$opts: != *:stop_check:* ]]; local has_stop_check=$?
  [[ :$opts: != *:progress:* ]]; local has_progress=$?

  ble-edit/history/load
  if [[ $_ble_edit_history_prefix ]]; then
    local -a _ble_edit_history_edit
    eval "_ble_edit_history_edit=(\"\${${_ble_edit_history_prefix}_history_edit[@]}\")"
  fi

  local NSTPCHK=1000 # 十分高速なのでこれぐらい大きくてOK
  local NPROGRESS=$((NSTPCHK*2)) # 倍数である必要有り
  local irest block j i=$index
  index=
  while ((i>=0)); do
    ((block=start-i,
      block<5&&(block=5),
      irest=NSTPCHK-isearch_time%NSTPCHK,
      block>i+1&&(block=i+1),
      block>irest&&(block=irest)))

    if ((has_regex)); then
      for ((j=i-block;++j<=i;)); do
        [[ ${_ble_edit_history_edit[j]} =~ $needle ]] && index=$j
      done
    else
      for ((j=i-block;++j<=i;)); do
        [[ ${_ble_edit_history_edit[j]} == *"$needle"* ]] && index=$j
      done
    fi

    ((isearch_time+=block))
    if [[ $index ]]; then
      ((i=j))
      return 0
    fi

    ((i-=block))
    if ((has_stop_check&&isearch_time%NSTPCHK==0)) && ble/util/is-stdin-ready; then
      return 148
    elif ((has_progress&&isearch_time%NPROGRESS==0)); then
      ble-edit/isearch/.draw-line-with-progress "$i"
    fi
  done
  return 1
}
function ble-edit/isearch/next-history/forward-search-history.impl {
  local opts=$1
  [[ :$opts: != *:regex:* ]]; local has_regex=$?
  [[ :$opts: != *:stop_check:* ]]; local has_stop_check=$?
  [[ :$opts: != *:progress:* ]]; local has_progress=$?
  [[ :$opts: != *:backward:* ]]; local has_backward=$?

  ble-edit/history/load
  if [[ $_ble_edit_history_prefix ]]; then
    local -a _ble_edit_history_edit
    eval "_ble_edit_history_edit=(\"\${${_ble_edit_history_prefix}_history_edit[@]}\")"
  fi

  if ((has_backward)); then
    local expr_cond='index>=0' expr_incr='index--'
  else
    local expr_cond="index<${#_ble_edit_history_edit[@]}" expr_incr='index++'
  fi

  for ((;expr_cond;expr_incr)); do
    ((isearch_time++))
    if ((has_stop_check&&isearch_time%100==0)) && ble/util/is-stdin-ready; then
      return 148
    fi

    if
      if ((has_regex)); then
        [[ ${_ble_edit_history_edit[index]} =~ $needle ]]
      else
        [[ ${_ble_edit_history_edit[index]} == *"$needle"* ]]
      fi
    then
      return 0
    fi

    if ((has_progress&&isearch_time%1000==0)); then
      ble-edit/isearch/.draw-line-with-progress "$index"
    fi
  done
  return 1
}
function ble-edit/isearch/forward-search-history {
  ble-edit/isearch/next-history/forward-search-history.impl "$1"
}
function ble-edit/isearch/backward-search-history {
  ble-edit/isearch/next-history/forward-search-history.impl "$1:backward"
}

# ---- isearch fibers ---------------------------------------------------------

## 関数 ble-edit/isearch/next.fib needle isAdd
function ble-edit/isearch/next.fib {
  local needle=${1-$_ble_edit_isearch_str} isAdd=$2
  local ind; ble-edit/history/get-index -v ind

  local beg= end= search_opts=$_ble_edit_isearch_dir
  ((isAdd)) && search_opts=$search_opts:extend
  if ble-edit/isearch/search "$needle" "$search_opts"; then
    ble-edit/isearch/.goto-match "$ind" "$beg" "$end" "$needle"
    return
  fi

  ble-edit/isearch/next-history.fib "${@:1:1}"
}

## 関数 ble-edit/isearch/next-history.fib [needle isAdd]
##
##   @var[in,out] isearch_suspend
##     中断した時にこの変数に再開用のデータを格納します。
##     再開する時はこの変数の中断時の内容を復元してこの関数を呼び出します。
##     この変数が空の場合は新しい検索を開始します。
##   @param[in,opt] needle,isAdd
##     新しい検索を開始する場合に、検索対象を明示的に指定します。
##     needle に検索対象の文字列を指定します。
##     isAdd 現在の履歴項目を検索対象とするかどうかを指定します。
##   @var[in] _ble_edit_isearch_str
##     最後に一致した検索文字列を指定します。
##     検索対象を明示的に指定しなかった場合に使う検索対象です。
##   @var[in] _ble_edit_history_ind
##     現在の履歴項目の位置を指定します。
##     新しい検索を開始する時の検索開始位置になります。
##
##   @var[in] _ble_edit_isearch_dir
##     現在の検索方向を指定します。
##   @var[in] _ble_edit_history_edit[]
##   @var[in,out] isearch_time
##
function ble-edit/isearch/next-history.fib {
  if [[ $isearch_suspend ]]; then
    # resume the previous search
    local needle=${isearch_suspend#*:} isAdd=
    local index start; eval "${isearch_suspend%%:*}"
    isearch_suspend=
  else
    # initialize new search
    local needle=${1-$_ble_edit_isearch_str} isAdd=$2
    local start; ble-edit/history/get-index -v start
    local index=$start
  fi

  if ((!isAdd)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      ((index--))
    else
      ((index++))
    fi
  fi

  # 検索
  if [[ $_ble_edit_isearch_dir == - ]]; then
    ble-edit/isearch/backward-search-history-blockwise stop_check:progress
  else
    ble-edit/isearch/forward-search-history stop_check:progress
  fi
  local r=$?

  if ((r==0)); then
    # 見付かった場合

    # 一致範囲 beg-end を取得
    local str; ble-edit/history/get-editted-entry -v str "$index"
    if [[ $_ble_edit_isearch_dir == - ]]; then
      local prefix=${str%"$needle"*}
    else
      local prefix=${str%%"$needle"*}
    fi
    local beg=${#prefix} end=$((${#prefix}+${#needle}))

    ble-edit/isearch/.goto-match "$index" "$beg" "$end" "$needle"
  elif ((r==148)); then
    # 中断した場合
    isearch_suspend="index=$index start=$start:$needle"
    return
  else
    # 見つからなかった場合
    ble/widget/.bell "isearch: \`$needle' not found"
    return
  fi
}

function ble-edit/isearch/forward.fib {
  _ble_edit_isearch_dir=+
  ble-edit/isearch/next.fib
}
function ble-edit/isearch/backward.fib {
  _ble_edit_isearch_dir=-
  ble-edit/isearch/next.fib
}
function ble-edit/isearch/self-insert.fib {
  local code=$1
  ((code==0)) && return
  local ret needle
  ble/util/c2s "$code"
  ble-edit/isearch/next.fib "$_ble_edit_isearch_str$ret" 1
}
function ble-edit/isearch/history-forward.fib {
  _ble_edit_isearch_dir=+
  ble-edit/isearch/next-history.fib
}
function ble-edit/isearch/history-backward.fib {
  _ble_edit_isearch_dir=-
  ble-edit/isearch/next-history.fib
}
function ble-edit/isearch/history-self-insert.fib {
  local code=$1
  ((code==0)) && return
  local ret needle
  ble/util/c2s "$code"
  ble-edit/isearch/next-history.fib "$_ble_edit_isearch_str$ret" 1
}

function ble-edit/isearch/prev {
  local sz=${#_ble_edit_isearch_arr[@]}
  ((sz==0)) && return 0

  local ilast=$((sz-1))
  local top=${_ble_edit_isearch_arr[ilast]}
  unset "_ble_edit_isearch_arr[$ilast]"

  local ind dir beg end
  ind=${top%%:*}; top=${top#*:}
  dir=${top%%:*}; top=${top#*:}
  beg=${top%%:*}; top=${top#*:}
  end=${top%%:*}; top=${top#*:}

  _ble_edit_isearch_dir=$dir
  ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"
  _ble_edit_isearch_str=$top

  # isearch 表示
  ble-edit/isearch/.draw-line
}

function ble-edit/isearch/process {
  _ble_edit_isearch_que=()

  local isearch_suspend=
  local isearch_time=0
  local isearch_ntask=$#
  while (($#)); do
    ((isearch_ntask--))
    case "$1" in
    (sf)  ble-edit/isearch/forward.fib ;;
    (sb)  ble-edit/isearch/backward.fib ;;
    (si*) ble-edit/isearch/self-insert.fib "${1:2}";;
    (hf)  ble-edit/isearch/history-forward.fib ;;
    (hb)  ble-edit/isearch/history-backward.fib ;;
    (hi*) ble-edit/isearch/history-self-insert.fib "${1:2}";;
    (z*)  isearch_suspend=${1:1}
          ble-edit/isearch/next-history.fib;;
    (*)   ble-stackdump "unknown isearch process entry '$1'." ;;
    esac
    shift

    if [[ $isearch_suspend ]]; then
      _ble_edit_isearch_que=("z$isearch_suspend" "$@")
      return
    fi
  done

  # 検索処理が完了した時
  ble-edit/isearch/.draw-line
}

function ble/widget/isearch/forward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" sf
}
function ble/widget/isearch/backward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" sb
}
function ble/widget/isearch/self-insert {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" "si$code"
}
function ble/widget/isearch/history-forward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" hf
}
function ble/widget/isearch/history-backward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" hb
}
function ble/widget/isearch/history-self-insert {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" "hi$code"
}
function ble/widget/isearch/prev {
  local nque
  if ((nque=${#_ble_edit_isearch_que[@]})); then
    unset '_ble_edit_isearch_que[nque-1]'
    if ((nque>=2)); then
      ble-edit/isearch/process "${_ble_edit_isearch_que[@]}"
    else
      ble-edit/isearch/.draw-line # 進捗状況を消去
    fi
  else
    ble-edit/isearch/prev
  fi
}
function ble/widget/isearch/exit {
  ble-decode/keymap/pop
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=
  _ble_edit_isearch_que=()
  _ble_edit_isearch_str=
  ble-edit/isearch/.erase-line
}
function ble/widget/isearch/cancel {
  if ((${#_ble_edit_isearch_que[@]})); then
    _ble_edit_isearch_que=()
    ble-edit/isearch/.draw-line # 進捗状況を消去
  else
    if ((${#_ble_edit_isearch_arr[@]})); then
      local step
      ble/string#split step : "${_ble_edit_isearch_arr[0]}"
      ble-edit/history/goto "${step[0]}"
      _ble_edit_ind=${step[2]} _ble_edit_mark=${step[3]}
    fi

    ble/widget/isearch/exit
  fi
}
function ble/widget/isearch/exit-default {
  ble/widget/isearch/exit
  ble-decode-key "${KEYS[@]}"
}
function ble/widget/isearch/accept {
  if ((${#_ble_edit_isearch_que[@]})); then
    ble/widget/.bell "isearch: now searching..."
  else
    ble/widget/isearch/exit-default
  fi
}
function ble/widget/isearch/exit-delete-forward-char {
  ble/widget/isearch/exit
  ble/widget/delete-forward-char
}

function ble/widget/history-isearch-backward {
  ble-edit/content/clear-arg
  ble-decode/keymap/push isearch
  _ble_edit_isearch_dir=-
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_que=()
  _ble_edit_mark=$_ble_edit_ind
  ble-edit/isearch/.draw-line
}
function ble/widget/history-isearch-forward {
  ble-edit/content/clear-arg
  ble-decode/keymap/push isearch
  _ble_edit_isearch_dir=+
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_que=()
  _ble_edit_mark=$_ble_edit_ind
  ble-edit/isearch/.draw-line
}

# ---- keymap:isearch ---------------------------------------------------------

function ble-decode/keymap:isearch/define {
  local ble_bind_keymap=isearch

  ble-bind -f __defchar__ isearch/self-insert
  ble-bind -f C-r         isearch/backward
  ble-bind -f C-s         isearch/forward
  ble-bind -f C-h         isearch/prev
  ble-bind -f DEL         isearch/prev

  ble-bind -f __default__ isearch/exit-default
  ble-bind -f M-C-j       isearch/exit
  ble-bind -f C-d         isearch/exit-delete-forward-char
  ble-bind -f C-g         isearch/cancel
  ble-bind -f C-j         isearch/accept
  ble-bind -f C-m         isearch/accept
}

# 
#------------------------------------------------------------------------------
# **** common bindings ****                                          @edit.safe

function ble-decode/keymap:safe/.bind {
  [[ $ble_bind_nometa && $1 == *M-* ]] && return
  ble-bind -f "$1" "$2"
}
function ble-decode/keymap:safe/bind-common {
  ble-decode/keymap:safe/.bind insert      'overwrite-mode'

  # ins
  ble-decode/keymap:safe/.bind __defchar__ 'self-insert'
  ble-decode/keymap:safe/.bind 'C-q'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'C-v'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'C-M-m'     'newline'
  ble-decode/keymap:safe/.bind 'M-RET'     'newline'
  ble-decode/keymap:safe/.bind paste_begin 'bracketed-paste'

  # kill
  ble-decode/keymap:safe/.bind 'C-@'       'set-mark'
  ble-decode/keymap:safe/.bind 'M-SP'      'set-mark'
  ble-decode/keymap:safe/.bind 'C-x C-x'   'exchange-point-and-mark'
  ble-decode/keymap:safe/.bind 'C-w'       'kill-region-or kill-backward-uword'
  ble-decode/keymap:safe/.bind 'M-w'       'copy-region-or copy-backward-uword'
  ble-decode/keymap:safe/.bind 'C-y'       'yank'

  # spaces
  ble-decode/keymap:safe/.bind 'M-\'       'delete-horizontal-space'

  # charwise operations
  ble-decode/keymap:safe/.bind 'C-f'       '@nomarked forward-char'
  ble-decode/keymap:safe/.bind 'C-b'       '@nomarked backward-char'
  ble-decode/keymap:safe/.bind 'right'     '@nomarked forward-char'
  ble-decode/keymap:safe/.bind 'left'      '@nomarked backward-char'
  ble-decode/keymap:safe/.bind 'S-C-f'     '@marked forward-char'
  ble-decode/keymap:safe/.bind 'S-C-b'     '@marked backward-char'
  ble-decode/keymap:safe/.bind 'S-right'   '@marked forward-char'
  ble-decode/keymap:safe/.bind 'S-left'    '@marked backward-char'
  ble-decode/keymap:safe/.bind 'C-d'       'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'C-h'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'delete'    'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'DEL'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'C-t'       'transpose-chars'

  # wordwise operations
  ble-decode/keymap:safe/.bind 'C-right'   '@nomarked forward-cword'
  ble-decode/keymap:safe/.bind 'C-left'    '@nomarked backward-cword'
  ble-decode/keymap:safe/.bind 'M-right'   '@nomarked forward-sword'
  ble-decode/keymap:safe/.bind 'M-left'    '@nomarked backward-sword'
  ble-decode/keymap:safe/.bind 'S-C-right' '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'S-C-left'  '@marked backward-cword'
  ble-decode/keymap:safe/.bind 'S-M-right' '@marked forward-sword'
  ble-decode/keymap:safe/.bind 'S-M-left'  '@marked backward-sword'
  ble-decode/keymap:safe/.bind 'M-d'       'kill-forward-cword'
  ble-decode/keymap:safe/.bind 'M-h'       'kill-backward-cword'
  ble-decode/keymap:safe/.bind 'C-delete'  'delete-forward-cword'
  ble-decode/keymap:safe/.bind 'C-_'       'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'M-delete'  'copy-forward-sword'
  ble-decode/keymap:safe/.bind 'M-DEL'     'copy-backward-sword'

  ble-decode/keymap:safe/.bind 'M-f'       '@nomarked forward-cword'
  ble-decode/keymap:safe/.bind 'M-b'       '@nomarked backward-cword'
  ble-decode/keymap:safe/.bind 'M-F'       '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'M-B'       '@marked backward-cword'
  ble-decode/keymap:safe/.bind 'C-M-f'     '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'C-M-b'     '@marked backward-cword'

  # linewise operations
  ble-decode/keymap:safe/.bind 'C-a'       '@nomarked beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-e'       '@nomarked end-of-line'
  ble-decode/keymap:safe/.bind 'home'      '@nomarked beginning-of-line'
  ble-decode/keymap:safe/.bind 'end'       '@nomarked end-of-line'
  ble-decode/keymap:safe/.bind 'S-C-a'     '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'S-C-e'     '@marked end-of-line'
  ble-decode/keymap:safe/.bind 'S-home'    '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'S-end'     '@marked end-of-line'
  ble-decode/keymap:safe/.bind 'M-m'       '@nomarked beginning-of-line'
  ble-decode/keymap:safe/.bind 'S-M-m'     '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'M-M'       '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-p'       '@nomarked backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'up'        '@nomarked backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-n'       '@nomarked forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'down'      '@nomarked forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-k'       'kill-forward-line'
  ble-decode/keymap:safe/.bind 'C-u'       'kill-backward-line'

  ble-decode/keymap:safe/.bind 'S-C-p'     '@marked backward-line'
  ble-decode/keymap:safe/.bind 'S-up'      '@marked backward-line'
  ble-decode/keymap:safe/.bind 'S-C-n'     '@marked forward-line'
  ble-decode/keymap:safe/.bind 'S-down'    '@marked forward-line'

  ble-decode/keymap:safe/.bind 'C-home'    '@nomarked beginning-of-text'
  ble-decode/keymap:safe/.bind 'C-end'     '@nomarked end-of-text'
  ble-decode/keymap:safe/.bind 'S-C-home'  '@marked beginning-of-text'
  ble-decode/keymap:safe/.bind 'S-C-end'   '@marked end-of-text'
}
function ble-decode/keymap:safe/bind-history {
  ble-decode/keymap:safe/.bind 'C-r'       'history-isearch-backward'
  ble-decode/keymap:safe/.bind 'C-s'       'history-isearch-forward'
  ble-decode/keymap:safe/.bind 'M-<'       'history-beginning'
  ble-decode/keymap:safe/.bind 'M->'       'history-end'
  ble-decode/keymap:safe/.bind 'C-prior'   'history-beginning'
  ble-decode/keymap:safe/.bind 'C-next'    'history-end'
  ble-decode/keymap:safe/.bind 'C-p'       '@nomarked backward-line history'
  ble-decode/keymap:safe/.bind 'up'        '@nomarked backward-line history'
  ble-decode/keymap:safe/.bind 'C-n'       '@nomarked forward-line history'
  ble-decode/keymap:safe/.bind 'down'      '@nomarked forward-line history'
}

function ble/widget/safe/__attach__ {
  ble-edit/info/set-default text ''
}
function ble-decode/keymap:safe/define {
  local ble_bind_keymap=safe
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history

  ble-bind -f 'C-d'      'delete-region-or delete-forward-char-or-exit'

  ble-bind -f 'SP'       magic-space
  ble-bind -f 'C-RET'    history-expand-line

  ble-bind -f __attach__ safe/__attach__

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
}

function ble-edit/bind/load-keymap-definition:safe {
  ble-decode/keymap/load safe
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/read ****                                            @edit.read

_ble_edit_read_accept=
_ble_edit_read_result=
function ble/widget/read/accept {
  _ble_edit_read_accept=1
  _ble_edit_read_result=$_ble_edit_str
  # [[ $_ble_edit_read_result ]] &&
  #   ble-edit/history/add "$_ble_edit_read_result" # Note: cancel でも登録する
  ble-decode/keymap/pop
}
function ble/widget/read/cancel {
  local _ble_edit_line_disabled=1
  ble/widget/read/accept
  _ble_edit_read_accept=2
}
function ble/widget/read/delete-forward-char-or-cancel {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/read/cancel
  fi
}

function ble-decode/keymap:read/define {
  local ble_bind_keymap=read
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history

  ble-bind -f 'C-c' read/cancel
  ble-bind -f 'C-\' read/cancel
  ble-bind -f 'C-m' read/accept
  ble-bind -f 'RET' read/accept
  ble-bind -f 'C-j' read/accept
  ble-bind -f 'C-d' 'delete-region-or read/delete-forward-char-or-cancel'

  # shell functions
  ble-bind -f  'C-g'     bell
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'M-l'     redraw-line
  # ble-bind -f  'C-i'     complete
  # ble-bind -f  'TAB'     complete
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'C-RET'   history-expand-line
  # ble-bind -f 'SP'      magic-space

  # ble-bind -f 'C-[' bell # unbound for "bleopt decode_isolated_esc=auto"
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

_ble_edit_read_history=()
_ble_edit_read_history_edit=()
_ble_edit_read_history_dirt=()
_ble_edit_read_history_ind=0
_ble_edit_read_history_onleave=()

function ble-edit/read/.process-option {
  case $1 in
  (-e) opt_readline=1 ;;
  (-i) opt_default=$2 ;;
  (-p) opt_prompt=$2 ;;
  (-u) opt_fd=$2
       ble/array#push opts_in "$@" ;;
  (-t) opt_timeout=$2 ;;
  (*)  ble/array#push opts "$@" ;;
  esac
}
function ble-edit/read/.read-arguments {
  local is_normal_args=
  vars=()
  opts=()
  while (($#)); do
    local arg=$1; shift
    if [[ $is_normal_args || $arg != -* ]]; then
      ble/array#push vars "$arg"
      continue
    fi

    if [[ $arg == -- ]]; then
      is_normal_args=1
      continue
    fi

    local i n=${#arg}
    for ((i=1;i<n;i++)); do
      case -${arg:i} in
      (-[adinNptu])  ble-edit/read/.process-option -${arg:i:1} "$1"; shift; break ;;
      (-[adinNptu]*) ble-edit/read/.process-option -${arg:i:1} "${arg:i+1}"; break ;;
      (-[ers]*)      ble-edit/read/.process-option -${arg:i:1} ;;
      esac
    done
  done
}

function ble-edit/read/.setup-textarea {
  # 初期化
  local def_kmap; ble-decode/DEFAULT_KEYMAP -v def_kmap
  ble-decode/keymap/push read

  # textarea, info
  _ble_textarea_panel=2
  ble/textarea#invalidate
  ble-edit/info/set-default raw ''

  # edit/prompt
  _ble_edit_PS1=$opt_prompt
  _ble_edit_prompt=("" 0 0 0 32 0 "" "")

  # edit
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=
  _ble_edit_str.reset "$opt_default" newline
  _ble_edit_ind=${#opt_default}

  # edit/undo
  ble-edit/undo/clear-all

  # edit/history
  _ble_edit_history_prefix=_ble_edit_read_

  # syntax, highlight
  _ble_syntax_lang=text
  _ble_highlight_layer__list=(plain region overwrite_mode disabled)
}
function ble/builtin/read/TRAPWINCH {
  ble/util/joblist.check
  local IFS=$_ble_term_IFS
  _ble_textmap_pos=()
  ble/util/buffer "$_ble_term_ed"
  ble/textarea#redraw
  ble/util/joblist.check ignore-volatile-jobs
}
function ble-edit/read/.loop {
  # Note: サブシェルの中では eval で failglob を防御できない様だ。
  #   それが理由で visible-bell を呼び出すと read が終了してしまう。
  #   対策として failglob を外す。サブシェルの中なので影響はない筈。
  # ref #D1090
  shopt -u failglob

  local x0=$_ble_line_x y0=$_ble_line_y
  ble-edit/read/.setup-textarea
  ble/builtin/trap/set-readline-signal WINCH ble-edit/read/TRAPWINCH

  if [[ $opt_timeout ]]; then
    local start_time; ble/util/strftime -v start_time %s

    # 実際は 1.99999 で 1 に切り捨てられている可能性もある。
    # 待ち時間が長くなる方向に倒して処理する。
    ((start_time&&start_time--))
  fi

  ble-edit/info/reveal
  ble/textarea#render
  ble/util/buffer.flush >&2

  local char= ret=
  local _ble_edit_read_accept=
  local _ble_edit_read_result=
  while [[ ! $_ble_edit_read_accept ]]; do
    # read 1 character
    TMOUT= IFS= builtin read -r -d '' -n 1 ${opt_timeout:+-t "$opt_timeout"} char "${opts_in[@]}"; local ext=$?
    if ((ext>142)); then
      # timeout
      #   Note: #D1467 Cygwin/Linux では read の timeout は 142 だが、これはシステム依存。
      #   man bash にある様に 128 より大きいかどうかで判定する。
      _ble_edit_read_accept=142
      break
    fi

    # update timeout
    if [[ $opt_timeout ]]; then
      local current_time; ble/util/strftime -v current_time %s
      if [[ $opt_timeout == *.* ]]; then
        local mantissa=$((${opt_timeout%%.*}-(current_time-start_time)))
        local fraction=${opt_timeout#*.}
        opt_timeout=$mantissa.$fraction
        ((mantissa<0||mantissa==0&&fraction==0)) && opt_timeout=0
      else
        opt_timeout=$((opt_timeout-(current_time-start_time)))
        ((opt_timeout<0)) && opt_timeout=0
      fi
      if ((opt_timeout<=0)); then
        # timeout
        _ble_edit_read_accept=142
        break
      fi
      start_time=$current_time
    fi

    # process
    ble/util/s2c "$char"
    ble-decode-char "$ret"
    [[ $_ble_edit_read_accept ]] && break

    # render
    ble/util/is-stdin-ready && continue
    ble-edit/info/reveal
    ble/textarea#render
    ble/util/buffer.flush >&2
  done

  # 入力が終わったら消すか次の行へ行く
  if [[ $_ble_edit_read_context == internal ]]; then
    local -a DRAW_BUFF=()
    ble-form/panel#set-height.draw "$_ble_textarea_panel" 0
    ble-form/goto.draw "$x0" "$y0"
    ble-edit/draw/bflush
  else
    if ((_ble_edit_read_accept==1)); then
      ble/widget/.insert-newline
    else
      _ble_edit_line_disabled=1 ble/widget/.insert-newline
    fi
  fi

  ble/util/buffer.flush >&2
  if ((_ble_edit_read_accept==1)); then
    local q=\' Q="'\''"
    printf %s "__ble_input='${_ble_edit_read_result//$q/$Q}'"
  elif ((_ble_edit_read_accept==142)); then
    # timeout
    return "$ext"
  else
    return 1
  fi
}

function ble-edit/read/.impl {
  local -a opts=() vars=() opts_in=()
  local opt_readline= opt_prompt= opt_default= opt_timeout= opt_fd=0
  ble-edit/read/.read-arguments "$@"
  if ! [[ $opt_readline && -t $opt_fd ]]; then
    # "-e オプションが指定されてかつ端末からの読み取り" のとき以外は builtin read する。
    [[ $opt_prompt ]] && ble/array#push opts -p "$opt_prompt"
    [[ $opt_timeout ]] && ble/array#push opts -t "$opt_timeout"
    __ble_args=("${opts[@]}" "${opts_in[@]}" -- "${vars[@]}")
    __ble_command='builtin read "${__ble_args[@]}"'
    return
  fi

  ble-decode/keymap/load read
  local result _ble_edit_read_context=$_ble_term_state

  # Note: サブシェル中で重複して出力されない様に空にしておく
  ble/util/buffer.flush >&2

  [[ $_ble_edit_read_context == external ]] && ble/term/enter # 外側にいたら入る
  result=$(ble-edit/read/.loop); local ext=$?
  [[ $_ble_edit_read_context == external ]] && ble/term/leave # 元の状態に戻る

  # Note: サブシェルを抜ける時に set-height 1 0 するので辻褄合わせ。
  [[ $_ble_edit_read_context == internal ]] && ((_ble_form_window_height[2]=0))

  if ((ext==0)); then
    builtin eval -- "$result"
    __ble_args=("${opts[@]}" -- "${vars[@]}")
    __ble_command='builtin read "${__ble_args[@]}" <<< "$__ble_input"'
  fi
  return "$ext"
}

## 関数 read [-ers] [-adinNptu arg] [name...]
##
##   ble.sh の所為で builtin read -e が全く動かなくなるので、
##   read -e を ble.sh の枠組みで再実装する。
##
function read {
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin read "$@"
    return
  fi

  local __ble_command= __ble_args= __ble_input=
  ble-edit/read/.impl "$@"; local __ble_ext=$?
  [[ $__ble_command ]] || return "$__ble_ext"

  # 局所変数により被覆されないように外側で評価
  builtin eval -- "$__ble_command"
  return
}

# 
#------------------------------------------------------------------------------
# **** completion ****                                                    @comp

: ${bleopt_complete_stdin_frequency:=50}
ble-autoload "$_ble_base/lib/core-complete.sh" ble/widget/complete
ble/util/isfunction ble/util/idle.push &&
  ble/util/idle.push 'ble-import "$_ble_base/lib/core-complete.sh"'

#------------------------------------------------------------------------------
# **** command-help ****                                          @command-help

## 設定関数 ble/cmdinfo/help
## 設定関数 ble/cmdinfo/help:$command
##
##   ヘルプを表示するシェル関数を定義します。
##   ble/widget/command-help から呼び出されます。
##   ble/cmdinfo/help:$command はコマンド $command に対するヘルプ表示で使われます。
##   ble/cmdinfo/help はその他のコマンドに対するヘルプ表示で使われます。
##
##   @var[in] command
##   @var[in] type
##     コマンド名と種類 (type -t によって得られるもの) を指定します。
##
##   @var[in] comp_line comp_point comp_words comp_cword
##     現在のコマンドラインと位置、コマンド名・引数と現在の引数番号を指定します。
##
##   @exit[out]
##     ヘルプの終了が完了したときに 0 を返します。
##     それ以外の時は 0 以外を返します。
##

## 関数 ble/widget/command-help/.read-man
##   @var[out] man_content
function ble/widget/command-help/.read-man {
  local -x _ble_local_tmpfile; ble/util/assign/.mktmp
  local pager="sh -c 'cat >| \"\$_ble_local_tmpfile\"'"
  MANPAGER=$pager PAGER=$pager MANOPT= man "$@" 2>/dev/null; local ext=$? # 668ms
  ble/util/readfile man_content "$_ble_local_tmpfile" # 80ms
  ble/util/assign/.rmtmp
  return "$ext"
}

function ble/widget/command-help/.locate-in-man-bash {
  local command=$1
  local ret rex
  local rex_esc=$'(\e\\[[ -?]*[@-~]||.\b)' cr=$'\r'

  # check if pager is less
  local pager; ble/util/get-pager pager
  local pager_cmd=${pager%%[$' \t\n']*}
  [[ ${pager_cmd##*/} == less ]] || return 1

  # awk/gawk
  local awk=awk; type -t gawk &>/dev/null && awk=gawk

  # man bash
  local man_content; ble/widget/command-help/.read-man bash || return 1 # 733ms (3 fork: man, sh, cat)

  # locate line number
  local cmd_awk
  case $command in
  ('function')  cmd_awk='name () compound-command' ;;
  ('until')     cmd_awk=while ;;
  ('command')   cmd_awk='command [' ;;
  ('source')    cmd_awk=. ;;
  ('typeset')   cmd_awk=declare ;;
  ('readarray') cmd_awk=mapfile ;;
  ('[')         cmd_awk=test ;;
  (*)           cmd_awk=$command ;;
  esac
  ble/string#escape-for-awk-regex "$cmd_awk"; local rex_awk=$ret
  rex='\b$'; [[ $awk == gawk && $cmd_awk =~ $rex ]] && rex_awk=$rex_awk'\y'
  local awk_script='{
    gsub(/'"$rex_esc"'/, "");
    if (!par && $0 ~ /^[[:space:]]*'"$rex_awk"'/) { print NR; exit; }
    par = !($0 ~ /^[[:space:]]*$/);
  }'
  local awk_out; ble/util/assign awk_out '"$awk" "$awk_script" 2>/dev/null <<< "$man_content"' || return 1 # 206ms (1 fork)
  local iline=${awk_out%$'\n'}; [[ $iline ]] || return 1

  # show
  ble/string#escape-for-extended-regex "$command"; local rex_ext=$ret
  rex='\b$'; [[ $command =~ $rex ]] && rex_ext=$rex_ext'\b'
  rex='^\b'; [[ $command =~ $rex ]] && rex_ext="($rex_esc|\b)$rex_ext"
  local manpager="$pager -r +'/$rex_ext$cr$((iline-1))g'"
  eval "$manpager" <<< "$man_content" # 1 fork
}
## 関数 ble/widget/command-help.core
##   @var[in] type
##   @var[in] command
##   @var[in] comp_cword comp_words comp_line comp_point
function ble/widget/command-help.core {
  ble/util/isfunction ble/cmdinfo/help:"$command" &&
    ble/cmdinfo/help:"$command" && return
  ble/util/isfunction ble/cmdinfo/help &&
    ble/cmdinfo/help "$command" && return

  if [[ $type == builtin || $type == keyword ]]; then
    # 組み込みコマンド・キーワードは man bash を表示
    ble/widget/command-help/.locate-in-man-bash "$command" && return
  elif [[ $type == function ]]; then
    # シェル関数は定義を表示
    local pager=ble/util/pager
    type -t source-highlight &>/dev/null &&
      pager='source-highlight -s sh -f esc | '$pager
    local def; ble/function#getdef "$command"
    LESS="$LESS -r" builtin eval -- "$pager" <<< "$def" && return
  fi

  if ble/util/isfunction ble/bin/man; then
    MANOPT= ble/bin/man "${command##*/}" 2>/dev/null && return
    # Note: $(man "${command##*/}") と (特に日本語で) 正しい結果が得られない。
    # if local content=$(MANOPT= ble/bin/man "${command##*/}" 2>&1) && [[ $content ]]; then
    #   builtin printf '%s\n' "$content" | ble/util/pager
    #   return
    # fi
  fi

  if local content; content=$("$command" --help 2>&1) && [[ $content ]]; then
    builtin printf '%s\n' "$content" | ble/util/pager
    return 0
  fi

  echo "ble: help of \`$command' not found" >&2
  return 1
}

## 関数 ble/widget/command-help/type.resolve-alias
##   サブシェルで実行してエイリアスを解決する。
##   解決のために unalias を使用する為にサブシェルで実行する。
##
##   @stdout type:command
##     command はエイリアスを解決した後の最終的なコマンド
##     type はそのコマンドの種類
##     解決に失敗した時は何も出力しない。
##
function ble/widget/command-help/.type/.resolve-alias {
  local literal=$1 command=$2 type=alias
  local last_literal=$1 last_command=$2

  while
    [[ $command == "$literal" ]] || break # Note: type=alias

    local alias_def
    ble/util/assign alias_def "alias $command"
    unalias "$command"
    eval "alias_def=${alias_def#*=}" # remove quote
    literal=${alias_def%%[$' \t\n']*} command= type=
    ble-syntax:bash/simple-word/is-simple "$literal" || break # Note: type=
    eval "command=$literal"
    ble/util/type type "$command"
    [[ $type ]] || break # Note: type=

    last_literal=$literal
    last_command=$command
    [[ $type == alias ]]
  do :; done

  if [[ ! $type || $type == alias ]]; then
    # - command はエイリアスに一致するが literal では quote されている時、
    #   type=alias の状態でループを抜ける。
    # - 途中で複雑なコマンドに展開された時、必ずしも先頭の単語がコマンド名ではない。
    #   例: alias which='(alias; declare -f) | /usr/bin/which ...'
    #   この時途中で type= になってループを抜ける。
    #
    # これらの時、直前の成功した command 名で非エイリアス名を探す。
    literal=$last_literal
    command=$last_command
    unalias "$command" &>/dev/null
    ble/util/type type "$command"
  fi

  local q="'" Q="'\''"
  printf "type='%s'\n" "${type//$q/$Q}"
  printf "literal='%s'\n" "${literal//$q/$Q}"
  printf "command='%s'\n" "${command//$q/$Q}"
  return
}

function ble/widget/command-help/.type {
  local literal=$1
  type= command=
  ble-syntax:bash/simple-word/is-simple "$literal" || return 1
  eval "command=$literal"
  ble/util/type type "$command"

  # alias の時はサブシェルで解決
  if [[ $type == alias ]]; then
    eval "$(ble/widget/command-help/.type/.resolve-alias "$literal" "$command")"
  fi

  if [[ $type == keyword && $command != "$literal" ]]; then
    if [[ $command == %* ]] && jobs -- "$command" &>/dev/null; then
      type=jobs
    elif ble/util/isfunction "$command"; then
      type=function
    elif enable -p | ble/bin/grep -q -F -x "enable $cmd" &>/dev/null; then
      type=builtin
    elif type -P -- "$cmd" &>/dev/null; then
      type=file
    else
      type=
      return 1
    fi
  fi
}

function ble/widget/command-help.impl {
  local literal=$1
  if [[ ! $literal ]]; then
    ble/widget/.bell
    return 1
  fi

  local type command; ble/widget/command-help/.type "$literal"
  if [[ ! $type ]]; then
    ble/widget/.bell "command \`$command' not found"
    return 1
  fi

  ble-edit/info/hide
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble-form/panel#set-height.draw "$_ble_textarea_panel" 0
  ble-form/panel#goto.draw "$_ble_textarea_panel" 0 0
  ble-edit/draw/bflush
  ble/term/leave
  ble/util/buffer.flush >&2
  ble/widget/command-help.core; local ext=$?
  ble/term/enter
  return "$ext"
}

function ble/widget/command-help {
  # ToDo: syntax update?
  ble-edit/content/clear-arg
  local comp_cword comp_words comp_line comp_point
  if ble-syntax:bash/extract-command "$_ble_edit_ind"; then
    local cmd=${comp_words[0]}
  else
    local args; ble/string#split-words args "$_ble_edit_str"
    local cmd=${args[0]}
  fi

  ble/widget/command-help.impl "$cmd"
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/bind ****                                                 @bind

function ble-edit/bind/stdout.on { :;}
function ble-edit/bind/stdout.off { ble/util/buffer.flush >&2;}
function ble-edit/bind/stdout.finalize { :;}

if [[ $bleopt_suppress_bash_output ]]; then
  _ble_edit_io_stdout=
  _ble_edit_io_stderr=
  if ((_ble_bash>40100)); then
    exec {_ble_edit_io_stdout}>&1
    exec {_ble_edit_io_stderr}>&2
  else
    ble/util/openat _ble_edit_io_stdout '>&1'
    ble/util/openat _ble_edit_io_stderr '>&2'
  fi
  _ble_edit_io_fname1=$_ble_base_run/$$.stdout
  _ble_edit_io_fname2=$_ble_base_run/$$.stderr

  function ble-edit/bind/stdout.on {
    exec 1>&$_ble_edit_io_stdout 2>&$_ble_edit_io_stderr
  }
  function ble-edit/bind/stdout.off {
    ble/util/buffer.flush >&2
    ble-edit/bind/stdout/check-stderr
    exec 1>>$_ble_edit_io_fname1 2>>$_ble_edit_io_fname2
  }
  function ble-edit/bind/stdout.finalize {
    ble-edit/bind/stdout.on
    [[ -f $_ble_edit_io_fname1 ]] && ble/bin/rm -f "$_ble_edit_io_fname1"
    [[ -f $_ble_edit_io_fname2 ]] && ble/bin/rm -f "$_ble_edit_io_fname2"
  }

  ## 関数 ble-edit/bind/stdout/check-stderr
  ##   bash が stderr にエラーを出力したかチェックし表示する。
  function ble-edit/bind/stdout/check-stderr {
    local file=${1:-$_ble_edit_io_fname2}

    # if the visible bell function is already defined.
    if ble/util/isfunction ble/term/visible-bell; then
      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   /dev/null の様なデバイスではなく、中身があるファイルの場合。
      if [[ -f $file && -s $file ]]; then
        local message= line
        while TMOUT= IFS= builtin read -r line || [[ $line ]]; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   例えば ~/bin/bash-3.1 等から実行していると
          #   "bash-3.1: ～" 等というエラーメッセージになる。
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* ]]; then
            message="$message${message:+; }$line"
          fi
        done < "$file"

        [[ $message ]] && ble/term/visible-bell "$message"
        : >| "$file"
      fi
    fi
  }

  # * bash-3.1, bash-3.2, bash-3.0 では C-d は直接検知できない。
  #   IGNOREEOF を設定しておくと C-d を押した時に
  #   stderr に bash が文句を吐くのでそれを捕まえて C-d が押されたと見做す。
  if ((_ble_bash<40000)); then
    function ble-edit/bind/stdout/TRAPUSR1 {
      [[ $_ble_term_state == internal ]] || return

      local IFS=$' \t\n'
      local file=$_ble_edit_io_fname2.proc
      if [[ -s $file ]]; then
        local content cmd
        ble/util/readfile content "$file"
        : >| "$file"
        for cmd in $content; do
          case "$cmd" in
          (eof)
            # C-d
            ble-decode/.hook 4
            builtin eval "$_ble_decode_bind_hook" ;;
          esac
        done
      fi
    }

    trap -- 'ble-edit/bind/stdout/TRAPUSR1' USR1

    ble/bin/rm -f "$_ble_edit_io_fname2.pipe"
    ble/bin/mkfifo "$_ble_edit_io_fname2.pipe"
    {
      {
        function ble-edit/stdout/check-ignoreeof-message {
          local line=$1

          [[ $line = *$bleopt_ignoreeof_message* ||
               $line = *'Use "exit" to leave the shell.'* ||
               $line = *'ログアウトする為には exit を入力して下さい'* ||
               $line = *'シェルから脱出するには "exit" を使用してください。'* ||
               $line = *'シェルから脱出するのに "exit" を使いなさい.'* ||
               $line = *'Gebruik Kaart na Los Tronk'* ]] && return 0

          # ignoreeof-messages.txt の中身をキャッシュする様にする?
          [[ $line == *exit* ]] && ble/bin/grep -q -F "$line" "$_ble_base"/ignoreeof-messages.txt
        }

        while TMOUT= IFS= builtin read -r line; do
          SPACE=$' \n\t'
          if [[ $line == *[^$SPACE]* ]]; then
            builtin printf '%s\n' "$line" >> "$_ble_edit_io_fname2"
          fi

          if [[ $bleopt_ignoreeof_message ]] && ble-edit/stdout/check-ignoreeof-message "$line"; then
            builtin echo eof >> "$_ble_edit_io_fname2.proc"
            kill -USR1 $$
            ble/util/sleep 0.1 # 連続で送ると bash が落ちるかも (落ちた事はないが念の為)
          fi
        done < "$_ble_edit_io_fname2.pipe"
      } &>/dev/null & disown
    } &>/dev/null

    ble/util/openat _ble_edit_fd_stderr_pipe '> "$_ble_edit_io_fname2.pipe"'

    function ble-edit/bind/stdout.off {
      ble/util/buffer.flush >&2
      ble-edit/bind/stdout/check-stderr
      exec 1>>$_ble_edit_io_fname1 2>&$_ble_edit_fd_stderr_pipe
    }
  fi
fi

_ble_edit_detach_flag=
function ble-edit/bind/.exit-TRAPRTMAX {
  # シグナルハンドラの中では stty は bash によって設定されている。
  local IFS=$' \t\n'
  ble/term/TRAPEXIT
  exit 0
}

## 関数 ble-edit/bind/.check-detach
##
##   @exit detach した場合に 0 を返します。それ以外の場合に 1 を返します。
##
function ble-edit/bind/.check-detach {
  if [[ ! -o emacs && ! -o vi ]]; then
    # 実は set +o emacs などとした時点で eval の評価が中断されるので、これを検知することはできない。
    # 従って、現状ではここに入ってくることはないようである。
    builtin echo "${_ble_term_setaf[9]}[ble: unsupported]$_ble_term_sgr0 Sorry, ble.sh is supported only with some editing mode (set -o emacs/vi)." 1>&2
    ble-detach
  fi

  if [[ $_ble_edit_detach_flag ]]; then
    type=$_ble_edit_detach_flag
    _ble_edit_detach_flag=
    #ble/term/visible-bell ' Bye!! '

    ble-edit-finalize
    ble-decode-detach

    READLINE_LINE='' READLINE_POINT=0

    if [[ $type == exit ]]; then
      # ※この部分は現在使われていない。
      #   exit 時の処理は trap EXIT を用いて行う事に決めた為。
      #   一応 _ble_edit_detach_flag=exit と直に入力する事で呼び出す事はできる。

      # exit
      ble/util/buffer.flush >&2
      builtin echo "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0" 1>&2
      ble-edit/info/hide
      ble/textarea#render
      ble/util/buffer.flush >&2

      # bind -x の中から exit すると bash が stty を「前回の状態」に復元してしまう様だ。
      # シグナルハンドラの中から exit すれば stty がそのままの状態で抜けられる様なのでそうする。
      trap 'ble-edit/bind/.exit-TRAPRTMAX' RTMAX
      kill -RTMAX $$
    else
      ble/util/buffer.flush >&2
      builtin echo "${_ble_term_setaf[12]}[ble: detached]$_ble_term_sgr0" 1>&2
      builtin echo "Please run \`stty sane' to recover the correct TTY state." >&2
      ble/textarea#render
      ble/util/buffer.flush >&2
      if ((_ble_bash>=40000)); then
        READLINE_LINE=' stty sane;' READLINE_POINT=11
        printf %s "$READLINE_LINE"
      fi
    fi

    return 0
  else
    # Note: ここに入った時 -o emacs か -o vi のどちらかが成立する。なぜなら、
    #   [[ ! -o emacs && ! -o vi ]] のときは ble-detach が呼び出されるのでここには来ない。
    local state=$_ble_decode_bind_state
    if [[ ( $state == emacs || $state == vi ) && ! -o $state ]]; then
      ble-decode/reset-default-keymap
      ble-decode-detach
      if ! ble-decode-attach; then
        ble-detach
        ble-edit/bind/.check-detach # 改めて終了処理
        return "$?"
      fi
    fi

    return 1
  fi
}

if ((_ble_bash>=40100)); then
  function ble-edit/bind/.head/adjust-bash-rendering {
    # bash-4.1 以降では呼出直前にプロンプトが消される
    ble/textarea#redraw-cache
    ble/util/buffer.flush >&2
  }
else
  function ble-edit/bind/.head/adjust-bash-rendering {
    # bash-3.*, bash-4.0 では呼出直前に次の行に移動する
    ((_ble_line_y++,_ble_line_x=0))
    local -a DRAW_BUFF=()
    ble-form/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble-edit/draw/flush
  }
fi

function ble-edit/bind/.head {
  ble-edit/bind/stdout.on

  [[ $bleopt_suppress_bash_output ]] ||
    ble-edit/bind/.head/adjust-bash-rendering
}

function ble-edit/bind/.tail-without-draw {
  ble-edit/bind/stdout.off
}

if ((_ble_bash>=40000)); then
  function ble-edit/bind/.tail {
    ble-edit/info/reveal
    ble/textarea#render
    ble/util/idle.do && ble/textarea#render
    ble/textarea#adjust-for-bash-bind # bash-4.0+
    ble-edit/bind/stdout.off
  }
else
  IGNOREEOF=10000
  function ble-edit/bind/.tail {
    ble-edit/info/reveal
    ble/textarea#render # bash-3 では READLINE_LINE を設定する方法はないので常に 0 幅
    ble/util/idle.do && ble/textarea#render # bash-4.0+
    ble-edit/bind/stdout.off
  }
fi

_ble_edit_bind_force_draw=

## ble-decode.sh 用の設定
function ble-decode/PROLOGUE {
  ble-edit/bind/.head
  ble-decode-bind/uvw
  ble/term/enter
  _ble_edit_bind_force_draw=
}

## ble-decode.sh 用の設定
function ble-decode/EPILOGUE {
  if ((_ble_bash>=40000)); then
    # 貼付対策:
    #   大量の文字が入力された時に毎回再描画をすると滅茶苦茶遅い。
    #   次の文字が既に来て居る場合には描画処理をせずに抜ける。
    #   (再描画は次の文字に対する bind 呼出でされる筈。)
    if [[ ! $_ble_edit_bind_force_draw ]] && ble/util/is-stdin-ready && ! ble-edit/exec/has-pending-commands; then
      ble-edit/bind/.tail-without-draw
      return 0
    fi
  fi

  # _ble_decode_bind_hook で bind/tail される。
  ble-edit/exec:"$bleopt_exec_type"/process && return 0

  ble-edit/bind/.tail
  return 0
}

## 関数 ble/widget/.SHELL_COMMAND command
##   ble-bind -cf で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND {
  ble-edit/content/clear-arg

  local _ble_local_command=$1

  _ble_edit_line_disabled=1 ble/widget/.insert-newline

  # Note: 空コマンドでも .insert-newline は実行する。
  [[ ${_ble_local_command//[$_ble_term_IFS]} ]] || return 1

  # やはり通常コマンドはちゃんとした環境で評価するべき
  ble-edit/exec/register "$_ble_local_command"
}

## 関数 ble/widget/.EDIT_COMMAND command
##   ble-bind -xf で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND {
  local command=$1
  local READLINE_LINE=$_ble_edit_str
  local READLINE_POINT=$_ble_edit_ind
  eval "$command" || return 1
  ble-edit/content/clear-arg

  [[ $READLINE_LINE != "$_ble_edit_str" ]] &&
    _ble_edit_str.reset-and-check-dirty "$READLINE_LINE"
  ((_ble_edit_ind=READLINE_POINT))

  local N=${#_ble_edit_str}
  ((_ble_edit_ind<0?_ble_edit_ind=0:(_ble_edit_ind>N&&(_ble_edit_ind=N))))
}

## ble-decode.sh 用の設定
function ble-decode/DEFAULT_KEYMAP {
  if [[ $bleopt_default_keymap == auto ]]; then
    if [[ -o vi ]]; then
      ble-edit/bind/load-keymap-definition vi &&
        builtin eval -- "$2=vi_imap"
    else
      ble-edit/bind/load-keymap-definition emacs &&
        builtin eval -- "$2=emacs"
    fi
  elif [[ $bleopt_default_keymap == vi ]]; then
    ble-edit/bind/load-keymap-definition vi &&
      builtin eval -- "$2=vi_imap"
  else
    ble-edit/bind/load-keymap-definition "$bleopt_default_keymap" &&
      builtin eval -- "$2=\"\$bleopt_default_keymap\""
  fi; local ext=$?

  if ((ext==0)) && ble-decode/keymap/is-keymap "${!2}"; then
    return 0
  fi

  echo "ble.sh: The definition of the default keymap \"$bleopt_default_keymap\" is not found. ble.sh uses \"safe\" keymap instead."
  ble-edit/bind/load-keymap-definition safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

function ble-edit/bind/load-keymap-definition {
  local name=$1
  if ble/util/isfunction ble-edit/bind/load-keymap-definition:"$name"; then
    ble-edit/bind/load-keymap-definition:"$name"
  else
    source "$_ble_base/keymap/$name.sh"
  fi
}

#------------------------------------------------------------------------------
# **** entry points ****

function ble-edit-initialize {
  ble-edit/prompt/initialize
}
function ble-edit-attach {
  ble-edit/attach
  _ble_line_x=0 _ble_line_y=0
  ble/util/buffer "$_ble_term_cr"
}
function ble-edit/reset-history {
  if ((_ble_bash>=40000)); then
    _ble_edit_history_loaded=
    ble-edit/history/clear-background-load
    ble/util/idle.push 'ble-edit/history/load async'
  elif ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
    _ble_edit_history_loaded=
  else
    # * history-load は initialize ではなく attach で行う。
    #   detach してから attach する間に
    #   追加されたエントリがあるかもしれないので。
    # * bash-3.0 では history -s は最近の履歴項目を置換するだけなので、
    #   履歴項目は全て自分で処理する必要がある。
    #   つまり、初めから load しておかなければならない。
    ble-edit/history/load
  fi
}
function ble-edit-finalize {
  ble-edit/bind/stdout.finalize
  ble-edit/detach
}
