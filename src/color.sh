#!/bin/bash

# gflags

_ble_color_gflags_Bold=0x01
_ble_color_gflags_Italic=0x02
_ble_color_gflags_Underline=0x04
_ble_color_gflags_Revert=0x08
_ble_color_gflags_Invisible=0x10
_ble_color_gflags_Strike=0x20
_ble_color_gflags_Blink=0x40
_ble_color_gflags_MaskFg=0x0000FF00
_ble_color_gflags_MaskBg=0x00FF0000
_ble_color_gflags_ShiftFg=8
_ble_color_gflags_ShiftBg=16
_ble_color_gflags_ForeColor=0x1000000
_ble_color_gflags_BackColor=0x2000000

if [[ ! ${bleopt_term_index_colors+set} ]]; then
  if [[ $TERM == xterm* || $TERM == *-256color || $TERM == kterm* ]]; then
    bleopt_term_index_colors=256
  elif [[ $TERM == *-88color ]]; then
    bleopt_term_index_colors=88
  else
    bleopt_term_index_colors=0
  fi
fi

function ble-color-show {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Update and reload ble.sh.' "$@"
    return
  fi

  local cols=16
  local bg bg0 bgN ret gflags=$((_ble_color_gflags_BackColor|_ble_color_gflags_ForeColor))
  for ((bg0=0;bg0<256;bg0+=cols)); do
    ((bgN=bg0+cols,bgN<256||(bgN=256)))
    for ((bg=bg0;bg<bgN;bg++)); do
      ble/color/g2sgr $((gflags|bg<<16))
      printf '%s%03d ' "$ret" "$bg"
    done
    printf '%s\n' "$_ble_term_sgr0"
    for ((bg=bg0;bg<bgN;bg++)); do
      ble/color/g2sgr $((gflags|bg<<16|15<<8))
      printf '%s%03d ' "$ret" "$bg"
    done
    printf '%s\n' "$_ble_term_sgr0"
  done
}

## 関数 ble/color/g2sgr g
##   @param[in] g
##   @var[out] ret
_ble_color_g2sgr=()
function ble/color/g2sgr/.impl {
  local -i g=$1
  local fg=$((g>> 8&0xFF))
  local bg=$((g>>16&0xFF))

  local sgr=0
  ((g&_ble_color_gflags_Bold))      && sgr="$sgr;${_ble_term_sgr_bold:-1}"
  ((g&_ble_color_gflags_Italic))    && sgr="$sgr;${_ble_term_sgr_sitm:-3}"
  ((g&_ble_color_gflags_Underline)) && sgr="$sgr;${_ble_term_sgr_smul:-4}"
  ((g&_ble_color_gflags_Blink))     && sgr="$sgr;${_ble_term_sgr_blink:-5}"
  ((g&_ble_color_gflags_Revert))    && sgr="$sgr;${_ble_term_sgr_rev:-7}"
  ((g&_ble_color_gflags_Invisible)) && sgr="$sgr;${_ble_term_sgr_invis:-8}"
  ((g&_ble_color_gflags_Strike))    && sgr="$sgr;${_ble_term_sgr_strike:-9}"
  if ((g&_ble_color_gflags_ForeColor)); then
    ble/color/.color2sgrfg "$fg"
    sgr="$sgr;$ret"
  fi
  if ((g&_ble_color_gflags_BackColor)); then
    ble/color/.color2sgrbg "$bg"
    sgr="$sgr;$ret"
  fi

  ret="[${sgr}m"
  _ble_color_g2sgr[$1]=$ret
}
function ble/color/g2sgr {
  ret=${_ble_color_g2sgr[$1]}
  [[ $ret ]] || ble/color/g2sgr/.impl "$1"
}
## 関数 ble/color/gspec2g gspec
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
      if ((ret<0)); then
        ((g&=~(_ble_color_gflags_ForeColor|_ble_color_gflags_MaskFg)))
      else
        ((g|=ret<<8|_ble_color_gflags_ForeColor))
      fi ;;
    (bg=*)
      ble/color/.name2color "${entry:3}"
      if ((ret<0)); then
        ((g&=~(_ble_color_gflags_BackColor|_ble_color_gflags_MaskBg)))
      else
        ((g|=ret<<16|_ble_color_gflags_BackColor))
      fi ;;
    (none)
      g=0 ;;
    esac
  done
  ret=$g
}
## 関数 ble/color/g2gspec g
##   @var[out] ret
function ble/color/g2gspec {
  local g=$1 gspec=
  if ((g&_ble_color_gflags_ForeColor)); then
    local fg=$(((g&_ble_color_gflags_MaskFg)>>_ble_color_gflags_ShiftFg))
    ble/color/.color2name "$fg"
    gspec=$gspec,fg=$ret
  fi
  if ((g&_ble_color_gflags_BackColor)); then
    local bg=$(((g&_ble_color_gflags_MaskBg)>>_ble_color_gflags_ShiftBg))
    ble/color/.color2name "$bg"
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

## 関数 ble/color/gspec2sgr gspec
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

## 関数 ble/color/.name2color colorName
##   @var[out] ret
function ble/color/.name2color {
  local colorName=$1
  if [[ ! ${colorName//[0-9]} ]]; then
    ((ret=10#$colorName&255))
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
    (transparent) ret=-1 ;;
    (*)       ret=-1 ;;
    esac
  fi
}
function ble/color/.color2name {
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

## 関数 ble/color/convert-color88-to-color256
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
## 関数 ble/color/convert-color256-to-color88
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

## 関数 ble/color/.color2sgrfg color
## 関数 ble/color/.color2sgrbg color
##   @param[in] color
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
    if ((ccode<_ble_term_colors||bleopt_term_index_colors==256)); then
      ret="${prefix}8;5;$ccode"
    elif ((bleopt_term_index_colors==88)); then
      ble/color/convert-color256-to-color88 "$ccode"
      ret="${prefix}8;5;$ret"
    elif ((ccode<bleopt_term_index_colors)); then
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
  fi
}

## 関数 ble/color/.color2sgrfg color_code
##   @var[out] ret
function ble/color/.color2sgrfg {
  ble/color/.color2sgr-impl "$1" 3
}
## 関数 ble/color/.color2sgrbg color_code
##   @var[out] ret
function ble/color/.color2sgrbg {
  ble/color/.color2sgr-impl "$1" 4
}

#------------------------------------------------------------------------------

## 関数 ble/color/read-sgrspec/.arg-next
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

## 関数 ble-color/read-sgrspec sgrspec opts
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
        ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
      elif ((40<=arg&&arg<48)); then
        local color=$((arg-40))
        ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
      elif ((arg==38)); then
        local j=1 color cspace
        ble/color/read-sgrspec/.arg-next -v cspace
        if ((cspace==5)); then
          ble/color/read-sgrspec/.arg-next -v color
          if [[ :$opts: != *:ansi:* ]] && ((bleopt_term_index_colors==88)); then
            local ret; ble/color/convert-color88-to-color256 "$color"; color=$ret
          fi
          ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
        fi
      elif ((arg==48)); then
        local j=1 color cspace
        ble/color/read-sgrspec/.arg-next -v cspace
        if ((cspace==5)); then
          ble/color/read-sgrspec/.arg-next -v color
          if [[ :$opts: != *:ansi:* ]] && ((bleopt_term_index_colors==88)); then
            local ret; ble/color/convert-color88-to-color256 "$color"; color=$ret
          fi
          ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
        fi
      elif ((arg==39)); then
        ((g&=~(_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor)))
      elif ((arg==49)); then
        ((g&=~(_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor)))
      fi
    elif ((90<=arg&&arg<98)); then
      local color=$((arg-90+8))
      ((g=g&~_ble_color_gflags_MaskFg|_ble_color_gflags_ForeColor|color<<8))
    elif ((100<=arg&&arg<108)); then
      local color=$((arg-100+8))
      ((g=g&~_ble_color_gflags_MaskBg|_ble_color_gflags_BackColor|color<<16))
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

## 関数 ble/color/sgrspec2g str
##   SGRに対する引数から描画属性を構築します。
##   @var[out] ret
function ble/color/sgrspec2g {
  local g=0
  ble/color/read-sgrspec "$1"
  ret=$g
}

## 関数 ble/color/ansi2g str
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
# _ble_color_faces_defface_hook=() # src/def.sh
# _ble_color_faces_setface_hook=() # src/def.sh

# 遅延初期化
if [[ ! $_ble_faces_count ]]; then # reload #D0875
  _ble_faces_count=0
  _ble_faces=()
  _ble_faces_sgr=()
fi

## 関数 ble/color/setface/.check-argument
##   @var[out] ext
function ble/color/setface/.check-argument {
  local rex='^[a-zA-Z0-9_]+$'
  [[ $# == 2 && $1 =~ $rex && $2 ]] && return 0

  local name=${FUNCNAME[1]}
  printf '%s\n' "usage: $name FACE_NAME [TYPE:]SPEC" '' \
         'TYPE' \
         '  Specifies the format of SPEC. The following values are available.' \
         '' \
         '  gspec   Comma separated graphic attribute list' \
         '  g       Integer value' \
         '  face    Face name' \
         '  iface   Face id' \
         '  sgrspec Parameters to the control function SGR' \
         '  ansi    ANSI Sequences'
  ext=2; [[ $# == 1 && $1 == --help ]] && ext=0
  return 1
} >&2
function ble-color-defface {
  local ext; ble/color/setface/.check-argument "$@" || return "$ext"
  ble/color/defface "$@"
}
function ble-color-setface {
  local ext; ble/color/setface/.check-argument "$@" || return "$ext"
  ble/color/setface "$@"
}

# 遅延関数 (後で上書き)
function ble/color/defface   { local q=\' Q="'\''"; ble/array#push _ble_color_faces_defface_hook "ble-color-defface '${1//$q/$Q}' '${2//$q/$Q}'"; }
function ble/color/setface   { local q=\' Q="'\''"; ble/array#push _ble_color_faces_setface_hook "ble-color-setface '${1//$q/$Q}' '${2//$q/$Q}'"; }
function ble/color/face2g    { ble/color/initialize-faces && ble/color/face2g    "$@"; }
function ble/color/face2sgr  { ble/color/initialize-faces && ble/color/face2sgr  "$@"; }
function ble/color/iface2g   { ble/color/initialize-faces && ble/color/iface2g   "$@"; }
function ble/color/iface2sgr { ble/color/initialize-faces && ble/color/iface2sgr "$@"; }

# 遅延初期化子
function ble/color/initialize-faces {
  local _ble_color_faces_initializing=1
  local -a _ble_color_faces_errors=()

  function ble/color/face2g {
    ((g=_ble_faces[_ble_faces__$1]))
  }
  function ble/color/face2sgr {
    builtin eval "sgr=\"\${_ble_faces_sgr[_ble_faces__$1]}\""
  }
  function ble/color/iface2g {
    ((g=_ble_faces[$1]))
  }
  function ble/color/iface2sgr {
    sgr=${_ble_faces_sgr[$1]}
  }

  ## 関数 ble/color/setface/.spec2g spec
  ##   @var[out] ret
  function ble/color/setface/.spec2g {
    local spec=$1
    case $spec in
    (gspec:*)   ble/color/gspec2g "${spec#*:}" ;;
    (g:*)       ret=$((${spec#*:})) ;;
    (face:*)    local g; ble/color/face2g "${spec#*:}" ; ret=$g ;;
    (iface:*)   local g; ble/color/iface2g "${spec#*:}"; ret=$g ;;
    (sgrspec:*) ble/color/sgrspec2g "${spec#*:}" ;;
    (ansi:*)    ble/color/ansi2g "${spec#*:}" ;;
    (*)         ble/color/gspec2g "$spec" ;;
    esac
  }

  function ble/color/defface {
    local name=_ble_faces__$1 spec=$2 ret
    (($name)) && return
    (($name=++_ble_faces_count))
    ble/color/setface/.spec2g "$spec"; _ble_faces[$name]=$ret
    ble/color/g2sgr "$ret"; _ble_faces_sgr[$name]=$ret
  }
  function ble/color/setface {
    local name=_ble_faces__$1 spec=$2 ret
    if [[ ${!name} ]]; then
      ble/color/setface/.spec2g "$spec"; _ble_faces[$name]=$ret
      ble/color/g2sgr "$ret"; _ble_faces_sgr[$name]=$ret
    else
      local message="ble.sh: the specified face \`$1' is not defined."
      if [[ $_ble_color_faces_initializing ]]; then
        ble/array#push _ble_color_faces_errors "$message"
      else
        builtin echo "$message" >&2
      fi
      return 1
    fi
  }

  ble/util/invoke-hook _ble_color_faces_defface_hook
  ble/util/invoke-hook _ble_color_faces_setface_hook

  if ((${#_ble_color_faces_errors[@]})); then
    if ((_ble_edit_attached)) && [[ ! $_ble_textarea_invalidated && $_ble_term_state == internal ]]; then
      IFS=$'\n' eval 'local message="${_ble_color_faces_errors[@]/%/=}"' # WA #D1570 checked
      ble/widget/print "$message"
    else
      printf '%s\n' "${_ble_color_faces_errors[@]}" >&2
    fi
    return 1
  else
    return 0
  fi
}

function ble/color/list-faces {
  local key g ret sgr
  for key in "${!_ble_faces__@}"; do
    local name=${key#_ble_faces__}
    ble/color/iface2sgr $((key))
    ble/color/g2gspec $((_ble_faces[key]))
    ret=$sgr$ret$_ble_term_sgr0
    printf 'ble-color-setface %s %s\n' "$name" "$ret"
  done
}

#------------------------------------------------------------------------------
# ble/highlight/layer

_ble_highlight_layer__list=(plain)
#_ble_highlight_layer__list=(plain RandomColor)

function ble/highlight/layer/update {
  local text=$1
  local -i DMIN=$((BLELINE_RANGE_UPDATE[0]))
  local -i DMAX=$((BLELINE_RANGE_UPDATE[1]))
  local -i DMAX0=$((BLELINE_RANGE_UPDATE[2]))

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
    [[ $g ]] && return
  done
  g=0
}

## 関数 ble/highlight/layer/getg index
##   @param[in] index
##   @var[out] g
function ble/highlight/layer/getg {
  LEVEL=${#_ble_highlight_layer__list[*]} ble/highlight/layer/update/getg "$1"
}

## レイヤーの実装
##   先ず作成するレイヤーの名前を決めます。ここでは <layerName> とします。
##   次に、以下の配列変数と二つの関数を用意します。
##
## 配列 _ble_highlight_layer_<layerName>_buff=()
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
## 関数 ble/highlight/layer:<layerName>/update text player
##   _ble_highlight_layer_<layerName>_buff の内容を更新します。
##
##   @param[in]     text
##   @var  [in]     DMIN DMAX DMAX0
##   @var  [in]     BLELINE_RANGE_UPDATE[]
##     第一引数 text には現在の編集文字列が指定されます。
##     シェル変数 DMIN DMAX DMAX0 には前回の呼出の後の編集文字列の変更位置が指定されます。
##     DMIN<0 の時は前回の呼出から text が変わっていない事を表します。
##     DMIN>=0 の時は、現在の text の DMIN から DMAX までが変更された部分になります。
##     DMAX0 は、DMAX の編集前の対応位置を表します。幾つか例を挙げます:
##     - aaaa の 境界2 に挿入があって aaxxaa となった場合、DMIN DMAX DMAX0 は 2 4 2 となります。
##     - aaxxaa から xx を削除して aaaa になった場合、DMIN DMAX DMAX0 はそれぞれ 2 2 4 となります。
##     - aaxxaa が aayyyaa となった場合 DMIN DMAX DMAX0 は 2 5 4 となります。
##     - aaxxaa が aazzaa となった場合 DMIN DMAX DMAX0 は 2 4 4 となります。
##     BLELINE_RANGE_UPDATE は DMIN DMAX DMAX0 と等価な情報です。
##     DMIN DMAX DMAX0 の三つの値を要素とする配列です。
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
## 関数 ble/highlight/layer:<layerName>/getg index
##   指定した index に対応する描画属性の値を g 値で取得します。
##   前回の ble/highlight/layer:<layerName>/update の呼出に基づく描画属性です。
##   @var[out] g
##     結果は変数 g に設定する事によって返します。
##     より下層のレイヤーの値を引き継ぐ場合には空文字列を設定します: g=
##

#------------------------------------------------------------------------------
# ble/highlight/layer:plain

_ble_highlight_layer_plain_buff=()

## 関数 ble/highlight/layer:plain/update/.getch
##   @var[in,out] ch
function ble/highlight/layer:plain/update/.getch {
  [[ $ch == [' '-'~'] ]] && return
  if [[ $ch == [-] ]]; then
    if [[ $ch == $'\t' ]]; then
      ch=${_ble_string_prototype::it}
    elif [[ $ch == $'\n' ]]; then
      ch=$_ble_term_el$_ble_term_nl
    elif [[ $ch == '' ]]; then
      ch='^?'
    else
      local ret
      ble/util/s2c "$ch" 0
      ble/util/c2s $((ret+64))
      ch="^$ret"
    fi
  else
    # C1 characters
    local ret; ble/util/s2c "$ch"
    if ((0x80<=ret&&ret<=0x9F)); then
      ble/util/c2s $((ret-64))
      ch="M-^$ret"
    fi
  fi
}

## 関数 ble/highlight/layer:<layerName>/update text pbuff
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

## 関数 ble/highlight/layer:plain/getg index
##   @var[out] g
function ble/highlight/layer:plain/getg {
  g=0
}

#------------------------------------------------------------------------------
# ble/highlight/layer:region

function ble/color/faces-defface-hook {
  ble/color/defface region         bg=60,fg=white
  ble/color/defface region_target  bg=153,fg=black
  ble/color/defface region_match   bg=55,fg=white
  ble/color/defface disabled       fg=242
  ble/color/defface overwrite_mode fg=black,bg=51
}
ble/array#push _ble_color_faces_defface_hook ble/color/faces-defface-hook

## @arr _ble_highlight_layer_region_buff
##
## @arr _ble_highlight_layer_region_osel
##   前回の選択範囲の端点を保持する配列です。
##
## @var _ble_highlight_layer_region_osgr
##   前回の選択範囲の着色を保持します。
##
_ble_highlight_layer_region_buff=()
_ble_highlight_layer_region_osel=()
_ble_highlight_layer_region_osgr=

function ble/highlight/layer:region/.update-dirty-range {
  local a=$1 b=$2 p q
  ((a==b)) && return
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
    ble/color/face2sgr "$face"
  fi
  local rlen=${#selection[@]}

  # 変更がない時はそのまま通過
  if ((DMIN<0)); then
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
      if ((k==0)); then
        ble/array#push buff "\"\${$PREV_BUFF[@]::$inext}\""
      elif ((k%2)); then
        ble/array#push buff "\"$sgr\${_ble_highlight_layer_plain_buff[@]:$iprev:$((inext-iprev))}\""
      else
        ble/highlight/layer/update/getg "$iprev"
        ble/color/g2sgr "$g"
        ble/array#push buff "\"$ret\${$PREV_BUFF[@]:$iprev:$((inext-iprev))}\""
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
    ((olen)) || return
    ((_ble_highlight_layer_region_osel[0]<=index&&index<_ble_highlight_layer_region_osel[olen-1])) || return

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
      ble/color/face2g "$face"
    fi
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:disabled

_ble_highlight_layer_disabled_prev=
_ble_highlight_layer_disabled_buff=()

function ble/highlight/layer:disabled/update {
  if [[ $_ble_edit_line_disabled ]]; then
    if ((DMIN>=0)) || [[ ! $_ble_highlight_layer_disabled_prev ]]; then
      local sgr
      ble/color/face2sgr disabled
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
    ble/color/face2g disabled
  fi
}

_ble_highlight_layer_overwrite_mode_index=-1
_ble_highlight_layer_overwrite_mode_buff=()
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
      ble/color/g2sgr "$g"
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
    ble/color/face2g overwrite_mode
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:RandomColor (sample)

_ble_highlight_layer_RandomColor_buff=()
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
