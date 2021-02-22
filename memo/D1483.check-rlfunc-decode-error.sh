#!/usr/bin/env bash

echo "----------"
echo "locale"
locale

echo "----------"
echo "test regex (default locale)"

rex='^"([^\"]|\\.)*$'
[[ $'"\x9B": self-insert' =~ $rex ]]
echo "$? (${BASH_REMATCH[*]@Q})"

echo "----------"
echo "test regex (locale C)"

LC_ALL=C
[[ $'"\x9B": self-insert' =~ $rex ]]
echo "$? (${BASH_REMATCH[*]@Q})"
