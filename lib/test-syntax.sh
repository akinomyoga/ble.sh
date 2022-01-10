# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-syntax
ble-import lib/core-test

ble/test/start-section 'ble/syntax' 22

(
  _func=ble/syntax:bash/simple-word/evaluate-last-brace-expansion
  _collect='ret=$simple_ibrace/$ret'
  ble/test "$_func 'a{b,c}x'    ; $_collect" ret='6:2/acx'
  ble/test "$_func 'a{b,{c,d}x' ; $_collect" ret='9:2/adx'
  ble/test "$_func 'a{b,{c,d}}x'; $_collect" ret='10:2/adx'
  ble/test "$_func 'a{{c,dx'    ; $_collect" ret='5:1/adx'
  ble/test "$_func 'a{b{c,dx'   ; $_collect" ret='6:2/abdx'
  ble/test "$_func 'a{b,c}{d}x' ; $_collect" ret='7:2/acd}x'
)

(
  _func=ble/syntax:bash/simple-word/reconstruct-incomplete-word
  _collect='ret=$?:$simple_flags:[$simple_ibrace]:$ret'
  ble/test "$_func 'hello-word'           ; $_collect" ret='0::[0:0]:hello-word'
  ble/test "$_func 'hello word'           ; $_collect" ret='1::[0:0]:hello'
  ble/test "$_func 'hello-word\"a'        ; $_collect" ret='0:D:[0:0]:hello-word"a"'
  ble/test "$_func 'a{b,c}x'              ; $_collect" ret='0::[6:2]:acx'
  ble/test "$_func 'a{b,{c,d}x'           ; $_collect" ret='0::[9:2]:adx'
  ble/test "$_func 'a{b,{c,d}}x'          ; $_collect" ret='0::[10:2]:adx'
  ble/test "$_func 'a{{c,dx'              ; $_collect" ret='0::[5:1]:adx'
  ble/test "$_func 'a{b{c,dx'             ; $_collect" ret='0::[6:2]:abdx'
  ble/test "$_func 'a{b,c}{d}x'           ; $_collect" ret='0::[7:2]:acd}x'
  ble/test "$_func 'a{b,c}x\"hello, world'; $_collect" ret='0:D:[6:2]:acx"hello, world"'
  ble/test "$_func 'a{b,{c,d}x'\''a'      ; $_collect" ret='0:S:[9:2]:adx'\''a'\'
  ble/test "$_func 'a{b,{c,d}}x\$'\''\e[m'; $_collect" ret='0:E:[10:2]:adx$'\''\e[m'\'
  ble/test "$_func 'a{{c,dx\$\"aa'        ; $_collect" ret='0:I:[5:1]:adx$"aa"'
)

(
  _func=ble/syntax:bash/simple-word/evaluate-path-spec
  _collect='ret="${spec[*]} >>> ${path[*]}"'
  ble/test "$_func '~/a/b/c'            ; $_collect" ret="~ ~/a ~/a/b ~/a/b/c >>> $HOME $HOME/a $HOME/a/b $HOME/a/b/c"
  ble/test "$_func '~/a/b/c' / after-sep; $_collect" ret="~/ ~/a/ ~/a/b/ ~/a/b/c >>> $HOME/ $HOME/a/ $HOME/a/b/ $HOME/a/b/c"
  ble/test "$_func '/x/y/z' / after-sep ; $_collect" ret="/ /x/ /x/y/ /x/y/z >>> / /x/ /x/y/ /x/y/z"
)

ble/test/end-section
