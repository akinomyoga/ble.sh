#!/bin/bash
# -*- coding: euc-jp -*-

export LC_CTYPE=ja_JP.eucJP
printf '%d\n' "'あ"

export LC_CTYPE=ja_JP.UTF-8
printf '%d\n' "'あ"

export LC_CTYPE=C
printf '%d\n' "'あ"
