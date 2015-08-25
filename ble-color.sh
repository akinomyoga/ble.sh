#!/bin/bash

# gflags

declare -i _ble_color_gflags_Bold=0x01
declare -i _ble_color_gflags_Italic=0x02
declare -i _ble_color_gflags_Underline=0x04
declare -i _ble_color_gflags_Revert=0x08
declare -i _ble_color_gflags_Invisible=0x10
declare -i _ble_color_gflags_Strike=0x20
declare -i _ble_color_gflags_Blink=0x40
declare -i _ble_color_gflags_MaskFg=0x0000FF00
declare -i _ble_color_gflags_MaskBg=0x00FF0000
declare -i _ble_color_gflags_ForeColor=0x1000000
declare -i _ble_color_gflags_BackColor=0x2000000

declare -a _ble_color_g2sgr__table=()
function ble-color-g2sgr {
  local _var=ret _ret
  if [[ $1 == -v ]]; then
    _var="$2"
    shift 2
  fi

  _ret="${_ble_color_g2sgr__table[$1]}"
  if [[ -z $_ret ]]; then
    local -i g="$1"
    local fg="$((g>> 8&0xFF))"
    local bg="$((g>>16&0xFF))"

    local _sgr=0
    ((g&_ble_color_gflags_Bold))      && _sgr="$_sgr;${_ble_term_sgr_bold:-1}"
    ((g&_ble_color_gflags_Italic))    && _sgr="$_sgr;${_ble_term_sgr_sitm:-3}"
    ((g&_ble_color_gflags_Underline)) && _sgr="$_sgr;${_ble_term_sgr_smul:-4}"
    ((g&_ble_color_gflags_Blink))     && _sgr="$_sgr;${_ble_term_sgr_blink:-5}"
    ((g&_ble_color_gflags_Revert))    && _sgr="$_sgr;${_ble_term_sgr_rev:-7}"
    ((g&_ble_color_gflags_Invisible)) && _sgr="$_sgr;${_ble_term_sgr_invis:-8}"
    ((g&_ble_color_gflags_Strike))    && _sgr="$_sgr;${_ble_term_sgr_strike:-9}"
    if ((g&_ble_color_gflags_ForeColor)); then
      .ble-color.color2sgrfg -v "$_var" "$fg"
      _sgr="$_sgr;${!_var}"
    fi
    if ((g&_ble_color_gflags_BackColor)); then
      .ble-color.color2sgrbg -v "$_var" "$bg"
      _sgr="$_sgr;${!_var}"
    fi
    
    _ret="[${_sgr}m"
    _ble_color_g2sgr__table[$1]="$_ret"
  fi

  builtin eval "$_var=\"\$_ret\""
}
function ble-color-gspec2g {
  local _var=ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi
  
  local _g=0 entry
  for entry in ${1//,/ }; do
    case "$entry" in
    (bold)      ((_g|=_ble_color_gflags_Bold)) ;;
    (underline) ((_g|=_ble_color_gflags_Underline)) ;;
    (blink)     ((_g|=_ble_color_gflags_Blink)) ;;
    (invis)     ((_g|=_ble_color_gflags_Invisible)) ;;
    (reverse)   ((_g|=_ble_color_gflags_Revert)) ;;
    (strike)    ((_g|=_ble_color_gflags_Strike)) ;;
    (italic)    ((_g|=_ble_color_gflags_Italic)) ;;
    (standout)  ((_g|=_ble_color_gflags_Revert|_ble_color_gflags_Bold)) ;;
    (fg=*)
      .ble-color.name2color -v "$_var" "${entry:3}"
      if ((_var<0)); then
        ((_g&=~(_ble_color_gflags_ForeColor|_ble_color_gflags_MaskFg)))
      else
        ((_g|=_var<<8|_ble_color_gflags_ForeColor))
      fi ;;
    (bg=*)
      .ble-color.name2color -v "$_var" "${entry:3}"
      if ((_var<0)); then
        ((_g&=~(_ble_color_gflags_BackColor|_ble_color_gflags_MaskBg)))
      else
        ((_g|=_var<<16|_ble_color_gflags_BackColor))
      fi ;;
    (none)
      _g=0 ;;
    esac
  done

  builtin eval "$_var=\"\$_g\""
}

function ble-color-gspec2sgr {
  local _var=ret __sgr=0 entry
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  for entry in ${1//,/ }; do
    case "$entry" in
    (bold)      __sgr="$__sgr;1" ;;
    (underline) __sgr="$__sgr;4" ;;
    (standout)  __sgr="$__sgr;7" ;;
    (fg=*)
      .ble-color.name2color "${entry:3}"
      .ble-color.color2sgrfg "$ret"
      __sgr="$__sgr;$ret" ;;
    (bg=*)
      .ble-color.name2color "${entry:3}"
      .ble-color.color2sgrbg "$ret"
      __sgr="$__sgr;$ret" ;;
    (none)
      __sgr=0 ;;
    esac
  done

  builtin eval "$_var=\"[\${__sgr}m\""
}

function .ble-color.name2color {
  local _var=ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  local colorName="$1" _ret
  if [[ $colorName == $((colorName)) ]]; then
    ((_ret=colorName<0?-1:colorName))
  else
    case "$colorName" in
    (black)   _ret=0 ;;
    (brown)   _ret=1 ;;
    (green)   _ret=2 ;;
    (olive)   _ret=3 ;;
    (navy)    _ret=4 ;;
    (purple)  _ret=5 ;;
    (teal)    _ret=6 ;;
    (silver)  _ret=7 ;;

    (gray)    _ret=8 ;;
    (red)     _ret=9 ;;
    (lime)    _ret=10 ;;
    (yellow)  _ret=11 ;;
    (blue)    _ret=12 ;;
    (magenta) _ret=13 ;;
    (cyan)    _ret=14 ;;
    (white)   _ret=15 ;;

    (orange)  _ret=202 ;;
    (transparent) _ret=-1 ;;
    (*)       _ret=-1 ;;
    esac
  fi

  builtin eval "$_var=\"\$_ret\""
}
function .ble-color.color2sgrfg {
  local _var=ret _ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  local ccode="$1"
  if ((ccode<0)); then
    _ret=39
  elif ((ccode<16)); then
    _ret="${_ble_term_sgr_af[ccode]}"
  elif ((ccode<256)); then
    _ret="38;5;$ccode"
  fi

  builtin eval "$_var=\"\$_ret\""
}
function .ble-color.color2sgrbg {
  local _var=ret _ret
  if [[ $1 == -v ]]; then
    _var=$2
    shift 2
  fi

  local ccode="$1"
  if ((ccode<0)); then
    _ret=49
  elif ((ccode<16)); then
    _ret="${_ble_term_sgr_ab[ccode]}"
  elif ((ccode<256)); then
    _ret="48;5;$ccode"
  fi

  builtin eval "$_var=\"\$_ret\""
}


_ble_faces_count=0
_ble_faces=()
_ble_faces_sgr=()
function ble-color-defface {
  local name="_ble_faces__$1" gspec="$2"
  (($name||($name=++_ble_faces_count)))
  ble-color-gspec2g -v "_ble_faces[$name]" "$gspec"
  ble-color-g2sgr -v "_ble_faces_sgr[$name]" "${_ble_faces[$name]}"
}
function ble-color-setface {
  local name="_ble_faces__$1" gspec="$2"
  if [[ ${!name} ]]; then
    ble-color-gspec2g -v "_ble_faces[$name]" "$gspec"
    ble-color-g2sgr -v "_ble_faces_sgr[$name]" "${_ble_faces[$name]}"
  else
    echo "ble.sh: the specified face \`$1' is not defined." >&2
    return 1
  fi
}
function ble-color-face2g {
  ((g=_ble_faces[_ble_faces__$1]))
}
function ble-color-face2sgr {
  builtin eval "sgr=\"\${_ble_faces_sgr[_ble_faces__$1]}\""
}
function ble-color-iface2g {
  ((g=_ble_faces[$1]))
}
function ble-color-iface2sgr {
  sgr="${_ble_faces_sgr[$1]}"
}

## 関数 _ble_region_highlight_table;  ble-region_highlight-append triplets ; _ble_region_highlight_table
function ble-region_highlight-append {
  while [ $# -gt 0 ]; do
    local -a triplet
    triplet=($1)
    local ret; ble-color-gspec2g "${triplet[2]}"; local g="$ret"
    local -i i="${triplet[0]}" iN="${triplet[1]}"
    for ((;i<iN;i++)); do
      _ble_region_highlight_table[$i]="$g"
    done
    shift
  done
}

#------------------------------------------------------------------------------

function ble-syntax-highlight+region {
  if [[ $_ble_edit_mark_active ]]; then
    if ((_ble_edit_mark>_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_ind $_ble_edit_mark bg=60,fg=white"
    elif ((_ble_edit_mark<_ble_edit_ind)); then
      ble-region_highlight-append "$_ble_edit_mark $_ble_edit_ind bg=60,fg=white"
    fi
  fi
}

function ble-syntax-highlight+test {
  local text="$1"
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    local tail="${text:i}" rex
    if [[ $mode == cmd ]]; then
      if rex='^[_a-zA-Z][_a-zA-Z0-9]*=' && [[ $tail =~ $rex ]]; then
        # 変数への代入
        local var="${tail%%=*}"
        ble-region_highlight-append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        mode=rhs
      elif rex='^[_a-zA-Z][_a-zA-Z0-9]*\[[^]]+\]=' && [[ $tail =~ $rex ]]; then
        # 配列変数への代入
        local var="${tail%%\[*}"
        ble-region_highlight-append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        local tmp="${tail%%\]=*}"
        local ind="${tmp#*\[}"
        ble-region_highlight-append "$i $((i+${#ind})) fg=green"
        ((i+=${#var}+1))
  
        mode=rhs
      elif rex='^[^ 	"'\'']+([ 	]|$)' && [[ $tail =~ $rex ]]; then
        local cmd="${tail%%[	 ]*}" btype
        ble/util/type btype "$cmd"
        case "$btype:$cmd" in
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
      else
        ((i++))
      fi
    else
      ((i++))
    fi
  done

  ble-syntax-highlight+region "$@"

  # ble-region_highlight-append "${#text1} $((${#text1}+1)) standout"
}

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
  local rex IFS=$' \t\n'
  local text="$1"
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    local tail="${text:i}"
    if [[ "$mode" == cmd ]]; then
      if rex='^([_a-zA-Z][_a-zA-Z0-9]*)\+?=' && [[ $tail =~ $rex ]]; then
        # for bash-3.1 ${#arr[n]} bug
        local rematch1="${BASH_REMATCH[1]}"

        # local var="${BASH_REMATCH[0]::-1}"
        ble-region_highlight-append "$i $((i+$rematch1)) fg=orange"
        ((i+=${#BASH_REMATCH}))
        mode=rhs
        continue
      elif rex='^([^'"$IFS"'|&;()<>'\''"\]|\\.)+' && [[ $tail =~ $rex ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう

        local _0="${BASH_REMATCH[0]}"
        builtin eval "local cmd=${_0}"

        # この部分の判定で fork を沢山する \if 等に対しては 4fork+2exec になる。
        # ■キャッシュ(accept-line 時に clear)するなどした方が良いかもしれない。
        local type; ble-syntax-highlight+default/type "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
        if [[ "$type" = alias && "$cmd" != "$_0" ]]; then
          # alias を \ で無効化している場合
          # → unalias して再度 check (2fork)
          type=$(
            unalias "$cmd"
            ble-syntax-highlight+default/type "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
            builtin echo -n "$type")
        elif [[ "$type" = keyword && "$cmd" != "$_0" ]]; then
          # keyword (time do if function else elif fi の類) を \ で無効化している場合
          # →file, function, builtin, jobs のどれかになる。以下 3fork+2exec
          if [[ ! ${cmd##%*} ]] && jobs "$cmd" &>/dev/null; then
            # %() { :; } として 関数を定義できるが jobs の方が優先される。
            # (% という名の関数を呼び出す方法はない?)
            # でも % で始まる物が keyword になる事はそもそも無いような。
            type=jobs
          elif ble/util/isfunction "$cmd"; then
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

        ((i+=${#BASH_REMATCH}))
        if rex='^keyword:([!{]|time|do|if|then|else|while|until)$|^builtin:eval$' && [[ "$type:$cmd" =~ $rex ]]; then
          mode=cmd
        else
          mode=arg
        fi

        continue
      fi
    elif [[ $mode == arg ]]; then
      if rex='^([^"$'"$IFS"'|&;()<>'\''"`\]|\\.)+' && [[ $tail =~ $rex ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう
        local arg="${BASH_REMATCH[0]}"

        local file="$arg"
        rex='^~' && [[ ! -e $file && $file =~ $rex ]] && file="$HOME${file:1}"
        if [[ -d $file ]]; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=navy,underline"
        elif [[ -h $file ]]; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=teal,underline"
        elif [[ -x $file ]]; then
          ble-region_highlight-append "$i $((i+${#arg})) fg=green,underline"
        elif [[ -f $file ]]; then
          ble-region_highlight-append "$i $((i+${#arg})) underline"
        fi

        ((i+=${#arg}))
        continue
      fi
    fi

    # /^'([^'])*'|^\$'([^\']|\\.)*'|^`([^\`]|\\.)*`|^\\./
    if rex='^'\''([^'\''])*'\''|^\$'\''([^\'\'']|\\.)*'\''|^`([^\`]|\\.)*`|^\\.' && [[ $tail =~ $rex ]]; then
      ble-region_highlight-append "$i $((i+${#BASH_REMATCH})) fg=green"
      ((i+=${#BASH_REMATCH}))
      mode=arg_
      continue
    elif rex='^['"$IFS"']+' && [[ $tail =~ $rex ]]; then
      ((i+=${#BASH_REMATCH}))
      local spaces="${BASH_REMATCH[0]}"
      if [[ "$spaces" =~ $'\n' ]]; then
        mode=cmd
      else
        [[ "$mode" = arg_ ]] && mode=arg
      fi
      continue
    elif rex='^;;?|^;;&$|^&&?|^\|\|?' && [[ $tail =~ $rex ]]; then
      if [[ $mode = cmd ]]; then
        ble-region_highlight-append "$i $((i+${#BASH_REMATCH})) bg=224"
      fi
      ((i+=${#BASH_REMATCH}))
      mode=cmd
      continue
    elif rex='^(&?>>?|<>?|[<>]&)' && [[ $tail =~ $rex ]]; then
      ble-region_highlight-append "$i $((i+${#BASH_REMATCH})) bold"
      ((i+=${#BASH_REMATCH}))
      mode=arg
      continue
    elif rex='^(' && [[ $tail =~ $rex ]]; then
      ((i+=${#BASH_REMATCH}))
      mode=cmd
      continue
    fi
    # 他 "...", ${}, $... arg と共通

    ((i++))
    # a[]=... の引数は、${} や "" を考慮に入れるだけでなく [] の数を数える。
  done

  ble-syntax-highlight+region "$@"
}

#------------------------------------------------------------------------------
# ble-highlight-layer

_ble_highlight_layer__buff=()
_ble_highlight_layer__list=(plain adapter)

#_ble_highlight_layer__list=(plain)
#_ble_highlight_layer__list=(plain RandomColor)

function ble-highlight-layer/update {
  local text="$1"
  local -ir DMIN="$((BLELINE_RANGE_UPDATE[0]))"
  local -ir DMAX="$((BLELINE_RANGE_UPDATE[1]))"
  local -ir DMAX0="$((BLELINE_RANGE_UPDATE[2]))"

  local PREV_BUFF=_ble_highlight_layer_plain_buff
  local PREV_UMIN=-1
  local PREV_UMAX=-1
  local layer player=plain LEVEL
  local nlevel="${#_ble_highlight_layer__list[@]}"
  for((LEVEL=0;LEVEL<nlevel;LEVEL++)); do
    layer="${_ble_highlight_layer__list[LEVEL]}"

    "ble-highlight-layer:$layer/update" "$text" "$player"
    # echo "PREV($LEVEL) $PREV_UMIN $PREV_UMAX" >> 1.tmp

    player="$layer"
  done

  HIGHLIGHT_BUFF="$PREV_BUFF"
  HIGHLIGHT_UMIN="$PREV_UMIN"
  HIGHLIGHT_UMAX="$PREV_UMAX"
}

function ble-highlight-layer/update/add-urange {
  local umin="$1" umax="$2"
  (((PREV_UMIN<0||PREV_UMIN>umin)&&(PREV_UMIN=umin),
    (PREV_UMAX<0||PREV_UMAX<umax)&&(PREV_UMAX=umax)))
}
function ble-highlight-layer/update/shift {
  local __dstArray="$1"
  local __srcArray="${2:-$__dstArray}"
  if ((DMIN>=0)); then
    _ble_util_array_prototype.reserve "$((DMAX-DMIN))"
    builtin eval "
    $__dstArray=(
      \"\${$__srcArray[@]::DMIN}\"
      \"\${_ble_util_array_prototype[@]::DMAX-DMIN}\"
      \"\${$__srcArray[@]:DMAX0}\")"
  else
    [[ $__dstArray != "$__srcArray" ]] && builtin eval "$__dstArray=(\"\${$__srcArray[@]}\")"
  fi
}

function ble-highlight-layer/update/getg {
  g=
  local LEVEL="$LEVEL"
  while ((--LEVEL>=0)); do
    "ble-highlight-layer:${_ble_highlight_layer__list[LEVEL]}/getg" "$1"
    [[ $g ]] && return
  done
  g=0
}

function ble-highlight-layer/getg {
  if [[ $1 == -v ]]; then
    if [[ $2 != g ]]; then
      local g
      ble-highlight-layer/getg "$3"
      builtin eval "$2=\"\$g\""
      return
    else
      shift 2
    fi
  fi

  LEVEL="${#_ble_highlight_layer__list[*]}" ble-highlight-layer/update/getg "$1"
}

## レイヤーの実装
##   先ず作成するレイヤーの名前を決めます。ここでは <layerName> とします。
##   次に、以下の配列変数と二つの関数を用意します。
##
## 配列 _ble_highlight_layer_<layerName>_buff=()
##
##   グローバルに定義する配列変数です。
##   後述の ble-highlight-layer:<layerName>/update が呼ばれた時に更新します。
##
##   各要素は編集文字列の各文字に対応しています。
##   各要素は "<SGR指定><表示文字>" の形式になります。
##
##   "SGR指定" には描画属性を指定するエスケープシーケンスを指定します。
##   "SGR指定" は前の文字と同じ描画属性の場合には省略可能です。
##   この描画属性は現在のレイヤーとその下層にある全てのレイヤーの結果を総合した物になります。
##   この描画属性は後述する ble-highlight-layer/getg 関数によって得られる
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
## 関数 ble-highlight-layer:<layerName>/update text player
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
##   @var  [in,out] LAYER_UMIN
##   @var  [in,out] LAYER_UMAX
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
##     ble-highlight-layer/update/shift 関数も参照して下さい。
##
## 関数 ble-highlight-layer:<layerName>/getg index
##   指定した index に対応する描画属性の値を g 値で取得します。
##   前回の ble-highlight-layer:<layerName>/update の呼出に基づく描画属性です。
##   @var[out] g
##     結果は変数 g に設定する事によって返します。
##     より下層のレイヤーの値を引き継ぐ場合には空文字列を設定します: g=
##

#------------------------------------------------------------------------------
# ble-highlight-layer:plain

_ble_highlight_layer_plain_buff=()

function ble-highlight-layer:plain/update/.getch {
  if [[ $ch == [-] ]]; then
    if [[ $ch == $'\t' ]]; then
      ch="${_ble_util_string_prototype::it}"
    elif [[ $ch == $'\n' ]]; then
      ch=$'\e[K\n'
    else
      .ble-text.s2c "$ch" 0
      .ble-text.c2s $((ret+64))
      ch="^$ret"
    fi
  elif [[ $ch == [$''-$'\302\237'] ]]; then
    # ※\302\237 は 0x9F の utf8 表現
    if [[ $ch == '' ]]; then
      ch='^?'
    else
      .ble-text.s2c "$ch" 0
      .ble-text.c2s $((ret-64))
      ch="M-^$ret"
    fi
  fi
}

## 関数 ble-highlight-layer:<layerName>/update text pbuff
function ble-highlight-layer:plain/update {
  if ((DMIN>=0)); then
    ble-highlight-layer/update/shift _ble_highlight_layer_plain_buff

    local i text="$1" ch
    local it="$_ble_term_it" ret
    for((i=DMIN;i<DMAX;i++)); do
      ch="${text:i:1}"

      # LC_COLLATE for cygwin collation
      LC_COLLATE=C ble-highlight-layer:plain/update/.getch

      _ble_highlight_layer_plain_buff[i]="$ch"
    done
  fi

  PREV_BUFF=_ble_highlight_layer_plain_buff
  ((PREV_UMIN=DMIN,PREV_UMAX=DMAX))
}

## 関数 ble-highlight-layer:plain/getg index
##   @var[out] g
function ble-highlight-layer:plain/getg {
  g=0
}

#------------------------------------------------------------------------------
# ble-highlight-layer:adapter

## 古い実装からの adapter
_ble_highlight_layer_adapter_buff=()
_ble_highlight_layer_adapter_table=()
function ble-highlight-layer:adapter/update {
  local text="$1" player="$2"

  # update g table
  local LAYER_UMIN LAYER_UMAX
  local -a _ble_region_highlight_table
  ble-highlight-layer/update/shift _ble_region_highlight_table _ble_highlight_layer_adapter_table
  if [[ $bleopt_syntax_highlight_mode ]]; then
    # LAYER_UMIN を設定しない highlight_mode の場合はそのまま。
    # LAYER_UMIN を設定する highlight_mode の場合は参照せずに上書きされる。
    LAYER_UMIN=0 LAYER_UMAX="$iN"
    "ble-syntax-highlight+$bleopt_syntax_highlight_mode" "$text"
  else
    LAYER_UMIN="$iN" LAYER_UMAX=0
  fi
  _ble_highlight_layer_adapter_table=("${_ble_region_highlight_table[@]}")

  # 描画文字を更新する範囲 [i1,i2]
  #   text[i2] (更新範囲の次の文字) の SGR に影響を与えない為、
  #   実際の更新は text[i2] に対しても行う。
  ((PREV_UMIN>=0&&LAYER_UMIN>PREV_UMIN&&(LAYER_UMIN=PREV_UMIN),
    PREV_UMAX>=0&&LAYER_UMAX<PREV_UMAX&&(LAYER_UMAX=PREV_UMAX)))
  local i1="$LAYER_UMIN" i2="$LAYER_UMAX"
  ((i2>=iN&&(i2=iN-1)))

  # update char buffer
  ble-highlight-layer/update/shift _ble_highlight_layer_adapter_buff
  local i g gprev=0 ctx=0 ret
  ((i1>0)) && ble-highlight-layer/getg -v gprev "$((i1-1))"
  # .ble-line-info.draw-text "layer:adapter u = $i1-$i2"
  for ((i=i1;i<=i2;i++)); do
    local ch
    if [[ ${_ble_region_highlight_table[i]} ]]; then
      ch="${_ble_highlight_layer_plain_buff[i]}"
      ((g=_ble_region_highlight_table[i]))
      if ((ctx!=0||g!=gprev)); then
        ((ctx=0,gprev=g))
        ble-color-g2sgr "$g"
        ch="$ret$ch"
      fi
    else
      builtin eval "ch=\"\${$PREV_BUFF[i]}\""
      if ((ctx!=1)); then
        ((ctx=1,gprev=-1))
        ble-highlight-layer/update/getg
        ble-color-g2sgr "$g"
        ch="$ret$ch"
      fi
    fi

    _ble_highlight_layer_adapter_buff[i]="$ch"
  done

  PREV_BUFF=_ble_highlight_layer_adapter_buff
  if ((LAYER_UMIN<LAYER_UMAX)); then
    ((PREV_UMIN=LAYER_UMIN,PREV_UMAX=LAYER_UMAX))
  else
    ((PREV_UMIN=-1,PREV_UMAX=-1))
  fi
}
function ble-highlight-layer:adapter/getg {
  # 描画属性がない時は _ble_region_highlight_table[i]
  # には空文字列が入っているのでOK
  g="${_ble_highlight_layer_adapter_table[$1]}"
}

#------------------------------------------------------------------------------
# ble-highlight-layer:region

ble-color-defface region bg=60,fg=white

_ble_highlight_layer_region_buff=()
_ble_highlight_layer_region_omin=-1
_ble_highlight_layer_region_omax=-1

function ble-highlight-layer:region/update-dirty-range {
  local -i a="$1" b="$2" p q
  ((a==b)) && return
  (((a<b?(p=a,q=b):(p=b,q=a)),
    (umin<0||umin>p)&&(umin=p),
    (umax<0||umax<q)&&(umax=q)))
}

function ble-highlight-layer:region/update {
  local omin omax
  ((omin=_ble_highlight_layer_region_omin,
    omax=_ble_highlight_layer_region_omax))
  if ((DMIN>=0)); then
    ((omin>=DMAX0&&(omin+=DMAX-DMAX0),
      omax>=DMAX0&&(omax+=DMAX-DMAX0)))
  fi

  local rmin rmax
  if [[ $_ble_edit_mark_active ]]; then
    if ((_ble_edit_mark>_ble_edit_ind)); then
      ((rmin=_ble_edit_ind,rmax=_ble_edit_mark))
    elif ((_ble_edit_mark<_ble_edit_ind)); then
      ((rmin=_ble_edit_mark,rmax=_ble_edit_ind))
    else
      ((rmin=-1,rmax=-1))
    fi
  else
    ((rmin=-1,rmax=-1))
  fi

  local umin=-1 umax=-1
  if ((rmin<rmax)); then
    # 選択範囲がある時

    local sgr
    ble-color-face2sgr region
    local g sgr2
    ble-highlight-layer/update/getg "$rmax"
    ble-color-g2sgr -v sgr2 "$g"
    builtin eval "_ble_highlight_layer_region_buff=(
      \"\${$PREV_BUFF[@]::rmin}\"
      \"\$sgr\"\"\${_ble_highlight_layer_plain_buff[@]:rmin:rmax-rmin}\"
      \"\$sgr2\"\"\${$PREV_BUFF[@]:rmax}\")"
    PREV_BUFF=_ble_highlight_layer_region_buff

    # DMIN-DMAX の間
    if ((DMIN>=0)); then
      ble-highlight-layer:region/update-dirty-range DMIN DMAX
    fi

    # 選択範囲の変更
    if ((omin>=0)); then
      # 端点の移動
      ble-highlight-layer:region/update-dirty-range omin rmin
      ble-highlight-layer:region/update-dirty-range omax rmax
    else
      # 新規の選択
      ble-highlight-layer:region/update-dirty-range rmin rmax
    fi

    # 下層の変更 (rmin ～ rmax は表には反映されない)
    local pmin pmax
    ((pmin=PREV_UMIN,pmax=PREV_UMAX,
      rmin<=pmin&&pmin<rmax&&(pmin=rmax),
      rmin<pmax&&pmax<=rmax&&(pmax=rmin)))
    ble-highlight-layer:region/update-dirty-range pmin pmax
  else
    # 選択範囲がない時

    # 下層の変更
    umin="$PREV_UMIN" umax="$PREV_UMAX"

    # 選択解除の範囲
    ble-highlight-layer:region/update-dirty-range omin omax
  fi
    
  ((_ble_highlight_layer_region_omin=rmin,
    _ble_highlight_layer_region_omax=rmax,
    PREV_UMIN=umin,
    PREV_UMAX=umax))
}

function ble-highlight-layer:region/getg {
  if [[ $_ble_edit_mark_active ]]; then
    if ((_ble_highlight_layer_region_omin<=$1&&$1<_ble_highlight_layer_region_omax)); then
      ble-color-face2g region
    fi
  fi
}

#------------------------------------------------------------------------------
# ble-highlight-layer:disabled

ble-color-defface disabled fg=gray

_ble_highlight_layer_disabled_prev=
_ble_highlight_layer_disabled_buff=()

function ble-highlight-layer:disabled/update {
  if [[ $_ble_edit_line_disabled ]]; then
    if ((DMIN>=0)) || [[ ! $_ble_highlight_layer_disabled_prev ]]; then
      local sgr
      ble-color-face2sgr disabled
      _ble_highlight_layer_disabled_buff=("$sgr""${_ble_highlight_layer_plain_buff[@]}")
    fi
    PREV_BUFF=_ble_highlight_layer_disabled_buff

    if [[ $_ble_highlight_layer_disabled_prev ]]; then
      PREV_UMIN="$DMIN" PREV_UMAX="$DMAX"
    else
      PREV_UMIN=0 PREV_UMAX="${#1}"
    fi
  else
    if [[ $_ble_highlight_layer_disabled_prev ]]; then
      PREV_UMIN=0 PREV_UMAX="${#1}"
    fi
  fi

  _ble_highlight_layer_disabled_prev="$_ble_edit_line_disabled"
}

function ble-highlight-layer:disabled/getg {
  if [[ $_ble_highlight_layer_disabled_prev ]]; then
    ble-color-face2g disabled
  fi
}

ble-color-defface overwrite_mode fg=black,bg=51

_ble_highlight_layer_overwrite_mode_index=-1
_ble_highlight_layer_overwrite_mode_buff=()
function ble-highlight-layer:overwrite_mode/update {
  local oindex="$_ble_highlight_layer_overwrite_mode_index"
  if ((DMIN>=0)); then
    if ((oindex>=DMAX0)); then
      ((oindex+=DMAX-DMAX0))
    elif ((oindex>=DMIN)); then
      oindex=-1
    fi
  fi

  local index=-1
  if [[ $_ble_edit_overwrite_mode ]]; then
    local next="${_ble_edit_str:_ble_edit_ind:1}"
    if [[ $next && $next != [$'\n\t'] ]]; then
      index="$_ble_edit_ind"

      local g sgr

      # PREV_BUFF の内容をロード
      if ((DMIN<0&&oindex>=0)); then
        # 前回の結果が残っている場合
        ble-highlight-layer/update/getg "$oindex"
        ble-color-g2sgr -v sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[oindex]="$sgr${_ble_highlight_layer_plain_buff[oindex]}"
      else
        # コピーした方が速い場合
        builtin eval "_ble_highlight_layer_overwrite_mode_buff=(\"\${$PREV_BUFF[@]}\")"
      fi
      PREV_BUFF=_ble_highlight_layer_overwrite_mode_buff

      # 1文字着色
      # ble-highlight-layer/update/getg "$index"
      # ((g^=_ble_color_gflags_Revert))
      ble-color-face2g overwrite_mode
      ble-color-g2sgr -v sgr "$g"
      _ble_highlight_layer_overwrite_mode_buff[index]="$sgr${_ble_highlight_layer_plain_buff[index]}"
      if ((index+1<${#1})); then
        ble-highlight-layer/update/getg "$((index+1))"
        ble-color-g2sgr -v sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[index+1]="$sgr${_ble_highlight_layer_plain_buff[index+1]}"
      fi
    fi
  fi

  if ((index>=0)); then
    builtin echo -n $'\e[?25l'
  else
    builtin echo -n $'\e[?25h'
  fi

  if ((index!=oindex)); then
    ((oindex>=0)) && ble-highlight-layer/update/add-urange "$oindex" "$((oindex+1))"
    ((index>=0)) && ble-highlight-layer/update/add-urange "$index" "$((index+1))"
  fi
  
  _ble_highlight_layer_overwrite_mode_index="$index"
}
function ble-highlight-layer:overwrite_mode/getg {
  local index="$_ble_highlight_layer_overwrite_mode_index"
  if ((index>=0&&index==$1)); then
    # ble-highlight-layer/update/getg "$1"
    # ((g^=_ble_color_gflags_Revert))
    ble-color-face2g overwrite_mode
  fi
}

#------------------------------------------------------------------------------
# ble-highlight-layer:RandomColor (sample)

_ble_highlight_layer_RandomColor_buff=()
function ble-highlight-layer:RandomColor/update {
  local text="$1" sgr i
  _ble_highlight_layer_RandomColor_buff=()
  for ((i=0;i<${#text};i++)); do
    # _ble_highlight_layer_RandomColor_buff[i] に "<sgr><表示文字>" を設定する。
    # "<表示文字>" は ${_ble_highlight_layer_plain_buff[i]} でなければならない
    # (或いはそれと文字幅が同じ物…ただそれが反映される保証はない)。
    ble-color-gspec2sgr -v sgr "fg=$((RANDOM%256))"
    _ble_highlight_layer_RandomColor_buff[i]="$sgr${_ble_highlight_layer_plain_buff[i]}"
  done
  PREV_BUFF=_ble_highlight_layer_RandomColor_buff
  ((PREV_UMIN=0,PREV_UMAX=${#text}))
}
function ble-highlight-layer:RandomColor/getg {
  # ここでは乱数を返しているが、実際は
  # PREV_BUFF=_ble_highlight_layer_RandomColor_buff
  # に設定した物に対応する物を指定しないと表示が変になる。
  ble-color-gspec2g -v g "fg=$((RANDOM%256))"
}

_ble_highlight_layer_RandomColor2_buff=()
function ble-highlight-layer:RandomColor2/update {
  local text="$1" sgr i x
  ble-highlight-layer/update/shift _ble_highlight_layer_RandomColor2_buff
  for ((i=DMIN;i<DMAX;i++)); do
    ble-color-gspec2sgr -v sgr "fg=$((16+(x=RANDOM%27)*4-x%9*2-x%3))"
    _ble_highlight_layer_RandomColor2_buff[i]="$sgr${_ble_highlight_layer_plain_buff[i]}"
  done
  PREV_BUFF=_ble_highlight_layer_RandomColor2_buff
  ((PREV_UMIN=0,PREV_UMAX=${#text}))
}
function ble-highlight-layer:RandomColor2/getg {
  # ここでは乱数を返しているが、実際は
  # PREV_BUFF=_ble_highlight_layer_RandomColor2_buff
  # に設定した物に対応する物を指定しないと表示が変になる。
  local x
  ble-color-gspec2g -v g "fg=$((16+(x=RANDOM%27)*4-x%9*2-x%3))"
}

_ble_highlight_layer__list=(plain syntax region disabled overwrite_mode)
