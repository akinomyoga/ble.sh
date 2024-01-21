#!/bin/bash

ble/util/import "$_ble_base/lib/core-syntax.sh"

## @fn ble/complete/string#search-longest-suffix-in needle haystack
##   @var[out] ret
function ble/complete/string#search-longest-suffix-in {
  local needle=$1 haystack=$2
  local l=0 u=${#needle}
  while ((l<u)); do
    local m=$(((l+u)/2))
    if [[ $haystack == *"${needle:m}"* ]]; then
      u=$m
    else
      l=$((m+1))
    fi
  done
  ret=${needle:l}
}
## @fn ble/complete/string#common-suffix-prefix lhs rhs
##   @var[out] ret
function ble/complete/string#common-suffix-prefix {
  local lhs=$1 rhs=$2
  if ((${#lhs}<${#rhs})); then
    local i n=${#lhs}
    for ((i=0;i<n;i++)); do
      ret=${lhs:i}
      [[ $rhs == "$ret"* ]] && return 0
    done
    ret=
  else
    local j m=${#rhs}
    for ((j=m;j>0;j--)); do
      ret=${rhs::j}
      [[ $lhs == *"$ret" ]] && return 0
    done
    ret=
  fi
}

## @fn ble/complete/string#match-patterns str patterns...
##   指定した文字列が patterns 集合の何れかのパターンに一致するか検査します。
##   @param[in] str
##   @param[in] patterns
##   @exit
function ble/complete/string#match-patterns {
  local s=$1 found= pattern; shift
  for pattern; do
    if [[ $s == $pattern ]]; then
      return 0
    fi
  done
  return 1
}

## @fn ble/complete/get-wordbreaks
##   @var[out] wordbreaks
function ble/complete/get-wordbreaks {
  wordbreaks=$_ble_term_IFS$COMP_WORDBREAKS
  [[ $wordbreaks == *'('* ]] && wordbreaks=${wordbreaks//['()']}'()'
  [[ $wordbreaks == *']'* ]] && wordbreaks=']'${wordbreaks//']'}
  [[ $wordbreaks == *'-'* ]] && wordbreaks=${wordbreaks//'-'}'-'
}

# 
#==============================================================================
# 選択インターフェイス (ble/complete/menu)

## @arr _ble_complete_menu_icons
##
##   各要素は以下の形式の文字列である。
##
##   x0,y0,x1,y1,${#pack},${#esc1}[,bbox]:$pack$esc1
##
##   * x0,y0 と x1,y1 は menu 項目の描画開始点と終了点。
##   * esc1 は実際に出力する描画シーケンス。
##   * bbox は "x y cols lines" の形式をしていて、描画シーケンスを生成する際に
##     使った bbox の情報を格納する。これは特に truncate が起こった時に、選択状
##     態の描画を同じ条件で実行する時に参照する。

_ble_complete_menu_items=()
_ble_complete_menu_class=
_ble_complete_menu_param=
_ble_complete_menu_version=
_ble_complete_menu_page_style=
_ble_complete_menu_ipage=
_ble_complete_menu_offset=
_ble_complete_menu_icons=()
_ble_complete_menu_info_data=()
_ble_complete_menu_selected=-1

function ble/complete/menu#check-cancel {
  ((menu_iloop++%menu_interval==0)) &&
    [[ :$comp_type: != *:sync:* ]] &&
    ble/decode/has-input
}

## @fn ble/complete/menu-style:$menu_style/construct-page
##   候補一覧メニューの表示・配置を計算します。
##
##   @var[out] x y esc
##   @var[in] menu_style
##   @arr[in] menu_items
##   @var[in] menu_class menu_param
##   @var[in] cols lines
##
## @fn ble/complete/menu-style:$menu_style/guess
##   scroll 番目の候補がどのページにいるかを予測します。
##   可能性のある最初のページ番号 ipage を返します。
##
##   @var[in] scroll
##   @var[out] ipage begin end
##   @var[in] cols lines
##

_ble_complete_menu_style_measure=()
_ble_complete_menu_style_icons=()
_ble_complete_menu_style_pages=()

#
# ble/complete/menu-style:align
#

## @fn ble/complete/menu#render-item item opts
##   @var[in] cols lines
##     Note: "$menu_class"/render-item の中で用いる。
##   @var[out] x y ret
function ble/complete/menu#render-item {
  # use custom renderer
  if ble/is-function "$menu_class"/render-item; then
    "$menu_class"/render-item "$@"
    return "$?"
  fi

  local item=$1 opts=$2
  #g=0 lc=0 lg=0 LINES=$lines COLUMNS=$cols ble/canvas/trace "$item" truncate:ellipsis

  local sgr0=$_ble_term_sgr0 sgr1=$_ble_term_rev
  [[ :$opts: == *:selected:* ]] && local sgr0=$sgr1 sgr1=$sgr0
  ble/canvas/trace-text "$item" nonewline:external-sgr
  ret=$sgr0$ret$_ble_term_sgr0
}

## @fn ble/complete/menu#get-prefix-width format column_width
##   @param[in] format
##   @param[in] column_width
##   @var[out] prefix_width
##   @var[out] prefix_format
function ble/complete/menu#get-prefix-width {
  prefix_width=0
  prefix_format=${1:-$bleopt_menu_prefix}
  if [[ $prefix_format ]]; then
    local prefix1 column_width=$2
    ble/util/sprintf prefix1 "$prefix_format" "${#menu_items[@]}"
    local x1 y1 x2 y2 g=0
    LINES=1 COLUMNS=$column_width x=0 y=0 ble/canvas/trace "$prefix1" truncate:measure-bbox
    if ((x2<=column_width/2)); then
      prefix_width=$x2
      ble/string#reserve-prototype "$prefix_width"
    fi
  fi
}

## @fn ble/complete/menu#render-prefix index
##   @param[in] index
##   @param[in,opt] column_width
##   @var[in] prefix_width
##   @var[in] prefix_format
##   @var[out] prefix_esc
function ble/complete/menu#render-prefix {
  prefix_esc=
  local index=$1
  if ((prefix_width)); then
    local prefix1; ble/util/sprintf prefix1 "$prefix_format" "$((index+1))"
    local x=0 y=0 g=0
    LINES=1 COLUMNS=$prefix_width ble/canvas/trace "$prefix1" truncate:relative
    prefix_esc=$ret$_ble_term_sgr0
    if ((x<prefix_width)); then
      prefix_esc=${_ble_string_prototype::prefix_width-x}$prefix_esc
    fi
  fi
}


## @fn ble/complete/menu-style:align/construct/.measure-candidates-in-page
##   その頁に入り切る範囲で候補の幅を計測する
##   @var[in] begin
##     その頁の一番最初に表示する候補を指定します。
##   @var[out] end
##     その頁に表示する候補の範囲の終端を返します。
##     実際には描画の際に全角文字などの文字送りによって
##     ここまで表示できるとは限りません。
##   @var[out] wcell
##     その頁を描画する時のセル幅を返します。
##   @arr[in,out] _ble_complete_menu_style_measure
##     計測結果をキャッシュしておく配列です。
##
##   @var[in] lines cols menu_iloop
function ble/complete/menu-style:align/construct/.measure-candidates-in-page {
  local max_wcell=$bleopt_menu_align_max; ((max_wcell>cols&&(max_wcell=cols)))
  ((wcell=bleopt_menu_align_min,wcell<2&&(wcell=2)))
  local ncell=0 index=$begin
  local item ret esc1 w
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148
    local wcell_old=$wcell

    # 候補の表示幅 w を計算
    local w=${_ble_complete_menu_style_measure[index]%%:*}
    if [[ ! $w ]]; then
      local prefix_esc
      ble/complete/menu#render-prefix "$index"
      local x=$prefix_width y=0
      ble/complete/menu#render-item "$item"; esc1=$ret
      local w=$((y*cols+x))
      _ble_complete_menu_style_measure[index]=$w:${#item},${#esc1}:$item$esc1$prefix_esc
    fi

    # wcell, ncell 更新
    local wcell_request=$((w++,w<=max_wcell?w:max_wcell))
    ((wcell<wcell_request)) && wcell=$wcell_request

    # 新しい ncell
    local line_ncell=$((cols/wcell))
    local cand_ncell=$(((w+wcell-1)/wcell))
    if [[ $menu_style == align-nowrap ]]; then
      # Note: nowrap が起こるのはすでに wcell == max_wcell の時なので、
      # 改行処理が終わった後に wcell が変化するという事はない。
      local x1=$((ncell%line_ncell*wcell))
      local ncell_eol=$(((ncell/line_ncell+1)*line_ncell))
      if ((x1>0&&x1+w>=cols)); then
        # 行送り
        ((ncell=ncell_eol+cand_ncell))
      elif ((x1+w<cols)); then
        # 余白に収まる場合
        ((ncell+=cand_ncell))
        ((ncell>ncell_eol&&(ncell=ncell_eol)))
      else
        ((ncell+=cand_ncell))
      fi
    else
      ((ncell+=cand_ncell))
    fi

    local max_ncell=$((line_ncell*lines))
    ((index&&ncell>max_ncell)) && { wcell=$wcell_old; break; }
    ((index++))
  done
  end=$index
}

## @fn ble/complete/menu-style:align/construct-page
##   @var[in,out] begin end x y esc
##   @arr[out] _ble_complete_menu_style_icons
##
##   @var[in,out] cols lines menu_iloop
function ble/complete/menu-style:align/construct-page {
  x=0 y=0 esc=

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_align_prefix" "$bleopt_menu_align_max"

  local wcell=2
  ble/complete/menu-style:align/construct/.measure-candidates-in-page
  (($?==148)) && return 148

  local ncell=$((cols/wcell))
  local index=$begin entry
  for entry in "${_ble_complete_menu_style_measure[@]:begin:end-begin}"; do
    ble/complete/menu#check-cancel && return 148

    local w=${entry%%:*}; entry=${entry#*:}
    local s=${entry%%:*}; entry=${entry#*:}
    local len; ble/string#split len , "$s"
    local item=${entry::len[0]} esc1=${entry:len[0]:len[1]} prefix_esc=${entry:len[0]+len[1]}

    local x0=$x y0=$y
    if ((x==0||x+w<cols)); then
      ((x+=w%cols,y+=w/cols))
      ((y>=lines&&(x=x0,y=y0,1))) && break
    else
      if [[ $menu_style == align-nowrap ]]; then
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x0=x=0,y0=++y))
        ((x=w%cols,y+=w/cols))
        ((y>=lines&&(x=x0,y=y0,1))) && break
      else
        ((x+=prefix_width))
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) || # [Note: 少なくとも1個ははみ出ても表示する]
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    _ble_complete_menu_style_icons[index]=$((x0+prefix_width)),$y0,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$prefix_esc$esc1

    # 候補と候補の間の空白
    if ((++index<end)); then
      local icell=$((x==0?0:(x+wcell)/wcell))
      if ((icell<ncell)); then
        # 次の升目
        local pad=$((icell*wcell-x))
        ble/string#reserve-prototype "$pad"
        esc=$esc${_ble_string_prototype::pad}
        ((x=icell*wcell))
      else
        # 次の行
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x=0,++y))
      fi
    fi
  done
  end=$index
}
function ble/complete/menu-style:align-nowrap/construct-page {
  ble/complete/menu-style:align/construct-page "$@"
}

#
# ble/complete/menu-style:dense
#

## @fn ble/complete/menu-style:dense/construct-page
##   @var[in,out] begin end x y esc
##   @var[in,out] cols lines menu_iloop
function ble/complete/menu-style:dense/construct-page {

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_dense_prefix" "$cols"

  x=0 y=0 esc=
  local item index=$begin N=${#menu_items[@]}
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148

    local x0=$x y0=$y

    local prefix_esc esc1
    ble/complete/menu#render-prefix "$index"
    ((x+=prefix_width,x>cols&&(y+=x/cols,x%=cols)))
    ble/complete/menu#render-item "$item" ||
      ((index==begin)) ||
      { x=$x0 y=$y0; break; }; esc1=$ret

    if [[ $menu_style == dense-nowrap ]]; then
      if ((y>y0&&x>0||y>y0+1)); then
        ((++y0>=lines)) && break
        esc=$esc$'\n'
        ((y=y0,x0=0,x=prefix_width))
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) ||
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    local x1=$((x0+prefix_width)) y1=$y0
    ((x1>=cols)) && ((y1+=x1/cols,x1%=cols))
    _ble_complete_menu_style_icons[index]=$x1,$y1,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$prefix_esc$esc1

    # 候補と候補の間の空白
    if ((++index<N)); then
      if [[ $menu_style == dense-nowrap ]] && ((x==0)); then
        : skip
      elif ((x+1<cols)); then
        esc=$esc' '
        ((x++))
      else
        ((y+1>=lines)) && break
        esc=$esc$'\n'
        ((x=0,++y))
      fi
    fi
  done
  end=$index
}
## @fn ble/complete/menu-style:dense/construct opts
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble/complete/menu-style:dense-nowrap/construct-page {
  ble/complete/menu-style:dense/construct-page "$@"
}

#
# ble/complete/menu-style:linewise
#

## @fn ble/complete/menu-style:linewise/construct-page opts
##   @var[in,out] begin end x y esc
function ble/complete/menu-style:linewise/construct-page {
  local opts=$1 ret
  local max_icon_width=$((cols-1))

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_linewise_prefix" "$max_icon_width"

  local item x0 y0 esc1 index=$begin
  end=$begin x=0 y=0 esc=
  for item in "${menu_items[@]:begin:lines}"; do
    ble/complete/menu#check-cancel && return 148

    local prefix_esc=
    ble/complete/menu#render-prefix "$index" "$max_icon_width"
    esc=$esc$prefix_esc
    ((x=prefix_width))

    ((x0=x,y0=y))
    local lines1=1 cols1=$max_icon_width
    lines=$lines1 cols=$cols1 y=0 ble/complete/menu#render-item "$item"; esc1=$ret
    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#item},${#esc1},"$x0 0 $cols1 $lines1":$item$esc1
    ((index++))
    esc=$esc$esc1

    ((y+1>=lines)) && break
    ((x=0,++y))
    esc=$esc$'\n'
  done
  end=$index
}
function ble/complete/menu-style:linewise/guess {
  ((ipage=scroll/lines,
    begin=ipage*lines,
    end=begin))
}

#
# ble/complete/menu-style:desc
#

_ble_complete_menu_desc_pageheight=()

## @fn ble/complete/menu-style:desc/construct-page opts
##   @var[in,out] begin end x y esc
##   @var[in] ipage
function ble/complete/menu-style:desc/construct-page {
  local opts=$1 ret
  local opt_raw=; [[ $menu_style != desc-text ]] && opt_raw=1

  # 失敗時・エラー時の既定値
  end=$begin esc= x=0 y=0

  local colsep=' | '
  local desc_sgr0=$'\e[m'
  ble/color/face2sgr-ansi syntax_quoted; local desc_sgrq=$ret
  ble/color/face2sgr-ansi syntax_delimiter; local desc_sgrt=$ret

  local ncolumn=1 nline=$lines
  local nrest_item=$((${#menu_items[@]}-begin))
  if [[ $bleopt_menu_desc_multicolumn_width ]]; then
    ncolumn=$((cols/bleopt_menu_desc_multicolumn_width))
    if ((ncolumn<1)); then
      ncolumn=1
    elif ((ncolumn>nrest_item)); then
      ncolumn=$nrest_item
    fi
  fi
  ((nline=(${#menu_items[@]}-begin+ncolumn-1)/ncolumn,
    nline>lines&&(nline=lines)))
  local ncolumn_max=$(((nrest_item+nline-1)/nline))
  ((ncolumn>ncolumn_max&&(ncolumn=ncolumn_max)))

  # Note #D1727: 相対移動の時は、右端に接すると端末による振る舞いの違
  #   いが問題になるので、右端に接しない様に col-1 にする。一部の端末
  #   については右端に接しても相対移動が壊れないと分かっているので、
  #   white list で右端に接する事を許可する。
  local available_width=$cols
  case $_ble_term_TERM in
  (screen:*|tmux:*|kitty:*|contra:*) ;;
  (*) ((available_width--)) ;;
  esac

  local wcolumn=$(((available_width-${#colsep}*(ncolumn-1))/ncolumn))

  local prefix_width prefix_format
  ble/complete/menu#get-prefix-width "$bleopt_menu_desc_prefix" "$wcolumn"
  ((wcolumn>=prefix_width+15)) || prefix_width=0

  local wcand_limit=$(((wcolumn-prefix_width+1)*2/3))
  ((wcand_limit<10&&(wcand_limit=wcolumn-prefix_width)))

  local -a DRAW_BUFF=()
  local index=$begin icolumn ymax=0
  for ((icolumn=0;icolumn<ncolumn;icolumn++)); do

    # 各候補を描画して幅を計算する
    local measure; measure=()
    local pack w esc1 max_width=0
    for pack in "${menu_items[@]:index:nline}"; do
      ble/complete/menu#check-cancel && return 148

      x=0 y=0
      lines=1 cols=$wcand_limit ble/complete/menu#render-item "$pack"; esc1=$ret
      ((w=y*wcand_limit+x,w>max_width&&(max_width=w)))

      ble/array#push measure "$w:${#pack}:$pack$esc1"
    done

    local cand_width=$max_width
    local desc_x=$((prefix_width+cand_width+1)); ((desc_x>wcolumn&&(desc_x=wcolumn)))
    local desc_prefix=; ((wcolumn-prefix_width-desc_x>30)) && desc_prefix=': '

    local xcolumn=$((icolumn*(wcolumn+${#colsep})))

    x=0 y=0
    local entry w s pack esc1 x0 y0 pad
    for entry in "${measure[@]}"; do
      ble/complete/menu#check-cancel && return 148

      w=${entry%%:*} entry=${entry#*:}
      s=${entry%%:*} entry=${entry#*:}
      pack=${entry::s} esc1=${entry:s}

      local prefix_esc
      ble/complete/menu#render-prefix "$index"
      ble/canvas/put.draw "$prefix_esc"
      ((x+=prefix_width))

      # 候補表示
      ((x0=x,y0=y,x+=w))
      _ble_complete_menu_style_icons[index]=$((xcolumn+x0)),$y0,$((xcolumn+x)),$y,${#pack},${#esc1},"0 0 $wcand_limit 1":$pack$esc1
      ((index++))
      ble/canvas/put.draw "$esc1"

      # 余白
      ble/canvas/put-spaces.draw "$((pad=desc_x-x))"
      ble/canvas/put.draw "$desc_prefix"
      ((x+=pad+${#desc_prefix}))

      # 説明表示
      local desc=$desc_sgrt'(no description)'$desc_sgr0
      ble/function#try "$menu_class"/get-desc "$pack"
      if [[ $opt_raw ]]; then
        y=0 g=0 lc=0 lg=0 LINES=1 COLUMNS=$wcolumn ble/canvas/trace.draw "$desc" truncate:relative:ellipsis
      else
        y=0 lines=1 cols=$wcolumn ble/canvas/trace-text "$desc" nonewline
        ble/canvas/put.draw "$ret"
      fi
      ble/canvas/put.draw "$_ble_term_sgr0"
      ((y+1>=nline)) && break
      ble/canvas/put-move.draw "$((-x))" 1
      ((x=0,++y))
    done
    ((y>ymax)) && ymax=$y

    if ((icolumn+1<ncolumn)); then
      # カラム仕切りを出力 (最後に次のカラムの先頭に移動)
      ble/canvas/put-move.draw "$((wcolumn-x))" "$((-y))"
      for ((y=0;y<=ymax;y++)); do
        ble/canvas/put.draw "$colsep"
        if ((y<ymax)); then
          ble/canvas/put-move.draw -${#colsep} 1
        else
          ble/canvas/put-move-y.draw "$((-y))"
        fi
      done
    else
      ((y<ymax)) && ble/canvas/put-move-y.draw "$((ymax-y))"
      ((x+=xcolumn,y=ymax))
    fi
  done

  _ble_complete_menu_desc_pageheight[ipage]=$nline
  end=$index
  ble/canvas/sflush.draw -v esc
}
function ble/complete/menu-style:desc/guess {
  local ncolumn=1
  if [[ $bleopt_menu_desc_multicolumn_width ]]; then
    ncolumn=$((cols/bleopt_menu_desc_multicolumn_width))
    ((ncolumn<1)) && ncolumn=1
  fi
  local nitem_per_page=$((ncolumn*lines))
  ((ipage=scroll/nitem_per_page,
    begin=ipage*nitem_per_page,
    end=begin))
}
function ble/complete/menu-style:desc/locate {
  local type=$1 osel=$2
  local ipage=$_ble_complete_menu_ipage
  local nline=${_ble_complete_menu_desc_pageheight[ipage]:-1}

  case $type in
  (right) ((ret=osel+nline)) ;;
  (left)  ((ret=osel-nline)) ;;
  (down)  ((ret=osel+1)) ;;
  (up)    ((ret=osel-1)) ;;
  (*) return 1 ;;
  esac

  local beg=$_ble_complete_menu_offset
  local end=$((beg+${#_ble_complete_menu_icons[@]}))
  if ((ret<beg)); then
    ((ret=beg-1))
  elif ((ret>end)); then
    ((ret=end))
  fi
  return 0
}

function ble/complete/menu-style:desc-text/construct-page { ble/complete/menu-style:desc/construct-page "$@"; }
function ble/complete/menu-style:desc-text/guess { ble/complete/menu-style:desc/guess; }
function ble/complete/menu-style:desc-text/locate { ble/complete/menu-style:desc/locate "$@"; }

# Obsolete menu_style (now synonym to "desc")
function ble/complete/menu-style:desc-raw/construct-page { ble/complete/menu-style:desc/construct-page "$@"; }
function ble/complete/menu-style:desc-raw/guess { ble/complete/menu-style:desc/guess; }
function ble/complete/menu-style:desc-raw/locate { ble/complete/menu-style:desc/locate "$@"; }

## @fn ble/complete/menu#construct/.initialize-size
##   @var[out] cols lines
function ble/complete/menu#construct/.initialize-size {
  ble/edit/info/.initialize-size
  local maxlines=$((bleopt_complete_menu_maxlines))
  ((maxlines>0&&lines>maxlines)) && lines=$maxlines
}
## @fn ble/complete/menu#construct menu_opts
##   実装分離の adapter 部分
##
##   @var[in] menu_style
##
##   @arr[in] menu_items
##     項目のリストを指定します。
##
##   @var[in] menu_class menu_param
##     以下に掲げる様々な callback を呼び出す為の変数です。
##
##   @fn[in,opt] $menu_class/render-item item opts
##     各項目に対応する描画内容を決定する renderer 関数を指定します。
##     @param[in] item
##       描画される項目を指定します。
##     @param[in] opts
##       selected
##         選択されている項目の描画を行う事を示します。
##     @var[in] lines cols
##       描画範囲の行数と列数を指定します。
##     @var[in,out] x y
##       描画開始位置を指定します。終了位置を返します。
##     @var[out] ret
##       描画に用いるシーケンスを返します。
##
##   @fn[in,opt] $menu_class/onselect nsel osel
##     項目が選択された時に呼び出される callback を指定します。
##     @param[in] nsel osel
##
##   @fn[in,opt] $menu_class/get-desc item
##     項目の説明を取得します。
##     @param[out] desc
##
##   @fn[in,opt] $menu_class/onaccept nsel [item]
##   @fn[in,opt] $menu_class/oncancel nsel
##
function ble/complete/menu#construct {
  local menu_opts=$1
  local menu_iloop=0
  local menu_interval=$bleopt_complete_polling_cycle

  local cols lines
  ble/complete/menu#construct/.initialize-size
  local nitem=${#menu_items[@]}
  local version=$nitem:$lines:$cols

  # 項目がない時の特別表示
  if ((nitem==0)); then
    _ble_complete_menu_version=$version
    _ble_complete_menu_items=()
    _ble_complete_menu_page_style=
    _ble_complete_menu_ipage=0
    _ble_complete_menu_offset=0
    _ble_complete_menu_icons=()
    _ble_complete_menu_info_data=(ansi $'\e[38;5;242m(no items)\e[m')
    _ble_complete_menu_selected=-1
    return 0
  fi

  # 表示したい項目の指定
  local scroll=0 rex=':scroll=([0-9]+):' use_cache=
  if [[ :$menu_opts: =~ $rex ]]; then
    scroll=${BASH_REMATCH[1]}
    ((nitem&&(scroll%=nitem)))
    [[ $_ble_complete_menu_version == $version ]] && use_cache=1
  fi
  if [[ ! $use_cache ]]; then
    _ble_complete_menu_style_measure=()
    _ble_complete_menu_style_icons=()
    _ble_complete_menu_style_pages=()
  fi

  local begin=0 end=0 ipage=0 x y esc
  ble/function#try ble/complete/menu-style:"$menu_style"/guess
  while ((end<nitem)); do
    ((scroll<begin)) && return 1
    local page_data=${_ble_complete_menu_style_pages[ipage]}
    if [[ $page_data ]]; then
      # キャッシュがある時はキャッシュから読み取り
      local fields; ble/string#split fields , "${page_data%%:*}"
      begin=${fields[0]} end=${fields[1]}
      if ((begin<=scroll&&scroll<end)); then
        x=${fields[2]} y=${fields[3]} esc=${page_data#*:}
        break
      fi
    else
      # キャッシュがない時は頁を構築
      ble/complete/menu-style:"$menu_style"/construct-page "$menu_opts" || return "$?"
      _ble_complete_menu_style_pages[ipage]=$begin,$end,$x,$y:$esc
      ((begin<=scroll&&scroll<end)) && break
    fi
    begin=$end
    ((ipage++))
  done

  _ble_complete_menu_version=$version
  _ble_complete_menu_items=("${menu_items[@]}")
  _ble_complete_menu_class=$menu_class
  _ble_complete_menu_param=$menu_param
  _ble_complete_menu_page_style=$menu_style
  _ble_complete_menu_ipage=$ipage
  _ble_complete_menu_offset=$begin
  _ble_complete_menu_icons=("${_ble_complete_menu_style_icons[@]:begin:end-begin}")
  _ble_complete_menu_info_data=(store "$x" "$y" "$esc")
  _ble_complete_menu_selected=-1
  return 0
}

function ble/complete/menu#show {
  ble/edit/info/immediate-show "${_ble_complete_menu_info_data[@]}"
}
function ble/complete/menu#clear {
  ble/edit/info/default
}


## @fn ble/complete/menu#select index [opts]
##   @param[in] opts
##     goto-page-top
##       指定した項目を含む頁に移動した後に、
##       その頁の一番上の項目に移動する事を指定します。
function ble/complete/menu#select {
  local menu_class=$_ble_complete_menu_class
  local menu_param=$_ble_complete_menu_param
  local osel=$_ble_complete_menu_selected nsel=$1 opts=$2
  local ncand=${#_ble_complete_menu_items[@]}
  ((0<=osel&&osel<ncand)) || osel=-1
  ((0<=nsel&&nsel<ncand)) || nsel=-1
  ((osel==nsel)) && return 0

  local infox infoy
  ble/canvas/panel#get-origin "$_ble_edit_info_panel" --prefix=info

  # ページ更新
  local visible_beg=$_ble_complete_menu_offset
  local visible_end=$((visible_beg+${#_ble_complete_menu_icons[@]}))
  if ((nsel>=0&&!(visible_beg<=nsel&&nsel<visible_end))); then
    ble/complete/menu/show filter:load-filtered-data:scroll="$nsel"; local ext=$?
    ((ext)) && return "$ext"

    if [[ $_ble_complete_menu_ipage ]]; then
      local ipage=$_ble_complete_menu_ipage
      ble/term/visible-bell "menu: Page $((ipage+1))" persistent
    else
      ble/term/visible-bell "menu: Offset $_ble_complete_menu_offset/$ncand" persistent
    fi

    visible_beg=$_ble_complete_menu_offset
    visible_end=$((visible_beg+${#_ble_complete_menu_icons[@]}))

    # スクロールに対応していない menu_style や、スクロールしすぎた時の為。
    ((visible_end<=nsel&&(nsel=visible_end-1)))
    ((nsel<=visible_beg&&(nsel=visible_beg)))
    ((visible_beg<=osel&&osel<visible_end)) || osel=-1
  fi

  local -a DRAW_BUFF=()
  local ret; ble/canvas/panel/save-position; local pos0=$ret
  if ((osel>=0)); then
    # 消去
    local entry=${_ble_complete_menu_icons[osel-visible_beg]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    if ((fields[3]<_ble_canvas_panel_height[_ble_edit_info_panel])); then
      # Note: 編集文字列の内容の変化により info panel が削れている事がある。
      # 現在の項目がちゃんと info panel の中にある時にだけ描画する。(#D0880)

      ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "${fields[@]::2}"
      ble/canvas/put.draw "${text:fields[4]}"
      _ble_canvas_x=${fields[2]} _ble_canvas_y=$((infoy+fields[3]))
    fi
  fi

  local value=
  if ((nsel>=0)); then
    [[ :$opts: == *:goto-page-top:* ]] && nsel=$visible_beg
    local entry=${_ble_complete_menu_icons[nsel-visible_beg]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    local x=${fields[0]} y=${fields[1]}
    local item=${text::fields[4]}

    # construct reverted candidate
    local ret
    if [[ ${fields[6]} ]]; then
      local box cols lines
      ble/string#split-words box "${fields[6]}"
      x=${box[0]} y=${box[1]} cols=${box[2]} lines=${box[3]}
      ble/complete/menu#render-item "$item" selected
      ((x+=fields[0]-box[0]))
      ((y+=fields[1]-box[1]))
    else
      local cols lines
      ble/complete/menu#construct/.initialize-size
      ble/complete/menu#render-item "$item" selected
    fi

    if ((y<_ble_canvas_panel_height[_ble_edit_info_panel])); then
      # Note: 編集文字列の内容の変化により info panel が削れている事がある。
      # 現在の項目がちゃんと info panel の中にある時にだけ描画する。(#D0880)

      ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "${fields[@]::2}"
      ble/canvas/put.draw "$ret"
      _ble_canvas_x=$x _ble_canvas_y=$((infoy+y))
    fi

    _ble_complete_menu_selected=$nsel
  else
    _ble_complete_menu_selected=-1
    value=$_ble_complete_menu_original
  fi
  ble/canvas/panel/load-position.draw "$pos0"
  ble/canvas/bflush.draw

  ble/function#try "$menu_class"/onselect "$nsel" "$osel"
  return 0
}

# widgets

function ble/widget/menu/forward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected+1))
  local ncand=${#_ble_complete_menu_items[@]}
  if ((nsel>=ncand)); then
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      nsel=0
    else
      ble/widget/.bell "menu: no more candidates"
      return 1
    fi
  fi
  ble/complete/menu#select "$nsel"
}
function ble/widget/menu/backward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected-1))
  if ((nsel<0)); then
    local ncand=${#_ble_complete_menu_items[@]}
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      ((nsel=ncand-1))
    else
      ble/widget/.bell "menu: no more candidates"
      return 1
    fi
  fi
  ble/complete/menu#select "$nsel"
}

function ble/widget/menu/forward-column {
  local osel=$((_ble_complete_menu_selected))
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate right "$osel"; then
    local nsel=$ret ncand=${#_ble_complete_menu_items[@]}
    if ((0<=nsel&&nsel<ncand&&nsel!=osel)); then
      ble/complete/menu#select "$nsel"
    else
      ble/widget/.bell "menu: no more candidates"
    fi
  else
    ble/widget/menu/forward
  fi
}
function ble/widget/menu/backward-column {
  local osel=$((_ble_complete_menu_selected))
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate left "$osel"; then
    local nsel=$ret ncand=${#_ble_complete_menu_items[@]}
    if ((0<=nsel&&nsel<ncand&&nsel!=osel)); then
      ble/complete/menu#select "$nsel"
    else
      ble/widget/.bell "menu: no more candidates"
    fi
  else
    ble/widget/menu/backward
  fi
}

_ble_complete_menu_lastcolumn=
## @fn ble/widget/menu/.check-last-column
##   @var[in,out] ox
function ble/widget/menu/.check-last-column {
  if [[ $_ble_complete_menu_lastcolumn ]]; then
    local lastwidget=${LASTWIDGET%%' '*}
    if [[ $lastwidget == ble/widget/menu/forward-line ||
            $lastwidget == ble/widget/menu/backward-line ]]
    then
      ox=$_ble_complete_menu_lastcolumn
      return 0
    fi
  fi
  _ble_complete_menu_lastcolumn=$ox
}
## @fn ble/widget/menu/.goto-column column
##   現在行の中で指定した列に対応する要素に移動する。
##   @param[in] column
function ble/widget/menu/.goto-column {
  local column=$1
  local offset=$_ble_complete_menu_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1
  local entry=${_ble_complete_menu_icons[osel-offset]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local nsel=-1
  if ((ox<column)); then
    # forward search within the line
    nsel=$osel
    for entry in "${_ble_complete_menu_icons[@]:osel+1-offset}"; do
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y==oy&&x<=column)) || break
      ((nsel++))
    done
  elif ((ox>column)); then
    # backward search within the line
    local i=$osel
    while ((--i>=offset)); do
      entry=${_ble_complete_menu_icons[i-offset]}
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<oy||x<=column&&(nsel=i,1))) && break
    done
  fi
  ((nsel>=0&&nsel!=osel)) &&
    ble/complete/menu#select "$nsel"
}
function ble/widget/menu/forward-line {
  local offset=$_ble_complete_menu_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1

  local nsel=-1 goto_column=
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate down "$osel"; then
    nsel=$ret
  else
    local entry=${_ble_complete_menu_icons[osel-offset]}
    local fields; ble/string#split fields , "${entry%%:*}"
    local ox=${fields[0]} oy=${fields[1]}
    ble/widget/menu/.check-last-column
    local i=$osel nsel=-1 is_next_page=
    for entry in "${_ble_complete_menu_icons[@]:osel+1-offset}"; do
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<=oy||y==oy+1&&x<=ox||nsel<0)) || break
      ((++i,y>oy&&(nsel=i)))
    done
    ((nsel<0&&(is_next_page=1,nsel=offset+${#_ble_complete_menu_icons[@]})))
    ((is_next_page)) && goto_column=$ox
  fi

  local ncand=${#_ble_complete_menu_items[@]}
  if ((0<=nsel&&nsel<ncand)); then
    ble/complete/menu#select "$nsel"
    [[ $goto_column ]] && ble/widget/menu/.goto-column "$goto_column"
    return 0
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-line {
  local offset=$_ble_complete_menu_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1

  local nsel=-1 goto_column=
  if local ret; ble/function#try ble/complete/menu-style:"$_ble_complete_menu_page_style"/locate up "$osel"; then
    nsel=$ret
  else
    local entry=${_ble_complete_menu_icons[osel-offset]}
    local fields; ble/string#split fields , "${entry%%:*}"
    local ox=${fields[0]} oy=${fields[1]}
    ble/widget/menu/.check-last-column
    local nsel=$osel
    while ((--nsel>=offset)); do
      entry=${_ble_complete_menu_icons[nsel-offset]}
      ble/string#split fields , "${entry%%:*}"
      local x=${fields[0]} y=${fields[1]}
      ((y<oy-1||y==oy-1&&x<=ox)) && break
    done
    ((0<=nsel&&nsel<offset)) && goto_column=$ox
  fi

  local ncand=${#_ble_complete_menu_items[@]}
  if ((0<=nsel&&nsel<ncand)); then
    ble/complete/menu#select "$nsel"
    [[ $goto_column ]] && ble/widget/menu/.goto-column "$goto_column"
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-page {
  if ((_ble_complete_menu_offset>0)); then
    ble/complete/menu#select "$((_ble_complete_menu_offset-1))" goto-page-top
  else
    ble/widget/.bell "menu: this is the first page."
    return 1
  fi
}
function ble/widget/menu/forward-page {
  local next=$((_ble_complete_menu_offset+${#_ble_complete_menu_icons[@]}))
  if ((next<${#_ble_complete_menu_items[@]})); then
    ble/complete/menu#select "$next"
  else
    ble/widget/.bell "menu: this is the last page."
    return 1
  fi
}
function ble/widget/menu/beginning-of-page {
  ble/complete/menu#select "$_ble_complete_menu_offset"
}
function ble/widget/menu/end-of-page {
  local nicon=${#_ble_complete_menu_icons[@]}
  ((nicon)) && ble/complete/menu#select "$((_ble_complete_menu_offset+nicon-1))"
}

function ble/widget/menu/cancel {
  ble/decode/keymap/pop
  ble/complete/menu#clear
  "$_ble_complete_menu_class"/oncancel
}
function ble/widget/menu/accept {
  ble/decode/keymap/pop
  ble/complete/menu#clear
  local nsel=$_ble_complete_menu_selected
  local hook=$_ble_complete_menu_accept_hook
  _ble_complete_menu_accept_hook=
  if ((nsel>=0)); then
    "$_ble_complete_menu_class"/onaccept "$nsel" "${_ble_complete_menu_items[nsel]}"
  else
    "$_ble_complete_menu_class"/onaccept "$nsel"
  fi
}

function ble-decode/keymap:menu/define {
  # ble-bind -f __defchar__ menu_complete/self-insert
  # ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f __default__ 'bell'
  ble-bind -f __line_limit__ nop
  ble-bind -f C-m         'menu/accept'
  ble-bind -f RET         'menu/accept'
  ble-bind -f C-g         'menu/cancel'
  ble-bind -f 'C-x C-g'   'menu/cancel'
  ble-bind -f 'C-M-g'     'menu/cancel'
  ble-bind -f C-f         'menu/forward-column'
  ble-bind -f right       'menu/forward-column'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward-column'
  ble-bind -f left        'menu/backward-column'
  ble-bind -f C-S-i       'menu/backward cyclic'
  ble-bind -f S-TAB       'menu/backward cyclic'
  ble-bind -f C-n         'menu/forward-line'
  ble-bind -f down        'menu/forward-line'
  ble-bind -f C-p         'menu/backward-line'
  ble-bind -f up          'menu/backward-line'
  ble-bind -f prior       'menu/backward-page'
  ble-bind -f next        'menu/forward-page'
  ble-bind -f home        'menu/beginning-of-page'
  ble-bind -f end         'menu/end-of-page'
}

# sample implementation
function ble/complete/menu.class/onaccept {
  local hook=$_ble_complete_menu_accept_hook
  _ble_complete_menu_accept_hook=
  "$hook" "$@"
}
function ble/complete/menu.class/oncancel {
  local hook=$_ble_complete_menu_cancel_hook
  _ble_complete_menu_cancel_hook=
  "$hook" "$@"
}
function ble/complete/menu#start {
  _ble_complete_menu_accept_hook=$1; shift
  _ble_complete_menu_cancel_hook=

  local menu_style=linewise
  local menu_items; menu_items=("$@")
  local menu_class=ble/complete/menu.class menu_param=
  ble/complete/menu#construct sync || return "$?"
  ble/complete/menu#show
  ble/complete/menu#select 0
  ble/decode/keymap/push menu
  return 147
}

# 
#==============================================================================
# 候補源 (context, source, action)

## ble/complete 内で共通で使われるローカル変数
##
## @var COMP1 COMP2 COMPS COMPV
##   COMP1-COMP2 は補完対象の範囲を指定します。
##   COMPS は COMP1-COMP2 にある文字列を表し、
##   COMPV は COMPS の評価値 (クォート除去、簡単なパラメータ展開をした値) を表します。
##   COMPS に複雑な構造が含まれていて即時評価ができない場合は
##   COMPV は unset になります。必要な場合は [[ $comps_flags == *v* ]] で判定して下さい。
##   ※ [[ -v COMPV ]] は bash-4.2 以降です。
##
## @var comp_type
##   候補生成の方法を制御します。
##   以下のオプションのコロン区切りの組み合わせからなる文字列です。
##
##   a 曖昧補完に用いる候補を生成する。
##     曖昧一致するかどうかは呼び出し元で判定されるので、
##     曖昧一致する可能性のある候補をできるだけ多く生成すれば良い。
##   m 曖昧補完 (中間部分に一致)
##   A 曖昧補完 (部分列・最初の文字も一致しなくて良い)
##
##   i (rlvar completion-ignore-case)
##     大文字小文字を区別しない補完候補生成を行う。
##   vstat (rlvar visible-stats)
##     ファイル名末尾にファイルの種類を示す記号を付加する。
##   markdir (rlvar mark-directories)
##     ディレクトリ名の補完後に / を付加する。
##
##   sync
##     ユーザの入力があっても中断しない事を表す。
##   raw
##     COMPV としてシェル評価前の文字列を使用します。
##

function ble/complete/check-cancel {
  [[ :$comp_type: != *:sync:* ]] && ble/decode/has-input
}

#------------------------------------------------------------------------------
# action

## 既存の action
##
##   ble/complete/action:plain
##   ble/complete/action:word
##   ble/complete/action:file
##   ble/complete/action:progcomp
##   ble/complete/action:command
##   ble/complete/action:variable
##
## action の実装
##
## @fn ble/complete/action:$ACTION/initialize
##   基本的に INSERT を設定すれば良い
##   @var[in    ] CAND
##   @var[in,out] ACTION
##   @var[in,out] DATA
##   @var[in,out] INSERT
##     COMP1-COMP2 を置き換える文字列を指定します
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[in    ] COMP_PREFIX
##
##   @var[in    ] comps_flags
##     以下のフラグ文字からなる文字列です。
##
##     p パラメータ展開の直後に於ける補完である事を表します。
##       直後に識別子を構成する文字を追記する時に対処が必要です。
##
##     v COMPV が利用可能である事を表します。
##     f failglob で COMPV 評価が失敗した事を表します。
##
##     S クォート ''  の中にいる事を表します。
##     E クォート $'' の中にいる事を表します。
##     D クォート ""  の中にいる事を表します。
##     I クォート $"" の中にいる事を表します。
##     B クォート \   の直後にいる事を表します。
##     x ブレース展開の中にいる事を表します。
##
##     Note: shopt -s nocaseglob のため、フラグ文字は
##       大文字・小文字でも重複しないように定義する必要がある。
##
##   @var[in    ] comps_fixed
##     補完対象がブレース展開を含む場合に ibrace:value の形式になります。
##     それ以外の場合は空文字列です。
##     ibrace はブレース展開の構造を保持するのに必要な COMPS 接頭辞の長さです。
##     value は ${COMPS::ibrace} のブレース展開を実行した結果の最後の単語の評価結果です。
##
## @fn ble/complete/action:$ACTION/complete
##   一意確定時に、挿入文字列・範囲に対する加工を行います。
##   例えばディレクトリ名の場合に / を後に付け加える等です。
##
##   @var[in] CAND
##   @var[in] ACTION
##   @var[in] DATA
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type comps_flags
##
##   @var[in,out] insert suffix
##     補完によって挿入される文字列を指定します。
##     加工後の挿入する文字列を返します。
##
##   @var[in] insert_beg insert_end
##     補完によって置換される範囲を指定します。
##
##   @var[in,out] insert_flags
##     以下のフラグ文字の組み合わせの文字列です。
##
##     r   [in] 既存の部分を保持したまま補完が実行される事を表します。
##         それ以外の時、既存の入力部分も含めて置換されます。
##     m   [out] 候補一覧 (menu) の表示を要求する事を表します。
##     n   [out] 再度補完を試み (確定せずに) 候補一覧を表示する事を要求します。
##

function ble/complete/string#escape-for-completion-context {
  local str=$1 escape_flags=$2
  case $comps_flags in
  (*S*)    ble/string#escape-for-bash-single-quote "$str"  ;;
  (*E*)    ble/string#escape-for-bash-escape-string "$str" ;;
  (*[DI]*) ble/string#escape-for-bash-double-quote "$str"  ;;
  (*)
    if [[ $comps_fixed ]]; then
      ble/string#escape-for-bash-specialchars "$str" "b$escape_flags"
    else
      ble/string#escape-for-bash-specialchars "$str" "$escape_flags"
    fi ;;
  esac
}

function ble/complete/action/complete.addtail {
  suffix=$suffix$1
}
function ble/complete/action/complete.mark-directory {
  [[ :$comp_type: == *:markdir:* && $CAND != */ ]] &&
    [[ ! -h $CAND || ( $insert == "$COMPS" || :$comp_type: == *:marksymdir:* ) ]] &&
    ble/complete/action/complete.addtail /
}
function ble/complete/action/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble/complete/action/complete.addtail \' ;;
  (*[DI]*) ble/complete/action/complete.addtail \" ;;
  esac
}

## @fn ble/complete/action/quote-insert.initialize action
##   @var[out] ${_ble_complete_quote_insert_varnames[@]}
##
## @fn ble/complete/action/quote-insert action
##   @var[ref] INSERT
##   @var[in] ${_ble_complete_quote_insert_varnames[@]}
##
## Note: quote-insert を呼び出す前に予め quote-insert.initialize を呼び出して
## quote_... 変数を初期化しておく必要があります。
##
## Example:
##
##   local "${_ble_complete_quote_insert_varnames[@]/%/=}" # WA #D1570 checked
##   ble/complete/action/quote-insert.initialize "$action"
##   for INSERT; do
##     ble/complete/action/quote-insert "$action"
##     : do something with INSERT
##   done
##

_ble_complete_quote_insert_varnames=(
  quote_action
  quote_escape_flags
  quote_cont_cutbackslash
  quote_paramx_comps
  quote_trav_prefix
  quote_fixed_comps
  quote_fixed_compv
  quote_fixed_comps_len
  quote_fixed_compv_len)

function ble/complete/action/quote-insert.initialize {
  quote_action=$1

  quote_escape_flags=c
  if [[ $quote_action == command ]]; then
    quote_escape_flags=
  elif [[ $quote_action == progcomp ]]; then
    # #D1362 Bash は "compopt -o filenames" が指定されている時、
    # '~' で始まる補完候補と同名のファイルがある時にのみチルダをクォートする。
    # [[ $CAND == '~'* && ! ( $comp_opts == *:filenames:* && -e $CAND ) ]] &&
    #   quote_escape_flags=T$quote_escape_flags
    # #D1434 = 及び : は filenames がついていない限りは quote しない事にする。
    #    bash-complete が unquoted =, : を生成する可能性があるので。
    [[ $comp_opts != *:filenames:* ]] &&
      quote_escape_flags=${quote_escape_flags//c}
  fi
  [[ $comps_fixed ]] && quote_escape_flags=b$quote_escape_flags

  # 孤立 backslash が前置している時は二重クォートを防ぐ為に削除
  quote_cont_cutbackslash=
  [[ $comps_flags == *B* && $COMPS == *'\' ]] &&
    quote_cont_cutbackslash=1

  # 直前にパラメータ展開があればエスケープ
  quote_paramx_comps=$COMPS
  if [[ $comps_flags == *p* ]]; then
    # Note: 安全策 (本来 comps_flags に p がある時点で '\' では終わらない筈)
    [[ $comps_flags == *B* && $quote_paramx_comps == *'\' ]] &&
      quote_paramx_comps=${quote_paramx_comps%'\'}

    case $comps_flags in
    (*[DI]*)
      if [[ $COMPS =~ $rex_raw_paramx ]]; then
        local rematch1=${BASH_REMATCH[1]}
        quote_paramx_comps=$rematch1'${'${COMPS:${#rematch1}+1}'}'
      else
        # Note: 安全策 (本来上で一致する筈)
        quote_paramx_comps=$quote_paramx_comps'""'
      fi ;;
    (*)
      quote_paramx_comps=$quote_paramx_comps'\' ;;
    esac
  fi

  # 遡って書き換えた時に文脈を復元
  quote_trav_prefix=
  case $comps_flags in
  (*S*) quote_trav_prefix=\' ;;
  (*E*) quote_trav_prefix=\$\' ;;
  (*D*) quote_trav_prefix=\" ;;
  (*I*) quote_trav_prefix=\$\" ;;
  esac

  # 遡って書き換える時に comps_fixed には注意する。
  quote_fixed_comps=('')
  quote_fixed_compv=('')
  quote_fixed_comps_len=('')
  quote_fixed_compv_len=('')
  if [[ $comps_fixed ]]; then
    quote_fixed_compv=${comps_fixed#*:}
    quote_fixed_compv_len=${#quote_fixed_compv}
    quote_fixed_comps_len=${comps_fixed%%:*}
    quote_fixed_comps=${COMPS::quote_fixed_comps_len}
  fi

  # 遡って書き換える時に '/' 区切りでできるだけ元の展開を保持する。
  # comps_fixed[1] 以降に '/' 区切りで展開した結果を短い順に格納する。
  local i v
  for ((i=1;i<${#comps_fixed[@]};i++)); do
    v=${comps_fixed[i]#*:}
    quote_fixed_compv[i]=$v
    quote_fixed_compv_len[i]=${#v}
    quote_fixed_comps_len[i]=${comps_fixed[i]%%:*}
    quote_fixed_comps[i]=${COMPS::quote_fixed_comps_len[i]}
  done
}

## @fn ble/complete/action/quote-insert
# Note: この関数の処理は ble/complete/action/quote-insert.batch/awk と一貫して
# いる必要がある。この関数を変更する時には quote-insert.batch/awk にも等価の変
# 更を適用する必要がある。
function ble/complete/action/quote-insert {
  if [[ ! $quote_action ]]; then
    local "${_ble_complete_quote_insert_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/action/quote-insert.initialize "${1:-plain}"
  fi

  local escape_flags=$quote_escape_flags
  if [[ $quote_action == command ]]; then
    # Note (#D1715,#D1978): "*:noquote:*" の判定について。action=command
    #   DATA=:noquote: は alias 生成のみで使われる。そして alias 生成は
    #   yield.batch を使わずに直接 yield を呼び出して行われる。なので :noquote:
    #   の判定は awk batch の側では行わなくて良い。
    [[ $DATA == *:noquote:* || $COMPS == "$COMPV" && ( $CAND == '[[' || $CAND == '!' ) ]] && return 0
  elif [[ $quote_action == progcomp ]]; then
    [[ $comp_opts == *:noquote:* ]] && return 0
    [[ $comp_opts == *:ble/syntax-raw:* && $comp_opts != *:filenames:* ]] && return 0

    # bash-completion には compopt -o nospace として、
    # 自分でスペースを付加する補完関数がある。この時クォートすると問題。
    [[ $comp_opts == *:nospace:* && $CAND == *' ' && ! -f $CAND ]] && return 0

    # #D1362 Bash は "compopt -o filenames" が指定されていてかつ
    # '~' で始まる補完候補と同名のファイルがある時にのみチルダをクォートする。
    [[ $CAND == '~'* && ! ( $comp_opts == *:filenames:* && -e $CAND ) ]] &&
      escape_flags=T$escape_flags
  fi

  # 入力済み文字列への追記の場合、元の単語を保持する。
  if [[ $comps_flags == *v* && $CAND == "$COMPV"* ]]; then
    local ins ret
    ble/complete/string#escape-for-completion-context "${CAND:${#COMPV}}" "$escape_flags"; ins=$ret
    if [[ $comps_flags == *p* && $ins == [_a-zA-Z0-9]* ]]; then
      INSERT=$quote_paramx_comps$ins
    else
      [[ $quote_cont_cutbackslash ]] && ins=${ins#'\'}
      INSERT=$COMPS$ins;
    fi
    return 0
  fi

  # 遡って書き換わる場合には単語内のできるだけ長い部分パスを保持する。
  local i=${#quote_fixed_comps[@]}
  while ((--i>=0)); do
    if [[ ${quote_fixed_comps[i]} && $CAND == "${quote_fixed_compv[i]}"* ]]; then
      local ret; ble/complete/string#escape-for-completion-context "${CAND:quote_fixed_compv_len[i]}" "$escape_flags"
      INSERT=${quote_fixed_comps[i]}$quote_trav_prefix$ret
      return 0
    fi
  done

  # 既存の物に一致しない場合、完全に書き換える。
  local ret; ble/complete/string#escape-for-completion-context "$CAND" "$escape_flags"
  INSERT=$quote_trav_prefix$ret
}

function ble/complete/action/quote-insert.batch/awk {
  local q=\'
  local -x comp_opts=$comp_opts
  local -x comps=$COMPS
  local -x compv=$COMPV
  local -x comps_flags=$comps_flags
  local -x quote_action=$quote_action
  local -x quote_escape_flags=$quote_escape_flags
  local -x quote_paramx_comps=$quote_paramx_comps
  local -x quote_cont_cutbackslash=$quote_cont_cutbackslash
  local -x quote_trav_prefix=$quote_trav_prefix

  local -x quote_fixed_count=${#quote_fixed_comps[@]}
  local i
  for ((i=0;i<quote_fixed_count;i++)); do
    local -x "quote_fixed_comps$i=${quote_fixed_comps[i]}"
    local -x "quote_fixed_compv$i=${quote_fixed_compv[i]}"
  done

  "$quote_batch_awk" -v quote_batch_nulsep="$quote_batch_nulsep" -v q="$q" '
    function exists(filename) { return substr($0, 1, 1) == "1"; }
    function is_file(filename) { return substr($0, 2, 1) == "1"; }

    function initialize(_, flags, comp_opts, tmp, i) {
      IS_XPG4 = AWKTYPE == "xpg4";
      REP_SL = "\\";
      if (IS_XPG4) REP_SL = "\\\\";

      REP_DBL_SL = "\\\\"; # gawk, nawk
      sub(/.*/, REP_DBL_SL, tmp);
      if (tmp == "\\") REP_DBL_SL = "\\\\\\\\"; # mawk, xpg4

      Q = q "\\" q q;

      DELIM = 10;
      if (quote_batch_nulsep != "") {
        RS = "\0";
        DELIM = 0;
      }

      quote_action = ENVIRON["quote_action"];

      comps = ENVIRON["comps"];
      compv = ENVIRON["compv"];
      compv_len = length(compv);

      comps_flags = ENVIRON["comps_flags"];
      escape_type = 0;
      if (comps_flags ~ /S/)
        escape_type = 1;
      else if (comps_flags ~ /E/)
        escape_type = 2;
      else if (comps_flags ~ /[DI]/)
        escape_type = 3;
      else
        escape_type = 4;
      comps_v = (comps_flags ~ /v/);
      comps_p = (comps_flags ~ /p/);

      comp_opts = ENVIRON["comp_opts"];
      is_noquote = comp_opts ~ /:noquote:/;
      is_nospace = comp_opts ~ /:nospace:/;
      is_syntaxraw = comp_opts ~ /:ble\/syntax-raw:/ && comp_opts !~ /:filenames:/;

      flags = ENVIRON["quote_escape_flags"];
      escape_c = (flags ~ /c/);
      escape_b = (flags ~ /b/);
      escape_tilde_always = 1;
      escape_tilde_exists = 0;
      if (quote_action == "progcomp") {
        escape_tilde_always = 0;
        escape_tilde_exists = (comp_opts ~ /:filenames:/);
      }

      quote_cont_cutbackslash   = ENVIRON["quote_cont_cutbackslash"] != "";
      quote_paramx_comps        = ENVIRON["quote_paramx_comps"];
      quote_trav_prefix     = ENVIRON["quote_trav_prefix"];

      quote_fixed_count = ENVIRON["quote_fixed_count"];
      for (i = 0; i < quote_fixed_count; i++) {
        quote_fixed_comps[i]     = ENVIRON["quote_fixed_comps" i];
        quote_fixed_compv[i]     = ENVIRON["quote_fixed_compv" i];
        quote_fixed_comps_len[i] = length(quote_fixed_comps[i]);
        quote_fixed_compv_len[i] = length(quote_fixed_compv[i]);
      }
    }
    BEGIN { initialize(); }

    function escape_for_completion_context(text) {
      if (escape_type == 1) {
        # single quote
        gsub(/'$q'/, Q, text);
      } else if (escape_type == 2) {
        # escape string
        if (text ~ /[\\'$q'\a\b\t\n\v\f\r\033]/) {
          gsub(/\\/  , REP_DBL_SL, text);
          gsub(/'$q'/, REP_SL q  , text);
          gsub(/\007/, REP_SL "a", text);
          gsub(/\010/, REP_SL "b", text);
          gsub(/\011/, REP_SL "t", text);
          gsub(/\012/, REP_SL "n", text);
          gsub(/\013/, REP_SL "v", text);
          gsub(/\014/, REP_SL "f", text);
          gsub(/\015/, REP_SL "r", text);
          gsub(/\033/, REP_SL "e", text);
        }
      } else if (escape_type == 3) {
        # double quote
        gsub(/[\\"$`]/, "\\\\&", text); # Note: All awks behaves the same for "\\\\&"
      } else if (escape_type == 4) {
        # bash specialchars
        gsub(/[]\\ "'$q'`$|&;<>()!^*?[]/, "\\\\&", text);
        if (escape_c) gsub(/[=:]/, "\\\\&", text);
        if (escape_b) gsub(/[{,}]/, "\\\\&", text);
        if (ret ~ /^~/ && (escape_tilde_always || escape_tilde_exists && exists(cand)))
          text = "\\" text;
        gsub(/\n/, "$" q REP_SL "n" q, text);
        gsub(/\t/, "$" q REP_SL "t" q, text);
      }
      return text;
    }

    function quote_insert(cand, _, i) {
      # progcomp 特有
      if (quote_action == "command") {
        if (comps == compv && cand ~ /^(\[\[|]]|!)$/) return cand;
      } else if (quote_action == "progcomp") {
        if (is_noquote || is_syntaxraw) return cand;
        if (is_nospace && cand ~ / $/ && !is_file(cand)) return cand;
      }

      if (comps_v && substr(cand, 1, compv_len) == compv) {
        ins = escape_for_completion_context(substr(cand, compv_len + 1));
        if (comps_p && ins ~ /^[_a-zA-Z0-9]/) {
          return quote_paramx_comps ins;
        } else {
          if (quote_cont_cutbackslash) sub(/^\\/, "", ins);
          return comps ins;
        }
      }

      for (i = quote_fixed_count; --i >= 0; ) {
        if (quote_fixed_comps_len[i] && substr(cand, 1, quote_fixed_compv_len[i]) == quote_fixed_compv[i]) {
          ins = substr(cand, quote_fixed_compv_len[i] + 1);
          return quote_fixed_comps[i] quote_trav_prefix escape_for_completion_context(ins);
        }
      }

      return quote_trav_prefix escape_for_completion_context(cand);
    }

    {
      cand = substr($0, 3);
      insert = quote_insert(cand);
      printf("%s%c", insert, DELIM);
    }
  '
}
function ble/complete/action/quote-insert.batch/proc {
  local _ble_local_tmpfile; ble/util/assign/mktmp

  local delim='\n'
  [[ $quote_batch_nulsep ]] && delim='\0'
  if [[ $quote_action == progcomp ]]; then
    local cand file exist
    for cand in "${cands[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      f=0 e=0
      [[ -e $cand ]] && e=1
      [[ -f $cand ]] && f=1
      printf "$e$f%s$delim" "$cand"
    done
  else
    printf "00%s$delim" "${cands[@]}"
  fi >| "$_ble_local_tmpfile"

  local fname_cands=$_ble_local_tmpfile
  ble/util/conditional-sync \
    'ble/complete/action/quote-insert.batch/awk < "$fname_cands"' \
    '! ble/complete/check-cancel <&"$_ble_util_fd_stdin"' '' progressive-weight
  local ext=$?

  ble/util/assign/rmtmp
  return "$ext"
}
## @fn ble/complete/action/quote-insert.batch
##   @arr[in] cands
##   @arr[out] inserts
function ble/complete/action/quote-insert.batch {
  local opts=$1

  local quote_batch_nulsep=
  local quote_batch_awk=ble/bin/awk
  if [[ :$opts: != *:newline:* ]]; then
    if ((_ble_bash>=40400)); then
      if [[ $_ble_bin_awk_type == [mg]awk ]]; then
        quote_batch_nulsep=1
      elif ble/bin#has mawk; then
        quote_batch_nulsep=1
        quote_batch_awk=mawk
      elif ble/bin#has gawk; then
        quote_batch_nulsep=1
        quote_batch_awk=gawk
      fi
    fi
    [[ ! $quote_batch_nulsep ]] &&
      [[ "${cands[*]}" == *$'\n'* ]] &&
      return 1
  fi

  if [[ $quote_batch_nulsep ]]; then
    ble/util/assign-array0 inserts ble/complete/action/quote-insert.batch/proc
  else
    ble/util/assign-array inserts ble/complete/action/quote-insert.batch/proc
  fi
  return "$?"
}

## @fn ble/complete/action/requote-final-insert
##   @var[ref] insert insert_flags
function ble/complete/action/requote-final-insert {
  local threshold=$((bleopt_complete_requote_threshold))
  ((threshold>=0)) || return 0

  local comps_prefix= check_optarg=
  if [[ $insert == "$COMPS"* ]]; then
    [[ $comps_flags == *[SEDI]* ]] && return 0

    # Note: 以下の設定は遡って書き換える事を許す事になる
    [[ $COMPS != *[!':/={,'] ]] && comps_prefix=$COMPS
    check_optarg=$COMPS
  else
    # 遡って書き換える場合 (中途半端な quote 状態ではないと仮定)
    check_optarg=$insert
  fi

  # Note: --prefix='/usr/local', PREFIX='/usr/local', -L'/usr/local/share/lib'
  # 等、オプション・変数代入の右辺などの quote は、その開始点と思われる箇所から
  # 始める。
  if [[ $check_optarg ]]; then
    if ble/string#match "$check_optarg" '^([_a-zA-Z][_a-zA-Z0-9]*|-[-a-zA-Z0-9.]+)=(([^\'\''"`${}]*|\\.)*:)?'; then
      # --prefix= や PREFIX=, PATH=xxxx: 等があった場合には = や : の直後から quote する。
      comps_prefix=$BASH_REMATCH
    elif [[ $COMP_PREFIX == -[!'-=:/\'\''"$`{};&|<>!^{}'] && $check_optarg == "$COMP_PREFIX"* ]]; then
      # -L'/path/to/library' 等。COMP_PREFIX=-L かつ COMPS が -L で始まっている時のみ。
      comps_prefix=${check_optarg::2}
    fi
  fi

  if [[ $comps_fixed ]]; then
    local comps_fixed_part=${COMPS::${comps_fixed%%:*}}
    [[ $comps_prefix == "$comps_fixed_part"* ]] ||
      comps_prefix=$comps_fixed_part
  fi

  if [[ $insert == "$comps_prefix"* && $comps_prefix != *[!':/={,'] ]]; then
    local ret ins=${insert:${#comps_prefix}}
    if ! ble/syntax:bash/simple-word/is-literal "$ins" &&
        ble/syntax:bash/simple-word/safe-eval "$ins" &&
        ((${#ret[@]}==1))
    then
      ble/string#quote-word "$ret" quote-empty
      ((${#ret}+threshold<=${#ins})) || return 0
      insert=$comps_prefix$ret
      [[ $insert == "$COMPS"* ]] || insert_flags=r$insert_flags # 遡って書き換えた
    fi
  fi
  return 0
}

function ble/complete/action#inherit-from {
  local dst=$1 src=$2
  local member srcfunc dstfunc
  for member in initialize{,.batch} complete getg get-desc; do
    srcfunc=ble/complete/action:$src/$member
    dstfunc=ble/complete/action:$dst/$member
    ble/is-function "$srcfunc" && builtin eval "function $dstfunc { $srcfunc; }"
  done
}

# action:plain
function ble/complete/action:plain/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:plain/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:plain/complete {
  ble/complete/action/requote-final-insert
}

# action:literal-substr
function ble/complete/action:literal-substr/initialize { :; }
function ble/complete/action:literal-substr/initialize.batch { inserts=("${cands[@]}"); }
function ble/complete/action:literal-substr/complete { :; }

# action:substr (equivalent to plain)
function ble/complete/action:substr/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:substr/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:substr/complete {
  ble/complete/action/requote-final-insert
}

# action:literal-word
function ble/complete/action:literal-word/initialize { :; }
function ble/complete/action:literal-word/initialize.batch { inserts=("${cands[@]}"); }
function ble/complete/action:literal-word/complete {
  if [[ $comps_flags == *x* ]]; then
    ble/complete/action/complete.addtail ','
  else
    ble/complete/action/complete.addtail ' '
  fi
}

# action:word
#
#   DATA ... 候補の説明として使用する文字列を指定します
#
function ble/complete/action:word/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:word/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:word/complete {
  ble/complete/action/requote-final-insert
  ble/complete/action/complete.close-quotation
  ble/complete/action:literal-word/complete
}
function ble/complete/action:word/get-desc {
  [[ $DATA ]] && desc=$DATA
}

# action:file
# action:file_rhs (source:argument 内部使用)

## @fn ble/complete/action:file/.get-filename word
##   "compopt -o ble/syntax-raw" の場合も考慮してファイル名を抽出する。
##   Bash の振る舞いを見るとチルダ展開だけを実行する様だ。
##   @var[in] CAND DATA
function ble/complete/action:file/.get-filename {
  ret=$CAND
  if [[ $ACTION == progcomp && :$DATA: == *:ble/syntax-raw:* && $ret == '~'* ]]; then
    local tilde=${ret%%/*} chars='\ "'\''`$|&;<>()!^*?[=:{,}'
    [[ $tilde == *["$chars"]* ]] && return 0
    builtin eval "local expand=$tilde"
    [[ $expand == "$tilde" ]] && return 0
    ret=$expand${ret:${#tilde}}
  fi
}
function ble/complete/action:file/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:file/initialize.batch {
  ble/complete/action/quote-insert.batch
}
function ble/complete/action:file/complete {
  local ret
  ble/complete/action:file/.get-filename
  if [[ -e $ret || -h $ret ]]; then
    if [[ -d $ret ]]; then
      ble/complete/action/requote-final-insert
      ble/complete/action/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  else
    # Note (#D2096): When "compopt -o filenames" is specified by progcomp, the
    # candidates are processed by action:file/complete.  However, words that
    # are not local filenames can also be generated.  Such a word would also
    # want to be suffixed by a space.
    ble/complete/action:word/complete
  fi
}
function ble/complete/action:file/init-menu-item {
  local ret
  ble/complete/action:file/.get-filename; local file=$ret
  ble/syntax/highlight/getg-from-filename "$file"
  [[ $g ]] || { local ret; ble/color/face2g filename_warning; g=$ret; }

  if [[ :$comp_type: == *:vstat:* ]]; then
    if [[ -h $file ]]; then
      suffix='@'
    elif [[ -d $file ]]; then
      suffix='/'
    elif [[ -x $file ]]; then
      suffix='*'
    fi
  fi
}
function ble/complete/action:file_rhs/initialize {
  ble/complete/action:file/initialize
}
function ble/complete/action:file_rhs/initialize.batch {
  ble/complete/action:file/initialize.batch
}
function ble/complete/action:file_rhs/complete {
  CAND=${CAND:${#DATA}} ble/complete/action:file/complete
}
function ble/complete/action:file_rhs/init-menu-item {
  CAND=${CAND:${#DATA}} ble/complete/action:file/init-menu-item
}

_ble_complete_action_file_desc[_ble_attr_FILE_LINK]='symbolic link'
_ble_complete_action_file_desc[_ble_attr_FILE_ORPHAN]='symbolic link (orphan)'
_ble_complete_action_file_desc[_ble_attr_FILE_DIR]='directory'
_ble_complete_action_file_desc[_ble_attr_FILE_STICKY]='directory (sticky)'
_ble_complete_action_file_desc[_ble_attr_FILE_SETUID]='file (setuid)'
_ble_complete_action_file_desc[_ble_attr_FILE_SETGID]='file (setgid)'
_ble_complete_action_file_desc[_ble_attr_FILE_EXEC]='file (executable)'
_ble_complete_action_file_desc[_ble_attr_FILE_FILE]='file'
_ble_complete_action_file_desc[_ble_attr_FILE_CHR]='character device'
_ble_complete_action_file_desc[_ble_attr_FILE_FIFO]='named pipe'
_ble_complete_action_file_desc[_ble_attr_FILE_SOCK]='socket'
_ble_complete_action_file_desc[_ble_attr_FILE_BLK]='block device'
_ble_complete_action_file_desc[_ble_attr_FILE_URL]='URL'
function ble/complete/action:file/get-desc {
  local type; ble/syntax/highlight/filetype "$CAND"
  desc=${_ble_complete_action_file_desc[type]:-'file (???)'}
}

# action:progcomp
#
#   DATA ... compopt 互換のオプションをコロン区切りで指定します
#
## @fn ble/complete/action:progcomp/initialize/.reconstruct-from-noquote
##   @var[in,out] INSERT CAND
##   @var[in] progcomp_resolve_brace
function ble/complete/action:progcomp/initialize/.reconstruct-from-noquote {
  local simple_flags simple_ibrace ret count
  ble/syntax:bash/simple-word/is-simple-or-open-simple "$INSERT" &&
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$INSERT" &&
    ble/complete/source/eval-simple-word "$ret" single:count &&
    ((count==1)) || return 0

  CAND=$ret

  # ブレース展開がある時は逆に INSERT を補正し返す。
  if [[ $quote_fixed_comps && $CAND == "$quote_fixed_compv"* ]]; then
    local ret; ble/complete/string#escape-for-completion-context "${CAND:quote_fixed_compv_len}" "$escape_flags"
    INSERT=$quote_fixed_comps$quote_trav_prefix$ret
    return 3
  fi
  return 0
}

function ble/complete/action:progcomp/initialize {
  if [[ :$DATA: == *:noquote:* ]]; then
    local progcomp_resolve_brace=$quote_fixed_comps
    [[ :$DATA: == *:ble/syntax-raw:* ]] && progcomp_resolve_brace=
    ble/complete/action:progcomp/initialize/.reconstruct-from-noquote
    return 0
  else
    ble/complete/action/quote-insert progcomp
  fi
}
## @fn ble/complete/action:progcomp/initialize.batch
##   @arr[in] cands
##   @arr[out] inserts
function ble/complete/action:progcomp/initialize.batch {
  if [[ :$DATA: == *:noquote:* ]]; then
    inserts=("${cands[@]}")

    # Note: 直接 comp_words に対して補完した時は意図的にブレース展開を潰してい
    # ると解釈できるので、ブレース展開を復元する事はしない。
    local progcomp_resolve_brace=$quote_fixed_comps
    [[ :$DATA: == *:ble/syntax-raw:* ]] && progcomp_resolve_brace=

    cands=()
    local INSERT simple_flags simple_ibrace ret count icand=0
    for INSERT in "${inserts[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      local CAND=$INSERT
      ble/complete/action:progcomp/initialize/.reconstruct-from-noquote ||
        inserts[icand]=$INSERT # INSERT を上書きした時 ($?==3)
      cands[icand++]=$CAND
    done
  else
    ble/complete/action/quote-insert.batch newline
  fi
}

function ble/complete/action:progcomp/complete {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/complete
  else
    if [[ $DATA != *:ble/no-mark-directories:* && -d $CAND ]]; then
      ble/complete/action/requote-final-insert
      ble/complete/action/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  fi

  [[ $DATA == *:nospace:* ]] && suffix=${suffix%' '}
  [[ $DATA == *:ble/no-mark-directories:* && -d $CAND ]] && suffix=${suffix%/}
}
function ble/complete/action:progcomp/init-menu-item {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/init-menu-item
  fi
}
function ble/complete/action:progcomp/get-desc {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/get-desc
  fi
}

# action:command

function ble/complete/action:command/initialize {
  ble/complete/action/quote-insert command
}
function ble/complete/action:command/initialize.batch {
  ble/complete/action/quote-insert.batch newline
}
function ble/complete/action:command/complete {
  if [[ -d $CAND ]]; then
    ble/complete/action/complete.mark-directory
  elif ! type "$CAND" &>/dev/null; then
    # 関数名について縮約されたもので一意確定した時。
    #
    # Note: 関数名について縮約されている時、
    #   本来は一意確定でなくても一意確定として此処に来ることがある。
    #   そのコマンドが存在していない時に、縮約されていると判定する。
    #
    if [[ $CAND == */ ]]; then
      # 縮約されていると想定し続きの補完候補を出す。
      insert_flags=${insert_flags}n
    fi
  else
    ble/complete/action:word/complete
  fi
}
function ble/complete/action:command/init-menu-item {
  if [[ -d $CAND ]]; then
    local ret; ble/color/face2g filename_directory; g=$ret
  else
    local type
    if [[ $CAND != "$INSERT" ]]; then
      ble/syntax/highlight/cmdtype "$CAND" "$INSERT"
    else
      # Note: ble/syntax/highlight/cmdtype はキャッシュ機能がついているが、
      #   キーワードに対して呼び出さない前提なのでキーワードを渡すと
      #   _ble_attr_ERR を返してしまう。
      local type; ble/util/type type "$CAND"
      ble/syntax/highlight/cmdtype1 "$type" "$CAND"
    fi
    if [[ $CAND == */ ]] && ((type==_ble_attr_ERR)); then
      type=_ble_attr_CMD_FUNCTION
    fi
    ble/syntax/attr2g "$type"
  fi
}

_ble_complete_action_command_desc[_ble_attr_CMD_BOLD]=builtin
_ble_complete_action_command_desc[_ble_attr_CMD_BUILTIN]=builtin
_ble_complete_action_command_desc[_ble_attr_CMD_ALIAS]=alias
_ble_complete_action_command_desc[_ble_attr_CMD_FUNCTION]=function
_ble_complete_action_command_desc[_ble_attr_CMD_FILE]=file
_ble_complete_action_command_desc[_ble_attr_KEYWORD]=command
_ble_complete_action_command_desc[_ble_attr_CMD_JOBS]=job
_ble_complete_action_command_desc[_ble_attr_ERR]='command ???'
_ble_complete_action_command_desc[_ble_attr_CMD_DIR]=directory
function ble/complete/action:command/get-desc {
  local title= value=
  if [[ -d $CAND ]]; then
    title=directory
  else
    local type; ble/util/type type "$CAND"
    ble/syntax/highlight/cmdtype1 "$type" "$CAND"

    case $type in
    ($_ble_attr_CMD_ALIAS)
      local ret
      ble/alias#expand "$CAND"
      title=alias value=$ret ;;
    ($_ble_attr_CMD_FILE)
      local path; ble/util/assign path 'type -p -- "$CAND"'
      [[ $path == ?*/"$CAND" ]] && path="from ${path%/"$CAND"}"
      title=file value=$path ;;
    ($_ble_attr_CMD_FUNCTION)

      local source lineno
      ble/function#get-source-and-lineno "$CAND"

      local def; ble/function#getdef "$CAND"
      ble/string#match "$def" '^[^()]*\(\)[[:space:]]*\{[[:space:]]+(.*[^[:space:]])[[:space:]]+\}[[:space:]]*$' &&
        def=${BASH_REMATCH[1]} # 関数の中身を抽出する
      local ret sgr0=$'\e[27m' sgr1=$'\e[7m' # Note: sgr-ansi で生成
      lines=1 cols=${COLUMNS:-80} x=0 y=0 ble/canvas/trace-text "$def" external-sgr

      title=function value="${source##*/}:$lineno $desc_sgrq$ret" ;;
    ($_ble_attr_CMD_JOBS)
      ble/util/joblist.check
      local job; ble/util/assign job 'jobs -- "$CAND" 2>/dev/null' || job='???'
      title=job value=${job:-(ambiguous)} ;;
    ($_ble_attr_ERR)
      if [[ $CAND == */ ]]; then
        title='function namespace'
      else
        title=${_ble_complete_action_command_desc[_ble_attr_ERR]}
      fi ;;
    (*)
      title=${_ble_complete_action_command_desc[type]:-'???'} ;;
    esac
  fi
  desc=${title:+$desc_sgrt($title)$desc_sgr0}${value:+ $value}
}

# action:variable
#
#   DATA ... 変数名の文脈を指定します。
#     assignment braced word arithmetic の何れかです。
#
function ble/complete/action:variable/initialize { ble/complete/action/quote-insert; }
function ble/complete/action:variable/initialize.batch { ble/complete/action/quote-insert.batch newline; }
function ble/complete/action:variable/complete {
  case $DATA in
  (assignment)
    # var= 等に於いて = を挿入
    ble/complete/action/complete.addtail '=' ;;
  (braced)
    # ${var 等に於いて } を挿入
    ble/complete/action/complete.addtail '}' ;;
  (word)       ble/complete/action:word/complete ;;
  (arithmetic|nosuffix) ;; # do nothing
  esac
}
function ble/complete/action:variable/init-menu-item {
  local ret; ble/color/face2g syntax_varname; g=$ret
}
function ble/complete/action:variable/get-desc {
  local _ble_local_title=variable
  if ble/is-array "$CAND"; then
    _ble_local_title=array
  elif ble/is-assoc "$CAND"; then
    _ble_local_title=assoc
  fi

  local _ble_local_value=
  if [[ $_ble_local_title == array || $_ble_local_title == assoc ]]; then
    builtin eval "local count=\${#$CAND[@]}"
    if ((count==0)); then
      count=empty
    else
      count="$count items"
    fi
    _ble_local_value=$'\e[94m['$count$']\e[m'
  else
    local ret; ble/string#quote-word "${!CAND}" ansi:sgrq="$desc_sgrq":quote-empty
    _ble_local_value=$ret
  fi
  desc="$desc_sgrt($_ble_local_title)$desc_sgr0 $_ble_local_value"
}

#------------------------------------------------------------------------------
# source

## @fn ble/complete/source/test-limit value
##   Tests whether "value" exceeds the completion limit
##   specified by bleopt complete_limit or complete_limit_auto.
##
##   @var[in] comp_type
##   @var[in,out] cand_limit_reached
##
function ble/complete/source/test-limit {
  local value=$1 limit=
  if [[ :$comp_type: == *:auto_menu:* && $bleopt_complete_limit_auto_menu ]]; then
    limit=$bleopt_complete_limit_auto_menu
  elif [[ :$comp_type: == *:auto:* && $bleopt_complete_limit_auto ]]; then
    limit=$bleopt_complete_limit_auto
  else
    limit=$bleopt_complete_limit
  fi

  if [[ $limit && value -gt limit ]]; then
    cand_limit_reached=1

    # Note: #D1618 自動候補一覧表示で失敗した時は不完全なリストが生成
    #   されるのを防ぐ為に補完全体をキャンセルする。
    [[ :$comp_type: == *:auto_menu: ]] && cand_limit_reached=cancel
    return 1
  else
    return 0
  fi
}

## @fn ble/complete/source/eval-simple-word
## @fn ble/complete/source/evaluate-path-spec
##   補完用の中断設定・timeout設定(auto-complete時のみ)を指定して、
##   それぞれ simple-word/{eval,evaluate-path-spec} を呼び出します。
##
## 注意: 現在の実装では、ユーザー入力による中断 148 及びtimeout による
## 中断 142 の両方に対してこれらの関数は 148 を返す様に振る舞いを変更
## している。呼び出し元で両方を区別なく取り扱うのに都合が良い為。
##
function ble/complete/source/eval-simple-word {
  local word=$1 opts=$2
  if [[ :$comp_type: != *:sync:* && :$opts: != *:noglob:* ]]; then
    opts=$opts:stopcheck:cached
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      opts=$opts:timeout=$((bleopt_complete_timeout_auto))
  fi
  ble/syntax:bash/simple-word/eval "$word" "$opts"; local ext=$?
  ((ext==142)) && return 148
  return "$ext"
}
function ble/complete/source/evaluate-path-spec {
  local word=$1 sep=$2 opts=$3
  if [[ :$comp_type: != *:sync:* && :$opts: != *:noglob:* ]]; then
    opts=$opts:stopcheck:cached:single
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      opts=$opts:timeout=$((bleopt_complete_timeout_auto))
  fi
  ble/syntax:bash/simple-word/evaluate-path-spec "$word" "$sep" "$opts"; local ext=$?
  ((ext==142)) && return 148
  return "$ext"
}


## @fn ble/complete/source/reduce-compv-for-ambiguous-match
##   曖昧補完の為に擬似的な COMPV と COMPS を生成・設定します。
##   @var[in,out] COMPS COMPV
function ble/complete/source/reduce-compv-for-ambiguous-match {
  [[ :$comp_type: == *:[maA]:* ]] || return 0

  local comps=$COMPS compv=$COMPV
  local comps_prefix= compv_prefix=
  if [[ $comps_fixed ]]; then
    comps_prefix=${comps::${comps_fixed%%:*}}
    compv_prefix=${comps_fixed#*:}
    compv=${COMPV:${#compv_prefix}}
  fi

  case $comps_flags in
  (*S*) comps_prefix=$comps_prefix\' ;;
  (*E*) comps_prefix=$comps_prefix\$\' ;;
  (*D*) comps_prefix=$comps_prefix\" ;;
  (*I*) comps_prefix=$comps_prefix\$\" ;;
  esac

  if [[ $compv && :$comp_type: == *:a:* ]]; then
    compv=${compv::1}
    ble/complete/string#escape-for-completion-context "$compv"
    comps=$ret
  else
    compv= comps=
  fi

  COMPV=$compv_prefix$compv
  COMPS=$comps_prefix$comps
}


_ble_complete_yield_varnames=("${_ble_complete_quote_insert_varnames[@]}")

## @fn ble/complete/cand/yield.initialize action
function ble/complete/cand/yield.initialize {
  ble/complete/action/quote-insert.initialize "$1"
}

## @fn ble/complete/cand/yield ACTION CAND DATA
##   @param[in] ACTION
##   @param[in] CAND
##   @param[in] DATA
##   @var[in] COMP_PREFIX
##   @var[in] flag_force_fignore
##   @var[in] flag_source_filter
function ble/complete/cand/yield {
  local ACTION=$1 CAND=$2 DATA=$3
  [[ $flag_force_fignore ]] && ! ble/complete/.fignore/filter "$CAND" && return 0
  [[ $flag_source_filter ]] || ble/complete/candidates/filter#test "$CAND" || return 0

  local INSERT=$CAND
  ble/complete/action:"$ACTION"/initialize || return "$?"

  local PREFIX_LEN=0
  [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_word[icand]=$INSERT
  cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
}

## @fn ble/complete/cand/yield.batch action data
##   @arr[in] cands
function ble/complete/cand/yield.batch {
  local ACTION=$1 DATA=$2

  local inserts threshold=500
  [[ $OSTYPE == cygwin* || $OSTYPE == msys* ]] && threshold=2000
  if ((${#cands[@]}>=threshold)) && ble/function#try ble/complete/action:"$ACTION"/initialize.batch; then
    local i n=${#cands[@]}
    for ((i=0;i<n;i++)); do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      local CAND=${cands[i]} INSERT=${inserts[i]}

      [[ $flag_force_fignore ]] && ! ble/complete/.fignore/filter "$CAND" && continue
      [[ $flag_source_filter ]] || ble/complete/candidates/filter#test "$CAND" || continue

      local PREFIX_LEN=0
      [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

      local icand
      ((icand=cand_count++))
      cand_cand[icand]=$CAND
      cand_word[icand]=$INSERT
      cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
    done
  else
    local cand
    for cand in "${cands[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      ble/complete/cand/yield "$ACTION" "$cand" "$DATA"
    done
  fi
}

function ble/complete/cand/yield-filenames {
  local action=$1; shift

  local rex_hidden=
  [[ :$comp_type: != *:match-hidden:* ]] &&
    rex_hidden=${COMPV:+'.{'${#COMPV}'}'}'(^|/)\.[^/]*$'

  local -a cands=()
  local cand icand=0
  for cand; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    [[ $rex_hidden && $cand =~ $rex_hidden ]] && continue
    cands[icand++]=$cand
  done

  [[ $FIGNORE ]] && local flag_force_fignore=1
  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  ble/complete/cand/yield.batch "$action"
}

_ble_complete_cand_varnames=(ACTION CAND INSERT DATA PREFIX_LEN)

## @fn ble/complete/cand/unpack data
##   @param[in] data
##     ACTION:ncand,ninsert,PREFIX_LEN:$CAND$INSERT$DATA
##   @var[out] ACTION CAND INSERT DATA PREFIX_LEN
function ble/complete/cand/unpack {
  local pack=$1
  ACTION=${pack%%:*} pack=${pack#*:}
  local text=${pack#*:}
  IFS=, builtin eval 'pack=(${pack%%:*})'
  CAND=${text::pack[0]}
  INSERT=${text:pack[0]:pack[1]}
  DATA=${text:pack[0]+pack[1]}
  PREFIX_LEN=${pack[2]}
}

## 定義されている source
##
##   source:wordlist
##   source:command
##   source:file
##   source:dir
##   source:argument
##   source:variable
##
## source の実装
##
## @fn ble/complete/source:$name args...
##   @param[in] args...
##     ble/syntax/completion-context/generate で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##   @var[in] comp_filter_type
##   @var[out] COMP_PREFIX
##     ble/complete/cand/yield で参照される一時変数。
##
##   @var[in,out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached

# source:none
function ble/complete/source:none { return 0; }

# source:wordlist
#
#  -r 指定された単語をエスケープせずにそのまま挿入する
#  -W 補完完了時に空白を挿入しない
#  -s sabbrev 候補も一緒に生成する
#
function ble/complete/source:wordlist {
  [[ $comps_flags == *v* ]] || return 1
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # process options
  local opt_raw= opt_noword= opt_sabbrev=
  while (($#)) && [[ $1 == -* ]]; do
    local arg=$1; shift
    case $arg in
    (--) break ;;
    (--*) ;; # ignore
    (-*)
      local i iN=${#arg}
      for ((i=1;i<iN;i++)); do
        case ${arg:i:1} in
        (r) opt_raw=1 ;;
        (W) opt_noword=1 ;;
        (s) opt_sabbrev=1 ;;
        (*) ;; # ignore
        esac
      done ;;
    esac
  done

  [[ $opt_sabbrev ]] &&
    ble/complete/source:sabbrev

  local action=word
  [[ $opt_noword ]] && action=substr
  [[ $opt_raw ]] && action=literal-$action

  local cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand; do
    [[ $cand == "$COMPV"* ]] && ble/complete/cand/yield "$action" "$cand"
  done
}

# source:command

function ble/complete/source:command/.contract-by-slashes {
  local slashes=${COMPV//[!'/']}
  ble/bin/awk -F / -v baseNF="${#slashes}" '
    function initialize_common() {
      common_NF = NF;
      for (i = 1; i <= NF; i++) common[i] = $i;
      common_degeneracy = 1;
      common0_NF = NF;
      common0_str = $0;
    }
    function print_common(_, output) {
      if (!common_NF) return;

      if (common_degeneracy == 1) {
        print common0_str;
        common_NF = 0;
        return;
      }

      output = common[1];
      for (i = 2; i <= common_NF; i++)
        output = output "/" common[i];

      # Note:
      #   For candidates `a/b/c/1` and `a/b/c/2`, prints `a/b/c/`.
      #   For candidates `a/b/c` and `a/b/c/1`, prints `a/b/c` and `a/b/c/1`.
      if (common_NF == common0_NF) print output;
      print output "/";

      common_NF = 0;
    }

    {
      if (NF <= baseNF + 1) {
        print_common();
        print $0;
      } else if (!common_NF) {
        initialize_common();
      } else {
        n = common_NF < NF ? common_NF : NF;
        for (i = baseNF + 1; i <= n; i++)
          if (common[i] != $i) break;
        matched_length = i - 1;

        if (matched_length <= baseNF) {
          print_common();
          initialize_common();
        } else {
          common_NF = matched_length;
          common_degeneracy++;
        }
      }
    }

    END { print_common(); }
  '
}

## @fn ble/complete/source:command/gen.1
function ble/complete/source:command/gen.1 {
  # Note #D1922: パス名コマンドの曖昧補完は compgen -c ではなく自前で処理する。
  # ディレクトリ名に関しては ble/complete/source:command/gen の側で生成されるの
  # でここでは生成しない。
  if [[ $COMPV == */* && :$comp_type: == *:[maA]:* ]]; then
    local ret
    ble/complete/source:file/.construct-pathname-pattern "$COMPV"
    ble/complete/util/eval-pathname-expansion "$ret"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ble/array#filter ret '[[ ! -d $1 && -x $1 ]]'
    ((${#ret[@]})) && printf '%s\n' "${ret[@]}"

    local COMPS=$COMPS COMPV=$COMPV
    ble/complete/source/reduce-compv-for-ambiguous-match

  else
    local COMPS=$COMPS COMPV=$COMPV
    ble/complete/source/reduce-compv-for-ambiguous-match

    # Note: cygwin では cyg,x86,i68 等で始まる場合にとても遅い。他の環境でも空
    #   の補完を実行すると遅くなる可能性がある。
    local slow_compgen=
    if [[ ! $COMPV ]]; then
      slow_compgen=1
    elif [[ $OSTYPE == cygwin* ]]; then
      case $COMPV in
      (?|cy*|x8*|i6*)
        slow_compgen=1 ;;
      esac
    fi

    # Note: 何故か compgen -A command はクォート除去が実行されない。compgen -A
    #   function はクォート除去が実行される。従って、compgen -A command には直
    #   接 COMPV を渡し、compgen -A function には compv_quoted を渡す。
    if [[ $slow_compgen ]]; then
      shopt -q no_empty_cmd_completion && return 0
      ble/util/conditional-sync \
        'builtin compgen -c -- "$COMPV"' \
        '! ble/complete/check-cancel' 128 progressive-weight
    else
      builtin compgen -c -- "$COMPV"
    fi
  fi

  if [[ $COMPV == */* ]]; then
    local q="'" Q="'\''"
    local compv_quoted="'${COMPV//$q/$Q}'"
    builtin compgen -A function -- "$compv_quoted"
  fi
}

function ble/complete/source:command/gen {
  if [[ :$comp_type: != *:[maA]:* && $bleopt_complete_contract_function_names ]]; then
    ble/complete/source:command/gen.1 |
      ble/complete/source:command/.contract-by-slashes
  else
    ble/complete/source:command/gen.1
  fi

  # ディレクトリ名列挙 (/ 付きで生成する)
  #
  #   Note: shopt -q autocd &>/dev/null かどうかに拘らず列挙する。
  #
  #   Note: compgen -A directory (以下のコード参照) はバグがあって、
  #     bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     [[ :$comp_type: == *:a:* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  #     compgen -A directory -S / -- "$compv_quoted"
  #
  if [[ $arg != *D* ]]; then
    local ret
    ble/complete/source:file/.construct-pathname-pattern "$COMPV"
    ble/complete/util/eval-pathname-expansion "$ret/"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
  fi

  # ジョブ名列挙
  if [[ ! $COMPV || $COMPV == %* ]]; then
    # %コマンド名
    local q="'" Q="'\''"
    local compv_quoted=${COMPV#'%'}
    compv_quoted="'${compv_quoted//$q/$Q}'"
    builtin compgen -j -P % -- "$compv_quoted"

    # %ジョブ番号
    local i joblist; ble/util/joblist
    local job_count=${#joblist[@]}
    for i in "${!joblist[@]}"; do
      if local rex='^\[([0-9]+)\]'; [[ ${joblist[i]} =~ $rex ]]; then
        joblist[i]=%${BASH_REMATCH[1]}
      else
        builtin unset -v 'joblist[i]'
      fi
    done
    joblist=("${joblist[@]}")

    # %% %+ %-
    if ((job_count>0)); then
      ble/array#push joblist %% %+
      ((job_count>=2)) &&
        ble/array#push joblist %-
    fi

    builtin compgen -W '"${joblist[@]}"' -- "$compv_quoted"
  fi
}
## ble/complete/source:command arg
##   @param[in] arg
##     arg に D が含まれている時、
##     ディレクトリ名の列挙を抑制する事を表します。
function ble/complete/source:command {
  [[ $comps_flags == *v* ]] || return 1
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  local arg=$1

  # Try progcomp by "complete -p -I" / "complete -p _InitialWorD_"
  {
    local old_cand_count=$cand_count

    local comp_opts=:
    ble/complete/source:argument/.generate-user-defined-completion initial; local ext=$?
    ((ext==148)) && return "$ext"
    if ((ext==0)); then
      ((cand_count>old_cand_count)) && return "$ext"
    fi
  }

  ble/complete/source:sabbrev

  local arr
  local compgen
  ble/util/assign compgen 'ble/complete/source:command/gen "$arg"'
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'ble/bin/sort -u <<< "$compgen"' # 1 fork/exec

  ble/complete/source/test-limit "${#arr[@]}" || return 1

  local action=command "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"

  # 無効 keyword, alias 判定用
  local is_quoted=
  [[ $COMPS != "$COMPV" ]] && is_quoted=1
  local rex_keyword='^(if|then|else|elif|fi|case|esac|for|select|while|until|do|done|function|time|[!{}]|\[\[|coproc|\]\]|in)$'
  local expand_aliases=
  shopt -q expand_aliases && expand_aliases=1

  local cand icand=0 cands
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    if [[ $is_quoted ]]; then
      local disable_count=
      # #D1691 keyword は quote されている場合には無効
      [[ $cand =~ $rex_keyword ]] && ((disable_count++))
      # #D1715 alias も quote されている場合には無効
      [[ $expand_aliases ]] && ble/is-alias "$cand" && ((disable_count++))
      if [[ $disable_count ]]; then
        local type; ble/util/type type "$cand"
        ((${#type[@]}>disable_count)) || continue
      fi
    else
      # 'in' と ']]' は alias でない限り常にエラー
      [[ $cand == ']]' || $cand == in ]] &&
        ! { [[ $expand_aliases ]] && ble/is-alias "$cand"; } &&
        continue

      if [[ ! $expand_aliases ]]; then
        # #D1715 expand_aliases が無効でも compgen -c は alias を列挙してしまうので、
        # ここで alias は除外 (type は expand_aliases をちゃんと考慮してくれる)。
        ble/is-alias "$cand" && ! type "$cand" &>/dev/null && continue
      fi

      # alias は quote されては困るので、quote される可能性のある文字を含んでい
      # る場合は個別に :noquote: 指定で yield する [ Note: alias 内で許される特
      # 殊文字は !#%-~^[]{}+*:@,.?_ である。更にその中で escape/quote の対象と
      # なり得る文字は、[*?]{,}!^~#: だけである。_.@+%- は quote されない ]。
      if ble/string#match "$cand" '[][*?{,}!^~#]' && ble/is-alias "$cand"; then
        ble/complete/cand/yield "$action" "$cand" :noquote:
        continue
      fi
    fi

    cands[icand++]=$cand
  done
  ble/complete/cand/yield.batch "$action"
}

# source:file, source:dir

function ble/complete/util/eval-pathname-expansion/.print-def {
  local pattern=$1 ret
  IFS= builtin eval "ret=($pattern)" 2>/dev/null
  ble/string#quote-words "${ret[@]}"
  ble/util/print "ret=($ret)"
}

## @fn ble/complete/util/eval-pathname-expansion pattern
##   @var[out] ret
function ble/complete/util/eval-pathname-expansion {
  local pattern=$1

  local -a dtor=()

  if [[ -o noglob ]]; then
    set +f
    ble/array#push dtor 'set -f'
  fi

  if ! shopt -q nullglob; then
    shopt -s nullglob
    ble/array#push dtor 'shopt -u nullglob'
  fi

  if ! shopt -q dotglob; then
    shopt -s dotglob
    ble/array#push dtor 'shopt -u dotglob'
  else
    # GLOBIGNORE に触ると設定が変わるので
    # dotglob は明示的に保存・復元する。
    ble/array#push dtor 'shopt -s dotglob'
  fi

  if ! shopt -q extglob; then
    shopt -s extglob
    ble/array#push dtor 'shopt -u extglob'
  fi

  if [[ :$comp_type: == *:i:* ]]; then
    if ! shopt -q nocaseglob; then
      shopt -s nocaseglob
      ble/array#push dtor 'shopt -u nocaseglob'
    fi
  else
    if shopt -q nocaseglob; then
      shopt -u nocaseglob
      ble/array#push dtor 'shopt -s nocaseglob'
    fi
  fi

  if ble/util/is-cygwin-slow-glob "$pattern"; then # Note: #D1168
    if shopt -q failglob &>/dev/null || shopt -q nullglob &>/dev/null; then
      pattern=
    else
      set -f
      ble/array#push dtor 'set +f'
    fi
  fi

  if [[ $GLOBIGNORE ]]; then
    local GLOBIGNORE_save=$GLOBIGNORE
    GLOBIGNORE=
    ble/array#push dtor 'GLOBIGNORE=$GLOBIGNORE_save'
  fi

  ble/array#reverse dtor

  ret=()
  if [[ :$comp_type: == *:sync:* ]]; then
    IFS= builtin eval "ret=($pattern)" 2>/dev/null
  else
    local sync_command='ble/complete/util/eval-pathname-expansion/.print-def "$pattern"'
    local sync_opts=progressive-weight
    [[ :$comp_type: == *:auto:* && $bleopt_complete_timeout_auto ]] &&
      sync_opts=$sync_opts:timeout=$((bleopt_complete_timeout_auto))

    local def
    ble/util/assign def 'ble/util/conditional-sync "$sync_command" "" "" "$sync_opts"' &>/dev/null; local ext=$?
    if ((ext==148)) || ble/complete/check-cancel; then
      ble/util/invoke-hook dtor
      return 148
    fi
    builtin eval -- "$def"
  fi 2>&"$_ble_util_fd_stderr"

  ble/util/invoke-hook dtor
  return 0
}

## @fn ble/complete/source:file/.construct-ambiguous-pathname-pattern path
##   指定された path に対応する曖昧一致パターンを生成します。
##   例えば alpha/beta/gamma に対して a*/b*/g* でファイル名を生成します。
##   但し "../" や "./" については (".*.*/" や ".*/" 等に変換せず) そのままにします。
##
##   @param[in] path
##   @var[out] ret
##
##   @remarks
##     当初は a*/b*/g* で生成して、後のフィルタに一致しないものの除外を一任していたが遅い。
##     従って、a*l*p*h*a*/b*e*t*a*/g*a*m*m*a* の様なパターンを生成する様に変更した。
##
function ble/complete/source:file/.construct-ambiguous-pathname-pattern {
  local path=$1 fixlen=${2:-1}
  local pattern= i=0 j
  local names; ble/string#split names / "$1"
  local name
  for name in "${names[@]}"; do
    ((i++)) && pattern=$pattern/
    if [[ $name == .. || $name == . && i -lt ${#names[@]} ]]; then
      pattern=$pattern$name
    elif [[ $name ]]; then
      ble/string#quote-word "${name::fixlen}"
      pattern=$pattern$ret*
      for ((j=fixlen;j<${#name};j++)); do
        ble/string#quote-word "${name:j:1}"
        if [[ $_ble_bash -lt 50000 && $pattern == *\* ]]; then
          # * を extglob *([!ch]) に変換 #D1389
          pattern=$pattern'([!'$ret'])'
        fi
        pattern=$pattern$ret*
      done
    fi
  done
  [[ $pattern == *'*' ]] || pattern=$pattern*
  ret=$pattern
}
## @fn ble/complete/source:file/.construct-pathname-pattern path
##   @param[in] path
##   @var[out] ret
function ble/complete/source:file/.construct-pathname-pattern {
  local path=$1 pattern
  case :$comp_type: in
  (*:a:*) ble/complete/source:file/.construct-ambiguous-pathname-pattern "$path"; pattern=$ret ;;
  (*:A:*) ble/complete/source:file/.construct-ambiguous-pathname-pattern "$path" 0; pattern=$ret ;;
  (*:m:*) ble/string#quote-word "$path"; pattern=*$ret* ;;
  (*) ble/string#quote-word "$path"; pattern=$ret*
  esac
  ret=$pattern
}

function ble/complete/source:file/.impl {
  local opts=$1
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: != *:[maA]:* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  # 入力文字列が空の場合は曖昧補完は本質的に通常の補完と同じなのでスキップ
  [[ :$comp_type: == *:[maA]:* && ! $COMPV ]] && return 1

  #   Note: compgen -A file/directory (以下のコード参照) はバグがあって、
  #     bash-4.0 と 4.1 でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #     local candidates; ble/util/assign-array candidates 'builtin compgen -A file -- "$compv_quoted"'

  ble/complete/source:tilde; local ext=$?
  ((ext==148||ext==0)) && return "$ext"

  local -a candidates=()
  local ret
  ble/complete/source:file/.construct-pathname-pattern "$COMPV"
  [[ :$opts: == *:directory:* ]] && ret=$ret/
  ble/complete/util/eval-pathname-expansion "$ret"; (($?==148)) && return 148
  ble/complete/source/test-limit "${#ret[@]}" || return 1

  if [[ :$opts: == *:directory:* ]]; then
    candidates=("${ret[@]%/}")
  else
    candidates=("${ret[@]}")
  fi
  [[ :$opts: == *:no-fd:* ]] &&
    ble/array#remove-by-regex candidates '^[0-9]+-?$|^-$'

  local flag_source_filter=1
  ble/complete/cand/yield-filenames file "${candidates[@]}"
}

function ble/complete/source:file {
  ble/complete/source:file/.impl "$1"
}
function ble/complete/source:dir {
  ble/complete/source:file/.impl "directory:$1"
}

# source:rhs

function ble/complete/source:rhs { ble/complete/source:file; }

#------------------------------------------------------------------------------
# source:tilde

function ble/complete/action:tilde/initialize {
  # チルダは quote しない
  CAND=${CAND#\~} ble/complete/action/quote-insert
  INSERT=\~$INSERT

  # Note: Windows 等でチルダ展開の無効なユーザー名があるのでチェック
  local rex='^~[^/'\''"$`\!:]*$'; [[ $INSERT =~ $rex ]]
}
function ble/complete/action:tilde/complete {
  ble/complete/action/complete.mark-directory
}
function ble/complete/action:tilde/init-menu-item {
  local ret
  ble/color/face2g filename_directory; g=$ret
}
function ble/complete/action:tilde/get-desc {
  if [[ $CAND == '~+' ]]; then
    desc='current directory (tilde expansion)'
  elif [[ $CAND == '~-' ]]; then
    desc='previous directory (tilde expansion)'
  elif local rex='^~[0-9]$'; [[ $CAND =~ $rex ]]; then
    desc='DIRSTACK directory (tilde expansion)'
  else
    desc='user directory (tilde expansion)'
  fi
}

function ble/complete/source:tilde/.generate {
  # generate user directories
  local pattern=${COMPS#\~}
  [[ :$comp_type: == *:[maA]:* ]] && pattern=
  builtin compgen -P \~ -u -- "$pattern"

  # generate special tilde expansions
  printf '%s\n' '~' '~+' '~-'
  local dirstack_max=$((${#DIRSTACK[@]}-1))
  ((dirstack_max>=0)) &&
    builtin eval "printf '%s\n' '~'{0..$dirstack_max}"

}

# tilde expansion
function ble/complete/source:tilde {
  local rex='^~[^/'\''"$`\!:]*$'; [[ $COMPS =~ $rex ]] || return 1

  # Generate candidates
  #   Note: Windows で同じユーザ名が compgen によって
  #   複数回列挙されるので sort -u を実行する。
  local compgen candidates
  ble/util/assign compgen ble/complete/source:tilde/.generate
  [[ $compgen ]] || return 1
  ble/util/assign-array candidates 'ble/bin/sort -u <<< "$compgen"'

  # COMPS を用いて自前でフィルタ
  local flag_source_filter=1
  if [[ $COMPS == '~'?* ]]; then
    local filter_type=$comp_filter_type
    [[ $filter_type == none ]] && filter_type=head
    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPS"
    ble/array#filter candidates ble/complete/candidates/filter#test
  fi

  ((${#candidates[@]})) || return 1

  local old_cand_count=$cand_count
  ble/complete/cand/yield-filenames tilde "${candidates[@]}"; local ext=$?
  return "$((ext?ext:cand_count>old_cand_count))"
}

function ble/complete/source:fd {
  IFS=: builtin eval 'local fdlist=":${_ble_util_openat_fdlist[*]}:"'

  [[ $comp_filter_type == none ]] &&
    local comp_filter_type=head

  local old_cand_count=$cand_count
  local action=word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  ble/complete/cand/yield "$action" -
  if [[ -d /proc/self/fd ]]; then
    local ret
    ble/complete/util/eval-pathname-expansion '/proc/self/fd/*'

    local fd
    for fd in "${ret[@]}"; do
      fd=${fd#/proc/self/fd/}
      [[ ${fd//[0-9]} ]] && continue
      [[ $fdlist == *:"$fd":* ]] && continue
      ble/complete/cand/yield "$action" "$fd"
      ble/complete/cand/yield "$action" "$fd-"
    done
  else
    local fd
    for ((fd=0;fd<10;fd++)); do
      ble/fd#is-open "$fd" || continue
      ble/complete/cand/yield "$action" "$fd"
      ble/complete/cand/yield "$action" "$fd-"
    done
  fi

  return "$((cand_count>old_cand_count))"
}

#------------------------------------------------------------------------------
# progcomp

# progcomp/.compgen

## @fn ble/complete/progcomp/.compvar-initialize-wordbreaks
##   @var[out] wordbreaks
function ble/complete/progcomp/.compvar-initialize-wordbreaks {
  local ifs=$_ble_term_IFS q=\'\" delim=';&|<>()' glob='[*?' hist='!^{' esc='`$\'
  local escaped=$ifs$q$delim$glob$hist$esc
  wordbreaks=${COMP_WORDBREAKS//[$escaped]} # =:
}
## @fn ble/complete/progcomp/.compvar-perform-wordbreaks word
##   @var[in] wordbreaks
##   @arr[out] ret
function ble/complete/progcomp/.compvar-perform-wordbreaks {
  local word=$1
  if [[ ! $word ]]; then
    ret=('')
    return 0
  fi

  ret=()
  while local head=${word%%["$wordbreaks"]*}; [[ $head != $word ]]; do
    # Note: #D1094 bash の動作に倣って wordbreaks の連続は一つにまとめる。
    ble/array#push ret "$head"
    word=${word:${#head}}
    head=${word%%[!"$wordbreaks"]*}
    ble/array#push ret "$head"
    word=${word:${#head}}
  done

  # Note: #D1094 $word が空の時でも ret に push する。
  #   $word が空の時は wordbreaks で終わっている事を意味するが、
  #   その場合には wordbreaks の次に新しい単語を開始していると考える。
  ble/array#push ret "$word"
}
function ble/complete/progcomp/.compvar-eval-word {
  local opts=$2:single
  if [[ :$opts: == *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval "$1" "$opts"
  else
    [[ $bleopt_complete_timeout_compvar ]] &&
      opts=timeout=$((bleopt_complete_timeout_compvar)):retry-noglob-on-timeout:$opts
    ble/complete/source/eval-simple-word "$1" "$opts"
  fi
}

## @fn ble/complete/progcomp/.compvar-generate-subwords/impl1 word
##   $wordbreaks で分割してから評価する戦略。
##
##   @param word
##   @arr[out] words
##   @var[in,out] point
##   @var[in] wordbreaks
##   @exit
##     単純単語として処理できなかった場合に失敗します。
##     それ以外の場合は 0 を返します。
function ble/complete/progcomp/.compvar-generate-subwords/impl1 {
  local word=$1 ret simple_flags simple_ibrace
  if [[ $point ]]; then
    # point で単語を前半と後半に分割
    local left=${word::point} right=${word:point}
  else
    local left=$word right=
    local point= # hide
  fi

  ble/syntax:bash/simple-word/reconstruct-incomplete-word "$left" || return 1
  left=$ret
  if [[ $right ]]; then
    case $simple_flags in
    (*I*) right=\$\"$right ;;
    (*D*) right=\"$right ;;
    (*E*) right=\$\'$right ;;
    (*S*) right=\'$right ;;
    (*B*) right=\\$right ;;
    esac
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$right" || return 1
    right=$ret
  fi

  point=0 words=()

  # 単語毎に評価 (前半)
  local eval_opts=noglob
  ((${#ret[@]}==1)) && eval_opts=
  ble/syntax:bash/simple-word#break-word "$left" "$wordbreaks"
  local subword
  for subword in "${ret[@]}"; do
    ble/complete/progcomp/.compvar-eval-word "$subword" "$eval_opts"
    ble/array#push words "$ret"
    ((point+=${#ret}))
  done

  # 単語毎に評価 (後半)
  if [[ $right ]]; then
    ble/syntax:bash/simple-word#break-word "$right" "$wordbreaks"
    local subword isfirst=1
    for subword in "${ret[@]}"; do
      ble/complete/progcomp/.compvar-eval-word "$subword" noglob
      if [[ $isfirst ]]; then
        isfirst=
        local iword=${#words[@]}; ((iword&&iword--))
        words[iword]=${words[iword]}$ret
      else
        ble/array#push words "$ret"
      fi
    done
  fi
  return 0
}
## @fn ble/complete/progcomp/.compvar-generate-subwords/impl2 word
##   評価してから $wordbreaks で分割する戦略。
##
##   @param word
##   @arr[out] words
##   @var[in,out] point
##   @var[in] wordbreaks
##   @exit
##     単純単語として処理できなかった場合に失敗します。
##     それ以外の場合は 0 を返します。
function ble/complete/progcomp/.compvar-generate-subwords/impl2 {
  local word=$1
  ble/syntax:bash/simple-word/reconstruct-incomplete-word "$word" || return 1

  ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; local value1=$ret
  if [[ $point ]]; then
    if ((point==${#word})); then
      point=${#value1}
    elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "${word::point}"; then
      ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148
      point=${#ret}
    fi
  fi

  ble/complete/progcomp/.compvar-perform-wordbreaks "$value1"; words=("${ret[@]}")
  return 0
}
## @fn ble/complete/progcomp/.compvar-generate-subwords word1
##   word1 を COMP_WORDBREAKS で分割します。
##
##   @arr[out] words
##     分割して得られた単語片を格納します。
##
##   @var[in,out] subword_flags
##     E が含まれる時、単語の展開・分割が実施された事を示す。
##       全体が単純単語になっている時、先に eval して COMP_WORDBREAKS で分割する。
##       そうでない時に先に COMP_WORDBREAKS で分割して、
##       各単語片に対して単純単語 eval を試みる。
##
##     Q が含まれている時、後続の処理における展開・クォートを抑制し、
##       補完関数に対してそのままの形で単語を渡す事を示す。
##       これはチルダ ~ に対してユーザ名を補完させるのに使う。
##
##   @var[in,out] point
##   @var[in] wordbreaks
##
## Note: 全体が単純単語になっている時には先に eval して COMP_WORDBREAKS で分割する。
##   この時 subword_flags=E を設定する。
##
function ble/complete/progcomp/.compvar-generate-subwords {
  local word1=$1 ret simple_flags simple_ibrace
  if [[ ! $word1 ]]; then
    # Note: 空文字列に対して正しい単語とする為に '' とすると git の補完関数が動かなくなる。
    #   仕方がないので空文字列のままで登録する事にする。
    subword_flags=E
    words=('')
  elif [[ $word1 == '~' ]]; then
    # #D1362: ~ は展開するとユーザ名を補完できなくので特別にそのまま渡す。
    subword_flags=Q
    words=('~')
  elif ble/complete/progcomp/.compvar-generate-subwords/impl1 "$word1"; then
    # 初めに、先に分割してから評価する戦略を試す。
    subword_flags=E
  elif ble/complete/progcomp/.compvar-generate-subwords/impl2 "$word1"; then
    # 次に、評価してから分割する戦略を試す。
    subword_flags=E
  else
    ble/complete/progcomp/.compvar-perform-wordbreaks "$word1"; words=("${ret[@]}")
  fi
}
## @fn ble/complete/progcomp/.compvar-quote-subword word
##   @var[in] index subword_flags
##   @var[out] ret
##   @var[in,out] p
function ble/complete/progcomp/.compvar-quote-subword {
  local word=$1 to_quote= is_evaluated= is_quoted=
  if [[ $subword_flags == *[EQ]* ]]; then
    [[ $subword_flags == *E* ]] && to_quote=1
  elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "$word"; then
    is_evaluated=1
    ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; word=$ret
    to_quote=1
  fi

  # コマンド名以外は再クォート
  if [[ $to_quote ]]; then
    local shell_specialchars=']\ ["'\''`$|&;<>()*?{}!^'$'\n\t' q="'" Q="'\''" qq="''"
    if ((index>0)) && [[ $word == *["$shell_specialchars"]* || $word == [#~]* ]]; then
      is_quoted=1
      word="'${w//$q/$Q}'" word=${word#"$qq"} word=${word%"$qq"}
    fi
  fi

  # 単語片が補正されている時、p も補正する
  if [[ $p && $word != "$1" ]]; then
    if ((p==${#1})); then
      p=${#word}
    else
      local left=${word::p}
      if [[ $is_evaluated ]]; then
        if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$left"; then
          ble/complete/progcomp/.compvar-eval-word "$ret"; (($?==148)) && return 148; left=$ret
        fi
      fi
      if [[ $is_quoted ]]; then
        left="'${left//$q/$Q}" left=${left#"$qq"}
      fi
      p=${#left}
    fi
  fi

  ret=$word
}

## @fn ble/complete/progcomp/.compvar-reduce-cur current_subword
##   @param[in] current_subword
##   @var[out] cur
builtin unset -v _ble_complete_progcomp_cur_wordbreaks
_ble_complete_progcomp_cur_rex_simple=
_ble_complete_progcomp_cur_rex_break=
function ble/complete/progcomp/.compvar-reduce-cur {
  # 正規表現の更新
  if [[ ! ${_ble_complete_progcomp_cur_wordbreaks+set} || $COMP_WORDBREAKS != "$_ble_complete_progcomp_cur_wordbreaks" ]]; then
    _ble_complete_progcomp_cur_wordbreaks=$COMP_WORDBREAKS
    _ble_complete_progcomp_cur_rex_simple='^([^\"'\'']|\\.|"([^\"]|\\.)*"|'\''[^'\'']*'\'')*'
    local chars=${COMP_WORDBREAKS//[\'\"]/} rex_break=
    [[ $chars == *\\* ]] && chars=${chars//\\/} rex_break='\\(.|$)'
    [[ $chars == *\$* ]] && chars=${chars//\$/} rex_break+=${rex_break:+'|'}'\$([^$'\'${rex_break:+\\}']|$)'
    if [[ $chars == '^' ]]; then
      rex_break+=${rex_break:+'|'}'\^'
    elif [[ $chars ]]; then
      [[ $chars == ?*']'* ]] && chars=']'${chars//']'/}
      [[ $chars == '^'* ]] && chars=${chars:1}${chars::1}
      [[ $chars == *'-'*? ]] && chars=${chars//'-'/}'-'
      rex_break+=${rex_break:+'|'}[$chars]
    fi
    _ble_complete_progcomp_cur_rex_break='^([^\"'\''$]|\$*\\.|\$*"([^\"]|\\.)*"|'\''[^'\'']*'\''|\$+'\''([^'\''\]|\\.)*'\''|\$+([^'\'']|$))*\$*('${rex_break:-'^$'}')'
  fi

  cur=$1
  if [[ $cur =~ $_ble_complete_progcomp_cur_rex_simple && ${cur:${#BASH_REMATCH}} == [\'\"]* ]]; then
    cur=${cur:${#BASH_REMATCH}+1}
  elif [[ $cur =~ $_ble_complete_progcomp_cur_rex_break ]]; then
    cur=${cur:${#BASH_REMATCH}}
    case ${BASH_REMATCH[5]} in (\$*|@|\\?) cur=${BASH_REMATCH[5]#\\}$cur ;; esac
  fi
}

## @fn ble/complete/progcomp/.compvar-initialize
##   プログラム補完で提供される変数を構築します。
##   @var[in]  comp_words comp_cword comp_line comp_point
##   @var[out] COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT COMP_KEY COMP_TYPE
##   @var[out] cmd cur prev
##     補完関数に渡す引数を格納します。cmd は COMP_WORDBREAKS による分割前のコ
##     マンド名を保持します。cur は現在の単語のカーソル前の部分を保持します。但
##     し、閉じていない引用符がある時は引用符の中身を、COMP_WORDBREAKS の文字が
##     含まれる場合にはそれによって分割された後の最後の単語を返します。
##   @var[out] progcomp_prefix
function ble/complete/progcomp/.compvar-initialize {
  COMP_TYPE=9
  COMP_KEY=9
  ((${#KEYS[@]})) && COMP_KEY=${KEYS[${#KEYS[@]}-1]:-9} # KEYS defined in ble-decode/widget/.call-keyseq

  # Note: 以降の処理は基本的には comp_words, comp_line, comp_point, comp_cword を
  #   COMP_WORDS COMP_LINE COMP_POINT COMP_CWORD にコピーする。
  #   (1) 但し、直接代入する場合。$'' などがあると bash-completion が正しく動かないので、
  #   エスケープを削除して適当に処理する。
  #   (2) シェルの特殊文字以外の COMP_WORDBREAKS に含まれる文字で単語を分割する。

  local wordbreaks
  ble/complete/progcomp/.compvar-initialize-wordbreaks

  progcomp_prefix=
  COMP_CWORD=
  COMP_POINT=
  COMP_LINE=
  COMP_WORDS=()
  cmd=${comp_words[0]}
  cur= prev=
  local ret simple_flags simple_ibrace
  local word1 index=0 offset=0 sep=
  for word1 in "${comp_words[@]}"; do
    # @var offset_dst
    #   現在の単語の COMP_LINE 内部に於ける開始位置
    local offset_dst=${#COMP_LINE}
    # @var point
    #   word が現在の単語の時、word 内のカーソル位置を保持する。
    #   それ以外の時は空文字列。
    local point=$((comp_point-offset))
    ((0<=point&&point<=${#word1})) || point=
    ((offset+=${#word1}))

    local words subword_flags=
    ble/complete/progcomp/.compvar-generate-subwords "$word1"

    local w wq i=0 o=0 p
    for w in "${words[@]}"; do
      # @var p
      #   現在の単語片の内部におけるカーソルの位置。
      #   現在の単語片の内部にカーソルがない場合は空文字列。
      p=
      if [[ $point ]]; then
        ((p=point-o))
        # Note: #D1094 境界上にいる場合には偶数番目の単語片
        #   (非 wordbreaks) に属させる。
        ((i%2==0?p<=${#w}:p<${#w})) || p=
        ((o+=${#w},i++))
      fi
      # カーソルが subword の境界にある時は左側の subword に属させる。
      # 右側の subword で処理が行われない様に point をクリア。
      [[ $p ]] && point=
      [[ $point ]] && progcomp_prefix=$progcomp_prefix$w

      # Note: w -> wq の修正に伴ってここで p も修正される。
      ble/complete/progcomp/.compvar-quote-subword "$w"; local wq=$ret

      # 単語登録
      if [[ $p ]]; then
        COMP_CWORD=${#COMP_WORDS[*]}
        ((COMP_POINT=${#COMP_LINE}+${#sep}+p))
        ble/complete/progcomp/.compvar-reduce-cur "${COMP_LINE:offset_dst}${wq::p}"
        prev=${COMP_WORDS[COMP_CWORD-1]}
      fi
      ble/array#push COMP_WORDS "$wq"
      COMP_LINE=$COMP_LINE$sep$wq
      sep=
    done

    sep=' '
    ((offset++))
    ((index++))
  done
}
function ble/complete/progcomp/.compgen-helper-prog {
  if [[ $comp_prog ]]; then
    local COMP_WORDS COMP_CWORD cmd cur prev
    local -x COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
    ble/complete/progcomp/.compvar-initialize

    if [[ $comp_opts == *:ble/prog-trim:* ]]; then
      # WA: aws_completer
      local compreply
      ble/util/assign compreply '"$comp_prog" "$cmd" "$cur" "$prev" < /dev/null'
      ble/bin/sed "s/[[:space:]]\{1,\}\$//" <<< "$compreply"
    else
      "$comp_prog" "$cmd" "$cur" "$prev" < /dev/null
    fi
  fi
}
## @fn ble/complete/progcomp/compopt [-o OPTION|+o OPTION]
##   compopt を上書きして -o/+o option を読み取る為の関数です。
##
##   OPTION
##     ble/syntax-raw
##       生成した候補をそのまま挿入する事を示します。
##
##     ble/no-default
##       ble.sh の既定の候補生成 (候補が生成されなかった時の既定の候補生成、お
##       よび、sabbrev 候補生成) を抑制します。
##
function ble/complete/progcomp/compopt {
  # Note: Bash補完以外から builtin compopt を呼び出しても
  #  エラーになるので呼び出さない事にした (2019-02-05)
  #builtin compopt "$@" 2>/dev/null; local ext=$?
  local ext=0

  local -a ospec
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case $c in
        (o)    ospec[${#ospec[@]}]="-$1"; shift ;;
        ([DE]) fDefault=1; break 2 ;;
        (*)    ((ext==0&&(ext=1))) ;;
        esac
      done ;;
    (+o) ospec[${#ospec[@]}]="+$1"; shift ;;
    (*)
      # 特定のコマンドに対する compopt 指定
      return "$ext" ;;
    esac
  done

  local s
  for s in "${ospec[@]}"; do
    case $s in
    (-*) comp_opts=${comp_opts//:"${s:1}":/:}${s:1}: ;;
    (+*) comp_opts=${comp_opts//:"${s:1}":/:} ;;
    esac
  done

  return "$ext"
}
function ble/complete/progcomp/.check-limits {
  # user-input check
  ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
    [[ ! -t 0 ]] && ble/complete/check-cancel <&"$_ble_util_fd_stdin" &&
    return 148
  ble/complete/source/test-limit "$((progcomp_read_count++))"
  return "$?"
}
function ble/complete/progcomp/.compgen-helper-func {
  [[ $comp_func ]] || return 1
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY cmd cur prev
  ble/complete/progcomp/.compvar-initialize

  local progcomp_read_count=0
  local _ble_builtin_read_hook='ble/complete/progcomp/.check-limits || { ble/bash/read "$@" < /dev/null; return 148; }'

  local fDefault=
  ble/function#push compopt 'ble/complete/progcomp/compopt "$@"'

  # WA (#D1807): A workaround for blocking scp/ssh
  ble/function#push ssh '
    local IFS=$_ble_term_IFS
    if [[ " ${FUNCNAME[*]} " == *" ble/complete/progcomp/.compgen "* ]]; then
      local -a args; args=("$@")
      ble/util/conditional-sync "exec ssh \"\${args[@]}\"" \
        "! ble/complete/check-cancel <&$_ble_util_fd_stdin" 128 progressive-weight:killall
    else
      ble/function#push/call-top "$@"
    fi'

  # WA (#D1834): Suppress invocation of "command_not_found_handle" in the
  #   completion functions
  ble/function#push command_not_found_handle

  builtin eval '"$comp_func" "$cmd" "$cur" "$prev"' < /dev/null >&"$_ble_util_fd_stdout" 2>&"$_ble_util_fd_stderr"; local ret=$?

  ble/function#pop command_not_found_handle
  ble/function#pop ssh
  ble/function#pop compopt

  [[ $ret == 124 ]] && progcomp_retry=1
  return 0
}

## @fn ble/complete/progcomp/.parse-complete/next
##   @var[out] optarg
##   @var[in,out] compdef
##   @var[in] rex
function ble/complete/progcomp/.parse-complete/next {
  if [[ $compdef =~ $rex ]]; then
    builtin eval "arg=$BASH_REMATCH"
    compdef=${compdef:${#BASH_REMATCH}}
    return 0
  elif [[ ${compdef%%' '*} ]]; then
    # 本来此処には来ない筈
    arg=${compdef%%' '*}
    compdef=${compdef#*' '}
    return 0
  else
    return 1
  fi
}
function ble/complete/progcomp/.parse-complete/optarg {
  optarg=
  if ((ic+1<${#arg})); then
    optarg=${arg:ic+1}
    ic=${#arg}
    return 0
  elif [[ $compdef =~ $rex ]]; then
    builtin eval "optarg=$BASH_REMATCH"
    compdef=${compdef:${#BASH_REMATCH}}
    return 0
  else
    return 2
  fi
}
## @fn ble/complete/progcomp/.parse-complete compdef
##   @param[in] compdef
##   @var[in,out] comp_opts
##   @var[out] compoptions comp_prog comp_func flag_noquote
function ble/complete/progcomp/.parse-complete {
  compoptions=()
  comp_prog=
  comp_func=
  flag_noquote=
  local compdef=${1#'complete '}

  local arg optarg rex='^([^][*?;&|[:space:]<>()\`$"'\''{}#^!]|\\.|'\''[^'\'']*'\'')+[[:space:]]+' # #D1709 safe (WA gawk 4.0.2)
  while ble/complete/progcomp/.parse-complete/next; do
    case $arg in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case $c in
        ([abcdefgjksuvE])
          # Note: workaround #D0714 #M0009 #D0870
          case $c in
          (c) flag_noquote=1 ;;
          (d) ((_ble_bash>=40300)) && flag_noquote=1 ;;
          (f) ((40000<=_ble_bash&&_ble_bash<40200)) && flag_noquote=1 ;;
          esac
          ble/array#push compoptions "-$c" ;;
        ([pr])
          ;; # 無視 (-p 表示 -r 削除)
        ([AGWXPS])
          # Note: workaround #D0714 #M0009 #D0870
          ble/complete/progcomp/.parse-complete/optarg || break 2
          if [[ $c == A ]]; then
            case $optarg in
            (command) flag_noquote=1 ;;
            (directory) ((_ble_bash>=40300)) && flag_noquote=1 ;;
            (file) ((40000<=_ble_bash&&_ble_bash<40200)) && flag_noquote=1 ;;
            esac
          fi
          ble/array#push compoptions "-$c" "$optarg" ;;
        (o)
          ble/complete/progcomp/.parse-complete/optarg || break 2
          comp_opts=${comp_opts//:"$optarg":/:}$optarg:
          ble/array#push compoptions "-$c" "$optarg" ;;
        (C)
          if ((_ble_bash<40000)); then
            # bash-3.2以下では -C は一番最後に出力される (unquoted)
            comp_prog=${compdef%' '}
            compdef=
          else
            # bash-4.0以降では -C は quoted
            ble/complete/progcomp/.parse-complete/optarg || break 2
            comp_prog=$optarg
          fi
          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-prog ;;
        (F)
          # unquoted optarg (bash-3.2 以下では続きに unquoted -C prog が来得る)
          if ((_ble_bash<40000)) && [[ $compdef == *' -C '* ]]; then
            comp_prog=${compdef#*' -C '}
            comp_prog=${comp_prog%' '}
            ble/array#push compoptions '-C' ble/complete/progcomp/.compgen-helper-prog
            comp_func=${compdef%%' -C '*}
          else
            comp_func=${compdef%' '}
            ((_ble_bash>=50200)) && builtin eval "comp_func=($comp_func)"
          fi
          compdef=

          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-func ;;
        (*)
          # -D, -I, etc. just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done
}

## @fn ble/complete/progcomp/.filter-and-split-compgen arr
##   filter/sort/uniq candidates
##
##   @var[out] $arr, flag_mandb
##   @var[in] compgen
##   @var[in] COMPV compcmd comp_cword comp_words
##   @var[in] comp_opts use_workaround_for_git
function ble/complete/progcomp/.filter-and-split-compgen {
  flag_mandb=

  # 1. sed (sort 前処理)
  local sed_script=
  {
    # $comp_opts == *:ble/filter-by-prefix:*
    #
    # Note: "$COMPV" で始まる単語だけを sed /^$rex_compv/ でフィルタする。
    #   それで候補が一つもなくなる場合にはフィルタ無しで単語を列挙する。
    #
    #   2019-02-03 実は、現在の実装ではわざわざフィルタする必要はないかもしれない。
    #   以前 compgen に -- "$COMPV" を渡してもフィルタしてくれなかったのは、
    #   #D0245 cdd38598 で ble/complete/progcomp/.compgen-helper-func に於いて、
    #   "$comp_func" に引数を渡し忘れていたのが原因と思われる。
    #   これは 1929132b に於いて修正されたが念のためにフィルタを残していた気がする。
    if [[ $comp_opts == *:ble/filter-by-prefix:* ]]; then
      local ret; ble/string#escape-for-sed-regex "$COMPV"; local rex_compv=$ret
      sed_script='!/^'$rex_compv'/d'
    fi

    [[ $use_workaround_for_git ]] &&
      sed_script=${sed_script:+$sed_script;}'s/[[:space:]]\{1,\}$//'
  }
  local out=
  [[ $sed_script ]] && ble/util/assign out 'ble/bin/sed "$sed_script;/^\$/d" <<< "$compgen"'
  [[ $out ]] || out=$compgen

  # 2. sort
  local require_awk=
  if [[ $comp_opts != *:nosort:* ]]; then
    ble/util/assign out 'ble/bin/sort -u <<< "$out"'
  else
    require_awk=1 # for uniq
  fi

  # Prepare mandb
  local -a args_mandb=()
  if [[ $comp_cword -gt 0 && $COMPV != [!-]* ]]; then
    # Expand the command name.  We first try to use the external variable
    # compcmd, which is supposed contain the expanded command name.  However,
    # when the variable "compcmd" contains a special value, we try to expand
    # the first word in-place.
    local cmd=$compcmd
    if [[ $cmd == _DefaultCmD_ || $cmd == _InitialWorD_ || $cmd == -[DI] ]]; then
      cmd=${comp_words[0]}
      local ret
      ble/syntax:bash/simple-word/safe-eval "$cmd" nonull && cmd=$ret
    fi

    # If the first word is "git" and the first non-option word "SUBCMD"
    # exists before comp_cword, we try to get mandb associated with
    # "git-SUBCMD".
    local man_page=${cmd##*/}
    if [[ $man_page == git ]]; then
      local isubcmd
      for ((isubcmd=1;isubcmd<comp_cword;isubcmd++)); do
        local subcmd=${comp_words[isubcmd]} ret
        if ble/syntax:bash/simple-word/safe-eval "$subcmd"; then
          ((${#ret[@]})) || continue
          subcmd=$ret
        fi
        if [[ $subcmd != -* ]]; then
          man_page=git-$subcmd
          break
        fi
      done
    fi

    if local ret; ble/complete/mandb/generate-cache "$man_page" "bin=$command"; then
      require_awk=1
      args_mandb=(mode=mandb "$ret")
    fi
  fi

  # 3. awk (sort 後処理)
  if [[ $require_awk ]]; then
    local fs=$_ble_term_FS
    local awk_script='
      BEGIN { mandb_count = 0; }
      mode == "mandb" {
        name = $0
        sub(/'"$_ble_term_FS"'.*/, "", name);
        if (!mandb[name]) mandb[name] = $0;
        next;
      }

      function register_mandb_entry(name, display, entry) {
        # If the completion generated by progcomp ends with = yet the suffix
        # specified by the entry is a space, we replace the suffix in the
        # entry.
        if (display ~ /=$/ && match(entry, /^[^'$fs']*'$fs'[^'$fs']*'$fs' '$fs'/) > 0)
          entry = substr(entry, 1, RLENGTH - 2) "=" substr(entry, RLENGTH);

        if (name2index[name] != "") {
          # Remove duplicates after removing trailing /=$/.  If the new
          # "display" is longer, overwrite the existing one.
          if (length(display) <= length(name2display[name])) return;
          name2display[name] = display;
          entries[name2index[name]] = entry;
        } else {
          name2index[name] = mandb_count;
          name2display[name] = display;
          entries[mandb_count++] = entry;
        }
      }

      !hash[$0]++ {
        if (/^$/) next;

        name = $0
        sub(/=$/, "", name);
        if (mandb[name]) {
          register_mandb_entry(name, $0, mandb[name]);
          next;
        } else if (sub(/^--no-/, "--", name)) {

          # Synthesize description of "--no-OPTION"
          if ((entry = mandb[name]) || (entry = mandb[substr(name, 2)])) {
            split(entry, record, FS);
            if ((desc = record[4])) {
              desc = "\033[1mReverse[\033[m " desc " \033[;1m]\033[m";
              if (match($0, /['"$_ble_term_space"']*[:=[]/)) {
                option = substr($0, 1, RSTART - 1);
                optarg = substr($0, RSTART);
                suffix = substr($0, RSTART, 1);
                if (suffix == "[") suffix = "";
              } else {
                option = $0;
                optarg = "";
                suffix = " ";
              }
              register_mandb_entry(name, $0, option FS optarg FS suffix FS desc);
            }
            next;
          }

        }

        print $0;
      }

      END {
        if (mandb_count) {
          for (i = 0; i < mandb_count; i++)
            print entries[i];
          exit 10;
        }
      }
    '
    ble/util/assign-array "$1" 'ble/bin/awk -F "$_ble_term_FS" "$awk_script" "${args_mandb[@]}" mode=compgen - <<< "$out"'
    (($?==10)) && flag_mandb=1
  else
    ble/string#split-lines "$1" "$out"
  fi
  return 0
} 2>/dev/null

function ble/complete/progcomp/patch:bash-completion/_comp_cmd_make.advice {
  if [[ ${BLE_ATTACHED-} ]]; then
    ble/function#push "${ADVICE_WORDS[1]}" '
      local -a make_args; make_args=("${ADVICE_WORDS[1]}" "$@")
      ble/util/conditional-sync \
        '\''command "${make_args[@]}"'\'' \
        "! ble/complete/check-cancel <&$_ble_util_fd_stdin" 128 progressive-weight:killall'
    ble/function#advice/do
    ble/function#pop "${ADVICE_WORDS[1]}"
  else
    ble/function#advice/do
  fi
}

function ble/complete/progcomp/patch:cobraV2/extract_activeHelp.patch {
  local cobra_version=$1
  if ((cobra_version<10500)); then
    local -a completions
    completions=("${out[@]}")
  fi

  local prefix=$cur
  [[ $comps_flags == *v* ]] && prefix=$COMPV
  local unprocessed has_desc=
  unprocessed=()
  local lines line cand desc
  for lines in "${out[@]}"; do
    ble/string#split-lines lines "$lines"
    for line in "${lines[@]}"; do
      if [[ $line == *$'\t'* ]]; then
        cand=${line%%$'\t'*}
        desc=${line#*$'\t'}
        [[ $cand == "$prefix"* ]] || continue
        ble/complete/cand/yield word "$cand" "$desc"
        has_desc=1
      elif [[ $line ]]; then
        ble/array#push unprocessed "$line"
      fi
    done
  done

  [[ $has_desc ]] && bleopt complete_menu_style=desc
  if ((${#unprocessed[@]})); then
    if ((cobra_version>=10500)); then
      completions=("${unprocessed[@]}")
    else
      out=("${unprocessed[@]}")
    fi
    ble/function#advice/do
  fi
}

function ble/complete/progcomp/patch:cobraV2/get_completion_results.advice {
  local -a orig_words
  orig_words=("${words[@]}")
  local -a words
  words=(ble/complete/progcomp/patch:cobraV2/get_completion_results.invoke "${orig_words[@]:1}")
  ble/function#advice/do
}
function ble/complete/progcomp/patch:cobraV2/get_completion_results.invoke {
  local -a invoke_args; invoke_args=("$@")
  local invoke_command="${orig_words[0]} \"\${invoke_args[@]}\""
  ble/util/conditional-sync \
    'builtin eval -- "$invoke_command"' \
    "! ble/complete/check-cancel <&$_ble_util_fd_stdin" 128 progressive-weight:killall
}

## @fn ble/complete/progcomp/.compgen opts
##
##   @param[in] opts
##     コロン区切りのオプションリストです。
##
##     initial ... 最初の単語 (コマンド名) の補完に用いる関数を指定します。
##
##   @param[in,opt] cmd
##     プログラム補完規則を検索するのに使う名前を指定します。
##     省略した場合 ${comp_words[0]} が使われます。
##
##   @var[out] comp_opts
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
##     ble/complete/source の標準的な変数たち。
##
##   @var[in] comp_words comp_line comp_point comp_cword
##     ble/syntax:bash/extract-command によって生成される変数たち。
##
##   @var[in] 他色々
##   @exit 入力がある時に 148 を返します。
function ble/complete/progcomp/.compgen {
  local opts=$1

  local compcmd= is_special_completion=
  local -a alias_args=()
  if [[ :$opts: == *:initial:* ]]; then
    if ((_ble_bash>=50000)); then
      is_special_completion=1
      compcmd='-I'
    else
      compcmd=_InitialWorD_
    fi
  elif [[ :$opts: == *:default:* ]]; then
    if ((_ble_bash>=40100)); then
      builtin complete -p -D &>/dev/null || return 1
      is_special_completion=1
      compcmd='-D'
    else
      builtin complete -p _DefaultCmD_ &>/dev/null || return 1
      compcmd=_DefaultCmD_
    fi
  else
    compcmd=${comp_words[0]}
  fi

  local compdef
  if [[ $is_special_completion ]]; then
    # -I, -D, etc.
    ble/util/assign compdef 'builtin complete -p "$compcmd" 2>/dev/null'
  elif ble/syntax:bash/simple-word/is-simple "$compcmd"; then
    # 既に呼び出し元で quote されている想定
    ble/util/assign compdef "builtin complete -p -- $compcmd 2>/dev/null"
    local ret; ble/syntax:bash/simple-word/eval "$compcmd"; compcmd=$ret
  else
    ble/util/assign compdef 'builtin complete -p -- "$compcmd" 2>/dev/null'
  fi
  # strip -I, -D, or command_name
  # Note (#D1579): bash-5.1 では空コマンドに限り '' と出力する様である。
  # Note (#D2088): bash-5.2 ではコマンド名に特殊文字が含まれている時 '...' と出
  #   力するが、一方で安全に eval で評価する事ができるのでこの時点でコマンド名
  #   を削除しなくても良い。
  compdef=${compdef%"${compcmd:-''}"}
  compdef=${compdef%' '}' '

  local comp_prog comp_func compoptions flag_noquote
  ble/complete/progcomp/.parse-complete "$compdef"

  # WA: Workarounds for third-party plugins
  if [[ $comp_func ]]; then
    # fzf
    [[ $comp_func == _fzf_* ]] &&
      ble-import -f contrib/integration/fzf-completion

    # bash_completion
    if ble/is-function _comp_initialize; then
      # bash-completion 2.12
      ble/complete/mandb:bash-completion/inject
    elif ble/is-function _quote_readline_by_ref; then
      # https://github.com/scop/bash-completion/pull/492 (fixed in bash-completion 2.12)
      function _quote_readline_by_ref {
        if [[ $1 == \'* ]]; then
          printf -v "$2" %s "${1:1}"
        else
          printf -v "$2" %q "$1"
          [[ ${!2} == \$* ]] && builtin eval "$2=${!2}"
        fi
      }
      ble/function#suppress-stderr _filedir 2>/dev/null

      # https://github.com/scop/bash-completion/issues/509 (fixed in bash-completion 2.12)
      ble/function#suppress-stderr _find 2>/dev/null

      # https://github.com/scop/bash-completion/pull/556 (fixed in bash-completion 2.12)
      ble/function#suppress-stderr _scp_remote_files 2>/dev/null

      # https://github.com/scop/bash-completion/pull/773 (fixed in bash-completion 2.12)
      ble/function#suppress-stderr _function 2>/dev/null

      ble/complete/mandb:bash-completion/inject
    fi

    if [[ $comp_func == _make || $comp_func == _comp_cmd_make ]] && ble/is-function "$comp_func"; then
      ble/function#advice around "$comp_func" ble/complete/progcomp/patch:bash-completion/_comp_cmd_make.advice
    fi

    # cobra GenBashCompletionV2
    if [[ $comp_func == __start_* ]]; then
      local target=__${comp_func#__start_}_handle_completion_types
      if ble/is-function "$target"; then
        local cobra_version=
        if ble/is-function "__${comp_func#__start_}_extract_activeHelp"; then
          cobra_version=10500 # v1.5.0 (Release 2022-06-21)
        fi
        ble/function#advice around "$target" "ble/complete/progcomp/patch:cobraV2/extract_activeHelp.patch $cobra_version"
      fi

      # https://github.com/akinomyoga/ble.sh/issues/353#issuecomment-1813801048
      # Note: Some programs can be slow to generate completions for internet
      # access or another reason.  Since the go programs called by cobraV2
      # completions are supposed to be an independent executable file (without
      # being shell functions), we can safely call them inside a subshell for
      # ble/util/conditional-sync.
      local target=__${comp_func#__start_}_get_completion_results
      if ble/is-function "$target"; then
        ble/function#advice around "$target" ble/complete/progcomp/patch:cobraV2/get_completion_results.advice
      fi
    fi

    # WA for dnf completion
    ble/function#advice around _dnf_commands_helper '
      ble/util/conditional-sync \
        ble/function#advice/do \
        "! ble/complete/check-cancel <&$_ble_util_fd_stdin" 128 progressive-weight:killall' 2>/dev/null

    # WA for zoxide TAB
    if [[ $comp_func == _z || $comp_func == __zoxide_z_complete ]]; then
      ble-import -f contrib/integration/zoxide
      ble/contrib/integration:zoxide/adjust
    fi

    # WA for _complete_nix
    if [[ $comp_func == _complete_nix ]]; then
      ble-import -f integration/nix-completion
      ble/contrib/integration:nix-completion/adjust
    fi

    # https://github.com/akinomyoga/ble.sh/issues/292 (Android Debug Bridge)
    ble/function#suppress-stderr _adb 2>/dev/null
  fi
  if [[ $comp_prog ]]; then
    # aws
    if [[ $comp_prog == aws_completer ]]; then
      comp_opts=${comp_opts}ble/no-mark-directories:ble/prog-trim:
    fi
  fi


  ble/complete/check-cancel && return 148

  # Note: 一旦 compgen だけで ble/util/assign するのは、compgen をサブシェルではなく元のシェルで評価する為である。
  #   補完関数が遅延読込になっている場合などに、読み込まれた補完関数が次回から使える様にする為に必要である。
  local compgen compgen_compv=$COMPV
  if [[ ! $flag_noquote && :$comp_opts: != *:noquote:* ]]; then
    local q="'" Q="'\''"
    compgen_compv="'${compgen_compv//$q/$Q}'"
  fi
  # WA #D1682: libvirt の virsh 用の補完が勝手に変数 IFS 及び word を書き換えて
  # そのまま放置して抜けてしまう。仕方がないので tmpenv で変数の内容を復元する
  # 事にする。
  local progcomp_prefix= progcomp_retry=
  IFS=$IFS word= ble/util/assign compgen 'builtin compgen "${compoptions[@]}" -- "$compgen_compv" 2>/dev/null'

  # Note #D0534: complete -D 補完仕様に従った補完関数が 124 を返したとき再度始
  #   めから補完を行う。ble/complete/progcomp/.compgen-helper-func 関数内で補間
  #   関数の終了ステータスを確認し、もし 124 だった場合には
  #   progcomp_retry に retry を設定する。
  # Note #D1760: complete -D 以外の時でも 124 が返された時再試行する。
  if [[ $progcomp_retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    opts=:$opts:
    opts=${opts//:default:/:}
    ble/complete/progcomp/.compgen "$opts"
    return "$?"
  fi

  [[ $compgen ]] || return 1

  # WA: git の補完関数など勝手に末尾に space をつけ -o nospace を指定する物が存在する。
  #   単語の後にスペースを挿入する事を意図していると思われるが、
  #   通常 compgen (例: compgen -f) で生成される候補に含まれるスペースは、
  #   挿入時のエスケープ対象であるので末尾の space もエスケープされてしまう。
  #
  #   仕方がないので sed で各候補の末端の [[:space:]]+ を除去する。
  #   これだとスペースで終わるファイル名を挿入できないという実害が発生するが、
  #   そのような変な補完関数を作るのが悪いのである。
  local use_workaround_for_git=
  if [[ $comp_func == __git* && $comp_opts == *:nospace:* ]]; then
    use_workaround_for_git=1
    ble/string#match "$compgen" $'(^|\n|[^[:space:]])(\n|$)' ||
      comp_opts=${comp_opts//:nospace:/:}
  fi

  local cands flag_mandb=
  ble/complete/progcomp/.filter-and-split-compgen cands # compgen (comp_opts, etc) -> cands, flag_mandb

  ble/complete/source/test-limit "${#cands[@]}" || return 1

  # determine COMP_PREFIX for filenames
  if [[ $comp_opts == *:filenames:* ]]; then
    if [[ $comp_opts == *:ble/syntax-raw:* ]]; then
      [[ $COMPS == */* ]] && COMP_PREFIX=${COMPS%/*}/
    else
      [[ $COMPV == */* ]] && COMP_PREFIX=${COMPV%/*}/
    fi
  fi

  local old_cand_count=$cand_count

  local action=progcomp "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  if [[ $flag_mandb ]]; then
    local -a entries; entries=("${cands[@]}")
    cands=()
    local fs=$_ble_term_FS has_desc= icand=0 entry
    for entry in "${entries[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      if [[ $entry == -*"$fs"*"$fs"*"$fs"* ]]; then
        local cand=${entry%%"$fs"*}
        ble/complete/cand/yield mandb "$cand" "$entry"
        [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
      else
        cands[icand++]=$progcomp_prefix$entry
      fi
    done
    [[ $has_desc ]] && bleopt complete_menu_style=desc
  else
    [[ $progcomp_prefix ]] &&
      if ((_ble_bash>=40300)) && ! shopt -q compat42; then
        cands=("${cands[@]/#/"$progcomp_prefix"}") # WA #D1570 #D1751 checked
      else
        cands=("${cands[@]/#/$progcomp_prefix}") # WA #D1570 #D1738 checked
      fi
  fi
  ble/complete/cand/yield.batch "$action" "$comp_opts"

  # plusdirs の時はディレクトリ名も候補として列挙
  # Note: 重複候補や順序については考えていない
  [[ $comp_opts == *:plusdirs:* ]] && ble/complete/source:dir

  ((cand_count>old_cand_count))
}

## @fn ble/complete/progcomp/.compline-rewrite-command cmd [args...]
##   alias 展開等によるコマンド名の変更に対応して、
##   補完対象のコマンド名を指定の物に書き換えます。
##
##   @var[in,out] comp_line comp_words comp_point comp_cword
##
function ble/complete/progcomp/.compline-rewrite-command {
  local ocmd=${comp_words[0]}
  [[ $1 != "$ocmd" ]] || (($#>=2)) || return 1
  local IFS=$_ble_term_IFS
  local ins="$*"
  if (($#==0)); then
    # コマンド除去 (aliasで空に展開された時)
    local ret; ble/string#ltrim "${comp_line:${#ocmd}}"
    ((comp_point-=${#comp_line}-${#ret}))
    comp_line=$ret
  else
    comp_line=$ins${comp_line:${#ocmd}}
    ((comp_point-=${#ocmd}))
  fi
  ((comp_point<0&&(comp_point=0),comp_point+=${#ins}))
  comp_words=("$@" "${comp_words[@]:1}")
  ((comp_cword&&(comp_cword+=$#-1)))
}

function ble/complete/progcomp/.split-alias-words {
  local tail=$1
  local rex_redir='^'$_ble_syntax_bash_RexRedirect
  local rex_word='^'$_ble_syntax_bash_simple_rex_element'+'
  local rex_delim=$'^[\n;|&]'
  local rex_spaces=$'^[ \t]+'
  local rex_misc='^[<>()]+'

  local -a words=()
  while [[ $tail ]]; do
    if [[ $tail =~ $rex_redir && $tail != ['<>']'('* ]]; then
      ble/array#push words "$BASH_REMATCH"
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_word ]]; then
      local w=$BASH_REMATCH
      tail=${tail:${#w}}
      if [[ $tail && $tail != ["$_ble_term_IFS;|&<>()"]* ]]; then
        local s=${tail%%["$_ble_term_IFS"]*}
        tail=${tail:${#s}}
        w=$w$s
      fi
      ble/array#push words "$w"
    elif [[ $tail =~ $rex_delim ]]; then
      words=()
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_spaces ]]; then
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $tail =~ $rex_misc ]]; then
      ble/array#push words "$BASH_REMATCH"
      tail=${tail:${#BASH_REMATCH}}
    else
      local w=${tail%%["$_ble_term_IFS"]*}
      ble/array#push words "$w"
      tail=${tail:${#w}}
    fi
  done

  # skip assignments/redirections
  local i=0 rex_assign='^[_a-zA-Z0-9]+(\['$_ble_syntax_bash_simple_rex_element'*\])?\+?='
  while ((i<${#words[@]})); do
   if [[ ${words[i]} =~ $rex_assign ]]; then
     ((i++))
   elif [[ ${words[i]} =~ $rex_redir && ${words[i]} != ['<>']'('* ]]; then
     ((i+=2))
   else
     break
   fi
  done

  ret=("${words[@]:i}")
}

## @fn ble/complete/progcomp/.try-load-completion cmd
##   bash-completion の loader を呼び出して遅延補完設定をチェックする。
function ble/complete/progcomp/.try-load-completion {
  if ble/is-function _comp_load; then
    ble/function#push command_not_found_handle
    _comp_load -- "$1" < /dev/null &>/dev/null; local ext=$?
    ble/function#pop command_not_found_handle
  elif ble/is-function __load_completion; then
    ble/function#push command_not_found_handle
    __load_completion "$1" < /dev/null &>/dev/null; local ext=$?
    ble/function#pop command_not_found_handle
  else
    return 1
  fi
  ((ext==0)) || return "$ext"

  builtin complete -p -- "$1" &>/dev/null
}

## @fn ble/complete/progcomp cmd opts
##   補完指定を検索して対応する補完関数を呼び出します。
##   @var[in] comp_line comp_words comp_point comp_cword
function ble/complete/progcomp {
  local cmd=${1-${comp_words[0]}} opts=$2

  # copy compline variables
  local orig_comp_words orig_comp_cword=$comp_cword orig_comp_line=$comp_line orig_comp_point=$comp_point
  orig_comp_words=("${comp_words[@]}")
  local comp_words comp_cword=$comp_cword comp_line=$comp_line comp_point=$comp_point
  comp_words=("${orig_comp_words[@]}")
  [[ $cmd == "${orig_comp_words[0]}" ]] ||
    ble/complete/progcomp/.compline-rewrite-command "$cmd"

  local orig_qcmds_set=
  local -a orig_qcmds=()
  local -a alias_args=()
  [[ :$opts: == *:__recursive__:* ]] ||
    local alias_checked=' '
  while :; do

    # @var cmd   ... 元のコマンド名
    # @var ucmd  ... simple-word/eval したコマンド名
    # @var qcmds ... simple-word/eval x quote-word したコマンド
    local ret ucmd qcmds
    ucmd=$cmd qcmds=("$cmd")
    if ble/syntax:bash/simple-word/is-simple "$cmd"; then
      if ble/syntax:bash/simple-word/eval "$cmd" noglob &&
          [[ $ret != "$cmd" || ${#ret[@]} -ne 1 ]]; then

        ucmd=${ret[0]} qcmds=()
        local word
        for word in "${ret[@]}"; do
          ble/string#quote-word "$word" quote-empty
          ble/array#push qcmds "$ret"
        done
      else
        ble/string#quote-word "$cmd" quote-empty
        qcmds=("$ret")
      fi

      [[ $cmd == "${orig_comp_words[0]}" ]] &&
        orig_qcmds_set=1 orig_qcmds=("${qcmds[@]}")
    fi

    if ble/is-function "ble/cmdinfo/complete:$ucmd"; then
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      "ble/cmdinfo/complete:$ucmd" "$opts"
      return "$?"
    elif [[ $ucmd == */?* ]] && ble/is-function "ble/cmdinfo/complete:${ucmd##*/}"; then
      ble/string#quote-word "${ucmd##*/}"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      "ble/cmdinfo/complete:${ucmd##*/}" "$opts"
      return "$?"
    elif builtin complete -p -- "$ucmd" &>/dev/null; then
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif [[ $ucmd == */?* ]] && builtin complete -p -- "${ucmd##*/}" &>/dev/null; then
      ble/string#quote-word "${ucmd##*/}"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif ble/complete/progcomp/.try-load-completion "${ucmd##*/}"; then
      ble/string#quote-word "${ucmd##*/}"; qcmds[0]=$ret
      ble/complete/progcomp/.compline-rewrite-command "${qcmds[@]}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    fi
    alias_checked=$alias_checked$cmd' '

    # progcomp_alias が有効でなければ break
    ((_ble_bash<50000)) || shopt -q progcomp_alias || break

    local ret
    ble/alias#expand "$cmd"
    [[ $ret == "$cmd" ]] && break
    ble/complete/progcomp/.split-alias-words "$ret"
    if ((${#ret[@]}==0)); then
      # alias 展開により内容が消滅した時は次の単語をコマンドとして再度展開を繰り返す
      ble/complete/progcomp/.compline-rewrite-command "${alias_args[@]}"
      if ((${#comp_words[@]})); then
        if ((comp_cword==0)); then
          ble/complete/source:command
        else
          ble/complete/progcomp "${comp_words[0]}" "__recursive__:$opts"
        fi
      fi
      return "$?"
    fi

    [[ $alias_checked != *" $ret "* ]] || break
    cmd=$ret
    ((${#ret[@]}>=2)) &&
      alias_args=("${ret[@]:1}" "${alias_args[@]}")
  done

  # comp_words の再構築
  comp_words=("${orig_comp_words[@]}")
  comp_cword=$orig_comp_cword
  comp_line=$orig_comp_line
  comp_point=$orig_comp_point
  [[ $orig_qcmds_set ]] &&
    ble/complete/progcomp/.compline-rewrite-command "${orig_qcmds[@]}"
  ble/complete/progcomp/.compgen "default:$opts"
}

#------------------------------------------------------------------------------
# mandb

# オプション名に現れる事を許す文字の集合 (- と + を除く)
# Exclude non-ASCII or symbols /[][()<>{}="'\''`]/
# Note: awk の正規表現内部で使っても大丈夫な様に \ と / をエスケープしている。
# Note (#D2039): @ は cd -@ で使われている
_ble_complete_option_chars='_!#$%&:;.,^~|\\?\/*a-zA-Z0-9@'

# action:mandb
#
#   DATA ... cmd FS menu_suffix FS insert_suffix FS desc
#
function ble/complete/action:mandb/initialize {
  ble/complete/action/quote-insert
}
function ble/complete/action:mandb/initialize.batch {
  ble/complete/action/quote-insert.batch newline
}
function ble/complete/action:mandb/complete {
  ble/complete/action/complete.close-quotation
  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  local tail=${fields[2]}
  [[ $tail == ' ' && $comps_flags == *x* ]] && tail=','
  ble/complete/action/complete.addtail "$tail"
}
function ble/complete/action:mandb/init-menu-item {
  local ret; ble/color/face2g argument_option; g=$ret

  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  suffix=${fields[1]}
}
function ble/complete/action:mandb/get-desc {
  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  desc=${fields[3]}
}

function ble/complete/mandb/load-mandb-conf {
  [[ -s $1 ]] || return 0
  local line words
  while ble/bash/read line || [[ $line ]]; do
    ble/string#split-words words "${line%%'#'*}"
    case ${words[0]} in
    (MANDATORY_MANPATH)
      [[ -d ${words[1]} ]] &&
        ble/array#push manpath_mandatory "${words[1]}" ;;
    (MANPATH_MAP)
      ble/dict#set manpath_map "${words[1]}" "${words[2]}" ;;
    esac
  done < "$1"
}

_ble_complete_mandb_default_manpath=()
function ble/complete/mandb/initialize-manpath {
  ((${#_ble_complete_mandb_default_manpath[@]})) && return 0
  local manpath
  MANPATH= ble/util/assign manpath 'manpath || ble/bin/man -w' 2>/dev/null
  ble/string#split manpath : "$manpath"
  if ((${#manpath[@]}==0)); then
    local -a manpath_mandatory=()
    builtin eval -- "${_ble_util_dict_declare//NAME/manpath_map}"
    ble/complete/mandb/load-mandb-conf /etc/man_db.conf
    ble/complete/mandb/load-mandb-conf ~/.manpath

    # default mandatory manpath
    if ((${#manpath_mandatory[@]}==0)); then
      local ret
      ble/complete/util/eval-pathname-expansion '~/*/share/man'
      ble/array#push manpath_mandatory "${ret[@]}"
      ble/complete/util/eval-pathname-expansion '~/@(opt|.opt)/*/share/man'
      ble/array#push manpath_mandatory "${ret[@]}"
      for ret in /usr/local/share/man /usr/local/man /usr/share/man; do
        [[ -d $ret ]] && ble/array#push manpath_mandatory "$ret"
      done
    fi

    builtin eval -- "${_ble_util_dict_declare//NAME/mark}"

    local paths path ret
    ble/string#split paths : "$PATH"
    for path in "${paths[@]}"; do
      [[ -d $path ]] || continue
      [[ $path == *?/ ]] && path=${path%/}
      if ble/dict#get manpath_map "$path"; then
        path=$ret
      else
        path=${path%/bin}/share/man
      fi
      if [[ -d $path ]] && ! ble/set#contains mark "$path"; then
        ble/set#add mark "$path"
        ble/array#push manpath "$path"
      fi
    done

    for path in "${manpath_mandatory[@]}"; do
      if [[ -d $path ]] && ! ble/set#contains mark "$path"; then
        ble/set#add mark "$path"
        ble/array#push manpath "$path"
      fi
    done
  fi
  _ble_complete_mandb_default_manpath=("${manpath[@]}")
}

function ble/complete/mandb/search-file/.extract-path {
  local command=$1
  [[ $_ble_complete_mandb_lang ]] &&
    local LC_ALL=$$_ble_complete_mandb_lang
  ble/util/assign path 'ble/bin/man -w "$command"' 2>/dev/null
}
ble/function#suppress-stderr ble/complete/mandb/search-file/.extract-path

function ble/complete/mandb/search-file/.check {
  local path=$1
  if [[ $path && -s $path ]]; then
    ret=$path
    return 0
  else
    return 1
  fi
}
## @fn ble/complete/mandb/search-file command
##   指定したコマンドに対応する man ページのファイルを検索します。
##   @var[out] ret
##     見つかったファイルへのパスを格納します。
##   @exit
##     該当するファイルが見つかった時に成功します。
function ble/complete/mandb/search-file {
  local command=$1

  local path
  ble/complete/mandb/search-file/.extract-path "$command"
  ble/complete/mandb/search-file/.check "$path" && return 0

  # Get manpaths
  ble/string#split ret : "$MANPATH"

  # Replace empty paths with the default manpaths
  ((${#ret[@]})) || ret=('')
  local -a manpath=()
  for path in "${ret[@]}"; do
    if [[ $path ]]; then
      ble/array#push manpath "$path"
    else
      # system manpath
      ble/complete/mandb/initialize-manpath
      ble/array#push manpath "${_ble_complete_mandb_default_manpath[@]}"
    fi
  done

  local path
  for path in "${manpath[@]}"; do
    [[ -d $path ]] || continue
    ble/complete/mandb/search-file/.check "$path/man1/$command.1" && return 0
    ble/complete/mandb/search-file/.check "$path/man1/$command.8" && return 0
    if ble/is-function ble/bin/gzip; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.gz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.gz" && return 0
    fi
    if ble/is-function ble/bin/bzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.bz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.bz2" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.bz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.bz2" && return 0
    fi
    if ble/is-function ble/bin/xzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.xz" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.xz" && return 0
    fi
    if ble/is-function ble/bin/lzcat; then
      ble/complete/mandb/search-file/.check "$path/man1/$command.1.lzma" && return 0
      ble/complete/mandb/search-file/.check "$path/man1/$command.8.lzma" && return 0
    fi
  done
  return 1
}

if ble/bin#freeze-utility-path preconv; then
  function ble/complete/mandb/.preconv { ble/bin/preconv; }
else
  # macOS では preconv がない
  function ble/complete/mandb/.preconv {
    ble/bin/od -A n -t u1 -v | ble/bin/awk '
      BEGIN {
        ECHAR = 65533; # U+FFFD

        # Initialize table
        byte = 0;
        for (i = 0; byte < 128; byte++) { mtable[byte] = 0; vtable[byte] = i++; }
        for (i = 0; byte < 192; byte++) { mtable[byte] = 0; vtable[byte] = ECHAR; }
        for (i = 0; byte < 224; byte++) { mtable[byte] = 1; vtable[byte] = i++; }
        for (i = 0; byte < 240; byte++) { mtable[byte] = 2; vtable[byte] = i++; }
        for (i = 0; byte < 248; byte++) { mtable[byte] = 3; vtable[byte] = i++; }
        for (i = 0; byte < 252; byte++) { mtable[byte] = 4; vtable[byte] = i++; }
        for (i = 0; byte < 254; byte++) { mtable[byte] = 5; vtable[byte] = i++; }
        for (i = 0; byte < 256; byte++) { mtable[byte] = 0; vtable[byte] = ECHAR; }

        M = 0; C = 0;
      }
      function put_uchar(uchar) {
        if (uchar < 128)
          printf("%c", uchar);
        else
          printf("\\[u%04X]", uchar);
      }
      function process_byte(byte) {
        if (M) {
          if (128 <= byte && byte < 192) {
            C = C * 64 + byte % 64;
            if (--M == 0) put_uchar(C);
            return;
          } else {
            # while (M--) C *= 64; put_uchar(C);
            put_uchar(ECHAR);
            M = 0;
          }
        }

        M = mtable[byte];
        C = vtable[byte];
        if (M == 0) put_uchar(C);
      }
      { for (i = 1; i <= NF; i++) process_byte($i); }
    '
  }
fi

_ble_complete_mandb_lang=
if ble/is-function ble/bin/groff; then
  # ENCODING: UTF-8
  _ble_complete_mandb_convert_type=man
  function ble/complete/mandb/convert-mandoc {
    if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
      ble/bin/groff -k -Tutf8 -man
    else
      ble/bin/groff -Tascii -man
    fi
  }

  # Note #D1551: macOS (groff-1.19.2) では groff -k も preconv も既定では存在しない
  if [[ $OSTYPE == darwin* ]] && ! ble/bin/groff -k -Tutf8 -man &>/dev/null <<< 'α'; then
    if ble/bin/groff -T utf8 -m man &>/dev/null <<< '\[u03B1]'; then
      function ble/complete/mandb/convert-mandoc {
        if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
          ble/complete/mandb/.preconv | ble/bin/groff -T utf8 -m man
        else
          ble/bin/groff -T ascii -m man
        fi
      }
    else
      _ble_complete_mandb_lang=C
      function ble/complete/mandb/convert-mandoc {
        ble/bin/groff -T ascii -m man
      }
    fi
  fi
elif ble/is-function ble/bin/nroff; then
  _ble_complete_mandb_convert_type=man
  function ble/complete/mandb/convert-mandoc {
    if [[ $_ble_util_locale_encoding == UTF-8 ]]; then
      ble/bin/nroff -Tutf8 -man
    else
      ble/bin/groff -Tascii -man
    fi
  }
elif ble/is-function ble/bin/mandoc; then
  # bsd
  _ble_complete_mandb_convert_type=mdoc
  function ble/complete/mandb/convert-mandoc {
    ble/bin/mandoc -mdoc
  }
fi

function ble/complete/mandb/.generate-cache-from-man {
  ble/is-function ble/bin/man &&
    ble/is-function ble/complete/mandb/convert-mandoc || return 1

  local command=$1
  local ret
  ble/complete/mandb/search-file "$command" || return 1
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  local path=$ret
  case $ret in
  (*.gz)       ble/bin/gzip -cd "$path" ;;
  (*.bz|*.bz2) ble/bin/bzcat "$path" ;;
  (*.lzma)     ble/bin/lzcat "$path" ;;
  (*.xz)       ble/bin/xzcat "$path" ;;
  (*)          ble/bin/cat "$path" ;;
  esac | ble/bin/awk -v type="$_ble_complete_mandb_convert_type" '
    BEGIN {
      g_keys_count = 0;
      g_desc = "";
      if (type == "man") {
        print ".TH __ble_ignore__ 1 __ble_ignore__ __ble_ignore__";
        print ".ll 9999"
        topic_start = ".TP";
      }
      mode = "begin";

      fmt3_state = "";
      fmt5_state = "";
      fmt6_state = "";
    }
    function output_pair(key, desc) {
      print "";
      print "__ble_key__";
      if (topic_start != "") print topic_start;
      print key;
      print "";
      print "__ble_desc__";
      print "";
      print desc;
    }
    function flush_topic(_, i) {
      if (g_keys_count != 0) {
        for (i = 0; i < g_keys_count; i++)
          output_pair(g_keys[i], g_desc);
      }
      g_keys_count = 0;
      g_desc = "";

      fmt3_flush();
      fmt5_state = "";
      fmt6_flush();
    }

    # ".Dd" seems to be the include directive for macros?
    # ".Nm" (in mdoc) specifies the name of the target the man page describes
    mode == "begin" && /^\.(Dd|Nm)['"$_ble_term_space"']/ {
      if (type == "man" && /^\.Dd['"$_ble_term_space"']+\$Mdoc/) topic_start = "";
      print $0;
    }

    function register_key(key) {
      g_keys[g_keys_count++] = key;
      g_desc = "";
    }

    # Comment: [.ig \n comments \n ..]
    /^\.ig/ { mode = "ignore"; next; }
    mode == "ignore" {
      if (/^\.\.['"$_ble_term_space"']*/) mode = "none";
      next;
    }

    {
      sub(/['"$_ble_term_space"']+$/, "");
      REQ = match($0, /^\.[_a-zA-Z0-9]+/) ? substr($0, 2, RLENGTH - 1) : "";
    }

    REQ ~ /^(S[Ss]|S[Hh]|Pp)$/ { flush_topic(); next; }

    #--------------------------------------------------------------------------
    # Format #5: [.PP \n key \n .RS \n desc \n .RE]
    # used by "ping" and "git".

    REQ == "PP" {
      flush_topic();
      fmt5_state = "key";
      fmt5_key = "";
      fmt5_desc = "";
      next;
    }

    fmt5_state {
      if (fmt5_state == "key") {
        if (/^\.RS([^_a-zA-Z0-9]|$)/)
          fmt5_state = "desc";
        else if (/^\.RE([^_a-zA-Z0-9]|$)/)
          fmt5_state = "none";
        else
          fmt5_key = (fmt5_key ? fmt5_key "\n" : "") $0;
      } else if (fmt5_state == "desc") {
        if (/^\.RE([^_a-zA-Z0-9]|$)/) {
          register_key(fmt5_key);
          g_desc = fmt5_desc;
          flush_topic();
          fmt5_state = "";
        } else
          fmt5_desc = (fmt5_desc ? fmt5_desc "\n" : "") $0;
      }
    }

    #--------------------------------------------------------------------------
    # Format #3: [.HP \n keys \n .IP \n desc]
    # GNU sed seems to use this format.
    # GNU coreutils mv seems to contain [.HP \n key      desc ] (for option "-b")

    REQ == "HP" {
      flush_topic();
      fmt3_state = "key";
      fmt3_key_count = 0;
      fmt3_desc = "";
      next;
    }

    function fmt3_process(_, key) {
      if (REQ == "TP") { fmt3_flush(); return; }
      if (REQ == "PD") return;

      if (fmt3_state == "key") {
        if (REQ == "IP") { fmt3_state = "desc"; return; }
        if (match($0, /(	|    )['"$_ble_term_space"']*/)) {
          fmt3_keys[fmt3_key_count++] = substr($0, 1, RSTART - 1);
          fmt3_desc = substr($0, RSTART + RLENGTH);
          fmt3_state = "desc";
        } else {
          fmt3_keys[fmt3_key_count++] = $0;
        }
      } else if (fmt3_state == "desc") {
        if (fmt3_desc != "") fmt3_desc = fmt3_desc "\n";
        fmt3_desc = fmt3_desc $0;
      }
    }
    function fmt3_flush(_, i) {
      if (fmt3_state == "desc" && fmt3_key_count > 0) {
        for (i = 0; i < fmt3_key_count; i++)
          register_key(fmt3_keys[i]);
        g_desc = fmt3_desc;
      }
      fmt3_state = "";
      fmt3_key_count = 0;
      fmt3_desc = "";
    }

    fmt3_state { fmt3_process(); }

    #--------------------------------------------------------------------------
    # Format #4: [[.IP "key" 4 \n .IX Item "..."]+ \n .PD \n desc]
    # This format is used by "wget".

    /^\.IP['"$_ble_term_space"']+".*"(['"$_ble_term_space"']+[0-9]+)?$/ && fmt3_state != "key" {
      fmt6_init();
      fmt4_init();
      next;
    }

    function fmt4_init() {
      if (mode != "fmt4_desc")
        if (!(g_keys_count && g_desc == "")) flush_topic();

      gsub(/^\.IP['"$_ble_term_space"']+"|"(['"$_ble_term_space"']+[0-9]+)?$/, "");
      register_key($0);
      mode = "fmt4_desc";
    }
    mode == "fmt4_desc" {
      if ($0 == "") { flush_topic(); mode = "none"; next; }

      # fish has a special format of [.IP "\(bu" 2 \n keys desc]
      if (g_keys_count == 1 && g_keys[0] == "\\(bu" && match($0, /^\\fC[^\\]+\\fP( or \\fC[^\\]+\\fP)?/) > 0) {
        _key = substr($0, 1, RLENGTH);
        _desc = substr($0, RLENGTH + 1);
        if (match(_key, / or \\fC[^\\]+\\fP/) > 0)
          _key = substr(_key, 1, RSTART - 1) ", " substr(_key, RSTART + 4);
        g_keys[0] = _key;
        g_desc = _desc;
        next;
      }

      if (REQ == "PD") next;
      if (/^\.IX['"$_ble_term_space"']+Item['"$_ble_term_space"']+/) next;

      if (g_desc != "") g_desc = g_desc "\n";
      g_desc = g_desc $0;
    }

    #--------------------------------------------------------------------------
    # Format #6: [[.IP "key" \n desc .IP]
    # This format is used by "rsync".

    function fmt6_init() {
      fmt6_flush();
      fmt6_state = "desc"
      fmt6_key = $0;
      fmt6_desc = "";
    }
    fmt6_state {
      if (REQ == "IX") {
        # Exclude fmt4 case
        fmt6_state = "";
      } else if (REQ == "IP") {
        fmt6_flush();
      } else {
        fmt6_desc = fmt6_desc $0 "\n";
      }
    }
    function fmt6_flush() {
      if (!fmt6_state) return;
      fmt6_state = "";
      if (fmt6_desc)
        output_pair(fmt6_key, fmt6_desc);
    }

    #--------------------------------------------------------------------------
    # Format #2: [.It Fl key \n desc] or [.It Fl Xo \n key \n .Xc desc]
    # This form was found in both "mdoc" and "man"
    /^\.It Fl([^_a-zA-Z0-9]|$)/ {
      if (g_keys_count && g_desc != "") flush_topic();
      sub(/^\.It Fl/, ".Fl");
      if ($0 ~ / Xo$/) {
        g_current_key = $0;
        mode = "fmt2_keyc"
      } else {
        register_key($0);
        mode = "desc";
      }
      next;
    }
    mode == "fmt2_keyc" {
      if (/^\.PD['"$_ble_term_space"']*([0-9]+['"$_ble_term_space"']*)?$/) next;
      g_current_key = g_current_key "\n" $0;
      if (REQ == "Xc") {
        register_key(g_current_key);
        mode = "desc";
      }
      next;
    }
    #--------------------------------------------------------------------------
    # Format #1: [.TP \n key \n desc]
    # Format #1: [.TP \n key   desc \n desc...]
    # This is the typical format in "man".
    type == "man" && REQ == "TP" {
      if (g_keys_count && g_desc != "") flush_topic();
      mode = "key1";
      next;
    }
    mode == "key1" {
      if (/^\.PD['"$_ble_term_space"']*([0-9]+['"$_ble_term_space"']*)?$/) next;

      # In Japanese version of "man ls", key and desc is separated by multiple
      # spaces, where the number of spaces seem to vary from 5 to more than 10
      # spaces.
      if (match($0, /['"$_ble_term_space"']['"$_ble_term_space"']['"$_ble_term_space"']/) > 0) {
        register_key(substr($0, 1, RSTART - 1));
        g_desc = substr($0, RSTART);
        sub(/^['"$_ble_term_space"']+/, "", g_desc);
      } else {
        register_key($0);
      }

      mode = "desc";
      next;
    }
    mode == "desc" {
      if (REQ == "PD") next;

      if (g_desc != "") g_desc = g_desc "\n";
      g_desc = g_desc $0;
    }
    #--------------------------------------------------------------------------

    END { flush_topic(); }
  ' | ble/complete/mandb/convert-mandoc 2>/dev/null | ble/bin/awk -F "$_ble_term_FS" '
    function flush_pair(_, i, desc, prev_opt) {
      if (g_option_count) {
        gsub(/\034/, "\x1b[7m^\\\x1b[27m", g_desc);
        sub(/(\.  |; ).*/, ".", g_desc); # Long descriptions are truncated.

        for (i = 0; i < g_option_count; i++) {
          desc = g_desc;

          # show a short option
          if (i > 0 && g_options[i] ~ /^--/) {
            prev_opt = g_options[i - 1];
            sub(/\034.*/, "", prev_opt);
            if (prev_opt ~ /^-[^-]$/)
              desc = "\033[1m[\033[0;36m" prev_opt "\033[0;1m]\033[m " desc;
          }

          print g_options[i] FS desc;
        }
      }
      g_option_count = 0;
      g_desc = "";
    }

    function process_key(line, _, n, specs, i, spec, option, optarg, suffix) {
      gsub(/^['"$_ble_term_space"']+|['"$_ble_term_space"']+$/, "", line);
      if (line == "") return;

      gsub(/\x1b\[[ -?]*[@-~]/, "", line); # CSI seq
      gsub(/\x1b[ -\/]*[0-~]/, "", line); # ESC seq
      gsub(/\t/, "    ", line); # HT
      gsub(/.\x08/, "", line); # CHAR BS
      gsub(/\x0E/, "", line); # SO
      gsub(/\x0F/, "", line); # SI
      gsub(/[\x00-\x1F]/, "", line); # Give up all the other control chars
      gsub(/^['"$_ble_term_space"']*|['"$_ble_term_space"']*$/, "", line);
      gsub(/['"$_ble_term_space"']+/, " ", line);
      if (line !~ /^[-+]./) return;

      n = split(line, specs, /,(['"$_ble_term_space"']+|$)| or /);
      prev_optarg = "";
      for (i = n; i > 0; i--) {
        spec = specs[i];
        sub(/,['"$_ble_term_space"']+$/, "", spec);

        # Exclude non-options.
        # Exclude FS (\034) because it is used for separators in the cache format.
        if (spec !~ /^[-+]/ || spec ~ /\034/) { specs[i] = ""; continue; }

        if (match(spec, /\[[:=]?|[:='"$_ble_term_space"']/)) {
          option = substr(spec, 1, RSTART - 1);
          optarg = substr(spec, RSTART);
          suffix = substr(spec, RSTART + RLENGTH - 1, 1);
          if (suffix == "[") suffix = "";
          prev_optarg = optarg;
        } else {
          option = spec;
          optarg = "";
          suffix = " ";

          # Carry previous optarg
          if (prev_optarg ~ /[A-Z]|<.+>/) {
            optarg = prev_optarg;
            if (option ~ /^[-+].$/) {
              sub(/^\[=/, "[", optarg);
              sub(/^=/, "", optarg);
              sub(/^[^'"$_ble_term_space"'[]/, " &", optarg);
            } else {
              if (optarg ~ /^\[[^:=]/)
                sub(/^\[/, "[=", optarg);
              else if (optarg ~ /^[^:='"$_ble_term_space"'[]/)
                optarg = " " optarg;
            }

            if (match(optarg, /^\[[:=]?|^[:='"$_ble_term_space"']/)) {
              suffix = substr(optarg, RSTART + RLENGTH - 1, 1);
              if (suffix == "[") suffix = "";
            }
          }
        }

        specs[i] = option FS optarg FS suffix;
      }

      for (i = 1; i <= n; i++) {
        if (specs[i] == "") continue;
        option = substr(specs[i], 1, index(specs[i], FS) - 1);
        if (!g_hash[option]++)
          g_options[g_option_count++] = specs[i];
      }
    }

    function process_desc(line) {
      gsub(/^['"$_ble_term_space"']*|['"$_ble_term_space"']*$/, "", line);
      if (line == "") {
        if (g_desc != "") return 0;
        return 1;
      }

      gsub(/['"$_ble_term_space"']['"$_ble_term_space"']+/, " ", line);
      if (g_desc != "") g_desc = g_desc " ";
      g_desc = g_desc line;
      return 1;
    }

    function process_string_fragment(str) {
      if (mode == "key") {
        process_key(str);
      } else if (mode == "desc") {
        if (!process_desc(str)) mode = "";
      }
    }

    function process_line(line, _, head, m0) {
      while (match(line, /__ble_(key|desc)__/) > 0) {
        head = substr(line, 1, RSTART - 1);
        m0 = substr(line, RSTART, RLENGTH);
        line = substr(line, RSTART + RLENGTH);

        process_string_fragment(head);

        if (m0 == "__ble_key__") {
          flush_pair();
          mode = "key";
        } else {
          mode = "desc";
        }
      }

      process_string_fragment(line);
    }

    { process_line($0); }
    END { flush_pair(); }
  ' | ble/bin/sort -t "$_ble_term_FS" -k 1
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}

## @fn ble/complete/mandb:help/generate-cache [opts]
function ble/complete/mandb:help/generate-cache {
  local opts=$1
  local -x cfg_usage= cfg_help=1 cfg_plus= cfg_plus_generate=
  [[ :$opts: == *:mandb-help-usage:* ]] && cfg_usage=1
  [[ :$opts: == *:mandb-usage:* ]] && cfg_usage=1 cfg_help=
  ble/string#match ":$opts:" ':plus-options(=[^:]+)?:' &&
    cfg_plus=1 cfg_plus_generate=${BASH_REMATCH[1]:1}

  local space=$' \t' # for #D1709 (WA gawk 4.0.2)
  local rex_argsep='(\[?[:=]|  ?|\[)'
  local rex_option='[-+](,|[^]:='$space',[]+)('$rex_argsep'(<[^<>]+>|\([^()]+\)|\[[^][]+\]|[^-'"$_ble_term_space"'、。][^'"$_ble_term_space"'、。]*))?([,'"$_ble_term_space"']|$)'
  local LC_ALL= LC_COLLATE=C 2>/dev/null
  ble/bin/awk -F "$_ble_term_FS" '
    BEGIN {
      cfg_help = ENVIRON["cfg_help"];
      g_help_indent = -1;
      g_help_score = -1; # score based on indent and the interval between the
                         # option and desc. smaller is better.
      g_help_keys_count = 0;
      g_help_desc = "";

      cfg_usage = ENVIRON["cfg_usage"];
      g_usage_count = 0;

      cfg_plus_generate = ENVIRON["cfg_plus_generate"];
      cfg_plus = ENVIRON["cfg_plus"] cfg_plus_generate;

      entries_init();
    }

    #--------------------------------------------------------------------------
    # entries

    function entries_init() {
      entries_count = 0;
    }

    function entries_register(entry, score, _, name, ientry) {
      name = entry;
      sub(/'"$_ble_term_FS"'.*$/, "", name);
      if (name ~ /^\+/ && !cfg_plus) return;

      if (entries_index[name] != "") {
        if (score >= entries_score[name]) return;
        ientry = entries_index[name];
      } else {
        ientry = entries_count++;
        entries_keys[ientry] = name;
      }

      entries_index[name] = ientry;
      entries_entry[name] = entry;
      entries_score[name] = score;
    }

    function entries_dump(_, ientry, name) {
      for (ientry = 0; ientry < entries_count; ientry++) {
        name = entries_keys[ientry];
        print entries_entry[name];
      }
    }

    #--------------------------------------------------------------------------

    function split_option_optarg_suffix(optspec, _, key, suffix, optarg) {
      # Note: Skip options that contain FS (due to the limitation by the cache format)
      if (index(optspec, FS) != 0) return "";

      if ((pos = match(optspec, /'"$rex_argsep"'/)) > 0) {
        key = substr(optspec, 1, pos - 1);
        suffix = substr(optspec, pos + RLENGTH - 1, 1);
        if (suffix == "[") suffix = "";
        optarg = substr(optspec, pos);
      } else {
        key = optspec;
        optarg = "";
        suffix = " ";
      }

      # Note: Exclude option names containing non-option characters
      if (key ~ /[^-+'"$_ble_complete_option_chars"']/) return "";

      return key FS optarg FS suffix;
    }

    {
      gsub(/\x1b\[[ -?]*[@-~]/, ""); # CSI seq
      gsub(/\x1b[ -\/]*[0-~]/, ""); # ESC seq
      gsub(/\t/, "    "); # HT
      gsub(/[\x00-\x1F]/, ""); # Remove all the other C0 chars
    }

    #--------------------------------------------------------------------------
    # Generate + options without descriptions

    function generate_plus(_, i, n) {
      if (!cfg_plus_generate) return;
      n = length(cfg_plus_generate);
      for (i = 1; i <= n; i++)
        entries_register("+" substr(cfg_plus_generate, i, 1) FS FS FS, 999);
    }

    #--------------------------------------------------------------------------
    # Extract usage [-DEI] [-f[helo] | --prefix=PATH]

    function usage_parse(line, _, optspec, optspec1, option, optarg, n, i, o) {
      while (match(line, /\[['"$_ble_term_space"']*([^][]|\[[^][]*\])+['"$_ble_term_space"']*\]/)) {
        optspec = substr(line, RSTART + 1, RLENGTH - 2);
        line = substr(line, RSTART + RLENGTH);

        # optspec: " -DEI | --prefix=PATH | ... ", etc.
        while (match(optspec, /([^][|]|\[[^][]*\])+/)) {
          optspec1 = substr(optspec, RSTART, RLENGTH);
          optspec = substr(optspec, RSTART + RLENGTH);
          gsub(/^['"$_ble_term_space"']+|['"$_ble_term_space"']+$/, "", optspec1);

          # optspec1: "--option optarg", "-f[optarg]", "-xzvf", etc.
          if (match(optspec1, /^[-+][^]:='"$space"'[]+/)) {
            option = substr(optspec1, RSTART, RLENGTH);
            optarg = substr(optspec1, RSTART + RLENGTH);
            n = RLENGTH;
            if (option ~ /^-.*-/) {
              if ((keyinfo = split_option_optarg_suffix(optspec1)) != "")
                g_usage[g_usage_count++] = keyinfo;
            } else {
              o = substr(option, 1, 1);
              for (i = 2; i <= n; i++)
                if ((keyinfo = split_option_optarg_suffix(o substr(option, i, 1) optarg)) != "")
                  g_usage[g_usage_count++] = keyinfo;
            }
          }
        }
      }
    }
    function usage_generate(_, i) {
      for (i = 0; i < g_usage_count; i++)
        entries_register(g_usage[i] FS, 999);
    }

    cfg_usage {
      if (NR <= 20 && (g_usage_start || $0 ~ /^[_a-zA-Z0-9]|^[^-'"$_ble_term_space"'][^'"$_ble_term_space"']*(: |：)/) ) {
        g_usage_start = 1;
        usage_parse($0);
      } else if (/^['"$_ble_term_space"']*$/)
        cfg_usage = 0;
    }

    #--------------------------------------------------------------------------
    # Extract option descriptions

    function get_indent(text, _, i, n, ret) {
      ret = 0;
      n = length(text);
      for (i = 1; i <= n; i++) {
        c = substr(text, i, 1);
        if (c == " ")
          ret++;
        else if (c == "\t")
          ret = (int(ret / 8) + 1) * 8;
        else
          break;
      }
      return ret;
    }
    function help_flush(_, i, desc, prev_opt) {
      if (g_help_indent < 0) return;
      for (i = 0; i < g_help_keys_count; i++) {
        desc = g_help_desc;

        # show a short option
        if (i > 0 && g_help_keys[i] ~ /^--/) {
          prev_opt = g_help_keys[i - 1];
          sub(/\034.*/, "", prev_opt);
          if (prev_opt ~ /^-[^-]$/) {
            # Note: This particular form of desc is used by
            # ble/complete/mandb:bash-completion/_parse_help.advice.  When we
            # change the format, the function also needs to be updated.
            desc = "\033[1m[\033[0;36m" prev_opt "\033[0;1m]\033[m " desc;
          }
        }

        entries_register(g_help_keys[i] FS desc, g_help_score);
      }
      g_help_indent = -1;
      g_help_keys_count = 0;
      g_help_desc = "";
    }
    function help_start(keydef, _, key, keyinfo, keys, nkey, i, optarg) {
      if (g_help_desc != "") help_flush();
      g_help_indent = get_indent(keydef);
      g_help_score = g_help_indent;

      nkey = 0;
      for (;;) {
        sub(/^,?['"$_ble_term_space"']+/, "", keydef);

        if (match(keydef, /^'"$rex_option"'/) <= 0) break;
        key = substr(keydef, 1, RLENGTH);
        keydef = substr(keydef, RLENGTH + 1);

        sub(/[,'"$_ble_term_space"']$/, "", key);
        keys[nkey++] = key;
      }

      # Copy optarg "-A, --accept=LIST" => "-A LIST, --accept=LIST"
      if (nkey >= 2) {
        optarg = "";
        for (i = nkey; --i >= 0; ) {
          if (match(keys[i], /'"$rex_argsep"'/) > 0) {
            optarg = substr(keys[i], RSTART);
            sub(/^['"$_ble_term_space"']+/, "", optarg);
            if (optarg !~ /[A-Z]|<.+>/) optarg = "";
          } else if (optarg != ""){
            if (keys[i] ~ /^[-+].$/) {
              optarg2 = optarg;
              sub(/^\[=/, "[", optarg2);
              sub(/^=/, "", optarg2);
              sub(/^[^'"$_ble_term_space"'[]/, " &", optarg2);
              keys[i] = keys[i] optarg2;
            } else {
              optarg2 = optarg;
              if (optarg2 ~ /^\[[^:=]/)
                sub(/^\[/, "[=", optarg2);
              else if (optarg2 ~ /^[^:='"$_ble_term_space"'[]/)
                optarg2 = " " optarg2;
              keys[i] = keys[i] optarg2;
            }
          }
        }
      }

      for (i = 0; i < nkey; i++)
        if ((keyinfo = split_option_optarg_suffix(keys[i])) != "")
          g_help_keys[g_help_keys_count++] = keyinfo;
    }
    function help_append_desc(desc) {
      gsub(/^['"$_ble_term_space"']+|['"$_ble_term_space"']$/, "", desc);
      if (desc == "") return;
      if (g_help_desc == "")
        g_help_desc = desc;
      else
        g_help_desc = g_help_desc " " desc;
    }

    # Note (#D1847): We here restrict the number of spaces between synonymous
    # options within 2 or 3.  Note that "rex_option" already contains the
    # trailing comma or space.
    cfg_help && match($0, /^['"$_ble_term_space"']*'"$rex_option"'((['"$_ble_term_space"']['"$_ble_term_space"']?)?'"$rex_option"')*/) {
      key = substr($0, 1, RLENGTH);
      desc = substr($0, RLENGTH + 1);
      if (desc ~ /^,/) next;
      help_start(key);
      help_append_desc(desc);
      if (desc !~ /^['"$_ble_term_space"']/) g_help_score += 100;
      next;
    }
    g_help_indent >= 0 {
      sub(/['"$_ble_term_space"']+$/, "");
      indent = get_indent($0);
      if (indent <= g_help_indent)
        help_flush();
      else
        help_append_desc($0);
    }

    #--------------------------------------------------------------------------

    END {
      help_flush();
      usage_generate();
      generate_plus();
      entries_dump();
    }
  ' | ble/bin/sort -t "$_ble_term_FS" -k 1
  ble/util/unlocal LC_COLLATE LC_ALL 2>/dev/null
}

function ble/complete/mandb:bash-completion/inject {
  if ble/is-function _comp_compgen_help; then
    # bash-completion 2.12
    ble/function#advice after _comp_compgen_help__get_help_lines 'ble/complete/mandb:bash-completion/_get_help_lines.advice' &&
      { ble/function#advice before _comp_complete_longopt 'ble/complete/mandb:bash-completion/_parse_help.advice "${ADVICE_WORDS[1]}"' ||
          ble/function#advice before _comp_longopt 'ble/complete/mandb:bash-completion/_parse_help.advice "${ADVICE_WORDS[1]}"'; } &&
      function ble/complete/mandb:bash-completion/inject { return 0; }
  elif ble/is-function _parse_help; then
    ble/function#advice before _parse_help 'ble/complete/mandb:bash-completion/_parse_help.advice "${ADVICE_WORDS[1]}" "${ADVICE_WORDS[2]}"' &&
      ble/function#advice before _longopt 'ble/complete/mandb:bash-completion/_parse_help.advice "${ADVICE_WORDS[1]}"' &&
      ble/function#advice before _parse_usage 'ble/complete/mandb:bash-completion/_parse_help.advice "${ADVICE_WORDS[1]}" "${ADVICE_WORDS[2]}"' &&
      function ble/complete/mandb:bash-completion/inject { return 0; }
  fi
} 2>/dev/null # _parse_help が別の枠組みで定義されている事がある? #D1900

## @fn ble/string#hash-pjw text [size shift]
##   @var[out] ret
function ble/string#hash-pjw {
  local size=${2:-32}
  local S=${3:-$(((size+7)/8))} # shift    4
  local C=$((size-2*S))         # co-shift 24
  local M=$(((1<<size-S)-1))    # mask     0x0FFFFFFF
  local N=$(((1<<S)-1<<S))      # mask2    0x000000F0

  ble/util/s2bytes "$1"
  local c h=0
  for c in "${ret[@]}"; do
    ((h=(h<<S)+c,h=(h^h>>C&N)&M))
  done
  ret=$h
}

## @fn ble/complete/mandb:bash-completion/.alloc-subcache command hash [opts]
##   @var[out] ret
function ble/complete/mandb:bash-completion/.alloc-subcache {
  ret=
  [[ $_ble_attached ]] || return 1

  local command=$1 hash=$2 opts=$3
  if [[ :$opts: == *:dequote:* ]]; then
    ble/syntax:bash/simple-word/safe-eval "$command" noglob:nonull &&
      command=$ret
  fi
  [[ $command ]] || return 1

  [[ $command == ble*/* ]] || command=${1##*/}
  ble/string#hash-pjw "$args" 64; local hash=$ret
  local lc_messages=${LC_ALL:-${LC_MESSAGES:-${LANG:-C}}}
  local mandb_cache_dir=$_ble_base_cache/complete.mandb/${lc_messages//'/'/%}
  ble/util/sprintf ret '%s.%014x' "$mandb_cache_dir/_parse_help.d/$command" "$hash"

  [[ -s $ret && $ret -nt $_ble_base/lib/core-complete.sh ]] && return 1

  ble/util/mkd "${ret%/*}"
}

## @fn ble/complete/mandb:bash-completion/_parse_help.advice command args
function ble/complete/mandb:bash-completion/_parse_help.advice {
  local cmd=$1 args=$2 func=$ADVICE_FUNCNAME
  # 現在のコマンド名。 Note: ADVICE_WORDS には実際に現在補完しようとしているコ
  # マンドとは異なるものが指定される場合があるので (例えば help や - 等) 信用で
  # きない。
  local command=${COMP_WORDS[0]-} hash="${ADVICE_WORDS[*]}" ret
  ble/complete/mandb:bash-completion/.alloc-subcache "$command" "$hash" dequote || return 0
  local subcache=$ret

  local default_option=--help help_opts=
  [[ $func == _parse_usage ]] &&
    default_option=--usage help_opts=mandb-usage

  if [[ ( $func == _parse_help || $func == _parse_usage ) && $cmd == - ]]; then
    # 標準入力からの読み取り
    ble/complete/mandb:help/generate-cache "$help_opts" >| "$subcache"

    # Note: _parse_help が読み取る筈だった内容を横取りしたので抽出した内容を標
    # 準出力に出力する。但し、対応する long option がある short option は除外す
    # る。
    LC_ALL= LC_COLLATE=C ble/bin/awk -F "$_ble_term_FS" '
      BEGIN { entry_count = 0; }
      {
        entries[entry_count++] = $1;

        # Assumption: the descriptions of long options have the form
        # "[short_opt] desc".  The format is defined by
        # ble/complete/mandb:help/generate-cache.
        desc = $4;
        gsub(/\033\[[ -?]*[@-~]/, "", desc);
        if (match(desc, /^\[[^]'"$_ble_term_space"'[]*\] /) > 0) { # #D1709 safe
          short_opt = substr(desc, 2, RLENGTH - 3);
          excludes[short_opt] =1;
        }
      }
      END {
        for (i = 0; i < entry_count; i++)
          if (!excludes[entries[i]])
            print entries[i];
      }
    ' "$subcache" 2>/dev/null # suppress locale error #D1440
  else
    local cmd_args
    ble/string#split-words cmd_args "${args:-$default_option}"
    "$cmd" "${cmd_args[@]}" 2>&1 | ble/complete/mandb:help/generate-cache "$help_opts" >| "$subcache"
  fi
}

function ble/complete/mandb:bash-completion/_get_help_lines.advice {
  ((${#_lines[@]})) || return 0

  # @var cmd
  #   現在のコマンド名。Note: _comp_command_offset 等によって別のコマンドの補完
  #   を呼び出している場合があるので ble.sh の用意する comp_words は信用できな
  #   い。bash-completion の使っている _comp_args[0] または bash-completion が
  #   上書きしている COMP_WORDS を参照する。
  local cmd=${_comp_args[0]-${COMP_WORDS[0]-}} hash="${ADVICE_WORDS[*]}"
  ble/complete/mandb:bash-completion/.alloc-subcache "$cmd" "$hash" dequote || return 0
  local subcache=$ret

  local help_opts=
  [[ ${ADVICE_FUNCNAME[1]} == *_usage ]] && help_opts=mandb-usage
  printf '%s\n' "${_lines[@]}" | ble/complete/mandb:help/generate-cache "$help_opts" >| "$subcache"
}

## @fn ble/complete/mandb/generate-cache cmdname [opts]
##   @param[in,opt] opts
##     @opt man=MAN_PAGE
##   @var[out] ret
##     キャッシュファイル名を返します。
function ble/complete/mandb/generate-cache {
  local command=${1##*/} opts=${2-}
  [[ $command ]] || return 1
  local lc_messages=${LC_ALL:-${LC_MESSAGES:-${LANG:-C}}}
  local mandb_cache_dir=$_ble_base_cache/complete.mandb/${lc_messages//'/'/%}
  local fcache=$mandb_cache_dir/$command

  local cmdspec_opts; ble/cmdspec/opts#load "$command"
  [[ :$cmdspec_opts: == *:no-options:* ]] && return 1

  # fcache_help
  if ble/opts#extract-all-optargs "$cmdspec_opts" mandb-help --help; then
    local -a helpspecs; helpspecs=("${ret[@]}")
    local subcache=$mandb_cache_dir/help.d/$command
    if ! [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/util/mkd "${subcache%/*}"
      local helpspec
      for helpspec in "${helpspecs[@]}"; do
        if [[ $helpspec == %* ]]; then
          builtin eval -- "${helpspec:1}"
        elif [[ $helpspec == @* ]]; then
          ble/util/print "${helpspec:1}"
        else
          ble/string#split-words helpspec "${helpspec#+}"
          "$command" "${helpspec[@]}" 2>&1
        fi
      done | ble/complete/mandb:help/generate-cache "$cmdspec_opts" >| "$subcache"
    fi
  fi

  # fcache_man
  if [[ :$cmdspec_opts: != *:mandb-disable-man:* ]] && {
       ble/opts#extract-last-optarg "$opts" bin
       local path=${ret:-"$1"}
       ble/bin#has "$path"; }; then
    local subcache=$mandb_cache_dir/man.d/$command
    if ! [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/util/mkd "${subcache%/*}"
      ble/complete/mandb/.generate-cache-from-man "$command" >| "$subcache"
    fi
  fi

  # collect available caches
  local -a subcaches=()
  local subcache update=
  ble/complete/util/eval-pathname-expansion '"$mandb_cache_dir"/_parse_help.d/"$command".??????????????'
  for subcache in "${ret[@]}" "$mandb_cache_dir"/{help,man}.d/"$command"; do
    if [[ -s $subcache && $subcache -nt $_ble_base/lib/core-complete.sh ]]; then
      ble/array#push subcaches "$subcache"
      [[ $fcache -nt $subcache ]] || update=1
    fi
  done

  if [[ $update ]]; then
    local -x exclude=
    ble/opts#extract-last-optarg "$cmdspec_opts" mandb-exclude && exclude=$ret

    local fs=$_ble_term_FS
    ble/bin/awk -F "$_ble_term_FS" '
      BEGIN {
        plus_count = 0;
        nodesc_count = 0;
        exclude = ENVIRON["exclude"];
      }
      function emit(name, entry) {
        hash[name] = entry;
        if (exclude != "" && name ~ exclude) return;
        print entry;
      }

      $4 == "" {
        if ($1 ~ /^\+/) {
          plus_name[plus_count] = $1;
          plus_entry[plus_count] = $0;
          plus_count++;
        } else {
          nodesc_name[nodesc_count] = $1;
          nodesc_entry[nodesc_count] = $0;
          nodesc_count++;
        }
        next;
      }
      !hash[$1] { emit($1, $0); }

      END {
        # minus options
        for (i = 0; i < nodesc_count; i++)
          if (!hash[nodesc_name[i]])
            emit(nodesc_name[i], nodesc_entry[i]);

        # plus options
        for (i = 0; i < plus_count; i++) {
          name = plus_name[i];
          if (hash[name]) continue;

          split(plus_entry[i], record, FS);
          optarg = record[2];
          suffix = record[3];
          desc = "";

          mname = name;
          sub(/^\+/, "-", mname);
          if (hash[mname]) {
            if (!optarg) {
              split(hash[mname], record, FS);
              optarg = record[2];
              suffix = record[3];
            }

            desc = hash[mname];
            sub(/^[^'$fs']*'$fs'[^'$fs']*'$fs'[^'$fs']*'$fs'/, "", desc);
            if (desc) desc = "\033[1mReverse[\033[m " desc " \033[;1m]\033[m";
          }

          if (!desc) desc = "reverse of \033[4m" mname "\033[m";
          emit(name, name FS optarg FS suffix FS desc);
        }
      }
    ' "${subcaches[@]}" >| "$fcache"
  fi

  ret=$fcache
  [[ -s $fcache ]]
}
function ble/complete/mandb/load-cache {
  ret=()
  ble/complete/mandb/generate-cache "$@" &&
    ble/util/mapfile ret < "$ret"
}

## @fn ble/complete/source:option/.is-option-context args...
##   args... に "--" などのオプション解釈を停止する様な引数が含まれて
##   いないか判定します。
##
##   @param[in] args...
##   @var[in] cmdspec_opts
##
function ble/complete/source:option/.is-option-context {
  #(($#)) || return 0

  local rexrej rexreq stopat
  ble/progcolor/stop-option#init "$cmdspec_opts"
  if [[ $stopat ]] && ((stopat<=$#)); then
    return 1
  elif [[ ! $rexrej$rexreq ]]; then
    return 0
  fi

  local word ret
  for word; do
    ble/syntax:bash/simple-word/safe-eval "$word" noglob &&
      ble/progcolor/stop-option#test "$ret" &&
      return 1
  done
  return 0
}

function ble/complete/source:option {
  local opts=$1
  if [[ :$opts: == *:empty:* ]]; then
    # 空文字列に対する補完を明示的に実行
    [[ ! $COMPV ]] || return 0
  else
    # /^[-+].*/ の時にだけ候補生成 (曖昧補完で最初の /^[-+]/ は補わない)
    local rex='^-[-+'$_ble_complete_option_chars']*$|^\+[_'$_ble_complete_option_chars']*$'
    [[ $COMPV =~ $rex ]] || return 0
  fi

  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  [[ :$comp_type: == *:[maA]:* ]] && local COMP2=$COMP1

  local comp_words comp_line comp_point comp_cword
  ble/syntax:bash/extract-command "$COMP2" || return 1

  ble/complete/source:option/generate-for-command "${comp_words[@]::comp_cword}"
}

## @fn ble/complete/source:option/generate-for-command command prev_args...
##   This function generates the option names based on man pages.
##
##   @param[in] command
##     The command name
##   @param[in] prev_args
##     The previous arguments before the word we currently try to complete.
##
##   For example, when one would like to generate the option
##   candidates for "cmd abc def ghi -xx[TAB]", command is "cmd", and
##   prev_args are "abc" "def" "ghi".
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
##     These variables carry the information on the completion
##     context. [COMP1, COMP2] specifies the range of the complete
##     target in the command-line text. COMPS is the word to
##     complete. COMPV is, if available, its current value after
##     evaluation. The variable "comp_type" contains additional flags
##     for the completion context.
##   @var[ref] cand_iloop
##
function ble/complete/source:option/generate-for-command {
  local cmd=$1 prev_args
  prev_args=("${@:2}")

  local alias_checked=' '
  while
    local ret cmdv=$cmd
    ble/syntax:bash/simple-word/safe-eval "$cmd" nonull && cmdv=$ret
    ! ble/complete/mandb/load-cache "$cmdv"
  do
    alias_checked=$alias_checked$cmd' '
    ble/alias#expand "$cmd" || return 1
    local words; ble/string#split-words ret "$ret"; words=("${ret[@]}")

    # 変数代入は読み飛ばし
    local iword=0 rex='^[_a-zA-Z][_a-zA-Z0-9]*\+?='
    while [[ ${words[iword]} =~ $rex ]]; do ((iword++)); done
    [[ ${words[iword]} && $alias_checked != *" ${words[iword]} "* ]] || return 1
    prev_args=("${words[@]:iword+1}" "${prev_args[@]}")
    cmd=${words[iword]}
  done
  local -a entries; entries=("${ret[@]}")

  # If the main command name is git, try to load the man page corresponding to
  # the subcommand.
  if [[ ${cmdv##*/} == git ]]; then
    local isubcmd
    for ((isubcmd=0;isubcmd<${#prev_args[@]};isubcmd++)); do
      local subcmd=${prev_args[isubcmd]}
      if ble/syntax:bash/simple-word/safe-eval "$subcmd"; then
        ((${#ret[@]}==0)) || continue
        subcmd=$ret
      fi
      if [[ $subcmd != -* ]] && ble/complete/mandb/load-cache "git-$subcmd"; then
        cmdv=git-$subcmd
        entries=("${ret[@]}")
        prev_args=("${prev_args[@]:isubcmd+1}")
        break
      fi
    done
  fi

  local cmdspec_opts=
  ble/cmdspec/opts#load "$cmdv"
  # "--" や非オプション引数など、オプション無効化条件をチェック
  ble/complete/source:option/.is-option-context "${prev_args[@]}" || return 1

  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize mandb
  local entry fs=$_ble_term_FS has_desc=
  for entry in "${entries[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
      ble/complete/check-cancel && return 148
    local CAND=${entry%%$fs*}
    [[ $CAND == "$COMPV"* ]] || continue
    ble/complete/cand/yield mandb "$CAND" "$entry"
    [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
  done

  [[ $has_desc && :$opts: != *:empty:* ]] && bleopt complete_menu_style=desc
}

#------------------------------------------------------------------------------
# source:argument

## @fn ble/complete/source:argument/.generate-user-defined-completion opts
##   ユーザ定義の補完を実行します。ble/cmdinfo/complete:コマンド名
##   という関数が定義されている場合はそれを使います。
##   それ以外の場合は complete によって登録されているプログラム補完が使用されます。
##
##   @param[in] opts
##     コロン区切りのオプションリストを指定します。
##     initial ... 最初の単語(コマンド名)の補完である事を示します。
##   @var[in] COMP1 COMP2
##   @var[in] (variables set by ble/syntax/parse)
##
function ble/complete/source:argument/.generate-user-defined-completion {
  shopt -q progcomp || return 1

  [[ :$comp_type: == *:[maA]:* ]] && local COMP2=$COMP1

  local comp_words comp_line comp_point comp_cword
  ble/syntax:bash/extract-command "$COMP2" || return 1

  # @var comp2_in_word 単語内のカーソルの位置
  # @var comp1_in_word 単語内の補完開始点
  local forward_words=
  ((comp_cword)) && IFS=' ' builtin eval 'forward_words="${comp_words[*]::comp_cword} "'
  local comp2_in_word=$((comp_point-${#forward_words}))
  local comp1_in_word=$((comp2_in_word-(COMP2-COMP1)))

  # 単語の途中に補完開始点がある時、単語を分割する
  if ((comp1_in_word>0)); then
    local w=${comp_words[comp_cword]}
    comp_words=("${comp_words[@]::comp_cword}" "${w::comp1_in_word}" "${w:comp1_in_word}" "${comp_words[@]:comp_cword+1}")
    IFS=' ' builtin eval 'comp_line="${comp_words[*]}"'
    ((comp_cword++,comp_point++))
    ((comp2_in_word=COMP2-COMP1,comp1_in_word=0))
  fi

  # 曖昧補完の場合は単語の内容を reduce する #D1413
  if [[ $COMPV && :$comp_type: == *:[maA]:* ]]; then
    local oword=${comp_words[comp_cword]::comp2_in_word} ins
    local ins=; [[ :$comp_type: == *:a:* ]] && ins=${COMPV::1}

    # escape ins
    local ret comps_flags= comps_fixed= # referenced in ble/complete/string#escape-for-completion-context
    if [[ $oword ]]; then
      # Note: 実は曖昧補完の時は COMP2=$COMP1 としていて、
      #   更に COMP1 で単語分割しているのでここには入らない筈。
      local simple_flags simple_ibrace
      ble/syntax:bash/simple-word/reconstruct-incomplete-word "$oword" || return 1
      comps_flags=v$simple_flags
      ((${simple_ibrace%:*})) && comps_fixed=1
    fi
    ble/complete/string#escape-for-completion-context "$ins" c; ins=$ret
    ble/util/unlocal comps_flags comps_fixed

    # rewrite
    ((comp_point+=${#ins}))
    comp_words=("${comp_words[@]::comp_cword}" "$oword$ins" "${comp_words[@]:comp_cword+1}")
    IFS=' ' builtin eval 'comp_line="${comp_words[*]}"'
    ((comp2_in_word+=${#ins}))
  fi

  local opts=$1
  if [[ :$opts: == *:initial:* ]]; then
    ble/complete/progcomp/.compgen initial
  else
    ble/complete/progcomp "${comp_words[0]}"
  fi
}

function ble/complete/source:argument/generate {
  local old_cand_count=$cand_count

  #----------------------------------------------------------------------------
  # 1. Attempt user-defined completion
  ble/complete/source:argument/.generate-user-defined-completion; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"
  [[ $comp_opts == *:ble/no-default:* ]] && return "$ext"

  #----------------------------------------------------------------------------
  # 2. Attempt built-in argument completion

  # "-option" の時は complete options based on mandb
  ble/complete/source:option; local ext=$?
  ((ext==148)) && return "$ext"

  # 候補が見付からない場合 (または曖昧補完で COMPV に / が含まれる場合)
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble/complete/source:dir
  else
    # filenames, default, bashdefault
    ble/complete/source:file
  fi; local ext=$?
  ((ext==148)) && return "$ext"

  # 空文字列に対するオプション生成はファイル名よりも後で試みる
  ble/complete/source:option empty; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"

  #----------------------------------------------------------------------------
  # 3. Attempt rhs completion

  if local rex='^/?[-_a-zA-Z0-9.]+\+?[:=]|^-[^-/=:]'; [[ $COMPV =~ $rex ]]; then
    # var=filename --option=filename /I:filename など。
    local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
    local COMP_PREFIX=$prefix
    [[ :$comp_type: != *:[maA]:* && $value =~ ^.+/ ]] &&
      COMP_PREFIX=$prefix${BASH_REMATCH[0]}

    local ret cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/source:file/.construct-pathname-pattern "$value"
    ble/complete/util/eval-pathname-expansion "$ret"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    ble/complete/cand/yield.initialize file_rhs
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      [[ -e $cand || -h $cand ]] || continue
      [[ $FIGNORE ]] && ! ble/complete/.fignore/filter "$cand" && continue
      ble/complete/cand/yield file_rhs "$prefix$cand" "$prefix"
    done
  fi

  ((cand_count>old_cand_count))
}

function ble/complete/source:argument {
  local comp_opts=:

  # failglob で展開に失敗した時は * を付加して再度展開を試みる
  if [[ $comps_flags == *f* && $COMPS != *\* && :$comp_type: != *:[maA]:* ]]; then
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"
    ble/complete/source/eval-simple-word "$ret*" && ((${#ret[*]})) &&
      ble/complete/cand/yield-filenames file "${ret[@]}"
    (($?==148)) && return 148
  fi

  ble/complete/source:argument/generate
  local ext=$?
  ((ext==148)) && return 148
  [[ $comp_opts == *:ble/no-default:* ]] && return "$ext"

  ble/complete/source:sabbrev
}

# source:variable
# source:user
# source:hostname

function ble/complete/source/compgen {
  [[ $comps_flags == *v* ]] || return 1
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match

  local compgen_action=$1
  local action=$2
  local data=$3

  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  local arr
  ble/util/assign-array arr 'builtin compgen -A "$compgen_action" -- "$compv_quoted"'

  ble/complete/source/test-limit "${#arr[@]}" || return 1

  # 既に完全一致している場合は、より前の起点から補完させるために省略
  [[ $1 != '=' && ${#arr[@]} == 1 && $arr == "$COMPV" ]] && return 0

  local cand "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand" "$data"
  done
}

function ble/complete/source:variable {
  local data=
  case $1 in
  ('=') data=assignment ;;
  ('b') data=braced ;;
  ('a') data=arithmetic ;;
  ('n') data=nosuffix ;;
  ('w'|*) data=word ;;
  esac
  ble/complete/source/compgen variable variable "$data"
}
function ble/complete/source:user {
  ble/complete/source/compgen user word
}
function ble/complete/source:hostname {
  ble/complete/source/compgen hostname word
}

#------------------------------------------------------------------------------
# context

## @fn  ble/complete/complete/determine-context-from-opts opts
##   @param[in] opts
##   @var[out] context
function ble/complete/complete/determine-context-from-opts {
  local opts=$1
  context=syntax
  if local rex=':context=([^:]+):'; [[ :$opts: =~ $rex ]]; then
    local rematch1=${BASH_REMATCH[1]}
    if ble/is-function ble/complete/context:"$rematch1"/generate-sources; then
      context=$rematch1
    else
      ble/util/print "ble/widget/complete: unknown context '$rematch1'" >&2
    fi
  fi
}
## @fn ble/complete/context/filter-prefix-sources
##   @var[in] comp_text comp_index
##   @var[in,out] sources
function ble/complete/context/filter-prefix-sources {
  # 現在位置より前に始まる補完文脈だけを選択する
  local -a filtered_sources=()
  local src asrc
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    local comp1=${asrc[1]}
    ((comp1<comp_index)) &&
      ble/array#push filtered_sources "$src"
  done
  sources=("${filtered_sources[@]}")
  ((${#sources[@]}))
}
## @fn ble/complete/context/overwrite-sources source
##   @param[in] source
##   @var[in] comp_text comp_index
##   @var[in,out] comp_type
##   @var[in,out] sources
function ble/complete/context/overwrite-sources {
  local source_name=$1
  local -a new_sources=()
  local src asrc mark
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    [[ ${mark[asrc[1]]} ]] && continue
    ble/array#push new_sources "$source_name ${asrc[1]}"
    mark[asrc[1]]=1
  done
  ((${#new_sources[@]})) ||
    ble/array#push new_sources "$source_name $comp_index"
  sources=("${new_sources[@]}")
}

## @fn ble/complete/context:syntax/generate-sources comp_text comp_index
##   @var[in] comp_text comp_index
##   @var[out] sources
function ble/complete/context:syntax/generate-sources {
  ble/syntax/import
  ble-edit/content/update-syntax
  ble/cmdspec/initialize # load user configruation
  ble/syntax/completion-context/generate "$comp_text" "$comp_index"
  ((${#sources[@]}))
}
function ble/complete/context:filename/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources file
}
function ble/complete/context:command/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources command
}
function ble/complete/context:variable/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources variable
}
function ble/complete/context:username/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources user
}
function ble/complete/context:hostname/generate-sources {
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources hostname
}

function ble/complete/context:glob/generate-sources {
  comp_type=$comp_type:raw
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources glob
}
function ble/complete/source:glob {
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: == *:[maA]:* ]] && return 1

  local pattern=$COMPV
  ble/complete/source/eval-simple-word "$pattern"; (($?==148)) && return 148
  if ((!${#ret[@]})) && [[ $pattern != *'*' ]]; then
    ble/complete/source/eval-simple-word "$pattern*"; (($?==148)) && return 148
  fi

  local cand action=file "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${ret[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand"
  done
}

function ble/complete/context:dynamic-history/generate-sources {
  comp_type=$comp_type:raw
  ble/complete/context:syntax/generate-sources || return "$?"
  ble/complete/context/overwrite-sources dynamic-history
}
function ble/complete/source:dynamic-history {
  [[ $comps_flags == *v* ]] || return 1
  [[ :$comp_type: == *:[maA]:* ]] && return 1
  [[ $COMPV ]] || return 1

  local wordbreaks; ble/complete/get-wordbreaks
  wordbreaks=${wordbreaks//$'\n'}

  local ret; ble/string#escape-for-extended-regex "$COMPV"
  local rex_needle='(^|['$wordbreaks'])'$ret'[^'$wordbreaks']+'
  local rex_wordbreaks='['$wordbreaks']'
  ble/util/assign-array ret 'HISTTIMEFORMAT= builtin history | ble/bin/grep -Eo "$rex_needle" | ble/bin/sed "s/^$rex_wordbreaks//" | ble/bin/sort -u'

  local cand action=literal-word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${ret[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$cand"
  done
}

# 
#==============================================================================
# 候補生成

## @var[out] cand_count
##   候補の数
## @arr[out] cand_cand
##   候補文字列
## @arr[out] cand_word
##   挿入文字列 (～ エスケープされた候補文字列)
##
## @arr[out] cand_pack
##   補完候補のデータを一つの配列に纏めたもの。
##   要素を使用する際は以下の様に変数に展開して使う。
##
##     local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
##     ble/complete/cand/unpack "${cand_pack[0]}"
##
##   先頭に ACTION が格納されているので
##   ACTION だけ参照する場合には以下の様にする。
##
##     local ACTION=${cand_pack[0]%%:*}
##

## @fn ble/complete/util/construct-ambiguous-regex text fixlen
##   曖昧一致に使う正規表現を生成します。
##   @param[in] text
##   @param[in,out] fixlen=1
##   @var[in] comp_type
##   @var[out] ret
function ble/complete/util/construct-ambiguous-regex {
  local text=$1 fixlen=${2:-1}
  local opt_icase=; [[ :$comp_type: == *:i:* ]] && opt_icase=1
  local -a buff=()
  local i=0 n=${#text} ch=
  for ((i=0;i<n;i++)); do
    ((i>=fixlen)) && ble/array#push buff '.*'
    ch=${text:i:1}
    if [[ $ch == [a-zA-Z] ]]; then
      if [[ $opt_icase ]]; then
        ble/string#toggle-case "$ch"
        ch=[$ch$ret]
      fi
    else
      ble/string#escape-for-extended-regex "$ch"; ch=$ret
    fi
    ble/array#push buff "$ch"
  done
  IFS= builtin eval 'ret="${buff[*]}"'
}
## @fn ble/complete/util/construct-glob-pattern text
##   部分一致に使うグロブを生成します。
function ble/complete/util/construct-glob-pattern {
  local text=$1
  if [[ :$comp_type: == *:i:* ]]; then
    local i n=${#text} c
    local -a buff=()
    for ((i=0;i<n;i++)); do
      c=${text:i:1}
      if [[ $c == [a-zA-Z] ]]; then
        ble/string#toggle-case "$c"
        c=[$c$ret]
      else
        ble/string#escape-for-bash-glob "$c"; c=$ret
      fi
      ble/array#push buff "$c"
    done
    IFS= builtin eval 'ret="${buff[*]}"'
  else
    ble/string#escape-for-bash-glob "$1"
  fi
}


function ble/complete/.fignore/prepare {
  comp_fignore=()
  local i=0 leaf tmp
  ble/string#split tmp ':' "$FIGNORE"
  for leaf in "${tmp[@]}"; do
    [[ $leaf ]] && comp_fignore[i++]="$leaf"
  done
}
function ble/complete/.fignore/filter {
  local pat
  for pat in "${comp_fignore[@]}"; do
    [[ $1 == *"$pat" ]] && return 1
  done
  return 0
}

## @fn ble/complete/candidates/.pick-nearest-sources
##   一番開始点に近い補完源の一覧を求めます。
##
##   @var[in] comp_index
##   @arr[in,out] remaining_sources
##   @arr[out]    nearest_sources
##   @var[out] COMP1 COMP2
##     補完範囲
##   @var[out] COMPS
##     補完範囲の (クオートが含まれうる) コマンド文字列
##   @var[out] COMPV
##     補完範囲のコマンド文字列が意味する実際の文字列
##   @var[out] comps_flags comps_fixed
function ble/complete/candidates/.pick-nearest-sources {
  COMP1= COMP2=$comp_index
  nearest_sources=()

  local -a unused_sources=()
  local src asrc
  for src in "${remaining_sources[@]}"; do
    ble/string#split-words asrc "$src"
    if ((COMP1<asrc[1])); then
      COMP1=${asrc[1]}
      ble/array#push unused_sources "${nearest_sources[@]}"
      nearest_sources=("$src")
    elif ((COMP1==asrc[1])); then
      ble/array#push nearest_sources "$src"
    else
      ble/array#push unused_sources "$src"
    fi
  done
  remaining_sources=("${unused_sources[@]}")

  COMPS=${comp_text:COMP1:COMP2-COMP1}
  comps_flags=
  comps_fixed=('')

  if [[ ! $COMPS ]]; then
    comps_flags=${comps_flags}v COMPV=
  elif local ret simple_flags simple_ibrace; ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"; then
    local reconstructed=$ret
    if [[ :$comp_type: == *:raw:* ]]; then
      # 展開前の値を COMPV に格納する。ブレース展開内部の場合は失敗
      if ((${simple_ibrace%:*})); then
        COMPV=
      else
        comps_flags=$comps_flags${simple_flags}v
        COMPV=$reconstructed
      fi
    elif ble/complete/source/eval-simple-word "$reconstructed"; local ext=$?; ((ext==148)) && return 148; ((ext==0)); then
      # 展開後の値を COMPV に格納する (既定)
      COMPV=("${ret[@]}")
      comps_flags=$comps_flags${simple_flags}v

      if ((${simple_ibrace%:*})); then
        ble/complete/source/eval-simple-word "${reconstructed::${simple_ibrace#*:}}" single; (($?==148)) && return 148
        comps_fixed=${simple_ibrace%:*}:$ret
        comps_flags=${comps_flags}x
      fi

      local path spec i s
      ble/syntax:bash/simple-word/evaluate-path-spec "$reconstructed" '' noglob:fixlen="${simple_ibrace#*:}"
      for ((i=0;i<${#spec[@]};i++)); do
        s=${spec[i]}
        [[ $s == "$comps_fixed" || $s == "$reconstructed" ]] && continue
        ble/array#push comps_fixed "${#s}:${path[i]}"
      done
    else
      # Note: failglob により simple-word/eval が失敗した時にここに来る。
      COMPV=
      comps_flags=$comps_flags${simple_flags}f
    fi
    [[ $COMPS =~ $rex_raw_paramx ]] && comps_flags=${comps_flags}p

  else
    COMPV=
  fi
}

function ble/complete/candidates/clear {
  cand_count=0
  cand_cand=()
  cand_word=()
  cand_pack=()
}

## @fn ble/complete/candidates/filter-by-command command [start]
##   生成された候補 (cand_*) に対して指定したコマンドを実行し、
##   成功した候補のみを残して他を削除します。
##   @param[in] command
##   @param[in,opt] start
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble/complete/candidates/filter-by-command {
  local command=$1 start=${2:-0}
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=$start
  local -a prop=() cand=() word=() show=() data=()
  for ((i=start;i<cand_count;i++)); do
    ((i%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    builtin eval -- "$command" || continue
    cand[j]=${cand_cand[i]}
    word[j]=${cand_word[i]}
    data[j]=${cand_pack[i]}
    ((j++))
  done
  cand_count=$j
  cand_cand=("${cand[@]}")
  cand_word=("${word[@]}")
  cand_pack=("${data[@]}")
}
## @fn ble/complete/candidates/.filter-by-regex rex_filter
##   生成された候補 (cand_*) において指定した正規表現に一致する物だけを残します。
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble/complete/candidates/.filter-by-regex {
  local rex_filter=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_cand[i]} =~ $rex_filter ]]'
}
function ble/complete/candidates/.filter-by-glob {
  local globpat=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_cand[i]} == $globpat ]]'
}
function ble/complete/candidates/.filter-word-by-prefix {
  local prefix=$1
  ble/complete/candidates/filter-by-command '[[ ${cand_word[i]} == "$prefix"* ]]'
}

function ble/complete/candidates/.initialize-rex_raw_paramx {
  local element=$_ble_syntax_bash_simple_rex_element
  local open_dquot=$_ble_syntax_bash_simple_rex_open_dquot
  rex_raw_paramx='^('$element'*('$open_dquot')?)\$[_a-zA-Z][_a-zA-Z0-9]*$'
}

## 候補フィルタ (candidate filters) は以下の関数を通して実装される。
##
##   @fn ble/complete/candidates/filter:FILTER_TYPE/init compv
##   @fn ble/complete/candidates/filter:FILTER_TYPE/test cand
##     @var[in] comp_filter_type
##     @var[in,out] comp_filter_pattern
##
##   @fn ble/complete/candidates/filter:FILTER_TYPE/match needle text
##     @param[in] needle text
##
##   関数 ble/complete/candidates/filter:FILTER_TYPE/count-match-chars value
##     @var[in] COMPV
##
## 使用するときには以下の関数を通して呼び出す (match, count-match-chars は直接呼び出す)。
##
##   @fn ble/complete/candidates/filter#init type compv
##   @fn ble/complete/candidates/filter#test value
##     @var[in,out] comp_filter_type
##     @var[in,out] comp_filter_pattern
##
function ble/complete/candidates/filter#init {
  comp_filter_type=$1
  comp_filter_pattern=
  ble/complete/candidates/filter:"$comp_filter_type"/init "$2"
}
function ble/complete/candidates/filter#test {
  ble/complete/candidates/filter:"$comp_filter_type"/test "$1"
}

function ble/complete/candidates/filter:none/init { ble/complete/candidates/filter:head/init "$@"; }
function ble/complete/candidates/filter:none/test { true; }
function ble/complete/candidates/filter:none/count-match-chars { ble/complete/candidates/filter:head/count-match-chars "$@"; }
function ble/complete/candidates/filter:none/match { ble/complete/candidates/filter:head/match "$@"; }

function ble/complete/candidates/filter:head/init {
  local ret; ble/complete/util/construct-glob-pattern "$1"
  comp_filter_pattern=$ret*
}
function ble/complete/candidates/filter:head/count-match-chars { # unused but for completeness
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  if [[ $value == "$compv"* ]]; then
    ret=${#compv}
  elif [[ $compv == "$value"* ]]; then
    ret=${#value}
  else
    ret=0
  fi
}
function ble/complete/candidates/filter:head/test { [[ $1 == $comp_filter_pattern ]]; }

## @fn ble/complete/candidates/filter:head/match needle text
##   @arr[out] ret
function ble/complete/candidates/filter:head/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  if [[ ! $needle || ! $text ]]; then
    ret=()
  elif [[ $text == "$needle"* ]]; then
    ret=(0 "${#needle}")
    return 0
  elif [[ $text == "${needle::${#text}}" ]]; then
    ret=(0 "${#text}")
    return 0
  else
    ret=()
    return 1
  fi
}

function ble/complete/candidates/filter:substr/init {
  local ret; ble/complete/util/construct-glob-pattern "$1"
  comp_filter_pattern=*$ret*
}
function ble/complete/candidates/filter:substr/count-match-chars {
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  if [[ $value == *"$compv"* ]]; then
    ret=${#compv}
    return 0
  fi
  ble/complete/string#common-suffix-prefix "$value" "$compv"
  ret=${#ret}
}
function ble/complete/candidates/filter:substr/test { [[ $1 == $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:substr/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  if [[ ! $needle ]]; then
    ret=()
  elif [[ $text == *"$needle"* ]]; then
    text=${text%%"$needle"*}
    local beg=${#text}
    local end=$((beg+${#needle}))
    ret=("$beg" "$end")
  elif ble/complete/string#common-suffix-prefix "$text" "$needle"; ((${#ret})); then
    local end=${#text}
    local beg=$((end-${#ret}))
    ret=("$beg" "$end")
  else
    ret=()
  fi
}

function ble/complete/candidates/filter:hsubseq/.determine-fixlen {
  fixlen=${1:-1}
  if [[ $comps_fixed ]]; then
    local compv_fixed_part=${comps_fixed#*:}
    [[ $compv_fixed_part ]] && fixlen=${#compv_fixed_part}
  fi
}
## @fn ble/complete/candidates/filter:hsubseq/init compv [fixlen]
##   @param[in] compv
##   @param[in,opt] fixlen
##   @var[in] comps_fixed
##   @var[out] comp_filter_pattern
function ble/complete/candidates/filter:hsubseq/init {
  local fixlen; ble/complete/candidates/filter:hsubseq/.determine-fixlen "$2"
  local ret; ble/complete/util/construct-ambiguous-regex "$1" "$fixlen"
  comp_filter_pattern=^$ret
}
## @fn ble/complete/candidates/filter:hsubseq/count-match-chars value [fixlen]
##   指定した文字列が COMPV の何処まで一致するかを返します。
##   @var[out] ret
function ble/complete/candidates/filter:hsubseq/count-match-chars {
  local value=$1 compv=$COMPV
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$value"; value=$ret
    ble/string#tolower "$compv"; compv=$ret
  fi

  local fixlen
  ble/complete/candidates/filter:hsubseq/.determine-fixlen "$2"
  [[ $value == "${compv::fixlen}"* ]] || return 1

  value=${value:fixlen}
  local i n=${#COMPV}
  for ((i=fixlen;i<n;i++)); do
    local a=${value%%"${compv:i:1}"*}
    [[ $a == "$value" ]] && { ret=$i; return 0; }
    value=${value:${#a}+1}
  done
  ret=$n
}
function ble/complete/candidates/filter:hsubseq/test { [[ $1 =~ $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:hsubseq/match {
  local needle=$1 text=$2
  if [[ :$comp_type: == *:i:* ]]; then
    ble/string#tolower "$needle"; needle=$ret
    ble/string#tolower "$text"; text=$ret
  fi

  local fixlen; ble/complete/candidates/filter:hsubseq/.determine-fixlen "$3"

  local prefix=${needle::fixlen}
  if [[ $text != "$prefix"* ]]; then
    if [[ $text && $text == "${prefix::${#text}}" ]]; then
      ret=(0 "${#text}")
    else
      ret=()
    fi
    return 0
  fi

  local pN=${#text} iN=${#needle}
  local first=1
  ret=()
  while :; do
    if [[ $first ]]; then
      first=
      local p0=0 p=${#prefix} i=${#prefix}
    else
      ((i<iN)) || return 0

      while ((p<pN)) && [[ ${text:p:1} != "${needle:i:1}" ]]; do
        ((p++))
      done
      ((p<pN)) || return 1
      p0=$p
    fi

    while ((i<iN&&p<pN)) && [[ ${text:p:1} == "${needle:i:1}" ]]; do
      ((p++,i++))
    done
    ((p0<p)) && ble/array#push ret "$p0" "$p"
  done
}

## @fn ble/complete/candidates/filter:subseq/init compv
##   @param[in] compv
##   @var[in] comps_fixed
##   @var[out] comp_filter_pattern
function ble/complete/candidates/filter:subseq/init {
  [[ $comps_fixed ]] && return 1
  ble/complete/candidates/filter:hsubseq/init "$1" 0
}
function ble/complete/candidates/filter:subseq/count-match-chars {
  ble/complete/candidates/filter:hsubseq/count-match-chars "$1" 0
}
function ble/complete/candidates/filter:subseq/test { [[ $1 =~ $comp_filter_pattern ]]; }
function ble/complete/candidates/filter:subseq/match {
  ble/complete/candidates/filter:hsubseq/match "$1" "$2" 0
}

function ble/complete/candidates/generate-with-filter {
  local filter_type=$1 opts=$2
  local -a remaining_sources nearest_sources
  remaining_sources=("${sources[@]}")

  local src asrc source
  while ((${#remaining_sources[@]})); do
    nearest_sources=()
    ble/complete/candidates/.pick-nearest-sources; (($?==148)) && return 148

    [[ ! $COMPV && :$opts: == *:no-empty:* ]] && continue
    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPV" || continue

    for src in "${nearest_sources[@]}"; do
      ble/string#split-words asrc "$src"
      ble/string#split source : "${asrc[0]}"

      local COMP_PREFIX= # 既定値 (yield-candidate で参照)
      ble/complete/source:"${source[@]}"
      ble/complete/check-cancel && return 148
    done

    [[ $comps_fixed ]] &&
      ble/complete/candidates/.filter-word-by-prefix "${COMPS::${comps_fixed%%:*}}"
    ((cand_count)) && return 0
  done
  return 0
}

function ble/complete/candidates/comp_type#read-rl-variables {
  local _ble_local_rlvars; ble/util/rlvar#load
  ble/util/rlvar#test completion-ignore-case 0 && comp_type=${comp_type}:i
  ble/util/rlvar#test visible-stats 0 && comp_type=${comp_type}:vstat
  ble/util/rlvar#test mark-directories 1 && comp_type=${comp_type}:markdir
  ble/util/rlvar#test mark-symlinked-directories 1 && comp_type=${comp_type}:marksymdir
  ble/util/rlvar#test match-hidden-files 1 && comp_type=${comp_type}:match-hidden
  ble/util/rlvar#test menu-complete-display-prefix 0 && comp_type=${comp_type}:menu-show-prefix

  # color settings are always enabled
  comp_type=$comp_type${bleopt_complete_menu_color:+:menu-color}
  comp_type=$comp_type${bleopt_complete_menu_color_match:+:menu-color-match}
}

## @fn ble/complete/candidates/generate opts
##   @param[in] opts
##   @var[in] comp_text comp_index
##   @arr[in] sources
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached
function ble/complete/candidates/generate {
  local opts=$1
  local flag_force_fignore=
  local flag_source_filter=
  local -a comp_fignore=()
  if [[ $FIGNORE ]]; then
    ble/complete/.fignore/prepare
    ((${#comp_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  local rex_raw_paramx
  ble/complete/candidates/.initialize-rex_raw_paramx
  ble/complete/candidates/comp_type#read-rl-variables

  local cand_iloop=0
  ble/complete/candidates/clear
  # #D1416 filter:none にするのは ~[TAB] の時など COMPV ではなく COMPS で補完したい事がある為
  ble/complete/candidates/generate-with-filter none "$opts" || return "$?"
  ((cand_count)) && return 0

  if [[ $bleopt_complete_ambiguous && $COMPV ]]; then
    local original_comp_type=$comp_type
    comp_type=${original_comp_type}:m
    ble/complete/candidates/generate-with-filter substr "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=${original_comp_type}:a
    ble/complete/candidates/generate-with-filter hsubseq "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=${original_comp_type}:A
    ble/complete/candidates/generate-with-filter subseq "$opts" || return "$?"
    ((cand_count)) && return 0
    comp_type=$original_comp_type
  fi

  return 0
}

## @fn ble/complete/candidates/determine-common-prefix/.apply-partial-comps
##   @var[in] COMPS
##   @var[in] comps_fixed
##   @var[in,out] common
function ble/complete/candidates/determine-common-prefix/.apply-partial-comps {
  local word0=$COMPS word1=$common fixed=
  if [[ $comps_fixed ]]; then
    local fixlen=${comps_fixed%%:*}
    fixed=${word0::fixlen}
    word0=${word0:fixlen}
    word1=${word1:fixlen}
  fi

  local ret spec path spec0 path0 spec1 path1
  ble/complete/source/evaluate-path-spec "$word0"; (($?==148)) && return 148; spec0=("${spec[@]}") path0=("${path[@]}")
  ble/complete/source/evaluate-path-spec "$word1"; (($?==148)) && return 148; spec1=("${spec[@]}") path1=("${path[@]}")
  local i=${#path1[@]}
  while ((i--)); do
    if ble/array#last-index path0 "${path1[i]}"; then
      local elem=${spec1[i]} # workaround bash-3.1 ${#arr[i]} bug
      word1=${spec0[ret]}${word1:${#elem}}
      break
    fi
  done
  common=$fixed$word1
}

# Note (#D1978): progcomp (syntax-raw) による単一確定の場合には遡って書き換わっ
#   ている場合でも、元の単語の部分を復元しようとはしない。
function ble/completion/candidates/determine-common-prefix/.is-progcomp-raw {
  ((cand_count==1)) && [[ ${cand_pack[0]} == progcomp:*:ble/syntax-raw:* ]] || return 0

  # 念の為、本当に DATA に :ble/syntax-raw: が含まれている事を確認する
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "${cand_pack[0]}"
  [[ $DATA == *:ble/syntax-raw:* ]]
}

## @fn ble/complete/candidates/determine-common-prefix
##   cand_* を元に common prefix を算出します。
##   @var[in] cand_*
##   @var[out] ret
function ble/complete/candidates/determine-common-prefix {
  # 共通部分
  local common=${cand_word[0]}
  local clen=${#common}
  if ((cand_count>1)); then
    # set up ignore case
    local unset_nocasematch= flag_tolower=
    if [[ :$comp_type: == *:i:* ]]; then
      if ((_ble_bash<30100)); then
        flag_tolower=1
        ble/string#tolower "$common"; common=$ret
      else
        unset_nocasematch=1
        shopt -s nocasematch
      fi
    fi

    local word loop=0
    for word in "${cand_word[@]:1}"; do
      ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && break

      if [[ $flag_tolower ]]; then
        ble/string#tolower "$word"; word=$ret
      fi

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common=${common::clen}
    done

    [[ $unset_nocasematch ]] && shopt -u nocasematch
    ble/complete/check-cancel && return 148

    [[ $flag_tolower ]] && common=${cand_word[0]::${#common}}
  fi

  if [[ $common != "$COMPS"* && ! ( $cand_count -eq 1 && $comp_type == *:i:* ) ]]; then
    if ! ble/completion/candidates/determine-common-prefix/.is-progcomp-raw; then
      # common を部分的に COMPS に置換する試み
      # Note: ignore-case で一意確定の時は case を候補に合わせたいので COMPS に
      #   は置換しない。
      ble/complete/candidates/determine-common-prefix/.apply-partial-comps
    fi
  fi

  if ((cand_count>1)) && [[ $common != "$COMPS"* ]]; then
    local common0=$common
    common=$COMPS # 取り敢えず補完挿入をキャンセル

    if [[ :$comp_type: == *:[maAi]:* ]]; then
      # 曖昧一致の時は遡って書き換えを起こし得る、
      # 一致する部分までを置換し一致しなかった部分を末尾に追加する。

      local simple_flags simple_ibrace
      if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common0"; then
        local common_reconstructed=$ret
        local value=$ret filter_type=head
        case :$comp_type: in
        (*:m:*) filter_type=substr ;;
        (*:a:*) filter_type=hsubseq ;;
        (*:A:*) filter_type=subseq ;;
        esac

        local is_processed=
        ble/complete/source/eval-simple-word "$common_reconstructed" single; local ext=$?
        ((ext==148)) && return 148
        if ((ext==0)) && ble/complete/candidates/filter:"$filter_type"/count-match-chars "$ret"; then
          if [[ $filter_type == head ]] && ((ret<${#COMPV})); then
            is_processed=1
            # Note: #D1181 ここに来たという事は外部の枠組みで
            #   生成された先頭一致しない候補があるという事。
            #   入力済み文字列が失われてしまう危険性を承知の上と思われるので書き換えを許可する。
            [[ $bleopt_complete_allow_reduction ]] && common=$common0
          elif ((ret)); then
            is_processed=1
            ble/string#escape-for-bash-specialchars "${COMPV:ret}" c
            common=$common0$ret
          fi
        fi

        # #D1417 チルダ展開やパス名展開など途中で切ると全く異なる展開になる物について
        #   より正しく処理する為に、完全解ではないが notilde, noglob でも部分一致を調べる。
        #
        #   例えば既に ~nouser と入力して共通一致部分が ~ だった時に
        #   ~ の何処までが ~nouser に部分一致するか調べる時、チルダ展開が有効だと
        #   ~ が /home/user に展開されてから部分一致が調べられる為、
        #   一致が起こらずに "~nouser" の全てが追加で挿入されて "~~nouser" になってしまう。
        #   なのでチルダ展開・パス名展開を無効にして部分一致を試みる必要がある。
        if [[ ! $is_processed ]] &&
             local notilde=\'\' &&
             ble/syntax:bash/simple-word/safe-eval "$notilde$COMPS" reconstruct:noglob &&
             local compv_notilde=$ret &&
             ble/syntax:bash/simple-word/eval "$notilde$common_reconstructed" noglob &&
             local commonv_notilde=$ret &&
             COMPV=$compv_notilde ble/complete/candidates/filter:"$filter_type"/count-match-chars "$commonv_notilde"
        then
          if [[ $filter_type == head ]] && ((ret<${#COMPV})); then
            is_processed=1
            [[ $bleopt_complete_allow_reduction ]] && common=$common0
          elif ((ret)); then
            # Note: 今の実装では展開結果に含まれている *?[ は全て glob として取
            #   り扱う事になっている。つまり 'a*b' が曖昧部分一致した時には元々
            #   の quote が外れて a*b になってしまうという事。これは現在の実装
            #   の制限である。
            is_processed=1
            ble/string#escape-for-bash-specialchars "${compv_notilde:ret}" TG
            common=$common0$ret
          fi
        fi

        [[ $is_processed ]] || common=$common0$COMPS
      fi

    else
      # Note: #D0768 文法的に単純であれば (構造を破壊しなければ) 遡って書き換えが起こることを許す。
      # Note: #D1181 外部の枠組みで生成された先頭一致しない共通部分の時でも書き換えを許す。
      if ble/syntax:bash/simple-word/is-simple-or-open-simple "$common"; then
        local flag_reduction=
        if [[ $bleopt_complete_allow_reduction ]]; then
          flag_reduction=1
        else
          local simple_flags simple_ibrace
          ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common0" &&
            ble/complete/source/eval-simple-word "$ret" single &&
            [[ $ret == "$COMPV"* ]] &&
            flag_reduction=1
          (($?==148)) && return 148
        fi

        [[ $flag_reduction ]] && common=$common0
      fi
    fi
  fi

  ret=$common
}

# 
#==============================================================================
# 候補一覧

_ble_complete_menu_active=
_ble_complete_menu_style=
_ble_complete_menu0_beg=
_ble_complete_menu0_end=
_ble_complete_menu0_str=
_ble_complete_menu_common_part=
_ble_complete_menu0_comp=()
_ble_complete_menu0_pack=()
_ble_complete_menu_comp=()

## @fn ble/complete/menu-complete.class/render-item pack opts
##   @param[in] pack
##     cand_pack の要素と同様の形式の文字列です。
##   @param[in] opts
##     コロン区切りのオプションです。
##     selected
##       選択されている候補の描画シーケンスを生成します。
##   @var[in,out] x y
##   @var[out] ret
##   @var[in] cols lines
##   @var[in] _ble_complete_menu_common_part
function ble/complete/menu-complete.class/render-item {
  local opts=$2

  # Note: select は menu 表示の文脈ではないので、
  #   補完文脈を復元しなければ参照できない。
  if [[ :$opts: == *:selected:* ]]; then
    local COMP1=${_ble_complete_menu_comp[0]}
    local COMP2=${_ble_complete_menu_comp[1]}
    local COMPS=${_ble_complete_menu_comp[2]}
    local COMPV=${_ble_complete_menu_comp[3]}
    local comp_type=${_ble_complete_menu_comp[4]}
    local comps_flags=${_ble_complete_menu0_comp[5]}
    local comps_fixed=${_ble_complete_menu0_comp[6]}
    local menu_common_part=$_ble_complete_menu_common_part
  fi

  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "$1"

  local prefix_len=$PREFIX_LEN
  [[ :$comp_type: == *:menu-show-prefix:* ]] && prefix_len=0

  local filter_target=${CAND:prefix_len}
  if [[ ! $filter_target ]]; then
    ret=
    return 0
  fi

  # 色の設定・表示内容・前置詞・後置詞を取得
  local g=0 show=$filter_target suffix= prefix=
  ble/function#try ble/complete/action:"$ACTION"/init-menu-item
  local g0=$g; [[ :$comp_type: == *:menu-color:* ]] || g0=0

  # 一致部分の抽出
  local m
  if [[ :$comp_type: == *:menu-color-match:* && $_ble_complete_menu_common_part && $show == *"$filter_target"* ]]; then
    local filter_type=head
    case :$comp_type: in
    (*:m:*) filter_type=substr ;;
    (*:a:*) filter_type=hsubseq ;;
    (*:A:*) filter_type=subseq ;;
    esac

    local needle=${_ble_complete_menu_common_part:prefix_len}
    ble/complete/candidates/filter:"$filter_type"/match "$needle" "$filter_target"; m=("${ret[@]}")

    # 表示文字列の部分文字列で絞り込みが起こっている場合
    if [[ $show != "$filter_target" ]]; then
      local show_prefix=${show%%"$filter_target"*}
      local offset=${#show_prefix}
      local i n=${#m[@]}
      for ((i=0;i<n;i++)); do ((m[i]+=offset)); done
    fi
  else
    m=()
  fi

  # 基本色の初期化 (Note: 高速化の為、直接 _ble_color_g2sgr を参照する)
  local sgrN0= sgrN1= sgrB0= sgrB1=
  [[ :$opts: == *:selected:* ]] && ((g0^=_ble_color_gflags_Revert))
  ret=${_ble_color_g2sgr[g=g0]}
  [[ $ret ]] || ble/color/g2sgr "$g"; sgrN0=$ret
  ret=${_ble_color_g2sgr[g=g0^_ble_color_gflags_Revert]}
  [[ $ret ]] || ble/color/g2sgr "$g"; sgrN1=$ret
  if ((${#m[@]})); then
    # 一致色の初期化
    ret=${_ble_color_g2sgr[g=g0|_ble_color_gflags_Bold]}
    [[ $ret ]] || ble/color/g2sgr "$g"; sgrB0=$ret
    ret=${_ble_color_g2sgr[g=(g0|_ble_color_gflags_Bold)^_ble_color_gflags_Revert]}
    [[ $ret ]] || ble/color/g2sgr "$g"; sgrB1=$ret
  fi

  # 前置部分の出力
  local out= flag_overflow= p0=0
  if [[ $prefix ]]; then
    ble/canvas/trace-text "$prefix" nonewline || flag_overflow=1
    out=$out$_ble_term_sgr0$ret
  fi

  # 一致部分の出力
  if ((${#m[@]})); then
    local i iN=${#m[@]} p p0=0
    for ((i=0;i<iN;i++)); do
      ((p=m[i]))
      if ((p0<p)); then
        if ((i%2==0)); then
          local sgr0=$sgrN0 sgr1=$sgrN1
        else
          local sgr0=$sgrB0 sgr1=$sgrB1
        fi
        ble/canvas/trace-text "${show:p0:p-p0}" nonewline:external-sgr || flag_overflow=1
        out=$out$sgr0$ret
      fi
      p0=$p
    done
  fi

  # 残りの出力
  if ((p0<${#show})); then
    local sgr0=$sgrN0 sgr1=$sgrN1
    ble/canvas/trace-text "${show:p0}" nonewline:external-sgr || flag_overflow=1
    out=$out$sgr0$ret
  fi

  # 後置部分の出力
  if [[ $suffix ]]; then
    ble/canvas/trace-text "$suffix" nonewline || flag_overflow=1
    out=$out$_ble_term_sgr0$ret
  fi

  ret=$out$_ble_term_sgr0
  [[ ! $flag_overflow ]]
}

function ble/complete/menu-complete.class/get-desc {
  local item=$1
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/unpack "$item"
  desc="$desc_sgrt(action:$ACTION)$desc_sgr0"
  ble/function#try ble/complete/action:"$ACTION"/get-desc
}

function ble/complete/menu-complete.class/onselect {
  local nsel=$1 osel=$2
  local insert=${_ble_complete_menu_original:-${_ble_complete_menu_comp[2]}}
  if ((nsel>=0)); then
    local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/unpack "${_ble_complete_menu_items[nsel]}"
    insert=$INSERT
  fi

  if [[ :$bleopt_complete_menu_complete_opts: == *:insert-selection:* ]]; then
    ble-edit/content/replace-limited "$_ble_complete_menu0_beg" "$_ble_edit_ind" "$insert"
    ((_ble_edit_ind=_ble_complete_menu0_beg+${#insert}))
  else
    ((_ble_edit_ind=_ble_complete_menu0_beg))
  fi
}

function ble/complete/menu/clear {
  if [[ $_ble_complete_menu_active ]]; then
    _ble_complete_menu_active=
    ble/complete/menu#clear
    [[ $_ble_highlight_layer_menu_filter_beg ]] &&
      ble/textarea#invalidate str # layer:menu_filter 解除 (#D0995)
  fi
  return 0
}
blehook widget_bell!=ble/complete/menu/clear
blehook history_leave!=ble/complete/menu/clear

## @fn ble/complete/menu/get-footprint
##   @var[out] footprint
function ble/complete/menu/get-footprint {
  footprint=$_ble_edit_ind:$_ble_edit_mark_active:${_ble_edit_mark_active:+$_ble_edit_mark}:$_ble_edit_overwrite_mode:$_ble_edit_str
}

## @fn ble/complete/menu/show opts
##   @param[in] opts
##     filter
##     menu-source
##     offset=NUMBER
##   @var[in] comp_type
##   @var[in] COMP1 COMP2 COMPS COMPV comps_flags comps_fixed
##   @arr[in] cand_pack
##   @var[in] menu_common_part
##
function ble/complete/menu/show {
  local opts=$1

  if [[ :$opts: == *:load-filtered-data:* ]]; then
    local COMP1=${_ble_complete_menu_comp[0]}
    local COMP2=${_ble_complete_menu_comp[1]}
    local COMPS=${_ble_complete_menu_comp[2]}
    local COMPV=${_ble_complete_menu_comp[3]}
    local comp_type=${_ble_complete_menu_comp[4]}
    local comps_flags=${_ble_complete_menu0_comp[5]}
    local comps_fixed=${_ble_complete_menu0_comp[6]}
    local cand_pack; cand_pack=("${_ble_complete_menu_items[@]}")
    local menu_common_part=$_ble_complete_menu_common_part
  fi

  # settings
  local menu_style=$bleopt_complete_menu_style
  [[ :$opts: == *:filter:* && $_ble_complete_menu_style ]] &&
    menu_style=$_ble_complete_menu_style
  local menu_items; menu_items=("${cand_pack[@]}")

  _ble_complete_menu_common_part=$menu_common_part
  local menu_class=ble/complete/menu-complete.class menu_param=

  local menu_opts=$opts
  [[ :$comp_type: == *:sync:* ]] && menu_opts=$menu_opts:sync

  ble/complete/menu#construct "$menu_opts" || return "$?"
  ble/complete/menu#show

  if [[ :$opts: == *:menu-source:* ]]; then
    # menu に既に表示されている内容を元にした補完後のメニュー再表示。
    # 補完開始時の情報を保持したまま調整を行う。

    # 編集領域左側の文字列が曖昧補完によって書き換わる可能性がある
    local left0=${_ble_complete_menu0_str::_ble_complete_menu0_end}
    local left1=${_ble_edit_str::_ble_edit_ind}
    local ret; ble/string#common-prefix "$left0" "$left1"; left0=$ret

    # 編集領域右側の文字列が吸収されて書き換わる可能性がある
    local right0=${_ble_complete_menu0_str:_ble_complete_menu0_end}
    local right1=${_ble_edit_str:_ble_edit_ind}
    local ret; ble/string#common-suffix "$right0" "$right1"; right0=$ret

    local footprint; ble/complete/menu/get-footprint
    _ble_complete_menu0_str=$left0$right0
    _ble_complete_menu0_end=${#left0}
    _ble_complete_menu_footprint=$footprint
  elif [[ :$opts: != *:filter:* ]]; then
    local beg=$COMP1 end=$_ble_edit_ind # COMP2 でなく補完挿入後の位置
    local str=$_ble_edit_str
    [[ $_ble_decode_keymap == auto_complete ]] &&
      str=${str::_ble_edit_ind}${str:_ble_edit_mark}
    local footprint; ble/complete/menu/get-footprint
    _ble_complete_menu_active=1
    _ble_complete_menu_style=$menu_style
    _ble_complete_menu0_beg=$beg
    _ble_complete_menu0_end=$end
    _ble_complete_menu0_str=$str
    _ble_complete_menu0_comp=("$COMP1" "$COMP2" "$COMPS" "$COMPV" "$comp_type" "$comps_flags" "$comps_fixed")
    _ble_complete_menu0_pack=("${cand_pack[@]}")
    _ble_complete_menu_selected=-1
    _ble_complete_menu_comp=("$COMP1" "$COMP2" "$COMPS" "$COMPV" "$comp_type")
    _ble_complete_menu_footprint=$footprint
  fi
  return 0
}

function ble/complete/menu/redraw {
  if [[ $_ble_complete_menu_active ]]; then
    ble/complete/menu#show
  fi
}

## ble/complete/menu/get-active-range [str [ind]]
##   @param[in,opt] str ind
##   @var[out] beg end
function ble/complete/menu/get-active-range {
  [[ $_ble_complete_menu_active ]] || return 1

  local str=${1-$_ble_edit_str} ind=${2-$_ble_edit_ind}
  local mbeg=$_ble_complete_menu0_beg
  local mend=$_ble_complete_menu0_end
  local left=${_ble_complete_menu0_str::mend}
  local right=${_ble_complete_menu0_str:mend}
  if [[ ${str::_ble_edit_ind} == "$left"* && ${str:_ble_edit_ind} == *"$right" ]]; then
    ((beg=mbeg,end=${#str}-${#right}))
    return 0
  else
    ble/complete/menu/clear
    return 1
  fi
}

## @fn ble/complete/menu/generate-candidates-from-menu
##   現在表示されている menu 内容から候補を再抽出します。
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/menu/generate-candidates-from-menu {
  # completion context information
  COMP1=${_ble_complete_menu_comp[0]}
  COMP2=${_ble_complete_menu_comp[1]}
  COMPS=${_ble_complete_menu_comp[2]}
  COMPV=${_ble_complete_menu_comp[3]}
  comp_type=${_ble_complete_menu_comp[4]}
  comps_flags=${_ble_complete_menu0_comp[5]}
  comps_fixed=${_ble_complete_menu0_comp[6]}

  # remaining candidates
  cand_count=${#_ble_complete_menu_items[@]}
  cand_cand=() cand_word=() cand_pack=()
  local pack "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  for pack in "${_ble_complete_menu_items[@]}"; do
    ble/complete/cand/unpack "$pack"
    ble/array#push cand_cand "$CAND"
    ble/array#push cand_word "$INSERT"
    ble/array#push cand_pack "$pack"
  done
  ((cand_count))
}

# 
#==============================================================================
# 補完

## @fn ble/complete/generate-candidates-from-opts opts
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
##   @var[in,out] cand_limit_reached
function ble/complete/generate-candidates-from-opts {
  local opts=$1

  # 文脈の決定
  local context; ble/complete/complete/determine-context-from-opts "$opts"

  # 補完源の生成
  comp_type=
  [[ :$opts: == *:auto_menu:* ]] && comp_type=auto_menu
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local sources
  ble/complete/context:"$context"/generate-sources "$comp_text" "$comp_index" || return "$?"

  ble/complete/candidates/generate "$opts"
}

## @fn ble/complete/insert insert_beg insert_end insert suffix
function ble/complete/insert {
  local insert_beg=$1 insert_end=$2
  local insert=$3 suffix=$4
  local original_text=${_ble_edit_str:insert_beg:insert_end-insert_beg}
  local ret

  # 編集範囲の最小化
  local insert_replace=
  if [[ $insert == "$original_text"* ]]; then
    # 既存部分の置換がない場合
    insert=${insert:insert_end-insert_beg}
    ((insert_beg=insert_end))
  else
    # 既存部分の置換がある場合
    ble/string#common-prefix "$insert" "$original_text"
    if [[ $ret ]]; then
      insert=${insert:${#ret}}
      ((insert_beg+=${#ret}))
    fi
  fi

  if [[ $bleopt_complete_skip_matched ]]; then
    # カーソルの右のテキストの吸収
    if [[ $insert ]]; then
      local right_text=${_ble_edit_str:insert_end}
      right_text=${right_text%%[$IFS]*}
      if ble/string#common-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に先頭一致する場合に吸収
        ((insert_end+=${#ret}))
      elif ble/complete/string#common-suffix-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に末尾一致する場合に吸収
        ((insert_end+=${#ret}))
      fi
    fi

    # suffix の吸収
    if [[ $suffix ]]; then
      local right_text=${_ble_edit_str:insert_end}
      if ble/string#common-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      elif ble/complete/string#common-suffix-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      fi
    fi
  fi

  local ins=$insert$suffix
  ble/widget/.replace-range "$insert_beg" "$insert_end" "$ins"
  ((_ble_edit_ind=insert_beg+${#ins},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
}

## @fn ble/complete/insert-common
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/insert-common {
  local ret
  ble/complete/candidates/determine-common-prefix; (($?==148)) && return 148
  local insert=$ret suffix=
  local insert_beg=$COMP1 insert_end=$COMP2
  local insert_flags=
  [[ $insert == "$COMPS"* ]] || insert_flags=r

  if ((cand_count==1)); then
    # 一意確定の時
    local ACTION=${cand_pack[0]%%:*}
    if ble/is-function ble/complete/action:"$ACTION"/complete; then
      local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/unpack "${cand_pack[0]}"
      ble/complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
  else
    # 候補が複数ある時
    insert_flags=${insert_flags}m
  fi

  local do_insert=1
  if ((cand_count>1)) && [[ $insert_flags == *r* ]]; then
    # 既存部分を置換し、かつ一意確定でない場合は置換しない。
    # 曖昧補完の時は determine-common-prefix 内で調整されるので挿入する。
    if [[ :$comp_type: != *:[maAi]:* ]]; then
      do_insert=
    fi
  elif [[ $insert$suffix == "$COMPS" ]]; then
    # 何も変化がない時は、挿入しない。
    do_insert=
  fi
  if [[ $do_insert ]]; then
    ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
    blehook/invoke complete_insert
  fi

  if [[ $insert_flags == *m* ]]; then
    # menu_common_part (メニュー強調文字列)
    #   もし insert が単純単語の場合には
    #   menu_common_part を挿入後の評価値とする。
    #   そうでなければ仕方がないので挿入前の値 COMPV とする。
    local menu_common_part=$COMPV
    local ret simple_flags simple_ibrace
    if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$insert"; then
      ble/complete/source/eval-simple-word "$ret" single
      (($?==148)) && return 148
      menu_common_part=$ret
    fi
    ble/complete/menu/show "$menu_show_opts" || return "$?"
  elif [[ $insert_flags == *n* ]]; then
    ble/widget/complete show_menu:regenerate || return "$?"
  else
    _ble_complete_state=complete
    ble/complete/menu/clear
  fi
  return 0
}

## @fn ble/complete/insert-all
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/insert-all {
  local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  local pack beg=$COMP1 end=$COMP2 insert= suffix= insert_flags= index=0
  for pack in "${cand_pack[@]}"; do
    ble/complete/cand/unpack "$pack"
    insert=$INSERT suffix= insert_flags=

    if ble/is-function ble/complete/action:"$ACTION"/complete; then
      ble/complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
    [[ $suffix != *' ' ]] && suffix="$suffix "

    ble/complete/insert "$beg" "$end" "$insert" "$suffix"
    blehook/invoke complete_insert
    beg=$_ble_edit_ind end=$_ble_edit_ind
    ((index++))
  done

  _ble_complete_state=complete
  ble/complete/menu/clear
  return 0
}

## @fn ble/complete/insert-braces/.compose words...
##   指定した単語をブレース展開に圧縮します。
##   @var[in] comp_type
##   @stdout
##     圧縮したブレース展開を返します。
function ble/complete/insert-braces/.compose {
  # Note: awk が RS = "\0" に対応していれば \0 で区切る。
  #   それ以外の場合には \x1E (ASCII RS) で区切る。
  if ble/bin/awk0.available; then
    local printf_format='%s\0' char_RS='"\0"' awk=ble/bin/awk0
  else
    local printf_format='%s\x1E' char_RS='"\x1E"' awk=ble/bin/awk
  fi

  local q=\'
  local -x rex_atom='^(\\.|[0-9]+|.)' del_close= del_open= quote_type=
  local -x COMPS=$COMPS
  if [[ :$comp_type: != *:[maAi]:* ]]; then
    local rex_brace='[,{}]|\{[-a-zA-Z0-9]+\.\.[-a-zA-Z0-9]+\}'
    case $comps_flags in
    (*S*)    rex_atom='^('$q'(\\'$q'|'$rex_brace')'$q'|[0-9]+|.)' # '...'
             del_close=\' del_open=\' quote_type=S ;;
    (*E*)    rex_atom='^(\\.|'$q'('$rex_brace')\$'$q'|[0-9]+|.)'  # $'...'
             del_close=\' del_open=\$\' quote_type=E ;;
    (*[DI]*) rex_atom='^(\\[\"$`]|"('$rex_brace')"|[0-9]+|.)'     # "...", $"..."
             del_close=\" del_open=\" quote_type=D ;;
    esac
  fi

  printf "$printf_format" "$@" | "$awk" '
    function starts_with(str, head) {
      return substr(str, 1, length(head)) == head;
    }

    # Note: value ~ /[[:lower:]]/ cannot be used in mawk. value ~ /[a-z]/ may
    # match uppercase characters in some strange locales, e.g., en_US.UTF-8 in
    # Ubuntu 16.04 LTS.
    function islower(s) {
      return s == tolower(s);
    }

    BEGIN {
      RS = '"$char_RS"';
      rex_atom = ENVIRON["rex_atom"];
      del_close = ENVIRON["del_close"];
      del_open = ENVIRON["del_open"];
      quote_type = ENVIRON["quote_type"];
      COMPS = ENVIRON["COMPS"];

      BRACE_OPEN = del_close "{" del_open;
      BRACE_CLOS = del_close "}" del_open;
    }

    function to_atoms(str, arr, _, chr, atom, level, count, rex) {
      count = 0;
      while (match(str, rex_atom) > 0) {
        chr = substr(str, 1, RLENGTH);
        str = substr(str, RLENGTH + 1);
        if (chr == BRACE_OPEN) {
          atom = chr;
          level = 1;
          while (match(str, rex_atom) > 0) {
            chr = substr(str, 1, RLENGTH);
            str = substr(str, RLENGTH + 1);
            atom = atom chr;
            if (chr == BRACE_OPEN)
              level++;
            else if (chr == BRACE_CLOS && --level==0)
              break;
          }
        } else {
          atom = chr;
        }
        arr[count++] = atom;
      }
      return count;
    }

    function remove_empty_quote(str, _, rex_quote_first, rex_quote, out, empty, m) {
      if (quote_type == "S" || quote_type == "E") {
        rex_quote_first = "^[^'$q']*'$q'";
        rex_quote = "'$q'[^'$q']*'$q'|(\\\\.|[^'$q'])+";
      } else if (quote_type == "D") {
        rex_quote_first = "^[^\"]*\"";
        rex_quote = "\"([^\\\"]|\\\\.)*\"|(\\\\.|[^\"])+";
      } else return str;
      empty = del_open del_close;

      out = "";

      if (starts_with(str, COMPS)) {
        out = COMPS;
        str = substr(str, length(COMPS) + 1);
        if (match(str, rex_quote_first) > 0) {
          out = out substr(str, 1, RLENGTH);
          str = substr(str, RLENGTH + 1);
        }
      }

      while (match(str, rex_quote) > 0) {
        m = substr(str, 1, RLENGTH);
        if (m != empty) out = out m;
        str = substr(str, RLENGTH + 1);
      }

      if (str == del_open)
        return out;
      else
        return out str del_close;
    }

    function zpad(value, width, _, wpad, i, pad) {
      wpad = width - length(value);
      pad = "";
      for (i = 0; i < wpad; i++) pad = "0" pad;
      if (value < 0)
        return "-" pad (-value);
      else
        return pad value;
    }
    function zpad_remove(value) {
      if (value ~ /^0+$/)
        value = "0";
      else if (value ~ /^-/)
        sub(/^-0+/, "-", value);
      else
        sub(/^0+/, "", value);
      return value;
    }
    function zpad_a2i(text) {
      sub(/^-0+/, "-", text) || sub(/^0+/, "", text);
      return 0 + text;
    }

    function range_contract(arr, len, _, i, value, alpha, lower, upper, keys, ikey, dict, b, e, beg, end, tmp) {
      lower = "abcdefghijklmnopqrstuvwxyz";
      upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
      for (i = 0; i < len; i++) {
        value = arr[i];
        if (dict[value]) {
          dict[value]++;
        } else {
          keys[ikey++] = value;
          dict[value] = 1;
        }
      }

      len = 0;

      for (i = 0; i < ikey; i++) {
        while (dict[value = keys[i]]--) {
          if (value ~ /^([a-zA-Z])$/) {
            alpha = islower(value) ? lower : upper;
            beg = end = value;
            b = e = index(alpha, value);
            while (b > 1 && dict[tmp = substr(alpha, b - 1, 1)]) {
              dict[beg = tmp]--;
              b--;
            }
            while (e < 26 && dict[tmp = substr(alpha, e + 1, 1)]) {
              dict[end = tmp]--;
              e++;
            }

            if (e == b) {
              arr[len++] = beg;
            } else if (e == b + 1) {
              arr[len++] = beg;
              arr[len++] = end;
            } else {
              arr[len++] = del_close "{" beg ".." end "}" del_open;
            }

          } else if (value ~ /^(0+|-?0*[1-9][0-9]*)$/) {
            beg = end = value;
            b = e = zpad_a2i(value);
            wmax = wmin = length(value);

            # range extension for normal numbers
            if (value ~ /^(0|-?[1-9][0-9]*)$/) {
              while (dict[b - 1]) dict[--b]--;
              while (dict[e + 1]) dict[++e]--;

              tmp = length(beg = "" b);
              if (tmp < wmin) wmin = tmp;
              else if (tmp > wmax) wmax = tmp;

              tmp = length(end = "" e);
              if (tmp < wmin) wmin = tmp;
              else if (tmp > wmax) wmax = tmp;
            }

            # try range extension for zpad numbers
            if (wmax == wmin) {
              while (length(tmp = zpad(b - 1, wmin)) == wmin && dict[tmp]) { dict[tmp]--; --b; }
              while (length(tmp = zpad(e + 1, wmin)) == wmin && dict[tmp]) { dict[tmp]--; ++e; }
              beg = zpad(b, wmin);
              end = zpad(e, wmin);
            }

            if (e == b) {
              arr[len++] = beg;
            } else if (e == b + 1) {
              arr[len++] = beg;
              arr[len++] = end;
            } else if (b < 0 && e < 0) {
              # if all the numbers are negative, factorize -
              arr[len++] = del_close "-{" substr(end, 2) ".." substr(beg, 2) "}" del_open;
            } else {
              arr[len++] = del_close "{" beg ".." end "}" del_open;
            }

          } else {
            arr[len++] = value;
          }
        }
      }
      return len;
    }

    function simple_brace(arr, len, _, ret, i) {
      if (len == 0) return "";

      len = range_contract(arr, len);
      if (len == 1) return arr[0];

      ret = BRACE_OPEN arr[0];
      for (i = 1; i < len; i++)
        ret = ret del_close "," del_open arr[i];
      return ret BRACE_CLOS;
    }

    #--------------------------------------------------------------------------
    # right factorization

    function rfrag_strlen_common(a, b, _, la, lb, tmp, i, n) {
      ret = 0;
      alen = to_atoms(a, abuf);
      blen = to_atoms(b, bbuf);
      while (alen > 0 && blen > 0) {
        if (abuf[alen - 1] != bbuf[blen - 1]) break;
        ret += length(abuf[alen - 1]);
        alen--;
        blen--;
      }
      return ret;
    }
    function rfrag_get_level(str, _, len, i, rfrag0, rfrag0len, rfrag1) {
      len = length(str);
      rfrag_matching_offset = len;
      for (i = 0; i < rfrag_depth - 1; i++) {
        rfrag0 = rfrag[i];
        rfrag0len = length(rfrag0);
        rfrag1 = substr(str, len - rfrag0len + 1);
        str = substr(str, 1, len -= rfrag0len);
        if (rfrag0 != rfrag1) break;
        rfrag_matching_offset -= rfrag0len;
      }
      while (i && rfrag[i - 1] == "") i--; # empty fragment
      return i;
    }
    function rfrag_reduce(new_depth, _, c, i, brace, frags) {
      while (rfrag_depth > new_depth) {
        rfrag_depth--;
        c = rfrag_count[rfrag_depth];
        for (i = 0; i < c; i++)
          frags[i] = rfrag[rfrag_depth, i];
        frags[c] = rfrag[rfrag_depth];
        brace = simple_brace(frags, c + 1);

        if (rfrag_depth == 0)
          return brace;
        else
          rfrag[rfrag_depth - 1] = brace rfrag[rfrag_depth - 1];
      }
    }
    function rfrag_register(str, level, _, rfrag0, rfrag1, len) {
      if (level == rfrag_depth) {
        rfrag_depth = level + 1;
        rfrag[level] = "";
        rfrag_count[level] = 0;
      } else if (rfrag_depth != level + 1) {
        print "ERR(rfrag)";
      }

      rfrag0 = rfrag[level];
      rfrag1 = substr(str, 1, rfrag_matching_offset);
      len = rfrag_strlen_common(rfrag0, rfrag1);
      if (len == 0) {
        rfrag[level, rfrag_count[level]++] = rfrag0;
        rfrag[level] = rfrag1;
      } else {
        rfrag[level] = substr(rfrag0, length(rfrag0) - len + 1);
        rfrag[level + 1, 0] = substr(rfrag0, 1, length(rfrag0) - len);
        rfrag[level + 1] = substr(rfrag1, 1, length(rfrag1) - len);
        rfrag_count[level + 1] = 1;
        rfrag_depth++;
      }
    }
    function rfrag_dump(_, i, j, prefix) {
      print "depth = " rfrag_depth;
      for (i = 0; i < rfrag_depth; i++) {
        prefix = "";
        for (j = 0; j < i; j++) prefix = prefix "  ";
        for (j = 0; j < rfrag_count[i]; j++)
          print prefix "rfrag[" i "," j "] = " rfrag[i,j];
        print prefix "rfrag[" i "] = " rfrag[i];
      }
    }
    function rfrag_brace(arr, len, _, i, level) {
      if (len == 0) return "";
      if (len == 1) return arr[0];

      rfrag_depth = 1;
      rfrag[0] = arr[0];
      rfrag_count[0] = 0;
      for (i = 1; i < len; i++) {
        level = rfrag_get_level(arr[i]);
        rfrag_reduce(level + 1);
        rfrag_register(arr[i], level);
      }

      return rfrag_reduce(0);
    }

    #--------------------------------------------------------------------------
    # left factorization

    function lfrag_strlen_common(a, b, _, ret, abuf, bbuf, alen, blen, ia, ib) {
      ret = 0;
      alen = to_atoms(a, abuf);
      blen = to_atoms(b, bbuf);
      for (ia = ib = 0; ia < alen && ib < blen; ia++ + ib++) {
        if (abuf[ia] != bbuf[ib]) break;
        ret += length(abuf[ia]);
      }
      return ret;
    }
    function lfrag_get_level(str, _, i, frag0, frag0len, frag1) {
      lfrag_matching_offset = 0;
      for (i = 0; i < lfrag_depth - 1; i++) {
        frag0 = frag[i]
        frag0len = length(frag0);
        frag1 = substr(str, lfrag_matching_offset + 1, frag0len);
        if (frag0 != frag1) break;
        lfrag_matching_offset += frag0len;
      }
      while (i && frag[i - 1] == "") i--; # empty fragment
      return i;
    }
    function lfrag_reduce(new_depth, _, c, i, brace, frags) {
      while (lfrag_depth > new_depth) {
        lfrag_depth--;
        c = frag_count[lfrag_depth];
        for (i = 0; i < c; i++)
          frags[i] = frag[lfrag_depth, i];
        frags[c] = frag[lfrag_depth];
        brace = rfrag_brace(frags, c + 1);

        if (lfrag_depth == 0)
          return brace;
        else
          frag[lfrag_depth - 1] = frag[lfrag_depth - 1] brace;
      }
    }
    function lfrag_register(str, level, _, frag0, frag1, len) {
      if (lfrag_depth == level) {
        lfrag_depth = level + 1;
        frag[level] = "";
        frag_count[level] = 0;
      } else if (lfrag_depth != level + 1) {
        print "ERR";
      }

      frag0 = frag[level];
      frag1 = substr(str, lfrag_matching_offset + 1);
      len = lfrag_strlen_common(frag0, frag1);
      if (len == 0) {
        frag[level, frag_count[level]++] = frag0;
        frag[level] = frag1;
      } else {
        frag[level] = substr(frag0, 1, len);
        frag[level + 1, 0] = substr(frag0, len + 1);
        frag[level + 1] = substr(frag1, len + 1);
        frag_count[level + 1] = 1;
        lfrag_depth++;
      }
    }

    function lfrag_dump(_, i, j, prefix) {
      print "depth = " lfrag_depth;
      for (i = 0; i < lfrag_depth; i++) {
        prefix = "";
        for (j = 0; j < i; j++) prefix = prefix "  ";
        for (j = 0; j < frag_count[i]; j++)
          print prefix "frag[" i "," j "] = " frag[i,j];
        print prefix "frag[" i "] = " frag[i];
      }
    }

    NR == 1 {
      lfrag_depth = 1;
      frag[0] = $0;
      frag_count[0] = 0;
      #lfrag_dump();
      next
    }
    {
      level = lfrag_get_level($0);
      lfrag_reduce(level + 1);
      lfrag_register($0, level);
      #lfrag_dump();
    }

    END {
      result = lfrag_reduce(0);
      result = remove_empty_quote(result);
      print result;
    }
  '
}

## @fn ble/complete/insert-braces
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/insert-braces {
  if ((cand_count==1)); then
    ble/complete/insert-common; return "$?"
  fi

  local comps_len=${#COMPS} loop=0
  local -a tails=()

  # 共通部分 (大文字・小文字は区別する)
  local common=${cand_word[0]}
  ble/array#push tails "${common:comps_len}"
  local word clen=${#common}
  for word in "${cand_word[@]:1}"; do
    ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148

    # 共通部分
    ((clen>${#word}&&(clen=${#word})))
    while [[ ${word::clen} != "${common::clen}" ]]; do
      ((clen--))
    done
    common=${common::clen}

    # COMPS 以降の部分
    ble/array#push tails "${word:comps_len}"
  done

  local fixed=$COMPS
  if [[ $common != "$COMPS"* ]]; then
    # 遡って書き換えが起こる場合
    tails=()

    # 前方固定部分
    local fixed= fixval=
    {
      # comps_fixed 迄は確実に固定する
      [[ $comps_fixed ]] &&
        fixed=${COMPS::${comps_fixed%%:*}} fixval=${comps_fixed#*:}

      # もし COMPS を部分的に適用できればそれを用いる
      local ret simple_flags simple_ibrace
      ble/complete/candidates/determine-common-prefix/.apply-partial-comps # var[in,out] common
      if ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common"; then
        ble/complete/source/eval-simple-word "$ret" single
        (($?==148)) && return 148
        fixed=$common fixval=$ret
      fi
    }

    # cand_cand から cand_word を再構築
    local cand ret fixval_len=${#fixval}
    for cand in "${cand_cand[@]}"; do
      ((loop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
      [[ $cand == "$fixval"* ]] || continue

      ble/complete/string#escape-for-completion-context "${cand:fixval_len}"
      case $comps in
      (*S*) cand=\'$ret\'   ;;
      (*E*) cand=\$\'$ret\' ;;
      (*D*) cand=\"$ret\"   ;;
      (*I*) cand=\$\"$ret\" ;;
      (*)   cand=$ret ;;
      esac

      ble/array#push tails "$cand"
    done
  fi

  local tail; ble/util/assign tail 'ble/complete/insert-braces/.compose "${tails[@]}"'
  local beg=$COMP1 end=$COMP2 insert=$fixed$tail suffix=

  if [[ $comps_flags == *x* ]]; then
    ble/complete/action/complete.addtail ','
  else
    ble/complete/action/complete.addtail ' '
  fi

  ble/complete/insert "$beg" "$end" "$insert" "$suffix"
  blehook/invoke complete_insert
  _ble_complete_state=complete
  ble/complete/menu/clear
  return 0
}

_ble_complete_state=

## @widget complete opts
##   @param[in] opts
##     コロン区切りのリストです。
##     以下は動作を指定するオプションです。
##
##     insert_common (既定)
##       共通一致部分を挿入します。
##     insert_all
##       候補を全て挿入します。
##     insert_braces
##       候補をブレース展開にまとめて挿入します。
##     insert_unique
##       候補が一意のときメニュー補完に入らずに挿入します。
##     show_menu
##       メニューを表示します。
##     enter_menu
##       メニュー補完に入ります。
##
##     context=*
##       候補生成の文脈を指定します。
##     backward
##       メニュー補完に入る時に最後の候補に移動します。
##     no-empty
##       空の COMPV による補完を抑制します。
##     no-bell
##       候補が存在しなかった時のベルを発生させません。
##
##     auto_menu
##       auto-menu 経由で呼び出されている事を指定します。
##       補完候補数の制限に complete_limit_auto_menu を使います。
##       一部の補完源で complete_limit に達した時に補完全体を中止します。
##
function ble/widget/complete {
  local opts=$1
  ble-edit/content/clear-arg

  local state=$_ble_complete_state
  _ble_complete_state=start

  local menu_show_opts=

  if [[ :$opts: != *:insert_*:* && :$opts: != *:show_menu:* ]]; then
    if [[ :$opts: == *:enter_menu:* ]]; then
      [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]] &&
        ble/complete/menu-complete/enter "$opts" && return 0
    elif [[ $bleopt_complete_menu_complete ]]; then
      if [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]]; then
        local footprint; ble/complete/menu/get-footprint
        [[ $footprint == "$_ble_complete_menu_footprint" ]] &&
          ble/complete/menu-complete/enter "$opts" && return 0
      fi
      [[ $WIDGET == "$LASTWIDGET" && $state != complete ]] && opts=$opts:enter_menu
    fi
  fi

  local COMP1 COMP2 COMPS COMPV
  local comp_type comps_flags comps_fixed
  local cand_count cand_cand cand_word cand_pack
  ble/complete/candidates/clear
  local cand_limit_reached=
  if [[ $_ble_complete_menu_active && :$opts: != *:regenerate:* &&
          :$opts: != *:context=*:* && ${#_ble_complete_menu_icons[@]} -gt 0 ]]
  then
    if [[ $_ble_complete_menu_filter_enabled && $bleopt_complete_menu_filter ]] || {
         ble/complete/menu-filter; local ext=$?
         ((ext==148)) && return 148
         ((ext==0)); }; then
      ble/complete/menu/generate-candidates-from-menu; local ext=$?
      ((ext==148)) && return 148
      if ((ext==0&&cand_count)); then
        local bleopt_complete_menu_style=$_ble_complete_menu_style
        menu_show_opts=$menu_show_opts:menu-source # 既存の filter 前候補を保持する
      fi
    fi
  fi
  if ((cand_count==0)); then
    local bleopt_complete_menu_style=$bleopt_complete_menu_style # source 等に一次変更を認める。
    ble/complete/generate-candidates-from-opts "$opts"; local ext=$?
    if ((ext==148)); then
      return 148
    fi
    if [[ $cand_limit_reached ]]; then
      [[ :$opts: != *:no-bell:* ]] &&
        ble/widget/.bell 'complete: limit reached'
      if [[ $cand_limit_reached == cancel ]]; then
        ble/edit/info/default
        return 1
      fi
    fi
    if ((ext!=0||cand_count==0)); then
      [[ :$opts: != *:no-bell:* && ! $cand_limit_reached ]] &&
        ble/widget/.bell 'complete: no completions'
      ble/edit/info/default
      return 1
    fi
  fi

  if [[ :$opts: == *:insert_common:* || :$opts: == *:insert_unique:* && cand_count -eq 1 ]]; then
    ble/complete/insert-common; return "$?"

  elif [[ :$opts: == *:insert_braces:* ]]; then
    ble/complete/insert-braces; return "$?"

  elif [[ :$opts: == *:insert_all:* ]]; then
    ble/complete/insert-all; return "$?"

  elif [[ :$opts: == *:enter_menu:* ]]; then
    local menu_common_part=$COMPV
    ble/complete/menu/show "$menu_show_opts" || return "$?"
    ble/complete/menu-complete/enter "$opts"; local ext=$?
    ((ext==148)) && return 148
    ((ext)) && [[ :$opts: != *:no-bell:* ]] &&
      ble/widget/.bell 'menu-complete: no completions'
    return 0

  elif [[ :$opts: == *:show_menu:* ]]; then
    local menu_common_part=$COMPV
    ble/complete/menu/show "$menu_show_opts"
    return "$?" # exit status of ble/complete/menu/show

  fi

  ble/complete/insert-common; return "$?"
}

function ble/widget/complete-insert {
  local original=$1 insert=$2 suffix=$3
  [[ ${_ble_edit_str::_ble_edit_ind} == *"$original" ]] || return 1

  local insert_beg=$((_ble_edit_ind-${#original}))
  local insert_end=$_ble_edit_ind
  ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

function ble/widget/menu-complete {
  local opts=$1
  ble/widget/complete enter_menu:insert_unique:$opts
}

function ble/widget/complete/.select-menu-with-arg {
  [[ $bleopt_complete_menu_complete && $_ble_complete_menu_active ]] || return 1

  local footprint; ble/complete/menu/get-footprint
  [[ $footprint == "$_ble_complete_menu_footprint" ]] || return 1

  local arg_opts= opts=$1
  [[ :$opts: == *:enter-menu:* ]] && arg_opts=always
  [[ :$opts: == *:nobell:* ]] && arg_opts=$arg_opts:nobell

  # 現在のキーが実際に引数の一部として解釈され得る時のみ menu に入る
  ble/widget/menu/append-arg/.is-argument "$arg_opts" || return 1
  ble/complete/menu-complete/enter
  ble/widget/menu/append-arg "$arg_opts"
  return 0
}

#------------------------------------------------------------------------------
# menu-filter

## @fn ble/complete/menu-filter/.filter-candidates
##   @var[in,out] comp_type
##   @var[out] cand_pack
function ble/complete/menu-filter/.filter-candidates {
  cand_pack=()

  local iloop=0 interval=$bleopt_complete_polling_cycle
  local filter_type pack "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
  for filter_type in head substr hsubseq subseq; do
    ble/path#remove-glob comp_type '[maA]'
    case $filter_type in
    (substr)  comp_type=${comp_type}:m ;;
    (hsubseq) comp_type=${comp_type}:a ;;
    (subseq)  comp_type=${comp_type}:A ;;
    esac

    local comp_filter_type
    local comp_filter_pattern
    ble/complete/candidates/filter#init "$filter_type" "$COMPV"
    for pack in "${_ble_complete_menu0_pack[@]}"; do
      ((iloop++%interval==0)) && ble/complete/check-cancel && return 148
      ble/complete/cand/unpack "$pack"
      ble/complete/candidates/filter#test "$CAND" &&
        ble/array#push cand_pack "$pack"
    done
    ((${#cand_pack[@]}!=0)) && return 0
  done
}
function ble/complete/menu-filter/.get-filter-target {
  if [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]]; then
    ret=$_ble_edit_str
  elif [[ $_ble_decode_keymap == auto_complete ]]; then
    ret=${_ble_edit_str::_ble_edit_ind}${_ble_edit_str:_ble_edit_mark}
  else
    return 1
  fi
}
function ble/complete/menu-filter {
  [[ $_ble_decode_keymap == menu_complete ]] && return 0
  local ret; ble/complete/menu-filter/.get-filter-target || return 1; local str=$ret

  local beg end; ble/complete/menu/get-active-range "$str" "$_ble_edit_ind" || return 1
  local input=${str:beg:end-beg}
  [[ $input == "${_ble_complete_menu_comp[2]}" ]] && return 0

  local simple_flags simple_ibrace
  if ! ble/syntax:bash/simple-word/reconstruct-incomplete-word "$input"; then
    ble/syntax:bash/simple-word/is-never-word "$input" && return 1
    return 0
  fi
  [[ $simple_ibrace ]] && ((${simple_ibrace%%:*}>10#0${_ble_complete_menu0_comp[6]%%:*})) && return 1 # 別のブレース展開要素に入った時
  ble/syntax:bash/simple-word/eval "$ret" single; (($?==148)) && return 148
  local COMPV=$ret

  local comp_type=${_ble_complete_menu0_comp[4]} cand_pack
  ble/complete/menu-filter/.filter-candidates; (($?==148)) && return 148

  local menu_common_part=$COMPV
  ble/complete/menu/show filter || return "$?"
  _ble_complete_menu_comp=("$beg" "$end" "$input" "$COMPV" "$comp_type")
  return 0
}

function ble/complete/menu-filter.idle {
  ble/util/idle.wait-user-input
  [[ $bleopt_complete_menu_filter ]] || return 1
  [[ $_ble_complete_menu_active ]] || return 1
  ble/complete/menu-filter; local ext=$?
  ((ext==148)) && return 148
  ((ext)) && ble/complete/menu/clear
  return 0
}

# ble/highlight/layer:menu_filter

## @fn ble/highlight/layer/buff#operate-gflags name beg end mask gflags
function ble/highlight/layer/buff#operate-gflags {
  local BUFF=$1 beg=$2 end=$3 mask=$4 gflags=$5
  ((beg<end)) || return 1

  if [[ $mask == auto ]]; then
    mask=0
    ((gflags&(_ble_color_gflags_FgIndexed|_ble_color_gflags_FgMask))) &&
      ((mask|=_ble_color_gflags_FgIndexed|_ble_color_gflags_FgMask))
    ((gflags&(_ble_color_gflags_BgIndexed|_ble_color_gflags_BgMask))) &&
      ((mask|=_ble_color_gflags_BgIndexed|_ble_color_gflags_BgMask))
  fi

  local i g ret
  for ((i=beg;i<end;i++)); do
    ble/highlight/layer/update/getg "$i"
    ((g=g&~mask|gflags))
    ble/color/g2sgr "$g"
    builtin eval -- "$BUFF[$i]=\$ret\${_ble_highlight_layer_plain_buff[$i]}"
  done
}
## @fn ble/highlight/layer/buff#set-explicit-sgr name index
function ble/highlight/layer/buff#set-explicit-sgr {
  local BUFF=$1 index=$2
  builtin eval "((index<\${#$BUFF[@]}))" || return 1
  local g; ble/highlight/layer/update/getg "$index"
  local ret; ble/color/g2sgr "$g"
  builtin eval "$BUFF[index]=\$ret\${_ble_highlight_layer_plain_buff[index]}"
}

_ble_highlight_layer_menu_filter_buff=()
_ble_highlight_layer_menu_filter_beg=
_ble_highlight_layer_menu_filter_end=
function ble/highlight/layer:menu_filter/update {
  local text=$1 player=$2

  # shift
  local obeg=$_ble_highlight_layer_menu_filter_beg
  local oend=$_ble_highlight_layer_menu_filter_end
  if [[ $obeg ]] && ((DMIN>=0)); then
    ((DMAX0<=obeg?(obeg+=DMAX-DMAX0):(DMIN<obeg&&(obeg=DMIN)),
      DMAX0<=oend?(oend+=DMAX-DMAX0):(DMIN<oend&&(oend=DMIN))))
  fi
  _ble_highlight_layer_menu_filter_beg=$obeg
  _ble_highlight_layer_menu_filter_end=$oend

  # determine range
  local beg= end= ret
  if [[ $bleopt_complete_menu_filter && $_ble_complete_menu_active && ${#_ble_complete_menu_icons[@]} -gt 0 ]]; then
    ble/complete/menu-filter/.get-filter-target && local str=$ret &&
      ble/complete/menu/get-active-range "$str" "$_ble_edit_ind" &&
      [[ ${str:beg:end-beg} != "${_ble_complete_menu0_comp[2]}" ]] || beg= end=
  fi

  # 変更のない場合スキップ
  [[ ! $obeg && ! $beg ]] && return 0
  ((PREV_UMIN<0)) && [[ $beg == "$obeg" && $end == "$oend" ]] &&
    PREV_BUFF=_ble_highlight_layer_menu_filter_buff && return 0

  local umin=$PREV_UMIN umax=$PREV_UMAX
  if [[ $beg ]]; then
    ble/color/face2g menu_filter_fixed; local gF=$ret
    ble/color/face2g menu_filter_input; local gI=$ret
    local mid=$_ble_complete_menu0_end
    ((mid<beg?(mid=beg):(end<mid&&(mid=end))))

    local buff_name=_ble_highlight_layer_menu_filter_buff
    builtin eval "$buff_name=(\"\${$PREV_BUFF[@]}\")"
    ble/highlight/layer/buff#operate-gflags "$buff_name" "$beg" "$mid" auto "$gF"
    ble/highlight/layer/buff#operate-gflags "$buff_name" "$mid" "$end" auto "$gI"
    ble/highlight/layer/buff#set-explicit-sgr "$buff_name" "$end"
    PREV_BUFF=$buff_name

    if [[ $obeg ]]; then :
      ble/highlight/layer:{selection}/.invalidate "$beg" "$obeg"
      ble/highlight/layer:{selection}/.invalidate "$end" "$oend"
    else
      ble/highlight/layer:{selection}/.invalidate "$beg" "$end"
    fi
  else
    if [[ $obeg ]]; then
      ble/highlight/layer:{selection}/.invalidate "$obeg" "$oend"
    fi
  fi
  _ble_highlight_layer_menu_filter_beg=$beg
  _ble_highlight_layer_menu_filter_end=$end
  ((PREV_UMIN=umin,PREV_UMAX=umax))
}
function ble/highlight/layer:menu_filter/getg {
  local index=$1
  local obeg=$_ble_highlight_layer_menu_filter_beg
  local oend=$_ble_highlight_layer_menu_filter_end
  local mid=$_ble_complete_menu0_end
  if [[ $obeg ]] && ((obeg<=index&&index<oend)); then
    local ret
    if ((index<mid)); then
      ble/color/face2g menu_filter_fixed; local g0=$ret
    else
      ble/color/face2g menu_filter_input; local g0=$ret
    fi
    ble/highlight/layer/update/getg "$index"
    ble/color/g.append "$g0"
  fi
}

_ble_complete_menu_filter_enabled=
if ble/is-function ble/util/idle.push-background; then
  _ble_complete_menu_filter_enabled=1
  ble/util/idle.push -n 9999 ble/complete/menu-filter.idle
  ble/array#insert-before _ble_highlight_layer_list region menu_filter
fi

#------------------------------------------------------------------------------
#
# menu-complete
#

## メニュー補完では以下の変数を参照する
##
##   @var[in] _ble_complete_menu0_beg
##   @var[in] _ble_complete_menu0_end
##   @var[in] _ble_complete_menu_original
##   @var[in] _ble_complete_menu_selected
##   @var[in] _ble_complete_menu_common_part
##   @arr[in] _ble_complete_menu_icons
##
## 更に以下の変数を使用する
##
##   @var[in,out] _ble_complete_menu_original=

_ble_complete_menu_original=

## @fn ble/complete/menu-complete/select index [opts]
function ble/complete/menu-complete/select {
  ble/complete/menu#select "$@"
}

## @fn ble/complete/menu-complete/enter [opts]
##   @var[in,opt] opts
##     backward
##     insert_unique
function ble/complete/menu-complete/enter {
  ((${#_ble_complete_menu_icons[@]}>=1)) || return 1
  local beg end; ble/complete/menu/get-active-range || return 1

  local opts=$1

  _ble_edit_mark=$beg
  _ble_edit_ind=$end
  local comps_fixed=${_ble_complete_menu0_comp[6]}
  if [[ $comps_fixed ]]; then
    local comps_fixed_length=${comps_fixed%%:*}
    ((_ble_edit_mark+=comps_fixed_length))
  fi

  # 一意確定時。menu の処理も含めて menu-complete の枠組みの中で確定を実行する。
  if [[ :$opts: == *:insert_unique:* ]] && ((${#_ble_complete_menu_items[@]}==1)); then
    ble/complete/menu#select 0
    ble/decode/keymap/push menu_complete
    ble/widget/menu_complete/exit complete
    return 0
  fi

  _ble_complete_menu_original=${_ble_edit_str:beg:end-beg}
  ble/complete/menu/redraw

  if [[ :$opts: == *:backward:* ]]; then
    ble/complete/menu#select "$((${#_ble_complete_menu_items[@]}-1))"
  else
    ble/complete/menu#select 0
  fi

  _ble_edit_mark_active=insert
  ble/decode/keymap/push menu_complete
  return 0
}

function ble/widget/menu_complete/exit {
  local opts=$1
  ble/decode/keymap/pop

  if ((_ble_complete_menu_selected>=0)); then
    # 置換情報を再構成
    local new=${_ble_edit_str:_ble_complete_menu0_beg:_ble_edit_ind-_ble_complete_menu0_beg}
    if [[ :$bleopt_complete_menu_complete_opts: != *:insert-selection:* ]]; then
      local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/unpack "${_ble_complete_menu_items[_ble_complete_menu_selected]}"
      new=$INSERT
    fi
    local old=$_ble_complete_menu_original
    local comp_text=${_ble_edit_str::_ble_complete_menu0_beg}$old${_ble_edit_str:_ble_edit_ind}
    local insert_beg=$_ble_complete_menu0_beg
    local insert_end=$((_ble_complete_menu0_beg+${#old}))
    local insert=$new
    local insert_flags=

    # suffix の決定と挿入
    local suffix=
    if [[ :$opts: == *:complete:* ]]; then
      local icon=${_ble_complete_menu_icons[_ble_complete_menu_selected-_ble_complete_menu_offset]}
      local icon_data=${icon#*:} icon_fields
      ble/string#split icon_fields , "${icon%%:*}"
      local pack=${icon_data::icon_fields[4]}

      local ACTION=${pack%%:*}
      if ble/is-function ble/complete/action:"$ACTION"/complete; then
        # 補完文脈の復元
        local COMP1=${_ble_complete_menu0_comp[0]}
        local COMP2=${_ble_complete_menu0_comp[1]}
        local COMPS=${_ble_complete_menu0_comp[2]}
        local COMPV=${_ble_complete_menu0_comp[3]}
        local comp_type=${_ble_complete_menu0_comp[4]}
        local comps_flags=${_ble_complete_menu0_comp[5]}
        local comps_fixed=${_ble_complete_menu0_comp[6]}

        # 補完候補のロード
        local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
        ble/complete/cand/unpack "$pack"

        ble/complete/action:"$ACTION"/complete
      fi
      ble/complete/insert "$_ble_complete_menu0_beg" "$_ble_edit_ind" "$insert" "$suffix"
    fi

    # 通知
    blehook/invoke complete_insert
  fi

  ble/complete/menu/clear
  _ble_edit_mark_active=
  _ble_complete_menu_original=
}
function ble/widget/menu_complete/cancel {
  ble/decode/keymap/pop
  ble/complete/menu#select -1
  _ble_edit_mark_active=
  _ble_complete_menu_original=
}
function ble/widget/menu_complete/accept {
  ble/widget/menu_complete/exit complete
}
function ble/widget/menu_complete/exit-default {
  ble/widget/menu_complete/exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}

function ble-decode/keymap:menu_complete/define {
  # ble-bind -f __defchar__ menu_complete/self-insert
  ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f C-m         'menu_complete/accept'
  ble-bind -f RET         'menu_complete/accept'
  ble-bind -f C-g         'menu_complete/cancel'
  ble-bind -f 'C-x C-g'   'menu_complete/cancel'
  ble-bind -f 'C-M-g'     'menu_complete/cancel'
  ble-bind -f C-f         'menu/forward-column'
  ble-bind -f right       'menu/forward-column'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward-column'
  ble-bind -f left        'menu/backward-column'
  ble-bind -f C-S-i       'menu/backward cyclic'
  ble-bind -f S-TAB       'menu/backward cyclic'
  ble-bind -f C-n         'menu/forward-line'
  ble-bind -f down        'menu/forward-line'
  ble-bind -f C-p         'menu/backward-line'
  ble-bind -f up          'menu/backward-line'
  ble-bind -f prior       'menu/backward-page'
  ble-bind -f next        'menu/forward-page'
  ble-bind -f home        'menu/beginning-of-page'
  ble-bind -f end         'menu/end-of-page'

  local key
  for key in {,M-,C-}{0..9}; do
    ble-bind -f "$key" 'menu/append-arg'
  done
}

_ble_complete_menu_arg=
## @fn ble/widget/menu/append-arg [opts]
##   @param[in,opt] opts
##     A colon-separated list of the options:
##
##     always
##       When a numeric argument is not started, the normal digit is by default
##       treated as normal user input.  This option makes the normal digit
##       always start a numeric argument.
##     nobell
##       Do not ring edit bell when no corresponding item is found.
##
function ble/widget/menu/append-arg {
  [[ ${LASTWIDGET%%' '*} == */append-arg ]] || _ble_complete_menu_arg=

  # 引数入力が開始されていなくて (修飾なしの) 数字キーの時はそのまま通常の数字
  # 入力として扱う。
  local i=${#KEYS[@]}; ((i&&i--))
  local flag=$((KEYS[i]&_ble_decode_MaskFlag))
  if ! [[ :$1: == *:always:* || flag -ne 0 || $_ble_complete_menu_arg ]]; then
    ble/widget/menu_complete/exit-default
    return "$?"
  fi

  local code=$((KEYS[i]&_ble_decode_MaskChar))
  ((48<=code&&code<=57)) || return 1
  local ret; ble/util/c2s "$code"; local ch=$ret
  ((_ble_complete_menu_arg=10#0$_ble_complete_menu_arg$ch))

  # 番号が範囲内になければ頭から数字を削っていく
  local count=${#_ble_complete_menu_items[@]}
  while ((_ble_complete_menu_arg>count)); do
    ((_ble_complete_menu_arg=10#0${_ble_complete_menu_arg:1}))
  done
  if ! ((_ble_complete_menu_arg)); then
    [[ :$1: == *:nobell:* ]] ||
      ble/widget/.bell 'menu: out of range'
    return 0
  fi

  # 移動
  ble/complete/menu#select "$((_ble_complete_menu_arg-1))"
}

## @fn ble/widget/menu/append-arg/.is-argument [opts]
##   @param[in,opt] opts
function ble/widget/menu/append-arg/.is-argument {
  local i=${#KEYS[@]}; ((i&&i--))
  local flag=$((KEYS[i]&_ble_decode_MaskFlag))
  local code=$((KEYS[i]&_ble_decode_MaskChar))
  [[ :$1: == *:always:* ]] || ((flag)) || return 1
  ((48<=code&&code<=57))
}

#------------------------------------------------------------------------------
#
# auto-complete
#

function ble/complete/auto-complete/initialize {
  local ret
  ble-decode-kbd/generate-keycode auto_complete_enter
  _ble_complete_KCODE_ENTER=$ret
}
ble/complete/auto-complete/initialize

function ble/highlight/layer:region/mark:auto_complete/get-face {
  face=auto_complete
}

_ble_complete_ac_type=
_ble_complete_ac_comp1=
_ble_complete_ac_cand=
_ble_complete_ac_word=
_ble_complete_ac_insert=
_ble_complete_ac_suffix=

## @fn ble/complete/auto-complete/enter type comp1 suggest cand word [insert suffix]
##   @param[in] type
##     c ... 接頭辞補完
##     h ... 履歴による接頭辞補完。c と同じ取り扱い
##     m ... 部分文字列補完
##     a ... 曖昧補完(1文字目確定)
##     A ... 曖昧補完
##   @param[in] comp1
##     補完開始点
##   @param[in] suggest
##     提示文字列
##   @param[in] cand
##     元の単語
##   @param[in] word
##     挿入文字列(確定前)
##   @param[in,opt] insert
##     挿入文字列(確定時)。省略時は word と同じと見做されます。
##   @param[in] suffix
##     接尾挿入文字列。省略時は空文字列と見做されます。
##
##   @var[in] _ble_edit_ind
##     提示文字列挿入位置を指定します。
##   @var[out] _ble_edit_mark
##     提示文字列の終端点を返します。
##
function ble/complete/auto-complete/enter {
  local type=$1 COMP1=$2 suggest=$3 cand=$4 word=$5 insert1=${6-$5} suffix=${7-}

  local limit=$((bleopt_line_limit_length))
  if ((limit&&${#_ble_edit_str}+${#suggest}>limit)); then
    # 文字数制限に引っかかる場合には単純に auto-complete は失敗する
    return 1
  fi

  # 提示
  local insert; ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$suggest" nobell
  ((_ble_edit_mark=_ble_edit_ind+${#suggest}))

  _ble_complete_ac_type=$type
  _ble_complete_ac_comp1=$COMP1
  _ble_complete_ac_cand=$cand
  _ble_complete_ac_word=$word
  _ble_complete_ac_insert=$insert1
  _ble_complete_ac_suffix=$suffix

  _ble_edit_mark_active=auto_complete
  ble/decode/keymap/push auto_complete
  ble-decode-key "$_ble_complete_KCODE_ENTER" # dummy key input to record keyboard macros
  return 0
}

## @fn ble/complete/auto-complete/source:history/.search-light text
##   !string もしくは !?string を用いて履歴の検索を行います
##   @param[in] text
##   @var[out] ret
function ble/complete/auto-complete/source:history/.search-light {
  [[ $_ble_history_prefix ]] && return 1

  local text=$1
  [[ ! $text ]] && return 1

  # !string による一致を試みる
  #   string には [$wordbreaks] は含められない。? はOK
  local wordbreaks="<>();&|:$_ble_term_IFS"
  local word= expand
  if [[ $text != [-0-9#?!]* ]]; then
    word=${text%%[$wordbreaks]*}
    command='!'$word ble/util/assign expand 'ble/edit/hist_expanded/.core' &>/dev/null || return 1
    if [[ $expand == "$text"* ]]; then
      ret=$expand
      return 0
    fi
  fi

  # !?string による一致を試みる
  #   string には "?" は含められない
  if [[ $word != "$text" ]]; then
    # ? を含まない最長一致部分
    local fragments; ble/string#split fragments '?' "$text"
    local frag longest_fragments len=0; longest_fragments=('')
    for frag in "${fragments[@]}"; do
      local len1=${#frag}
      ((len1>len&&(len=len1))) && longest_fragments=()
      ((len1==len)) && ble/array#push longest_fragments "$frag"
    done

    for frag in "${longest_fragments[@]}"; do
      command='!?'$frag ble/util/assign expand 'ble/edit/hist_expanded/.core' &>/dev/null || return 1
      [[ $expand == "$text"* ]] || continue
      ret=$expand
      return 0
    done
  fi

  return 1
}

_ble_complete_ac_history_needle=
_ble_complete_ac_history_index=
_ble_complete_ac_history_start=
## @fn ble/complete/auto-complete/source:history/.search-heavy text
##   @var[out] ret
function ble/complete/auto-complete/source:history/.search-heavy {
  local text=$1

  local count; ble/history/get-count -v count
  local start=$((count-1))
  local index=$((count-1))
  local needle=$text

  # 途中からの検索再開
  ((start==_ble_complete_ac_history_start)) &&
    [[ $needle == "$_ble_complete_ac_history_needle"* ]] &&
    index=$_ble_complete_ac_history_index

  local isearch_time=0 isearch_ntask=1
  local isearch_opts=head
  [[ :$comp_type: == *:sync:* ]] || isearch_opts=$isearch_opts:stop_check
  ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
  _ble_complete_ac_history_start=$start
  _ble_complete_ac_history_index=$index
  _ble_complete_ac_history_needle=$needle
  ((ext)) && return "$ext"

  ble/history/get-edited-entry -v ret "$index"
  return 0
}

## @fn ble/complete/auto-complete/source:history/.impl opts
##   @param[in] opts
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/source:history/.impl {
  local opts=$1
  local searcher=.search-heavy
  [[ :$opts: == *:light:*  ]] && searcher=.search-light

  local ret
  ((_ble_edit_ind==${#_ble_edit_str})) || return 1
  ble/complete/auto-complete/source:history/"$searcher" "$_ble_edit_str" || return "$?" # 0, 1 or 148
  local command=$ret
  [[ $command == "$_ble_edit_str" ]] && return 1
  ble/complete/auto-complete/enter h 0 "${command:${#_ble_edit_str}}" '' "$command"
}
function ble/complete/auto-complete/source:history {
  [[ $bleopt_complete_auto_history ]] || return 1
  ble/complete/auto-complete/source:history/.impl light; local ext=$?
  ((ext==0||ext==148)) && return "$ext"

  [[ $_ble_history_prefix || $_ble_history_load_done ]] &&
    ble/complete/auto-complete/source:history/.impl; local ext=$?
  ((ext==0||ext==148)) && return "$ext"
}

## @fn ble/complete/auto-complete/source:syntax
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/source:syntax {
  local sources
  ble/complete/context:syntax/generate-sources "$comp_text" "$comp_index" &&
    ble/complete/context/filter-prefix-sources || return 1

  # ble/complete/candidates/generate 設定
  local bleopt_complete_contract_function_names=
  local bleopt_complete_menu_style=$bleopt_complete_menu_style # source local settings
  ((bleopt_complete_polling_cycle>25)) &&
    local bleopt_complete_polling_cycle=25
  local COMP1 COMP2 COMPS COMPV
  local comps_flags comps_fixed
  local cand_count cand_cand cand_word cand_pack
  local cand_limit_reached=
  ble/complete/candidates/generate; local ext=$?
  [[ $COMPV ]] || return 1
  ((ext)) && return "$ext"

  ((cand_count)) || return 1

  local word=${cand_word[0]} cand=${cand_cand[0]}
  [[ $word == "$COMPS" ]] && return 1

  # addtail 等の修飾
  local insert=$word suffix=
  local ACTION=${cand_pack[0]%%:*}
  if ble/is-function ble/complete/action:"$ACTION"/complete; then
    local "${_ble_complete_cand_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/unpack "${cand_pack[0]}"
    local insert_beg=$COMP1 insert_end=$COMP2 insert_flags=
    ble/complete/action:"$ACTION"/complete
  fi

  local type= suggest=
  if [[ $insert == "$COMPS"* ]]; then
    # 入力候補が既に続きに入力されている時は提示しない
    [[ ${comp_text:COMP1} == "$insert"* ]] && return 1

    type=c
    suggest="${insert:${#COMPS}}"
  else
    case :$comp_type: in
    (*:a:*) type=a ;;
    (*:m:*) type=m ;;
    (*:A:*) type=A ;;
    (*)   type=r ;;
    esac
    suggest=" [$insert] "
  fi
  ble/complete/auto-complete/enter "$type" "$COMP1" "$suggest" "$cand" "$word" "$insert" "$suffix"
}

_ble_complete_auto_source=(history syntax)

## @fn ble/complete/auto-complete.impl opts
##   @param[in] opts
#      コロン区切りのオプションのリストです。
##     sync   ユーザ入力があっても処理を中断しない事を指定します。
function ble/complete/auto-complete.impl {
  local opts=$1
  local comp_type=auto
  [[ :$opts: == *:sync:* ]] && comp_type=${comp_type}:sync

  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  [[ $comp_text ]] || return 0

  # menu-filter 編集領域内部では auto-complete は抑制する
  if local beg end; ble/complete/menu/get-active-range "$_ble_edit_str" "$_ble_edit_ind"; then
    ((_ble_edit_ind<end)) && return 0
  fi

  local source
  for source in "${_ble_complete_auto_source[@]}"; do
    ble/complete/auto-complete/source:"$source"; local ext=$?
    ((ext==0)) && break
    ((ext==148)) && return "$ext"
  done
}

## 背景関数 ble/complete/auto-complete.idle
function ble/complete/auto-complete.idle {
  # ※特に上書きしなければ常に wait-user-input で抜ける。
  ble/util/idle.wait-user-input

  [[ $bleopt_complete_auto_complete ]] || return 1
  [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]] || return 0

  case $_ble_decode_widget_last in
  (ble/widget/self-insert|ble/widget/magic-space|ble/widget/magic-slash) ;;
  (ble/widget/complete|ble/widget/vi_imap/complete)
    [[ :$bleopt_complete_auto_complete_opts: == *:suppress-after-complete:* ]] && return 0 ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_auto_delay だけ経過してから処理
  ble/util/idle.sleep-until "$((_ble_idle_clock_start+bleopt_complete_auto_delay))" checked && return 0

  ble/complete/auto-complete.impl
}

## 背景関数 ble/complete/auto-menu.idle
function ble/complete/auto-menu.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] && return 0
  ((bleopt_complete_auto_menu>0)) || return 1

  case $_ble_decode_widget_last in
  (ble/widget/self-insert|ble/widget/magic-slash) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (ble/widget/auto_complete/self-insert) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_auto_delay だけ経過してから処理
  local until=$((_ble_idle_clock_start+bleopt_complete_auto_menu))
  ble/util/idle.sleep-until "$until" checked && return 0

  ble/widget/complete auto_menu:show_menu:no-empty:no-bell
}

ble/function#try ble/util/idle.push-background ble/complete/auto-complete.idle
ble/function#try ble/util/idle.push-background ble/complete/auto-menu.idle

## @widget auto-complete-enter
##
##   Note:
##     キーボードマクロで自動補完を明示的に起動する時に用いる編集関数です。
##     auto-complete.idle に於いて ble-decode-key を用いて
##     キー auto_complete_enter を発生させ、
##     再生時にはこのキーを通して自動補完が起動されます。
##
function ble/widget/auto-complete-enter {
  ble/complete/auto-complete.impl sync
}
function ble/widget/auto_complete/cancel {
  ble/decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
}
function ble/widget/auto_complete/insert {
  ble/decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark=$_ble_edit_ind

  local comp_text=$_ble_edit_str
  local insert_beg=$_ble_complete_ac_comp1
  local insert_end=$_ble_edit_ind
  local insert=$_ble_complete_ac_insert
  local suffix=$_ble_complete_ac_suffix
  ble/complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
  blehook/invoke complete_insert

  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
  ble/complete/menu/clear
  ble-edit/content/clear-arg
  return 0
}
function ble/widget/auto_complete/cancel-default {
  ble/widget/auto_complete/cancel
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}

## @fn ble/widget/auto_complete/self-insert/.is-magic-space
##   @var[in] KEYS
##   現在のキー入力が親 keymap で magic-space に対応するかどうかを判定します。

function ble/widget/auto_complete/self-insert/.is-magic-space {
  ((${#KEYS[@]}==1)) || return 1

  local ikeymap=$((${#_ble_decode_keymap_stack[@]}-1))
  ((ikeymap>=0)) || return 1

  local dicthead=_ble_decode_${_ble_decode_keymap_stack[ikeymap]}_kmap_
  builtin eval "local ent=\${$dicthead$_ble_decode_key__seq[KEYS[0]]-}"
  local command=${ent#*:}
  [[ $command == ble/widget/magic-space || $command == ble/widget/magic-slash ]]
}

function ble/widget/auto_complete/self-insert {
  if [[ $_ble_edit_overwrite_mode ]] || ble/widget/auto_complete/self-insert/.is-magic-space; then
    ble/widget/auto_complete/cancel-default
    return "$?"
  fi

  local code; ble/widget/self-insert/.get-code
  ((code==0)) && return 0

  local ret

  # もし挿入によって現在の候補が変わらないのであれば、
  # 候補を表示したまま挿入を実行する。
  ble/util/c2s "$code"; local ins=$ret
  local comps_cur=${_ble_edit_str:_ble_complete_ac_comp1:_ble_edit_ind-_ble_complete_ac_comp1}
  local comps_new=$comps_cur$ins
  local processed=
  if [[ $_ble_complete_ac_type == [ch] ]]; then
    # c: 入力済み部分が補完結果の先頭に含まれる場合
    #   挿入した後でも補完結果の先頭に含まれる場合、その文字数だけ確定。
    if [[ $_ble_complete_ac_word == "$comps_new"* ]]; then
      ((_ble_edit_ind+=${#ins}))

      # Note: 途中で完全一致した場合は tail を挿入せずに終了する事にする
      [[ $_ble_complete_ac_word == "$comps_new" ]] && ble/widget/auto_complete/cancel
      processed=1
    fi
  elif [[ $_ble_complete_ac_type == [rmaA] && $ins != [{,}] ]]; then
    if local ret simple_flags simple_ibrace; ble/syntax:bash/simple-word/reconstruct-incomplete-word "$comps_new"; then
      if ble/complete/source/eval-simple-word "$ret" single && local compv_new=$ret; then
        # r: 遡って書き換わる時
        #   挿入しても展開後に一致する時、そのまま挿入。
        #   元から展開後に一致していない場合もあるが、その場合は一旦候補を消してやり直し。
        # a: 曖昧一致の時
        #   文字を挿入後に展開してそれが曖昧一致する時、そのまま挿入。

        local filter_type=head
        case $_ble_complete_ac_type in
        (*m*) filter_type=substr  ;;
        (*a*) filter_type=hsubseq ;;
        (*A*) filter_type=subseq  ;;
        esac

        local comps_fixed=
        local comp_filter_type
        local comp_filter_pattern
        ble/complete/candidates/filter#init "$filter_type" "$compv_new"
        if ble/complete/candidates/filter#test "$_ble_complete_ac_cand"; then
          local insert; ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#insert},_ble_edit_mark+=${#insert}))
          [[ $_ble_complete_ac_cand == "$compv_new" ]] &&
            ble/widget/auto_complete/cancel
          processed=1
        fi
      fi
    fi
  fi

  if [[ $processed ]]; then
    # notify dummy insertion
    local comp_text= insert_beg=0 insert_end=0 insert=$ins suffix=
    blehook/invoke complete_insert
    return 0
  else
    ble/widget/auto_complete/cancel
    ble/decode/widget/skip-lastwidget
    ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
  fi
}

function ble/widget/auto_complete/insert-on-end {
  if ((_ble_edit_mark==${#_ble_edit_str})); then
    ble/widget/auto_complete/insert
  else
    ble/widget/auto_complete/cancel-default
  fi
}
function ble/widget/auto_complete/insert-word {
  local breaks=${bleopt_complete_auto_wordbreaks:-$_ble_term_IFS}
  local rex='^['$breaks']*([^'$breaks']+['$breaks']*)?'
  if [[ $_ble_complete_ac_type == [ch] ]]; then
    local ins=${_ble_edit_str:_ble_edit_ind:_ble_edit_mark-_ble_edit_ind}
    [[ $ins =~ $rex ]]
    if [[ $BASH_REMATCH == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return 0
    else
      local ins=$BASH_REMATCH

      # Note: 以下の様に _ble_edit_ind だけずらす。
      #   <C>he<I>llo world<M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      ((_ble_edit_ind+=${#ins}))

      # 通知
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=${_ble_edit_str:insert_beg:insert_end-insert_beg}$ins
      local suffix=
      blehook/invoke complete_insert
      return 0
    fi
  elif [[ $_ble_complete_ac_type == [rmaA] ]]; then
    local ins=$_ble_complete_ac_insert
    [[ $ins =~ $rex ]]
    if [[ $BASH_REMATCH == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return 0
    else
      local ins=$BASH_REMATCH

      # Note: 以下の様に内容を書き換える。
      #   <C>hll<I> [hello world] <M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      _ble_complete_ac_type=c
      # Note: 内容としては短くなるので replace-limited は使わなくて良い。
      ble-edit/content/replace "$_ble_complete_ac_comp1" "$_ble_edit_mark" "$_ble_complete_ac_insert"
      ((_ble_edit_ind=_ble_complete_ac_comp1+${#ins},
        _ble_edit_mark=_ble_complete_ac_comp1+${#_ble_complete_ac_insert}))

      # 通知
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=$ins
      local suffix=
      blehook/invoke complete_insert

      return 0
    fi
  fi
  return 1
}
function ble/widget/auto_complete/accept-line {
  ble/widget/auto_complete/insert
  ble-decode-key 13
}
function ble/widget/auto_complete/notify-enter {
  ble/decode/widget/skip-lastwidget
}
function ble-decode/keymap:auto_complete/define {
  ble-bind -f __defchar__ auto_complete/self-insert
  ble-bind -f __default__ auto_complete/cancel-default
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       auto_complete/cancel
  ble-bind -f 'C-x C-g'   auto_complete/cancel
  ble-bind -f 'C-M-g'     auto_complete/cancel
  ble-bind -f S-RET       auto_complete/insert
  ble-bind -f S-C-m       auto_complete/insert
  ble-bind -f C-f         auto_complete/insert-on-end
  ble-bind -f right       auto_complete/insert-on-end
  ble-bind -f C-e         auto_complete/insert-on-end
  ble-bind -f end         auto_complete/insert-on-end
  ble-bind -f M-f         auto_complete/insert-word
  ble-bind -f M-right     auto_complete/insert-word
  ble-bind -f C-j         auto_complete/accept-line
  ble-bind -f C-RET       auto_complete/accept-line
  ble-bind -f auto_complete_enter auto_complete/notify-enter
}

#------------------------------------------------------------------------------
#
# sabbrev
#

# The following are variables defined in core-complete-def.sh:
#
# @var _ble_complete_sabbrev_wordwise
# @var _ble_complete_sabbrev_literal

function ble/complete/sabbrev/.initialize-print {
  sgr0= sgr1= sgr2= sgr3= sgro=
  if [[ $flags == *c* || $flags != *n* && -t 1 ]]; then
    local ret
    ble/color/face2sgr command_function; sgr1=$ret
    ble/color/face2sgr syntax_varname; sgr2=$ret
    ble/color/face2sgr syntax_quoted; sgr3=$ret
    ble/color/face2sgr argument_option; sgro=$ret
    sgr0=$_ble_term_sgr0
  fi
}
function ble/complete/sabbrev/.print-definition {
  local key=$1 type=${2%%:*} value=${2#*:}
  local option=
  [[ $type != w ]] && option=$sgro'-'$type$sgr0' '

  local ret
  ble/string#quote-word "$key" quote-empty:sgrq="$sgr3":sgr0="$sgr2"
  key=$sgr2$ret$sgr0
  ble/string#quote-word "$value" sgrq="$sgr3":sgr0="$sgr0"
  value=$ret
  ble/util/print "${sgr1}ble-sabbrev$sgr0 $option$key=$value"
}

## @fn ble/complete/sabbrev/register key value
##   静的略語展開を登録します。
##   @param[in] key value
##
## @fn ble/complete/sabbrev/list type [keys...]
##   登録されている静的略語展開の一覧を表示します。
##   @var[in] flags
##
## @fn ble/complete/sabbrev/reset type [keys...]
##   登録されている静的略語展開を削除します。
##   @var[in] flags
##
## @fn ble/complete/sabbrev/wordwise.get key
##   静的略語展開の展開値を取得します。
##   @param[in] key
##   @var[out] ret
##

# Note: _ble_complete_sabbrev_wordwise は core-complete-def.sh で定義
function ble/complete/sabbrev/register {
  local key=$1 value=$2
  if [[ $value == [il]:* ]]; then
    ble/gdict#set _ble_complete_sabbrev_literal "$key" "$value"
    ble/gdict#unset _ble_complete_sabbrev_wordwise "$key"
  else
    ble/gdict#set _ble_complete_sabbrev_wordwise "$key" "$value"
    ble/gdict#unset _ble_complete_sabbrev_literal "$key"
  fi
}
function ble/complete/sabbrev/list {
  local type=$1; shift
  local keys ret; keys=("$@")
  if ((${#keys[@]}==0)); then
    if [[ $type ]]; then
      # type が指定されている時は、その type の sabbrev だけ表示する
      local dict=_ble_complete_sabbrev_wordwise
      case $type in
      ([wm]) dict=_ble_complete_sabbrev_wordwise ;;
      ([il]) dict=_ble_complete_sabbrev_literal ;;
      esac

      local ret key
      ble/gdict#keys "$dict"
      for key in "${ret[@]}"; do
        ble/gdict#get "$dict" "$key" && [[ $ret == "$type":* ]] || continue
        ble/array#push keys "$key"
      done
    else
      ble/gdict#keys _ble_complete_sabbrev_wordwise
      keys=("${ret[@]}")
      ble/gdict#keys _ble_complete_sabbrev_literal
      ble/array#push keys "${ret[@]}"
    fi
    ((${#keys[@]})) || return 0
  fi

  local sgr0 sgr1 sgr2 sgr3 sgro
  ble/complete/sabbrev/.initialize-print

  local key ext=0
  for key in "${keys[@]}"; do
    if ble/gdict#get _ble_complete_sabbrev_wordwise "$key"; then
      ble/complete/sabbrev/.print-definition "$key" "$ret"
    elif ble/gdict#get _ble_complete_sabbrev_literal "$key"; then
      ble/complete/sabbrev/.print-definition "$key" "$ret"
    else
      ble/util/print "ble-sabbrev: $key: not found." >&2
      ext=1
    fi
  done

  return "$ext"
}
function ble/complete/sabbrev/reset {
  local type=$1; shift
  if (($#)); then
    local key
    for key; do
      ble/gdict#unset _ble_complete_sabbrev_wordwise "$key"
      ble/gdict#unset _ble_complete_sabbrev_literal "$key"
    done
  elif [[ $type ]]; then
    # type が指定されている時は、その type の sabbrev だけ削除する

    local dict=_ble_complete_sabbrev_wordwise
    case $type in
    ([wm]) dict=_ble_complete_sabbrev_wordwise ;;
    ([il]) dict=_ble_complete_sabbrev_literal ;;
    esac

    local ret key
    ble/gdict#keys "$dict"
    for key in "${ret[@]}"; do
      ble/gdict#get "$dict" "$key" && [[ $ret == "$type":* ]] || continue
      ble/gdict#unset "$dict" "$key"
    done
  else
    ble/gdict#clear _ble_complete_sabbrev_wordwise
    ble/gdict#clear _ble_complete_sabbrev_literal
  fi
  return 0
}
function ble/complete/sabbrev/wordwise.get {
  local key=$1
  ble/gdict#get _ble_complete_sabbrev_wordwise "$key"
}
function ble/complete/sabbrev/wordwise.get-keys {
  local ret
  ble/gdict#keys _ble_complete_sabbrev_wordwise
  keys=("${ret[@]}")
}

## @fn ble/complete/sabbrev/literal.find str [opts]
##   最長一致するリテラル略語とその値を取得します。
##   @param[in] str
##   @param[in,opt] opts
##     コロン区切りのオプションです。
##
##     filter-by-patterns
##       patterns 配列に指定されているパターンに一致する sabbrev だけを一致対象
##       とします。
##       @arr[in] patterns
##
##   @var[out] key
##   @var[out] ret
##
function ble/complete/sabbrev/literal.find {
  key=
  local ent= opts=$2 key1 ent1
  ble/gdict#keys _ble_complete_sabbrev_literal
  for key1 in "${ret[@]}"; do
    ((${#key1}>${#key})) || continue

    ble/gdict#get _ble_complete_sabbrev_literal "$key1" || continue; ent1=$ret
    [[ $1 == *"$key1" ]] || continue
    if [[ $ent1 == l:* ]]; then
      ble/string#match "${1%"$key1"}" $'(^|\n)[ \t]*$' || continue
    fi

    [[ :$opts: == *:filter-by-patterns:* ]] &&
      ((${#patterns[@]})) &&
      ! ble/complete/string#match-patterns "$key1" "${patterns[@]}" &&
      continue

    key=$key1 ent=$ent1
  done

  ret=$ent
  [[ $key ]]
}

## @fn ble/complete/sabbrev/read-arguments/.set-type opt
##   @var[in,out] flags type
function ble/complete/sabbrev/read-arguments/.set-type {
  local new_type
  case $1 in
  (--type=wordwise | -w) new_type=w ;;
  (--type=dynamic  | -m) new_type=m ;;
  (--type=inline   | -i) new_type=i ;;
  (--type=linewise | -l) new_type=l ;;
  (*)
    ble/util/print "ble-sabbrev: unknown sabbrev type '${1#--type=}'." >&2
    flags=E$flags
    return  1 ;;
  esac

  if [[ $type && $type != "$new_type" ]]; then
    ble/util/print "ble-sabbrev: arg $1: a conflicting sabbrev type (-$type) has already been specified." >&2
    flags=E$flags
  fi
  type=$new_type
}

## @fn ble/complete/sabbrev/read-arguments args...
##   @arr[out] specs print
##   @var[out] flags type
function ble/complete/sabbrev/read-arguments {
  specs=() print=()
  flags= type=
  while (($#)); do
    local arg=$1; shift
    if [[ $flags != L && $arg == -* ]]; then
      case $arg in
      (--)
        flags=L$flags ;;
      (--help)
        flags=H$flags ;;
      (--reset)
        flags=r$flags
      (--color|--color=always)
        flags=c${flags//[cn]} ;;
      (--color=never)
        flags=n${flags//[cn]} ;;
      (--color=auto)
        flags=${flags//[cn]} ;;
      (--color=*)
        ble/util/print "ble-sabbrev: unknown color type '$arg'." >&2
        flags=E$flags ;;
      (--type=*)
        ble/complete/sabbrev/read-arguments/.set-type "$arg" ;;
      (--type)
        if ((!$#)); then
          ble/util/print "ble-sabbrev: option argument for '$arg' is missing" >&2
          flags=E$flags
        else
          ble/complete/sabbrev/read-arguments/.set-type "--type=$1"; shift
        fi ;;
      (--*)
        ble/util/print "ble-sabbrev: unknown option '$arg'." >&2
        flags=E$flags ;;
      (-*)
        local i n=${#arg} c
        for ((i=1;i<n;i++)); do
          c=${arg:i:1}
          case $c in
          ([wmil]) ble/complete/sabbrev/read-arguments/.set-type "-$c" ;;
          (r) flags=r$flags ;;
          (*)
            ble/util/print "ble-sabbrev: unknown option '-$c'." >&2
            flags=E$flags ;;
          esac
        done ;;
      esac
    else
      if [[ $arg == ?*=* ]]; then
        ble/array#push specs "$arg"
      else
        ble/array#push print "$arg"
      fi
    fi
  done
  return 0
}

## @fn ble-sabbrev key=value
##   静的略語展開を登録します。
function ble-sabbrev {
  local flags type specs print
  ble/complete/sabbrev/read-arguments "$@"
  if [[ $flags == *H* || $flags == *E* ]]; then
    [[ $flags == *E* ]] && ble/util/print
    ble/util/print-lines \
      'usage: ble-sabbrev [--type=TYPE|-wmil] [KEY=VALUE]...' \
      'usage: ble-sabbrev [-r|--reset] [--type=TYPE|-wmil|KEY...]' \
      'usage: ble-sabbrev [--color[=auto|always|never]] [--type=TYPE|-wmil|KEY...]' \
      'usage: ble-sabbrev --help' \
      '     Register sabbrev expansion.' \
      '' \
      'OPTIONS' \
      '  -w, --type=wordwise   replace matching word.' \
      '  -m, --type=dynamic    run command and replace matching word.' \
      '  -i, --type=inline     replace matching suffix.' \
      '  -l, --type=linewise   replace matching line.' \
      '' \
      '  -r, --reset           remove specified set of sabbrev.' \
      '' \
      '  --color=always         enable color output.' \
      '  --color=never          disable color output.' \
      '  --color, --color=auto  automatically determine color output (default).' \
      ''
    [[ ! $flags == *E* ]]; return "$?"
  fi

  local ext=0
  if ((${#specs[@]}==0||${#print[@]})); then
    if [[ $flags == *r* ]]; then
      ble/complete/sabbrev/reset "$type" "${print[@]}"
    else
      ble/complete/sabbrev/list "$type" "${print[@]}"
    fi || ext=$?
  fi

  local spec key value
  for spec in "${specs[@]}"; do
    # spec は key=value の形式
    key=${spec%%=*} value=${spec#*=}
    ble/complete/sabbrev/register "$key" "${type:-w}:$value"
  done
  return "$ext"
}

## @fn ble/complete/sabbrev/locate-key rex_source_type
## @var[out] pos
## @var[in] comp_index comp_text
function ble/complete/sabbrev/locate-key {
  pos=$comp_index
  local rex_source_type='^('$1')$'
  local sources src asrc
  ble/complete/context:syntax/generate-sources
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    [[ ${asrc[0]} =~ $rex_source_type ]] || continue

    if [[ ${asrc[0]} == argument ]]; then
      # source:argument かつ変数代入形式の時は右辺を sabbrev の対象とする。
      # wtype を (恰も declare の引数の様に) ATTR_VAR にして find-rhs を呼び出
      # す。
      local wtype=$_ble_attr_VAR wbeg=${asrc[1]} wlen=$((comp_index-asrc[1])) ret
      ble/syntax:bash/find-rhs "$wtype" "$wbeg" "$wlen" long-option &&
        asrc[0]=rhs asrc[1]=$ret
    fi

    if [[ ${asrc[0]} == rhs ]]; then
      # 変数代入形式の右辺では : で区切った最後のフィールドを対象とする。最後の
      # unquoted colon まで読み飛ばす。[Note: 文法情報の参照をすればより厳密に
      # 決定できるかもしれないが今は実装しない]
      local rex_element
      ble/syntax:bash/simple-word/get-rex_element :
      local rex='^:*('$rex_element':+)'
      [[ ${_ble_edit_str:asrc[1]:comp_index-asrc[1]} =~ $rex ]] &&
        ((asrc[1]+=${#BASH_REMATCH}))
    fi

    ((asrc[1]<pos)) && pos=${asrc[1]}
  done
  ((pos<comp_index))
}

## @fn ble/complete/sabbrev/expand [opts]
##   @param[in,opt] opts
##     コロン区切りのオプションです。
##
##     wordwise
##     literal
##       それぞれ wordwise sabbrev および literal sabbrev (line, inline) の展開
##       を実行します。どちらも指定されていない場合は両方実行します。
##
##     pattern=PATTERN
##       これが一つ以上指定されていた時は何れかの PATTERN で指定された名前を持
##       つ sabbrev だけ有効にします。
##
##     strip-slash
##       展開後の末尾に含まれる / を削除します。
##
##     type-status
##       実行した sabbrev の種類を終了ステータスで返します。
##
function ble/complete/sabbrev/expand {
  local opts=$1
  local comp_index=$_ble_edit_ind comp_text=$_ble_edit_str

  [[ :$opts: == *:wordwise:* || :$opts: == *:literal:* ]] ||
    opts=$opts:wordwise:literal

  local -a patterns=()
  local ret
  ble/opts#extract-all-optargs "$opts" pattern &&
    patterns=("${ret[@]}")

  # wordwise sabbrev と literal sabbrev を両方検索しより長い一致を選択する
  local key1= ent1= key2= ent2=
  if [[ :$opts: == *:wordwise:* ]]; then
    local pos key ret
    ble/complete/sabbrev/locate-key 'file|command|argument|variable:w|wordlist:.*|sabbrev|rhs' &&
      key=${_ble_edit_str:pos:comp_index-pos} &&
      ble/complete/sabbrev/wordwise.get "$key" &&
      { ((${#patterns[@]}==0)) || ble/complete/string#match-patterns "$key" "${patterns[@]}"; } &&
      key1=$key ent1=$ret
  fi
  if [[ :$opts: == *:literal:* ]]; then
    local key ret
    ble/complete/sabbrev/literal.find "${_ble_edit_str::comp_index}" filter-by-patterns &&
      key2=$key ent2=$ret
  fi
  if ((${#key1}>=${#key2})); then
    local key=$key1 ent=$ent1
  else
    local key=$key2 ent=$ent2
  fi
  [[ $key ]] || return 1

  local type=${ent%%:*} value=${ent#*:}

  local exit=0
  if [[ :$opts: == *:type-status:* ]]; then
    local ret
    ble/util/s2c "$type"
    exit=$ret
  fi

  case $type in
  ([wil])
    [[ :$opts: == *:strip-slash:* ]] && value=${value%/}
    local pos=$((comp_index-${#key}))
    ble/widget/.replace-range "$pos" "$comp_index" "$value"
    ((_ble_edit_ind=pos+${#value})) ;;
  (m)
    # prepare completion context
    local comp_type= comps_flags= comps_fixed=
    local COMP1=$pos COMP2=$pos COMPS=$key COMPV=
    ble/complete/candidates/comp_type#read-rl-variables

    local flag_force_fignore=
    local flag_source_filter=1

    # construct cand_pack
    local cand_count cand_cand cand_word cand_pack
    ble/complete/candidates/clear
    local COMP_PREFIX=

    # local settings
    local bleopt_sabbrev_menu_style=$bleopt_complete_menu_style
    local bleopt_sabbrev_menu_opts=

    # generate candidates
    #   COMPREPLY に候補を追加してもらうか、
    #   或いは手動で ble/complete/cand/yield 等を呼び出してもらう。
    local -a COMPREPLY=()
    builtin eval -- "$value"

    local cand action=word "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/yield.initialize "$action"
    for cand in "${COMPREPLY[@]}"; do
      ble/complete/cand/yield "$action" "$cand" ""
    done

    if ((cand_count==0)); then
      return 1
    elif ((cand_count==1)); then
      local value=${cand_word[0]}
      [[ :$opts: == *:strip-slash:* ]] && value=${value%/}
      ble/widget/.replace-range "$pos" "$comp_index" "$value"
      ((_ble_edit_ind=pos+${#value}))
      return "$exit"
    fi

    # Note: 既存の内容 (key) は削除する
    ble/widget/.replace-range "$pos" "$comp_index" ''

    local bleopt_complete_menu_style=$bleopt_sabbrev_menu_style
    local menu_common_part=
    ble/complete/menu/show || return "$?"
    [[ :$bleopt_sabbrev_menu_opts: == *:enter_menu:* ]] &&
      ble/complete/menu-complete/enter "$bleopt_sabbrev_menu_opts"
    return 147 ;;
  (*) return 1 ;;
  esac
  return "$exit"
}
function ble/widget/sabbrev-expand {
  if ! ble/complete/sabbrev/expand; then
    ble/widget/.bell
    return 1
  fi
}

# sabbrev の補完候補
function ble/complete/action:sabbrev/initialize { CAND=$value; }
function ble/complete/action:sabbrev/complete { :; }
function ble/complete/action:sabbrev/init-menu-item {
  local ret; ble/color/face2g command_alias; g=$ret
  show=$INSERT
}
function ble/complete/action:sabbrev/get-desc {
  local ret; ble/complete/sabbrev/wordwise.get "$INSERT"
  desc="$desc_sgrt(sabbrev)$desc_sgr0 $ret"
}
function ble/complete/source:sabbrev {
  local opts=$bleopt_complete_source_sabbrev_opts
  [[ ! $COMPS && :$opts: == *:no-empty-completion:* ]] && return 1

  local keys; ble/complete/sabbrev/wordwise.get-keys "$opts"

  local filter_type=$comp_filter_type
  [[ $filter_type == none ]] && filter_type=head
  local comps_fixed=

  # フィルタリング用設定を COMPS で再初期化
  local comp_filter_type
  local comp_filter_pattern
  ble/complete/candidates/filter#init "$filter_type" "$COMPS"
  local cand action=sabbrev "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize "$action"
  for cand in "${keys[@]}"; do
    ble/complete/candidates/filter#test "$cand" || continue
    ble/complete/string#match-patterns "$cand" "${_ble_complete_source_sabbrev_ignore[@]}" && continue

    # filter で除外されない為に cand には評価後の値を入れる必要がある。
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$cand" &&
      ble/complete/source/eval-simple-word "$ret" single || continue

    local value=$ret # referenced in "ble/complete/action:sabbrev/initialize"
    local flag_source_filter=1
    ble/complete/cand/yield "$action" "$cand"
  done
}

function ble/complete/alias/expand {
  local pos comp_index=$_ble_edit_ind comp_text=$_ble_edit_str
  ble/complete/sabbrev/locate-key 'command'
  ((pos<comp_index)) || return 1

  local word=${_ble_edit_str:pos:comp_index-pos}
  local ret; ble/alias#expand "$word"
  [[ $ret != "$word" ]] || return 1
  ble/widget/.replace-range "$pos" "$comp_index" "$ret"
  return 0
}

#------------------------------------------------------------------------------
#
# dabbrev
#

_ble_complete_dabbrev_original=
_ble_complete_dabbrev_regex1=
_ble_complete_dabbrev_regex2=
_ble_complete_dabbrev_index=
_ble_complete_dabbrev_pos=
_ble_complete_dabbrev_stack=()

function ble/complete/dabbrev/.show-status.fib {
  local index='!'$((_ble_complete_dabbrev_index+1))
  local nmatch=${#_ble_complete_dabbrev_stack[@]}
  local needle=$_ble_complete_dabbrev_original
  local text="(dabbrev#$nmatch: << $index) \`$needle'"

  local pos=$1
  if [[ $pos ]]; then
    local count; ble/history/get-count
    local percentage=$((count?pos*1000/count:1000))
    text="$text searching... @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  ((fib_ntask)) && text="$text *$fib_ntask"

  ble/edit/info/show text "$text"
}
function ble/complete/dabbrev/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble/complete/dabbrev/.show-status.fib
}
function ble/complete/dabbrev/erase-status {
  ble/edit/info/default
}

## @fn ble/complete/dabbrev/initialize-variables
function ble/complete/dabbrev/initialize-variables {
  # Note: _ble_term_IFS を前置しているので ! や ^ が先頭に来ない事は保証される
  local wordbreaks; ble/complete/get-wordbreaks
  _ble_complete_dabbrev_wordbreaks=$wordbreaks

  local left=${_ble_edit_str::_ble_edit_ind}
  local original=${left##*[$wordbreaks]}
  local p1=$((_ble_edit_ind-${#original})) p2=$_ble_edit_ind
  _ble_edit_mark=$p1
  _ble_edit_ind=$p2
  _ble_complete_dabbrev_original=$original

  local ret; ble/string#escape-for-extended-regex "$original"
  local needle='(^|['$wordbreaks'])'$ret
  _ble_complete_dabbrev_regex1=$needle
  _ble_complete_dabbrev_regex2='('$needle'[^'$wordbreaks']*).*'

  local index; ble/history/get-index
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=${#_ble_edit_str}

  _ble_complete_dabbrev_stack=()
}

function ble/complete/dabbrev/reset {
  local original=$_ble_complete_dabbrev_original
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" "$original"
  ((_ble_edit_ind=_ble_edit_mark+${#original}))
  _ble_edit_mark_active=
}

## @fn ble/complete/dabbrev/search-in-history-entry line index
##   @param[in] line
##     検索対象の内容を指定します。
##   @param[in] index
##     検索対象の履歴番号を指定します。
##   @var[in] dabbrev_current_match
##     現在の一致内容を指定します。
##   @var[in] dabbrev_pos
##     履歴項目内の検索開始位置を指定します。
##   @var[out] dabbrev_match
##     一致した場合に、一致した内容を返します。
##   @var[out] dabbrev_match_pos
##     一致した場合に、一致範囲の最後の位置を返します。
##     これは次の検索開始位置に対応します。
function ble/complete/dabbrev/search-in-history-entry {
  local line=$1 index=$2

  # 現在編集している行自身には一致させない。
  local index_editing; ble/history/get-index -v index_editing
  if ((index!=index_editing)); then
    local pos=$dabbrev_pos
    while [[ ${line:pos} && ${line:pos} =~ $_ble_complete_dabbrev_regex2 ]]; do
      local rematch1=${BASH_REMATCH[1]} rematch2=${BASH_REMATCH[2]}
      local match=${rematch1:${#rematch2}}
      if [[ $match && $match != "$dabbrev_current_match" ]]; then
        dabbrev_match=$match
        dabbrev_match_pos=$((${#line}-${#BASH_REMATCH}+${#match}))
        return 0
      else
        ((pos++))
      fi
    done
  fi

  return 1
}

function ble/complete/dabbrev/.search.fib {
  if [[ ! $fib_suspend ]]; then
    local start=$_ble_complete_dabbrev_index
    local index=$_ble_complete_dabbrev_index
    local pos=$_ble_complete_dabbrev_pos

    # Note: start は最初に backward-history-search が呼ばれる時の index。
    #   backward-history-search が呼び出される前に index-- されるので、
    #   start は最初から 1 減らして定義しておく。
    #   これにより cyclic 検索で再度自分に一致する事が保証される。
    # Note: start がこれで負になった時は "履歴項目の数" を設定する。
    #   未だ "履歴" に登録されていない最新の項目 (_ble_history_edit
    #   には格納されている) も検索の対象とするため。
    ((--start>=0)) || ble/history/get-count -v start
  else
    local start index pos; builtin eval -- "$fib_suspend"
    fib_suspend=
  fi

  local dabbrev_match=
  local dabbrev_pos=$pos
  local dabbrev_current_match=${_ble_edit_str:_ble_edit_mark:_ble_edit_ind-_ble_edit_mark}

  local line; ble/history/get-edited-entry -v line "$index"
  if ! ble/complete/dabbrev/search-in-history-entry "$line" "$index"; then
    ((index--,dabbrev_pos=0))

    local isearch_time=0
    local isearch_opts=stop_check:cyclic

    # 条件による一致判定の設定
    isearch_opts=$isearch_opts:condition
    local dabbrev_original=$_ble_complete_dabbrev_original
    local dabbrev_regex1=$_ble_complete_dabbrev_regex1
    local needle='[[ $LINE =~ $dabbrev_regex1 ]] && ble/complete/dabbrev/search-in-history-entry "$LINE" "$INDEX"'
    # Note: glob で先に枝刈りした方が速い。
    [[ $dabbrev_original ]] && needle='[[ $LINE == *"$dabbrev_original"* ]] && '$needle

    # 検索進捗の表示
    isearch_opts=$isearch_opts:progress
    local isearch_progress_callback=ble/complete/dabbrev/.show-status.fib

    ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
    ((ext==148)) && fib_suspend="start=$start index=$index pos=$pos"
    if ((ext)); then
      if ((${#_ble_complete_dabbrev_stack[@]})); then
        ble/widget/.bell # 周回したので鳴らす
        return 0
      else
        # 一つも見つからない場合
        return "$ext"
      fi
    fi
  fi

  local rec=$_ble_complete_dabbrev_index,$_ble_complete_dabbrev_pos,$_ble_edit_ind,$_ble_edit_mark
  ble/array#push _ble_complete_dabbrev_stack "$rec:$_ble_edit_str"
  local insert; ble-edit/content/replace-limited "$_ble_edit_mark" "$_ble_edit_ind" "$dabbrev_match"
  ((_ble_edit_ind=_ble_edit_mark+${#insert}))

  ((index>_ble_complete_dabbrev_index)) &&
    ble/widget/.bell # 周回
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=$dabbrev_match_pos

  ble/textarea#redraw
}
function ble/complete/dabbrev/next.fib {
  ble/complete/dabbrev/.search.fib; local ext=$?
  if ((ext==0)); then
    _ble_edit_mark_active=insert
    ble/complete/dabbrev/.show-status.fib
  elif ((ext==148)); then
    ble/complete/dabbrev/.show-status.fib
  else
    ble/widget/.bell
    ble/widget/dabbrev/exit
    ble/complete/dabbrev/reset
    fib_kill=1
  fi
  return "$ext"
}
function ble/widget/dabbrev-expand {
  ble/complete/dabbrev/initialize-variables
  ble/decode/keymap/push dabbrev
  ble/util/fiberchain#initialize ble/complete/dabbrev
  ble/util/fiberchain#push next
  ble/util/fiberchain#resume
}
function ble/widget/dabbrev/next {
  ble/util/fiberchain#push next
  ble/util/fiberchain#resume
}
function ble/widget/dabbrev/prev {
  if ((${#_ble_util_fiberchain[@]})); then
    # 処理中の物がある時はひとつずつ取り消す
    local ret; ble/array#pop _ble_util_fiberchain
    if ((${#_ble_util_fiberchain[@]})); then
      ble/util/fiberchain#resume
    else
      ble/complete/dabbrev/show-status
    fi
  elif ((${#_ble_complete_dabbrev_stack[@]})); then
    # 前の一致がある時は遡る
    local ret; ble/array#pop _ble_complete_dabbrev_stack
    local rec str=${ret#*:}
    ble/string#split rec , "${ret%%:*}"
    ble-edit/content/reset-and-check-dirty "$str"
    _ble_edit_ind=${rec[2]}
    _ble_edit_mark=${rec[3]}
    _ble_complete_dabbrev_index=${rec[0]}
    _ble_complete_dabbrev_pos=${rec[1]}
    ble/complete/dabbrev/show-status
  else
    ble/widget/.bell
    return 1
  fi
}
function ble/widget/dabbrev/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble/complete/dabbrev/show-status
  else
    ble/widget/dabbrev/exit
    ble/complete/dabbrev/reset
  fi
}
function ble/widget/dabbrev/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
  ble/complete/dabbrev/erase-status
}
function ble/widget/dabbrev/exit-default {
  ble/widget/dabbrev/exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}
function ble/widget/dabbrev/accept-line {
  ble/widget/dabbrev/exit
  ble-decode-key 13
}
function ble-decode/keymap:dabbrev/define {
  ble-bind -f __default__ 'dabbrev/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'dabbrev/cancel'
  ble-bind -f 'C-x C-g'   'dabbrev/cancel'
  ble-bind -f 'C-M-g'     'dabbrev/cancel'
  ble-bind -f C-r         'dabbrev/next'
  ble-bind -f C-s         'dabbrev/prev'
  ble-bind -f RET         'dabbrev/exit'
  ble-bind -f C-m         'dabbrev/exit'
  ble-bind -f C-RET       'dabbrev/accept-line'
  ble-bind -f C-j         'dabbrev/accept-line'
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

## @fn ble/cmdinfo/complete/yield-flag cmd flags [opts]
##   "-${flags}X" の X を補完する。
##   @param[in] cmd
##     mandb 検索に用いるコマンド名
##   @param[in] flags
##     可能なオプション文字の一覧
##   @param[in,opt] opts
##     コロン区切りのリスト
##
##     dedup[=XFLAGS]
##       既に指定されている排他的フラグは除外します。XFLAGS には排他的フラグの
##       集合を指定します。省略または空文字列を指定した場合は全てのフラグが排他
##       的であると見なします。
##
##     cancel-on-empty
##       候補のフラグがもうない場合に補完候補生成をキャンセルします。既定では、
##       候補のフラグがもうない場合には現在入力済みの内容で補完確定します。
##
##     hasarg=AFLAGS
##       オプション引数を持つフラグの集合を指定します。この文字集合に含まれる文
##       字が既に COMPV に指定されている場合にはオプションは補完しません。
##
##   @var[in] COMPV

ble/complete/action#inherit-from mandb.flag mandb
function ble/complete/action:mandb.flag/initialize {
  ble/complete/action:mandb/initialize "$@"
}
function ble/complete/action:mandb.flag/init-menu-item {
  ble/complete/action:mandb/init-menu-item
  prefix=${CAND::!!PREFIX_LEN}
}

function ble/cmdinfo/complete/yield-flag {
  local cmd=$1 flags=$2 opts=$3
  [[ $COMPV != [!-]* && $COMPV != --* && $flags ]] || return 1

  local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
  ble/complete/cand/yield.initialize mandb

  # opts dedup
  local ret
  if [[ ${COMPV:1} ]] && ble/opts#extract-last-optarg "$opts" dedup "$flags"; then
    local specified_flags=${ret//[!"${COMPV:1}"]}
    flags=${flags//["$specified_flags"]}
  fi

  if ble/opts#extract-last-optarg "$opts" hasarg; then
    [[ $COMPV == -*["$ret"]* ]] && return 1
  fi

  if [[ ! $flags ]]; then
    [[ :$opts: == *:cancel-on-empty:* ]] && return 1

    # 候補のフラグがもうない場合は現在の内容で一意確定
    local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
    ble/complete/cand/yield.initialize word
    ble/complete/cand/yield word "$COMPV"
    return "$?"
  fi

  local COMP_PREFIX=$COMPV

  # desc が mandb に見つかればそれを適用する
  local has_desc=
  if local ret; ble/complete/mandb/load-cache "$cmd"; then
    local entry fs=$_ble_term_FS
    for entry in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      local option=${entry%%$fs*}
      [[ $option == -? && ${option:1} == ["$flags"] ]] || continue
      ble/complete/cand/yield mandb.flag "$COMPV${option:1}" "$entry"
      [[ $entry == *"$fs"*"$fs"*"$fs"?* ]] && has_desc=1
      flags=${flags//${option:1}}
    done
    [[ $has_desc ]] && bleopt complete_menu_style=desc
  fi

  # 見つからない場合には説明なしで生成する
  local i
  for ((i=0;i<${#flags};i++)); do
    ble/complete/cand/yield mandb.flag "$COMPV${flags:i:1}"
  done
}


# action:cdpath (action:file を修正)

function ble/complete/action:cdpath/initialize {
  DATA=$cdpath_basedir
  ble/complete/action:file/initialize
}
function ble/complete/action:cdpath/complete {
  CAND=$DATA$CAND ble/complete/action:file/complete
}
function ble/complete/action:cdpath/init-menu-item {
  ble/color/face2g cmdinfo_cd_cdpath; g=$ret
  if [[ :$comp_type: == *:vstat:* ]]; then
    if [[ -h $CAND ]]; then
      suffix='@'
    elif [[ -d $CAND ]]; then
      suffix='/'
    fi
  fi
}
function ble/complete/action:cdpath/get-desc {
  local sgr0=$_ble_term_sgr0 sgr1= sgr2=
  local g ret g1 g2
  ble/syntax/highlight/getg-from-filename "$DATA$CAND"; g1=$g
  [[ $g1 ]] || { ble/color/face2g filename_warning; g1=$ret; }
  ((g2=g1^_ble_color_gflags_Revert))
  ble/color/g2sgr "$g1"; sgr1=$ret
  ble/color/g2sgr "$g2"; sgr2=$ret
  ble/string#escape-for-display "$DATA$CAND" sgr1="$sgr2":sgr0="$sgr1"
  local filename=$sgr1$ret$sgr0

  CAND=$DATA$CAND ble/complete/action:file/get-desc
  desc="CDPATH $filename ($desc)"
}

## @fn ble/cmdinfo/complete:cd/.impl
##   @remarks
##     この実装は ble/complete/source:file/.impl を元にしている。
##     実装に関する注意点はこの元の実装も参照の事。
function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

  case $type in
  (pushd|popd|dirs)
    # todo: -- より後の [-+]* は処理しない
    # todo: 実は -N/+N はオプションではなく通常引数
    if [[ $COMPV == [-+]* ]]; then
      local old_cand_count=$cand_count

      # yield options
      local flags=n
      [[ $type == dirs ]] && flags=clpv
      ble/cmdinfo/complete/yield-flag "$type" "$flags" dedup:hasarg=0123456789:cancel-on-empty

      local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/yield.initialize word
      local ret
      ble/color/face2sgr-ansi filename_directory
      local sgr1=$ret sgr0=$'\e[m'

      # yield -N/+N
      local i n=${#DIRSTACK[@]}
      for ((i=0;i<n;i++)); do
        local cand=${COMPV::1}$i
        [[ $cand == "$COMPV"* ]] || continue
        local j=$i; [[ $COMPV == -* ]] && j=$((n-1-i))
        ble/complete/cand/yield word "$cand" "DIRSTACK[$j] $sgr1${DIRSTACK[j]}$sgr0"
      done

      # yield - and -- for pushd
      if [[ $type == pushd ]]; then
        [[ ${OLDPWD:-} && $COMPV == - ]] &&
          ble/complete/cand/yield word - "OLDPWD $sgr1$OLDPWD$sgr0"
        [[ -- == "$COMPV"* ]] &&
          ble/complete/cand/yield word -- '(indicate the end of options)'
      fi

      ((cand_count!=old_cand_count)) && return 0
    fi
    [[ $type == pushd ]] || return 0 ;;
  (*)
    # todo: -- より後の [-+]* は処理しない
    if [[ $COMPV == -* ]]; then
      local list=LP
      ((_ble_bash>=40200)) && list=${list}e
      ((_ble_bash>=40300)) && list=${list}@
      ble/cmdinfo/complete/yield-flag cd "$list" dedup

      local "${_ble_complete_yield_varnames[@]/%/=}" # WA #D1570 checked
      ble/complete/cand/yield.initialize word
      if [[ ${OLDPWD:-} && $COMPV == - ]]; then
        local ret
        ble/color/face2sgr-ansi filename_directory
        local sgr1=$ret sgr0=$'\e[m'
        ble/complete/cand/yield word - "OLDPWD $sgr1$OLDPWD$sgr0"
      fi
      [[ -- == "$COMPV"* ]] &&
        ble/complete/cand/yield word -- '(indicate the end of options)'

      return 0
    fi
  esac

  [[ :$comp_type: != *:[maA]:* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  [[ :$comp_type: == *:[maA]:* && ! $COMPV ]] && return 1

  if [[ ! $CDPATH ]]; then
    ble/complete/source:dir
    return "$?"
  fi

  ble/complete/source:tilde; local ext=$?
  ((ext==148||ext==0)) && return "$ext"

  local is_pwd_visited= is_cdpath_generated=
  "${_ble_util_set_declare[@]//NAME/visited}" # WA #D1570 checked

  # Check CDPATH first
  local name names; ble/string#split names : "$CDPATH"
  for name in "${names[@]}"; do
    [[ $name ]] || continue
    name=${name%/}/

    # カレントディレクトリが CDPATH に含まれている時は action=file で登録
    local action=cdpath
    [[ ${name%/} == . || ${name%/} == "${PWD%/}" ]] &&
      is_pwd_visited=1 action=file

    local -a candidates=()
    local ret cand
    ble/complete/source:file/.construct-pathname-pattern "$COMPV"
    ble/complete/util/eval-pathname-expansion "$name$ret"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      [[ $cand && -d $cand ]] || continue
      [[ $cand == / ]] || cand=${cand%/}
      cand=${cand#"$name"}

      ble/set#contains visited "$cand" && continue
      ble/set#add visited "$cand"
      ble/array#push candidates "$cand"
    done
    ((${#candidates[@]})) || continue

    local flag_source_filter=1
    local cdpath_basedir=$name
    ble/complete/cand/yield-filenames "$action" "${candidates[@]}"
    [[ $action == cdpath ]] && is_cdpath_generated=1
  done
  [[ $is_cdpath_generated ]] &&
      bleopt complete_menu_style=desc

  # Check PWD next
  # カレントディレクトリが CDPATH に含まれていなかった時に限り通常の候補生成
  if [[ ! $is_pwd_visited ]]; then
    local -a candidates=()
    local ret cand
    ble/complete/source:file/.construct-pathname-pattern "$COMPV"
    ble/complete/util/eval-pathname-expansion "${ret%/}/"; (($?==148)) && return 148
    ble/complete/source/test-limit "${#ret[@]}" || return 1
    for cand in "${ret[@]}"; do
      ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
        ble/complete/check-cancel && return 148
      [[ -d $cand ]] || continue
      [[ $cand == / ]] || cand=${cand%/}
      ble/set#contains visited "$cand" && continue
      ble/array#push candidates "$cand"
    done
    local flag_source_filter=1
    ble/complete/cand/yield-filenames file "${candidates[@]}"
  fi
}
function ble/cmdinfo/complete:cd {
  ble/cmdinfo/complete:cd/.impl cd
}
function ble/cmdinfo/complete:pushd {
  ble/cmdinfo/complete:cd/.impl pushd
}
function ble/cmdinfo/complete:popd {
  ble/cmdinfo/complete:cd/.impl popd
}
function ble/cmdinfo/complete:dirs {
  ble/cmdinfo/complete:cd/.impl dirs
}

blehook/invoke complete_load
blehook complete_load=
return 0
