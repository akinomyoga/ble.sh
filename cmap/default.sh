#!/bin/bash

#
# 以下は ble-decode.sh にて既定で定義される特殊キー
#
#   __defchar__
#   __default__
#   __before_command__
#   __after_command__
#   __attach__
#
#   shift alter control meta super hyper
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
# Note: ble-decode.sh における特殊キーの変更に際して、
# この一覧を更新することでキャッシュの更新が起こるようにしている。
#
# 2020-04-13 cmap キャッシュ生成のバグ修正に伴う更新。

function ble/cmap/default/bind-single-csi {
  ble-bind -k "ESC [ $1" "$2"
  ble-bind -k "CSI $1" "$2"
}
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

  echo -n "ble/cmap/default.sh: updating key sequences... " >&2

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
  ble-decode-kbd/.gen-keycode insert
  ble-decode-kbd/.gen-keycode home
  ble-decode-kbd/.gen-keycode prior
  ble-decode-kbd/.gen-keycode delete
  ble-decode-kbd/.gen-keycode end
  ble-decode-kbd/.gen-keycode next

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
  ble-bind -k 'ESC ? SP' kpspace
  ble-bind -k 'ESC O SP' kpspace
  ble/cmap/default/bind-keypad-key 'A' up    1
  ble/cmap/default/bind-keypad-key 'B' down  1
  ble/cmap/default/bind-keypad-key 'C' right 1
  ble/cmap/default/bind-keypad-key 'D' left  1
  ble/cmap/default/bind-keypad-key 'E' begin 1
  ble/cmap/default/bind-keypad-key 'F' end   1
  ble/cmap/default/bind-keypad-key 'H' home  1
  ble/cmap/default/bind-keypad-key 'I' kptab 3
  ble/cmap/default/bind-keypad-key 'M' kpent 3
  ble/cmap/default/bind-keypad-key 'P' f1    1
  ble/cmap/default/bind-keypad-key 'Q' f2    1
  ble/cmap/default/bind-keypad-key 'R' f3    1
  ble/cmap/default/bind-keypad-key 'S' f4    1
  ble/cmap/default/bind-keypad-key 'j' kpmul 3 # *
  ble/cmap/default/bind-keypad-key 'k' kpadd 3 # +
  ble/cmap/default/bind-keypad-key 'l' kpsep 3 # ,
  ble/cmap/default/bind-keypad-key 'm' kpsub 3 # -
  ble/cmap/default/bind-keypad-key 'n' kpdec 3 # .
  ble/cmap/default/bind-keypad-key 'o' kpdiv 3 # /
  ble/cmap/default/bind-keypad-key 'p' kp0   3
  ble/cmap/default/bind-keypad-key 'q' kp1   3
  ble/cmap/default/bind-keypad-key 'r' kp2   3
  ble/cmap/default/bind-keypad-key 's' kp3   3
  ble/cmap/default/bind-keypad-key 't' kp4   3
  ble/cmap/default/bind-keypad-key 'u' kp5   3
  ble/cmap/default/bind-keypad-key 'v' kp6   3
  ble/cmap/default/bind-keypad-key 'w' kp7   3
  ble/cmap/default/bind-keypad-key 'x' kp8   3
  ble/cmap/default/bind-keypad-key 'y' kp9   3
  ble/cmap/default/bind-keypad-key 'X' kpeq  3

  # rxvt
  ble-bind -k 'ESC [ Z' S-tab

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

  # st specific
  ble/cmap/default/bind-single-csi '2 J' S-home
  ble/cmap/default/bind-single-csi 'J'   C-end
  ble/cmap/default/bind-single-csi 'K'   S-end
  ble/cmap/default/bind-single-csi '4 l' S-insert
  ble/cmap/default/bind-single-csi 'L'   C-insert
  ble/cmap/default/bind-single-csi '4 h' insert
  # ble/cmap/default/bind-single-csi 'M'   C-delete # conflicts with kpent
  ble/cmap/default/bind-single-csi '2 K' S-delete
  ble/cmap/default/bind-single-csi 'P'   delete

  echo "ble/cmap/default.sh: updating key sequences... done" >&2
}

ble-bind-function-key+default
