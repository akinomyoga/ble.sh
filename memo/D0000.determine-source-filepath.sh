#!/bin/bash


## source されたファイルの中で $0 は何に設定されているか?
echo "0=$0"
## → 通常の様に実行すれば当然そのファイルの名前だが、
##    source で実行した場合、自分自身が何処に配置されているかは分からない。

## 手で source ... と入力した場合に source された中から BASH_COMMAND を参照する事が出来るか?
echo "BASH_COMMAND=$BASH_COMMAND"
## → 更に内側で実行されているコマンドが取得されるだけである。
##    つまりこの場合 'echo "BASH_COMMAND=$BASH_COMMAND"' が BASH_COMMAND に入っている。

## BASH_SOURCE には何が入っているだろうか?
echo "${BASH_SOURCE[*]}"
## → どうやらこれで取得できる様子?

