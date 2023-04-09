#!/usr/bin/env bash

prefix=D1956

function test1/fds {
  local pid=$(exec sh -c 'echo "$PPID"')
  ls -la "/proc/$pid/fd" >/dev/tty
} <&"$_test1_a" >&"$_test1_b"

function test1/sqlite3 {
  exec sqlite3 -quote -cmd "-- [ble-test1: $$]" "$prefix.sqlite3" <&"$_test1_a" >&"$_test1_b"
}

function test1 {
  local fa=$prefix.a.pipe
  local fb=$prefix.b.pipe
  rm -f "$fa" "$fb"
  mkfifo "$fa" "$fb"
  exec 36<> "$fa"
  exec 37<> "$fb"
  _test1_a=36
  _test1_b=37

  #bgpid=$(test1/sqlite3 >/dev/null & disown; echo $!)
  bgpid=$(test1/fds >/dev/null & disown; echo $!)
  if ! kill -0 "$bgpid"; then
    echo 'background sqlite3 failed to start.' >&2
    bgpid=
  fi
}
test1
