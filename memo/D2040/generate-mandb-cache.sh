#!/usr/bin/env bash

if [[ -s ~/.mwg/src/ble.sh/out/ble.sh ]]; then
  source ~/.mwg/src/ble.sh/out/ble.sh --lib
else
  source ~/.local/share/blesh/ble.sh --lib
fi
ble-import core-complete
ble-import core-cmdspec
for cmd in alias bind cd command declare typeset dirs disown echo exec export fc hash help history jobs kill; do
  echo "========== $cmd =========="
  ble/complete/mandb/generate-cache "$cmd" && awk -F $'\x1c' '{print $1}' "$ret"
done
