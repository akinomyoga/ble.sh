
# source 3ximus.dotfiles/.bash/git-prompt.sh
# source 3ximus.dotfiles/.bash/prompts/prompt_7.sh
# source ~/.mwg/src/ble.sh/out/ble.sh
#------------------------------------------------------------------------------
# source 3ximus.dotfiles/.bash/git-prompt.sh
# GIT_PS1_SHOWDIRTYSTATE='nonempty'
# GIT_PS1_SHOWSTASHSTATE='nonempty'
# GIT_PS1_SHOWUNTRACKEDFILES='nonempty'
# PROMPT_COMMAND='__git_ps1 "" "\\$ " " %s"'
# source ~/.mwg/src/ble.sh/out/ble.sh
#------------------------------------------------------------------------------
# PROMPT_COMMAND='(true)'
# source ~/.mwg/src/ble.sh/out/ble.sh
#------------------------------------------------------------------------------
# PROMPT_COMMAND='(date;printf "%s\n" "${FUNCNAME[*]}")>>a.txt'
# source ~/.mwg/src/ble.sh/out/ble.sh

# Result:
#
# ble/prompt/update/.eval-prompt_command.1
# ble/prompt/update/.eval-prompt_command
# ble/prompt/update ble/textarea#render
# ble/textarea#redraw
# ble-edit/attach/TRAPWINCH
# blehook/invoke
# ble/builtin/trap/.handler
#------------------------------------------------------------------------------
# PROMPT_COMMAND='pcmd'
# pcmd() {
#   echo "QQQ:${FUNCNAME[*]: -1}"
#   jobs
#   echo MMM
#   (true)
#   jobs # ここで (true) が終了ジョブとして表示される。
#   echo ZZZ
# } >> a.txt
# source ~/.mwg/src/ble.sh/out/ble.sh

# trapwinch() {
#   (true); jobs
# }
#trap '(true); jobs' WINCH
#------------------------------------------------------------------------------

#trap '(true); jobs' WINCH
#trap '(true); jobs' INT


# trapwinch() {
#   (true)
#   echo abc
#   (jobs -- "(")
#   echo def
#   jobs
# }
# trap trapwinch WINCH

#------------------------------------------------------------------------------

# trap '(true)' WINCH
# bind -x '"\C-u":true'
# bind -x '"\C-t":jobs'
