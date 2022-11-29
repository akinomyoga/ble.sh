# debug

print_posix() {
  local tag=$1
  if [[ -o posix ]]; then
    echo "${tag:+$tag: }posix [POSIXLY_CORRECT=${POSIXLY_CORRECT-(unset)}]"
  else
    echo "${tag:+$tag: }not posix [POSIXLY_CORRECT=${POSIXLY_CORRECT-(unset)}]"
  fi >/dev/pts/3
}
print_posix profile1
set +o posix
print_posix profile2

# Test 1 (prompt attach)
#source ~/.mwg/src/ble.sh/out/ble.sh --attach=prompt
#PROMPT_COMMAND+=('print_posix PROMPT_COMMAND; unset POSIXLY_CORRECT')

# Test 2 (direct attach)
#source ~/.mwg/src/ble.sh/out/ble.sh --attach=attach

# Test 3 (manual attach)
source ~/.mwg/src/ble.sh/out/ble.sh --attach=none
ble-attach
#echo ATTACHED >/dev/tty
