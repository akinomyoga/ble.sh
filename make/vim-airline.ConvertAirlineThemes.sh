#!/bin/bash

if [[ ! ${BLE_VERSION-} ]]; then
  echo "This script needs to be sourced in a ble.sh session." >&2
  return 1 || exit 1
fi

#_ble_vim_airline_dumpdir=tmp/airline
_ble_vim_airline_vimruntime=$(builtin printf '%s\n' /usr/share/vim/vim[0-9]* | tail -n 1)
_ble_vim_airline_dumpdir=out/data/airline
_ble_vim_airline_themes_repo=~/.vim/plugged/vim-airline-themes
_ble_vim_airline_themes_year=2021

declare -A name2color=([none]=-1 [lightmagenta]='#ffe0ff')

## @fn ble/lib/vim-airline/convert-theme/load-vim-rgb
##   This attempts to read $VIMRUNTIME/rgb.txt.
##
##   @remarks $VIMRUNTIME/rgb.txt seems to have been deprecated.  ":help
##   rgb.txt" shows the following descriptions:
##
##   > Additionally, colors defined by a default color list can be used.  For
##   > more info see :colorscheme.  These colors used to be defined in
##   > $VIMRUNTIME/rgb.txt, now they are in v:colornames which is initialized
##   > from $VIMRUNTIME/colors/lists/default.vim.
function ble/lib/vim-airline/convert-theme/load-vim-rgb {
  local path_rgb_txt=$_ble_vim_airline_vimruntime/rgb.txt
  [[ -s $path_rgb_txt ]] || return 1
  local R G B name ret IFS=$' \t\n'
  while builtin read -r R G B name || [[ $name ]]; do
    name=${name,,}
    name=${name//["$_ble_term_IFS"]}
    [[ $name ]] || continue
    printf -v ret '#%02x%02x%02x' "$R" "$G" "$B"
    name2color[$name]=$ret
  done < "$path_rgb_txt"
}

## @fn ble/lib/vim-airline/convert-theme/load-vim-default-colors
##   This attempts to read $VIMRUNTIME/colors/lists/default.vim.
function ble/lib/vim-airline/convert-theme/load-vim-default-colors {
  local path_default_vim=$_ble_vim_airline_vimruntime/colors/lists/default.vim
  [[ -s $path_default_vim ]] || return 1
  local R G B name color IFS=$' \t\n'
  while builtin read -r color name || [[ $name ]]; do
    name=${name,,}
    name=${name//["$_ble_term_IFS"]}
    [[ $name ]] || continue
    name2color[$name]=$color
  done < <(
    ble/bin/sed -n '
      s/^.*'\''\([^'\''"]\{1,\}\)'\'': '\''\(#[0-9a-fA-F]\{6\}\)'\''.*$/\2 \1/p
    ' "$path_default_vim"
  )
}

ble/lib/vim-airline/convert-theme/load-vim-rgb ||
  ble/lib/vim-airline/convert-theme/load-vim-default-colors

function ble/lib/vim-airline/convert-theme/decode-color {
  local cspec=${1,,} ret
  if [[ $cspec == '#'?????? ]]; then
    local R=$((16#${cspec:1:2}))
    local G=$((16#${cspec:3:2})) 
    local B=$((16#${cspec:5:2}))
    ble/color/convert-rgb24-to-color256 "$R" "$G" "$B"
    color256=$ret color24=$cspec
  elif [[ $cspec == '#'??? ]]; then
    local r=${cspec::1} g=${cspec:1:1} b=${cspec:2:1}
    ble/lib/vim-airline/convert-theme/decode-color "#$r$r$g$g$b$b"
  elif [[ $cspec && ! ${cspec//[0-9]} || $cspec == -1 ]]; then
    color256=$cspec color24=$cspec
  elif [[ ${name2color[$cspec]} ]]; then
    ble/lib/vim-airline/convert-theme/decode-color "${name2color[$cspec]}"
  else
    color256=unknown color24=unknown
    ble/util/print "$theme: unknown color spec '$cspec'" >&2
  fi
}

function face {
  local mode=$1 face=$2 fg=${3:-${5:-0}} bg=${4:-${6:-0}}

  # check mode
  case ${mode%_modified} in
  (normal|insert|replace|visual|commandline|inactive) ;;
  (accents|tabline|ctrlp|terminal) return 0 ;;
  (*_paste|insert_replace|normal_error|insert_error) return 0 ;;
  (*) ble/util/print "$theme: Unknown mode '$mode'" >&2
  esac

  # check face
  case $face in
  (airline_[abcxyz]|airline_error|airline_term|airline_warning) ;;
  (airline_*_to_airline_*) return 0 ;;
  (airline_file) return 0 ;; # ?????? itchyny/landscape.vim で使用
  (*) ble/util/print "$theme: Unknown face type '$face'" >&2
  esac

  local face_name=vim_${face}_$mode

  local color256 color24
  ble/lib/vim-airline/convert-theme/decode-color "$fg"
  fg256[$face_name]=$color256
  fg24[$face_name]=$color24
  ble/lib/vim-airline/convert-theme/decode-color "$bg"
  bg256[$face_name]=$color256
  bg24[$face_name]=$color24
}

function ble/lib/vim-airline/convert-theme/eq {
  local face1=$1 face2=$2
  [[ "${fg256[$face1]}" == "${fg256[$face2]}" ]] || return 1
  [[ "${bg256[$face1]}" == "${bg256[$face2]}" ]] || return 1
  [[ "${fg24[$face1]}" == "${fg24[$face2]}" ]] || return 1
  [[ "${bg24[$face1]}" == "${bg24[$face2]}" ]] || return 1
  return 0
}

function ble/lib/vim-airline/convert-theme/convert {
  local theme=$1

  local -A fg256=() bg256=() fg24=() bg24=()

  # These are the dummy faces used to compare the colors with the default
  # values of the respective faces (without "_default").
  local f
  f=vim_airline_error_default   fg256[$f]=16  bg256[$f]=88  fg24[$f]='#000000' bg24[$f]='#990000'
  f=vim_airline_term_default    fg256[$f]=158 bg256[$f]=234 fg24[$f]='#9cffd3' bg24[$f]='#202020'
  f=vim_airline_warning_default fg256[$f]=16  bg256[$f]=166 fg24[$f]='#000000' bg24[$f]='#df5f00'

  source "$_ble_vim_airline_dumpdir/$theme.bash"

  [[ -d contrib/airline ]] || mkdir -p contrib/airline
  exec 5> "contrib/airline/$theme.bash"
  {
    if [[ $theme == dark ]]; then
      ble/util/print "# From github:vim-airline/vim-airline/autoload/airline/themes/dark.vim"
      ble/util/print "#   The MIT License (MIT)"
      ble/util/print "#   Copyright (c) 2013-2021 Bailey Ling et al."
      ble/util/print "#"
    elif [[ $theme == landscape ]]; then
      ble/util/print "# From github:itchyny/landscape.vim/autoload/airline/themes/$theme.vim"
      ble/util/print "#   The MIT License (MIT)"
      ble/util/print "#   Copyright (c) 2012-2015 itchyny."
      ble/util/print "#"
    else
      ble/util/print "# From github:vim-airline/vim-airline-themes/autoload/airline/themes/$theme.vim"
      ble/util/print "#   The MIT License (MIT)"
      ble/util/print "#   Copyright (C) 2013-$_ble_vim_airline_themes_year Bailey Ling & Contributors."
      ble/util/print "#"
      ble/bin/sed '/^"/!Q;s//#/' "$_ble_vim_airline_themes_repo"/autoload/airline/themes/"$theme".vim
    fi
    ble/util/print
    ble/util/print 'ble-import lib/vim-airline'
    ble/util/print
    ble/util/print "function ble/lib/vim-airline/theme:$theme/initialize {"
    ble/util/print '  ble-face -r vim_airline_@'
  } >&5

  local face
  for face in "${!fg256[@]}"; do
    local face2=$face
    case $face in
    (*_modified) ble/lib/vim-airline/convert-theme/eq "$face" "${face%_modified}" && continue ;;
    (vim_airline_x_*) ble/lib/vim-airline/convert-theme/eq "$face" "${face/x/c}" && continue ;;
    (vim_airline_y_*) ble/lib/vim-airline/convert-theme/eq "$face" "${face/y/b}" && continue ;;
    (vim_airline_z_*) ble/lib/vim-airline/convert-theme/eq "$face" "${face/z/a}" && continue ;;
    (*_replace) ble/lib/vim-airline/convert-theme/eq "$face" "${face%_*}_insert" && continue ;;
    (*_normal)
      face2=${face%_normal}
      ble/lib/vim-airline/convert-theme/eq "$face" "${face%_*}_default" && continue ;;
    (*_default) continue ;; # skip dummy faces
    (*_*) ble/lib/vim-airline/convert-theme/eq "$face" "${face%_*}_normal" && continue ;;
    (*) continue ;;
    esac

    printf '  ble-face -s %-40s %-13s # fg=%s,bg=%s\n' \
           "$face2" "fg=${fg256[$face]},bg=${bg256[$face]}" "${fg24[$face]}" "${bg24[$face]}"
  done | ble/bin/sort >&5
  ble/util/print '}' >&5
  exec 5>&-
}

function ble/lib/vim-airline/convert-theme/convert-all {
  local file theme
  for file in "$_ble_vim_airline_dumpdir"/*.bash; do
    theme=${file##*/}
    theme=${theme%.bash}
    #ble/util/print "Converting $theme..."
    ble/lib/vim-airline/convert-theme/convert "$theme"
  done
}
ble/lib/vim-airline/convert-theme/convert-all
