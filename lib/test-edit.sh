#!/bin/bash

ble-import lib/core-test

ble/test/start-section 'ble/edit' 2

(
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-eol 13 -1" exit=0 ret=10
  ble/test "_ble_edit_str=$'echo\nhello\nworld' ble-edit/content/find-logical-bol 13 -1" exit=0 ret=5
)

ble/test/end-section
