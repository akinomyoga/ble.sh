# -*- mode: sh; mode: sh-bash -*-

set -o vi
shopt -s no_empty_cmd_completion
function ble-decode/.hook {
  echo ble-decode/.hook: $1
  if (($1==4)); then
    echo exit
    exit
  elif (($1==20)); then
    local POSIXLY_CORRECT=y
    unset -f echo
    unset POSIXLY_CORRECT
  fi
}
source D0727.bind.source1 # $_ble_base_cache/ble-decode-bind.$_ble_bash.UTF-8.unbind
source D0727.bind.source2 # $_ble_base_cache/ble-decode-bind.$_ble_bash.UTF-8.bind
