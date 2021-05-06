#!/bin/bash

{
  echo '[plain Bash]'
  completer=(aws_completer "$@")
  declare -p COMP_LINE COMP_POINT COMP_TYPE COMP_KEY completer
} >> b.txt
"${completer[@]}"
