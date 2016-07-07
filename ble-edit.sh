#!/bin/bash

# **** sections ****
#
# @text.c2w
# @line.pos
# @line.ps1
# @line.text
# @line.info
# @edit
# @edit.ps1
# @edit.draw
# @edit.bell
# @edit.delete
# @edit.insert
# @edit.cursor
# @edit.accept
# @edit.mark
# @history
# @history.isearch
# @comp
# @bind
# @bind.bind

## オプション bleopt_char_width_mode
##   文字の表示幅の計算方法を指定します。
## bleopt_char_width_mode=east
##   Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 2 とします
## bleopt_char_width_mode=west
##   Unicode East_Asian_Width=A (Ambiguous) の文字幅を全て 1 とします
## bleopt_char_width_mode=emacs
##   emacs で用いられている既定の文字幅の設定です
## 定義 ble/util/c2w+$bleopt_char_width_mode
: ${bleopt_char_width_mode:=east}

## オプション bleopt_edit_vbell
##   編集時の visible bell の有効・無効を設定します。
## bleopt_edit_vbell=1
##   有効です。
## bleopt_edit_vbell=
##   無効です。
: ${bleopt_edit_vbell=}

## オプション bleopt_edit_abell
##   編集時の audible bell (BEL 文字出力) の有効・無効を設定します。
## bleopt_edit_abell=1
##   有効です。
## bleopt_edit_abell=
##   無効です。
: ${bleopt_edit_abell=1}

## オプション bleopt_history_lazyload
## bleopt_history_lazyload=1
##   ble-attach 後、初めて必要になった時に履歴の読込を行います。
## bleopt_history_lazyload=
##   ble-attach 時に履歴の読込を行います。
##
## bash-3.1 未満では history -s が思い通りに動作しないので、
## このオプションの値に関係なく ble-attach の時に履歴の読み込みを行います。
: ${bleopt_history_lazyload=1}

## オプション bleopt_exec_type (内部使用)
##   コマンドの実行の方法を指定します。
## bleopt_exec_type=exec
##   関数内で実行します (従来の方法です。将来的に削除されます)
## bleopt_exec_type=gexec
##   グローバルな文脈で実行します (新しい方法です。現在テスト中です)
## 要件: 関数 ble-edit/exec:$bleopt_exec_type/process
: ${bleopt_exec_type:=gexec}

## オプション bleopt_suppress_bash_output (内部使用)
##   bash 自体の出力を抑制するかどうかを指定します。
## bleopt_suppress_bash_output=1
##   抑制します。bash のエラーメッセージは visible-bell で表示します。
## bleopt_suppress_bash_output=
##   抑制しません。bash のメッセージは全て端末に出力されます。
##   これはデバグ用の設定です。bash の出力を制御するためにちらつきが発生する事があります。
##   bash-3 ではこの設定では C-d を捕捉できません。
: ${bleopt_suppress_bash_output=1}

## オプション bleopt_ignoreeof_message (内部使用)
##   bash-3.0 の時に使用します。C-d を捕捉するのに用いるメッセージです。
##   これは自分の bash の設定に合わせる必要があります。
: ${bleopt_ignoreeof_message:='Use "exit" to leave the shell.'}

# 
#------------------------------------------------------------------------------
# **** char width ****                                                @text.c2w

# ※注意 [ -~] の範囲の文字は全て幅1であるという事を仮定したコードが幾らかある
#   もしこれらの範囲の文字を幅1以外で表示する端末が有ればそれらのコードを実装し
#   直す必要がある。その様な変な端末があるとは思えないが。


declare -a _ble_text_c2w__table=()

## 関数 ble/util/c2w ccode
##   @var[out] ret
function ble/util/c2w {
  # ret="${_ble_text_c2w__table[$1]}"
  # [[ $ret ]] && return
  "ble/util/c2w+$bleopt_char_width_mode" "$1"
  # _ble_text_c2w__table[$1]="$ret"
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

## 関数 ble/util/c2w+emacs
##   emacs-24.2.1 default char-width-table
declare -a _ble_text_c2w__emacs_wranges=(
 162 164 167 169 172 173 176 178 180 181 182 183 215 216 247 248 272 273 276 279
 280 282 284 286 288 290 293 295 304 305 306 308 315 316 515 516 534 535 545 546
 555 556 608 618 656 660 722 723 724 725 768 769 770 772 775 777 779 780 785 787
 794 795 797 801 805 806 807 813 814 815 820 822 829 830 850 851 864 866 870 872
 874 876 898 900 902 904 933 934 959 960 1042 1043 1065 1067 1376 1396 1536 1540 1548 1549
 1551 1553 1555 1557 1559 1561 1563 1566 1568 1569 1571 1574 1576 1577 1579 1581 1583 1585 1587 1589
 1591 1593 1595 1597 1599 1600 1602 1603 1611 1612 1696 1698 1714 1716 1724 1726 1734 1736 1739 1740
 1742 1744 1775 1776 1797 1799 1856 1857 1858 1859 1898 1899 1901 1902 1903 1904)
function ble/util/c2w+emacs {
  local code="$1" al=0 ah=0 tIndex=

  # bash-4.0 bug workaround
  #   中で使用している変数に日本語などの文字列が入っているとエラーになる。
  #   その値を参照していなくても、その分岐に入らなくても関係ない。
  #   なので ret に予め適当な値を設定しておく事にする。
  ret=1

  (('
    code<0xA0?(
      ret=1
    ):(0x3100<=code&&code<0xA4D0||0xAC00<=code&&code<0xD7A4?(
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
    )))
  '))

  [[ $tIndex ]] || return 0

  local tIndex="$1"
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
function ble/util/c2w.ambiguous {
  local code="$1"
  ret=1
  (('
    (code<0xA0)?(
      ret=1
    ):((
      (code<0xFB00)?(
        0x2E80<=code&&code<0xA4D0&&code!=0x303F||
        0xAC00<=code&&code<0xD7A4||
        0xF900<=code||
        0x1100<=code&&code<0x1160||
        code==0x2329||code==0x232A
      ):(code<0x10000?(
        0xFF00<=code&&code<0xFF61||
        0xFE30<=code&&code<0xFE70||
        0xFFE0<=code&&code<0xFFE7
      ):(
        0x20000<=code&&code<0x2FFFE||
        0x30000<=code&&code<0x3FFFE
      ))
    )?(
      ret=2
    ):(
      ret=-1
    ))
  '))
}
function ble/util/c2w+west {
  ble/util/c2w.ambiguous "$1"
  (((ret<0)&&(ret=1)))
}

## 関数 ble/util/c2w+east
declare -a _ble_text_c2w__east_wranges=(
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
  ble/util/c2w.ambiguous "$1"
  ((ret>=0)) && return

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
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$*"
}
function ble-edit/draw/put.il {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_il//'%d'/$value}"
}
function ble-edit/draw/put.dl {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_dl//'%d'/$value}"
}
function ble-edit/draw/put.cuu {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_cuu//'%d'/$value}"
}
function ble-edit/draw/put.cud {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_cud//'%d'/$value}"
}
function ble-edit/draw/put.cuf {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_cuf//'%d'/$value}"
}
function ble-edit/draw/put.cub {
  local -i value="${1-1}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="${_ble_term_cub//'%d'/$value}"
}
function ble-edit/draw/put.cup {
  local -i l="${1-1}" c="${2-1}"
  local out="$_ble_term_cup"
  out="${out//'%l'/$l}"
  out="${out//'%c'/$c}"
  out="${out//'%y'/$((l-1))}"
  out="${out//'%x'/$((c-1))}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$out"
}
function ble-edit/draw/put.hpa {
  local -i c="${1-1}"
  local out="$_ble_term_hpa"
  out="${out//'%c'/$c}"
  out="${out//'%x'/$((c-1))}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$out"
}
function ble-edit/draw/put.vpa {
  local -i l="${1-1}"
  local out="$_ble_term_vpa"
  out="${out//'%l'/$l}"
  out="${out//'%y'/$((l-1))}"
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$out"
}
function ble-edit/draw/flush {
  IFS= builtin eval 'builtin echo -n "${DRAW_BUFF[*]}"'
  DRAW_BUFF=()
}
function ble-edit/draw/sflush {
  local _var=ret
  [[ $1 == -v ]] && _var="$2"
  IFS= builtin eval "$_var=\"\${DRAW_BUFF[*]}\""
  DRAW_BUFF=()
}

_ble_draw_trace_brack=()
_ble_draw_trace_scosc=
function ble-edit/draw/trace/SC {
  _ble_draw_trace_scosc="$x $y $g $lc $lg"
  ble-edit/draw/put "$_ble_term_sc"
}
function ble-edit/draw/trace/RC {
  local -a scosc
  scosc=($_ble_draw_trace_scosc)
  x="${scosc[0]}"
  y="${scosc[1]}"
  g="${scosc[2]}"
  lc="${scosc[3]}"
  lg="${scosc[4]}"
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
    _var="$2"
    shift 2
  fi

  if ((j<${#f[*]})); then
    _ret="${f[j++]}"
  else
    ((i++))
    _ret="${specs[i]%%:*}"
  fi

  (($_var=_ret))
}
function ble-edit/draw/trace/SGR {
  local param="$1" seq="$2" specs i iN
  IFS=\; builtin eval 'specs=($param)'
  if ((${#specs[*]}==0)); then
    g=0
    ble-edit/draw/put "$_ble_term_sgr0"
    return
  fi

  for ((i=0,iN=${#specs[@]};i<iN;i++)); do
    local spec="${specs[i]}" f
    IFS=: builtin eval 'f=($spec)'
    if ((30<=f[0]&&f[0]<50)); then
      # colors
      if ((30<=f[0]&&f[0]<38)); then
        local color="$((f[0]-30))"
        ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
      elif ((40<=f[0]&&f[0]<48)); then
        local color="$((f[0]-40))"
        ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
      elif ((f[0]==38)); then
        local j=1 color cspace
        ble-edit/draw/trace/SGR/arg_next -v cspace
        if ((cspace==5)); then
          ble-edit/draw/trace/SGR/arg_next -v color
          ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
        fi
      elif ((f[0]==48)); then
        local j=1 color cspace
        ble-edit/draw/trace/SGR/arg_next -v cspace
        if ((cspace==5)); then
          ble-edit/draw/trace/SGR/arg_next -v color
          ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
        fi
      elif ((f[0]==39)); then
        ((g&=~(_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor)))
      elif ((f[0]==49)); then
        ((g&=~(_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor)))
      fi
    elif ((90<=f[0]&&f[0]<98)); then
      local color="$((f[0]-90+8))"
      ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
    elif ((100<=f[0]&&f[0]<108)); then
      local color="$((f[0]-100+8))"
      ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
    elif ((f[0]==0)); then
      g=0
    elif ((f[0]==1)); then
      ((g|=_ble_color_gflags_Bold))
    elif ((f[0]==22)); then
      ((g&=~_ble_color_gflags_Bold))
    elif ((f[0]==4)); then
      ((g|=_ble_color_gflags_Underline))
    elif ((f[0]==24)); then
      ((g&=~_ble_color_gflags_Underline))
    elif ((f[0]==7)); then
      ((g|=_ble_color_gflags_Revert))
    elif ((f[0]==27)); then
      ((g&=~_ble_color_gflags_Revert))
    elif ((f[0]==3)); then
      ((g|=_ble_color_gflags_Italic))
    elif ((f[0]==23)); then
      ((g&=~_ble_color_gflags_Italic))
    elif ((f[0]==5)); then
      ((g|=_ble_color_gflags_Blink))
    elif ((f[0]==25)); then
      ((g&=~_ble_color_gflags_Blink))
    elif ((f[0]==8)); then
      ((g|=_ble_color_gflags_Invisible))
    elif ((f[0]==28)); then
      ((g&=~_ble_color_gflags_Invisible))
    elif ((f[0]==9)); then
      ((g|=_ble_color_gflags_Strike))
    elif ((f[0]==29)); then
      ((g&=~_ble_color_gflags_Strike))
    fi
  done

  ble-color-g2sgr -v seq "$g"
  ble-edit/draw/put "$seq"
}
function ble-edit/draw/trace/process-csi-sequence {
  local seq="$1" seq1="${1:2}" rex
  local char="${seq1:${#seq1}-1:1}" param="${seq1::${#seq1}-1}"
  if [[ ! ${param//[0-9:;]/} ]]; then
    # CSI 数字引数 + 文字
    case "$char" in
    (m) # SGR
      ble-edit/draw/trace/SGR "$param" "$seq"
      return ;;
    ([ABCDEFGIZ\`ade])
      local arg=0
      [[ $param =~ ^[0-9]+$ ]] && arg="$param"
      ((arg==0&&(arg=1)))

      local x0="$x" y0="$y"
      if [[ $char == A ]]; then
        # CUU "CSI A"
        ((y-=arg,y<0&&(y=0)))
        ((y<y0)) && ble-edit/draw/put.cuu "$((y0-y))"
      elif [[ $char == [Be] ]]; then
        # CUD "CSI B"
        # VPR "CSI e"
        ((y+=arg,y>=lines&&(y=lines-1)))
        ((y>y0)) && ble-edit/draw/put.cud "$((y-y0))"
      elif [[ $char == [Ca] ]]; then
        # CUF "CSI C"
        # HPR "CSI a"
        ((x+=arg,x>=cols&&(x=cols-1)))
        ((x>x0)) && ble-edit/draw/put.cuf "$((x-x0))"
      elif [[ $char == D ]]; then
        # CUB "CSI D"
        ((x-=arg,x<0&&(x=0)))
        ((x<x0)) && ble-edit/draw/put.cub "$((x0-x))"
      elif [[ $char == E ]]; then
        # CNL "CSI E"
        ((y+=arg,y>=lines&&(y=lines-1),x=0))
        ((y>y0)) && ble-edit/draw/put.cud "$((y-y0))"
        ble-edit/draw/put "$_ble_term_cr"
      elif [[ $char == F ]]; then
        # CPL "CSI F"
        ((y-=arg,y<0&&(y=0),x=0))
        ((y<y0)) && ble-edit/draw/put.cuu "$((y0-y))"
        ble-edit/draw/put "$_ble_term_cr"
      elif [[ $char == [G\`] ]]; then
        # CHA "CSI G"
        # HPA "CSI `"
        ((x=arg-1,x<0&&(x=0),x>=cols&&(x=cols-1)))
        ble-edit/draw/put.hpa "$((x+1))"
      elif [[ $char == d ]]; then
        # VPA "CSI d"
        ((y=arg-1,y<0&&(y=0),y>=lines&&(y=lines-1)))
        ble-edit/draw/put.vpa "$((y+1))"
      elif [[ $char == I ]]; then
        # CHT "CSI I"
        local _x
        ((_x=(x/it+arg)*it,
          _x>=cols&&(_x=cols-1)))
        if ((_x>x)); then
          ble-edit/draw/put.cuf "$((_x-x))"
          ((x=_x))
        fi
      elif [[ $char == Z ]]; then
        # CHB "CSI Z"
        local _x
        ((_x=((x+it-1)/it-arg)*it,
          _x<0&&(_x=0)))
        if ((_x<x)); then
          ble-edit/draw/put.cub "$((x-_x))"
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
      ble-edit/draw/put.cup "$((y+1))" "$((x+1))"
      lc=-1 lg=0
      return ;;
    ([su]) # SCOSC SCORC
      if [[ $param == 99 ]]; then
        # PS1 の \[ ... \] の処理。
        # ble-edit/prompt/update で \e[99s, \e[99u に変換している。
        if [[ $char == s ]]; then
          _ble_draw_trace_brack[${#_ble_draw_trace_brack[*]}]="$x $y"
        else
          local lastIndex="${#_ble_draw_trace_brack[*]}-1"
          if ((lastIndex>=0)); then
            local -a scosc
            scosc=(${_ble_draw_trace_brack[lastIndex]})
            ((x=scosc[0]))
            ((y=scosc[1]))
            unset "_ble_draw_trace_brack[$lastIndex]"
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
  local seq="$1" char="${1:1}"
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
      ble-edit/draw/put.hpa "$((x+1))" # tput ind が唯の改行の時がある
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
##   @var[in,out] x y
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
  local cols="${COLUMNS-80}" lines="${LINES-25}"
  local it="$_ble_term_it" xenl="$_ble_term_xenl"
  local text="$1"

  # cygwin では LC_COLLATE=C にしないと
  # 正規表現の range expression が期待通りに動かない。
  # __ENCODING__:
  #   マルチバイト文字コードで escape seq と紛らわしいコードが含まれる可能性がある。
  #   多くの文字コードでは C0, C1 にあたるバイトコードを使わないので大丈夫と思われる。
  #   日本語と混ざった場合に問題が生じたらまたその時に考える。
  local LC_COLLATE=C

  # CSI
  local rex_csi='^\[[ -?]*[@-~]'
  # OSC, DCS, SOS, PM, APC Sequences + "GNU screen ESC k"
  local rex_osc='^([]PX^_k])([^]|+[^\])*(\\|||$)'
  # ISO-2022 関係 (3byte以上の物)
  local rex_2022='^[ -/]+[@-~]'
  # ESC ?
  local rex_esc='^[ -~]'

  local i=0 iN="${#text}"
  while ((i<iN)); do
    local tail="${text:i}"
    local w=0
    if [[ $tail == [-]* ]]; then
      local s="${tail::1}"
      ((i++))
      case "$s" in
      ('')
        if [[ $tail =~ $rex_osc ]]; then
          # 各種メッセージ (素通り)
          s="$BASH_REMATCH"
          [[ ${BASH_REMATCH[3]} ]] || s="$s\\" # 終端の追加
          ((i+=${#BASH_REMATCH}-1))
        elif [[ $tail =~ $rex_csi ]]; then
          # Control sequences
          s=
          ((i+=${#BASH_REMATCH}-1))
          ble-edit/draw/trace/process-csi-sequence "$BASH_REMATCH"
        elif [[ $tail =~ $rex_2022 ]]; then
          # ISO-2022 (素通り)
          s="$BASH_REMATCH"
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
          s="${_ble_util_string_prototype::_x-x}"
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
        s="$_ble_term_cr"
        ((x=0,lc=-1,lg=0)) ;;
      # その他の制御文字は  (BEL)  (FF) も含めてゼロ幅と解釈する
      esac
      [[ $s ]] && ble-edit/draw/put "$s"
    elif ble/util/isprint+ "$tail"; then
      w="${#BASH_REMATCH}"
      ble-edit/draw/put "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
      if [[ ! $bleopt_suppress_bash_output ]]; then
        ble-text.s2c -v lc "$BASH_REMATCH" "$((w-1))"
        lg="$g"
      fi
    else
      local w ret
      ble-text.s2c -v lc "$tail" 0
      ((lg=g))
      ble/util/c2w "$lc"
      w="$ret"
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
  _ble_edit_prompt__string_h="${HOSTNAME%%.*}"
  _ble_edit_prompt__string_H="${HOSTNAME}"

  # tty basename
  local tmp=$(tty 2>/dev/null)
  _ble_edit_prompt__string_l="${tmp##*/}"

  # command name
  _ble_edit_prompt__string_s="${0##*/}"

  # user
  _ble_edit_prompt__string_u="${USER}"

  # bash versions
  ble/util/sprintf _ble_edit_prompt__string_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  ble/util/sprintf _ble_edit_prompt__string_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if [[ $EUID -eq 0 ]]; then
    _ble_edit_prompt__string_root='#'
  else
    _ble_edit_prompt__string_root='$'
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
##   @var _ble_edit_prompt[7]    ps1esc
##     調整前の ps1out を格納します。ps1out の計算を省略する為に使用します。
_ble_edit_prompt=("" 0 0 0 32 0 "" "")

function _ble_edit_prompt.load {
  x="${_ble_edit_prompt[1]}"
  y="${_ble_edit_prompt[2]}"
  g="${_ble_edit_prompt[3]}"
  lc="${_ble_edit_prompt[4]}"
  lg="${_ble_edit_prompt[5]}"
  ret="${_ble_edit_prompt[6]}"
}

## 関数 ble-edit/prompt/update/append text
##   指定された文字列を "" 内に入れる為のエスケープをして出力します。
##   @param[in] text
##     エスケープされる文字列を指定します。
##   @var[out]  DRAW_BUFF[]
##     出力先の配列です。
function ble-edit/prompt/update/append {
  local text="$1" a b
  if [[ $text == *['$\"`']* ]]; then
    a='\' b='\\' text="${text//"$a"/$b}"
    a='$' b='\$' text="${text//"$a"/$b}"
    a='"' b='\"' text="${text//"$a"/$b}"
    a='`' b='\`' text="${text//"$a"/$b}"
  fi
  ble-edit/draw/put "$text"
}
function ble-edit/prompt/update/process-text {
  local text="$1" a b
  if [[ $text == *'"'* ]]; then
    a='"' b='\"' text="${text//"$a"/$b}"
  fi
  ble-edit/draw/put "$text"
}

## 関数 ble-edit/prompt/update/process-backslash
##   @var[in]     tail
##   @var[in.out] DRAW_BUFF
function ble-edit/prompt/update/process-backslash {
  ((i+=2))

  # \\ の次の文字
  local c="${tail:1:1}" pat='[]#!$\'
  if [[ ! ${pat##*"$c"*} ]]; then
    case "$c" in
    (\[) ble-edit/draw/put $'\e[99s' ;; # \[ \] は後処理の為、適当な識別用の文字列を出力する。
    (\]) ble-edit/draw/put $'\e[99u' ;;
    ('#') # コマンド番号 (本当は history に入らない物もある…)
      ble-edit/draw/put "$_ble_edit_CMD" ;;
    (\!) # 履歴番号
      local count
      ble-edit/history/getcount -v count
      ble-edit/draw/put "$count" ;;
    ('$') # # or $
      ble-edit/prompt/update/append "$_ble_edit_prompt__string_root" ;;
    (\\)
      # '\\' は '\' と出力された後に、更に "" 内で評価された時に次の文字をエスケープする。
      # 例えば '\\$' は一旦 '\$' となり、更に展開されて '$' となる。'\\\\' も同様に '\' になる。
      ble-edit/draw/put '\' ;;
    esac
  elif local handler="ble-edit/prompt/update/backslash:$c" && ble/util/isfunction "$handler"; then
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
    local seq="${BASH_REMATCH[0]}"
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
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_w"
}
function ble-edit/prompt/update/backslash:V { # = bash version %d.%d.%d
  ble-edit/prompt/update/append "$_ble_edit_prompt__string_V"
}
function ble-edit/prompt/update/backslash:w { # PWD
  ble-edit/prompt/update/append "$param_wd"
}
function ble-edit/prompt/update/backslash:W { # PWD短縮
  if [[ $PWD == / ]]; then
    ble-edit/prompt/update/append /
  else
    ble-edit/prompt/update/append "${param_wd##*/}"
  fi
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
  local ps1="${_ble_edit_PS1}"
  local version="$_ble_edit_LINENO"
  if [[ ${_ble_edit_prompt[0]} == "$version" ]]; then
    _ble_edit_prompt.load
    return
  fi

  if [[ $PROMPT_COMMAND ]]; then
    ble-edit/prompt/update/eval-prompt_command
  fi

  local param_wd=
  if [[ $PWD == "$HOME" || $PWD == "$HOME"/* ]]; then
    param_wd="~${PWD#$HOME}"
  else
    param_wd="$PWD"
  fi

  local cache_d cache_t cache_A cache_T cache_at cache_D cache_j

  # 1 特別な Escape \? を処理
  local i=0 iN="${#ps1}"
  local -a DRAW_BUFF
  local rex_letters='^[^\]+|\\$'
  while ((i<iN)); do
    local tail="${ps1:i}"
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
  builtin eval "ps1esc=\"$ps1esc\""
  if [[ $ps1esc == "${_ble_edit_prompt[7]}" ]]; then
    # 前回と同じ ps1esc の場合は計測処理は省略
    _ble_edit_prompt[0]="$version"
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
  ret="$ps1out"
  _ble_edit_prompt=("$version" "$x" "$y" "$g" "$lc" "$lg" "$ps1out" "$ps1esc")
}

# 
# **** text ****                                                     @line.text

# 廃止予定
declare -a _ble_region_highlight_table
: ${bleopt_syntax_highlight_mode=default}


## @var _ble_line_text_cache_pos[]
## @var _ble_line_text_cache_cs[]
##   編集文字列の各文字に対応する位置と表示文字列の配列です。
declare -a _ble_line_text_cache_pos=()
declare -a _ble_line_text_cache_cs=()

## @var _ble_line_text_cache_ichg[]
##   表示文字に変更のあった物の index の一覧です。
declare -a _ble_line_text_cache_ichg=()
_ble_line_text_cache_length=

## 関数 text x y; .ble-line-text/update/position; x y
##   @var[in    ] text
##   @var[in,out] x y
##   @var[in    ] BLELINE_RANGE_UPDATE[]
##   @var[   out] POS_UMIN POS_UMAX
##   @var[   out] _ble_line_text_cache_length
##   @var[   out] _ble_line_text_cache_pos[]
##   @var[   out] _ble_line_text_cache_cs[]
##   @var[   out] _ble_line_text_cache_ichg[]
function .ble-line-text/update/position {
  local dbeg dend dend0
  ((dbeg=BLELINE_RANGE_UPDATE[0]))
  ((dend=BLELINE_RANGE_UPDATE[1]))
  ((dend0=BLELINE_RANGE_UPDATE[2]))

  local iN="${#text}"
  ((_ble_line_text_cache_length=iN))

  # 初期位置 x y
  local _pos="$x $y"
  local -a pos
  if [[ ${_ble_line_text_cache_pos[0]} != "$_pos" ]]; then
    # 初期位置の変更がある場合は初めから計算し直し
    ((dbeg<0&&(dend=dend0=0),
      dbeg=0))
    _ble_line_text_cache_pos[0]="$_pos"
  else
    if ((dbeg<0)); then
      # 初期位置も内容も変更がない場合はOK
      pos=(${_ble_line_text_cache_pos[iN]})
      ((x=pos[0]))
      ((y=pos[1]))
      return
    elif ((dbeg>0)); then
      # 途中から計算を再開
      pos=(${_ble_line_text_cache_pos[dbeg]})
      ((x=pos[0]))
      ((y=pos[1]))
    fi
  fi

  local cols="${COLUMNS-80}" it="$_ble_term_it" xenl="$_ble_term_xenl"
  # local cols="80" it="$_ble_term_it" xenl="1"

#%if !release
  ble-assert '((dbeg<0||(dbeg<=dend&&dbeg<=dend0)))' "($dbeg $dend $dend0) <- (${BLELINE_RANGE_UPDATE[*]})"
#%end

  # shift cached data
  _ble_util_array_prototype.reserve "$iN"
  local -a old_pos old_ichg
  old_pos=("${_ble_line_text_cache_pos[@]:dend0:iN-dend+1}")
  old_ichg=("${_ble_line_text_cache_ichg[@]}")
  _ble_line_text_cache_pos=(
    "${_ble_line_text_cache_pos[@]::dbeg+1}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
    "${_ble_line_text_cache_pos[@]:dend0+1:iN-dend}")
  _ble_line_text_cache_cs=(
    "${_ble_line_text_cache_cs[@]::dbeg}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
    "${_ble_line_text_cache_cs[@]:dend0:iN-dend}")
  _ble_line_text_cache_ichg=()

  local i
  for ((i=dbeg;i<iN;)); do
    if ble/util/isprint+ "${text:i}"; then
      local w="${#BASH_REMATCH}"
      local n
      for ((n=i+w;i<n;i++)); do
        local cs="${text:i:1}"
        if (((++x==cols)&&(y++,x=0,xenl))); then
          cs="$cs$_ble_term_nl"
          ble/util/array-push _ble_line_text_cache_ichg "$i"
        fi
        _ble_line_text_cache_cs[i]="$cs"
        _ble_line_text_cache_pos[i+1]="$x $y 0"
      done
    else
      local ret
      ble/util/s2c "$text" "$i"
      local code="$ret"

      local w=0 cs= changed=0
      if ((code<32)); then
        if ((code==9)); then
          if ((x+1>=cols)); then
            cs=' '
            ((xenl)) && cs="$cs$_ble_term_nl"
            changed=1
            ((y++,x=0))
          else
            local x2
            ((x2=(x/it+1)*it,
              x2>=cols&&(x2=cols-1),
              w=x2-x,
              w!=it&&(changed=1)))
            cs="${_ble_util_string_prototype::w}"
          fi
        elif ((code==10)); then
          ((y++,x=0))
          cs="$_ble_term_el$_ble_term_nl"
        else
          ((w=2))
          ble/util/c2s "$((code+64))"
          cs="^$ret"
        fi
      elif ((code==127)); then
        w=2 cs="^?"
      elif ((128<=code&&code<160)); then
        ble/util/c2s "$((code-64))"
        w=4 cs="M-^$ret"
      else
        ble/util/c2w "$code"
        w="$ret" cs="${text:i:1}"
      fi

      local wrapping=0
      if ((w>0)); then
        if ((x<cols&&cols<x+w)); then
          ((xenl)) && cs="$_ble_term_nl$cs"
          cs="${_ble_util_string_prototype::cols-x}$cs"
          ((x=cols,changed=1,wrapping=1))
        fi

        ((x+=w))
        while ((x>cols)); do
          ((y++,x-=cols))
        done
        if ((x==cols)); then
          if ((xenl)); then
            cs="$cs$_ble_term_nl"
            changed=1
          fi
          ((y++,x=0))
        fi
      fi

      _ble_line_text_cache_cs[i]="$cs"
      ((changed)) && ble/util/array-push _ble_line_text_cache_ichg "$i"
      _ble_line_text_cache_pos[i+1]="$x $y $wrapping"
      ((i++))
    fi

    # 後は同じなので計算を省略
    ((i>=dend)) && [[ ${old_pos[i-dend]} == ${_ble_line_text_cache_pos[i]} ]] && break
  done

  if ((i<iN)); then
    # 途中で一致して中断した場合は、前の iN 番目の位置を読む
    local -a pos
    pos=(${_ble_line_text_cache_pos[iN]})
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
      ble/util/array-push _ble_line_text_cache_ichg "$ichg"
    fi
  done

  ((dbeg<i)) && POS_UMIN="$dbeg" POS_UMAX="$i"
}

_ble_line_text_buff=()
_ble_line_text_buffName=

## 関数 x y lc lg; .ble-line-text/update; x y cx cy lc lg
## \param [in    ] text  編集文字列
## \param [in    ] dirty 編集によって変更のあった最初の index
## \param [in    ] index カーソルの index
## \param [in,out] x     編集文字列開始位置、終了位置。
## \param [in,out] y     編集文字列開始位置、終了位置。
## \param [in,out] lc lg
##   カーソル左の文字のコードと gflag を返します。
##   カーソルが先頭にある場合は、編集文字列開始位置の左(プロンプトの最後の文字)について記述します。
## @var   [   out] umin umax
##   umin,umax は再描画の必要な範囲を文字インデックスで返します。
function .ble-line-text/update {
  # text dirty x y [.ble-line-text/update/position] x y
  local POS_UMIN=-1 POS_UMAX=-1
  .ble-line-text/update/position

  local iN="${#text}"

  # highlight -> HIGHLIGHT_BUFF
  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble-highlight-layer/update "$text"
  #.ble-line-info.draw-text "highlight-urange = ($HIGHLIGHT_UMIN $HIGHLIGHT_UMAX)"

  # 変更文字の適用
  if ((${#_ble_line_text_cache_ichg[@]})); then
    local ichg g sgr
    builtin eval "_ble_line_text_buff=(\"\${$HIGHLIGHT_BUFF[@]}\")"
    HIGHLIGHT_BUFF=_ble_line_text_buff
    for ichg in "${_ble_line_text_cache_ichg[@]}"; do
      ble-highlight-layer/getg "$ichg"
      ble-color-g2sgr -v sgr "$g"
      _ble_line_text_buff[ichg]="$sgr${_ble_line_text_cache_cs[ichg]}"
    done
  fi

  _ble_line_text_buffName="$HIGHLIGHT_BUFF"

  # umin, umax
  ((umin=HIGHLIGHT_UMIN,
    umax=HIGHLIGHT_UMAX,
    POS_UMIN>=0&&(umin<0||umin>POS_UMIN)&&(umin=POS_UMIN),
    POS_UMAX>=0&&(umax<0||umax<POS_UMAX)&&(umax=POS_UMAX)))
  # .ble-line-info.draw-text "position $POS_UMIN-$POS_UMAX, highlight $HIGHLIGHT_UMIN-$HIGHLIGHT_UMAX"

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
      .ble-line-text/getxy.cur --prefix=c "$index"

      local lcs ret
      if ((cx==0)); then
        # 次の文字
        if ((index==iN)); then
          # 次の文字がない時は空白
          ret=32
        else
          lcs="${_ble_line_text_cache_cs[index]}"
          ble/util/s2c "$lcs" 0
        fi

        # 次が改行の時は空白にする
        ble-highlight-layer/getg -v lg "$index"
        ((lc=ret==10?32:ret))
      else
        # 前の文字
        lcs="${_ble_line_text_cache_cs[index-1]}"
        ble/util/s2c "$lcs" "$((${#lcs}-1))"
        ble-highlight-layer/getg -v lg "$((index-1))"
        ((lc=ret))
      fi
    fi
  fi
}

## 関数 .ble-line-text/getxy iN
##   @var[out] x
##   @var[out] y
function .ble-line-text/getxy {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
    shift
  fi

  local -a _pos
  _pos=(${_ble_line_text_cache_pos[$1]})
  ((${_prefix}x=_pos[0]))
  ((${_prefix}y=_pos[1]))
}
## 関数 .ble-line-text/getxy.cur iN
function .ble-line-text/getxy.cur {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
    shift
  fi

  local -a _pos
  _pos=(${_ble_line_text_cache_pos[$1]})

  # 追い出しされたか check
  if (($1<_ble_line_text_cache_length)); then
    local -a _eoc
    _eoc=(${_ble_line_text_cache_pos[$1+1]})
    ((_eoc[2])) && ((_pos[0]=0,_pos[1]++))
  fi

  ((${_prefix}x=_pos[0]))
  ((${_prefix}y=_pos[1]))
}


## 関数 .ble-line-text/slice [beg [end]]
##   @var [out] ret
function .ble-line-text/slice {
  local iN="$_ble_line_text_cache_length"
  local i1="${1:-0}" i2="${2:-$iN}"
  ((i1<0&&(i1+=iN,i1<0&&(i1=0)),
    i2<0&&(i2+=iN)))
  if ((i1<i2&&i1<iN)); then
    local g sgr
    ble-highlight-layer/getg -v g "$i1"
    ble-color-g2sgr -v sgr "$g"
    IFS= builtin eval "ret=\"\$sgr\${$_ble_line_text_buffName[*]:i1:i2-i1}\""
  else
    ret=
  fi
}

## 関数 .ble-line-text/get-index-at x y
##   指定した位置 x y に対応する index を求めます。
function .ble-line-text/get-index-at {
  local _var=index
  if [[ $1 == -v ]]; then
    _var="$2"
    shift 2
  fi

  local _x="$1" _y="$2"
  if ((_y>_ble_line_endy)); then
    (($_var=_ble_line_text_cache_length))
  elif ((_y<_ble_line_begy)); then
    (($_var=0))
  else
    # 2分法
    local _l=0 _u="$((_ble_line_text_cache_length+1))" _m
    local -a _mx _my
    while ((_l+1<_u)); do
      .ble-line-text/getxy.cur --prefix=_m "$((_m=(_l+_u)/2))"
      (((_y<_my||_y==_my&&_x<_mx)?(_u=_m):(_l=_m)))
    done
    (($_var=_l))
  fi
}


# 
# **** information pane ****                                         @line.info

## 関数 x y cols out ; .ble-line-cur.xyo/add-atomic ( nchar text )+ ; x y out
##   指定した文字列を out に追加しつつ、現在位置を更新します。
##   文字列は幅 1 の文字で構成されていると仮定します。
function .ble-line-cur.xyo/add-simple {
  local nchar="$1"

  # assert ((x<=cols))
  out="$out$2"
  ((
    x+=nchar%cols,
    y+=nchar/cols,
    (_ble_term_xenl?x>cols:x>=cols)&&(y++,x-=cols)
  ))
}
## 関数 x y cols out ; .ble-line-cur.xyo/add-atomic ( w char )+ ; x y out
##   指定した文字を out に追加しつつ、現在位置を更新します。
function .ble-line-cur.xyo/add-atomic {
  local w c
  w="$1"

  # その行に入りきらない文字は次の行へ (幅 w が2以上の文字)
  if ((x<cols&&cols<x+w)); then
    _ble_util_string_prototype.reserve "$((cols-x))"
    out="$out${_ble_util_string_prototype::cols-x}"
    ((x=cols))
  fi

  out="$out$2"

  # 移動
  if ((w>0)); then
    ((x+=w))
    while ((_ble_term_xenl?x>cols:x>=cols)); do
      ((y++,x-=cols))
    done
  fi
}
## 関数 x y cols out ; .ble-line-cur.xyo/eol2nl ; x y out
##   行末にいる場合次の行へ移動します。
function .ble-line-cur.xyo/eol2nl {
  if ((x==cols)); then
    ((_ble_term_xenl)) && out="$out"$'\n'
    ((y++,x=0))
  fi
}

## 関数 x y; .ble-line-info.construct-info text ; ret
##   指定した文字列を表示する為の制御系列に変換します。
function .ble-line-info.construct-info {

  local cols=${COLUMNS-80}

  local text="$1" out=
  local i iN=${#text}
  for ((i=0;i<iN;)); do
    local tail="${text:i}"

    if ble/util/isprint+ "$tail"; then
      .ble-line-cur.xyo/add-simple "${#BASH_REMATCH}" "${BASH_REMATCH[0]}"
      ((i+=${#BASH_REMATCH}))
    else
      ble/util/s2c "$text" "$i"
      local code="$ret" w=0
      if ((code<32)); then
        ble/util/c2s "$((code+64))"
        .ble-line-cur.xyo/add-atomic 2 "$_ble_term_rev^$ret$_ble_term_sgr0"
      elif ((code==127)); then
        .ble-line-cur.xyo/add-atomic 2 '$_ble_term_rev^?$_ble_term_sgr0'
      elif ((128<=code&&code<160)); then
        ble/util/c2s "$((code-64))"
        .ble-line-cur.xyo/add-atomic 4 "${_ble_term_rev}M-^$ret$_ble_term_sgr0"
      else
        ble/util/c2w "$code"
        .ble-line-cur.xyo/add-atomic "$ret" "${text:i:1}"
      fi

      ((i++))
    fi
  done

  .ble-line-cur.xyo/eol2nl

  ret="$out"
}

_ble_line_info=(0 0 "")
function .ble-line-info.draw/impl {
  local text="$2"

  local -a DRAW_BUFF

  local x=0 y=0 content=
  # 内容の構築
  case "$1" in
  (raw)
    local lc=32 lg=0 g=0
    ble-edit/draw/trace "$text"
    ble-edit/draw/sflush -v content ;;
  (text)
    local lc=32 ret
    .ble-line-info.construct-info "$text"
    content="$ret" ;;
  esac

  # (1) 移動・領域確保
  ble-edit/draw/goto 0 "$_ble_line_endy"
  ble-edit/draw/put "$_ble_term_ind"
  [[ ${_ble_line_info[2]} ]] && ble-edit/draw/put.dl '_ble_line_info[1]+1'
  [[ $content ]] && ble-edit/draw/put.il y+1

  # (2) 内容
  ble-edit/draw/put "$content"
  ble-edit/draw/flush >&2

  _ble_line_y="$((_ble_line_endy+1+y))"
  _ble_line_x="$x"
  _ble_line_info=("$x" "$y" "$content")
}
function .ble-line-info.draw-text {
  .ble-line-info.draw/impl text "$1"
}
function .ble-line-info.draw {
  .ble-line-info.draw/impl raw "$1"
}
function .ble-line-info.clear {
  [[ ${_ble_line_info[2]} ]] || return

  local -a DRAW_BUFF
  ble-edit/draw/goto 0 _ble_line_endy
  ble-edit/draw/put "$_ble_term_ind"
  ble-edit/draw/put.dl '_ble_line_info[1]+1'
  ble-edit/draw/flush >&2

  _ble_line_y="$((_ble_line_endy+1))"
  _ble_line_x=0
  _ble_line_info=(0 0 "")
}

# 
#------------------------------------------------------------------------------
# **** edit ****                                                          @edit

# 現在の編集状態は以下の変数で表現される
_ble_edit_str=
_ble_edit_ind=0
_ble_edit_mark=0
_ble_edit_mark_active=
_ble_edit_kill_ring=
_ble_edit_overwrite_mode=

# _ble_edit_str は以下の関数を通して変更する。
# 変更範囲を追跡する為。
function _ble_edit_str.replace {
  local -i beg="$1" end="$2"
  local ins="$3"

  # c.f. Note#1
  _ble_edit_str="${_ble_edit_str::beg}""$ins""${_ble_edit_str:end}"
  _ble_edit_str/update-dirty-range "$beg" "$((beg+${#ins}))" "$end"
  .ble-edit-draw.set-dirty "$beg"
#%if !release
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble-stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; beg=$beg, end=$end, ins(${#ins})=$ins"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end="${#_ble_edit_str}"
    if ((_ble_edit_ind>${#_ble_edit_str})); then
      _ble_edit_ind=${#_ble_edit_str}
    fi
  fi
#%end
}
function _ble_edit_str.reset {
  local str="$1"
  _ble_edit_str/update-dirty-range 0 "${#str}" "${#_ble_edit_str}"
  .ble-edit-draw.set-dirty 0
  _ble_edit_str="$str"
#%if !release
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble-stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; str(${#str})=$str"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end="${#_ble_edit_str}"
  fi
#%end
}
function _ble_edit_str.reset-and-check-dirty {
  local str="$1"
  [[ $_ble_edit_str == $str ]] && return

  local ret pref suff
  ble/string#common-prefix "$_ble_edit_str" "$str"; pref="$ret"
  local dmin="${#pref}"
  ble/string#common-suffix "${_ble_edit_str:dmin}" "${str:dmin}"; suff="$ret"
  local dmax0=$((${#_ble_edit_str}-${#suff})) dmax=$((${#str}-${#suff}))

  _ble_edit_str/update-dirty-range "$dmin" "$dmax" "$dmax0"
  _ble_edit_str="$str"
}

_ble_edit_dirty_draw_beg=-1
_ble_edit_dirty_draw_end=-1
_ble_edit_dirty_draw_end0=-1

_ble_edit_dirty_syntax_beg=0
_ble_edit_dirty_syntax_end=0
_ble_edit_dirty_syntax_end0=1

function _ble_edit_str/update-dirty-range {
  ble-edit/dirty-range/update --prefix=_ble_edit_dirty_draw_ "$@"
  ble-edit/dirty-range/update --prefix=_ble_edit_dirty_syntax_ "$@"

  # ble-assert '((
  #   _ble_edit_dirty_draw_beg==_ble_edit_dirty_syntax_beg&&
  #   _ble_edit_dirty_draw_end==_ble_edit_dirty_syntax_end&&
  #   _ble_edit_dirty_draw_end0==_ble_edit_dirty_syntax_end0))'
}

function _ble_edit_str.update-syntax {
  local beg end end0
  ble-edit/dirty-range/load --prefix=_ble_edit_dirty_syntax_
  if ((beg>=0)); then
    ble-edit/dirty-range/clear --prefix=_ble_edit_dirty_syntax_

    ble-syntax/parse "$_ble_edit_str" "$beg" "$end" "$end0"
  fi
}

# **** edit/dirty ****                                              @edit.dirty

function ble-edit/dirty-range/load {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
    ((beg=${_prefix}beg,
      end=${_prefix}end,
      end0=${_prefix}end0))
  fi
}

function ble-edit/dirty-range/clear {
  local _prefix=
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
    shift
  fi

  ((${_prefix}beg=-1,
    ${_prefix}end=-1,
    ${_prefix}end0=-1))
}

## 関数 ble-edit/dirty-range/update [--prefix=PREFIX] beg end end0
## @param[out] PREFIX
## @param[in]  beg    変更開始点。beg<0 は変更がない事を表す
## @param[in]  end    変更終了点。end<0 は変更が末端までである事を表す
## @param[in]  end0   変更前の end に対応する位置。
function ble-edit/dirty-range/update {
  local _prefix=_ble_edit_dirty_draw_
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1#--prefix=}"
    shift
  fi

  local begB="$1" endB="$2" endB0="$3"
  ((begB<0)) && return

  local begA endA endA0
  ((begA=${_prefix}beg,endA=${_prefix}end,endA0=${_prefix}end0))

  local beg end end0 delta
  if ((begA<0)); then
    ((beg=begB,
      end=endB,
      end0=endB0))
  else
    ((beg=begA<begB?begA:begB))
    if ((endA<0||endB<0)); then
      ((end=-1,end0=-1))
    else
      ((end=endB,end0=endA0,
        (delta=endA-endB0)>0?(end+=delta):(end0-=delta)))
    fi
  fi

  ((${_prefix}beg=beg,
    ${_prefix}end=end,
    ${_prefix}end0=end0))
}

# **** PS1/LINENO ****                                                @edit.ps1
#
# 内部使用変数
## 変数 _ble_edit_PS1
## 変数 _ble_edit_LINENO
## 変数 _ble_edit_CMD

function .ble-edit/edit/attach/TRAPWINCH {
  if ((_ble_edit_attached)); then
    _ble_line_text_cache_pos=()
    .ble-edit/stdout/on
    .ble-edit-draw.redraw
    .ble-edit/stdout/off
  fi
}

## called by ble-edit-attach
_ble_edit_attached=0
function .ble-edit/edit/attach {
  ((_ble_edit_attached)) && return
  _ble_edit_attached=1

  if [[ ! ${_ble_edit_LINENO+set} ]]; then
    _ble_edit_LINENO="${BASH_LINENO[*]: -1}"
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0
    unset LINENO; LINENO="$_ble_edit_LINENO"
    _ble_edit_CMD="$_ble_edit_LINENO"
  fi

  trap .ble-edit/edit/attach/TRAPWINCH WINCH

  # if [[ ! ${_ble_edit_PS1+set} ]]; then
  # fi
  _ble_edit_PS1="$PS1"
  PS1=
}

function .ble-edit/edit/detach {
  ((!_ble_edit_attached)) && return
  PS1="$_ble_edit_PS1"
  _ble_edit_attached=0
}

# **** ble-edit/draw ****                                            @edit/draw

# 出力のための新しい関数群2

## 関数 ble-edit/draw/goto varname x y
##   現在位置を指定した座標へ移動する制御系列を生成します。
##   @param [in] x y
##     移動先のカーソルの座標を指定します。
##     プロンプト原点が x=0 y=0 に対応します。
function ble-edit/draw/goto {
  local -i x="$1" y="$2"
  ble-edit/draw/put "$_ble_term_sgr0"

  local -i dy=y-_ble_line_y
  if ((dy!=0)); then
    if ((dy>0)); then
      ble-edit/draw/put "${_ble_term_cud//'%d'/$dy}"
    else
      ble-edit/draw/put "${_ble_term_cuu//'%d'/$((-dy))}"
    fi
  fi

  local -i dx=x-_ble_line_x
  if ((dx!=0)); then
    if ((x==0)); then
      ble-edit/draw/put "$_ble_term_cr"
    elif ((dx>0)); then
      ble-edit/draw/put "${_ble_term_cuf//'%d'/$dx}"
    else
      ble-edit/draw/put "${_ble_term_cub//'%d'/$((-dx))}"
    fi
  fi

  _ble_line_x="$x" _ble_line_y="$y"
}
## 関数 ble-edit/draw/clear-line
##   プロンプト原点に移動して、既存のプロンプト表示内容を空白にする制御系列を生成します。
function ble-edit/draw/clear-line {
  ble-edit/draw/goto 0 0
  if ((_ble_line_endy>0)); then
    local height=$((_ble_line_endy+1))
    ble-edit/draw/put "${_ble_term_dl//'%d'/$height}${_ble_term_il//'%d'/$height}"
  else
    ble-edit/draw/put "$_ble_term_el2"
  fi
}
## 関数 ble-edit/draw/clear-line-after x y
##   指定した x y 位置に移動して、
##   更に、以降の内容を空白にする制御系列を生成します。
## \param [in] x
## \param [in] y
function ble-edit/draw/clear-line-after {
  local x="$1" y="$2"

  ble-edit/draw/goto "$x" "$y"
  if ((_ble_line_endy>y)); then
    local height=$((_ble_line_endy-y))
    ble-edit/draw/put "$_ble_term_ind${_ble_term_dl//'%d'/$height}${_ble_term_il//'%d'/$height}$_ble_term_ri"
  fi
  ble-edit/draw/put "$_ble_term_el"

  _ble_line_x="$x" _ble_line_y="$y"
}

# **** .ble-edit-draw ****                                           @edit.draw

## 配列 _ble_line_cur
##   キャレット位置 (ユーザに対して呈示するカーソル) と其処の文字の情報を保持します。
## _ble_line_cur[0] x   キャレット位置の y 座標を保持します。
## _ble_line_cur[1] y   キャレット位置の y 座標を保持します。
## _ble_line_cur[2] lc
##   キャレット位置の左側の文字の文字コードを整数で保持します。
##   キャレットが最も左の列にある場合は右側の文字を保持します。
## _ble_line_cur[3] lg
##   キャレット位置の左側の SGR フラグを保持します。
##   キャレットが最も左の列にある場合は右側の文字に適用される SGR フラグを保持します。
_ble_line_cur=(0 0 32 0)

## 変数 x
## 変数 y
##   現在の (描画の為に動き回る) カーソル位置を保持します。
_ble_line_x=0 _ble_line_y=0

_ble_line_begx=0
_ble_line_begy=0
_ble_line_endx=0
_ble_line_endy=0

## 変数 _ble_edit_dirty
##   編集文字列の変更開始点を記録します。
##   編集文字列の位置計算は、この点以降に対して実行されます。
##   .ble-edit-draw.update 関数内で使用されクリアされます。
##   @value _ble_edit_dirty=
##     再描画の必要がない事を表します。
##   @value _ble_edit_dirty=-1
##     プロンプトも含めて内容の再計算をする必要がある事を表します。
##   @value _ble_edit_dirty=(整数)
##     編集文字列の指定した位置以降に対し再計算する事を表します。
_ble_edit_dirty=-1

function .ble-edit-draw.set-dirty {
  local d2="${1:-$_ble_edit_ind}"
  if [[ ! $_ble_edit_dirty ]]; then
    _ble_edit_dirty="$d2"
  else
    ((d2<_ble_edit_dirty&&(_ble_edit_dirty=d2)))
  fi
}

## 変数 _ble_line_cache_ind := inds ':' mark ':' mark_active
##   現在の表示内容のカーソル位置・ポイント位置の情報を保持します。
_ble_line_cache_ind=::

## 関数 .ble-edit-draw.update
##   要件: カーソル位置 (x y) = (_ble_line_cur[0] _ble_line_cur[1]) に移動する
##   要件: 編集文字列部分の再描画を実行する
function .ble-edit-draw.update {
  local indices="$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active:$_ble_edit_line_disabled:$_ble_edit_overwrite_mode"
  if [[ ! $_ble_edit_dirty && "$_ble_line_cache_ind" == "$indices" ]]; then
    local -a DRAW_BUFF
    ble-edit/draw/goto "${_ble_line_cur[0]}" "${_ble_line_cur[1]}"
    ble-edit/draw/flush >&2
    return
  fi

  #-------------------
  # 内容の再計算

  local ret

  local x y g lc lg=0
  ble-edit/prompt/update # x y lc ret
  local prox="$x" proy="$y" prolc="$lc" esc_prompt="$ret"

  # BLELINE_RANGE_UPDATE → .ble-line-text/update 内でこれを見て update を済ませる
  local -a BLELINE_RANGE_UPDATE=("$_ble_edit_dirty_draw_beg" "$_ble_edit_dirty_draw_end" "$_ble_edit_dirty_draw_end0")
  ble-edit/dirty-range/clear --prefix=_ble_edit_dirty_draw_
#%if !release
  ble-assert '((BLELINE_RANGE_UPDATE[0]<0||(
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[1]&&
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[2])))' "(${BLELINE_RANGE_UPDATE[*]})"
#%end

  # local graphic_dbeg graphic_dend graphic_dend0
  # ble-edit/dirty-range/update --prefix=graphic_d

  # 編集内容の構築
  local text="$_ble_edit_str" index="$_ble_edit_ind" dirty="$_ble_edit_dirty"
  local iN="${#text}"
  ((index<0?(index=0):(index>iN&&(index=iN))))

  local umin=-1 umax=-1
  .ble-line-text/update # text index dirty -> x y lc lg

  #-------------------
  # 出力

  local -a DRAW_BUFF

  # 1 描画領域の確保 (高さの調整)
  local endx endy begx begy
  .ble-line-text/getxy --prefix=beg 0
  .ble-line-text/getxy --prefix=end "$iN"
  local delta
  if (((delta=endy-_ble_line_endy)!=0)); then
    if((delta>0)); then
      ble-edit/draw/goto 0 "$((_ble_line_endy+1))"
      ble-edit/draw/put.il delta
    else
      ble-edit/draw/goto 0 "$((_ble_line_endy+1+delta))"
      ble-edit/draw/put.dl -delta
    fi
  fi
  _ble_line_begx="$begx" _ble_line_begy="$begy"
  _ble_line_endx="$endx" _ble_line_endy="$endy"

  # 2 表示内容
  local ret retx=-1 rety=-1 esc_line=
  if ((_ble_edit_dirty>=0)); then
    # 部分更新の場合

    # # 編集文字列全体の描画
    # local ret
    # .ble-line-text/slice # → ret
    # local esc_line="$ret"
    # ble-edit/draw/clear-line-after "$prox" "$proy"
    # ble-edit/draw/put "$ret"
    # .ble-line-text/getxy --prefix=ret "$iN" # → retx rety
    # _ble_line_x="$retx" _ble_line_y="$rety"

    # 編集文字列の一部を描画する場合
    if ((umin<umax)); then
      local uminx uminy umaxx umaxy
      .ble-line-text/getxy --prefix=umin "$umin"
      .ble-line-text/getxy --prefix=umax "$umax"

      ble-edit/draw/goto "$uminx" "$uminy"
      .ble-line-text/slice "$umin" "$umax"
      ble-edit/draw/put "$ret"
      _ble_line_x="$umaxx" _ble_line_y="$umaxy"
    fi

    if ((BLELINE_RANGE_UPDATE[0]>=0)); then
      ble-edit/draw/clear-line-after "$endx" "$endy"
    fi
  else
    # 全体更新

    # プロンプト描画
    ble-edit/draw/clear-line
    ble-edit/draw/put "$esc_prompt"
    _ble_line_x="$prox" _ble_line_y="$proy"

    # # SC/RC で復帰する場合はこちら。
    # local ret esc_line
    # if ((index<iN)); then
    #   .ble-line-text/slice 0 "$index"
    #   esc_line="$ret$_ble_term_sc"
    #   .ble-line-text/slice "$index"
    #   esc_line="$esc_line$ret$_ble_term_rc"
    #   ble-edit/draw/put "$esc_line"
    #   .ble-line-text/getxy --prefix=ret "$index"
    #   _ble_line_x="$retx" _ble_line_y="$rety"
    # else
    #   .ble-line-text/slice
    #   esc_line="$ret"
    #   ble-edit/draw/put "$esc_line"
    #   .ble-line-text/getxy --prefix=ret "$iN"
    #   _ble_line_x="$retx" _ble_line_y="$rety"
    # fi

    # 全体を描画する場合
    local ret esc_line
    .ble-line-text/slice # → ret
    esc_line="$ret"
    ble-edit/draw/put "$ret"
    .ble-line-text/getxy --prefix=ret "$iN" # → retx rety
    _ble_line_x="$retx" _ble_line_y="$rety"
  fi

  # 3 移動
  local cx cy
  .ble-line-text/getxy.cur --prefix=c "$index" # → cx cy
  ble-edit/draw/goto "$cx" "$cy"
  ble-edit/draw/flush 1>&2

  # 4 後で使う情報の記録
  _ble_line_cur=("$cx" "$cy" "$lc" "$lg")
  _ble_edit_dirty= _ble_line_cache_ind="$indices"

  if [[ -z $bleopt_suppress_bash_output ]]; then
    if ((retx<0)); then
      .ble-line-text/slice
      esc_line="$ret"
      .ble-line-text/getxy --prefix=ret "$iN"
    fi

    _ble_line_cache=(
      "$esc_prompt$esc_line"
      "${_ble_line_cur[@]}"
      "$_ble_line_endx" "$_ble_line_endy"
      "$retx" "$rety")
  fi
}
function .ble-edit-draw.redraw {
  _ble_edit_dirty=-1
  .ble-edit-draw.update
}

## 配列 _ble_line_cache
##   現在表示している内容のキャッシュです。
##   .ble-edit-draw.update で値が設定されます。
##   .ble-edit-draw.redraw-cache はこの情報を元に再描画を行います。
## _ble_line_cache[0]:        表示内容
## _ble_line_cache[1]: curx   カーソル位置 x
## _ble_line_cache[2]: cury   カーソル位置 y
## _ble_line_cache[3]: curlc  カーソル位置の文字の文字コード
## _ble_line_cache[3]: curlg  カーソル位置の文字の SGR フラグ
## _ble_line_cache[4]: endx   末端位置 x
## _ble_line_cache[5]: endy   末端位置 y
_ble_line_cache=()

function .ble-edit-draw.redraw-cache {
  if [[ ${_ble_line_cache[0]+set} ]]; then
    local -a d
    d=("${_ble_line_cache[@]}")

    local -a DRAW_BUFF

    ble-edit/draw/clear-line
    ble-edit/draw/put "${d[0]}"
    _ble_line_x="${d[7]}" _ble_line_y="${d[8]}"
    _ble_line_endx="${d[5]}" _ble_line_endy="${d[6]}"

    _ble_line_cur=("${d[@]:1:4}")
    ble-edit/draw/goto "${_ble_line_cur[0]}" "${_ble_line_cur[1]}"

    ble-edit/draw/flush 1>&2
  else
    .ble-edit-draw.redraw
  fi
}
## 関数 .ble-edit-draw.update-adjusted
##
## * この関数は bind -x される関数から呼び出される事を想定している。
##   通常のコマンドとして実行される関数から呼び出す事は想定していない。
##   内部で PS1= 等の設定を行うのでプロンプトの情報が失われる。
##   また、READLINE_LINE, READLINE_POINT 等のグローバル変数の値を変更する。
function .ble-edit-draw.update-adjusted {
  .ble-edit-draw.update
  # 現在はフルで描画 (bash が消してしまうので)
  # .ble-edit-draw.redraw

  local -a DRAW_BUFF

  # bash が表示するプロンプトを見えなくする
  # (現在のカーソルの左側にある文字を再度上書きさせる)
  PS1=
  local ret lc="${_ble_line_cur[2]}" lg="${_ble_line_cur[3]}"
  ble/util/c2s "$lc"
  READLINE_LINE="$ret"
  if ((_ble_line_cur[0]==0)); then
    READLINE_POINT=0
  else
    if [[ ! $bleopt_suppress_bash_output ]]; then
      ble/util/c2w "$lc"
      ((ret>0)) && ble-edit/draw/put.cub "$ret"
    fi
    ble-text-c2bc "$lc"
    READLINE_POINT="$ret"
  fi

  ble-color-g2sgr "$lg"
  ble-edit/draw/put "$ret"
  ble-edit/draw/flush >&2
}
function ble/widget/redraw-line {
  .ble-edit-draw.set-dirty -1
}
function ble/widget/clear-screen {
  builtin echo -n "$_ble_term_clear" >&2
  _ble_line_x=0 _ble_line_y=0
  _ble_line_cur=(0 0 32 0)
  .ble-edit-draw.set-dirty -1
  ble-term/visible-bell/cancel-erasure
}
function ble/widget/display-shell-version {
  ble/widget/.shell-command 'builtin echo "GNU bash, version $BASH_VERSION ($MACHTYPE) with ble.sh"'
}

# 
# **** mark, kill, copy ****                                         @edit.mark

function ble/widget/overwrite-mode {
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=1
  fi
}

function ble/widget/set-mark {
  _ble_edit_mark="$_ble_edit_ind"
  _ble_edit_mark_active=1
}
function ble/widget/kill-forward-text {
  ((_ble_edit_ind>=${#_ble_edit_str})) && return

  _ble_edit_kill_ring="${_ble_edit_str:_ble_edit_ind}"
  _ble_edit_str.replace "$_ble_edit_ind" "${#_ble_edit_str}" ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble/widget/kill-backward-text {
  ((_ble_edit_ind==0)) && return
  _ble_edit_kill_ring="${_ble_edit_str::_ble_edit_ind}"
  _ble_edit_str.replace 0 _ble_edit_ind ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble/widget/exchange-point-and-mark {
  local m="$_ble_edit_mark" p="$_ble_edit_ind"
  _ble_edit_ind="$m" _ble_edit_mark="$p"
}
function ble/widget/yank {
  ble/widget/insert-string "$_ble_edit_kill_ring"
}
function ble/widget/marked {
  if [[ $_ble_edit_mark_active != S ]]; then
    _ble_edit_mark="$_ble_edit_ind"
    _ble_edit_mark_active=S
  fi
  "ble/widget/$@"
}
function ble/widget/nomarked {
  if [[ $_ble_edit_mark_active == S ]]; then
    _ble_edit_mark_active=
  fi
  "ble/widget/$@"
}

## 関数 .ble-edit.process-range-argument P0 P1; p0 p1 len ?
## \param [in]  P0  範囲の端点を指定します。
## \param [in]  P1  もう一つの範囲の端点を指定します。
## \param [out] p0  範囲の開始点を返します。
## \param [out] p1  範囲の終端点を返します。
## \param [out] len 範囲の長さを返します。
## \param [out] $?
##   範囲が有限の長さを持つ場合に正常終了します。
##   範囲が空の場合に 1 を返します。
function .ble-edit.process-range-argument {
  p0="$1" p1="$2" len="${#_ble_edit_str}"
  local pt
  ((
    p0>len?(p0=len):p0<0&&(p0=0),
    p1>len?(p1=len):p0<0&&(p1=0),
    p1<p0&&(pt=p1,p1=p0,p0=pt),
    (len=p1-p0)>0
  ))
}
## 関数 .ble-edit.delete-range P0 P1
function .ble-edit.delete-range {
  local p0 p1 len
  .ble-edit.process-range-argument "$@" || return 0

  # delete
  ((
    _ble_edit_ind>p1? (_ble_edit_ind-=len):
    _ble_edit_ind>p0&&(_ble_edit_ind=p0),
    _ble_edit_mark>p1? (_ble_edit_mark-=len):
    _ble_edit_mark>p0&&(_ble_edit_mark=p0)
  ))
  _ble_edit_str.replace p0 p1 ''
}
## 関数 .ble-edit.kill-range P0 P1
function .ble-edit.kill-range {
  local p0 p1 len
  .ble-edit.process-range-argument "$@" || return 0

  # copy
  _ble_edit_kill_ring="${_ble_edit_str:p0:len}"

  # delete
  ((
    _ble_edit_ind>p1? (_ble_edit_ind-=len):
    _ble_edit_ind>p0&&(_ble_edit_ind=p0),
    _ble_edit_mark>p1? (_ble_edit_mark-=len):
    _ble_edit_mark>p0&&(_ble_edit_mark=p0)
  ))
  _ble_edit_str.replace p0 p1 ''
}
## 関数 .ble-edit.copy-range P0 P1
function .ble-edit.copy-range {
  local p0 p1 len
  .ble-edit.process-range-argument "$@" || return 0

  # copy
  _ble_edit_kill_ring="${_ble_edit_str:p0:len}"
}
## 関数 ble/widget/delete-region
##   領域を削除します。
function ble/widget/delete-region {
  .ble-edit.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/kill-region
##   領域を切り取ります。
function ble/widget/kill-region {
  .ble-edit.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/copy-region
##   領域を転写します。
function ble/widget/copy-region {
  .ble-edit.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/delete-region-or type
##   領域または引数に指定した単位を削除します。
##   mark が active な場合には領域の削除を行います。
##   それ以外の場合には第一引数に指定した単位の削除を実行します。
## \param [in] type
##   mark が active でない場合に実行される削除の単位を指定します。
##   実際には ble-edit 関数 delete-type が呼ばれます。
function ble/widget/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/delete-region
  else
    "ble/widget/delete-$@"
  fi
}
## 関数 ble/widget/kill-region-or type
##   領域または引数に指定した単位を切り取ります。
##   mark が active な場合には領域の切り取りを行います。
##   それ以外の場合には第一引数に指定した単位の切り取りを実行します。
## \param [in] type
##   mark が active でない場合に実行される切り取りの単位を指定します。
##   実際には ble-edit 関数 kill-type が呼ばれます。
function ble/widget/kill-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/kill-region
  else
    "ble/widget/kill-$@"
  fi
}
## 関数 ble/widget/copy-region-or type
##   領域または引数に指定した単位を転写します。
##   mark が active な場合には領域の転写を行います。
##   それ以外の場合には第一引数に指定した単位の転写を実行します。
## \param [in] type
##   mark が active でない場合に実行される転写の単位を指定します。
##   実際には ble-edit 関数 copy-type が呼ばれます。
function ble/widget/copy-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/copy-region
  else
    "ble/widget/copy-$@"
  fi
}

# 
# **** bell ****                                                     @edit.bell

function .ble-edit.bell {
  [[ $bleopt_edit_vbell ]] && ble-term/visible-bell "$1"
  [[ $bleopt_edit_abell ]] && ble-term/audible-bell
}
function ble/widget/bell {
  .ble-edit.bell
  _ble_edit_mark_active=
}

# 
# **** insert ****                                                 @edit.insert

function ble/widget/insert-string {
  local ins="$*"
  [[ $ins ]] || return

  local dx="${#ins}"
  _ble_edit_str.replace _ble_edit_ind _ble_edit_ind "$ins"
  (('
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  '))
  _ble_edit_mark_active=
}
function ble/widget/self-insert {
  local code="$((KEYS[0]&ble_decode_MaskChar))"
  ((code==0)) && return

  local ibeg="$_ble_edit_ind" iend="$_ble_edit_ind"
  local ret ins; ble/util/c2s "$code"; ins="$ret"
  local delta=1 # 挿入による文字数の増減

  if [[ $_ble_edit_overwrite_mode ]] && ((code!=10&&code!=9)); then
    local ret w; ble/util/c2w-edit "$code"; w="$ret"

    local repw iend iN="${#_ble_edit_str}"
    for ((repw=0;repw<w&&iend<iN;iend++)); do
      local c1 w1
      ble/util/s2c "$_ble_edit_str" "$iend"; c1="$ret"
      [[ $c1 == 0 || $c1 == 10 || $c1 == 9 ]] && break
      ble/util/c2w-edit "$c1"; w1="$ret"
      ((repw+=w1,delta--))
    done

    if ((repw>w)); then
      ins="$ins${_ble_util_string_prototype::repw-w}"
      ((delta++))
    fi
  fi

  _ble_edit_str.replace ibeg iend "$ins"
  ((_ble_edit_ind++,
    _ble_edit_mark>ibeg&&(
      _ble_edit_mark<iend?(
        _ble_edit_mark=_ble_edit_ind
      ):(
        _ble_edit_mark+=delta))))
  _ble_edit_mark_active=
}

# quoted insert
function .ble-edit.quoted-insert.hook {
  local -a KEYS=("$1")
  ble/widget/self-insert
}
function ble/widget/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_char__hook=.ble-edit.quoted-insert.hook
}

function ble/widget/transpose-chars {
  if ((_ble_edit_ind<=0||_ble_edit_ind>=${#_ble_edit_str})); then
    .ble-edit.bell
  else
    local a="${_ble_edit_str:_ble_edit_ind-1:1}"
    local b="${_ble_edit_str:_ble_edit_ind:1}"
    _ble_edit_str.replace _ble_edit_ind-1 _ble_edit_ind+1 "$b$a"
    ((_ble_edit_ind++))
  fi
}

# 
# **** delete-char ****                                            @edit.delete

function .ble-edit/delete-backward-char {
  if ((_ble_edit_ind<=0)); then
    return 1
  else
    local ins=
    if [[ $_ble_edit_overwrite_mode ]]; then
      local next="${_ble_edit_str:_ble_edit_ind:1}"
      if [[ $next && $next != [$'\n\t'] ]]; then
        local clast ret
        ble/util/s2c "$_ble_edit_str" "$((_ble_edit_ind-1))"
        ble/util/c2w-edit "$ret"
        ins="${_ble_util_string_prototype::ret}"
        ((_ble_edit_mark>=_ble_edit_ind&&
             (_ble_edit_mark+=ret)))
      fi
    fi

    _ble_edit_str.replace _ble_edit_ind-1 _ble_edit_ind "$ins"
    ((_ble_edit_ind--,
      _ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
    return 0
  fi
}

function .ble-edit.delete-char {
  local a="${1:-1}"
  if ((a>0)); then
    # delete-forward-char
    if ((_ble_edit_ind>=${#_ble_edit_str})); then
      return 1
    else
      _ble_edit_str.replace _ble_edit_ind _ble_edit_ind+1 ''
    fi
  elif ((a<0)); then
    # delete-backward-char
    .ble-edit/delete-backward-char
    return
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      _ble_edit_str.replace _ble_edit_ind _ble_edit_ind+1 ''
    else
      _ble_edit_ind="${#_ble_edit_str}"
      .ble-edit/delete-backward-char
      return
    fi
  fi

  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
  return 0
}
function ble/widget/delete-forward-char {
  .ble-edit.delete-char 1 || .ble-edit.bell
}
function ble/widget/delete-backward-char {
  .ble-edit.delete-char -1 || .ble-edit.bell
}
function ble/widget/delete-forward-char-or-exit {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
    return
  fi

  # job が残っている場合
  local joblist
  ble/util/joblist
  if ((${#joblist[@]})); then
    .ble-edit.bell "(exit) ジョブが残っています!"
    ble/widget/.shell-command 'printf %s "$_ble_util_joblist_jobs"'
    return
  fi

  #_ble_edit_detach_flag=exit

  #ble-term/visible-bell ' Bye!! ' # 最後に vbell を出すと一時ファイルが残る
  builtin echo "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0" >&2
  exit
}
function ble/widget/delete-forward-backward-char {
  .ble-edit.delete-char 0 || .ble-edit.bell
}


function ble/widget/delete-horizontal-space {
  local a b rex
  b="${_ble_edit_str::_ble_edit_ind}" rex='[ 	]*$' ; [[ $b =~ $rex ]]; b="${#BASH_REMATCH}"
  a="${_ble_edit_str:_ble_edit_ind}"  rex='^[ 	]*'; [[ $a =~ $rex ]]; a="${#BASH_REMATCH}"
  .ble-edit.delete-range "$((_ble_edit_ind-b))" "$((_ble_edit_ind+a))"
}

# 
# **** cursor move ****                                            @edit.cursor

function .ble-edit.goto-char {
  local _ind="$1"
  ((_ble_edit_ind==_ind)) && return
  _ble_edit_ind="$_ind"
}
function .ble-edit.forward-char {
  local _ind=$((_ble_edit_ind+${1:-1}))
  if ((_ind>${#_ble_edit_str})); then
    .ble-edit.goto-char "${#_ble_edit_str}"
    return 1
  elif ((_ind<0)); then
    .ble-edit.goto-char 0
    return 1
  else
    .ble-edit.goto-char "$_ind"
    return 0
  fi
}
function ble/widget/forward-char {
  .ble-edit.forward-char 1 || .ble-edit.bell
}
function ble/widget/backward-char {
  .ble-edit.forward-char -1 || .ble-edit.bell
}
function ble/widget/end-of-text {
  .ble-edit.goto-char ${#_ble_edit_str}
}
function ble/widget/beginning-of-text {
  .ble-edit.goto-char 0
}

function ble/widget/beginning-of-line {
  local x y index
  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$y"
  .ble-edit.goto-char "$index"
}
function ble/widget/end-of-line {
  local x y index ax ay
  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$((y+1))"
  .ble-line-text/getxy.cur --prefix=a "$index"
  ((ay>y&&index--))
  .ble-edit.goto-char "$index"
}

function ble/widget/kill-backward-line {
  local x y index
  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$y"
  ((index==_ble_edit_ind&&index>0&&index--))
  .ble-edit.kill-range "$index" "$_ble_edit_ind"
}
function ble/widget/kill-forward-line {
  local x y index ax ay
  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$((y+1))"
  .ble-line-text/getxy.cur --prefix=a "$index"
  ((_ble_edit_ind+1<index&&ay>y&&index--))
  .ble-edit.kill-range "$_ble_edit_ind" "$index"
}

function ble/widget/forward-line {
  local x y index
  ((_ble_edit_ind<_ble_line_text_cache_length)) || return 1
  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at "$x" "$((y+1))"
  .ble-edit.goto-char "$index"
  ((_ble_edit_mark_active||y<_ble_line_endy))
}
function ble/widget/backward-line {
  local x y index

  # 一番初めの文字でも追い出しによって2行目以降に表示される可能性。
  # その場合に exit status 1 にする為に初めに check してしまう。
  ((_ble_edit_ind>0)) || return 1

  .ble-line-text/getxy.cur "$_ble_edit_ind"
  .ble-line-text/get-index-at "$x" "$((y-1))"
  .ble-edit.goto-char "$index"
  ((_ble_edit_mark_active||y>_ble_line_begy))
}

# 
# **** word location ****                                            @edit.word

## 関数 .ble-edit.locate-backward-cword; a b c
##   後方の c word を探索します。
##   |---|www|---|
##   a   b   c   x
function .ble-edit.locate-backward-cword {
  local x="${1:-$_ble_edit_ind}"
  c="${_ble_edit_str::x}"; c="${c##*[_a-zA-Z0-9]}" ; c=$((x-${#c}))
  b="${_ble_edit_str::c}"; b="${b##*[^_a-zA-Z0-9]}"; b=$((c-${#b}))
  a="${_ble_edit_str::b}"; a="${a##*[_a-zA-Z0-9]}" ; a=$((b-${#a}))
}
## 関数 .ble-edit.locate-backward-cword; s t u
##   前方の c word を探索します。
##   |---|www|---|
##   x   s   t   u
function .ble-edit.locate-forward-cword {
  local x="${1:-$_ble_edit_ind}"
  s="${_ble_edit_str:x}"; s="${s%%[_a-zA-Z0-9]*}" ; s=$((x+${#s}))
  t="${_ble_edit_str:s}"; t="${t%%[^_a-zA-Z0-9]*}"; t=$((s+${#t}))
  u="${_ble_edit_str:t}"; u="${u%%[_a-zA-Z0-9]*}" ; u=$((t+${#u}))
}
## 関数 .ble-edit.locate-backward-cword; s t u
##   現在位置の c word を探索します。
##   |---|wwww|---|
##   r   s    t   u
##        <- x --->
function .ble-edit.locate-current-cword {
  local x="${1:-$_ble_edit_ind}"

  local a b c # <a> *<b>w*<c> *<x>
  .ble-edit.locate-backward-cword

  r="$a"
  .ble-edit.locate-forward-cword "$r"
}
#%m locate-xword (
## 関数 .ble-edit.locate-backward-xword; a b c
##   後方の generic word を探索します。
##   |---|www|---|
##   a   b   c   x
function .ble-edit.locate-backward-xword {
  local x="${1:-$_ble_edit_ind}" FS=%FS%
  c="${_ble_edit_str::x}"; c="${c##*[^$FS]}"; c=$((x-${#c}))
  b="${_ble_edit_str::c}"; b="${b##*[$FS]}"; b=$((c-${#b}))
  a="${_ble_edit_str::b}"; a="${a##*[^$FS]}"; a=$((b-${#a}))
}
## 関数 .ble-edit.locate-backward-xword; s t u
##   前方の generic word を探索します。
##   |---|www|---|
##   x   s   t   u
function .ble-edit.locate-forward-xword {
  local x="${1:-$_ble_edit_ind}" FS=%FS%
  s="${_ble_edit_str:x}"; s="${s%%[^$FS]*}"; s=$((x+${#s}))
  t="${_ble_edit_str:s}"; t="${t%%[$FS]*}"; t=$((s+${#t}))
  u="${_ble_edit_str:t}"; u="${u%%[^$FS]*}"; u=$((t+${#u}))
}
## 関数 .ble-edit.locate-backward-xword; s t u
##   現在位置の generic word を探索します。
##   |---|wwww|---|
##   r   s    t   u
##        <- x --->
function .ble-edit.locate-current-xword {
  local x="${1:-$_ble_edit_ind}"

  local a b c # <a> *<b>w*<c> *<x>
  .ble-edit.locate-backward-xword

  r="$a"
  .ble-edit.locate-forward-xword "$r"
}
#%)
#%x locate-xword .r/xword/uword/ .r/generic word/unix word/ .r/%FS%/"${IFS:-$' \t\n'}"/
#%x locate-xword .r/xword/sword/ .r/generic word/shell word/.r/%FS%/$'|&;()<> \t\n'/
#%x locate-xword .r/xword/fword/ .r/generic word/filename/  .r|%FS%|"/${IFS:-$' \t\n'}"|

# 
#%m kill-uword (
# unix word

## 関数 ble/widget/delete-forward-uword
##   前方の unix word を削除します。
function ble/widget/delete-forward-uword {
  # |---|www|---|
  # x   s   t   u
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword
  if ((x!=t)); then
    .ble-edit.delete-range "$x" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/delete-backward-uword
##   後方の unix word を削除します。
function ble/widget/delete-backward-uword {
  # |---|www|---|
  # a   b   c   x
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword
  if ((x>c&&(c=x),b!=c)); then
    .ble-edit.delete-range "$b" "$c"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/delete-uword
##   現在位置の unix word を削除します。
function ble/widget/delete-uword {
  local x="${1:-$_ble_edit_ind}" r s t u
  .ble-edit.locate-current-uword "$x"
  if ((x>t&&(t=x),r!=t)); then
    .ble-edit.delete-range "$r" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/kill-forward-uword
##   前方の unix word を切り取ります。
function ble/widget/kill-forward-uword {
  # <x> *<s>w*<t> *<u>
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword
  if ((x!=t)); then
    .ble-edit.kill-range "$x" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/kill-backward-uword
##   後方の unix word を切り取ります。
function ble/widget/kill-backward-uword {
  # <a> *<b>w*<c> *<x>
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword
  if ((x>c&&(c=x),b!=c)); then
    .ble-edit.kill-range "$b" "$c"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/kill-uword
##   現在位置の unix word を切り取ります。
function ble/widget/kill-uword {
  local x="${1:-$_ble_edit_ind}" r s t u
  .ble-edit.locate-current-uword "$x"
  if ((x>t&&(t=x),r!=t)); then
    .ble-edit.kill-range "$r" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble/widget/copy-forward-uword
##   前方の unix word を転写します。
function ble/widget/copy-forward-uword {
  # <x> *<s>w*<t> *<u>
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword
  .ble-edit.copy-range "$x" "$t"
}
## 関数 ble/widget/copy-backward-uword
##   後方の unix word を転写します。
function ble/widget/copy-backward-uword {
  # <a> *<b>w*<c> *<x>
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword
  .ble-edit.copy-range "$b" "$((c>x?c:x))"
}
## 関数 ble/widget/copy-uword
##   現在位置の unix word を転写します。
function ble/widget/copy-uword {
  local x="${1:-$_ble_edit_ind}" r s t u
  .ble-edit.locate-current-uword "$x"
  .ble-edit.copy-range "$r" "$((t>x?t:x))"
}

#%)
#%x kill-uword
#%x kill-uword.r/uword/cword/.r/unix word/c word/
#%x kill-uword.r/uword/sword/.r/unix word/shell word/
#%x kill-uword.r/uword/fword/.r/unix word/filename/
#%m forward-word (
function ble/widget/forward-uword {
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword "$x"
  if ((x==t)); then
    .ble-edit.bell
  else
    .ble-edit.goto-char "$t"
  fi
}
function ble/widget/backward-uword {
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword "$x"
  if ((x==b)); then
    .ble-edit.bell
  else
    .ble-edit.goto-char "$b"
  fi
}
#%)
#%x forward-word
#%x forward-word.r/uword/cword/.r/unix word/c word/
#%x forward-word.r/uword/sword/.r/unix word/shell word/

# **** ble-edit/exec ****                                            @edit.exec

declare -a _ble_edit_exec_lines=()
declare _ble_edit_exec_lastexit=0
function ble-edit/exec/register {
  local BASH_COMMAND="$1"
  ble/util/array-push _ble_edit_exec_lines "$1"
}
function ble-edit/exec/.setexit {
  # $? 変数の設定
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec/.adjust-eol {
  # 文末調整
  local cols="${COLUMNS:-80}"
  local -a DRAW_BUFF
  ble-edit/draw/put "$_ble_term_sc"
  ble-edit/draw/put "${_ble_term_setaf[12]}[ble: EOF]$_ble_term_sgr0"
  ble-edit/draw/put "$_ble_term_rc"
  ble-edit/draw/put.cuf "$((_ble_term_xenl?cols-2:cols-3))"
  ble-edit/draw/put "  $_ble_term_cr$_ble_term_el"
  ble-edit/draw/flush >&2
  _ble_line_x=0 _ble_line_y=0
}

## 関数 _ble_edit_exec_lines= ble-edit/exec:$bleopt_exec_type/process;
##   指定したコマンドを実行します。
## @param[in,out] _ble_edit_exec_lines
##   実行するコマンドの配列を指定します。実行したコマンドは削除するか空文字列を代入します。
## @return
##   戻り値が 0 の場合、終端 (ble-edit/bind/.tail) に対する処理も行われた事を意味します。
##   つまり、そのまま ble-decode-byte:bind から抜ける事を期待します。
##   それ以外の場合には終端処理をしていない事を表します。

#--------------------------------------
# bleopt_exec_type = exec
#--------------------------------------

function ble-edit/exec:exec/.eval-TRAPINT {
  builtin echo
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
    builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2"
    return 0
  else
    trap - DEBUG # 何故か効かない
    return 1
  fi
}

function ble-edit/exec:exec/.eval-prologue {
  ble-stty/leave

  set -H

  # C-c に対して
  trap 'ble-edit/exec:exec/.eval-TRAPINT; return 128' INT
  # trap '_ble_edit_exec_INT=126; return 126' TSTP
}
function ble-edit/exec:exec/.eval {
  local _ble_edit_exec_in_eval=1
  # BASH_COMMAND に return が含まれていても大丈夫な様に関数内で評価
  ble-edit/exec/.setexit
  builtin eval -- "$BASH_COMMAND"
}
function ble-edit/exec:exec/.eval-epilogue {
  trap - INT DEBUG # DEBUG 削除が何故か効かない

  ble-stty/enter
  _ble_edit_PS1="$PS1"

  ble-edit/exec/.adjust-eol

  # lastexit
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit="$_ble_edit_exec_INT"
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
## \param [in] index
function ble-edit/exec:exec/.recursive {
  (($1>=${#_ble_edit_exec_lines})) && return

  local BASH_COMMAND="${_ble_edit_exec_lines[$1]}"
  _ble_edit_exec_lines[$1]=
  if [[ ${BASH_COMMAND//[ 	]/} ]]; then
    # 実行
    local PS1="$_ble_edit_PS1" HISTCMD
    ble-edit/history/getcount -v HISTCMD

    local _ble_edit_exec_INT=0
    ble-edit/exec:exec/.eval-prologue
    ble-edit/exec:exec/.eval
    _ble_edit_exec_lastexit="$?"
    ble-edit/exec:exec/.eval-epilogue
  fi

  ble-edit/exec:exec/.recursive "$(($1+1))"
}

declare _ble_edit_exec_replacedDeclare=
declare _ble_edit_exec_replacedTypeset=
function ble-edit/exec:exec/.isGlobalContext {
  local offset="$1"

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
  #   local func="${FUNCNAME[i]}"
  #   local path="${BASH_SOURCE[i]}"
  #   if [[ $func = ble-edit/exec:exec/.eval && $path = $BASH_SOURCE ]]; then
  #     return 0
  #   elif [[ $path != source && $path != $BASH_SOURCE ]]; then
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
  ble-edit/exec:exec/.recursive 0

  _ble_edit_exec_lines=()

  # C-c で中断した場合など以下が実行されないかもしれないが
  # 次の呼出の際にここが実行されるのでまあ許容する。
  if [[ $_ble_edit_exec_replacedDeclare ]]; then
    _ble_edit_exec_replacedDeclare=
    unset declare
  fi
  if [[ $_ble_edit_exec_replacedTypeset ]]; then
    _ble_edit_exec_replacedTypeset=
    unset typeset
  fi
}

function ble-edit/exec:exec/process {
  ble-edit/exec:exec
  ble-edit/bind/.check-detach
  return $?
}

#--------------------------------------
# bleopt_exec_type = gexec
#--------------------------------------

function ble-edit/exec:gexec/.eval-TRAPINT {
  builtin echo
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

    local depth="${#FUNCNAME[*]}"
    local rex='^\ble-edit/exec:gexec/.'
    if ((depth>=2)) && ! [[ ${FUNCNAME[*]:depth-1} =~ $rex ]]; then
      # 関数内にいるが、ble-edit/exec:gexec/. の中ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2"
      return 0
    fi

    local rex='^(\ble-edit/exec:gexec/.|trap - )'
    if ((depth==1)) && ! [[ $BASH_COMMAND =~ $rex ]]; then
      # 一番外側で、ble-edit/exec:gexec/. 関数ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 $BASH_COMMAND $2"
      return 0
    fi
  fi

  trap - DEBUG # 何故か効かない
  return 1
}
function ble-edit/exec:gexec/.begin {
  _ble_decode_bind_hook=
  .ble-edit/stdout/on
  set -H

  # C-c に対して
  trap 'ble-edit/exec:gexec/.eval-TRAPINT' INT
}
function ble-edit/exec:gexec/.end {
  trap - INT DEBUG
  # ↑何故か効かないので、
  #   end の呼び出しと同じレベルで明示的に実行する。

  ble/util/joblist.flush >&2
  ble-edit/bind/.check-detach && return 0
  ble-edit/bind/.tail
}
function ble-edit/exec:gexec/.eval-prologue {
  BASH_COMMAND="$1"
  PS1="$_ble_edit_PS1"
  unset HISTCMD; ble-edit/history/getcount -v HISTCMD
  _ble_edit_exec_INT=0
  ble/util/joblist.clear
  ble-stty/leave
  ble-edit/exec/.setexit
}
function ble-edit/exec:gexec/.eval-epilogue {
  # lastexit
  _ble_edit_exec_lastexit="$?"
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit="$_ble_edit_exec_INT"
  fi
  _ble_edit_exec_INT=0

  unset -f builtin
  builtin unset -f builtin return break continue : eval echo

  trap - DEBUG # DEBUG 削除が何故か効かない

  ble-stty/enter
  _ble_edit_PS1="$PS1"
  PS1=
  ble-edit/exec/.adjust-eol

  if [ "$_ble_edit_exec_lastexit" -ne 0 ]; then
    # SIGERR処理
    if builtin type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      builtin echo "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0" 2>&1
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

  local apos=\' APOS="'\\''"
  local cmd
  local -a buff
  local count=0
  buff[${#buff[@]}]=ble-edit/exec:gexec/.begin
  for cmd in "${_ble_edit_exec_lines[@]}"; do
    if [[ "$cmd" == *[^' 	']* ]]; then
      buff[${#buff[@]}]="ble-edit/exec:gexec/.eval-prologue '${cmd//$apos/$APOS}'"
      buff[${#buff[@]}]="builtin eval -- '${cmd//$apos/$APOS}'"
      buff[${#buff[@]}]="ble-edit/exec:gexec/.eval-epilogue"
      ((count++))

      # ※直接 $cmd と書き込むと文法的に破綻した物を入れた時に
      #   下の行が実行されない事になってしまう。
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
  return $?
}

# **** accept-line ****                                            @edit.accept

function .ble-edit/newline {
  # 行更新
  .ble-line-info.clear
  .ble-edit-draw.update

  # 新しい行
  local -a DRAW_BUFF
  ble-edit/draw/goto "$_ble_line_endx" "$_ble_line_endy"
  ble-edit/draw/put "$_ble_term_nl"
  ble-edit/draw/flush >&2
  ble/util/joblist.flush >&2
  _ble_line_x=0 _ble_line_y=0
  ((LINENO=++_ble_edit_LINENO))

  # カーソルを表示する。
  # layer:overwrite でカーソルを消している時の為。
  [[ $_ble_edit_overwrite_mode ]] && builtin echo -n $'\e[?25h'

  _ble_edit_str.reset ''
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_dirty=-1
  _ble_edit_overwrite_mode=
}

function ble/widget/discard-line {
  _ble_edit_line_disabled=1 .ble-edit/newline
}

if ((_ble_bash>=30100)); then
  function ble-edit/hist_expanded/.expand {
    history -p -- "$BASH_COMMAND" 2>/dev/null || echo "$BASH_COMMAND"
    builtin echo -n :
  }
else
  function ble-edit/hist_expanded/.expand {
    (history -p -- "$BASH_COMMAND" 2>/dev/null || echo "$BASH_COMMAND")
    builtin echo -n :
  }
fi

## @var[out] hist_expanded
function ble-edit/hist_expanded.update {
  local BASH_COMMAND="$*"
  if [[ ! -o histexpand || ! ${BASH_COMMAND//[ 	]} ]]; then
    hist_expanded="$BASH_COMMAND"
    return 0
  elif ble/util/assign hist_expanded ble-edit/hist_expanded/.expand; then
    hist_expanded="${hist_expanded%$_ble_term_nl:}"
    return 0
  else
    return 1
  fi
}

function ble/widget/accept-line {
  local BASH_COMMAND="$_ble_edit_str"

  # 履歴展開
  local hist_expanded
  if ! ble-edit/hist_expanded.update "$BASH_COMMAND"; then
    .ble-edit-draw.set-dirty -1
    return
  fi

  _ble_edit_mark_active=
  .ble-edit/newline

  if [[ $hist_expanded != "$BASH_COMMAND" ]]; then
    BASH_COMMAND="$hist_expanded"
    builtin echo "${_ble_term_setaf[12]}[ble: expand]$_ble_term_sgr0 $BASH_COMMAND" 1>&2
  fi

  if [[ ${BASH_COMMAND//[ 	]} ]]; then
    ((++_ble_edit_CMD))

    # 編集文字列を履歴に追加
    ble-edit/history/add "$BASH_COMMAND"

    # 実行を登録
    ble-edit/exec/register "$BASH_COMMAND"
  fi
}

function ble/widget/accept-and-next {
  local hist_ind
  ble-edit/history/getindex -v hist_ind
  ble/widget/accept-line
  ble-edit/history/goto $((hist_ind+1))
}
function ble/widget/newline {
  KEYS=(10) ble/widget/self-insert
}
function ble/widget/accept-single-line-or-newline {
  if [[ $_ble_edit_str == *$'\n'* ]]; then
    ble/widget/newline
  else
    ble/widget/accept-line
  fi
}

# 
#------------------------------------------------------------------------------
# **** history ****                                                    @history

: ${bleopt_history_preserve_point=}
_ble_edit_history=()
_ble_edit_history_edit=()
_ble_edit_history_dirt=()
_ble_edit_history_ind=0

_ble_edit_history_loaded=
_ble_edit_history_count=

function ble-edit/history/getindex {
  local _var=index _ret
  [[ $1 == -v ]] && { _var="$2"; shift 2; }
  if [[ $_ble_edit_history_loaded ]]; then
    (($_var=_ble_edit_history_ind))
  else
    ble-edit/history/getcount -v "$_var"
  fi
}

function ble-edit/history/getcount {
  local _var=count _ret
  [[ $1 == -v ]] && { _var="$2"; shift 2; }

  if [[ $_ble_edit_history_loaded ]]; then
    _ret="${#_ble_edit_history[@]}"
  else
    if [[ ! $_ble_edit_history_count ]]; then
      _ble_edit_history_count=($(history 1))
    fi
    _ret="$_ble_edit_history_count"
  fi

  (($_var=_ret))
}

function ble-edit/history/.generate-source-to-load-history {
  if ! history -p '!1' &>/dev/null; then
    # rcfile として起動すると history が未だロードされていない。
    history -n
  fi
  HISTTIMEFORMAT=__ble_ext__

  # 285ms for 16437 entries
  local apos="'"
  history | command awk -v apos="'" '
    BEGIN{
      n="";
      print "_ble_edit_history=("
    }

    # ※rcfile として読み込むと HISTTIMEFORMAT が ?? に化ける。
    /^ *[0-9]+\*? +(__ble_ext__|\?\?)/{
      if(n!=""){
        n="";
        print "  " apos t apos;
      }

      n=$1;t="";
      sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/,"",$0);
    }
    {
      line=$0;
      if(line~/^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
        line=apos substr(line,9) apos;
      else
        gsub(apos,apos "\\" apos apos,line);

      t=t!=""?t "\n" line:line;
    }
    END{
      if(n!=""){
        n="";
        print "  " apos t apos;
      }

      print ")"
    }
  '
}

## called by ble-edit-initialize
function ble-edit/history/load {
  [[ $_ble_edit_history_loaded ]] && return
  _ble_edit_history_loaded=1

  if ((_ble_edit_attached)); then
    local x="$_ble_line_x" y="$_ble_line_y"
    .ble-line-info.draw-text "loading history..."

    local -a DRAW_BUFF
    ble-edit/draw/goto "$x" "$y"
    ble-edit/draw/flush >&2
  fi

  # * プロセス置換にしてもファイルに書き出しても大した違いはない。
  #   270ms for 16437 entries (generate-source の時間は除く)
  # * プロセス置換×source は bash-3 で動かない。eval に変更する。
  builtin eval -- "$(ble-edit/history/.generate-source-to-load-history)"
  _ble_edit_history_edit=("${_ble_edit_history[@]}")
  _ble_edit_history_count="${#_ble_edit_history[@]}"
  _ble_edit_history_ind="$_ble_edit_history_count"
  if ((_ble_edit_attached)); then
    .ble-line-info.clear
  fi
}

function ble-edit/history/add {
  [[ -o history ]] || return

  if [[ $_ble_edit_history_loaded ]]; then
    # 登録・不登録に拘わらず取り敢えず初期化
    _ble_edit_history_ind=${#_ble_edit_history[@]}

    # _ble_edit_history_edit を未編集状態に戻す
    local index
    for index in "${!_ble_edit_history_dirt[@]}"; do
      _ble_edit_history_edit[index]="${_ble_edit_history[index]}"
    done
    _ble_edit_history_dirt=()
  fi

  local cmd="$1"
  if [[ $HISTIGNORE ]]; then
    local i pats pat
    GLOBIGNORE='*' IFS=: builtin eval 'pats=($HISTIGNORE)'
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return
    done
  fi

  local histfile=

  if [[ $_ble_edit_history_loaded ]]; then
    if [[ $HISTCONTROL ]]; then
      local lastIndex=$((${#_ble_edit_history[@]}-1)) spec
      for spec in ${HISTCONTROL//:/ }; do
        case "$spec" in
        ignorespace)
          [[ ! ${cmd##[ 	]*} ]] && return ;;
        ignoredups)
          if ((lastIndex>=0)); then
            [[ $cmd == "${_ble_edit_history[lastIndex]}" ]] && return
          fi ;;
        ignoreboth)
          [[ ! ${cmd##[ 	]*} ]] && return
          if ((lastIndex>=0)); then
            [[ $cmd == "${_ble_edit_history[lastIndex]}" ]] && return
          fi ;;
        erasedups)
          local i n=-1
          for ((i=0;i<=lastIndex;i++)); do
            if [[ ${_ble_edit_history[i]} != "$cmd" ]]; then
              ((++n!=i)) && _ble_edit_history[n]="${_ble_edit_history[i]}"
            fi
          done
          for ((i=lastIndex;i>n;i--)); do
            unset '_ble_edit_history[i]'
          done
          ;;
        esac
      done
    fi

    _ble_edit_history[${#_ble_edit_history[@]}]="$cmd"
    _ble_edit_history_edit[${#_ble_edit_history_edit[@]}]="$cmd"
    _ble_edit_history_count="${#_ble_edit_history[@]}"
    _ble_edit_history_ind="$_ble_edit_history_count"

    # _ble_bash<30100 の時は必ずここを通る。
    # 始めに _ble_edit_history_loaded=1 になるので。
    ((_ble_bash<30100)) && histfile="${HISTFILE:-$HOME/.bash_history}"
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
    ble/util/sprintf cmd 'eval -- %q' "$cmd"
  fi

  if [[ $histfile ]]; then
    builtin printf '%s\n' "$cmd" >> "$histfile"
  else
    history -s -- "$cmd"
  fi
}

function ble-edit/history/goto {
  ble-edit/history/load

  local histlen=${#_ble_edit_history[@]}
  local index0="$_ble_edit_history_ind"
  local index1="$1"

  ((index0==index1)) && return

  if ((index1>histlen)); then
    index1=histlen
    .ble-edit.bell
  elif ((index1<0)); then
    index1=0
    .ble-edit.bell
  fi

  ((index0==index1)) && return

  # store
  if [[ ${_ble_edit_history_edit[index0]} != "$_ble_edit_str" ]]; then
    _ble_edit_history_edit[index0]="$_ble_edit_str"
    _ble_edit_history_dirt[index0]=1
  fi

  # restore
  _ble_edit_history_ind="$index1"
  _ble_edit_str.reset "${_ble_edit_history_edit[index1]}"

  # point
  if [[ $bleopt_history_preserve_point ]]; then
    if ((_ble_edit_ind>"${#_ble_edit_str}")); then
      _ble_edit_ind="${#_ble_edit_str}"
    fi
  else
    _ble_edit_ind="${#_ble_edit_str}"
  fi
  _ble_edit_mark=0
  _ble_edit_mark_active=
}

function ble/widget/history-next {
  ble-edit/history/load
  ble-edit/history/goto $((_ble_edit_history_ind+1))
}
function ble/widget/history-prev {
  ble-edit/history/load
  ble-edit/history/goto $((_ble_edit_history_ind-1))
}
function ble/widget/history-beginning {
  ble-edit/history/load
  ble-edit/history/goto 0
}
function ble/widget/history-end {
  ble-edit/history/load
  ble-edit/history/goto "${#_ble_edit_history[@]}"
}

function ble/widget/history-expand-line {
  local hist_expanded
  ble-edit/hist_expanded.update "$_ble_edit_str" || return
  [[ $_ble_edit_str == $hist_expanded ]] && return

  _ble_edit_str.reset "$hist_expanded"
  _ble_edit_ind="${#hist_expanded}"
  _ble_edit_mark=0
  _ble_edit_mark_active=
}
function ble/widget/magic-space {
  KEYS=(32) ble/widget/self-insert

  local prevline="${_ble_edit_str::_ble_edit_ind}" hist_expanded
  ble-edit/hist_expanded.update "$prevline" || return
  [[ $prevline == $hist_expanded ]] && return

  _ble_edit_str.replace 0 _ble_edit_ind "$hist_expanded"
  _ble_edit_ind="${#hist_expanded}"
  _ble_edit_mark=0
  _ble_edit_mark_active=
  #ble/widget/history-expand-line
}

function ble/widget/forward-line-or-history-next {
  ble/widget/forward-line || ble/widget/history-next
}
function ble/widget/backward-line-or-history-prev {
  ble/widget/backward-line || ble/widget/history-prev
}


# 
# **** incremental search ****                                 @history.isearch

## 変数 _ble_edit_isearch_str
##   一致した文字列
## 変数 _ble_edit_isearch_dir
##   現在・直前の検索方法
## 配列 _ble_edit_isearch_arr
##   検索履歴
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
    ll="<<" rr="  "
  else
    ll="  " rr=">>"
    text="  >>)"
  fi
  local text="(${#_ble_edit_isearch_arr[@]}: $ll $_ble_edit_history_ind $rr) \`$_ble_edit_isearch_str'"

  if [[ $1 ]]; then
    local pos="$1"
    local percentage="$((pos*1000/${#_ble_edit_history_edit[@]}))"
    text="$text searching... @$pos ($((percentage/10)).$((percentage%10))%)"
    ((isearch_ntask)) && text="$text *$isearch_ntask"
  fi

  .ble-line-info.draw-text "$text"
}

function ble-edit/isearch/.draw-line {
  ble-edit/isearch/.draw-line-with-progress
}
function ble-edit/isearch/.erase-line {
  .ble-line-info.clear
}
function ble-edit/isearch/.set-region {
  local beg="$1" end="$2"
  if ((beg<end)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      _ble_edit_ind="$beg"
      _ble_edit_mark="$end"
    else
      _ble_edit_ind="$end"
      _ble_edit_mark="$beg"
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
  local hash="$beg:$end:$needle"

  # [... A | B] -> A と来た時 (A を _ble_edit_isearch_arr から削除) [... | A] になる。
  local ilast="$((${#_ble_edit_isearch_arr[@]}-1))"
  if ((ilast>=0)) && [[ ${_ble_edit_isearch_arr[ilast]} == "$ind:"[-+]":$hash" ]]; then
    unset "_ble_edit_isearch_arr[$ilast]"
    return
  fi

  local oind="$_ble_edit_history_ind"
  local obeg="$_ble_edit_ind" oend="$_ble_edit_mark" tmp
  ((obeg<=oend||(tmp=obeg,obeg=oend,oend=tmp)))
  local oneedle="$_ble_edit_isearch_str"
  local ohash="$obeg:$oend:$oneedle"

  # [... A | B] -> B と来た時 (何もしない) [... A | B] になる。
  [[ $ind == "$oind" && $hash == "$ohash" ]] && return

  # [... A | B] -> C と来た時 (B を _ble_edit_isearch_arr に移動) [... A B | C] になる。
  ble/util/array-push _ble_edit_isearch_arr "$oind:$_ble_edit_isearch_dir:$ohash"
}
function ble-edit/isearch/.goto-match {
  local ind="$1" beg="$2" end="$3" needle="$4"
  ((beg==end&&(beg=end=-1)))

  # 検索履歴に待避 (変数 ind beg end needle 使用)
  ble-edit/isearch/.push-isearch-array

  # 状態を更新
  _ble_edit_isearch_str="$needle"
  [[ $_ble_edit_history_ind != $ind ]] &&
    ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"

  # isearch 表示
  ble-edit/isearch/.draw-line
  _ble_edit_bind_force_draw=1
}

function ble-edit/isearch/next.fib {
  local needle="${1-$_ble_edit_isearch_str}" isMod="$2"
  local ind="$_ble_edit_history_ind" beg= end=

  # 現在位置における伸張
  if ((isMod)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      if [[ ${_ble_edit_str:_ble_edit_ind} == "$needle"* ]]; then
        beg="$_ble_edit_ind"
        end="$((beg+${#needle}))"
      fi
    else
      if [[ ${_ble_edit_str:_ble_edit_mark} == "$needle"* ]]; then
        beg="$_ble_edit_mark"
        end="$((beg+${#needle}))"
      fi
    fi

    if [[ $beg ]]; then
      ble-edit/isearch/.goto-match "$ind" "$beg" "$end" "$needle"
      return
    fi
  fi

  # 次の候補
  if [[ $_ble_edit_isearch_dir == - ]]; then
    local target="${_ble_edit_str::_ble_edit_ind}"
    local m="${target%"$needle"*}"
    if [[ $target != "$m" ]]; then
      beg="${#m}"
      end="$((beg+${#needle}))"
    fi
  else
    local target="${_ble_edit_str:_ble_edit_ind}"
    local m="${target#*"$needle"}"
    if [[ $target != "$m" ]]; then
      end="$((${#_ble_edit_str}-${#m}))"
      beg="$((end-${#needle}))"
    fi
  fi

  if [[ $beg ]]; then
    ble-edit/isearch/.goto-match "$ind" "$beg" "$end" "$needle"
    return
  else
    ble-edit/isearch/next-history.fib "${@:1:1}"
  fi
}

## 関数 ble-edit/isearch/next-history.fib [needle isMod]
##
##   @var[in,out] isearch_suspend
##     中断した時にこの変数に再開用のデータを格納します。
##     再開する時はこの変数の中断時の内容を復元してこの関数を呼び出します。
##     この変数が空の場合は新しい検索を開始します。
##   @param[in,opt] needle,isMod
##     新しい検索を開始する場合に、検索対象を明示的に指定します。
##     needle に検索対象の文字列を指定します。
##     isMod 現在の履歴項目を検索対象とするかどうかを指定します。
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
## 関数 ble-edit/isearch/next-history/.blockwise-backward-search
##   work around for bash slow array access: blockwise search
##   @var[in,out] i ind susp
##   @var[in,out] isearch_time
##   @var[in] _ble_edit_history_edit start
##
function ble-edit/isearch/next-history/.blockwise-backward-search {
  local NSTPCHK=1000 # 十分高速なのでこれぐらい大きくてOK
  local NPROGRESS=$((NSTPCHK*2)) # 倍数である必要有り
  local irest block j
  while ((i>=0)); do
    ((block=start-i,
      block<5&&(block=5),
      irest=NSTPCHK-isearch_time%NSTPCHK,
      block>i+1&&(block=i+1),
      block>irest&&(block=irest)))

    for ((j=i-block;++j<=i;)); do
      if [[ ${_ble_edit_history_edit[j]} == *"$needle"* ]]; then
        ind="$j"
      fi
    done

    ((isearch_time+=block))
    if [[ $ind ]]; then
      ((i=j))
    else
      ((i-=block))
    fi

    if [[ $ind ]]; then
      break
    elif ((isearch_time%NSTPCHK==0)) && ble/util/is-stdin-ready; then
      susp=1
      break
    elif ((isearch_time%NPROGRESS==0)); then
      ble-edit/isearch/.draw-line-with-progress "$i"
    fi
  done
}
function ble-edit/isearch/next-history.fib {
  if [[ $isearch_suspend ]]; then
    # resume the previous search
    local needle="${isearch_suspend#*:}" isMod=
    local i start; eval "${isearch_suspend%%:*}"
    isearch_suspend=
  else
    # initialize new search
    local needle="${1-$_ble_edit_isearch_str}" isMod="$2"
    local start="$_ble_edit_history_ind"
    local i="$start"
  fi

  local dir="$_ble_edit_isearch_dir"
  if [[ $dir == - ]]; then
    # backward-search
    local x_cond='i>=0' x_incr='i--'
  else
    # forward-search
    local x_cond="i<${#_ble_edit_history_edit[@]}" x_incr='i++'
  fi
  ((isMod||x_incr))

  # 検索
  local ind= susp=
  if [[ $dir == - ]]; then
    ble-edit/isearch/next-history/.blockwise-backward-search
  else
    for ((;x_cond;x_incr)); do
      if ((++isearch_time%100==0)) && ble/util/is-stdin-ready; then
        susp=1
        break
      fi
      if [[ ${_ble_edit_history_edit[i]} == *"$needle"* ]]; then
        ind="$i"
        break
      fi

      if ((isearch_time%1000==0)); then
        ble-edit/isearch/.draw-line-with-progress "$i"
      fi
    done
  fi

  if [[ $ind ]]; then
    # 見付かった場合

    # 一致範囲 beg-end を取得
    local str="${_ble_edit_history_edit[ind]}"
    if [[ $_ble_edit_isearch_dir == - ]]; then
      local prefix="${str%"$needle"*}"
    else
      local prefix="${str%%"$needle"*}"
    fi
    local beg="${#prefix}" end="$((${#prefix}+${#needle}))"

    ble-edit/isearch/.goto-match "$ind" "$beg" "$end" "$needle"
  elif [[ $susp ]]; then
    # 中断した場合
    isearch_suspend="i=$i start=$start:$needle"
    return
  else
    # 見つからなかった場合
    .ble-edit.bell "isearch: \`$needle' not found"
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
  local code="$1"
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
  local code="$1"
  ((code==0)) && return
  local ret needle
  ble/util/c2s "$code"
  ble-edit/isearch/next-history.fib "$_ble_edit_isearch_str$ret" 1
}

function ble-edit/isearch/prev {
  local sz="${#_ble_edit_isearch_arr[@]}"
  ((sz==0)) && return 0

  local ilast=$((sz-1))
  local top="${_ble_edit_isearch_arr[ilast]}"
  unset "_ble_edit_isearch_arr[$ilast]"

  local ind dir beg end
  ind="${top%%:*}"; top="${top#*:}"
  dir="${top%%:*}"; top="${top#*:}"
  beg="${top%%:*}"; top="${top#*:}"
  end="${top%%:*}"; top="${top#*:}"

  _ble_edit_isearch_dir="$dir"
  ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"
  _ble_edit_isearch_str="$top"

  # isearch 表示
  ble-edit/isearch/.draw-line
}

function ble-edit/isearch/process {
  _ble_edit_isearch_que=()

  local isearch_suspend=
  local isearch_time=0
  local isearch_ntask="$#"
  while (($#)); do
    ((isearch_ntask--))
    case "$1" in
    (sf)  ble-edit/isearch/forward.fib ;;
    (sb)  ble-edit/isearch/backward.fib ;;
    (si*) ble-edit/isearch/self-insert.fib "${1:2}";;
    (hf)  ble-edit/isearch/history-forward.fib ;;
    (hb)  ble-edit/isearch/history-backward.fib ;;
    (hi*) ble-edit/isearch/history-self-insert.fib "${1:2}";;
    (z*)  isearch_suspend="${1:1}"
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
  local code="${KEYS[0]&ble_decode_MaskChar}"
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" "si$code"
}
function ble/widget/isearch/history-forward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" hf
}
function ble/widget/isearch/history-backward {
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" hb
}
function ble/widget/isearch/history-self-insert {
  local code="${KEYS[0]&ble_decode_MaskChar}"
  ble-edit/isearch/process "${_ble_edit_isearch_que[@]}" "hi$code"
}
function ble/widget/isearch/prev {
  local nque
  if ((nque=${#_ble_edit_isearch_que[@]})); then
    unset _ble_edit_isearch_que[nque-1]
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
      local line="${_ble_edit_isearch_arr[0]}"
      ble-edit/history/goto "${line%%:*}"
    fi

    ble/widget/isearch/exit
  fi
}
function ble/widget/isearch/exit-default {
  ble/widget/isearch/exit

  for key in "${KEYS[@]}"; do
    ble-decode-key "$key"
  done
}
function ble/widget/isearch/accept {
  if ((${#_ble_edit_isearch_que[@]})); then
    .ble-edit.bell "isearch: now searching..."
  else
    ble/widget/isearch/exit
    ble/widget/accept-line
  fi
}
function ble/widget/isearch/exit-delete-forward-char {
  ble/widget/isearch/exit
  ble/widget/delete-forward-char
}

function ble/widget/history-isearch-backward {
  ble-edit/history/load
  ble-decode/keymap/push isearch
  _ble_edit_isearch_dir=-
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_que=()
  ble-edit/isearch/.draw-line
}
function ble/widget/history-isearch-forward {
  ble-edit/history/load
  ble-decode/keymap/push isearch
  _ble_edit_isearch_dir=+
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_que=()
  ble-edit/isearch/.draw-line
}

# 
#------------------------------------------------------------------------------
# **** completion ****                                                    @comp

ble-autoload "$_ble_base/complete.sh" ble/widget/complete

function ble/widget/command-help {
  local -a args
  args=($_ble_edit_str)
  local cmd="${args[0]}"

  if [[ ! $cmd ]]; then
    .ble-edit.bell
    return 1
  fi

  if ! type -t "$cmd" &>/dev/null; then
    .ble-edit.bell "command \`$cmd' not found"
    return 1
  fi

  local content
  if content="$("$cmd" --help 2>&1)" && [[ $content ]]; then
    builtin printf '%s\n' "$content" | ble/util/less
    return
  fi

  if content="$(command man "$cmd" 2>&1)" && [[ $content ]]; then
    builtin printf '%s\n' "$content" | ble/util/less
    return
  fi

  .ble-edit.bell "help of \`$cmd' not found"
  return 1
}

# 
#------------------------------------------------------------------------------
# **** bash key binder ****                                               @bind

# **** binder ****                                                   @bind.bind

function .ble-edit/stdout/on { :;}
function .ble-edit/stdout/off { :;}
function .ble-edit/stdout/finalize { :;}

if [[ $bleopt_suppress_bash_output ]]; then
  declare _ble_edit_io_stdout
  declare _ble_edit_io_stderr
  if ((_ble_bash>40100)); then
    exec {_ble_edit_io_stdout}>&1
    exec {_ble_edit_io_stderr}>&2
  else
    ble/util/openat _ble_edit_io_stdout '>&1'
    ble/util/openat _ble_edit_io_stderr '>&2'
  fi
  declare _ble_edit_io_fname1="$_ble_base_tmp/$$.stdout"
  declare _ble_edit_io_fname2="$_ble_base_tmp/$$.stderr"

  function .ble-edit/stdout/on {
    exec 1>&$_ble_edit_io_stdout 2>&$_ble_edit_io_stderr
  }
  function .ble-edit/stdout/off {
    .ble-edit/stdout/check-stderr
    exec 1>>$_ble_edit_io_fname1 2>>$_ble_edit_io_fname2
  }
  function .ble-edit/stdout/finalize {
    .ble-edit/stdout/on
    [[ -f $_ble_edit_io_fname1 ]] && command rm -f "$_ble_edit_io_fname1"
    [[ -f $_ble_edit_io_fname2 ]] && command rm -f "$_ble_edit_io_fname2"
  }

  ## 関数 .ble-edit/stdout/check-stderr
  ##   bash が stderr にエラーを出力したかチェックし表示する。
  function .ble-edit/stdout/check-stderr {
    local file="${1:-$_ble_edit_io_fname2}"

    # if the visible bell function is already defined.
    if ble/util/isfunction ble-term/visible-bell; then
      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   /dev/null の様なデバイスではなく、中身があるファイルの場合。
      if [[ -f $file && -s $file ]]; then
        local message= line
        while IFS= read -r line || [[ $line ]]; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   例えば ~/bin/bash-3.1 等から実行していると
          #   "bash-3.1: ～" 等というエラーメッセージになる。
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* ]]; then
            message="$message${message:+; }$line"
          fi
        done < "$file"

        [[ $message ]] && ble-term/visible-bell "$message"
        : >| "$file"
      fi
    fi
  }

  # * bash-3.1, bash-3.2, bash-4.0 では C-d は直接検知できない。
  #   IGNOREEOF を設定しておくと C-d を押した時に
  #   stderr に bash が文句を吐くのでそれを捕まえて C-d が押されたと見做す。
  if ((_ble_bash<40000)); then
    function .ble-edit/stdout/trap-SIGUSR1 {
      local file="$_ble_edit_io_fname2.proc"
      if [[ -s $file ]]; then
        content="$(< $file)"
        : >| "$file"
        for cmd in $content; do
          case "$cmd" in
          (eof)
            # C-d
            ble-decode-byte:bind 4 ;;
          esac
        done
      fi
    }

    trap -- '.ble-edit/stdout/trap-SIGUSR1' USR1

    command rm -f "$_ble_edit_io_fname2.pipe"
    command mkfifo "$_ble_edit_io_fname2.pipe"
    {
      {
        function ble-edit/stdout/check-ignoreeof-message {
          local line="$1"

          [[ $line = *$bleopt_ignoreeof_message* ||
               $line = *'Use "exit" to leave the shell.'* ||
               $line = *'ログアウトする為には exit を入力して下さい'* ||
               $line = *'シェルから脱出するには "exit" を使用してください。'* ||
               $line = *'シェルから脱出するのに "exit" を使いなさい.'* ||
               $line = *'Gebruik Kaart na Los Tronk'* ]] && return 0

          # ignoreeof-messages.txt の中身をキャッシュする様にする?
          [[ $line == *exit* ]] && command grep -q -F "$line" "$_ble_base"/ignoreeof-messages.txt
        }

        while IFS= read -r line; do
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

    function .ble-edit/stdout/off {
      .ble-edit/stdout/check-stderr
      exec 1>>$_ble_edit_io_fname1 2>&$_ble_edit_fd_stderr_pipe
    }
  fi
fi

_ble_edit_detach_flag=
function ble-edit/bind/.exit-trap {
  # シグナルハンドラの中では stty は bash によって設定されている。
  ble-stty/exit-trap
  exit 0
}
function ble-edit/bind/.check-detach {
  if [[ $_ble_edit_detach_flag ]]; then
    type="$_ble_edit_detach_flag"
    _ble_edit_detach_flag=
    #ble-term/visible-bell ' Bye!! '
    .ble-edit-finalize
    ble-decode-detach
    ble-stty/finalize

    READLINE_LINE="" READLINE_POINT=0

    if [[ "$type" == exit ]]; then
      # ※この部分は現在使われていない。
      #   exit 時の処理は trap EXIT を用いて行う事に決めた為。
      #   一応 _ble_edit_detach_flag=exit と直に入力する事で呼び出す事はできる。

      # exit
      builtin echo "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0" 1>&2
      .ble-edit-draw.update

      # bind -x の中から exit すると bash が stty を「前回の状態」に復元してしまう様だ。
      # シグナルハンドラの中から exit すれば stty がそのままの状態で抜けられる様なのでそうする。
      trap 'ble-edit/bind/.exit-trap' RTMAX
      kill -RTMAX $$
    else
      builtin echo "${_ble_term_setaf[12]}[ble: detached]$_ble_term_sgr0" 1>&2
      builtin echo "Please run \`stty sane' to recover the correct TTY state." >&2
      .ble-edit-draw.update
      READLINE_LINE='stty sane' READLINE_POINT=9
    fi
    return 0
  else
    return 1
  fi
}

if ((_ble_bash>=40100)); then
  function ble-edit/bind/.head {
    .ble-edit/stdout/on

    if [[ -z $bleopt_suppress_bash_output ]]; then
      .ble-edit-draw.redraw-cache # bash-4.1 以降では呼出直前にプロンプトが消される
    fi
  }
else
  function ble-edit/bind/.head {
    .ble-edit/stdout/on

    if [[ -z $bleopt_suppress_bash_output ]]; then
      # bash-3.*, bash-4.0 では呼出直前に次の行に移動する
      ((_ble_line_y++,_ble_line_x=0))
      local -a DRAW_BUFF=()
      ble-edit/draw/goto "${_ble_edit_cur[0]}" "${_ble_edit_cur[1]}"
      ble-edit/draw/flush
    fi
  }
fi

function ble-edit/bind/.tail-without-draw {
  .ble-edit/stdout/off
}

if ((_ble_bash>40000)); then
  function ble-edit/bind/.tail {
    .ble-edit-draw.update-adjusted
    .ble-edit/stdout/off
  }
else
  IGNOREEOF=10000
  function ble-edit/bind/.tail {
    .ble-edit-draw.update # bash-3 では READLINE_LINE を設定する方法はないので常に 0 幅
    .ble-edit/stdout/off
  }
fi

_ble_edit_bind_force_draw=

## 関数 ble-decode-byte:bind/PROLOGUE
function ble-decode-byte:bind/PROLOGUE {
  ble-edit/bind/.head
  ble-decode-bind/uvw
  ble-stty/enter
  _ble_edit_bind_force_draw=
}

## 関数 ble-decode-byte:bind/EPILOGUE
function ble-decode-byte:bind/EPILOGUE {
  if ((_ble_bash>=40000)); then
    # 貼付対策:
    #   大量の文字が入力された時に毎回再描画をすると滅茶苦茶遅い。
    #   次の文字が既に来て居る場合には描画処理をせずに抜ける。
    #   (再描画は次の文字に対する bind 呼出でされる筈。)
    if [[ ! $_ble_edit_bind_force_draw ]] && ble/util/is-stdin-ready; then
      ble-edit/bind/.tail-without-draw
      return 0
    fi
  fi

  # _ble_decode_bind_hook で bind/tail される。
  "ble-edit/exec:$bleopt_exec_type/process" && return 0

  ble-edit/bind/.tail
  return 0
}

## 関数 ble/widget/.shell-command command
##   ble-bind -cf で登録されたコマンドを処理します。
function ble/widget/.shell-command {
  local -a BASH_COMMAND
  BASH_COMMAND=("$*")
  .ble-line-info.clear
  .ble-edit-draw.update

  local -a DRAW_BUFF
  ble-edit/draw/goto "$_ble_line_endx" "$_ble_line_endy"
  ble-edit/draw/put "$_ble_term_nl"
  ble-edit/draw/flush >&2
  ble/util/joblist.flush >&2
  _ble_line_x=0 _ble_line_y=0
  ((LINENO=++_ble_edit_LINENO))

  # やはり通常コマンドはちゃんとした環境で評価するべき
  if [[ "${BASH_COMMAND//[ 	]/}" ]]; then
    ble-edit/exec/register "$BASH_COMMAND"
  fi

  .ble-edit-draw.set-dirty -1
}

## 関数 ble/widget/.edit-command command
##   ble-bind -xf で登録されたコマンドを処理します。
function ble/widget/.edit-command {
  local READLINE_LINE="$_ble_edit_str"
  local READLINE_POINT="$_ble_edit_ind"
  eval "$command" || return 1

  [[ $READLINE_LINE != $_ble_edit_str ]] &&
    _ble_edit_str.reset-and-check-dirty "$READLINE_LINE"
  [[ $READLINE_POINT != $_ble_edit_ind ]] &&
    .ble-edit.goto-char "$READLINE_POINT"
}

function .ble-edit.default-key-bindings {
  if [[ $_ble_base_cache/keymap.emacs -nt $_ble_base/keymap/emacs.sh &&
          $_ble_base_cache/keymap.emacs -nt $_ble_base/cmap/default.sh ]]; then
    source "$_ble_base_cache/keymap.emacs"
  else
    source "$_ble_base/keymap/emacs.sh"
  fi
}

function ble-edit-initialize {
  ble-edit/prompt/initialize
}
function ble-edit-attach {
  if ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
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

  .ble-edit/edit/attach
}
function .ble-edit-finalize {
  .ble-edit/stdout/finalize
  .ble-edit/edit/detach
}
