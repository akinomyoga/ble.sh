#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

function dummy-function {
  echo hello
}

function type.1 {
  ret="$(type -t "$1" 2>/dev/null)"
}
function type.2 {
  type -t "$1" > a.tmp 2>/dev/null
  ret="$(< a.tmp)"
}
function type.3 {
  ret=
  type -t "$1" > a.tmp 2>/dev/null
  IFS= read -r ret < a.tmp
}
function type.4 {
  local arr
  type -t "$1" > a.tmp 2>/dev/null
  mapfile -t arr < a.tmp
  ret="${arr[*]}"
}

# check
type.1 dummy-function && [[ $ret == function ]] || return 1
type.2 dummy-function && [[ $ret == function ]] || return 2
type.3 dummy-function && [[ $ret == function ]] || return 3
type.4 dummy-function && [[ $ret == function ]] || return 4

# 計測
function line {
  echo ---------- ---------- ---------- ----------
}

ifold -i -s -w 80 <<EOF
type -t の結果を取得する為に現在 \$() を使用している。\
この方法だと一回 fork が必要になるので遅いのではないかという懸念がある。\
ファイルに出力してそれを読み取る様にしてしまえば実は速いのではないかという話。

  type.1
    \$() を用いて実行
  type.2
    一回ファイルに出力してからそれを読み取る
    ファイルからの読み取りには \$(< filename) を用いる。
    どうやらこの方法を用いたとしても内部的に fork はする様だ。
  type.3
    ファイルに出力して read で読み取る(1行目だけ読み取れれば良いので read でOK)。
  type.4
    ファイルに出力して mapfile で読み取る。

padparadscha で試してみた所、read/mapfile を用いた type.3/type.4 が fork する type.1/type.2 よりも3倍程度速いという事が分かった。\
read/mapfile の違いは殆どないが mapfile の方が微妙に早いように思われる。\
但し、mapfile は最近の bash にしか存在していないので、実際には read を用いるのが現実的であると思われる。

gauge では type.1/type.2 は 70ms 程度かかるが、type.3/type.4 は 1.8ms/1.4ms と30倍程度速い。\
cygwin 環境では type.3/type.4 の様な一度ファイルに書き出す方式の方が断然良いという事である。
EOF
line
ble-measure type.1 dummy-function
line
ble-measure type.2 dummy-function
line
ble-measure type.3 dummy-function
line
ble-measure type.4 dummy-function
rm a.tmp
