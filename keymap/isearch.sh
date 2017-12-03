#!/bin/bash

function ble-edit/load-keymap-definition:isearch { :; }

function ble-decode/keymap:isearch/define {
  local ble_bind_keymap=isearch

  ble-bind -f __defchar__ isearch/self-insert
  ble-bind -f C-r         isearch/backward
  ble-bind -f C-s         isearch/forward
  ble-bind -f C-h         isearch/prev
  ble-bind -f DEL         isearch/prev

  ble-bind -f __default__ isearch/exit-default
  ble-bind -f M-C-j       isearch/exit
  ble-bind -f C-d         isearch/exit-delete-forward-char
  ble-bind -f C-g         isearch/cancel
  ble-bind -f C-j         isearch/accept
  ble-bind -f C-m         isearch/accept
}
