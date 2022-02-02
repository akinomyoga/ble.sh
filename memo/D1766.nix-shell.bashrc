#!/bin/bash

echo bashrc
PS1=prompt_string
[[ $- == *i* ]] && source out/ble.sh --attach=none
[[ ${BLE_VERSION-} ]] && ble-attach
exec echo world
