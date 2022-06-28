#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

i=1
#((I+1))
ble-measure 'i=$(expr "$1" + 1)'
ble-measure '((i++))'

