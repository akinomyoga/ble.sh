#!/usr/bin/env bash

# 調べた感じだと全て bash-4.4 の時点で導入された様だ。
cmds=(
  times pwd suspend

  alias bind cd command compgen complete compopt dirs disown enable exec
  export fc getopts hash help history jobs kill mapfile popd printf pushd
  read readonly set shopt trap type ulimit umask unalias unset wait

  . source fg bg builtin caller eval let
  break continue exit logout return shift
  printf

  declare typeset local readonly
)

for cmd in "${cmds[@]}"; do
  help=$("$cmd" --help 2>&1)
  [[ $help == "$cmd: "* ]] && continue
  echo "==== $cmd ===="
  head -5 <<< "$help"
done
