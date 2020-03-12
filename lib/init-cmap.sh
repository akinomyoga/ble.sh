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
# 特殊文字 (内部使用)
#
#   @ESC @NUL
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
# 2019-04-15 __error__ を追加したので keycode の再生成が必要。
# 2019-05-04 実験的に mouse, mouse_move を追加した。
# 2019-05-06 ble-update 関連でバグがあったのを潰したので更新。
# 2020-01-31 @ESC, @NUL を追加した。
# 2020-03-12 __line_limit__ を追加

function ble/init:cmap/bind-single-csi {
  ble-bind -k "ESC [ $1" "$2"
  ble-bind -k "CSI $1" "$2"
}
function ble/init:cmap/bind-single-ss3 {
  ble-bind -k "ESC O $1" "$2"
  ble-bind -k "SS3 $1" "$2"
}
function ble/init:cmap/bind-keypad-key {
  local Ft=$1 name=$2
  (($3&4)) && ble-bind --csi "$Ft" "$name"
  (($3&1)) && ble/init:cmap/bind-single-ss3 "$Ft" "$name"
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
    ble-bind --csi '1~' home
    ble-bind --csi '2~' insert
    ble-bind --csi '3~' delete
    ble-bind --csi '4~' end
    ble-bind --csi '5~' prior
    ble-bind --csi '6~' next
  fi
  ble-bind --csi '7~' home
  ble-bind --csi '8~' end
  local kdch1; ble/util/assign kdch1 'tput kD 2>/dev/null || tput kdch1 2>/dev/null'
  [[ $kdch1 == $'\x7F' ]] && ble-bind -k 'DEL' delete

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
  #
  # Note: ble/init:cmap/bind-keypad-key 第3引数は
  #   1: ESC ? X, 2: SS3 X, 4: CSI X の和。
  ble/init:cmap/bind-keypad-key 'SP' SP   3 # kpspace
  ble/init:cmap/bind-keypad-key 'A' up    5
  ble/init:cmap/bind-keypad-key 'B' down  5
  ble/init:cmap/bind-keypad-key 'C' right 5
  ble/init:cmap/bind-keypad-key 'D' left  5
  ble/init:cmap/bind-keypad-key 'E' begin 5
  ble/init:cmap/bind-keypad-key 'F' end   5
  ble/init:cmap/bind-keypad-key 'H' home  5
  ble/init:cmap/bind-keypad-key 'I' TAB   3 # kptab (Note: CSI I は xterm SM(?1004) focus と重複)
  ble/init:cmap/bind-keypad-key 'M' RET   7 # kpent
  ble/init:cmap/bind-keypad-key 'P' f1    5 # kpf1 # Note: 普通の f1-f4
  ble/init:cmap/bind-keypad-key 'Q' f2    5 # kpf2 #   に対してこれらの
  ble/init:cmap/bind-keypad-key 'R' f3    5 # kpf3 #   シーケンスを送る
  ble/init:cmap/bind-keypad-key 'S' f4    5 # kpf4 #   端末もある。
  ble/init:cmap/bind-keypad-key 'j' '*'   7 # kpmul
  ble/init:cmap/bind-keypad-key 'k' '+'   7 # kpadd
  ble/init:cmap/bind-keypad-key 'l' ','   7 # kpsep
  ble/init:cmap/bind-keypad-key 'm' '-'   7 # kpsub
  ble/init:cmap/bind-keypad-key 'n' '.'   7 # kpdec
  ble/init:cmap/bind-keypad-key 'o' '/'   7 # kpdiv
  ble/init:cmap/bind-keypad-key 'p' '0'   7 # kp0
  ble/init:cmap/bind-keypad-key 'q' '1'   7 # kp1
  ble/init:cmap/bind-keypad-key 'r' '2'   7 # kp2
  ble/init:cmap/bind-keypad-key 's' '3'   7 # kp3
  ble/init:cmap/bind-keypad-key 't' '4'   7 # kp4
  ble/init:cmap/bind-keypad-key 'u' '5'   7 # kp5
  ble/init:cmap/bind-keypad-key 'v' '6'   7 # kp6
  ble/init:cmap/bind-keypad-key 'w' '7'   7 # kp7
  ble/init:cmap/bind-keypad-key 'x' '8'   7 # kp8
  ble/init:cmap/bind-keypad-key 'y' '9'   7 # kp9
  ble/init:cmap/bind-keypad-key 'X' '='   7 # kpeq

  # xterm SM(?1004) Focus In/Out の通知
  ble-bind --csi 'I' focus
  ble-bind --csi 'O' blur

  # rxvt
  #   Note: "CSI code @", "CSI code ^" は本体側で特別に処理している。
  ble/init:cmap/bind-single-csi 'Z'     S-TAB
  ble/init:cmap/bind-single-ss3 'a'     C-up
  ble/init:cmap/bind-single-csi 'a'     S-up
  ble/init:cmap/bind-single-ss3 'b'     C-down
  ble/init:cmap/bind-single-csi 'b'     S-down
  ble/init:cmap/bind-single-ss3 'c'     C-right
  ble/init:cmap/bind-single-csi 'c'     S-right
  ble/init:cmap/bind-single-ss3 'd'     C-left
  ble/init:cmap/bind-single-csi 'd'     S-left
  ble/init:cmap/bind-single-csi '2 $'   S-insert # ECMA-48 違反
  ble/init:cmap/bind-single-csi '3 $'   S-delete # ECMA-48 違反
  ble/init:cmap/bind-single-csi '5 $'   S-prior  # ECMA-48 違反
  ble/init:cmap/bind-single-csi '6 $'   S-next   # ECMA-48 違反
  ble/init:cmap/bind-single-csi '7 $'   S-home   # ECMA-48 違反
  ble/init:cmap/bind-single-csi '8 $'   S-end    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 3 $' S-f11    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 4 $' S-f12    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 5 $' S-f13    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 6 $' S-f14    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 8 $' S-f15    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '2 9 $' S-f16    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '3 1 $' S-f17    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '3 2 $' S-f18    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '3 3 $' S-f19    # ECMA-48 違反
  ble/init:cmap/bind-single-csi '3 4 $' S-f20    # ECMA-48 違反

  # cygwin specific
  ble/init:cmap/bind-single-csi '[ A' f1
  ble/init:cmap/bind-single-csi '[ B' f2
  ble/init:cmap/bind-single-csi '[ C' f3
  ble/init:cmap/bind-single-csi '[ D' f4
  ble/init:cmap/bind-single-csi '[ E' f5

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

  ble-edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences... done"
}

ble/init:cmap/initialize
