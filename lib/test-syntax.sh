# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

function ble-test/check-ret {
  local f=$1 in=$2 expected=$3 ret
  "$f" "$in"
  ble/util/assert '[[ $ret == "$expected" ]]' ||
    ble/bin/echo "fail: command=($f $in) result=($ret) expected=($expected)" >&2
}

function ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion {
  local simple_ibrace
  ble/syntax:bash/simple-word/evaluate-last-brace-expansion "$1"
  ret=$simple_ibrace/$ret
}
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{b,c}x'     '6:2/acx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{b,{c,d}x'  '9:2/adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{b,{c,d}}x' '10:2/adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{{c,dx'     '5:1/adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{b{c,dx'    '6:2/abdx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-last-brace-expansion 'a{b,c}{d}x'  '7:2/acd}x'

function ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word {
  local simple_flags simple_ibrace
  if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$1"; then
    ret=$simple_flags:[$simple_ibrace]:$ret
  else
    ret=ERR
  fi
}
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'hello-word'           ':[0:0]:hello-word'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'hello word'           'ERR'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'hello-word"a'         'D:[0:0]:hello-word"a"'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,c}x'              ':[6:2]:acx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,{c,d}x'           ':[9:2]:adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,{c,d}}x'          ':[10:2]:adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{{c,dx'              ':[5:1]:adx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b{c,dx'             ':[6:2]:abdx'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,c}{d}x'           ':[7:2]:acd}x'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,c}x"hello, world' 'D:[6:2]:acx"hello, world"'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,{c,d}x'"'a"       'S:[9:2]:adx'\''a'\'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{b,{c,d}}x'"$'\e[m"  'E:[10:2]:adx$'\''\e[m'\'
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/reconstruct-incomplete-word 'a{{c,dx$"aa'          'I:[5:1]:adx$"aa"'

function ble-test:ble/syntax:bash/simple-word/evaluate-path-spec {
  local path spec
  ble/syntax:bash/simple-word/evaluate-path-spec "$1"
  ret="${spec[*]} >>> ${path[*]}"
}
ble-test/check-ret ble-test:ble/syntax:bash/simple-word/evaluate-path-spec '~/a/b/c' "~ ~/a ~/a/b ~/a/b/c >>> $HOME $HOME/a $HOME/a/b $HOME/a/b/c"
