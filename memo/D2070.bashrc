# bashrc -*- mode: sh; mode: sh-bash -*-
#------------------------------------------------------------------------------
HISTFILE=~/.mwg/src/ble.sh/A
HISTSIZE=
HISTFILESIZE=
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
alias l='colored ls -lB'
#------------------------------------------------------------------------------

# 再現1 (bash-dev (5.3)で job 関連の warning が出る。release ビルドでは出ない)
# LANG='en_XY.UTF-8'
# source out/ble.sh --norc

# 再現2
# source out/ble.sh --norc --attach=none
# # function conditional-sync {
# #   (
# #     sleep 1 & pid=$!
# #     while builtin kill -0 "$pid" &>/dev/null; do
# #       sleep 0.2
# #     done
# #   )
# # }
# # function test1 {
# #   # compgen=${ ble/util/conditional-sync \
# #   #              'builtin compgen -c -- ""' \
# #   #              '! ble/decode/has-input' 250 progressive-weight; }
# #   #compgen=${ conditional-sync; }
# #   compgen=${ sleep 0.1 & }
# # }
# # ble-bind -@ C-t test1
# # builtin bind -x '"\C-t": test1'
# builtin bind -x '"\C-t": v=${ sleep 0.1 & }'

# [再現3]
# source out/ble.sh --norc --attach=none
# builtin bind -x '"\C-t": v=${ sleep 0.1 & }'

# [設定抽出 for source ble.sh]
# { shopt; builtin bind -v; } > a1.txt
# source out/ble.sh --norc --attach=none
# { shopt; builtin bind -v; } > a2.txt
# diff -bwu a1.txt a2.txt > ad.txt
# rm a1.txt a2.txt

# shopt -s inherit_errexit
# builtin bind 'set colored-completion-prefix on'
# builtin bind 'set colored-stats on'
# builtin bind 'set skip-completed-text on'
# builtin bind -x '"\C-t": v=${ sleep 0.1 & }'

# [再現4]
#source out/ble.sh --norc --attach=none
#builtin bind -x '"\C-t": v=${ ble/builtin/sleep 0.1 & }'

# [再現5]
# enable -f /home/murase/opt/bash/dev/lib/bash/sleep sleep
# function ble/builtin/sleep {
#   while (($#)); do shift; done
#   builtin sleep 0.10000000000000
# }
# builtin bind -x '"\C-t": v=${ ble/builtin/sleep 0.1 & }'

# [最小再現]
PS1='\$ '
LANG=C
enable -f /home/murase/opt/bash/dev/lib/bash/sleep sleep
function f1 { for a in 1; do builtin sleep 0.1; done }
builtin bind -x '"\C-t": v=${ f1 & }'
