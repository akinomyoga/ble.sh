# -*- mode: sh; mode: sh-bash -*-
#
# airline.vim (https://github.com/vim-airline/vim-airline) の模倣実装
#
# * "g:airline_mode_map" is partially supported
#
#   Unsupported mappings
#
#   'ic'    : 'INSERT COMPL',
#   'ix'    : 'INSERT COMPL',
#   'multi' : 'MULTI'
#   't'     : 'TERMINAL'
#

ble-import keymap.vi
ble-import prompt-git

bleopt/declare -n vim_airline_theme dark
function bleopt/check:vim_airline_theme {
  local init=ble/lib/vim-airline/theme:"$value"/initialize
  if ! ble/is-function "$init"; then
    local ret
    if ! ble/util/import/search "airline/$value"; then
      ble/util/print "ble/lib/vim-airline: theme '$value' not found." >&2
      return 1
    fi
    ble/util/import "$ret"
    ble/is-function "$init" || return 1
  fi

  "$init"
  return 0
}

bleopt/declare -v vim_airline_section_a '\e[1m\q{lib/vim-airline/mode}'
bleopt/declare -v vim_airline_section_b '\q{lib/vim-airline/gitstatus}'
bleopt/declare -v vim_airline_section_c '\w'
bleopt/declare -v vim_airline_section_x 'bash'
bleopt/declare -v vim_airline_section_y '$_ble_util_locale_encoding[unix]'
bleopt/declare -v vim_airline_section_z ' \q{history-percentile} \e[1m!\q{history-index}/\!\e[22m \q{position}'

bleopt/declare -v vim_airline_left_sep      $'\uE0B0'
bleopt/declare -v vim_airline_left_alt_sep  $'\uE0B1'
bleopt/declare -v vim_airline_right_sep     $'\uE0B2'
bleopt/declare -v vim_airline_right_alt_sep $'\uE0B3'
bleopt/declare -v vim_airline_symbol_branch $'\uE0A0'
bleopt/declare -v vim_airline_symbol_dirty  $'\u26A1'

function bleopt/check:vim_airline_left_sep      { ble/prompt/unit#clear _ble_prompt_status; }
function bleopt/check:vim_airline_left_alt_sep  { ble/prompt/unit#clear _ble_prompt_status; }
function bleopt/check:vim_airline_right_sep     { ble/prompt/unit#clear _ble_prompt_status; }
function bleopt/check:vim_airline_right_alt_sep { ble/prompt/unit#clear _ble_prompt_status; }

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_lib_vim_airline_mode_map_default}"
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'i'  'INSERT'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'n'  'NORMAL'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'in' '(INSERT)'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'o'  'OP PENDING'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'R'  'REPLACE'
ble/gdict#set _ble_lib_vim_airline_mode_map_default '' 'V REPLACE'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'v'  'VISUAL'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'V'  'V-LINE'
ble/gdict#set _ble_lib_vim_airline_mode_map_default '' 'V-BLOCK'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 's'  'SELECT'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'S'  'S-LINE'
ble/gdict#set _ble_lib_vim_airline_mode_map_default '' 'S-BLOCK'
ble/gdict#set _ble_lib_vim_airline_mode_map_default '?'  '------'
ble/gdict#set _ble_lib_vim_airline_mode_map_default 'c'  'COMMAND'
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_lib_vim_airline_mode_map_atomic}"
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'i'  'I'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'n'  'N'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'R'  'R'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'v'  'V'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'V'  'V-L'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic '' 'V-B'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 's'  'S'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'S'  'S-L'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic '' 'S-B'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic '?'  '--'
ble/gdict#set _ble_lib_vim_airline_mode_map_atomic 'c'  'C'
builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_lib_vim_airline_mode_map}"
ble/gdict#cp _ble_lib_vim_airline_mode_map_default _ble_lib_vim_airline_mode_map

function ble/lib/vim-airline/initialize-faces {
  # default (taken from dark.vim insert)
  ble/color/defface vim_airline_a       fg=17,bg=45
  ble/color/defface vim_airline_b       fg=231,bg=27
  ble/color/defface vim_airline_c       fg=231,bg=18
  ble/color/defface vim_airline_error   fg=16,bg=88   # fg=#000000,bg=#990000
  ble/color/defface vim_airline_term    fg=158,bg=234 # fg=#9cffd3,bg=#202020
  ble/color/defface vim_airline_warning fg=16,bg=166  # fg=#000000,bg=#df5f00


  # "abc" spezialized for map is by default mirror of "abc" for
  # general map (except for _replace)
  local section map
  for section in a b c error term warning; do
    for map in _normal _insert _visual _commandline _inactive; do
      ble/color/defface "vim_airline_$section$map" ref:"vim_airline_$section"
    done
    ble/color/defface "vim_airline_${section}_replace" ref:"vim_airline_${section}_insert"
  done

  # "zyx" is mirror of "abc" by default
  local map
  for map in '' _normal _insert _replace _visual _commandline _inactive; do
    ble/color/defface "vim_airline_x$map" ref:"vim_airline_c$map"
    ble/color/defface "vim_airline_y$map" ref:"vim_airline_b$map"
    ble/color/defface "vim_airline_z$map" ref:"vim_airline_a$map"
  done

  # "modified" is mirror of unmodified by default
  local name
  for name in {a,b,c,x,y,z,error,term,warning}{,_normal,_insert,_replace,_visual,_commandline,_inactive}; do
    ble/color/defface "vim_airline_${name}_modified" ref:"vim_airline_$name"
  done
}
ble/lib/vim-airline/initialize-faces

function ble/lib/vim-airline/convert-theme/.to-color256 {
  local R=$((16#${1:1:2}))
  local G=$((16#${1:3:2}))
  local B=$((16#${1:5:2}))
  ble/color/convert-rgb24-to-color256 "$R" "$G" "$B"
}
function ble/lib/vim-airline/convert-theme/.setface {
  local gspec=
  local ret
  ble/lib/vim-airline/convert-theme/.to-color256 "$2"; local fg=$ret
  ble/lib/vim-airline/convert-theme/.to-color256 "$3"; local bg=$ret
  printf 'ble/color/setface vim_airline_%-13s %-13s # %s\n' "$1" "fg=$fg,bg=$bg" "fg=$2,bg=$3"
}
function ble/lib/vim-airline/convert-theme {
  local file=$1
  sed -n 's/let s:airline_\([_a-zA-Z0-9]\{1,\}\)[^[:alnum:]]\{1,\}\(\#[0-9a-fA-F]\{6\}\)[^[:alnum:]]\{1,\}\(\#[0-9a-fA-F]\{6\}\).*/\1 \2 \3/p' "$file" |
    while ble/bash/read face fg bg; do
      ble/lib/vim-airline/convert-theme/.setface "$face" "$fg" "$bg"
    done
}

# themes/dark.vim (default)
ble/color/setface vim_airline_a_normal      fg=17,bg=190  # fg=#00005f,bg=#dfff00
ble/color/setface vim_airline_b_normal      fg=231,bg=238 # fg=#ffffff,bg=#444444
ble/color/setface vim_airline_c_normal      fg=158,bg=234 # fg=#9cffd3,bg=#202020
ble/color/setface vim_airline_a_insert      fg=17,bg=45   # fg=#00005f,bg=#00dfff
ble/color/setface vim_airline_b_insert      fg=231,bg=27  # fg=#ffffff,bg=#005fff
ble/color/setface vim_airline_c_insert      fg=231,bg=18  # fg=#ffffff,bg=#000080
ble/color/setface vim_airline_a_visual      fg=16,bg=214  # fg=#000000,bg=#ffaf00
ble/color/setface vim_airline_b_visual      fg=16,bg=202  # fg=#000000,bg=#ff5f00
ble/color/setface vim_airline_c_visual      fg=231,bg=52  # fg=#ffffff,bg=#5f0000
ble/color/setface vim_airline_a_inactive    fg=239,bg=234 # fg=#4e4e4e,bg=#1c1c1c
ble/color/setface vim_airline_b_inactive    fg=239,bg=235 # fg=#4e4e4e,bg=#262626
ble/color/setface vim_airline_c_inactive    fg=239,bg=236 # fg=#4e4e4e,bg=#303030
ble/color/setface vim_airline_a_commandline fg=17,bg=40   # fg=#00005f,bg=#00d700
ble/color/setface vim_airline_b_commandline fg=231,bg=238 # fg=#ffffff,bg=#444444
ble/color/setface vim_airline_c_commandline fg=158,bg=234 # fg=#9cffd3,bg=#202020

#------------------------------------------------------------------------------

# unit:_ble_lib_vim_airline_mode

_ble_lib_vim_airline_mode_data=()
_ble_lib_vim_airline_keymap=
_ble_lib_vim_airline_mode=
_ble_lib_vim_airline_rawmode=
function ble/prompt/unit:_ble_lib_vim_airline_mode/update {
  local keymap mode m
  ble/keymap:vi/script/get-vi-keymap
  ble/keymap:vi/script/get-mode
  case $mode in
  (i*)          m='insert' ;;
  ([R]*)      m='replace' ;;
  (*[vVsS]) m='visual' ;;
  (*c)          m='commandline' ;;
  (*n)          m='normal' ;;
  (*)           m='inactive' ;;
  esac

  ble/prompt/unit/add-hash '$_ble_edit_str'
  ble/prompt/unit/add-hash '$_ble_history_INDEX'

  local entry
  ble/history/get-entry "$_ble_history_INDEX"
  [[ $_ble_edit_str != "$entry" ]] && m=${m}_modified

  ble/prompt/unit/assign _ble_lib_vim_airline_keymap  "$keymap"
  ble/prompt/unit/assign _ble_lib_vim_airline_mode    "$m"
  ble/prompt/unit/assign _ble_lib_vim_airline_rawmode "$mode"
  [[ $prompt_unit_changed ]]
}

## unit:_ble_lib_vim_airline_sep_width
##   分割子の幅を計測してキャッシュします。
## @arr _ble_lib_vim_airline_right_sep_width
##   @var _ble_lib_vim_airline_right_sep_width[0] (unit内部使用) version
##   @var _ble_lib_vim_airline_right_sep_width[1] (unit内部使用) hashref
##   @var _ble_lib_vim_airline_right_sep_width[2] (unit内部使用) hash
##   @var _ble_lib_vim_airline_right_sep_width[3] 左sepの幅
##   @var _ble_lib_vim_airline_right_sep_width[4] 右sepの幅
_ble_lib_vim_airline_sep_width_data=()
function ble/prompt/unit:_ble_lib_vim_airline_sep_width/update {
  ble/prompt/unit/add-hash '$bleopt_char_width_version,$bleopt_char_width_mode'
  ble/prompt/unit/add-hash '$bleopt_emoji_version,$bleopt_emoji_width,$bleopt_emoji_opts'

  local w ret x y g

  ((x=0,y=0,g=0))
  LINES=1 COLUMNS=$cols ble/canvas/trace "$bleopt_vim_airline_left_sep" confine
  ((w=x,x=0,y=0,g=0))
  LINES=1 COLUMNS=$cols ble/canvas/trace "$bleopt_vim_airline_left_alt_sep" confine
  ((w=x>w?x:w))
  ble/prompt/unit/add-hash '$bleopt_vim_airline_left_sep'
  ble/prompt/unit/add-hash '$bleopt_vim_airline_left_alt_sep'
  ble/prompt/unit/assign '_ble_lib_vim_airline_sep_width_data[3]' "$w"

  ((x=0,y=0,g=0))
  LINES=1 COLUMNS=$cols ble/canvas/trace "$bleopt_vim_airline_right_sep" confine
  ((w=x,x=0,y=0,g=0))
  LINES=1 COLUMNS=$cols ble/canvas/trace "$bleopt_vim_airline_right_alt_sep" confine
  ((w=x>w?x:w))
  ble/prompt/unit/add-hash '$bleopt_vim_airline_right_sep'
  ble/prompt/unit/add-hash '$bleopt_vim_airline_right_alt_sep'
  ble/prompt/unit/assign '_ble_lib_vim_airline_sep_width_data[4]' "$w"

  [[ $prompt_unit_changed ]]
}

## @fn ble/prompt/backslash:lib/vim-airline/mode/.resolve rawmode
##   @var[out] ret
function ble/prompt/backslash:lib/vim-airline/mode/.resolve {
  local raw=$1
  if ble/gdict#has _ble_lib_vim_airline_mode_map "$raw"; then
    ble/gdict#get _ble_lib_vim_airline_mode_map "$raw"
  else
    case $raw in
    (o)              ble/prompt/backslash:lib/vim-airline/mode/.resolve "$_ble_lib_vim_airline_rawmode" ;;
    ([iR]?*)       ble/prompt/backslash:lib/vim-airline/mode/.resolve "${raw::1}" ;;
    (*?[ncvVsS]) ble/prompt/backslash:lib/vim-airline/mode/.resolve "${raw:${#raw}-1}" ;;
    ()             ble/prompt/backslash:lib/vim-airline/mode/.resolve R ;;
    (R)              ble/prompt/backslash:lib/vim-airline/mode/.resolve i ;;
    ([S])          ble/prompt/backslash:lib/vim-airline/mode/.resolve s ;;
    ([Vs])         ble/prompt/backslash:lib/vim-airline/mode/.resolve v ;;
    ([ivnc])
      ret=
      case $_ble_lib_vim_airline_rawmode in
      (i*) ret=$bleopt_keymap_vi_mode_name_insert ;;
      (R*) ret=$bleopt_keymap_vi_mode_name_replace ;;
      (*) ret=$bleopt_keymap_vi_mode_name_vreplace ;;
      esac
      [[ $_ble_lib_vim_airline_rawmode == [iR]?* ]] &&
        ble/string#tolower "($insert) "

      case $_ble_lib_vim_airline_rawmode in
      (*n)
        if [[ ! $ret ]]; then
          local rex='[[:alnum:]](.*[[:alnum:]])?'
          [[ $bleopt_keymap_vi_mode_string_nmap =~ $rex ]]
          ret=${BASH_REMATCH[0]:-NORMAL}
        fi ;;
      (*v)  ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_visual" ;;
      (*V)  ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_visual $bleopt_keymap_vi_mode_name_line" ;;
      (*) ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_visual $bleopt_keymap_vi_mode_name_block" ;;
      (*s)  ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_select" ;;
      (*S)  ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_select $bleopt_keymap_vi_mode_name_line" ;;
      (*) ret="${ret}${ret:+ }$bleopt_keymap_vi_mode_name_select $bleopt_keymap_vi_mode_name_block" ;;
      (*c)  ret="${ret}${ret:+ }COMMAND" ;;
      esac
      [[ $ret ]] ||
        ble/prompt/backslash:lib/vim-airline/mode/.resolve '?' ;;
    (*) ret='?__' ;;
    esac
  fi
}
function ble/prompt/backslash:lib/vim-airline/mode {
  local ret
  if [[ $_ble_lib_vim_airline_keymap == vi_omap ]]; then
    ble/prompt/backslash:lib/vim-airline/mode/.resolve o
  else
    ble/prompt/backslash:lib/vim-airline/mode/.resolve "$_ble_lib_vim_airline_rawmode"
  fi
  [[ $ret ]] && ble/prompt/print "$ret"
}
function ble/prompt/backslash:lib/vim-airline/gitstatus {
  local "${_ble_contrib_prompt_git_vars[@]/%/=}" # WA #D1570 checked
  if ble/contrib/prompt-git/initialize; then
    ble/contrib/prompt-git/update-head-information
    if [[ $branch ]]; then
      ble/prompt/print "$bleopt_vim_airline_symbol_branch$branch"
    elif [[ $hash ]]; then
      ble/prompt/print "$bleopt_vim_airline_symbol_branch${hash::7}"
    else
      ble/prompt/print '$bleopt_vim_airline_symbol_branch???????'
    fi
    ble/contrib/prompt-git/is-dirty &&
      ble/prompt/print "$bleopt_vim_airline_symbol_dirty"
  fi
}

function ble/prompt/unit:{vim-airline-section}/update {
  local section=$1
  local ref_ps=bleopt_vim_airline_section_$section
  local face=vim_airline_${section}_$_ble_lib_vim_airline_mode
  local prefix=_ble_lib_vim_airline_section_$section

  ble/prompt/unit/add-hash '$_ble_lib_vim_airline_mode_data'
  ble/prompt/unit/add-hash "\$$ref_ps"
  local trace_opts=confine:relative:noscrc:face0="$face":ansi:measure-bbox:measure-gbox
  local prompt_rows=1 prompt_cols=$cols # Note: cols は \q{lib/vim-airline} で設定される
  ble/prompt/unit:{section}/update "$prefix" "${!ref_ps}" "$trace_opts"
}
function ble/prompt/unit:_ble_lib_vim_airline_section_a/update { ble/prompt/unit:{vim-airline-section}/update a; }
function ble/prompt/unit:_ble_lib_vim_airline_section_b/update { ble/prompt/unit:{vim-airline-section}/update b; }
function ble/prompt/unit:_ble_lib_vim_airline_section_c/update { ble/prompt/unit:{vim-airline-section}/update c; }
function ble/prompt/unit:_ble_lib_vim_airline_section_x/update { ble/prompt/unit:{vim-airline-section}/update x; }
function ble/prompt/unit:_ble_lib_vim_airline_section_y/update { ble/prompt/unit:{vim-airline-section}/update y; }
function ble/prompt/unit:_ble_lib_vim_airline_section_z/update { ble/prompt/unit:{vim-airline-section}/update z; }

function ble/lib/vim-airline/.print-section {
  local section=$1
  local ret g0 bg
  ble/color/face2g "vim_airline_${section}_$_ble_lib_vim_airline_mode"; g0=$ret
  ble/color/g#compute-bg "$g0"; bg=$ret

  if [[ $prev_g0 ]]; then
    local sep=bleopt_vim_airline gsep
    if [[ $prev_section == [ab] ]]; then
      sep=${sep}_left
    else
      sep=${sep}_right
    fi
    if [[ $prev_bg == $bg ]]; then
      sep=${sep}_alt_sep
      if [[ $prev_section == [ab] ]]; then
        gsep=$prev_g0
      else
        gsep=$g0
      fi
      ((gsep&=~_ble_color_gflags_DecorationMask|_ble_color_gflags_Revert|_ble_color_gflags_Invisible))
    else
      sep=${sep}_sep gsep=0
      if [[ $sep == *_right_sep ]]; then
        ble/color/g#setfg gsep "$bg"
        ble/color/g#setbg gsep "$prev_bg"
      else
        ble/color/g#setfg gsep "$prev_bg"
        ble/color/g#setbg gsep "$bg"
      fi
    fi
    ble/color/g2sgr-ansi "$gsep"
    ble/prompt/print "$ret${!sep}"
  fi

  local ref_show=_ble_lib_vim_airline_section_${section}_show
  if [[ ${!ref_show} ]]; then
    ble/prompt/unit:{section}/get "_ble_lib_vim_airline_section_$section"; local esc=$ret
    ble/color/g2sgr-ansi "$g0"
    ble/prompt/print "$ret $esc$ret "
  fi
  [[ $section == c ]] && ble/prompt/print $'\r'

  prev_g0=$g0
  prev_bg=$bg
  prev_section=$section
}

function ble/prompt/backslash:lib/vim-airline {
  local "${_ble_contrib_prompt_git_vars[@]/%/=}" # WA #D1570 checked
  ble/prompt/unit#update _ble_lib_vim_airline_mode

  ble/prompt/unit#update _ble_lib_vim_airline_sep_width
  local lwsep=${_ble_lib_vim_airline_sep_width_data[3]:-1}
  local rwsep=${_ble_lib_vim_airline_sep_width_data[4]:-1}

  # Set background color
  local ret bg=0
  ble/color/face2g "vim_airline_c_$_ble_lib_vim_airline_mode"
  ble/color/g#getbg "$ret"
  ble/color/g#setbg bg "$ret"
  ble/color/setface prompt_status_line "g:$bg"

  local cols=$COLUMNS; ((_ble_term_xenl||cols--))
  local unit rest_cols=$((cols-2*lwsep-3*rwsep))
  for unit in _ble_lib_vim_airline_section_{a,c,z,b,y,x}; do
    ble/prompt/unit#update "$unit"

    local gx1=${unit}_gbox[0]; gx1=${!gx1}
    local x2=${unit}_bbox[2]; x2=${!x2}
    local show=
    [[ $gx1 ]] && ((x2+2<=rest_cols)) && ((show=1,rest_cols-=x2+2))
    builtin eval -- "${unit}_show=\$show"
  done

  local section prev_section= prev_g0= prev_bg=
  for section in a b c x y z; do
    ble/lib/vim-airline/.print-section "$section"
  done
}

bleopt -I vim_airline_@
bleopt keymap_vi_mode_show=
bleopt prompt_status_line='\q{lib/vim-airline}'
bleopt prompt_status_align=$'justify=\r'
