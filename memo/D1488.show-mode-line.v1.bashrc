# bashrc

set -o vi
bind 'set show-mode-in-prompt on'
bind $'set vi-cmd-mode-string \eD\eM\e7\e[9999B\r\e[K\e[1m~\e[m\e8'
bind $'set vi-ins-mode-string \eD\eM\e7\e[9999B\r\e[K\e[1m-- INSERT --\e[m\e8'
PS0=$'\e7\eD\eM\e[9999B\e[2K\e8'

bind '"\C-l": clear-screen'
