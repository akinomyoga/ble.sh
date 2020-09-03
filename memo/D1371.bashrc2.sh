# blerc -*- mode: sh; mode: sh-bash -*-

# from https://github.com/akinomyoga/ble.sh/issues/60

blehook PRECMD+=__prompt_command
ansi[blue=4]=$'\e[34m'
ansi[yellow=3]=$'\e[33m'

abbreviate_path() { ble/util/put "${1##*/}"; }
__prompt_command() {
  local _exit="$?"             # This needs to be first
  local _logo=

  local _last_command="$(fc -l -1)"

  if [ $_exit -ne 0 ] && [[ "$_exit_notified_for" != "${_last_command}" ]]; then
    _logo="𐔴"
    _exit_notified_for="${_last_command}"
  fi

  bleopt prompt_rps1=
  bind 'set show-mode-in-prompt on'
  bind "set vi-ins-mode-string \"\1\e[6 q\2${_logo}${ansi[blue]}$(abbreviate_path "$PWD")${ansi[yellow]}→${ansi[yellow]}\""
  bind "set vi-cmd-mode-string \"\1\e[2 q\2${_logo}${ansi[blue]}$(abbreviate_path "$PWD")${ansi[blue]}:${ansi[yellow]}\""
  
  PS1=" "
  PS2="... "
}
