#!/usr/bin/env bash

# function set_trap { for sig in INT QUIT; do trap "echo $sig >/dev/tty; trap - $sig; kill -$sig $BASHPID" "$sig"; done; }
# function process_something { echo do >/dev/tty; for ((i=0;i<1000000;i++)); do :; done; echo done >/dev/tty; }

function set_trap {
  trap 'echo INT >/dev/tty;trap - INT;kill -INT $BASHPID' INT
}
function process_something {
  echo start >/dev/tty
  for ((i=0;i<1000000;i++)); do :; done
  echo end >/dev/tty
}

case $1 in
(direct)
  set_trap; process_something ;;
(subshell)
  (set_trap; process_something) ;;
(comsub)
  : $(set_trap; process_something) ;;
(subshell-inherit)
  set_trap; (process_something) ;;
(comsub-inherit)
  set_trap; : $(process_something) ;;
(comsub-plain)
  : $(process_something) ;;
esac
