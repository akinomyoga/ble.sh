#!/bin/bash

# 現在の bash の version に従って以下の二つのファイルを生成します:
#
#   $_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.bind
#   $_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.unbind
#
# Note: #D1300 bind -s で束縛するマクロの非終端文字は
#   decode.sh (ble/decode/nonblocking-read) でチェックする必要がある。
#   現在の実装では 0xC0 と 0xDF をチェックしている。
#   (( esc1B != 3 && esc1B1B )) の時には 0x1B も追加でチェックする必要がある。
#   マクロを追加する時にはそれに応じてチェックを追加する必要がある。

function ble/init:bind/append {
  local xarg="\"$1\":ble-decode/.hook $2; builtin eval -- \"\$_ble_decode_bind_hook\""
  local rarg=$1 condition=$3${3:+' && '}
  ble/util/print "${condition}builtin bind -x '${xarg//$q/$Q}'" >> "$fbind1"
  ble/util/print "${condition}builtin bind -r '${rarg//$q/$Q}'" >> "$fbind2"
}
function ble/init:bind/append-macro {
  local kseq1=$1 kseq2=$2 condition=$3${3:+' && '}
  local sarg="\"$kseq1\":\"$kseq2\"" rarg=$kseq1
  ble/util/print "${condition}builtin bind    '${sarg//$q/$Q}'" >> "$fbind1"
  ble/util/print "${condition}builtin bind -r '${rarg//$q/$Q}'" >> "$fbind2"
}
function ble/init:bind/bind-s {
  local sarg=$1
  ble/util/print "builtin bind '${sarg//$q/$Q}'" >> "$fbind1"
}

function ble/init:bind/generate-binder {
  local fbind1=$_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.bind
  local fbind2=$_ble_base_cache/decode.bind.$_ble_bash.$bleopt_input_encoding.unbind

  ble/edit/info/show text "ble.sh: updating binders..."

  : >| "$fbind1"
  : >| "$fbind2"

  local q=\' Q="'\\''"
  local altdqs00='\xC0\x80'
  local altdqs24='\xC0\x98'
  local altdqs27='\xC0\x9B'

  # ※bash-4.3 以降は bind -x の振る舞いがこれまでと色々と違う様だ
  #   何より 3 byte 以上の物にも bind できる様になった点が大きい (が ble.sh では使っていない)

  # * C-@ (0) は bash-4.3 では何故か bind -x すると
  #   bash: bash_execute_unix_command: コマンドのキーマップがありません
  #   bash_execute_unix_command: cannot find keymap for command
  #   になってしまう。"C-@ *" に全て割り当てても駄目である。
  #   bind '"\C-@":""' は使える様なので、UTF-8 の別表現に翻訳してしまう。
  local esc00=$((40300<=_ble_bash&&_ble_bash<50000))

  # * C-x (24) に単体で直接 bind -x するとクラッシュする問題。
  #   #D0017 #D0018 #D0057 #D0122 #D0148 #D0391 #D0583 #D1478
  #
  #   [症状]
  #   bash-4.3 を除く bash-3.0 ～ bash-4.4 の全てで、set -o emacs で問題が生じる。
  #   例えば C-x C-b C-b などと入力すると、bash-3.2 では無限ループになって固まる。
  #   bash-4.4 では "コマンドのキーマップがありません" というエラーメッセージになる。
  #   それ以外の bash では、何秒かしてクラッシュする。
  #   bash-5.0 では修正されたので対策は不要になった (#D1163)
  #
  #   [対処法1] "C-x ?" 全束縛 ... bash-3.0..4.2 で使用
  #
  #   C-x には直接 bind せずに 2 文字の組み合わせで bind -x '"\C-x?": ...' とする。
  #
  #   * bash-3.0..4.2: これをすると vi に切り替えた時に後遺症が残る。
  #     cmd_xmap[24] に submap が追加される事により、\C-x に対して \C-x\C-x の
  #     コマンドが実行される様になる。その対策として直接 "\C-x?" に対して bind
  #     -x するのではなくて、"\C-x?" をマクロで UTF-8 代替表現に置き換えて受信
  #     する。 (#D1478)
  #
  #   [対処法2] 却下 #D0583
  #   bind -s '"\C-x": "\xC0\x98"' のようにする。
  #   クラッシュはしなくなるが、謎の遅延が残る。
  #   遅延をなくすには 対処法1 を実行するしかない。
  #
  #   [対処法3] 単一 C-x (with \C-x\C-x shadow) ... bash-4.4 で使用 (#D1478)
  #
  #   一旦 bind -x '"\C-x\C-x":hook 24' としてから bind -r '\C-x\C-x' で削除す
  #   る。この後で bind -x '"\C-x":...' で timeout すると "\C-x\C-x" のコマンド
  #   が実行される。
  #
  #   * bash-3.0..4.2 で \C-x\C-x に一度でも bind すると C-x で timeout しなく
  #     なるので、この対策を実行するのは emacs keymap のみにする。
  #
  local bind18XX=0
  if ((40400<=_ble_bash&&_ble_bash<50000)); then
    # Insert a dummy entry in "cmd_xmap"
    ble/util/print "[[ -o emacs ]] && builtin bind 'set keyseq-timeout 1'" >> "$fbind1"
    fbind2=$fbind1 ble/init:bind/append '\C-x\C-x' 24 '[[ -o emacs ]]'
  elif ((_ble_bash<40300)); then
    bind18XX=1
  fi

  # ESC について
  #
  # * esc1B=1: bash-3 では "ESC *" の組合せも全部登録しておかないと駄目??
  #   (もしかすると bind -r 等に失敗していただけかも知れないが)
  #
  #   追記: bash-4.0 bash-4.3 でも必要
  #   追記: bash-4.1 でも bind -x '"\ez":fg' 等を一回もしていない場合は必要
  #   追記: この方法でも ESC を 2 つ以上連続で入力する時に
  #     bash_execute_unix_command のエラーが発生する。
  #
  # * esc1B=2: 2017-10-22 実は bind '"\e": "\xC0\x9B"' とすれば全バージョンで OK の様だ。
  #
  #   しかし、これだと単体の ESC と続きのある ESC の区別ができない。
  #   続きがあるとき Readline が標準入力からひとまとまりで読み取ってから hook を呼び出す。
  #   従って、標準入力に文字が残っているかどうか見ても判定できないし、
  #   標準入力から次の文字をタイムアウト付きで読み取るとシーケンスの順序が狂う。
  #
  # * esc1B=3: 2017-10-22 代替案として
  #
  #     bind '"\e":"\e[27;5;91~"'
  #     bind '"\e?":"\xC0\x9B?"'
  #     bind '"\e\e":"\xC0\x9B\e[27;5;91~"'
  #
  #   などの様に bind -s で1文字のものと2文字のものを両方登録して、
  #   Readline に ESC に続きがあるかどうかを判定させて単独 ESC を区別するという手がある。
  #
  local esc1B=3

  # esc1B5B (esc1B == 1 の時に有効)
  #
  # * bash-3.1
  #   ESC [ を bind -x で捕まえようとしてもエラーになるので、
  #   一旦 "ESC [" の ESC を UTF-8 2-byte code にしてから受信し直す。
  #   bash-3.1 で確認。bash-4.1 ではOK。他は未確認。
  # * bash-4.3, bash-4.1
  #   ESC *, ESC [ *, etc を全部割り当てないと以下のエラーになる。
  #   bash_execute_unix_command: cannot find keymap for command
  #   これを避ける為に二つの方針がある
  #   1 全てを登録する方針 (bindAllSeq)
  #   2 ESC [ を別のシーケンスに割り当てる (esc1B5B)
  #   初め 1 の方法を用いていたが 2 でも動く事が分かったので 2 を使う。
  #
  local esc1B5B=1 bindAllSeq=0

  # esc1B1B (esc1B != 3 の時に有効)
  #
  # * bash-4.1 では ESC ESC に bind すると
  #   bash_execute_unix_command: cannot find keymap for command
  #   が出るので ESC [ ^ に適当に redirect して ESC [ ^ を
  #   ESC ESC として解釈する様にする。
  #
  local esc1B1B=$((40100<=_ble_bash&&_ble_bash<40300))

  # Note: 'set convert-meta on' 対策
  #
  #   bind 'set convert-meta on' の時、bind -p '"\200": ...' などが
  #   "\C-@" などの cmd_xmap を上書きしてしまう。
  #   呼び出し元で一時的に 'set convert-meta off' になる様にしているが、
  #   保険として 128-255 を先に bind してから 0-127 を bind する。
  local i
  for i in {128..255} {0..127}; do
    local ret; ble/decode/c2dqs "$i"

    # *
    if ((i==0)); then
      # C-@
      if ((esc00)); then
        # ENCODING: UTF-8 2-byte code of 0 (UTF-8依存)
        ble/init:bind/append-macro '\C-@' "$altdqs00"
      else
        ble/init:bind/append "$ret" "$i"
      fi
    elif ((i==24)); then
      # C-x
      if ((bind18XX)); then
        ble/init:bind/append "$ret" "$i" '[[ ! -o emacs ]]'
      else
        ble/init:bind/append "$ret" "$i"
      fi
    elif ((i==27)); then
      # C-[
      if ((esc1B==0)); then
        ble/init:bind/append "$ret" "$i"
      elif ((esc1B==2)); then
        # ENCODING: UTF-8
        ble/init:bind/append-macro '\e' "$altdqs27"
      elif ((esc1B==3)); then
        # ENCODING: UTF-8 (_ble_decode_IsolatedESC U+07FF)
        ble/init:bind/append-macro '\e' '\xDF\xBF' # C-[
      fi
    else
      # Note: Bash-5.0 では \C-\\ で bind すると変な事になる #D1162 #D1078
      ((i==28&&_ble_bash>=50000)) && ret='\x1C'
      ble/init:bind/append "$ret" "$i"
    fi

    # # C-@ * for bash-4.3 (2015-02-11) 無駄?
    # ble/init:bind/append "\\C-@$ret" "0 $i"

    # C-x *
    if ((bind18XX)); then
      # emacs mode では "C-x ?" の組み合わせで登録する。
      # Note: 普通に bind -x すると cmd_xmap の \C-x が曖昧になって vi 側の単一
      # "C-x" が動かなくなるので、ここでは UTF-8 2B 表示を通して受信する。
      if ((i==0)); then
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$altdqs00" '[[ -o emacs ]]'
      elif ((i==24)); then
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$altdqs24" '[[ -o emacs ]]'
      else
        ble/init:bind/append-macro "\C-x$ret" "$altdqs24$ret"      '[[ -o emacs ]]'
      fi
    fi

    # ESC *
    if ((esc1B==3)); then
      if ((i==0)); then
        ble/init:bind/append-macro '\e'"$ret" "$altdqs27$altdqs00"
      elif ((bind18XX&&i==24)); then
        ble/init:bind/append-macro '\e'"$ret" "$altdqs27$altdqs24"
      else
        ble/init:bind/append-macro '\e'"$ret" "$altdqs27$ret"
      fi
    else
      if ((esc1B==1)); then
        # ESC [
        if ((i==91&&esc1B5B)); then
          # * obsoleted workaround
          #   ESC [ を CSI (encoded in utf-8) に変換して受信する。
          #   受信した後で CSI を ESC [ に戻す。
          #   CSI = \u009B = utf8{\xC2\x9B} = utf8{\302\233}
          # printf 'bind %q' '"\e[":"\302\233"'               >> "$fbind1"
          # ble/util/print "ble-bind -f 'CSI' '.CHARS 27 91'" >> "$fbind1"

          # ENCODING: \xC0\x9B is 2-byte code of ESC (UTF-8依存)
          ble/init:bind/append-macro '\e[' "$altdqs27["
        else
          ble/init:bind/append "\\e$ret" "27 $i"
        fi
      fi

      # ESC ESC
      if ((i==27&&esc1B1B)); then
        # ESC ESC for bash-4.1
        ble/init:bind/append-macro '\e\e' '\e[^'
        ble/util/print "ble-bind -k 'ESC [ ^' __esc__"      >> "$fbind1"
        ble/util/print "ble-bind -f __esc__ '.CHARS 27 27'" >> "$fbind1"
      fi
    fi
  done

  if ((bindAllSeq)); then
    # 決まったパターンのキーシーケンスは全て登録
    #   bash-4.3 で keymap が見付かりませんのエラーが出るので。
    # ※3文字以上の bind -x ができるのは bash-4.3 以降
    #   (bash-4.3-alpha で bugfix が入っている)
    ble/util/print 'source "$_ble_decode_bind_fbinder.bind"' >> "$fbind1"
    ble/util/print 'source "$_ble_decode_bind_fbinder.unbind"' >> "$fbind2"
  fi

  ble/function#try ble/encoding:"$bleopt_input_encoding"/generate-binder

  ble/edit/info/immediate-show text "ble.sh: updating binders... done"
}

ble/init:bind/generate-binder
