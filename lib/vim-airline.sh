# -*- mode: sh; mode: sh-bash -*-
#
# airline.vim (https://github.com/vim-airline/vim-airline) の模倣実装
#
# 以下の機能については未対応
#
# - airline_mode_map (モードからモード名への対応)
# - 自動省略 (automatic truncation)
#
# * "g:airline_mode_map" is partially supported
#
#   Unsupported mappings
#   
#   'c'     : 'COMMAND'
#   'ic'    : 'INSERT COMPL',
#   'ix'    : 'INSERT COMPL',
#   'multi' : 'MULTI'
#   't'     : 'TERMINAL'
#

ble-import keymap/vi
ble-import contrib/prompt-git

function ble/lib/vim-airline/invalidate { ble/prompt/clear; }

bleopt/declare -v vim_airline_section_a '\q{lib/vim-airline/mode}'
bleopt/declare -v vim_airline_section_b '\q{lib/vim-airline/gitstatus}'
bleopt/declare -v vim_airline_section_c '\w'
bleopt/declare -v vim_airline_section_x 'bash'
bleopt/declare -v vim_airline_section_y '$_ble_util_locale_encoding[unix]'
bleopt/declare -v vim_airline_section_z '\e[1m!\q{lib/vim-airline/history-index}/\!\e[22m'
function bleopt/check:vim_airline_section_a { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_section_b { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_section_c { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_section_x { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_section_x { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_section_y { ble/lib/vim-airline/invalidate; }

bleopt/declare -v vim_airline_left_sep      $'\uE0B0'
bleopt/declare -v vim_airline_left_alt_sep  $'\uE0B1'
bleopt/declare -v vim_airline_right_sep     $'\uE0B2'
bleopt/declare -v vim_airline_right_alt_sep $'\uE0B3'
bleopt/declare -v vim_airline_symbol_branch $'\uE0A0'
bleopt/declare -v vim_airline_symbol_dirty  $'\u26A1'

function bleopt/check:vim_airline_left_sep      { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_left_alt_sep  { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_right_sep     { ble/lib/vim-airline/invalidate; }
function bleopt/check:vim_airline_right_alt_sep { ble/lib/vim-airline/invalidate; }

builtin eval -- "${_ble_util_gdict_declare//NAME/_ble_lib_vim_airline_mode_map}"
ble/gdict#set _ble_lib_vim_airline_mode_map 'i'  'INSERT'
ble/gdict#set _ble_lib_vim_airline_mode_map 'n'  'NORMAL'
ble/gdict#set _ble_lib_vim_airline_mode_map 'in' '(INSERT)'
ble/gdict#set _ble_lib_vim_airline_mode_map 'o'  'OP PENDING'
ble/gdict#set _ble_lib_vim_airline_mode_map 'R'  'REPLACE'
ble/gdict#set _ble_lib_vim_airline_mode_map '' 'V REPLACE'
ble/gdict#set _ble_lib_vim_airline_mode_map 'v'  'VISUAL'
ble/gdict#set _ble_lib_vim_airline_mode_map 'V'  'V-LINE'
ble/gdict#set _ble_lib_vim_airline_mode_map '' 'V-BLOCK'
ble/gdict#set _ble_lib_vim_airline_mode_map 's'  'SELECT'
ble/gdict#set _ble_lib_vim_airline_mode_map 'S'  'S-LINE'
ble/gdict#set _ble_lib_vim_airline_mode_map '' 'S-BLOCK'
ble/gdict#set _ble_lib_vim_airline_mode_map '?'  '------'

ble/color/defface vim_airline_a             fg=17,bg=45,bold
ble/color/defface vim_airline_b             fg=231,bg=27
ble/color/defface vim_airline_c             fg=231,bg=18
ble/color/defface vim_airline_x             ref:vim_airline_c
ble/color/defface vim_airline_y             ref:vim_airline_b
ble/color/defface vim_airline_z             ref:vim_airline_a
ble/color/defface vim_airline_a_normal      ref:vim_airline_a
ble/color/defface vim_airline_b_normal      ref:vim_airline_b
ble/color/defface vim_airline_c_normal      ref:vim_airline_c
ble/color/defface vim_airline_x_normal      ref:vim_airline_c_normal
ble/color/defface vim_airline_y_normal      ref:vim_airline_b_normal
ble/color/defface vim_airline_z_normal      ref:vim_airline_a_normal
ble/color/defface vim_airline_a_insert      ref:vim_airline_a
ble/color/defface vim_airline_b_insert      ref:vim_airline_b
ble/color/defface vim_airline_c_insert      ref:vim_airline_c
ble/color/defface vim_airline_x_insert      ref:vim_airline_c_insert
ble/color/defface vim_airline_y_insert      ref:vim_airline_b_insert
ble/color/defface vim_airline_z_insert      ref:vim_airline_a_insert
ble/color/defface vim_airline_a_replace     ref:vim_airline_a_insert
ble/color/defface vim_airline_b_replace     ref:vim_airline_b_insert
ble/color/defface vim_airline_c_replace     ref:vim_airline_c_insert
ble/color/defface vim_airline_x_replace     ref:vim_airline_c_replace
ble/color/defface vim_airline_y_replace     ref:vim_airline_b_replace
ble/color/defface vim_airline_z_replace     ref:vim_airline_a_replace
ble/color/defface vim_airline_a_visual      ref:vim_airline_a
ble/color/defface vim_airline_b_visual      ref:vim_airline_b
ble/color/defface vim_airline_c_visual      ref:vim_airline_c
ble/color/defface vim_airline_x_visual      ref:vim_airline_c_visual
ble/color/defface vim_airline_y_visual      ref:vim_airline_b_visual
ble/color/defface vim_airline_z_visual      ref:vim_airline_a_visual
ble/color/defface vim_airline_a_commandline ref:vim_airline_a
ble/color/defface vim_airline_b_commandline ref:vim_airline_b
ble/color/defface vim_airline_c_commandline ref:vim_airline_c
ble/color/defface vim_airline_x_commandline ref:vim_airline_c_commandline
ble/color/defface vim_airline_y_commandline ref:vim_airline_b_commandline
ble/color/defface vim_airline_z_commandline ref:vim_airline_a_commandline
ble/color/defface vim_airline_a_inactive    ref:vim_airline_a
ble/color/defface vim_airline_b_inactive    ref:vim_airline_b
ble/color/defface vim_airline_c_inactive    ref:vim_airline_c
ble/color/defface vim_airline_x_inactive    ref:vim_airline_c_inactive
ble/color/defface vim_airline_y_inactive    ref:vim_airline_b_inactive
ble/color/defface vim_airline_z_inactive    ref:vim_airline_a_inactive

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
  sed -n 's/let s:airline_\([a-zA-Z_0-9]\{1,\}\)[^[:alnum:]]\{1,\}\(\#[0-9a-fA-F]\{6\}\)[^[:alnum:]]\{1,\}\(\#[0-9a-fA-F]\{6\}\).*/\1 \2 \3/p' "$file" |
    while read -r face fg bg; do
      ble/lib/vim-airline/convert-theme/.setface "$face" "$fg" "$bg"
    done
}

# themes/dark.vim (default)
ble/color/setface vim_airline_a_normal      fg=17,bg=190,bold  # fg=#00005f,bg=#dfff00
ble/color/setface vim_airline_b_normal      fg=231,bg=238      # fg=#ffffff,bg=#444444
ble/color/setface vim_airline_c_normal      fg=158,bg=234      # fg=#9cffd3,bg=#202020
ble/color/setface vim_airline_a_insert      fg=17,bg=45,bold   # fg=#00005f,bg=#00dfff
ble/color/setface vim_airline_b_insert      fg=231,bg=27       # fg=#ffffff,bg=#005fff
ble/color/setface vim_airline_c_insert      fg=231,bg=18       # fg=#ffffff,bg=#000080
ble/color/setface vim_airline_a_visual      fg=16,bg=214,bold  # fg=#000000,bg=#ffaf00
ble/color/setface vim_airline_b_visual      fg=16,bg=202       # fg=#000000,bg=#ff5f00
ble/color/setface vim_airline_c_visual      fg=231,bg=52       # fg=#ffffff,bg=#5f0000
ble/color/setface vim_airline_a_inactive    fg=239,bg=234,bold # fg=#4e4e4e,bg=#1c1c1c
ble/color/setface vim_airline_b_inactive    fg=239,bg=235      # fg=#4e4e4e,bg=#262626
ble/color/setface vim_airline_c_inactive    fg=239,bg=236      # fg=#4e4e4e,bg=#303030
ble/color/setface vim_airline_a_commandline fg=17,bg=40,bold   # fg=#00005f,bg=#00d700
ble/color/setface vim_airline_b_commandline fg=231,bg=238      # fg=#ffffff,bg=#444444
ble/color/setface vim_airline_c_commandline fg=158,bg=234      # fg=#9cffd3,bg=#202020

#------------------------------------------------------------------------------

_ble_lib_vim_airline_keymap=
_ble_lib_vim_airline_mode=
_ble_lib_vim_airline_rawmode=
function ble/lib/vim-airline/.update-mode {
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
  _ble_lib_vim_airline_keymap=$keymap
  _ble_lib_vim_airline_mode=$m
  _ble_lib_vim_airline_rawmode=$mode
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
    ([ivnc])         ble/prompt/backslash:lib/vim-airline/mode/.resolve '?' ;;
    (*)              ret='???' ;;
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
  if ble/contrib/prompt-git/initialize; then
    local hash branch
    ble/contrib/prompt-git/get-head-information
    if [[ $branch ]]; then
      ble/prompt/print "$bleopt_vim_airline_symbol_branch$branch"
    elif [[ $hash ]]; then
      ble/prompt/print "$bleopt_vim_airline_symbol_branch${hash::7}"
    else
      ble/prompt/print '$bleopt_vim_airline_symbol_branch???????'
    fi
    git diff --quiet || ble/prompt/print "$bleopt_vim_airline_symbol_dirty"
  fi
}

blehook history_onleave+=ble/lib/vim-airline/invalidate
function ble/prompt/backslash:lib/vim-airline/history-index {
  local index
  ble/history/get-index -v index
  ble/canvas/put.draw $((index+1))
}

function ble/lib/vim-airline/.instantiate-section {
  local section=$1
  local bleopt=bleopt_vim_airline_section_$section
  local face=vim_airline_${section}_$_ble_lib_vim_airline_mode
  local save_prefix=_ble_lib_vim_airline_section_${section}_
  local -a save_vars=(show data bbox)
  local "${save_vars[@]/%/=}"
  if [[ ${!bleopt} ]]; then
    local ps=${!bleopt}
    local trace_opts=confine:relative:measure-bbox:noscrc:face0="$face":ansi:measure-gbox
    ble/util/restore-vars "$save_prefix" "${save_vars[@]}"

    local trace_hash esc x y g lc lg
    local x1=${bbox[0]} y1=${bbox[1]} x2=${bbox[2]} y2=${bbox[3]}
    local gx1=${bbox[4]} gy1=${bbox[5]} gx2=${bbox[6]} gy2=${bbox[7]}
    LINES=1 COLUMNS=$cols ble/prompt/.instantiate "$ps" "$trace_opts" "${data[@]:1}"

    local version=N/A
    data=("$version" "$x" "$y" "$g" "$lc" "$lg" "$esc" "$trace_hash")
    bbox=("$x1" "$y1" "$x2" "$y2" "$gx1" "$gy1" "$gx2" "$gy2")
    if [[ $gx1 ]] && ((x2+2<=rest_cols)); then
      ((show=1,rest_cols-=x2+2))
    else
      show=
    fi
  fi
  ble/util/save-vars "$save_prefix" "${save_vars[@]}"
}
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
  local ref_esc=_ble_lib_vim_airline_section_${section}_data[6]
  if [[ ${!ref_show} ]]; then
    ble/color/g2sgr-ansi "$g0"
    ble/prompt/print "$ret ${!ref_esc}$ret "
  fi
  [[ $section == c ]] && ble/prompt/print $'\r'

  prev_g0=$g0
  prev_bg=$bg
  prev_section=$section
}

function ble/prompt/backslash:lib/vim-airline {
  local "${_ble_contrib_prompt_git_vars[@]/%/=}"
  ble/lib/vim-airline/.update-mode
  ble/color/setface prompt_status_line "copy:vim_airline_c_$_ble_lib_vim_airline_mode"

  local cols=$COLUMNS; ((_ble_term_xenl||cols--))
  local section rest_cols=$((cols-4))
  for section in a c z b y x; do
    ble/lib/vim-airline/.instantiate-section "$section"
  done

  local prev_section= prev_g0= prev_bg=
  for section in a b c x y z; do
    ble/lib/vim-airline/.print-section "$section"
  done
}

bleopt keymap_vi_mode_show=
bleopt keymap_vi_mode_update_prompt=1
bleopt prompt_status_line='\q{lib/vim-airline}'
bleopt prompt_status_align=$'justify=\r'
