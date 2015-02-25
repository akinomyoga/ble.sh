#!/bin/bash

if type tput &>/dev/null; then
  _ble_term_hasput=1
  function ble/term.sh/tput { tput "$@" 2>/dev/null; }
else
  function ble/term.sh/tput { return 1; }
fi

function ble/term.sh/define-cap {
  local name="$1" def="$2"
  shift 2
  eval "$name=\"\$(ble/term.sh/tput $@ || echo -n \"\$def\")\""
  varnames+=("$name")
}
function ble/term.sh/define-cap.2 {
  local name="$1" def="$2"
  shift 2
  eval "$name=\"\$(echo -n x;ble/term.sh/tput $@ || echo -n \"\$def\";echo -n x)\"; $name=\${$name#x}; $name=\${$name%x}"
  varnames+=("$name")
}

function ble/term.sh/initialize {
  local varnames=()

  # xenl (end of line behavior)
  _ble_term_xenl=1
  [[ $_ble_term_hasput ]] &&
    ! tput xenl &>/dev/null &&
    _ble_term_xenl=0
  varnames+=(_ble_term_xenl)

  # tab width
  _ble_term_it=8
  if [[ $_ble_term_hasput ]]; then
    _ble_term_it="$(tput it 2>/dev/null)"
    _ble_term_it="${_ble_term_it:-8}"
  fi
  varnames+=(_ble_term_it)

  # CUU/CUD/CUF/CUB
  ble/term.sh/define-cap _ble_term_cuu $'\e[%dA' cuu 123
  ble/term.sh/define-cap _ble_term_cud $'\e[%dB' cud 123
  ble/term.sh/define-cap _ble_term_cuf $'\e[%dC' cuf 123
  ble/term.sh/define-cap _ble_term_cub $'\e[%dD' cub 123
  _ble_term_cuu="${_ble_term_cuu//123/%d}"
  _ble_term_cud="${_ble_term_cud//123/%d}"
  _ble_term_cuf="${_ble_term_cuf//123/%d}"
  _ble_term_cub="${_ble_term_cub//123/%d}"
  # 122 だとか 124 だとかになっていると上記は駄目になる…。

  # CUP
  ble/term.sh/define-cap _ble_term_cup $'\e[13;35H' cup 12 34
  _ble_term_cup="${_ble_term_cup//13/%l}"
  _ble_term_cup="${_ble_term_cup//35/%c}"
  _ble_term_cup="${_ble_term_cup//12/%y}"
  _ble_term_cup="${_ble_term_cup//34/%x}"

  # IL/DL
  ble/term.sh/define-cap _ble_term_il $'\e[%dL' il 123
  ble/term.sh/define-cap _ble_term_dl $'\e[%dM' dl 123
  _ble_term_il="${_ble_term_il//123/%d}"
  _ble_term_dl="${_ble_term_dl//123/%d}"

  # IND/RI
  ble/term.sh/define-cap.2 _ble_term_ind $'\eD' ind
  ble/term.sh/define-cap _ble_term_ri  $'\eM' ri

  # CR
  ble/term.sh/define-cap _ble_term_cr $'' cr

  # EL
  ble/term.sh/define-cap _ble_term_el  $'\e[K'  el
  ble/term.sh/define-cap _ble_term_el1 $'\e[1K' el1
  if [[ $_ble_term_el == $'\e[K' && $_ble_term_el1 == $'\e[1K' ]]; then
    _ble_term_el2=$'\e[2K'
  else
    _ble_term_el2="$_ble_term_el1$_ble_term_el"
  fi
  varnames+=(_ble_term_el2)

  # SC/RC or SCOSC/SCORC
  ble/term.sh/define-cap _ble_term_sc $'\e[s' sc
  ble/term.sh/define-cap _ble_term_rc $'\e[u' rc

  # SGR clear
  ble/term.sh/define-cap _ble_term_sgr0 $'\e[m' sgr0

  # SGR misc
  ble/term.sh/define-cap _ble_term_sgr_fghr $'\e[91m' setaf 9
  ble/term.sh/define-cap _ble_term_sgr_fghb $'\e[94m' setaf 12
  ble/term.sh/define-cap _ble_term_setaf2 $'\e[32m' setaf 2
  ble/term.sh/define-cap _ble_term_rev $'\e[7m' rev

  declare -p "${varnames[@]}" | sed '
    s/^declare \(-- \)\{0,1\}//
  ' > "$_ble_base/cache/$TERM.term"
}

echo -n "ble/term.sh: updating tput cache for TERM=$TERM..." >&2
ble/term.sh/initialize
echo    "ble/term.sh: updating tput cache for TERM=$TERM... done" >&2
