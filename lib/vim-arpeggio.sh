#!/bin/bash

source "$_ble_base/keymap/vi.sh"

bleopt/declare -v vim_arpeggio_timeoutlen 40

function ble/lib/vim-arpeggio.sh/bind/.usage {
  ble/bin/echo "usage: ble/lib/vim-arpeggio.sh/bind [-m KEYMAP] -[fxcs@] KEYS COMMAND"
  ble/bin/echo "  KEYS has the form of {mods}{X}{Y}. {mods} are modifiers of the form"
  ble/bin/echo "  /([CSMAsH]-)*/ and {X} and {Y} are alphabets which specify simultaneous"
  ble/bin/echo "  keys."
}

function ble/lib/vim-arpeggio.sh/bind {
  local -a opts=()
  if [[ $1 == -m ]]; then
    if [[ ! $2 ]]; then
      ble/bin/echo "vim-arpeggio.sh: invalid option argument for \`-m'." >&2
      ble/lib/vim-arpeggio.sh/bind/.usage >&2
      return 1
    fi
    ble/array#push opts -m "$2"
    shift 2
  fi

  local type=$1 keys=$2 cmd=$3
  if [[ $type == --help ]]; then
    ble/lib/vim-arpeggio.sh/bind/.usage
    return 0
  elif [[ $type != -[fxcs@] ]]; then
    ble/bin/echo "vim-arpeggio.sh: invalid bind type." >&2
    ble/lib/vim-arpeggio.sh/bind/.usage >&2
    return 1
  fi

  local mods=
  if local rex='^(([CSMAsH]-)+)..'; [[ $keys =~ $rex ]]; then
    mods=${BASH_REMATCH[1]}
    keys=${keys:${#mods}}
  fi

  local timeout=$((bleopt_vim_arpeggio_timeoutlen))
  ((timeout<0)) && timeout=

  if ((${#keys}==2)); then
    local k1=$mods${keys::1} k2=$mods${keys:1:1}
    ble-bind "${opts[@]}" "$type" "$k1 $k2" "$cmd"
    ble-bind "${opts[@]}" "$type" "$k2 $k1" "$cmd"
    ble-bind "${opts[@]}" -T "$k1" "$timeout"
    ble-bind "${opts[@]}" -T "$k2" "$timeout"
  else
    ble/bin/echo "vim-arpeggio.sh: sorry only 2-key bindings are supported now." >&2
    ble/lib/vim-arpeggio.sh/bind/.usage >&2
    return 1
  fi
}
