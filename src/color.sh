#!/bin/bash

# gflags

_ble_color_gflags_Bold=0x01
_ble_color_gflags_Italic=0x02
_ble_color_gflags_Underline=0x04
_ble_color_gflags_Revert=0x08
_ble_color_gflags_Invisible=0x10
_ble_color_gflags_Strike=0x20
_ble_color_gflags_Blink=0x40

_ble_color_gflags_DecorationMask=0x77
_ble_color_gflags_FgMask=0x00000000FFFFFF00
_ble_color_gflags_BgMask=0x00FFFFFF00000000
_ble_color_gflags_FgIndexed=0x0100000000000000
_ble_color_gflags_BgIndexed=0x0200000000000000

function ble/color/define-options {
  local ncolor=0
  if [[ $TERM == xterm* || $TERM == *-256color || $TERM == kterm* ]]; then
    ncolor=256
  elif [[ $TERM == *-88color ]]; then
    ncolor=88
  fi
  bleopt/declare -v term_true_colors semicolon
  bleopt/declare -v term_index_colors "$ncolor"
}
ble/color/define-options

function bleopt/check:term_true_colors {
  ble/color/g2sgr/.clear-cache
  return 0
}
function bleopt/check:term_index_colors {
  ble/color/g2sgr/.clear-cache
  return 0
}
function ble/color/initialize-term-colors {
  local fields
  ble/string#split fields \; "$_ble_term_DA2R"
  if [[ $bleopt_term_true_colors == auto ]]; then
    # truecolor support 自動判定 (暫定実装)
    local value=
    if [[ $TERM == *-24bit || $TERM == *-direct ]]; then
      value=colon
    elif [[ $TERM == *-24bits || $TERM == *-truecolor || $COLORTERM == *24bit* || $COLORTERM == *truecolor* ]]; then
      value=semicolon
    else
      case ${fields[0]} in
      (83) # screen (truecolor on にしている必要がある。判定方法は不明)
        if ((fields[1]>=49900)); then
          value=semicolon
        fi ;;
      (67)
        if ((fields[1]>=100000)); then
          : # cygwin terminal
        else
          # contra
          value=colon
        fi ;;
      esac
    fi
    [[ $value ]] &&
      bleopt term_true_colors="$value"
  fi
}
blehook DA2R+=ble/color/initialize-term-colors


function ble-color-show {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Update and reload ble.sh.' "$@"
    return "$?"
  fi

  local cols=16
  local bg bg0 bgN ret gflags=$((_ble_color_gflags_BgIndexed|_ble_color_gflags_FgIndexed))
  for ((bg0=0;bg0<256;bg0+=cols)); do
    ((bgN=bg0+cols,bgN<256||(bgN=256)))
    for ((bg=bg0;bg<bgN;bg++)); do
      ble/color/g2sgr $((gflags|bg<<32))
      printf '%s%03d ' "$ret" "$bg"
    done
    printf '%s\n' "$_ble_term_sgr0"
    for ((bg=bg0;bg<bgN;bg++)); do
      ble/color/g2sgr $((gflags|bg<<32|15<<8))
      printf '%s%03d ' "$ret" "$bg"
    done
    printf '%s\n' "$_ble_term_sgr0"
  done
}


## @fn ble/color/g2sgr g
## @fn ble/color/g2sgr-ansi g
##   @param[in] g
##   @var[out] ret
_ble_color_g2sgr=()
_ble_color_g2sgr_ansi=()
function ble/color/g2sgr/.impl {
  local g=$(($1))

  local sgr=0
  ((g&_ble_color_gflags_Bold))      && sgr="$sgr;${_ble_term_sgr_bold:-1}"
  ((g&_ble_color_gflags_Italic))    && sgr="$sgr;${_ble_term_sgr_sitm:-3}"
  ((g&_ble_color_gflags_Underline)) && sgr="$sgr;${_ble_term_sgr_smul:-4}"
  ((g&_ble_color_gflags_Blink))     && sgr="$sgr;${_ble_term_sgr_blink:-5}"
  ((g&_ble_color_gflags_Revert))    && sgr="$sgr;${_ble_term_sgr_rev:-7}"
  ((g&_ble_color_gflags_Invisible)) && sgr="$sgr;${_ble_term_sgr_invis:-8}"
  ((g&_ble_color_gflags_Strike))    && sgr="$sgr;${_ble_term_sgr_strike:-9}"
  if ((g&_ble_color_gflags_FgIndexed)); then
    local fg=$((g>>8&0xFF))
    ble/color/.color2sgrfg "$fg"
    sgr="$sgr;$ret"
  elif ((g&_ble_color_gflags_FgMask)); then
    local rgb=$((1<<24|g>>8&0xFFFFFF))
    ble/color/.color2sgrfg "$rgb"
    sgr="$sgr;$ret"
  fi
  if ((g&_ble_color_gflags_BgIndexed)); then
    local bg=$((g>>32&0xFF))
    ble/color/.color2sgrbg "$bg"
    sgr="$sgr;$ret"
  elif ((g&_ble_color_gflags_BgMask)); then
    local rgb=$((1<<24|g>>32&0xFFFFFF))
    ble/color/.color2sgrbg "$rgb"
    sgr="$sgr;$ret"
  fi

  ret=$'\e['$sgr'm'
  _ble_color_g2sgr[$1]=$ret
}
function ble/color/g2sgr/.clear-cache {
  _ble_color_g2sgr=()
}
function ble/color/g2sgr {
  ret=${_ble_color_g2sgr[$1]}
  [[ $ret ]] || ble/color/g2sgr/.impl "$1"
}
function ble/color/g2sgr-ansi/.impl {
  local g=$(($1))

  local sgr=0
  ((g&_ble_color_gflags_Bold))      && sgr="$sgr;1"
  ((g&_ble_color_gflags_Italic))    && sgr="$sgr;3"
  ((g&_ble_color_gflags_Underline)) && sgr="$sgr;4"
  ((g&_ble_color_gflags_Blink))     && sgr="$sgr;5"
  ((g&_ble_color_gflags_Revert))    && sgr="$sgr;7"
  ((g&_ble_color_gflags_Invisible)) && sgr="$sgr;8"
  ((g&_ble_color_gflags_Strike))    && sgr="$sgr;9"
  if ((g&_ble_color_gflags_FgIndexed)); then
    local fg=$((g>>8&0xFF))
    sgr="$sgr;38:5:$fg"
  elif ((g&_ble_color_gflags_FgMask)); then
    local rgb=$((1<<24|g>>8&0xFFFFFF))
    local R=$((rgb>>16&0xFF)) G=$((rgb>>8&0xFF)) B=$((rgb&0xFF))
    sgr="$sgr;38:2::$r:$g:$b"
  fi
  if ((g&_ble_color_gflags_BgIndexed)); then
    local bg=$((g>>32&0xFF))
    sgr="$sgr;48:5:$bg"
  elif ((g&_ble_color_gflags_BgMask)); then
    local rgb=$((1<<24|g>>32&0xFFFFFF))
    local R=$((rgb>>16&0xFF)) G=$((rgb>>8&0xFF)) B=$((rgb&0xFF))
    sgr="$sgr;48:2::$r:$g:$b"
  fi

  ret=$'\e['$sgr'm'
  _ble_color_g2sgr_ansi[$1]=$ret
}
function ble/color/g2sgr-ansi {
  ret=${_ble_color_g2sgr_ansi[$1]}
  [[ $ret ]] || ble/color/g2sgr-ansi/.impl "$1"
}

function ble/color/g#setfg-clear {
  (($1&=~(_ble_color_gflags_FgIndexed|_ble_color_gflags_FgMask)))
}
function ble/color/g#setbg-clear {
  (($1&=~(_ble_color_gflags_BgIndexed|_ble_color_gflags_BgMask)))
}
function ble/color/g#setfg-index {
  local __color=$2
  (($1=$1&~_ble_color_gflags_FgMask|_ble_color_gflags_FgIndexed|(__color&0xFF)<<8)) # index color
}
function ble/color/g#setbg-index {
  local __color=$2
  (($1=$1&~_ble_color_gflags_BgMask|_ble_color_gflags_BgIndexed|(__color&0xFF)<<32)) # index color
}
function ble/color/g#setfg-rgb {
  local __R=$2 __G=$3 __B=$4
  ((__R&=0xFF,__G&=0xFF,__B&=0xFF))
  if ((__R==0&&__G==0&&__B==0)); then
    ble/color/g#setfg-index "$1" 16
  else
    (($1=$1&~(_ble_color_gflags_FgIndexed|_ble_color_gflags_FgMask)|__R<<24|__G<<16|__B<<8)) # true color
  fi
}
function ble/color/g#setbg-rgb {
  local __R=$2 __G=$3 __B=$4
  ((__R&=0xFF,__G&=0xFF,__B&=0xFF))
  if ((__R==0&&__G==0&&__B==0)); then
    ble/color/g#setbg-index "$1" 16
  else
    (($1=$1&~(_ble_color_gflags_BgIndexed|_ble_color_gflags_BgMask)|__R<<48|__G<<40|__B<<32)) # true color
  fi
}
function ble/color/g#setfg-cmyk {
  local __C=$2 __M=$3 __Y=$4 __K=${5:-0}
  ((__K=~__K&0xFF,
    __C=(~__C&0xFF)*__K/255,
    __M=(~__M&0xFF)*__K/255,
    __Y=(~__Y&0xFF)*__K/255))
  ble/color/g#setfg-rgb "$__C" "$__M" "$__Y"
}
function ble/color/g#setbg-cmyk {
  local __C=$2 __M=$3 __Y=$4 __K=${5:-0}
  ((__K=~__K&0xFF,
    __C=(~__C&0xFF)*__K/255,
    __M=(~__M&0xFF)*__K/255,
    __Y=(~__Y&0xFF)*__K/255))
  ble/color/g#setbg-rgb "$1" "$__C" "$__M" "$__Y"
}
function ble/color/g#setfg {
  local __color=$2
  if ((__color<0)); then
    ble/color/g#setfg-clear "$1"
  elif ((__color>=0x1000000)); then
    if ((__color==0x1000000)); then
      ble/color/g#setfg-index "$1" 16
    else
      (($1=$1&~(_ble_color_gflags_FgIndexed|_ble_color_gflags_FgMask)|(__color&0xFFFFFF)<<8)) # true color
    fi
  else
    ble/color/g#setfg-index "$1" "$__color"
  fi
}
function ble/color/g#setbg {
  local __color=$2
  if ((__color<0)); then
    ble/color/g#setbg-clear "$1"
  elif ((__color>=0x1000000)); then
    if ((__color==0x1000000)); then
      ble/color/g#setbg-index "$1" 16
    else
      (($1=$1&~(_ble_color_gflags_BgIndexed|_ble_color_gflags_BgMask)|(__color&0xFFFFFF)<<32)) # true color
    fi
  else
    ble/color/g#setbg-index "$1" "$__color"
  fi
}
## @fn ble/color/g#append g g2
##   g に描画属性 g2 を上書きします。
##   @param[in,out] g
##   @param[in] g2
function ble/color/g#append {
  local __g2=$2
  ((__g2&(_ble_color_gflags_FgMask|_ble_color_gflags_FgIndexed))) &&
    (($1&=~(_ble_color_gflags_FgMask|_ble_color_gflags_FgIndexed)))
  ((__g2&(_ble_color_gflags_BgMask|_ble_color_gflags_BgIndexed))) &&
    (($1&=~(_ble_color_gflags_BgMask|_ble_color_gflags_BgIndexed)))
  (($1|=__g2))
}
function ble/color/g#compose {
  (($1=($2)))
  local __g2
  for __g2 in "${@:3}"; do
    ble/color/g#append "$1" "$__g2"
  done
}
function ble/color/g.setfg { ble/color/g#setfg g "$@"; }
function ble/color/g.setbg { ble/color/g#setbg g "$@"; }
function ble/color/g.setfg-clear { ble/color/g#setfg-clear g "$@"; }
function ble/color/g.setbg-clear { ble/color/g#setbg-clear g "$@"; }
function ble/color/g.setfg-index { ble/color/g#setfg-index g "$@"; }
function ble/color/g.setbg-index { ble/color/g#setbg-index g "$@"; }
function ble/color/g.setfg-rgb { ble/color/g#setfg-rgb g "$@"; }
function ble/color/g.setbg-rgb { ble/color/g#setbg-rgb g "$@"; }
function ble/color/g.setfg-cmyk { ble/color/g#setfg-cmyk g "$@"; }
function ble/color/g.setbg-cmyk { ble/color/g#setbg-cmyk g "$@"; }
function ble/color/g.append { ble/color/g#append g "$@"; }
function ble/color/g.compose { ble/color/g#compose g "$@"; }

function ble/color/g#getfg {
  local g=$1
  if ((g&_ble_color_gflags_FgIndexed)); then
    ((ret=g>>8&0xFF))
  elif ((g&_ble_color_gflags_FgMask)); then
    ((ret=0x1000000|(g>>8&0xFFFFFF)))
  else
    ((ret=-1))
  fi
}
function ble/color/g#getbg {
  local g=$1
  if ((g&_ble_color_gflags_BgIndexed)); then
    ((ret=g>>32&0xFF))
  elif ((g&_ble_color_gflags_BgMask)); then
    ((ret=0x1000000|(g>>32&0xFFFFFF)))
  else
    ((ret=-1))
  fi
}
function ble/color/g#compute-fg {
  local g=$1
  if ((g&_ble_color_gflags_Invisible)); then
    ble/color/g#compute-bg "$g"
  elif ((g&_ble_color_gflags_Revert)); then
    ble/color/g#getbg "$g"
  else
    ble/color/g#getfg "$g"
  fi
}
function ble/color/g#compute-bg {
  local g=$1
  if ((g&_ble_color_gflags_Revert)); then
    ble/color/g#getfg "$g"
  else
    ble/color/g#getbg "$g"
  fi
}

## @fn ble/color/gspec2g gspec
##   @param[in] gspec
##   @var[out] ret
function ble/color/gspec2g {
  local g=0 entry
  for entry in ${1//,/ }; do
    case "$entry" in
    (bold)      ((g|=_ble_color_gflags_Bold)) ;;
    (underline) ((g|=_ble_color_gflags_Underline)) ;;
    (blink)     ((g|=_ble_color_gflags_Blink)) ;;
    (invis)     ((g|=_ble_color_gflags_Invisible)) ;;
    (reverse)   ((g|=_ble_color_gflags_Revert)) ;;
    (strike)    ((g|=_ble_color_gflags_Strike)) ;;
    (italic)    ((g|=_ble_color_gflags_Italic)) ;;
    (standout)  ((g|=_ble_color_gflags_Revert|_ble_color_gflags_Bold)) ;;
    (fg=*)
      ble/color/.name2color "${entry:3}"
      ble/color/g.setfg "$ret" ;;
    (bg=*)
      ble/color/.name2color "${entry:3}"
      ble/color/g.setbg "$ret" ;;
    (none)
      g=0 ;;
    esac
  done
  ret=$g
}
## @fn ble/color/g2gspec g
##   @var[out] ret
function ble/color/g2gspec {
  local g=$1 gspec=
  if ((g&_ble_color_gflags_FgIndexed)); then
    local fg=$((g>>8&0xFF))
    ble/color/.color2name "$fg"
    gspec=$gspec,fg=$ret
  elif ((g&_ble_color_gflags_FgMask)); then
    local rgb=$((1<<24|g>>8&0xFFFFFF))
    ble/color/.color2name "$rgb"
    gspec=$gspec,fg=$ret
  fi
  if ((g&_ble_color_gflags_BgIndexed)); then
    local bg=$((g>>32&0xFF))
    ble/color/.color2name "$bg"
    gspec=$gspec,bg=$ret
  elif ((g&_ble_color_gflags_BgMask)); then
    local rgb=$((1<<24|g>>32&0xFFFFFF))
    ble/color/.color2name "$rgb"
    gspec=$gspec,bg=$ret
  fi
  ((g&_ble_color_gflags_Bold))      && gspec=$gspec,bold
  ((g&_ble_color_gflags_Underline)) && gspec=$gspec,underline
  ((g&_ble_color_gflags_Blink))     && gspec=$gspec,blink
  ((g&_ble_color_gflags_Invisible)) && gspec=$gspec,invis
  ((g&_ble_color_gflags_Revert))    && gspec=$gspec,reverse
  ((g&_ble_color_gflags_Strike))    && gspec=$gspec,strike
  ((g&_ble_color_gflags_Italic))    && gspec=$gspec,italic
  gspec=${gspec#,}
  ret=${gspec:-none}
}

## @fn ble/color/gspec2sgr gspec
##   @param[in] gspec
##   @var[out] ret
function ble/color/gspec2sgr {
  local sgr=0 entry

  for entry in ${1//,/ }; do
    case "$entry" in
    (bold)      sgr="$sgr;${_ble_term_sgr_bold:-1}" ;;
    (underline) sgr="$sgr;${_ble_term_sgr_smul:-4}" ;;
    (blink)     sgr="$sgr;${_ble_term_sgr_blink:-5}" ;;
    (invis)     sgr="$sgr;${_ble_term_sgr_invis:-8}" ;;
    (reverse)   sgr="$sgr;${_ble_term_sgr_rev:-7}" ;;
    (strike)    sgr="$sgr;${_ble_term_sgr_strike:-9}" ;;
    (italic)    sgr="$sgr;${_ble_term_sgr_sitm:-3}" ;;
    (standout)  sgr="$sgr;${_ble_term_sgr_bold:-1};${_ble_term_sgr_rev:-7}" ;;
    (fg=*)
      ble/color/.name2color "${entry:3}"
      ble/color/.color2sgrfg "$ret"
      sgr="$sgr;$ret" ;;
    (bg=*)
      ble/color/.name2color "${entry:3}"
      ble/color/.color2sgrbg "$ret"
      sgr="$sgr;$ret" ;;
    (none)
      sgr=0 ;;
    esac
  done

  ret="[${sgr}m"
}

function ble/color/.name2color/.clamp {
  local text=$1 max=$2
  if [[ $text == *% ]]; then
    ((ret=10#${text%'%'}*max/100))
  else
    ((ret=10#$text))
  fi
  ((ret>max)) && ret=max
}
function ble/color/.name2color/.wrap {
  local text=$1 max=$2
  if [[ $text == *% ]]; then
    ((ret=10#${text%'%'}*max/100))
  else
    ((ret=10#$text))
  fi
  ((ret%=max))
}
function ble/color/.hxx2color {
  local H=$1 Min=$2 Range=$3 Unit=$4
  local h1 h2 x=$Min y=$Min z=$Min
  ((h1=H%120,h2=120-h1,
    x+=Range*(h2<60?h2:60)/60,
    y+=Range*(h1<60?h1:60)/60))
  ((x=x*255/Unit,
    y=y*255/Unit,
    z=z*255/Unit))
  case $((H/120)) in
  (0) local R=$x G=$y B=$z ;;
  (1) local R=$z G=$x B=$y ;;
  (2) local R=$y G=$z B=$x ;;
  esac
  ((ret=1<<24|R<<16|G<<8|B))
}
function ble/color/.hsl2color {
  local H=$1 S=$2 L=$3 Unit=$4
  local Range=$((2*(L<=Unit/2?L:Unit-L)*S/Unit))
  local Min=$((L-Range/2))
  ble/color/.hxx2color "$H" "$Min" "$Range" "$Unit"
}
function ble/color/.hsb2color {
  local H=$1 S=$2 B=$3 Unit=$4
  local Range=$((B*S/Unit))
  local Min=$((B-Range))
  ble/color/.hxx2color "$H" "$Min" "$Range" "$Unit"
}
## @fn ble/color/.name2color colorName
##   @var[out] ret
function ble/color/.name2color {
  local colorName=$1
  if [[ ! ${colorName//[0-9]} ]]; then
    ((ret=10#$colorName&255))
  elif [[ $colorName == '#'* ]]; then
    if local rex='^#[0-9a-fA-F]{3}$'; [[ $colorName =~ $rex ]]; then
      let "ret=1<<24|16#${colorName:1:1}*0x11<<16|16#${colorName:2:1}*0x11<<8|16#${colorName:3:1}*0x11"
    elif rex='^#[0-9a-fA-F]{6}$'; [[ $colorName =~ $rex ]]; then
      let "ret=1<<24|16#${colorName:1:2}<<16|16#${colorName:3:2}<<8|16#${colorName:5:2}"
    else
      ret=-1
    fi
  elif [[ $colorName == *:* ]]; then
    if local rex='^rgb:([0-9]+%?)/([0-9]+%?)/([0-9]+%?)$'; [[ $colorName =~ $rex ]]; then
      ble/color/.name2color/.clamp "${BASH_REMATCH[1]}" 255; local R=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[2]}" 255; local G=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[3]}" 255; local B=$ret
      ((ret=1<<24|R<<16|G<<8|B))
    elif
      local rex1='^cmy:([0-9]+%?)/([0-9]+%?)/([0-9]+%?)$'
      local rex2='^cmyk:([0-9]+%?)/([0-9]+%?)/([0-9]+%?)/([0-9]+%?)$'
      [[ $colorName =~ $rex1 || $colorName =~ $rex2 ]]
    then
      ble/color/.name2color/.clamp "${BASH_REMATCH[1]}" 255; local C=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[2]}" 255; local M=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[3]}" 255; local Y=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[4]:-0}" 255; local K=$ret
      local K=$((~K&0xFF))
      local R=$(((~C&0xFF)*K/255))
      local G=$(((~M&0xFF)*K/255))
      local B=$(((~Y&0xFF)*K/255))
      ((ret=1<<24|R<<16|G<<8|B))
    elif rex='^hs[lvb]:([0-9]+)/([0-9]+%)/([0-9]+%)$'; [[ $colorName =~ $rex ]]; then
      ble/color/.name2color/.wrap  "${BASH_REMATCH[1]}" 360; local H=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[2]}" 1000; local S=$ret
      ble/color/.name2color/.clamp "${BASH_REMATCH[3]}" 1000; local X=$ret
      if [[ $colorName == hsl:* ]]; then
        ble/color/.hsl2color "$H" "$S" "$X" 1000
      else
        ble/color/.hsb2color "$H" "$S" "$X" 1000
      fi
    else
      ret=-1
    fi
  else
    case "$colorName" in
    (black)   ret=0 ;;
    (brown)   ret=1 ;;
    (green)   ret=2 ;;
    (olive)   ret=3 ;;
    (navy)    ret=4 ;;
    (purple)  ret=5 ;;
    (teal)    ret=6 ;;
    (silver)  ret=7 ;;

    (gray)    ret=8 ;;
    (red)     ret=9 ;;
    (lime)    ret=10 ;;
    (yellow)  ret=11 ;;
    (blue)    ret=12 ;;
    (magenta) ret=13 ;;
    (cyan)    ret=14 ;;
    (white)   ret=15 ;;

    (orange)  ret=202 ;;
    (transparent|default) ret=-1 ;;
    (*)       ret=-1 ;;
    esac
  fi
}
function ble/color/.color2name {
  if (($1>=0x1000000)); then
    ble/util/sprintf ret '#%06x' $(($1&0xFFFFFF))
    return 0
  fi

  ((ret=(10#$1&255)))
  case $ret in
  (0)  ret=black   ;;
  (1)  ret=brown   ;;
  (2)  ret=green   ;;
  (3)  ret=olive   ;;
  (4)  ret=navy    ;;
  (5)  ret=purple  ;;
  (6)  ret=teal    ;;
  (7)  ret=silver  ;;
  (8)  ret=gray    ;;
  (9)  ret=red     ;;
  (10) ret=lime    ;;
  (11) ret=yellow  ;;
  (12) ret=blue    ;;
  (13) ret=magenta ;;
  (14) ret=cyan    ;;
  (15) ret=white   ;;
  (202) ret=orange ;;
  esac
}

## @fn ble/color/convert-color88-to-color256 color
##   @param[in] color
##   @var[out] ret
function ble/color/convert-color88-to-color256 {
  local color=$1
  if ((color>=16)); then
    if ((color>=80)); then
      local L=$((((color-80+1)*25+4)/9))
      ((color=L==0?16:(L==25?231:232+(L-1))))
    else
      ((color-=16))
      local R=$((color/16)) G=$((color/4%4)) B=$((color%4))
      ((R=(R*5+1)/3,G=(G*5+1)/3,B=(B*5+1)/3,
        color=16+R*36+G*6+B))
    fi
  fi
  ret=$color
}
## @fn ble/color/convert-color256-to-color88 color
##   @param[in] color
##   @var[out] ret
function ble/color/convert-color256-to-color88 {
  local color=$1
  if ((color>=16)); then
    if ((color>=232)); then
      local L=$((((color-232+1)*9+12)/25))
      ((color=L==0?16:(L==9?79:80+(L-1))))
    else
      ((color-=16))
      local R=$((color/36)) G=$((color/6%6)) B=$((color%6))
      ((R=(R*3+2)/5,G=(G*3+2)/5,B=(B*3+2)/5,
        color=16+R*16+G*4+B))
    fi
  fi
  ret=$color
}
## @fn ble/color/convert-rgb24-to-color256 R G B
##   @param[in] R G B
##     0..255 の階調値
##   @var[out] ret
function ble/color/convert-rgb24-to-color256 {
  local R=$1 G=$2 B=$3
  if ((R==G&&G==B)); then
    # xterm 24 grayscale: 10k+8 (0..238)
    if ((R<=3)); then
      # 6x6x6 cube (0,0,0)
      ret=16
    elif ((R>=247)); then
      # 6x6x6 cube (5,5,5)
      ret=231
    elif ((R>=92&&(R-92)%40<5)); then
      # 6x6x6 cube (1,1,1)-(4,4,4)
      ((ret=59+43*(R-92)/40))
    else
      local level=$(((R-3)/10))
      ((ret=232+(level<=23?level:23)))
    fi
  else
    # xterm 6x6x6 cube: k?55+40k:0
    ((R=R<=47?0:(R<=95?1:(R-35)/40)))
    ((G=G<=47?0:(G<=95?1:(G-35)/40)))
    ((B=B<=47?0:(B<=95?1:(B-35)/40)))
    ((ret=16+36*R+6*G+B))
  fi
}
## @fn ble/color/convert-rgb24-to-color88 R G B
##   @param[in] R G B
##     0..255 の階調値
##   @var[out] ret
function ble/color/convert-rgb24-to-color88 {
  local R=$1 G=$2 B=$3
  if ((R==G&&G==B)); then
    # xterm 8 grayscale: 46+25k = 46,71,96,121,146,171,196,221
    if ((R<=22)); then
      ret=16 # 4x4x4 cube (0,0,0)=0:0:0
    elif ((R>=239)); then
      ret=79 # 4x4x4 cube (3,3,3)=255:255:255
    elif ((131<=R&&R<=142)); then
      ret=37 # 4x4x4 cube (1,1,1)=139:139:139
    elif ((197<=R&&R<=208)); then
      ret=58 # 4x4x4 cube (2,2,2)=197:197:197
    else
      local level=$(((R-34)/25))
      ((ret=80+(level<=7?level:7)))
    fi
  else
    # xterm 4x4x4 cube: (k?81+58k:0) = 0,139,197,255
    ((R=R<=69?0:(R<=168?1:(R-52)/58)))
    ((G=G<=69?0:(G<=168?1:(G-52)/58)))
    ((B=B<=69?0:(B<=168?1:(B-52)/58)))
    ((ret=16+16*R+4*G+B))
  fi
}

## @fn ble/color/.color2sgrfg color
## @fn ble/color/.color2sgrbg color
##   @param[in] color
##     0-255 の値は index color を表します。
##     1XXXXXX の値は 24bit color を表します。
##   @var[out] ret
function ble/color/.color2sgr-impl {
  local ccode=$1 prefix=$2 # 3 for fg, 4 for bg
  if ((ccode<0)); then
    ret=${prefix}9
  elif ((ccode<16&&ccode<_ble_term_colors)); then
    if ((prefix==4)); then
      ret=${_ble_term_sgr_ab[ccode]}
    else
      ret=${_ble_term_sgr_af[ccode]}
    fi
  elif ((ccode<256)); then
    if ((_ble_term_colors>=256||bleopt_term_index_colors==256)); then
      ret="${prefix}8;5;$ccode"
    elif ((_ble_term_colors>=88||bleopt_term_index_colors==88)); then
      ble/color/convert-color256-to-color88 "$ccode"
      ret="${prefix}8;5;$ret"
    elif ((ccode<_ble_term_colors||ccode<bleopt_term_index_colors)); then
      ret="${prefix}8;5;$ccode"
    elif ((_ble_term_colors>=16||_ble_term_colors==8)); then
      if ((ccode>=16)); then
        if ((ccode>=232)); then
          local L=$((((ccode-232+1)*3+12)/25))
          ((ccode=L==0?0:(L==1?8:(L==2?7:15))))
        else
          ((ccode-=16))
          local R=$((ccode/36)) G=$((ccode/6%6)) B=$((ccode%6))
          if ((R==G&&G==B)); then
            local L=$(((R*3+2)/5))
            ((ccode=L==0?0:(L==1?8:(L==2?7:15))))
          else
            local min max
            ((R<G?(min=R,max=G):(min=G,max=R),
              B<min?(min=B):(B>max&&(max=B))))
            local Range=$((max-min))
            ((R=(R-min+Range/2)/Range,
              G=(G-min+Range/2)/Range,
              B=(B-min+Range/2)/Range,
              ccode=R+G*2+B*4+(min+max>=5?8:0)))
          fi
        fi
      fi
      ((_ble_term_colors==8&&ccode>=8&&(ccode-=8)))

      if ((prefix==4)); then
        ret=${_ble_term_sgr_ab[ccode]}
      else
        ret=${_ble_term_sgr_af[ccode]}
      fi
    else
      ret=${prefix}9
    fi
  elif ((0x1000000<=ccode&&ccode<0x2000000)); then
    # 24bit True Colors
    local R=$((ccode>>16&0xFF)) G=$((ccode>>8&0xFF)) B=$((ccode&0xFF))
    if [[ $bleopt_term_true_colors == semicolon ]]; then
      ret="${prefix}8;2;$R;$G;$B"
    elif [[ $bleopt_term_true_colors == colon ]]; then
      ret="${prefix}8:2:$R:$G:$B"
    elif ((_ble_term_colors>=256||bleopt_term_index_colors==256)); then
      ble/color/convert-rgb24-to-color256 "$R" "$G" "$B"
      ret="${prefix}8;5;$ret"
    elif ((_ble_term_colors>=88||bleopt_term_index_colors==88)); then
      ble/color/convert-rgb24-to-color88 "$R" "$G" "$B"
      ret="${prefix}8;5;$ret"
    else
      ble/color/convert-rgb24-to-color256 "$R" "$G" "$B"
      ble/color/.color2sgr-impl "$ret" "$prefix"
    fi
  else
    ret=${prefix}9
  fi
}

## @fn ble/color/.color2sgrfg color_code
##   @var[out] ret
function ble/color/.color2sgrfg {
  ble/color/.color2sgr-impl "$1" 3
}
## @fn ble/color/.color2sgrbg color_code
##   @var[out] ret
function ble/color/.color2sgrbg {
  ble/color/.color2sgr-impl "$1" 4
}

#------------------------------------------------------------------------------

## @fn ble/color/read-sgrspec/.arg-next
##   @var[in    ] fields
##   @var[in,out] j
##   @var[   out] arg
function ble/color/read-sgrspec/.arg-next {
  local _var=arg _ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  if ((j<${#fields[*]})); then
    ((_ret=10#${fields[j++]}))
  else
    ((i++))
    ((_ret=10#${specs[i]%%:*}))
  fi

  (($_var=_ret))
}

## @fn ble-color/read-sgrspec sgrspec opts
##   @param[in] sgrspec
##   @var[in,out] g
function ble/color/read-sgrspec {
  local specs i iN
  ble/string#split specs \; "$1"
  for ((i=0,iN=${#specs[@]};i<iN;i++)); do
    local spec=${specs[i]} fields
    ble/string#split fields : "$spec"
    local arg=$((10#${fields[0]}))
    if ((arg==0)); then
      g=0
      continue
    elif [[ :$opts: != *:ansi:* ]]; then
      [[ ${_ble_term_sgr_term2ansi[arg]} ]] &&
        arg=${_ble_term_sgr_term2ansi[arg]}
    fi

    if ((30<=arg&&arg<50)); then
      # colors
      if ((30<=arg&&arg<38)); then
        local color=$((arg-30))
        ble/color/g.setfg-index "$color"
      elif ((40<=arg&&arg<48)); then
        local color=$((arg-40))
        ble/color/g.setbg-index "$color"
      elif ((arg==38)); then
        local j=1 color cspace
        ble/color/read-sgrspec/.arg-next -v cspace
        if ((cspace==5)); then
          ble/color/read-sgrspec/.arg-next -v color
          if [[ :$opts: != *:ansi:* ]] && ((bleopt_term_index_colors==88)); then
            local ret; ble/color/convert-color88-to-color256 "$color"; color=$ret
          fi
          ble/color/g.setfg-index "$color"
        elif ((cspace==2)); then
          local S R G B
          ((${#fields[@]}>5)) &&
            ble/color/read-sgrspec/.arg-next -v S
          ble/color/read-sgrspec/.arg-next -v R
          ble/color/read-sgrspec/.arg-next -v G
          ble/color/read-sgrspec/.arg-next -v B
          ble/color/g.setfg-rgb "$R" "$G" "$B"
        elif ((cspace==3||cspace==4)); then
          local S C M Y K=0
          ((${#fields[@]}>2+cspace)) &&
            ble/color/read-sgrspec/.arg-next -v S
          ble/color/read-sgrspec/.arg-next -v C
          ble/color/read-sgrspec/.arg-next -v M
          ble/color/read-sgrspec/.arg-next -v Y
          ((cspace==4)) &&
            ble/color/read-sgrspec/.arg-next -v K
          ble/color/g.setfg-cmyk "$C" "$M" "$Y" "$K"
        else
          ble/color/g.setfg-clear
        fi
      elif ((arg==48)); then
        local j=1 color cspace
        ble/color/read-sgrspec/.arg-next -v cspace
        if ((cspace==5)); then
          ble/color/read-sgrspec/.arg-next -v color
          if [[ :$opts: != *:ansi:* ]] && ((bleopt_term_index_colors==88)); then
            local ret; ble/color/convert-color88-to-color256 "$color"; color=$ret
          fi
          ble/color/g.setbg-index "$color"
        elif ((cspace==2)); then
          local S R G B
          ((${#fields[@]}>5)) &&
            ble/color/read-sgrspec/.arg-next -v S
          ble/color/read-sgrspec/.arg-next -v R
          ble/color/read-sgrspec/.arg-next -v G
          ble/color/read-sgrspec/.arg-next -v B
          ble/color/g.setbg-rgb "$R" "$G" "$B"
        elif ((cspace==3||cspace==4)); then
          local S C M Y K=0
          ((${#fields[@]}>2+cspace)) &&
            ble/color/read-sgrspec/.arg-next -v S
          ble/color/read-sgrspec/.arg-next -v C
          ble/color/read-sgrspec/.arg-next -v M
          ble/color/read-sgrspec/.arg-next -v Y
          ((cspace==4)) &&
            ble/color/read-sgrspec/.arg-next -v K
          ble/color/g.setbg-cmyk "$C" "$M" "$Y" "$K"
        else
          ble/color/g.setbg-clear
        fi
      elif ((arg==39)); then
        ble/color/g.setfg-clear
      elif ((arg==49)); then
        ble/color/g.setbg-clear
      fi
    elif ((90<=arg&&arg<98)); then
      local color=$((arg-90+8))
      ble/color/g.setfg-index "$color"
    elif ((100<=arg&&arg<108)); then
      local color=$((arg-100+8))
      ble/color/g.setbg-index "$color"
    elif ((arg==1)); then
      ((g|=_ble_color_gflags_Bold))
    elif ((arg==22)); then
      ((g&=~_ble_color_gflags_Bold))
    elif ((arg==4)); then
      ((g|=_ble_color_gflags_Underline))
    elif ((arg==24)); then
      ((g&=~_ble_color_gflags_Underline))
    elif ((arg==7)); then
      ((g|=_ble_color_gflags_Revert))
    elif ((arg==27)); then
      ((g&=~_ble_color_gflags_Revert))
    elif ((arg==3)); then
      ((g|=_ble_color_gflags_Italic))
    elif ((arg==23)); then
      ((g&=~_ble_color_gflags_Italic))
    elif ((arg==5)); then
      ((g|=_ble_color_gflags_Blink))
    elif ((arg==25)); then
      ((g&=~_ble_color_gflags_Blink))
    elif ((arg==8)); then
      ((g|=_ble_color_gflags_Invisible))
    elif ((arg==28)); then
      ((g&=~_ble_color_gflags_Invisible))
    elif ((arg==9)); then
      ((g|=_ble_color_gflags_Strike))
    elif ((arg==29)); then
      ((g&=~_ble_color_gflags_Strike))
    fi
  done
}

## @fn ble/color/sgrspec2g str
##   SGRに対する引数から描画属性を構築します。
##   @var[out] ret
function ble/color/sgrspec2g {
  local g=0
  ble/color/read-sgrspec "$1"
  ret=$g
}

## @fn ble/color/ansi2g str
##   ANSI制御シーケンスから描画属性を構築します。
##   Note: canvas.sh を読み込んで以降でないと使えません。
##   @var[out] ret
function ble/color/ansi2g {
  local x=0 y=0 g=0
  ble/function#try ble/canvas/trace "$1" # -> ret
  ret=$g
}

#------------------------------------------------------------------------------
# _ble_faces

# 遅延初期化登録
# @hook color_defface_load (defined in src/def.sh)
# @hook color_setface_load (defined in src/def.sh)

# 遅延初期化
if [[ ! ${_ble_faces_count-} ]]; then # reload #D0875
  _ble_faces_count=0
  _ble_faces=()
fi

## @fn ble/color/setface/.check-argument
##   @var[out] ext
function ble/color/setface/.check-argument {
  local rex='^[a-zA-Z0-9_]+$'
  [[ $# == 2 && $1 =~ $rex && $2 ]] && return 0

  local flags=a
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--help) flags=H$flags ;;
    (--color|--color=always) flags=c${flags//[ac]} ;;
    (--color=auto) flags=a${flags//[ac]} ;;
    (--color=never) flags=${flags//[ac]} ;;
    (-*)
      ble/util/print "${FUNCNAME[1]}: unrecognized option '$arg'." >&2
      flags=E$flags ;;
    (*)
      ble/util/print "${FUNCNAME[1]}: unrecognized argument '$arg'." >&2
      flags=E$flags ;;
    esac
  done

  if [[ $flags == *E* ]]; then
    ext=2; return 1
  elif [[ $flags == *H* ]]; then
    ble/util/print-lines \
      "usage: $name FACE_NAME [TYPE:]SPEC" \
      '    Set face.' \
      '' \
      '  TYPE      Specifies the format of SPEC. The following values are available.' \
      '    gspec   Comma separated graphic attribute list' \
      '    g       Integer value' \
      '    ref     Face name or id (reference)' \
      '    copy    Face name or id (copy value)' \
      '    sgrspec Parameters to the control function SGR' \
      '    ansi    ANSI Sequences' >&2
    ext=0; return 1
  fi

  local opts=
  [[ $flags == *c* || $flags == *a* && -t 1 ]] && opts=$opts:color
  ble/color/list-faces "$opts"; ext=$?; return 1
}
function ble-color-defface {
  local ext; ble/color/setface/.check-argument "$@" || return "$ext"
  ble/color/defface "$@"
}
function ble-color-setface {
  local ext; ble/color/setface/.check-argument "$@" || return "$ext"
  ble/color/setface "$@"
}

# 遅延関数 (後で上書き)
function ble/color/defface   { local q=\' Q="'\''"; blehook color_defface_load+="ble/color/defface '${1//$q/$Q}' '${2//$q/$Q}'"; }
function ble/color/setface   { local q=\' Q="'\''"; blehook color_setface_load+="ble/color/setface '${1//$q/$Q}' '${2//$q/$Q}'"; }
function ble/color/face2g    { ble/color/initialize-faces && ble/color/face2g    "$@"; }
function ble/color/face2sgr  { ble/color/initialize-faces && ble/color/face2sgr  "$@"; }
function ble/color/iface2g   { ble/color/initialize-faces && ble/color/iface2g   "$@"; }
function ble/color/iface2sgr { ble/color/initialize-faces && ble/color/iface2sgr "$@"; }

function ble/color/face2sgr-ansi { ble/color/initialize-faces && ble/color/face2sgr  "$@"; }

# 遅延初期化子
_ble_color_faces_initialized=
function ble/color/initialize-faces {
  local _ble_color_faces_initializing=1
  local -a _ble_color_faces_errors=()

  ## @fn ble/color/face2g face
  ##   @var[out] ret
  function ble/color/face2g {
    ((ret=_ble_faces[_ble_faces__$1]))
  }
  ## @fn ble/color/face2sgr face
  ##   @var[out] ret
  function ble/color/face2sgr { ble/color/g2sgr $((_ble_faces[_ble_faces__$1])); }
  function ble/color/face2sgr-ansi { ble/color/g2sgr-ansi $((_ble_faces[_ble_faces__$1])); }
  ## @fn ble/color/iface2g iface
  ##   @var[out] ret
  function ble/color/iface2g {
    ((ret=_ble_faces[$1]))
  }
  ## @fn ble/color/iface2sgr iface
  ##   @var[out] ret
  function ble/color/iface2sgr {
    ble/color/g2sgr $((_ble_faces[$1]))
  }

  ## @fn ble/color/setface/.spec2g spec
  ##   @var[out] ret
  function ble/color/setface/.spec2g {
    local spec=$1 value=${spec#*:}
    case $spec in
    (gspec:*)   ble/color/gspec2g "$value" ;;
    (g:*)       ret=$(($value)) ;;
    (ref:*)
      if [[ ! ${value//[0-9]} ]]; then
        ret=_ble_faces[$((value))]
      else
        ret=_ble_faces[_ble_faces__$value]
      fi ;;
    (copy:*|face:*|iface:*)
      # `face:*' and `iface:*' are obsoleted forms.
      [[ $spec == copy:* ]] ||
        ble/util/print "ble-face: \"${spec%%:*}:*\" is obsoleted. Use \"copy:*\" instead." >&2
      if [[ ! ${value//[0-9]} ]]; then
        ble/color/iface2g "$value"
      else
        ble/color/face2g "$value"
      fi ;;
    (sgrspec:*) ble/color/sgrspec2g "$value" ;;
    (ansi:*)    ble/color/ansi2g "$value" ;;
    (*)         ble/color/gspec2g "$spec" ;;
    esac
  }

  function ble/color/defface {
    local name=_ble_faces__$1 spec=$2 ret
    (($name)) && return 0
    (($name=++_ble_faces_count))
    ble/color/setface/.spec2g "$spec"
    _ble_faces[$name]=$ret
    _ble_faces_def[$name]=$ret
  }
  function ble/color/setface {
    local name=_ble_faces__$1 spec=$2 ret
    if [[ ${!name} ]]; then
      ble/color/setface/.spec2g "$spec"; _ble_faces[$name]=$ret
    else
      local message="ble.sh: the specified face \`$1' is not defined."
      if [[ $_ble_color_faces_initializing ]]; then
        ble/array#push _ble_color_faces_errors "$message"
      else
        ble/util/print "$message" >&2
      fi
      return 1
    fi
  }

  _ble_color_faces_initialized=1
  blehook/invoke color_defface_load
  blehook/invoke color_setface_load
  blehook color_defface_load=
  blehook color_setface_load=

  if ((${#_ble_color_faces_errors[@]})); then
    if ((_ble_edit_attached)) && [[ ! $_ble_textarea_invalidated && $_ble_term_state == internal ]]; then
      IFS=$'\n' builtin eval 'local message="${_ble_color_faces_errors[*]}"'
      ble/widget/print "$message"
    else
      printf '%s\n' "${_ble_color_faces_errors[@]}" >&2
    fi
    return 1
  else
    return 0
  fi
}
ble/function#try ble/util/idle.push ble/color/initialize-faces

## @fn ble/color/list-faces opts
function ble/color/list-faces {
  local flags=
  [[ :$1: == *:color:* ]] && flags=c

  local ret sgr0= sgr1= sgr2=
  if [[ $flags == *c* ]]; then
    sgr0=$_ble_term_sgr0
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
  fi

  local key
  for key in "${!_ble_faces__@}"; do
    ble-face/.print-face "$key"
  done
}

function ble-face/.read-arguments/process-set {
  local o=$1 face=$2 value=$3
  if local rex='^[_a-zA-Z0-9@][_a-zA-Z0-9@]*$'; ! [[ $face =~ $rex ]]; then
    ble/util/print "ble-face: invalid face name '$face'." >&2
    flags=E$flags
    return 1
  elif [[ $o == '-d' && $face == *@* ]]; then
    ble/util/print "ble-face: wildcards cannot be used in the face name '$face' for definition." >&2
    flags=E$flags
    return 1
  fi

  local assign='='
  [[ $o == -d ]] && assign=':='
  ble/array#push setface "$face$assign$value"
}

## @fn ble-face/.read-arguments args...
##   @var[out] flags
##     H = help
##     E = error
##     L = literal
##     c = color
##     r = reset
##     u = changed
function ble-face/.read-arguments {
  flags= setface=() print=()
  local opt_color=auto
  local args iarg narg=$#; args=("$@")
  for ((iarg=0;iarg<narg;)); do
    local arg=${args[iarg++]}
    if [[ $arg == -* ]]; then
      if [[ $flags == *L* ]]; then
        ble/util/print "ble-face: unrecognized argument '$arg'." >&2
        flags=E$flags
      else
        case $arg in
        (--help) flags=H$flags ;;
        (--color)
          opt_color=always ;;
        (--color=always|--color=auto|--color=never)
          opt_color=${arg#*=} ;;
        (--color=*)
          ble/util/print "ble-face: '${arg#*=}': unrecognized option argument for '--color'." >&2
          flags=E$flags ;;
        (--reset) flags=r$flags ;;
        (--changed) flags=u$flags ;;
        (--) flags=L$flags ;;
        (--*)
          ble/util/print "ble-face: unrecognized long option '$arg'." >&2
          flags=E$flags ;;
        (-?*)
          local i c
          for ((i=1;i<${#arg};i++)); do
            c=${arg:i:1}
            case $c in
            ([ru]) flags=$c$flags ;;
            ([sd])
              if ((i+1<${#arg})); then
                local lhs=${arg:i+1}
              else
                local lhs=${args[iarg++]}
              fi
              local rhs=${args[iarg++]}
              if ((iarg>narg)); then
                ble/util/print "ble-face: missing option argument for '-$c FACE SPEC'." >&2
                flags=E$flags
                continue
              fi
              ble-face/.read-arguments/process-set "${arg::2}" "$lhs" "$rhs"
              break ;;
            (*)
              ble/util/print "ble-face: unrecognized option '-$c'." >&2
              flags=E$flags ;;
            esac
          done ;;
        (-)
          ble/util/print "ble-face: unrecognized argument '$arg'." >&2
          flags=E$flags ;;
        esac
      fi

    elif [[ $arg == *=* ]]; then
      if local rex='^[_a-zA-Z@][_a-zA-Z0-9@]*:?='; [[ $arg =~ $rex ]]; then
        ble/array#push setface "$arg"
      else
        local lhs=${arg%%=*}; lhs=${lhs%:}
        ble/util/print "ble-face: invalid left-hand side '$lhs' ($arg)." >&2
        flags=E$flags
      fi

    else
      if local rex='^[_a-zA-Z@][_a-zA-Z0-9@]*$'; [[ $arg =~ $rex ]]; then
        ble/array#push print "$arg"
      else
        ble/util/print "ble-face: unrecognized form of argument '$arg'." >&2
        flags=E$flags
      fi
    fi
  done

  [[ $opt_color == auto && -t 1 || $opt_color == always ]] && flags=c$flags
  [[ $flags != *E* ]]
}
function ble-face/.print-help {
  ble/util/print-lines >&2 \
    'ble-face --help' \
    'ble-face [FACEPAT[:=|=][TYPE:]SPEC | -[sd] FACEPAT [TYPE:]SPEC]]...' \
    'ble-face [-ur|--color[=WHEN]] [FACE...]' \
    '' \
    '  OPTIONS/ARGUMENTS' \
    '' \
    '    FACEPAT=[TYPE:]SPEC' \
    '    -s FACEPAT [TYPE:]SPEC' \
    '            Set a face.  FACEPAT can include a wildcard @ which matches one or' \
    '            more characters.' \
    '' \
    '    FACE:=[TYPE:]SPEC' \
    '    -d FACE [TYPE:]SPEC' \
    '            Define a face' \
    '' \
    '    [-u | --color[=always|never|auto]]... FACEPAT...' \
    '            Print faces.  If faces are not specified, all faces are selected.' \
    '            If -u is specified, only the faces with different values from their' \
    '            default will be printed.  The option "--color" controls the output' \
    '            color settings.  The default is "auto".' \
    '' \
    '    -r FACEPAT...' \
    '            Reset faces.  If faces are not specified, all faces are selected.' \
    '' \
    '  FACEPAT   Specifies a face name.  The character @ in the face name is treated' \
    '            as a wildcard.' \
    '' \
    '  FACE      Specifies a face name.  Wildcard @ cannot be used.' \
    '' \
    '  TYPE      Specifies the format of SPEC. The following values are available.' \
    '    gspec   Comma separated graphic attribute list' \
    '    g       Integer value' \
    '    ref     Face name or id (reference)' \
    '    copy    Face name or id (copy value)' \
    '    sgrspec Parameters to the control function SGR' \
    '    ansi    ANSI Sequences' \
    ''
  return 0
}
## @fn ble/color/.print-face key
##   @param[in] key
##   @var[in] flags sgr0 sgr1 sgr2
function ble-face/.print-face {
  local key=$1 ret
  local name=${key#_ble_faces__}
  local cur=${_ble_faces[key]}
  if [[ $flags == *u* ]]; then
    local def=_ble_faces_def[key]
    [[ ${!def+set} && $cur == "${!def}" ]] && return 0
  fi
  local def=${_ble_faces[key]}
  if [[ $cur == '_ble_faces['*']' ]]; then
    cur=${cur#'_ble_faces['}
    cur=${cur%']'}
    cur=ref:${cur#_ble_faces__}
  else
    ble/color/g2gspec $((cur)); cur=$ret
  fi
  if [[ $flags == *c* ]]; then
    ble/color/iface2sgr $((key))
    cur=$ret$cur$_ble_term_sgr0
  fi
  printf '%s %s=%s\n' "${sgr1}ble-face$sgr0" "$sgr2$name$sgr0" "$cur"
}
## @fn ble/color/.print-face key
##   @param[in] key
##   @var[in] flags sgr0 sgr1 sgr2
function ble-face/.reset-face {
  local key=$1 ret
  [[ ${_ble_faces_def[key]+set} ]] &&
    _ble_faces[key]=${_ble_faces_def[key]}
}
function ble-face {
  local flags setface print
  ble-face/.read-arguments "$@"
  if [[ $flags == *H* ]]; then
    ble-face/.print-help
    return 2
  elif [[ $flags == *E* ]]; then
    return 2
  fi

  if ((!${#print[@]}&&!${#setface[@]})); then
    print=(@)
  fi

  ((${#print[@]})) && ble/color/initialize-faces
  if [[ ! $_ble_color_faces_initialized ]]; then
    local ret
    ble/string#quote-command ble-face "${setface[@]}"
    blehook color_setface_load+="$ret"
    return 0
  fi

  local spec
  for spec in "${setface[@]}"; do
    if local rex='^([_a-zA-Z@][_a-zA-Z0-9@]*)(:?=)(.*)$'; ! [[ $spec =~ $rex ]]; then
      ble/util/print "ble-face: unrecognized setting '$spec'" >&2
      flags=E$flags
      continue
    fi

    local var=${BASH_REMATCH[1]}
    local type=${BASH_REMATCH[2]}
    local value=${BASH_REMATCH[3]}
    if [[ $type == ':=' ]]; then
      if [[ $var == *@* ]]; then
        ble/util/print "ble-face: wild card @ cannot be used for face definition ($spec)." >&2
        flags=E$flags
      else
        ble/color/defface "$var" "$value"
      fi
    else
      local ret face
      if bleopt/expand-variable-pattern "_ble_faces__$var"; then
        for face in "${ret[@]}"; do
          ble/color/setface "${face#_ble_faces__}" "$value"
        done
      else
        ble/util/print "ble-face: face '$var' not found" >&2
        flags=E$flags
      fi
    fi
  done

  if ((${#print[@]})); then
    # initialize
    local ret sgr0= sgr1= sgr2=
    if [[ $flags == *c* ]]; then
      sgr0=$_ble_term_sgr0
      ble/color/face2sgr command_function; sgr1=$ret
      ble/color/face2sgr syntax_varname; sgr2=$ret
    fi

    local spec
    for spec in "${print[@]}"; do
      local ret face
      if bleopt/expand-variable-pattern "_ble_faces__$spec"; then
        if [[ $flags == *r* ]]; then
          for face in "${ret[@]}"; do
            ble-face/.reset-face "$face"
          done
        else
          for face in "${ret[@]}"; do
            ble-face/.print-face "$face"
          done
        fi
      else
        ble/util/print "ble-face: face '$spec' not found" >&2
        flags=E$flags
      fi
    done
  fi
  [[ $flags != *E* ]]
}

#------------------------------------------------------------------------------
# ble/highlight/layer

_ble_highlight_layer__list=(plain)

## @fn ble/highlight/layer/update text opts [DMIN DMAX DMAX0]
##   @param[in] text opts DMIN DMAX DMAX0
##   @var[out] HIGHLIGHT_BUFF
##   @var[out] HIGHLIGHT_UMIN
##   @var[out] HIGHLIGHT_UMAX
function ble/highlight/layer/update {
  local text=$1 iN=${#1} opts=$2
  local DMIN=${3:-0} DMAX=${4:-$iN} DMAX0=${5:-0}

  local PREV_BUFF=_ble_highlight_layer_plain_buff
  local PREV_UMIN=-1
  local PREV_UMAX=-1
  local layer player=plain LEVEL
  local nlevel=${#_ble_highlight_layer__list[@]}
  for ((LEVEL=0;LEVEL<nlevel;LEVEL++)); do
    layer=${_ble_highlight_layer__list[LEVEL]}

    "ble/highlight/layer:$layer/update" "$text" "$player"
    # echo "PREV($LEVEL) $PREV_UMIN $PREV_UMAX" >> 1.tmp

    player=$layer
  done

  HIGHLIGHT_BUFF=$PREV_BUFF
  HIGHLIGHT_UMIN=$PREV_UMIN
  HIGHLIGHT_UMAX=$PREV_UMAX
}

function ble/highlight/layer/update/add-urange {
  local umin=$1 umax=$2
  (((PREV_UMIN<0||PREV_UMIN>umin)&&(PREV_UMIN=umin),
    (PREV_UMAX<0||PREV_UMAX<umax)&&(PREV_UMAX=umax)))
}
function ble/highlight/layer/update/shift {
  local __dstArray=$1
  local __srcArray=${2:-$__dstArray}
  if ((DMIN>=0)); then
    ble/array#reserve-prototype $((DMAX-DMIN))
    builtin eval "
    $__dstArray=(
      \"\${$__srcArray[@]::DMIN}\"
      \"\${_ble_array_prototype[@]::DMAX-DMIN}\"
      \"\${$__srcArray[@]:DMAX0}\")"
  else
    [[ $__dstArray != "$__srcArray" ]] && builtin eval "$__dstArray=(\"\${$__srcArray[@]}\")"
  fi
}

function ble/highlight/layer/update/getg {
  g=
  local LEVEL=$LEVEL
  while ((--LEVEL>=0)); do
    "ble/highlight/layer:${_ble_highlight_layer__list[LEVEL]}/getg" "$1"
    [[ $g ]] && return 0
  done
  g=0
}

## @fn ble/highlight/layer/getg index
##   @param[in] index
##   @var[out] g
function ble/highlight/layer/getg {
  LEVEL=${#_ble_highlight_layer__list[*]} ble/highlight/layer/update/getg "$1"
}

## レイヤーの実装
##   先ず作成するレイヤーの名前を決めます。ここでは <layerName> とします。
##   次に、以下の配列変数と二つの関数を用意します。
##
## @arr _ble_highlight_layer_<layerName>_buff=()
##
##   グローバルに定義する配列変数です。
##   後述の ble/highlight/layer:<layerName>/update が呼ばれた時に更新します。
##
##   各要素は編集文字列の各文字に対応しています。
##   各要素は "<SGR指定><表示文字>" の形式になります。
##
##   "SGR指定" には描画属性を指定するエスケープシーケンスを指定します。
##   "SGR指定" は前の文字と同じ描画属性の場合には省略可能です。
##   この描画属性は現在のレイヤーとその下層にある全てのレイヤーの結果を総合した物になります。
##   この描画属性は後述する ble/highlight/layer/getg 関数によって得られる
##   g 値と対応している必要があります。
##
##   "<表示文字>" は編集文字列中の文字に対応する、予め定められた文字列です。
##   基本レイヤーである plain の _ble_highlight_layer_plain_buff 配列に
##   対応する "<表示文字>" が (SGR属性無しで) 格納されているのでこれを使用して下さい。
##   表示文字の内容は基本的に、その文字自身と同一の物になります。
##   但し、改行を除く制御文字の場合には、文字自身とは異なる "<表示文字>" になります。
##   ASCII code 1-8, 11-31 の文字については "^A" ～ "^_" という2文字になります。
##   ASCII code 9 (TAB) の場合には、空白が幾つか (端末の設定に応じた数だけ) 並んだ物になります。
##   ASCII code 127 (DEL) については "^?" という2文字の表現になります。
##   通常は _ble_highlight_layer_plain_buff に格納されている値をそのまま使えば良いので、
##   これらの "<表示文字>" の詳細について考慮に入れる必要はありません。
##
## @fn ble/highlight/layer:<layerName>/update text player
##   _ble_highlight_layer_<layerName>_buff の内容を更新します。
##
##   @param[in]     text
##   @var  [in]     DMIN DMAX DMAX0
##     第一引数 text には現在の編集文字列が指定されます。
##     シェル変数 DMIN DMAX DMAX0 には前回の呼出の後の編集文字列の変更位置が指定されます。
##     DMIN<0 の時は前回の呼出から text が変わっていない事を表します。
##     DMIN>=0 の時は、現在の text の DMIN から DMAX までが変更された部分になります。
##     DMAX0 は、DMAX の編集前の対応位置を表します。幾つか例を挙げます:
##     - aaaa の 境界2 に挿入があって aaxxaa となった場合、DMIN DMAX DMAX0 は 2 4 2 となります。
##     - aaxxaa から xx を削除して aaaa になった場合、DMIN DMAX DMAX0 はそれぞれ 2 2 4 となります。
##     - aaxxaa が aayyyaa となった場合 DMIN DMAX DMAX0 は 2 5 4 となります。
##     - aaxxaa が aazzaa となった場合 DMIN DMAX DMAX0 は 2 4 4 となります。
##
##   @param[in]     player
##   @var  [in,out] LAYER_UMIN (unused)
##   @var  [in,out] LAYER_UMAX (unused)
##   @param[in]     PREV_BUFF
##   @var  [in,out] PREV_UMIN
##   @var  [in,out] PREV_UMAX
##     player には現在のレイヤーの一つ下にあるレイヤーの名前が指定されます。
##     通常 _ble_highlight_layer_<layerName>_buff は
##     _ble_highlight_layer_<player>_buff の値を上書きする形で実装します。
##     LAYER_UMIN, LAYER_UMAX は _ble_highlight_layer_<player>_buff において、
##     前回の呼び出し以来、変更のあった範囲が指定されます。
##
##   @param[in,out] _ble_highlight_layer_<layerName>_buff
##     前回の呼出の時の状態で関数が呼び出されます。
##     DMIN DMAX DMAX0, LAYER_UMIN, LAYER_UMAX を元に
##     前回から描画属性の変化がない部分については、
##     呼出時に入っている値を再利用する事ができます。
##     ble/highlight/layer/update/shift 関数も参照して下さい。
##
## @fn ble/highlight/layer:<layerName>/getg index
##   指定した index に対応する描画属性の値を g 値で取得します。
##   前回の ble/highlight/layer:<layerName>/update の呼出に基づく描画属性です。
##   @var[out] g
##     結果は変数 g に設定する事によって返します。
##     より下層のレイヤーの値を引き継ぐ場合には空文字列を設定します: g=
##

#------------------------------------------------------------------------------
# ble/highlight/layer:plain

_ble_highlight_layer_plain_VARNAMES=(
  _ble_highlight_layer_plain_buff)
function ble/highlight/layer:plain/initialize-vars {
  _ble_highlight_layer_plain_buff=()
}
ble/highlight/layer:plain/initialize-vars

## @fn ble/highlight/layer:plain/update/.getch
##   @var[in,out] ch
function ble/highlight/layer:plain/update/.getch {
  [[ $ch == [' '-'~'] ]] && return 0
  if [[ $ch == [$'\t\n\177'] ]]; then
    if [[ $ch == $'\t' ]]; then
      ch=${_ble_string_prototype::it}
    elif [[ $ch == $'\n' ]]; then
      ch=$_ble_term_el$_ble_term_nl
    elif [[ $ch == $'\177' ]]; then
      ch='^?'
    fi
  else
    local ret; ble/util/s2c "$ch"
    local cs=${_ble_unicode_GraphemeCluster_ControlRepresentation[ret]}
    if [[ $cs ]]; then
      ch=$cs
    elif ((ret<0x20)); then
      ble/util/c2s $((ret+64))
      ch="^$ret"
    elif ((0x80<=ret&&ret<=0x9F)); then
      # C1 characters
      ble/util/c2s $((ret-64))
      ch="M-^$ret"
    fi
  fi
}

## @fn ble/highlight/layer:<layerName>/update text pbuff
function ble/highlight/layer:plain/update {
  if ((DMIN>=0)); then
    ble/highlight/layer/update/shift _ble_highlight_layer_plain_buff

    local i text=$1 ch
    local it=$_ble_term_it
    for ((i=DMIN;i<DMAX;i++)); do
      ch=${text:i:1}

      # LC_COLLATE for cygwin collation
      local LC_ALL= LC_COLLATE=C
      ble/highlight/layer:plain/update/.getch

      _ble_highlight_layer_plain_buff[i]=$ch
    done
  fi

  PREV_BUFF=_ble_highlight_layer_plain_buff
  ((PREV_UMIN=DMIN,PREV_UMAX=DMAX))
}
# Note: suppress LC_COLLATE errors #D1205 #D1440
ble/function#suppress-stderr ble/highlight/layer:plain/update

## @fn ble/highlight/layer:plain/getg index
##   @var[out] g
function ble/highlight/layer:plain/getg {
  g=0
}

#------------------------------------------------------------------------------
# ble/highlight/layer:region

function ble/color/defface.onload {
  ble/color/defface region         bg=60,fg=white
  ble/color/defface region_target  bg=153,fg=black
  ble/color/defface region_match   bg=55,fg=white
  ble/color/defface region_insert  fg=12,bg=252
  ble/color/defface disabled       fg=242
  ble/color/defface overwrite_mode fg=black,bg=51
}
blehook color_defface_load+=ble/color/defface.onload

## @arr _ble_highlight_layer_region_buff
##
## @arr _ble_highlight_layer_region_osel
##   前回の選択範囲の端点を保持する配列です。
##
## @var _ble_highlight_layer_region_osgr
##   前回の選択範囲の着色を保持します。
##
_ble_highlight_layer_region_VARNAMES=(
  _ble_highlight_layer_region_buff
  _ble_highlight_layer_region_osel
  _ble_highlight_layer_region_osgr)
function ble/highlight/layer:region/initialize-vars {
  _ble_highlight_layer_region_buff=()
  _ble_highlight_layer_region_osel=()
  _ble_highlight_layer_region_osgr=
}
ble/highlight/layer:region/initialize-vars

function ble/highlight/layer:region/.update-dirty-range {
  local a=$1 b=$2 p q
  ((a==b)) && return 0
  (((a<b?(p=a,q=b):(p=b,q=a)),
    (umin<0||umin>p)&&(umin=p),
    (umax<0||umax<q)&&(umax=q)))
}

function ble/highlight/layer:region/update {
  local IFS=$_ble_term_IFS
  local omin=-1 omax=-1 osgr= olen=${#_ble_highlight_layer_region_osel[@]}
  if ((olen)); then
    omin=${_ble_highlight_layer_region_osel[0]}
    omax=${_ble_highlight_layer_region_osel[olen-1]}
    osgr=$_ble_highlight_layer_region_osgr
  fi

  if ((DMIN>=0)); then
    ((DMAX0<=omin?(omin+=DMAX-DMAX0):(DMIN<omin&&(omin=DMIN)),
      DMAX0<=omax?(omax+=DMAX-DMAX0):(DMIN<omax&&(omax=DMIN))))
  fi

  local sgr=
  local -a selection=()
  if [[ $_ble_edit_mark_active ]]; then
    # 外部定義の選択範囲があるか確認
    #   vi-mode のビジュアルモード (文字選択、行選択、矩形選択) の実装で使用する。
    if ! ble/function#try ble/highlight/layer:region/mark:"$_ble_edit_mark_active"/get-selection; then
      if ((_ble_edit_mark>_ble_edit_ind)); then
        selection=("$_ble_edit_ind" "$_ble_edit_mark")
      elif ((_ble_edit_mark<_ble_edit_ind)); then
        selection=("$_ble_edit_mark" "$_ble_edit_ind")
      fi
    fi

    # sgr の取得
    local face=region
    ble/function#try ble/highlight/layer:region/mark:"$_ble_edit_mark_active"/get-face
    local ret; ble/color/face2sgr "$face"; sgr=$ret
  fi
  local rlen=${#selection[@]}

  # 変更がない時はそのまま通過
  if ((DMIN<0&&(PREV_UMIN<0||${#selection[*]}>=2&&selection[0]<=PREV_UMIN&&PREV_UMAX<=selection[1]))); then
    if [[ $sgr == "$osgr" && ${selection[*]} == "${_ble_highlight_layer_region_osel[*]}" ]]; then
      [[ ${selection[*]} ]] && PREV_BUFF=_ble_highlight_layer_region_buff
      return 0
    fi
  else
    [[ ! ${selection[*]} && ! ${_ble_highlight_layer_region_osel[*]} ]] && return 0
  fi

  local umin=-1 umax=-1
  if ((rlen)); then
    # 選択範囲がある時
    local rmin=${selection[0]}
    local rmax=${selection[rlen-1]}

    # 描画文字配列の更新
    local -a buff=()
    local g ret
    local k=0 inext iprev=0
    for inext in "${selection[@]}"; do
      if ((inext>iprev)); then
        if ((k==0)); then
          ble/array#push buff "\"\${$PREV_BUFF[@]::$inext}\""
        elif ((k%2)); then
          ble/array#push buff "\"$sgr\${_ble_highlight_layer_plain_buff[@]:$iprev:$((inext-iprev))}\""
        else
          ble/highlight/layer/update/getg "$iprev"
          ble/color/g2sgr "$g"
          ble/array#push buff "\"$ret\${$PREV_BUFF[@]:$iprev:$((inext-iprev))}\""
        fi
      fi
      ((iprev=inext,k++))
    done
    ble/highlight/layer/update/getg "$iprev"
    ble/color/g2sgr "$g"
    ble/array#push buff "\"$ret\${$PREV_BUFF[@]:$iprev}\""
    builtin eval "_ble_highlight_layer_region_buff=(${buff[*]})"
    PREV_BUFF=_ble_highlight_layer_region_buff

    # DMIN-DMAX の間
    if ((DMIN>=0)); then
      ble/highlight/layer:region/.update-dirty-range "$DMIN" "$DMAX"
    fi

    # 選択範囲の変更による再描画範囲
    if ((omin>=0)); then
      if [[ $osgr != "$sgr" ]]; then
        # 色が変化する場合
        ble/highlight/layer:region/.update-dirty-range "$omin" "$omax"
        ble/highlight/layer:region/.update-dirty-range "$rmin" "$rmax"
      else
        # 端点の移動による再描画
        ble/highlight/layer:region/.update-dirty-range "$omin" "$rmin"
        ble/highlight/layer:region/.update-dirty-range "$omax" "$rmax"
        if ((olen>1||rlen>1)); then
          # 複数範囲選択
          ble/highlight/layer:region/.update-dirty-range "$rmin" "$rmax"
        fi
      fi
    else
      # 新規選択
      ble/highlight/layer:region/.update-dirty-range "$rmin" "$rmax"
    fi

    # 下層の変更 (rmin ～ rmax は表には反映されない)
    local pmin=$PREV_UMIN pmax=$PREV_UMAX
    if ((rlen==2)); then
      ((rmin<=pmin&&pmin<rmax&&(pmin=rmax),
        rmin<pmax&&pmax<=rmax&&(pmax=rmin)))
    fi
    ble/highlight/layer:region/.update-dirty-range "$pmin" "$pmax"
  else
    # 選択範囲がない時

    # 下層の変更
    umin=$PREV_UMIN umax=$PREV_UMAX

    # 選択解除の範囲
    ble/highlight/layer:region/.update-dirty-range "$omin" "$omax"
  fi

  _ble_highlight_layer_region_osel=("${selection[@]}")
  _ble_highlight_layer_region_osgr=$sgr
  ((PREV_UMIN=umin,
    PREV_UMAX=umax))
}

function ble/highlight/layer:region/getg {
  if [[ $_ble_edit_mark_active ]]; then
    local index=$1 olen=${#_ble_highlight_layer_region_osel[@]}
    ((olen)) || return 1
    ((_ble_highlight_layer_region_osel[0]<=index&&index<_ble_highlight_layer_region_osel[olen-1])) || return 1

    local flag_region=
    if ((olen>=4)); then
      # 複数の region に分かれている時は二分法
      local l=0 u=$((olen-1)) m
      while ((l+1<u)); do
        ((_ble_highlight_layer_region_osel[m=(l+u)/2]<=index?(l=m):(u=m)))
      done
      ((l%2==0)) && flag_region=1
    else
      flag_region=1
    fi

    if [[ $flag_region ]]; then
      local face=region
      ble/function#try ble/highlight/layer:region/mark:"$_ble_edit_mark_active"/get-face
      local ret; ble/color/face2g "$face"; g=$ret
    fi
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:disabled

_ble_highlight_layer_disabled_VARNAMES=(
  _ble_highlight_layer_disabled_prev
  _ble_highlight_layer_disabled_buff)
function ble/highlight/layer:disabled/initialize-vars {
  _ble_highlight_layer_disabled_prev=
  _ble_highlight_layer_disabled_buff=()
}
ble/highlight/layer:disabled/initialize-vars

function ble/highlight/layer:disabled/update {
  if [[ $_ble_edit_line_disabled ]]; then
    if ((DMIN>=0)) || [[ ! $_ble_highlight_layer_disabled_prev ]]; then
      local ret; ble/color/face2sgr disabled; local sgr=$ret
      _ble_highlight_layer_disabled_buff=("$sgr""${_ble_highlight_layer_plain_buff[@]}")
    fi
    PREV_BUFF=_ble_highlight_layer_disabled_buff

    if [[ $_ble_highlight_layer_disabled_prev ]]; then
      PREV_UMIN=$DMIN PREV_UMAX=$DMAX
    else
      PREV_UMIN=0 PREV_UMAX=${#1}
    fi
  else
    if [[ $_ble_highlight_layer_disabled_prev ]]; then
      PREV_UMIN=0 PREV_UMAX=${#1}
    fi
  fi

  _ble_highlight_layer_disabled_prev=$_ble_edit_line_disabled
}

function ble/highlight/layer:disabled/getg {
  if [[ $_ble_highlight_layer_disabled_prev ]]; then
    local ret; ble/color/face2g disabled; g=$ret
  fi
}

_ble_highlight_layer_overwrite_mode_VARNAMES=(
  _ble_highlight_layer_overwrite_mode_index
  _ble_highlight_layer_overwrite_mode_buff)
function ble/highlight/layer:overwrite_mode/initialize-vars {
  _ble_highlight_layer_overwrite_mode_index=-1
  _ble_highlight_layer_overwrite_mode_buff=()
}
ble/highlight/layer:overwrite_mode/initialize-vars

function ble/highlight/layer:overwrite_mode/update {
  local oindex=$_ble_highlight_layer_overwrite_mode_index
  if ((DMIN>=0)); then
    if ((oindex>=DMAX0)); then
      ((oindex+=DMAX-DMAX0))
    elif ((oindex>=DMIN)); then
      oindex=-1
    fi
  fi

  local index=-1
  if [[ $_ble_edit_overwrite_mode && ! $_ble_edit_mark_active ]]; then
    local next=${_ble_edit_str:_ble_edit_ind:1}
    if [[ $next && $next != [$'\n\t'] ]]; then
      index=$_ble_edit_ind

      local g ret

      # PREV_BUFF の内容をロード
      if ((PREV_UMIN<0&&oindex>=0)); then
        # 前回の結果が残っている場合
        ble/highlight/layer/update/getg "$oindex"
        ble/color/g2sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[oindex]=$ret${_ble_highlight_layer_plain_buff[oindex]}
      else
        # コピーした方が速い場合
        builtin eval "_ble_highlight_layer_overwrite_mode_buff=(\"\${$PREV_BUFF[@]}\")"
      fi
      PREV_BUFF=_ble_highlight_layer_overwrite_mode_buff

      # 1文字着色
      # ble/highlight/layer/update/getg "$index"
      # ((g^=_ble_color_gflags_Revert))
      ble/color/face2g overwrite_mode
      ble/color/g2sgr "$ret"
      _ble_highlight_layer_overwrite_mode_buff[index]=$ret${_ble_highlight_layer_plain_buff[index]}
      if ((index+1<${#1})); then
        ble/highlight/layer/update/getg $((index+1))
        ble/color/g2sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[index+1]=$ret${_ble_highlight_layer_plain_buff[index+1]}
      fi
    fi
  fi

  if ((index>=0)); then
    ble/term/cursor-state/hide
  else
    ble/term/cursor-state/reveal
  fi

  if ((index!=oindex)); then
    ((oindex>=0)) && ble/highlight/layer/update/add-urange "$oindex" $((oindex+1))
    ((index>=0)) && ble/highlight/layer/update/add-urange "$index" $((index+1))
  fi

  _ble_highlight_layer_overwrite_mode_index=$index
}
function ble/highlight/layer:overwrite_mode/getg {
  local index=$_ble_highlight_layer_overwrite_mode_index
  if ((index>=0&&index==$1)); then
    # ble/highlight/layer/update/getg "$1"
    # ((g^=_ble_color_gflags_Revert))
    local ret; ble/color/face2g overwrite_mode; g=$ret
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:RandomColor (sample)

_ble_highlight_layer_RandomColor_VARNAMES=(
  _ble_highlight_layer_RandomColor_buff)
function ble/highlight/layer:RandomColor/initialize-vars {
  _ble_highlight_layer_RandomColor_buff=()
}
ble/highlight/layer:RandomColor/initialize-vars

function ble/highlight/layer:RandomColor/update {
  local text=$1 ret i
  _ble_highlight_layer_RandomColor_buff=()
  for ((i=0;i<${#text};i++)); do
    # _ble_highlight_layer_RandomColor_buff[i] に "<sgr><表示文字>" を設定する。
    # "<表示文字>" は ${_ble_highlight_layer_plain_buff[i]} でなければならない
    # (或いはそれと文字幅が同じ物…ただそれが反映される保証はない)。
    ble/color/gspec2sgr "fg=$((RANDOM%256))"
    _ble_highlight_layer_RandomColor_buff[i]=$ret${_ble_highlight_layer_plain_buff[i]}
  done
  PREV_BUFF=_ble_highlight_layer_RandomColor_buff
  ((PREV_UMIN=0,PREV_UMAX=${#text}))
}
function ble/highlight/layer:RandomColor/getg {
  # ここでは乱数を返しているが、実際は
  # PREV_BUFF=_ble_highlight_layer_RandomColor_buff
  # に設定した物に対応する物を指定しないと表示が変になる。
  local ret; ble/color/gspec2g "fg=$((RANDOM%256))"; g=$ret
}

_ble_highlight_layer_RandomColor2_buff=()
function ble/highlight/layer:RandomColor2/update {
  local text=$1 ret i x
  ble/highlight/layer/update/shift _ble_highlight_layer_RandomColor2_buff
  for ((i=DMIN;i<DMAX;i++)); do
    ble/color/gspec2sgr "fg=$((16+(x=RANDOM%27)*4-x%9*2-x%3))"
    _ble_highlight_layer_RandomColor2_buff[i]=$ret${_ble_highlight_layer_plain_buff[i]}
  done
  PREV_BUFF=_ble_highlight_layer_RandomColor2_buff
  ((PREV_UMIN=0,PREV_UMAX=${#text}))
}
function ble/highlight/layer:RandomColor2/getg {
  # ここでは乱数を返しているが、実際は
  # PREV_BUFF=_ble_highlight_layer_RandomColor2_buff
  # に設定した物に対応する物を指定しないと表示が変になる。
  local x ret
  ble/color/gspec2g "fg=$((16+(x=RANDOM%27)*4-x%9*2-x%3))"; g=$ret
}

_ble_highlight_layer__list=(plain syntax region overwrite_mode disabled)
