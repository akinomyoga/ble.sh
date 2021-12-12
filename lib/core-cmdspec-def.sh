# -*- mode: sh; mode: sh-bash -*-

function ble/cmdspec/initialize { ble-import "$_ble_base/lib/core-cmdspec.sh"; }
ble/is-function ble/util/idle.push && ble-import -d "$_ble_base/lib/core-cmdspec.sh"
