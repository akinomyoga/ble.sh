#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

function echo.normal {
  echo hello
}

function echo.builtin {
  builtin echo hello
}

function ble/builtin/echo1 {
  builtin echo "$@"
}
function echo.function1 {
  ble/builtin/echo1 hello
}

function ble/builtin/echo2 {
  builtin printf '%s\n' "$*"
}
function echo.function2 {
  ble/builtin/echo2 hello
}

ble-measure echo.normal
ble-measure echo.builtin
ble-measure echo.function1
ble-measure echo.function2

function ble/print {
  builtin echo "$@"
}
function echo.functionS {
  ble/print hello
}

function ble/p {
  builtin echo "$@"
}
function echo.functiont {
  ble/p hello
}

ble-measure echo.functionS
ble-measure echo.functiont
