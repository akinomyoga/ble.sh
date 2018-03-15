#!/bin/bash

# 以下の様な LC_CTYPE と LC_COLLATE が異なる環境で、
# 期待通りに LC_CTYPE による文字コードでの範囲になるだろうか。
# →試してみた所、期待通りになった。ちゃんと UTF-8 解釈されている。

LC_CTYPE=ja_JP.UTF-8
LC_COLLATE=C

if [[  == [] ]]; then
  echo glob test: OK
else
  echo glob test: NG
fi

rex='^[]$'
if [[  =~ $rex ]]; then
  echo regex test: OK
else
  echo regex test: NG
fi
