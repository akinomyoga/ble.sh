#!/bin/bash

function process {
  ## @arr commits
  ##   この配列は after:before の形式の要素を持つ。
  ##   但し after は前の version から release までに加えられた変更の commit である。
  ##   そして before は after に対応する master における commit である。
  local -a commits; commits=("$@")

  for commit_pair in "${commits[@]}"; do
    local b=${commit_pair#*:}
    local a=${commit_pair%:*}

    local result=$(sed -n "s/$b/$a (master: $b)/p" changelog.txt)
    if [[ $result ]]; then
      echo "$result"
    else
      echo "@@@not found $a"
    fi
  done
}

# ble-0.3.0
#
# 232767a:30cc31c
# 244205f:3f1f472
# 655fbaa:2e6f44c
# 1bc9934:b29f248
# 910313e:309b9e4
# e6ae0be:ab8dad2
# a235aa4:467b7a4
# d2aa2d2:1666ec2
# 8926704:4ce2753
# 7b15550:d94f691
# f8bdf9d:376bfe7
# 45db2ec:b52da28

# ble-0.2.0
#
process \
  6713766:f199215 \
  b109b46:88a1b0f \
  73a191d:36b9a8f \
  ae72dc3:ae176b2 \
  50fbadf:8e4180c \
  7109acf:4efe1a9 \
  637ec53:f20f840 \
  6f5058d:a46ada0 \
  6c931fd:9290adb \
  6ad206a:9892d63
