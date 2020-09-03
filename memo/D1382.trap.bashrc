#!/bin/bash

function is-interactive-execution {
  (alias false=true; eval false)
}

# これは駄目。その場で実行される。
function sub:attach-signal {
  trap 'echo USR2' USR2
  #kill -USR2 $$
  kill -USR2 $$ &
}

function sub:attach-debug/handler {
  echo "[$LINENO:$HISTCMD:$-] $BASH_COMMAND"
  #echo "opts=$BASHOPTS"
  is-interactive-execution; echo "interactive? $?"
  declare -p FUNCNAME BASH_LINENO BASH_SOURCE
}
function sub:attach-debug {
  trap 'sub:attach-debug/handler' DEBUG
}
sub:attach-debug

#echo "\$*=($*)"
#declare marker=this_is_bashrc

function sub:check-bashrc {
  shopt -u extdebug
  echo "BASH_ENV=$BASH_ENV"
  declare | grep D0000.trap.bashrc
}

#echo "LINENO=$LINENO"

sleep 0.2
echo Middle of Bashrc
sleep 0.2
echo End of Bashrc
PROMPT_COMMAND='echo Prompt Command'
