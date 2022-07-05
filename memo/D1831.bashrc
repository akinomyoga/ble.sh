# bashrc -*- mode: sh; mode: sh-bash -*-

if [[ ! -f out/ble.sh ]]; then
  echo 'memo/D1831.bashrc: out/ble.sh not found.' >&2
  return 2
fi

cp -f memo/D1831.history{,.tmp}
HISTFILE=$PWD/memo/D1831.history.tmp
HISTFILESIZE=
HISTSIZE=
HISTTIMEFORMAT=%s
source out/ble.sh --norc -o vbell_duration=5000
