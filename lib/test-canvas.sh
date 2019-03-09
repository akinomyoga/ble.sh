#!/bin/bash

function test1 {
  local -a DRAW_BUFF=() x=0 y=0 LINES=20 COLUMNS=10
  ble/canvas/rmoveto.draw 3 3
  x=0 y=0
  ble/canvas/trace.draw 'hello world this is a flow world' relative
  ble/canvas/bflush.draw
  ble/util/buffer.flush
  echo

  LINES=1 COLUMNS=20 x=0 y=0
  ble/canvas/trace.draw '12345678901234567890hello' nooverflow
  ble/canvas/bflush.draw
  ble/util/buffer.flush
}
test1
