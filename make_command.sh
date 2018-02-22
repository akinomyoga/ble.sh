#!/bin/bash

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

function sub:install {
  local src=$1
  local dst=$2
  mkd "${dst%/*}"
  if [[ $src == *.sh ]]; then
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$src" > "$dst"
  else
    cp "$src" "$dst"
  fi
}

function sub:dist {
  local tmpdir="ble-$FULLVER"
  local src
  for src in "$@"; do
    local dst="$tmpdir${src#out}"
    sub:install "$src" "$dst"
  done
  tar caf "dist/$tmpdir.$(date +'%Y%m%d').tar.xz" "$tmpdir" && rm -r "$tmpdir"
}

if declare -f sub:$1 &>/dev/null; then
  sub:"$@"
else
  echo "unknown subcommand '$1'" >&2
  exit 1
fi
