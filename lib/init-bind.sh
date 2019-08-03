#!/bin/bash

# 現在の bash の version に従って以下の二つのファイルを生成します:
#
#   $_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.bind
#   $_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.unbind
#

function ble/init:bind/append {
  local xarg="\"$1\":ble-decode/.hook $2; builtin eval \"\$_ble_decode_bind_hook\""
  local rarg=$1 condition=$3
  ble/bin/echo "$condition${condition:+ && }builtin bind -x '${xarg//$apos/$APOS}'" >> "$fbind1"
  ble/bin/echo "$condition${condition:+ && }builtin bind -r '${rarg//$apos/$APOS}'" >> "$fbind2"
}
function ble/init:bind/bind-s {
  local sarg=$1
  ble/bin/echo "builtin bind '${sarg//$apos/$APOS}'" >> "$fbind1"
}
function ble/init:bind/bind-r {
  local rarg=$1
  ble/bin/echo "builtin bind -r '${rarg//$apos/$APOS}'" >> "$fbind2"
}

function ble/init:bind/generate-binder {
  local fbind1=$_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.bind
  local fbind2=$_ble_base_cache/ble-decode-bind.$_ble_bash.$bleopt_input_encoding.unbind

  ble-edit/info/show text "ble.sh: updating binders..."

  : >| "$fbind1"
  : >| "$fbind2"

  local apos=\' APOS="'\\''"

  # ※bash-4.3 以降は bind -x の振る舞いがこれまでと色々と違う様だ
  #   何より 3 byte 以上の物にも bind できる様になった点が大きい (が ble.sh では使っていない)

  # * C-@ (0) は bash-4.3 では何故か bind -x すると
  #   bash: bash_execute_unix_command: コマンドのキーマップがありません
  #   bash_execute_unix_command: cannot find keymap for command
  #   になってしまう。"C-@ *" に全て割り当てても駄目である。
  #   bind '"\C-@":""' は使える様なので、UTF-8 の別表現に翻訳してしまう。
  local esc00=$((_ble_bash>=40300))

  # * C-x (24) に単体で直接 bind -x するとクラッシュする問題。
  #
  #   [症状]
  #   bash-4.3 を除く bash-3.0 ～ bash-4.4 の全てで、set -o emacs で問題が生じる。
  #   例えば C-x C-b C-b などと入力すると、bash-3.2 では無限ループになって固まる。
  #   bash-4.4 では "コマンドのキーマップがありません" というエラーメッセージになる。
  #   それ以外の bash では、何秒かしてクラッシュする。
  #   bash-5.0 では修正されたので対策は不要になった (#D1163)
  #
  #   [対処法1]
  #   C-x には直接 bind せずに 2 文字の組み合わせで bind -x '"\C-x?": ...' とする。
  #
  #   [対処法2] 却下 #D0583
  #   bind -s '"\C-x": "\xC0\x98"' のようにする。
  #   クラッシュはしなくなるが、謎の遅延が残る。
  #   遅延をなくすには 対処法1 を実行するしかない。
  #
  local bind18XX=$((_ble_bash<40300||40400<=_ble_bash&&_ble_bash<50000))

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
    local ret; ble-decode-bind/c2dqs "$i"

    # *
    if ((i==0)); then
      # C-@
      if ((esc00)); then
        # ENCODING: UTF-8 2-byte code of 0 (UTF-8依存)
        ble/init:bind/bind-s '"\C-@":"\xC0\x80"'
        ble/init:bind/bind-r '\C-@'
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
        ble/init:bind/bind-s '"\e":"\xC0\x9B"'
        ble/init:bind/bind-r '\e'
      elif ((esc1B==3)); then
        # ENCODING: UTF-8 (_ble_decode_IsolatedESC U+07FF)
        ble/init:bind/bind-s '"\e":"\xDF\xBF"' # C-[
        ble/init:bind/bind-r '\e'
      fi
    else
      # Note: Bash-5.0 では \C-\\ で bind すると変な事になる #D1162 #D1078
      ((i==28&&_ble_bash>=50000)) && ret='\x1C'
      ble/init:bind/append "$ret" "$i"
    fi

    # # C-@ * for bash-4.3 (2015-02-11) 無駄?
    # ble/init:bind/append "\\C-@$ret" "0 $i"

    # C-x *
    ((bind18XX)) && ble/init:bind/append "$ret" "24 $i" '[[ -o emacs ]]'

    # ESC *
    if ((esc1B==3)); then
      ble/init:bind/bind-s '"\e'"$ret"'":"\xC0\x9B'"$ret"'"'
      ble/init:bind/bind-r '\e'"$ret"
    else
      if ((esc1B==1)); then
        # ESC [
        if ((i==91&&esc1B5B)); then
          # * obsoleted workaround
          #   ESC [ を CSI (encoded in utf-8) に変換して受信する。
          #   受信した後で CSI を ESC [ に戻す。
          #   CSI = \u009B = utf8{\xC2\x9B} = utf8{\302\233}
          # printf 'bind %q' '"\e[":"\302\233"'               >> "$fbind1"
          # ble/bin/echo "ble-bind -f 'CSI' '.ble-decode-char 27 91'" >> "$fbind1"

          # ENCODING: \xC0\x9B is 2-byte code of ESC (UTF-8依存)
          ble/init:bind/bind-s '"\e[":"\xC0\x9B["'
          ble/init:bind/bind-r '\e['
        else
          ble/init:bind/append "\\e$ret" "27 $i"
        fi
      fi

      # ESC ESC
      if ((i==27&&esc1B1B)); then
        # ESC ESC for bash-4.1
        ble/init:bind/bind-s '"\e\e":"\e[^"'
        ble/bin/echo "ble-bind -k 'ESC [ ^' __esc__"                >> "$fbind1"
        ble/bin/echo "ble-bind -f __esc__ '.ble-decode-char 27 27'" >> "$fbind1"
        ble/init:bind/bind-r '\e\e'
      fi
    fi
  done

  if ((bindAllSeq)); then
    # 決まったパターンのキーシーケンスは全て登録
    #   bash-4.3 で keymap が見付かりませんのエラーが出るので。
    # ※3文字以上の bind -x ができるのは bash-4.3 以降
    #   (bash-4.3-alpha で bugfix が入っている)
    ble/bin/echo 'source "$_ble_decode_bind_fbinder.bind"' >> "$fbind1"
    ble/bin/echo 'source "$_ble_decode_bind_fbinder.unbind"' >> "$fbind2"
  fi

  ble/function#try ble/encoding:"$bleopt_input_encoding"/generate-binder

  ble-edit/info/immediate-show text "ble.sh: updating binders... done"
}

ble/init:bind/generate-binder
