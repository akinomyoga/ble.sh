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
## 定義 .ble-text.c2w+$bleopt_char_width_mode
: ${bleopt_char_width_mode:=emacs}

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

## オプション bleopt_exec_type (内部使用)
##   コマンドの実行の方法を指定します。
## bleopt_exec_type=exec
##   関数内で実行します (従来の方法です。将来的に削除されます)
## bleopt_exec_type=gexec
##   グローバルな文脈で実行します (新しい方法です。現在テスト中です)
## 定義 .ble-edit+accept-line/process+$bleopt_exec_type
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

## \param [out] ret
function .ble-text.c2w {
  # ret="${_ble_text_c2w__table[$1]}"
  # test -n "$ret" && return
  ".ble-text.c2w+$bleopt_char_width_mode" "$1"
  # _ble_text_c2w__table[$1]="$ret"
}
## \param [out] ret
function .ble-text.s2w {
  .ble-text.s2c "$1" "$2"
  ".ble-text.c2w+$bleopt_char_width_mode" "$ret"
}

## 関数 .ble-text.c2w+emacs
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
function .ble-text.c2w+emacs {
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

  test -z "$tIndex" && return 0

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

## 関数 .ble-text.c2w+west
function .ble-text.c2w.ambiguous {
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
function .ble-text.c2w+west {
  .ble-text.c2w.ambiguous "$1"
  (((ret<0)&&(ret=1)))
}

## 関数 .ble-text.c2w+east
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
function .ble-text.c2w+east {
  .ble-text.c2w.ambiguous "$1"
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
# **** cursor position ****                                           @line.pos

# function _medit.movePositionWithEditText {
#   # 編集文字列は bash によって加工されてから出力される
#   local text="$1"
#   local cols=${COLUMNS-80} it=$_ble_term_it xenl=$_ble_term_xenl
#   local i iN=${#text} code ret _x
#   for ((i=0;i<iN;i++)); do
#     .ble-text.s2c "$text" "$i"

#     local cw=0
#     if ((code<32)); then
#       if ((code==9)); then
#         # \t 右端に行った時も以下の式で良い様だ
#         ((cw=(x+it)/it*it-x))
#       elif ((code==10)); then
#         # \n
#         ((y++,x=0))
#         continue
#       else
#         cw=2
#       fi
#     elif ((code==127)); then
#       cw=2
#     else
#       .ble-text.c2w "$code"
#       cw=$ret
#     fi

#     ((x+=cw))
#     while ((x>=cols)); do
#       ((y++,x-=cols))
#     done
#   done
# }

# 
# **** prompt ****                                                    @line.ps1

## 関数 x y lc; .ble-line-cur.xyc/add-text text ; x y lc
##   指定した文字列を直接出力した時のカーソル位置の移動を計算します。
## \param [in]     text 出力する文字列
## \param [in.out] x    text を出力した後の cursor の x 座標
## \param [in.out] y    text を出力した後の cursor の y 座標
## \param [in.out] lc   text を出力した後の cursor の左にある文字のコード
function .ble-line-cur.xyc/add-text {
  local text="$1"
  local cols=${COLUMNS-80} it=$_ble_term_it xenl=$_ble_term_xenl
  local i iN=${#text} ret
  for ((i=0;i<iN;i++)); do
    .ble-text.s2c "$text" "$i"
    local code="$ret"

    local cw=0
    if ((code<32)); then
      case "$code" in
      8) ((x>0&&(x--,lc=32))) ;; # BS
      9) # HT
        local _x
        ((
          _x=(x+it)/it*it,
          _x>=cols&&(_x=cols-1),
          (x<_x)&&(x=_x,lc=32)
        )) ;;
      10) ((y++,x=0)) ;; # LF
      11) ((y++,lc=32)) ;; # VT
      13) x=0 ;; # CR
      esac
    elif ((code==127)); then
      cw=0
    else
      .ble-text.c2w "$code"
      cw=$ret
    fi

    ((cw==0)) && continue

    lc="$code"

    (((x+cw<=cols)?(x+=cw):(y++,x=cw)))
    while ((xenl?x>cols:x>=cols)); do
      ((y++,x-=cols))
    done
  done
}

## 関数 x y lc _ps1txt _ps1esc _suppress ; .ble-cursor.construct-prompt.append esc txt? ; x y lc _ps1txt _ps1esc
## \param [in]     esc
## \param [in]     txt
## \param [in,out] x
## \param [in,out] y
## \param [in,out] lc
## \param [in]     _suppress
## \param [in,out] _ps1txt
## \param [in,out] _ps1esc
function .ble-cursor.construct-prompt.append {
  local esc="$1" txt="${2-$1}"
  [ -z "$esc" ] && return

  _ps1esc="$_ps1esc$esc"
  if [ -z "$_suppress" ]; then
    _ps1txt="$_ps1txt$txt"
    .ble-line-cur.xyc/add-text "$txt"
  fi
}

## called by ble-edit-initialize
function .ble-cursor.construct-prompt.initialize {
  # hostname
  _ble_cursor_prompt__string_h="${HOSTNAME%%.*}"
  _ble_cursor_prompt__string_H="${HOSTNAME}"

  # tty basename
  local tmp=$(tty 2>/dev/null)
  _ble_cursor_prompt__string_l="${tmp##*/}"

  # command name
  _ble_cursor_prompt__string_s="${0##*/}"

  # user
  _ble_cursor_prompt__string_u="${USER}"

  # bash versions
  .ble-text.sprintf _ble_cursor_prompt__string_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  .ble-text.sprintf _ble_cursor_prompt__string_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if test "$EUID" -eq 0; then
    _ble_cursor_prompt__string_root='#'
  else
    _ble_cursor_prompt__string_root='$'
  fi
}

_ble_line_prompt=("" 0 0 32 "")
## 変数 _ble_line_prompt
##   構築した prompt の情報をキャッシュします。
## _ble_line_prompt[0] version  prompt 情報を作成した時の _ble_edit_LINENO
## _ble_line_prompt[1] x   prompt を表示し終わった時のカーソル x 座標
## _ble_line_prompt[2] y   prompt を表示し終わった時のカーソル y 座標
## _ble_line_prompt[3] lc  prompt を表示し終わった時のカーソルの右側にある文字
## _ble_line_prompt[4] ret prompt として出力する制御シーケンス
## _ble_line_prompt[5] txt prompt として出力する文字列 (制御部分 \[...\] を除いた物)

## @var[in,out] tail
## @var[in,out] i
## @var[in,out] _suprress
function .ble-cursor.construct-prompt/process-backslash {
  ((i+=2))

  # \\ の次の文字
  local c="${tail:1:1}"
  case "$c" in
  (\[) _suppress=1 ;;
  (\]) _suppress= ;;
  ('#') # コマンド番号 (本当は history に入らない物もある…)
    .ble-cursor.construct-prompt.append "$_ble_edit_CMD" ;;
  (\!) # 履歴番号
    .ble-cursor.construct-prompt.append "${#_ble_edit_history[@]}" ;;
  ([0-7]) # 8進表現
    local rex='^\\[0-7]{1,3}'
    if [[ $tail =~ $rex ]]; then
      local seq="${BASH_REMATCH[0]}"
      ((i+=${#seq}-2))
      eval "c=\$'$seq'"
    fi
    .ble-cursor.construct-prompt.append "$c" ;;
  (a) # 0 BEL
    .ble-cursor.construct-prompt.append "" ;;
  (d) # ? 日付
    [[ $date_d ]] || ble/util/strftime -v date_d '%a %b %d'
    .ble-cursor.construct-prompt.append "$date_d" ;;
  (t) # 8 時刻
    [[ $date_t ]] || ble/util/strftime -v date_t '%H:%M:%S'
    .ble-cursor.construct-prompt.append "$date_t" ;;
  (A) # 5 時刻
    [[ $date_A ]] || ble/util/strftime -v date_A '%H:%M'
    .ble-cursor.construct-prompt.append "$date_A" ;;
  (T) # 8 時刻
    [[ $date_T ]] || ble/util/strftime -v date_T '%I:%M:%S'
    .ble-cursor.construct-prompt.append "$date_T" ;;
  ('@')  # ? 時刻
    [[ $date_at ]] || ble/util/strftime -v date_at '%I:%M %p'
    .ble-cursor.construct-prompt.append "$date_at" ;;
  (D)
    local rex='^\\D\{([^{}]*)\}' date_D
    if [[ $tail =~ $rex ]]; then
      ble/util/strftime -v date_D "${BASH_REMATCH[1]}"
      .ble-cursor.construct-prompt.append "$date_D"
      ((i+=${#BASH_REMATCH[0]}-2))
    else
      .ble-cursor.construct-prompt.append "\\$c" "$c"
    fi ;;
  (e) 
    .ble-cursor.construct-prompt.append "" ;;
  (h) # = ホスト名
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_h" ;;
  (H) # = ホスト名
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_H" ;;
  (j) #   ジョブの数
    if test -z "$jobc"; then
      local joblist
      IFS=$'\n' GLOBIGNORE='*' eval 'joblist=($(jobs))'
      jobc=${#joblist[@]}
    fi
    .ble-cursor.construct-prompt.append "$jobc" ;;
  (l) #   tty basename
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_l" ;;
  (n)
    .ble-cursor.construct-prompt.append $'\n' ;;
  (r)
    .ble-cursor.construct-prompt.append "" ;;
  (s) # 4 "bash"
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_s" ;;
  (u) # = ユーザ名
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_u" ;;
  (v) # = bash version %d.%d
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_w" ;;
  (V) # = bash version %d.%d.%d
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_V" ;;
  (w) # PWD
    .ble-cursor.construct-prompt.append "$param_wd" ;;
  (W) # PWD短縮
    if test "$PWD" = /; then
      .ble-cursor.construct-prompt.append /
    else
      .ble-cursor.construct-prompt.append "${param_wd##*/}"
    fi ;;
  ($) # # or $
    .ble-cursor.construct-prompt.append "$_ble_cursor_prompt__string_root" ;;
  ('"') # '\"' は一旦 '"' に戻す。後で '\"' に置換される。
    .ble-cursor.construct-prompt.append "$c" ;;
  (*) # '\$' '\\' '\`' 及びその他の文字の場合はそのまま出力。
    .ble-cursor.construct-prompt.append "\\$c" "$c";;
  esac
}

## 関数 .ble-cursor.construct-prompt ; x y lc
## \param [out] ret=(x y lc ps1esc)
function .ble-cursor.construct-prompt {
  local ps1="${_ble_edit_PS1}"
  local version="$_ble_edit_LINENO"
  if [[ ${_ble_line_prompt[0]} == "$version" ]]; then
    x="${_ble_line_prompt[1]}"
    y="${_ble_line_prompt[2]}"
    lc="${_ble_line_prompt[3]}"
    ret="${_ble_line_prompt[4]}"
    return
  fi

  local param_wd=${PWD#$HOME}
  [ "$param_wd" != "$PWD" ] && param_wd="~$param_wd"
 
  x=0 y=0 lc=0
  local _suppress= _ps1txt= _ps1esc="$_ble_term_sgr0"
  local i iN=${#ps1}
  local jobc date_d date_t date_A date_T date_at
  local rex_ascii='^[]-~ -[]+'
  local rex_csi='^\[[ -?]*[]-~@-[]' # 無条件でゼロ幅と解釈する
  # 中に展開して欲しい \\ があるかもしれないので正規表現で跳ばす事はできない
  # local rex_esc='^[ -/]+([]-~@-[]|\\\\)|^([]-~@-[]|\\\\)'
  # local rex_osc='^[]PX^_]([^]|+\\?[^\])*(\\\\||)'
  for ((i=0;i<iN;)); do
    local tail="${ps1:i}"
    if [[ $tail == '\'?* ]]; then
      .ble-cursor.construct-prompt/process-backslash
    elif [[ $tail =~ $rex_ascii ]]; then
      .ble-cursor.construct-prompt.append "${BASH_REMATCH[0]}"
      ((i+=${#BASH_REMATCH[0]}))
    elif [[ $tail =~ $rex_csi ]]; then # || [[ $tail =~ $rex_esc ]] || [[ $tail =~ $rex_osc ]]
      # さすがに escape seq を解釈するのは…。
      _ps1esc="$_ps1esc${BASH_REMATCH[0]}"
      ((i+=${#BASH_REMATCH[0]}))
    else
      .ble-cursor.construct-prompt.append "${tail::1}"
      ((i++))
    fi
  done

  local dq='"' bsdq='\"'
  eval "_ps1esc=\"${_ps1esc//$dq/$bsdq}\""
  # eval "ret=\"${_ps1txt//$dq/$bsdq}\""
  _ble_line_prompt=("$version" "$x" "$y" "$lc" "$_ps1esc" "$_ps1txt")
  ret="$_ps1esc"
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
  if [[ ${_ble_line_text_cache_pos[0]} != "$_pos" ]]; then
    # 初期位置の変更がある場合は初めから計算し直し
    ((dbeg<0&&(dend=dend0=0),
      dbeg=0))
    _ble_line_text_cache_pos[0]="$_pos"
  else
    if ((dbeg<0)); then
      # 初期位置も内容も変更がない場合はOK
      local pos=(${_ble_line_text_cache_pos[iN]})
      ((x=pos[0]))
      ((y=pos[1]))
      return
    elif ((dbeg>0)); then
      # 途中から計算を再開
      local pos=(${_ble_line_text_cache_pos[dbeg]})
      ((x=pos[0]))
      ((y=pos[1]))
    fi
  fi

  local cols="${COLUMNS-80}" it="$_ble_term_it" xenl="$_ble_term_xenl"
  # local cols="80" it="$_ble_term_it" xenl="1"
  local nl=$'\n'

#%if debug (
  ble-assert '((dbeg<0||(dbeg<=dend&&dbeg<=dend0)))' "($dbeg $dend $dend0) <- (${BLELINE_RANGE_UPDATE[*]})"
#%)
  
  # shift cached data
  _ble_util_array_prototype.reserve "$iN"
  local old_pos=("${_ble_line_text_cache_pos[@]:dend0:iN-dend+1}")
  _ble_line_text_cache_pos=(
    "${_ble_line_text_cache_pos[@]::dbeg+1}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
    "${_ble_line_text_cache_pos[@]:dend0+1:iN-dend}")
  _ble_line_text_cache_cs=(
    "${_ble_line_text_cache_cs[@]::dbeg}"
    "${_ble_util_array_prototype[@]::dend-dbeg}"
    "${_ble_line_text_cache_cs[@]:dend0:iN-dend}")
  local old_ichg=("${_ble_line_text_cache_ichg[@]}")
  _ble_line_text_cache_ichg=()
  
  local i rex_ascii='^[ -~]+'
  for ((i=dbeg;i<iN;)); do
    if [[ ${text:i} =~ $rex_ascii ]]; then
      local w="${#BASH_REMATCH[0]}"
      local n
      for ((n=i+w;i<n;i++)); do
        cs="${text:i:1}"
        (((++x==cols)&&(y++,x=0,xenl))) && cs="$cs$nl"
        _ble_line_text_cache_cs[i]="$cs"
        _ble_line_text_cache_pos[i+1]="$x $y"
      done
    else
      .ble-text.s2c "$text" "$i"
      local code="$ret"

      local w=0 cs= changed=0
      if ((code<32)); then
        if ((code==9)); then
          if (((w=(x+it)/it*it-x)>0)); then
            cs="${_ble_util_string_prototype::w}"
            ((w!=it)) && changed=1
          fi
        elif ((code==10)); then
          ((y++,x=0))
          cs=$'\e[K\n'
        else
          ((w=2))
          .ble-text.c2s "$((code+64))"
          cs="^$ret"
        fi
      elif ((code==127)); then
        w=2 cs="^?"
      else
        .ble-text.c2w "$code"
        w="$ret" cs="${text:i:1}"
        if ((x<cols&&cols<x+w)); then
          ((x=cols))
          cs="${_ble_util_string_prototype::cols-x}$cs"
          changed=1
        fi
      fi

      if ((w>0)); then
        ((x+=w))
        while ((x>cols)); do
          ((y++,x-=cols))
        done
        if ((x==cols)); then
          if ((xenl)); then
            cs="$cs"$'\n'
            changed=1
          fi
          ((y++,x=0))
        fi
      fi

      _ble_line_text_cache_cs[i]="$cs"
      ((changed)) && _ble_line_text_cache_ichg+=("$i")
      _ble_line_text_cache_pos[i+1]="$x $y"
      ((i++))
    fi
    
    # 後は同じなので計算を省略
    ((i>=dend)) && [[ ${old_pos[i-dend]} == ${_ble_line_text_cache_pos[i]} ]] && break
  done

  if ((i<iN)); then
    # 途中で一致して中断した場合は、前の iN 番目の位置を読む
    local pos=(${_ble_line_text_cache_pos[iN]})
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
      _ble_line_text_cache_ichg+=("$ichg")
    fi
  done

  ((dbeg<i)) && POS_UMIN="$dbeg" POS_UMAX="$i"
}

_ble_line_text_buffName=

## 関数 x y lc lg; .ble-line.construct-text; x y cx cy lc lg
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
  #.ble-line-info.draw "highlight-urange = ($HIGHLIGHT_UMIN $HIGHLIGHT_UMAX)"

  # 変更文字の適用
  if ((${#_ble_line_text_cache_ichg[@]})); then
    local buff ichg g sgr
    eval "buff=(\"\${$HIGHLIGHT_BUFF[@]}\")"
    HIGHLIGHT_BUFF=buff
    for ichg in "${_ble_line_text_cache_ichg[@]}"; do
      ble-highlight-layer/getg "$ichg"
      ble-color-g2sgr "$g"
      buff[ichg]="$sgr${_ble_line_text_cache_cs[ichg]}"
    done
  fi

  _ble_line_text_buffName="$HIGHLIGHT_BUFF"

  # umin, umax
  ((umin=HIGHLIGHT_UMIN,
    umax=HIGHLIGHT_UMAX,
    POS_UMIN>=0&&(umin<0||umin>POS_UMIN)&&(umin=POS_UMIN),
    POS_UMAX>=0&&(umax<0||umax<POS_UMAX)&&(umax=POS_UMAX)))
  # .ble-line-info.draw "position $POS_UMIN-$POS_UMAX, highlight $HIGHLIGHT_UMIN-$HIGHLIGHT_UMAX"

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
    if ((index>0)); then
      # index == 0 の場合は受け取った lc lg をそのまま返す

      local lcs ret
      if ((cx==0)); then
        # 次の文字
        if ((index==iN)); then
          # 次の文字がない時は空白
          ret=32
        else
          lcs="${_ble_line_text_cache_cs[index]}"
          .ble-text.s2c "$lcs" 0
        fi

        # 次が改行の時は空白にする
        ble-highlight-layer/getg -v lg "$index"
        ((lc=ret==10?32:ret))
      else
        # 前の文字
        lcs="${_ble_line_text_cache_cs[index-1]}"
        .ble-text.s2c "$lcs" "$((${#lcs}-1))"
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

  local _pos=(${_ble_line_text_cache_pos[$1]})
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
    IFS= eval "ret=\"\$sgr\${$_ble_line_text_buffName[*]:i1:i2-i1}\""
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
  elif ((_y<0)); then
    (($_var=0))
  else
    # 2分法
    local _l=0 _u="$((_ble_line_text_cache_length+1))" _m
    while ((_l+1<_u)); do
      local _pos=(${_ble_line_text_cache_pos[_m=(_l+_u)/2]})
      (((_y<_pos[1]||_y==_pos[1]&&_x<_pos[0])?(_u=_m):(_l=_m)))
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
  # 正規表現は _ble_bash>=30000
  local rex_ascii='^[ -~]+'

  local cols=${COLUMNS-80}

  local text="$1" out=
  local i iN=${#text}
  for ((i=0;i<iN;)); do
    local tail="${text:i}"

    if [[ $tail =~ $rex_ascii ]]; then
      .ble-line-cur.xyo/add-simple "${#BASH_REMATCH[0]}" "${BASH_REMATCH[0]}"
      ((i+=${#BASH_REMATCH[0]})) 
    else
      .ble-text.s2c "$text" "$i"
      local code="$ret" w=0
      if ((code<32)); then
        .ble-text.c2s "$((code+64))"
        .ble-line-cur.xyo/add-atomic 2 "[7m^$ret[m"
      elif ((code==127)); then
        .ble-line-cur.xyo/add-atomic 2 '[7m^?[m'
      else
        .ble-text.c2w "$code"
        .ble-line-cur.xyo/add-atomic "$ret" "${text:i:1}"
      fi

      ((i++))
    fi
  done

  .ble-line-cur.xyo/eol2nl

  ret="$out"
}

_ble_line_info=(0 0 "")
function .ble-line-info.draw {
  local text="$1"

  # 内容の構築
  local x=0 y=0 lc=32 ret
  .ble-line-info.construct-info "$text"
  local content="$ret"

  local DRAW_BUFF=()

  # (1) 移動・領域確保
  ble-edit/draw/goto 0 "$_ble_line_endy"
  ble-edit/draw/put "$_ble_term_ind"
  [[ ${_ble_line_info[2]} ]] && ble-edit/draw/put "[$((_ble_line_info[1]+1))M"
  [[ $content ]] && ble-edit/draw/put "[$((y+1))L"

  # (2) 内容
  ble-edit/draw/put "$content"
  ble-edit/draw/flush >&2

  _ble_line_y="$((_ble_line_endy+1+y))"
  _ble_line_x="$x"
  _ble_line_info=("$x" "$y" "$content")
}
function .ble-line-info.clear {
  test -z "${_ble_line_info[2]}" && return

  # (1) 移動・削除
  local out=
  .ble-edit-draw.goto-xy out 0 _ble_line_endy
  out="$outD[$((_ble_line_info[1]+1))M"

  echo -n "$out"
  _ble_line_y="$((_ble_line_endy+1+y))"
  _ble_line_x="$x"
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

# _ble_edit_str は以下の関数を通して変更する。
# 変更範囲を追跡する為。
function _ble_edit_str.replace {
  local -i beg="$1" end="$2"
  local ins="$3"

  # c.f. Note#1
  _ble_edit_str="${_ble_edit_str::beg}""$ins""${_ble_edit_str:end}"
  ble-edit/dirty-range/update "$beg" "$((beg+${#ins}))" "$end"
  .ble-edit-draw.set-dirty "$beg"
}
function _ble_edit_str.reset {
  local str="$1"
  ble-edit/dirty-range/update 0 "${#str}" "${#_ble_edit_str}"
  .ble-edit-draw.set-dirty 0
  _ble_edit_str="$str"
}

# 変更範囲
_ble_edit_str_dbeg=-1
_ble_edit_str_dend=-1
_ble_edit_str_dend0=-1
function ble-edit/dirty-range/clear {
  _ble_edit_str_dbeg=-1
  _ble_edit_str_dend=-1
  _ble_edit_str_dend0=-1
}

## 関数 ble-edit/dirty-range/update [--prefix=PREFIX] beg end end0
## @param[out] PREFIX
## @param[in]  beg    変更開始点。beg<0 は変更がない事を表す
## @param[in]  end    変更終了点。end<0 は変更が末端までである事を表す
## @param[in]  end0   変更前の end に対応する位置。
function ble-edit/dirty-range/update {
  local _prefix=_ble_edit_str_d
  if [[ $1 == --prefix=* ]]; then
    _prefix="${1:9}"
    shift
  fi

  local begB="$1" endB="$2" endB0="$3"
  ((begB<0)) && return

  local begA endA endA0
  ((begA=${_prefix}beg,endA=${_prefix}end,endA0=${_prefix}beg))

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
        (delta=endA-endB0)>0?(end+=del):(end0-=del)))
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

  if test -z "${_ble_edit_LINENO+x}"; then
    _ble_edit_LINENO="${BASH_LINENO[*]: -1}"
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0
    unset LINENO; LINENO="$_ble_edit_LINENO"
    _ble_edit_CMD="$_ble_edit_LINENO"
  fi

  trap .ble-edit/edit/attach/TRAPWINCH WINCH

  # if test -z "${_ble_edit_PS1+set}"; then
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

# 出力のための新しい関数群

function ble-edit/draw/put {
  DRAW_BUFF[${#DRAW_BUFF[*]}]="$*"
}
function ble-edit/draw/flush {
  IFS= eval 'echo -n "${DRAW_BUFF[*]}"'
}
function ble-edit/draw/goto {
  local -i x="$1" y="$2"
  ble-edit/draw/put "$_ble_term_sgr0"

  local -i dy=y-_ble_line_y
  if ((dy!=0)); then
    if ((dy>0)); then
      ble-edit/draw/put "${_ble_term_cud//%d/$dy}"
    else
      ble-edit/draw/put "${_ble_term_cuu//%d/$((-dy))}"
    fi
  fi

  local -i dx=x-_ble_line_x
  if ((dx!=0)); then
    if ((x==0)); then
      ble-edit/draw/put ""
    elif ((dx>0)); then
      ble-edit/draw/put "${_ble_term_cuf//%d/$dx}"
    else
      ble-edit/draw/put "${_ble_term_cub//%d/$((-dx))}"
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
    ble-edit/draw/put "${_ble_term_dl//%d/$height}${_ble_term_il//%d/$height}"
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
    ble-edit/draw/put "$_ble_term_ind${_ble_term_dl//%d/$height}${_ble_term_il//%d/$height}$_ble_term_ri"
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

## 変数 _ble_line_cache_ind := inds ':' mark ':' mark_active
##   現在の表示内容のカーソル位置・ポイント位置の情報を保持します。
_ble_line_cache_ind=::

function .ble-edit-draw.set-dirty {
  local d2="${1:-$_ble_edit_ind}"
  if test -z "$_ble_edit_dirty"; then
    _ble_edit_dirty="$d2"
  else
    ((d2<_ble_edit_dirty&&(_ble_edit_dirty=d2)))
  fi
}

## 関数 .ble-edit-draw.put var content
function .ble-edit-draw.put {
  if test -n "$1"; then
    eval "$1=\"\${$1}\$2\""
  else
    echo -n "$2"
  fi
}

## 関数 .ble-edit-drwa.goto-xy varname x y
##   現在位置を指定した座標へ移動する制御系列を生成します。
## \param [out] varname
##   制御系列の書込先変数名を指定します。指定した変数に制御系列を追記します。
##   var が指定されていない場合は、標準出力に制御系列を出力します。
## \param [in] x
##   移動先のカーソル位置 x 座標を指定します。プロンプト原点が x=0 に対応します。
## \param [in] y
##   移動先のカーソル位置 y 座標を指定します。プロンプト原点が y=0 に対応します。
function .ble-edit-draw.goto-xy {
  local x="$2" y="$3"
  local esc="$_ble_term_sgr0" # 必要か?

  local -i dy=y-_ble_line_y
  if ((dy!=0)); then
    if ((dy>0)); then
      esc="$esc[${dy}B"
    else
      esc="$esc[$((-dy))A"
    fi
  fi

  local -i dx=x-_ble_line_x
  if ((dx!=0)); then
    if ((x==0)); then
      esc="$esc"
    elif ((dx>0)); then
      esc="$esc[${dx}C"
    else
      esc="$esc[$((-dx))D"
    fi
  fi

  if test -n "$esc"; then
    .ble-edit-draw.put "$1" "$esc"
    _ble_line_x="$x" _ble_line_y="$y"
  fi
}

## 関数 .ble-edit-draw.update
##   要件: カーソル位置 (x y) = (_ble_line_cur[0] _ble_line_cur[1]) に移動する
##   要件: 編集文字列部分の再描画を実行する
function .ble-edit-draw.update {
  local indices="$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active"
  if test -z "$_ble_edit_dirty" -a "$_ble_line_cache_ind" = "$indices"; then
    .ble-edit-draw.goto-xy '' "${_ble_line_cur[0]}" "${_ble_line_cur[1]}"
    return
  fi

  #-------------------
  # 内容の再計算

  local ret

  local x y lc lg=
  .ble-cursor.construct-prompt # x y lc ret
  local prox="$x" proy="$y" prolc="$lc" esc_prompt="$ret"

  # BLELINE_RANGE_UPDATE → .ble-line-text/update 内でこれを見て update を済ませる
  local BLELINE_RANGE_UPDATE=("$_ble_edit_str_dbeg" "$_ble_edit_str_dend" "$_ble_edit_str_dend0")
  ble-edit/dirty-range/clear
#%if debug (
  ble-assert '((BLELINE_RANGE_UPDATE[0]<0||(
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[1]&&
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[2])))' "(${BLELINE_RANGE_UPDATE[*]})"
#%)

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

  local DRAW_BUFF=()

  # 1 描画領域の確保 (高さの調整)
  local endx endy
  .ble-line-text/getxy --prefix=end "$iN"
  local delta
  if (((delta=endy-_ble_line_endy)!=0)); then
    if((delta>0)); then
      ble-edit/draw/goto 0 "$((_ble_line_endy+1))"
      ble-edit/draw/put "${_ble_term_il//%d/$delta}"
    else
      ble-edit/draw/goto 0 "$((_ble_line_endy+1+delta))"
      ble-edit/draw/put "${_ble_term_dl//%d/$((-delta))}"
    fi
  fi
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
  .ble-line-text/getxy --prefix=c "$index" # → cx cy
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
  if test -n "${_ble_line_cache[0]+set}"; then
    local -a d=("${_ble_line_cache[@]}")

    local DRAW_BUFF=()

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

  # bash が表示するプロンプトを見えなくする
  # (現在のカーソルの左側にある文字を再度上書きさせる)
  PS1=
  local ret lc="${_ble_line_cur[2]}" lg="${_ble_line_cur[3]}"
  .ble-text.c2s "$lc"
  READLINE_LINE="$ret"
  if ((_ble_line_cur[0]==0)); then
    READLINE_POINT=0
  else
    if test -z "$bleopt_suppress_bash_output"; then
      .ble-text.c2w "$lc"
      ((ret>0)) && echo -n "[${ret}D"
    fi
    .ble-text.c2bc "$lc"
    READLINE_POINT="$ret"
  fi

  ble-color-g2sgr "$lg"
  echo -n "$ret"
}
function ble-edit+redraw-line {
  .ble-edit-draw.set-dirty -1
}
function ble-edit+clear-screen {
  echo -n '[0;0H[2J'
  _ble_line_x=0 _ble_line_y=0
  _ble_line_cur=(0 0 32 0)
  .ble-edit-draw.set-dirty -1
  .ble-term.visible-bell.cancel-erasure
}
function ble-edit+display-shell-version {
  .ble-edit.bind.command 'echo "GNU bash, version $BASH_VERSION ($MACHTYPE) with ble.sh"'
}

# 
# **** mark, kill, copy ****                                         @edit.mark

function ble-edit+set-mark {
  _ble_edit_mark="$_ble_edit_ind"
  _ble_edit_mark_active=1
}
function ble-edit+kill-forward-text {
  ((_ble_edit_ind>=${#_ble_edit_str})) && return

  _ble_edit_kill_ring="${_ble_edit_str:_ble_edit_ind}"
  _ble_edit_str.replace "$_ble_edit_ind" "${#_ble_edit_str}" ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble-edit+kill-backward-text {
  ((_ble_edit_ind==0)) && return
  _ble_edit_kill_ring="${_ble_edit_str::_ble_edit_ind}"
  _ble_edit_str.replace 0 _ble_edit_ind ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble-edit+exchange-point-and-mark {
  local m="$_ble_edit_mark" p="$_ble_edit_ind"
  _ble_edit_ind="$m" _ble_edit_mark="$p"
}
function ble-edit+yank {
  ble-edit+insert-string "$_ble_edit_kill_ring"
}
function ble-edit+marked {
  if test "$_ble_edit_mark_active" != S; then
    _ble_edit_mark="$_ble_edit_ind"
    _ble_edit_mark_active=S
  fi
  "ble-edit+$@"
}
function ble-edit+nomarked {
  if test "$_ble_edit_mark_active" = S; then
    _ble_edit_mark_active=
  fi
  "ble-edit+$@"
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
## 関数 ble-edit+delete-region
##   領域を削除します。
function ble-edit+delete-region {
  .ble-edit.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble-edit+kill-region
##   領域を切り取ります。
function ble-edit+kill-region {
  .ble-edit.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble-edit+copy-region
##   領域を転写します。
function ble-edit+copy-region {
  .ble-edit.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble-edit+delete-region-or type
##   領域または引数に指定した単位を削除します。
##   mark が active な場合には領域の削除を行います。
##   それ以外の場合には第一引数に指定した単位の削除を実行します。
## \param [in] type
##   mark が active でない場合に実行される削除の単位を指定します。
##   実際には ble-edit 関数 delete-type が呼ばれます。
function ble-edit+delete-region-or {
  if test -n "$_ble_edit_mark_active"; then
    ble-edit+delete-region
  else
    "ble-edit+delete-$@"
  fi
}
## 関数 ble-edit+kill-region-or type
##   領域または引数に指定した単位を切り取ります。
##   mark が active な場合には領域の切り取りを行います。
##   それ以外の場合には第一引数に指定した単位の切り取りを実行します。
## \param [in] type
##   mark が active でない場合に実行される切り取りの単位を指定します。
##   実際には ble-edit 関数 kill-type が呼ばれます。
function ble-edit+kill-region-or {
  if test -n "$_ble_edit_mark_active"; then
    ble-edit+kill-region
  else
    "ble-edit+kill-$@"
  fi
}
## 関数 ble-edit+copy-region-or type
##   領域または引数に指定した単位を転写します。
##   mark が active な場合には領域の転写を行います。
##   それ以外の場合には第一引数に指定した単位の転写を実行します。
## \param [in] type
##   mark が active でない場合に実行される転写の単位を指定します。
##   実際には ble-edit 関数 copy-type が呼ばれます。
function ble-edit+copy-region-or {
  if test -n "$_ble_edit_mark_active"; then
    ble-edit+copy-region
  else
    "ble-edit+copy-$@"
  fi
}

# 
# **** bell ****                                                     @edit.bell

function .ble-edit.bell {
  [ -n "$bleopt_edit_vbell" ] && .ble-term.visible-bell "$1"
  [ -n "$bleopt_edit_abell" ] && .ble-term.audible-bell
}
function ble-edit+bell {
  .ble-edit.bell
  _ble_edit_mark_active=
}

# 
# **** insert ****                                                 @edit.insert

function ble-edit+insert-string {
  local ins="$*"
  test -z "$ins" && return

  local dx="${#ins}"
  _ble_edit_str.replace _ble_edit_ind _ble_edit_ind "$ins"
  (('
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  '))
  _ble_edit_mark_active=
}
function ble-edit+self-insert {
  local code="$((KEYS[0]&ble_decode_MaskChar))"
  ((code==0)) && return

  local ret
  .ble-text.c2s "$code"
  _ble_edit_str.replace _ble_edit_ind _ble_edit_ind "$ret"
  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark++))
  ((_ble_edit_ind++))
  _ble_edit_mark_active=
}

# quoted insert
function .ble-edit.quoted-insert.hook {
  local KEYS=("$1")
  ble-edit+self-insert
}
function ble-edit+quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_char__hook=.ble-edit.quoted-insert.hook
}

function ble-edit+transpose-chars {
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
    if ((_ble_edit_ind<=0)); then
      return 1
    else
      _ble_edit_str.replace _ble_edit_ind-1 _ble_edit_ind ''
      ((_ble_edit_ind--))
    fi
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      _ble_edit_str.replace _ble_edit_ind _ble_edit_ind+1 ''
    else
      _ble_edit_ind="${#_ble_edit_str}"
      _ble_edit_str.replace _ble_edit_ind-1 _ble_edit_ind ''
    fi
  fi

  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
  return 0
}
function ble-edit+delete-forward-char {
  .ble-edit.delete-char 1 || .ble-edit.bell
}
function ble-edit+delete-backward-char {
  .ble-edit.delete-char -1 || .ble-edit.bell
}
function ble-edit+delete-forward-char-or-exit {
  if [[ -n "$_ble_edit_str" ]]; then
    ble-edit+delete-forward-char
    return
  fi

  # job が残っている場合
  if jobs % &>/dev/null; then
    .ble-edit.bell "(exit) ジョブが残っています!"
    .ble-edit.bind.command jobs
    return
  fi

  #_ble_edit_detach_flag=exit
  
  #.ble-term.visible-bell ' Bye!! ' # 最後に vbell を出すと一時ファイルが残る
  echo '[94m[ble: exit][m' 1>&2
  exit
}
function ble-edit+delete-forward-backward-char {
  .ble-edit.delete-char 0 || .ble-edit.bell
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
function ble-edit+forward-char {
  .ble-edit.forward-char 1 || .ble-edit.bell
}
function ble-edit+backward-char {
  .ble-edit.forward-char -1 || .ble-edit.bell
}
function ble-edit+end-of-text {
  .ble-edit.goto-char ${#_ble_edit_str}
}
function ble-edit+beginning-of-text {
  .ble-edit.goto-char 0
}

function ble-edit+beginning-of-line {
  local x y index
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$y"
  .ble-edit.goto-char "$index"
}
function ble-edit+end-of-line {
  local x y index ax ay
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$((y+1))"
  .ble-line-text/getxy --prefix=a "$index"
  ((ay>y&&index--))
  .ble-edit.goto-char "$index"
}

function ble-edit+kill-backward-line {
  local x y index
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$y"
  .ble-edit.kill-range "$index" "$_ble_edit_ind"
}
function ble-edit+kill-forward-line {
  local x y index ax ay
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at 0 "$((y+1))"
  .ble-line-text/getxy --prefix=a "$index"
  ((_ble_edit_ind+1<index&&ay>y&&index--))
  .ble-edit.kill-range "$_ble_edit_ind" "$index"
}

function ble-edit+forward-line {
  local x y index
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at "$x" "$((y+1))"
  .ble-edit.goto-char "$index"
  ((_ble_edit_mark_active||y<_ble_line_endy))
}
function ble-edit+backward-line {
  local x y index
  .ble-line-text/getxy "$_ble_edit_ind"
  .ble-line-text/get-index-at "$x" "$((y-1))"
  .ble-edit.goto-char "$index"
  ((_ble_edit_mark_active||y>0))
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

## 関数 ble-edit+delete-forward-uword
##   前方の unix word を削除します。
function ble-edit+delete-forward-uword {
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
## 関数 ble-edit+delete-backward-uword
##   後方の unix word を削除します。
function ble-edit+delete-backward-uword {
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
## 関数 ble-edit+delete-uword
##   現在位置の unix word を削除します。
function ble-edit+delete-uword {
  local x="${1:-$_ble_edit_ind}" r s t u
  .ble-edit.locate-current-uword "$x"
  if ((x>t&&(t=x),r!=t)); then
    .ble-edit.delete-range "$r" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble-edit+kill-forward-uword
##   前方の unix word を切り取ります。
function ble-edit+kill-forward-uword {
  # <x> *<s>w*<t> *<u>
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword
  if ((x!=t)); then
    .ble-edit.kill-range "$x" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble-edit+kill-backward-uword
##   後方の unix word を切り取ります。
function ble-edit+kill-backward-uword {
  # <a> *<b>w*<c> *<x>
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword
  if ((x>c&&(c=x),b!=c)); then
    .ble-edit.kill-range "$b" "$c"
  else 
    .ble-edit.bell
  fi
}
## 関数 ble-edit+kill-uword
##   現在位置の unix word を切り取ります。
function ble-edit+kill-uword {
  local x="${1:-$_ble_edit_ind}" r s t u
  .ble-edit.locate-current-uword "$x"
  if ((x>t&&(t=x),r!=t)); then
    .ble-edit.kill-range "$r" "$t"
  else
    .ble-edit.bell
  fi
}
## 関数 ble-edit+copy-forward-uword
##   前方の unix word を転写します。
function ble-edit+copy-forward-uword {
  # <x> *<s>w*<t> *<u>
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword
  .ble-edit.copy-range "$x" "$t"
}
## 関数 ble-edit+copy-backward-uword
##   後方の unix word を転写します。
function ble-edit+copy-backward-uword {
  # <a> *<b>w*<c> *<x>
  local a b c x="${1:-$_ble_edit_ind}"
  .ble-edit.locate-backward-uword
  .ble-edit.copy-range "$b" "$((c>x?c:x))"
}
## 関数 ble-edit+copy-uword
##   現在位置の unix word を転写します。
function ble-edit+copy-uword {
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
function ble-edit+forward-uword {
  local x="${1:-$_ble_edit_ind}" s t u
  .ble-edit.locate-forward-uword "$x"
  if ((x==t)); then
    .ble-edit.bell
  else
    .ble-edit.goto-char "$t" 
  fi
}
function ble-edit+backward-uword {
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

# **** .ble-edit/exec ****                                           @edit.exec

declare -a _ble_edit_accept_line=()
declare _ble_edit_accept_line_lastexit=0
function .ble-edit.accept-line.add {
  local BASH_COMMAND="$1"
  _ble_edit_accept_line+=("$1")
}
function .ble-edit/exec/setexit {
  # $? 変数の設定
  return "$_ble_edit_accept_line_lastexit"
}
function .ble-edit/exec/adjust-eol {
  # 文末調整
  local eof="$_ble_term_sgr_fghb[ble: EOF]$_ble_term_sgr0"
  local cols=${COLUMNS:-80} xenl=$_ble_term_xenl
  echo -n "$_ble_term_sc${eof}$_ble_term_rc[$((xenl?cols-2:cols-3))C  [2K"
  _ble_line_x=0 _ble_line_y=0
}
function .ble-edit/exec/eval-TRAPINT {
  echo
  # echo "SIGINT ${FUNCNAME[1]}"
  if ((_ble_bash>=40300)); then
    _ble_edit_accept_line_INT=130
  else
    _ble_edit_accept_line_INT=128
  fi
  trap '.ble-edit/exec/eval-TRAPDEBUG SIGINT "$*" && return' DEBUG
}
function .ble-edit/exec/eval-TRAPDEBUG {
  # 一旦 DEBUG を設定すると bind -x を抜けるまで削除できない様なので、
  # _ble_edit_accept_line_INT のチェックと _ble_edit_exec_in_eval のチェックを行う。
  if ((_ble_edit_accept_line_INT&&_ble_edit_exec_in_eval)); then
    echo "$_ble_term_sgr_fghr[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2"
    return 0
  else
    trap - DEBUG # 何故か効かない
    return 1
  fi
}

function .ble-edit/exec/eval-prologue {
  .ble-stty.leave

  set -H

  # C-c に対して
  trap '.ble-edit/exec/eval-TRAPINT; return 128' INT
  # trap '_ble_edit_accept_line_INT=126; return 126' TSTP
}
function .ble-edit/exec/eval {
  local _ble_edit_exec_in_eval=1
  # BASH_COMMAND に return が含まれていても大丈夫な様に関数内で評価
  .ble-edit/exec/setexit
  eval -- "$BASH_COMMAND"
}
function .ble-edit/exec/eval-epilogue {
  trap - INT DEBUG # DEBUG 削除が何故か効かない

  .ble-stty.enter
  _ble_edit_PS1="$PS1"

  .ble-edit/exec/adjust-eol

  # lastexit
  if ((_ble_edit_accept_line_lastexit==0)); then
    _ble_edit_accept_line_lastexit="$_ble_edit_accept_line_INT"
  fi
  if [ "$_ble_edit_accept_line_lastexit" -ne 0 ]; then
    # SIGERR処理
    if type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      echo "$_ble_term_sgr_fghr[ble: exit $_ble_edit_accept_line_lastexit]$_ble_term_sgr0" 2>&1
    fi
  fi
}

## 関数 .ble-edit/exec/recursive index
##   index 番目のコマンドを実行し、引数 index+1 で自己再帰します。
##   コマンドがこれ以上ない場合は何もせずに終了します。
## \param [in] index
function .ble-edit/exec/recursive {
  (($1>=${#_ble_edit_accept_line})) && return

  local BASH_COMMAND="${_ble_edit_accept_line[$1]}"
  _ble_edit_accept_line[$1]=
  if test -n "${BASH_COMMAND//[ 	]/}"; then
    # 実行
    local PS1="$_ble_edit_PS1" HISTCMD="${#_ble_edit_history[@]}"
    local _ble_edit_accept_line_INT=0
    .ble-edit/exec/eval-prologue
    .ble-edit/exec/eval
    _ble_edit_accept_line_lastexit="$?"
    .ble-edit/exec/eval-epilogue
  fi

  .ble-edit/exec/recursive "$(($1+1))"
}

declare _ble_edit_exec_replacedDeclare=
declare _ble_edit_exec_replacedTypeset=
function .ble-edit/exec/isGlobalContext {
  local offset="$1"

  local path
  for path in "${FUNCNAME[@]:offset+1}"; do
    # source or . が続く限りは遡る (. で呼び出しても FUNCNAME には source が入る様だ。)
    if [[ $path = .ble-edit/exec/eval ]]; then
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
  #   if [[ $func = .ble-edit/exec/eval && $path = $BASH_SOURCE ]]; then
  #     return 0
  #   elif [[ $path != source && $path != $BASH_SOURCE ]]; then
  #     # source ble.sh の中の declare が全て local になるので上だと駄目。
  #     # しかしそもそも二重にロードしても大丈夫な物かは謎。
  #     return 1
  #   fi
  # done

  return 0
}

function .ble-edit.accept-line.exec {
  test ${#_ble_edit_accept_line[@]} -eq 0 && return

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
        if .ble-edit/exec/isGlobalContext 1; then
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
        if .ble-edit/exec/isGlobalContext 1; then
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

  # 以下、配列 _ble_edit_accept_line に登録されている各コマンドを順に実行する。
  # ループ構文を使うと、ループ構文自体がユーザの入力した C-z (SIGTSTP)
  # を受信して(?)停止してしまう様なので、再帰でループする必要がある。
  .ble-edit/exec/recursive 0

  _ble_edit_accept_line=()

  # C-c で中断した場合など以下が実行されないかもしれないが
  # 次の呼出の際にここが実行されるのでまあ許容する。
  if test -n "$_ble_edit_exec_replacedDeclare"; then
    _ble_edit_exec_replacedDeclare=
    unset declare
  fi
  if test -n "$_ble_edit_exec_replacedTypeset"; then
    _ble_edit_exec_replacedTypeset=
    unset typeset
  fi
}

function .ble-edit+accept-line/process+exec {
  .ble-edit.accept-line.exec
  .ble-decode-byte:bind/check-detach
  return $?
}

# **** .ble-edit/gexec ****                                         @edit.gexec

function .ble-edit/gexec/eval-TRAPINT {
  echo
  if ((_ble_bash>=40300)); then
    _ble_edit_accept_line_INT=130
  else
    _ble_edit_accept_line_INT=128
  fi
  trap '.ble-edit/gexec/eval-TRAPDEBUG SIGINT "$*" && { return &>/dev/null || break &>/dev/null;}' DEBUG
}
function .ble-edit/gexec/eval-TRAPDEBUG {
  if ((_ble_edit_accept_line_INT!=0)); then
    # エラーが起きている時

    local depth="${#FUNCNAME[*]}"
    local rex='^\.ble-edit/gexec/'
    if ((depth>=2)) && ! [[ ${FUNCNAME[*]:depth-1} =~ $rex ]]; then
      # 関数内にいるが、.ble-edit/gexec/ の中ではない時
      echo "$_ble_term_sgr_fghr[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2"
      return 0
    fi
    
    local rex='^(\.ble-edit/gexec/|trap - )'
    if ((depth==1)) && ! [[ $BASH_COMMAND =~ $rex ]]; then
      # 一番外側で、.ble-edit/gexec/ 関数ではない時
      echo "$_ble_term_sgr_fghr[ble: $1]$_ble_term_sgr0 $BASH_COMMAND $2"
      return 0
    fi
  fi

  trap - DEBUG # 何故か効かない
  return 1
}
function .ble-edit/gexec/begin {
  _ble_decode_bind_hook=
  .ble-edit/stdout/on
  set -H

  # C-c に対して
  trap '.ble-edit/gexec/eval-TRAPINT' INT
}
function .ble-edit/gexec/end {
  trap - INT DEBUG # DEBUG: 何故か効かない

  .ble-decode-byte:bind/check-detach && return 0
  .ble-decode-byte:bind/tail
}
function .ble-edit/gexec/eval-prologue {
  # unset HISTCMD
  BASH_COMMAND="$1"
  PS1="$_ble_edit_PS1"
  HISTCMD="${#_ble_edit_history[@]}"
  _ble_edit_accept_line_INT=0
  .ble-stty.leave
  .ble-edit/exec/setexit
}
function .ble-edit/gexec/eval-epilogue {
  # lastexit
  _ble_edit_accept_line_lastexit="$?"
  if ((_ble_edit_accept_line_lastexit==0)); then
    _ble_edit_accept_line_lastexit="$_ble_edit_accept_line_INT"
  fi
  _ble_edit_accept_line_INT=0

  trap - DEBUG # DEBUG 削除が何故か効かない

  .ble-stty.enter
  _ble_edit_PS1="$PS1"
  PS1=
  .ble-edit/exec/adjust-eol

  if [ "$_ble_edit_accept_line_lastexit" -ne 0 ]; then
    # SIGERR処理
    if type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      echo "$_ble_term_sgr_fghr[ble: exit $_ble_edit_accept_line_lastexit]$_ble_term_sgr0" 2>&1
    fi
  fi
}
function .ble-edit/gexec/setup {
  # コマンドを _ble_decode_bind_hook に設定してグローバルで評価する。
  #
  # ※ユーザの入力したコマンドをグローバルではなく関数内で評価すると
  #   declare した変数がコマンドローカルになってしまう。
  #   配列でない単純な変数に関しては declare を上書きする事で何とか誤魔化していたが、
  #   declare -a arr=(a b c) の様な特殊な構文の物は上書きできない。
  #   この所為で、例えば source 内で declare した配列などが壊れる。
  #
  ((${#_ble_edit_accept_line[@]}==0)) && return 1

  local apos=\' APOS="'\\''"
  local cmd
  local -a buff
  local count=0
  buff[${#buff[@]}]=.ble-edit/gexec/begin
  for cmd in "${_ble_edit_accept_line[@]}"; do
    if [[ "$cmd" == *[^' 	']* ]]; then
      buff[${#buff[@]}]=".ble-edit/gexec/eval-prologue '${cmd//$apos/$APOS}'"
      buff[${#buff[@]}]="eval -- '${cmd//$apos/$APOS}'"
      buff[${#buff[@]}]=".ble-edit/gexec/eval-epilogue"
      ((count++))

      # ※直接 $cmd と書き込むと文法的に破綻した物を入れた時に
      #   下の行が実行されない事になってしまう。
    fi
  done
  _ble_edit_accept_line=()

  ((count==0)) && return 1

  buff[${#buff[@]}]='trap - INT DEBUG' # trap - は一番外側でないと効かない様だ
  buff[${#buff[@]}]=.ble-edit/gexec/end

  IFS=$'\n' eval '_ble_decode_bind_hook="${buff[*]}"'
  return 0
}

function .ble-edit+accept-line/process+gexec {
  .ble-edit/gexec/setup
  return $?
}

# **** accept-line ****                                            @edit.accept

function ble-edit+discard-line {
  # 行更新
  .ble-line-info.clear
  .ble-edit-draw.update
  .ble-edit-draw.goto-xy '' "$_ble_line_endx" "$_ble_line_endy"

  # 新しい行
  echo 1>&2
  ((LINENO=++_ble_edit_LINENO))
  _ble_edit_str.reset ''
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_dirty=-1
}

function ble-edit+accept-line {
  local BASH_COMMAND="$_ble_edit_str"
  local nl=$'\n'

  # 行更新
  .ble-line-info.clear
  .ble-edit-draw.update
  .ble-edit-draw.goto-xy '' "$_ble_line_endx" "$_ble_line_endy"
  echo 1>&2
  ((LINENO=++_ble_edit_LINENO))

  # 履歴展開
  local hist_expanded
  if ! hist_expanded="$(history -p -- "$BASH_COMMAND" 2>/dev/null;echo -n :)"; then
    .ble-edit-draw.set-dirty -1
    return
  fi
  if test "${hist_expanded%$nl:}" != "$BASH_COMMAND"; then
    BASH_COMMAND="${hist_expanded%$nl:}"
    echo "$_ble_term_sgr_fghb[ble: expand]$_ble_term_sgr0 $BASH_COMMAND" 1>&2
  fi

  _ble_edit_str.reset ''
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_dirty=-1

  if test -n "${BASH_COMMAND//[ 	]/}"; then
    ((++_ble_edit_CMD))

    # 編集文字列を履歴に追加
    .ble-edit.history-add "$BASH_COMMAND"

    # 実行を登録
    .ble-edit.accept-line.add "$BASH_COMMAND"
  fi
}

function ble-edit+accept-and-next {
  local hist_ind=$((_ble_edit_history_ind+1))
  ble-edit+accept-line
  .ble-edit.history-goto $hist_ind
}
function ble-edit+newline {
  KEYS=(10) ble-edit+self-insert
}
function ble-edit+accept-single-line-or-newline {
  if [[ $_ble_edit_str == *$'\n'* ]]; then
    ble-edit+newline
  else
    ble-edit+accept-line
  fi
}

function .ble-edit.bind.command {
  local BASH_COMMAND=("$*")
  .ble-line-info.clear
  .ble-edit-draw.update
  .ble-edit-draw.goto-xy '' "$_ble_line_endx" "$_ble_line_endy"
  echo 1>&2
  ((LINENO=++_ble_edit_LINENO))

  # eval "$BASH_COMMAND"
  # .ble-edit/exec/adjust-eol

  # やはり通常コマンドはちゃんとした環境で評価するべき
  if test -n "${BASH_COMMAND//[ 	]/}"; then
    .ble-edit.accept-line.add "$BASH_COMMAND"
  fi

  .ble-edit-draw.set-dirty -1
}

# 
#------------------------------------------------------------------------------
# **** history ****                                                    @history

: ${ble_opt_history_preserve_point=}
_ble_edit_history=()
_ble_edit_history_edit=()
_ble_edit_history_ind=0

function .ble-edit/history/generate-source-to-load-history {
  # rcfile として起動すると history が未だロードされていない。
  history -n
  HISTTIMEFORMAT=__ble_ext__
  
  # 285ms for 16437 entries
  local apos="'"
  history | awk -v apos="'" '
    BEGIN{
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
function .ble-edit.history-load {
  # * プロセス置換にしてもファイルに書き出しても大した違いはない。
  #   270ms for 16437 entries (generate-source の時間は除く)
  # * プロセス置換×source は bash-3 で動かない。eval に変更する。
  eval -- "$(.ble-edit/history/generate-source-to-load-history)"

  _ble_edit_history_ind=${#_ble_edit_history[@]}
}

function .ble-edit.history-add {
  # 登録・不登録に拘わらず取り敢えず初期化
  _ble_edit_history_ind=${#_ble_edit_history[@]}
  _ble_edit_history_edit=()

  local cmd="$1"
  if test -n "$HISTIGNORE"; then
    local i pats pat
    GLOBIGNORE='*' IFS=: eval 'pats=($HISTIGNORE)'
    for pat in "${pats[@]}"; do
      test -z "${cmd/$pat/}" && return
    done
  fi

  if test -n "$HISTCONTROL"; then
    local lastIndex=$((${#_ble_edit_history[@]}-1)) spec
    for spec in ${HISTCONTROL//:/}; do
      case "$spec" in
      ignorespace)
        test "${cmd#[ 	]}" != "$cmd" && return ;;
      ignoredups)
        if test "$lastIndex" -ge 0; then
          test "$cmd" = "${_ble_edit_history[$lastIndex]}" && return
        fi ;;
      ignoreboth)
        test "${cmd#[ 	]}" != "$cmd" && return
        if test "$lastIndex" -ge 0; then
          test "$cmd" = "${_ble_edit_history[$lastIndex]}" && return
        fi ;;
      erasedups)
        local i n=-1
        for ((i=0;i<=lastIndex;i++)); do
          if test "${_ble_edit_history[$i]}" != "$cmd"; then
            ((++n!=i)) && _ble_edit_history[$n]=_ble_edit_history[$i]
          fi
        done
        for ((i=lastIndex;i>n;i--)); do
          unset '_ble_edit_history[$i]'
        done
        ;;
      esac
    done
  fi
  
  _ble_edit_history[${#_ble_edit_history[@]}]="$cmd"
  _ble_edit_history_ind=${#_ble_edit_history[@]}

  if [[ $cmd == *$'\n'* ]]; then
    if ((_ble_bash>=40100)); then
      printf -v cmd 'eval -- %q' "$cmd"
    else
      cmd="$(printf 'eval -- %q' "$cmd")"
    fi
  fi
  history -s -- "$cmd"
}

function .ble-edit.history-goto {
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
  _ble_edit_history_edit[$index0]="$_ble_edit_str"

  # restore
  _ble_edit_history_ind="$index1"
  if test -n "${_ble_edit_history_edit[$index1]+set}"; then
    _ble_edit_str.reset "${_ble_edit_history_edit[$index1]}"
  else
    _ble_edit_str.reset "${_ble_edit_history[$index1]}"
  fi

  # point
  if test -n "$ble_opt_history_preserve_point"; then
    if ((_ble_edit_ind>"${#_ble_edit_str}")); then
      _ble_edit_ind="${#_ble_edit_str}"
    fi
  else
    _ble_edit_ind="${#_ble_edit_str}"
  fi
  _ble_edit_mark=0
}

function ble-edit+history-next {
  .ble-edit.history-goto $((_ble_edit_history_ind+1))
}
function ble-edit+history-prev {
  .ble-edit.history-goto $((_ble_edit_history_ind-1))
}
function ble-edit+history-beginning {
  .ble-edit.history-goto 0
}
function ble-edit+history-end {
  .ble-edit.history-goto "${#_ble_edit_history[@]}"
}

function ble-edit+history-expand-line {
  local hist_expanded
  hist_expanded="$(history -p -- "$_ble_edit_str" 2>/dev/null)" || return
  test "x$_ble_edit_str" = "x$hist_expanded" && return

  _ble_edit_str.reset "$hist_expanded"
  _ble_edit_ind="${#hist_expanded}"
  _ble_edit_mark=0
  _ble_edit_mark_active=
}

function ble-edit+forward-line-or-history-next {
  ble-edit+forward-line || ble-edit+history-next
}
function ble-edit+backward-line-or-history-prev {
  ble-edit+backward-line || ble-edit+history-prev
}


# 
# **** incremental search ****                                 @history.isearch

## 関数 .ble-edit-isearch.create-visible-text text ; ret
##   指定した文字列を表示する為の制御系列に変換します。
function .ble-edit-isearch.create-visible-text {
  local text="$1" ptext=
  local i iN=${#text}
  for ((i=0;i<iN;i++)); do
    .ble-text.s2c "$text" "$i"
    local code="$ret"
    if ((code<32)); then
      .ble-text.c2s "$((code+64))"
      ptext="$ptext[7m^$ret[m"
    elif ((code==127)); then
      ptext="$ptext[7m^?[m"
    else
      ptext="$ptext${text:i:1}"
    fi
  done
  ret="$ptext"
}

function .ble-edit-isearch.draw-line {
  # 出力
  local ll rr
  if test "x$_ble_edit_isearch_dir" = x-; then
    ll="<<" rr="  "
  else
    ll="  " rr=">>"
    text="  >>)"
  fi

  local text="(${#_ble_edit_isearch_arr[@]}: $ll $_ble_edit_history_ind $rr) \`$_ble_edit_isearch_str'"
  .ble-line-info.draw "$text"
}
function .ble-edit-isearch.erase-line {
  .ble-line-info.clear
}

function ble-edit+isearch/next {
  local needle="${1-$_ble_edit_isearch_str}" isMod="$2"
  # 検索
  local i ind=
  #echo $_ble_edit_history_ind
  if test "x$_ble_edit_isearch_dir" = 'x-'; then
    # backward-search
    
    for((i=_ble_edit_history_ind-(isMod?0:1);i>=0;i--)); do
      case "${_ble_edit_history[$i]}" in
      (*"$needle"*) ind="$i" ; break ;;
      esac
    done
  else
    # forward-search
    for((i=_ble_edit_history_ind+(isMod?0:1);i<${#_ble_edit_history[@]};i++)); do
      case "${_ble_edit_history[$i]}" in
      (*"$needle"*) ind="$i" ; break ;;
      esac
    done
  fi
  if test -z "$ind"; then
    # 見つからない場合
    .ble-edit.bell "isearch: \`$needle' not found"
    return
  fi
  
  # 見付かったら _ble_edit_isearch_arr を更新
  local pop= ilast="$((${#_ble_edit_isearch_arr[@]}-1))"
  if test "$ilast" -ge 0; then
    case "${_ble_edit_isearch_arr[$ilast]}" in
    ("$ind:"[-+]":$needle")
      pop=1 ;;
    esac
  fi
  if test -n "$pop"; then
    unset "_ble_edit_isearch_arr[$ilast]"
  else
    _ble_edit_isearch_arr+=("$_ble_edit_history_ind:$_ble_edit_isearch_dir:$_ble_edit_isearch_str")
  fi

  _ble_edit_isearch_str="$needle"
  .ble-edit.history-goto "$ind"
  .ble-edit-isearch.draw-line
}
function ble-edit+isearch/prev {
  local sz="${#_ble_edit_isearch_arr[@]}"
  ((sz==0)) && return 0

  local ilast=$((sz-1))
  local top="${_ble_edit_isearch_arr[$ilast]}"
  unset "_ble_edit_isearch_arr[$ilast]"

  .ble-edit.history-goto "${top%%:*}"; top="${top#*:}"
  _ble_edit_isearch_dir="${top%%:*}"; top="${top#*:}"
  _ble_edit_isearch_str="$top"

  # isearch 表示
  .ble-edit-isearch.draw-line
}

function ble-edit+isearch/forward {
  _ble_edit_isearch_dir=+
  ble-edit+isearch/next
}
function ble-edit+isearch/backward {
  _ble_edit_isearch_dir=-
  ble-edit+isearch/next
}
function ble-edit+isearch/self-insert {
  local code="${KEYS[0]&ble_decode_MaskChar}"
  ((code==0)) && return

  local ret needle
  .ble-text.c2s "$code"
  ble-edit+isearch/next "$_ble_edit_isearch_str$ret" 1
}
function ble-edit+isearch/exit {
  .ble-decode/keymap/pop
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=
  _ble_edit_isearch_str=
  .ble-edit-isearch.erase-line
}
function ble-edit+isearch/cancel {
  if test "${#_ble_edit_isearch_arr[@]}" -gt 0; then
    local line="${_ble_edit_isearch_arr[0]}"
    .ble-edit.history-goto "${line%%:*}"
  fi

  ble-edit+isearch/exit
}
function ble-edit+isearch/exit-default {
  ble-edit+isearch/exit

  for key in "${KEYS[@]}"; do
    .ble-decode-key "$key"
  done
}
function ble-edit+isearch/accept {
  ble-edit+isearch/exit
  ble-edit+accept-line
}
function ble-edit+isearch/exit-delete-forward-char {
  ble-edit+isearch/exit
  ble-edit+delete-forward-char
}

function ble-edit-setup-keymap+isearch {
  local ble_opt_default_keymap=isearch

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


function ble-edit+history-isearch-backward {
  .ble-decode/keymap/push isearch
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=-
  .ble-edit-isearch.draw-line
}
function ble-edit+history-isearch-forward {
  .ble-decode/keymap/push isearch
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=+
  .ble-edit-isearch.draw-line
}

# 
#------------------------------------------------------------------------------
# **** completion ****                                                    @comp

function .ble-edit-comp.initialize-vars {
  local COMP_LINE="$_ble_edit_str"
  local COMP_POINT="$_ble_edit_ind"

  # COMP_KEY
  local COMP_KEY="${KEYS[@]: -1}"
  local flag char
  ((
    flag=COMP_KEY&ble_decode_MaskFlag,
    char=COMP_KEY&ble_decode_MaskChar,
    flag==ble_decode_Ctrl&&(char==0x40||0x61<=char&&char<0x7B||0x5B<=char&&char<0x60)&&(
      COMP_KEY=char&0x31
    )
  ))

  local COMP_TYPE="TAB" # ? ! @ %

  # COMP_WORDS, COMP_CWORD
  local _default_wordbreaks=' 	
"'"'"'><=;|&(:}'
  GLOBIGNORE='*' IFS="${COMP_WORDBREAKS-$_default_wordbreaks}" eval '
    COMP_WORDS=($COMP_LINE)
    local _tmp=(${COMP_LINE::COMP_POINT}x)
    COMP_CWORD=$((${#_tmp[@]}-1))
  '

  _ble_comp_cword="${_tmp[$COMP_CWORD]%x}"
}

## 関数 .ble-edit-comp.common-part word cands... ; ret
function .ble-edit-comp.common-part {
  local word="$1"; shift
  local value isFirst=1
  for value in "$@"; do
    if test -n "$isFirst"; then
      isFirst=
      common="$value"
    else
      local i len1 len2 len
      ((len1=${#common},
        len2=${#value},
        len=len1<len2?len1:len2))
      for ((i=${#word};i<len;i++)); do
        test "x${common:i:1}" != "x${value:i:1}" && break
      done
      common="${common::i}"
    fi
  done

  ret="$common"
}

function .ble-edit-comp.complete-filename {
  local fhead="${_ble_edit_str::_ble_edit_ind}"
  local sword_sep=$'|&;()<> \t\n'
  fhead="${fhead##*[$sword_sep]}"

  # local files=(* .*)
  # local cands=($(compgen -W '"${files[@]}"' -- "$fhead"))
  local cands=($(compgen -f -- "$fhead"))
  if test ${#cands[@]} -eq 0; then
    .ble-edit.bell
    .ble-line-info.clear
    return
  fi

  local ret
  .ble-edit-comp.common-part "$fhead" "${cands[@]}"

  local common="$ret" ins="${ret:${#fhead}}"
  if ((${#cands[@]}==1)) && test -e "${cands[0]}"; then
    if test -d "${cands[0]}"; then
      ins="$ins/"
    else
      ins="$ins "
    fi
  fi
  if test -n "$ins"; then
    ble-edit+insert-string "$ins"
  else
    .ble-edit.bell
  fi

  if ((${#cands[@]}>1)); then
    local dir="${fhead%/*}"
    if test "$fhead" != "$dir"; then
      .ble-line-info.draw "${cands[*]#$dir/}"
    else
      .ble-line-info.draw "${cands[*]}"
    fi
  fi
}

function ble-edit+complete {
  .ble-edit-comp.complete-filename
}

## 実装途中
function ble-edit+complete-F {
  local COMP_LINE COMP_POINT COMP_KEY COMP_TYPE
  local COMP_WORDS COMP_CWORD _ble_comp_cword
  .ble-edit-comp.initialize-vars

  # -- call completion function --
  local COMPREPLY

  #■

  # -- common part completion --
  .ble-edit-comp.common-part "$_ble_comp_cword" "${COMPREPLY[@]}"
  local common="$ret" ins="${ret:${#fhead}}"
  ((${#cands[@]}==1)) && ins="$ins "
  if test -n "$ins"; then
    ble-edit+insert-string "$ins"
  else
    .ble-edit.bell
  fi
}

function ble-edit+command-help {
  local args=($_ble_edit_str)
  local cmd="${args[0]}"

  if test -z "$cmd"; then
    .ble-edit.bell
    return 1
  fi

  if ! type -t "$cmd" &>/dev/null; then
    .ble-edit.bell "command \`$cmd' not found"
    return 1
  fi
    
  local content ret
  content="$("$cmd" --help 2>&1)"; ret=$?
  if test $ret -eq 0 -a -n "$content"; then
    echo "$content" | less
    return
  fi

  content="$(man "$cmd" 2>&1)"; ret=$?
  if test $ret -eq 0 -a -n "$content"; then
    echo "$content" | less
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

if test -n "$bleopt_suppress_bash_output"; then
  declare _ble_edit_io_stdout
  declare _ble_edit_io_stderr
  if ((_ble_bash>40100)); then
    exec {_ble_edit_io_stdout}>&1
    exec {_ble_edit_io_stderr}>&2
  else
    ble/util/openat _ble_edit_io_stdout '>&1'
    ble/util/openat _ble_edit_io_stderr '>&2'
  fi
  # declare _ble_edit_io_fname1=/dev/null
  # declare _ble_edit_io_fname2=/dev/null
  declare _ble_edit_io_fname1="$_ble_base/tmp/$$.stdout"
  declare _ble_edit_io_fname2="$_ble_base/tmp/$$.stderr"

  function .ble-edit/stdout/on {
    exec 1>&$_ble_edit_io_stdout 2>&$_ble_edit_io_stderr
  }
  function .ble-edit/stdout/off {
    .ble-edit/stdout/check-stderr
    exec 1>>$_ble_edit_io_fname1 2>>$_ble_edit_io_fname2
  }
  function .ble-edit/stdout/finalize {
    .ble-edit/stdout/on
    test -f "$_ble_edit_io_fname1" && rm -f "$_ble_edit_io_fname1"
    test -f "$_ble_edit_io_fname2" && rm -f "$_ble_edit_io_fname2"
  }

  ## 関数 .ble-edit/stdout/check-stderr
  ##   bash が stderr にエラーを出力したかチェックし表示する。
  function .ble-edit/stdout/check-stderr {
    local file="${1:-$_ble_edit_io_fname2}"

    # if the visible bell function is already defined.
    if ble/util/isfunction .ble-term.visible-bell; then

      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   /dev/null の様なデバイスではなく、中身があるファイルの場合。
      if test -f "$file" -a -s "$file"; then
        local message= line
        while IFS= read -r line; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   例えば ~/bin/bash-3.1 等から実行していると
          #   "bash-3.1: ～" 等というエラーメッセージになる。
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* ]]; then
            message+="${message:+; }$line"
          fi
        done < "$file"
        
        test -n "$message" && .ble-term.visible-bell "$message"
        :> "$file"
      fi
    fi
  }

  # * bash-3.1, bash-3.2, bash-4.0 では C-d は直接検知できない。
  #   IGNOREEOF を設定しておくと C-d を押した時に
  #   stderr に bash が文句を吐くのでそれを捕まえて C-d が押されたと見做す。
  if ((_ble_bash<40000)); then
    function .ble-edit/stdout/trap-SIGUSR1 {
      local file="$_ble_edit_io_fname2.proc"
      if test -s "$file"; then
        content="$(< $file)"
        : > "$file"
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

    rm -f "$_ble_edit_io_fname2.pipe"
    mkfifo "$_ble_edit_io_fname2.pipe"
    {
      while IFS= read -r line; do
        SPACE=$' \n\t'
        if [[ $line == *[^$SPACE]* ]]; then
          echo "$line" >> "$_ble_edit_io_fname2"
        fi

        if [[ $bleopt_ignoreeof_message && $line = *$bleopt_ignoreeof_message* ||
                  $line = *'Use "exit" to leave the shell.'* ||
                  $line = *'ログアウトする為には exit を入力して下さい'* ||
                  $line = *'シェルから脱出するには "exit" を使用してください。'* ||
                  $line = *'シェルから脱出するのに "exit" を使いなさい.'* ]]
        then
          echo eof >> "$_ble_edit_io_fname2.proc"
          kill -USR1 $$
          sleep 0.1 # 連続で送ると bash が落ちるかも (落ちた事はないが念の為)
        fi
      done < "$_ble_edit_io_fname2.pipe" &>/dev/null &
      disown $!
    } &>/dev/null
    
    ble/util/openat _ble_edit_fd_stderr_pipe '> "$_ble_edit_io_fname2.pipe"'

    function .ble-edit/stdout/off {
      .ble-edit/stdout/check-stderr
      exec 1>>$_ble_edit_io_fname1 2>&$_ble_edit_fd_stderr_pipe
    }
  fi
fi

_ble_edit_detach_flag=
function .ble-decode-byte:bind/exit-trap {
  # シグナルハンドラの中では stty は bash によって設定されている。
  .ble-stty.exit-trap
  exit 0
}
function .ble-decode-byte:bind/check-detach {
  if test -n "$_ble_edit_detach_flag"; then
    type="$_ble_edit_detach_flag"
    _ble_edit_detach_flag=
    #.ble-term.visible-bell ' Bye!! '
    .ble-edit-finalize
    ble-decode-detach
    .ble-stty.finalize

    READLINE_LINE="" READLINE_POINT=0

    if [[ "$type" == exit ]]; then
      # ※この部分は現在使われていない。
      #   exit 時の処理は trap EXIT を用いて行う事に決めた為。
      #   一応 _ble_edit_detach_flag=exit と直に入力する事で呼び出す事はできる。

      # exit
      echo '$_ble_term_sgr_fghb[ble: exit]$_ble_term_sgr0' 1>&2
      .ble-edit-draw.update

      # bind -x の中から exit すると bash が stty を「前回の状態」に復元してしまう様だ。
      # シグナルハンドラの中から exit すれば stty がそのままの状態で抜けられる様なのでそうする。
      trap '.ble-decode-byte:bind/exit-trap' RTMAX
      kill -RTMAX $$
    else
      echo "$_ble_term_sgr_fghb[ble: detached]$_ble_term_sgr0" 1>&2
      .ble-edit-draw.update
    fi
    return 0
  else
    return 1
  fi
}

if ((_ble_bash>=40100)); then
  function .ble-decode-byte:bind/head {
    .ble-edit/stdout/on

    if [[ -z $bleopt_suppress_bash_output ]]; then
      .ble-edit-draw.redraw-cache # bash-4.1 以降では呼出直前にプロンプトが消される
    fi
  }
else
  function .ble-decode-byte:bind/head {
    .ble-edit/stdout/on

    if [[ -z $bleopt_suppress_bash_output ]]; then
      # bash-3.*, bash-4.0 では呼出直前に次の行に移動する
      ((_ble_line_y++,_ble_line_x=0))
      local DRAW_BUFF=()
      ble-edit/draw/goto "${_ble_edit_cur[0]}" "${_ble_edit_cur[1]}"
      ble-edit/draw/flush
    fi
  }
fi

if ((_ble_bash>40000)); then
  function .ble-decode-byte:bind/tail {
    .ble-edit-draw.update-adjusted
    .ble-edit/stdout/off
  }
else
  IGNOREEOF=10000
  function .ble-decode-byte:bind/tail {
    .ble-edit-draw.update # bash-3 では READLINE_LINE を設定する方法はないので常に 0 幅
    .ble-edit/stdout/off
  }
fi

## 関数 _ble_edit_accept_line= .ble-edit+accept-line/process+$bleopt_exec_type;
##   指定したコマンドを実行します。
## @param[in,out] _ble_edit_accept_line
##   実行するコマンドの配列を指定します。実行したコマンドは削除するか空文字列を代入します。
## @return
##   戻り値が 0 の場合、終端 (.ble-decode-byte:bind/tail) に対する処理も行われた事を意味します。
##   つまり、そのまま ble-decode-byte:bind から抜ける事を期待します。
##   それ以外の場合には終端処理をしていない事を表します。

function ble-decode-byte:bind {
  local dbg="$*"
  .ble-decode-byte:bind/head
  .ble-decode-bind.uvw
  .ble-stty.enter

  while test $# -gt 0; do
    "ble-decode-byte+$ble_opt_input_encoding" "$1"
    shift
  done

  ".ble-edit+accept-line/process+$bleopt_exec_type" && return 0

  .ble-decode-byte:bind/tail
  return 0
}


function ble-edit-setup-keymap+emacs {
  local ble_opt_default_keymap=emacs

  # ins
  ble-bind -f __defchar__ self-insert
  ble-bind -f 'C-q'       quoted-insert
  ble-bind -f 'C-v'       quoted-insert

  # shell function
  ble-bind -f 'C-c'    discard-line
  ble-bind -f 'C-j'    accept-line
  ble-bind -f 'C-m'    accept-single-line-or-newline
  ble-bind -f 'RET'    accept-single-line-or-newline
  ble-bind -f 'C-o'    accept-and-next
  ble-bind -f 'C-g'    bell
  ble-bind -f 'C-l'    clear-screen
  ble-bind -f 'M-l'    redraw-line
  ble-bind -f 'C-i'    complete
  ble-bind -f 'TAB'    complete
  ble-bind -f 'f1'     command-help

  # history
  ble-bind -f 'C-r'    history-isearch-backward
  ble-bind -f 'C-s'    history-isearch-forward
  ble-bind -f 'C-RET'  history-expand-line
  ble-bind -f 'M-<'    history-beginning
  ble-bind -f 'M->'    history-end

  # kill
  ble-bind -f 'C-@'      set-mark
  ble-bind -f 'M-SP'     set-mark
  ble-bind -f 'C-x C-x'  exchange-point-and-mark
  ble-bind -f 'C-w'      'kill-region-or uword'
  ble-bind -f 'M-w'      'copy-region-or uword'
  ble-bind -f 'C-y'      yank

  # charwise operations
  ble-bind -f 'C-f'      'nomarked forward-char'
  ble-bind -f 'C-b'      'nomarked backward-char'
  ble-bind -f 'right'    'nomarked forward-char'
  ble-bind -f 'left'     'nomarked backward-char'
  ble-bind -f 'S-C-f'    'marked forward-char'
  ble-bind -f 'S-C-b'    'marked backward-char'
  ble-bind -f 'S-right'  'marked forward-char'
  ble-bind -f 'S-left'   'marked backward-char'
  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'
  ble-bind -f 'C-h'      'delete-region-or backward-char'
  ble-bind -f 'delete'   'delete-region-or forward-char'
  ble-bind -f 'DEL'      'delete-region-or backward-char'
  ble-bind -f 'C-t'      transpose-chars

  # wordwise operations
  ble-bind -f 'C-right'   'nomarked forward-cword'
  ble-bind -f 'C-left'    'nomarked backward-cword'
  ble-bind -f 'M-right'   'nomarked forward-sword'
  ble-bind -f 'M-left'    'nomarked backward-sword'
  ble-bind -f 'S-C-right' 'marked forward-cword'
  ble-bind -f 'S-C-left'  'marked backward-cword'
  ble-bind -f 'S-M-right' 'marked forward-sword'
  ble-bind -f 'S-M-left'  'marked backward-sword'
  ble-bind -f 'M-d'       kill-forward-cword
  ble-bind -f 'M-h'       kill-backward-cword
  ble-bind -f 'C-delete'  delete-forward-cword  # C-delete
  ble-bind -f 'C-_'       delete-backward-cword # C-BS
  ble-bind -f 'M-delete'  copy-forward-sword    # M-delete
  ble-bind -f 'M-DEL'     copy-backward-sword   # M-BS

  ble-bind -f 'M-f'       'nomarked forward-cword'
  ble-bind -f 'M-b'       'nomarked backward-cword'
  ble-bind -f 'M-F'       'marked forward-cword'
  ble-bind -f 'M-B'       'marked backward-cword'

  # linewise operations
  ble-bind -f 'C-a'       'nomarked beginning-of-line'
  ble-bind -f 'C-e'       'nomarked end-of-line'
  ble-bind -f 'home'      'nomarked beginning-of-line'
  ble-bind -f 'end'       'nomarked end-of-line'
  ble-bind -f 'M-m'       'nomarked beginning-of-line'
  ble-bind -f 'S-C-a'     'marked beginning-of-line'
  ble-bind -f 'S-C-e'     'marked end-of-line'
  ble-bind -f 'S-home'    'marked beginning-of-line'
  ble-bind -f 'S-end'     'marked end-of-line'
  ble-bind -f 'S-M-m'     'marked beginning-of-line'
  ble-bind -f 'C-k'       kill-forward-line
  ble-bind -f 'C-u'       kill-backward-line

  ble-bind -f 'C-p'    'nomarked backward-line-or-history-prev'
  ble-bind -f 'up'     'nomarked backward-line-or-history-prev'
  ble-bind -f 'C-n'    'nomarked forward-line-or-history-next'
  ble-bind -f 'down'   'nomarked forward-line-or-history-next'
  ble-bind -f 'S-C-p'  'marked backward-line'
  ble-bind -f 'S-up'   'marked backward-line'
  ble-bind -f 'S-C-n'  'marked forward-line'
  ble-bind -f 'S-down' 'marked forward-line'

  ble-bind -f 'C-home'   'nomarked beginning-of-text'
  ble-bind -f 'C-end'    'nomarked end-of-text'
  ble-bind -f 'S-C-home' 'marked beginning-of-text'
  ble-bind -f 'S-C-end'  'marked end-of-text'

  ble-bind -f 'C-x C-v'   display-shell-version
  # ble-bind -f 'C-x' bell
  ble-bind -cf 'C-z' fg
  ble-bind -cf 'M-z' fg
  ble-bind -f 'C-[' bell
  ble-bind -f 'C-\' bell
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

function .ble-edit.default-key-bindings {
  ble-edit-setup-keymap+emacs
  ble-edit-setup-keymap+isearch
}

function ble-edit-initialize {
  .ble-cursor.construct-prompt.initialize
}
function ble-edit-attach {
  # * history-load は initialize ではなく attach で行う。
  #   detach してから attach する間に
  #   追加されたエントリがあるかもしれないので。
  .ble-edit.history-load

  .ble-edit/edit/attach
}
function .ble-edit-finalize {
  .ble-edit/stdout/finalize
  .ble-edit/edit/detach
}
