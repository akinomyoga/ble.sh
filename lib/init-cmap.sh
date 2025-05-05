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
#   __detach__
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
# 2020-04-13 cmap キャッシュ生成バグ修正に伴う更新。
# 2020-04-29 cmap キャッシュ生成バグ修正に伴う更新 (2)
# 2021-07-12 __detach__ 追加
# 2024-01-21 _ble_decode_csimap_dict 追加に伴う更新
# 2024-02-07 @ESC, @NUL コード変更に伴う更新
# 2024-06-05 "ble-decode/.hook => _ble_decode_hook" に伴う更新
# 2025-05-03 Add @PrO for "up" (ESC O A) vs "M-O" (ESC O) in Bash <= 4.4
# 2025-05-04 Add a new key "dsr0" for "ESC [ 0 n"

function ble/init:cmap/initialize-kbd {
  ble/decode/kbd/.set-keycode TAB  9
  ble/decode/kbd/.set-keycode RET  13

  ble/decode/kbd/.set-keycode NUL  0
  ble/decode/kbd/.set-keycode SOH  1
  ble/decode/kbd/.set-keycode STX  2
  ble/decode/kbd/.set-keycode ETX  3
  ble/decode/kbd/.set-keycode EOT  4
  ble/decode/kbd/.set-keycode ENQ  5
  ble/decode/kbd/.set-keycode ACK  6
  ble/decode/kbd/.set-keycode BEL  7
  ble/decode/kbd/.set-keycode BS   8
  ble/decode/kbd/.set-keycode HT   9  # aka TAB
  ble/decode/kbd/.set-keycode LF   10
  ble/decode/kbd/.set-keycode VT   11
  ble/decode/kbd/.set-keycode FF   12
  ble/decode/kbd/.set-keycode CR   13 # aka RET
  ble/decode/kbd/.set-keycode SO   14
  ble/decode/kbd/.set-keycode SI   15

  ble/decode/kbd/.set-keycode DLE  16
  ble/decode/kbd/.set-keycode DC1  17
  ble/decode/kbd/.set-keycode DC2  18
  ble/decode/kbd/.set-keycode DC3  19
  ble/decode/kbd/.set-keycode DC4  20
  ble/decode/kbd/.set-keycode NAK  21
  ble/decode/kbd/.set-keycode SYN  22
  ble/decode/kbd/.set-keycode ETB  23
  ble/decode/kbd/.set-keycode CAN  24
  ble/decode/kbd/.set-keycode EM   25
  ble/decode/kbd/.set-keycode SUB  26
  ble/decode/kbd/.set-keycode ESC  27
  ble/decode/kbd/.set-keycode FS   28
  ble/decode/kbd/.set-keycode GS   29
  ble/decode/kbd/.set-keycode RS   30
  ble/decode/kbd/.set-keycode US   31

  ble/decode/kbd/.set-keycode SP   32
  ble/decode/kbd/.set-keycode DEL  127

  ble/decode/kbd/.set-keycode PAD  128
  ble/decode/kbd/.set-keycode HOP  129
  ble/decode/kbd/.set-keycode BPH  130
  ble/decode/kbd/.set-keycode NBH  131
  ble/decode/kbd/.set-keycode IND  132
  ble/decode/kbd/.set-keycode NEL  133
  ble/decode/kbd/.set-keycode SSA  134
  ble/decode/kbd/.set-keycode ESA  135
  ble/decode/kbd/.set-keycode HTS  136
  ble/decode/kbd/.set-keycode HTJ  137
  ble/decode/kbd/.set-keycode VTS  138
  ble/decode/kbd/.set-keycode PLD  139
  ble/decode/kbd/.set-keycode PLU  140
  ble/decode/kbd/.set-keycode RI   141
  ble/decode/kbd/.set-keycode SS2  142
  ble/decode/kbd/.set-keycode SS3  143

  ble/decode/kbd/.set-keycode DCS  144
  ble/decode/kbd/.set-keycode PU1  145
  ble/decode/kbd/.set-keycode PU2  146
  ble/decode/kbd/.set-keycode STS  147
  ble/decode/kbd/.set-keycode CCH  148
  ble/decode/kbd/.set-keycode MW   149
  ble/decode/kbd/.set-keycode SPA  150
  ble/decode/kbd/.set-keycode EPA  151
  ble/decode/kbd/.set-keycode SOS  152
  ble/decode/kbd/.set-keycode SGCI 153
  ble/decode/kbd/.set-keycode SCI  154
  ble/decode/kbd/.set-keycode CSI  155
  ble/decode/kbd/.set-keycode ST   156
  ble/decode/kbd/.set-keycode OSC  157
  ble/decode/kbd/.set-keycode PM   158
  ble/decode/kbd/.set-keycode APC  159

  ble/decode/kbd/.set-keycode @ESC "$_ble_decode_IsolatedESC"
  ble/decode/kbd/.set-keycode @NUL "$_ble_decode_EscapedNUL"
  ble/decode/kbd/.set-keycode @PrO "$_ble_decode_PrefixO"

  local ret
  ble/decode/kbd/.generate-keycode __batch_char__
  _ble_decode_KCODE_BATCH_CHAR=$ret
  ble/decode/kbd/.generate-keycode __defchar__
  _ble_decode_KCODE_DEFCHAR=$ret
  ble/decode/kbd/.generate-keycode __default__
  _ble_decode_KCODE_DEFAULT=$ret
  ble/decode/kbd/.generate-keycode __before_widget__
  _ble_decode_KCODE_BEFORE_WIDGET=$ret
  ble/decode/kbd/.generate-keycode __after_widget__
  _ble_decode_KCODE_AFTER_WIDGET=$ret
  ble/decode/kbd/.generate-keycode __attach__
  _ble_decode_KCODE_ATTACH=$ret
  ble/decode/kbd/.generate-keycode __detach__
  _ble_decode_KCODE_DETACH=$ret

  ble/decode/kbd/.generate-keycode shift
  _ble_decode_KCODE_SHIFT=$ret
  ble/decode/kbd/.generate-keycode alter
  _ble_decode_KCODE_ALTER=$ret
  ble/decode/kbd/.generate-keycode control
  _ble_decode_KCODE_CONTROL=$ret
  ble/decode/kbd/.generate-keycode meta
  _ble_decode_KCODE_META=$ret
  ble/decode/kbd/.generate-keycode super
  _ble_decode_KCODE_SUPER=$ret
  ble/decode/kbd/.generate-keycode hyper
  _ble_decode_KCODE_HYPER=$ret

  # Note: 無視するキー。ble-decode-char に於いて
  #   端末からの通知などを処理した時に使う。
  ble/decode/kbd/.generate-keycode __ignore__
  _ble_decode_KCODE_IGNORE=$ret

  # Note: bleopt decode_error_cseq_discard
  ble/decode/kbd/.generate-keycode __error__
  _ble_decode_KCODE_ERROR=$ret

  # Note: line_limit による制限超過時のイベント
  ble/decode/kbd/.generate-keycode __line_limit__
  _ble_decode_KCODE_LINE_LIMIT=$ret

  # Note: 暫定的な対応なので後で変更するかもしれない
  ble/decode/kbd/.generate-keycode mouse
  _ble_decode_KCODE_MOUSE=$ret
  ble/decode/kbd/.generate-keycode mouse_move
  _ble_decode_KCODE_MOUSE_MOVE=$ret

  # Note: 以下は改めてそれぞれのファイルで参照される
  #   コードを固定する為にここで定義しておく。
  ble/decode/kbd/.generate-keycode auto_complete_enter

  builtin unset -f "$FUNCNAME"
}

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

function ble/init:cmap/initialize-keys {
  # Synonyms
  #   paste = S-insert [rxvt]
  #   scroll_up = S-prior [rxvt]
  #   scroll_down = S-next [rxvt]
  #   help = f15 [rxvt]
  #   menu = f16 [rxvt]
  #   print = f16 [xterm]
  #   deleteline = A-delete

  ble/edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences..."

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
  local ret
  ble/decode/kbd/.generate-keycode insert
  ble/decode/kbd/.generate-keycode home
  ble/decode/kbd/.generate-keycode prior
  ble/decode/kbd/.generate-keycode delete
  ble/decode/kbd/.generate-keycode end
  ble/decode/kbd/.generate-keycode next
  ble/decode/kbd/.generate-keycode find
  ble/decode/kbd/.generate-keycode select

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
  local kdch1; ble/util/assign kdch1 'tput kD 2>/dev/null || tput kdch1 2>/dev/null'
  [[ $kdch1 == $'\x7F' || $TERM == sun* ]] && ble-bind -k 'DEL' delete

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
  #   1: SS3 X, 2: ESC ? X, 4: CSI X の和。
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
  ble/init:cmap/bind-keypad-key 'I' focus 4 # Note: 1 (= SS3) は TAB と重複するので設定しない
  ble/init:cmap/bind-keypad-key 'O' blur  5

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

  # kitty specific "CSI ... u" sequences
  _ble_decode_csimap_kitty_u=(
    [57358]=capslock [57359]=scrolllock [57360]=numlock [57361]=print [57362]=pause [57363]=menu

    [57376]=f13 [57377]=f14 [57378]=f15 [57379]=f16 [57380]=f17 [57381]=f18 [57382]=f19 [57383]=f20
    [57384]=f21 [57385]=f22 [57386]=f23 [57387]=f24 [57388]=f25 [57389]=f26 [57390]=f27 [57391]=f28
    [57392]=f29 [57393]=f30 [57394]=f31 [57395]=f32 [57396]=f33 [57397]=f34 [57398]=f35

    [57399]=0 [57400]=1 [57401]=2 [57402]=3 [57403]=4 [57404]=5 [57405]=6 [57406]=7 [57407]=8 [57408]=9
    [57409]='.' [57410]='/' [57411]='*' [57412]='-' [57413]='+' [57414]=RET [57415]='=' [57416]=','
    [57417]=left [57418]=right [57419]=up [57420]=down
    [57421]=prior [57422]=next [57423]=home [57424]=end [57425]=insert [57426]=delete [57427]=begin

    [57428]=media_play [57429]=media_pause [57430]=media_play_pause [57431]=media_reverse
    [57432]=media_stop [57433]=media_fast_forward [57434]=media_rewind [57435]=media_track_next
    [57436]=media_track_prev [57437]=media_record [57438]=lower_volume [57439]=raise_volume
    [57440]=mute_volume

    [57441]=lshift [57442]=lcontrol [57443]=lalter [57444]=lsuper [57445]=lhyper [57446]=lmeta
    [57447]=rshift [57448]=rcontrol [57449]=ralter [57450]=rsuper [57451]=rhyper [57452]=rmeta
    [57453]=iso_shift3 [57454]=iso_shift5
  )
  local keyname
  for keyname in "${_ble_decode_csimap_kitty_u[@]}"; do
    ble/decode/kbd/.generate-keycode "$keyname"
  done

  # DSR(0): DSR response for DSR(5) (operating status).
  # Note: This is similar to kpdec described above, but the format of the
  # payload is different from the function-key sequences.
  ble/init:cmap/bind-single-csi '0 n' dsr0

  ble/edit/info/immediate-show text "ble/lib/init-cmap.sh: updating key sequences... done"

  builtin unset -f "$FUNCNAME"
}

## @fn ble/init:cmap/initialize-keys
##   @var[in] dump
##     The filename to write the cache
function ble/init:cmap/initialize {
  ble/edit/info/immediate-show text 'ble.sh: generating "'"$dump"'"...'
  ble/init:cmap/initialize-kbd
  ble/init:cmap/initialize-keys
  ble-bind -D | ble/bin/awk '
    {
      sub(/^declare +(-[aAilucnrtxfFgGI]+ +)?/, "");
      sub(/^-- +/, "");
    }
    /^_ble_decode_(cmap|KCODE|csimap|kbd)/ {
      if (!($0 ~ /^_ble_decode_csimap_kitty_u/))
        gsub(/["'\'']/, "");
      print
    }
  ' >| "$dump"

  # If ble.sh has not yet attached, we want to clear the processing message.
  [[ $_ble_attached ]] || ble/edit/info/immediate-clear

  builtin unset -f "$FUNCNAME"
}
ble/init:cmap/initialize
