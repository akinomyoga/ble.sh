#!/bin/bash

# Bash 4.1 では read -t timeout でタイムアウトした時
# 読み取り済みの内容が失われてしまう。

printf '%s\n' {0..10000} | {
  read -r -d "" -t 0.01 line
  echo "$?:[$line]"
  read -d "" line
  echo "(${line::10}...#${#line})"
}
