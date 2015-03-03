#!/bin/bash

if type tput &>/dev/null; then
  _ble_term_hasput=1
  function ble/term.sh/tput { tput "$@" 2>/dev/null; }
else
  function ble/term.sh/tput { return 1; }
fi

function ble/term.sh/register-varname {
  local name="$1"
  varnames[${#varnames[@]}]="$name"
}

function ble/term.sh/define-cap {
  local name="$1" def="$2"
  shift 2
  eval "$name=\"\$(ble/term.sh/tput $@ || echo -n \"\$def\")\""
  ble/term.sh/register-varname "$name"
}
function ble/term.sh/define-cap.2 {
  local name="$1" def="$2"
  shift 2
  eval "$name=\"\$(echo -n x;ble/term.sh/tput $@ || echo -n \"\$def\";echo -n x)\"; $name=\${$name#x}; $name=\${$name%x}"
  ble/term.sh/register-varname "$name"
}

function ble/term.sh/initialize {
  local -a varnames=()

  # xenl (end of line behavior)
  _ble_term_xenl=1
  [[ $_ble_term_hasput ]] &&
    ! tput xenl &>/dev/null &&
    _ble_term_xenl=0
  ble/term.sh/register-varname _ble_term_xenl

  # tab width
  _ble_term_it=8
  if [[ $_ble_term_hasput ]]; then
    _ble_term_it="$(tput it 2>/dev/null)"
    _ble_term_it="${_ble_term_it:-8}"
  fi
  ble/term.sh/register-varname _ble_term_it

  # IND/RI, CR, LF
  ble/term.sh/define-cap.2 _ble_term_ind $'\eD' ind
  ble/term.sh/define-cap   _ble_term_ri  $'\eM' ri
  ble/term.sh/define-cap   _ble_term_cr  $''  cr
  _ble_term_nl=$'\n'
  ble/term.sh/register-varname _ble_term_nl

  # CUU/CUD/CUF/CUB
  ble/term.sh/define-cap _ble_term_cuu $'\e[%dA' cuu 123
  ble/term.sh/define-cap _ble_term_cud $'\e[%dB' cud 123
  ble/term.sh/define-cap _ble_term_cuf $'\e[%dC' cuf 123
  ble/term.sh/define-cap _ble_term_cub $'\e[%dD' cub 123
  _ble_term_cuu="${_ble_term_cuu//123/%d}"
  _ble_term_cud="${_ble_term_cud//123/%d}"
  _ble_term_cuf="${_ble_term_cuf//123/%d}"
  _ble_term_cub="${_ble_term_cub//123/%d}"
  # ※もし 122 だとか 124 だとかになると上記では駄目

  # CUP
  ble/term.sh/define-cap _ble_term_cup $'\e[13;35H' cup 12 34
  _ble_term_cup="${_ble_term_cup//13/%l}"
  _ble_term_cup="${_ble_term_cup//35/%c}"
  _ble_term_cup="${_ble_term_cup//12/%y}"
  _ble_term_cup="${_ble_term_cup//34/%x}"

  # CHA HPA VPA
  ble/term.sh/define-cap _ble_term_hpa "$_ble_term_cr${_ble_term_cuf//'%d'/123}" hpa 123
  _ble_term_hpa="${_ble_term_hpa//123/%x}"
  _ble_term_hpa="${_ble_term_hpa//124/%c}"
  ble/term.sh/define-cap _ble_term_vpa "${_ble_term_cuu//'%d'/199}${_ble_term_cud//'%d'/123}" vpa 123
  _ble_term_vpa="${_ble_term_vpa//123/%y}"
  _ble_term_vpa="${_ble_term_vpa//124/%l}"

  # CUP+ED (clear_screen)
  ble/term.sh/define-cap _ble_term_clear $'\e[H\e[2J' clear

  # IL/DL
  ble/term.sh/define-cap _ble_term_il $'\e[%dL' il 123
  ble/term.sh/define-cap _ble_term_dl $'\e[%dM' dl 123
  _ble_term_il="${_ble_term_il//123/%d}"
  _ble_term_dl="${_ble_term_dl//123/%d}"

  # EL
  ble/term.sh/define-cap _ble_term_el  $'\e[K'  el
  ble/term.sh/define-cap _ble_term_el1 $'\e[1K' el1
  if [[ $_ble_term_el == $'\e[K' && $_ble_term_el1 == $'\e[1K' ]]; then
    _ble_term_el2=$'\e[2K'
  else
    _ble_term_el2="$_ble_term_el1$_ble_term_el"
  fi
  ble/term.sh/register-varname _ble_term_el2

  # DECSC/DECRC or SCOSC/SCORC
  ble/term.sh/define-cap _ble_term_sc $'\e[s' sc
  ble/term.sh/define-cap _ble_term_rc $'\e[u' rc

  # SGR clear
  ble/term.sh/define-cap _ble_term_sgr0 $'\e[m' sgr0

  # SGR misc
  ble/term.sh/define-cap _ble_term_sgr_fghr $'\e[91m' setaf 9
  ble/term.sh/define-cap _ble_term_sgr_fghb $'\e[94m' setaf 12
  ble/term.sh/define-cap _ble_term_setaf2 $'\e[32m' setaf 2
  ble/term.sh/define-cap _ble_term_rev $'\e[7m' rev

  if ((_ble_bash>=30100)); then
    declare -p "${varnames[@]}" | sed '
      s/^declare \(-- \)\{0,1\}//
    ' > "$_ble_base/cache/$TERM.term"
  else
    # bash-3.0 の declare -p は改行について誤った出力をする。
    local var
    for var in "${varnames[@]}"; do
      eval "printf '$var=%q' \"\${$var}\""
    done > "$_ble_base/cache/$TERM.term"
  fi
}

echo -n "ble/term.sh: updating tput cache for TERM=$TERM..." >&2
ble/term.sh/initialize
echo    "ble/term.sh: updating tput cache for TERM=$TERM... done" >&2
