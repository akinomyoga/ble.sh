#!/bin/bash

function generate.ignoreeof-messages {
  (
    cd ~/local/build/bash-4.3/po
    sed -nr '/msgid "Use \\"%s\\" to leave the shell\.\\n"/{n;s/^[[:space:]]*msgstr "(.*)"[^"]*$/\1/p;}' *.po | while builtin read -r line || [[ $line ]]; do
      [[ $line ]] || continue
      echo $(printf "$line" exit) # $() は末端の改行を削除するため
    done
  ) >| lib/core-edit.ignoreeof-messages.new
}

generate.ignoreeof-messages
