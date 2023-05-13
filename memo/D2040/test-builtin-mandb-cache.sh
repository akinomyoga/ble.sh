#!/usr/bin/env bash

# https://github.com/akinomyoga/ble.sh/issues/325#issuecomment-1546542201

# shellcheck disable=1090
blesh=~/.mwg/src/ble.sh/out/ble.sh
if [[ ! -s $blesh ]]; then
  blesh=~/.local/share/blesh/ble.sh
  if [[ ! -s $blesh ]]; then
    echo "$0: failed to find ble.sh." >&2
    return 1
  fi
fi

source "$blesh" --lib
ble-import core-complete
ble-import core-cmdspec

# Note: +f was removed from declare, typeset, local.
# Note: -DEI was removed from compgen
declare -A command_options=([":"]="" [source]="" [alias]="-p" [bg]=""
  [bind]="-m -l -p -s -v -P -S -V -X -q -u -r -f -x" [break]="" [builtin]=""
  [caller]="" [cd]="-L -P -e -@" [command]="-p -V -v" [compgen]="-a -b -c -d -e
  -f -g -j -k -s -u -v -o -A -G -W -F -C -X -P -S" [complete]="-a -b -c -d -e
  -f -g -j -k -s -u -v -o -D -E -I -A -G -W -F -C -X -P -S -p -r" [compopt]="-o
  -D -E -I +o" [continue]="" [declare]="-a -A -f -F -g -i -I -l -n -r -t -u -x
  -p +a +A +i +l +n +r +t +u +x" [typeset]="-a -A -f -F -g -i -I -l -n -r -t -u
  -x -p +a +A +i +l +n +r +t +u +x" [dirs]="-c -l -p -v" [disown]="-a -r -h"
  [echo]="-n -e -E" [enable]="-a -d -n -p -s -f" [eval]="" [exec]="-c -l -a"
  [exit]="" [export]="-f -n -p" [fc]="-e -l -n -r -s" [fg]="" [getopts]=""
  [hash]="-l -r -p -d -t" [help]="-d -m -s" [history]="-c -d -a -n -r -w -p -s"
  [jobs]="-l -n -p -r -s -x" [kill]="-s -n -l -L" [local]="-a -A -f -F -g -i -I
  -l -n -r -t -u -x -p +a +A +i +l +n +r +t +u +x" [logout]="" [mapfile]="-d -n
  -O -s -t -u -C -c" [readarray]="-d -n -O -s -t -u -C -c" [popd]="-n"
  [printf]="-v" [pushd]="-n" [pwd]="-L -P" [read]="-e -r -s -a -d -i -n -N -p
  -t -u" [readonly]="-a -A -f -p" [return]="" [set]="-a -b -e -f -h -k -m -n -p
  -t -u -v -x -B -C -E -H -P -T -o +a +b +e +f +h +k +m +n +p +t +u +v +x +B +C
  +E +H +P +T +o" [shift]="" [shopt]="-p -q -s -u -o" [suspend]="-f" [test]="-a
  -b -c -d -e -f -g -h -k -p -r -s -t -u -w -x -G -L -N -O -S -ef -nt -ot -o -v
  -R -z -n -eq -ne -gt -lt -ge -le" [times]="" [trap]="-l -p" [type]="-a -f -t
  -p -P" [ulimit]="-H -S -a -b -c -d -e -f -i -k -l -m -n -p -q -r -s -t -u -v
  -x -P -R -T" [umask]="-p -S" [unalias]="-a" [unset]="-f -v -n" [wait]="-f -n
  -p")

declare -i counter=0
set -f

for name in "${!command_options[@]}"; do
  suggestions=()
  # shellcheck disable=SC2154
  ble/complete/mandb/generate-cache "$name" &&
    ble/string#split-words suggestions "$(awk --field-separator=$'\x1c' '{print $1}' "$ret")"

  options=()
  ble/string#split-words options "${command_options[$name]}"

  echo "$name:"
  #echo "$name: ${suggestions[*]}"
  declare -i is_broken=0
  for option in "${options[@]}"; do
    grep --quiet -- "$option" <<< "${suggestions[*]}" || {
      echo "- '$option' is not suggested, while it's documented"
      is_broken=1
    }
  done

  for option in "${suggestions[@]}"; do
    [[ $option == --help || $option == -- ]] && continue
    grep --quiet -- "$option" <<< "${options[*]}" || {
      echo "- '$option' is suggested, while it's unknown"
      is_broken=1
    }
  done

  counter+=$is_broken
  echo
done

echo "$counter out of ${#command_options[@]} are broken"
