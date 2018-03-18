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
_ble_color_gflags_ForeColor=0x1000000
_ble_color_gflags_BackColor=0x2000000

function ble-color-show {
  local h l c
  local lN=16
  local hN=$((256/lN))
  for ((h=0;h<hN;h++)); do
    printf '\e[38;5;15m'
    for ((l=0;l<lN;l++)); do
      ((c=h*lN+l))
      printf '\e[48;5;%dm%03d ' "$c" "$c"
    done
    printf '\e[m\n\e[38;5;0m'
    for ((l=0;l<lN;l++)); do
      ((c=h*lN+l))
      printf '\e[48;5;%dm%03d ' "$c" "$c"
    done
    printf '\e[m\n'
  done
}

_ble_color_g2sgr__table=()
function ble-color-g2sgr {
  eval "$ble_util_upvar_setup"

  ret="${_ble_color_g2sgr__table[$1]}"
  if [[ -z $ret ]]; then
    local -i g="$1"
    local fg="$((g>> 8&0xFF))"
    local bg="$((g>>16&0xFF))"

    local sgr=0
    ((g&_ble_color_gflags_Bold))      && sgr="$sgr;${_ble_term_sgr_bold:-1}"
    ((g&_ble_color_gflags_Italic))    && sgr="$sgr;${_ble_term_sgr_sitm:-3}"
    ((g&_ble_color_gflags_Underline)) && sgr="$sgr;${_ble_term_sgr_smul:-4}"
    ((g&_ble_color_gflags_Blink))     && sgr="$sgr;${_ble_term_sgr_blink:-5}"
    ((g&_ble_color_gflags_Revert))    && sgr="$sgr;${_ble_term_sgr_rev:-7}"
    ((g&_ble_color_gflags_Invisible)) && sgr="$sgr;${_ble_term_sgr_invis:-8}"
    ((g&_ble_color_gflags_Strike))    && sgr="$sgr;${_ble_term_sgr_strike:-9}"
    if ((g&_ble_color_gflags_ForeColor)); then
      ble-color/.color2sgrfg -v "$var" "$fg"
      sgr="$sgr;${!var}"
    fi
    if ((g&_ble_color_gflags_BackColor)); then
      ble-color/.color2sgrbg -v "$var" "$bg"
      sgr="$sgr;${!var}"
    fi

    ret="[${sgr}m"
    _ble_color_g2sgr__table[$1]="$ret"
  fi

  eval "$ble_util_upvar"
}
function ble-color-gspec2g {
  eval "$ble_util_upvar_setup"

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
      ble-color/.name2color -v "$var" "${entry:3}"
      if ((var<0)); then
        ((g&=~(_ble_color_gflags_ForeColor|_ble_color_gflags_MaskFg)))
      else
        ((g|=var<<8|_ble_color_gflags_ForeColor))
      fi ;;
    (bg=*)
      ble-color/.name2color -v "$var" "${entry:3}"
      if ((var<0)); then
        ((g&=~(_ble_color_gflags_BackColor|_ble_color_gflags_MaskBg)))
      else
        ((g|=var<<16|_ble_color_gflags_BackColor))
      fi ;;
    (none)
      g=0 ;;
    esac
  done

  ret="$g"; eval "$ble_util_upvar"
}

function ble-color-gspec2sgr {
  eval "$ble_util_upvar_setup"
  local sgr=0 entry

  for entry in ${1//,/ }; do
    case "$entry" in
    (bold)      sgr="$sgr;1" ;;
    (underline) sgr="$sgr;4" ;;
    (standout)  sgr="$sgr;7" ;;
    (fg=*)
      ble-color/.name2color "${entry:3}"
      ble-color/.color2sgrfg "$ret"
      sgr="$sgr;$ret" ;;
    (bg=*)
      ble-color/.name2color "${entry:3}"
      ble-color/.color2sgrbg "$ret"
      sgr="$sgr;$ret" ;;
    (none)
      sgr=0 ;;
    esac
  done

  ret="[${sgr}m"; eval "$ble_util_upvar"
}

function ble-color/.name2color {
  eval "$ble_util_upvar_setup"

  local colorName="$1"
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

  eval "$ble_util_upvar"
}
function ble-color/.color2sgrfg {
  eval "$ble_util_upvar_setup"

  local ccode="$1"
  if ((ccode<0)); then
    ret=39
  elif ((ccode<16)); then
    ret="${_ble_term_sgr_af[ccode]}"
  elif ((ccode<256)); then
    ret="38;5;$ccode"
  fi

  eval "$ble_util_upvar"
}
function ble-color/.color2sgrbg {
  eval "$ble_util_upvar_setup"

  local ccode="$1"
  if ((ccode<0)); then
    ret=49
  elif ((ccode<16)); then
    ret="${_ble_term_sgr_ab[ccode]}"
  elif ((ccode<256)); then
    ret="48;5;$ccode"
  fi

  eval "$ble_util_upvar"
}

#------------------------------------------------------------------------------
# _ble_faces

# 遅延初期化登録
_ble_faces_lazy_loader=()
function ble-color/faces/addhook-onload { ble/array#push _ble_faces_lazy_loader "hook:$1"; }

# 遅延初期化
_ble_faces_count=0
_ble_faces=()
_ble_faces_sgr=()
function ble-color-defface   { ble/array#push _ble_faces_lazy_loader "def:$1:$2"; }
function ble-color-setface   { ble/array#push _ble_faces_lazy_loader "set:$1:$2"; }
function ble-color-face2g    { ble-color/faces/initialize && ble-color-face2g    "$@"; }
function ble-color-face2sgr  { ble-color/faces/initialize && ble-color-face2sgr  "$@"; }
function ble-color-iface2g   { ble-color/faces/initialize && ble-color-iface2g   "$@"; }
function ble-color-iface2sgr { ble-color/faces/initialize && ble-color-iface2sgr "$@"; }

# 遅延初期化子
function ble-color/faces/initialize {

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

  function ble-color/faces/addhook-onload { "$1"; }

  local initializer arg ret=0
  for initializer in "${_ble_faces_lazy_loader[@]}"; do
    local arg="${initializer#*:}"
    case "$initializer" in
    (def:*)  ble-color-defface "${arg%%:*}" "${arg#*:}";;
    (set:*)  ble-color-setface "${arg%%:*}" "${arg#*:}";;
    (hook:*) eval "$arg";;
    esac || ((ret++))
  done
  unset _ble_faces_lazy_loader

  return "$ret"
}

#------------------------------------------------------------------------------
# ble-highlight-layer

_ble_highlight_layer__list=(plain)
#_ble_highlight_layer__list=(plain RandomColor)

function ble-highlight-layer/update {
  local text=$1
  local -ir DMIN=$((BLELINE_RANGE_UPDATE[0]))
  local -ir DMAX=$((BLELINE_RANGE_UPDATE[1]))
  local -ir DMAX0=$((BLELINE_RANGE_UPDATE[2]))

  local PREV_BUFF=_ble_highlight_layer_plain_buff
  local PREV_UMIN=-1
  local PREV_UMAX=-1
  local layer player=plain LEVEL
  local nlevel=${#_ble_highlight_layer__list[@]}
  for((LEVEL=0;LEVEL<nlevel;LEVEL++)); do
    layer=${_ble_highlight_layer__list[LEVEL]}

    "ble-highlight-layer:$layer/update" "$text" "$player"
    # echo "PREV($LEVEL) $PREV_UMIN $PREV_UMAX" >> 1.tmp

    player="$layer"
  done

  HIGHLIGHT_BUFF=$PREV_BUFF
  HIGHLIGHT_UMIN=$PREV_UMIN
  HIGHLIGHT_UMAX=$PREV_UMAX
}

function ble-highlight-layer/update/add-urange {
  local umin=$1 umax=$2
  (((PREV_UMIN<0||PREV_UMIN>umin)&&(PREV_UMIN=umin),
    (PREV_UMAX<0||PREV_UMAX<umax)&&(PREV_UMAX=umax)))
}
function ble-highlight-layer/update/shift {
  local __dstArray=$1
  local __srcArray=${2:-$__dstArray}
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
  local LEVEL=$LEVEL
  while ((--LEVEL>=0)); do
    "ble-highlight-layer:${_ble_highlight_layer__list[LEVEL]}/getg" "$1"
    [[ $g ]] && return
  done
  g=0
}

function ble-highlight-layer/getg {
  eval "$ble_util_upvar_setup"

  LEVEL=${#_ble_highlight_layer__list[*]} ble-highlight-layer/update/getg "$1"

  ret=$g; eval "$ble_util_upvar"
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

## 関数 ble-highlight-layer:plain/update/.getch
##   @var[in,out] ch
function ble-highlight-layer:plain/update/.getch {
  [[ $ch == [' '-'~'] ]] && return
  if [[ $ch == [-] ]]; then
    if [[ $ch == $'\t' ]]; then
      ch=${_ble_util_string_prototype::it}
    elif [[ $ch == $'\n' ]]; then
      ch=$'\e[K\n'
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

## 関数 ble-highlight-layer:<layerName>/update text pbuff
function ble-highlight-layer:plain/update {
  if ((DMIN>=0)); then
    ble-highlight-layer/update/shift _ble_highlight_layer_plain_buff

    local i text=$1 ch
    local it=$_ble_term_it
    for ((i=DMIN;i<DMAX;i++)); do
      ch=${text:i:1}

      # LC_COLLATE for cygwin collation
      LC_COLLATE=C ble-highlight-layer:plain/update/.getch &>/dev/null

      _ble_highlight_layer_plain_buff[i]=$ch
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
# ble-highlight-layer:region

function ble-color/basic/faces-onload-hook {
  ble-color-defface region         bg=60,fg=white
  ble-color-defface region_target  bg=153,fg=black
  ble-color-defface disabled       fg=gray
  ble-color-defface overwrite_mode fg=black,bg=51
}
ble-color/faces/addhook-onload ble-color/basic/faces-onload-hook

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

function ble-highlight-layer:region/update-dirty-range {
  local -i a=$1 b=$2 p q
  ((a==b)) && return
  (((a<b?(p=a,q=b):(p=b,q=a)),
    (umin<0||umin>p)&&(umin=p),
    (umax<0||umax<q)&&(umax=q)))
}

function ble-highlight-layer:region/update {
  local omin=-1 omax=-1 osgr= olen=${#_ble_highlight_layer_region_osel[@]}
  if ((olen)); then
    omin=${_ble_highlight_layer_region_osel[0]}
    omax=${_ble_highlight_layer_region_osel[olen-1]}
    osgr=$_ble_highlight_layer_region_osgr
  fi

  if ((DMIN>=0)); then
    ((DMAX0<=omin?(omin+=DMAX-DMAX0):(DMAX<omin&&(omin=DMAX)),
      DMAX0<=omax?(omax+=DMAX-DMAX0):(DMAX<omax&&(omax=DMAX))))
  fi

  local sgr=
  local -a selection=()
  if [[ $_ble_edit_mark_active ]]; then
    # 外部定義の選択範囲があるか確認
    #   vi-mode のビジュアルモード (文字選択、行選択、矩形選択) の実装で使用する。
    local get_range=ble-highlight-layer:region/mark:$_ble_edit_mark_active/get-selection
    if ble/util/isfunction "$get_range"; then
      "$get_range"
    else
      if ((_ble_edit_mark>_ble_edit_ind)); then
        selection=("$_ble_edit_ind" "$_ble_edit_mark")
      elif ((_ble_edit_mark<_ble_edit_ind)); then
        selection=("$_ble_edit_mark" "$_ble_edit_ind")
      fi
    fi

    # sgr の取得
    local get_sgr=ble-highlight-layer:region/mark:$_ble_edit_mark_active/get-sgr
    if ble/util/isfunction "$get_sgr"; then
      "$get_sgr"
    else
      ble-color-face2sgr region
    fi
  fi
  local rlen=${#selection[@]}

  # 変更がない時はそのまま通過
  if ((DMIN<0)); then
    [[ $sgr == $osgr ]] &&
      [[ ${selection[*]} == ${_ble_highlight_layer_region_osel[*]} ]]
  else
    [[ ! ${selection[*]} && ! ${_ble_highlight_layer_region_osel[*]} ]]
  fi && return 0

  local umin=-1 umax=-1
  if ((rlen)); then
    # 選択範囲がある時
    local rmin=${selection[0]}
    local rmax=${selection[rlen-1]}

    # 描画文字配列の更新
    local -a buff
    local g sgr2
    local k=0 inext iprev=0
    for inext in "${selection[@]}"; do
      if ((k==0)); then
        ble/array#push buff "\"\${$PREV_BUFF[@]::$inext}\""
      elif ((k%2)); then
        ble/array#push buff "\"$sgr\${_ble_highlight_layer_plain_buff[@]:$iprev:$((inext-iprev))}\""
      else
        ble-highlight-layer/update/getg "$iprev"
        ble-color-g2sgr -v sgr2 "$g"
        ble/array#push buff "\"$sgr2\${$PREV_BUFF[@]:$iprev:$((inext-iprev))}\""
      fi
      ((iprev=inext,k++))
    done
    ble-highlight-layer/update/getg "$iprev"
    ble-color-g2sgr -v sgr2 "$g"
    ble/array#push buff "\"$sgr2\${$PREV_BUFF[@]:$iprev}\""
    builtin eval "_ble_highlight_layer_region_buff=(${buff[*]})"
    PREV_BUFF=_ble_highlight_layer_region_buff

    # DMIN-DMAX の間
    if ((DMIN>=0)); then
      ble-highlight-layer:region/update-dirty-range DMIN DMAX
    fi

    # 選択範囲の変更による再描画範囲
    if ((omin>=0)); then
      if [[ $osgr != $sgr ]]; then
        # 色が変化する場合
        ble-highlight-layer:region/update-dirty-range omin omax
        ble-highlight-layer:region/update-dirty-range rmin rmax
      else
        # 端点の移動による再描画
        ble-highlight-layer:region/update-dirty-range omin rmin
        ble-highlight-layer:region/update-dirty-range omax rmax
        if ((olen>1||rlen>1)); then
          # 複数範囲選択
          ble-highlight-layer:region/update-dirty-range rmin rmax
        fi
      fi
    else
      # 新規選択
      ble-highlight-layer:region/update-dirty-range rmin rmax
    fi

    # 下層の変更 (rmin ～ rmax は表には反映されない)
    local pmin=$PREV_UMIN pmax=$PREV_UMAX
    if ((rlen==2)); then
      ((rmin<=pmin&&pmin<rmax&&(pmin=rmax),
        rmin<pmax&&pmax<=rmax&&(pmax=rmin)))
    fi
    ble-highlight-layer:region/update-dirty-range pmin pmax
  else
    # 選択範囲がない時

    # 下層の変更
    umin=$PREV_UMIN umax=$PREV_UMAX

    # 選択解除の範囲
    ble-highlight-layer:region/update-dirty-range omin omax
  fi

  _ble_highlight_layer_region_osel=("${selection[@]}")
  _ble_highlight_layer_region_osgr=$sgr
  ((PREV_UMIN=umin,
    PREV_UMAX=umax))
}

function ble-highlight-layer:region/getg {
  if [[ $_ble_edit_mark_active ]]; then
    local index=$1 olen=${#_ble_highlight_layer_region_osel[@]}
    ((olen)) || return
    ((_ble_highlight_layer_region_osel[0]<=index&&index<_ble_highlight_layer_region_osel[olen-1])) || return
    if ((olen>=4)); then
      local l=0 u=$((olen-1)) m
      while ((l+1<u)); do
        ((_ble_highlight_layer_region_osel[m=(l+u)/2]<=index?(l=m):(u=m)))
      done
      ((l%2==0)) && ble-color-face2g region
    else
      ble-color-face2g region
    fi
  fi
}

#------------------------------------------------------------------------------
# ble-highlight-layer:disabled

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

function ble-highlight-layer:disabled/getg {
  if [[ $_ble_highlight_layer_disabled_prev ]]; then
    ble-color-face2g disabled
  fi
}

_ble_highlight_layer_overwrite_mode_index=-1
_ble_highlight_layer_overwrite_mode_buff=()
function ble-highlight-layer:overwrite_mode/update {
  local oindex=$_ble_highlight_layer_overwrite_mode_index
  if ((DMIN>=0)); then
    if ((oindex>=DMAX0)); then
      ((oindex+=DMAX-DMAX0))
    elif ((oindex>=DMIN)); then
      oindex=-1
    fi
  fi

  local index=-1
  if [[ $_ble_edit_overwrite_mode ]]; then
    local next=${_ble_edit_str:_ble_edit_ind:1}
    if [[ $next && $next != [$'\n\t'] ]]; then
      index=$_ble_edit_ind

      local g sgr

      # PREV_BUFF の内容をロード
      if ((PREV_UMIN<0&&oindex>=0)); then
        # 前回の結果が残っている場合
        ble-highlight-layer/update/getg "$oindex"
        ble-color-g2sgr -v sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[oindex]=$sgr${_ble_highlight_layer_plain_buff[oindex]}
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
      _ble_highlight_layer_overwrite_mode_buff[index]=$sgr${_ble_highlight_layer_plain_buff[index]}
      if ((index+1<${#1})); then
        ble-highlight-layer/update/getg $((index+1))
        ble-color-g2sgr -v sgr "$g"
        _ble_highlight_layer_overwrite_mode_buff[index+1]=$sgr${_ble_highlight_layer_plain_buff[index+1]}
      fi
    fi
  fi

  if ((index>=0)); then
    ble/term/cursor-state/hide
  else
    ble/term/cursor-state/reveal
  fi

  if ((index!=oindex)); then
    ((oindex>=0)) && ble-highlight-layer/update/add-urange "$oindex" $((oindex+1))
    ((index>=0)) && ble-highlight-layer/update/add-urange "$index" $((index+1))
  fi

  _ble_highlight_layer_overwrite_mode_index=$index
}
function ble-highlight-layer:overwrite_mode/getg {
  local index=$_ble_highlight_layer_overwrite_mode_index
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
  local text=$1 sgr i
  _ble_highlight_layer_RandomColor_buff=()
  for ((i=0;i<${#text};i++)); do
    # _ble_highlight_layer_RandomColor_buff[i] に "<sgr><表示文字>" を設定する。
    # "<表示文字>" は ${_ble_highlight_layer_plain_buff[i]} でなければならない
    # (或いはそれと文字幅が同じ物…ただそれが反映される保証はない)。
    ble-color-gspec2sgr -v sgr "fg=$((RANDOM%256))"
    _ble_highlight_layer_RandomColor_buff[i]=$sgr${_ble_highlight_layer_plain_buff[i]}
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
    _ble_highlight_layer_RandomColor2_buff[i]=$sgr${_ble_highlight_layer_plain_buff[i]}
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

_ble_highlight_layer__list=(plain syntax region overwrite_mode disabled)
