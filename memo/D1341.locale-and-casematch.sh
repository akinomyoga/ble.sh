#!/bin/bash

LANG=en_US.utf8


# Bash-4.4 以下で失敗する。
function check.1 { [[ A == [a-z] ]] && echo "NG ($1)"; }
check.1 check.1

# Bash-4.1 以下で失敗する
function check.2 { LC_ALL= LC_COLLATE=C check.1 "$1" 2>/dev/null; }
check.2 check.2

# これならば OK。
function check.3 {
  local LC_ALL= LC_COLLATE=C
  check.1 "$1"
} 2>/dev/null
check.3 check.3

# つまり、LC_ALL= LC_COLLATE=C command の形式を用いると
# Bash 4.1 以下では効果がないという事を意味する。
# 既存の同形式は全て置き換える必要がある。

function check.4 {
  local LC_ALL= LC_COLLATE=C
  [[ A == [a-z] ]] && echo "NG ($1)"
} 2>/dev/null
check.4 check.4
