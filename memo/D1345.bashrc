#!/bin/bash

shopt -s checkwinsize
function p1 {
  echo "[$COLUMNS:$LINES] $READLINE_LINE"
}
function winch {
  trap -- 'echo "[$COLUMNS:$LINES] $READLINE_LINE (WINCH)"' WINCH
}

function handle-t {
  exec &>/dev/tty
  p1
  exec &>/dev/null
}
function handle-u {
  exec &>/dev/tty
  p1
}
function handle-h {
  exec &>/dev/tty
  exec &>/dev/null
}
winch

bind -x '"\C-t": handle-t'
bind -x '"\C-h": handle-h'
bind -x '"\C-y": handle-u'
