#!/bin/bash

bind 'set keymap emacs'
bind '"A": "from 0.sh"'
bind -f D1038.test1.1.inputrc
bind '"E": "from 0.sh"'

if [[ $_ble_attached ]]; then
  ble-bind -m emacs -m vi_imap -m vi_nmap -P | grep ' -s'
  ble/debug/print-variables _ble_builtin_bind_keymap
else
  echo '# keymap emacs'
  bind -m emacs -s
  echo '# keymap vi-insert'
  bind -m vi-insert -s
  echo '# keymap vi-command'
  bind -m vi-command -s
  bind -v | grep keymap
fi
