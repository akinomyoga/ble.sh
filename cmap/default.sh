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

function ble/cmap/default/bind-keypad-key {
  local Ft=$1 name=$2
  ble-bind --csi "$Ft" "$name"
  (($3&1)) && ble-bind -k "ESC O $Ft" "$name"
  (($3&2)) && ble-bind -k "ESC ? $Ft" "$name"
}

function ble-bind-function-key+default {
  # Synonyms
  #   paste = S-insert [rxvt]
  #   scroll_up = S-prior [rxvt]
  #   scroll_down = S-next [rxvt]
  #   help = f15 [rxvt]
  #   menu = f16 [rxvt]
  #   print = f16 [xterm]
  #   deleteline = A-delete

  ble-edit/info/immediate-show text "ble/cmap/default.sh: updating key sequences..."

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

  local kend; ble/util/assign kend 'tput kend'
  if [[ $kend == $'\e[5~' ]]; then
    # vt100
    ble-bind --csi '1~' insert
    ble-bind --csi '2~' home
    ble-bind --csi '3~' prior
    ble-bind --csi '4~' delete
    ble-bind --csi '5~' end
    ble-bind --csi '6~' next
  else
    ble-bind --csi '1~' home
    ble-bind --csi '2~' insert
    ble-bind --csi '3~' delete
    ble-bind --csi '4~' end
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
  ble/cmap/default/bind-keypad-key 'A' up    1
  ble/cmap/default/bind-keypad-key 'B' down  1
  ble/cmap/default/bind-keypad-key 'C' right 1
  ble/cmap/default/bind-keypad-key 'D' left  1
  ble/cmap/default/bind-keypad-key 'E' begin 1
  ble/cmap/default/bind-keypad-key 'F' end   1
  ble/cmap/default/bind-keypad-key 'H' home  1
  ble/cmap/default/bind-keypad-key 'I' TAB   3 # kptab
  ble/cmap/default/bind-keypad-key 'M' RET   3 # kpent
  ble/cmap/default/bind-keypad-key 'P' f1    1 # kpf1 # Note: 普通の f1-f4
  ble/cmap/default/bind-keypad-key 'Q' f2    1 # kpf2 #   に対してこれらの
  ble/cmap/default/bind-keypad-key 'R' f3    1 # kpf3 #   シーケンスを送る
  ble/cmap/default/bind-keypad-key 'S' f4    1 # kpf4 #   端末もある。
  ble/cmap/default/bind-keypad-key 'j' '*'   3 # kpmul
  ble/cmap/default/bind-keypad-key 'k' '+'   3 # kpadd
  ble/cmap/default/bind-keypad-key 'l' ','   3 # kpsep
  ble/cmap/default/bind-keypad-key 'm' '-'   3 # kpsub
  ble/cmap/default/bind-keypad-key 'n' '.'   3 # kpdec
  ble/cmap/default/bind-keypad-key 'o' '/'   3 # kpdiv
  ble/cmap/default/bind-keypad-key 'p' '0'   3 # kp0
  ble/cmap/default/bind-keypad-key 'q' '1'   3 # kp1
  ble/cmap/default/bind-keypad-key 'r' '2'   3 # kp2
  ble/cmap/default/bind-keypad-key 's' '3'   3 # kp3
  ble/cmap/default/bind-keypad-key 't' '4'   3 # kp4
  ble/cmap/default/bind-keypad-key 'u' '5'   3 # kp5
  ble/cmap/default/bind-keypad-key 'v' '6'   3 # kp6
  ble/cmap/default/bind-keypad-key 'w' '7'   3 # kp7
  ble/cmap/default/bind-keypad-key 'x' '8'   3 # kp8
  ble/cmap/default/bind-keypad-key 'y' '9'   3 # kp9
  ble/cmap/default/bind-keypad-key 'X' '='   3 # kpeq

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
  ble-bind -k 'ESC [ [ A' f1
  ble-bind -k 'ESC [ [ B' f2
  ble-bind -k 'ESC [ [ C' f3
  ble-bind -k 'ESC [ [ D' f4
  ble-bind -k 'ESC [ [ E' f5

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

  ble-edit/info/immediate-show text "ble/cmap/default.sh: updating key sequences... done"
}

ble-bind-function-key+default
