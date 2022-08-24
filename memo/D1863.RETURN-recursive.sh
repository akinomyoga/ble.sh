
# 通常の RETURN の使い方

f2() {
  trap 'echo "RETURN/f2 @ ${BLE_TRAP_FUNCNAME:-$FUNCNAME}"; trap - RETURN' RETURN
  echo f2
  echo /f2
}

f1() {
  trap 'echo "RETURN/f1 @ ${BLE_TRAP_FUNCNAME:-$FUNCNAME}"; trap - RETURN' RETURN
  echo f1
  f2
  echo /f1
}

f0() {
  echo f0
  f1
  echo /f0
}

f0
trap -p
echo

# ble.sh 内部の構造 (function trap に対して RETURN trap が発火しない様
# に install-hook した時)

ihandler=0
trap_handler() {
  local offset
  for ((offset=1;offset<${#FUNCNAME[@]};offset++)); do
    case ${FUNCNAME[offset]} in
    (ble/builtin/trap/invoke.sandbox | ble/builtin/trap/invoke | ble/builtin/trap/.handler) ;;
    (trap_set | trap | ble/builtin/trap) return 0 ;;
    (*) break ;;
    esac
  done
  #echo "trap_handler(offset=$offset,${FUNCNAME[*]})" >/dev/tty
  eval "${trap_handlers[$1]}"
}
declare -ft trap_handler
trap_set() {
  if [[ $1 == - ]]; then
    trap - RETURN
    echo "[note: current RETURN trap: $(trap -p RETURN)]"
  else
    trap_handlers[ihandler]=$1
    trap "trap_handler $((ihandler++))" RETURN
  fi
}
declare -ft trap_set

f2() {
  trap_set 'echo "RETURN/f2 @ ${BLE_TRAP_FUNCNAME:-${FUNCNAME[1]}}"; trap_set -'
  echo f2
  echo /f2
}

f1() {
  trap_set 'echo "RETURN/f1 @ ${BLE_TRAP_FUNCNAME:-${FUNCNAME[1]}}"; trap_set -'
  echo f1
  f2
  echo /f1
}

f0() {
  echo f0
  f1
  echo /f0
}

f0
trap -p
