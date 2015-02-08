#!/bin/bash

# gflags

declare -i _ble_color_gflags_MaskFg=0x0000FF00
declare -i _ble_color_gflags_MaskBg=0x00FF0000
declare -i _ble_color_gflags_Bold=0x01
declare -i _ble_color_gflags_Underline=0x02
declare -i _ble_color_gflags_Revert=0x04

declare -a _ble_color_g2seq__table=()
function .ble-color.g2seq {
  ret="${_ble_color_g2seq__table[$1]}"
  test -n "$ret" && return

  local -i g="$1"
  local fg="$((g>> 8&0xFF))"
  local bg="$((g>>16&0xFF))"

  local sgr=0
  ((g&_ble_color_gflags_Bold))      && sgr="$sgr;1"
  ((g&_ble_color_gflags_Underline)) && sgr="$sgr;4"
  ((g&_ble_color_gflags_Revert))    && sgr="$sgr;7"
  if ((fg)); then
    .ble-color.color2sgrfg "$fg"
    sgr="$sgr;$ret"
  fi
  if ((bg)); then
    .ble-color.color2sgrbg "$bg"
    sgr="$sgr;$ret"
  fi
  
  ret="[${sgr}m"
  _ble_color_g2seq__table[$1]="$ret"
}
function .ble-color.gspec2g {
  local g=0
  for entry in ${1//,/ }; do
    case "$entry" in
    bold)      ((g|=_ble_color_gflags_Bold)) ;;
    underline) ((g|=_ble_color_gflags_Underline)) ;;
    standout)  ((g|=_ble_color_gflags_Revert)) ;;
    fg=*)
      .ble-color.name2color "${entry:3}"
      (('g|=ret<<8')) ;;
    bg=*)
      .ble-color.name2color "${entry:3}"
      (('g|=ret<<16')) ;;
    none)
      g=0 ;;
    esac
  done

  ret="$g"
}

function ble-color-getseq {
  local ret sgr=0
  for entry in ${1//,/ }; do
    case "$entry" in
    bold)      sgr="$sgr;1" ;;
    underline) sgr="$sgr;4" ;;
    standout)  sgr="$sgr;7" ;;
    fg=*)
      .ble-color.name2color "${entry:3}"
      .ble-color.color2sgrfg "$ret"
      sgr="$sgr;$ret" ;;
    bg=*)
      .ble-color.name2color "${entry:3}"
      .ble-color.color2sgrbg "$ret"
      sgr="$sgr;$ret" ;;
    none)
      sgr=0 ;;
    esac
  done

  seq="[${sgr}m"
}

function .ble-color.name2color {
  local colorName="$1"
  if [ -z "${colorName//[0-9]/}" ]; then
    ret=${colorName--1}
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
    (*)       ret=-1 ;;
    esac
  fi
}
function .ble-color.color2sgrfg {
  local ccode="$1"
  if ((ccode<0)); then
    ret=39
  elif ((ccode<8)); then
    ret="3$ccode"
  elif ((ccode<16)); then
    ret="9$((ccode-8))"
  elif ((ccode<256)); then
    ret="38;5;$ccode"
  fi
}
function .ble-color.color2sgrbg {
  local ccode="$1"
  if ((ccode<0)); then
    ret=49
  elif ((ccode<8)); then
    ret="4$ccode"
  elif ((ccode<16)); then
    ret="10$((ccode-8))"
  elif ((ccode<256)); then
    ret="48;5;$ccode"
  fi
}


## 関数 _ble_region_highlight_table;  ble-region_highlight-append triplets ; _ble_region_highlight_table
function ble-region_highlight-append {
  while [ $# -gt 0 ]; do
    local -a triplet=($1)
    local ret; .ble-color.gspec2g "${triplet[2]}"; local g="$ret"
    local -i i="${triplet[0]}" iN="${triplet[1]}"
    for ((;i<iN;i++)); do
      _ble_region_highlight_table[$i]="$g"
    done
    shift
  done
}

#------------------------------------------------------------------------------

.ble-shopt-extglob-push

function ble-syntax-highlight+default {
  .ble-shopt-extglob-push

  local text="$1"
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    local tail="${text:$i}"
    case "$mode" in
    cmd)
      case "$tail" in
      ([_a-zA-Z]*([_a-zA-Z0-9])=*)
        # 変数への代入
        local var="${tail%%=*}"
        ble-region_highlight-append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        mode=rhs
        ;;
      ([_a-zA-Z]*([_a-zA-Z0-9])\[+([^\]])\]=*)
        # 配列変数への代入
        local var="${tail%%\[*}"
        ble-region_highlight-append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        local tmp="${tail%%\]=*}"
        local ind="${tmp#*\[}"
        ble-region_highlight-append "$i $((i+${#ind})) fg=green"
        ((i+=${#var}+1))
  
        mode=rhs
        ;;
      (+([^ 	"'\""])?([ 	]*))
        local cmd="${tail%%[	 ]*}"
        case "$(builtin type -t "$cmd" 2>/dev/null):$cmd" in
        builtin:*)
          ble-region_highlight-append "$i $((i+${#cmd})) fg=red" ;;
        alias:*)
          ble-region_highlight-append "$i $((i+${#cmd})) fg=teal" ;;
        function:*)
          ble-region_highlight-append "$i $((i+${#cmd})) fg=navy" ;;
        file:*)
          ble-region_highlight-append "$i $((i+${#cmd})) fg=green" ;;
        keyword:*)
          ble-region_highlight-append "$i $((i+${#cmd})) fg=blue" ;;
        *)
          ble-region_highlight-append "$i $((i+${#cmd})) bg=224" ;;
        esac
        ((i+=${#cmd}))
        mode=arg
        ;;
      *)
        ((i++))
        ;;
      esac ;;
    *)
      ((i++))
      ;;
    esac
  done

  .ble-shopt-extglob-pop

  if test -n "$_ble_edit_mark_active"; then
    if ((_ble_edit_mark>_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_ind $_ble_edit_mark bg=60,fg=white"
    elif ((_ble_edit_mark<_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_mark $_ble_edit_ind bg=60,fg=white"
    fi
  fi
  # ble-region_highlight-append "${#text1} $((${#text1}+1)) standout"
}

.ble-shopt-extglob-pop

