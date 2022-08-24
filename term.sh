#!/bin/bash

# 2020-02-07 #D12MSYS2 の CR 対策のため更新の必要あり

function ble/term.sh/tput { return 1; }
if type tput &>/dev/null; then
  _ble_term_hasput=1
  if tput cuu 1 &>/dev/null; then
    function ble/term.sh/tput { tput "${1%%:*}" "${@:2}" 2>/dev/null; }
  elif tput UP 1 &>/dev/null; then
    function ble/term.sh/tput { tput "${1#*:}" "${@:2}" 2>/dev/null; }
  fi
fi

function ble/term.sh/register-varname {
  local name="$1"
  varnames[${#varnames[@]}]="$name"
}

function ble/term.sh/define-cap {
  local IFS=$_ble_term_IFS
  local name=$1 def=$2
  shift 2
  builtin eval "$name=\"\$(ble/term.sh/tput $* || echo -n \"\$def\")\""
  ble/term.sh/register-varname "$name"
}
function ble/term.sh/define-cap.2 {
  local IFS=$_ble_term_IFS
  local name=$1 def=$2
  shift 2
  builtin eval "$name=\"\$(echo -n x;ble/term.sh/tput $* || echo -n \"\$def\";echo -n x)\"; $name=\${$name#x}; $name=\${$name%x}"
  ble/term.sh/register-varname "$name"
}

_ble_term_rex_sgr='\[([0-9;:]+)m'
function ble/term.sh/define-sgr-param {
  local name="$1" seq="$2"
  if [[ $seq =~ $_ble_term_rex_sgr ]]; then
    builtin eval "$name=\"\${BASH_REMATCH[1]}\""
  else
    builtin eval "$name="
  fi

  if [[ $name =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]; then
    ble/term.sh/register-varname "$name"
  fi
}

function ble/term.sh/initialize {
  local -a varnames=()

  # xenl (end of line behavior)
  _ble_term_xenl=1
  [[ $_ble_term_hasput ]] &&
    ! ble/term.sh/tput xenl:xn &>/dev/null &&
    _ble_term_xenl=0
  ble/term.sh/register-varname _ble_term_xenl

  # tab width
  _ble_term_it=8
  if [[ $_ble_term_hasput ]]; then
    _ble_term_it="$(ble/term.sh/tput it:it 2>/dev/null)"
    _ble_term_it="${_ble_term_it:-8}"
  fi
  ble/term.sh/register-varname _ble_term_it

  # IND/RI, CR, LF
  ble/term.sh/define-cap.2 _ble_term_ind $'\eD' ind:sf
  ble/term.sh/define-cap   _ble_term_ri  $'\eM' ri:sr
  ble/term.sh/define-cap   _ble_term_cr  $''  cr:cr

  # CUU/CUD/CUF/CUB
  ble/term.sh/define-cap _ble_term_cuu $'\e[%dA' cuu:UP 123
  ble/term.sh/define-cap _ble_term_cud $'\e[%dB' cud:DO 123
  ble/term.sh/define-cap _ble_term_cuf $'\e[%dC' cuf:RI 123
  ble/term.sh/define-cap _ble_term_cub $'\e[%dD' cub:LE 123
  _ble_term_cuu="${_ble_term_cuu//123/%d}"
  _ble_term_cud="${_ble_term_cud//123/%d}"
  _ble_term_cuf="${_ble_term_cuf//123/%d}"
  _ble_term_cub="${_ble_term_cub//123/%d}"
  # ※もし 122 だとか 124 だとかになると上記では駄目

  # CUP
  ble/term.sh/define-cap _ble_term_cup $'\e[13;35H' cup:cm 12 34
  _ble_term_cup="${_ble_term_cup//13/%l}"
  _ble_term_cup="${_ble_term_cup//35/%c}"
  _ble_term_cup="${_ble_term_cup//12/%y}"
  _ble_term_cup="${_ble_term_cup//34/%x}"

  # CHA HPA VPA
  ble/term.sh/define-cap _ble_term_hpa "$_ble_term_cr${_ble_term_cuf//'%d'/123}" hpa:ch 123
  _ble_term_hpa="${_ble_term_hpa//123/%x}"
  _ble_term_hpa="${_ble_term_hpa//124/%c}"
  ble/term.sh/define-cap _ble_term_vpa "${_ble_term_cuu//'%d'/199}${_ble_term_cud//'%d'/123}" vpa:cv 123
  _ble_term_vpa="${_ble_term_vpa//123/%y}"
  _ble_term_vpa="${_ble_term_vpa//124/%l}"

  # CUP+ED (clear_screen)
  ble/term.sh/define-cap _ble_term_clear $'\e[H\e[2J' clear:cl

  # IL/DL
  ble/term.sh/define-cap _ble_term_il $'\e[%dL' il:AL 123
  ble/term.sh/define-cap _ble_term_dl $'\e[%dM' dl:DL 123
  _ble_term_il="${_ble_term_il//123/%d}"
  _ble_term_dl="${_ble_term_dl//123/%d}"

  # EL
  ble/term.sh/define-cap _ble_term_el  $'\e[K'  el:ce
  ble/term.sh/define-cap _ble_term_el1 $'\e[1K' el1:cb
  if [[ $_ble_term_el == $'\e[K' && $_ble_term_el1 == $'\e[1K' ]]; then
    _ble_term_el2=$'\e[2K'
  else
    _ble_term_el2="$_ble_term_el1$_ble_term_el"
  fi
  ble/term.sh/register-varname _ble_term_el2

  # ED
  ble/term.sh/define-cap _ble_term_ed  $'\e[J' ed:cd

  # DECSC/DECRC or SCOSC/SCORC
  ble/term.sh/define-cap _ble_term_sc $'\e[s' sc:sc
  ble/term.sh/define-cap _ble_term_rc $'\e[u' rc:rc

  ble/term.sh/define-cap _ble_term_cvvis $'\e[?25h' cvvis:vs
  ble/term.sh/define-cap _ble_term_civis $'\e[?25l' civis:vi

  # SGR clear
  ble/term.sh/define-cap _ble_term_sgr0 $'\e[m' sgr0:me

  # SGR misc
  ble/term.sh/define-cap _ble_term_bold $'\e[1m' bold:md
  ble/term.sh/define-cap _ble_term_sitm $'\e[3m' sitm:ZH
  ble/term.sh/define-cap _ble_term_smul $'\e[4m' smul:us
  ble/term.sh/define-cap _ble_term_blink $'\e[5m' blink:mb
  ble/term.sh/define-cap _ble_term_rev $'\e[7m' rev:mr
  ble/term.sh/define-cap _ble_term_invis $'\e[8m' invis:mk
  ble/term.sh/define-sgr-param _ble_term_sgr_bold "$_ble_term_bold"
  ble/term.sh/define-sgr-param _ble_term_sgr_sitm "$_ble_term_sitm"
  ble/term.sh/define-sgr-param _ble_term_sgr_smul "$_ble_term_smul"
  ble/term.sh/define-sgr-param _ble_term_sgr_blink "$_ble_term_blink"
  ble/term.sh/define-sgr-param _ble_term_sgr_rev "$_ble_term_rev"
  ble/term.sh/define-sgr-param _ble_term_sgr_invis "$_ble_term_invis"

  # SGR colors
  ble/term.sh/define-cap _ble_term_colors 8 colors:Co
  local i
  _ble_term_setaf=()
  _ble_term_setab=()
  _ble_term_sgr_af=()
  _ble_term_sgr_ab=()
  for ((i=0;i<16;i++)); do
    local i1="$((i%8))" af= ab=

    # from terminfo
    if ((i<_ble_term_colors)); then
      local j1
      ((j1=(i1==3?6:
            (i1==6?3:
             (i1==1?4:
              (i1==4?1:i1))))))
      local j="$((k-i1+j1))"

      af="$(ble/term.sh/tput setaf:AF "$i" 2>/dev/null)"
      [[ $af ]] || af="$(ble/term.sh/tput setf:Sf "$j" 2>/dev/null)"

      ab="$(ble/term.sh/tput setab:AB "$i" 2>/dev/null)"
      [[ $ab ]] || ab="$(ble/term.sh/tput setb:Sb "$j" 2>/dev/null)"
    fi

    # default value
    : ${af:=$'\e[3'"${i1}m"}
    : ${ab:=$'\e[4'"${i1}m"}

    # register
    _ble_term_setaf[i]="$af"
    _ble_term_setab[i]="$ab"
    ble/term.sh/define-sgr-param "_ble_term_sgr_af[i]" "$af"
    ble/term.sh/define-sgr-param "_ble_term_sgr_ab[i]" "$ab"
  done
  ble/term.sh/register-varname "_ble_term_setaf"
  ble/term.sh/register-varname "_ble_term_setab"
  ble/term.sh/register-varname "_ble_term_sgr_af"
  ble/term.sh/register-varname "_ble_term_sgr_ab"

  # save
  ble/util/declare-print-definitions "${varnames[@]}" > "$_ble_base/cache/$TERM.term"
}

echo -n "ble/term.sh: updating tput cache for TERM=$TERM... " >&2
ble/term.sh/initialize
echo  "ble/term.sh: updating tput cache for TERM=$TERM... done" >&2
