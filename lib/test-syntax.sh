# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-syntax
ble-import lib/core-test

ble/test/start-section 'ble/syntax' 22

(
  func=ble/syntax:bash/simple-word/evaluate-last-brace-expansion
  collect='ret=$simple_ibrace/$ret'
  ble/test "$func 'a{b,c}x'    ; $collect" ret='6:2/acx'
  ble/test "$func 'a{b,{c,d}x' ; $collect" ret='9:2/adx'
  ble/test "$func 'a{b,{c,d}}x'; $collect" ret='10:2/adx'
  ble/test "$func 'a{{c,dx'    ; $collect" ret='5:1/adx'
  ble/test "$func 'a{b{c,dx'   ; $collect" ret='6:2/abdx'
  ble/test "$func 'a{b,c}{d}x' ; $collect" ret='7:2/acd}x'
)

(
  func=ble/syntax:bash/simple-word/reconstruct-incomplete-word
  collect='ret=$?:$simple_flags:[$simple_ibrace]:$ret'
  ble/test "$func 'hello-word'           ; $collect" ret='0::[0:0]:hello-word'
  ble/test "$func 'hello word'           ; $collect" ret='1::[0:0]:hello'
  ble/test "$func 'hello-word\"a'        ; $collect" ret='0:D:[0:0]:hello-word"a"'
  ble/test "$func 'a{b,c}x'              ; $collect" ret='0::[6:2]:acx'
  ble/test "$func 'a{b,{c,d}x'           ; $collect" ret='0::[9:2]:adx'
  ble/test "$func 'a{b,{c,d}}x'          ; $collect" ret='0::[10:2]:adx'
  ble/test "$func 'a{{c,dx'              ; $collect" ret='0::[5:1]:adx'
  ble/test "$func 'a{b{c,dx'             ; $collect" ret='0::[6:2]:abdx'
  ble/test "$func 'a{b,c}{d}x'           ; $collect" ret='0::[7:2]:acd}x'
  ble/test "$func 'a{b,c}x\"hello, world'; $collect" ret='0:D:[6:2]:acx"hello, world"'
  ble/test "$func 'a{b,{c,d}x'\''a'      ; $collect" ret='0:S:[9:2]:adx'\''a'\'
  ble/test "$func 'a{b,{c,d}}x\$'\''\e[m'; $collect" ret='0:E:[10:2]:adx$'\''\e[m'\'
  ble/test "$func 'a{{c,dx\$\"aa'        ; $collect" ret='0:I:[5:1]:adx$"aa"'
)

(
  func=ble/syntax:bash/simple-word/evaluate-path-spec
  collect='ret="${spec[*]} >>> ${path[*]}"'
  ble/test "$func '~/a/b/c'            ; $collect" ret="~ ~/a ~/a/b ~/a/b/c >>> $HOME $HOME/a $HOME/a/b $HOME/a/b/c"
  ble/test "$func '~/a/b/c' / after-sep; $collect" ret="~/ ~/a/ ~/a/b/ ~/a/b/c >>> $HOME/ $HOME/a/ $HOME/a/b/ $HOME/a/b/c"
  ble/test "$func '/x/y/z' / after-sep ; $collect" ret="/ /x/ /x/y/ /x/y/z >>> / /x/ /x/y/ /x/y/z"
)

ble/test/end-section
