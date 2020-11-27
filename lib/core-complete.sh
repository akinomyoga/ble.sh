#!/bin/bash

ble/util/import "$_ble_base/lib/core-syntax.sh"

## 関数 ble/complete/string#search-longest-suffix-in needle haystack
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
## 関数 ble/complete/string#common-suffix-prefix lhs rhs
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

## 関数 ble/complete/get-wordbreaks
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

_ble_complete_menu_items=()
_ble_complete_menu_class=
_ble_complete_menu_param=
_ble_complete_menu_version=
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

## 関数 ble/complete/menu-style:$menu_style/construct
##   候補一覧メニューの表示・配置を計算します。
##
##   @var[out] x y esc
##   @var[in] menu_style
##   @arr[in] menu_items
##   @var[in] menu_class menu_param
##   @var[in] cols lines
##

_ble_complete_menu_style_measure=()
_ble_complete_menu_style_icons=()
_ble_complete_menu_style_pages=()

#
# ble/complete/menu-style:align
#

## 関数 ble/complete/menu#render-item item opts
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

## 関数 ble/complete/menu-style:align/construct/.measure-candidates-in-page
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
  local max_wcell=$bleopt_complete_menu_align; ((max_wcell>cols&&(max_wcell=cols)))
  wcell=2
  local ncell=0 index=$begin
  local item ret esc1 w
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148
    local wcell_old=$wcell

    # 候補の表示幅 w を計算
    local w=${_ble_complete_menu_style_measure[index]%%:*}
    if [[ ! $w ]]; then
      local x=0 y=0
      ble/complete/menu#render-item "$item"; esc1=$ret
      local w=$((y*cols+x))
      _ble_complete_menu_style_measure[index]=$w:${#item}:$item$esc1
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
      local ncell_eol=$(((ncell+line_ncell-1)/line_ncell*line_ncell))
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

## 関数 ble/complete/menu-style:align/construct-page
##   @var[in,out] begin end x y esc
##   @arr[out] _ble_complete_menu_style_icons
##
##   @var[in,out] cols lines menu_iloop
function ble/complete/menu-style:align/construct-page {
  x=0 y=0 esc=

  local wcell=2
  ble/complete/menu-style:align/construct/.measure-candidates-in-page
  (($?==148)) && return 148

  local ncell=$((cols/wcell))
  local index=$begin entry
  for entry in "${_ble_complete_menu_style_measure[@]:begin:end-begin}"; do
    ble/complete/menu#check-cancel && return 148

    local w=${entry%%:*}; entry=${entry#*:}
    local s=${entry%%:*}; entry=${entry#*:}
    local item=${entry::s} esc1=${entry:s}

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
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) || # [Note: 少なくとも1個ははみ出ても表示する]
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$esc1

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

## 関数 ble/complete/menu-style:dense/construct-page
##   @var[in,out] begin end x y esc
function ble/complete/menu-style:dense/construct-page {
  x=0 y=0 esc=
  local item index=$begin N=${#menu_items[@]}
  for item in "${menu_items[@]:begin}"; do
    ble/complete/menu#check-cancel && return 148

    local x0=$x y0=$y esc1
    ble/complete/menu#render-item "$item" ||
      ((index==begin)) ||
      { x=$x0 y=$y0; break; }; esc1=$ret

    if [[ $menu_style == dense-nowrap ]]; then
      if ((y>y0&&x>0||y>y0+1)); then
        ((++y0>=lines)) && break
        esc=$esc$'\n'
        ((y=y0,x=x0=0))
        ble/complete/menu#render-item "$item" ||
          ((begin==index)) ||
          { x=$x0 y=$y0; break; }; esc1=$ret
      fi
    fi

    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#item},${#esc1}:$item$esc1
    esc=$esc$esc1

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
## 関数 ble/complete/menu-style:dense/construct opts
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble/complete/menu-style:dense-nowrap/construct-page {
  ble/complete/menu-style:dense/construct-page "$@"
}

#
# ble/complete/menu-style:linewise
#

## 関数 ble/complete/menu-style:linewise/construct-page opts
##   @var[in,out] begin end x y esc
function ble/complete/menu-style:linewise/construct-page {
  local opts=$1 ret
  local max_icon_width=$((cols-1))

  local prefix_format=$bleopt_menu_linewise_prefix prefix_width=0
  if [[ $prefix_format ]]; then
    local prefix1
    ble/util/sprintf prefix1 "$prefix_format" ${#menu_items[@]}
    local x1 y1 x2 y2
    LINES=1 COLUMNS=$max_icon_width x=0 y=0 ble/canvas/trace "$prefix1" truncate:measure-bbox
    if ((x2<=max_icon_width/2)); then
      prefix_width=$x2
      ble/string#reserve-prototype "$prefix_width"
    fi
  fi

  local item x0 y0 esc1 index=$begin
  end=$begin x=0 y=0 esc=
  for item in "${menu_items[@]:begin:lines}"; do
    ble/complete/menu#check-cancel && return 148

    # prefix
    if ((prefix_width)); then
      local prefix1; ble/util/sprintf prefix1 "$prefix_format" $((index+1))
      LINES=1 COLUMNS=$max_icon_width y=0 ble/canvas/trace "$prefix1" truncate:relative:measure-bbox; esc1=$ret
      if ((x<prefix_width)); then
        x=$prefix_width
        esc=$esc${_ble_string_prototype::prefix_width-x}$esc1
      else
        esc=$esc$esc1
      fi
    fi

    ((x0=x,y0=y))
    lines=1 cols=$max_icon_width y=0 ble/complete/menu#render-item "$item"; esc1=$ret
    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#item},${#esc1}:$item$esc1
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

## 関数 ble/complete/menu-style:desc/construct-page opts
##   @var[in,out] begin end x y esc
function ble/complete/menu-style:desc/construct-page {
  local opts=$1 ret
  local opt_raw=; [[ $menu_style == desc-raw ]] && opt_raw=1

  # 各候補を描画して幅を計算する
  local measure; measure=()
  local max_cand_width=$(((cols+1)/2))
  ((max_cand_width<10&&(max_cand_width=cols)))
  local pack w esc1 max_width=0
  for pack in "${menu_items[@]:begin:lines}"; do
    ble/complete/menu#check-cancel && return 148

    x=0 y=0
    lines=1 cols=$max_cand_width ble/complete/menu#render-item "$pack"; esc1=$ret
    ((w=y*cols+x,w>max_width&&(max_width=w)))

    ble/array#push measure "$w:${#pack}:$pack$esc1"
  done

  local cand_width=$max_width
  local desc_x=$((cand_width+1)); ((desc_x>cols&&(desc_x=cols)))
  local desc_prefix=; ((cols-desc_x>30)) && desc_prefix='| '

  end=$begin x=0 y=0 esc=
  local entry w s pack esc1 x0 y0 pad index=$begin
  for entry in "${measure[@]}"; do
    ble/complete/menu#check-cancel && return 148

    w=${entry%%:*} entry=${entry#*:}
    s=${entry%%:*} entry=${entry#*:}
    pack=${entry::s} esc1=${entry:s}

    # 候補表示
    ((x0=x,y0=y,x+=w))
    _ble_complete_menu_style_icons[index]=$x0,$y0,$x,$y,${#pack},${#esc1}:$pack$esc1
    ((index++))
    esc=$esc$esc1

    # 余白
    ble/string#reserve-prototype $((pad=desc_x-x))
    esc=$esc${_ble_string_prototype::pad}$desc_prefix
    ((x+=pad+${#desc_prefix}))

    # 説明表示
    local desc='(no description)'
    ble/function#try "$menu_class"/get-desc "$pack"
    if [[ $opt_raw ]]; then
      y=0 g=0 lc=0 lg=0 LINES=1 COLUMNS=$cols ble/canvas/trace "$desc" truncate:relative:ellipsis
    else
      y=0 lines=1 ble/canvas/trace-text "$desc" nonewline
    fi
    esc=$esc$ret
    ((y+1>=lines)) && break
    ((x=0,++y))
    esc=$esc$'\n'
  done
  end=$index
}
function ble/complete/menu-style:desc/guess {
  ((ipage=scroll/lines,
    begin=ipage*lines,
    end=begin))
}
function ble/complete/menu-style:desc-raw/construct-page {
  ble/complete/menu-style:desc/construct-page "$@"
}
function ble/complete/menu-style:desc-raw/guess {
  ble/complete/menu-style:desc/guess
}

## 関数 ble/complete/menu#construct/.initialize-size
##   @var[out] cols lines
function ble/complete/menu#construct/.initialize-size {
  ble-edit/info/.initialize-size
  local maxlines=$((bleopt_complete_menu_maxlines))
  ((maxlines>0&&lines>maxlines)) && lines=$maxlines
}
## 関数 ble/complete/menu#construct menu_opts
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
  if ((${#menu_items[@]}==0)); then
    _ble_complete_menu_version=$version
    _ble_complete_menu_items=()
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
    ((${#menu_items[@]}&&(scroll%=nitem)))
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
  _ble_complete_menu_ipage=$ipage
  _ble_complete_menu_offset=$begin
  _ble_complete_menu_icons=("${_ble_complete_menu_style_icons[@]:begin:end-begin}")
  _ble_complete_menu_info_data=(store "$x" "$y" "$esc")
  _ble_complete_menu_selected=-1
  return 0
}

function ble/complete/menu#show {
  ble-edit/info/immediate-show "${_ble_complete_menu_info_data[@]}"
}
function ble/complete/menu#clear {
  ble-edit/info/clear
}


## 関数 ble/complete/menu#select index [opts]
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
  local x0=$_ble_canvas_x y0=$_ble_canvas_y
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
    local ret cols lines
    ble/complete/menu#construct/.initialize-size
    ble/complete/menu#render-item "$item" selected

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
  ble/canvas/goto.draw "$x0" "$y0"
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

_ble_complete_menu_lastcolumn=
## 関数 ble/widget/menu/.check-last-column
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
## 関数 ble/widget/menu/.goto-column column
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

  local ncand=${#_ble_complete_menu_items[@]}
  if ((0<=nsel&&nsel<ncand)); then
    ble/complete/menu#select "$nsel"
    ((is_next_page)) &&
      ble/widget/menu/.goto-column "$ox"
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-line {
  local offset=$_ble_complete_menu_offset
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return 1
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

  if ((nsel>=0)); then
    ble/complete/menu#select "$nsel"
    ((nsel<offset)) &&
      ble/widget/menu/.goto-column "$ox"
  else
    ble/widget/.bell 'menu: no more candidates'
    return 1
  fi
}
function ble/widget/menu/backward-page {
  if ((_ble_complete_menu_offset>0)); then
    ble/complete/menu#select $((_ble_complete_menu_offset-1)) goto-page-top
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
  ((nicon)) && ble/complete/menu#select $((_ble_complete_menu_offset+nicon-1))
}

function ble/widget/menu/cancel {
  ble-decode/keymap/pop
  ble/complete/menu#clear
  "$_ble_complete_menu_class"/oncancel
}
function ble/widget/menu/accept {
  ble-decode/keymap/pop
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
  ble-bind -f C-f         'menu/forward'
  ble-bind -f right       'menu/forward'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward'
  ble-bind -f left        'menu/backward'
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
  ble-decode/keymap/push menu
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
## 関数 ble/complete/action:$ACTION/initialize
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
## 関数 ble/complete/action:$ACTION/complete
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

function ble/complete/action/util/complete.addtail {
  suffix=$suffix$1
}
function ble/complete/action/util/complete.mark-directory {
  [[ :$comp_type: == *:markdir:* && $CAND != */ ]] &&
    [[ :$comp_type: == *:marksymdir:* || ! -h $CAND ]] &&
    ble/complete/action/util/complete.addtail /
}
function ble/complete/action/util/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble/complete/action/util/complete.addtail \' ;;
  (*[DI]*) ble/complete/action/util/complete.addtail \" ;;
  esac
}

## 関数 ble/complete/action/util/quote-insert type
function ble/complete/action/util/quote-insert {
  local escape_flags=c
  if [[ $1 == command ]]; then
    escape_flags=
  elif [[ $1 == progcomp ]]; then
    # #D1362 Bash は "compopt -o filenames" が指定されている時、
    # '~' で始まる補完候補と同名のファイルがある時にのみチルダをクォートする。
    [[ $INSERT == '~'* && ! ( $DATA == *:filenames:* && -e $INSERT ) ]] &&
      escape_flags=T$escape_flags
  fi

  if [[ $comps_flags == *v* && $CAND == "$COMPV"* ]]; then
    local ins=${CAND:${#COMPV}} ret

    # 単語内の文脈に応じたエスケープ
    ble/complete/string#escape-for-completion-context "$ins" "$escape_flags"; ins=$ret

    # 直前にパラメータ展開があればエスケープ
    if [[ $comps_flags == *p* && $ins == [a-zA-Z_0-9]* ]]; then
      case $comps_flags in
      (*[DI]*)
        if [[ $COMPS =~ $rex_raw_paramx ]]; then
          local rematch1=${BASH_REMATCH[1]}
          INSERT=$rematch1'${'${COMPS:${#rematch1}+1}'}'$ins
          return 0
        else
          ins='""'$ins
        fi ;;
      (*) ins='\'$ins ;;
      esac
    fi

    # backslash が前置している時は二重クォートを防ぐ為に削除
    [[ $comps_flags == *B* && $COMPS == *'\' && $ins == '\'* ]] && ins=${ins:1}

    INSERT=$COMPS$ins
  else
    local ins=$CAND comps_fixed_part= compv_fixed_part=
    if [[ $comps_fixed && $CAND == "${comps_fixed#*:}"* ]]; then
      comps_fixed_part=${COMPS::${comps_fixed%%:*}}
      compv_fixed_part=${comps_fixed#*:}
      ins=${CAND:${#compv_fixed_part}}
    fi

    local ret; ble/complete/string#escape-for-completion-context "$ins" "$escape_flags"; ins=$ret
    case $comps_flags in
    (*S*) ins=\'$ins ;;
    (*E*) ins=\$\'$ins ;;
    (*D*) ins=\"$ins ;;
    (*I*) ins=\$\"$ins ;;
    esac

    INSERT=$comps_fixed_part$ins
  fi
}

function ble/complete/action/inherit-from {
  local dst=$1 src=$2
  local member srcfunc dstfunc
  for member in initialize complete getg get-desc; do
    srcfunc=ble/complete/action:$src/$member
    dstfunc=ble/complete/action:$dst/$member
    ble/is-function "$srcfunc" && builtin eval "function $dstfunc { $srcfunc; }"
  done
}

# action:plain

function ble/complete/action:plain/initialize {
  ble/complete/action/util/quote-insert
}
function ble/complete/action:plain/complete { :; }

# action:word
#
#   DATA ... 候補の説明として使用する文字列を指定します
#
function ble/complete/action:word/initialize {
  ble/complete/action/util/quote-insert
}
function ble/complete/action:word/complete {
  ble/complete/action/util/complete.close-quotation
  if [[ $comps_flags == *x* ]]; then
    ble/complete/action/util/complete.addtail ','
  else
    ble/complete/action/util/complete.addtail ' '
  fi
}
function ble/complete/action:word/get-desc {
  [[ $DATA ]] && desc=$DATA
}

# action:literal-substr
# action:literal-word
# action:substr
function ble/complete/action:literal-substr/initialize { :; }
function ble/complete/action:literal-substr/complete { :; }
function ble/complete/action:literal-word/initialize { :; }
function ble/complete/action:literal-word/complete { ble/complete/action:word/complete; }
function ble/complete/action:substr/initialize { ble/complete/action:word/initialize; }
function ble/complete/action:substr/complete { :; }

# action:file
# action:file_rhs (source:argument 内部使用)
function ble/complete/action:file/initialize {
  ble/complete/action/util/quote-insert
}
function ble/complete/action:file/complete {
  if [[ -e $CAND || -h $CAND ]]; then
    if [[ -d $CAND ]]; then
      ble/complete/action/util/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  fi
}
function ble/complete/action:file/init-menu-item {
  ble/syntax/highlight/getg-from-filename "$CAND"
  [[ $g ]] || { local ret; ble/color/face2g filename_warning; g=$ret; }

  if [[ :$comp_type: == *:vstat:* ]]; then
    if [[ -h $CAND ]]; then
      suffix='@'
    elif [[ -d $CAND ]]; then
      suffix='/'
    elif [[ -x $CAND ]]; then
      suffix='*'
    fi
  fi
}
function ble/complete/action:file_rhs/initialize {
  ble/complete/action/util/quote-insert
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
function ble/complete/action:progcomp/initialize {
  [[ $DATA == *:noquote:* ]] && return 0

  # bash-completion には compopt -o nospace として、
  # 自分でスペースを付加する補完関数がある。この時クォートすると問題。
  [[ $DATA == *:nospace:* && $CAND == *' ' && ! -f $CAND ]] && return 0

  ble/complete/action/util/quote-insert progcomp
}
function ble/complete/action:progcomp/complete {
  if [[ $DATA == *:filenames:* ]]; then
    ble/complete/action:file/complete
  else
    if [[ -d $CAND ]]; then
      ble/complete/action/util/complete.mark-directory
    else
      ble/complete/action:word/complete
    fi
  fi

  [[ $DATA == *:nospace:* ]] && suffix=${suffix%' '}
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
  ble/complete/action/util/quote-insert command
}
function ble/complete/action:command/complete {
  if [[ -d $CAND ]]; then
    ble/complete/action/util/complete.mark-directory
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
    # Note: ble/syntax/highlight/cmdtype はキャッシュ機能がついているが、
    #   キーワードに対して呼び出さない前提なのでキーワードを渡すと
    #   _ble_attr_ERR を返してしまう。
    local type; ble/util/type type "$CAND"
    ble/syntax/highlight/cmdtype1 "$type" "$CAND"
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
_ble_complete_action_command_desc[_ble_attr_KEYWORD]=keyword
_ble_complete_action_command_desc[_ble_attr_CMD_JOBS]=job
_ble_complete_action_command_desc[_ble_attr_ERR]='???'
_ble_complete_action_command_desc[_ble_attr_CMD_DIR]=directory
function ble/complete/action:command/get-desc {
  if [[ -d $CAND ]]; then
    desc=directory
  else
    local type; ble/util/type type "$CAND"
    ble/syntax/highlight/cmdtype1 "$type" "$CAND"
    if [[ $CAND == */ ]] && ((type==_ble_attr_ERR)); then
      type=_ble_attr_CMD_FUNCTION
    fi
    desc=${_ble_complete_action_command_desc[type]:-'???'}
  fi
}

# action:variable
#
#   DATA ... 変数名の文脈を指定します。
#     assignment braced word arithmetic の何れかです。
#
function ble/complete/action:variable/initialize { ble/complete/action/util/quote-insert; }
function ble/complete/action:variable/complete {
  case $DATA in
  (assignment)
    # var= 等に於いて = を挿入
    ble/complete/action/util/complete.addtail '=' ;;
  (braced)
    # ${var 等に於いて } を挿入
    ble/complete/action/util/complete.addtail '}' ;;
  (word)       ble/complete/action:word/complete ;;
  (arithmetic|nosuffix) ;; # do nothing
  esac
}
function ble/complete/action:variable/init-menu-item {
  local ret; ble/color/face2g syntax_varname; g=$ret
}

#------------------------------------------------------------------------------
# source

## 関数 ble/complete/source/reduce-compv-for-ambiguous-match
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

## 関数 ble/complete/cand/yield ACTION CAND DATA
##   @param[in] ACTION
##   @param[in] CAND
##   @param[in] DATA
##   @var[in] COMP_PREFIX
##   @var[in] flag_force_fignore
##   @var[in] flag_source_filter
function ble/complete/cand/yield {
  local ACTION=$1 CAND=$2 DATA="${*:3}"
  [[ $flag_force_fignore ]] && ! ble/complete/.fignore/filter "$CAND" && return 0

  [[ $flag_source_filter ]] ||
    ble/complete/candidates/filter#test "$CAND" || return 0

  local PREFIX_LEN=0
  [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

  local INSERT=$CAND
  ble/complete/action:"$ACTION"/initialize || return "$?"

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_word[icand]=$INSERT
  cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
}

function ble/complete/cand/yield-filenames {
  local action=$1; shift

  local rex_hidden=
  [[ :$comp_type: != *:match-hidden:* ]] &&
    rex_hidden=${COMPV:+'.{'${#COMPV}'}'}'(^|/)\.[^/]*$'

  local cand
  for cand; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    [[ $rex_hidden && $cand =~ $rex_hidden ]] && continue
    [[ $FIGNORE ]] && ! ble/complete/.fignore/filter "$cand" && continue
    ble/complete/cand/yield "$action" "$cand"
  done
}

_ble_complete_cand_varnames=(ACTION CAND INSERT DATA PREFIX_LEN)

## 関数 ble/complete/cand/unpack data
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
## 関数 ble/complete/source:$name args...
##   @param[in] args...
##     ble/syntax/completion-context/generate で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##   @var[in] comp_filter_type
##   @var[out] COMP_PREFIX
##     ble/complete/cand/yield で参照される一時変数。
##

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

  local cand
  for cand; do
    [[ $cand == "$COMPV"* ]] && ble/complete/cand/yield "$action" "$cand"
  done
}

# source:command

function ble/complete/source:command/.contract-by-slashes {
  local slashes=${COMPV//[!'/']}
  ble/bin/awk -F / -v baseNF=${#slashes} '
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

function ble/complete/source:command/gen.1 {
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match

  # Note: cygwin では cyg,x86,i68 等で始まる場合にとても遅い。
  #   他の環境でも空の補完を実行すると遅くなる可能性がある。
  local slow_compgen=
  if [[ ! $COMPV ]]; then
    slow_compgen=1
  elif [[ $OSTYPE == cygwin* ]]; then
    case $COMPV in
    (?|cy*|x8*|i6*)
      slow_compgen=1 ;;
    esac
  fi

  # Note: 何故か compgen -A command はクォート除去が実行されない。
  #   compgen -A function はクォート除去が実行される。
  #   従って、compgen -A command には直接 COMPV を渡し、
  #   compgen -A function には compv_quoted を渡す。
  if [[ $slow_compgen ]]; then
    shopt -q no_empty_cmd_completion && return 0
    ble/util/conditional-sync \
      'builtin compgen -c -- "$COMPV"' \
      '! ble/complete/check-cancel' 128 progressive-weight
  else
    builtin compgen -c -- "$COMPV"
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
    ble/complete/util/eval-pathname-expansion "$ret/"
    ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
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

  # Try progcomp by "complete -I"
  if ((_ble_bash>=50000)); then
    local old_cand_count=$cand_count

    local comp_opts=:
    ble/complete/source:argument/.generate-user-defined-completion initial; local ext=$?
    ((ext==148)) && return "$ext"
    if ((ext==0)); then
      ((cand_count>old_cand_count)) && return "$ext"
    fi
  fi

  ble/complete/source:sabbrev

  local cand arr
  local compgen
  ble/util/assign compgen 'ble/complete/source:command/gen "$arg"'
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'ble/bin/sort -u <<< "$compgen"' # 1 fork/exec

  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble/complete/cand/yield command "$cand"
  done
}

# source:file, source:dir

## 関数 ble/complete/util/eval-pathname-expansion pattern
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

  IFS= GLOBIGNORE= builtin eval "ret=(); ret=($pattern)" 2>/dev/null

  ble/util/invoke-hook dtor
}

## 関数 ble/complete/source:file/.construct-ambiguous-pathname-pattern path
##   指定された path に対応する曖昧一致パターンを生成します。
##   例えばalpha/beta/gamma に対して a*/b*/g* でファイル名を生成します。
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
    if [[ $name ]]; then
      ble/string#quote-word "${name::fixlen}"
      pattern=$pattern$ret*
      for ((j=fixlen;j<${#name};j++)); do
        ble/string#quote-word "${name:j:1}"
        if [[ $pattern == *\* ]]; then
          # * を extglob *([!ch]) に変換 #D1389
          pattern=$pattern'([!'$ret'])'
        fi
        pattern=$pattern$ret*
      done
    fi
  done
  [[ $pattern ]] || pattern="*"
  ret=$pattern
}
## 関数 ble/complete/source:file/.construct-pathname-pattern path
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
  [[ :$opts: == *:directory:* ]] && ret=${ret%/}/
  ble/complete/util/eval-pathname-expansion "$ret"

  candidates=()
  local cand
  if [[ :$opts: == *:directory:* ]]; then
    for cand in "${ret[@]}"; do
      [[ -d $cand ]] || continue
      [[ $cand == / ]] || cand=${cand%/}
      ble/array#push candidates "$cand"
    done
  else
    for cand in "${ret[@]}"; do
      [[ -e $cand || -h $cand ]] || continue
      ble/array#push candidates "$cand"
    done
  fi

  local flag_source_filter=1
  ble/complete/cand/yield-filenames file "${candidates[@]}"
}

function ble/complete/source:file {
  ble/complete/source:file/.impl
}
function ble/complete/source:dir {
  ble/complete/source:file/.impl directory
}

# source:rhs

function ble/complete/source:rhs { ble/complete/source:file; }

#------------------------------------------------------------------------------
# source:tilde

function ble/complete/action:tilde/initialize {
  # チルダは quote しない
  CAND=${CAND#\~} ble/complete/action/util/quote-insert
  INSERT=\~$INSERT

  # Note: Windows 等でチルダ展開の無効なユーザー名があるのでチェック
  local rex='^~[^/'\''"$`\!:]*$'; [[ $INSERT =~ $rex ]]
}
function ble/complete/action:tilde/complete {
  ble/complete/action/util/complete.mark-directory
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
    eval "printf '%s\n' '~'{0..$dirstack_max}"

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
  return $((ext?ext:cand_count==old_cand_count))
}

#------------------------------------------------------------------------------
# progcomp

# progcomp/.compgen

## 関数 ble/complete/progcomp/.compvar-initialize-wordbreaks
##   @var[out] wordbreaks
function ble/complete/progcomp/.compvar-initialize-wordbreaks {
  local ifs=$' \t\n' q=\'\" delim=';&|<>()' glob='[*?' hist='!^{' esc='`$\'
  local escaped=$ifs$q$delim$glob$hist$esc
  wordbreaks=${COMP_WORDBREAKS//[$escaped]} # =:
}
## 関数 ble/complete/progcomp/.compvar-perform-wordbreaks word
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

## 関数 ble/complete/progcomp/.compvar-generate-subwords/impl1 word
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
  local evaluator=eval-noglob
  ((${#ret[@]}==1)) && evaluator=eval
  ble/syntax:bash/simple-word#break-word "$left"
  local subword
  for subword in "${ret[@]}"; do
    ble/syntax:bash/simple-word/"$evaluator" "$subword"
    ble/array#push words "$ret"
    ((point+=${#ret}))
  done

  # 単語毎に評価 (後半)
  if [[ $right ]]; then
    ble/syntax:bash/simple-word#break-word "$right"
    local subword isfirst=1
    for subword in "${ret[@]}"; do
      ble/syntax:bash/simple-word/eval-noglob "$subword"
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
## 関数 ble/complete/progcomp/.compvar-generate-subwords/impl1 word
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

  ble/syntax:bash/simple-word/eval "$ret"; local value1=$ret
  if [[ $point ]]; then
    if ((point==${#word})); then
      point=${#value1}
    elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "${word::point}"; then
      ble/syntax:bash/simple-word/eval "$ret"
      point=${#ret}
    fi
  fi

  ble/complete/progcomp/.compvar-perform-wordbreaks "$value1"; words=("${ret[@]}")
  return 0
}
## 関数 ble/complete/progcomp/.compvar-generate-subwords word1
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
##       補完間関数に対してそのままの形で単語を渡す事を示す。
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
## 関数 ble/complete/progcomp/.compvar-quote-subword word
##   @var[in] index subword_flags
##   @var[out] ret
##   @var[in,out] p
function ble/complete/progcomp/.compvar-quote-subword {
  local word=$1 to_quote= is_evaluated= is_quoted=
  if [[ $subword_flags == *[EQ]* ]]; then
    [[ $subword_flags == *E* ]] && to_quote=1
  elif ble/syntax:bash/simple-word/reconstruct-incomplete-word "$word"; then
    is_evaluated=1
    ble/syntax:bash/simple-word/eval "$ret"; word=$ret
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
          ble/syntax:bash/simple-word/eval "$ret"; left=$ret
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

## 関数 ble/complete/progcomp/.compvar-initialize
##   プログラム補完で提供される変数を構築します。
##   @var[in]  comp_words comp_cword comp_line comp_point
##   @var[out] COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT COMP_KEY COMP_TYPE
##   @var[out] progcomp_prefix
function ble/complete/progcomp/.compvar-initialize {
  COMP_TYPE=9
  COMP_KEY=${KEYS[${#KEYS[@]}-1]:-9} # KEYS defined in ble-decode/widget/.call-keyseq

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
  local ret simple_flags simple_ibrace
  local word1 index=0 offset=0 sep=
  for word1 in "${comp_words[@]}"; do
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

      ble/complete/progcomp/.compvar-quote-subword "$w"; local wq=$ret

      # 単語登録
      if [[ $p ]]; then
        COMP_CWORD=${#COMP_WORDS[*]}
        ((COMP_POINT=${#COMP_LINE}+${#sep}+p))
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
    local COMP_WORDS COMP_CWORD
    local -x COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
    ble/complete/progcomp/.compvar-initialize
    local cmd=${COMP_WORDS[0]} cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
    "$comp_prog" "$cmd" "$cur" "$prev" </dev/null
  fi
}
# compopt に介入して -o/+o option を読み取る。
function ble/complete/progcomp/compopt {
  # Note: Bash補完以外から builtin compopt を呼び出しても
  #  エラーになるので呼び出さない事にした (2019-02-05)
  #builtin compopt "$@" 2>/dev/null; local ext=$?
  local ext=0

  local -a ospec
  while (($#)); do
    local arg=$1; shift
    case "$arg" in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case "$c" in
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
    case "$s" in
    (-*) comp_opts=${comp_opts//:"${s:1}":/:}${s:1}: ;;
    (+*) comp_opts=${comp_opts//:"${s:1}":/:} ;;
    esac
  done

  return "$ext"
}
function ble/complete/progcomp/.compgen-helper-func {
  [[ $comp_func ]] || return 1
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY
  ble/complete/progcomp/.compvar-initialize

  local fDefault=
  local cmd=${COMP_WORDS[0]} cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD-1]}
  ble/function#push compopt 'ble/complete/progcomp/compopt "$@"'
  builtin eval '"$comp_func" "$cmd" "$cur" "$prev"' < /dev/null; local ret=$?
  ble/function#pop compopt

  if [[ $is_default_completion && $ret == 124 ]]; then
    is_default_completion=retry
  fi
}

## 関数 ble/complete/progcomp/.compgen opts
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

  local comp_prog= comp_func=
  local compcmd= is_default_completion= is_special_completion=
  local -a alias_args=()
  if [[ :$opts: == *:initial:* ]]; then
    is_special_completion=1
    compcmd='-I'
  elif [[ :$opts: == *:default:* ]]; then
    builtin complete -p -D &>/dev/null || return 1
    is_special_completion=1
    is_default_completion=1
    compcmd='-D'
  else
    compcmd=${comp_words[0]}
  fi

  local -a compargs compoptions flag_noquote=
  local ret iarg=1
  if [[ $is_special_completion ]]; then
    ble/util/assign ret 'builtin complete -p "$compcmd" 2>/dev/null'
  else
    ble/util/assign ret 'builtin complete -p -- "$compcmd" 2>/dev/null'
  fi
  ble/string#split-words compargs "$ret"
  while ((iarg<${#compargs[@]})); do
    local arg=${compargs[iarg++]}
    case "$arg" in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c=${arg:ic:1}
        case "$c" in
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
          if [[ $c == A ]]; then
            case ${compargs[iarg]} in
            (command) flag_noquote=1 ;;
            (directory) ((_ble_bash>=40300)) && flag_noquote=1 ;;
            (file) ((40000<=_ble_bash&&_ble_bash<40200)) && flag_noquote=1 ;;
            esac
          fi
          ble/array#push compoptions "-$c" "${compargs[iarg++]}" ;;
        (o)
          local o=${compargs[iarg++]}
          comp_opts=${comp_opts//:"$o":/:}$o:
          ble/array#push compoptions "-$c" "$o" ;;
        (F)
          comp_func=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-func ;;
        (C)
          comp_prog=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble/complete/progcomp/.compgen-helper-prog ;;
        (*)
          # -D, -I, etc. just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done

  ble/complete/check-cancel && return 148

  # Note: 一旦 compgen だけで ble/util/assign するのは、compgen をサブシェルではなく元のシェルで評価する為である。
  #   補完関数が遅延読込になっている場合などに、読み込まれた補完関数が次回から使える様にする為に必要である。
  local compgen compgen_compv=$COMPV
  if [[ ! $flag_noquote && :$comp_opts: != *:noquote:* ]]; then
    local q="'" Q="'\''"
    compgen_compv="'${compgen_compv//$q/$Q}'"
  fi
  local progcomp_prefix=
  ble/util/assign compgen 'builtin compgen "${compoptions[@]}" -- "$compgen_compv" 2>/dev/null'

  # Note: complete -D 補完仕様に従った補完関数が 124 を返したとき再度始めから補完を行う。
  #   ble/complete/progcomp/.compgen-helper-func 関数内で補間関数の終了ステータスを確認し、
  #   もし 124 だった場合には is_default_completion に retry を設定する。
  if [[ $is_default_completion == retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    opts=:$opts:
    opts=${opts//:default:/:}
    ble/complete/progcomp/.compgen "${opts//:default:/:}"
    return "$?"
  fi

  [[ $compgen ]] || return 1

  # Note: git の補完関数など勝手に末尾に space をつけ -o nospace を指定する物が存在する。
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
    comp_opts=${comp_opts//:nospace:/:}
  fi

  # filter/sort/uniq candidates
  #
  #   Note: "$COMPV" で始まる単語だけを sed /^$rex_compv/ でフィルタする。
  #     それで候補が一つもない場合にはフィルタ無しで単語を列挙する。
  #
  #     2019-02-03 実は、現在の実装ではわざわざフィルタする必要はないかもしれない。
  #     以前 compgen に -- "$COMPV" を渡してもフィルタしてくれなかったのは、
  #     #D0245 cdd38598 で ble/complete/progcomp/.compgen-helper-func に於いて、
  #     "$comp_func" に引数を渡し忘れていたのが原因と思われる。
  #     これは 1929132b に於いて修正されたが念のためにフィルタを残していた気がする。
  #
  local arr
  {
    local compgen2=
    if [[ $comp_opts == *:filter_by_prefix:* ]]; then
      local ret; ble/string#escape-for-sed-regex "$COMPV"; local rex_compv=$ret
      ble/util/assign compgen2 'ble/bin/sed -n "/^\$/d;/^$rex_compv/p" <<< "$compgen"'
    fi
    [[ $compgen2 ]] || ble/util/assign compgen2 'ble/bin/sed "/^\$/d" <<< "$compgen"'

    local compgen3=$compgen2
    [[ $use_workaround_for_git ]] &&
      ble/util/assign compgen3 'ble/bin/sed "s/[[:space:]]\{1,\}\$//" <<< "$compgen2"'

    if [[ $comp_opts == *:nosort:* ]]; then
      ble/util/assign-array arr 'ble/bin/awk "!a[\$0]++" <<< "$compgen3"'
    else
      ble/util/assign-array arr 'ble/bin/sort -u <<< "$compgen3"'
    fi
  } 2>/dev/null

  local action=progcomp
  [[ $comp_opts == *:filenames:* && $COMPV == */* ]] && COMP_PREFIX=${COMPV%/*}/

  local old_cand_count=$cand_count
  local cand
  for cand in "${arr[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) && ble/complete/check-cancel && return 148
    ble/complete/cand/yield "$action" "$progcomp_prefix$cand" "$comp_opts"
  done

  # plusdirs の時はディレクトリ名も候補として列挙
  # Note: 重複候補や順序については考えていない
  [[ $comp_opts == *:plusdirs:* ]] && ble/complete/source:dir

  ((cand_count!=old_cand_count))
}

## 関数 ble/complete/progcomp/.compline-rewrite-command cmd [args...]
##   alias 展開等によるコマンド名の変更に対応して、
##   補完対象のコマンド名を指定の物に書き換えます。
##
##   @var[in,out] comp_line comp_words comp_point comp_cword
##
function ble/complete/progcomp/.compline-rewrite-command {
  local ocmd=${comp_words[0]}
  [[ $1 != "$ocmd" ]] || (($#>=2)) || return 1
  local ins="$*"
  comp_line=$ins${comp_line:${#ocmd}}
  ((comp_point-=${#ocmd},comp_point<0&&(comp_point=0),comp_point+=${#ins}))
  comp_words=("$@" "${comp_words[@]:1}")
  ((comp_cword&&(comp_cword+=$#-1)))
}

## 関数 ble/complete/progcomp cmd opts
##   補完指定を検索して対応する補完関数を呼び出します。
##   @var[in] comp_line comp_words comp_point comp_cword
function ble/complete/progcomp {
  local cmd=$1 opts=$2

  # copy compline variables
  local -a tmp; tmp=("${comp_words[@]}")
  local comp_words comp_line=$comp_line comp_point=$comp_point comp_cword=$comp_cword
  comp_words=("${tmp[@]}")

  local -a alias_args=()
  local alias_checked=' '
  while :; do
    if ble/is-function "ble/cmdinfo/complete:$cmd"; then
      ble/complete/progcomp/.compline-rewrite-command "$cmd" "${alias_args[@]}"
      "ble/cmdinfo/complete:$cmd" "$opts"
      return "$?"
    elif [[ $cmd == */?* ]] && ble/is-function "ble/cmdinfo/complete:${cmd##*/}"; then
      ble/complete/progcomp/.compline-rewrite-command "${cmd##*/}" "${alias_args[@]}"
      "ble/cmdinfo/complete:${cmd##*/}" "$opts"
      return "$?"
    elif builtin complete -p "$cmd" &>/dev/null; then
      ble/complete/progcomp/.compline-rewrite-command "$cmd" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif [[ $cmd == */?* ]] && builtin complete -p "${cmd##*/}" &>/dev/null; then
      ble/complete/progcomp/.compline-rewrite-command "${cmd##*/}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    elif
      # bash-completion の loader を呼び出して遅延補完設定をチェックする。
      ble/function#try __load_completion "${cmd##*/}" &>/dev/null &&
        builtin complete -p "${cmd##*/}" &>/dev/null
    then
      ble/complete/progcomp/.compline-rewrite-command "${cmd##*/}" "${alias_args[@]}"
      ble/complete/progcomp/.compgen "$opts"
      return "$?"
    fi
    alias_checked=$alias_checked$cmd' '

    # progcomp_alias が有効でなければ break
    ((_ble_bash<50000)) || shopt -q progcomp_alias || break

    local ret
    ble/util/expand-alias "$cmd"
    ble/string#split-words ret "$ret"
    [[ $alias_checked != *" $ret "* ]] || break
    cmd=$ret
    ((${#ret[@]}>=2)) &&
      alias_args=("${ret[@]:1}" "${alias_args[@]}")
  done

  ble/complete/progcomp/.compgen "default:$opts"
}

#------------------------------------------------------------------------------
# mandb

# action:mandb
#
#   DATA ... cmd FS menu_suffix FS insert_suffix FS desc
#
function ble/complete/action:mandb/initialize {
  ble/complete/action/util/quote-insert
}
function ble/complete/action:mandb/complete {
  ble/complete/action/util/complete.close-quotation
  local fields
  ble/string#split fields "$_ble_term_FS" "$DATA"
  ble/complete/action/util/complete.addtail "${fields[2]}"
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

function ble/complete/mandb/search-file/.check {
  local path=$1
  if [[ $path && -s $path ]]; then
    ret=$path
    return 0
  else
    return 1
  fi
}
function ble/complete/mandb/search-file {
  local command=$1

  # Try "man -w" first
  ble/complete/mandb/search-file/.check "$(ble/bin/man -w "$command" 2>/dev/null)" && return

  local manpath=${MANPATH:-/usr/share/man:/usr/local/share/man:/usr/local/man}
  ble/string#split manpath : "$manpath"
  local path
  for path in "${manpath[@]}"; do
    ble/complete/mandb/search-file/.check "$path/man1/$man.1.gz" && return
    ble/complete/mandb/search-file/.check "$path/man1/$man.1" && return
    ble/complete/mandb/search-file/.check "$path/man1/$man.8.gz" && return
    ble/complete/mandb/search-file/.check "$path/man1/$man.8" && return
  done
  return 1
}

function ble/complete/mandb/.generate-cache {
  ble/is-function ble/bin/man &&
    ble/is-function ble/bin/gzip &&
    ble/is-function ble/bin/nroff || return 1

  local command=$1
  local ret
  ble/complete/mandb/search-file "$command" || return 1
  local path=$ret
  if [[ $ret == *.gz ]]; then
    ble/bin/gzip -cd "$path"
  else
    ble/bin/cat "$path"
  fi | ble/bin/awk '
    BEGIN {
      g_key = "";
      g_desc = "";
      print ".TH __ble_ignore__ 1 __ble_ignore__ __ble_ignore__";
      print ".ll 9999"
    }
    function flush_topic() {
      if (g_key == "") return;
      print "__ble_key__";
      print ".TP";
      print g_key;
      print "";
      print "__ble_desc__";
      print "";
      print g_desc;
      print "";

      g_key = "";
      g_desc = "";
    }

    /^\.TP\y/ { flush_topic(); mode = "key"; next; }
    /^\.(SS|SH)\y/ { flush_topic(); next; }

    mode == "key" {
      g_key = $0;
      g_desc = "";
      mode = "desc";
      next;
    }
    mode == "desc" {
      if (g_desc != "") g_desc = g_desc "\n";
      g_desc = g_desc $0;
    }

    END { flush_topic(); }
  ' | ble/bin/nroff -Tutf8 -man | ble/bin/awk '
    function process_pair(name, desc) {
      if (!(g_name ~ /^-/)) return;

      # FS (\034) は特殊文字として使用するので除外する。
      sep = "\034";
      if (g_name ~ /\034/) return;
      gsub(/\034/, "\x1b[7m^\\\x1b[27m", desc);

      n = split(name, names, /,[[:space:]]*/);
      sub(/(\.  |; ).*/, ".", desc);
      for (i = 1; i <= n; i++) {
        name = names[i];
        insert_suffix = " ";
        menu_suffix = "";
        if (match(name, /[[ =]/)) {
          m = substr(name, RSTART, 1);
          if (m == "=") {
            insert_suffix = "=";
          } else if (m == "[") {
            insert_suffix = "";
          }
          menu_suffix = substr(name, RSTART);
          name = substr(name, 1, RSTART - 1);
        }
        printf("%s" sep "%s" sep "%s" sep "%s\n", name, menu_suffix, insert_suffix, desc);
      }
    }

    function flush_pair() {
      if (g_name == "") return;
      process_pair(g_name, g_desc);
      g_name = "";
      g_desc = "";
    }

    sub(/^[[:space:]]*__ble_key__/, "", $0) {
      flush_pair();
      mode = "key";
    }
    sub(/^[[:space:]]*__ble_desc__/, "", $0) {
      mode = "desc";
    }

    mode == "key" {
      line = $0;
      gsub(/\x1b\[[ -?]*[@-~]/, "", line); # CSI seq
      gsub(/\x1b[ -/]*[0-~]/, "", line); # ESC seq
      gsub(/\x0E/, "", line);
      gsub(/\x0F/, "", line);
      gsub(/^[[:space:]]*|[[:space:]]*$/, "", line);
      #gsub(/[[:space:]]+/, " ", line);
      if (line == "") next;
      if (g_name != "") g_name = g_name " ";
      g_name = g_name line;
    }

    mode == "desc" {
      line = $0;
      gsub(/^[[:space:]]*|[[:space:]]*$/, "", line);
      if (line == "") {
        if (g_desc != "") mode = "";
        next;
      }
      if (g_desc != "") g_desc = g_desc " ";
      g_desc = g_desc line;
    }

    END { flush_pair(); }
  ' | ble/bin/sort -k 1
}
function ble/complete/mandb/load-cache {
  local command=${1##*/}
  local fcache=$_ble_base_cache/man/$command
  if [[ ! -s $fcache ]]; then
    [[ -d $_ble_base_cache/man ]] ||
      ble/bin/mkdir -p "$_ble_base_cache/man"
    ble/complete/mandb/.generate-cache "$command" >| "$fcache" &&
      [[ -s $fcache ]] ||
        return 1
  fi
  ble/util/mapfile ret < "$fcache"
}

#------------------------------------------------------------------------------
# source:argument

## 関数 ble/complete/source:argument/.generate-user-defined-completion opts
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

function ble/complete/source:argument/.contains-literal-option {
  local word
  for word; do
    ble/syntax:bash/simple-word/is-simple "$word" &&
      ble/syntax:bash/simple-word/eval "$word" &&
      [[ $ret == -- ]] &&
      return 0
  done
  return 1
}

function ble/complete/source:argument/.generate-from-mandb {
  local COMPS=$COMPS COMPV=$COMPV
  ble/complete/source/reduce-compv-for-ambiguous-match
  [[ :$comp_type: == *:[maA]:* ]] && local COMP2=$COMP1

  local comp_words comp_line comp_point comp_cword
  ble/syntax:bash/extract-command "$COMP2" || return 1

  # 現在の単語よりも前に -- がある場合にはオプションを候補として生成しない。
  ((comp_cword>=1)) &&
    ble/complete/source:argument/.contains-literal-option "${comp_words[@]:1:comp_cword-1}" &&
    return 1

  local old_cand_count=$cand_count

  local cmd=${comp_words[0]}
  local alias_checked=' '
  while local ret; ! ble/complete/mandb/load-cache "$cmd"; do
    alias_checked=$alias_checked$cmd' '
    ble/util/expand-alias "$cmd"
    ble/string#split-words ret "$ret"
    [[ $alias_checked != *" $ret "* ]] || return 1
    ble/complete/source:argument/.contains-literal-option "${ret[@]:1}" && return 1
    cmd=$ret
  done

  local entry
  for entry in "${ret[@]}"; do
    ((cand_iloop++%bleopt_complete_polling_cycle==0)) &&
      ble/complete/check-cancel && return 148
    local CAND=${entry%%$_ble_term_FS*}
    [[ $CAND == "$COMPV"* ]] &&
      ble/complete/cand/yield mandb "$CAND" "$entry"
  done

  ((cand_count>old_cand_count)) &&
    bleopt complete_menu_style=desc-raw
}

function ble/complete/source:argument {
  local comp_opts=:

  ble/complete/source:sabbrev

  # failglob で展開に失敗した時は * を付加して再度展開を試みる
  if [[ $comps_flags == *f* && $COMPS != *\* && :$comp_type: != *:[maA]:* ]]; then
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"
    ble/syntax:bash/simple-word/eval "$ret*" && ((${#ret[*]})) &&
      ble/complete/cand/yield-filenames file "${ret[@]}"
    (($?==148)) && return 148
  fi

  local old_cand_count=$cand_count

  # try complete&compgen
  ble/complete/source:argument/.generate-user-defined-completion; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"

  # "-option" の時は complete options based on mandb
  if local rex='^-[-_a-zA-Z0-9]*$'; [[ $COMPV =~ $rex ]]; then
    ble/complete/source:argument/.generate-from-mandb; local ext=$?
    ((ext==148||cand_count>old_cand_count)) && return "$ext"
  fi

  # 候補が見付からない場合 (または曖昧補完で COMPV に / が含まれる場合)
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble/complete/source:dir
  else
    # filenames, default, bashdefault
    ble/complete/source:file
  fi; local ext=$?
  ((ext==148||cand_count>old_cand_count)) && return "$ext"

  if local rex='^/?[-_a-zA-Z0-9]+[:=]'; [[ $COMPV =~ $rex ]]; then
    # var=filename --option=filename /I:filename など。
    local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
    local COMP_PREFIX=$prefix
    [[ :$comp_type: != *:[maA]:* && $value =~ ^.+/ ]] &&
      COMP_PREFIX=$prefix${BASH_REMATCH[0]}

    local ret cand
    ble/complete/source:file/.construct-pathname-pattern "$value"
    ble/complete/util/eval-pathname-expansion "$ret"
    for cand in "${ret[@]}"; do
      [[ -e $cand || -h $cand ]] || continue
      [[ $FIGNORE ]] && ! ble/complete/.fignore/filter "$cand" && continue
      ble/complete/cand/yield file_rhs "$prefix$cand" "$prefix"
    done
  fi
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

  # 既に完全一致している場合は、より前の起点から補完させるために省略
  [[ $1 != '=' && ${#arr[@]} == 1 && $arr == "$COMPV" ]] && return 0

  local cand
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

## 関数  ble/complete/complete/determine-context-from-opts opts
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
## 関数 ble/complete/context/filter-prefix-sources
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
## 関数 ble/complete/context/overwrite-sources source
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

## 関数 ble/complete/context:syntax/generate-sources comp_text comp_index
##   @var[in] comp_text comp_index
##   @var[out] sources
function ble/complete/context:syntax/generate-sources {
  ble/syntax/import
  ble-edit/content/update-syntax
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
  local ret; ble/syntax:bash/simple-word/eval "$pattern"
  if ((!${#ret[@]})) && [[ $pattern != *'*' ]]; then
    ble/syntax:bash/simple-word/eval "$pattern*"
  fi

  local cand action=file
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

  local cand action=literal-word
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
##     local "${_ble_complete_cand_varnames[@]}"
##     ble/complete/cand/unpack "${cand_pack[0]}"
##
##   先頭に ACTION が格納されているので
##   ACTION だけ参照する場合には以下の様にする。
##
##     local ACTION=${cand_pack[0]%%:*}
##

## 関数 ble/complete/util/construct-ambiguous-regex text fixlen
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
## 関数 ble/complete/util/construct-glob-pattern text
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
  _fignore=()
  local i=0 leaf tmp
  ble/string#split tmp ':' "$FIGNORE"
  for leaf in "${tmp[@]}"; do
    [[ $leaf ]] && _fignore[i++]="$leaf"
  done
}
function ble/complete/.fignore/filter {
  local pat
  for pat in "${_fignore[@]}"; do
    [[ $1 == *"$pat" ]] && return 1
  done
}

## 関数 ble/complete/candidates/.pick-nearest-sources
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
  comps_fixed=

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
    elif ble/syntax:bash/simple-word/eval "$reconstructed"; then
      # 展開後の値を COMPV に格納する (既定)
      COMPV=("${ret[@]}")
      comps_flags=$comps_flags${simple_flags}v

      if ((${simple_ibrace%:*})); then
        ble/syntax:bash/simple-word/eval "${reconstructed::${simple_ibrace#*:}}"
        comps_fixed=${simple_ibrace%:*}:$ret
        comps_flags=${comps_flags}x
      fi
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

## 関数 ble/complete/candidates/.filter-by-command command
##   生成された候補 (cand_*) に対して指定したコマンドを実行し、
##   成功した候補のみを残して他を削除します。
##   @param[in] command
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble/complete/candidates/.filter-by-command {
  local command=$1
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=0
  local -a prop=() cand=() word=() show=() data=()
  for ((i=0;i<cand_count;i++)); do
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
## 関数 ble/complete/candidates/.filter-by-regex rex_filter
##   生成された候補 (cand_*) において指定した正規表現に一致する物だけを残します。
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble/complete/candidates/.filter-by-regex {
  local rex_filter=$1
  ble/complete/candidates/.filter-by-command '[[ ${cand_cand[i]} =~ $rex_filter ]]'
}
function ble/complete/candidates/.filter-by-glob {
  local globpat=$1
  ble/complete/candidates/.filter-by-command '[[ ${cand_cand[i]} == $globpat ]]'
}
function ble/complete/candidates/.filter-word-by-prefix {
  local prefix=$1
  ble/complete/candidates/.filter-by-command '[[ ${cand_word[i]} == "$prefix"* ]]'
}

function ble/complete/candidates/.initialize-rex_raw_paramx {
  local element=$_ble_syntax_bash_simple_rex_element
  local open_dquot=$_ble_syntax_bash_simple_rex_open_dquot
  rex_raw_paramx='^('$element'*('$open_dquot')?)\$[a-zA-Z_][a-zA-Z_0-9]*$'
}

## 候補フィルタ (candidate filters) は以下の関数を通して実装される。
##
##   関数 ble/complete/candidates/filter:FILTER_TYPE/init compv
##   関数 ble/complete/candidates/filter:FILTER_TYPE/test cand
##     @var[in] comp_filter_type
##     @var[in,out] comp_filter_pattern
##
##   関数 ble/complete/candidates/filter:FILTER_TYPE/match needle text
##     @param[in] needle text
##
##   関数 ble/complete/candidates/filter:FILTER_TYPE/count-match-chars value
##     @var[in] COMPV
##
## 使用するときには以下の関数を通して呼び出す (match, count-match-chars は直接呼び出す)。
##
##   関数 ble/complete/candidates/filter#init type compv
##   関数 ble/complete/candidates/filter#test value
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

## 関数 ble/complete/candidates/filter:head/match needle text
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
    ret=(0 ${#needle})
    return 0
  elif [[ $text == "${needle::${#text}}" ]]; then
    ret=(0 ${#text})
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
## 関数 ble/complete/candidates/filter:hsubseq/init compv [fixlen]
##   @param[in] compv
##   @param[in,opt] fixlen
##   @var[in] comps_fixed
##   @var[out] comp_filter_pattern
function ble/complete/candidates/filter:hsubseq/init {
  local fixlen; ble/complete/candidates/filter:hsubseq/.determine-fixlen "$2"
  local ret; ble/complete/util/construct-ambiguous-regex "$1" "$fixlen"
  comp_filter_pattern=^$ret
}
## 関数 ble/complete/candidates/filter:hsubseq/count-match-chars value [fixlen]
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
      ret=(0 ${#text})
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

## 関数 ble/complete/candidates/filter:subseq/init compv
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
    ble/complete/candidates/.pick-nearest-sources

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
  ble/util/test-rl-variable completion-ignore-case 0 && comp_type=${comp_type}:i
  ble/util/test-rl-variable visible-stats 0 && comp_type=${comp_type}:vstat
  ble/util/test-rl-variable mark-directories 1 && comp_type=${comp_type}:markdir
  ble/util/test-rl-variable mark-symlinked-directories 1 && comp_type=${comp_type}:marksymdir
  ble/util/test-rl-variable match-hidden-files 1 && comp_type=${comp_type}:match-hidden
  ble/util/test-rl-variable menu-complete-display-prefix 0 && comp_type=${comp_type}:menu-show-prefix

  # color settings are always enabled
  comp_type=$comp_type:menu-color:menu-color-match
  # ble/util/test-rl-variable colored-stats 1 && comp_type=${comp_type}:menu-color
  # ble/util/test-rl-variable colored-completion-prefix 1 && comp_type=${comp_type}:menu-color-match
}

## 関数 ble/complete/candidates/generate opts
##   @param[in] opts
##   @var[in] comp_text comp_index
##   @arr[in] sources
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags comps_fixed
##   @var[out] cand_*
function ble/complete/candidates/generate {
  local opts=$1
  local flag_force_fignore=
  local flag_source_filter=
  local -a _fignore=()
  if [[ $FIGNORE ]]; then
    ble/complete/.fignore/prepare
    ((${#_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  local rex_raw_paramx
  ble/complete/candidates/.initialize-rex_raw_paramx
  ble/complete/candidates/comp_type#read-rl-variables

  local cand_iloop=0
  cand_count=0
  cand_cand=() # 候補文字列
  cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  cand_pack=() # 候補の詳細データ

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

## 関数 ble/complete/candidates/determine-common-prefix/.apply-partial-comps
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
  ble/syntax:bash/simple-word/evaluate-path-spec "$word0"; spec0=("${spec[@]}") path0=("${path[@]}")
  ble/syntax:bash/simple-word/evaluate-path-spec "$word1"; spec1=("${spec[@]}") path1=("${path[@]}")
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

## 関数 ble/complete/candidates/determine-common-prefix
##   cand_* を元に common prefix を算出します。
##   @var[in] cand_*
##   @var[out] ret
function ble/complete/candidates/determine-common-prefix {
  # 共通部分
  local common=${cand_word[0]}
  local clen=${#common}
  if ((cand_count>1)); then
    # setup ignore case
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
    # common を部分的に COMPS に置換する試み
    # Note: ignore-case で一意確定の時は case を
    #   候補に合わせたいので COMPS には置換しない。
    ble/complete/candidates/determine-common-prefix/.apply-partial-comps
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
        if ble/syntax:bash/simple-word/eval "$common_reconstructed" &&
            ble/complete/candidates/filter:"$filter_type"/count-match-chars "$ret"; then
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
             ble/syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS" &&
             ble/syntax:bash/simple-word/eval-noglob "$notilde$ret" &&
             local compv_notilde=$ret &&
             ble/syntax:bash/simple-word/eval-noglob "$notilde$common_reconstructed" &&
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
        if [[ $bleopt_complete_allow_reduction ]] ||
             { local simple_flags simple_ibrace
               ble/syntax:bash/simple-word/reconstruct-incomplete-word "$common0" &&
                 ble/syntax:bash/simple-word/eval "$ret" &&
                 [[ $ret == "$COMPV"* ]]; }; then
          common=$common0
        fi
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

## 関数 ble/complete/menu-complete.class/render-item pack opts
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

  local "${_ble_complete_cand_varnames[@]}"
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
  [[ :$opts: == *:selected:* ]] && ((g0|=_ble_color_gflags_Revert))
  ret=${_ble_color_g2sgr[g=g0]}
  [[ $ret ]] || ble/color/g2sgr "$g"; sgrN0=$ret
  ret=${_ble_color_g2sgr[g=g0|_ble_color_gflags_Revert]}
  [[ $ret ]] || ble/color/g2sgr "$g"; sgrN1=$ret
  if ((${#m[@]})); then
    # 一致色の初期化
    ret=${_ble_color_g2sgr[g=g0|_ble_color_gflags_Bold]}
    [[ $ret ]] || ble/color/g2sgr "$g"; sgrB0=$ret
    ret=${_ble_color_g2sgr[g=g0|_ble_color_gflags_Bold|_ble_color_gflags_Revert]}
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
    local i iN=${#m[@]} p p0=0 out=
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
  local "${_ble_complete_cand_varnames[@]}"
  ble/complete/cand/unpack "$item"
  desc="(action: $ACTION)"
  ble/function#try ble/complete/action:"$ACTION"/get-desc
}

function ble/complete/menu-complete.class/onselect {
  local nsel=$1 osel=$2
  local insert=${_ble_complete_menu_original:-${_ble_complete_menu_comp[2]}}
  if ((nsel>=0)); then
    local "${_ble_complete_cand_varnames[@]}"
    ble/complete/cand/unpack "${_ble_complete_menu_items[nsel]}"
    insert=$INSERT
  fi
  ble-edit/content/replace-limited "$_ble_complete_menu0_beg" "$_ble_edit_ind" "$insert"
  ((_ble_edit_ind=_ble_complete_menu0_beg+${#insert}))
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
blehook widget_bell+=ble/complete/menu/clear
blehook history_onleave+=ble/complete/menu/clear

## 関数 ble/complete/menu/get-footprint
##   @var[out] footprint
function ble/complete/menu/get-footprint {
  footprint=$_ble_edit_ind:$_ble_edit_mark_active:${_ble_edit_mark_active:+$_ble_edit_mark}:$_ble_edit_overwrite_mode:$_ble_edit_str
}

## 関数 ble/complete/menu/show opts
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

## 関数 ble/complete/menu/generate-candidates-from-menu
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
  local pack "${_ble_complete_cand_varnames[@]}"
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

## 関数 ble/complete/generate-candidates-from-opts opts
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/generate-candidates-from-opts {
  local opts=$1

  # 文脈の決定
  local context; ble/complete/complete/determine-context-from-opts "$opts"

  # 補完源の生成
  comp_type=
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local sources
  ble/complete/context:"$context"/generate-sources "$comp_text" "$comp_index" || return "$?"

  ble/complete/candidates/generate "$opts"
}

## 関数 ble/complete/insert insert_beg insert_end insert suffix
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

  if ble/util/test-rl-variable skip-completed-text; then
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
  ble/widget/.replace-range "$insert_beg" "$insert_end" "$ins" 1
  ((_ble_edit_ind=insert_beg+${#ins},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
}

## 関数 ble/complete/insert-common
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
      local "${_ble_complete_cand_varnames[@]}"
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
      ble/syntax:bash/simple-word/eval "$ret"
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

## 関数 ble/complete/insert-all
##   @var[out] COMP1 COMP2 COMPS COMPV comp_type comps_flags comps_fixed
##   @var[out] cand_count cand_cand cand_word cand_pack
function ble/complete/insert-all {
  local "${_ble_complete_cand_varnames[@]}"
  local pack beg=$COMP1 end=$COMP2 insert= suffix= index=0
  for pack in "${cand_pack[@]}"; do
    ble/complete/cand/unpack "$pack"
    insert=$INSERT suffix=

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

## 関数 ble/complete/insert-braces/.compose words...
##   指定した単語をブレース展開に圧縮します。
##   @var[in] comp_type
##   @stdout
##     圧縮したブレース展開を返します。
function ble/complete/insert-braces/.compose {
  # Note: awk が RS = "\0" に対応していれば \0 で区切る。
  #   それ以外の場合には \x1E (ASCII RS) で区切る。
  if ble/bin/awk-supports-null-record-separator; then
    local printf_format='%s\0' RS='"\0"'
  else
    local printf_format='%s\x1E' RS='"\x1E"'
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

  printf "$printf_format" "$@" | ble/bin/awk '
    function starts_with(str, head) {
      return substr(str, 1, length(head)) == head;
    }

    BEGIN {
      RS = '"$RS"';
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
            alpha = (value ~ /^[a-z]$/) ? lower : upper;
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

## 関数 ble/complete/insert-braces
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
        ble/syntax:bash/simple-word/eval "$ret"
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
    ble/complete/action/util/complete.addtail ','
  else
    ble/complete/action/util/complete.addtail ' '
  fi

  ble/complete/insert "$beg" "$end" "$insert" "$suffix"
  blehook/invoke complete_insert
  _ble_complete_state=complete
  ble/complete/menu/clear
  return 0
}

_ble_complete_state=

## 関数 ble/widget/complete opts
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
          ble/complete/menu-complete/enter && return 0
      fi
      [[ $WIDGET == "$LASTWIDGET" && $state != complete ]] && opts=$opts:enter_menu
    fi
  fi

  local COMP1 COMP2 COMPS COMPV
  local comp_type comps_flags comps_fixed
  local cand_count=0
  local -a cand_cand cand_word cand_pack
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
    elif ((ext!=0||cand_count==0)); then
      [[ :$opts: != *:no-bell:* ]] &&
        ble/widget/.bell 'complete: no completions'
      ble-edit/info/clear
      return 1
    fi
  fi

  if [[ :$opts: == *:insert_common:* ]]; then
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
  ble/widget/complete enter_menu:$opts
}

#------------------------------------------------------------------------------
# menu-filter

## 関数 ble/complete/menu-filter/.filter-candidates
##   @var[in,out] comp_type
##   @var[out] cand_pack
function ble/complete/menu-filter/.filter-candidates {
  cand_pack=()

  local iloop=0 interval=$bleopt_complete_polling_cycle
  local filter_type pack "${_ble_complete_cand_varnames[@]}"
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

  # 最初に生成した全ての候補 (遡って書き換える候補等)
  cand_pack=("${_ble_complete_menu0_pack[@]}")
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
  ble/syntax:bash/simple-word/eval "$ret"
  local COMPV=$ret

  local comp_type=${_ble_complete_menu0_comp[4]} cand_pack
  ble/complete/menu-filter/.filter-candidates

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

## 関数 ble/highlight/layer/buff#operate-gflags name beg end mask gflags
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
## 関数 ble/highlight/layer/buff#set-explicit-sgr name index
function ble/highlight/layer/buff#set-explicit-sgr {
  local BUFF=$1 index=$2
  builtin eval "((index<\${#$BUFF[@]}))" || return 1
  local g; ble/highlight/layer/update/getg "$index"
  local ret; ble/color/g2sgr "$g"
  builtin eval "$BUFF[index]=\$ret\${_ble_highlight_layer_plain_buff[index]}"
}

# ble/color/defface menu_filter_fixed bg=247,bold
# ble/color/defface menu_filter_input bg=147,bold
ble/color/defface menu_filter_fixed bold
ble/color/defface menu_filter_input fg=16,bg=229

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
      ble/highlight/layer:region/.update-dirty-range "$beg" "$obeg"
      ble/highlight/layer:region/.update-dirty-range "$end" "$oend"
    else
      ble/highlight/layer:region/.update-dirty-range "$beg" "$end"
    fi
  else
    if [[ $obeg ]]; then
      ble/highlight/layer:region/.update-dirty-range "$obeg" "$oend"
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
    ble/color/g#append "$g0"
  fi
}

_ble_complete_menu_filter_enabled=
if ble/is-function ble/util/idle.push-background; then
  _ble_complete_menu_filter_enabled=1
  ble/util/idle.push-background ble/complete/menu-filter.idle
  ble/array#insert-before _ble_highlight_layer__list region menu_filter
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

## 関数 ble/complete/menu-complete/select index [opts]
function ble/complete/menu-complete/select {
  ble/complete/menu#select "$@"
}

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

  _ble_complete_menu_original=${_ble_edit_str:beg:end-beg}
  ble/complete/menu/redraw

  if [[ :$opts: == *:backward:* ]]; then
    ble/complete/menu#select $((${#_ble_complete_menu_items[@]}-1))
  else
    ble/complete/menu#select 0
  fi

  _ble_edit_mark_active=insert
  ble-decode/keymap/push menu_complete
  return 0
}

function ble/widget/menu_complete/exit {
  local opts=$1
  ble-decode/keymap/pop

  if ((_ble_complete_menu_selected>=0)); then
    # 置換情報を再構成
    local new=${_ble_edit_str:_ble_complete_menu0_beg:_ble_edit_ind-_ble_complete_menu0_beg}
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
        local "${_ble_complete_cand_varnames[@]}"
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
  ble-decode/keymap/pop
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
  ble/decode/widget/redispatch "${KEYS[@]}"
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
  ble-bind -f C-f         'menu/forward'
  ble-bind -f right       'menu/forward'
  ble-bind -f C-i         'menu/forward cyclic'
  ble-bind -f TAB         'menu/forward cyclic'
  ble-bind -f C-b         'menu/backward'
  ble-bind -f left        'menu/backward'
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

## 関数 ble/complete/auto-complete/.search-history-light text
##   !string もしくは !?string を用いて履歴の検索を行います
##   @param[in] text
##   @var[out] ret
function ble/complete/auto-complete/.search-history-light {
  [[ $_ble_history_prefix ]] && return 1

  local text=$1
  [[ ! $text ]] && return 1

  # !string による一致を試みる
  #   string には [$wordbreaks] は含められない。? はOK
  local wordbreaks="<>();&|:$_ble_term_IFS"
  local word=
  if [[ $text != [-0-9#?!]* ]]; then
    word=${text%%[$wordbreaks]*}
    local expand
    BASH_COMMAND='!'$word ble/util/assign expand 'ble/edit/hist_expanded/.core' &>/dev/null || return 1
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
      BASH_COMMAND='!?'$frag ble/util/assign expand 'ble/edit/hist_expanded/.core' &>/dev/null || return 1
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
## 関数 ble/complete/auto-complete/.search-history-heavy text
##   @var[out] ret
function ble/complete/auto-complete/.search-history-heavy {
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

  ble/history/get-editted-entry -v ret "$index"
  return 0
}

## 関数 ble/complete/auto-complete/.setup-auto-complete-mode
##   @var[in] type COMP1 cand word insert suffix
function ble/complete/auto-complete/.setup-auto-complete-mode {
  _ble_complete_ac_type=$type
  _ble_complete_ac_comp1=$COMP1
  _ble_complete_ac_cand=$cand
  _ble_complete_ac_word=$word
  _ble_complete_ac_insert=$insert
  _ble_complete_ac_suffix=$suffix

  _ble_edit_mark_active=auto_complete
  ble-decode/keymap/push auto_complete
  ble-decode-key "$_ble_complete_KCODE_ENTER" # dummy key input to record keyboard macros
}
## 関数 ble/complete/auto-complete/.insert ins
##   @param[in] ins
##   @var[in,out] _ble_edit_ind _ble_edit_mark
function ble/complete/auto-complete/.insert {
  local insert=$1
  ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$insert" nobell
  ((_ble_edit_mark=_ble_edit_ind+${#insert}))
}

## 関数 ble/complete/auto-complete/.check-history opts
##   @param[in] opts
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/.check-history {
  local opts=$1
  local searcher=.search-history-heavy
  [[ :$opts: == *:light:*  ]] && searcher=.search-history-light

  local ret
  ((_ble_edit_ind==${#_ble_edit_str})) || return 1
  ble/complete/auto-complete/"$searcher" "$_ble_edit_str" || return "$?" # 0, 1 or 148
  local word=$ret cand=
  local COMP1=0 COMPS=$_ble_edit_str
  [[ $word == "$COMPS" ]] && return 1
  local insert=$word suffix=
  local type=h
  ble/complete/auto-complete/.insert "${insert:${#COMPS}}"

  # vars: type COMP1 cand word insert suffix
  ble/complete/auto-complete/.setup-auto-complete-mode
  return 0
}

## 関数 ble/complete/auto-complete/.check-context
##   @var[in] comp_type comp_text comp_index
function ble/complete/auto-complete/.check-context {
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
  local cand_count
  local -a cand_cand cand_word cand_pack
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
    local "${_ble_complete_cand_varnames[@]}"
    ble/complete/cand/unpack "${cand_pack[0]}"
    ble/complete/action:"$ACTION"/complete
  fi

  local type=
  if [[ $word == "$COMPS"* ]]; then
    # 入力候補が既に続きに入力されている時は提示しない
    [[ ${comp_text:COMP1} == "$word"* ]] && return 1

    type=c
    ble/complete/auto-complete/.insert "${insert:${#COMPS}}"
  else
    case :$comp_type: in
    (*:a:*) type=a ;;
    (*:m:*) type=m ;;
    (*:A:*) type=A ;;
    (*)   type=r ;;
    esac
    ble/complete/auto-complete/.insert " [$insert] "
  fi

  # vars: type COMP1 cand word insert suffix
  ble/complete/auto-complete/.setup-auto-complete-mode
  return 0
}

## 関数 ble/complete/auto-complete.impl opts
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

  if [[ $bleopt_complete_auto_history ]]; then
    ble/complete/auto-complete/.check-history light; local ext=$?
    ((ext==0||ext==148)) && return "$ext"

    [[ $_ble_history_prefix || $_ble_history_load_done ]] &&
      ble/complete/auto-complete/.check-history; local ext=$?
    ((ext==0||ext==148)) && return "$ext"
  fi

  ble/complete/auto-complete/.check-context
}

## 背景関数 ble/complete/auto-complete.idle
function ble/complete/auto-complete.idle {
  # ※特に上書きしなければ常に wait-user-input で抜ける。
  ble/util/idle.wait-user-input

  [[ $bleopt_complete_auto_complete ]] || return 1
  [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]] || return 0

  case $_ble_decode_widget_last in
  (ble/widget/self-insert) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_auto_delay だけ経過してから処理
  local rest_delay=$((bleopt_complete_auto_delay-ble_util_idle_elapsed))
  if ((rest_delay>0)); then
    ble/util/idle.sleep "$rest_delay"
    return 0
  fi

  ble/complete/auto-complete.impl
}

## 背景関数 ble/complete/auto-menu.idle
function ble/complete/auto-menu.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] && return 0
  ((bleopt_complete_auto_menu>0)) || return 1

  case $_ble_decode_widget_last in
  (ble/widget/self-insert) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (ble/widget/auto_complete/self-insert) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_auto_delay だけ経過してから処理
  local rest_delay=$((bleopt_complete_auto_menu-ble_util_idle_elapsed))
  if ((rest_delay>0)); then
    ble/util/idle.sleep "$rest_delay"
    return 0
  fi

  ble/widget/complete show_menu:no-empty:no-bell
}

ble/function#try ble/util/idle.push-background ble/complete/auto-complete.idle
ble/function#try ble/util/idle.push-background ble/complete/auto-menu.idle

## 編集関数 ble/widget/auto-complete-enter
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
  ble-decode/keymap/pop
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
}
function ble/widget/auto_complete/insert {
  ble-decode/keymap/pop
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
  ble/decode/widget/redispatch "${KEYS[@]}"
}
function ble/widget/auto_complete/self-insert {
  local code=$((KEYS[0]&_ble_decode_MaskChar))
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
      [[ ! $_ble_complete_ac_word ]] && ble/widget/auto_complete/cancel
      processed=1
    fi
  elif [[ $_ble_complete_ac_type == [rmaA] && $ins != [{,}] ]]; then
    if local ret simple_flags simple_ibrace; ble/syntax:bash/simple-word/reconstruct-incomplete-word "$comps_new"; then
      if ble/syntax:bash/simple-word/eval "$ret" && local compv_new=$ret; then
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
    ble/decode/widget/redispatch "${KEYS[@]}"
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

function ble/complete/sabbrev/.print-definition {
  local key=$1 type=${2%%:*} value=${2#*:}
  local flags=
  [[ $type == m ]] && flags='-m '

  local q=\' Q="'\''" shell_specialchars=$' \n\t&|;<>()''\$`"'\''[]*?!~'
  if [[ $key == *["$shell_specialchars"]* ]]; then
    printf "ble-sabbrev %s'%s=%s'\n" "$flags" "${key//$q/$Q}" "${value//$q/$Q}"
  else
    printf "ble-sabbrev %s%s='%s'\n" "$flags" "$key" "${value//$q/$Q}"
  fi
}

## 関数 ble/complete/sabbrev/register key value
##   静的略語展開を登録します。
##   @param[in] key value
##
## 関数 ble/complete/sabbrev/list
##   登録されている静的略語展開の一覧を表示します。
##
## 関数 ble/complete/sabbrev/get key
##   静的略語展開の展開値を取得します。
##   @param[in] key
##   @var[out] ret
##
if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  function ble/complete/sabbrev/register {
    local key=$1 value=$2
    _ble_complete_sabbrev[$key]=$value
  }
  function ble/complete/sabbrev/list {
    local key
    for key in "${!_ble_complete_sabbrev[@]}"; do
      local value=${_ble_complete_sabbrev[$key]}
      ble/complete/sabbrev/.print-definition "$key" "$value"
    done
  }
  function ble/complete/sabbrev/get {
    local key=$1
    ret=${_ble_complete_sabbrev[$key]}
    [[ $ret ]]
  }
  function ble/complete/sabbrev/get-keys {
    keys=("${!_ble_complete_sabbrev[@]}")
  }
else
  if ! ble/is-array _ble_complete_sabbrev_keys; then # reload #D0875
    _ble_complete_sabbrev_keys=()
    _ble_complete_sabbrev_values=()
  fi
  function ble/complete/sabbrev/register {
    local key=$1 value=$2 i=0
    for key2 in "${_ble_complete_sabbrev_keys[@]}"; do
      [[ $key2 == "$key" ]] && break
      ((i++))
    done
    _ble_complete_sabbrev_keys[i]=$key
    _ble_complete_sabbrev_values[i]=$value
  }
  function ble/complete/sabbrev/list {
    local shell_specialchars=$' \n\t&|;<>()''\$`"'\''[]*?!~'
    local i N=${#_ble_complete_sabbrev_keys[@]} q=\' Q="'\''"
    for ((i=0;i<N;i++)); do
      local key=${_ble_complete_sabbrev_keys[i]}
      local value=${_ble_complete_sabbrev_values[i]}
      ble/complete/sabbrev/.print-definition "$key" "$value"
    done
  }
  function ble/complete/sabbrev/get {
    ret=
    local key=$1 value=$2 i=0
    for key in "${_ble_complete_sabbrev_keys[@]}"; do
      if [[ $key == "$1" ]]; then
        ret=${_ble_complete_sabbrev_values[i]}
        break
      fi
      ((i++))
    done
    [[ $ret ]]
  }
  function ble/complete/sabbrev/get-keys {
    keys=("${_ble_complete_sabbrev_keys[@]}")
  }
fi


function ble/complete/sabbrev/read-arguments {
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == ?*=* ]]; then
      ble/array#push specs "s:$arg"
    else
      case $arg in
      (--help) flag_help=1 ;;
      (-*)
        local i n=${#arg} c
        for ((i=1;i<n;i++)); do
          c=${arg:i:1}
          case $c in
          (m)
            if ((!$#)); then
              ble/util/print "ble-sabbrev: option argument for '-$c' is missing" >&2
              flag_error=1
            elif [[ $1 != ?*=* ]]; then
              ble/util/print "ble-sabbrev: invalid option argument '-$c $1' (expected form: '-c key=value')" >&2
              flag_error=1
            else
              ble/array#push specs "$c:$1"; shift
            fi ;;
          (*)
            ble/util/print "ble-sabbrev: unknown option '-$c'." >&2
            flag_error=1 ;;
          esac
        done ;;
      (*)
        ble/util/print "ble-sabbrev: unrecognized argument '$arg'." >&2
        flag_error=1 ;;
      esac
    fi
  done
}

## 関数 ble-sabbrev key=value
##   静的略語展開を登録します。
function ble-sabbrev {
  if (($#)); then
    local -a specs=()
    local flag_help= flag_error=
    ble/complete/sabbrev/read-arguments "$@"
    if [[ $flag_help || $flag_error ]]; then
      [[ $flag_error ]] && ble/util/print
      printf '%s\n' \
             'usage: ble-sabbrev key=value' \
             'usage: ble-sabbrev -m key=function' \
             'usage: ble-sabbrev --help' \
             'Register sabbrev expansion.'
      [[ ! $flag_error ]]; return "$?"
    fi

    local spec key type value
    for spec in "${specs[@]}"; do
      # spec は t:key=value の形式
      type=${spec::1} spec=${spec:2}
      key=${spec%%=*} value=${spec#*=}
      ble/complete/sabbrev/register "$key" "$type:$value"
    done
  else
    ble/complete/sabbrev/list
  fi
}

function ble/complete/sabbrev/expand {
  local sources comp_index=$_ble_edit_ind comp_text=$_ble_edit_str
  ble/complete/context:syntax/generate-sources
  local src asrc pos=$comp_index
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    case ${asrc[0]} in
    (file|command|argument|variable:w|wordlist:*|sabbrev)
      ((asrc[1]<pos)) && pos=${asrc[1]} ;;
    esac
  done

  ((pos<comp_index)) || return 1

  local key=${_ble_edit_str:pos:comp_index-pos}
  local ret; ble/complete/sabbrev/get "$key" || return 1

  local type=${ret%%:*} value=${ret#*:}
  case $type in
  (s)
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
    local cand_count=0
    local -a cand_cand=() cand_word=() cand_pack=()
    local cand COMP_PREFIX=

    # local settings
    local bleopt_sabbrev_menu_style=$bleopt_complete_menu_style
    local bleopt_sabbrev_menu_opts=

    # generate candidates
    #   COMPREPLY に候補を追加してもらうか、
    #   或いは手動で ble/complete/cand/yield 等を呼び出してもらう。
    local -a COMPREPLY=()
    builtin eval -- "$value"
    for cand in "${COMPREPLY[@]}"; do
      ble/complete/cand/yield word "$cand" ""
    done

    if ((cand_count==0)); then
      return 1
    elif ((cand_count==1)); then
      local value=${cand_word[0]}
      ble/widget/.replace-range "$pos" "$comp_index" "$value"
      ((_ble_edit_ind=pos+${#value}))
      return 0
    fi

    # Note: 既存の内容 (key) は削除する
    ble/widget/.replace-range "$pos" "$comp_index" ''

    local bleopt_complete_menu_style=$bleopt_sabbrev_menu_style
    local menu_common_part=
    ble/complete/menu/show || return "$?"
    [[ :$bleopt_sabbrev_menu_opts: == *:enter_menu:* ]] &&
      ble/complete/menu-complete/enter
    return 147 ;;
  (*) return 1 ;;
  esac
  return 0
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
  local ret; ble/complete/sabbrev/get "$INSERT"
  desc="(sabbrev expansion) $ret"
}
function ble/complete/source:sabbrev {
  local keys; ble/complete/sabbrev/get-keys
  local key cand

  local filter_type=$comp_filter_type
  [[ $filter_type == none ]] && filter_type=head
  local comps_fixed=

  # フィルタリング用設定を COMPS で再初期化
  local comp_filter_type
  local comp_filter_pattern
  ble/complete/candidates/filter#init "$filter_type" "$COMPS"
  for cand in "${keys[@]}"; do
    ble/complete/candidates/filter#test "$cand" || continue

    # filter で除外されない為に cand には評価後の値を入れる必要がある。
    local ret simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$cand" &&
      ble/syntax:bash/simple-word/eval "$ret" || continue

    local value=$ret flag_source_filter=1
    ble/complete/cand/yield sabbrev "$cand"
  done
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

  ble-edit/info/show text "$text"
}
function ble/complete/dabbrev/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble/complete/dabbrev/.show-status.fib
}
function ble/complete/dabbrev/erase-status {
  ble-edit/info/default
}

## 関数 ble/complete/dabbrev/initialize-variables
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

## 関数 ble/complete/dabbrev/search-in-history-entry line index
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

  local line; ble/history/get-editted-entry -v line "$index"
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
  ble-decode/keymap/push dabbrev
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
  ble-decode/keymap/pop
  _ble_edit_mark_active=
  ble/complete/dabbrev/erase-status
}
function ble/widget/dabbrev/exit-default {
  ble/widget/dabbrev/exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch "${KEYS[@]}"
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

# action:cdpath (action:file を修正)

function ble/complete/action:cdpath/initialize {
  DATA=$cdpath_basedir
  ble/complete/action/util/quote-insert
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
  ble/syntax/highlight/getg-from-filename "$DATA$CAND"; local g1=$g
  [[ $g1 ]] || { ble/color/face2g filename_warning; g1=$ret; }
  ((g2=g^_ble_color_gflags_Revert))
  ble/color/g2sgr "$g1"; sgr1=$ret
  ble/color/g2sgr "$g2"; sgr2=$ret
  ble/string#escape-for-display "$DATA$CAND" sgr1="$sgr2":sgr0="$sgr1"
  local filename=$sgr1$ret$sgr0

  CAND=$DATA$CAND ble/complete/action:file/get-desc
  desc="CDPATH $filename ($desc)"
}

## 関数 ble/cmdinfo/complete:cd/.impl
##   @remarks
##     この実装は ble/complete/source:file/.impl を元にしている。
##     実装に関する注意点はこの元の実装も参照の事。
function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

  if [[ $COMPV == -* ]]; then
    local action=word
    case $type in
    (pushd)
      if [[ $COMPV == - || $COMPV == -n ]]; then
        ble/complete/cand/yield "$action" -n
      fi ;;
    (*)
      COMP_PREFIX=$COMPV
      local -a list=()
      [[ $COMPV == -* ]] && ble/complete/cand/yield "$action" "${COMPV}"
      [[ $COMPV != *L* ]] && ble/complete/cand/yield "$action" "${COMPV}L"
      [[ $COMPV != *P* ]] && ble/complete/cand/yield "$action" "${COMPV}P"
      ((_ble_bash>=40200)) && [[ $COMPV != *e* ]] && ble/complete/cand/yield "$action" "${COMPV}e"
      ((_ble_bash>=40300)) && [[ $COMPV != *@* ]] && ble/complete/cand/yield "$action" "${COMPV}@" ;;
    esac
    return 0
  fi

  [[ :$comp_type: != *:[maA]:* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}
  [[ :$comp_type: == *:[maA]:* && ! $COMPV ]] && return 1

  if [[ ! $CDPATH ]]; then
    ble/complete/source:dir
    return "$?"
  fi

  ble/complete/source:tilde; local ext=$?
  ((ext==148||ext==0)) && return "$ext"

  local is_pwd_visited= is_cdpath_generated=
  "${_ble_util_set_declare[@]//NAME/visited}"

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
    ble/complete/util/eval-pathname-expansion "$name$ret"
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
      bleopt complete_menu_style=desc-raw

  # Check PWD next
  # カレントディレクトリが CDPATH に含まれていなかった時に限り通常の候補生成
  if [[ ! $is_pwd_visited ]]; then
    local -a candidates=()
    local ret cand
    ble/complete/source:file/.construct-pathname-pattern "$COMPV"
    ble/complete/util/eval-pathname-expansion "${ret%/}/"
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

blehook/invoke complete_load
blehook complete_load=
return 0
