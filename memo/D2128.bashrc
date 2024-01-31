# bashrc -*- mode: sh-bash -*-

# if [[ ! $PS1 =~ 133 ]] ; then
#   #echo ""
#   PS1='\[\e]133;L\a\]\[\e]133;D;$?\]\[\e]133;A\a\]'$PS1'\[\e]133;B\a\]' ;
#   PS2='\[\e]133;A\a\]'$PS2'\[\e]133;B\a\]' ;
#   PS0='\[\e]133;C\a\]' ; fi

#------------------------------------------------------------------------------
# https://github.com/akinomyoga/ble.sh/issues/391#issuecomment-1915834867

# 初期化順序で動いたり動かなかったりする問題? でも再現しない。

# * bash-preexec version? → 動く

# # Settings for Bash-it
# BASH_IT=~/.mwg/git/Bash-it/bash-it
# export BASH_IT_THEME='bobby'
# export GIT_HOSTING='git@git.domain.com'
# unset MAILCHECK
# export IRC_CLIENT='irssi'
# export TODO="t"
# export SCM_CHECK=true

# # working
# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# ble-attach

# # working
# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# source ~/.mwg/git/PerBothner/DomTerm/tools/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# ble-attach

# # working
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# ble-attach

# # working
# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# source ~/.mwg/git/Bash-it/bash-it/bash_it.sh
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# ble-attach

# # working
# source ~/.mwg/git/Bash-it/bash-it/bash_it.sh
# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# ble-attach

# # working (with "bash-it enable plugin blesh")
# source ~/.mwg/git/Bash-it/bash-it/bash_it.sh
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
# ble-attach

#------------------------------------------------------------------------------

source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
export BASH_IT_THEME='bobby'
export SCM_CHECK=true
export THEME_SHOW_PYTHON=true
source ~/.mwg/git/Bash-it/bash-it/bash_it.sh
#source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
source ~/.mwg/git/PerBothner/DomTerm/tools/bash-preexec.sh
source ~/.mwg/git/PerBothner/DomTerm/tools/shell-integration.bash
ble-attach

# source ~/.mwg/src/ble.sh/out/ble.sh --norc --attach=none
# source ~/.mwg/git/rcaloras/bash-preexec/bash-preexec.sh
# function _my_preexec { echo "$FUNCNAME (${FUNCNAME[*]:1})"; }
# function _my_precmd { echo "$FUNCNAME (${FUNCNAME[*]:1})"; }
# preexec_functions+=('_my_preexec')
# precmd_functions+=('_my_precmd')
# ble-attach
