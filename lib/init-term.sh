#!/bin/bash

if ble/bin/.freeze-utility-path tput; then
  _ble_term_hasput=1
  function ble/init:term/tput { ble/bin/tput "$@" 2>/dev/null; }
else
  function ble/init:term/tput { return 1; }
fi

function ble/init:term/register-varname {
  local name=$1
  varnames[${#varnames[@]}]=$name
}

function ble/init:term/define-cap {
  local name=$1 def=$2
  shift 2
  ble/util/assign "$name" "ble/init:term/tput $* || ble/bin/echo -n \"\$def\""
  ble/init:term/register-varname "$name"
}
function ble/init:term/define-cap.2 {
  local name=$1 def=$2
  shift 2
  ble/util/assign "$name" "ble/bin/echo -n x; ble/init:term/tput $* || ble/bin/echo -n \"\$def\"; ble/bin/echo -n x"
  builtin eval "$name=\${$name#x}; $name=\${$name%x}"
  ble/init:term/register-varname "$name"
}

_ble_term_sgr_term2ansi=()
ble/init:term/register-varname _ble_term_sgr_term2ansi
_ble_term_rex_sgr=$'\e''\[([0-9;:]+)m'
function ble/init:term/define-sgr-param {
  local name=$1 seq=$2 ansi=$3
  if [[ $seq =~ $_ble_term_rex_sgr ]]; then
    local rematch1=${BASH_REMATCH[1]}
    builtin eval "$name=\$rematch1"

    # term2ansi
    if [[ $ansi ]]; then
      local rex='^[0-9]+$'
      [[ $rematch1 =~ $rex ]] &&
        [[ ! ${_ble_term_sgr_term2ansi[rematch1]} ]] &&
        _ble_term_sgr_term2ansi[rematch1]=$ansi
    fi
  else
    builtin eval "$name="
  fi

  if [[ $name =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]; then
    ble/init:term/register-varname "$name"
  fi
}

function ble/init:term/initialize {
  local -a varnames=()

  # xenl (end of line behavior)
  _ble_term_xenl=1
  [[ $_ble_term_hasput ]] &&
    ! ble/init:term/tput xenl &>/dev/null &&
    _ble_term_xenl=0
  ble/init:term/register-varname _ble_term_xenl

  # tab width
  _ble_term_it=8
  if [[ $_ble_term_hasput ]]; then
    ble/util/assign _ble_term_it 'ble/init:term/tput it'
    _ble_term_it=${_ble_term_it:-8}
  fi
  ble/init:term/register-varname _ble_term_it

  # IND/RI, CR, LF, FS
  ble/init:term/define-cap.2 _ble_term_ind $'\eD' ind
  ble/init:term/define-cap   _ble_term_ri  $'\eM' ri
  ble/init:term/define-cap   _ble_term_cr  $'\r'  cr
  _ble_term_nl=$'\n'
  ble/init:term/register-varname _ble_term_nl
  _ble_term_IFS=$' \t\n'
  ble/init:term/register-varname _ble_term_IFS
  _ble_term_fs=$'\034'
  ble/init:term/register-varname _ble_term_fs

  # CUU/CUD/CUF/CUB
  ble/init:term/define-cap _ble_term_cuu $'\e[%dA' cuu 123
  ble/init:term/define-cap _ble_term_cud $'\e[%dB' cud 123
  ble/init:term/define-cap _ble_term_cuf $'\e[%dC' cuf 123
  ble/init:term/define-cap _ble_term_cub $'\e[%dD' cub 123
  _ble_term_cuu=${_ble_term_cuu//123/%d}
  _ble_term_cud=${_ble_term_cud//123/%d}
  _ble_term_cuf=${_ble_term_cuf//123/%d}
  _ble_term_cub=${_ble_term_cub//123/%d}
  # ※もし 122 だとか 124 だとかになると上記では駄目

  # CUP
  ble/init:term/define-cap _ble_term_cup $'\e[13;35H' cup 12 34
  _ble_term_cup=${_ble_term_cup//13/%l}
  _ble_term_cup=${_ble_term_cup//35/%c}
  _ble_term_cup=${_ble_term_cup//12/%y}
  _ble_term_cup=${_ble_term_cup//34/%x}

  # CHA HPA VPA
  ble/init:term/define-cap _ble_term_hpa "$_ble_term_cr${_ble_term_cuf//'%d'/123}" hpa 123
  _ble_term_hpa=${_ble_term_hpa//123/%x}
  _ble_term_hpa=${_ble_term_hpa//124/%c}
  ble/init:term/define-cap _ble_term_vpa "${_ble_term_cuu//'%d'/199}${_ble_term_cud//'%d'/123}" vpa 123
  _ble_term_vpa=${_ble_term_vpa//123/%y}
  _ble_term_vpa=${_ble_term_vpa//124/%l}

  # CUP+ED (clear_screen)
  ble/init:term/define-cap _ble_term_clear $'\e[H\e[2J' clear

  # IL/DL
  ble/init:term/define-cap _ble_term_il $'\e[%dL' il 123
  ble/init:term/define-cap _ble_term_dl $'\e[%dM' dl 123
  _ble_term_il=${_ble_term_il//123/%d}
  _ble_term_dl=${_ble_term_dl//123/%d}

  # EL
  ble/init:term/define-cap _ble_term_el  $'\e[K'  el
  ble/init:term/define-cap _ble_term_el1 $'\e[1K' el1
  if [[ $_ble_term_el == $'\e[K' && $_ble_term_el1 == $'\e[1K' ]]; then
    _ble_term_el2=$'\e[2K'
  else
    _ble_term_el2=$_ble_term_el1$_ble_term_el
  fi
  ble/init:term/register-varname _ble_term_el2

  # ED
  ble/init:term/define-cap _ble_term_ed  $'\e[J' ed

  # ICH/DCH/ECH
  #   Note: 必ずしも対応しているか分からないので terminfo に載っている時のみ使う。
  ble/init:term/define-cap _ble_term_ich '' ich 123 # CSI @
  ble/init:term/define-cap _ble_term_dch '' dch 123 # CSI P
  ble/init:term/define-cap _ble_term_ech '' ech 123 # CSI X
  _ble_term_ich=${_ble_term_ich//123/%d}
  _ble_term_dch=${_ble_term_dch//123/%d}
  _ble_term_ech=${_ble_term_ech//123/%d}

  # DECSC/DECRC or SCOSC/SCORC
  ble/init:term/define-cap _ble_term_sc $'\e[s' sc
  ble/init:term/define-cap _ble_term_rc $'\e[u' rc

  # Cursors
  ble/init:term/define-cap _ble_term_Ss '' ss 123 # DECSCUSR
  _ble_term_Ss=${_ble_term_Ss//123/@1}
  ble/init:term/define-cap _ble_term_cvvis $'\e[?25h' cvvis
  ble/init:term/define-cap _ble_term_civis $'\e[?25l' civis
  # xterm の terminfo が点滅まで勝手に変更するので消す。
  [[ $_ble_term_cvvis == $'\e[?12;25h' || $_ble_term_cvvis == $'\e[?25;12h' ]] &&
    _ble_term_cvvis=$'\e[?25h'
  # 何故か screen の terminfo が壊れている(非対称になっている)ので対称化する。
  [[ $_ble_term_cvvis == $'\e[34l'* && $_ble_term_civis != *$'\e[34h'* ]] &&
    _ble_term_civis=$_ble_term_civis$'\e[34h'
  [[ $_ble_term_civis == $'\e[?25l'* && $_ble_term_cvvis != *$'\e[?25h'* ]] &&
    _ble_term_cvvis=$_ble_term_cvvis$'\e[?25h'

  # SGR clear
  ble/init:term/define-cap _ble_term_sgr0 $'\e[m' sgr0

  # SGR misc
  ble/init:term/define-cap _ble_term_bold  $'\e[1m' bold
  ble/init:term/define-cap _ble_term_blink $'\e[5m' blink
  ble/init:term/define-cap _ble_term_rev   $'\e[7m' rev
  ble/init:term/define-cap _ble_term_invis $'\e[8m' invis
  ble/init:term/define-sgr-param _ble_term_sgr_bold  "$_ble_term_bold"  1
  ble/init:term/define-sgr-param _ble_term_sgr_blink "$_ble_term_blink" 5
  ble/init:term/define-sgr-param _ble_term_sgr_rev   "$_ble_term_rev"   7
  ble/init:term/define-sgr-param _ble_term_sgr_invis "$_ble_term_invis" 8
  ble/init:term/define-cap _ble_term_sitm $'\e[3m'  sitm
  ble/init:term/define-cap _ble_term_ritm $'\e[23m' ritm
  ble/init:term/define-cap _ble_term_smul $'\e[4m'  smul
  ble/init:term/define-cap _ble_term_rmul $'\e[24m' rmul
  ble/init:term/define-cap _ble_term_smso $'\e[7m'  smso
  ble/init:term/define-cap _ble_term_rmso $'\e[27m' rmso
  ble/init:term/define-sgr-param _ble_term_sgr_sitm "$_ble_term_sitm" 3
  ble/init:term/define-sgr-param _ble_term_sgr_ritm "$_ble_term_ritm" 23
  ble/init:term/define-sgr-param _ble_term_sgr_smul "$_ble_term_smul" 4
  ble/init:term/define-sgr-param _ble_term_sgr_rmul "$_ble_term_rmul" 24
  ble/init:term/define-sgr-param _ble_term_sgr_smso "$_ble_term_smso" 7
  ble/init:term/define-sgr-param _ble_term_sgr_rmso "$_ble_term_rmso" 27

  # Note: rev と smso が同じ場合は、rev の reset に rmso を使用する。
  ble/init:term/register-varname _ble_term_sgr_rev_reset
  if [[ $_ble_term_sgr_smso && $_ble_term_sgr_smso == "$_ble_term_sgr_rev" ]]; then
    _ble_term_sgr_rev_reset=$_ble_term_sgr_rmso
  else
    _ble_term_sgr_rev_reset=
  fi

  # SGR colors
  ble/init:term/define-cap _ble_term_colors 256 colors
  local i
  _ble_term_setaf=()
  _ble_term_setab=()
  _ble_term_sgr_af=()
  _ble_term_sgr_ab=()
  for ((i=0;i<16;i++)); do
    local i1=$((i%8)) af= ab=

    # from terminfo
    if ((i<_ble_term_colors)); then
      local j1
      ((j1=(i1==3?6:
            (i1==6?3:
             (i1==1?4:
              (i1==4?1:i1))))))
      local j=$((i-i1+j1))

      ble/util/assign af 'ble/init:term/tput setaf "$i" 2>/dev/null'
      [[ $af ]] || ble/util/assign af 'ble/init:term/tput setf "$j" 2>/dev/null'

      ble/util/assign ab 'ble/init:term/tput setab "$i" 2>/dev/null'
      [[ $ab ]] || ble/util/assign ab 'ble/init:term/tput setb "$j" 2>/dev/null'
    fi

    # default value
    [[ $af ]] || af=$'\e[3'$i1'm'
    [[ $ab ]] || ab=$'\e[4'$i1'm'

    # register
    _ble_term_setaf[i]=$af
    _ble_term_setab[i]=$ab
    local ansi_sgr_af=3$i1 ansi_sgr_ab=4$i1
    ((i>=8)) && ansi_sgr_af=9$i1 ansi_sgr_ab=10$i1
    ble/init:term/define-sgr-param "_ble_term_sgr_af[i]" "$af" "$ansi_sgr_af"
    ble/init:term/define-sgr-param "_ble_term_sgr_ab[i]" "$ab" "$ansi_sgr_ab"
  done
  ble/init:term/register-varname "_ble_term_setaf"
  ble/init:term/register-varname "_ble_term_setab"
  ble/init:term/register-varname "_ble_term_sgr_af"
  ble/init:term/register-varname "_ble_term_sgr_ab"

  # save
  ble/util/declare-print-definitions "${varnames[@]}" >| "$_ble_base_cache/$TERM.term"
}

ble/bin/echo -n "ble/term.sh: updating tput cache for TERM=$TERM... " >&2
ble/init:term/initialize
ble/bin/echo $'\r'"ble/term.sh: updating tput cache for TERM=$TERM... done" >&2
