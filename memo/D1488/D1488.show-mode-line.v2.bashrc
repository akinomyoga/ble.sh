# -*- mode: sh; mode: sh-bash -*-

set -o vi
bind '"\C-l": clear-screen'

# bind 'set show-mode-in-prompt on'
# bind $'set vi-cmd-mode-string \1\eD\eM\e7\e[9999B\r\e[K\e[1m~\e[m\e8\2'
# bind $'set vi-ins-mode-string \1\eD\eM\e7\e[9999B\r\e[K\e[1m-- INSERT --\e[m\e8\2'
# PS0=$'\1\e7\e[9999B\e[2K\e8\2'

CMD='\e[1m~\e[m'
INSERT='\e[1m-- INSERT --\e[m'
bind 'set show-mode-in-prompt on'
bind $"set vi-cmd-mode-string \1\eD\eM\e7\e[9999B\r\e[K\e[1m$CMD\e[m\e8\2"
bind $"set vi-ins-mode-string \1\eD\eM\e7\e[9999B\r\e[K\e[1m$INSERT\e[m\e8\2"
PS0=$'\1\e7\e[9999B\e[2K\e8\2'
#PS4=$'\1\e7\eD\eM\e[9999B\e[2K\e8\2'
