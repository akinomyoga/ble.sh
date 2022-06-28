#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

ifold -s -w 80 -i <<EOF

変数名が不明の場合に値を設定する方法について。
printf -v を用いた配列名に対する代入は bash-4.1 以降でしかできない。

比較してみたが eval を用いても、関数呼出で printf を用いても大差ないようだ。\
記述が簡単になる関数呼出で printf を用いる方法を採用する事にする。\
bash-4.1 未満の場合には保険の為、関数呼出で eval を用いる方法にする。

builtin eval, builtin printf, builtin read 等のように builtin を開始呼び出すと、\
関数内では 3.5 us 程度ずつ、直接 eval だと 5.8us ずつ遅くなる様である。\
全体の処理時間に比べれば 5% - 20% 程度である。余り気にしなくて良いと思う。

EOF

hello=12345 var=hello value=12345
ble-measure 'hello=12345'
ble-measure '(($var=value))'
ble-measure 'printf -v "$var" %s "$value"'
ble-measure 'eval "$var=\"\$value\""'
ble-measure "IFS= read -r -d '' \"\$var\" <<< \"\$value\""

flag_function_assign=

if [[ $flag_function_assign ]]; then
  function ble/util/set.printf {
    printf -v "$1" %s "$2"
  }
  function ble/util/set.eval {
    eval "$1=\"\$2\""
  }
  function ble/util/set.read {
    IFS= read -r -d '' "$1" <<<"$2"
  }
  ble-measure 'ble/util/set.printf "$var" "$value"'
  ble-measure 'ble/util/set.eval "$var" "$value"'
  ble-measure 'ble/util/set.read "$var" "$value"'

  # function ble/util/set.eval.2 {
  #   builtin eval "$1=\"\$2\""
  # }
  # function ble/util/set.printf.2 {
  #   builtin printf -v "$1" %s "$2"
  # }
  # function ble/util/set.read.2 {
  #   IFS= builtin read -r -d '' "$1" <<<"$2"
  # }
  # ble-measure 'ble/util/set.eval.2 "$var" "$value"'
  # ble-measure 'ble/util/set.printf.2 "$var" "$value"'
  # ble-measure 'ble/util/set.read.2 "$var" "$value"'
fi

mem=/dev/shm/$UID
memtmp=$mem/$$.tmp
> $memtmp || (umask 077; mkdir -p "$mem")

ble-measure 'echo hello > $memtmp && IFS= read -r -d "" result < $memtmp'
ble-measure 'echo hello > $$.tmp && IFS= read -r -d "" result < $$.tmp'
ble-measure 'result=$(echo hello)'

ble-measure 'date > $memtmp && IFS= read -r -d "" result < $memtmp'
ble-measure 'date > $$.tmp && IFS= read -r -d "" result < $$.tmp'
ble-measure 'result=$(date)'

rm -f "$$.tmp" "$memtmp"
