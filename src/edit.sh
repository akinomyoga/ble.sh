#!/bin/bash

# **** sections ****
#
# @line.ps1
# @line.text
# @line.info
# @edit.content
# @edit.ps1
# @textarea
# @textarea.buffer
# @textarea.render
# @widget.clear
# @widget.mark
# @edit.bell
# @edit.insert
# @edit.delete
# @edit.cursor
# @edit.word
# @edit.exec
# @edit.accept
# @history
# @history.widget
# @history.isearch
# @comp
# @bind
# @bind.bind
#
# 現在の ble/canvas/panel 構成
#   0 command-line
#   1 追加入力欄
#   2 infobar

## @bleopt edit_vbell
##   編集時の visible bell の有効・無効を設定します。
## bleopt_edit_vbell=1
##   有効です。
## bleopt_edit_vbell=
##   無効です。
bleopt/declare -v edit_vbell ''

## @bleopt edit_abell
##   編集時の audible bell (BEL 文字出力) の有効・無効を設定します。
## bleopt_edit_abell=1
##   有効です。
## bleopt_edit_abell=
##   無効です。
bleopt/declare -v edit_abell 1

## @bleopt history_lazyload
## bleopt_history_lazyload=1
##   ble-attach 後、初めて必要になった時に履歴の読込を行います。
## bleopt_history_lazyload=
##   ble-attach 時に履歴の読込を行います。
##
## bash-3.1 未満では history -s が思い通りに動作しないので、
## このオプションの値に関係なく ble-attach の時に履歴の読み込みを行います。
bleopt/declare -v history_lazyload 1

## @bleopt delete_selection_mode
##   文字挿入時に選択範囲をどうするかについて設定します。
## bleopt_delete_selection_mode=1 (既定)
##   選択範囲の内容を新しい文字で置き換えます。
## bleopt_delete_selection_mode=
##   選択範囲を解除して現在位置に新しい文字を挿入します。
bleopt/declare -v delete_selection_mode 1

## @bleopt indent_offset
##   シェルのインデント幅を指定します。既定では 4 です。
bleopt/declare -n indent_offset 4

## @bleopt indent_tabs
##   インデントにタブを使用するかどうかを指定します。
##   0 を指定するとインデントに空白だけを用います。
##   それ以外の場合はインデントにタブを使用します。
bleopt/declare -n indent_tabs 1

## @bleopt undo_point
##   undo/redo 実行直後のカーソル位置を設定します。
##
##   undo_point=beg
##     undo/redo によって変化のあった範囲の先頭に移動します。
##   undo_point=end
##     undo/redo によって変化のあった範囲の末端に移動します。
##   その他の時
##     undo/redo 後の状態が記録された時のカーソル位置を復元します。
##
bleopt/declare -v undo_point end

## @bleopt edit_forced_textmap
##   1 が設定されているとき、矩形選択に先立って配置計算を強制します。
##   0 が設定されているとき、配置情報があるときにそれを使い、
##   配置情報がないときは論理行・論理列による矩形選択にフォールバックします。
##
bleopt/declare -n edit_forced_textmap 1

function ble/edit/use-textmap {
  ble/textmap#is-up-to-date && return 0
  ((bleopt_edit_forced_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

## @bleopt edit_line_type
##   行頭・行末への移動などの操作を行う時の行の解釈を指定します。
##   "logical" が設定されている時、論理行で解釈します。
##   つまり編集文字列内の改行文字で区切られた行頭・行末を使用して操作を行います。
##   "graphical" が設定されている時、表示行で解釈します。
##   つまり端末内での現在行の行頭・行末を使用して操作を行います。
bleopt/declare -n edit_line_type logical
function bleopt/check:edit_line_type {
  if [[ $value != logical && $value != graphical ]]; then
    ble/util/print "bleopt edit_line_type: Unexpected value '$value'. 'logical' or 'graphical' is expected." >&2
    return 1
  fi
}

function ble/edit/performs-on-graphical-line {
  [[ $edit_line_type == graphical ]] || return 1
  ble/textmap#is-up-to-date && return 0
  ((bleopt_edit_forced_textmap)) || return 1
  ble/widget/.update-textmap
  return 0
}

bleopt/declare -n info_display top
function bleopt/check:info_display {
  case $value in
  (top)
    [[ $_ble_canvas_panel_vfill == 3 ]] && return 0
    _ble_canvas_panel_vfill=3
    [[ $_ble_attached ]] && ble/canvas/panel/clear
    return 0 ;;
  (bottom)
    [[ $_ble_canvas_panel_vfill == 2 ]] && return 0
    _ble_canvas_panel_vfill=2
    [[ $_ble_attached ]] && ble/canvas/panel/clear
    return 0 ;;
  (*)
    ble/util/print "bleopt: Invalid value for 'info_display': $value"
    return 1 ;;
  esac
}

## プロンプトオプション
bleopt/declare -v prompt_ps1_final ''
bleopt/declare -v prompt_ps1_transient ''
bleopt/declare -v prompt_rps1 ''
bleopt/declare -v prompt_rps1_final ''
bleopt/declare -v prompt_rps1_transient ''
bleopt/declare -v prompt_xterm_title  ''
bleopt/declare -v prompt_screen_title ''
bleopt/declare -v prompt_term_status  ''
# obsoleted options
bleopt/declare -o rps1 prompt_rps1
bleopt/declare -o rps1_transient prompt_rps1_transient

## @bleopt prompt_eol_mark
bleopt/declare -v prompt_eol_mark $'\e[94m[ble: EOF]\e[m'

bleopt/declare -v prompt_status_line  ''
bleopt/declare -n prompt_status_align $'justify=\r'
ble/color/defface prompt_status_line fg=231,bg=240

function bleopt/check:prompt_status_align {
  case $value in
  (left|right|center|justify|justify=?*)
    ble/prompt/unit#clear _ble_prompt_status hash
    return 0 ;;
  (*)
    ble/util/print "bleopt prompt_status_align: unsupported value: '$value'" >&2
    return 1 ;;
  esac
}

## @bleopt internal_exec_type (内部使用)
##   コマンドの実行の方法を指定します。
##
##   internal_exec_type=exec [廃止]
##     関数内で実行します (削除されました)
##   internal_exec_type=gexec
##     グローバルな文脈で実行します (新しい方法です)
##
## 要件: 関数 ble-edit/exec:$bleopt_internal_exec_type/process が定義されていること。
bleopt/declare -n internal_exec_type gexec
function bleopt/check:internal_exec_type {
  if ! ble/is-function "ble-edit/exec:$value/process"; then
    ble/util/print "bleopt: Invalid value internal_exec_type='$value'. A function 'ble-edit/exec:$value/process' is not defined." >&2
    return 1
  fi
}

## @bleopt internal_suppress_bash_output (内部使用)
##   bash 自体の出力を抑制するかどうかを指定します。
## bleopt_internal_suppress_bash_output=1
##   抑制します。bash のエラーメッセージは visible-bell で表示します。
## bleopt_internal_suppress_bash_output=
##   抑制しません。bash のメッセージは全て端末に出力されます。
##   これはデバグ用の設定です。bash の出力を制御するためにちらつきが発生する事があります。
##   bash-3 ではこの設定では C-d を捕捉できません。
bleopt/declare -v internal_suppress_bash_output 1

## @bleopt internal_ignoreeof_trap (内部使用)
##   bash-3.0 の時に使用します。C-d を捕捉するのに用いるメッセージです。
##   これは自分の bash の設定に合わせる必要があります。
bleopt/declare -n internal_ignoreeof_trap 'Use "exit" to leave the shell.'

## @bleopt allow_exit_with_jobs
##   この変数に空文字列が設定されている時、
##   ジョブが残っている時には ble/widget/exit からシェルは終了しません。
##   この変数に空文字列以外が設定されている時、
##   ジョブがある場合でも条件を満たした時に exit を実行します。
##   停止中のジョブがある場合、または、shopt -s checkjobs かつ実行中のジョブが存在する時は、
##   二回連続で同じ widget から exit を呼び出した時にシェルを終了します。
##   それ以外の場合は常にシェルを終了します。
##   既定値は空文字列です。
bleopt/declare -v allow_exit_with_jobs ''

## @bleopt history_share
##   この変数に空文字列が設定されている時、履歴を共有します。
bleopt/declare -v history_share ''


## @bleopt accept_line_threshold
##   編集関数 accept-single-line-or-newline の単一行モードにおける振る舞いを制御します。
##   この変数が負の整数の時、常にコマンドを実行します。
##   この変数が 0 の時、ユーザの入力がある場合は改行を挿入して複数行モードに入ります。
##   正の整数 n の時、未処理のユーザ入力が n 以上の時に改行を挿入して複数行モードに入ります。
bleopt/declare -v accept_line_threshold 5

## @bleopt exec_errexit_mark
##   終了ステータスが非零の時に表示するマークの書式を指定します。
##   この変数が空の時、終了ステータスは表示しません。
bleopt/declare -v exec_errexit_mark $'\e[91m[ble: exit %d]\e[m'

## @bleopt line_limit_length
##   一括挿入時のコマンドライン文字数の上限を指定します。
##   0以下の値は文字数に制限を与えない事を示します。
bleopt/declare -v line_limit_length 10000

## @bleopt line_limit_type
##   一括挿入で文字数を超過した時の動作を指定します。
bleopt/declare -v line_limit_type none

# 
#------------------------------------------------------------------------------
# **** Application ****

_ble_app_render_mode=panel
function ble/application/.set-up-render-mode {
  [[ $1 == "$_ble_app_render_mode" ]] && return 0
  case $1 in
  (panel)
    ble/term/leave-altscr
    ble/canvas/panel/invalidate ;;
  (forms:*)
    ble/term/enter-altscr
    ble/util/buffer "$_ble_term_clear"
    ble/util/buffer $'\e[H'
    _ble_canvas_x=0 _ble_canvas_y=0 ;;
  (*)
    ble/util/print "ble/edit: unrecognized render mode '$1'."
    return 1 ;;
  esac
}
function ble/application/push-render-mode {
  ble/application/.set-up-render-mode "$1" || return 1
  ble/array#unshift _ble_app_render_mode "$1"
}
function ble/application/pop-render-mode {
  [[ ${_ble_app_render_mode[1]} ]] || return 1
  ble/application/.set-up-render-mode "${_ble_app_render_mode[1]}"
  ble/array#shift _ble_app_render_mode
}
function ble/application/render {
  local render=$_ble_app_render_mode
  case $render in
  (panel)
    ble/edit/leave-command-layout # ble/edit 特有
    ble/canvas/panel/render ;;
  (forms:*)
    ble/forms/render "${render#*:}" ;;
  esac
  ble/util/buffer.flush >&2
}

# canvas.sh 設定

_ble_canvas_panel_focus=0
_ble_canvas_panel_class=(ble/textarea ble/textarea ble/edit/info ble/prompt/status)
_ble_canvas_panel_vfill=3

_ble_edit_layout=normal
function ble/edit/enter-command-layout {
  [[ $_ble_edit_layout == command ]] && return 0
  _ble_edit_layout=command
  ble/edit/info/hide
  ble/prompt/status#collapse
}
function ble/edit/leave-command-layout {
  _ble_edit_layout=normal
  ble/edit/info/reveal
}

# 
#------------------------------------------------------------------------------
# **** ble/prompt/status ****                                    @prompt.status

_ble_prompt_status_panel=3
_ble_prompt_status_dirty=
_ble_prompt_status_data=()
_ble_prompt_status_bbox=()

function ble/prompt/status#panel::invalidate {
  _ble_prompt_status_dirty=1
}
function ble/prompt/status#panel::render {
  [[ $_ble_prompt_status_dirty ]] || return 0
  _ble_prompt_status_dirty=

  # 表示内容がない場合は何もせず抜ける (高さは既に調整されている前提)
  local index=$1
  local height; ble/prompt/status#panel::getHeight "$index"
  [[ ${height#*:} == 1 ]] || return 0

  local -a DRAW_BUFF=()

  # 高さが一致していない場合は取り敢えず再配置を要求してみる。
  # 高さを取得できなければ諦める。
  height=$3
  if ((height!=1)); then
    ble/canvas/panel/reallocate-height.draw
    ble/canvas/bflush.draw
    height=${_ble_canvas_panel_height[index]}
    ((height==0)) && return 0
  fi

  local esc=${_ble_prompt_status_data[10]}
  if [[ $esc ]]; then
    local prox=${_ble_prompt_status_data[11]}
    local proy=${_ble_prompt_status_data[12]}
    ble/canvas/panel#goto.draw "$_ble_prompt_status_panel"
    ble/canvas/panel#put.draw "$_ble_prompt_status_panel" "$esc" "$prox" "$proy"
  else
    ble/canvas/panel#clear.draw "$_ble_prompt_status_panel"
  fi
  ble/canvas/bflush.draw
}
function ble/prompt/status#panel::getHeight {
  if [[ $_ble_edit_layout == command ]]; then
    height=0:0
  elif [[ ${_ble_prompt_status_data[10]} ]]; then
    height=0:1
  else
    height=0:0
  fi
}
function ble/prompt/status#panel::onHeightChange {
  ble/prompt/status#panel::invalidate
}
function ble/prompt/status#collapse {
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_prompt_status_panel" 0
  ble/canvas/bflush.draw
}

# 
#------------------------------------------------------------------------------
# **** prompt ****                                                    @line.ps1

## @var _ble_prompt_version
##   ble/prompt/update でのプロンプト更新の度にインクリメントする変数
_ble_prompt_hash=
_ble_prompt_version=0

## called by ble-edit/initialize
function ble/prompt/initialize {
  # hostname
  _ble_prompt_const_H=${HOSTNAME}
  if local rex='^[0-9]+(\.[0-9]){3}$'; [[ $HOSTNAME =~ $rex ]]; then
    # IPv4 の形式の場合には省略しない
    _ble_prompt_const_h=$HOSTNAME
  else
    _ble_prompt_const_h=${HOSTNAME%%.*}
  fi

  # tty basename
  local tmp
  if ((_ble_bash>=40400)); then
    tmp='\l' _ble_prompt_const_l=${tmp@P}
  else
    ble/util/assign tmp 'ble/bin/tty 2>/dev/null'
    _ble_prompt_const_l=${tmp##*/}
  fi

  # command name
  _ble_prompt_const_s=${0##*/}

  # user
  _ble_prompt_const_u=${USER}

  # bash versions
  ble/util/sprintf _ble_prompt_const_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  ble/util/sprintf _ble_prompt_const_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if [[ $EUID -eq 0 ]]; then
    _ble_prompt_const_root='#'
  else
    _ble_prompt_const_root='$'
  fi

  if [[ $OSTYPE == cygwin* ]]; then
    local windir=/cygdrive/c/Windows
    if [[ $WINDIR == [a-zA-Z]:\\* ]]; then
      local bsl='\' sl=/
      local c=${WINDIR::1} path=${WINDIR:3}
      if [[ $c == [A-Z] ]]; then
        if ((_ble_bash>=40000)); then
          c=${c,?}
        else
          local ret
          ble/util/s2c "$c"
          ble/util/c2s $((ret+32))
          c=$ret
        fi
      fi
      windir=/cygdrive/$c/${path//$bsl/$sl}
    fi

    if [[ -e $windir && -w $windir ]]; then
      _ble_prompt_const_root='#'
    fi
  elif [[ $OSTYPE == msys* ]]; then
    # msys64/etc/bash.bashrc に倣う
    if ble/bin#has id getent; then
      local id getent
      ble/util/assign id 'id -G'
      ble/util/assign getent 'getent -w group S-1-16-12288'
      ble/string#split getent : "$getent"
      [[ " $id " == *" ${getent[1]} "* ]] &&
        _ble_prompt_const_root='#'
    fi
  fi
}

## @arr PREFIX_data
##   プロンプトに表示するデータの単位です。
##   他のデータに対する依存性等を管理する機能を有します。
##
##   @var PREFIX_data[0]    version
##     prompt 情報の更新回数を保持します。
##   @var PREFIX_data[1]    hashref
##   @var PREFIX_data[2]    hash
##     依存性追跡に使われる変数です。
##
## @fn ble/prompt/unit#update TYPE PREFIX ARGS...
##   依存性を追跡しつつデータを更新します。
##
##   @fn[in] ble/prompt/unit:TYPE/update
##     データの更新をします。データに変化があった場合に 0 を返します。
##     それ以外の場合に 1 を返します。
##
##     @var[in]     prompt_unit
##     @var[in,out] prompt_unit_changed
##     @var[in]     prompt_unit_expired
##     @var[in,out] prompt_hashref_dep
##     @var[in,out] prompt_hashref_var
##
##   @var[in,opt]  prompt_hashref_base
##
##   @var[in] prompt_unit
##     ble/prompt/unit:PREFIX/update が入れ子で呼び出される時に設定される変数です。
##     親プロンプトの PREFIX を保持します。
##     prompt 間の依存性を追跡する為に呼び出し元の以下の変数を更新します。
##
##     @var[ref,opt] prompt_hashref_dep
##
function ble/prompt/unit#update {
  local unit=$1

  local prompt_unit_changed=
  local prompt_unit_expired=

  local ohashref=${unit}_data[1]; ohashref=${!ohashref-}
  if [[ ! $ohashref ]]; then
    prompt_unit_expired=1
  else
    ble/prompt/unit#update/.update-dependencies "$ohashref"
    local ohash=${unit}_data[2]; ohash=${!ohash}
    builtin eval -- "nhash=\"$ohashref\"" 2>/dev/null
    [[ $nhash != "$ohash" ]] && prompt_unit_expired=1
  fi

  if [[ $prompt_unit_expired ]]; then
    local prompt_unit=$unit
    local prompt_hashref_dep= # プロンプト間依存性
    local prompt_hashref_var= # 変数に対する依存性

    ble/prompt/unit:"$unit"/update "$unit" &&
      ((prompt_unit_changed=1,${unit}_data[0]++))

    local hashref=${prompt_hashref_base-'$_ble_prompt_version'}:$prompt_hashref_dep:$prompt_hashref_var
    builtin eval -- "${unit}_data[1]=\$hashref"
    builtin eval -- "${unit}_data[2]=\"$hashref\"" 2>/dev/null
    ble/util/unlocal prompt_unit prompt_hashref_dep
  fi

  # 呼び出し元 prompt_hashref_dep の更新 (依存性登録)
  if [[ $prompt_unit ]]; then
    local ref1='$'$unit'_data'
    [[ ,$prompt_hashref_dep, != *,"$ref1",* ]] &&
      prompt_hashref_dep=$prompt_hashref_dep${prompt_hashref_dep:+,}$ref1
  fi
  [[ $prompt_unit_changed ]]
}
function ble/prompt/unit#update/.update-dependencies {
  local ohashref=$1
  local otree=${ohashref#*:}; otree=${otree%%:*}
  if [[ $otree ]]; then
    ble/string#split otree , "$otree"

    local prompt_unit= # 依存関係の登録はしない
    local child
    for child in "${otree[@]}"; do
      [[ $child == '$'?*'_data' ]] || continue
      child=${child:1:${#child}-6}
      ble/is-function ble/prompt/unit:"$child"/update &&
        ble/prompt/unit#update "$child"
    done
  fi
}
function ble/prompt/unit#clear {
  builtin eval -- "${prefix}_data[2]="
}

function ble/prompt/unit/assign {
  local var=$1 value=$2
  [[ $value == "${!var}" ]] && return 1
  prompt_unit_changed=1
  builtin eval -- "$var=\$value"
}

## @fn ble/prompt/unit/add-hash hashref
##   プロンプトの更新検出に用いるシェル単語を指定します。
function ble/prompt/unit/add-hash {
  [[ $prompt_unit && ,$prompt_hashref_var, != *,"$1",* ]] &&
    prompt_hashref_var=$prompt_hashref_var${prompt_hashref_var:+,}$1
  return 0
}

## @var _ble_prompt_ps1_data
## @var _ble_prompt_rps1_data
## @var _ble_prompt_status_data
## @var _ble_prompt_xterm_title_data
## @var _ble_prompt_screen_title_data
## @var _ble_prompt_term_status_data
##   構築した prompt の情報をキャッシュします。
##
##   @var PREFIX_data[3..5] x y g
##     prompt を表示し終わった時のカーソルの位置と描画属性を表します。
##   @var PREFIX_data[6..7] lc lg
##     bleopt_internal_suppress_bash_output= の時、
##     prompt を表示し終わった時の左側にある文字とその描画属性を表します。
##     それ以外の時はこの値は使われません。
##   @var PREFIX_data[8]    ps1out (esc)
##     prompt を表示する為に出力する制御シーケンスを含んだ文字列です。
##   @var PREFIX_data[9]    trace_hash
##     COLUMNS:ps1esc の形式の文字列です。
##     調整前の ps1out を格納します。
##     ps1out の計算 (trace) を省略する為に使用します。
##
##   @var PREFIX_data[10...] tailored
##     ps1out の結果を加工して得られるデータ。
##     加工だけを後で再実行する事もあるので統一的に管理する。
##
_ble_prompt_ps1_dirty=
_ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 '' '')
_ble_prompt_rps1_dirty=
_ble_prompt_rps1_data=()
_ble_prompt_rps1_gbox=()
_ble_prompt_rps1_shown=

_ble_prompt_xterm_title_dirty=
_ble_prompt_xterm_title_data=()
_ble_prompt_screen_title_dirty=
_ble_prompt_screen_title_data=()
_ble_prompt_term_status_dirty=
_ble_prompt_term_status_data=()

## @fn ble/prompt/print text
##   プロンプト構築中に呼び出す関数です。
##   指定された文字列を、後の評価に対するエスケープをして出力します。
##   @param[in] text
##     エスケープされる文字列を指定します。
##   @var[out]  DRAW_BUFF[]
##     出力先の配列です。
function ble/prompt/print {
  local text=$1 a b
  if [[ ! $prompt_noesc && $text == *['$\"`']* ]]; then
    a='\' b='\\' text=${text//"$a"/$b}
    a='$' b='\$' text=${text//"$a"/$b}
    a='"' b='\"' text=${text//"$a"/$b}
    a='`' b='\`' text=${text//"$a"/$b}
  fi
  ble/canvas/put.draw "$text"
}

## @fn ble/prompt/process-prompt-string prompt_string
##   プロンプト構築中に呼び出す関数です。
##   指定した引数を PS1 と同様の形式と解釈して処理します。
##   @param[in] prompt_string
##   @arr[in,out] DRAW_BUFF
function ble/prompt/process-prompt-string {
  local ps1=$1
  local i=0 iN=${#ps1}
  local rex_letters='^[^\]+|\\$'
  while ((i<iN)); do
    local tail=${ps1:i}
    if [[ $tail == '\'?* ]]; then
      ble/prompt/.process-backslash
    elif [[ $tail =~ $rex_letters ]]; then
      ble/canvas/put.draw "$BASH_REMATCH"
      ((i+=${#BASH_REMATCH}))
    else
      # ? ここには本来来ないはず。
      ble/canvas/put.draw "${tail::1}"
      ((i++))
    fi
  done
}
## @fn ble/prompt/.process-backslash
##   @var[in]     tail
##   @arr[in.out] DRAW_BUFF
function ble/prompt/.process-backslash {
  ((i+=2))

  # \\ の次の文字
  local c=${tail:1:1} pat='][#!$\'
  if [[ $c == ["$pat"] ]]; then
    case "$c" in
    (\[) ble/canvas/put.draw $'\001' ;; # \[ \] は後処理の為、適当な識別用の文字列を出力する。
    (\]) ble/canvas/put.draw $'\002' ;;
    ('#') # コマンド番号 (本当は history に入らない物もある…)
      ble/prompt/unit/add-hash '$_ble_edit_CMD'
      ble/canvas/put.draw "$_ble_edit_CMD" ;;
    (\!) # 編集行の履歴番号
      local count
      ble/history/get-count -v count
      ble/canvas/put.draw $((count+1)) ;;
    ('$') # # or $
      ble/prompt/print "$_ble_prompt_const_root" ;;
    (\\)
      # '\\' は '\' と出力された後に、更に "" 内で評価された時に次の文字をエスケープする。
      # 例えば '\\$' は一旦 '\$' となり、更に展開されて '$' となる。'\\\\' も同様に '\' になる。
      ble/canvas/put.draw '\' ;;
    esac
  elif ble/is-function ble/prompt/backslash:"$c"; then
    ble/function#try ble/prompt/backslash:"$c"
  elif ble/is-function ble-edit/prompt/backslash:"$c"; then # deprecated name
    ble/function#try ble-edit/prompt/backslash:"$c"
  else
    # その他の文字はそのまま出力される。
    # - '\"' '\`' はそのまま出力された後に "" 内で評価され '"' '`' となる。
    # - それ以外の場合は '\?' がそのまま出力された後に、"" 内で評価されても変わらず '\?' 等となる。
    ble/canvas/put.draw "\\$c"
  fi
}

## @fn[custom] ble/prompt/backslash:*
##   プロンプト PS1 内で使用するバックスラッシュシーケンスを定義します。
##   内部では ble/canvas/put.draw escaped_text もしくは
##   ble/prompt/print unescaped_text を用いて
##   シーケンスの展開結果を追記します。
##
##   @exit
##     対応する文字列を出力した時に成功します。
##     0 以外の終了ステータスを返した場合、
##     シーケンスが処理されなかったと見做され、
##     呼び出し元によって \c (c: 文字) が代わりに書き込まれます。
##
function ble/prompt/backslash:0 { # 8進表現
  local rex='^\\[0-7]{1,3}'
  if [[ $tail =~ $rex ]]; then
    local seq=${BASH_REMATCH[0]}
    ((i+=${#seq}-2))
    builtin eval "c=\$'$seq'"
  fi
  ble/prompt/print "$c"
  return 0
}
function ble/prompt/backslash:1 { ble/prompt/backslash:0; }
function ble/prompt/backslash:2 { ble/prompt/backslash:0; }
function ble/prompt/backslash:3 { ble/prompt/backslash:0; }
function ble/prompt/backslash:4 { ble/prompt/backslash:0; }
function ble/prompt/backslash:5 { ble/prompt/backslash:0; }
function ble/prompt/backslash:6 { ble/prompt/backslash:0; }
function ble/prompt/backslash:7 { ble/prompt/backslash:0; }
function ble/prompt/backslash:a { # 0 BEL
  ble/canvas/put.draw ""
  return 0
}
function ble/prompt/backslash:e {
  ble/canvas/put.draw $'\e'
  return 0
}
function ble/prompt/backslash:n {
  ble/canvas/put.draw $'\n'
  return 0
}
function ble/prompt/backslash:r {
  ble/canvas/put.draw "$_ble_term_cr"
  return 0
}

_ble_prompt_cache_vars=(
  prompt_cache_d
  prompt_cache_t
  prompt_cache_A
  prompt_cache_T
  prompt_cache_at
  prompt_cache_j
  prompt_cache_wd
)

function ble/prompt/backslash:d { # ? 日付
  [[ $prompt_cache_d ]] || ble/util/strftime -v prompt_cache_d '%a %b %d'
  ble/prompt/print "$prompt_cache_d"
  return 0
}
function ble/prompt/backslash:t { # 8 時刻
  [[ $prompt_cache_t ]] || ble/util/strftime -v prompt_cache_t '%H:%M:%S'
  ble/prompt/print "$prompt_cache_t"
  return 0
}
function ble/prompt/backslash:A { # 5 時刻
  [[ $prompt_cache_A ]] || ble/util/strftime -v prompt_cache_A '%H:%M'
  ble/prompt/print "$prompt_cache_A"
  return 0
}
function ble/prompt/backslash:T { # 8 時刻
  [[ $prompt_cache_T ]] || ble/util/strftime -v prompt_cache_T '%I:%M:%S'
  ble/prompt/print "$prompt_cache_T"
  return 0
}
function ble/prompt/backslash:@ { # ? 時刻
  [[ $prompt_cache_at ]] || ble/util/strftime -v prompt_cache_at '%I:%M %p'
  ble/prompt/print "$prompt_cache_at"
  return 0
}
function ble/prompt/backslash:D {
  local rex='^\\D\{([^{}]*)\}' cache_D
  if [[ $tail =~ $rex ]]; then
    ble/util/strftime -v cache_D "${BASH_REMATCH[1]}"
    ble/prompt/print "$cache_D"
    ((i+=${#BASH_REMATCH}-2))
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:h { # = ホスト名
  ble/prompt/print "$_ble_prompt_const_h"
  return 0
}
function ble/prompt/backslash:H { # = ホスト名
  ble/prompt/print "$_ble_prompt_const_H"
  return 0
}
function ble/prompt/backslash:j { #   ジョブの数
  if [[ ! $prompt_cache_j ]]; then
    local joblist
    ble/util/joblist
    prompt_cache_j=${#joblist[@]}
  fi
  ble/canvas/put.draw "$prompt_cache_j"
  return 0
}
function ble/prompt/backslash:l { #   tty basename
  ble/prompt/print "$_ble_prompt_const_l"
  return 0
}
function ble/prompt/backslash:s { # 4 "bash"
  ble/prompt/print "$_ble_prompt_const_s"
  return 0
}
function ble/prompt/backslash:u { # = ユーザ名
  ble/prompt/print "$_ble_prompt_const_u"
  return 0
}
function ble/prompt/backslash:v { # = bash version %d.%d
  ble/prompt/print "$_ble_prompt_const_v"
  return 0
}
function ble/prompt/backslash:V { # = bash version %d.%d.%d
  ble/prompt/print "$_ble_prompt_const_V"
  return 0
}
function ble/prompt/backslash:w { # PWD
  ble/prompt/unit/add-hash '$PWD'
  ble/prompt/.update-working-directory
  ble/prompt/print "$prompt_cache_wd"
  return 0
}
function ble/prompt/backslash:W { # PWD短縮
  ble/prompt/unit/add-hash '$PWD'
  if [[ ! ${PWD//'/'} ]]; then
    ble/prompt/print "$PWD"
  else
    ble/prompt/.update-working-directory
    ble/prompt/print "${prompt_cache_wd##*/}"
  fi
  return 0
}

# \q{name} (ble.sh extension)
function ble/prompt/backslash:q {
  local rex='^\{([^{}]*)\}'
  if [[ ${tail:2} =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    ((i+=${#rematch}))
    local word; ble/string#split-words word "${BASH_REMATCH[1]}"
    if [[ $word ]] && ble/is-function ble/prompt/backslash:"$word"; then
      ble/util/joblist.check
      ble/prompt/backslash:"${word[@]}"; local ext=$?
      ble/util/joblist.check ignore-volatile-jobs
      return "$?"
    else
      if [[ ! $word ]]; then
        ble/term/visible-bell "ble/prompt: invalid sequence \\q$rematch"
      elif ! ble/is-function ble/prompt/backslash:"$word"; then
        ble/term/visible-bell "ble/propmt: undefined named sequence \\q{$word}"
      fi
      ble/prompt/print "\\q$BASH_REMATCH"
      return 2
    fi
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:g {
  local rex='^\{([^{}]*)\}'
  if [[ ${tail:2} =~ $rex ]]; then
    ((i+=${#BASH_REMATCH}))
    local ret
    ble/color/gspec2g "${BASH_REMATCH[1]}"
    ble/color/g2sgr-ansi "$ret"
    ble/prompt/print "$ret"
  else
    ble/prompt/print "\\$c"
  fi
  return 0
}
function ble/prompt/backslash:position {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local fmt=${1:-'(%s,%s)'} pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/util/sprintf pos "$fmt" $((pos[1]+1)) $((pos[0]+1))
  ble/prompt/print "$pos"
}
function ble/prompt/backslash:row {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/prompt/print $((pos[1]+1))
}
function ble/prompt/backslash:column {
  ((_ble_textmap_dbeg>=0)) && ble/widget/.update-textmap
  local pos
  ble/prompt/unit/add-hash '${_ble_textmap_pos[_ble_edit_ind]}'
  ble/string#split-words pos "${_ble_textmap_pos[_ble_edit_ind]}"
  ble/prompt/print $((pos[0]+1))
}
function ble/prompt/backslash:point {
  ble/prompt/unit/add-hash '$_ble_edit_ind'
  ble/prompt/print "$_ble_edit_ind"
}
function ble/prompt/backslash:mark {
  ble/prompt/unit/add-hash '$_ble_edit_mark'
  ble/prompt/print "$_ble_edit_mark"
}
function ble/prompt/backslash:history-index {
  ble/prompt/unit/add-hash '$_ble_history_INDEX'
  ble/canvas/put.draw $((_ble_history_INDEX+1))
}
function ble/prompt/backslash:history-percentile {
  ble/prompt/unit/add-hash '$_ble_history_INDEX'
  ble/prompt/unit/add-hash '$_ble_history_COUNT'
  local index=$_ble_history_INDEX
  local count=$_ble_history_COUNT
  ((count||count++))
  ble/canvas/put.draw "$((index*100/count))%"
}

## @fn ble/prompt/.update-working-directory
##   @var[in,out] prompt_cache_wd
function ble/prompt/.update-working-directory {
  [[ $prompt_cache_wd ]] && return 0

  if [[ ! ${PWD//'/'} ]]; then
    prompt_cache_wd=$PWD
    return 0
  fi

  local head= body=${PWD%/}
  if [[ $body == "$HOME" ]]; then
    prompt_cache_wd='~'
    return 0
  elif [[ $body == "$HOME"/* ]]; then
    head='~/'
    body=${body#"$HOME"/}
  fi

  if [[ $PROMPT_DIRTRIM ]]; then
    local dirtrim=$((PROMPT_DIRTRIM))
    local pat='[^/]'
    local count=${body//$pat}
    if ((${#count}>=dirtrim)); then
      local ret
      ble/string#repeat '/*' "$dirtrim"
      local omit=${body%$ret}
      ((${#omit}>3)) &&
        body=...${body:${#omit}}
    fi
  fi

  prompt_cache_wd=$head$body
}

function ble/prompt/.escape/check-double-quotation {
  if [[ $tail == '"'* ]]; then
    if [[ ! $nest ]]; then
      out=$out'\"'
      tail=${tail:1}
    else
      out=$out'"'
      tail=${tail:1}
      nest=\"$nest
      ble/prompt/.escape/update-rex_skip
    fi
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-command-substitution {
  if [[ $tail == '$('* ]]; then
    out=$out'$('
    tail=${tail:2}
    nest=')'$nest
    ble/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-parameter-expansion {
  if [[ $tail == '${'* ]]; then
    out=$out'${'
    tail=${tail:2}
    nest='}'$nest
    ble/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/check-incomplete-quotation {
  if [[ $tail == '`'* ]]; then
    local rex='^`([^\`]|\\.)*\\$'
    [[ $tail =~ $rex ]] && tail=$tail'\'
    out=$out$tail'`'
    tail=
    return 0
  elif [[ $nest == ['})']* && $tail == \'* ]]; then
    out=$out$tail$q
    tail=
    return 0
  elif [[ $nest == ['})']* && $tail == \$\'* ]]; then
    local rex='^\$'$q'([^\'$q']|\\.)*\\$'
    [[ $tail =~ $rex ]] && tail=$tail'\'
    out=$out$tail$q
    tail=
    return 0
  elif [[ $tail == '\' ]]; then
    out=$out'\\'
    tail=
    return 0
  else
    return 1
  fi
}
function ble/prompt/.escape/update-rex_skip {
  if [[ $nest == \)* ]]; then
    rex_skip=$rex_skip_paren
  elif [[ $nest == \}* ]]; then
    rex_skip=$rex_skip_brace
  else
    rex_skip=$rex_skip_dquot
  fi
}
function ble/prompt/.escape {
  local tail=$1 out= nest=

  # 地の文の " だけをエスケープする。

  local q=\'
  local rex_bq='`([^\`]|\\.)*`'
  local rex_sq=$q'[^'$q']*'$q'|\$'$q'([^\'$q']|\\.)*'$q

  local rex_skip
  local rex_skip_dquot='^([^\"$`]|'$rex_bq'|\\.)+'
  local rex_skip_brace='^([^\"$`'$q'}]|'$rex_bq'|'$rex_sq'|\\.)+'
  local rex_skip_paren='^([^\"$`'$q'()]|'$rex_bq'|'$rex_sq'|\\.)+'
  ble/prompt/.escape/update-rex_skip

  while [[ $tail ]]; do
    if [[ $tail =~ $rex_skip ]]; then
      out=$out$BASH_REMATCH
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $nest == ['})"']* && $tail == "${nest::1}"* ]]; then
      out=$out${nest::1}
      tail=${tail:1}
      nest=${nest:1}
      ble/prompt/.escape/update-rex_skip
    elif [[ $nest == \)* && $tail == \(* ]]; then
      out=$out'('
      tail=${tail:1}
      nest=')'$nest
    elif ble/prompt/.escape/check-double-quotation; then
      continue
    elif ble/prompt/.escape/check-command-substitution; then
      continue
    elif ble/prompt/.escape/check-parameter-expansion; then
      continue
    elif ble/prompt/.escape/check-incomplete-quotation; then
      continue
    else
      out=$out${tail::1}
      tail=${tail:1}
    fi
  done
  ret=$out$nest
}
## @fn ble/prompt/.get-keymap-for-current-mode
##   @var[out] keymap
function ble/prompt/.get-keymap-for-current-mode {
  ble/prompt/unit/add-hash '$_ble_decode_keymap,${_ble_decode_keymap_stack[*]}'

  keymap=$_ble_decode_keymap
  local index=${#_ble_decode_keymap_stack}
  while :; do
    case $keymap in (vi_?map|emacs) return ;; esac
    ((--index<0)) && break
    keymap=${_ble_decode_keymap_stack[index]}
  done
}
## @fn ble/prompt/.instantiate ps opts [x0 y0 g0 lc0 lg0 esc0 trace_hash0]
##
##   @var[out] x y g
##     プロンプトの描画開始点を指定します。
##     プロンプトを描画した後の位置を返します。
##   @var[out] lc lg
##     bleopt_internal_suppress_bash_output= の際に、
##     描画開始点の左の文字コードを指定します。
##     描画終了点の左の文字コードが分かる場合にそれを返します。
##   @var[out] esc
##     プロンプトを描画する為の文字列を返します。
##   @var[out] trace_hash
##
##   @var[in,out] x1 x2 y1 y2
##     opts に measure-bbox を指定した時。
##   @var[in,out] "${_ble_prompt_cache_vars[@]}"
##   @var[in,out] prompt_rows prompt_cols
##
function ble/prompt/.instantiate {
  trace_hash= esc= x=0 y=0 g=0 lc=32 lg=0
  local ps=$1 opts=$2 x0=$3 y0=$4 g0=$5 lc0=$6 lg0=$7 esc0=$8 trace_hash0=$9
  [[ ! $ps ]] && return 0

  local expanded=
  local chars_safe_esc='][0-7aenrdtAT@DhHjlsuvV!$\wW'
  if ((_ble_bash>=40400)) && [[ $ps != *'\'[!"$chars_safe_esc"]* ]]; then
    [[ $ps == *'\'[wW]* ]] && ble/prompt/unit/add-hash '$PWD'
    BASH_COMMAND=$_ble_edit_exec_BASH_COMMAND \
                builtin eval 'expanded=${ps@P}'

  else
    # 展開設定
    local prompt_noesc=
    shopt -q promptvars &>/dev/null || prompt_noesc=1

    # 1. PS1 に含まれる \c を処理する
    local -a DRAW_BUFF=()
    ble/prompt/process-prompt-string "$ps"
    local processed; ble/canvas/sflush.draw -v processed

    # 2. PS1 に含まれる \\ や " をエスケープし、
    #   eval して各種シェル展開を実行する。
    if [[ ! $prompt_noesc ]]; then
      local ret
      ble/prompt/.escape "$processed"; local escaped=$ret
      expanded=${trace_hash0#*:} # Note: これは次行が失敗した時の既定値
      ble-edit/exec/.setexit "$_ble_edit_exec_lastarg"
      BASH_COMMAND=$_ble_edit_exec_BASH_COMMAND \
                  builtin eval "expanded=\"$escaped\""
    else
      expanded=$processed
    fi
  fi

  if [[ :$opts: == *:show-mode-in-prompt:* ]]; then
    if ble/util/test-rl-variable show-mode-in-prompt; then
      local keymap; ble/prompt/.get-keymap-for-current-mode

      local ret=
      case $keymap in
      (vi_imap) ble/util/read-rl-variable vi-ins-mode-string ;;
      (vi_[noxs]map) ble/util/read-rl-variable vi-cmd-mode-string ;;
      (emacs) ble/util/read-rl-variable emacs-mode-string ;;
      esac
      [[ $ret ]] && expanded=$expanded$ret
    fi
  fi

  # 3. 端末への出力を構成する
  if [[ :$opts: == *:no-trace:* ]]; then
    # Note: "ESC k ... ESC \" 等を対象とするプロンプト文字列は trace 不要
    x=0 y=0 g=0 lc=32 lg=0
    esc=$expanded
  elif
    local rows=${prompt_rows:-${LINES:-25}}
    local cols=${prompt_cols:-${COLUMNS:-80}}
    trace_hash=$opts:$rows,$cols:$expanded
    [[ $trace_hash != "$trace_hash0" ]]
  then
    local trace_opts=$opts:prompt
    [[ $bleopt_internal_suppress_bash_output ]] || trace_opts=$trace_opts:left-char
    x=0 y=0 g=0 lc=32 lg=0
    LINES=$rows COLUMNS=$cols ble/canvas/trace "$expanded" "$trace_opts"; local traced=$ret
    ((lc<0&&(lc=0)))
    esc=$traced
    return 0
  else
    x=$x0 y=$y0 g=$g0 lc=$lc0 lg=$lg0
    esc=$esc0
    return 2
  fi
}

## @fn ble/prompt/unit:{section}/clear prefix type
##   プロンプト内容の再計算を要求。
##   以前の内容と一致したら付属処理は省略。
##
##   @param[in,opt] type
##     hash ... hash 消去     (プロンプト内容の再計算を実施)
##     tail ... tail 情報消去 (プロンプト内容計算後の付加処理を再実施)
##     draw ... dirty 設定    (プロンプト内容の再描画)
##     all  ... 全消去        (全て再計算)
##
function ble/prompt/unit:{section}/clear {
  local prefix=$1 type=${2:-hash:draw}
  [[ :$type: == *:hash:* ]] &&
    builtin eval -- "${prefix}_data[2]="
  [[ :$type: == *:tail:* ]] &&
    builtin eval -- "${prefix}_data=(\"\${${prefix}_data[@]::10}\")"
  [[ :$type: == *:draw:* ]] &&
    builtin eval -- "${prefix}_dirty=1"
  [[ :$type: == *:all:* ]] &&
    builtin eval -- "${prefix}_data=(\"\${${prefix}_data[0]}\")"
  return 0
}

function ble/prompt/unit:{section}/get {
  local ref=${1}_data[8]; ret=${!ref}
}

## @fn ble/prompt/unit:{section}/update prefix ps opts
##   @param[in] prefix
##   @param[in] ps
##   @param[in] opts
##     コロン区切りの trace オプションです。
##
##     show-mode-in-prompt
##       現在のモード名を付加します。
##
##     no-trace
##       ble/canvas/trace による変換・計測をせず、
##       プロンプト文字列の処理のみを行います。
##       これは制御列など端末に出力しない内容を解析するのに使います。
##
##   @param[in] prompt_rows prompt_cols
function ble/prompt/unit:{section}/update {
  local prefix=$1 ps=$2 opts=$3

  # Load variables
  local -a vars; vars=(data dirty)
  [[ :$opts: == *:measure-bbox:* ]] && ble/array#push vars bbox
  [[ :$opts: == *:measure-gbox:* ]] && ble/array#push vars gbox
  local "${vars[@]/%/=}" # #D1570 OK
  ble/util/restore-vars "${prefix}_" "${vars[@]}"

  local has_changed=
  if [[ $prompt_unit_expired ]]; then
    local original_esc=${data[8]}:${data[9]}:${data[10]} # esc:trace_hash:tailor

    if [[ $ps ]]; then
      # load
      [[ :$opts: == *:measure-bbox:* ]] &&
        local x1=${bbox[0]} y1=${bbox[1]} x2=${bbox[2]} y2=${bbox[3]}
      [[ :$opts: == *:measure-gbox:* ]] &&
        local gx1=${gbox[0]} gy1=${gbox[1]} gx2=${gbox[2]} gy2=${gbox[3]}

      local trace_hash esc x y g lc lg
      ble/prompt/.instantiate "$ps" "$opts" "${data[@]:3:7}"
      data=("${data[0]:-0}" '' '' "$x" "$y" "$g" "$lc" "$lg" "$esc" "$trace_hash" "${data[@]:10}")

      # store
      [[ :$opts: == *:measure-bbox:* ]] &&
        bbox=("$x1" "$y1" "$x2" "$y2")
      [[ :$opts: == *:measure-gbox:* ]] &&
        gbox=("$gx1" "$gy1" "$gx2" "$gy2")
    else
      data=("${data[0]:-0}" '' '' 0 0 0 32 0 '' '' "${data[@]:10}")
      [[ :$opts: == *:measure-bbox:* ]] && bbox=()
      [[ :$opts: == *:measure-gbox:* ]] && gbox=()
    fi

    [[ ${data[8]}:${data[9]}:${data[10]} != "$original_esc" ]] && has_changed=1
  fi

  [[ $has_changed ]] && ((dirty=1))

  # Save variables
  ble/util/save-vars "${prefix}_" "${vars[@]}"

  [[ $has_changed ]]
}

#----------------------------------------------------------
# Definitions of prompt sections

function ble/prompt/unit:_ble_prompt_ps1/update {
  ble/prompt/unit/add-hash '$prompt_ps1'
  ble/prompt/unit:{section}/update _ble_prompt_ps1 "$prompt_ps1" show-mode-in-prompt
}

function ble/prompt/unit:_ble_prompt_rps1/update {
  ble/prompt/unit/add-hash '$prompt_rps1'
  ble/prompt/unit/add-hash '$_ble_prompt_ps1_data'
  local cols=${COLUMNS-80}
  local ps1x=${_ble_prompt_ps1_data[3]}
  local ps1y=${_ble_prompt_ps1_data[4]}
  local prompt_rows=$((ps1y+1)) prompt_cols=$cols
  ble/prompt/unit:{section}/update _ble_prompt_rps1 "$prompt_rps1" confine:relative:right:measure-gbox || return 1

  local esc=${_ble_prompt_rps1_data[8]} width=
  if [[ $esc ]]; then
    ((width=_ble_prompt_rps1_gbox[2]-_ble_prompt_rps1_gbox[0]))
    ((width&&20+width<cols&&ps1x+10+width<cols)) || esc= width=
  fi
  _ble_prompt_rps1_data[10]=$esc
  _ble_prompt_rps1_data[11]=$width
  return 0
}

function  ble/prompt/unit:_ble_prompt_xterm_title/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_xterm_title'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_xterm_title "$bleopt_prompt_xterm_title" confine:no-trace || return 1

  local esc=${_ble_prompt_xterm_title_data[8]}
  [[ $esc ]] && esc=$'\e]0;'${esc//[! -~]/'#'}$'\a'
  _ble_prompt_xterm_title_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_screen_title/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_screen_title'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_screen_title "$bleopt_prompt_screen_title" confine:no-trace || return 1

  local esc=${_ble_prompt_screen_title_data[8]}
  [[ $esc ]] && esc=$'\ek'${esc//[! -~]/'#'}$'\e\\'
  _ble_prompt_screen_title_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_term_status/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_term_status'
  local prompt_rows=1
  ble/prompt/unit:{section}/update _ble_prompt_term_status "$bleopt_prompt_term_status" confine:no-trace || return 1

  local esc=${_ble_prompt_term_status_data[8]}
  if [[ $esc ]]; then
    esc=$_ble_term_tsl${esc//[! -~]/'#'}$_ble_term_fsl
  else
    # 非空文字列から空文字列になった時はステータス行をクリア
    esc=$_ble_term_dsl
  fi
  _ble_prompt_term_status_data[10]=$esc
  return 0
}

function ble/prompt/unit:_ble_prompt_status/update {
  ble/prompt/unit/add-hash '$bleopt_prompt_status_align'
  ble/prompt/unit/add-hash '$bleopt_prompt_status_line'
  local ps=$bleopt_prompt_status_line
  local cols=$COLUMNS; ((_ble_term_xenl||cols--))
  local trace_opts=confine:relative:measure-bbox:noscrc:face0=prompt_status_line
  local rex='^justify(=[^:]+)?$'
  [[ $bleopt_prompt_status_align =~ $rex ]] &&
    trace_opts=$trace_opts:$BASH_REMATCH

  local prompt_cols=1 prompt_cols=$cols
  ble/prompt/unit:{section}/update _ble_prompt_status "$ps" "$trace_opts" || return 1

  # tailor
  local esc=${_ble_prompt_status_data[8]}
  if [[ $ps && $esc ]]; then
    local x=${_ble_prompt_status_data[3]}
    local y=${_ble_prompt_status_data[4]}
    local x1=${_ble_prompt_status_bbox[0]}
    local x2=${_ble_prompt_status_bbox[2]}

    local -a DRAW_BUFF=()

    # background color
    local ret
    ble/color/face2g prompt_status_line; local g0=$ret
    ble/color/g2sgr "$g0"; local sgr=$ret
    if ((g0==0||_ble_term_bce)); then
      ble/canvas/put.draw "$sgr$_ble_term_el$_ble_term_sgr0"
    else
      ble/string#reserve-prototype "$cols"
      ble/canvas/put.draw "$sgr${_ble_string_prototype::cols}"
      ble/canvas/put-cub.draw "$cols"
      ble/canvas/put.draw "$_ble_term_sgr0"
    fi

    # bleopt prompt_status_align
    local xshift=0
    case $bleopt_prompt_status_align in
    (center) ((xshift=cols/2-(x2+x1)/2)) ;;
    (right)  ((xshift=cols-x2)) ;;
    esac
    if ((xshift>0)); then
      ((x+=xshift))
      ble/canvas/put-cuf.draw "$xshift"
    fi

    ble/canvas/put.draw "$esc"
    ble/canvas/sflush.draw -v esc

    _ble_prompt_status_data[10]=$esc
    _ble_prompt_status_data[11]=$x
    _ble_prompt_status_data[12]=$y
  else
    _ble_prompt_status_data[10]=
    _ble_prompt_status_data[11]=
    _ble_prompt_status_data[12]=
  fi

  return 0
}

#----------------------------------------------------------
# Update prompts for textarea

# process TMOUT
if ble/is-function ble/util/idle.push; then
  _ble_prompt_timeout_task=
  _ble_prompt_timeout_lineno=
  function ble/prompt/timeout/process {
    ble/util/idle.suspend # exit に失敗した時の為 task を suspend にする
    _ble_edit_line_disabled=1 ble/widget/.insert-newline
    ble/util/buffer.flush
    ble/util/print "${_ble_term_setaf[12]}[ble: auto-logout]$_ble_term_sgr0 timed out waiting for input"
    builtin exit 0 &>/dev/null
    builtin exit 0 &>/dev/null
  } >/dev/tty
  function ble/prompt/timeout/check {
    [[ $_ble_edit_lineno == "$_ble_prompt_timeout_lineno" ]] && return 0
    _ble_prompt_timeout_lineno=$_ble_edit_lineno

    if [[ ${TMOUT:-} =~ ^[0-9]+ ]] && ((BASH_REMATCH>0)); then
      if [[ ! $_ble_prompt_timeout_task ]]; then
        ble/util/idle.push -Z 'ble/prompt/timeout/process'
        _ble_prompt_timeout_task=$_ble_util_idle_lasttask
      fi
      ble/util/idle#sleep "$_ble_prompt_timeout_task" $((BASH_REMATCH*1000))
    elif [[ $_ble_prompt_timeout_task ]]; then
      ble/util/idle#suspend "$_ble_prompt_timeout_task"
    fi
  }
else
  function ble/prompt/timeout/check { ((1)); }
fi

function ble/prompt/update/.has-prompt_command {
  [[ ${PROMPT_COMMAND[*]} ]]
}
function ble/prompt/update/.eval-prompt_command.1 {
  # Note: return 等と記述されていた時対策として関数内評価する。
  ble-edit/exec/.setexit "$_ble_edit_exec_lastarg"
  BASH_COMMAND=$_ble_edit_exec_BASH_COMMAND \
    builtin eval -- "$1"
}
function ble/prompt/update/.eval-prompt_command {
  local _command
  for _command in "${PROMPT_COMMAND[@]}"; do
    ble/prompt/update/.eval-prompt_command.1 "$_command"
  done
}
## @fn ble/prompt/update opts
##   _ble_edit_PS1 からプロンプトを構築します。
##   @param[in] opts
##     コロン区切りのオプションのリストです。
##
##     leave ... 次行に行く直前の最後の表示である事を示します。
##               これが指定された時 transient prompt 等の処理を実行します。
##
##   @var[in]  _ble_edit_PS1
##     構築されるプロンプトの内容を指定します。
##   @var[out] _ble_prompt_ps1_data
##     構築したプロンプトの情報を格納します。
function ble/prompt/update {
  local opts=:$1: dirty=

  ble/prompt/timeout/check

  # Update PS1 in PROMPT_COMMAND / PRECMD
  local version=$COLUMNS:$_ble_edit_lineno:$_ble_history_count
  if [[ $_ble_prompt_hash != "$version" && $opts != *:leave:* ]]; then
    if ble/prompt/update/.has-prompt_command || blehook/has-hook PRECMD; then
      ble-edit/restore-PS1
      ble/prompt/update/.eval-prompt_command
      ble-edit/exec:gexec/invoke-hook-with-setexit PRECMD
      ble-edit/adjust-PS1
    fi
  fi

  local prompt_opts=
  local prompt_ps1=$_ble_edit_PS1
  local prompt_rps1=$bleopt_prompt_rps1
  if [[ $opts == *:leave:* ]]; then
    local ps1f=$bleopt_prompt_ps1_final
    local rps1f=$bleopt_prompt_rps1_final
    local ps1t=$bleopt_prompt_ps1_transient
    [[ :$ps1t: == *:trim:* || :$ps1t: == *:same-dir:* && $PWD != $_ble_edit_line_opwd ]] && ps1t=
    if [[ $ps1f || $rps1f || $ps1t ]]; then
      prompt_opts=$prompt_opts:leave-rewrite
      [[ $ps1f || $ps1t ]] && prompt_ps1=$ps1f
      [[ $rps1f ]] && prompt_rps1=$rps1f
      ble/textarea#invalidate
    fi
  fi

  if [[ :$prompt_opts: == *:leave-rewrite:* || $_ble_prompt_hash != "$version" ]]; then
    _ble_prompt_hash=$version
    ((_ble_prompt_version++))
  fi

  # initialize variables
  ble/history/update-position
  local prompt_hashref_base='$_ble_prompt_version'
  local prompt_rows=${LINES:-25}
  local prompt_cols=${COLUMNS:-80}
  local "${_ble_prompt_cache_vars[@]/%/=}" # #D1570 OK

  ble/prompt/unit#update _ble_prompt_ps1 && dirty=1

  # Note #D1392: mc (midnight commander) の中では補助プロンプトは全て off
  [[ $MC_SID == $$ ]] && { [[ $dirty ]]; return $?; }

  # Note: 補助プロンプトは _ble_textarea_panel==0 の時だけ有効 #D1027
  ((_ble_textarea_panel==0)) || { [[ $dirty ]]; return $?; }

  # bleopt prompt_rps1
  if ((_ble_textarea_panel==0)); then
    if [[ :$opts: == *:leave:* && ! $rps1f && $bleopt_prompt_rps1_transient ]]; then
      # prompt_rps1_transient による消去 (以前の大きさを保持)
      [[ ${_ble_prompt_rps1_data[10]} ]] && dirty=1 rps1_enabled=erase

    else
      [[ $prompt_rps1 || ${_ble_prompt_rps1_data[10]} ]] &&
        ble/prompt/unit#update _ble_prompt_rps1 && dirty=1
      [[ ${_ble_prompt_rps1_data[10]} ]] && rps1_enabled=1
    fi
  fi

  # bleopt prompt_xterm_title
  case ${_ble_term_TERM:-$TERM} in
  (sun*|minix) ;; # black list
  (*)
    [[ $bleopt_prompt_xterm_title || ${_ble_prompt_xterm_title_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_xterm_title && dirty=1 ;;
  esac

  # bleopt prompt_screen_title
  case ${_ble_term_TERM:-$TERM} in
  (screen|tmux|contra|screen.*|screen-*)
    [[ $bleopt_prompt_screen_title || ${_ble_prompt_screen_title_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_screen_title && dirty=1 ;;
  esac

  # bleopt prompt_term_status
  if [[ $_ble_term_tsl && $_ble_term_fsl ]]; then
    [[ $bleopt_prompt_term_status || ${_ble_prompt_term_status_data[10]} ]] &&
      ble/prompt/unit#update _ble_prompt_term_status && dirty=1
  fi

  # bleopt prompt_status_line
  [[ $bleopt_prompt_status_line || ${_ble_prompt_status_data[10]} ]] &&
    ble/prompt/unit#update _ble_prompt_status && dirty=1

  [[ $dirty ]]
}
function ble/prompt/clear {
  _ble_prompt_hash=
  ble/textarea#invalidate
}

# 
#------------------------------------------------------------------------------
# **** information pane ****                                         @line.info

## @fn ble/edit/info/.initialize-size
##   @var[out] cols lines
function ble/edit/info/.initialize-size {
  local ret
  ble/canvas/panel/layout/.get-available-height "$_ble_edit_info_panel"
  cols=${COLUMNS-80} lines=$ret
}

_ble_edit_info_panel=2
_ble_edit_info=(0 0 "")
_ble_edit_info_invalidated=

function ble/edit/info#panel::getHeight {
  (($1!=_ble_edit_info_panel)) && return 0
  if [[ ${_ble_edit_info[2]} ]]; then
    height=1:$((_ble_edit_info[1]+1))
  else
    height=0:0
  fi
}
function ble/edit/info#panel::invalidate {
  (($1!=_ble_edit_info_panel)) && return 0
  _ble_edit_info_invalidated=1
}
function ble/edit/info#panel::render {
  (($1!=_ble_edit_info_panel)) && return 0
  [[ $_ble_edit_info_invalidated ]] || return 0
  _ble_edit_info_invalidated=
  ((_ble_canvas_panel_height[$1])) || return 0

  local -a DRAW_BUFF=()
  ble/canvas/panel#clear.draw "$_ble_edit_info_panel"
  if [[ ${_ble_edit_info[2]} ]]; then
    ble/canvas/panel#goto.draw "$_ble_edit_info_panel"
    ble/canvas/put.draw "${_ble_edit_info[2]}"
    ((_ble_canvas_x=_ble_edit_info[0]))
    ((_ble_canvas_y+=_ble_edit_info[1]))
  fi
  ble/canvas/bflush.draw
}

## @fn ble/edit/info/.construct-content type text
##   @var[out] x y
##   @var[out] content
function ble/edit/info/.construct-content {
  local cols lines
  ble/edit/info/.initialize-size
  x=0 y=0 content=

  local type=$1 text=$2
  case "$1" in
  (clear) ;;
  (ansi|esc)
    local trace_opts=truncate
    [[ $bleopt_info_display == bottom ]] && trace_opts=$trace_opts:noscrc
    [[ $1 == esc ]] && trace_opts=$trace_opts:terminfo
    local ret= g=0
    LINES=$lines ble/canvas/trace "$text" "$trace_opts"
    content=$ret ;;
  (text)
    local ret
    ble/canvas/trace-text "$text"
    content=$ret ;;
  (store)
    x=$2 y=$3 content=$4
    # 現在の高さに入らない時は計測し直す。
    ((y<lines)) || ble/edit/info/.construct-content esc "$content" ;;
  (*)
    ble/util/print "usage: ble/edit/info/.construct-content type text" >&2 ;;
  esac
}

function ble/edit/info/.clear-content {
  [[ ${_ble_edit_info[2]} ]] || return 1
  [[ $_ble_app_render_mode == panel ]] || return 0

  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_edit_info_panel" 0
  ble/canvas/bflush.draw

  _ble_edit_info=(0 0 "")
}

## @fn ble/edit/info/.render-content x y content
##   @param[in] x y content
function ble/edit/info/.render-content {
  local x=$1 y=$2 content=$3

  # 既に同じ内容で表示されているとき…。
  [[ $content == "${_ble_edit_info[2]}" ]] && return 0

  if [[ ! $content ]]; then
    ble/edit/info/.clear-content; return "$?"
  fi

  _ble_edit_info=("$x" "$y" "$content")

  [[ $_ble_app_render_mode == panel ]] || return 0

  local -a DRAW_BUFF=()
  ble/canvas/panel/reallocate-height.draw
  ble/canvas/panel#clear.draw "$_ble_edit_info_panel"
  ble/canvas/panel#goto.draw "$_ble_edit_info_panel"
  ble/canvas/put.draw "$content"
  ((_ble_canvas_y+=y,_ble_canvas_x=x))
  ble/canvas/bflush.draw
}

_ble_edit_info_default=(0 0 "")
_ble_edit_info_scene=default

## @fn ble/edit/info/show type text
##
##   @param[in] type
##
##     以下の何れかを指定する。
##
##     text, ansi, esc, store
##
##   @param[in] text
##
##     type=text のとき、引数 text は表示する文字列を含む。
##     改行などの制御文字は代替表現に置き換えられる。
##     type=ansi のとき、引数 text はANSI制御シーケンスを含む文字列を指定する。
##     type=esc のとき、引数 text は現在の端末の制御シーケンスを含む文字列を指定する。
##
##     これらの文字列について
##     画面からはみ出る文字列に関しては自動で truncate される。
##
function ble/edit/info/show {
  local type=$1 text=$2
  if [[ $text ]]; then
    local x y content=
    ble/edit/info/.construct-content "$@"
    ble/edit/info/.render-content "$x" "$y" "$content"
    ble/util/buffer.flush >&2
    _ble_edit_info_scene=show
  else
    ble/edit/info/default
  fi
}
function ble/edit/info/set-default {
  local type=$1 text=$2
  local x y content
  ble/edit/info/.construct-content "$type" "$text"
  _ble_edit_info_default=("$x" "$y" "$content")
}
function ble/edit/info/default {
  _ble_edit_info_scene=default
  (($#)) && ble/edit/info/set-default "$@"
  return 0
}
function ble/edit/info/clear {
  ble/edit/info/default
}

## @fn ble/edit/info/hide
## @fn ble/edit/info/reveal
##
##   これらの関数は .newline 前後に一時的に info の表示を抑制するための関数である。
##   この関数の呼び出しの後に flush が入ることを想定して ble/util/buffer.flush は実行しない。
##
function ble/edit/info/hide {
  ble/edit/info/.clear-content
}
function ble/edit/info/reveal {
  blehook/invoke info_reveal
  if [[ $_ble_edit_info_scene == default ]]; then
    ble/edit/info/.render-content "${_ble_edit_info_default[@]}"
  fi
}

function ble/edit/info/immediate-show {
  local ret; ble/canvas/panel/save-position
  ble/edit/info/show "$@"
  ble/canvas/panel/load-position "$ret"
  ble/util/buffer.flush >&2
}
function ble/edit/info/immediate-clear {
  local ret; ble/canvas/panel/save-position
  ble/edit/info/clear
  ble/edit/info/reveal
  ble/canvas/panel/load-position "$ret"
  ble/util/buffer.flush >&2
}

# 
#------------------------------------------------------------------------------
# **** edit ****                                                  @edit.content

_ble_edit_VARNAMES=(
  _ble_edit_str
  _ble_edit_ind
  _ble_edit_mark
  _ble_edit_mark_active
  _ble_edit_overwrite_mode
  _ble_edit_line_disabled
  _ble_edit_arg
  _ble_edit_dirty_draw_beg
  _ble_edit_dirty_draw_end
  _ble_edit_dirty_draw_end0
  _ble_edit_dirty_syntax_beg
  _ble_edit_dirty_syntax_end
  _ble_edit_dirty_syntax_end0
  _ble_edit_dirty_observer
  _ble_edit_kill_index
  _ble_edit_kill_ring
  _ble_edit_kill_type)

# 現在の編集状態は以下の変数で表現される
_ble_edit_str=
_ble_edit_ind=0
_ble_edit_mark=0
_ble_edit_mark_active=
_ble_edit_overwrite_mode=
_ble_edit_line_disabled=
_ble_edit_arg=

# 以下は複数の編集文字列が合ったとして全体で共有して良いもの
_ble_edit_kill_index=0
_ble_edit_kill_ring=()
_ble_edit_kill_type=()

# _ble_edit_str は以下の関数を通して変更する。
# 変更範囲を追跡する為。
function ble-edit/content/replace {
  local beg=$1 end=$2
  local ins=$3 reason=${4:-edit}

  # cf. Note#1
  _ble_edit_str="${_ble_edit_str::beg}""$ins""${_ble_edit_str:end}"
  ble-edit/content/.update-dirty-range "$beg" $((beg+${#ins})) "$end" "$reason"
#%if !release
  # Note: 何処かのバグで _ble_edit_ind に変な値が入ってエラーになるので、
  #   ここで誤り訂正を行う。想定として、この関数を呼出した時の _ble_edit_ind の値は、
  #   replace を実行する前の値とする。この関数の呼び出し元では、
  #   _ble_edit_ind の更新はこの関数の呼び出しより後で行う様にする必要がある。
  # Note: このバグは恐らく #D0411 で解決したが暫く様子見する。
  ble/util/assert \
    '((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str}))' \
    "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; beg=$beg, end=$end, ins(${#ins})=$ins" ||
    {
      _ble_edit_dirty_syntax_beg=0
      _ble_edit_dirty_syntax_end=${#_ble_edit_str}
      _ble_edit_dirty_syntax_end0=0
      local olen=$((${#_ble_edit_str}-${#ins}+end-beg))
      ((olen<0&&(olen=0),
        _ble_edit_ind>olen&&(_ble_edit_ind=olen),
        _ble_edit_mark>olen&&(_ble_edit_mark=olen)))
    }
#%end
}
function ble-edit/content/reset {
  local str=$1 reason=${2:-edit}
  local beg=0 end=${#str} end0=${#_ble_edit_str}
  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$beg" "$end" "$end0" "$reason"
#%if !release
  ble/util/assert \
    '((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str}))' \
    "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; str(${#str})=$str" ||
    {
      _ble_edit_dirty_syntax_beg=0
      _ble_edit_dirty_syntax_end=${#_ble_edit_str}
      _ble_edit_dirty_syntax_end0=0
    }
#%end
}
function ble-edit/content/reset-and-check-dirty {
  local str=$1 reason=${2:-edit}
  [[ $_ble_edit_str == "$str" ]] && return 0

  local ret pref suff
  ble/string#common-prefix "$_ble_edit_str" "$str"; pref=$ret
  local dmin=${#pref}
  ble/string#common-suffix "${_ble_edit_str:dmin}" "${str:dmin}"; suff=$ret
  local dmax0=$((${#_ble_edit_str}-${#suff})) dmax=$((${#str}-${#suff}))

  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$dmin" "$dmax" "$dmax0" "$reason"
}
## @fn ble-edit/content/replace-limited beg end insert opts
##   bleopt_line_limit_type の制限をかけて挿入を行います。
##   実際に挿入された文字列は insert に格納されます。
##
##   @param[in] beg end insert
##   @param[in] opts
##     nobell ... 何も挿入・削除がない時に bell を鳴らしません。
##
##   @var[out] insert
##
function ble-edit/content/replace-limited {
  insert=$3
  if [[ $bleopt_line_limit_type == discard ]]; then
    local ibeg=$1 iend=$2 opts=:$4:
    local limit=$((bleopt_line_limit_length))
    if ((limit)); then
      local inslimit=$((limit-${#_ble_edit_str}+(iend-ibeg)))
      ((inslimit<iend-ibeg&&(inslimit=iend-ibeg)))
      ((${#insert}>inslimit)) && insert=${insert::inslimit}
      if [[ ! $insert ]] && ((ibeg==iend)); then
        [[ $opts == *:nobell:* ]] ||
          ble/widget/.bell "ble: reached line_limit_length=$limit"
        return 1
      fi
    fi
  fi
  ble-edit/content/replace "$1" "$2" "$insert"
}
function ble-edit/content/check-limit {
  local opts=:${1:-truncate:editor}:
  if [[ $opts == *:${bleopt_line_limit_type:-none}:* ]]; then
    local limit=$((bleopt_line_limit_length))
    if ((limit>0&&${#_ble_edit_str}>limit)); then
      local ble_edit_line_limit=$limit
      ble-decode-key "$_ble_decode_KCODE_LINE_LIMIT"
    fi
  fi
}
function ble/widget/__line_limit__ {
  local editor=ble/widget/${1:-edit-and-execute-command.impl}
  local limit=$ble_edit_line_limit
  case ${bleopt_line_limit_type:-none} in
  (editor)
    local content=$_ble_edit_str
    ble-edit/content/reset "# reached line_limit_length=$limit"
    _ble_edit_ind=0 _ble_edit_mark=0
    "$editor" "$content"
    (($?==127)) &&
      ble-edit/content/reset "${content::limit}"
    return 1 ;;
  (truncate|*)
    ble-edit/content/replace "$limit" "${#_ble_edit_str}" ''
    ((_ble_edit_ind>limit&&(_ble_edit_ind=limit)))
    ((_ble_edit_mark>limit&&(_ble_edit_mark=limit)))
    return 1 ;;
  esac
  return 0
}

_ble_edit_dirty_draw_beg=-1
_ble_edit_dirty_draw_end=-1
_ble_edit_dirty_draw_end0=-1

_ble_edit_dirty_syntax_beg=0
_ble_edit_dirty_syntax_end=0
_ble_edit_dirty_syntax_end0=1

_ble_edit_dirty_observer=()
## @fn ble-edit/content/.update-dirty-range beg end end0 [reason]
##  @param[in] beg end end0
##    変更範囲を指定します。
##  @param[in] reason
##    変更の理由を表す文字列を指定します。
function ble-edit/content/.update-dirty-range {
  ble/dirty-range#update --prefix=_ble_edit_dirty_draw_ "${@:1:3}"
  ble/dirty-range#update --prefix=_ble_edit_dirty_syntax_ "${@:1:3}"
  ble/textmap#update-dirty-range "${@:1:3}"

  local obs
  for obs in "${_ble_edit_dirty_observer[@]}"; do "$obs" "$@"; done
}

function ble-edit/content/update-syntax {
  if ble/util/import/is-loaded "$_ble_base/lib/core-syntax.sh"; then
    local beg end end0
    ble/dirty-range#load --prefix=_ble_edit_dirty_syntax_
    if ((beg>=0)); then
      ble/dirty-range#clear --prefix=_ble_edit_dirty_syntax_
      ble/syntax/parse "$_ble_edit_str" '' "$beg" "$end" "$end0"
    fi
  fi
}

## @fn ble-edit/content/bolp
##   現在カーソルが行頭に位置しているかどうかを判定します。
function ble-edit/content/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
## @fn ble-edit/content/bolp
##   現在カーソルが行末に位置しているかどうかを判定します。
function ble-edit/content/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
## @fn ble-edit/content/find-logical-eol [index [offset]]
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の終端位置を返します。
##
##   @var[out] ret
##     offset が 0 の場合は位置 index を含む行の行末を返します。
##     offset が正で offset 次の行がない場合は ${#_ble_edit_str} を返します。
##
function ble-edit/content/find-logical-eol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local text=${_ble_edit_str:index}
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?[^\n]*'
    [[ $text =~ $rex ]]
    ((ret=index+${#BASH_REMATCH}))
    [[ ${BASH_REMATCH[2]} ]]
  elif ((offset<0)); then
    local text=${_ble_edit_str::index}
    local rex=$'(\n[^\n]*){0,'$((-offset-1))$'}(\n[^\n]*)?$'
    [[ $text =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index-${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-eol "$index" 0
      return 1
    fi
  else
    local text=${_ble_edit_str:index}
    text=${text%%$'\n'*}
    ((ret=index+${#text}))
    return 0
  fi
}
## @fn ble-edit/content/find-logical-bol [index [offset]]
##   _ble_edit_str 内で位置 index から offset 行だけ次の行の先頭位置を返します。
##
##   @var[out] ret
##     offset が 0 の場合は位置 index を含む行の行頭を返します。
##     offset が正で offset だけ次の行がない場合は最終行の行頭を返します。
##     特に次の行がない場合は現在の行頭を返します。
##
function ble-edit/content/find-logical-bol {
  local index=${1:-$_ble_edit_ind} offset=${2:-0}
  if ((offset>0)); then
    local rex=$'^([^\n]*\n){0,'$((offset-1))$'}([^\n]*\n)?'
    [[ ${_ble_edit_str:index} =~ $rex ]]
    if [[ $BASH_REMATCH ]]; then
      ((ret=index+${#BASH_REMATCH}))
      [[ ${BASH_REMATCH[2]} ]]
    else
      ble-edit/content/find-logical-bol "$index" 0
      return 1
    fi
  elif ((offset<0)); then
    ble-edit/content/find-logical-eol "$index" "$offset"; local ext=$?
    ble-edit/content/find-logical-bol "$ret" 0
    return "$ext"
  else
    local text=${_ble_edit_str::index}
    text=${text##*$'\n'}
    ((ret=index-${#text}))
    return 0
  fi
}
## @fn ble-edit/content/find-non-space index
##   指定した位置以降の最初の非空白文字を探します。
##   @param[in] index
##   @var[out] ret
function ble-edit/content/find-non-space {
  local bol=$1
  local rex=$'^[ \t]*'; [[ ${_ble_edit_str:bol} =~ $rex ]]
  ret=$((bol+${#BASH_REMATCH}))
}


## @fn ble-edit/content/is-single-line
function ble-edit/content/is-single-line {
  [[ $_ble_edit_str != *$'\n'* ]]
}

## @var _ble_edit_arg
##   入力された引数を保持します。以下の何れかの状態を示します。
##   /^$/
##     引数の未入力状態である事を示します。
##   /^\+$/
##     universal-arugument (M-C-u) 開始直後である事を示します。
##     次に入力する - または数字を引数として解釈します。
##   /^([0-9]+|-[0-9]*)$/
##     引数の入力途中である事を表します。
##     次に入力する数字を引数として解釈します。
##   /^\+([0-9]+|-[0-9]*)$/
##     引数の入力が完了した事を示します。
##     次に来る数字は引数として解釈しません。

## @fn ble-edit/content/get-arg
##   @var[out] arg
function ble-edit/content/get-arg {
  local default_value=$1
  local value=$_ble_edit_arg
  _ble_edit_arg=

  if [[ $value == +* ]]; then
    if [[ $value == + ]]; then
      arg=4
      return 0
    fi
    value=${value#+}
  fi

  if [[ $value == -* ]]; then
    if [[ $value == - ]]; then
      arg=-1
    else
      arg=$((-10#${value#-}))
    fi
  else
    if [[ $value ]]; then
      arg=$((10#$value))
    else
      arg=$default_value
    fi
  fi
}
function ble-edit/content/clear-arg {
  _ble_edit_arg=
}
function ble-edit/content/toggle-arg {
  if [[ $_ble_edit_arg == + ]]; then
    _ble_edit_arg=
  elif [[ $_ble_edit_arg && $_ble_edit_arg != +* ]]; then
    _ble_edit_arg=+$_ble_edit_arg
  else
    _ble_edit_arg=+
  fi
}

function ble/keymap:generic/clear-arg {
  if [[ $_ble_decode_keymap == vi_[noxs]map ]]; then
    ble/keymap:vi/clear-arg
  else
    ble-edit/content/clear-arg
  fi
}

function ble/widget/append-arg-or {
  local code=$((KEYS[0]&_ble_decode_MaskChar))
  ((code==0)) && return 1
  local ret; ble/util/c2s "$code"; local ch=$ret
  if
    if [[ $_ble_edit_arg == + ]]; then
      [[ $ch == [-0-9] ]] && _ble_edit_arg=
    elif [[ $_ble_edit_arg == +* ]]; then
      false
    elif [[ $_ble_edit_arg ]]; then
      [[ $ch == [0-9] ]]
    else
      ((KEYS[0]&_ble_decode_MaskFlag))
    fi
  then
    ble/decode/widget/skip-lastwidget
    _ble_edit_arg=$_ble_edit_arg$ch
  else
    ble/widget/"$@"
  fi
}
function ble/widget/append-arg {
  ble/widget/append-arg-or self-insert
}
function ble/widget/universal-arg {
  ble/decode/widget/skip-lastwidget
  ble-edit/content/toggle-arg
}

## @fn ble-edit/content/prepend-kill-ring string kill_type
function ble-edit/content/prepend-kill-ring {
  _ble_edit_kill_index=0
  local otext=${_ble_edit_kill_ring[0]-} ntext=$1
  local otype=${_ble_edit_kill_type[0]-} ntype=$2
  if [[ $otype == L || $ntype == L ]]; then
    ntext=${ntext%$'\n'}$'\n'
    otext=${otext%$'\n'}$'\n'
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]=L
  elif [[ $otype == B:* ]]; then
    if [[ $ntype != B:* ]]; then
      ntext=${ntext%$'\n'}$'\n'
      local ret; ble/string#count-char "$ntext" $'\n'
      ble/string#repeat '0 ' "$ret"
      ntype=B:${ret%' '}
    fi
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]="B:${ntype#B:} ${otype#B:}"
  else
    _ble_edit_kill_ring[0]=$ntext$otext
    _ble_edit_kill_type[0]=$otype
  fi
}
## @fn ble-edit/content/append-kill-ring string kill_type
function ble-edit/content/append-kill-ring {
  _ble_edit_kill_index=0
  local otext=${_ble_edit_kill_ring[0]-} ntext=$1
  local otype=${_ble_edit_kill_type[0]-} ntype=$2
  if [[ $otype == L || $ntype == L ]]; then
    ntext=${ntext%$'\n'}$'\n'
    otext=${otext%$'\n'}$'\n'
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]=L
  elif [[ $otype == B:* ]]; then
    if [[ $ntype != B:* ]]; then
      ntext=${ntext%$'\n'}$'\n'
      local ret; ble/string#count-char "$ntext" $'\n'
      ble/string#repeat '0 ' "$ret"
      ntype=B:${ret%' '}
    fi
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]="B:${otype#B:} ${ntype#B:}"
  else
    _ble_edit_kill_ring[0]=$otext$ntext
    _ble_edit_kill_type[0]=$otype
  fi
}

## @fn ble-edit/content/push-kill-ring string kill_type opts
function ble-edit/content/push-kill-ring {
  if ((${#_ble_edit_kill_ring[@]})) && [[ ${LASTWIDGET#ble/widget/} == kill-* || ${LASTWIDGET#ble/widget/} == copy-* ]]; then
    local name; ble/string#split-words name "${WIDGET#ble/widget/}"
    if [[ $name == kill-backward-* || $name == copy-backward-* ]]; then
      ble-edit/content/prepend-kill-ring "$1" "$2"
      return "$?"
    elif [[ $name != kill-region* && $name != copy-region* ]]; then
      ble-edit/content/append-kill-ring "$1" "$2"
      return "$?"
    fi
  fi

  _ble_edit_kill_index=0
  ble/array#unshift _ble_edit_kill_ring "$1"
  ble/array#unshift _ble_edit_kill_type "$2"
}


# 
#------------------------------------------------------------------------------
# **** saved variables such as (PS1/LINENO) ****                      @edit.ps1
#
# 内部使用変数
## @var _ble_edit_LINENO
##   LINENO の値を保持します。
##   コマンドラインで処理・キャンセルした行数の合計です。
## @var _ble_edit_CMD
##   プロンプトで \# として参照される変数です。
##   実際のコマンド実行の回数を保持します。
##   PS0 の評価後に増加します。
## @var _ble_edit_PS1
## @var _ble_edit_IFS
## @var _ble_edit_IGNOREEOF_adjusted
## @var _ble_edit_IGNOREEOF
## @arr _ble_edit_READLINE

_ble_edit_PS1_adjusted=
_ble_edit_PS1='\s-\v\$ '
function ble-edit/adjust-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] && return 0
  _ble_edit_PS1_adjusted=1
  _ble_edit_PS1=$PS1
  [[ $bleopt_internal_suppress_bash_output ]] || PS1=
}
function ble-edit/restore-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] || return 1
  _ble_edit_PS1_adjusted=
  PS1=$_ble_edit_PS1
}

_ble_edit_IGNOREEOF_adjusted=
_ble_edit_IGNOREEOF=
function ble-edit/adjust-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] && return 0
  _ble_edit_IGNOREEOF_adjusted=1

  if [[ ${IGNOREEOF+set} ]]; then
    _ble_edit_IGNOREEOF=$IGNOREEOF
  else
    builtin unset -v _ble_edit_IGNOREEOF
  fi
  if ((_ble_bash>=40000)); then
    builtin unset -v IGNOREEOF
  else
    IGNOREEOF=9999
  fi
}
function ble-edit/restore-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] || return 1
  _ble_edit_IGNOREEOF_adjusted=

  if [[ ${_ble_edit_IGNOREEOF+set} ]]; then
    IGNOREEOF=$_ble_edit_IGNOREEOF
  else
    builtin unset -v IGNOREEOF
  fi
}

_ble_edit_READLINE=()
function ble-edit/adjust-READLINE {
  [[ $_ble_edit_READLINE ]] && return 0
  _ble_edit_READLINE=1
  ble/variable#copy-state READLINE_LINE  '_ble_edit_READLINE[1]'
  ble/variable#copy-state READLINE_POINT '_ble_edit_READLINE[2]'
  ble/variable#copy-state READLINE_MARK  '_ble_edit_READLINE[3]'
}
function ble-edit/restore-READLINE {
  [[ $_ble_edit_READLINE ]] || return 0
  _ble_edit_READLINE=
  ble/variable#copy-state '_ble_edit_READLINE[1]' READLINE_LINE
  ble/variable#copy-state '_ble_edit_READLINE[2]' READLINE_POINT
  ble/variable#copy-state '_ble_edit_READLINE[3]' READLINE_MARK
}

## @fn ble-edit/eval-IGNOREEOF
##   @var[out] ret
function ble-edit/eval-IGNOREEOF {
  local value=
  if [[ $_ble_edit_IGNOREEOF_adjusted ]]; then
    value=${_ble_edit_IGNOREEOF-0}
  else
    value=${IGNOREEOF-0}
  fi

  if [[ $value && ! ${value//[0-9]} ]]; then
    # 正の整数は十進数で解釈
    ret=$((10#$value))
  else
    # 負の整数、空文字列、その他
    ret=10
  fi
}

function ble-edit/attach/TRAPWINCH {
  local FUNCNEST=
  local IFS=$_ble_term_IFS
  if ((_ble_edit_attached)); then
    if [[ $_ble_term_state == internal ]]; then
      _ble_textmap_pos=()
      ble-edit/bind/stdout.on

      # 処理中に届いた WINCH は失われる様だ。連続的サイズ変化を通知す
      # る端末の場合、途中のサイズの WINCH の処理中に最終的なサイズの
      # WINCH を逃して表示が乱れたままになる。対策として描画終了時に処
      # 理中にサイズ変化が起こっていないか確認する。

      local old_size= i
      for ((i=0;i<20;i++)); do
        # 次の待つと共にサブシェルで checkwinsize を誘発
        (ble/util/msleep 50)
        # trap 中だと bash のバグでジョブが溜まるので逐次捌く
        ble/util/joblist.check ignore-volatile-jobs
        local size=$LINES:$COLUMNS
        [[ $size == "$old_size" ]] && break

        old_size=$size
        ble/canvas/panel/invalidate height # 高さの再確保も含めて。
        ble/application/render
      done

      ble-edit/bind/stdout.off
    fi
  fi
}

## called by ble-edit/attach
_ble_edit_attached=0
function ble-edit/attach/.attach {
  ((_ble_edit_attached)) && return 0
  _ble_edit_attached=1

  if [[ ! ${_ble_edit_LINENO+set} ]]; then
    _ble_edit_LINENO=${BASH_LINENO[${#BASH_LINENO[@]}-1]}
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0
    builtin unset -v LINENO; LINENO=$_ble_edit_LINENO
    _ble_edit_CMD=$_ble_edit_LINENO
  fi

  ble/builtin/trap/install-hook WINCH readline
  blehook WINCH-+=ble-edit/attach/TRAPWINCH

  ble-edit/adjust-PS1
  ble-edit/adjust-READLINE
  ble-edit/adjust-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && _ble_edit_IFS=$IFS
}

function ble-edit/attach/.detach {
  ((!_ble_edit_attached)) && return 0
  ble-edit/restore-PS1
  ble-edit/restore-READLINE
  ble-edit/restore-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && IFS=$_ble_edit_IFS
  _ble_edit_attached=0
}


# 
#------------------------------------------------------------------------------
# **** textarea ****                                                  @textarea

_ble_textarea_VARNAMES=(
  _ble_textarea_buffer
  _ble_textarea_bufferName

  _ble_textarea_cur
  _ble_textarea_panel
  _ble_textarea_scroll
  _ble_textarea_scroll_new
  _ble_textarea_gendx
  _ble_textarea_gendy

  _ble_textarea_invalidated
  _ble_textarea_version
  _ble_textarea_caret_state
  _ble_textarea_cache
  _ble_textarea_render_defer)

_ble_textarea_local_VARNAMES=()

## @fn ble/textarea#panel::getHeight
##   @var[out] height
function ble/textarea#panel::getHeight {
  if [[ $1 == "$_ble_textarea_panel" ]]; then
    local min=$((_ble_prompt_ps1_data[4]+1)) max=$((_ble_textmap_endy+1))
    ((min<max&&min++))
    height=$min:$max
  else
    height=0:${_ble_canvas_panel_height[$1]}
  fi
}
function ble/textarea#panel::onHeightChange {
  [[ $1 == "$_ble_textarea_panel" ]] || return 1

  if [[ ! $ble_textarea_render_flag ]]; then
    ble/textarea#invalidate
  fi
}
function ble/textarea#panel::invalidate {
  if (($1==_ble_textarea_panel)); then
    ble/textarea#invalidate
  fi
}
function ble/textarea#panel::render {
  if (($1==_ble_textarea_panel)); then
    ble/textarea#render
  fi
}

# **** textarea.buffer ****                                    @textarea.buffer

_ble_textarea_buffer=()
_ble_textarea_bufferName=

## @fn lc lg; ble/textarea#update-text-buffer; cx cy lc lg
##
##   @param[in    ] text  編集文字列
##   @var  [in,out] umin umax
##     umin,umax は再描画の必要な範囲を文字インデックスで返します。
##
##   @var[in] _ble_textmap_*
##     配置情報が最新であることを要求します。
##
function ble/textarea#update-text-buffer {
  local iN=${#text}

  local beg end end0
  ble/dirty-range#load --prefix=_ble_edit_dirty_draw_
  ble/dirty-range#clear --prefix=_ble_edit_dirty_draw_

  # highlight -> HIGHLIGHT_BUFF
  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble/highlight/layer/update "$text" '' "$beg" "$end" "$end0"
  ble/urange#update "$HIGHLIGHT_UMIN" "$HIGHLIGHT_UMAX"

  # 変更文字の適用
  if ((${#_ble_textmap_ichg[@]})); then
    local ichg g ret
    builtin eval "_ble_textarea_buffer=(\"\${$HIGHLIGHT_BUFF[@]}\")"
    HIGHLIGHT_BUFF=_ble_textarea_buffer
    for ichg in "${_ble_textmap_ichg[@]}"; do
      ble/highlight/layer/getg "$ichg"
      ble/color/g2sgr "$g"
      _ble_textarea_buffer[ichg]=$ret${_ble_textmap_glyph[ichg]}
    done
  fi

  _ble_textarea_bufferName=$HIGHLIGHT_BUFF
}
## @fn ble/textarea#update-left-char index
##   update lc, lg.
##
##   @param[in] index
##     カーソルの index
##   @param[out] lc lg
##     カーソル左の文字のコードと gflag を返します。
##     カーソルが先頭にある場合は、編集文字列開始位置の左(プロンプトの最後の文字)について記述します。
##
##   lc, lg は bleopt_internal_suppress_bash_output= の時に bash に出力させる文字と
##   その属性を表す。READLINE_LINE が空だと C-d を押した時にその場でログアウト
##   してしまったり、エラーメッセージが表示されたりする。その為 READLINE_LINE
##   に有限の長さの文字列を設定したいが、そうするとそれが画面に出てしまう。
##   そこで、ble.sh では現在のカーソル位置にある文字と同じ文字を READLINE_LINE
##   に設定する事で、bash が文字を出力しても見た目に問題がない様にしている。
##
##   cx==0 の時には現在のカーソル位置の右にある文字を READLINE_LINE に設定し
##   READLINE_POINT=0 とする。cx>0 の時には現在のカーソル位置の左にある文字を
##   READLINE_LINE に設定し READLINE_POINT=(左の文字のバイト数) とする。
##   (READLINE_POINT は文字数ではなくバイトオフセットである事に注意する。)
##
function ble/textarea#update-left-char {
  local index=$1
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    lc=32 lg=0
    return 0
  fi

  # index==0 の場合はプロンプトの右端に於ける値
  if ((index==0)); then
    lc=${_ble_prompt_ps1_data[6]}
    lg=${_ble_prompt_ps1_data[7]}
    return 0
  fi

  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index"

  local lcs ret
  if ((cx==0)); then
    # 次の文字
    if ((index==iN)); then
      # 次の文字がない時は空白
      ret=32
    else
      lcs=${_ble_textmap_glyph[index]}
      ble/util/s2c "$lcs"
    fi

    # 次が改行の時は空白にする
    local g; ble/highlight/layer/getg "$index"; lg=$g
    ((lc=ret==10?32:ret))
  else
    # 前の文字
    lcs=${_ble_textmap_glyph[index-1]}
    ble/util/s2c "${lcs:${#lcs}-1}"
    local g; ble/highlight/layer/getg $((index-1)); lg=$g
    ((lc=ret))
  fi
}
## @fn ble/textarea#slice-text-buffer [beg [end]]
##   @var[out] ret
function ble/textarea#slice-text-buffer {
  ble/textmap#assert-up-to-date
  local iN=$_ble_textmap_length
  local i1=${1:-0} i2=${2:-$iN}
  ((i1<0&&(i1+=iN,i1<0&&(i1=0)),
    i2<0&&(i2+=iN)))
  if ((i1<i2&&i1<iN)); then
    local g
    ble/highlight/layer/getg "$i1"
    ble/color/g2sgr "$g"
    IFS= builtin eval "ret=\"\$ret\${$_ble_textarea_bufferName[*]:i1:i2-i1}\""
  else
    ret=
  fi
}

# 
# **** textarea.render ****                                    @textarea.render

#
# 大域変数
#

## @arr _ble_textarea_cur
##     キャレット位置 (ユーザに対して呈示するカーソル) と其処の文字の情報を保持します。
##   _ble_textarea_cur[0] x   キャレット描画位置の y 座標を保持します。
##   _ble_textarea_cur[1] y   キャレット描画位置の y 座標を保持します。
##   _ble_textarea_cur[2] lc
##     キャレット位置の左側の文字の文字コードを整数で保持します。
##     キャレットが最も左の列にある場合は右側の文字を保持します。
##   _ble_textarea_cur[3] lg
##     キャレット位置の左側の SGR フラグを保持します。
##     キャレットが最も左の列にある場合は右側の文字に適用される SGR フラグを保持します。
_ble_textarea_cur=(0 0 32 0)

_ble_textarea_panel=0
_ble_textarea_scroll=
_ble_textarea_scroll_new=
_ble_textarea_gendx=0
_ble_textarea_gendy=0

#
# 表示関数
#

## @var _ble_textarea_invalidated
##   完全再描画 (プロンプトも含めた) を要求されたことを記録します。
##   完全再描画の要求前に空文字列で、要求後に 1 の値を持ちます。
_ble_textarea_invalidated=1

function ble/textarea#invalidate {
  if [[ $1 == str || $1 == partial ]]; then
    ((_ble_textarea_version++))
  else
    _ble_textarea_invalidated=1
  fi
  return 0
}

## @fn ble/textarea#render/.erase-forward-line.draw opts
##   @var[in] x cols
function ble/textarea#render/.erase-forward-line.draw {
  local eraser=$_ble_term_sgr0$_ble_term_el
  if [[ :$render_opts: == *:relative:* ]]; then
    local width=$((cols-x))
    if ((width==0)); then
      eraser=
    elif [[ $_ble_term_ech ]]; then
      eraser=$_ble_term_sgr0${_ble_term_ech//'%d'/$width}
    else
      ble/string#reserve-prototype "$width"
      eraser=$_ble_term_sgr0${_ble_string_prototype::width}${_ble_term_cub//'%d'/$width}
    fi
  fi
  ble/canvas/put.draw "$eraser"
}

## @fn ble/textarea#render/.determine-scroll
##   新しい表示高さとスクロール位置を決定します。
##   ble/textarea#render から呼び出されることを想定します。
##
##   @var[in,out] scroll
##     現在のスクロール量を指定します。調整後のスクロール量を指定します。
##   @var[in,out] height
##     現在の表示高さを指定します。再配置後の表示高さを返します。
##   @var[in,out] umin umax
##     描画範囲を表示領域に制限して返します。
##
##   @var[in] cols
##   @var[in] begx begy endx endy cx cy
##     それぞれ編集文字列の先端・末端・現在カーソル位置の表示座標を指定します。
##
function ble/textarea#render/.determine-scroll {
  local nline=$((endy+1))

  # panel の高さを要求。この後 height <= nline になる筈。
  if ((height!=nline)); then
    ble/canvas/panel/reallocate-height.draw
    height=${_ble_canvas_panel_height[_ble_textarea_panel]}
  fi

  if ((height<nline)); then
    ((scroll<=nline-height)) || ((scroll=nline-height))

    local _height=$((height-begy)) _nline=$((nline-begy)) _cy=$((cy-begy))
    local margin=$((_height>=6&&_nline>_height+2?2:1))
    local smin smax
    ((smin=_cy-_height+margin,
      smin>nline-height&&(smin=nline-height),
      smax=_cy-margin,
      smax<0&&(smax=0)))
    if ((scroll>smax)); then
      scroll=$smax
    elif ((scroll<smin)); then
      scroll=$smin
    fi

    # [umin, umax] を表示範囲で制限する。
    #
    # Note: scroll == 0 の時は表示1行目から表示する。
    #   scroll > 0 の時は表示1行目には ... だけを表示し、
    #   表示2行目から表示する。
    #
    local wmin=0 wmax index
    if ((scroll)); then
      ble/textmap#get-index-at 0 $((scroll+begy+1)); wmin=$index
    fi
    ble/textmap#get-index-at "$cols" $((scroll+height-1)); wmax=$index
    ((umin<umax)) &&
      ((umin<wmin&&(umin=wmin),
        umax>wmax&&(umax=wmax)))
  else
    # Note: height == nline の筈
    scroll=
    if ! ble/util/assert '((height==nline))'; then
      ble/canvas/panel#set-height.draw "$_ble_textarea_panel" "$nline"
      height=$nline
    fi
  fi
}
## @fn ble/textarea#render/.perform-scroll new_scroll
##
##   @var[out] DRAW_BUFF
##     スクロールを実行するシーケンスの出力先です。
##
##   @var[in] height cols render_opts
##   @var[in] begx begy
##
function ble/textarea#render/.perform-scroll {
  local new_scroll=$1
  if ((new_scroll!=_ble_textarea_scroll)); then
    local scry=$((begy+1))
    local scrh=$((height-scry))

    # 行の削除と挿入および新しい領域 [fmin, fmax] の決定
    local fmin fmax index
    if ((_ble_textarea_scroll>new_scroll)); then
      local shift=$((_ble_textarea_scroll-new_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 $((height-draw_shift))
      ble/canvas/put-dl.draw "$draw_shift" panel
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble/canvas/put-il.draw "$draw_shift" panel

      if ((new_scroll==0)); then
        fmin=0
      else
        ble/textmap#get-index-at 0 $((scry+new_scroll)); fmin=$index
      fi
      ble/textmap#get-index-at "$cols" $((scry+new_scroll+draw_shift-1)); fmax=$index
    else
      local shift=$((new_scroll-_ble_textarea_scroll))
      local draw_shift=$((shift<scrh?shift:scrh))
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble/canvas/put-dl.draw "$draw_shift" panel
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 $((height-draw_shift))
      ble/canvas/put-il.draw "$draw_shift" panel

      ble/textmap#get-index-at 0 $((new_scroll+height-draw_shift)); fmin=$index
      ble/textmap#get-index-at "$cols" $((new_scroll+height-1)); fmax=$index
    fi

    # 新しく現れた範囲 [fmin, fmax] を埋める
    if ((fmin<fmax)); then
      local fmaxx fmaxy fminx fminy
      ble/textmap#getxy.out --prefix=fmin "$fmin"
      ble/textmap#getxy.out --prefix=fmax "$fmax"

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$fminx" $((fminy-new_scroll))
      ((new_scroll==0)) &&
        x=$fminx ble/textarea#render/.erase-forward-line.draw # ... を消す
      local ret; ble/textarea#slice-text-buffer "$fmin" "$fmax"
      ble/canvas/put.draw "$ret"
      ((_ble_canvas_x=fmaxx,
        _ble_canvas_y+=fmaxy-fminy))

      ((umin<umax)) &&
        ((fmin<=umin&&umin<fmax&&(umin=fmax),
          fmin<umax&&umax<=fmax&&(umax=fmin)))
    fi

    _ble_textarea_scroll=$new_scroll

    ble/textarea#render/.show-scroll-at-first-line
  fi
}
## @fn ble/textarea#render/.show-scroll-at-first-line
##   スクロール時 "(line 3) ..." などの表示
##
##   @var[in] _ble_textarea_scroll
##   @var[in] cols render_opts
##   @var[in,out] DRAW_BUFF _ble_canvas_x _ble_canvas_y
##
function ble/textarea#render/.show-scroll-at-first-line {
  if ((_ble_textarea_scroll!=0)); then
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$begx" "$begy"
    local scroll_status="(line $((_ble_textarea_scroll+2))) ..."
    scroll_status=${scroll_status::cols-1-begx}
    x=$begx ble/textarea#render/.erase-forward-line.draw
    ble/canvas/put.draw "$eraser$_ble_term_bold$scroll_status$_ble_term_sgr0"
    ((_ble_canvas_x+=${#scroll_status}))
  fi
}

## @fn ble/textarea#render/.erase-rprompt
##   @var[in] cols
##     rps1 の幅の分だけ減少させた後の cols を指定します。
function ble/textarea#render/.erase-rprompt {
  [[ $_ble_prompt_rps1_shown ]] || return 0
  _ble_prompt_rps1_shown=
  local rps1_height=${_ble_prompt_rps1_gbox[3]}
  local -a DRAW_BUFF=()
  local y=0
  for ((y=0;y<rps1_height;y++)); do
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" $((cols+1)) "$y" sgr0
    ble/canvas/put.draw "$_ble_term_el"
  done
  ble/canvas/bflush.draw
}
## @fn ble/textarea#render/.cleanup-trailing-spaces-after-newline
##   rps1_transient の時に、次の行に行く前に行末の無駄な空白を削除します。
##   @var[in] text
##   @var[in] _ble_textmap_pos
function ble/textarea#render/.cleanup-trailing-spaces-after-newline {
  local -a DRAW_BUFF=()
  local -a buffer; ble/string#split-lines buffer "$text"
  local line index=0 pos
  for line in "${buffer[@]}"; do
    ((index+=${#line}))
    ble/string#split-words pos "${_ble_textmap_pos[index]}"
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${pos[0]}" "${pos[1]}" sgr0
    ble/canvas/put.draw "$_ble_term_el"
    ((index++))
  done
  ble/canvas/bflush.draw
  _ble_prompt_rps1_shown=
}

## @fn ble/textarea#render/.show-control-string prefix [force]
function ble/textarea#render/.show-control-string {
  local ref_dirty=${1}_dirty ref_output=${1}_data[10] force=$2
  [[ $force || ${!ref_dirty} ]] || return 0
  ble/canvas/put.draw "${!ref_output}"
  builtin eval -- "$ref_dirty="
  return 0
}
## @fn ble/textarea#render/.show-prompt [force]
function ble/textarea#render/.show-prompt {
  [[ $1 || $_ble_prompt_ps1_dirty ]] || return 0
  local esc=${_ble_prompt_ps1_data[8]}
  local prox=${_ble_prompt_ps1_data[3]}
  local proy=${_ble_prompt_ps1_data[4]}
  ble/canvas/panel#goto.draw "$_ble_textarea_panel"
  ble/canvas/panel#put.draw "$_ble_textarea_panel" "$esc" "$prox" "$proy"
  _ble_prompt_ps1_dirty=
}
## @fn ble/textarea#render/.show-rprompt [force]
##   @var[in] cols
function ble/textarea#render/.show-rprompt {
  [[ $1 || $_ble_prompt_rps1_dirty ]] || return 0
  local rps1out=${_ble_prompt_rps1_data[8]}
  local rps1x=$((_ble_prompt_rps1_data[3]+COLUMNS-_ble_prompt_rps1_gbox[2]))
  local rps1y=${_ble_prompt_rps1_data[4]}
  # Note: cols は画面右端ではなく textmap の右端
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
  ble/canvas/panel#put.draw "$_ble_textarea_panel" "$rps1out" "$rps1x" "$rps1y"
  _ble_prompt_rps1_dirty=
  _ble_prompt_rps1_shown=1
}

## @fn ble/textarea#focus
##   プロンプト・編集文字列の現在位置に端末のカーソルを移動します。
function ble/textarea#focus {
  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
  ble/canvas/bflush.draw
}

## @fn ble/textarea#render opts
##   プロンプト・編集文字列の表示更新を ble/util/buffer に対して行う。
##   Post-condition: カーソル位置 (x y) = (_ble_textarea_cur[0] _ble_textarea_cur[1]) に移動する
##   Post-condition: 編集文字列部分の再描画を実行する
##
##   @param[in] opts
##     leave
##       bleopt prompt_rps1_transient が非空文字列の時、rps1 を消去します。
##     update
##       強制的に再描画します。例えば非同期の着色を更新する時に用います。
##
##   @var _ble_textarea_caret_state := inds ':' mark ':' mark_active ':' line_disabled ':' overwrite_mode
##     ble/textarea#render で用いる変数です。
##     現在の表示内容のカーソル位置・ポイント位置の情報を記録します。
##
_ble_textarea_caret_state=::
_ble_textarea_version=0
function ble/textarea#render {
  local opts=$1
  local ble_textarea_render_flag=1 # ble/textarea#panel::onHeightChange から参照する
  local caret_state=$_ble_textarea_version:$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active:$_ble_edit_line_disabled:$_ble_edit_overwrite_mode

  local dirty= rps1_enabled=
  if ble/prompt/update "$opts"; then
    dirty=1
  elif ((_ble_edit_dirty_draw_beg>=0)); then
    dirty=1
  elif [[ $_ble_textarea_invalidated ]]; then
    dirty=1
  elif [[ $_ble_textarea_caret_state != "$caret_state" ]]; then
    dirty=1
  elif [[ $_ble_textarea_scroll != "$_ble_textarea_scroll_new" ]]; then
    dirty=1
  elif [[ :$opts: == *:leave:* || :$opts: == *:update:* ]]; then
    dirty=1
  fi

  if [[ ! $dirty ]]; then
    ble/textarea#focus
    return 0
  fi

  #-------------------
  # 描画内容の計算 (配置情報、着色文字列)

  local cols=${COLUMNS-80}
  local rps1_width=${_ble_prompt_rps1_data[11]}
  _ble_prompt_rps1_data[12]=$rps1_enabled
  if [[ $rps1_enabled ]]; then
    ((cols-=rps1_width+1,_ble_term_xenl||cols--))
    if [[ $rps1_enabled == erase ]]; then
      ble/textarea#render/.erase-rprompt
      rps1_enabled=
    fi
  fi

  # 編集内容の構築
  local text=$_ble_edit_str index=$_ble_edit_ind
  local iN=${#text}
  ((index<0?(index=0):(index>iN&&(index=iN))))

  local umin=-1 umax=-1
  local x=${_ble_prompt_ps1_data[3]}
  local y=${_ble_prompt_ps1_data[4]}

  # 配置情報の更新
  local render_opts=
  [[ $rps1_enabled ]] && render_opts=relative
  COLUMNS=$cols ble/textmap#update "$text" "$render_opts" # [ref] x y
  ble/urange#update "$_ble_textmap_umin" "$_ble_textmap_umax" # [ref] umin umax
  ble/urange#clear --prefix=_ble_textmap_

  # 着色の更新
  local DMIN=$_ble_edit_dirty_draw_beg
  ble-edit/content/update-syntax
  ble/textarea#update-text-buffer # [in] text index [ref] lc lg;

  local lc=32 lg=0
  [[ $bleopt_internal_suppress_bash_output ]] ||
    ble/textarea#update-left-char "$index"

  #-------------------
  # 描画領域の決定とスクロール

  local -a DRAW_BUFF=()

  # 1 描画領域の決定
  local begx=$_ble_textmap_begx begy=$_ble_textmap_begy
  local endx=$_ble_textmap_endx endy=$_ble_textmap_endy
  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index" # → cx cy

  local cols=$_ble_textmap_cols
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}
  local scroll=${_ble_textarea_scroll_new:-$_ble_textarea_scroll}
  ble/textarea#render/.determine-scroll # update: height scroll umin umax

  local gend gendx gendy
  if [[ $scroll ]]; then
    ble/textmap#get-index-at "$cols" $((height+scroll-1)); gend=$index
    ble/textmap#getxy.out --prefix=gend "$gend"
    ((gendy-=scroll))
  else
    gend=$iN gendx=$endx gendy=$endy
  fi
  _ble_textarea_gendx=$gendx _ble_textarea_gendy=$gendy

  #-------------------
  # 出力

  # 2 表示内容
  local ret esc_line= esc_line_set=
  if [[ ! $_ble_textarea_invalidated ]]; then
    # 部分更新の場合

    [[ ! $rps1_enabled && $_ble_prompt_rps1_shown || $rps1_enabled && $_ble_prompt_rps1_dirty ]] &&
      ble/textarea#render/.cleanup-trailing-spaces-after-newline

    # スクロール
    ble/textarea#render/.perform-scroll "$scroll" # update: umin umax
    _ble_textarea_scroll_new=$_ble_textarea_scroll

    # プロンプトに更新があれば表示
    [[ $rps1_enabled ]] && ble/textarea#render/.show-rprompt
    ble/textarea#render/.show-prompt
    ble/textarea#render/.show-control-string _ble_prompt_xterm_title
    ble/textarea#render/.show-control-string _ble_prompt_screen_title
    ble/textarea#render/.show-control-string _ble_prompt_term_status

    # 編集文字列の一部を描画する場合
    if ((umin<umax)); then
      local uminx uminy umaxx umaxy
      ble/textmap#getxy.out --prefix=umin "$umin"
      ble/textmap#getxy.out --prefix=umax "$umax"

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$uminx" $((uminy-_ble_textarea_scroll))
      ble/textarea#slice-text-buffer "$umin" "$umax"
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$umaxx" $((umaxy-_ble_textarea_scroll))
    fi

    if ((DMIN>=0)); then
      local endY=$((endy-_ble_textarea_scroll))
      if ((endY<height)); then
        if [[ :$render_opts: == *:relative:* ]]; then
          ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$endx" "$endY"
          x=$endx ble/textarea#render/.erase-forward-line.draw
          ble/canvas/panel#clear-after.draw "$_ble_textarea_panel" 0 $((endY+1))
        else
          ble/canvas/panel#clear-after.draw "$_ble_textarea_panel" "$endx" "$endY"
        fi
      fi
    fi
  else
    # 全体更新
    ble/canvas/panel#clear.draw "$_ble_textarea_panel"
    _ble_prompt_rps1_shown=

    # プロンプト描画
    [[ $rps1_enabled ]] && ble/textarea#render/.show-rprompt force
    ble/textarea#render/.show-prompt force
    ble/textarea#render/.show-control-string _ble_prompt_xterm_title  force
    ble/textarea#render/.show-control-string _ble_prompt_screen_title force
    ble/textarea#render/.show-control-string _ble_prompt_term_status  force

    # 全体描画
    _ble_textarea_scroll=$scroll
    _ble_textarea_scroll_new=$_ble_textarea_scroll
    if [[ ! $_ble_textarea_scroll ]]; then
      ble/textarea#slice-text-buffer # → ret
      esc_line=$ret esc_line_set=1
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    else
      ble/textarea#render/.show-scroll-at-first-line

      local gbeg=0
      if ((_ble_textarea_scroll)); then
        ble/textmap#get-index-at 0 $((_ble_textarea_scroll+begy+1)); gbeg=$index
      fi

      local gbegx gbegy
      ble/textmap#getxy.out --prefix=gbeg "$gbeg"
      ((gbegy-=_ble_textarea_scroll))

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
      ((_ble_textarea_scroll==0)) &&
        x=$gbegx ble/textarea#render/.erase-forward-line.draw # ... を消す

      ble/textarea#slice-text-buffer "$gbeg" "$gend"
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    fi
  fi

  # 3 移動
  local gcx=$cx gcy=$((cy-_ble_textarea_scroll))
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gcx" "$gcy"
  ble/canvas/bflush.draw

  # 4 後で使う情報の記録
  _ble_textarea_cur=("$gcx" "$gcy" "$lc" "$lg")
  _ble_textarea_invalidated= _ble_textarea_caret_state=$caret_state

  if [[ ! $bleopt_internal_suppress_bash_output ]]; then
    if [[ ! $esc_line_set ]]; then
      if [[ ! $_ble_textarea_scroll ]]; then
        ble/textarea#slice-text-buffer
        esc_line=$ret
      else
        local _ble_canvas_x=$begx _ble_canvas_y=$begy
        DRAW_BUFF=()

        ble/textarea#render/.show-scroll-at-first-line

        local gbeg=0
        if ((_ble_textarea_scroll)); then
          ble/textmap#get-index-at 0 $((_ble_textarea_scroll+begy+1)); gbeg=$index
        fi
        local gbegx gbegy
        ble/textmap#getxy.out --prefix=gbeg "$gbeg"
        ((gbegy-=_ble_textarea_scroll))

        ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$gbegx" "$gbegy"
        ((_ble_textarea_scroll==0)) &&
          x=$gbegx ble/textarea#render/.erase-forward-line.draw # ... を消す
        ble/textarea#slice-text-buffer "$gbeg" "$gend"
        ble/canvas/put.draw "$ret"

        ble/canvas/sflush.draw -v esc_line
      fi
    fi

    local esc=${_ble_prompt_ps1_data[8]}
    esc=${_ble_prompt_xterm_title_data[10]}$esc
    esc=${_ble_prompt_screen_title_data[10]}$esc
    esc=${_ble_prompt_term_status_data[10]}$esc
    _ble_textarea_cache=(
      "$esc$esc_line"
      "${_ble_textarea_cur[@]}"
      "$_ble_textarea_gendx" "$_ble_textarea_gendy")
  fi
}
function ble/textarea#redraw {
  ble/textarea#invalidate
  ble/textarea#render
}

## @arr _ble_textarea_cache
##   現在表示している内容のキャッシュです。
##   ble/textarea#render で値が設定されます。
##   ble/textarea#redraw-cache はこの情報を元に再描画を行います。
## _ble_textarea_cache[0]:        表示内容
## _ble_textarea_cache[1]: curx   カーソル位置 x
## _ble_textarea_cache[2]: cury   カーソル位置 y
## _ble_textarea_cache[3]: curlc  カーソル位置の文字の文字コード
## _ble_textarea_cache[4]: curlg  カーソル位置の文字の SGR フラグ
## _ble_textarea_cache[5]: gendx  表示末端位置 x
## _ble_textarea_cache[6]: gendy  表示末端位置 y
_ble_textarea_cache=()

function ble/textarea#redraw-cache {
  if [[ ! $_ble_textarea_scroll && ${_ble_textarea_cache[0]+set} ]]; then
    local -a d; d=("${_ble_textarea_cache[@]}")

    local -a DRAW_BUFF=()

    ble/canvas/panel#clear.draw "$_ble_textarea_panel"
    ble/canvas/panel#goto.draw "$_ble_textarea_panel"
    ble/canvas/put.draw "${d[0]}"
    ble/canvas/panel#report-cursor-position "$_ble_textarea_panel" "${d[5]}" "${d[6]}"
    _ble_textarea_gendx=${d[5]}
    _ble_textarea_gendy=${d[6]}

    _ble_textarea_cur=("${d[@]:1:4}")
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble/canvas/bflush.draw
  else
    ble/textarea#redraw
  fi
}

## @fn ble/textarea#adjust-for-bash-bind
##   プロンプト・編集文字列の表示位置修正を行う。
##
##   @remarks
##   この関数は bind -x される関数から呼び出される事を想定している。
##   通常のコマンドとして実行される関数から呼び出す事は想定していない。
##   内部で PS1= 等の設定を行うのでプロンプトの情報が失われる。
##   また、READLINE_LINE, READLINE_POINT 等のグローバル変数の値を変更する。
##
## 2018-03-19
##   どうやら stty -echo の時には READLINE_LINE に値が設定されていても、
##   Bash は何も出力しないという事の様である。
##   従って、単に FEADLINE_LINE に文字を設定すれば良い。
##
function ble/textarea#adjust-for-bash-bind {
  ble-edit/adjust-PS1
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    READLINE_LINE=$'\n' READLINE_POINT=0 READLINE_MARK=0
  else
    # bash が表示するプロンプトを見えなくする
    # (現在のカーソルの左側にある文字を再度上書きさせる)
    local -a DRAW_BUFF=()
    local ret lc=${_ble_textarea_cur[2]} lg=${_ble_textarea_cur[3]}
    ble/util/c2s "$lc"
    READLINE_LINE=$ret READLINE_MARK=0
    if ((_ble_textarea_cur[0]==0)); then
      READLINE_POINT=0
    else
      ble/util/c2w "$lc"
      ((ret>0)) && ble/canvas/put-cub.draw "$ret"
      ble/util/c2bc "$lc"
      READLINE_POINT=$ret
    fi

    ble/color/g2sgr "$lg"
    ble/canvas/put.draw "$ret"

    # 2018-03-19 stty -echo の時は Bash は何も出力しないので調整は不要
    #ble/canvas/bflush.draw
  fi
}

function ble/textarea#save-state {
  local prefix=$1
  local -a vars=()

  # _ble_prompt_ps1_data
  ble/array#push vars _ble_edit_PS1 _ble_prompt_ps1_data

  # _ble_edit_*
  ble/array#push vars "${_ble_edit_VARNAMES[@]}"

  # _ble_textmap_*
  ble/array#push vars "${_ble_textmap_VARNAMES[@]}"

  # _ble_highlight_layer_*
  ble/array#push vars _ble_highlight_layer__list
  local layer names
  for layer in "${_ble_highlight_layer__list[@]}"; do
    builtin eval "ble/array#push vars \"\${!_ble_highlight_layer_$layer@}\""
  done

  # _ble_textarea_*
  ble/array#push vars "${_ble_textarea_VARNAMES[@]}"

  # _ble_syntax_*
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"

  # user-defined local variables
  ble/array#push vars "${_ble_textarea_local_VARNAMES[@]}"

  builtin eval -- "${prefix}_VARNAMES=(\"\${vars[@]}\")"
  ble/util/save-vars "$prefix" "${vars[@]}"
}
function ble/textarea#restore-state {
  local prefix=$1
  if builtin eval "[[ \$prefix && \${${prefix}_VARNAMES+set} ]]"; then
    builtin eval "ble/util/restore-vars $prefix \"\${${prefix}_VARNAMES[@]}\""
  else
    ble/util/print "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}
function ble/textarea#clear-state {
  local prefix=$1
  if [[ $prefix ]]; then
    local vars=${prefix}_VARNAMES
    builtin eval "builtin unset -v \"\${$vars[@]/#/$prefix}\" $vars"
  else
    ble/util/print "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}

# 非同期更新

_ble_textarea_render_defer=
function ble/textarea#render-defer.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_textarea_render_defer ]] || return 0

  local ble_textarea_render_defer_running=1
  ble/util/buffer.flush >&2
  _ble_textarea_render_defer=
  blehook/invoke textarea_render_defer
  ble/textarea#render update

  [[ $_ble_textarea_render_defer ]] &&
    ble/util/idle.continue
  return 0
}
ble/function#try ble/util/idle.push-background ble/textarea#render-defer.idle

# 
#------------------------------------------------------------------------------

function ble/widget/.update-textmap {
  # rps1 がある時の幅の再現
  local cols=${COLUMNS:-80}
  local rps1w=${_ble_prompt_rps1_data[11]}
  local rps1q=${_ble_prompt_rps1_data[12]}
  [[ $rps1q ]] && ((cols-=rps1w+1,_ble_term_xenl||cols--))

  local x=$_ble_textmap_begx y=$_ble_textmap_begy
  COLUMNS=$cols ble/textmap#update "$_ble_edit_str"
}
function ble/widget/do-lowercase-version {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag)) char=$((KEYS[0]&_ble_decode_MaskChar))
  if ((65<=char&&char<=90)); then
    ble/decode/widget/skip-lastwidget
    ble/decode/widget/redispatch-by-keys $((flag|char+32)) "${KEYS[@]:1}"
  else
    return 125
  fi
}

# 
# **** redraw, clear-screen, etc ****                             @widget.clear

function ble/widget/redraw-line {
  ble-edit/content/clear-arg
  ble/textarea#invalidate
}
function ble/widget/clear-screen {
  ble-edit/content/clear-arg
  ble/edit/enter-command-layout
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble/canvas/panel/goto-top-dock.draw
  ble/canvas/bflush.draw
  ble/util/buffer "$_ble_term_clear"
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/term/visible-bell/cancel-erasure
}
function ble/widget/clear-display {
  ble/util/buffer $'\e[3J'
  ble/widget/clear-screen
}
function ble/widget/display-shell-version {
  ble-edit/content/clear-arg
  ble/widget/print \
    "GNU bash, version $BASH_VERSION ($MACHTYPE)" \
    "ble.sh, version $BLE_VERSION (noarch)"
}
function ble/widget/readline-dump-functions {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -P'
  ble/widget/print "$ret"
}
function ble/widget/readline-dump-macros {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -S'
  ble/widget/print "$ret"
}
function ble/widget/readline-dump-variables {
  ble-edit/content/clear-arg
  local ret
  ble/util/assign ret 'ble/builtin/bind -V'
  ble/widget/print "$ret"
}
function ble/widget/re-read-init-file {
  ble-edit/content/clear-arg

  local inputrc=$INPUTRC
  [[ $inputrc && -e $inputrc ]] || inputrc=~/.inputrc
  [[ -e $inputrc ]] || return 0
  ble/decode/read-inputrc "$inputrc"

  # Note: 読み終わった "後" に "既定" に戻す #D1038
  _ble_builtin_bind_keymap=
}

# **** mark, kill, copy ****                                       @widget.mark

function ble/widget/overwrite-mode {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_overwrite_mode ]]; then
    _ble_edit_overwrite_mode=
  else
    _ble_edit_overwrite_mode=1
  fi
}

function ble/widget/set-mark {
  ble-edit/content/clear-arg
  _ble_edit_mark=$_ble_edit_ind
  _ble_edit_mark_active=1
}
function ble/widget/kill-forward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind>=${#_ble_edit_str})) && return 0
  ble-edit/content/push-kill-ring "${_ble_edit_str:_ble_edit_ind}"
  ble-edit/content/replace "$_ble_edit_ind" ${#_ble_edit_str} ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble/widget/kill-backward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind==0)) && return 0
  ble-edit/content/push-kill-ring "${_ble_edit_str::_ble_edit_ind}"
  ble-edit/content/replace 0 "$_ble_edit_ind" ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble/widget/exchange-point-and-mark {
  ble-edit/content/clear-arg
  local m=$_ble_edit_mark p=$_ble_edit_ind
  _ble_edit_ind=$m _ble_edit_mark=$p
}
function ble/widget/@marked {
  if [[ $_ble_edit_mark_active != S ]]; then
    _ble_edit_mark=$_ble_edit_ind
    _ble_edit_mark_active=S
  fi
  ble/decode/widget/dispatch "$@"
}
function ble/widget/@nomarked {
  if [[ $_ble_edit_mark_active == S ]]; then
    _ble_edit_mark_active=
  fi
  ble/decode/widget/dispatch "$@"
}

## @fn ble/widget/.process-range-argument P0 P1; p0 p1 len ?
##   @param[in]  P0  範囲の端点を指定します。
##   @param[in]  P1  もう一つの範囲の端点を指定します。
##   @param[out] p0  範囲の開始点を返します。
##   @param[out] p1  範囲の終端点を返します。
##   @param[out] len 範囲の長さを返します。
##   @param[out] $?
##     範囲が有限の長さを持つ場合に正常終了します。
##     範囲が空の場合に 1 を返します。
function ble/widget/.process-range-argument {
  p0=$1 p1=$2 len=${#_ble_edit_str}
  local pt
  ((
    p0>len?(p0=len):p0<0&&(p0=0),
    p1>len?(p1=len):p0<0&&(p1=0),
    p1<p0&&(pt=p1,p1=p0,p0=pt),
    (len=p1-p0)>0
  ))
}
## @fn ble/widget/.delete-range P0 P1 [opts]
function ble/widget/.delete-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # delete
  if ((len)); then
    ble-edit/content/replace "$p0" "$p1" ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## @fn ble/widget/.kill-range P0 P1 [opts [kill_type]]
function ble/widget/.kill-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # copy
  ble-edit/content/push-kill-ring "${_ble_edit_str:p0:len}" "$4"

  # delete
  if ((len)); then
    ble-edit/content/replace "$p0" "$p1" ''
    ((
      _ble_edit_ind>p1? (_ble_edit_ind-=len):
      _ble_edit_ind>p0&&(_ble_edit_ind=p0),
      _ble_edit_mark>p1? (_ble_edit_mark-=len):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)
    ))
  fi
  return 0
}
## @fn ble/widget/.copy-range P0 P1 [opts [kill_type]]
function ble/widget/.copy-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || return 1

  # copy
  ble-edit/content/push-kill-ring "${_ble_edit_str:p0:len}" "$4"
}
## @fn ble/widget/.replace-range P0 P1 string
function ble/widget/.replace-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}"
  local insert; ble-edit/content/replace-limited "$p0" "$p1" "$3"
  local inslen=${#insert} delta
  ((delta=inslen-len)) &&
    ((_ble_edit_ind>p1?(_ble_edit_ind+=delta):
      _ble_edit_ind>=p0&&(_ble_edit_ind=p0+inslen),
      _ble_edit_mark>p1?(_ble_edit_mark+=delta):
      _ble_edit_mark>p0&&(_ble_edit_mark=p0)))
  return 0
}
## @widget delete-region
##   領域を削除します。
function ble/widget/delete-region {
  ble-edit/content/clear-arg
  ble/widget/.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget kill-region
##   領域を切り取ります。
function ble/widget/kill-region {
  ble-edit/content/clear-arg
  ble/widget/.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget copy-region
##   領域を転写します。
function ble/widget/copy-region {
  ble-edit/content/clear-arg
  ble/widget/.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## @widget delete-region-or widget
##   mark が active の時に領域を削除します。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/delete-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}
## @widget kill-region-or widget
##   mark が active の時に領域を切り取ります。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/kill-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/kill-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}
## @widget copy-region-or widget
##   mark が active の時に領域を転写します。
##   それ以外の時に編集関数 widget を実行します。
##   @param[in] widget
function ble/widget/copy-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/copy-region
  else
    ble/decode/widget/dispatch "$@"
  fi
}

## @widget yank
function ble/widget/yank {
  local arg; ble-edit/content/get-arg 1

  local nkill=${#_ble_edit_kill_ring[@]}
  if ((nkill==0)); then
    ble/widget/.bell 'no strings in kill-ring'
    _ble_edit_yank_index=
    return 1
  fi

  local index=$_ble_edit_kill_index
  local delta=$((arg-1))
  if ((delta)); then
    ((index=(index+delta)%nkill,
      index=(index+nkill)%nkill))
    _ble_edit_kill_index=$index
  fi

  local insert=${_ble_edit_kill_ring[index]}
  _ble_edit_yank_index=$index
  if [[ $insert ]]; then
    ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$insert"
    ((_ble_edit_mark=_ble_edit_ind,
      _ble_edit_ind+=${#insert}))
    _ble_edit_mark_active=
  fi
}

_ble_edit_yank_index=
function ble/edit/yankpop.impl {
  local arg=$1
  local nkill=${#_ble_edit_kill_ring[@]}
  ((_ble_edit_yank_index=(_ble_edit_yank_index+arg)%nkill,
    _ble_edit_yank_index=(_ble_edit_yank_index+nkill)%nkill))
  local insert=${_ble_edit_kill_ring[_ble_edit_yank_index]}
  ble-edit/content/replace-limited "$_ble_edit_mark" "$_ble_edit_ind" "$insert"
  ((_ble_edit_ind=_ble_edit_mark+${#insert}))
}
function ble/widget/yank-pop {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  if ! [[ $_ble_edit_yank_index && ${LASTWIDGET%%' '*} == ble/widget/yank ]]; then
    ble/widget/.bell
    return 1
  fi

  [[ :$opts: == *:backward:* ]] && ((arg=-arg))

  ble/edit/yankpop.impl "$arg"
  _ble_edit_mark_active=insert
  ble/decode/keymap/push yankpop
}
function ble/widget/yankpop/next {
  local arg; ble-edit/content/get-arg 1
  ble/edit/yankpop.impl "$arg"
}
function ble/widget/yankpop/prev {
  local arg; ble-edit/content/get-arg 1
  ble/edit/yankpop.impl $((-arg))
}
function ble/widget/yankpop/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
}
function ble/widget/yankpop/cancel {
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" ''
  _ble_edit_ind=$_ble_edit_mark
  ble/widget/yankpop/exit
}
function ble/widget/yankpop/exit-default {
  ble/widget/yankpop/exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}
function ble-decode/keymap:yankpop/define {
  ble-decode/keymap:safe/bind-arg yankpop/exit-default
  ble-bind -f __default__ 'yankpop/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'yankpop/cancel'
  ble-bind -f 'C-x C-g'   'yankpop/cancel'
  ble-bind -f 'C-M-g'     'yankpop/cancel'
  ble-bind -f 'M-y'       'yankpop/next'
  ble-bind -f 'M-S-y'     'yankpop/prev'
  ble-bind -f 'M-Y'       'yankpop/prev'
}

# **** bell ****                                                     @edit.bell

function ble/widget/.bell {
  [[ $bleopt_edit_vbell ]] && ble/term/visible-bell "$1"
  [[ $bleopt_edit_abell ]] && ble/term/audible-bell
  return 0
}

# blehook/declare widget_bell (defined in def.sh)
function ble/widget/bell {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_arg=
  blehook/invoke widget_bell
  ble/widget/.bell "$1"
}

function ble/widget/nop { :; }

# **** insert ****                                                 @edit.insert

function ble/widget/insert-string {
  local IFS=$_ble_term_IFS
  local content="$*"
  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repetition number $arg"
    return 1
  elif ((arg==0)); then
    return 0
  elif ((arg>1)); then
    local ret; ble/string#repeat "$content" "$arg"; content=$ret
  fi
  ble/widget/.insert-string "$content"
}
function ble/widget/.insert-string {
  local insert=$1
  [[ $insert ]] || return 1

  ble-edit/content/replace-limited "$_ble_edit_ind" "$_ble_edit_ind" "$insert"
  local dx=${#insert}
  ((
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  ))
  _ble_edit_mark_active=
}
if [[ -c /dev/clipboard ]]; then
  function ble/widget/paste-from-clipboard {
    local clipboard
    if ! ble/util/readfile clipboard /dev/clipboard; then
      ble/widget/.bell
      return 1
    fi

    ble/widget/insert-string "$clipboard"
    return 0
  }
fi

## @fn ble/widget/insert-arg.impl beg end index delta nth
##   @param[in] beg end
##     置換範囲を指定します。
##   @param[in] index
##     起点の履歴番号を指定します。
##   @param[in] delta
##     (最低の)移動量を指定します。
##   @param[in] nth
##     '$', '^', n 等の単語指定子を指定します。
##
##   @var _ble_edit_lastarg_index
##     最後に挿入した最終引数の履歴番号です。
##   @var _ble_edit_lastarg_delta
##     最後に挿入した時の移動量です。
##     繰り返し呼び出した時の移動方向を決定するのに使います。
##   @var _ble_edit_lastarg_nth
##     最後に挿入した時の単語指定子です。
##
_ble_edit_lastarg_index=
_ble_edit_lastarg_delta=
_ble_edit_lastarg_nth=
function ble/widget/insert-arg.impl {
  local beg=$1 end=$2 index=$3 delta=$4 nth=$5
  ((delta)) || delta=1

  ble/history/initialize
  local hit= lastarg=
  local decl=$(
    local original=${_ble_edit_str:beg:end-beg}
    local count=; ((delta>0)) && count=_ble_history_COUNT
    while :; do
      # index = next history index to check
      if ((delta>0)); then
        ((index+1>=count)) && break
        ((index+=delta,delta=1))
        ((index>=count&&(index=count-1)))
      else
        ((index-1<0)) && break
        ((index+=delta,delta=-1))
        ((index<0&&(index=0)))
      fi

      local entry; ble/history/get-edited-entry "$index"
      builtin history -s -- "$entry"
      local hist_expanded
      if ble-edit/hist_expanded.update '!!:'"$nth" &&
          [[ $hist_expanded != "$original" ]]; then
        hit=1 lastarg=$hist_expanded
        ble/util/declare-print-definitions hit lastarg
        break
      fi
    done
    _ble_edit_lastarg_index=$index
    _ble_edit_lastarg_delta=$delta
    _ble_edit_lastarg_nth=$nth
    ble/util/declare-print-definitions \
      _ble_edit_lastarg_index \
      _ble_edit_lastarg_delta \
      _ble_edit_lastarg_nth
  )
  builtin eval -- "$decl"

  if [[ $hit ]]; then
    local insert; ble-edit/content/replace-limited "$beg" "$end" "$lastarg"
    ((_ble_edit_mark=beg,_ble_edit_ind=beg+${#insert}))
    return 0
  else
    ble/widget/.bell
    return 1
  fi
}
function ble/widget/insert-nth-argument {
  ble/history/initialize
  local arg; ble-edit/content/get-arg '^'
  local beg=$_ble_edit_ind end=$_ble_edit_ind
  local index=$_ble_history_INDEX
  local delta=-1 nth=$arg
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth"
}
function ble/widget/insert-last-argument {
  ble/history/initialize
  local arg; ble-edit/content/get-arg '$'
  local beg=$_ble_edit_ind end=$_ble_edit_ind
  local index=$_ble_history_INDEX
  local delta=-1 nth=$arg
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth" || return "$?"
  _ble_edit_mark_active=insert
  ble/decode/keymap/push lastarg
}
function ble/widget/lastarg/next {
  local arg; ble-edit/content/get-arg 1
  local beg=$_ble_edit_mark
  local end=$_ble_edit_ind
  local index=$_ble_edit_lastarg_index

  local delta
  if [[ $arg ]]; then
    delta=$((-arg))
  else
    ((delta=_ble_edit_lastarg_delta>=0?1:-1))
  fi

  local nth=$_ble_edit_lastarg_nth
  ble/widget/insert-arg.impl "$beg" "$end" "$index" "$delta" "$nth"
}
function ble/widget/lastarg/exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
}
function ble/widget/lastarg/cancel {
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" ''
  _ble_edit_ind=$_ble_edit_mark
  ble/widget/lastarg/exit
}
function ble/widget/lastarg/exit-default {
  ble/widget/lastarg/exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}
function ble/highlight/layer:region/mark:insert/get-face {
  face=region_insert
}

function ble-decode/keymap:lastarg/define {
  ble-decode/keymap:safe/bind-arg lastarg/exit-default

  ble-bind -f __default__ 'lastarg/exit-default'
  ble-bind -f __line_limit__ nop
  ble-bind -f 'C-g'       'lastarg/cancel'
  ble-bind -f 'C-x C-g'   'lastarg/cancel'
  ble-bind -f 'C-M-g'     'lastarg/cancel'
  ble-bind -f 'M-.'       'lastarg/next'
  ble-bind -f 'M-_'       'lastarg/next'
}

## @widget self-insert
##   文字を挿入する。
##
##   @var[in] _ble_edit_arg
##     繰り返し回数を指定する。
##
##   @var[in] ble_widget_self_insert_opts
##     コロン区切りの設定のリストを指定する。
##
##     nolineext は上書きモードにおいて、行の長さを拡張しない。
##     行の長さが足りない場合は操作をキャンセルする。
##     vi.sh の r, gr による挿入を想定する。
##
function ble/widget/self-insert {
  local code=$((KEYS[0]&_ble_decode_MaskChar))
  ((code==0)) && return 0

  # Note: Bash 3.0 では ^? (DEL) の処理に問題があるので、
  #   ^@ (NUL) と同様に単に無視する事にする #D1093
  ((code==127&&_ble_bash<30100)) && return 0

  local ibeg=$_ble_edit_ind iend=$_ble_edit_ind
  local ret ins; ble/util/c2s "$code"; ins=$ret

  local arg; ble-edit/content/get-arg 1
  if ((arg<0)); then
    ble/widget/.bell "negative repetition number $arg"
    return 1
  elif ((arg==0)) || [[ ! $ins ]]; then
    arg=0 ins=
  elif ((arg>1)); then
    ble/string#repeat "$ins" "$arg"; ins=$ret
  fi
  # Note: arg はこの時点での ins の文字数になっているとは限らない。
  #   現在の LC_CTYPE で対応する文字がない場合 \uXXXX 等に変換される為。

  if [[ $bleopt_delete_selection_mode && $_ble_edit_mark_active ]]; then
    # 選択範囲を置き換える。
    ((_ble_edit_mark<_ble_edit_ind?(ibeg=_ble_edit_mark):(iend=_ble_edit_mark),
      _ble_edit_ind=ibeg))
    ((arg==0&&ibeg==iend)) && return 0
  elif [[ $_ble_edit_overwrite_mode ]] && ((code!=10&&code!=9)); then
    ((arg==0)) && return 0

    local removed_width
    if [[ $_ble_edit_overwrite_mode == R ]]; then
      local removed_text=${_ble_edit_str:ibeg:arg}
      removed_text=${removed_text%%[$'\n\t']*}
      removed_width=${#removed_text}
      ((iend+=removed_width))
    else
      # 上書きモードの時は Unicode 文字幅を考慮して既存の文字を置き換える。
      # ※現在の LC_CTYPE で対応する文字がない場合でも、意図しない動作を防ぐために、
      #   対応していたと想定した時の文字幅で削除する。
      local ret w; ble/util/c2w-edit "$code"; w=$((arg*ret))

      local iN=${#_ble_edit_str}
      for ((removed_width=0;removed_width<w&&iend<iN;iend++)); do
        local c1 w1
        ble/util/s2c "${_ble_edit_str:iend:1}"; c1=$ret
        [[ $c1 == 0 || $c1 == 10 || $c1 == 9 ]] && break
        ble/util/c2w-edit "$c1"; w1=$ret
        ((removed_width+=w1))
      done

      ((removed_width>w)) && ins=$ins${_ble_string_prototype::removed_width-w}
    fi

    # これは vi.sh の r gr で設定する変数
    if [[ :$ble_widget_self_insert_opts: == *:nolineext:* ]]; then
      if ((removed_width<arg)); then
        ble/widget/.bell
        return 0
      fi
    fi
  fi

  # コマンドライン文字数制限
  local insert; ble-edit/content/replace-limited "$ibeg" "$iend" "$ins"
  ((_ble_edit_ind+=${#insert},
    _ble_edit_mark>ibeg&&(
      _ble_edit_mark<iend?(
        _ble_edit_mark=_ble_edit_ind
      ):(
        _ble_edit_mark+=${#insert}-(iend-ibeg)))))
  _ble_edit_mark_active=
  return 0
}

function ble/widget/batch-insert.progress {
  ((index%${1:-257}==0&&N>=2000)) || return 1
  local ble_batch_insert_index=$index
  local ble_batch_insert_count=$N
  builtin eval -- "$_ble_decode_show_progress_hook"
}
function ble/widget/batch-insert {
  local -a chars; chars=("${KEYS[@]}")

  local -a KEYS=()
  local index=0 N=${#chars[@]}
  if [[ $_ble_edit_overwrite_mode ]]; then
    while ((index<N&&_ble_edit_ind<${#_ble_edit_str})); do
      KEYS=${chars[index]} ble/widget/self-insert
      ((index++))
    done
    ((index<N)) || return 0
  fi

  # コマンドライン文字数制限
  if [[ $bleopt_line_limit_type == discard ]]; then
    local limit=$((bleopt_line_limit_length))
    if ((limit&&${#_ble_edit_str}+N-index>=limit)); then
      chars=("${chars[@]::limit-${#_ble_edit_str}}")
      N=${#chars[@]}
      ((index<N)) || { ble/widget/.bell; return 1; }
    fi
  fi

  while ((index<N)) && [[ $_ble_edit_arg || $_ble_edit_mark_active ]]; do
    KEYS=${chars[index]} ble/widget/self-insert
    ((index++))
    ble/widget/batch-insert.progress
  done

  if ((index<N)); then
    # NUL を unset してから一括で変換する
    local index0=$index ret ins
    for ((;index<N;index++)); do
      ((chars[index])) || builtin unset -v 'chars[index]'
      ble/widget/batch-insert.progress 2357
    done
    ble/util/chars2s "${chars[@]:index0}"; ins=$ret
    ble/widget/insert-string "$ins"
  fi

  ble-edit/content/check-limit truncate
}

# quoted insert
function ble/widget/quoted-insert-char.hook {
  ble/widget/self-insert
}
function ble/widget/quoted-insert-char {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/quoted-insert-char.hook
  return 147
}
function ble/widget/quoted-insert.hook {
  local flag=$((KEYS[0]&_ble_decode_MaskFlag))
  local char=$((KEYS[0]&_ble_decode_MaskChar))
  if ((flag==0&&char<_ble_decode_FunctionKeyBase)); then
    ble/widget/self-insert
  elif ((flag==_ble_decode_Ctrl&&(char==63||91<=char&&char<=122)&&(char&0x1F)!=0)); then
    # C-x (C-@ 以外) は変換して制御文字を挿入する。
    ((char=char==63?127:char&0x1F))
    local -a KEYS; KEYS=("$char")
    ble/widget/self-insert
  else
    local -a KEYS; KEYS=("${CHARS[@]}")
    ble/widget/batch-insert
  fi
}
function ble/widget/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_key__hook=ble/widget/quoted-insert.hook
  return 147
}

_ble_edit_bracketed_paste=()
_ble_edit_bracketed_paste_proc=
_ble_edit_bracketed_paste_count=0
function ble/widget/bracketed-paste {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_bracketed_paste=()
  _ble_edit_bracketed_paste_count=0
  _ble_edit_bracketed_paste_proc=ble/widget/bracketed-paste.proc
  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 147
}
function ble/widget/bracketed-paste.hook/check-end {
  local is_end= chars=
  if ((_ble_edit_bracketed_paste_count>=5)); then
    IFS=: builtin eval '_ble_edit_bracketed_paste=("${_ble_edit_bracketed_paste[*]}")'
    chars=:$_ble_edit_bracketed_paste
    if [[ $chars == *:50:48:49:126 ]]; then
      if [[ $chars == *:27:91:50:48:49:126 ]]; then # ESC [ 2 0 1 ~
        chars=${chars%:27:91:50:48:49:126} is_end=1
      elif [[ $chars == *:155:50:48:49:126 ]]; then # CSI 2 0 1 ~
        chars=${chars%:155:50:48:49:126} is_end=1
      fi
    fi
  fi

  [[ $is_end ]] || return 1

  _ble_decode_char__hook=
  chars=:${chars//:/::}:
  chars=${chars//:13::10:/:10:} # CR LF -> LF
  chars=${chars//:13:/:10:} # CR -> LF
  ble/string#split-words chars "${chars//:/ }"

  local proc=$_ble_edit_bracketed_paste_proc
  _ble_edit_bracketed_paste_proc=
  [[ $proc ]] && builtin eval -- "$proc \"\${chars[@]}\""
  return 0
}
function ble/widget/bracketed-paste.hook {
  ((_ble_edit_bracketed_paste_count%1000==0)) &&
    IFS=: builtin eval '_ble_edit_bracketed_paste=("${_ble_edit_bracketed_paste[*]}")' # contract

  _ble_edit_bracketed_paste[_ble_edit_bracketed_paste_count++]=$1
  (($1==126)) && ble/widget/bracketed-paste.hook/check-end && return 0

  # ble-decode-char にある次の文字を取り出してできるだけここで処理する。
  if ((!_ble_debug_keylog_enabled)) && [[ ! $_ble_decode_keylog_chars_enabled ]]; then
    local char
    while ble/decode/char-hook/next-char; do
      _ble_edit_bracketed_paste[_ble_edit_bracketed_paste_count++]=$char
      ((char==126)) && ble/widget/bracketed-paste.hook/check-end && return 0
    done
  fi

  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 147
}
function ble/widget/bracketed-paste.proc {
  local -a KEYS; KEYS=("$@")
  ble/widget/batch-insert
}


function ble/widget/transpose-chars {
  local arg; ble-edit/content/get-arg ''
  if ((arg==0)); then
    [[ ! $arg ]] && ble-edit/content/eolp &&
      ((_ble_edit_ind>0&&_ble_edit_ind--))
    arg=1
  fi

  local p q r
  if ((arg>0)); then
    ((p=_ble_edit_ind-1,
      q=_ble_edit_ind,
      r=_ble_edit_ind+arg))
  else # arg<0
    ((p=_ble_edit_ind-1+arg,
      q=_ble_edit_ind,
      r=_ble_edit_ind+1))
  fi

  if ((p<0||${#_ble_edit_str}<r)); then
    ((_ble_edit_ind=arg<0?0:${#_ble_edit_str}))
    ble/widget/.bell
    return 1
  fi

  local a=${_ble_edit_str:p:q-p}
  local b=${_ble_edit_str:q:r-q}
  ble-edit/content/replace "$p" "$r" "$b$a"
  ((_ble_edit_ind+=arg))
  return 0
}

# 
# **** delete-char ****                                            @edit.delete

function ble/widget/.delete-backward-char {
  local a=${1:-1}
  if ((_ble_edit_ind-a<0)); then
    return 1
  fi

  local ins=
  if [[ $_ble_edit_overwrite_mode ]]; then
    local next=${_ble_edit_str:_ble_edit_ind:1}
    if [[ $next && $next != [$'\n\t'] ]]; then
      if [[ $_ble_edit_overwrite_mode == R ]]; then
        local w=$a
      else
        local w=0 ret i
        for ((i=0;i<a;i++)); do
          ble/util/s2c "${_ble_edit_str:_ble_edit_ind-a+i:1}"
          ble/util/c2w-edit "$ret"
          ((w+=ret))
        done
      fi
      if ((w)); then
        local ret; ble/string#repeat ' ' "$w"; ins=$ret
        ((_ble_edit_mark>=_ble_edit_ind&&(_ble_edit_mark+=w)))
      fi
    fi
  fi

  ble-edit/content/replace $((_ble_edit_ind-a)) "$_ble_edit_ind" "$ins"
  ((_ble_edit_ind-=a,
    _ble_edit_ind+a<_ble_edit_mark?(_ble_edit_mark-=a):
    _ble_edit_ind<_ble_edit_mark&&(_ble_edit_mark=_ble_edit_ind)))
  return 0
}

function ble/widget/.delete-char {
  local a=${1:-1}
  if ((a>0)); then
    # delete-forward-char
    if ((${#_ble_edit_str}<_ble_edit_ind+a)); then
      return 1
    else
      ble-edit/content/replace "$_ble_edit_ind" $((_ble_edit_ind+a)) ''
    fi
  elif ((a<0)); then
    # delete-backward-char
    ble/widget/.delete-backward-char $((-a)); return "$?"
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      ble-edit/content/replace "$_ble_edit_ind" $((_ble_edit_ind+1)) ''
    else
      _ble_edit_ind=${#_ble_edit_str}
      ble/widget/.delete-backward-char 1; return "$?"
    fi
  fi

  ((_ble_edit_mark>_ble_edit_ind&&_ble_edit_mark--))
  return 0
}
function ble/widget/delete-forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.delete-char "$arg" || ble/widget/.bell
}
function ble/widget/delete-backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0

  # keymap/vi.sh (white widget)
  [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more

  ble/widget/.delete-char $((-arg)) || ble/widget/.bell

  # keymap/vi.sh (white widget)
  [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more
}

_ble_edit_exit_count=0
function ble/widget/exit {
  ble-edit/content/clear-arg

  if [[ $WIDGET == "$LASTWIDGET" ]]; then
    ((_ble_edit_exit_count++))
  else
    _ble_edit_exit_count=1
  fi

  local ret; ble-edit/eval-IGNOREEOF
  if ((_ble_edit_exit_count<=ret)); then
    local remain=$((ret-_ble_edit_exit_count+1))
    ble/widget/.bell 'IGNOREEOF'
    ble/widget/print "IGNOREEOF($remain): Use \"exit\" to leave the shell."
    return 0
  fi

  local opts=$1
  ((_ble_bash>=40000)) && shopt -q checkjobs &>/dev/null && opts=$opts:checkjobs

  if [[ $bleopt_allow_exit_with_jobs ]]; then
    local ret
    if ble/util/assign ret 'compgen -A stopped -- ""' 2>/dev/null; [[ $ret ]]; then
      opts=$opts:twice
    elif [[ :$opts: == *:checkjobs:* ]]; then
      if ble/util/assign ret 'compgen -A running -- ""' 2>/dev/null; [[ $ret ]]; then
        opts=$opts:twice
      fi
    else
      opts=$opts:force
    fi
  fi

  if ! [[ :$opts: == *:force:* || :$opts: == *:twice:* && _ble_edit_exit_count -ge 2 ]]; then
    # job が残っている場合
    local joblist
    ble/util/joblist
    if ((${#joblist[@]})); then
      ble/widget/.bell "exit: There are remaining jobs."
      local q=\' Q="'\''" message=
      if [[ :$opts: == *:twice:* ]]; then
        message='There are remaining jobs. Input the same key to exit the shell anyway.'
      else
        message='There are remaining jobs. Use "exit" to leave the shell.'
      fi
      ble/widget/internal-command "ble/util/print '${_ble_term_setaf[12]}[ble: ${message//$q/$Q}]$_ble_term_sgr0'; jobs"
      return "$?"
    fi
  elif [[ :$opts: == *:checkjobs:* ]]; then
    local joblist
    ble/util/joblist
    ((${#joblist[@]})) && printf '%s\n' "${#joblist[@]}"
  fi

  #_ble_edit_detach_flag=exit

  #ble/term/visible-bell ' Bye!! ' # 最後に vbell を出すと一時ファイルが残る
  _ble_edit_line_disabled=1 ble/textarea#render

  # Note: bleopt_syntax_debug=1 の時 ble/textarea#render の中で info が設定されるので、
  #   これは ble/textarea#render より後である必要がある。
  ble/edit/enter-command-layout

  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
  ble/canvas/bflush.draw
  ble/util/buffer.print "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0"
  ble/util/buffer.flush >&2

  # Note: ジョブが残っている場合でも強制終了させる為 2 回連続で呼び出す必要がある。
  builtin exit 0 &>/dev/null
  builtin exit 0 &>/dev/null
  return 1
}
function ble/widget/delete-forward-char-or-exit {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/exit
  fi
}
function ble/widget/delete-forward-backward-char {
  ble-edit/content/clear-arg
  ble/widget/.delete-char 0 || ble/widget/.bell
}
function ble/widget/delete-forward-char-or-list {
  local right=${_ble_edit_str:_ble_edit_ind}
  if [[ ! $right || $right == $'\n'* ]]; then
    ble/widget/complete show_menu
  else
    ble/widget/delete-forward-char
  fi
}

function ble/widget/delete-horizontal-space {
  local arg; ble-edit/content/get-arg ''

  local b=0 rex=$'[ \t]+$'
  [[ ${_ble_edit_str::_ble_edit_ind} =~ $rex ]] &&
    b=${#BASH_REMATCH}

  local a=0 rex=$'^[ \t]+'
  [[ ! $arg && ${_ble_edit_str:_ble_edit_ind} =~ $rex ]] &&
    a=${#BASH_REMATCH}

  ble/widget/.delete-range $((_ble_edit_ind-b)) $((_ble_edit_ind+a))
}

# 
# **** cursor move ****                                            @edit.cursor

function ble/widget/.forward-char {
  ((_ble_edit_ind+=${1:-1}))
  if ((_ble_edit_ind>${#_ble_edit_str})); then
    _ble_edit_ind=${#_ble_edit_str}
    return 1
  elif ((_ble_edit_ind<0)); then
    _ble_edit_ind=0
    return 1
  fi
}
function ble/widget/forward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.forward-char "$arg" || ble/widget/.bell
}
function ble/widget/backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  ble/widget/.forward-char $((-arg)) || ble/widget/.bell
}

_ble_edit_character_search_arg=
function ble/widget/character-search-forward {
  local arg; ble-edit/content/get-arg 1
  _ble_edit_character_search_arg=$arg
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/character-search.hook
}
function ble/widget/character-search-backward {
  local arg; ble-edit/content/get-arg 1
  ((_ble_edit_character_search_arg=-arg))
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/character-search.hook
}
function ble/widget/character-search.hook {
  local char=${KEYS[0]}
  local ret; ble/util/c2s "${KEYS[0]}"; local c=$ret
  [[ $c ]] || return 1 # Note: C-@ の時は無視
  local arg=$_ble_edit_character_search_arg
  if ((arg>0)); then
    local right=${_ble_edit_str:_ble_edit_ind+1}
    if ble/string#index-of "$right" "$c" "$arg"; then
      ((_ble_edit_ind=_ble_edit_ind+1+ret))
    elif ble/string#last-index-of "$right" "$c"; then
      ble/widget/.bell "${arg}th character not found"
      ((_ble_edit_ind=_ble_edit_ind+1+ret))
    else
      ble/widget/.bell 'character not found'
      return 1
    fi
  elif ((arg<0)); then
    local left=${_ble_edit_str::_ble_edit_ind}
    if ble/string#last-index-of "$left" "$c" $((-arg)); then
      _ble_edit_ind=$ret
    elif ble/string#index-of "$left" "$c"; then
      ble/widget/.bell "$((-arg))th last character not found"
      _ble_edit_ind=$ret
    else
      ble/widget/.bell 'character not found'
      return 1
    fi
  fi
  return 0
}

## @fn ble/widget/.locate-forward-byte delta
##   @param[in] delta
##   @var[in,out] index
function ble/widget/.locate-forward-byte {
  local delta=$1 ret
  if ((delta==0)); then
    return 0
  elif ((delta>0)); then
    local right=${_ble_edit_str:index:delta}
    local rlen=${#right}
    ble/util/strlen "$right"; local rsz=$ret
    if ((delta>=rsz)); then
      ((index+=rlen))
      ((delta==rsz)); return "$?"
    else
      # 二分法
      while ((delta&&rlen>=2)); do
        local mlen=$((rlen/2))
        local m=${right::mlen}
        ble/util/strlen "$m"; local msz=$ret
        if ((delta>=msz)); then
          right=${right:mlen}
          ((index+=mlen,
            rlen-=mlen,
            delta-=msz))
          ((rlen>delta)) &&
            right=${right::delta} rlen=$delta
        else
          right=$m rlen=$mlen
        fi
      done
      ((delta&&rlen&&index++))
      return 0
    fi
  elif ((delta<0)); then
    ((delta=-delta))
    local left=${_ble_edit_str::index}
    local llen=${#left}
    ((llen>delta)) && left=${left:llen-delta} llen=$delta
    ble/util/strlen "$left"; local lsz=$ret
    if ((delta>=lsz)); then
      ((index-=llen))
      ((delta==lsz)); return "$?"
    else
      # 二分法
      while ((delta&&llen>=2)); do
        local mlen=$((llen/2))
        local m=${left:llen-mlen}
        ble/util/strlen "$m"; local msz=$ret
        if ((delta>=msz)); then
          left=${left::llen-mlen}
          ((index-=mlen,
            llen-=mlen,
            delta-=msz))
          ((llen>delta)) &&
            left=${left:llen-delta} llen=$delta
        else
          left=$m llen=$mlen
        fi
      done
      ((delta&&llen&&index--))
      return 0
    fi
  fi
}
function ble/widget/forward-byte {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte "$arg" || ble/widget/.bell
  _ble_edit_ind=$index
}
function ble/widget/backward-byte {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return 0
  local index=$_ble_edit_ind
  ble/widget/.locate-forward-byte $((-arg)) || ble/widget/.bell
  _ble_edit_ind=$index
}

function ble/widget/end-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=0
    else
      ((arg<0&&(arg=0)))
      local index=$(((19-2*arg)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=${#_ble_edit_str}
  fi
}
function ble/widget/beginning-of-text {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    if ((arg>=10)); then
      _ble_edit_ind=${#_ble_edit_str}
    else
      ((arg<0&&(arg=0)))
      local index=$(((2*arg+1)*${#_ble_edit_str}/20))
      local ret; ble-edit/content/find-logical-bol "$index"
      _ble_edit_ind=$ret
    fi
  else
    _ble_edit_ind=0
  fi
}

function ble/widget/beginning-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}
function ble/widget/end-of-logical-line {
  local arg; ble-edit/content/get-arg 1
  local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}

## @widget kill-backward-logical-line
##
##   現在の行の行頭まで削除する。
##   既に行頭にいる場合には直前の改行を削除する。
##   引数 arg を与えたときは arg 行前の行末まで削除する。
##
function ble/widget/kill-backward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-eol "$_ble_edit_ind" $((-arg)); local index=$ret
    if ((arg>0)); then
      if ((_ble_edit_ind<=index)); then
        index=0
      else
        ble/string#count-char "${_ble_edit_str:index:_ble_edit_ind-index}" $'\n'
        ((ret<arg)) && index=0
      fi
      [[ $flag_beg ]] && index=0
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-bol
    # 行頭にいるとき無引数で呼び出すと、直前の改行を削除
    ((0<ret&&ret==_ble_edit_ind&&ret--))
  fi
  ble/widget/.kill-range "$ret" "$_ble_edit_ind"
}
## @widget kill-forward-logical-line
##
##   現在の行の行末まで削除する。
##   既に行末にいる場合は直後の改行を削除する。
##   引数 arg を与えたときは arg 行次の行頭まで削除する。
##
function ble/widget/kill-forward-logical-line {
  local arg; ble-edit/content/get-arg ''
  if [[ $arg ]]; then
    local ret; ble-edit/content/find-logical-bol "$_ble_edit_ind" "$arg"; local index=$ret
    if ((arg>0)); then
      if ((index<=_ble_edit_ind)); then
        index=${#_ble_edit_str}
      else
        ble/string#count-char "${_ble_edit_str:_ble_edit_ind:index-_ble_edit_ind}" $'\n'
        ((ret<arg)) && index=${#_ble_edit_str}
      fi
    fi
    ret=$index
  else
    local ret; ble-edit/content/find-logical-eol
    # 行末にいるとき無引数で呼び出すと、直後の改行を削除
    ((ret<${#_ble_edit_str}&&_ble_edit_ind==ret&&ret++))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$ret"
}
function ble/widget/kill-logical-line {
  local arg; ble-edit/content/get-arg 0
  local bofs=0 eofs=0 bol=0 eol=${#_ble_edit_str}
  ((arg>0?(eofs=arg-1):(arg<0&&(bofs=arg+1))))
  ble-edit/content/find-logical-bol "$_ble_edit_ind" "$bofs" && local bol=$ret
  ble-edit/content/find-logical-eol "$_ble_edit_ind" "$eofs" && local eol=$ret
  [[ ${_ble_edit_str:eol:1} == $'\n' ]] && ((eol++))
  ((bol<eol)) && ble/widget/.kill-range "$bol" "$eol"
}

function ble/widget/forward-history-line.impl {
  local arg=$1
  ((arg==0)) && return 0

  local rest=$((arg>0?arg:-arg))
  if ((arg>0)); then
    if [[ ! $_ble_history_prefix && ! $_ble_history_load_done ]]; then
      # 履歴を未だロードしていないので次の項目は存在しない
      ble/widget/.bell 'end of history'
      return 1
    fi
  fi

  ble/history/initialize
  local index=$_ble_history_INDEX

  local expr_next='--index>=0'
  if ((arg>0)); then
    local count=$_ble_history_COUNT
    expr_next="++index<=$count"
  fi

  while ((expr_next)); do
    if ((--rest<=0)); then
      ble-edit/history/goto "$index" # 位置は goto に任せる
      return "$?"
    fi

    local entry; ble/history/get-edited-entry "$index"
    if [[ $entry == *$'\n'* ]]; then
      local ret; ble/string#count-char "$entry" $'\n'
      if ((rest<=ret)); then
        ble-edit/history/goto "$index"
        if ((arg>0)); then
          ble-edit/content/find-logical-eol 0 "$rest"
        else
          ble-edit/content/find-logical-eol ${#entry} $((-rest))
        fi
        _ble_edit_ind=$ret
        return 0
      fi
      ((rest-=ret))
    fi
  done

  if ((arg>0)); then
    ble-edit/history/goto "$count"
    _ble_edit_ind=${#_ble_edit_str}
    ble/widget/.bell 'end of history'
  else
    ble-edit/history/goto 0
    _ble_edit_ind=0
    ble/widget/.bell 'beginning of history'
  fi
  return 0
}

## @fn ble/widget/forward-logical-line.impl arg opts
##
##   @param arg
##     移動量を表す整数を指定する。
##   @param opts
##     コロン区切りでオプションを指定する。
##
function ble/widget/forward-logical-line.impl {
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  # 事前チェック
  local ind=$_ble_edit_ind
  if ((arg>0)); then
    ((ind<${#_ble_edit_str})) || return 1
  else
    ((ind>0)) || return 1
  fi

  local ret; ble-edit/content/find-logical-bol "$ind" "$arg"; local bol2=$ret
  if ((arg>0)); then
    if ((ind<bol2)); then
      ble/string#count-char "${_ble_edit_str:ind:bol2-ind}" $'\n'
      ((arg-=ret))
    fi
  else
    if ((ind>bol2)); then
      ble/string#count-char "${_ble_edit_str:bol2:ind-bol2}" $'\n'
      ((arg+=ret))
    fi
  fi

  # 同じ履歴項目内に移動先行が見つかった場合
  if ((arg==0)); then
    # 元と同じ列に移動して戻る。
    ble-edit/content/find-logical-bol "$ind" ; local bol1=$ret
    ble-edit/content/find-logical-eol "$bol2"; local eol2=$ret
    local dst=$((bol2+ind-bol1))
    ((_ble_edit_ind=dst<eol2?dst:eol2))
    return 0
  fi

  # 取り敢えず移動できる所まで移動する
  if ((arg>0)); then
    ble-edit/content/find-logical-eol "$bol2"
  else
    ret=$bol2
  fi
  _ble_edit_ind=$ret

  # 履歴項目の移動を行う場合
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg"
    return "$?"
  fi

  # 移動先行がない場合は bell
  if ((arg>0)); then
    ble/widget/.bell 'end of string'
  else
    ble/widget/.bell 'beginning of string'
  fi
  return 0
}
function ble/widget/forward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl "$arg" "$opts"
}
function ble/widget/backward-logical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-logical-line.impl $((-arg)) "$opts"
}

## @fn ble/keymap:emacs/find-graphical-eol [index [offset]]
##   @var[out] ret
function ble/keymap:emacs/find-graphical-eol {
  local axis=${1:-$_ble_edit_ind} arg=${2:-0}
  local x y index
  ble/textmap#getxy.cur "$axis"
  ble/textmap#get-index-at 0 $((y+arg+1))
  if ((index>0)); then
    local ax ay
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y+arg&&index--))
  fi
  ret=$index
}

function ble/widget/beginning-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local x y index
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 $((y+arg-1))
  _ble_edit_ind=$index
}
function ble/widget/end-of-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 1
  local ret; ble/keymap:emacs/find-graphical-eol "$_ble_edit_ind" $((arg-1))
  _ble_edit_ind=$ret
}

## @widget kill-backward-graphical-line
##   現在の行の表示行頭まで削除する。
##   既に表示行頭にいる場合には直前の文字を削除する。
##   引数 arg を与えたときは arg 行前の表示行末まで削除する。
function ble/widget/kill-backward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  if [[ ! $arg ]]; then
    local x y index
    ble/textmap#getxy.cur "$_ble_edit_ind"
    ble/textmap#get-index-at 0 "$y"
    ((index==_ble_edit_ind&&index>0&&index--))
    ble/widget/.kill-range "$index" "$_ble_edit_ind"
  else
    local ret; ble/keymap:emacs/find-graphical-eol "$_ble_edit_ind" $((-arg))
    ble/widget/.kill-range "$ret" "$_ble_edit_ind"
  fi
}
## @widget kill-forward-graphical-line
##   現在の行の表示行末まで削除する。
##   既に表示行末 (折り返し時は行の最後の文字の手前) にいる場合は直後の文字を削除する。
##   引数 arg を与えたときは arg 行後の表示行頭まで削除する。
function ble/widget/kill-forward-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg ''
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 $((y+${arg:-1}))
  if [[ ! $arg ]] && ((_ble_edit_ind<index-1)); then
    # 無引数でかつ行末より前にいた時、
    # 行頭までではなくその前の行末までしか消さない。
    ble/textmap#getxy.cur --prefix=a "$index"
    ((ay>y&&index--))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$index"
}
## @widget kill-graphical-line
##   現在の表示行を削除する。
function ble/widget/kill-graphical-line {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg; ble-edit/content/get-arg 0
  local bofs=0 eofs=0
  ((arg>0?(eofs=arg-1):(arg<0&&(bofs=arg+1))))
  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at 0 $((y+bofs))  ; local bol=$index
  ble/textmap#get-index-at 0 $((y+eofs+1)); local eol=$index
  ((bol<eol)) && ble/widget/.kill-range "$bol" "$eol"
}

function ble/widget/forward-graphical-line.impl {
  ble/textmap#is-up-to-date || ble/widget/.update-textmap
  local arg=$1 opts=$2
  ((arg==0)) && return 0

  local x y index ax ay
  ble/textmap#getxy.cur "$_ble_edit_ind"
  ble/textmap#get-index-at "$x" $((y+arg))
  ble/textmap#getxy.cur --prefix=a "$index"
  ((arg-=ay-y))
  _ble_edit_ind=$index # 何れにしても移動は行う

  # 現在の履歴項目内で移動が完結する場合
  ((arg==0)) && return 0

  # 履歴項目の移動を行う場合
  if [[ :$opts: == *:history:* && ! $_ble_edit_mark_active ]]; then
    ble/widget/forward-history-line.impl "$arg"
    return "$?"
  fi

  if ((arg>0)); then
    ble/widget/.bell 'end of string'
  else
    ble/widget/.bell 'beginning of string'
  fi
  return 0
}

function ble/widget/forward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl "$arg" "$opts"
}
function ble/widget/backward-graphical-line {
  local opts=$1
  local arg; ble-edit/content/get-arg 1
  ble/widget/forward-graphical-line.impl $((-arg)) "$opts"
}

function ble/widget/beginning-of-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/beginning-of-graphical-line
  else
    ble/widget/beginning-of-logical-line
  fi
}
function ble/widget/non-space-beginning-of-line {
  local old=$_ble_edit_ind
  ble/widget/beginning-of-logical-line
  local bol=$_ble_edit_ind ret=
  ble-edit/content/find-non-space "$bol"
  [[ $ret == $old ]] && ret=$bol # toggle
  _ble_edit_ind=$ret
  return 0
}
function ble/widget/end-of-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/end-of-graphical-line
  else
    ble/widget/end-of-logical-line
  fi
}
function ble/widget/kill-backward-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-backward-graphical-line
  else
    ble/widget/kill-backward-logical-line
  fi
}
function ble/widget/kill-forward-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-forward-graphical-line
  else
    ble/widget/kill-forward-logical-line
  fi
}
function ble/widget/kill-line {
  if ble/edit/performs-on-graphical-line; then
    ble/widget/kill-graphical-line
  else
    ble/widget/kill-logical-line
  fi
}
function ble/widget/forward-line {
  if ble/edit/use-textmap; then
    ble/widget/forward-graphical-line "$@"
  else
    ble/widget/forward-logical-line "$@"
  fi
}
function ble/widget/backward-line {
  if ble/edit/use-textmap; then
    ble/widget/backward-graphical-line "$@"
  else
    ble/widget/backward-logical-line "$@"
  fi
}

# 
# **** word location ****                                            @edit.word

## @fn ble/edit/word:eword/setup
## @fn ble/edit/word:cword/setup
## @fn ble/edit/word:uword/setup
## @fn ble/edit/word:sword/setup
## @fn ble/edit/word:fword/setup
##   @var[out] WSET WSEP
function ble/edit/word:eword/setup {
  WSET='a-zA-Z0-9'; WSEP="^$WSET"
}
function ble/edit/word:cword/setup {
  WSET='_a-zA-Z0-9'; WSEP="^$WSET"
}
function ble/edit/word:uword/setup {
  WSEP="$_ble_term_IFS"; WSET="^$WSEP"
}
function ble/edit/word:sword/setup {
  WSEP=$'|&;()<> \t\n'; WSET="^$WSEP"
}
function ble/edit/word:fword/setup {
  WSEP="/$_ble_term_IFS"; WSET="^$WSEP"
}

## @fn ble/edit/word/skip-backward set
## @fn ble/edit/word/skip-forward set
##   @var[in,out] x
function ble/edit/word/skip-backward {
  local set=$1 head=${_ble_edit_str::x}
  head=${head##*[$set]}
  ((x-=${#head},${#head}))
}
function ble/edit/word/skip-forward {
  local set=$1 tail=${_ble_edit_str:x}
  tail=${tail%%[$set]*}
  ((x+=${#tail},${#tail}))
}

## @fn ble/edit/word/locate-backward x arg
##   左側の単語の範囲を特定します。
##   @param[in] x arg
##   @var[in] WSET WSEP
##   @var[out] a b c
##
##   |---|www|---|
##   a   b   c   x
##
function ble/edit/word/locate-backward {
  local x=${1:-$_ble_edit_ind} arg=${2:-1}
  while ((arg--)); do
    ble/edit/word/skip-backward "$WSET"; c=$x
    ble/edit/word/skip-backward "$WSEP"; b=$x
  done
  ble/edit/word/skip-backward "$WSET"; a=$x
}
## @fn ble/edit/word/locate-forward x arg
##   右側の単語の範囲を特定します。
##   @param[in] x arg
##   @var[in] WSET WSEP
##   @var[out] s t u
##
##   |---|www|---|
##   x   s   t   u
##
function ble/edit/word/locate-forward {
  local x=${1:-$_ble_edit_ind} arg=${2:-1}
  while ((arg--)); do
    ble/edit/word/skip-forward "$WSET"; s=$x
    ble/edit/word/skip-forward "$WSEP"; t=$x
  done
  ble/edit/word/skip-forward "$WSET"; u=$x
}

## @fn ble/edit/word/forward-range arg
## @fn ble/edit/word/backward-range arg
## @fn ble/edit/word/current-range arg
##   @var[in,out] x y
function ble/edit/word/forward-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg<0)); then
    ble/edit/word/backward-range $((-arg))
    return "$?"
  fi
  local s t u; ble/edit/word/locate-forward "$x" "$arg"; y=$t
}
function ble/edit/word/backward-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg<0)); then
    ble/edit/word/forward-range $((-arg))
    return "$?"
  fi
  local a b c; ble/edit/word/locate-backward "$x" "$arg"; y=$b
}
function ble/edit/word/current-range {
  local arg=$1; ((arg)) || arg=1
  if ((arg>0)); then
    local a b c; ble/edit/word/locate-backward "$x"
    local s t u; ble/edit/word/locate-forward "$a" "$arg"
    ((y=a,x<t&&(x=t)))
  elif ((arg<0)); then
    local s t u; ble/edit/word/locate-forward "$x"
    local a b c; ble/edit/word/locate-backward "$u" $((-arg))
    ((b<x&&(x=b),y=u))
  fi
  return 0
}

## @fn ble/widget/word.impl type direction operator
function ble/widget/word.impl {
  local operator=$1 direction=$2 wtype=$3

  local arg; ble-edit/content/get-arg 1
  local WSET WSEP; ble/edit/word:"$wtype"/setup

  local x=$_ble_edit_ind y=$_ble_edit_ind
  ble/function#try ble/edit/word/"$direction"-range "$arg"
  if ((x==y)); then
    ble/widget/.bell
    return 1
  fi

  case $operator in
  (goto) _ble_edit_ind=$y ;;

  (delete)
    # keymap/vi.sh (white list に登録されている編集関数)
    [[ $_ble_decode_keymap == vi_imap && $direction == backward ]] &&
      ble/keymap:vi/undo/add more

    ble/widget/.delete-range "$x" "$y"

    # keymap/vi.sh (white list に登録されている編集関数)
    [[ $_ble_decode_keymap == vi_imap && $direction == backward ]] &&
      ble/keymap:vi/undo/add more ;;

  (kill)   ble/widget/.kill-range "$x" "$y" ;;
  (copy)   ble/widget/.copy-range "$x" "$y" ;;
  (*)      ble/widget/.bell; return 1 ;;
  esac
}

function ble/widget/transpose-words.impl1 {
  local wtype=$1 arg=$2
  local WSET WSEP; ble/edit/word:"$wtype"/setup
  if ((arg==0)); then
    local x=$_ble_edit_ind
    ble/edit/word/skip-forward "$WSET"
    ble/edit/word/skip-forward "$WSEP"; local e1=$x
    ble/edit/word/skip-backward "$WSEP"; local b1=$x
    local x=$_ble_edit_mark
    ble/edit/word/skip-forward "$WSET"
    ble/edit/word/skip-forward "$WSEP"; local e2=$x
    ble/edit/word/skip-backward "$WSEP"; local b2=$x
  else
    local x=$_ble_edit_ind
    ble/edit/word/skip-backward "$WSET"
    ble/edit/word/skip-backward "$WSEP"; local b1=$x
    ble/edit/word/skip-forward "$WSEP"; local e1=$x
    if ((arg>0)); then
      x=$e1
      ble/edit/word/skip-forward "$WSET"; local b2=$x
      while ble/edit/word/skip-forward "$WSEP" || return 1; ((--arg>0)); do
        ble/edit/word/skip-forward "$WSET"
      done; local e2=$x
    else
      x=$b1
      ble/edit/word/skip-backward "$WSET"; local e2=$x
      while ble/edit/word/skip-backward "$WSEP" || return 1; ((++arg<0)); do
        ble/edit/word/skip-backward "$WSET"
      done; local b2=$x
    fi
  fi

  ((b1>b2)) && local b1=$b2 e1=$e2 b2=$b1 e2=$e1
  if ! ((b1<e1&&e1<=b2&&b2<e2)); then
    ble/widget/.bell
    return 1
  fi

  local word1=${_ble_edit_str:b1:e1-b1}
  local word2=${_ble_edit_str:b2:e2-b2}
  local sep=${_ble_edit_str:e1:b2-e1}
  ble/widget/.replace-range "$b1" "$e2" "$word2$sep$word1"
  _ble_edit_ind=$e2
}
function ble/widget/transpose-words.impl {
  local wtype=$1 arg; ble-edit/content/get-arg 1
  ble/widget/transpose-words.impl1 "$wtype" "$arg" && return 0
  ble/widget/.bell
  return 1
}

## @fn ble/widget/filter-word.impl xword filter
## keymap: safe vi_nmap
function ble/widget/filter-word.impl {
  local xword=$1 filter=$2

  # determine arg
  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    local ARG FLAG REG; ble/keymap:vi/get-arg 1
    local arg=$ARG
  else
    local arg; ble-edit/content/get-arg 1
  fi

  local WSET WSEP; ble/edit/word:"$xword"/setup
  local x=$_ble_edit_ind s t u
  ble/edit/word/locate-forward "$x" "$arg"
  if ((x==t)); then
    ble/widget/.bell
    [[ $_ble_decode_keymap == vi_nmap ]] &&
      ble/keymap:vi/adjust-command-mode
    return 1
  fi

  local word=${_ble_edit_str:x:t-x}
  "$filter" "$word"
  [[ $word != $ret ]] &&
    ble-edit/content/replace "$x" "$t" "$ret"

  if [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/mark/set-previous-edit-area "$x" "$t"
    ble/keymap:vi/repeat/record
    ble/keymap:vi/adjust-command-mode
  fi
  _ble_edit_ind=$t
}

#%define 2
function ble/widget/forward-XWORD  { ble/widget/word.impl goto forward  XWORD; }
function ble/widget/backward-XWORD { ble/widget/word.impl goto backward XWORD; }
#%define 1
function ble/widget/OPERATOR-forward-XWORD  { ble/widget/word.impl OPERATOR forward  XWORD; }
function ble/widget/OPERATOR-backward-XWORD { ble/widget/word.impl OPERATOR backward XWORD; }
function ble/widget/OPERATOR-XWORD          { ble/widget/word.impl OPERATOR current  XWORD; }
#%end
#%expand 1.r/OPERATOR/delete/
#%expand 1.r/OPERATOR/kill/
#%expand 1.r/OPERATOR/copy/
function ble/widget/capitalize-XWORD { ble/widget/filter-word.impl XWORD ble/string#capitalize; }
function ble/widget/downcase-XWORD   { ble/widget/filter-word.impl XWORD ble/string#tolower; }
function ble/widget/upcase-XWORD     { ble/widget/filter-word.impl XWORD ble/string#toupper; }
function ble/widget/transpose-XWORDs { ble/widget/transpose-words.impl XWORD; }
#%end
#%expand 2.r/XWORD/eword/
#%expand 2.r/XWORD/cword/
#%expand 2.r/XWORD/uword/
#%expand 2.r/XWORD/sword/
#%expand 2.r/XWORD/fword/

#------------------------------------------------------------------------------
# **** ble-edit/exec ****                                            @edit.exec

_ble_edit_exec_lines=()
_ble_edit_exec_lastexit=0
_ble_edit_exec_lastarg=$BASH
_ble_edit_exec_BASH_COMMAND=$BASH
function ble-edit/exec/register {
  ble/array#push _ble_edit_exec_lines "$1"
}
function ble-edit/exec/has-pending-commands {
  ((${#_ble_edit_exec_lines[@]}))
}
function ble-edit/exec/.setexit {
  # $? 変数の設定
  return "$_ble_edit_exec_lastexit"
}
## @fn ble-edit/exec/.adjust-eol
##   文末調整を行います。
_ble_edit_exec_eol_mark=('' '' 0)
function ble-edit/exec/.adjust-eol {
  # update cache
  if [[ $bleopt_prompt_eol_mark != "${_ble_edit_exec_eol_mark[0]}" ]]; then
    if [[ $bleopt_prompt_eol_mark ]]; then
      local ret= x=0 y=0 g=0 x1=0 x2=0 y1=0 y2=0
      LINES=1 COLUMNS=80 ble/canvas/trace "$bleopt_prompt_eol_mark" truncate:measure-bbox
      _ble_edit_exec_eol_mark=("$bleopt_prompt_eol_mark" "$ret" "$x2")
    else
      _ble_edit_exec_eol_mark=('' '' 0)
    fi
  fi

  local cols=${COLUMNS:-80}
  local -a DRAW_BUFF=()
  local eol_mark=${_ble_edit_exec_eol_mark[1]}
  if [[ $eol_mark ]]; then
    # Note #D1458: コマンドを実行前に panel/render で panel 0 に移動している筈。
    #   従って bottom-dock には居らず SC/RC を使って OK の筈。
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_sc"
    local width=${_ble_edit_exec_eol_mark[2]} limit=$cols
    [[ $_ble_term_rc ]] || ((limit--))
    if ((width>limit)); then
      local x=0 y=0 g=0
      LINES=1 COLUMNS=$limit ble/canvas/trace.draw "$bleopt_prompt_eol_mark" truncate
      width=$x
    else
      ble/canvas/put.draw "$eol_mark"
    fi
    [[ $_ble_term_rc ]] || ble/canvas/put-cub.draw "$width"
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_rc"
  fi

  local advance=$((_ble_term_xenl?cols-2:cols-3))
  if [[ $_ble_term_TERM == cygwin ]]; then
    # Note (#D1144): Cygwin console では何故か行き先が
    #   丁度 cols+1 列目になる様な CUF は一文字も動かない。
    #   cols列目またはcols+2列目以降は大丈夫である。
    #   仕方がないので少しずつ慎重に前進する事にする。
    while ((advance)); do
      ble/canvas/put-cuf.draw $((advance-advance/2))
      ((advance/=2))
    done
  else
    ble/canvas/put-cuf.draw "$advance"
  fi
  ble/canvas/put.draw "  $_ble_term_cr$_ble_term_el"
  ble/canvas/bflush.draw
}

if ((_ble_bash>=50100)); then
  _ble_edit_exec_BASH_REMATCH=()
  function ble-edit/exec/save-BASH_REMATCH {
    _ble_edit_exec_BASH_REMATCH=("${BASH_REMATCH[@]}")
  }
  function ble-edit/exec/restore-BASH_REMATCH {
    BASH_REMATCH=("${_ble_edit_exec_BASH_REMATCH[@]}")
  }

else
  _ble_edit_exec_BASH_REMATCH=()
  _ble_edit_exec_BASH_REMATCH_rex=none

  ## @fn ble-edit/exec/save-BASH_REMATCH/increase delta
  ##   @param[in] delta
  ##   @var[in,out] i rex
  function ble-edit/exec/save-BASH_REMATCH/increase {
    local delta=$1
    ((delta)) || return 1
    ((i+=delta))
    if ((delta==1)); then
      rex=$rex.
    else
      rex=$rex.{$delta}
    fi
  }
  function ble-edit/exec/save-BASH_REMATCH/is-updated {
    local i n=${#_ble_edit_exec_BASH_REMATCH[@]}
    ((n!=${#BASH_REMATCH[@]})) && return 0
    for ((i=0;i<n;i++)); do
      [[ ${_ble_edit_exec_BASH_REMATCH[i]} != "${BASH_REMATCH[i]}" ]] && return 0
    done
    return 1
  }
  function ble-edit/exec/save-BASH_REMATCH {
    ble-edit/exec/save-BASH_REMATCH/is-updated || return 1

    local size=${#BASH_REMATCH[@]}
    if ((size==0)); then
      _ble_edit_exec_BASH_REMATCH=()
      _ble_edit_exec_BASH_REMATCH_rex=none
      return 0
    fi

    local rex= i=0
    local text=$BASH_REMATCH sub ret isub

    local -a rparens=()
    local isub rex i=0
    for ((isub=1;isub<size;isub++)); do
      local sub=${BASH_REMATCH[isub]}

      # 既存の子一致の孫一致になるか確認
      local r rN=${#rparens[@]}
      for ((r=rN-1;r>=0;r--)); do
        local end=${rparens[r]}
        if ble/string#index-of "${text:i:end-i}" "$sub"; then
          ble-edit/exec/save-BASH_REMATCH/increase "$ret"
          ble/array#push rparens $((i+${#sub}))
          rex=$rex'('
          break
        else
          ble-edit/exec/save-BASH_REMATCH/increase $((end-i))
          rex=$rex')'
          builtin unset -v 'rparens[r]'
        fi
      done

      ((r>=0)) && continue

      # 新しい子一致
      if ble/string#index-of "${text:i}" "$sub"; then
        ble-edit/exec/save-BASH_REMATCH/increase "$ret"
        ble/array#push rparens $((i+${#sub}))
        rex=$rex'('
      else
        break # 復元失敗
      fi
    done

    local r rN=${#rparens[@]}
    for ((r=rN-1;r>=0;r--)); do
      local end=${rparens[r]}
      ble-edit/exec/save-BASH_REMATCH/increase $((end-i))
      rex=$rex')'
      builtin unset -v 'rparens[r]'
    done

    ble-edit/exec/save-BASH_REMATCH/increase $((${#text}-i))

    _ble_edit_exec_BASH_REMATCH=("${BASH_REMATCH[@]}")
    _ble_edit_exec_BASH_REMATCH_rex=$rex
  }
  function ble-edit/exec/restore-BASH_REMATCH {
    [[ $_ble_edit_exec_BASH_REMATCH =~ $_ble_edit_exec_BASH_REMATCH_rex ]]
  }
fi

_ble_prompt_ps10_data=()
function ble/prompt/unit:_ble_prompt_ps10/update {
  ble/prompt/unit:{section}/update _ble_prompt_ps10 "$PS0" ''
}

function ble-edit/exec/print-PS0 {
  if [[ $PS0 ]]; then
    local version=$COLUMNS,$_ble_edit_lineno,$_ble_history_count,$_ble_edit_CMD
    local prompt_hashref_base='$version'
    local prompt_rows=${LINES:-25}
    local prompt_cols=${COLUMNS:-80}
    local "${_ble_prompt_cache_vars[@]/%/=}" # #D1570 OK
    ble/prompt/unit#update _ble_prompt_ps10
    ble/prompt/unit:{section}/get _ble_prompt_ps10
    ble/util/put "$ret"
  fi
}

function ble/builtin/exit/.read-arguments {
  while (($#)); do
    local arg=$1; shift
    if [[ $arg == --help ]]; then
      opt_flags=${opt_flags}H
    elif local rex='^[-+]?[0-9]+$'; [[ $arg =~ $rex ]]; then
      ble/array#push opt_args "$arg"
    else
      ble/util/print "exit: unrecognized argument '$arg'" >&2
      opt_flags=${opt_flags}E
    fi
  done
}
function ble/builtin/exit {
  local ext=$?
  if ble/util/is-running-in-subshell || [[ $_ble_decode_bind_state == none ]]; then
    if (($#)); then
      builtin exit "$@"
    else
      builtin exit "$ext"
    fi
    return 1
  fi

  local opt_flags=
  local -a opt_args=()
  ble/builtin/exit/.read-arguments "$@"
  if [[ $opt_flags == *[EH]* ]]; then
    [[ $opt_flags == *H* ]] && builtin exit --help
    return 2
  fi
  ((${#opt_args[@]})) || ble/array#push opt_args "$ext"

  local joblist
  ble/util/joblist
  if ((${#joblist[@]})); then
    local ret
    while
      local cancel_reason=
      if ble/util/assign ret 'compgen -A stopped -- ""' 2>/dev/null; [[ $ret ]]; then
        cancel_reason='stopped jobs'
      elif [[ :$opts: == *:checkjobs:* ]]; then
        if ble/util/assign ret 'compgen -A running -- ""' 2>/dev/null; [[ $ret ]]; then
          cancel_reason='running jobs'
        fi
      fi
      [[ $cancel_reason ]]
    do
      jobs
      ble/builtin/read -ep "\e[38;5;12m[ble: There are $cancel_reason]\e[m Leave the shell anyway? [yes/No] " ret
      case $ret in
      ([yY]|[yY][eE][sS]) break ;;
      ([nN]|[nN][oO]|'')  return 0 ;;
      esac
    done
  fi

  ble/util/print "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0" >&2
  builtin exit "${opt_args[@]}" &>/dev/null
  builtin exit "${opt_args[@]}" &>/dev/null
  return 1 # exit できなかった場合は 1 らしい
}

function exit { ble/builtin/exit "$@"; }

## @fn ble-edit/exec:$bleopt_internal_exec_type/process
##   指定したコマンドを実行します。
##   @param[in,out] _ble_edit_exec_lines
##     実行するコマンドの配列を指定します。実行したコマンドは削除するか空文字列を代入します。
##   @return
##     戻り値が 0 の場合、終端 (ble-edit/bind/.tail) に対する処理も行われた事を意味します。
##     つまり、そのまま ble-decode/.hook から抜ける事を期待します。
##     それ以外の場合には終端処理をしていない事を表します。

#--------------------------------------
# bleopt_internal_exec_type = gexec
#--------------------------------------

_ble_edit_exec_TRAPDEBUG_enabled=
_ble_edit_exec_inside_begin=
_ble_edit_exec_inside_prologue=
_ble_edit_exec_inside_userspace=
ble/builtin/trap/reserve DEBUG
function ble-edit/exec:gexec/.TRAPDEBUG/trap {
  builtin trap -- 'ble-edit/exec:gexec/.TRAPDEBUG "$*" || { (($?==2)) && return 0 || break; } &>/dev/null' DEBUG
}
function ble-edit/exec:gexec/.TRAPDEBUG/enter {
  ble/builtin/trap/.initialize
  if [[ ${_ble_builtin_trap_handlers[_ble_builtin_trap_DEBUG]} ]]; then
    ble-edit/exec:gexec/.TRAPDEBUG/trap
  fi
}
function ble-edit/exec:gexec/.TRAPDEBUG {
  [[ ! $_ble_edit_exec_TRAPDEBUG_enabled ]] && return 0
  [[ $BASH_COMMAND == ble-edit/exec:gexec/.* ]] && return 0
  [[ $_ble_builtin_trap_inside ]] && return 0

  ble/builtin/trap/invoke DEBUG; local ext=$?

  if ((_ble_edit_exec_INT!=0)); then
    # エラーが起きている時

    local IFS=$_ble_term_IFS
    local depth=${#FUNCNAME[*]}
    local rex='^(ble-edit/exec:gexec/\.|\<ble/builtin/trap/\.handler)'
    if ((depth>=2)) && ! [[ ${FUNCNAME[*]:1} =~ $rex ]]; then
      # 関数内にいるが、ble-edit/exec:gexec/. の中ではない時
      ble/util/print "${_ble_term_setaf[9]}[ble: SIGINT]$_ble_term_sgr0 ${FUNCNAME[1]} $1" >&2
      return 2
    fi

    local rex='^ble-edit/exec:gexec/\.'
    if ((depth==1)) && ! [[ $BASH_COMMAND =~ $rex ]]; then
      # 一番外側で、ble-edit/exec:gexec/. 関数ではない時
      ble/util/print "${_ble_term_setaf[9]}[ble: SIGINT]$_ble_term_sgr0 $BASH_COMMAND" >&2
      return 2
    fi
  fi

  # Note: builtin trap - DEBUG は何故か此処では効かない
  builtin trap -- - DEBUG
  return "$ext"
}
function ble/builtin/trap:DEBUG {
  # Note (#D1155): ユーザコマンド実行中に新しく ble/builtin/trap DEBUG
  # が設定された場合は builtin trap DEBUG を仕掛ける。
  if [[ $1 != - && $_ble_edit_exec_TRAPDEBUG_enabled ]]; then
    ble-edit/exec:gexec/.TRAPDEBUG/trap
  fi
}

function ble-edit/exec:gexec/.TRAPINT {
  ble/util/print "$_ble_term_bold^C$_ble_term_sgr0" >&2
  if ((_ble_bash>=40300)); then
    _ble_edit_exec_INT=130
  else
    _ble_edit_exec_INT=128
  fi
  ble-edit/exec:gexec/.TRAPDEBUG/trap
}
function ble-edit/exec:gexec/.TRAPINT/reset {
  blehook INT-='ble-edit/exec:gexec/.TRAPINT'
}
function ble-edit/exec:gexec/invoke-hook-with-setexit {
  ble-edit/exec/.setexit "$_ble_edit_exec_lastarg"
  BASH_COMMAND=$_ble_edit_exec_BASH_COMMAND \
    blehook/invoke "$@"
} >&$_ble_util_fd_stdout 2>&$_ble_util_fd_stderr

# ble-edit/exec:gexec/TERM
#
# Note #D1287: Bash は途中で TERM が変更されると勝手に TERM 固有のキー
#   を bind してしまう。これにより ble.sh がキーを読み取れなくなってし
#   まう。ここでは bash による bind を検出して rebind を実行する。因み
#   に再読み込みを強制すると其処でコマンド実行が失敗する可能性があるの
#   で ble/term/enter の後で rebind するべき。
_ble_edit_exec_TERM=
function ble-edit/exec:gexec/TERM/is-dirty {
  [[ $TERM != "$_ble_edit_exec_TERM" ]] && return 0
  local bindp
  ble/util/assign bindp 'builtin bind -p'
  [[ $bindp != "$_ble_decode_bind_bindp" ]]
}
function ble-edit/exec:gexec/TERM/leave {
  _ble_edit_exec_TERM=$TERM
}
function ble-edit/exec:gexec/TERM/enter {
  if [[ $_ble_decode_bind_state != none ]] && ble-edit/exec:gexec/TERM/is-dirty; then
    # Note: ble/decode/rebind ではなく元の binding の記録・復元も含めてやり直す。
    ble/edit/info/immediate-show text 'ble: TERM has changed. rebinding...'
    ble/decode/detach
    if ! ble/decode/attach; then
      ble-detach
      ble-edit/bind/.check-detach && return 1
    fi
    ble/edit/info/immediate-clear
  fi
}

## @fn ble-edit/exec:gexec/.begin
## @fn ble-edit/exec:gexec/.end
##   端末や入出力などの設定をコマンド実行用に調整します。
##   また DEBUG や INT に対する trap の設定も行います。
##   DEBUG の設定の解除はトップレベルでないと実行できないので、
##   実際に使う時には以下の様にする必要があります。
##
##     ble-edit/exec:gexec/.begin
##
##     コマンド実行
##
##     builtin trap -- - DEBUG
##     ble-edit/exec:gexec/.end
##
function ble-edit/exec:gexec/.begin {
  _ble_edit_exec_inside_begin=1
  local IFS=$_ble_term_IFS
  _ble_decode_bind_hook=
  _ble_edit_exec_PWD=$PWD
  ble-edit/exec:gexec/TERM/leave
  ble/term/leave
  ble-edit/bind/stdout.on
  ble/util/buffer.flush >&2

  # C-c に対して
  ble/builtin/trap/install-hook INT # 何故か改めて実行しないと有効にならない
  blehook INT+='ble-edit/exec:gexec/.TRAPINT'
  ble-edit/exec:gexec/.TRAPDEBUG/enter
}
function ble-edit/exec:gexec/.end {
  _ble_edit_exec_inside_begin=
  local IFS=$_ble_term_IFS

  # Note: builtin trap -- - DEBUG は何故か此処では効かないので
  #   ble-edit/exec:gexec/.end を呼び出す直前に外側で実行する。
  ble-edit/exec:gexec/.TRAPINT/reset
  builtin trap -- - DEBUG

  [[ $PWD != "$_ble_edit_exec_PWD" ]] && blehook/invoke CHPWD
  ble/util/joblist.flush >&2
  ble-edit/bind/.check-detach && return 0
  ble/term/enter
  ble-edit/exec:gexec/TERM/enter || return 0 # rebind に失敗した時 .tail せずに抜ける
  [[ $1 == restore ]] && return 0 # Note: 前回の呼出で .end に失敗した時 #D1170
  ble-edit/bind/.tail # flush will be called here
}

function ble-edit/exec:gexec/.prologue {
  _ble_edit_exec_inside_prologue=1
  local IFS=$_ble_term_IFS
  BASH_COMMAND=$1
  _ble_edit_exec_BASH_COMMAND=$1
  ble-edit/restore-PS1
  ble-edit/restore-READLINE
  ble-edit/restore-IGNOREEOF
  builtin unset -v HISTCMD; ble/history/get-count -v HISTCMD

  _ble_edit_exec_INT=0
  ble/util/joblist.clear
  ble-edit/exec:gexec/invoke-hook-with-setexit PREEXEC "$_ble_edit_exec_BASH_COMMAND"
  ble-edit/exec/print-PS0 >&$_ble_util_fd_stdout 2>&$_ble_util_fd_stderr
  ((++_ble_edit_CMD))

  ble-edit/exec/restore-BASH_REMATCH
  ble/base/restore-bash-options
  ble/base/restore-POSIXLY_CORRECT
  ble/base/restore-builtin-wrappers
  builtin eval -- "$_ble_bash_FUNCNEST_restore" # これ以降関数は呼び出せない
  _ble_edit_exec_TRAPDEBUG_enabled=1
  _ble_edit_exec_inside_userspace=1
  return "$_ble_edit_exec_lastexit" # set $?
} &>/dev/null # set -x 対策 #D0930
function ble-edit/exec:gexec/.save-last-arg {
  _ble_edit_exec_lastarg=$_ _ble_edit_exec_lastexit=$?
  _ble_edit_exec_inside_userspace=
  _ble_edit_exec_TRAPDEBUG_enabled=
  builtin eval -- "$_ble_bash_FUNCNEST_adjust" # 他の関数呼び出しよりも先
  ble/base/adjust-bash-options
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec:gexec/.epilogue {
  _ble_edit_exec_lastexit=$? # lastexit
  _ble_edit_exec_inside_userspace=
  _ble_edit_exec_TRAPDEBUG_enabled=
  builtin eval -- "$_ble_bash_FUNCNEST_adjust" # 他の関数呼び出しよりも先
  ble/base/adjust-builtin-wrappers-1
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit=$_ble_edit_exec_INT
  fi
  _ble_edit_exec_INT=0

  local IFS=$_ble_term_IFS
  # Note: builtin trap -- - DEBUG は此処では何故か効かない
  builtin trap -- - DEBUG

  ble/base/adjust-bash-options
  ble/base/adjust-POSIXLY_CORRECT
  ble/base/adjust-builtin-wrappers-2
  ble-edit/adjust-IGNOREEOF
  ble-edit/adjust-READLINE
  ble-edit/adjust-PS1
  ble-edit/exec/save-BASH_REMATCH
  ble/util/reset-keymap-of-editing-mode
  ble-edit/exec/.adjust-eol
  _ble_edit_exec_inside_prologue=

  ble-edit/exec:gexec/invoke-hook-with-setexit POSTEXEC

  if ((_ble_edit_exec_lastexit)); then
    # SIGERR処理
    ble-edit/exec:gexec/invoke-hook-with-setexit ERR
    if [[ $bleopt_exec_errexit_mark == $'\e[91m[ble: exit %d]\e[m' ]]; then
      ble/util/print "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0"
    elif [[ $bleopt_exec_errexit_mark ]]; then
      local ret
      ble/util/sprintf ret "$bleopt_exec_errexit_mark" "$_ble_edit_exec_lastexit"
      x=0 y=0 g=0 ble/canvas/trace "$ret"
      ble/util/print "$ret"
    fi >&3 # Note: >&3 は set -x 対策による呼び出し元のリダイレクトと対応 #D0930
  fi
}
function ble-edit/exec:gexec/.setup {
  # コマンドを _ble_decode_bind_hook に設定してグローバルで評価する。
  #
  # ※ユーザの入力したコマンドをグローバルではなく関数内で評価すると
  #   declare した変数がコマンドローカルになってしまう。
  #   配列でない単純な変数に関しては declare を上書きする事で何とか誤魔化していたが、
  #   declare -a arr=(a b c) の様な特殊な構文の物は上書きできない。
  #   この所為で、例えば source 内で declare した配列などが壊れる。
  #
  ((${#_ble_edit_exec_lines[@]}==0)) && return 1
  ble/util/buffer.flush >&2

  local apos=\' APOS="'\\''"
  local cmd
  local -a buff=()
  local count=0
  buff[${#buff[@]}]=ble-edit/exec:gexec/.begin
  for cmd in "${_ble_edit_exec_lines[@]}"; do
    if [[ "$cmd" == *[^' 	']* ]]; then
      # Note: $_ble_edit_exec_lastarg は $_ を設定するためのものである。
      local prologue="ble-edit/exec:gexec/.prologue '${cmd//$apos/$APOS}' \"\$_ble_edit_exec_lastarg\""
      buff[${#buff[@]}]="builtin eval -- '${prologue//$apos/$APOS}"
      buff[${#buff[@]}]="${cmd//$apos/$APOS}"
      buff[${#buff[@]}]="{ ble-edit/exec:gexec/.save-last-arg; } &>/dev/null'" # Note: &>/dev/null は set -x 対策 #D0930
      buff[${#buff[@]}]="{ ble-edit/exec:gexec/.epilogue; } 3>&2 &>/dev/null"
      ((count++))

      # ※直接 $cmd と書き込むと文法的に破綻した物を入れた時に
      #   続きの行が実行されない事になってしまう。
    fi
  done
  _ble_edit_exec_lines=()

  ((count==0)) && return 1

  # Note: 現在は blehook 経由で処理しているので問題ないが、
  #   builtin trap - INT DEBUG を使う時一番外側 (此処) でないと効かない
  buff[${#buff[@]}]='builtin trap -- - DEBUG'
  buff[${#buff[@]}]=ble-edit/exec:gexec/.end
  IFS=$'\n' builtin eval '_ble_decode_bind_hook="${buff[*]}"'
  return 0
}

function ble-edit/exec:gexec/process {
  ble-edit/exec:gexec/.setup
  return $?
}
function ble-edit/exec:gexec/restore-state {
  # 構文エラー等で epilogue/end が呼び出されなかった時の為 #D1170
  [[ $_ble_edit_exec_inside_prologue ]] && ble-edit/exec:gexec/.epilogue 3>&2 &>/dev/null
  [[ $_ble_edit_exec_inside_begin ]] && ble-edit/exec:gexec/.end restore
}

# **** accept-line ****                                            @edit.accept

: ${_ble_edit_lineno:=0}
_ble_edit_line_opwd=

## @fn ble/widget/.insert-newline/trim-prompt
##   @var[ref] DRAW_BUFF
function ble/widget/.insert-newline/trim-prompt {
  local ps1f=$bleopt_prompt_ps1_final
  local ps1t=$bleopt_prompt_ps1_transient
  if [[ ! $ps1f && :$ps1t: == *:trim:* ]]; then
    [[ :$ps1t: == *:same-dir:* && $PWD != $_ble_edit_line_opwd ]] && return
    local y=${_ble_prompt_ps1_data[4]}
    if ((y)); then
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
      ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" $((-y)) shift
      ((_ble_textarea_gendy-=y))
    fi
  fi
}
function ble/widget/.insert-newline {
  local opts=$1
  local -a DRAW_BUFF=()
  if [[ :$opts: == *:keep-info:* && $_ble_textarea_panel == 0 ]] &&
       ! ble/util/joblist.has-events
  then
    # 最終状態の描画
    ble/textarea#render leave
    ble/widget/.insert-newline/trim-prompt

    # info を表示したまま行を挿入し、今までの panel 0 の内容を範囲外に破棄
    local textarea_height=${_ble_canvas_panel_height[_ble_textarea_panel]}
    ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" 1
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$textarea_height" sgr0
    ble/canvas/bflush.draw
  else
    # 最終状態の描画
    ble/edit/enter-command-layout
    ble/textarea#render leave
    ble/widget/.insert-newline/trim-prompt

    # 新しい描画領域
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy" sgr0
    ble/canvas/put.draw "$_ble_term_nl"
    ble/canvas/bflush.draw
    ble/util/joblist.bflush
  fi

  # 描画領域情報の初期化
  ((_ble_edit_lineno++))
  _ble_edit_line_opwd=$PWD
  ble/textarea#invalidate
  _ble_canvas_x=0 _ble_canvas_y=0
  _ble_textarea_gendx=0 _ble_textarea_gendy=0
  _ble_canvas_panel_height[_ble_textarea_panel]=1
}
function ble/widget/.hide-current-line {
  ble/edit/enter-command-layout
  local -a DRAW_BUFF=()
  ble/canvas/panel#clear.draw "$_ble_textarea_panel"
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
  ble/canvas/bflush.draw
  ble/textarea#invalidate
  _ble_canvas_x=0 _ble_canvas_y=0
  _ble_textarea_gendx=0 _ble_textarea_gendy=0
  _ble_canvas_panel_height[_ble_textarea_panel]=1
}

function ble/widget/.newline/clear-content {
  # カーソルを表示する。
  # layer:overwrite でカーソルを消している時の為。
  [[ $_ble_edit_overwrite_mode ]] &&
    ble/term/cursor-state/reveal

  # 行内容の初期化
  ble-edit/content/reset '' newline
  _ble_edit_ind=0
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_edit_overwrite_mode=
}

## @fn ble/widget/.newline opts
##   @param[in] opts
##     コロン区切りのオプションです。
##     keep-info
##       info を隠さずに表示したままにします。
##       (但し menu-complete は必ずクリアします。)
function ble/widget/.newline {
  local opts=$1
  _ble_edit_mark_active=

  # (for lib/core-complete.sh layer:menu_filter)
  if [[ $_ble_complete_menu_active ]]; then
    [[ $_ble_highlight_layer_menu_filter_beg ]] &&
      ble/textarea#invalidate str # (#D0995)
  fi

  _ble_complete_menu_active= ble/widget/.insert-newline "$opts"

  # update LINENO
  local ret; ble/string#count-char "$_ble_edit_str" $'\n'
  ((_ble_edit_LINENO+=1+ret))
  ((LINENO=_ble_edit_LINENO))

  ble/history/onleave.fire
  ble/widget/.newline/clear-content
}

function ble/widget/discard-line {
  ble-edit/content/clear-arg
  _ble_edit_line_disabled=1 ble/widget/.newline keep-info
  ble/textarea#render
}

function ble/edit/hist_expanded/.core {
  ble/builtin/history/option:p "$command"
}
function ble-edit/hist_expanded/.expand {
  ble/edit/hist_expanded/.core 2>/dev/null; local ext=$?
  ((ext)) && ble/util/print "$command"
  ble/util/put :
  return "$ext"
}

## @var[out] hist_expanded
function ble-edit/hist_expanded.update {
  local command=$1
  if [[ ! -o histexpand || ! ${command//[ 	]} ]]; then
    hist_expanded=$command
    return 0
  elif ble/util/assign hist_expanded 'ble-edit/hist_expanded/.expand'; then
    hist_expanded=${hist_expanded%$_ble_term_nl:}
    return 0
  else
    hist_expanded=$command
    return 1
  fi
}

function ble/widget/accept-line {
  ble/decode/widget/keymap-dispatch "$@"
}
function ble/widget/default/accept-line {
  # 文法的に不完全の時は改行挿入
  # Note: mc (midnight commander) が改行を含むコマンドを書き込んでくる #D1392
  if [[ :$1: == *:syntax:* || $MC_SID == $$ && $LINENO == 0 ]]; then
    ble-edit/content/update-syntax
    if ! ble/syntax:bash/is-complete; then
      ble/widget/newline
      return "$?"
    fi
  fi

  ble-edit/content/clear-arg
  local command=$_ble_edit_str

  if [[ ! ${command//["$_ble_term_IFS"]} ]]; then
    [[ $bleopt_history_share ]] &&
      ble/builtin/history/option:n
    ble/widget/.newline keep-info
    ble/textarea#render
    ble/util/buffer.flush >&2
    return 0
  fi

  # 履歴展開
  local hist_expanded
  if ! ble-edit/hist_expanded.update "$command"; then
    _ble_edit_line_disabled=1 ble/widget/.insert-newline
    shopt -q histreedit &>/dev/null || ble/widget/.newline/clear-content
    ble/util/buffer.flush >&2
    ble/edit/hist_expanded/.core 1>/dev/null # エラーメッセージを表示
    return "$?"
  fi

  local hist_is_expanded=
  if [[ $hist_expanded != "$command" ]]; then
    if shopt -q histverify &>/dev/null; then
      _ble_edit_line_disabled=1 ble/widget/.insert-newline
      ble-edit/content/reset-and-check-dirty "$hist_expanded"
      _ble_edit_ind=${#hist_expanded}
      _ble_edit_mark=0
      _ble_edit_mark_active=
      return 0
    fi

    command=$hist_expanded
    hist_is_expanded=1
  fi

  ble/widget/.newline

  [[ $hist_is_expanded ]] && ble/util/buffer.print "${_ble_term_setaf[12]}[ble: expand]$_ble_term_sgr0 $command"

  # 編集文字列を履歴に追加
  ble/history/add "$command"

  # 実行を登録
  ble-edit/exec/register "$command"
}

function ble/widget/accept-and-next {
  ble-edit/content/clear-arg
  ble/history/initialize
  local index=$_ble_history_INDEX
  local count=$_ble_history_COUNT

  if ((index+1<count)); then
    local HISTINDEX_NEXT=$((index+1)) # to be modified in accept-line
    ble/widget/accept-line
    ble-edit/history/goto "$HISTINDEX_NEXT"
  else
    local content=$_ble_edit_str
    ble/widget/accept-line

    count=$_ble_history_COUNT
    if ((count)); then
      local entry; ble/history/get-entry $((count-1))
      if [[ $entry == "$content" ]]; then
        ble-edit/history/goto $((count-1))
      fi
    fi

    [[ $_ble_edit_str != "$content" ]] &&
      ble-edit/content/reset "$content"
  fi
}
function ble/widget/newline {
  ble/decode/widget/keymap-dispatch "$@"
}
function ble/widget/default/newline {
  local -a KEYS=(10)
  ble/widget/self-insert
}
function ble/widget/tab-insert {
  local -a KEYS=(9)
  ble/widget/self-insert
}
function ble-edit/is-single-complete-line {
  ble-edit/content/is-single-line || return 1
  [[ $_ble_edit_str ]] && ble/decode/has-input &&
    ((0<=bleopt_accept_line_threshold&&bleopt_accept_line_threshold<=_ble_decode_input_count+ble_decode_char_rest)) &&
    return 1
  if shopt -q cmdhist &>/dev/null; then
    ble-edit/content/update-syntax
    ble/syntax:bash/is-complete || return 1
  fi
  return 0
}
function ble/widget/accept-single-line-or {
  ble/decode/widget/keymap-dispatch "$@"
}
function ble/widget/default/accept-single-line-or {
  if ble-edit/is-single-complete-line; then
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/accept-single-line-or-newline {
  ble/widget/accept-single-line-or newline
}
## @fn ble/widget/edit-and-execute-command.edit content opts
##   @var[in] content
##   @var[in] opts
##   @var[out] ret
function ble/widget/edit-and-execute-command.edit {
  local content=$1 opts=:$2:

  local file=$_ble_base_run/$$.blesh-fc.bash
  ble/util/print "$content" >| "$file"

  [[ $opts == *:no-newline:* ]] ||
    _ble_edit_line_disabled=1 ble/widget/.newline

  local fallback=vi
  if type emacs &>/dev/null; then
    fallback='emacs -nw'
  elif type vim &>/dev/null; then
    fallback=vim
  elif type nano &>/dev/null; then
    fallback=nano
  fi

  ble/term/leave
  ${bleopt_editor:-${VISUAL:-${EDITOR:-$fallback}}} "$file"; local ext=$?
  ble/term/enter

  if ((ext)); then
    ble/widget/.bell
    return 127
  fi

  ble/util/readfile ret "$file"
  return 0
}
function ble/widget/edit-and-execute-command.impl {
  local ret
  ble/widget/edit-and-execute-command.edit "$1"
  local command=$ret

  command=${command%$'\n'}
  if [[ ! ${command//["$_ble_term_IFS"]} ]]; then
    ble/widget/.bell
    return 1
  fi

  # Note: accept-line を参考にした
  ble/util/buffer.print "${_ble_term_setaf[12]}[ble: fc]$_ble_term_sgr0 $command"
  ble/history/add "$command"
  ble-edit/exec/register "$command"
}
function ble/widget/edit-and-execute-command {
  ble-edit/content/clear-arg
  ble/widget/edit-and-execute-command.impl "$_ble_edit_str"
}

function ble/widget/insert-comment/.remove-comment {
  local comment_begin=$1
  ret=

  [[ $comment_begin ]] || return 1
  ble/string#escape-for-extended-regex "$comment_begin"; local rex_comment_begin=$ret
  local rex1=$'([ \t]*'$rex_comment_begin$')[^\n]*(\n|$)|[ \t]+(\n|$)|\n'
  local rex=$'^('$rex1')*$'; [[ $_ble_edit_str =~ $rex ]] || return 1

  local tail=$_ble_edit_str out=
  while [[ $tail && $tail =~ ^$rex1 ]]; do
    local rematch1=${BASH_REMATCH[1]}
    if [[ $rematch1 ]]; then
      out=$out${rematch1%?}${BASH_REMATCH:${#rematch1}}
    else
      out=$out$BASH_REMATCH
    fi
    tail=${tail:${#BASH_REMATCH}}
  done

  [[ $tail ]] && return 1

  ret=$out
}
function ble/widget/insert-comment/.insert {
  local arg=$1
  local ret='#'; ble/util/read-rl-variable comment-begin
  local comment_begin=${ret::1}
  local text=
  if [[ $arg ]] && ble/widget/insert-comment/.remove-comment "$comment_begin"; then
    text=$ret
  else
    text=$comment_begin${_ble_edit_str//$'\n'/$'\n'"$comment_begin"}
  fi
  ble-edit/content/reset-and-check-dirty "$text"
}
function ble/widget/insert-comment {
  local arg; ble-edit/content/get-arg ''
  ble/widget/insert-comment/.insert "$arg"
  ble/widget/accept-line
}

function ble/widget/alias-expand-line.proc {
  if ((tchild>=0)); then
    ble/syntax/tree-enumerate-children \
      ble/widget/alias-expand-line.proc
  elif [[ $wtype && ! ${wtype//[0-9]} ]] && ((wtype==_ble_ctx_CMDI)); then
    local word=${_ble_edit_str:wbegin:wlen}
    local ret; ble/util/expand-alias "$word"
    [[ $word == "$ret" ]] && return 0
    changed=1
    ble/widget/.replace-range "$wbegin" $((wbegin+wlen)) "$ret"
  fi
}
function ble/widget/alias-expand-line {
  ble-edit/content/clear-arg
  ble-edit/content/update-syntax
  local iN= changed=
  ble/syntax/tree-enumerate ble/widget/alias-expand-line.proc
  [[ $changed ]] && _ble_edit_mark_active=
}

function ble/widget/tilde-expand {
  ble-edit/content/clear-arg
  ble-edit/content/update-syntax
  local len=${#_ble_edit_str}
  local i=$len j=$len
  while ((--i>=0)); do
    ((_ble_syntax_attr[i])) || continue
    if ((_ble_syntax_attr[i]==_ble_attr_TILDE)); then
      local word=${_ble_edit_str:i:j-i}
      builtin eval "local path=$word"
      [[ $path != "$word" ]] &&
        ble/widget/.replace-range "$i" "$j" "$path"
    fi
    j=$i
  done
}

_ble_edit_shell_expand_ExpandWtype=()
function ble/widget/shell-expand-line.initialize {
  function ble/widget/shell-expand-line.initialize { :; }
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_CMDI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGEI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_ARGVI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRF]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRD]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_RDRS]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_VALI]=1
  _ble_edit_shell_expand_ExpandWtype[_ble_ctx_CONDI]=1
}
## @fn ble/widget/shell-expand-line.expand-word
##   @var[in] wtype
##   @var[out] ret flags
function ble/widget/shell-expand-line.expand-word {
  local word=$1

  # 未知の wtype については処理しない。
  ble/widget/shell-expand-line.initialize
  if [[ ! ${_ble_edit_shell_expand_ExpandWtype[wtype]} ]]; then
    ret=$word
    return 0
  fi

  # 単語展開
  ret=$word; [[ $ret == '~'* ]] && ret='\'$word
  ble/syntax:bash/simple-word/eval "$ret" noglob
  if [[ $word != $ret || ${#ret[@]} -ne 1 ]]; then
    [[ $opts == *:quote:* ]] && flags=${flags}q
    return 0
  fi

  # エイリアス展開
  if ((wtype==_ble_ctx_CMDI)); then
    ble/util/expand-alias "$word"
    [[ $word != $ret ]] && return 0
  fi

  ret=$word
}
function ble/widget/shell-expand-line.proc {
  [[ $wtype ]] || return 0

  # 単語以外の構造の場合には中に入る (例: < file や [[ arg ]] など)
  if [[ ${wtype//[0-9]} ]]; then
    ble/syntax/tree-enumerate-children ble/widget/shell-expand-line.proc
    return 0
  fi

  local word=${_ble_edit_str:wbegin:wlen}

  # 配列代入の時は配列要素に対して適用
  local rex='^[_a-zA-Z][_a-zA-Z0-9]*=+?\('
  if ((wtype==_ble_attr_VAR)) && [[ $word =~ $rex ]]; then
    ble/syntax/tree-enumerate-children ble/widget/shell-expand-line.proc
    return 0
  fi

  local flags=
  local -a ret=() words=()
  ble/widget/shell-expand-line.expand-word "$word"
  words=("${ret[@]}")
  [[ ${#words[@]} -eq 1 && $word == "$ret" ]] && return 0

  if ((wtype==_ble_ctx_RDRF||wtype==_ble_ctx_RDRD||wtype==_ble_ctx_RDRS)); then
    local IFS=$_ble_term_IFS
    words=("${words[*]}")
  fi

  local q=\' Q="'\''" specialchars='\ ["'\''`$|&;<>()*?!^{,}'
  local w index=0 out=
  for w in "${words[@]}"; do
    ((index++)) && out=$out' '
    [[ $flags == *q* && $w == *["$specialchars"]* ]] && w=$q${w//$q/$Q}$q
    out=$out$w
  done

  changed=1
  ble/widget/.replace-range "$wbegin" $((wbegin+wlen)) "$out"
}
## @widget shell-expand-line opts
##   @param[in] opts
##     コロン区切りのオプションです。
##     quote 直接実行した時と振る舞いが同じになる様に、
##           展開結果を適切に quote します。
function ble/widget/shell-expand-line {
  local opts=:$1:
  ble-edit/content/clear-arg
  ble/widget/history-expand-line
  ble-edit/content/update-syntax
  local iN= changed=
  ble/syntax/tree-enumerate ble/widget/shell-expand-line.proc
  [[ $changed ]] && _ble_edit_mark_active=
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/undo ****                                            @edit.undo

## @var _ble_edit_undo_hindex=
##   現在の _ble_edit_undo が保持する情報の履歴項目番号。
##   初期は空文字列でどの履歴項目でもない状態を表す。
##

_ble_edit_undo=()
_ble_edit_undo_index=0
_ble_edit_undo_history=()
_ble_edit_undo_hindex=
ble/array#push _ble_textarea_local_VARNAMES \
               _ble_edit_undo \
               _ble_edit_undo_index \
               _ble_edit_undo_history \
               _ble_edit_undo_hindex
function ble-edit/undo/.check-hindex {
  local hindex; ble/history/get-index -v hindex
  [[ $_ble_edit_undo_hindex == "$hindex" ]] && return 0

  # save
  if [[ $_ble_edit_undo_hindex ]]; then
    local uindex=${_ble_edit_undo_index:-${#_ble_edit_undo[@]}}
    local ret; ble/string#quote-words "$uindex" "${_ble_edit_undo[@]}"
    _ble_edit_undo_history[_ble_edit_undo_hindex]=$ret
  fi

  # load
  if [[ ${_ble_edit_undo_history[hindex]} ]]; then
    local data; builtin eval -- "data=(${_ble_edit_undo_history[hindex]})"
    _ble_edit_undo=("${data[@]:1}")
    _ble_edit_undo_index=${data[0]}
  else
    _ble_edit_undo=()
    _ble_edit_undo_index=0
  fi
  _ble_edit_undo_hindex=$hindex
}
function ble-edit/undo/clear-all {
  _ble_edit_undo=()
  _ble_edit_undo_index=0
  _ble_edit_undo_history=()
  _ble_edit_undo_hindex=
}
function ble-edit/undo/history-delete.hook {
  ble/builtin/history/array#delete-hindex _ble_edit_undo_history "$@"
  _ble_edit_undo_hindex=
}
function ble-edit/undo/history-clear.hook {
  ble-edit/undo/clear-all
}
function ble-edit/undo/history-insert.hook {
  ble/builtin/history/array#insert-range _ble_edit_undo_history "$@"
  local beg=$1 len=$2
  [[ $_ble_edit_undo_hindex ]] &&
    ((_ble_edit_undo_hindex>=beg)) &&
    ((_ble_edit_undo_hindex+=len))
}
blehook history_delete+=ble-edit/undo/history-delete.hook
blehook history_clear+=ble-edit/undo/history-clear.hook
blehook history_insert+=ble-edit/undo/history-insert.hook

## @fn ble-edit/undo/.get-current-state
##   @var[out] str ind
function ble-edit/undo/.get-current-state {
  if ((_ble_edit_undo_index==0)); then
    str=
    if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
      local index; ble/history/get-index
      ble/history/get-entry -v str "$index"
    fi
    ind=${#entry}
  else
    local entry=${_ble_edit_undo[_ble_edit_undo_index-1]}
    str=${entry#*:} ind=${entry%%:*}
  fi
}

function ble-edit/undo/add {
  ble-edit/undo/.check-hindex

  # 変更がない場合は記録しない
  local str ind; ble-edit/undo/.get-current-state
  [[ $str == "$_ble_edit_str" ]] && return 0

  _ble_edit_undo[_ble_edit_undo_index++]=$_ble_edit_ind:$_ble_edit_str
  if ((${#_ble_edit_undo[@]}>_ble_edit_undo_index)); then
    _ble_edit_undo=("${_ble_edit_undo[@]::_ble_edit_undo_index}")
  fi
}
function ble-edit/undo/.load {
  local str ind; ble-edit/undo/.get-current-state
  if [[ $bleopt_undo_point == end || $bleopt_undo_point == beg ]]; then

    # Note: 実際の編集過程に依らず、現在位置 _ble_edit_ind の周辺で
    #   変更前と変更後の文字列だけから「変更範囲」を決定する事にする。
    local old=$_ble_edit_str new=$str ret
    if [[ $bleopt_undo_point == end ]]; then
      ble/string#common-suffix "${old:_ble_edit_ind}" "$new"; local s1=${#ret}
      local old=${old::${#old}-s1} new=${new:${#new}-s1}
      ble/string#common-prefix "${old::_ble_edit_ind}" "$new"; local p1=${#ret}
      local old=${old:p1} new=${new:p1}
      ble/string#common-suffix "$old" "$new"; local s2=${#ret}
      local old=${old::${#old}-s2} new=${new:${#new}-s2}
      ble/string#common-prefix "$old" "$new"; local p2=${#ret}
    else
      ble/string#common-prefix "${old::_ble_edit_ind}" "$new"; local p1=${#ret}
      local old=${old:p1} new=${new:p1}
      ble/string#common-suffix "${old:_ble_edit_ind-p1}" "$new"; local s1=${#ret}
      local old=${old::${#old}-s1} new=${new:${#new}-s1}
      ble/string#common-prefix "$old" "$new"; local p2=${#ret}
      local old=${old:p2} new=${new:p2}
      ble/string#common-suffix "$old" "$new"; local s2=${#ret}
    fi

    local beg=$((p1+p2)) end0=$((${#_ble_edit_str}-s1-s2)) end=$((${#str}-s1-s2))
    ble-edit/content/replace "$beg" "$end0" "${str:beg:end-beg}"

    if [[ $bleopt_undo_point == end ]]; then
      ind=$end
    else
      ind=$beg
    fi
  else
    ble-edit/content/reset-and-check-dirty "$str"
  fi

  _ble_edit_ind=$ind
  return 0
}
function ble-edit/undo/undo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index-=arg))
  ((_ble_edit_undo_index<0&&(_ble_edit_undo_index=0)))
  ble-edit/undo/.load
}
function ble-edit/undo/redo {
  local arg=${1:-1}
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  local ucount=${#_ble_edit_undo[@]}
  ((_ble_edit_undo_index<ucount)) || return 1
  ((_ble_edit_undo_index+=arg))
  ((_ble_edit_undo_index>=ucount&&(_ble_edit_undo_index=ucount)))
  ble-edit/undo/.load
}
function ble-edit/undo/revert {
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  ((_ble_edit_undo_index)) || return 1
  ((_ble_edit_undo_index=0))
  ble-edit/undo/.load
}
function ble-edit/undo/revert-toggle {
  local arg=${1:-1}
  ((arg%2==0)) && return 0
  ble-edit/undo/.check-hindex
  ble-edit/undo/add # 最後に add/load してから変更があれば記録
  if ((_ble_edit_undo_index)); then
    ((_ble_edit_undo_index=0))
    ble-edit/undo/.load
  elif ((${#_ble_edit_undo[@]})); then
    ((_ble_edit_undo_index=${#_ble_edit_undo[@]}))
    ble-edit/undo/.load
  else
    return 1
  fi
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/keyboard-macro ****                                 @edit.macro

_ble_edit_kbdmacro_record=
_ble_edit_kbdmacro_last=()
_ble_edit_kbdmacro_onplay=
function ble/widget/start-keyboard-macro {
  ble/keymap:generic/clear-arg
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # 再生中は無視
  if ! ble/decode/charlog#start kbd-macro; then
    if [[ $_ble_decode_keylog_chars_enabled == kbd-macro ]]; then
      ble/widget/.bell 'kbd-macro: recording is already started'
    else
      ble/widget/.bell 'kbd-macro: the logging system is currently busy'
    fi
    return 1
  fi

  _ble_edit_kbdmacro_record=1
  if [[ $_ble_decode_keymap == emacs ]]; then
    ble/keymap:emacs/update-mode-name
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/end-keyboard-macro {
  ble/keymap:generic/clear-arg
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # 再生中は無視
  if [[ $_ble_decode_keylog_chars_enabled != kbd-macro ]]; then
    ble/widget/.bell 'kbd-macro: recording is not running'
    return 1
  fi
  _ble_edit_kbdmacro_record=

  ble/decode/charlog#end-exclusive-depth1
  _ble_edit_kbdmacro_last=("${ret[@]}")
  if [[ $_ble_decode_keymap == emacs ]]; then
    ble/keymap:emacs/update-mode-name
  elif [[ $_ble_decode_keymap == vi_nmap ]]; then
    ble/keymap:vi/adjust-command-mode
  fi
  return 0
}
function ble/widget/call-keyboard-macro {
  local arg; ble-edit/content/get-arg 1
  ble/keymap:generic/clear-arg
  ((arg>0)) || return 1
  [[ $_ble_edit_kbdmacro_onplay ]] && return 0 # 再生中は無視

  local _ble_edit_kbdmacro_onplay=1
  if ((arg==1)); then
    ble/widget/.MACRO "${_ble_edit_kbdmacro_last[@]}"
  else
    local -a chars=()
    while ((arg-->0)); do
      ble/array#push chars "${_ble_edit_kbdmacro_last[@]}"
    done
    ble/widget/.MACRO "${chars[@]}"
  fi
  [[ $_ble_decode_keymap == vi_nmap ]] &&
    ble/keymap:vi/adjust-command-mode
}
function ble/widget/print-keyboard-macro {
  ble/keymap:generic/clear-arg
  local ret; ble/decode/charlog#encode "${_ble_edit_kbdmacro_last[@]}"
  ble/edit/info/show text "kbd-macro: $ret"
  [[ $_ble_decode_keymap == vi_nmap ]] &&
    ble/keymap:vi/adjust-command-mode
  return 0
}

# 
#------------------------------------------------------------------------------
# **** history ****                                                    @history

bleopt/declare -v history_preserve_point ''

function ble-edit/history/goto {
  ble/history/initialize

  local histlen=$_ble_history_COUNT
  local index0=$_ble_history_INDEX
  local index1=$1

  ((index0==index1)) && return 0

  if ((index1>histlen)); then
    index1=$histlen
    ble/widget/.bell
  elif ((index1<0)); then
    index1=0
    ble/widget/.bell
  fi

  ((index0==index1)) && return 0

  if [[ $bleopt_history_share && ! $_ble_history_prefix && $_ble_decode_keymap != isearch ]]; then
    # Note: isearch の途中の history/goto で履歴情報が書き換わると変な事になるので
    #   isearch では history_share による読み込みは行わない。
    #   一方で nsearch や lastarg は過去の履歴項目を参照するが
    #   ble-edit/history/goto を呼び出す事はない。
    if ((index0==histlen||index1==histlen)); then
      ble/builtin/history/option:n
      local histlen2=$_ble_history_COUNT
      if ((histlen!=histlen2)); then
        ble/textarea#invalidate
        ble-edit/history/goto $((index1==histlen?histlen:index1))
        return "$?"
      fi
    fi
  fi

  # store
  ble/history/set-edited-entry "$index0" "$_ble_edit_str"
  ble/history/onleave.fire

  # restore
  ble/history/set-index "$index1"
  local entry; ble/history/get-edited-entry -v entry "$index1"
  ble-edit/content/reset "$entry" history

  # point
  if [[ $bleopt_history_preserve_point ]]; then
    if ((_ble_edit_ind>${#_ble_edit_str})); then
      _ble_edit_ind=${#_ble_edit_str}
    fi
  else
    if ((index1<index0)); then
      # 遡ったときは最後の行の末尾
      _ble_edit_ind=${#_ble_edit_str}
    else
      # 進んだときは最初の行の末尾
      local first_line=${_ble_edit_str%%$'\n'*}
      _ble_edit_ind=${#first_line}
    fi
  fi
  _ble_edit_mark=0
  _ble_edit_mark_active=
}

function ble-edit/history/history-message.hook {
  ((_ble_edit_attached)) || return 1
  local message=$1
  if [[ $message ]]; then
    ble/edit/info/immediate-show text "$message"
  else
    ble/edit/info/immediate-clear
  fi
}
blehook history_message+=ble-edit/history/history-message.hook

# 
#------------------------------------------------------------------------------
# **** basic history widgets ****                               @history.widget

function ble/widget/history-next {
  if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
    local arg; ble-edit/content/get-arg 1
    ble/history/initialize
    ble-edit/history/goto $((_ble_history_INDEX+arg))
  else
    ble-edit/content/clear-arg
    ble/widget/.bell
  fi
}
function ble/widget/history-prev {
  local arg; ble-edit/content/get-arg 1
  ble/history/initialize
  ble-edit/history/goto $((_ble_history_INDEX-arg))
}
function ble/widget/history-beginning {
  ble-edit/content/clear-arg
  ble-edit/history/goto 0
}
function ble/widget/history-end {
  ble-edit/content/clear-arg
  if [[ $_ble_history_prefix || $_ble_history_load_done ]]; then
    ble/history/initialize
    ble-edit/history/goto "$_ble_history_COUNT"
  else
    ble/widget/.bell
  fi
}

## @widget history-expand-line
##   @exit 展開が行われた時に成功します。それ以外の時に失敗します。
function ble/widget/history-expand-line {
  ble-edit/content/clear-arg
  local hist_expanded
  ble-edit/hist_expanded.update "$_ble_edit_str" || return 1
  [[ $_ble_edit_str == "$hist_expanded" ]] && return 1

  ble-edit/content/reset-and-check-dirty "$hist_expanded"
  _ble_edit_ind=${#hist_expanded}
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
function ble/widget/history-and-alias-expand-line {
  ble/widget/history-expand-line
  ble/widget/alias-expand-line
}
## @widget history-expand-backward-line
##   @exit 展開が行われた時に成功します。それ以外の時に失敗します。
function ble/widget/history-expand-backward-line {
  ble-edit/content/clear-arg
  local prevline=${_ble_edit_str::_ble_edit_ind} hist_expanded
  ble-edit/hist_expanded.update "$prevline" || return 1
  [[ $prevline == "$hist_expanded" ]] && return 1

  local ret
  ble/string#common-prefix "$prevline" "$hist_expanded"; local dmin=${#ret}

  local insert; ble-edit/content/replace-limited "$dmin" "$_ble_edit_ind" "${hist_expanded:dmin}"
  ((_ble_edit_ind=dmin+${#insert}))
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
## @widget magic-space
##   履歴展開と静的略語展開を実行してから空白を挿入します。
function ble/widget/magic-space {
  # keymap/vi.sh
  [[ $_ble_decode_keymap == vi_imap ]] &&
    local oind=$_ble_edit_ind ostr=$_ble_edit_str

  local arg; ble-edit/content/get-arg ''
  ble/widget/history-expand-backward-line ||
    ble/complete/sabbrev/expand
  local ext=$?
  ((ext==147)) && return 147 # sabbrev/expand でメニュー補完に入った時など。

  # keymap/vi.sh
  [[ $_ble_decode_keymap == vi_imap ]] &&
    if [[ $ostr != "$_ble_edit_str" ]]; then
      _ble_edit_ind=$oind _ble_edit_str=$ostr ble/keymap:vi/undo/add more
      ble/keymap:vi/undo/add more
    fi

  local -a KEYS=(32)
  _ble_edit_arg=$arg
  ble/widget/self-insert
}

# 
#------------------------------------------------------------------------------
# **** basic search functions ****                              @history.search

function ble/highlight/layer:region/mark:search/get-face { face=region_match; }

## @fn ble-edit/isearch/search needle opts ; beg end
##   @param[in] needle
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     + ... forward に検索します (既定)
##     - ... backward に検索します。終端位置が現在位置以前にあるものに一致します。
##     B ... backward に検索します。開始位置が現在位置より前のものに一致します。
##     extend
##       これが指定された時、現在位置における一致の伸長が試みられます。
##       指定されなかったとき、現在一致範囲と重複のない新しい一致が試みられます。
##     regex
##       正規表現による一致を試みます
##     allow_empty
##       空一致 (長さ0の一致) が現在位置で起こることを許容します。
##       既定では空一致の時には一つ次の位置から再検索を実行します。
##
##   @var[out] beg end
##     検索対象が見つかった時に一致範囲の先頭と終端を返します。
##
##   @exit
##     検索対象が見つかった時に 0 を返します。
##     それ以外のときに 1 を返します。
function ble-edit/isearch/search {
  local needle=$1 opts=$2
  beg= end=
  [[ :$opts: != *:regex:* ]]; local has_regex=$?
  [[ :$opts: != *:extend:* ]]; local has_extend=$?

  local flag_empty_retry=
  if [[ :$opts: == *:-:* ]]; then
    local start=$((has_extend?_ble_edit_mark+1:_ble_edit_ind))

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.*($needle)" padding=$((${#_ble_edit_str}-start))
      ((padding)) && rex="$rex.{$padding}"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || $BASH_REMATCH == "$_ble_edit_str" || :$opts: == *:allow_empty:* ]]; then
          ((end=${#BASH_REMATCH}-padding,
            beg=end-${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        local target=${_ble_edit_str::start}
        local m=${target%"$needle"*}
        if [[ $target != "$m" ]]; then
          beg=${#m}
          end=$((beg+${#needle}))
          return 0
        fi
      else
        if [[ :$opts: == *:allow_empty:* ]] || ((--start>=0)); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  elif [[ :$opts: == *:B:* ]]; then
    local start=$((has_extend?_ble_edit_ind:_ble_edit_ind-1))
    ((start<0)) && return 1

    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="^.{0,$start}($needle)"
      ((start==0)) && rex="^($needle)"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || :$opts: == *:allow_empty:* ]]; then
          ((end=${#BASH_REMATCH},
            beg=end-${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        local target=${_ble_edit_str::start+${#needle}}
        local m=${target%"$needle"*}
        if [[ $target != "$m" ]]; then
          ((beg=${#m},
            end=beg+${#needle}))
          return 0
        fi
      else
        if [[ :$opts: == *:allow_empty:* ]] && ((--start>=0)); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  else
    local start=$((has_extend?_ble_edit_mark:_ble_edit_ind))
    if ((has_regex)); then
      ble-edit/isearch/.shift-backward-references
      local rex="($needle).*\$"
      ((start)) && rex=".{$start}$rex"
      if [[ $_ble_edit_str =~ $rex ]]; then
        local rematch1=${BASH_REMATCH[1]}
        if [[ $rematch1 || :$opts: == *:allow_empty:* ]]; then
          ((beg=${#_ble_edit_str}-${#BASH_REMATCH}+start))
          ((end=beg+${#rematch1}))
          return 0
        else
          flag_empty_retry=1
        fi
      fi
    else
      if [[ $needle ]]; then
        local target=${_ble_edit_str:start}
        local m=${target#*"$needle"}
        if [[ $target != "$m" ]]; then
          ((end=${#_ble_edit_str}-${#m}))
          ((beg=end-${#needle}))
          return 0
        fi
      else
        if [[ :$opts: == *:allow_empty:* ]] || ((++start<=${#_ble_edit_str})); then
          ((beg=end=start))
          return 0
        fi
      fi
    fi
  fi

  # (正規表現一致の時) 現在地の空一致に対して再一致
  if [[ $flag_empty_retry ]]; then
    if [[ :$opts: == *:[-B]:* ]]; then
      if ((--start>=0)); then
        local mark=$_ble_edit_mark; ((mark&&mark--))
        local ind=$_ble_edit_ind; ((ind&&ind--))
        opts=$opts:allow_empty
        _ble_edit_mark=$mark _ble_edit_ind=$ind ble-edit/isearch/search "$needle" "$opts"
        return 0
      fi
    else
      if ((++start<=${#_ble_edit_str})); then
        local mark=$_ble_edit_mark; ((mark<${#_ble_edit_str}&&mark++))
        local ind=$_ble_edit_ind; ((ind<${#_ble_edit_str}&&ind++))
        opts=$opts:allow_empty
        _ble_edit_mark=$mark _ble_edit_ind=$ind ble-edit/isearch/search "$needle" "$opts"
        return 0
      fi
    fi
  fi
  return 1
}
## @fn ble-edit/isearch/.shift-backward-references
##   @var[in,out] needle
##     処理する正規表現を指定します。
##     後方参照をおきかえた正規表現を返します。
function ble-edit/isearch/.shift-backward-references {
    # 後方参照 (backward references) の番号を 1 ずつ増やす。
    # bash 正規表現は 2 桁以上の後方参照に対応していないので、
    # \1 - \8 を \2-\9 にずらすだけにする (\9 が存在するときに問題になるが仕方がない)。
    local rex_cc='\[[@][^]@]+[@]\]' # [:space:] [=a=] [.a.] など。
    local rex_bracket_expr='\[\^?]?('${rex_cc//@/:}'|'${rex_cc//@/=}'|'${rex_cc//@/.}'|[^][]|\[[^]:=.])*\[?\]'
    local rex='^('$rex_bracket_expr'|\\[^1-8])*\\[1-8]'
    local buff=
    while [[ $needle =~ $rex ]]; do
      local mlen=${#BASH_REMATCH}
      buff=$buff${BASH_REMATCH::mlen-1}$((10#${BASH_REMATCH:mlen-1}+1))
      needle=${needle:mlen}
    done
    needle=$buff$needle
}

# 
#------------------------------------------------------------------------------
# **** incremental search ****                                 @history.isearch

## @var _ble_edit_isearch_str
##   一致した文字列
## @var _ble_edit_isearch_dir
##   現在・直前の検索方法
## @arr _ble_edit_isearch_arr[]
##   インクリメンタル検索の過程を記録する。
##   各要素は ind:dir:beg:end:needle の形式をしている。
##   ind は履歴項目の番号を表す。dir は履歴検索の方向を表す。
##   beg, end はそれぞれ一致開始位置と終了位置を表す。
##   丁度 _ble_edit_ind 及び _ble_edit_mark に対応する。
##   needle は検索に使用した文字列を表す。
## @var _ble_edit_isearch_old
##   前回の検索に使用した文字列
_ble_edit_isearch_str=
_ble_edit_isearch_dir=-
_ble_edit_isearch_arr=()
_ble_edit_isearch_old=

## @fn ble-edit/isearch/status/append-progress-bar pos count
##   @var[in,out] text
function ble-edit/isearch/status/append-progress-bar {
  ble/util/is-unicode-output || return 1
  local pos=$1 count=$2 dir=$3
  [[ :$dir: == *:-:* || :$dir: == *:backward:* ]] && ((pos=count-1-pos))
  local ret; ble/string#create-unicode-progress-bar "$pos" "$count" 5
  text=$text$' \e[1;38;5;69;48;5;253m'$ret$'\e[m '
}

## @fn ble-edit/isearch/.show-status-with-progress.fib [pos]
##   @param[in,opt] pos
##     検索の途中の時に現在の検索位置を指定します。
##     検索の進行状況を表示します。
##
##   @var[in] fib_ntask
##     現在の待ちスクの数を指定します。
##
##   @var[in] _ble_edit_isearch_str
##   @var[in] _ble_edit_isearch_dir
##   @var[in] _ble_edit_isearch_arr
##     現在の検索状態を保持する変数です。
##
function ble-edit/isearch/.show-status-with-progress.fib {
  # 出力
  local ll rr
  if [[ $_ble_edit_isearch_dir == - ]]; then
    # Emacs workaround: '<<' や "<<" と書けない。
    ll=\<\< rr="  "
  else
    ll="  " rr=">>"
  fi
  local index; ble/history/get-index
  local histIndex='!'$((index+1))
  local text="(${#_ble_edit_isearch_arr[@]}: $ll $histIndex $rr) \`$_ble_edit_isearch_str'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_isearch_dir"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi
  ((fib_ntask)) && text="$text *$fib_ntask"

  ble/edit/info/show ansi "$text"
}

## @fn ble-edit/isearch/.show-status.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.show-status.fib {
  ble-edit/isearch/.show-status-with-progress.fib
}
function ble-edit/isearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/isearch/.show-status.fib
}
function ble-edit/isearch/erase-status {
  ble/edit/info/default
}
function ble-edit/isearch/.set-region {
  local beg=$1 end=$2
  if ((beg<end)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      _ble_edit_ind=$beg
      _ble_edit_mark=$end
    else
      _ble_edit_ind=$end
      _ble_edit_mark=$beg
    fi
    _ble_edit_mark_active=search
  elif ((beg==end)); then
    _ble_edit_ind=$beg
    _ble_edit_mark=$beg
    _ble_edit_mark_active=
  else
    _ble_edit_mark_active=
  fi
}
## @fn ble-edit/isearch/.push-isearch-array
##   現在の isearch の情報を配列 _ble_edit_isearch_arr に待避する。
##
##   これから登録しようとしている情報が現在のものと同じならば何もしない。
##   これから登録しようとしている情報が配列の最上にある場合は、
##   検索の巻き戻しと解釈して配列の最上の要素を削除する。
##   それ以外の場合は、現在の情報を配列に追加する。
##   @var[in] ind beg end needle
##     これから登録しようとしている isearch の情報。
function ble-edit/isearch/.push-isearch-array {
  local hash=$beg:$end:$needle

  # [... A | B] -> A と来た時 (A を _ble_edit_isearch_arr から削除) [... | A] になる。
  local ilast=$((${#_ble_edit_isearch_arr[@]}-1))
  if ((ilast>=0)) && [[ ${_ble_edit_isearch_arr[ilast]} == "$ind:"[-+]":$hash" ]]; then
    builtin unset -v "_ble_edit_isearch_arr[$ilast]"
    return 0
  fi

  local oind; ble/history/get-index -v oind
  local obeg=$_ble_edit_ind oend=$_ble_edit_mark
  [[ $_ble_edit_mark_active ]] || oend=$obeg
  ((obeg>oend)) && local obeg=$oend oend=$obeg
  local oneedle=$_ble_edit_isearch_str
  local ohash=$obeg:$oend:$oneedle

  # [... A | B] -> B と来た時 (何もしない) [... A | B] になる。
  [[ $ind == "$oind" && $hash == "$ohash" ]] && return 0

  # [... A | B] -> C と来た時 (B を _ble_edit_isearch_arr に移動) [... A B | C] になる。
  ble/array#push _ble_edit_isearch_arr "$oind:$_ble_edit_isearch_dir:$ohash"
}
## @fn ble-edit/isearch/.goto-match.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.goto-match.fib {
  local ind=$1 beg=$2 end=$3 needle=$4

  # 検索履歴に待避 (変数 ind beg end needle 使用)
  ble-edit/isearch/.push-isearch-array

  # 状態を更新
  _ble_edit_isearch_str=$needle
  [[ $needle ]] && _ble_edit_isearch_old=$needle
  local oind; ble/history/get-index -v oind
  ((oind!=ind)) && ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"

  # isearch 表示
  ble-edit/isearch/.show-status.fib
  ble/textarea#redraw
}

# ---- isearch fibers ---------------------------------------------------------

## @fn ble-edit/isearch/.next.fib opts [needle]
##   @param[in] opts
##     append
##     forward
##     backward
function ble-edit/isearch/.next.fib {
  local opts=$1
  if [[ ! $fib_suspend ]]; then
    if [[ :$opts: == *:forward:* || :$opts: == *:backward:* ]]; then
      if [[ :$opts: == *:forward:* ]]; then
        _ble_edit_isearch_dir=+
      else
        _ble_edit_isearch_dir=-
      fi
    fi

    # 現在行の別の位置での一致
    local needle=${2-$_ble_edit_isearch_str}
    local beg= end= search_opts=$_ble_edit_isearch_dir
    if [[ :$opts: == *:append:* ]]; then
      search_opts=$search_opts:extend
      # Note: 現在の項目はここで処理するので
      #   .next-history.fib には append は指定しない #D1025
      ble/path#remove opts append
    fi
    if [[ $needle ]] && ble-edit/isearch/search "$needle" "$search_opts"; then
      local ind; ble/history/get-index -v ind
      ble-edit/isearch/.goto-match.fib "$ind" "$beg" "$end" "$needle"
      return 0
    fi
  fi
  ble-edit/isearch/.next-history.fib "$opts" "$needle"
}

## @fn ble-edit/isearch/.next-history.fib [opts [needle]]
##
##   @param[in,opt] opts
##     コロン区切りのリストです。
##     append
##       現在の履歴項目を検索対象とします。
##
##   @param[in,opt] needle
##     新しい検索を開始する場合に、検索対象を明示的に指定します。
##     needle に検索対象の文字列を指定します。
##
##   @var[in,out] fib_suspend
##     中断した時にこの変数に再開用のデータを格納します。
##     再開する時はこの変数の中断時の内容を復元してこの関数を呼び出します。
##     この変数が空の場合は新しい検索を開始します。
##   @var[in] _ble_edit_isearch_str
##     最後に一致した検索文字列を指定します。
##     検索対象を明示的に指定しなかった場合に使う検索対象です。
##
##   @var[in] _ble_edit_isearch_dir
##     現在の検索方向を指定します。
##   @var[in] PREFIX_history_edit[]
##   @var[in,out] isearch_time
##
function ble-edit/isearch/.next-history.fib {
  local opts=$1
  if [[ $fib_suspend ]]; then
    # resume the previous search
    local needle=${fib_suspend#*:} isAdd=
    local index start; builtin eval -- "${fib_suspend%%:*}"
    fib_suspend=
  else
    # initialize new search
    local needle=${2-$_ble_edit_isearch_str} isAdd=
    [[ :$opts: == *:append:* ]] && isAdd=1
    ble/history/initialize
    local start=$_ble_history_INDEX
    local index=$start
  fi

  if ((!isAdd)); then
    if [[ $_ble_edit_isearch_dir == - ]]; then
      ((index--))
    else
      ((index++))
    fi
  fi

  # 検索
  local isearch_progress_callback=ble-edit/isearch/.show-status-with-progress.fib
  if [[ $_ble_edit_isearch_dir == - ]]; then
    ble/history/isearch-backward-blockwise stop_check:progress
  else
    ble/history/isearch-forward stop_check:progress
  fi
  local ext=$?

  if ((ext==0)); then
    # 見付かった場合

    # 一致範囲 beg-end を取得
    local str; ble/history/get-edited-entry -v str "$index"
    if [[ $needle ]]; then
      if [[ $_ble_edit_isearch_dir == - ]]; then
        local prefix=${str%"$needle"*}
      else
        local prefix=${str%%"$needle"*}
      fi
      local beg=${#prefix} end=$((${#prefix}+${#needle}))
    else
      local beg=${#str} end=${#str}
    fi

    ble-edit/isearch/.goto-match.fib "$index" "$beg" "$end" "$needle"
  elif ((ext==148)); then
    # 中断した場合
    fib_suspend="index=$index start=$start:$needle"
    return 0
  else
    # 見つからなかった場合
    ble/widget/.bell "isearch: \`$needle' not found"
    return 0
  fi
}

function ble-edit/isearch/forward.fib {
  if [[ ! $_ble_edit_isearch_str ]]; then
    ble-edit/isearch/.next.fib forward "$_ble_edit_isearch_old"
  else
    ble-edit/isearch/.next.fib forward
  fi
}
function ble-edit/isearch/backward.fib {
  if [[ ! $_ble_edit_isearch_str ]]; then
    ble-edit/isearch/.next.fib backward "$_ble_edit_isearch_old"
  else
    ble-edit/isearch/.next.fib backward
  fi
}
function ble-edit/isearch/self-insert.fib {
  local needle=
  if [[ ! $fib_suspend ]]; then
    local code=$1
    ((code==0)) && return 0
    local ret; ble/util/c2s "$code"
    needle=$_ble_edit_isearch_str$ret
  fi
  ble-edit/isearch/.next.fib append "$needle"
}
function ble-edit/isearch/insert-string.fib {
  local needle=
  [[ ! $fib_suspend ]] &&
    needle=$_ble_edit_isearch_str$1
  ble-edit/isearch/.next.fib append "$needle"
}
function ble-edit/isearch/history-forward.fib {
  _ble_edit_isearch_dir=+
  ble-edit/isearch/.next-history.fib
}
function ble-edit/isearch/history-backward.fib {
  _ble_edit_isearch_dir=-
  ble-edit/isearch/.next-history.fib
}
function ble-edit/isearch/history-self-insert.fib {
  local needle=
  if [[ ! $fib_suspend ]]; then
    local code=$1
    ((code==0)) && return 0
    local ret; ble/util/c2s "$code"
    needle=$_ble_edit_isearch_str$ret
  fi
  ble-edit/isearch/.next-history.fib append "$needle"
}

function ble-edit/isearch/prev {
  local sz=${#_ble_edit_isearch_arr[@]}
  ((sz==0)) && return 0

  local ilast=$((sz-1))
  local top=${_ble_edit_isearch_arr[ilast]}
  builtin unset -v '_ble_edit_isearch_arr[ilast]'

  local ind dir beg end
  ind=${top%%:*}; top=${top#*:}
  dir=${top%%:*}; top=${top#*:}
  beg=${top%%:*}; top=${top#*:}
  end=${top%%:*}; top=${top#*:}

  _ble_edit_isearch_dir=$dir
  ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"
  _ble_edit_isearch_str=$top
  [[ $top ]] && _ble_edit_isearch_old=$top

  # isearch 表示
  ble-edit/isearch/show-status
}

function ble-edit/isearch/process {
  local isearch_time=0
  ble/util/fiberchain#resume
  ble-edit/isearch/show-status
}
function ble/widget/isearch/forward {
  ble/util/fiberchain#push forward
  ble-edit/isearch/process
}
function ble/widget/isearch/backward {
  ble/util/fiberchain#push backward
  ble-edit/isearch/process
}
function ble/widget/isearch/self-insert {
  local code=$((KEYS[0]&_ble_decode_MaskChar))
  ble/util/fiberchain#push "self-insert $code"
  ble-edit/isearch/process
}
function ble/widget/isearch/history-forward {
  ble/util/fiberchain#push history-forward
  ble-edit/isearch/process
}
function ble/widget/isearch/history-backward {
  ble/util/fiberchain#push history-backward
  ble-edit/isearch/process
}
function ble/widget/isearch/history-self-insert {
  local code=$((KEYS[0]&_ble_decode_MaskChar))
  ble/util/fiberchain#push "history-self-insert $code"
  ble-edit/isearch/process
}
function ble/widget/isearch/prev {
  local nque
  if ((nque=${#_ble_util_fiberchain[@]})); then
    local ret; ble/array#pop _ble_util_fiberchain
    ble-edit/isearch/process
  else
    ble-edit/isearch/prev
  fi
}

function ble/widget/isearch/.restore-mark-state {
  local old_mark_active=${_ble_edit_isearch_save[3]}
  if [[ $old_mark_active ]]; then
    local index; ble/history/get-index
    if ((index==_ble_edit_isearch_save[0])); then
      _ble_edit_mark=${_ble_edit_isearch_save[2]}
      if [[ $old_mark_active != S ]] || ((_ble_edit_ind==_ble_edit_isearch_save[1])); then
        _ble_edit_mark_active=$old_mark_active
      fi
    fi
  fi
}
function ble/widget/isearch/exit.impl {
  ble/decode/keymap/pop
  _ble_edit_isearch_arr=()
  _ble_edit_isearch_dir=
  _ble_edit_isearch_str=
  ble-edit/isearch/erase-status
}
function ble/widget/isearch/exit-with-region {
  ble/widget/isearch/exit.impl
  [[ $_ble_edit_mark_active ]] &&
    _ble_edit_mark_active=S
}
function ble/widget/isearch/exit {
  ble/widget/isearch/exit.impl

  _ble_edit_mark_active=
  ble/widget/isearch/.restore-mark-state
}
function ble/widget/isearch/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-edit/isearch/show-status # 進捗状況だけ消去
  else
    if ((${#_ble_edit_isearch_arr[@]})); then
      local step
      ble/string#split step : "${_ble_edit_isearch_arr[0]}"
      ble-edit/history/goto "${step[0]}"
    fi

    ble/widget/isearch/exit.impl
    _ble_edit_ind=${_ble_edit_isearch_save[1]}
    _ble_edit_mark=${_ble_edit_isearch_save[2]}
    _ble_edit_mark_active=${_ble_edit_isearch_save[3]}
  fi
}
function ble/widget/isearch/exit-default {
  ble/widget/isearch/exit-with-region
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}
function ble/widget/isearch/accept-line {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/widget/.bell "isearch: now searching..."
  else
    ble/widget/isearch/exit
    ble-decode-key 13 # RET
  fi
}
function ble/widget/isearch/exit-delete-forward-char {
  ble/widget/isearch/exit
  ble/widget/delete-forward-char
}

## @fn ble/widget/history-isearch.impl opts
function ble/widget/history-isearch.impl {
  local opts=$1
  ble-edit/content/clear-arg
  ble/decode/keymap/push isearch
  ble/util/fiberchain#initialize ble-edit/isearch

  local index; ble/history/get-index
  _ble_edit_isearch_save=("$index" "$_ble_edit_ind" "$_ble_edit_mark" "$_ble_edit_mark_active")

  if [[ :$opts: == *:forward:* ]]; then
    _ble_edit_isearch_dir=+
  else
    _ble_edit_isearch_dir=-
  fi
  _ble_edit_isearch_arr=()
  _ble_edit_mark=$_ble_edit_ind
  ble-edit/isearch/show-status
}
function ble/widget/history-isearch-backward {
  ble/widget/history-isearch.impl backward
}
function ble/widget/history-isearch-forward {
  ble/widget/history-isearch.impl forward
}

function ble-decode/keymap:isearch/define {
  ble-bind -f __defchar__ isearch/self-insert
  ble-bind -f __line_limit__ nop

  ble-bind -f C-r         isearch/backward
  ble-bind -f C-s         isearch/forward
  ble-bind -f 'C-?'       isearch/prev
  ble-bind -f 'DEL'       isearch/prev
  ble-bind -f 'C-h'       isearch/prev
  ble-bind -f 'BS'        isearch/prev

  ble-bind -f __default__ isearch/exit-default
  ble-bind -f 'C-g'       isearch/cancel
  ble-bind -f 'C-x C-g'   isearch/cancel
  ble-bind -f 'C-M-g'     isearch/cancel
  ble-bind -f C-m         isearch/exit
  ble-bind -f RET         isearch/exit
  ble-bind -f C-j         isearch/accept-line
  ble-bind -f C-RET       isearch/accept-line
}

# 
#------------------------------------------------------------------------------
# **** non-incremental-search ****                             @history.nsearch

## @var _ble_edit_nsearch_needle
##   検索対象の文字列を保持します。
## @var _ble_edit_nsearch_input
##   最後にユーザ入力された検索対象を保持します。
## @var _ble_edit_nsearch_opts
##   検索の振る舞いを制御するオプションを保持します。
## @arr _ble_edit_nsearch_stack[]
##   検索が一致する度に記録される。
##   各要素は "direction,index,ind,mark:line" の形式をしている。
##   前回の検索の方向 (direction) と、検索前の状態を記録する。
##   index は検索の履歴位置で ind と mark はカーソル位置とマークの位置。
##   line は編集文字列である。
## @var _ble_edit_nsearch_match
##   現在表示している行内容がどの履歴番号に対応するかを保持します。
##   nsearch 開始位置もしくは最後に一致した位置に対応します。
## @var _ble_edit_nsearch_index
##   最後に検索した位置を表します。
##   検索が一致した場合は _ble_edit_nsearch_match と同じになります。
## @var _ble_edit_nsearch_prev
##   前回の検索文字列
_ble_edit_nsearch_input=
_ble_edit_nsearch_needle=
_ble_edit_nsearch_index0=
_ble_edit_nsearch_opts=
_ble_edit_nsearch_stack=()
_ble_edit_nsearch_match=
_ble_edit_nsearch_index=
_ble_edit_nsearch_prev=

function ble/highlight/layer:region/mark:nsearch/get-face {
  face=region_match
}
function ble/highlight/layer:region/mark:nsearch/get-selection {
  local beg=$_ble_edit_mark
  local end=$((_ble_edit_mark+${#_ble_edit_nsearch_needle}))
  selection=("$beg" "$end")
}

## @fn ble-edit/nsearch/.show-status.fib [pos_progress]
##   @var[in] fib_ntask
function ble-edit/nsearch/.show-status.fib {
  [[ :$_ble_edit_nsearch_opts: == *:hide-status:* ]] && return 0

  local ll=\<\< rr=">>" # Note: Emacs workaround: '<<' や "<<" と書けない。
  local match=$_ble_edit_nsearch_match index0=$_ble_edit_nsearch_index0
  if ((match>index0)); then
    ll="  "
  elif ((match<index0)); then
    rr="  "
  fi

  local sindex='!'$((_ble_edit_nsearch_match+1))
  local nmatch=${#_ble_edit_nsearch_stack[@]}
  local needle=$_ble_edit_nsearch_needle
  local text="(nsearch#$nmatch: $ll $sindex $rr) \`$needle'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_isearch_opts"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  local ntask=$fib_ntask
  ((ntask)) && text="$text *$ntask"

  ble/edit/info/show ansi "$text"
}
function ble-edit/nsearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/nsearch/.show-status.fib
}
function ble-edit/nsearch/erase-status {
  ble/edit/info/default
}

#@ToDo backward/forward backward 固定になっているがそれで良いのか?
function ble-edit/nsearch/.goto-match {
  local index=$1 opts=$2
  local direction=backward
  [[ :$opts: == *:forward:* ]] && direction=forward
  local needle=$_ble_edit_nsearch_needle
  local old_match=$_ble_edit_nsearch_match
  ble/array#push _ble_edit_nsearch_stack "$direction,$old_match,$_ble_edit_ind,$_ble_edit_mark:$_ble_edit_str"

  if [[ ! $index ]]; then
    ble/history/get-index
  elif [[ :$opts: == *:action=load:* ]]; then
    local old_index; ble/history/get-index -v old_index
    if ((index!=old_index)); then
      local line; ble/history/get-edited-entry -v line "$index"
      ble-edit/content/reset-and-check-dirty "$line"
    fi
  else
    ble-edit/history/goto "$index"
  fi
  local prefix=${_ble_edit_str%%"$needle"*}
  local beg=${#prefix}
  local end=$((beg+${#needle}))
  _ble_edit_nsearch_match=$index
  _ble_edit_nsearch_index=$index
  _ble_edit_mark=$beg
  case :$opts: in
  (*:point=begin:*)       _ble_edit_ind=0 ;;
  (*:point=end:*)         _ble_edit_ind=${#_ble_edit_str} ;;
  (*:point=match-begin:*) _ble_edit_ind=$beg ;;
  (*:point=match-end:*|*) _ble_edit_ind=$end ;;
  esac
  if ((beg!=end)); then
    _ble_edit_mark_active=nsearch
  else
    _ble_edit_mark_active=
  fi
}

function ble-edit/nsearch/.search.fib {
  local opts=$1
  local opt_forward=
  [[ :$opts: == *:forward:* ]] && opt_forward=1

  # 前回の一致と逆方向の時は前回の一致前の状態に戻す
  # Note: stack[0] は一致結果ではなくて現在行の記録に使われているので
  #   nstack >= 2 の時にのみ状態を戻すことにする。
  local nstack=${#_ble_edit_nsearch_stack[@]}
  if ((nstack>=2)); then
    local record_type=${_ble_edit_nsearch_stack[nstack-1]%%,*}
    if
      if [[ $opt_forward ]]; then
        [[ $record_type == backward ]]
      else
        [[ $record_type == forward ]]
      fi
    then
      local ret; ble/array#pop _ble_edit_nsearch_stack
      local record line=${ret#*:}
      ble/string#split record , "${ret%%:*}"

      if [[ :$opts: == *:action=load:* ]]; then
        ble-edit/content/reset-and-check-dirty "$line"
      else
        ble-edit/history/goto "${record[1]}"
      fi
      _ble_edit_nsearch_match=${record[1]}
      _ble_edit_nsearch_index=${record[1]}
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
      if ((_ble_edit_mark!=_ble_edit_ind)); then
        _ble_edit_mark_active=nsearch
      else
        _ble_edit_mark_active=
      fi
      ble-edit/nsearch/.show-status.fib
      ble/textarea#redraw
      fib_suspend=
      return 0
    fi
  fi

  # 検索の実行
  local index start opt_resume=
  if [[ $fib_suspend ]]; then
    opt_resume=1
    builtin eval -- "$fib_suspend"
    fib_suspend=
  else
    local index=$_ble_edit_nsearch_index
    if ((nstack==1)); then
      # 検索方向反転があった時は検索開始位置を初期化
      local index0=$_ble_edit_nsearch_index0
      ((opt_forward?index<index0:index>index0)) &&
        index=$index0
    fi
    local start=$index
  fi
  local needle=$_ble_edit_nsearch_needle
  if
    if [[ $opt_forward ]]; then
      local count; ble/history/get-count
      [[ $opt_resume ]] || ((++index))
      ((index<=count))
    else
      [[ $opt_resume ]] || ((--index))
      ((index>=0))
    fi
  then
    local isearch_time=$fib_clock
    local isearch_progress_callback=ble-edit/nsearch/.show-status.fib
    local isearch_opts=stop_check:progress; [[ :$opts: != *:substr:* ]] && isearch_opts=$isearch_opts:head
    if [[ $opt_forward ]]; then
      ble/history/isearch-forward "$isearch_opts"; local ext=$?
    else
      ble/history/isearch-backward-blockwise "$isearch_opts"; local ext=$?
    fi
    fib_clock=$isearch_time
  else
    local ext=1
  fi

  # 書き換え
  if ((ext==0)); then
    ble-edit/nsearch/.goto-match "$index" "$opts"
    ble-edit/nsearch/.show-status.fib
    ble/textarea#redraw
  elif ((ext==148)); then
    fib_suspend="index=$index start=$start"
    return 148
  else
    ble/widget/.bell "ble.sh: nsearch: '$needle' not found"
    ble-edit/nsearch/.show-status.fib
    if [[ $opt_forward ]]; then
      local count; ble/history/get-count
      ((_ble_edit_nsearch_index=count-1))
    else
      ((_ble_edit_nsearch_index=0))
    fi
    return "$ext"
  fi
}
function ble-edit/nsearch/forward.fib {
  ble-edit/nsearch/.search.fib "$_ble_edit_nsearch_opts:forward"
}
function ble-edit/nsearch/backward.fib {
  ble-edit/nsearch/.search.fib "$_ble_edit_nsearch_opts:backward"
}

## @widget history-search opts
##   @param[in] opts
##
##     forward   前方に検索します
##     backward  後方に検索します
##     substr    部分一致を行います
##     input     検索文字列をユーザー入力します
##     again     前回ユーザー入力した検索文字列を使います
##
##     empty=EMPTY
##       空文字列で検索を開始した時の動作を指定します。
##       previous-search 前回の検索文字列を使用して検索します [既定]
##       empty-search    空文字列で検索します。
##       hide-status     空文字列検索。nsearch 状態は隠します。
##       history-move    履歴項目移動。コマンドライン先頭に移動します。
##
##     action=ACTION
##       文字列が見つかった時の動作を指定します。
##       goto 見つかった履歴項目に移動します [既定]
##       load 現在の履歴項目の位置で見つかったコマンド文字列をロードします
##
##     point=POINT
##       文字列が見つかった時のカーソル位置を指定します。
##       begin       コマンドラインの先頭に移動します。
##       end         コマンドラインの末尾に移動します。
##       match-begin 一致範囲の先頭に移動します。
##       match-end   一致範囲の末尾に移動します。
##
##     hide-status
##       現在の検索状態を表示しません。
##
##     immediate-accept
##       nsearch を正常終了する時にコマンドを即座に実行します。
##
function ble/widget/history-search {
  local opts=$1

  # initialize variables
  if [[ :$opts: == *:input:* || :$opts: == *:again:* && ! $_ble_edit_nsearch_input ]]; then
    ble/builtin/read -ep "nsearch> " _ble_edit_nsearch_needle || return 1
    _ble_edit_nsearch_input=$_ble_edit_nsearch_needle
  elif [[ :$opts: == *:again:* ]]; then
    _ble_edit_nsearch_needle=$_ble_edit_nsearch_input
  else
    _ble_edit_nsearch_needle=${_ble_edit_str::_ble_edit_ind}
  fi

  # 検索文字列が空の時は別の動作を行う
  if [[ ! $_ble_edit_nsearch_needle ]]; then
    local empty=empty-search
    local rex='.*:empty=([^:]*):'
    [[ :$opts: =~ $rex ]] && empty=${BASH_REMATCH[1]}
    case $empty in
    (history-move)
      if [[ :$opts: == *:forward:* ]]; then
        ble/widget/history-next
      else
        ble/widget/history-prev
      fi && _ble_edit_ind=0
      return $? ;;
    (hide-status)
      opts=$opts:hide-status ;;
    (previous-search)
      _ble_edit_nsearch_needle=$_ble_edit_nsearch_prev ;;
    esac
  fi
  _ble_edit_nsearch_prev=$_ble_edit_nsearch_needle

  ble-edit/content/clear-arg

  _ble_edit_nsearch_stack=()
  local index; ble/history/get-index
  _ble_edit_nsearch_index0=$index
  _ble_edit_nsearch_opts=$opts
  ble/path#remove _ble_edit_nsearch_opts forward
  ble/path#remove _ble_edit_nsearch_opts backward
  _ble_edit_nsearch_match=$index
  _ble_edit_nsearch_index=$index
  _ble_edit_mark_active=
  ble/decode/keymap/push nsearch

  # 現在履歴位置が一致する場合は戻って来れる様に記録する。
  if
    if [[ :$opts: == *:substr:* ]]; then
      [[ $_ble_edit_str == *"$_ble_edit_nsearch_needle"* ]]
    else
      [[ $_ble_edit_str == "$_ble_edit_nsearch_needle"* ]]
    fi
  then
    ble-edit/nsearch/.goto-match '' "$opts"
  fi

  # start search
  ble/util/fiberchain#initialize ble-edit/nsearch
  if [[ :$opts: == *:forward:* ]]; then
    ble/util/fiberchain#push forward
  else
    ble/util/fiberchain#push backward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/history-nsearch-backward {
  ble/widget/history-search "input:substr:backward:$1"
}
function ble/widget/history-nsearch-forward {
  ble/widget/history-search "input:substr:forward:$1"
}
function ble/widget/history-nsearch-backward-again {
  ble/widget/history-search "again:substr:backward:$1"
}
function ble/widget/history-nsearch-forward-again {
  ble/widget/history-search "again:substr:forward:$1"
}
function ble/widget/history-search-backward {
  ble/widget/history-search "backward:$1"
}
function ble/widget/history-search-forward {
  ble/widget/history-search "forward:$1"
}
function ble/widget/history-substring-search-backward {
  ble/widget/history-search "substr:backward:$1"
}
function ble/widget/history-substring-search-forward {
  ble/widget/history-search "substr:forward:$1"
}

function ble/widget/nsearch/forward {
  local ntask=${#_ble_util_fiberchain[@]}
  if ((ntask>=1)) && [[ ${_ble_util_fiberchain[ntask-1]%%:*} == backward ]]; then
    # 最後の逆方向の検索をキャンセル
    local ret; ble/array#pop _ble_util_fiberchain
  else
    ble/util/fiberchain#push forward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/nsearch/backward {
  local ntask=${#_ble_util_fiberchain[@]}
  if ((ntask>=1)) && [[ ${_ble_util_fiberchain[ntask-1]%%:*} == forward ]]; then
    # 最後の逆方向の検索をキャンセル
    local ret; ble/array#pop _ble_util_fiberchain
  else
    ble/util/fiberchain#push backward
  fi
  ble/util/fiberchain#resume
}
function ble/widget/nsearch/.exit {
  ble/decode/keymap/pop
  _ble_edit_mark_active=
  ble-edit/nsearch/erase-status
}
function ble/widget/nsearch/exit {
  if [[ :$_ble_edit_nsearch_opts: == *:immediate-accept:* ]]; then
    ble/widget/nsearch/accept-line
  else
    ble/widget/nsearch/.exit
  fi
}
function ble/widget/nsearch/exit-default {
  ble/widget/nsearch/.exit
  ble/decode/widget/skip-lastwidget
  ble/decode/widget/redispatch-by-keys "${KEYS[@]}"
}
function ble/widget/nsearch/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-edit/nsearch/show-status
  else
    ble/widget/nsearch/.exit
    local record=${_ble_edit_nsearch_stack[0]}
    if [[ $record ]]; then
      local line=${record#*:}
      ble/string#split record , "${record%%:*}"
      if [[ :$_ble_edit_nsearch_opts: == *:action=load:* ]]; then
        ble-edit/content/reset-and-check-dirty "$line"
      else
        ble-edit/history/goto "$_ble_edit_nsearch_index0"
      fi
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
    fi
  fi
}
function ble/widget/nsearch/accept-line {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/widget/.bell "nsearch: now searching..."
  else
    ble/widget/nsearch/.exit
    ble-decode-key 13 # RET
  fi
}

function ble-decode/keymap:nsearch/define {
  ble-bind -f __default__ nsearch/exit-default
  ble-bind -f __line_limit__ nop

  ble-bind -f 'C-g'       nsearch/cancel
  ble-bind -f 'C-x C-g'   nsearch/cancel
  ble-bind -f 'C-M-g'     nsearch/cancel
  ble-bind -f C-m         nsearch/exit
  ble-bind -f RET         nsearch/exit
  ble-bind -f C-j         nsearch/accept-line
  ble-bind -f C-RET       nsearch/accept-line

  ble-bind -f C-r         nsearch/backward
  ble-bind -f C-s         nsearch/forward
  ble-bind -f C-p         nsearch/backward
  ble-bind -f C-n         nsearch/forward
  ble-bind -f up          nsearch/backward
  ble-bind -f down        nsearch/forward
}

# 
#------------------------------------------------------------------------------
# **** common bindings ****                                          @edit.safe

function ble-decode/keymap:safe/.bind {
  [[ $ble_bind_nometa && $1 == *M-* ]] && return 0
  ble-bind -f "$1" "$2"
}
function ble-decode/keymap:safe/bind-common {
  ble-decode/keymap:safe/.bind insert      'overwrite-mode'

  # ins
  ble-decode/keymap:safe/.bind __batch_char__ 'batch-insert'
  ble-decode/keymap:safe/.bind __defchar__ 'self-insert'
  ble-decode/keymap:safe/.bind 'C-q'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'C-v'       'quoted-insert'
  ble-decode/keymap:safe/.bind 'M-C-m'     'newline'
  ble-decode/keymap:safe/.bind 'M-RET'     'newline'
  ble-decode/keymap:safe/.bind paste_begin 'bracketed-paste'

  # kill
  ble-decode/keymap:safe/.bind 'C-@'       'set-mark'
  ble-decode/keymap:safe/.bind 'C-SP'      'set-mark'
  ble-decode/keymap:safe/.bind 'NUL'       'set-mark'
  ble-decode/keymap:safe/.bind 'M-SP'      'set-mark'
  ble-decode/keymap:safe/.bind 'C-x C-x'   'exchange-point-and-mark'
  ble-decode/keymap:safe/.bind 'C-w'       'kill-region-or kill-backward-uword'
  ble-decode/keymap:safe/.bind 'M-w'       'copy-region-or copy-backward-uword'
  ble-decode/keymap:safe/.bind 'C-y'       'yank'
  ble-decode/keymap:safe/.bind 'M-y'       'yank-pop'
  ble-decode/keymap:safe/.bind 'M-S-y'     'yank-pop backward'
  ble-decode/keymap:safe/.bind 'M-Y'       'yank-pop backward'

  # spaces
  ble-decode/keymap:safe/.bind 'M-\'       'delete-horizontal-space'

  # charwise operations
  ble-decode/keymap:safe/.bind 'C-f'       '@nomarked forward-char'
  ble-decode/keymap:safe/.bind 'C-b'       '@nomarked backward-char'
  ble-decode/keymap:safe/.bind 'right'     '@nomarked forward-char'
  ble-decode/keymap:safe/.bind 'left'      '@nomarked backward-char'
  ble-decode/keymap:safe/.bind 'S-C-f'     '@marked forward-char'
  ble-decode/keymap:safe/.bind 'S-C-b'     '@marked backward-char'
  ble-decode/keymap:safe/.bind 'S-right'   '@marked forward-char'
  ble-decode/keymap:safe/.bind 'S-left'    '@marked backward-char'
  ble-decode/keymap:safe/.bind 'C-d'       'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'delete'    'delete-region-or delete-forward-char'
  ble-decode/keymap:safe/.bind 'C-?'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'DEL'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'C-h'       'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'BS'        'delete-region-or delete-backward-char'
  ble-decode/keymap:safe/.bind 'C-t'       'transpose-chars'

  # wordwise operations
  ble-decode/keymap:safe/.bind 'C-right'   '@nomarked forward-cword'
  ble-decode/keymap:safe/.bind 'C-left'    '@nomarked backward-cword'
  ble-decode/keymap:safe/.bind 'M-right'   '@nomarked forward-sword'
  ble-decode/keymap:safe/.bind 'M-left'    '@nomarked backward-sword'
  ble-decode/keymap:safe/.bind 'S-C-right' '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'S-C-left'  '@marked backward-cword'
  ble-decode/keymap:safe/.bind 'M-S-right' '@marked forward-sword'
  ble-decode/keymap:safe/.bind 'M-S-left'  '@marked backward-sword'
  ble-decode/keymap:safe/.bind 'M-d'       'kill-forward-cword'
  ble-decode/keymap:safe/.bind 'M-h'       'kill-backward-cword'
  ble-decode/keymap:safe/.bind 'C-delete'  'delete-forward-cword'
  ble-decode/keymap:safe/.bind 'C-_'       'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'C-DEL'     'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'C-BS'      'delete-backward-cword'
  ble-decode/keymap:safe/.bind 'M-delete'  'copy-forward-sword'
  ble-decode/keymap:safe/.bind 'M-C-?'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-DEL'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-C-h'     'copy-backward-sword'
  ble-decode/keymap:safe/.bind 'M-BS'      'copy-backward-sword'

  ble-decode/keymap:safe/.bind 'M-f'       '@nomarked forward-cword'
  ble-decode/keymap:safe/.bind 'M-b'       '@nomarked backward-cword'
  ble-decode/keymap:safe/.bind 'M-F'       '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'M-B'       '@marked backward-cword'
  ble-decode/keymap:safe/.bind 'M-S-f'     '@marked forward-cword'
  ble-decode/keymap:safe/.bind 'M-S-b'     '@marked backward-cword'

  ble-decode/keymap:safe/.bind 'M-c'       'capitalize-eword'
  ble-decode/keymap:safe/.bind 'M-l'       'downcase-eword'
  ble-decode/keymap:safe/.bind 'M-u'       'upcase-eword'
  ble-decode/keymap:safe/.bind 'M-t'       'transpose-ewords'

  # linewise operations
  ble-decode/keymap:safe/.bind 'C-a'       '@nomarked beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-e'       '@nomarked end-of-line'
  ble-decode/keymap:safe/.bind 'home'      '@nomarked beginning-of-line'
  ble-decode/keymap:safe/.bind 'end'       '@nomarked end-of-line'
  ble-decode/keymap:safe/.bind 'S-C-a'     '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'S-C-e'     '@marked end-of-line'
  ble-decode/keymap:safe/.bind 'S-home'    '@marked beginning-of-line'
  ble-decode/keymap:safe/.bind 'S-end'     '@marked end-of-line'
  ble-decode/keymap:safe/.bind 'M-m'       '@nomarked non-space-beginning-of-line'
  ble-decode/keymap:safe/.bind 'M-S-m'     '@marked non-space-beginning-of-line'
  ble-decode/keymap:safe/.bind 'M-M'       '@marked non-space-beginning-of-line'
  ble-decode/keymap:safe/.bind 'C-p'       '@nomarked backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'up'        '@nomarked backward-line' # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-n'       '@nomarked forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'down'      '@nomarked forward-line'  # overwritten by bind-history
  ble-decode/keymap:safe/.bind 'C-k'       'kill-forward-line'
  ble-decode/keymap:safe/.bind 'C-u'       'kill-backward-line'

  ble-decode/keymap:safe/.bind 'S-C-p'     '@marked backward-line'
  ble-decode/keymap:safe/.bind 'S-up'      '@marked backward-line'
  ble-decode/keymap:safe/.bind 'S-C-n'     '@marked forward-line'
  ble-decode/keymap:safe/.bind 'S-down'    '@marked forward-line'

  ble-decode/keymap:safe/.bind 'C-home'    '@nomarked beginning-of-text'
  ble-decode/keymap:safe/.bind 'C-end'     '@nomarked end-of-text'
  ble-decode/keymap:safe/.bind 'S-C-home'  '@marked beginning-of-text'
  ble-decode/keymap:safe/.bind 'S-C-end'   '@marked end-of-text'

  # macros
  ble-decode/keymap:safe/.bind 'C-x ('     'start-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x )'     'end-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x e'     'call-keyboard-macro'
  ble-decode/keymap:safe/.bind 'C-x P'     'print-keyboard-macro'

  # Note: vi では C-] は sabbrev-expand で上書きされる
  ble-decode/keymap:safe/.bind 'C-]'       'character-search-forward'
  ble-decode/keymap:safe/.bind 'M-C-]'     'character-search-backward'
}
function ble-decode/keymap:safe/bind-history {
  ble-decode/keymap:safe/.bind 'C-r'       'history-isearch-backward'
  ble-decode/keymap:safe/.bind 'C-s'       'history-isearch-forward'
  ble-decode/keymap:safe/.bind 'M-<'       'history-beginning'
  ble-decode/keymap:safe/.bind 'M->'       'history-end'
  ble-decode/keymap:safe/.bind 'C-prior'   'history-beginning'
  ble-decode/keymap:safe/.bind 'C-next'    'history-end'
  ble-decode/keymap:safe/.bind 'C-p'       '@nomarked backward-line history'
  ble-decode/keymap:safe/.bind 'up'        '@nomarked backward-line history'
  ble-decode/keymap:safe/.bind 'C-n'       '@nomarked forward-line history'
  ble-decode/keymap:safe/.bind 'down'      '@nomarked forward-line history'
  ble-decode/keymap:safe/.bind 'C-x C-p'   'history-search-backward'
  ble-decode/keymap:safe/.bind 'C-x up'    'history-search-backward'
  ble-decode/keymap:safe/.bind 'C-x C-n'   'history-search-forward'
  ble-decode/keymap:safe/.bind 'C-x down'  'history-search-forward'
  ble-decode/keymap:safe/.bind 'C-x p'     'history-substring-search-backward'
  ble-decode/keymap:safe/.bind 'C-x n'     'history-substring-search-forward'
  ble-decode/keymap:safe/.bind 'C-x <'     'history-nsearch-backward'
  ble-decode/keymap:safe/.bind 'C-x >'     'history-nsearch-forward'
  ble-decode/keymap:safe/.bind 'C-x ,'     'history-nsearch-backward-again'
  ble-decode/keymap:safe/.bind 'C-x .'     'history-nsearch-forward-again'

  ble-decode/keymap:safe/.bind 'M-.'       'insert-last-argument'
  ble-decode/keymap:safe/.bind 'M-_'       'insert-last-argument'
  ble-decode/keymap:safe/.bind 'M-C-y'     'insert-nth-argument'
}
function ble-decode/keymap:safe/bind-complete {
  ble-decode/keymap:safe/.bind 'C-i'       'complete'
  ble-decode/keymap:safe/.bind 'TAB'       'complete'
  ble-decode/keymap:safe/.bind 'M-?'       'complete show_menu'
  ble-decode/keymap:safe/.bind 'M-*'       'complete insert_all'
  ble-decode/keymap:safe/.bind 'M-{'       'complete insert_braces'
  ble-decode/keymap:safe/.bind 'C-TAB'     'menu-complete'
  ble-decode/keymap:safe/.bind 'S-C-i'     'menu-complete backward'
  ble-decode/keymap:safe/.bind 'S-TAB'     'menu-complete backward'
  ble-decode/keymap:safe/.bind 'auto_complete_enter' 'auto-complete-enter'

  ble-decode/keymap:safe/.bind 'M-/'       'complete context=filename'
  ble-decode/keymap:safe/.bind 'M-~'       'complete context=username'
  ble-decode/keymap:safe/.bind 'M-$'       'complete context=variable'
  ble-decode/keymap:safe/.bind 'M-@'       'complete context=hostname'
  ble-decode/keymap:safe/.bind 'M-!'       'complete context=command'
  ble-decode/keymap:safe/.bind 'C-x /'     'complete show_menu:context=filename'
  ble-decode/keymap:safe/.bind 'C-x ~'     'complete show_menu:context=username'
  ble-decode/keymap:safe/.bind 'C-x $'     'complete show_menu:context=variable'
  ble-decode/keymap:safe/.bind 'C-x @'     'complete show_menu:context=hostname'
  ble-decode/keymap:safe/.bind 'C-x !'     'complete show_menu:context=command'

  ble-decode/keymap:safe/.bind "M-'"       'sabbrev-expand'
  ble-decode/keymap:safe/.bind "C-x '"     'sabbrev-expand'
  ble-decode/keymap:safe/.bind 'C-x C-r'   'dabbrev-expand'

  ble-decode/keymap:safe/.bind 'M-g'       'complete context=glob'
  ble-decode/keymap:safe/.bind 'C-x *'     'complete insert_all:context=glob'
  ble-decode/keymap:safe/.bind 'C-x g'     'complete show_menu:context=glob'

  ble-decode/keymap:safe/.bind 'M-C-i'     'complete context=dynamic-history'
  ble-decode/keymap:safe/.bind 'M-TAB'     'complete context=dynamic-history'
}
function ble-decode/keymap:safe/bind-arg {
  local append_arg=append-arg${1:+'-or '}$1

  ble-decode/keymap:safe/.bind M-C-u 'universal-arg'

  ble-decode/keymap:safe/.bind M-- "$append_arg"
  ble-decode/keymap:safe/.bind M-0 "$append_arg"
  ble-decode/keymap:safe/.bind M-1 "$append_arg"
  ble-decode/keymap:safe/.bind M-2 "$append_arg"
  ble-decode/keymap:safe/.bind M-3 "$append_arg"
  ble-decode/keymap:safe/.bind M-4 "$append_arg"
  ble-decode/keymap:safe/.bind M-5 "$append_arg"
  ble-decode/keymap:safe/.bind M-6 "$append_arg"
  ble-decode/keymap:safe/.bind M-7 "$append_arg"
  ble-decode/keymap:safe/.bind M-8 "$append_arg"
  ble-decode/keymap:safe/.bind M-9 "$append_arg"

  ble-decode/keymap:safe/.bind C-- "$append_arg"
  ble-decode/keymap:safe/.bind C-0 "$append_arg"
  ble-decode/keymap:safe/.bind C-1 "$append_arg"
  ble-decode/keymap:safe/.bind C-2 "$append_arg"
  ble-decode/keymap:safe/.bind C-3 "$append_arg"
  ble-decode/keymap:safe/.bind C-4 "$append_arg"
  ble-decode/keymap:safe/.bind C-5 "$append_arg"
  ble-decode/keymap:safe/.bind C-6 "$append_arg"
  ble-decode/keymap:safe/.bind C-7 "$append_arg"
  ble-decode/keymap:safe/.bind C-8 "$append_arg"
  ble-decode/keymap:safe/.bind C-9 "$append_arg"

  ble-decode/keymap:safe/.bind -   "$append_arg"
  ble-decode/keymap:safe/.bind 0   "$append_arg"
  ble-decode/keymap:safe/.bind 1   "$append_arg"
  ble-decode/keymap:safe/.bind 2   "$append_arg"
  ble-decode/keymap:safe/.bind 3   "$append_arg"
  ble-decode/keymap:safe/.bind 4   "$append_arg"
  ble-decode/keymap:safe/.bind 5   "$append_arg"
  ble-decode/keymap:safe/.bind 6   "$append_arg"
  ble-decode/keymap:safe/.bind 7   "$append_arg"
  ble-decode/keymap:safe/.bind 8   "$append_arg"
  ble-decode/keymap:safe/.bind 9   "$append_arg"
}

function ble/widget/safe/__attach__ {
  ble/edit/info/set-default text ''
}
function ble-decode/keymap:safe/define {
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete

  ble-bind -f 'C-d'      'delete-region-or delete-forward-char-or-exit'

  ble-bind -f 'SP'       magic-space
  ble-bind -f 'M-^'      history-expand-line

  ble-bind -f __attach__     safe/__attach__
  ble-bind -f __line_limit__ __line_limit__

  ble-bind -f 'C-c'      discard-line
  ble-bind -f 'C-j'      accept-line
  ble-bind -f 'C-RET'    accept-line
  ble-bind -f 'C-m'      accept-single-line-or-newline
  ble-bind -f 'RET'      accept-single-line-or-newline
  ble-bind -f 'C-o'      accept-and-next
  ble-bind -f 'C-x C-e'  edit-and-execute-command
  ble-bind -f 'M-#'      insert-comment
  ble-bind -f 'M-C-e'    shell-expand-line
  ble-bind -f 'M-&'      tilde-expand
  ble-bind -f 'C-g'      bell
  ble-bind -f 'C-x C-g'  bell
  ble-bind -f 'C-M-g'    bell

  ble-bind -f 'C-l'      clear-screen
  ble-bind -f 'C-M-l'    redraw-line

  ble-bind -f 'f1'       command-help
  ble-bind -f 'C-x C-v'  display-shell-version
  ble-bind -c 'C-z'      fg
  ble-bind -c 'M-z'      fg
}

function ble-edit/bind/load-editing-mode:safe {
  ble/decode/keymap#load safe
}

ble/util/autoload "keymap/emacs.sh" \
                  ble-decode/keymap:emacs/define
ble/util/autoload "keymap/vi.sh" \
                  ble-decode/keymap:vi_{i,n,o,x,s,c}map/define
ble/util/autoload "keymap/vi_digraph.sh" \
                  ble-decode/keymap:vi_digraph/define

function ble/widget/.change-editing-mode {
  [[ $_ble_decode_bind_state == none ]] && return 0
  local mode=$1
  if [[ $bleopt_default_keymap == auto ]]; then
    if [[ ! -o $mode ]]; then
      set -o "$mode"
      ble/decode/reset-default-keymap
      ble/decode/detach
      ble/decode/attach || ble-detach
    fi
  else
    bleopt default_keymap="$mode"
  fi
}
function ble/widget/emacs-editing-mode {
  ble/widget/.change-editing-mode emacs
}
function ble/widget/vi-editing-mode {
  ble/widget/.change-editing-mode vi
}

# 
#------------------------------------------------------------------------------
# **** ble/builtin/read ****                                         @edit.read

_ble_edit_read_accept=
_ble_edit_read_result=
function ble/widget/read/accept {
  _ble_edit_read_accept=1
  _ble_edit_read_result=$_ble_edit_str
  # [[ $_ble_edit_read_result ]] &&
  #   ble/history/add "$_ble_edit_read_result" # Note: cancel でも登録する
  ble/decode/keymap/pop
}
function ble/widget/read/cancel {
  local _ble_edit_line_disabled=1
  ble/widget/read/accept
  _ble_edit_read_accept=2
}
function ble/widget/read/delete-forward-char-or-cancel {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
  else
    ble/widget/read/cancel
  fi
}

function ble/widget/read/__line_limit__.edit {
  local content=$1
  ble/widget/edit-and-execute-command.edit "$content" no-newline; local ext=$?
  ((ext==127)) && return "$ext"
  ble-edit/content/reset "$ret"
  ble/widget/read/accept
}
function ble/widget/read/__line_limit__ {
  ble/widget/__line_limit__ read/__line_limit__.edit
}

function ble-decode/keymap:read/define {
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  # ble-decode/keymap:safe/bind-complete

  ble-bind -f __line_limit__ read/__line_limit__

  ble-bind -f 'C-c' read/cancel
  ble-bind -f 'C-\' read/cancel
  ble-bind -f 'C-m' read/accept
  ble-bind -f 'RET' read/accept
  ble-bind -f 'C-j' read/accept
  ble-bind -f 'C-d' 'delete-region-or read/delete-forward-char-or-cancel'

  # shell functions
  ble-bind -f  'C-g'     bell
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'C-M-l'   redraw-line
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'M-^'      history-expand-line
  # ble-bind -f 'SP'       magic-space

  # ble-bind -f 'C-[' bell # unbound for "bleopt decode_isolated_esc=auto"
  ble-bind -f 'C-^' bell
}

_ble_edit_read_history=()
_ble_edit_read_history_edit=()
_ble_edit_read_history_dirt=()
_ble_edit_read_history_index=0

function ble/builtin/read/.process-option {
  case $1 in
  (-e) opt_flags=${opt_flags}r ;;
  (-i) opt_default=$2 ;;
  (-p) opt_prompt=$2 ;;
  (-u) opt_fd=$2
       ble/array#push opts_in "$@" ;;
  (-t) opt_timeout=$2 ;;
  (*)  ble/array#push opts "$@" ;;
  esac
}
function ble/builtin/read/.read-arguments {
  local is_normal_args=
  vars=()
  opts=()
  while (($#)); do
    local arg=$1; shift
    if [[ $is_normal_args || $arg != -* ]]; then
      ble/array#push vars "$arg"
    elif [[ $arg == -- ]]; then
      is_normal_args=1
    elif [[ $arg == --* ]]; then
      case $arg in
      (--help)
        opt_flags=${opt_flags}H ;;
      (*)
        ble/util/print "read: unrecognized long option '$arg'" >&2
        opt_flags=${opt_flags}E ;;
      esac
    else
      local i n=${#arg} c
      for ((i=1;i<n;i++)); do
        c=${arg:i:1}
        case ${arg:i} in
        ([adinNptu])
          if (($#)); then
            ble/builtin/read/.process-option -$c "$1"; shift
          else
            ble/util/print "read: missing option argument for '-$c'" >&2
            opt_flags=${opt_flags}E
          fi
          break ;;
        ([adinNptu]*) ble/builtin/read/.process-option -$c "${arg:i+1}"; break ;;
        ([ers]*)      ble/builtin/read/.process-option -$c ;;
        (*)
          ble/util/print "read: unrecognized option '-$c'" >&2
          opt_flags=${opt_flags}E ;;
        esac
      done
    fi
  done
}

function ble/builtin/read/.set-up-textarea {
  # 初期化
  ble/decode/keymap/push read || return 1

  [[ $_ble_edit_read_context == external ]] &&
    _ble_canvas_panel_height[0]=0

  # textarea, info
  _ble_textarea_panel=1
  _ble_canvas_panel_focus=1
  ble/textarea#invalidate
  ble/edit/info/set-default ansi ''

  # edit/prompt
  _ble_edit_PS1=$opt_prompt
  _ble_prompt_ps1_data=(0 '' '' 0 0 0 32 0 "" "")

  # edit
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=
  ble-edit/content/reset "$opt_default" newline
  _ble_edit_ind=${#opt_default}

  # edit/undo
  ble-edit/undo/clear-all

  # edit/history
  ble/history/set-prefix _ble_edit_read_

  # syntax, highlight
  _ble_syntax_lang=text
  _ble_highlight_layer__list=(plain region overwrite_mode disabled)
  return 0
}
function ble/builtin/read/TRAPWINCH {
  local IFS=$_ble_term_IFS
  _ble_textmap_pos=()
  ble/util/buffer "$_ble_term_ed"
  ble/textarea#redraw
}
function ble/builtin/read/.loop {
  # この関数はサブシェルの中で実行される事を前提としている。

  set +m # ジョブ管理を無効にする

  # Note: サブシェルの中では eval で failglob を防御できない様だ。
  #   それが理由で visible-bell を呼び出すと read が終了してしまう。
  #   対策として failglob を外す。サブシェルの中なので影響はない筈。
  # ref #D1090
  shopt -u failglob

  local ret; ble/canvas/panel/save-position; local pos0=$ret
  ble/builtin/read/.set-up-textarea || return 1
  ble/builtin/trap/install-hook WINCH readline
  blehook WINCH=ble/builtin/read/TRAPWINCH

  local ret= timeout=
  if [[ $opt_timeout ]]; then
    ble/util/clock; local start_time=$ret

    # Note: 時間分解能が低いとき、実際は 1999ms なのに
    #   1000ms に切り捨てられている可能性もある。
    #   待ち時間が長くなる方向に倒して処理する。
    ((start_time&&(start_time-=_ble_util_clock_reso-1)))

    if [[ $opt_timeout == *.* ]]; then
      local mantissa=${opt_timeout%%.*}
      local fraction=${opt_timeout##*.}000
      ((timeout=mantissa*1000+10#${fraction::3}))
    else
      ((timeout=opt_timeout*1000))
    fi
    ((timeout<0)) && timeout=
  fi

  ble/application/render

  # Note: ble-decode-key が中断しない為の設定 #D0998
  #   ble/encoding:.../is-intermediate の状態にはないと仮定して、
  #   それによって ble-decode-key が中断する事はないと考える。
  local _ble_decode_input_count=0
  local ble_decode_char_nest=
  local -a _ble_decode_char_buffer=()

  local char=
  local _ble_edit_read_accept=
  local _ble_edit_read_result=
  while [[ ! $_ble_edit_read_accept ]]; do
    local timeout_option=
    if [[ $timeout ]]; then
      if ((_ble_bash>=40000)); then
        local timeout_frac=000$((timeout%1000))
        timeout_option="-t $((timeout/1000)).${timeout_frac:${#timeout_frac}-3}"
      else
        timeout_option="-t $((timeout/1000))"
      fi
    fi

    # read 1 character
    local TMOUT= 2>/dev/null # #D1630 WA readonly TMOUT
    IFS= builtin read "${_ble_bash_tmout_wa[@]}" -r -d '' -n 1 $timeout_option char "${opts_in[@]}"; local ext=$?
    if ((ext>128)); then
      # timeout
      #   Note: #D1467 Cygwin/Linux では read の timeout は 142 だが、これはシステム依存。
      #   man bash にある様に 128 より大きいかどうかで判定する。
      _ble_edit_read_accept=142
      break
    fi

    # update timeout
    if [[ $timeout ]]; then
      ble/util/clock; local current_time=$ret
      ((timeout-=current_time-start_time))
      if ((timeout<=0)); then
        # timeout
        _ble_edit_read_accept=142
        break
      fi
      start_time=$current_time
    fi

    # process
    ble/util/s2c "$char"
    ble-decode-char "$ret"
    [[ $_ble_edit_read_accept ]] && break

    # render
    ble/util/is-stdin-ready && continue
    ble-edit/content/check-limit
    ble-decode/.hook/erase-progress
    ble/application/render
  done

  # 入力が終わったら消すか次の行へ行く
  if [[ $_ble_edit_read_context == internal ]]; then
    local -a DRAW_BUFF=()
    ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
    ble/canvas/panel/load-position.draw "$pos0"
    ble/canvas/bflush.draw
  else
    if ((_ble_edit_read_accept==1)); then
      ble/widget/.insert-newline
    else
      _ble_edit_line_disabled=1 ble/widget/.insert-newline
    fi
  fi

  ble/util/buffer.flush >&2
  if ((_ble_edit_read_accept==1)); then
    local q=\' Q="'\''"
    printf %s "__ble_input='${_ble_edit_read_result//$q/$Q}'"
  elif ((_ble_edit_read_accept==142)); then
    # timeout
    return "$ext"
  else
    return 1
  fi
}

function ble/builtin/read/.impl {
  local -a opts=() vars=() opts_in=()
  # opt_flags ... E: error, H: help (--help), r: readline (-e)
  local opt_flags= opt_prompt= opt_default= opt_timeout= opt_fd=0

  # シェル変数 TMOUT
  local rex1='^[0-9]+(\.[0-9]*)?$|^\.[0-9]+$' rex2='^[0.]+$'
  [[ $TMOUT =~ $rex1 && ! ( $TMOUT =~ $rex2 ) ]] && opt_timeout=$TMOUT

  ble/builtin/read/.read-arguments "$@"
  if [[ $opt_flags == *[HE]* ]]; then
    [[ $opt_flags == *H* ]] &&
      builtin read --help
    return 2
  fi

  if ! [[ $opt_flags == *r* && -t $opt_fd ]]; then
    # "-e オプションが指定されてかつ端末からの読み取り" のとき以外は builtin read する。
    [[ $opt_prompt ]] && ble/array#push opts -p "$opt_prompt"
    [[ $opt_timeout ]] && ble/array#push opts -t "$opt_timeout"
    __ble_args=("${opts[@]}" "${opts_in[@]}" -- "${vars[@]}")
    __ble_command='builtin read "${__ble_args[@]}"'
    return 0
  fi

  ble/decode/keymap#load read
  local result _ble_edit_read_context=$_ble_term_state

  # Note: サブシェル中で重複して出力されない様に空にしておく
  ble/util/buffer.flush >&2

  [[ $_ble_edit_read_context == external ]] && ble/term/enter # 外側にいたら入る
  result=$(ble/builtin/read/.loop); local ext=$?
  [[ $_ble_edit_read_context == external ]] && ble/term/leave # 元の状態に戻る

  # Note: サブシェルを抜ける時に set-height 1 0 するので辻褄合わせ。
  [[ $_ble_edit_read_context == internal ]] && ((_ble_canvas_panel_height[1]=0))

  if ((ext==0)); then
    builtin eval -- "$result"
    __ble_args=("${opts[@]}" -- "${vars[@]}")
    __ble_command='builtin read "${__ble_args[@]}" <<< "$__ble_input"'
  fi
  return "$ext"
}

## @fn read [-ers] [-adinNptu arg] [name...]
##
##   ble.sh の所為で builtin read -e が全く動かなくなるので、
##   read -e を ble.sh の枠組みで再実装する。
##
function ble/builtin/read {
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin read "$@"
    return "$?"
  fi

  # used by core-complete to cancel progcomp
  [[ $_ble_builtin_read_hook ]] &&
    builtin eval -- "$_ble_builtin_read_hook"

  local __ble_command= __ble_args= __ble_input=
  ble/builtin/read/.impl "$@"; local __ble_ext=$?
  [[ $__ble_command ]] || return "$__ble_ext"

  # 局所変数により被覆されないように外側で評価
  builtin eval -- "$__ble_command"
}
function read { ble/builtin/read "$@"; }

#------------------------------------------------------------------------------
# **** command-help ****                                          @command-help

## @fn[custom] ble/cmdinfo/help
## @fn[custom] ble/cmdinfo/help:$command
##
##   ヘルプを表示するシェル関数を定義します。
##   ble/widget/command-help から呼び出されます。
##   ble/cmdinfo/help:$command はコマンド $command に対するヘルプ表示で使われます。
##   ble/cmdinfo/help はその他のコマンドに対するヘルプ表示で使われます。
##
##   @var[in] command
##   @var[in] type
##     コマンド名と種類 (type -t によって得られるもの) を指定します。
##
##   @var[in] comp_line comp_point comp_words comp_cword
##     現在のコマンドラインと位置、コマンド名・引数と現在の引数番号を指定します。
##
##   @exit[out]
##     ヘルプの終了が完了したときに 0 を返します。
##     それ以外の時は 0 以外を返します。
##

## @fn ble/widget/command-help/.read-man
##   @var[out] man_content
function ble/widget/command-help/.read-man {
  local pager="sh -c 'cat >| \"\$BLETMPFILE\"'" tmp=$_ble_util_assign_base
  BLETMPFILE=$tmp MANPAGER=$pager PAGER=$pager MANOPT= man "$@" 2>/dev/null; local ext=$? # 668ms
  ble/util/readfile man_content "$tmp" # 80ms
  return "$ext"
}

function ble/widget/command-help/.locate-in-man-bash {
  local command=$1
  local ret rex
  local rex_esc=$'(\e\\[[ -?]*[@-~]||.\b)' cr=$'\r'

  # check if pager is less
  local pager; ble/util/get-pager pager
  local pager_cmd=${pager%%["$_ble_term_IFS"]*}
  [[ ${pager_cmd##*/} == less ]] || return 1

  # awk/gawk
  local awk=ble/bin/awk; type -t gawk &>/dev/null && awk=gawk

  # man bash
  local man_content; ble/widget/command-help/.read-man bash || return 1 # 733ms (3 fork: man, sh, cat)

  # locate line number
  local cmd_awk
  case $command in
  ('function')  cmd_awk='name () compound-command' ;;
  ('until')     cmd_awk=while ;;
  ('command')   cmd_awk='command [' ;;
  ('source')    cmd_awk=. ;;
  ('typeset')   cmd_awk=declare ;;
  ('readarray') cmd_awk=mapfile ;;
  ('[')         cmd_awk=test ;;
  (*)           cmd_awk=$command ;;
  esac
  ble/string#escape-for-awk-regex "$cmd_awk"; local rex_awk=$ret
  rex='\b$'; [[ $awk == gawk && $cmd_awk =~ $rex ]] && rex_awk=$rex_awk'\y'
  local awk_script='{
    gsub(/'"$rex_esc"'/, "");
    if (!par && $0 ~ /^[[:space:]]*'"$rex_awk"'/) { print NR; exit; }
    par = !($0 ~ /^[[:space:]]*$/);
  }'
  local awk_out; ble/util/assign awk_out '"$awk" "$awk_script" 2>/dev/null <<< "$man_content"' || return 1 # 206ms (1 fork)
  local iline=${awk_out%$'\n'}; [[ $iline ]] || return 1

  # show
  ble/string#escape-for-extended-regex "$command"; local rex_ext=$ret
  rex='\b$'; [[ $command =~ $rex ]] && rex_ext=$rex_ext'\b'
  rex='^\b'; [[ $command =~ $rex ]] && rex_ext="($rex_esc|\b)$rex_ext"
  local manpager="$pager -r +'/$rex_ext$cr$((iline-1))g'"
  builtin eval -- "$manpager" <<< "$man_content" # 1 fork
}
## @fn ble/widget/command-help.core
##   @var[in] type
##   @var[in] command
##   @var[in] comp_cword comp_words comp_line comp_point
function ble/widget/command-help.core {
  ble/function#try ble/cmdinfo/help:"$command" && return 0
  ble/function#try ble/cmdinfo/help "$command" && return 0

  if [[ $type == builtin || $type == keyword ]]; then
    # 組み込みコマンド・キーワードは man bash を表示
    ble/widget/command-help/.locate-in-man-bash "$command" && return 0
  elif [[ $type == function ]]; then
    # シェル関数は定義を表示
    local pager=ble/util/pager
    type -t source-highlight &>/dev/null &&
      pager='source-highlight -s sh -f esc | '$pager
    local def; ble/function#getdef "$command"
    local -x LESS="$LESS -r" # Note: Bash のバグで tempenv builtin eval は消滅するので #D1438
    builtin eval -- "$pager" <<< "$def" && return 0
  fi

  if ble/is-function ble/bin/man; then
    MANOPT= ble/bin/man "${command##*/}" 2>/dev/null && return 0
    # Note: $(man "${command##*/}") だと (特に日本語で) 正しい結果が得られない。
    # if local content=$(MANOPT= ble/bin/man "${command##*/}" 2>&1) && [[ $content ]]; then
    #   ble/util/print "$content" | ble/util/pager
    #   return 0
    # fi
  fi

  if local content; content=$("$command" --help 2>&1) && [[ $content ]]; then
    ble/util/print "$content" | ble/util/pager
    return 0
  fi

  ble/util/print "ble: help of \`$command' not found" >&2
  return 1
}

## @fn ble/widget/command-help/type.resolve-alias
##   サブシェルで実行してエイリアスを解決する。
##   解決のために unalias を使用する為にサブシェルで実行する。
##
##   @stdout type:command
##     command はエイリアスを解決した後の最終的なコマンド
##     type はそのコマンドの種類
##     解決に失敗した時は何も出力しない。
##
function ble/widget/command-help/.type/.resolve-alias {
  local literal=$1 command=$2 type=alias
  local last_literal=$1 last_command=$2

  while
    [[ $command == "$literal" ]] || break # Note: type=alias

    local alias_def
    ble/util/assign alias_def "alias $command"
    builtin unalias "$command"
    builtin eval "alias_def=${alias_def#*=}" # remove quote
    literal=${alias_def%%["$_ble_term_IFS"]*} command= type=
    ble/syntax:bash/simple-word/is-simple "$literal" || break # Note: type=
    local ret; ble/syntax:bash/simple-word/eval "$literal"; command=$ret
    ble/util/type type "$command"
    [[ $type ]] || break # Note: type=

    last_literal=$literal
    last_command=$command
    [[ $type == alias ]]
  do :; done

  if [[ ! $type || $type == alias ]]; then
    # - command はエイリアスに一致するが literal では quote されている時、
    #   type=alias の状態でループを抜ける。
    # - 途中で複雑なコマンドに展開された時、必ずしも先頭の単語がコマンド名ではない。
    #   例: alias which='(alias; declare -f) | /usr/bin/which ...'
    #   この時途中で type= になってループを抜ける。
    #
    # これらの時、直前の成功した command 名で非エイリアス名を探す。
    literal=$last_literal
    command=$last_command
    builtin unalias "$command" &>/dev/null
    ble/util/type type "$command"
  fi

  local q="'" Q="'\''"
  printf "type='%s'\n" "${type//$q/$Q}"
  printf "literal='%s'\n" "${literal//$q/$Q}"
  printf "command='%s'\n" "${command//$q/$Q}"
  return 0
} 2>/dev/null

## @fn ble/widget/command-help/.type
##   @var[out] type command
function ble/widget/command-help/.type {
  local literal=$1
  type= command=
  ble/syntax:bash/simple-word/is-simple "$literal" || return 1
  local ret; ble/syntax:bash/simple-word/eval "$literal"; command=$ret
  ble/util/type type "$command"

  # alias の時はサブシェルで解決
  if [[ $type == alias ]]; then
    builtin eval -- "$(ble/widget/command-help/.type/.resolve-alias "$literal" "$command")"
  fi

  if [[ $type == keyword && $command != "$literal" ]]; then
    if [[ $command == %* ]] && jobs -- "$command" &>/dev/null; then
      type=jobs
    else
      # type -a の第二候補を用いる #D1406
      type=${type[1]}
      [[ $type ]] || return 1
    fi
  fi
}

function ble/widget/command-help.impl {
  local literal=$1
  if [[ ! $literal ]]; then
    ble/widget/.bell
    return 1
  fi

  local type command; ble/widget/command-help/.type "$literal"
  if [[ ! $type ]]; then
    ble/widget/.bell "command \`$command' not found"
    return 1
  fi

  ble/widget/external-command ble/widget/command-help.core
}

function ble/widget/command-help {
  # ToDo: syntax update?
  ble-edit/content/clear-arg
  local comp_cword comp_words comp_line comp_point
  if ble/syntax:bash/extract-command "$_ble_edit_ind"; then
    local cmd=${comp_words[0]}
  else
    local args; ble/string#split-words args "$_ble_edit_str"
    local cmd=${args[0]}
  fi

  ble/widget/command-help.impl "$cmd"
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/bind ****                                                 @bind

function ble-edit/bind/stdout.on { :;}
function ble-edit/bind/stdout.off { ble/util/buffer.flush >&2;}
function ble-edit/bind/stdout.finalize { :;}

if [[ $bleopt_internal_suppress_bash_output ]]; then
  _ble_edit_io_fname1=$_ble_base_run/$$.stdout
  _ble_edit_io_fname2=$_ble_base_run/$$.stderr

  function ble-edit/bind/stdout.on {
    exec 1>&$_ble_util_fd_stdout 2>&$_ble_util_fd_stderr
  }
  function ble-edit/bind/stdout.off {
    ble/util/buffer.flush >&2
    ble-edit/io/check-stderr
    exec 1>>$_ble_edit_io_fname1 2>>$_ble_edit_io_fname2
  }
  function ble-edit/bind/stdout.finalize {
    ble-edit/bind/stdout.on
    [[ -f $_ble_edit_io_fname1 ]] && : >| "$_ble_edit_io_fname1"
    [[ -f $_ble_edit_io_fname2 ]] && : >| "$_ble_edit_io_fname2"
  }

  ## @fn ble-edit/io/check-stderr
  ##   bash が stderr にエラーを出力したかチェックし表示する。
  function ble-edit/io/check-stderr {
    local file=${1:-$_ble_edit_io_fname2}

    # if the visible bell function is already defined.
    if ble/is-function ble/term/visible-bell; then
      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   /dev/null の様なデバイスではなく、中身があるファイルの場合。
      if [[ -f $file && -s $file ]]; then
        local message= line TMOUT= 2>/dev/null # #D1630 WA readonly TMOUT
        while IFS= builtin read "${_ble_bash_tmout_wa[@]}" -r line || [[ $line ]]; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   例えば ~/bin/bash-3.1 等から実行していると
          #   "bash-3.1: ～" 等というエラーメッセージになる。
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* || $line == "ble.sh ("*"): "* ]]; then
            message="$message${message:+; }$line"
          fi
        done < "$file"

        [[ $message ]] && ble/term/visible-bell "$message"
        : >| "$file"
      fi
    fi
  }

  # * bash-3.1, bash-3.2, bash-3.0 では C-d は直接検知できない。
  #   IGNOREEOF を設定しておくと C-d を押した時に
  #   stderr に bash が文句を吐くのでそれを捕まえて C-d が押されたと見做す。
  if ((_ble_bash<40000)); then
    function ble-edit/io/TRAPUSR1 {
      [[ $_ble_term_state == internal ]] || return 1

      local FUNCNEST=
      local IFS=$_ble_term_IFS
      local file=$_ble_edit_io_fname2.proc
      if [[ -s $file ]]; then
        local content cmd
        ble/util/readfile content "$file"
        : >| "$file"
        for cmd in $content; do
          case "$cmd" in
          (eof)
            # C-d
            ble-decode/.hook 4
            builtin eval -- "$_ble_decode_bind_hook" ;;
          esac
        done
      fi
      ble/builtin/trap/invoke USR1
    }
    blehook/declare USR1
    blehook USR1+=ble-edit/io/TRAPUSR1
    ble/builtin/trap/install-hook USR1

    function ble-edit/io/check-ignoreeof-message {
      local line=$1

      # 様々の Bash のバージョンで使われているメッセージと照合する。
      [[ ( $bleopt_internal_ignoreeof_trap && $line == *$bleopt_internal_ignoreeof_trap* ) ||
           $line == *'Use "exit" to leave the shell.'* ||
           $line == *'ログアウトする為には exit を入力して下さい'* ||
           $line == *'シェルから脱出するには "exit" を使用してください。'* ||
           $line == *'シェルから脱出するのに "exit" を使いなさい.'* ||
           $line == *'Gebruik Kaart na Los Tronk'* ]] && return 0

      # lib/core-edit.ignoreeof-messages.txt の中身をキャッシュする様にする?
      [[ $line == *exit* ]] && ble/bin/grep -q -F "$line" "$_ble_base"/lib/core-edit.ignoreeof-messages.txt
    }

    function ble-edit/io/check-ignoreeof-loop {
      local line opts=:$1: TMOUT= 2>/dev/null # #D1630 WA readonly TMOUT
      while IFS= builtin read "${_ble_bash_tmout_wa[@]}" -r line; do
        if [[ $line == *[^$_ble_term_IFS]* ]]; then
          ble/util/print "$line" >> "$_ble_edit_io_fname2"
        fi

        if ble-edit/io/check-ignoreeof-message "$line"; then
          ble/util/print eof >> "$_ble_edit_io_fname2.proc"
          kill -USR1 $$
          ble/util/msleep 100 # 連続で送ると bash が落ちるかも (落ちた事はないが念の為)
        fi
      done
    } &>/dev/null

    ble/bin/rm -f "$_ble_edit_io_fname2.pipe"
    if ble/bin/mkfifo "$_ble_edit_io_fname2.pipe" 2>/dev/null; then
      {
        ble-edit/io/check-ignoreeof-loop fifo < "$_ble_edit_io_fname2.pipe" & disown
      } &>/dev/null

      ble/fd#alloc _ble_edit_io_fd2 '> "$_ble_edit_io_fname2.pipe"'

      function ble-edit/bind/stdout.off {
        ble/util/buffer.flush >&2
        ble-edit/io/check-stderr
        exec 1>>$_ble_edit_io_fname1 2>&$_ble_edit_io_fd2
      }
    elif . "$_ble_base/lib/init-msys1.sh"; ble-edit/io:msys1/start-background; then
      function ble-edit/bind/stdout.off {
        ble/util/buffer.flush >&2
        ble-edit/io/check-stderr

        # Note: 一気に入力すると permission denied のエラーメッセージが出る。
        #   メッセージを抑制するには先に >/dev/null してから別の exec で繋がな
        #   ければならない。同じ exec でリダイレクトしようとするとメッセージ本
        #   体は表示されないが、エラーメッセージの改行だけは出力されてしなう。
        exec 1>>$_ble_edit_io_fname1 2>/dev/null
        exec 2>>$_ble_edit_io_fname2.buff
      }
    fi
  fi
fi

[[ ${_ble_edit_detach_flag-} != reload ]] &&
  _ble_edit_detach_flag=
function ble-edit/bind/.exit-TRAPRTMAX {
  # シグナルハンドラの中では stty は bash によって設定されている。
  local FUNCNEST=
  ble/base/unload
  builtin exit 0
}

## @fn ble-edit/bind/.check-detach
##
##   @exit detach した場合に 0 を返します。それ以外の場合に 1 を返します。
##
function ble-edit/bind/.check-detach {
  if [[ ! -o emacs && ! -o vi ]]; then
    # 実は set +o emacs などとした時点で eval の評価が中断されるので、これを検知することはできない。
    # 従って、現状ではここに入ってくることはないようである。
    ble/util/print "${_ble_term_setaf[9]}[ble: unsupported]$_ble_term_sgr0 Sorry, ble.sh is supported only with some editing mode (set -o emacs/vi)." 1>&2
    ble-detach
  fi

  # reload & prompt-attach の時は素通り (detach 後の処理は不要)
  [[ $_ble_edit_detach_flag == prompt-attach ]] && return 1

  if [[ $_ble_edit_detach_flag || ! $_ble_attached ]]; then
    type=$_ble_edit_detach_flag
    _ble_edit_detach_flag=
    #ble/term/visible-bell ' Bye!! '

    local attached=$_ble_attached
    [[ $attached ]] && ble-detach/impl

    if [[ $type == exit ]]; then
      # ※この部分は現在使われていない。
      #   exit 時の処理は trap EXIT を用いて行う事に決めた為。
      #   一応 _ble_edit_detach_flag=exit と直に入力する事で呼び出す事はできる。
      ble-detach/message "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0"

      # bind -x の中から exit すると bash が stty を「前回の状態」に復元してしまう様だ。
      # シグナルハンドラの中から exit すれば stty がそのままの状態で抜けられる様なのでそうする。
      builtin trap 'ble-edit/bind/.exit-TRAPRTMAX' RTMAX
      kill -RTMAX $$
    else
      ble-detach/message \
        "${_ble_term_setaf[12]}[ble: detached]$_ble_term_sgr0" \
        "Please run \`stty sane' to recover the correct TTY state."

      if ((_ble_bash>=40000)); then
        READLINE_LINE='stty sane;' READLINE_POINT=10 READLINE_MARK=0
        printf %s "$READLINE_LINE"
      fi
    fi

    if [[ $attached ]]; then
      # ここで ble-detach/impl した時は調整は最低限でOK
      ble/base/restore-bash-options
      ble/base/restore-POSIXLY_CORRECT
      ble/base/restore-builtin-wrappers
      builtin eval -- "$_ble_bash_FUNCNEST_restore" # これ以降関数は呼び出せない
    else
      # Note: 既に ble-detach/impl されていた時 (reload 時) は
      #   epilogue によって detach 後の状態が壊されているので
      #   改めて prologue を呼び出す必要がある。
      #   #D1130 #D1199 #D1223
      ble-edit/exec:"$bleopt_internal_exec_type"/.prologue
      _ble_edit_exec_inside_prologue=
    fi

    return 0
  else
    # Note: ここに入った時 -o emacs か -o vi のどちらかが成立する。なぜなら、
    #   [[ ! -o emacs && ! -o vi ]] のときは ble-detach が呼び出されるのでここには来ない。
    local state=$_ble_decode_bind_state
    if [[ ( $state == emacs || $state == vi ) && ! -o $state ]]; then
      ble/decode/reset-default-keymap
      ble/decode/detach
      if ! ble/decode/attach; then
        ble-detach
        ble-edit/bind/.check-detach # 改めて終了処理
        return $?
      fi
    fi

    return 1
  fi
}

if ((_ble_bash>=40100)); then
  function ble-edit/bind/.head/adjust-bash-rendering {
    # bash-4.1 以降では呼出直前にプロンプトが消される
    ble/textarea#redraw-cache
    ble/util/buffer.flush >&2
  }
else
  function ble-edit/bind/.head/adjust-bash-rendering {
    # bash-3.*, bash-4.0 では呼出直前に次の行に移動する
    ((_ble_canvas_y++,_ble_canvas_x=0))
    local -a DRAW_BUFF=()
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
    ble/canvas/flush.draw
  }
fi

function ble-edit/bind/.head {
  ble-edit/bind/stdout.on
  ble/base/recover-bash-options
  [[ $bleopt_internal_suppress_bash_output ]] ||
    ble-edit/bind/.head/adjust-bash-rendering
}

function ble-edit/bind/.tail-without-draw {
  ble-edit/bind/stdout.off
}

if ((_ble_bash>=40000)); then
  function ble-edit/bind/.tail {
    ble/application/render
    ble/util/idle.do && ble/application/render
    ble/textarea#adjust-for-bash-bind # bash-4.0+
    ble-edit/bind/stdout.off
  }
else
  function ble-edit/bind/.tail {
    ble/application/render
    ble/util/idle.do && ble/application/render
    # bash-3 では READLINE_LINE を設定する方法はないので常に 0 幅
    ble-edit/bind/stdout.off
  }
fi

## src/decode.sh 用の設定
function ble-decode/PROLOGUE {
  ble-edit/exec:gexec/restore-state
  ble-edit/bind/.head
  ble/decode/bind/adjust-uvw
  ble/term/enter
}

## src/decode.sh 用の設定
function ble-decode/EPILOGUE {
  if ((_ble_bash>=40000)); then
    # 貼付対策:
    #   大量の文字が入力された時に毎回再描画をすると滅茶苦茶遅い。
    #   次の文字が既に来て居る場合には描画処理をせずに抜ける。
    #   (再描画は次の文字に対する bind 呼出でされる筈。)
    #   現在は ble-decode/.hook の段階で連続入力を縮約しているので
    #   この関数はそんなに沢山呼び出される事はない。
    #   bash 4.0 以降でないとユーザー入力検出できない事に注意。
    if ble/decode/has-input && ! ble-edit/exec/has-pending-commands; then
      ble-edit/bind/.tail-without-draw
      return 0
    fi
  fi

  ble-edit/content/check-limit

  # コマンド実行が設定された時には _ble_decode_bind_hook の最後で bind/.tail
  # が実行される。
  ble-edit/exec:"$bleopt_internal_exec_type"/process && return 0

  ble-edit/bind/.tail
  return 0
}

function ble/widget/print {
  ble-edit/content/clear-arg
  local message="$*"
  [[ ${message//["$_ble_term_IFS"]} ]] || return 1

  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  ble/util/buffer.flush >&2
  ble/util/print-lines "$@" >&2
}
function ble/widget/internal-command {
  ble-edit/content/clear-arg
  local command=$1
  [[ ${command//[$_ble_term_IFS]} ]] || return 1

  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  BASH_COMMAND=$command builtin eval -- "$command"
}
function ble/widget/external-command {
  ble-edit/content/clear-arg
  local _ble_local_command=$1
  [[ ${_ble_local_command//[$_ble_term_IFS]} ]] || return 1

  ble/edit/enter-command-layout
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0 sgr0
  ble/canvas/bflush.draw
  ble/term/leave
  ble/util/buffer.flush >&2
  BASH_COMMAND=$_ble_local_command builtin eval -- "$_ble_local_command"; local ext=$?
  ble/term/enter
  return "$ext"
}
function ble/widget/execute-command {
  ble-edit/content/clear-arg
  local command=$1

  _ble_edit_line_disabled=1 ble/widget/.insert-newline

  # Note: 空コマンドでも .insert-newline は実行する。
  [[ ${command//[$_ble_term_IFS]} ]] || return 1

  # やはり通常コマンドはちゃんとした環境で評価するべき
  ble-edit/exec/register "$command"
}

## @fn ble/widget/.SHELL_COMMAND command
##   ble-bind -c で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND { ble/widget/execute-command "$@"; }

## @fn ble/widget/.EDIT_COMMAND command
##   ble-bind -x で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND {
  local command=$1
  local -x READLINE_LINE=$_ble_edit_str
  local -x READLINE_POINT=$_ble_edit_ind
  local -x READLINE_MARK=$_ble_edit_mark
  [[ $_ble_edit_arg ]] &&
    local -x READLINE_ARGUMENT=$_ble_edit_arg
  ble/widget/.hide-current-line
  ble/util/buffer.flush >&2
  builtin eval -- "$command" || return 1
  ble-edit/content/clear-arg

  [[ $READLINE_LINE != "$_ble_edit_str" ]] &&
    ble-edit/content/reset-and-check-dirty "$READLINE_LINE"
  ((_ble_edit_ind=READLINE_POINT))
  ((_ble_edit_mark=READLINE_MARK))

  local N=${#_ble_edit_str}
  ((_ble_edit_ind<0?_ble_edit_ind=0:(_ble_edit_ind>N&&(_ble_edit_ind=N))))
  ((_ble_edit_mark<0?_ble_edit_mark=0:(_ble_edit_mark>N&&(_ble_edit_mark=N))))
}

## ble-decode.sh 用の設定
function ble-decode/INITIALIZE_DEFMAP {
  local ret
  bleopt/get:default_keymap; local defmap=$ret
  if ble-edit/bind/load-editing-mode "$defmap"; then
    local base_keymap=$defmap
    [[ $defmap == vi ]] && base_keymap=vi_imap
    builtin eval -- "$2=\$base_keymap"
    ble/decode/is-keymap "$base_keymap" && return 0
  fi

  # エラーメッセージ
  ble/widget/.hide-current-line
  local -a DRAW_BUFF=()
  ble/canvas/put.draw "$_ble_term_cr$_ble_term_el${_ble_term_setaf[9]}"
  ble/canvas/put.draw "[ble.sh: The definition of the default keymap \"$defmap\" is not found. ble.sh uses \"safe\" keymap instead.]"
  ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_nl"
  ble/canvas/bflush.draw
  ble/util/buffer.flush >&2

  # Fallback keymap "safe"
  ble-edit/bind/load-editing-mode safe &&
    ble/decode/keymap#load safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

function ble-edit/bind/load-editing-mode {
  local name=$1
  if ble/is-function ble-edit/bind/load-editing-mode:"$name"; then
    ble-edit/bind/load-editing-mode:"$name"
  else
    ble/util/import "$_ble_base/keymap/$name.sh"
  fi
}
function ble-edit/bind/clear-keymap-definition-loader {
  builtin unset -f ble-edit/bind/load-editing-mode:safe
  builtin unset -f ble-edit/bind/load-editing-mode:emacs
  builtin unset -f ble-edit/bind/load-editing-mode:vi
}

#------------------------------------------------------------------------------
# **** entry points ****

function ble-edit/initialize {
  ble/prompt/initialize
}
function ble-edit/attach {
  ble-edit/attach/.attach
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/util/buffer "$_ble_term_cr"
}
function ble-edit/detach {
  ble-edit/bind/stdout.finalize
  ble-edit/attach/.detach
}
