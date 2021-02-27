#!/bin/bash

function ble/arithmetic/sum {
  IFS=+ eval 'let "ret=$*+0"'
}

## 変数 _ble_line_x
## 変数 _ble_line_y
##   現在の (描画の為に動き回る) カーソル位置を保持します。
_ble_line_x=0 _ble_line_y=0

## 関数 ble-form/goto.draw x y opts
##   現在位置を指定した座標へ移動する制御系列を生成します。
## @param[in] x y
##   移動先のカーソルの座標を指定します。
##   プロンプト原点が x=0 y=0 に対応します。
function ble-form/goto.draw {
  local -i x=$1 y=$2
  local opts=$3

  # Note #D1392: mc (midnight commander) は
  #   sgr0 単体でもプロンプトと勘違いするので、
  #   プロンプト更新もカーソル移動も不要の時は、
  #   sgr0 も含めて何も出力しない。
  [[ :$opts: != *:sgr0:* ]] &&
    ((x==_ble_line_x&&y==_ble_line_y)) && return 0

  ble-edit/draw/put "$_ble_term_sgr0"

  local -i dy=y-_ble_line_y
  if ((dy!=0)); then
    if ((dy>0)); then
      if [[ $MC_SID == $$ ]]; then
        # Note #D1392: mc (midnight commander) の中だと layout が破壊されるので、
        #   必ずしも CUD で想定した行だけ移動できると限らない。
        ble-edit/draw/put.ind "$dy"
      else
        ble-edit/draw/put "${_ble_term_cud//'%d'/$dy}"
      fi
    else
      ble-edit/draw/put "${_ble_term_cuu//'%d'/$((-dy))}"
    fi
  fi

  local -i dx=x-_ble_line_x
  if ((dx!=0)); then
    if ((x==0)); then
      ble-edit/draw/put "$_ble_term_cr"
    elif ((dx>0)); then
      ble-edit/draw/put "${_ble_term_cuf//'%d'/$dx}"
    else
      ble-edit/draw/put "${_ble_term_cub//'%d'/$((-dx))}"
    fi
  fi

  _ble_line_x=$x _ble_line_y=$y
}


## 配列 _ble_form_window_height
##   各パネルの高さを保持する。
##   現在 panel 0 が textarea で panel 1 が info に対応する。
##
##   開始した瞬間にキー入力をすると画面に echo されてしまうので、
##   それを削除するために最初の編集文字列の行数を 1 とする。
_ble_form_window_height=(1 0)

function ble-form/panel#goto.draw {
  local index=$1 x=${2-0} y=${3-0} opts=$4 ret
  ble/arithmetic/sum "${_ble_form_window_height[@]::index}"
  ble-form/goto.draw "$x" $((ret+y)) "$opts"
}
function ble-form/panel#report-cursor-position {
  local index=$1 x=${2-0} y=${3-0} ret
  ble/arithmetic/sum "${_ble_form_window_height[@]::index}"
  ((_ble_line_x=x,_ble_line_y=ret+y))
}

function ble-form/panel#increase-total-height.draw {
  local delta=$1
  ((delta>0)) || return

  local ret
  ble/arithmetic/sum "${_ble_form_window_height[@]}"; local old_total_height=$ret
  # 下に余白を確保
  if ((old_total_height>0)); then
    ble-form/goto.draw 0 $((old_total_height-1)) sgr0
    ble-edit/draw/put.ind "$delta"; ((_ble_line_y+=delta))
  else
    ble-form/goto.draw 0 0 sgr0
    ble-edit/draw/put.ind $((delta-1)); ((_ble_line_y+=delta-1))
  fi
}

function ble-form/panel#set-height.draw {
  local index=$1 new_height=$2
  local delta=$((new_height-_ble_form_window_height[index]))
  ((delta)) || return

  local ret
  if ((delta>0)); then
    # 新しく行を挿入
    ble-form/panel#increase-total-height.draw "$delta"

    ble/arithmetic/sum "${_ble_form_window_height[@]::index+1}"; local ins_offset=$ret
    ble-form/goto.draw 0 "$ins_offset" sgr0
    ble-edit/draw/put.il "$delta"
  else
    # 行を削除
    ble/arithmetic/sum "${_ble_form_window_height[@]::index+1}"; local ins_offset=$ret
    ble-form/goto.draw 0 $((ins_offset+delta)) sgr0
    ble-edit/draw/put.dl $((-delta))
  fi

  ((_ble_form_window_height[index]=new_height))
}

function ble-form/panel#set-height-and-clear.draw {
  local index=$1 new_height=$2
  local old_height=${_ble_form_window_height[index]}
  ((old_height||new_height)) || return

  local ret
  ble-form/panel#increase-total-height.draw $((new_height-old_height))
  ble/arithmetic/sum "${_ble_form_window_height[@]::index}"; local ins_offset=$ret
  ble-form/goto.draw 0 "$ins_offset"
  ((old_height)) && ble-edit/draw/put.dl "$old_height"
  ((new_height)) && ble-edit/draw/put.il "$new_height"

  ((_ble_form_window_height[index]=new_height))
}

function ble-form/panel#clear.draw {
  local index=$1
  local height=${_ble_form_window_height[index]}
  if ((height)); then
    local ret
    ble/arithmetic/sum "${_ble_form_window_height[@]::index}"; local ins_offset=$ret
    ble-form/goto.draw 0 "$ins_offset" sgr0
    if ((height==1)); then
      ble-edit/draw/put "$_ble_term_el2"
    else
      ble-edit/draw/put.dl "$height"
      ble-edit/draw/put.il "$height"
    fi
  fi
}
function ble-form/panel#clear-after.draw {
  local index=$1 x=$2 y=$3
  local height=${_ble_form_window_height[index]}
  ((y<height)) || return

  ble-form/panel#goto.draw "$index" "$x" "$y" sgr0
  ble-edit/draw/put "$_ble_term_el"
  local rest_lines=$((height-(y+1)))
  if ((rest_lines)); then
    ble-edit/draw/put "$_ble_term_ind"
    ble-edit/draw/put.dl "$rest_lines"
    ble-edit/draw/put.il "$rest_lines"
    ble-edit/draw/put "$_ble_term_ri"
  fi
}
