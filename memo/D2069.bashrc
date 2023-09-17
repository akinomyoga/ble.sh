# bashrc -*- mode: sh; mode: sh-bash -*-
# https://github.com/akinomyoga/ble.sh/issues/361
#------------------------------------------------------------------------------
HISTFILE=~/.mwg/src/ble.sh/A
HISTSIZE=
HISTFILESIZE=
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
alias l='colored ls -lB'
#------------------------------------------------------------------------------

LANG='en_XY.UTF-8'
source out/ble.sh --norc

#source out/ble.sh --norc --attach=attach
#source out/ble.sh --norc --attach=prompt
#source out/ble.sh --norc --attach=none
#ble-bind -c C-h 'echo hello'
#ble-bind -f C-h 'external-command "echo hello"'
# function ble/widget/test1 {
#   ble/term/leave
#   ble/util/buffer.flush >&2
#   ble/term/enter
#   ble/util/buffer.flush >&2
# }
# ble-bind -f C-h test1
# function ble/widget/test2 {
#   ble/term/stty/leave
#   ble/term/rl-convert-meta/leave
#   ble/term/stty/enter
#   ble/term/rl-convert-meta/enter
#   ble/util/buffer.flush >&2
# }
# ble-bind -f C-h test2
# function ble/widget/test3 {
#   #declare -p _ble_term_rl_convert_meta_adjusted >&2
#   ble/term/rl-convert-meta/leave
#   ble/term/rl-convert-meta/enter
#   ble/util/buffer.flush >&2
# }
# ble-bind -f C-h test3
# function ble/widget/test4 {
#   builtin bind -v | grep convert-meta >&2
#   builtin bind 'set convert-meta off'
# }
#ble-bind -f C-h test4

# [対策コード]
# if ((_ble_bash>=50200)); then
#   ble/util/assign x '{ LC_ALL= LC_CTYPE=C ble/util/setexit 0; } 2>&1'
#   if [[ $x ]]; then
#     echo "$x" >&2
#     builtin read -et 0.000001 xxx </dev/tty
#   fi
# fi
