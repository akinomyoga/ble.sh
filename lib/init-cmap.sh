#!/bin/bash

#
# 以下は ble-decode.sh にて既定で定義される特殊キー
#
# 制御文字
#
#   TAB  RET
#
#   NUL  SOH  STX  ETX  EOT  ENQ  ACK  BEL
#   BS   HT   LF   VT   FF   CR   SO   SI
#   DLE  DC1  DC2  DC3  DC4  NAK  SYN  ETB
#   CAN  EM   SUB  ESC  FS   GS   RS   US
#
#   SP   DEL
#
#   PAD  HOP  BPH  NBH  IND  NEL  SSA  ESA
#   HTS  HTJ  VTS  PLD  PLU  RI   SS2  SS3
#   DCS  PU1  PU2  STS  CCH  MW   SPA  EPA
#   SOS  SGCI SCI  CSI  ST   OSC  PM   APC
#
# 特殊キーバインディング
#
#   __batch_char__
#   __defchar__
#   __default__
#   __before_widget__
#   __after_widget__
#   __attach__
#
# 修飾キー
#
#   shift alter control meta super hyper
#
# 端末の応答を処理した時
#
#   __ignore__
#
# Note: ble-decode.sh における特殊キーの変更に際して、
# この一覧を更新することでキャッシュの更新が起こるようにしている。
#
# 2019-05-06 ble-update 関連でバグがあったのを潰したので更新。
# 2020-04-13 cmap キャッシュ生成のバグ修正に伴う更新。

function ble/init:cmap/bind-single-csi {
  ble-bind -k "ESC [ $1" "$2"
  ble-bind -k "CSI $1" "$2"
}
function ble/init:cmap/bind-keypad-key {
  local Ft=$1 name=$2
  ble-bind --csi "$Ft" "$name"
  (($3&1)) && ble-bind -k "ESC O $Ft" "$name"
  (($3&2)) && ble-bind -k "ESC ? $Ft" "$name"
}

function ble/init:cmap/initialize {
  # Synonyms
  #   paste = S-insert [rxvt]
  #   scroll_up = S-prior [rxvt]
  #   scroll_down = S-next [rxvt]
  #   help = f15 [rxvt]
  #   menu = f16 [rxvt]
  #   print = f16 [xterm]
  #   deleteline = A-delete

  ble-edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences..."

  # pc-style keys
  # # vt52, xterm, rxvt
  # ble-bind --csi '1~' find
  # ble-bind --csi '2~' insert
  # ble-bind --csi '3~' delete # execute
  # ble-bind --csi '4~' select
  # ble-bind --csi '5~' prior
  # ble-bind --csi '6~' next
  # ble-bind --csi '7~' home
  # ble-bind --csi '8~' end

  # # cygwin, screen, rosaterm
  # ble-bind --csi '1~' home
  # ble-bind --csi '2~' insert
  # ble-bind --csi '3~' delete
  # ble-bind --csi '4~' end
  # ble-bind --csi '5~' prior
  # ble-bind --csi '6~' next

  # # vt100 (seems minority)
  # ble-bind --csi '1~' insert
  # ble-bind --csi '2~' home
  # ble-bind --csi '3~' prior
  # ble-bind --csi '4~' delete
  # ble-bind --csi '5~' end
  # ble-bind --csi '6~' next

  # 順番を固定
  ble-decode-kbd/generate-keycode insert
  ble-decode-kbd/generate-keycode home
  ble-decode-kbd/generate-keycode prior
  ble-decode-kbd/generate-keycode delete
  ble-decode-kbd/generate-keycode end
  ble-decode-kbd/generate-keycode next

  local kend; ble/util/assign kend 'tput @7 2>/dev/null || tput kend 2>/dev/null'
  if [[ $kend == $'\e[5~' ]]; then
    # vt100
    ble-bind --csi '1~' insert
    ble-bind --csi '2~' home
    ble-bind --csi '3~' prior
    ble-bind --csi '4~' delete
    ble-bind --csi '5~' end
    ble-bind --csi '6~' next
  else
    # Note: openSUSE の /etc/inputrc.keys が home/end と find/select
    #   を別のキーと見做して誰も使わない keybinding を設定しているので、
    #   home/end が上書きされてしまう。仕方がないので TERM=xterm の時
    #   のみ find/select を独立したキーとして取り扱う事にする。これで
    #   動かなくなる設定も存在するかもしれないが、取り敢えず openSUSE
    #   inputrc を優先させてみる事にする。
    #

    # 調べると DEC keyboard では home/end の位置に find/select と印字
    # されている。幾つかの端末で 1~/4~ が home/end になっているのはこ
    # れが由来だろう。
    if [[ $kend == $'\e[F' && ( $TERM == xterm || $TERM == xterm-* || $TERM == kvt ) ]]; then
      ble-bind --csi '1~' find
      ble-bind --csi '4~' select
    else
      ble-bind --csi '1~' home
      ble-bind --csi '4~' end
    fi
    ble-bind --csi '2~' insert
    ble-bind --csi '3~' delete
    ble-bind --csi '5~' prior
    ble-bind --csi '6~' next
  fi
  ble-bind --csi '7~' home
  ble-bind --csi '8~' end

  # vt220, xterm, rxvt
  ble-bind --csi '11~' f1
  ble-bind --csi '12~' f2
  ble-bind --csi '13~' f3
  ble-bind --csi '14~' f4
  ble-bind --csi '15~' f5
  ble-bind --csi '17~' f6
  ble-bind --csi '18~' f7
  ble-bind --csi '19~' f8
  ble-bind --csi '20~' f9
  ble-bind --csi '21~' f10
  ble-bind --csi '23~' f11
  ble-bind --csi '24~' f12
  ble-bind --csi '25~' f13
  ble-bind --csi '26~' f14
  ble-bind --csi '28~' f15
  ble-bind --csi '29~' f16
  ble-bind --csi '31~' f17
  ble-bind --csi '32~' f18
  ble-bind --csi '33~' f19
  ble-bind --csi '34~' f20

  ble-bind --csi '200~' paste_begin
  ble-bind --csi '201~' paste_end

  # keypad
  #   vt100, xterm, application mode
  #   ESC ? は vt52 由来
  #
  #   Note: kp～ と通常のキーを区別しても binding が大変なだけで
  #   余り利点もないので取り敢えずこの設定では区別しない。
  ble-bind -k 'ESC ? SP' SP # kpspace
  ble-bind -k 'ESC O SP' SP # kpspace
  ble/init:cmap/bind-keypad-key 'A' up    1
  ble/init:cmap/bind-keypad-key 'B' down  1
  ble/init:cmap/bind-keypad-key 'C' right 1
  ble/init:cmap/bind-keypad-key 'D' left  1
  ble/init:cmap/bind-keypad-key 'E' begin 1
  ble/init:cmap/bind-keypad-key 'F' end   1
  ble/init:cmap/bind-keypad-key 'H' home  1
  ble/init:cmap/bind-keypad-key 'I' TAB   3 # kptab
  ble/init:cmap/bind-keypad-key 'M' RET   3 # kpent
  ble/init:cmap/bind-keypad-key 'P' f1    1 # kpf1 # Note: 普通の f1-f4
  ble/init:cmap/bind-keypad-key 'Q' f2    1 # kpf2 #   に対してこれらの
  ble/init:cmap/bind-keypad-key 'R' f3    1 # kpf3 #   シーケンスを送る
  ble/init:cmap/bind-keypad-key 'S' f4    1 # kpf4 #   端末もある。
  ble/init:cmap/bind-keypad-key 'j' '*'   3 # kpmul
  ble/init:cmap/bind-keypad-key 'k' '+'   3 # kpadd
  ble/init:cmap/bind-keypad-key 'l' ','   3 # kpsep
  ble/init:cmap/bind-keypad-key 'm' '-'   3 # kpsub
  ble/init:cmap/bind-keypad-key 'n' '.'   3 # kpdec
  ble/init:cmap/bind-keypad-key 'o' '/'   3 # kpdiv
  ble/init:cmap/bind-keypad-key 'p' '0'   3 # kp0
  ble/init:cmap/bind-keypad-key 'q' '1'   3 # kp1
  ble/init:cmap/bind-keypad-key 'r' '2'   3 # kp2
  ble/init:cmap/bind-keypad-key 's' '3'   3 # kp3
  ble/init:cmap/bind-keypad-key 't' '4'   3 # kp4
  ble/init:cmap/bind-keypad-key 'u' '5'   3 # kp5
  ble/init:cmap/bind-keypad-key 'v' '6'   3 # kp6
  ble/init:cmap/bind-keypad-key 'w' '7'   3 # kp7
  ble/init:cmap/bind-keypad-key 'x' '8'   3 # kp8
  ble/init:cmap/bind-keypad-key 'y' '9'   3 # kp9
  ble/init:cmap/bind-keypad-key 'X' '='   3 # kpeq

  # rxvt
  #   Note: "CSI code @", "CSI code ^" は本体側で特別に処理している。
  ble-bind -k 'ESC [ Z'     S-TAB
  ble-bind -k 'ESC O a'     C-up
  ble-bind -k 'ESC [ a'     S-up
  ble-bind -k 'ESC O b'     C-down
  ble-bind -k 'ESC [ b'     S-down
  ble-bind -k 'ESC O c'     C-right
  ble-bind -k 'ESC [ c'     S-right
  ble-bind -k 'ESC O d'     C-left
  ble-bind -k 'ESC [ d'     S-left
  ble-bind -k 'ESC [ 2 $'   S-insert # ECMA-48 違反
  ble-bind -k 'ESC [ 3 $'   S-delete # ECMA-48 違反
  ble-bind -k 'ESC [ 5 $'   S-prior  # ECMA-48 違反
  ble-bind -k 'ESC [ 6 $'   S-next   # ECMA-48 違反
  ble-bind -k 'ESC [ 7 $'   S-home   # ECMA-48 違反
  ble-bind -k 'ESC [ 8 $'   S-end    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 3 $' S-f11    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 4 $' S-f12    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 5 $' S-f13    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 6 $' S-f14    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 8 $' S-f15    # ECMA-48 違反
  ble-bind -k 'ESC [ 2 9 $' S-f16    # ECMA-48 違反
  ble-bind -k 'ESC [ 3 1 $' S-f17    # ECMA-48 違反
  ble-bind -k 'ESC [ 3 2 $' S-f18    # ECMA-48 違反
  ble-bind -k 'ESC [ 3 3 $' S-f19    # ECMA-48 違反
  ble-bind -k 'ESC [ 3 4 $' S-f20    # ECMA-48 違反

  # cygwin specific
  ble/init:cmap/bind-single-csi '[ A' f1
  ble/init:cmap/bind-single-csi '[ B' f2
  ble/init:cmap/bind-single-csi '[ C' f3
  ble/init:cmap/bind-single-csi '[ D' f4
  ble/init:cmap/bind-single-csi '[ E' f5

  # sun specific (Solaris)
  ble/init:cmap/bind-single-csi '2 4 7 z' insert
  ble/init:cmap/bind-single-csi '2 1 4 z' home
  ble/init:cmap/bind-single-csi '2 2 0 z' end
  ble/init:cmap/bind-single-csi '2 2 2 z' prior
  ble/init:cmap/bind-single-csi '2 1 6 z' next
  ble/init:cmap/bind-single-csi '2 2 4 z' f1
  ble/init:cmap/bind-single-csi '2 2 5 z' f2
  ble/init:cmap/bind-single-csi '2 2 6 z' f3
  ble/init:cmap/bind-single-csi '2 2 7 z' f4
  ble/init:cmap/bind-single-csi '2 2 8 z' f5
  ble/init:cmap/bind-single-csi '2 2 9 z' f6
  ble/init:cmap/bind-single-csi '2 3 0 z' f7
  ble/init:cmap/bind-single-csi '2 3 1 z' f8
  ble/init:cmap/bind-single-csi '2 3 2 z' f9
  ble/init:cmap/bind-single-csi '2 3 3 z' f10
  ble/init:cmap/bind-single-csi '2 3 4 z' f11
  ble/init:cmap/bind-single-csi '2 3 5 z' f12
  # ble/init:cmap/bind-single-csi '2 z'     insert # terminfo
  # ble/init:cmap/bind-single-csi '3 z'     delete # terminfo
  # ble/init:cmap/bind-single-csi '1 9 2 z' f11
  # ble/init:cmap/bind-single-csi '1 9 3 z' f12
  ble/init:cmap/bind-single-csi '1 z' find   # from xterm ctlseqs
  ble/init:cmap/bind-single-csi '4 z' select # from xterm ctlseqs

  # 修飾キー 'CAN @ ?'
  #
  #   取り敢えず CAN で始まる修飾キーは無効にしておく。何故なら、
  #   CAN (C-x) で始まるシーケンスをキーに当てはめてしまうと、
  #   C-x で終わるコマンド (exchange-point-and-mark) が曖昧になってしまう。
  #   結果として、次に非 @ の文字が来るまで確定しないので実行が遅れる。
  #   また C-x C-x の後で @h 等を入力したい場合に別の解釈になってしまう。
  #
  # ble-bind -k "CAN @ S" shift
  # ble-bind -k "CAN @ a" alter
  # ble-bind -k "CAN @ c" control
  # ble-bind -k "CAN @ h" hyper
  # ble-bind -k "CAN @ m" meta
  # ble-bind -k "CAN @ s" super

  # st specific
  ble/init:cmap/bind-single-csi '2 J' S-home
  ble/init:cmap/bind-single-csi 'J' C-end
  ble/init:cmap/bind-single-csi 'K' S-end
  ble/init:cmap/bind-single-csi '4 l' S-insert
  ble/init:cmap/bind-single-csi 'L'   C-insert
  ble/init:cmap/bind-single-csi '4 h' insert
  # ble/init:cmap/bind-single-csi 'M'   C-delete # conflicts with kpent
  ble/init:cmap/bind-single-csi '2 K' S-delete
  ble/init:cmap/bind-single-csi 'P'   delete

  ble-edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences... done"
}

ble/init:cmap/initialize
