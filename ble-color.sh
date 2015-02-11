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

function ble-syntax-highlight+region {
  if test -n "$_ble_edit_mark_active"; then
    if ((_ble_edit_mark>_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_ind $_ble_edit_mark bg=60,fg=white"
    elif ((_ble_edit_mark<_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_mark $_ble_edit_ind bg=60,fg=white"
    fi
  fi
}

.ble-shopt-extglob-push

function ble-syntax-highlight+test {
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

  ble-syntax-highlight+region

  # ble-region_highlight-append "${#text1} $((${#text1}+1)) standout"
}

.ble-shopt-extglob-pop

function ble-syntax-highlight+default/type {
  type="$1"
  local cmd="$2"
  case "$type:$cmd" in
  (builtin::|builtin:.)
    # 見にくいので太字にする
    type=builtin_bold ;;
  (builtin:*)
    type=builtin ;;
  (alias:*)
    type=alias ;;
  (function:*)
    type=function ;;
  (file:*)
    type=file ;;
  (keyword:*)
    type=keyword ;;
  (*:%*)
    # jobs
    if jobs "$cmd" &>/dev/null; then
      type=jobs
    else
      type=error
    fi ;;
  (*)
    type=error ;;
  esac
}

function ble-syntax-highlight+default {
  local text="$1"
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    tail="${text:i}"
    if [[ "$mode" = cmd ]]; then
      if [[ "$tail" =~ ^([_a-zA-Z][_a-zA-Z0-9]*)\+?= ]]; then
        # local var="${BASH_REMATCH[0]::-1}"
        ble-region_highlight-append "$i $((i+${#BASH_REMATCH[1]})) fg=orange"
        ((i+=${#BASH_REMATCH[0]}))
        mode=rhs
        continue
      elif [[ "$tail" =~ ^([^"$IFS|&;()<>'\"\\"]|\\.)+ ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう

        local _0="${BASH_REMATCH[0]}"
        eval "local cmd=${_0}"

        # この部分の判定で fork を沢山する \if 等に対しては 4fork+2exec になる。
        # ■キャッシュ(accept-line 時に clear)するなどした方が良いかもしれない。
        local type; ble-syntax-highlight+default/type "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
        if [[ "$type" = alias && "$cmd" != "$_0" ]]; then
          # alias を \ で無効化している場合
          # → unalias して再度 check (2fork)
          type=$(
            unalias "$cmd"
            ble-syntax-highlight+default/type "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
            echo -n "$type")
        elif [[ "$type" = keyword && "$cmd" != "$_0" ]]; then
          # keyword (time do if function else elif fi の類) を \ で無効化している場合
          # →file, function, builtin, jobs のどれかになる。以下 3fork+2exec
          if test -z "${cmd##%*}" && jobs "$cmd" &>/dev/null; then
            # %() { :; } として 関数を定義できるが jobs の方が優先される。
            # (% という名の関数を呼び出す方法はない?)
            # でも % で始まる物が keyword になる事はそもそも無いような。
            type=jobs
          elif declare -f "$cmd" &>/dev/null; then
            type=function
          elif enable -p | fgrep -xq "enable $cmd" &>/dev/null; then
            type=builtin
          elif which "$cmd" &>/dev/null; then
            type=file
          else
            type=error
          fi
        fi

        case "$type" in
        (file)
          ble-region_highlight-append "$i $((i+${#_0})) fg=green" ;;
        (alias)
          ble-region_highlight-append "$i $((i+${#_0})) fg=teal" ;;
        (function)
          ble-region_highlight-append "$i $((i+${#_0})) fg=navy" ;;
        (builtin)
          ble-region_highlight-append "$i $((i+${#_0})) fg=red" ;;
        (builtin_bold)
          ble-region_highlight-append "$i $((i+${#_0})) fg=red,bold" ;;
        (keyword)
          ble-region_highlight-append "$i $((i+${#_0})) fg=blue" ;;
        (jobs)
          ble-region_highlight-append "$i $((i+1)) fg=red" ;;
        (error|*)
          ble-region_highlight-append "$i $((i+${#_0})) bg=224" ;;
        esac

        ((i+=${#BASH_REMATCH[0]}))
        case "$type:$cmd" in
        (keyword:time|keyword:!|keyword:do|builtin:eval|keyword:\{)
          mode=cmd ;;
        (*)
          mode=arg ;;
        esac

        continue
      fi
    elif [[ "$mode" =~ arg ]]; then
      if [[ "$tail" =~ ^([^"$IFS|&;()<>'\"\`\\"]|\\.)+ ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう
        local arg="${BASH_REMATCH[0]}"

        local file="$arg"
        [[ ! -e "$file" && "$file" =~ ^\~ ]] && file="$HOME${file:1}"
        if test -d "$file"; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=navy,underline"
        elif test -h "$file"; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=teal,underline"
        elif test -x "$file"; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=green,underline"
        elif test -f "$file"; then
          ble-region_highlight-append "$i $((i+${#arg})) underline"
        fi

        ((i+=${#arg}))
        continue
      fi
    fi

    if [[ "$tail" =~ ^\'([^\'])*\'|^\$\'([^\']|\\.)*\'|^\`([^\`]|\\.)*\` ]]; then
      ble-region_highlight-append "$i $((i+${#BASH_REMATCH[0]})) fg=green"
      ((i+=${#BASH_REMATCH[0]}))
      mode=arg_
      continue
    elif [[ "$tail" =~ ^[$IFS]+ ]]; then
      ((i+=${#BASH_REMATCH[0]}))
      local spaces="${BASH_REMATCH[0]}"
      if [[ "$spaces" =~ $'\n' ]]; then
        mode=cmd
      else
        [[ "$mode" = arg_ ]] && mode=arg
      fi
      continue
    elif [[ "$tail" =~ ^\;\;?|^\&\&?|^\|\|? ]]; then
      if [[ $mode = cmd ]]; then
        ble-region_highlight-append "$i $((i+${#BASH_REMATCH[0]})) bg=224"
      fi
      ((i+=${#BASH_REMATCH[0]}))
      mode=cmd
      continue
    elif [[ "$tail" =~ ^\( ]]; then
      ((i+=${#BASH_REMATCH[0]}))
      mode=cmd
      continue
    fi
    # 他 "...", ${}, $... arg と共通

    ((i++))
    # a[]=... の引数は、${} や "" を考慮に入れるだけでなく [] の数を数える。
  done

  ble-syntax-highlight+region
}
