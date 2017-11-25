#!/bin/bash

## 結論: ${var#text} の text を quote する場合、
## 1. 解析時に shopt -u extquote で、
## 2. ${} 全体が "" で囲まれていて、
## 2. $'' の形式の quote の時にうまくいかない。
## それ以外の場合には期待通りに quote 除去が行われる。

shopt -s extquote
function check_ltrim_extquote {
  echo check_ltrim_extquote
  local hello=check:hello
  [[ "${hello#'check'}"  == ':hello' ]] || echo Error
  [[ "${hello#$'check'}" == ':hello' ]] || echo Error
  [[ "${hello#"check"}"  == ':hello' ]] || echo Error
  [[ ${hello#'check'}  == ':hello' ]] || echo Error
  [[ ${hello#$'check'} == ':hello' ]] || echo Error
  [[ ${hello#"check"}  == ':hello' ]] || echo Error

  [[ $(echo "${hello#'check'}" ) == ':hello' ]] || echo Error
  [[ $(echo "${hello#$'check'}") == ':hello' ]] || echo Error
  [[ $(echo "${hello#"check"}" ) == ':hello' ]] || echo Error
  [[ $(echo ${hello#'check'}   ) == ':hello' ]] || echo Error
  [[ $(echo ${hello#$'check'}  ) == ':hello' ]] || echo Error
  [[ $(echo ${hello#"check"}   ) == ':hello' ]] || echo Error
}
check_ltrim_extquote

shopt -u extquote
function check_ltrim_noextquote {
  echo check_ltrim_extquote
  local hello=check:hello
  [[ "${hello#'check'}"  == ':hello' ]] || echo Error1
  [[ "${hello#$'check'}" != ':hello' ]] || echo Error2 # これだけ違う
  [[ "${hello#"check"}"  == ':hello' ]] || echo Error3
  [[ ${hello#'check'}  == ':hello' ]] || echo Error4
  [[ ${hello#$'check'} == ':hello' ]] || echo Error5
  [[ ${hello#"check"}  == ':hello' ]] || echo Error6

  [[ $(echo "${hello#'check'}" ) == ':hello' ]] || echo Error1
  [[ $(echo "${hello#$'check'}") != ':hello' ]] || echo Error2
  [[ $(echo "${hello#"check"}" ) == ':hello' ]] || echo Error3
  [[ $(echo ${hello#'check'}   ) == ':hello' ]] || echo Error4
  [[ $(echo ${hello#$'check'}  ) == ':hello' ]] || echo Error5
  [[ $(echo ${hello#"check"}   ) == ':hello' ]] || echo Error6
}
check_ltrim_noextquote

## 結論: ${var:offset} の offset を quote する場合、
##   1. shopt -s extquote が設定されていて (解析時・実行時の両時点で) (1/2)、
##   2. ${} 全体が "" で囲まれていて (1/2)、
##   3. offset の quote が $'' である (1/3)
##   場合にのみ認められる。それ以外 (2*2*3-1 = 11 パターン) は構文エラーになる。
shopt -s extquote
function check_quoted_offset_extquote {
  local digits=0123456789
  echo 'check_quoted_offset_extquote'
  # echo "${digits:'1'}" # error
  echo "${digits:$'1'}"
  # echo "${digits:"1"}" # error
  # echo ${digits:'1'} # error
  # echo ${digits:$'1'} # error
  # echo ${digits:"1"} # error
}
check_quoted_offset_extquote

shopt -u extquote
function check_quoted_offset_noextquote {
  local digits=0123456789
  echo 'check_quoted_offset_noextquote'
  # echo "${digits:'1'}" # error
  # echo "${digits:$'1'}" # error
  # echo "${digits:"1"}" # error
  # echo ${digits:'1'} # error
  # echo ${digits:$'1'} # error
  # echo ${digits:"1"} # error
}
check_quoted_offset_noextquote

## 結論: ${var#text} の場合と同じパターンである。
## 但し算術式が構文エラーになり実行が停止する。
shopt -s extquote
function check_quoted_sub_extquote {
  local -a digits=({0..9})
  echo 'check_quoted_sub_extquote'
  [[ "${digits['1']}"  == 1 ]] || echo Error1
  [[ "${digits[$'1']}" == 1 ]] || echo Error2
  [[ "${digits["1"]}"  == 1 ]] || echo Error3
  [[ ${digits['1']}    == 1 ]] || echo Error4
  [[ ${digits[$'1']}   == 1 ]] || echo Error5
  [[ ${digits["1"]}    == 1 ]] || echo Error6
}
check_quoted_sub_extquote

shopt -u extquote
function check_quoted_sub_noextquote {
  local -a digits=({0..9})
  echo 'check_quoted_sub_noextquote'
  [[ "${digits['1']}"  == 1 ]] || echo Error1
  # [[ "${digits[$'1']}" != 1 ]] || echo Error2 # 構文エラー
  [[ "${digits["1"]}"  == 1 ]] || echo Error3
  [[ ${digits['1']}    == 1 ]] || echo Error4
  [[ ${digits[$'1']}   == 1 ]] || echo Error5
  [[ ${digits["1"]}    == 1 ]] || echo Error6
  # echo "${digits:'1'}" # error
  # echo "${digits:$'1'}" # error
  # echo "${digits:"1"}" # error
  # echo ${digits:'1'} # error
  # echo ${digits:$'1'} # error
  # echo ${digits:"1"} # error
}
check_quoted_sub_noextquote

## ここでまでのまとめ
##
## shopt -u extquote の時
##
## 1. ${var#a}, ${var[a]} の形式では基本的に a に quote が含まれて良い。
##   但し、全体が "" で囲まれている場合は $''/$"" の quote は除去されない。
##   特に ${var[a]} では算術式の構文エラーになる。
## 2. ${var:offset} の形式では基本的に offset に quote を含めると
##   算術式の構文エラーになる。
##
## shopt -s extquote の時は
##
## 全体が "" で囲まれている場合に $''/$"" が除去される様になる。
##
##
## 以降は二重に ${} が入れ子になっている場合に "${ ${} }"
## と ${} のどちらと同じ振る舞いになるかについてである。


# (1) "${ :- ${var#text} }" について → "${var#text}" と同じ
shopt -s extquote
function check_qrltrim_extquote {
  echo check_qrltrim_extquote
  local hello=check:hello n=
  [[ "${n:-${hello#'check'}}"  == ':hello' ]] || echo Error1
  [[ "${n:-${hello#$'check'}}" == ':hello' ]] || echo Error2
  [[ "${n:-${hello#"check"}}"  == ':hello' ]] || echo Error3
  [[ $(echo "${n:-${hello#'check'}}" ) == ':hello' ]] || echo Error1
  [[ $(echo "${n:-${hello#$'check'}}") == ':hello' ]] || echo Error2
  [[ $(echo "${n:-${hello#"check"}}" ) == ':hello' ]] || echo Error3
}
check_qrltrim_extquote

shopt -u extquote
function check_qrltrim_noextquote {
  echo check_qrltrim_noextquote
  local hello=check:hello n=
  [[ "${n:-${hello#'check'}}"  == ':hello' ]] || echo Error1
  [[ "${n:-${hello#$'check'}}" != ':hello' ]] || echo Error2
  [[ "${n:-${hello#"check"}}"  == ':hello' ]] || echo Error3
  [[ $(echo "${n:-${hello#'check'}}" ) == ':hello' ]] || echo Error1
  [[ $(echo "${n:-${hello#$'check'}}") != ':hello' ]] || echo Error2
  [[ $(echo "${n:-${hello#"check"}}" ) == ':hello' ]] || echo Error3
}
check_qrltrim_noextquote

# (2) "${ :- ${var:offset} }" について → "${var:offset}" と同じ
shopt -s extquote
function check_qroffset_extquote {
  local digits=0123456789 n=
  echo 'check_qroffset_extquote'
  # echo "${n:-${digits:'1'}}" # error
  echo "${n:-${digits:$'1'}}"
  # echo "${n:-${digits:"1"}}" # error
}
check_qroffset_extquote

shopt -u extquote
function check_qroffset_noextquote {
  local digits=0123456789 n=
  echo 'check_qroffset_noextquote'
  # echo "${n:-${digits:'1'}}" # error
  # echo "${n:-${digits:$'1'}}" # error
  # echo "${n:-${digits:"1"}}" # error
}
check_qroffset_noextquote

# (3) "${ :- ${arr[index]} }" → "${arr[index]}" と同じ

shopt -s extquote
function check_qrsub_extquote {
  local digits n=
  digits=({0..9})
  echo 'check_qrsub_extquote'
  [[ "${n:-${digits['1']}}"  == 1 ]] || echo Error1
  [[ "${n:-${digits[$'1']}}" == 1 ]] || echo Error2
  [[ "${n:-${digits["1"]}}"  == 1 ]] || echo Error3
}
check_qrsub_extquote

shopt -u extquote
function check_qrsub_noextquote {
  local digits n=
  digits=({0..9})
  echo 'check_qrsub_noextquote'
  [[ "${n:-${digits['1']}}"  == 1 ]] || echo Error1
  # [[ "${n:-${digits[$'1']}}" != 1 ]] || echo Error2 # 構文エラー
  [[ "${n:-${digits["1"]}}"  == 1 ]] || echo Error3
}
check_qrsub_noextquote

# (4) "$(( ${var#text} ))" → なんと ("${}" ではなくて) ${} と同じ振る舞いである。
shopt -s extquote
function check_qaltrim_extquote {
  echo check_qaltrim_extquote
  local hello=321123 n=
  [[ "$((${hello#'321'}))"  == '123' ]] || echo Error1
  [[ "$((${hello#$'321'}))" == '123' ]] || echo Error2
  [[ "$((${hello#"321"}))"  == '123' ]] || echo Error3
}
check_qaltrim_extquote

shopt -u extquote
function check_qaltrim_noextquote {
  echo check_qaltrim_noextquote
  local hello=321123 n=
  [[ "$((${hello#'321'}))"  == '123' ]] || echo Error1
  [[ "$((${hello#$'321'}))" == '123' ]] || echo Error2
  [[ "$((${hello#"321"}))"  == '123' ]] || echo Error3
}
check_qaltrim_noextquote

# (1) "${var: ${var#text} }" について → "${var#text}" と同じ
shopt -s extquote
function check_qoltrim_extquote {
  echo check_qoltrim_extquote
  local hello=123 var=abcde
  [[ "${var:${hello#'12'}}"  == de ]] || echo Error1
  [[ "${var:${hello#$'12'}}" == de ]] || echo Error2
  [[ "${var:${hello#"12"}}"  == de ]] || echo Error3
}
check_qoltrim_extquote

shopt -u extquote
function check_qoltrim_noextquote {
  echo check_qoltrim_noextquote
  local hello=123 var=abcde
  [[ "${var:${hello#'12'}}"  == de ]] || echo Error1
  [[ "${var:${hello#$'12'}}" != de ]] || echo Error2
  [[ "${var:${hello#"12"}}"  == de ]] || echo Error3
}
check_qoltrim_noextquote
