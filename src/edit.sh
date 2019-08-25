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
# @history.isearch
# @comp
# @bind
# @bind.bind

## オプション edit_vbell
##   編集時の visible bell の有効・無効を設定します。
## bleopt_edit_vbell=1
##   有効です。
## bleopt_edit_vbell=
##   無効です。
bleopt/declare -v edit_vbell ''

## オプション edit_abell
##   編集時の audible bell (BEL 文字出力) の有効・無効を設定します。
## bleopt_edit_abell=1
##   有効です。
## bleopt_edit_abell=
##   無効です。
bleopt/declare -v edit_abell 1

## オプション history_lazyload
## bleopt_history_lazyload=1
##   ble-attach 後、初めて必要になった時に履歴の読込を行います。
## bleopt_history_lazyload=
##   ble-attach 時に履歴の読込を行います。
##
## bash-3.1 未満では history -s が思い通りに動作しないので、
## このオプションの値に関係なく ble-attach の時に履歴の読み込みを行います。
bleopt/declare -v history_lazyload 1

## オプション delete_selection_mode
##   文字挿入時に選択範囲をどうするかについて設定します。
## bleopt_delete_selection_mode=1 (既定)
##   選択範囲の内容を新しい文字で置き換えます。
## bleopt_delete_selection_mode=
##   選択範囲を解除して現在位置に新しい文字を挿入します。
bleopt/declare -v delete_selection_mode 1

## オプション indent_offset
##   シェルのインデント幅を指定します。既定では 4 です。
bleopt/declare -n indent_offset 4

## オプション indent_tabs
##   インデントにタブを使用するかどうかを指定します。
##   0 を指定するとインデントに空白だけを用います。
##   それ以外の場合はインデントにタブを使用します。
bleopt/declare -n indent_tabs 1

## オプション undo_point
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

## オプション edit_forced_textmap
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

## オプション rps1
bleopt/declare -v rps1 ''
bleopt/declare -v rps1_transient ''

## オプション prompt_eol_mark
bleopt/declare -v prompt_eol_mark $'\e[94m[ble: EOF]\e[m'

## オプション internal_exec_type (内部使用)
##   コマンドの実行の方法を指定します。
##
##   internal_exec_type=exec
##     関数内で実行します (従来の方法です。将来的に削除されます)
##   internal_exec_type=gexec
##     グローバルな文脈で実行します (新しい方法です)
##
## 要件: 関数 ble-edit/exec:$bleopt_internal_exec_type/process が定義されていること。
bleopt/declare -n internal_exec_type gexec

function bleopt/check:internal_exec_type {
  if ! ble/is-function "ble-edit/exec:$value/process"; then
    echo "bleopt: Invalid value internal_exec_type='$value'. A function 'ble-edit/exec:$value/process' is not defined." >&2
    return 1
  fi
}

## オプション internal_suppress_bash_output (内部使用)
##   bash 自体の出力を抑制するかどうかを指定します。
## bleopt_internal_suppress_bash_output=1
##   抑制します。bash のエラーメッセージは visible-bell で表示します。
## bleopt_internal_suppress_bash_output=
##   抑制しません。bash のメッセージは全て端末に出力されます。
##   これはデバグ用の設定です。bash の出力を制御するためにちらつきが発生する事があります。
##   bash-3 ではこの設定では C-d を捕捉できません。
bleopt/declare -v internal_suppress_bash_output 1

## オプション internal_ignoreeof_trap (内部使用)
##   bash-3.0 の時に使用します。C-d を捕捉するのに用いるメッセージです。
##   これは自分の bash の設定に合わせる必要があります。
bleopt/declare -n internal_ignoreeof_trap 'Use "exit" to leave the shell.'

## オプション allow_exit_with_jobs
##   この変数に空文字列が設定されている時、
##   ジョブが残っている時には ble/widget/exit からシェルは終了しません。
##   この変数に空文字列以外が設定されている時、
##   ジョブがある場合でも条件を満たした時に exit を実行します。
##   停止中のジョブがある場合、または、shopt -s checkjobs かつ実行中のジョブが存在する時は、
##   二回連続で同じ widget から exit を呼び出した時にシェルを終了します。
##   それ以外の場合は常にシェルを終了します。
##   既定値は空文字列です。
bleopt/declare -v allow_exit_with_jobs ''

# 
#------------------------------------------------------------------------------
# **** prompt ****                                                    @line.ps1

## called by ble-edit/initialize
function ble-edit/prompt/initialize {
  # hostname
  _ble_edit_prompt__string_h=${HOSTNAME%%.*}
  _ble_edit_prompt__string_H=${HOSTNAME}

  # tty basename
  local tmp; ble/util/assign tmp 'tty 2>/dev/null'
  _ble_edit_prompt__string_l=${tmp##*/}

  # command name
  _ble_edit_prompt__string_s=${0##*/}

  # user
  _ble_edit_prompt__string_u=${USER}

  # bash versions
  ble/util/sprintf _ble_edit_prompt__string_v '%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
  ble/util/sprintf _ble_edit_prompt__string_V '%d.%d.%d' "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" "${BASH_VERSINFO[2]}"

  # uid
  if [[ $EUID -eq 0 ]]; then
    _ble_edit_prompt__string_root='#'
  else
    _ble_edit_prompt__string_root='$'
  fi

  if [[ $OSTYPE == cygwin* ]]; then
    local windir=/cygdrive/c/Windows
    if [[ $WINDIR == [A-Za-z]:\\* ]]; then
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
      _ble_edit_prompt__string_root='#'
    fi
  fi
}

## 変数 _ble_edit_prompt
##   構築した prompt の情報をキャッシュします。
##   @var _ble_edit_prompt[0]    version
##     prompt 情報を作成した時の _ble_edit_LINENO を表します。
##   @var _ble_edit_prompt[1..3] x y g
##     prompt を表示し終わった時のカーソルの位置と描画属性を表します。
##   @var _ble_edit_prompt[4..5] lc lg
##     bleopt_internal_suppress_bash_output= の時、
##     prompt を表示し終わった時の左側にある文字とその描画属性を表します。
##     それ以外の時はこの値は使われません。
##   @var _ble_edit_prompt[6]    ps1out
##     prompt を表示する為に出力する制御シーケンスを含んだ文字列です。
##   @var _ble_edit_prompt[7]    trace_hash
##     COLUMNS:ps1esc の形式の文字列です。
##     調整前の ps1out を格納します。
##     ps1out の計算 (trace) を省略する為に使用します。
_ble_edit_prompt=("" 0 0 0 32 0 "" "")


## 関数 ble-edit/prompt/.load
##   @var[out] x y g
##   @var[out] lc lg
##   @var[out] ret
##     プロンプトを描画するための文字列
function ble-edit/prompt/.load {
  x=${_ble_edit_prompt[1]}
  y=${_ble_edit_prompt[2]}
  g=${_ble_edit_prompt[3]}
  lc=${_ble_edit_prompt[4]}
  lg=${_ble_edit_prompt[5]}
  ret=${_ble_edit_prompt[6]}
}

## 関数 ble-edit/prompt/print text
##   プロンプト構築中に呼び出す関数です。
##   指定された文字列を、後の評価に対するエスケープをして出力します。
##   @param[in] text
##     エスケープされる文字列を指定します。
##   @var[out]  DRAW_BUFF[]
##     出力先の配列です。
function ble-edit/prompt/print {
  local text=$1 a b
  if [[ $text == *['$\"`']* ]]; then
    a='\' b='\\' text=${text//"$a"/$b}
    a='$' b='\$' text=${text//"$a"/$b}
    a='"' b='\"' text=${text//"$a"/$b}
    a='`' b='\`' text=${text//"$a"/$b}
  fi
  ble/canvas/put.draw "$text"
}

## 関数 ble-edit/prompt/process-prompt-string prompt_string
##   プロンプト構築中に呼び出す関数です。
##   指定した引数を PS1 と同様の形式と解釈して処理します。
##   @param[in] prompt_string
##   @arr[in,out] DRAW_BUFF
function ble-edit/prompt/process-prompt-string {
  local ps1=$1
  local i=0 iN=${#ps1}
  local rex_letters='^[^\]+|\\$'
  while ((i<iN)); do
    local tail=${ps1:i}
    if [[ $tail == '\'?* ]]; then
      ble-edit/prompt/.process-backslash
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
## 関数 ble-edit/prompt/.process-backslash
##   @var[in]     tail
##   @arr[in.out] DRAW_BUFF
function ble-edit/prompt/.process-backslash {
  ((i+=2))

  # \\ の次の文字
  local c=${tail:1:1} pat='[]#!$\'
  if [[ ! ${pat##*"$c"*} ]]; then
    case "$c" in
    (\[) ble/canvas/put.draw $'\e[99s' ;; # \[ \] は後処理の為、適当な識別用の文字列を出力する。
    (\]) ble/canvas/put.draw $'\e[99u' ;;
    ('#') # コマンド番号 (本当は history に入らない物もある…)
      ble/canvas/put.draw "$_ble_edit_CMD" ;;
    (\!) # 編集行の履歴番号
      local count
      ble-edit/history/get-count -v count
      ble/canvas/put.draw $((count+1)) ;;
    ('$') # # or $
      ble-edit/prompt/print "$_ble_edit_prompt__string_root" ;;
    (\\)
      # '\\' は '\' と出力された後に、更に "" 内で評価された時に次の文字をエスケープする。
      # 例えば '\\$' は一旦 '\$' となり、更に展開されて '$' となる。'\\\\' も同様に '\' になる。
      ble/canvas/put.draw '\' ;;
    esac
  elif ! ble/function#try ble-edit/prompt/backslash:"$c"; then
    # その他の文字はそのまま出力される。
    # - '\"' '\`' はそのまま出力された後に "" 内で評価され '"' '`' となる。
    # - それ以外の場合は '\?' がそのまま出力された後に、"" 内で評価されても変わらず '\?' 等となる。
    ble/canvas/put.draw "\\$c"
  fi
}

## 設定関数 ble-edit/prompt/backslash:*
##   プロンプト PS1 内で使用するバックスラッシュシーケンスを定義します。
##   内部では ble/canvas/put.draw escaped_text もしくは
##   ble-edit/prompt/print unescaped_text を用いて
##   シーケンスの展開結果を追記します。
##
##   @exit
##     対応する文字列を出力した時に成功します。
##     0 以外の終了ステータスを返した場合、
##     シーケンスが処理されなかったと見做され、
##     呼び出し元によって \c (c: 文字) が代わりに書き込まれます。
##
function ble-edit/prompt/backslash:0 { # 8進表現
  local rex='^\\[0-7]{1,3}'
  if [[ $tail =~ $rex ]]; then
    local seq=${BASH_REMATCH[0]}
    ((i+=${#seq}-2))
    builtin eval "c=\$'$seq'"
  fi
  ble-edit/prompt/print "$c"
  return 0
}
function ble-edit/prompt/backslash:1 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:2 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:3 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:4 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:5 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:6 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:7 { ble-edit/prompt/backslash:0; }
function ble-edit/prompt/backslash:a { # 0 BEL
  ble/canvas/put.draw ""
  return 0
}
function ble-edit/prompt/backslash:d { # ? 日付
  [[ $cache_d ]] || ble/util/strftime -v cache_d '%a %b %d'
  ble-edit/prompt/print "$cache_d"
  return 0
}
function ble-edit/prompt/backslash:t { # 8 時刻
  [[ $cache_t ]] || ble/util/strftime -v cache_t '%H:%M:%S'
  ble-edit/prompt/print "$cache_t"
  return 0
}
function ble-edit/prompt/backslash:A { # 5 時刻
  [[ $cache_A ]] || ble/util/strftime -v cache_A '%H:%M'
  ble-edit/prompt/print "$cache_A"
  return 0
}
function ble-edit/prompt/backslash:T { # 8 時刻
  [[ $cache_T ]] || ble/util/strftime -v cache_T '%I:%M:%S'
  ble-edit/prompt/print "$cache_T"
  return 0
}
function ble-edit/prompt/backslash:@ { # ? 時刻
  [[ $cache_at ]] || ble/util/strftime -v cache_at '%I:%M %p'
  ble-edit/prompt/print "$cache_at"
  return 0
}
function ble-edit/prompt/backslash:D {
  local rex='^\\D\{([^{}]*)\}' cache_D
  if [[ $tail =~ $rex ]]; then
    ble/util/strftime -v cache_D "${BASH_REMATCH[1]}"
    ble-edit/prompt/print "$cache_D"
    ((i+=${#BASH_REMATCH}-2))
  else
    ble-edit/prompt/print "\\$c"
  fi
  return 0
}
function ble-edit/prompt/backslash:e {
  ble/canvas/put.draw $'\e'
  return 0
}
function ble-edit/prompt/backslash:h { # = ホスト名
  ble-edit/prompt/print "$_ble_edit_prompt__string_h"
  return 0
}
function ble-edit/prompt/backslash:H { # = ホスト名
  ble-edit/prompt/print "$_ble_edit_prompt__string_H"
  return 0
}
function ble-edit/prompt/backslash:j { #   ジョブの数
  if [[ ! $cache_j ]]; then
    local joblist
    ble/util/joblist
    cache_j=${#joblist[@]}
  fi
  ble/canvas/put.draw "$cache_j"
  return 0
}
function ble-edit/prompt/backslash:l { #   tty basename
  ble-edit/prompt/print "$_ble_edit_prompt__string_l"
  return 0
}
function ble-edit/prompt/backslash:n {
  ble/canvas/put.draw $'\n'
  return 0
}
function ble-edit/prompt/backslash:r {
  ble/canvas/put.draw "$_ble_term_cr"
  return 0
}
function ble-edit/prompt/backslash:s { # 4 "bash"
  ble-edit/prompt/print "$_ble_edit_prompt__string_s"
  return 0
}
function ble-edit/prompt/backslash:u { # = ユーザ名
  ble-edit/prompt/print "$_ble_edit_prompt__string_u"
  return 0
}
function ble-edit/prompt/backslash:v { # = bash version %d.%d
  ble-edit/prompt/print "$_ble_edit_prompt__string_v"
  return 0
}
function ble-edit/prompt/backslash:V { # = bash version %d.%d.%d
  ble-edit/prompt/print "$_ble_edit_prompt__string_V"
  return 0
}
function ble-edit/prompt/backslash:w { # PWD
  ble-edit/prompt/.update-working-directory
  ble-edit/prompt/print "$cache_wd"
  return 0
}
function ble-edit/prompt/backslash:W { # PWD短縮
  if [[ ! ${PWD//'/'} ]]; then
    ble-edit/prompt/print "$PWD"
  else
    ble-edit/prompt/.update-working-directory
    ble-edit/prompt/print "${cache_wd##*/}"
  fi
  return 0
}
## 関数 ble-edit/prompt/.update-working-directory
##   @var[in,out] cache_wd
function ble-edit/prompt/.update-working-directory {
  [[ $cache_wd ]] && return

  if [[ ! ${PWD//'/'} ]]; then
    cache_wd=$PWD
    return
  fi

  local head= body=${PWD%/}
  if [[ $body == "$HOME" ]]; then
    cache_wd='~'
    return
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

  cache_wd=$head$body
}

function ble-edit/prompt/.escape/check-double-quotation {
  if [[ $tail == '"'* ]]; then
    if [[ ! $nest ]]; then
      out=$out'\"'
      tail=${tail:1}
    else
      out=$out'"'
      tail=${tail:1}
      nest=\"$nest
      ble-edit/prompt/.escape/update-rex_skip
    fi
    return 0
  else
    return 1
  fi
}
function ble-edit/prompt/.escape/check-command-substitution {
  if [[ $tail == '$('* ]]; then
    out=$out'$('
    tail=${tail:2}
    nest=')'$nest
    ble-edit/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble-edit/prompt/.escape/check-parameter-expansion {
  if [[ $tail == '${'* ]]; then
    out=$out'${'
    tail=${tail:2}
    nest='}'$nest
    ble-edit/prompt/.escape/update-rex_skip
    return 0
  else
    return 1
  fi
}
function ble-edit/prompt/.escape/check-incomplete-quotation {
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
function ble-edit/prompt/.escape/update-rex_skip {
  if [[ $nest == \)* ]]; then
    rex_skip=$rex_skip_paren
  elif [[ $nest == \}* ]]; then
    rex_skip=$rex_skip_brace
  else
    rex_skip=$rex_skip_dquot
  fi
}
function ble-edit/prompt/.escape {
  local tail=$1 out= nest=

  # 地の文の " だけをエスケープする。

  local q=\'
  local rex_bq='`([^\`]|\\.)*`'
  local rex_sq=$q'[^'$q']*'$q'|\$'$q'([^\'$q']|\\.)*'$q

  local rex_skip
  local rex_skip_dquot='^([^\"$`]|'$rex_bq'|\\.)+'
  local rex_skip_brace='^([^\"$`'$q'}]|'$rex_bq'|'$rex_sq'|\\.)+'
  local rex_skip_paren='^([^\"$`'$q'()]|'$rex_bq'|'$rex_sq'|\\.)+'
  ble-edit/prompt/.escape/update-rex_skip

  while [[ $tail ]]; do
    if [[ $tail =~ $rex_skip ]]; then
      out=$out$BASH_REMATCH
      tail=${tail:${#BASH_REMATCH}}
    elif [[ $nest == ['})"']* && $tail == "${nest::1}"* ]]; then
      out=$out${nest::1}
      tail=${tail:1}
      nest=${nest:1}
      ble-edit/prompt/.escape/update-rex_skip
    elif [[ $nest == \)* && $tail == \(* ]]; then
      out=$out'('
      tail=${tail:1}
      nest=')'$nest
    elif ble-edit/prompt/.escape/check-double-quotation; then
      continue
    elif ble-edit/prompt/.escape/check-command-substitution; then
      continue
    elif ble-edit/prompt/.escape/check-parameter-expansion; then
      continue
    elif ble-edit/prompt/.escape/check-incomplete-quotation; then
      continue
    else
      out=$out${tail::1}
      tail=${tail:1}
    fi
  done
  ret=$out$nest
}
## 関数 ble-edit/prompt/.instantiate ps opts [x0 y0 g0 lc0 lg0 val0 esc0]
##   @var[out] val esc x y g lc lg
##   @var[in,out] x1 x2 y1 y2
##   @var[in,out] cache_d cache_t cache_A cache_T cache_at cache_j cache_wd
function ble-edit/prompt/.instantiate {
  trace_hash= esc= x=0 y=0 g=0 lc=32 lg=0
  local ps=$1 opts=$2 x0=$3 y0=$4 g0=$5 lc0=$6 lg0=$7 esc0=$8 trace_hash0=$9
  [[ ! $ps ]] && return 0

  # 1. PS1 に含まれる \c を処理する
  local -a DRAW_BUFF=()
  ble-edit/prompt/process-prompt-string "$ps"
  local processed; ble/canvas/sflush.draw -v processed

  # 2. PS1 に含まれる \\ や " をエスケープし、
  #   eval して各種シェル展開を実行する。
  local ret
  ble-edit/prompt/.escape "$processed"; local escaped=$ret
  local expanded=${trace_hash0#*:} # Note: これは次行が失敗した時の既定値
  builtin eval "expanded=\"$escaped\""

  # 3. 端末への出力を構成する
  trace_hash=$COLUMNS:$expanded
  if [[ $trace_hash != "$trace_hash0" ]]; then
    x=0 y=0 g=0 lc=32 lg=0
    ble/canvas/trace "$expanded" "$opts:left-char"; local traced=$ret
    ((lc<0&&(lc=0)))
    esc=$traced
    return 0
  else
    x=$x0 y=$y0 g=$g0 lc=$lc0 lg=$lg0
    esc=$esc0
    return 2
  fi
}

function ble-edit/prompt/update/.eval-prompt_command {
  # return 等と記述されていた時対策として関数内評価。
  eval "$PROMPT_COMMAND"
}
## 関数 ble-edit/prompt/update
##   _ble_edit_PS1 からプロンプトを構築します。
##   @var[in]  _ble_edit_PS1
##     構築されるプロンプトの内容を指定します。
##   @var[out] _ble_edit_prompt
##     構築したプロンプトの情報を格納します。
##   @var[out] ret
##     プロンプトを描画する為の文字列を返します。
##   @var[in,out] x y g
##     プロンプトの描画開始点を指定します。
##     プロンプトを描画した後の位置を返します。
##   @var[in,out] lc lg
##     bleopt_internal_suppress_bash_output= の際に、
##     描画開始点の左の文字コードを指定します。
##     描画終了点の左の文字コードが分かる場合にそれを返します。
function ble-edit/prompt/update {
  local version=$COLUMNS:$_ble_edit_LINENO
  if [[ ${_ble_edit_prompt[0]} == "$version" ]]; then
    ble-edit/prompt/.load
    return
  fi

  local cache_d= cache_t= cache_A= cache_T= cache_at= cache_j= cache_wd=

  # update PS1
  if [[ $PROMPT_COMMAND ]]; then
    ble-edit/restore-PS1
    ble-edit/prompt/update/.eval-prompt_command
    ble-edit/adjust-PS1
  fi
  local trace_hash esc
  ble-edit/prompt/.instantiate "$_ble_edit_PS1" '' "${_ble_edit_prompt[@]:1}"
  _ble_edit_prompt=("$version" "$x" "$y" "$g" "$lc" "$lg" "$esc" "$trace_hash")
  ret=$esc

  # update edit_rps1
  if [[ $bleopt_rps1 ]]; then
    local ps1_height=$((y+1))
    local trace_hash esc x y g lc lg # Note: これ以降は local の x y g lc lg
    local x1=${_ble_edit_rprompt_bbox[0]}
    local y1=${_ble_edit_rprompt_bbox[1]}
    local x2=${_ble_edit_rprompt_bbox[2]}
    local y2=${_ble_edit_rprompt_bbox[3]}
    LINES=$ps1_height ble-edit/prompt/.instantiate "$bleopt_rps1" confine:relative:measure-bbox "${_ble_edit_rprompt[@]:1}"
    _ble_edit_rprompt=("$version" "$x" "$y" "$g" "$lc" "$lg" "$esc" "$trace_hash")
    _ble_edit_rprompt_bbox=("$x1" "$y1" "$x2" "$y2")
  fi
}

# 
# **** information pane ****                                         @line.info

## 関数 ble-edit/info/.initialize-size
##   @var[out] cols lines
function ble-edit/info/.initialize-size {
  local ret
  ble/canvas/panel/layout/.get-available-height "$_ble_edit_info_panel"
  cols=${COLUMNS-80} lines=$ret
}

_ble_edit_info_panel=2
_ble_edit_info=(0 0 "")

function ble-edit/info#get-height {
  if [[ ${_ble_edit_info[2]} ]]; then
    height=1:$((_ble_edit_info[1]+1))
  else
    height=0:0
  fi
}

## 関数 ble-edit/info/.construct-content type text
##   @var[out] x y
##   @var[out] content
function ble-edit/info/.construct-content {
  local cols lines
  ble-edit/info/.initialize-size
  x=0 y=0 content=

  local type=$1 text=$2
  case "$1" in
  (ansi|esc)
    local trace_opts=truncate
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
    ((y<lines)) || ble-edit/info/.construct-content esc "$content" ;;
  (*)
    echo "usage: ble-edit/info/.construct-content type text" >&2 ;;
  esac
}

function ble-edit/info/.clear-content {
  [[ ${_ble_edit_info[2]} ]] || return

  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_edit_info_panel" 0
  ble/canvas/bflush.draw

  _ble_edit_info=(0 0 "")
}

## 関数 ble-edit/info/.render-content x y content
##   @param[in] x y content
function ble-edit/info/.render-content {
  local x=$1 y=$2 content=$3

  # 既に同じ内容で表示されているとき…。
  [[ $content == "${_ble_edit_info[2]}" ]] && return

  if [[ ! $content ]]; then
    ble-edit/info/.clear-content
    return
  fi

  _ble_edit_info=("$x" "$y" "$content")

  local -a DRAW_BUFF=()
  ble/canvas/panel#reallocate-height.draw
  ble/canvas/panel#clear.draw "$_ble_edit_info_panel"
  ble/canvas/panel#goto.draw "$_ble_edit_info_panel"
  ble/canvas/put.draw "$content"
  ble/canvas/bflush.draw
  ((_ble_canvas_y+=y,_ble_canvas_x=x))
}

_ble_edit_info_default=(0 0 "")
_ble_edit_info_scene=default

## 関数 ble-edit/info/show type text
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
function ble-edit/info/show {
  local type=$1 text=$2
  if [[ $text ]]; then
    local x y content=
    ble-edit/info/.construct-content "$@"
    ble-edit/info/.render-content "$x" "$y" "$content"
    ble/util/buffer.flush >&2
    _ble_edit_info_scene=show
  else
    ble-edit/info/default
  fi
}
function ble-edit/info/set-default {
  local type=$1 text=$2
  local x y content
  ble-edit/info/.construct-content "$type" "$text"
  _ble_edit_info_default=("$x" "$y" "$content")
}
function ble-edit/info/default {
  _ble_edit_info_scene=default
  (($#)) && ble-edit/info/set-default "$@"
  return 0
}
function ble-edit/info/clear {
  ble-edit/info/default
}

## 関数 ble-edit/info/hide
## 関数 ble-edit/info/reveal
##
##   これらの関数は .newline 前後に一時的に info の表示を抑制するための関数である。
##   この関数の呼び出しの後に flush が入ることを想定して ble/util/buffer.flush は実行しない。
##
function ble-edit/info/hide {
  ble-edit/info/.clear-content
}
function ble-edit/info/reveal {
  if [[ $_ble_edit_info_scene == default ]]; then
    ble-edit/info/.render-content "${_ble_edit_info_default[@]}"
  fi
}

function ble-edit/info/immediate-show {
  local x=$_ble_canvas_x y=$_ble_canvas_y
  ble-edit/info/show "$@"
  local -a DRAW_BUFF=()
  ble/canvas/goto.draw "$x" "$y"
  ble/canvas/bflush.draw
  ble/util/buffer.flush >&2
}
function ble-edit/info/immediate-clear {
  local x=$_ble_canvas_x y=$_ble_canvas_y
  ble-edit/info/clear
  ble-edit/info/reveal
  local -a DRAW_BUFF=()
  ble/canvas/goto.draw "$x" "$y"
  ble/canvas/bflush.draw
  ble/util/buffer.flush >&2
}

# 
#------------------------------------------------------------------------------
# **** edit ****                                                          @edit

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
  _ble_edit_kill_ring
  _ble_edit_kill_type
  _ble_edit_dirty_observer)
_ble_edit_ARRNAMES=()

# 現在の編集状態は以下の変数で表現される
_ble_edit_str=
_ble_edit_ind=0
_ble_edit_mark=0
_ble_edit_mark_active=
_ble_edit_overwrite_mode=
_ble_edit_line_disabled=
_ble_edit_arg=

# 以下は複数の編集文字列が合ったとして全体で共有して良いもの
_ble_edit_kill_ring=
_ble_edit_kill_type=

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
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble/util/stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; beg=$beg, end=$end, ins(${#ins})=$ins"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end=${#_ble_edit_str}
    _ble_edit_dirty_syntax_end0=0
    local olen=$((${#_ble_edit_str}-${#ins}+end-beg))
    ((olen<0&&(olen=0),
      _ble_edit_ind>olen&&(_ble_edit_ind=olen),
      _ble_edit_mark>olen&&(_ble_edit_mark=olen)))
  fi
#%end
}
function ble-edit/content/reset {
  local str=$1 reason=${2:-edit}
  local beg=0 end=${#str} end0=${#_ble_edit_str}
  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$beg" "$end" "$end0" "$reason"
#%if !release
  if ! ((0<=_ble_edit_dirty_syntax_beg&&_ble_edit_dirty_syntax_end<=${#_ble_edit_str})); then
    ble/util/stackdump "0 <= beg=$_ble_edit_dirty_syntax_beg <= end=$_ble_edit_dirty_syntax_end <= len=${#_ble_edit_str}; str(${#str})=$str"
    _ble_edit_dirty_syntax_beg=0
    _ble_edit_dirty_syntax_end=${#_ble_edit_str}
    _ble_edit_dirty_syntax_end0=0
  fi
#%end
}
function ble-edit/content/reset-and-check-dirty {
  local str=$1 reason=${2:-edit}
  [[ $_ble_edit_str == "$str" ]] && return

  local ret pref suff
  ble/string#common-prefix "$_ble_edit_str" "$str"; pref=$ret
  local dmin=${#pref}
  ble/string#common-suffix "${_ble_edit_str:dmin}" "${str:dmin}"; suff=$ret
  local dmax0=$((${#_ble_edit_str}-${#suff})) dmax=$((${#str}-${#suff}))

  _ble_edit_str=$str
  ble-edit/content/.update-dirty-range "$dmin" "$dmax" "$dmax0" "$reason"
}

_ble_edit_dirty_draw_beg=-1
_ble_edit_dirty_draw_end=-1
_ble_edit_dirty_draw_end0=-1

_ble_edit_dirty_syntax_beg=0
_ble_edit_dirty_syntax_end=0
_ble_edit_dirty_syntax_end0=1

_ble_edit_dirty_observer=()
## 関数 ble-edit/content/.update-dirty-range beg end end0 [reason]
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
  if ble/is-function ble/syntax/parse; then
    local beg end end0
    ble/dirty-range#load --prefix=_ble_edit_dirty_syntax_
    if ((beg>=0)); then
      ble/dirty-range#clear --prefix=_ble_edit_dirty_syntax_
      ble/syntax/parse "$_ble_edit_str" "$beg" "$end" "$end0"
    fi
  fi
}

## 関数 ble-edit/content/bolp
##   現在カーソルが行頭に位置しているかどうかを判定します。
function ble-edit/content/eolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos==${#_ble_edit_str})) || [[ ${_ble_edit_str:pos:1} == $'\n' ]]
}
## 関数 ble-edit/content/bolp
##   現在カーソルが行末に位置しているかどうかを判定します。
function ble-edit/content/bolp {
  local pos=${1:-$_ble_edit_ind}
  ((pos<=0)) || [[ ${_ble_edit_str:pos-1:1} == $'\n' ]]
}
## 関数 ble-edit/content/find-logical-eol [index [offset]]
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
## 関数 ble-edit/content/find-logical-bol [index [offset]]
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
## 関数 ble-edit/content/find-non-space index
##   指定した位置以降の最初の非空白文字を探します。
##   @param[in] index
##   @var[out] ret
function ble-edit/content/find-non-space {
  local bol=$1
  local rex=$'^[ \t]*'; [[ ${_ble_edit_str:bol} =~ $rex ]]
  ret=$((bol+${#BASH_REMATCH}))
}


## 関数 ble-edit/content/is-single-line
function ble-edit/content/is-single-line {
  [[ $_ble_edit_str != *$'\n'* ]]
}

## 関数 ble-edit/content/get-arg
##   @var[out] arg
function ble-edit/content/get-arg {
  local default_value=$1
  if [[ $_ble_edit_arg == -* ]]; then
    if [[ $_ble_edit_arg == - ]]; then
      arg=-1
    else
      arg=$((-10#${_ble_edit_arg#-}))
    fi
  else
    if [[ $_ble_edit_arg ]]; then
      arg=$((10#$_ble_edit_arg))
    else
      arg=$default_value
    fi
  fi
  _ble_edit_arg=
}
function ble-edit/content/clear-arg {
  _ble_edit_arg=
}

# **** PS1/LINENO ****                                                @edit.ps1
#
# 内部使用変数
## 変数 _ble_edit_LINENO
## 変数 _ble_edit_CMD
## 変数 _ble_edit_PS1
## 変数 _ble_edit_IFS
## 変数 _ble_edit_IGNOREEOF_adjusted
## 変数 _ble_edit_IGNOREEOF

_ble_edit_PS1_adjusted=
_ble_edit_PS1=
function ble-edit/adjust-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] && return
  _ble_edit_PS1_adjusted=1
  _ble_edit_PS1=$PS1
  PS1=
}
function ble-edit/restore-PS1 {
  [[ $_ble_edit_PS1_adjusted ]] || return
  _ble_edit_PS1_adjusted=
  PS1=$_ble_edit_PS1
}

_ble_edit_IGNOREEOF_adjusted=
_ble_edit_IGNOREEOF=
function ble-edit/adjust-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] && return
  _ble_edit_IGNOREEOF_adjusted=1

  if [[ ${IGNOREEOF+set} ]]; then
    _ble_edit_IGNOREEOF=$IGNOREEOF
  else
    unset -v _ble_edit_IGNOREEOF
  fi
  if ((_ble_bash>=40000)); then
    unset -v IGNOREEOF
  else
    IGNOREEOF=9999
  fi
}
function ble-edit/restore-IGNOREEOF {
  [[ $_ble_edit_IGNOREEOF_adjusted ]] || return
  _ble_edit_IGNOREEOF_adjusted=

  if [[ ${_ble_edit_IGNOREEOF+set} ]]; then
    IGNOREEOF=$_ble_edit_IGNOREEOF
  else
    unset -v IGNOREEOF
  fi
}
## 関数 ble-edit/eval-IGNOREEOF
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
  local IFS=$' \t\n'
  if ((_ble_edit_attached)); then
    if [[ ! $_ble_textarea_invalidated && $_ble_term_state == internal ]]; then
      _ble_textmap_pos=()
      ble-edit/bind/stdout.on
      ble-edit/info/hide
      ble/util/buffer "$_ble_term_ed"
      ble-edit/info/reveal
      ble/textarea#redraw
      ble-edit/bind/stdout.off
    fi
  fi
}

## called by ble-edit/attach
_ble_edit_attached=0
function ble-edit/attach/.attach {
  ((_ble_edit_attached)) && return
  _ble_edit_attached=1

  if [[ ! ${_ble_edit_LINENO+set} ]]; then
    _ble_edit_LINENO="${BASH_LINENO[*]: -1}"
    ((_ble_edit_LINENO<0)) && _ble_edit_LINENO=0
    unset -v LINENO; LINENO=$_ble_edit_LINENO
    _ble_edit_CMD=$_ble_edit_LINENO
  fi

  trap ble-edit/attach/TRAPWINCH WINCH

  ble-edit/adjust-PS1
  ble-edit/adjust-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && _ble_edit_IFS=$IFS
}

function ble-edit/attach/.detach {
  ((!_ble_edit_attached)) && return
  ble-edit/restore-PS1
  ble-edit/restore-IGNOREEOF
  [[ $bleopt_internal_exec_type == exec ]] && IFS=$_ble_edit_IFS
  _ble_edit_attached=0
}


# 
#------------------------------------------------------------------------------
# **** textarea ****                                                  @textarea

_ble_textarea_VARNAMES=(
  _ble_textarea_bufferName
  _ble_textarea_scroll
  _ble_textarea_gendx
  _ble_textarea_gendy
  _ble_textarea_invalidated
  _ble_textarea_version
  _ble_textarea_caret_state
  _ble_textarea_panel)
_ble_textarea_ARRNAMES=(
  _ble_textarea_buffer
  _ble_textarea_cur
  _ble_textarea_cache)

## 関数 ble/textarea/panel#get-height
##   @var[out] height
function ble/textarea/panel#get-height {
  if [[ $1 == "$_ble_textarea_panel" ]]; then
    local min=$((_ble_edit_prompt[2]+1)) max=$((_ble_textmap_endy+1))
    ((min<max&&min++))
    height=$min:$max
  else
    height=0:${_ble_canvas_panel_height[$1]}
  fi
}
function ble/textarea/panel#on-height-change {
  [[ $1 == "$_ble_textarea_panel" ]] || return

  if [[ ! $ble_textarea_render_flag ]]; then
    ble/textarea#invalidate
  fi
}

# **** textarea.buffer ****                                    @textarea.buffer

_ble_textarea_buffer=()
_ble_textarea_bufferName=

## 関数 lc lg; ble/textarea#update-text-buffer; cx cy lc lg
##
##   @param[in    ] text  編集文字列
##   @param[in    ] index カーソルの index
##   @param[in,out] x     編集文字列開始位置、終了位置。
##   @param[in,out] y     編集文字列開始位置、終了位置。
##   @param[in,out] lc lg
##     カーソル左の文字のコードと gflag を返します。
##     カーソルが先頭にある場合は、編集文字列開始位置の左(プロンプトの最後の文字)について記述します。
##   @var  [   out] umin umax
##     umin,umax は再描画の必要な範囲を文字インデックスで返します。
##
##   @var[in] _ble_textmap_*
##     配置情報が最新であることを要求します。
##
function ble/textarea#update-text-buffer {
  local iN=${#text}

  # highlight -> HIGHLIGHT_BUFF
  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble/highlight/layer/update "$text"
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

  # update lc, lg
  #
  #   lc, lg は bleopt_internal_suppress_bash_output= の時に bash に出力させる文字と
  #   その属性を表す。READLINE_LINE が空だと C-d を押した時にその場でログアウト
  #   してしまったり、エラーメッセージが表示されたりする。その為 READLINE_LINE
  #   に有限の長さの文字列を設定したいが、そうするとそれが画面に出てしまう。
  #   そこで、ble.sh では現在のカーソル位置にある文字と同じ文字を READLINE_LINE
  #   に設定する事で、bash が文字を出力しても見た目に問題がない様にしている。
  #
  #   cx==0 の時には現在のカーソル位置の右にある文字を READLINE_LINE に設定し
  #   READLINE_POINT=0 とする。cx>0 の時には現在のカーソル位置の左にある文字を
  #   READLINE_LINE に設定し READLINE_POINT=(左の文字のバイト数) とする。
  #   (READLINE_POINT は文字数ではなくバイトオフセットである事に注意する。)
  #
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    lc=32 lg=0
  else
    # index==0 の場合は受け取った lc lg をそのまま返す
    if ((index>0)); then
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
          ble/util/s2c "$lcs" 0
        fi

        # 次が改行の時は空白にする
        local g; ble/highlight/layer/getg "$index"; lg=$g
        ((lc=ret==10?32:ret))
      else
        # 前の文字
        lcs=${_ble_textmap_glyph[index-1]}
        ble/util/s2c "$lcs" $((${#lcs}-1))
        local g; ble/highlight/layer/getg $((index-1)); lg=$g
        ((lc=ret))
      fi
    fi
  fi
}
## 関数 ble/textarea#slice-text-buffer [beg [end]]
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

## 配列 _ble_textarea_cur
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

## 変数 _ble_textarea_invalidated
##   完全再描画 (プロンプトも含めた) を要求されたことを記録します。
##   完全再描画の要求前に空文字列で、要求後に 1 の値を持ちます。
_ble_textarea_invalidated=1

function ble/textarea#invalidate {
  if [[ $1 == str ]]; then
    ((_ble_textarea_version++))
  else
    _ble_textarea_invalidated=1
  fi
}

## 関数 ble/textarea#render/.erase-forward-line.draw opts
##   @var[in] x cols
function ble/textarea#render/.erase-forward-line.draw {
  local eraser=$_ble_term_el
  if [[ :$render_opts: == *:relative:* ]]; then
    local width=$((cols-x))
    if ((width==0)); then
      eraser=
    elif [[ $_ble_term_ech ]]; then
      eraser=${_ble_term_ech//'%d'/$width}
    else
      ble/string#reserve-prototype "$width"
      eraser=${_ble_string_prototype::width}${_ble_term_cub//'%d'/$width}
    fi
  fi
  ble/canvas/put.draw "$eraser"
}

## 関数 ble/textarea#render/.determine-scroll
##   新しい表示高さとスクロール位置を決定します。
##   ble/textarea#render から呼び出されることを想定します。
##
##   @var[in,out] scroll
##     現在のスクロール量を指定します。調整後のスクロール量を指定します。
##   @var[in,out] height
##     最大の表示高さを指定します。実際の表示高さを返します。
##   @var[in,out] umin umax
##     描画範囲を表示領域に制限して返します。
##
##   @var[in] cols
##   @var[in] begx begy endx endy cx cy
##     それぞれ編集文字列の先端・末端・現在カーソル位置の表示座標を指定します。
##
function ble/textarea#render/.determine-scroll {
  local nline=$((endy+1))
  if ((nline>height)); then
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
    scroll=
    height=$nline
  fi
}
## 関数 ble/textarea#render/.perform-scroll new_scroll
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
      ble/canvas/put-dl.draw "$draw_shift"
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 "$scry"
      ble/canvas/put-il.draw "$draw_shift"

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
      ble/canvas/put-dl.draw "$draw_shift"
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 $((height-draw_shift))
      ble/canvas/put-il.draw "$draw_shift"

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
## 関数 ble/textarea#render/.show-scroll-at-first-line
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

## 関数 ble/textarea#render/.erase-rps1
##   @var[in] cols
##     rps1 の幅の分だけ減少させた後の cols を指定します。
function ble/textarea#render/.erase-rps1 {
  local rps1_height=${_ble_edit_rprompt_bbox[3]}
  local -a DRAW_BUFF=()
  local y=0
  for ((y=0;y<rps1_height;y++)); do
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" $((cols+1)) "$y"
    ble/canvas/put.draw "$_ble_term_el"
  done
  ble/canvas/bflush.draw
}
## 関数 ble/textarea#render/.cleanup-trailing-spaces-after-newline
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
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${pos[0]}" "${pos[1]}"
    ble/canvas/put.draw "$_ble_term_el"
    ((index++))
  done
  ble/canvas/bflush.draw
}

## 関数 ble/textarea#focus
##   プロンプト・編集文字列の現在位置に端末のカーソルを移動します。
function ble/textarea#focus {
  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_textarea_cur[0]}" "${_ble_textarea_cur[1]}"
  ble/canvas/bflush.draw
}

## 関数 ble/textarea#render opts
##   プロンプト・編集文字列の表示更新を ble/util/buffer に対して行う。
##   Post-condition: カーソル位置 (x y) = (_ble_textarea_cur[0] _ble_textarea_cur[1]) に移動する
##   Post-condition: 編集文字列部分の再描画を実行する
##
##   @param[in] opts
##     leave
##       bleopt rps1_transient が非空文字列の時、rps1 を消去します。
##
##   @var _ble_textarea_caret_state := inds ':' mark ':' mark_active ':' line_disabled ':' overwrite_mode
##     ble/textarea#render で用いる変数です。
##     現在の表示内容のカーソル位置・ポイント位置の情報を記録します。
##
_ble_textarea_caret_state=::
_ble_textarea_version=0
function ble/textarea#render {
  local opts=$1
  local ble_textarea_render_flag=1 # ble/textarea/panel#on-height-change から参照する

  local caret_state=$_ble_textarea_version:$_ble_edit_ind:$_ble_edit_mark:$_ble_edit_mark_active:$_ble_edit_line_disabled:$_ble_edit_overwrite_mode
  local dirty=
  if ((_ble_edit_dirty_draw_beg>=0)); then
    dirty=1
  elif [[ $_ble_textarea_invalidated ]]; then
    dirty=1
  elif [[ $_ble_textarea_caret_state != "$caret_state" ]]; then
    dirty=1
  elif [[ $_ble_textarea_scroll != "$_ble_textarea_scroll_new" ]]; then
    dirty=1
  elif [[ :$opts: == *:leave:* ]]; then
    dirty=1
  fi

  if [[ ! $dirty ]]; then
    ble/textarea#focus
    return
  fi

  #-------------------
  # 描画内容の計算 (配置情報、着色文字列)

  local ret
  local cols=${COLUMNS-80}

  # rps1: _ble_textarea_panel==1 の時だけ有効 #D1027
  local rps1_enabled=; [[ $bleopt_rps1 ]] && ((_ble_textarea_panel==0)) && rps1_enabled=1

  # rps1_transient
  local rps1_clear=
  if [[ $rps1_enabled && :$opts: == *:leave:* && $bleopt_rps1_transient ]]; then
    # Note: ble-edit/prompt/update を実行するよりも前に現在の表示内容を消去する。
    local rps1_width=${_ble_edit_rprompt_bbox[2]}
    if ((rps1_width&&20+rps1_width<cols&&prox+10+rps1_width<cols)); then
      rps1_clear=1
      ((cols-=rps1_width+1,_ble_term_xenl||cols--))
      ble/textarea#render/.erase-rps1
    fi
  fi

  local x y g lc lg=0
  ble-edit/prompt/update # x y lc ret
  local prox=$x proy=$y prolc=$lc esc_prompt=$ret

  # rps1
  local rps1_show=
  if [[ $rps1_enabled && ! $rps1_clear ]]; then
    local rps1_width=${_ble_edit_rprompt_bbox[2]}
    ((rps1_width&&20+rps1_width<cols&&prox+10+rps1_width<cols)) &&
      ((rps1_show=1,cols-=rps1_width+1,_ble_term_xenl||cols--))
  fi

  # BLELINE_RANGE_UPDATE → ble/textarea#update-text-buffer 内でこれを見て update を済ませる
  local -a BLELINE_RANGE_UPDATE
  BLELINE_RANGE_UPDATE=("$_ble_edit_dirty_draw_beg" "$_ble_edit_dirty_draw_end" "$_ble_edit_dirty_draw_end0")
  ble/dirty-range#clear --prefix=_ble_edit_dirty_draw_
#%if !release
  ble/util/assert '((BLELINE_RANGE_UPDATE[0]<0||(
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[1]&&
       BLELINE_RANGE_UPDATE[0]<=BLELINE_RANGE_UPDATE[2])))' "(${BLELINE_RANGE_UPDATE[*]})"
#%end

  # local graphic_dbeg graphic_dend graphic_dend0
  # ble/dirty-range#update --prefix=graphic_d

  # 編集内容の構築
  local text=$_ble_edit_str index=$_ble_edit_ind
  local iN=${#text}
  ((index<0?(index=0):(index>iN&&(index=iN))))

  local umin=-1 umax=-1

  # 配置情報の更新
  local render_opts=
  [[ $rps1_show ]] && render_opts=relative
  COLUMNS=$cols ble/textmap#update "$text" "$render_opts"
  ble/urange#update "$_ble_textmap_umin" "$_ble_textmap_umax"
  ble/urange#clear --prefix=_ble_textmap_

  # 着色の更新
  ble/textarea#update-text-buffer # text index -> lc lg

  #-------------------
  # 描画領域の決定とスクロール

  local -a DRAW_BUFF=()
  ble/canvas/panel#reallocate-height.draw

  # 1 描画領域の決定
  local begx=$_ble_textmap_begx begy=$_ble_textmap_begy
  local endx=$_ble_textmap_endx endy=$_ble_textmap_endy
  local cx cy
  ble/textmap#getxy.cur --prefix=c "$index" # → cx cy

  local cols=$_ble_textmap_cols
  local height=${_ble_canvas_panel_height[_ble_textarea_panel]}
  local scroll=${_ble_textarea_scroll_new:-$_ble_textarea_scroll}
  ble/textarea#render/.determine-scroll # update: height scroll umin umax
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" "$height"

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

  [[ $rps1_clear ]] &&
    ble/textarea#render/.cleanup-trailing-spaces-after-newline

  # 2 表示内容
  local ret esc_line= esc_line_set=
  if [[ ! $_ble_textarea_invalidated ]]; then
    # 部分更新の場合

    # スクロール
    ble/textarea#render/.perform-scroll "$scroll" # update: umin umax
    _ble_textarea_scroll_new=$_ble_textarea_scroll

    # 編集文字列の一部を描画する場合
    if ((umin<umax)); then
      local uminx uminy umaxx umaxy
      ble/textmap#getxy.out --prefix=umin "$umin"
      ble/textmap#getxy.out --prefix=umax "$umax"

      ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$uminx" $((uminy-_ble_textarea_scroll))
      ble/textarea#slice-text-buffer "$umin" "$umax"
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$ret" "$umaxx" $((umaxy-_ble_textarea_scroll))
    fi

    if ((BLELINE_RANGE_UPDATE[0]>=0)); then
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

    # プロンプト描画
    ble/canvas/panel#goto.draw "$_ble_textarea_panel"
    if [[ $rps1_show ]]; then
      local rps1out=${_ble_edit_rprompt[6]}
      local rps1x=${_ble_edit_rprompt[1]} rps1y=${_ble_edit_rprompt[2]}
      # Note: cols は画面右端ではなく textmap の右端
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" $((cols+1)) 0
      ble/canvas/panel#put.draw "$_ble_textarea_panel" "$rps1out" $((cols+1+rps1x)) "$rps1y"
      ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
    fi
    ble/canvas/panel#put.draw "$_ble_textarea_panel" "$esc_prompt" "$prox" "$proy"

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

    _ble_textarea_cache=(
      "$esc_prompt$esc_line"
      "${_ble_textarea_cur[@]}"
      "$_ble_textarea_gendx" "$_ble_textarea_gendy")
  fi
}
function ble/textarea#redraw {
  ble/textarea#invalidate
  ble/textarea#render
}

## 配列 _ble_textarea_cache
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

## 関数 ble/textarea#adjust-for-bash-bind
##   プロンプト・編集文字列の表示位置修正を行う。
##
## @remarks
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
  if [[ $bleopt_internal_suppress_bash_output ]]; then
    PS1= READLINE_LINE=$'\n' READLINE_POINT=0
  else
    # bash が表示するプロンプトを見えなくする
    # (現在のカーソルの左側にある文字を再度上書きさせる)
    local -a DRAW_BUFF=()
    PS1=
    local ret lc=${_ble_textarea_cur[2]} lg=${_ble_textarea_cur[3]}
    ble/util/c2s "$lc"
    READLINE_LINE=$ret
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
  local -a vars=() arrs=()

  # _ble_edit_prompt
  ble/array#push arrs _ble_edit_prompt
  ble/array#push vars _ble_edit_PS1

  # _ble_edit_*
  ble/array#push vars "${_ble_edit_VARNAMES[@]}"
  ble/array#push arrs "${_ble_edit_ARRNAMES[@]}"

  # _ble_edit_undo_*
  ble/array#push vars "${_ble_edit_undo_VARNAMES[@]}"
  ble/array#push arrs "${_ble_edit_undo_ARRNAMES[@]}"

  # _ble_textmap_*
  ble/array#push vars "${_ble_textmap_VARNAMES[@]}"
  ble/array#push arrs "${_ble_textmap_ARRNAMES[@]}"

  # _ble_highlight_layer_*
  ble/array#push arrs _ble_highlight_layer__list
  local layer names
  for layer in "${_ble_highlight_layer__list[@]}"; do
    eval "names=(\"\${!_ble_highlight_layer_$layer@}\")"
    for name in "${names[@]}"; do
      if ble/is-array "$name"; then
        ble/array#push arrs "$name"
      else
        ble/array#push vars "$name"
      fi
    done
  done

  # _ble_textarea_*
  ble/array#push vars "${_ble_textarea_VARNAMES[@]}"
  ble/array#push arrs "${_ble_textarea_ARRNAMES[@]}"

  # _ble_syntax_*
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"
  ble/array#push arrs "${_ble_syntax_ARRNAMES[@]}"

  eval "${prefix}_VARNAMES=(\"\${vars[@]}\")"
  eval "${prefix}_ARRNAMES=(\"\${arrs[@]}\")"
  ble/util/save-vars "$prefix" "${vars[@]}"
  ble/util/save-arrs "$prefix" "${arrs[@]}"
}
function ble/textarea#restore-state {
  local prefix=$1
  if eval "[[ \$prefix && \${${prefix}_VARNAMES+set} && \${${prefix}_ARRNAMES+set} ]]"; then
    eval "ble/util/restore-vars $prefix \"\${${prefix}_VARNAMES[@]}\""
    eval "ble/util/restore-arrs $prefix \"\${${prefix}_ARRNAMES[@]}\""
  else
    echo "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}
function ble/textarea#clear-state {
  local prefix=$1
  if [[ $prefix ]]; then
    local vars=${prefix}_VARNAMES arrs=${prefix}_ARRNAMES
    eval "unset -v \"\${$vars[@]/#/$prefix}\" \"\${$arrs[@]/#/$prefix}\" $vars $arrs"
  else
    echo "ble/textarea#restore-state: unknown prefix '$prefix'." >&2
    return 1
  fi
}

# 
# **** redraw, clear-screen, etc ****                             @widget.clear

function ble/widget/.update-textmap {
  local text=$_ble_edit_str x=$_ble_textmap_begx y=$_ble_textmap_begy
  ble/textmap#update "$text"
}
function ble/widget/redraw-line {
  ble-edit/content/clear-arg
  ble/textarea#invalidate
}
function ble/widget/clear-screen {
  ble-edit/content/clear-arg
  ble-edit/info/hide
  ble/textarea#invalidate
  ble/util/buffer "$_ble_term_clear"
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/term/visible-bell/cancel-erasure
}
function ble/widget/display-shell-version {
  ble-edit/content/clear-arg
  ble/widget/print "GNU bash, version $BASH_VERSION ($MACHTYPE) with ble.sh"
}

# 
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
  ((_ble_edit_ind>=${#_ble_edit_str})) && return

  _ble_edit_kill_ring=${_ble_edit_str:_ble_edit_ind}
  _ble_edit_kill_type=
  ble-edit/content/replace "$_ble_edit_ind" ${#_ble_edit_str} ''
  ((_ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark=_ble_edit_ind)))
}
function ble/widget/kill-backward-text {
  ble-edit/content/clear-arg
  ((_ble_edit_ind==0)) && return
  _ble_edit_kill_ring=${_ble_edit_str::_ble_edit_ind}
  _ble_edit_kill_type=
  ble-edit/content/replace 0 "$_ble_edit_ind" ''
  ((_ble_edit_mark=_ble_edit_mark<=_ble_edit_ind?0:_ble_edit_mark-_ble_edit_ind))
  _ble_edit_ind=0
}
function ble/widget/exchange-point-and-mark {
  ble-edit/content/clear-arg
  local m=$_ble_edit_mark p=$_ble_edit_ind
  _ble_edit_ind=$m _ble_edit_mark=$p
}
function ble/widget/yank {
  ble-edit/content/clear-arg
  ble/widget/.insert-string "$_ble_edit_kill_ring"
}
function ble/widget/@marked {
  if [[ $_ble_edit_mark_active != S ]]; then
    _ble_edit_mark=$_ble_edit_ind
    _ble_edit_mark_active=S
  fi
  "ble/widget/$@"
}
function ble/widget/@nomarked {
  if [[ $_ble_edit_mark_active == S ]]; then
    _ble_edit_mark_active=
  fi
  "ble/widget/$@"
}

## 関数 ble/widget/.process-range-argument P0 P1; p0 p1 len ?
## @param[in]  P0  範囲の端点を指定します。
## @param[in]  P1  もう一つの範囲の端点を指定します。
## @param[out] p0  範囲の開始点を返します。
## @param[out] p1  範囲の終端点を返します。
## @param[out] len 範囲の長さを返します。
## @param[out] $?
##   範囲が有限の長さを持つ場合に正常終了します。
##   範囲が空の場合に 1 を返します。
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
## 関数 ble/widget/.delete-range P0 P1 [allow_empty]
function ble/widget/.delete-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

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
## 関数 ble/widget/.kill-range P0 P1 [allow_empty [kill_type]]
function ble/widget/.kill-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

  # copy
  _ble_edit_kill_ring=${_ble_edit_str:p0:len}
  _ble_edit_kill_type=$4

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
## 関数 ble/widget/.copy-range P0 P1 [allow_empty [kill_type]]
function ble/widget/.copy-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($3)) || return 1

  # copy
  _ble_edit_kill_ring=${_ble_edit_str:p0:len}
  _ble_edit_kill_type=$4
}
## 関数 ble/widget/.replace-range P0 P1 string [allow_empty]
function ble/widget/.replace-range {
  local p0 p1 len
  ble/widget/.process-range-argument "${@:1:2}" || (($4)) || return 1
  local str=$3 strlen=${#3}

  ble-edit/content/replace "$p0" "$p1" "$str"
  local delta
  ((delta=strlen-len)) &&
    ((_ble_edit_ind>p1?(_ble_edit_ind+=delta):
      _ble_edit_ind>p0+strlen&&(_ble_edit_ind=p0+strlen),
      _ble_edit_mark>p1?(_ble_edit_mark+=delta):
      _ble_edit_mark>p0+strlen&&(_ble_edit_mark=p0+strlen)))
  return 0
}
## 関数 ble/widget/delete-region
##   領域を削除します。
function ble/widget/delete-region {
  ble-edit/content/clear-arg
  ble/widget/.delete-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/kill-region
##   領域を切り取ります。
function ble/widget/kill-region {
  ble-edit/content/clear-arg
  ble/widget/.kill-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/copy-region
##   領域を転写します。
function ble/widget/copy-region {
  ble-edit/content/clear-arg
  ble/widget/.copy-range "$_ble_edit_mark" "$_ble_edit_ind"
  _ble_edit_mark_active=
}
## 関数 ble/widget/delete-region-or type
##   領域または引数に指定した単位を削除します。
##   mark が active な場合には領域の削除を行います。
##   それ以外の場合には第一引数に指定した単位の削除を実行します。
## @param[in] type
##   mark が active でない場合に実行される削除の単位を指定します。
##   実際には ble-edit 関数 delete-type が呼ばれます。
function ble/widget/delete-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/delete-region
  else
    "ble/widget/delete-$@"
  fi
}
## 関数 ble/widget/kill-region-or type
##   領域または引数に指定した単位を切り取ります。
##   mark が active な場合には領域の切り取りを行います。
##   それ以外の場合には第一引数に指定した単位の切り取りを実行します。
## @param[in] type
##   mark が active でない場合に実行される切り取りの単位を指定します。
##   実際には ble-edit 関数 kill-type が呼ばれます。
function ble/widget/kill-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/kill-region
  else
    "ble/widget/kill-$@"
  fi
}
## 関数 ble/widget/copy-region-or type
##   領域または引数に指定した単位を転写します。
##   mark が active な場合には領域の転写を行います。
##   それ以外の場合には第一引数に指定した単位の転写を実行します。
## @param[in] type
##   mark が active でない場合に実行される転写の単位を指定します。
##   実際には ble-edit 関数 copy-type が呼ばれます。
function ble/widget/copy-region-or {
  if [[ $_ble_edit_mark_active ]]; then
    ble/widget/copy-region
  else
    "ble/widget/copy-$@"
  fi
}

# 
# **** bell ****                                                     @edit.bell

function ble/widget/.bell {
  [[ $bleopt_edit_vbell ]] && ble/term/visible-bell "$1"
  [[ $bleopt_edit_abell ]] && ble/term/audible-bell
  return 0
}

_ble_widget_bell_hook=()
function ble/widget/bell {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_arg=
  ble/util/invoke-hook _ble_widget_bell_hook
  ble/widget/.bell "$1"
}

function ble/widget/nop { :; }

# 
# **** insert ****                                                 @edit.insert

function ble/widget/insert-string {
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
  local ins="$*"
  [[ $ins ]] || return

  local dx=${#ins}
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
  (('
    _ble_edit_mark>_ble_edit_ind&&(_ble_edit_mark+=dx),
    _ble_edit_ind+=dx
  '))
  _ble_edit_mark_active=
}

## 編集関数 self-insert
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
  ((code==0)) && return

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
    ((arg==0&&ibeg==iend)) && return
  elif [[ $_ble_edit_overwrite_mode ]] && ((code!=10&&code!=9)); then
    ((arg==0)) && return

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
        ble/util/s2c "$_ble_edit_str" "$iend"; c1=$ret
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

  ble-edit/content/replace "$ibeg" "$iend" "$ins"
  ((_ble_edit_ind+=${#ins},
    _ble_edit_mark>ibeg&&(
      _ble_edit_mark<iend?(
        _ble_edit_mark=_ble_edit_ind
      ):(
        _ble_edit_mark+=${#ins}-(iend-ibeg)))))
  _ble_edit_mark_active=
  return 0
}

function ble/widget/batch-insert {
  local -a chars; chars=("${KEYS[@]}")

  if [[ $_ble_edit_overwrite_mode ]]; then
    local -a KEYS=(0)
    local char
    for char in "${chars[@]}"; do
      KEYS=$char ble/widget/self-insert
    done

  else
    local index=0 N=${#chars[@]}
    while ((index<N)) && [[ $_ble_edit_arg || $_ble_edit_mark_active ]]; do
      KEYS=${chars[index]} ble/widget/self-insert
      ((index++))
    done

    if ((index<N)); then
      local ret ins=
      while ((index<N)); do
        ble/util/c2s "${chars[index]}"; ins=$ins$ret
        ((index++))
      done
      ble/widget/insert-string "$ins"
    fi
  fi
}


# quoted insert
function ble/widget/quoted-insert.hook {
  ble/widget/self-insert
}
function ble/widget/quoted-insert {
  _ble_edit_mark_active=
  _ble_decode_char__hook=ble/widget/quoted-insert.hook
  return 148
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

_ble_edit_bracketed_paste=
_ble_edit_bracketed_paste_proc=
function ble/widget/bracketed-paste {
  ble-edit/content/clear-arg
  _ble_edit_mark_active=
  _ble_edit_bracketed_paste=()
  _ble_edit_bracketed_paste_proc=ble/widget/bracketed-paste.proc
  _ble_decode_char__hook=ble/widget/bracketed-paste.hook
  return 148
}
function ble/widget/bracketed-paste.hook {
  _ble_edit_bracketed_paste=$_ble_edit_bracketed_paste:$1

  # check terminater
  local is_end= chars=
  if chars=${_ble_edit_bracketed_paste%:27:91:50:48:49:126} # ESC [ 2 0 1 ~
     [[ $chars != "$_ble_edit_bracketed_paste" ]]; then is_end=1
  elif chars=${_ble_edit_bracketed_paste%:155:50:48:49:126} # CSI 2 0 1 ~
       [[ $chars != "$_ble_edit_bracketed_paste" ]]; then is_end=1
  fi

  if [[ ! $is_end ]]; then
    _ble_decode_char__hook=ble/widget/bracketed-paste.hook
    return 148
  fi

  chars=$chars:
  chars=${chars//:13:10:/:10:} # CR LF -> LF
  chars=${chars//:13:/:10:} # CR -> LF
  chars=(${chars//:/' '})

  local proc=$_ble_edit_bracketed_paste_proc
  _ble_edit_bracketed_paste_proc=
  [[ $proc ]] && builtin eval -- "$proc \"\${chars[@]}\""
}
function ble/widget/bracketed-paste.proc {
  local -a KEYS; KEYS=("$@")
  ble/widget/batch-insert
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
          ble/util/s2c "$_ble_edit_str" $((_ble_edit_ind-a+i))
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
    ble/widget/.delete-backward-char $((-a))
    return
  else
    # delete-forward-backward-char
    if ((${#_ble_edit_str}==0)); then
      return 1
    elif ((_ble_edit_ind<${#_ble_edit_str})); then
      ble-edit/content/replace "$_ble_edit_ind" $((_ble_edit_ind+1)) ''
    else
      _ble_edit_ind=${#_ble_edit_str}
      ble/widget/.delete-backward-char 1
      return
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
    return
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
      ble/widget/internal-command "echo '${_ble_term_setaf[12]}[ble: ${message//$q/$Q}]$_ble_term_sgr0'; jobs"
      return
    fi
  elif [[ :$opts: == *:checkjobs:* ]]; then
    local joblist
    ble/util/joblist
    ((${#joblist[@]})) && printf '%s\n' "${#joblist[@]}"
  fi

  #_ble_edit_detach_flag=exit

  #ble/term/visible-bell ' Bye!! ' # 最後に vbell を出すと一時ファイルが残る
  _ble_edit_line_disabled=1 ble/textarea#render

  # Note: ble_debug=1 の時 ble/textarea#render の中で info が設定されるので、
  #   これは ble/textarea#render より後である必要がある。
  ble-edit/info/hide

  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
  ble/canvas/bflush.draw
  ble/util/buffer.print "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0"
  ble/util/buffer.flush >&2

  # Note: ジョブが残っている場合でも強制終了させる為 2 回連続で呼び出す必要がある。
  builtin exit "$ext" &>/dev/null
  builtin exit "$ext" &>/dev/null
  return 1
}
function ble/widget/delete-forward-char-or-exit {
  if [[ $_ble_edit_str ]]; then
    ble/widget/delete-forward-char
    return
  else
    ble/widget/exit
  fi
}
function ble/widget/delete-forward-backward-char {
  ble-edit/content/clear-arg
  ble/widget/.delete-char 0 || ble/widget/.bell
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
  ((arg==0)) && return
  ble/widget/.forward-char "$arg" || ble/widget/.bell
}
function ble/widget/backward-char {
  local arg; ble-edit/content/get-arg 1
  ((arg==0)) && return
  ble/widget/.forward-char $((-arg)) || ble/widget/.bell
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

## 編集関数 ble/widget/kill-backward-logical-line
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
## 編集関数 ble/widget/kill-forward-logical-line
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
    ((ret<${#_ble_edit_ind}&&_ble_edit_ind==ret&&ret++))
  fi
  ble/widget/.kill-range "$_ble_edit_ind" "$ret"
}

function ble/widget/forward-history-line.impl {
  local arg=$1
  ((arg==0)) && return 0

  local rest=$((arg>0?arg:-arg))
  if ((arg>0)); then
    if [[ ! $_ble_edit_history_prefix && ! $_ble_edit_history_loaded ]]; then
      # 履歴を未だロードしていないので次の項目は存在しない
      ble/widget/.bell 'end of history'
      return 1
    fi
  fi

  local index; ble-edit/history/get-index

  local expr_next='--index>=0'
  if ((arg>0)); then
    local count; ble-edit/history/get-count
    expr_next="++index<=$count"
  fi

  while ((expr_next)); do
    if ((--rest<=0)); then
      ble-edit/history/goto "$index" # 位置は goto に任せる
      return
    fi

    local entry; ble-edit/history/get-editted-entry "$index"
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
        return
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

## 関数 ble/widget/forward-logical-line.impl arg opts
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
    return
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

## 関数 ble/keymap:emacs/find-graphical-eol [index [offset]]
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

## 編集関数 ble/widget/kill-backward-graphical-line
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
## 編集関数 ble/widget/kill-forward-graphical-line
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
    return
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
  if ble/edit/use-textmap; then
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
  if ble/edit/use-textmap; then
    ble/widget/end-of-graphical-line
  else
    ble/widget/end-of-logical-line
  fi
}
function ble/widget/kill-backward-line {
  if ble/edit/use-textmap; then
    ble/widget/kill-backward-graphical-line
  else
    ble/widget/kill-backward-logical-line
  fi
}
function ble/widget/kill-forward-line {
  if ble/edit/use-textmap; then
    ble/widget/kill-forward-graphical-line
  else
    ble/widget/kill-forward-logical-line
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

function ble/widget/.genword-setup-cword {
  WSET='_a-zA-Z0-9'; WSEP="^$WSET"
}
function ble/widget/.genword-setup-uword {
  WSEP="${IFS:-$' \t\n'}"; WSET="^$WSEP"
}
function ble/widget/.genword-setup-sword {
  WSEP=$'|%WSEP%;()<> \t\n'; WSET="^$WSEP"
}
function ble/widget/.genword-setup-fword {
  WSEP="/${IFS:-$' \t\n'}"; WSET="^$WSEP"
}

## 関数 ble/widget/.locate-backward-genword; a b c
##   後方の単語を探索します。
##
##   |---|www|---|
##   a   b   c   x
##
##   @var[in] WSET,WSEP
##   @var[out] a,b,c
##
function ble/widget/.locate-backward-genword {
  local x=${1:-$_ble_edit_ind}
  c=${_ble_edit_str::x}; c=${c##*[$WSET]}; c=$((x-${#c}))
  b=${_ble_edit_str::c}; b=${b##*[$WSEP]}; b=$((c-${#b}))
  a=${_ble_edit_str::b}; a=${a##*[$WSET]}; a=$((b-${#a}))
}
## 関数 ble/widget/.locate-backward-genword; s t u
##   前方の単語を探索します。
##
##   |---|www|---|
##   x   s   t   u
##
##   @var[in] WSET,WSEP
##   @var[out] s,t,u
##
function ble/widget/.locate-forward-genword {
  local x=${1:-$_ble_edit_ind}
  s=${_ble_edit_str:x}; s=${s%%[$WSET]*}; s=$((x+${#s}))
  t=${_ble_edit_str:s}; t=${t%%[$WSEP]*}; t=$((s+${#t}))
  u=${_ble_edit_str:t}; u=${u%%[$WSET]*}; u=$((t+${#u}))
}
## 関数 ble/widget/.locate-backward-genword; s t u
##   現在位置の単語を探索します。
##
##   |---|wwww|---|
##   r   s    t   u
##        <- x --->
##
##   @var[in] WSET,WSEP
##   @var[out] s,t,u
##
function ble/widget/.locate-current-genword {
  local x=${1:-$_ble_edit_ind}

  local a b c # <a> *<b>w*<c> *<x>
  ble/widget/.locate-backward-genword

  r=$a
  ble/widget/.locate-forward-genword "$r"
}


## 関数 ble/widget/.delete-forward-genword
##   前方の unix word を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-forward-genword {
  # |---|www|---|
  # x   s   t   u
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  if ((x!=t)); then
    ble/widget/.delete-range "$x" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.delete-backward-genword
##   後方の単語を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-backward-genword {
  # |---|www|---|
  # a   b   c   x
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  if ((x>c&&(c=x),b!=c)); then
    # keymap/vi.sh (white list に登録されている編集関数)
    [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more

    ble/widget/.delete-range "$b" "$c"

    # keymap/vi.sh (white list に登録されている編集関数)
    [[ $_ble_decode_keymap == vi_imap ]] && ble/keymap:vi/undo/add more
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.delete-genword
##   現在位置の単語を削除します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.delete-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  if ((x>t&&(t=x),r!=t)); then
    ble/widget/.delete-range "$r" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-forward-genword
##   前方の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-forward-genword {
  # <x> *<s>w*<t> *<u>
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  if ((x!=t)); then
    ble/widget/.kill-range "$x" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-backward-genword
##   後方の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-backward-genword {
  # <a> *<b>w*<c> *<x>
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  if ((x>c&&(c=x),b!=c)); then
    ble/widget/.kill-range "$b" "$c"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.kill-genword
##   現在位置の単語を切り取ります。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.kill-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  if ((x>t&&(t=x),r!=t)); then
    ble/widget/.kill-range "$r" "$t"
  else
    ble/widget/.bell
  fi
}
## 関数 ble/widget/.copy-forward-genword
##   前方の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-forward-genword {
  # <x> *<s>w*<t> *<u>
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword
  ble/widget/.copy-range "$x" "$t"
}
## 関数 ble/widget/.copy-backward-genword
##   後方の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-backward-genword {
  # <a> *<b>w*<c> *<x>
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword
  ble/widget/.copy-range "$b" $((c>x?c:x))
}
## 関数 ble/widget/.copy-genword
##   現在位置の単語を転写します。
##
##   @var[in] WSET,WSEP
##
function ble/widget/.copy-genword {
  local x=${1:-$_ble_edit_ind} r s t u
  ble/widget/.locate-current-genword "$x"
  ble/widget/.copy-range "$r" $((t>x?t:x))
}
## 関数 ble/widget/.forward-genword
##
##   @var[in] WSET,WSEP
##
function ble/widget/.forward-genword {
  local x=${1:-$_ble_edit_ind} s t u
  ble/widget/.locate-forward-genword "$x"
  if ((x==t)); then
    ble/widget/.bell
  else
    _ble_edit_ind=$t
  fi
}
## 関数 ble/widget/.backward-genword
##
##   @var[in] WSET,WSEP
##
function ble/widget/.backward-genword {
  local a b c x=${1:-$_ble_edit_ind}
  ble/widget/.locate-backward-genword "$x"
  if ((x==b)); then
    ble/widget/.bell
  else
    _ble_edit_ind=$b
  fi
}

# 
#%m kill-xword

# generic word

## 関数 ble/widget/delete-forward-xword
##   前方の generic word を削除します。
function ble/widget/delete-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-forward-genword "$@"
}
## 関数 ble/widget/delete-backward-xword
##   後方の generic word を削除します。
function ble/widget/delete-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-backward-genword "$@"
}
## 関数 ble/widget/delete-xword
##   現在位置の generic word を削除します。
function ble/widget/delete-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.delete-genword "$@"
}
## 関数 ble/widget/kill-forward-xword
##   前方の generic word を切り取ります。
function ble/widget/kill-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-forward-genword "$@"
}
## 関数 ble/widget/kill-backward-xword
##   後方の generic word を切り取ります。
function ble/widget/kill-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-backward-genword "$@"
}
## 関数 ble/widget/kill-xword
##   現在位置の generic word を切り取ります。
function ble/widget/kill-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.kill-genword "$@"
}
## 関数 ble/widget/copy-forward-xword
##   前方の generic word を転写します。
function ble/widget/copy-forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-forward-genword "$@"
}
## 関数 ble/widget/copy-backward-xword
##   後方の generic word を転写します。
function ble/widget/copy-backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-backward-genword "$@"
}
## 関数 ble/widget/copy-xword
##   現在位置の generic word を転写します。
function ble/widget/copy-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.copy-genword "$@"
}
#%end
#%x kill-xword .r/generic word/unix word/  .r/xword/cword/
#%x kill-xword .r/generic word/c word/     .r/xword/uword/
#%x kill-xword .r/generic word/shell word/ .r/xword/sword/
#%x kill-xword .r/generic word/filename/   .r/xword/fword/

#%m forward-xword (
function ble/widget/forward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.forward-genword "$@"
}
function ble/widget/backward-xword {
  ble-edit/content/clear-arg
  local WSET WSEP; ble/widget/.genword-setup-xword
  ble/widget/.backward-genword "$@"
}
#%)
#%x forward-xword .r/generic word/unix word/  .r/xword/cword/
#%x forward-xword .r/generic word/c word/     .r/xword/uword/
#%x forward-xword .r/generic word/shell word/ .r/xword/sword/

#------------------------------------------------------------------------------
# **** ble-edit/exec ****                                            @edit.exec

_ble_edit_exec_lines=()
_ble_edit_exec_lastexit=0
_ble_edit_exec_lastarg=$BASH
function ble-edit/exec/register {
  local BASH_COMMAND=$1
  ble/array#push _ble_edit_exec_lines "$1"
}
function ble-edit/exec/.setexit {
  # $? 変数の設定
  return "$_ble_edit_exec_lastexit"
}
## 関数 ble-edit/exec/.adjust-eol
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
    ble/canvas/put.draw "$_ble_term_sc"
    if ((_ble_edit_exec_eol_mark[2]>cols)); then
      local x=0 y=0 g=0
      LINES=1 COLUMNS=$cols ble/canvas/trace.draw "$bleopt_prompt_eol_mark" truncate
    else
      ble/canvas/put.draw "$eol_mark"
    fi
    ble/canvas/put.draw "$_ble_term_sgr0$_ble_term_rc"
  fi
  ble/canvas/put-cuf.draw $((_ble_term_xenl?cols-2:cols-3))
  ble/canvas/put.draw "  $_ble_term_cr$_ble_term_el"
  ble/canvas/bflush.draw
}

function ble-edit/exec/.reset-builtins-1 {
  # Note: 何故か local POSIXLY_CORRECT の効果が
  #   unset -v POSIXLY_CORRECT しても残存するので関数に入れる。
  local POSIXLY_CORRECT=y
  local -a builtins1; builtins1=(builtin unset enable unalias)
  local -a builtins2; builtins2=(return break continue declare typeset local eval echo)
  local -a keywords1; keywords1=(if then elif else case esac while until for select do done '{' '}' '[[' function)
  builtin unset -f "${builtins1[@]}"
  builtin unset -f "${builtins2[@]}"
  builtin unalias "${builtins1[@]}" "${builtins2[@]}" "${keywords1[@]}"
  ble/base/unset-POSIXLY_CORRECT
}
function ble-edit/exec/.reset-builtins-2 {
  # Workaround (bash-3.0 - 4.3) #D0722
  #
  #   unset -v POSIXLY_CORRECT でないと unset -f : できないが、
  #   bash-3.0 -- 4.3 のバグで、local POSIXLY_CORRECT の時、
  #   unset -v POSIXLY_CORRECT しても POSIXLY_CORRECT が有効であると判断されるので、
  #   "unset -f :" (非POSIX関数名) は別関数で adjust-POSIXLY_CORRECT の後で実行することにする。
  #
  builtin unset -f :
}

_ble_edit_exec_BASH_REMATCH=()
_ble_edit_exec_BASH_REMATCH_rex=none

## 関数 ble-edit/exec/save-BASH_REMATCH/increase delta
##   @param[in] delta
##   @var[in,out] i rex
function ble-edit/exec/save-BASH_REMATCH/increase {
  local delta=$1
  ((delta)) || return
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
  ble-edit/exec/save-BASH_REMATCH/is-updated || return

  local size=${#BASH_REMATCH[@]}
  if ((size==0)); then
    _ble_edit_exec_BASH_REMATCH=()
    _ble_edit_exec_BASH_REMATCH_rex=none
    return
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
        unset -v 'rparens[r]'
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
    unset -v 'rparens[r]'
  done

  ble-edit/exec/save-BASH_REMATCH/increase $((${#text}-i))

  _ble_edit_exec_BASH_REMATCH=("${BASH_REMATCH[@]}")
  _ble_edit_exec_BASH_REMATCH_rex=$rex
}
function ble-edit/exec/restore-BASH_REMATCH {
  [[ $_ble_edit_exec_BASH_REMATCH =~ $_ble_edit_exec_BASH_REMATCH_rex ]]
}

function ble/builtin/exit {
  local ext=${1-$?}
  if ((BASHPID!=$$)) || [[ $_ble_decode_bind_state == none ]]; then
    builtin exit "$ext"
    return
  fi

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
      ([nN]|[nN][oO]|'')  return ;;
      esac
    done
  fi

  echo "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0" >&2
  builtin exit "$ext" &>/dev/null
  builtin exit "$ext" &>/dev/null
  return 1 # exit できなかった場合は 1 らしい
}

function exit { ble/builtin/exit "$@"; }

## 関数 _ble_edit_exec_lines= ble-edit/exec:$bleopt_internal_exec_type/process;
##   指定したコマンドを実行します。
## @param[in,out] _ble_edit_exec_lines
##   実行するコマンドの配列を指定します。実行したコマンドは削除するか空文字列を代入します。
## @return
##   戻り値が 0 の場合、終端 (ble-edit/bind/.tail) に対する処理も行われた事を意味します。
##   つまり、そのまま ble-decode/.hook から抜ける事を期待します。
##   それ以外の場合には終端処理をしていない事を表します。

#--------------------------------------
# bleopt_internal_exec_type = exec
#--------------------------------------

function ble-edit/exec:exec/.eval-TRAPINT {
  builtin echo >&2
  # echo "SIGINT ${FUNCNAME[1]}"
  if ((_ble_bash>=40300)); then
    _ble_edit_exec_INT=130
  else
    _ble_edit_exec_INT=128
  fi
  trap 'ble-edit/exec:exec/.eval-TRAPDEBUG SIGINT "$*" && return' DEBUG
}
function ble-edit/exec:exec/.eval-TRAPDEBUG {
  # 一旦 DEBUG を設定すると bind -x を抜けるまで削除できない様なので、
  # _ble_edit_exec_INT のチェックと _ble_edit_exec_in_eval のチェックを行う。
  if ((_ble_edit_exec_INT&&_ble_edit_exec_in_eval)); then
    builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2" >&2
    return 0
  else
    trap - DEBUG # 何故か効かない
    return 1
  fi
}

function ble-edit/exec:exec/.eval-prologue {
  ble-edit/exec/restore-BASH_REMATCH
  ble/base/restore-bash-options
  ble/base/restore-POSIXLY_CORRECT

  set -H

  # C-c に対して
  trap 'ble-edit/exec:exec/.eval-TRAPINT; return 128' INT
  # trap '_ble_edit_exec_INT=126; return 126' TSTP
}
function ble-edit/exec:exec/.save-last-arg {
  _ble_edit_exec_lastarg=$_ _ble_edit_exec_lastexit=$?
  ble/base/adjust-bash-options
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec:exec/.eval {
  # BASH_COMMAND に return が含まれていても大丈夫な様に関数内で評価
  local _ble_edit_exec_in_eval=1 nl=$'\n'
  ble-edit/exec/.setexit "$_ble_edit_exec_lastarg" # set $? and $_
  builtin eval -- "$BASH_COMMAND${nl}ble-edit/exec:exec/.save-last-arg"
}
function ble-edit/exec:exec/.eval-epilogue {
  trap - INT DEBUG # DEBUG 削除が何故か効かない

  ble/base/adjust-bash-options
  ble/base/adjust-POSIXLY_CORRECT
  _ble_edit_PS1=$PS1
  _ble_edit_IFS=$IFS
  ble-edit/adjust-IGNOREEOF
  ble-edit/exec/save-BASH_REMATCH
  ble-edit/exec/.adjust-eol

  # lastexit
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit=$_ble_edit_exec_INT
  fi
  if ((_ble_edit_exec_lastexit!=0)); then
    # SIGERR処理
    if type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      builtin echo "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0" >&2
    fi
  fi
}

## 関数 ble-edit/exec:exec/.recursive index
##   index 番目のコマンドを実行し、引数 index+1 で自己再帰します。
##   コマンドがこれ以上ない場合は何もせずに終了します。
## @param[in] index
function ble-edit/exec:exec/.recursive {
  (($1>=${#_ble_edit_exec_lines})) && return

  local BASH_COMMAND=${_ble_edit_exec_lines[$1]}
  _ble_edit_exec_lines[$1]=
  if [[ ${BASH_COMMAND//[ 	]/} ]]; then
    # 実行
    local PS1=$_ble_edit_PS1
    local IFS=$_ble_edit_IFS
    local IGNOREEOF; ble-edit/restore-IGNOREEOF
    local HISTCMD
    ble-edit/history/get-count -v HISTCMD

    local _ble_edit_exec_INT=0
    ble-edit/exec:exec/.eval-prologue
    ble-edit/exec:exec/.eval
    _ble_edit_exec_lastexit=$?
    ble-edit/exec:exec/.eval-epilogue
  fi

  ble-edit/exec:exec/.recursive $(($1+1))
}

_ble_edit_exec_replacedDeclare=
_ble_edit_exec_replacedTypeset=
function ble-edit/exec:exec/.isGlobalContext {
  local offset=$1

  local path
  for path in "${FUNCNAME[@]:offset+1}"; do
    # source or . が続く限りは遡る (. で呼び出しても FUNCNAME には source が入る様だ。)
    if [[ $path = ble-edit/exec:exec/.eval ]]; then
      return 0
    elif [[ $path != source ]]; then
      # source という名の関数を定義して呼び出している場合、source と区別が付かない。
      # しかし関数と組込では、組込という判定を優先する。
      # (理由は (1) 関数内では普通 local を使う事
      # (2) local になるべき物が global になるのと、
      # global になるべき物が local になるのでは前者の方がまし、という事)
      return 1
    fi
  done

  # BASH_SOURCE は source が関数か builtin か判定するのには使えない
  # local i iN=${#FUNCNAME[@]}
  # for ((i=offset;i<iN;i++)); do
  #   local func=${FUNCNAME[i]}
  #   local path=${BASH_SOURCE[i]}
  #   if [[ $func == ble-edit/exec:exec/.eval && $path == "$BASH_SOURCE" ]]; then
  #     return 0
  #   elif [[ $path != source && $path != "$BASH_SOURCE" ]]; then
  #     # source ble.sh の中の declare が全て local になるので上だと駄目。
  #     # しかしそもそも二重にロードしても大丈夫な物かは謎。
  #     return 1
  #   fi
  # done

  return 0
}

function ble-edit/exec:exec {
  [[ ${#_ble_edit_exec_lines[@]} -eq 0 ]] && return

  # コマンド内部で declare してもグローバルに定義されない。
  # bash-4.2 以降では -g オプションがあるので declare を上書きする。
  #
  # - -g は変数の作成・変更以外の場合は無視されると man に書かれているので、
  #   変数定義の参照などの場合に影響は与えない。
  # - 既に declare が定義されている場合には上書きはしない。
  #   custom declare に -g を渡す様に書き換えても良いが、
  #   custom declare に -g を指定した時に何が起こるか分からない。
  #   また、custom declare を待避・定義しなければならず実装が面倒。
  # - コマンド内で直接 declare をしているのか、
  #   関数内で declare をしているのかを判定する為に FUNCNAME 変数を使っている。
  #   但し、source という名の関数を定義して呼び出している場合は
  #   source している場合と区別が付かない。この場合は source しているとの解釈を優先させる。
  #
  # ※内部で declare() を上書きされた場合に対応していない。
  # ※builtin declare と呼び出された場合に対しては流石に対応しない
  #
  if ((_ble_bash>=40200)); then
    if ! builtin declare -f declare &>/dev/null; then
      _ble_edit_exec_replacedDeclare=1
      # declare() { builtin declare -g "$@"; }
      declare() {
        if ble-edit/exec:exec/.isGlobalContext 1; then
          builtin declare -g "$@"
        else
          builtin declare "$@"
        fi
      }
    fi
    if ! builtin declare -f typeset &>/dev/null; then
      _ble_edit_exec_replacedTypeset=1
      # typeset() { builtin typeset -g "$@"; }
      typeset() {
        if ble-edit/exec:exec/.isGlobalContext 1; then
          builtin typeset -g "$@"
        else
          builtin typeset "$@"
        fi
      }
    fi
  fi

  # ローカル変数を宣言すると実行されるコマンドから見えてしまう。
  # また、実行されるコマンドで定義される変数のスコープを制限する事にもなるので、
  # ローカル変数はできるだけ定義しない。
  # どうしても定義する場合は、予約識別子名として _ble_ で始まる名前にする。

  # 以下、配列 _ble_edit_exec_lines に登録されている各コマンドを順に実行する。
  # ループ構文を使うと、ループ構文自体がユーザの入力した C-z (SIGTSTP)
  # を受信して(?)停止してしまう様なので、再帰でループする必要がある。
  ble/term/leave
  ble/util/buffer.flush >&2
  ble-edit/exec:exec/.recursive 0
  ble/term/enter

  _ble_edit_exec_lines=()

  # C-c で中断した場合など以下が実行されないかもしれないが
  # 次の呼出の際にここが実行されるのでまあ許容する。
  if [[ $_ble_edit_exec_replacedDeclare ]]; then
    _ble_edit_exec_replacedDeclare=
    unset -f declare
  fi
  if [[ $_ble_edit_exec_replacedTypeset ]]; then
    _ble_edit_exec_replacedTypeset=
    unset -f typeset
  fi
}

function ble-edit/exec:exec/process {
  ble-edit/exec:exec
  ble-edit/bind/.check-detach
  return $?
}

#--------------------------------------
# bleopt_internal_exec_type = gexec
#--------------------------------------

function ble-edit/exec:gexec/.eval-TRAPINT {
  builtin echo >&2
  if ((_ble_bash>=40300)); then
    _ble_edit_exec_INT=130
  else
    _ble_edit_exec_INT=128
  fi
  trap 'ble-edit/exec:gexec/.eval-TRAPDEBUG SIGINT "$*" && { return &>/dev/null || break &>/dev/null;}' DEBUG
}
function ble-edit/exec:gexec/.eval-TRAPDEBUG {
  if ((_ble_edit_exec_INT!=0)); then
    # エラーが起きている時

    local IFS=$' \t\n'
    local depth=${#FUNCNAME[*]}
    local rex='^\ble-edit/exec:gexec/.'
    if ((depth>=2)) && ! [[ ${FUNCNAME[*]:depth-1} =~ $rex ]]; then
      # 関数内にいるが、ble-edit/exec:gexec/. の中ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 ${FUNCNAME[1]} $2" >&2
      return 0
    fi

    local rex='^(\ble-edit/exec:gexec/.|trap - )'
    if ((depth==1)) && ! [[ $BASH_COMMAND =~ $rex ]]; then
      # 一番外側で、ble-edit/exec:gexec/. 関数ではない時
      builtin echo "${_ble_term_setaf[9]}[ble: $1]$_ble_term_sgr0 $BASH_COMMAND $2" >&2
      return 0
    fi
  fi

  trap - DEBUG # 何故か効かない
  return 1
}
function ble-edit/exec:gexec/.begin {
  local IFS=$' \t\n'
  _ble_decode_bind_hook=
  ble/term/leave
  ble/util/buffer.flush >&2
  ble-edit/bind/stdout.on
  set -H

  # C-c に対して
  trap 'ble-edit/exec:gexec/.eval-TRAPINT' INT
}
function ble-edit/exec:gexec/.end {
  local IFS=$' \t\n'
  trap - INT DEBUG
  # ↑何故か効かないので、
  #   end の呼び出しと同じレベルで明示的に実行する。

  ble/util/joblist.flush >&2
  ble-edit/bind/.check-detach && return 0
  ble/term/enter
  ble-edit/bind/.tail # flush will be called here
}
function ble-edit/exec:gexec/.eval-prologue {
  local IFS=$' \t\n'
  BASH_COMMAND=$1
  ble-edit/restore-PS1
  ble-edit/restore-IGNOREEOF
  unset -v HISTCMD; ble-edit/history/get-count -v HISTCMD
  _ble_edit_exec_INT=0
  ble/util/joblist.clear
  ble-edit/exec/restore-BASH_REMATCH
  ble/base/restore-bash-options
  ble/base/restore-POSIXLY_CORRECT
  ble-edit/exec/.setexit # set $?
} &>/dev/null # set -x 対策 #D0930
function ble-edit/exec:gexec/.save-last-arg {
  _ble_edit_exec_lastarg=$_ _ble_edit_exec_lastexit=$?
  ble/base/adjust-bash-options
  return "$_ble_edit_exec_lastexit"
}
function ble-edit/exec:gexec/.eval-epilogue {
  # lastexit
  _ble_edit_exec_lastexit=$?
  ble-edit/exec/.reset-builtins-1
  if ((_ble_edit_exec_lastexit==0)); then
    _ble_edit_exec_lastexit=$_ble_edit_exec_INT
  fi
  _ble_edit_exec_INT=0

  local IFS=$' \t\n'
  trap - DEBUG # DEBUG 削除が何故か効かない

  ble/base/adjust-bash-options
  ble/base/adjust-POSIXLY_CORRECT
  ble-edit/exec/.reset-builtins-2
  ble-edit/adjust-IGNOREEOF
  ble-edit/adjust-PS1
  ble-edit/exec/save-BASH_REMATCH
  ble/util/reset-keymap-of-editing-mode
  ble-edit/exec/.adjust-eol

  if ((_ble_edit_exec_lastexit)); then
    # SIGERR処理
    if builtin type -t TRAPERR &>/dev/null; then
      TRAPERR
    else
      # Note: >&3 は set -x 対策による呼び出し元のリダイレクトと対応 #D0930
      builtin echo "${_ble_term_setaf[9]}[ble: exit $_ble_edit_exec_lastexit]$_ble_term_sgr0" >&3
    fi
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
  local -a buff
  local count=0
  buff[${#buff[@]}]=ble-edit/exec:gexec/.begin
  for cmd in "${_ble_edit_exec_lines[@]}"; do
    if [[ "$cmd" == *[^' 	']* ]]; then
      # Note: $_ble_edit_exec_lastarg は $_ を設定するためのものである。
      local prologue="ble-edit/exec:gexec/.eval-prologue '${cmd//$apos/$APOS}' \"\$_ble_edit_exec_lastarg\""
      buff[${#buff[@]}]="builtin eval -- '${prologue//$apos/$APOS}"
      buff[${#buff[@]}]="${cmd//$apos/$APOS}"
      buff[${#buff[@]}]="{ ble-edit/exec:gexec/.save-last-arg; } &>/dev/null'" # Note: &>/dev/null は set -x 対策 #D0930
      buff[${#buff[@]}]="{ ble-edit/exec:gexec/.eval-epilogue; } 3>&2 &>/dev/null"
      ((count++))

      # ※直接 $cmd と書き込むと文法的に破綻した物を入れた時に
      #   続きの行が実行されない事になってしまう。
    fi
  done
  _ble_edit_exec_lines=()

  ((count==0)) && return 1

  buff[${#buff[@]}]='trap - INT DEBUG' # trap - は一番外側でないと効かない様だ
  buff[${#buff[@]}]=ble-edit/exec:gexec/.end

  IFS=$'\n' builtin eval '_ble_decode_bind_hook="${buff[*]}"'
  return 0
}

function ble-edit/exec:gexec/process {
  ble-edit/exec:gexec/.setup
  return $?
}

# **** accept-line ****                                            @edit.accept

function ble/widget/.insert-newline {
  local opts=$1
  if [[ :$opts: == *:keep-info:* && $_ble_textarea_panel == 0 ]] &&
       ! ble/util/joblist.has-events
  then
    # 最終状態の描画
    ble/textarea#render leave

    # info を表示したまま行を挿入し、今までの panel 0 の内容を範囲外に破棄
    local -a DRAW_BUFF=()
    ble/canvas/panel#increase-height.draw "$_ble_textarea_panel" 1
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 $((_ble_textarea_gendy+1))
    ble/canvas/bflush.draw
  else
    # 最終状態の描画
    ble-edit/info/hide
    ble/textarea#render leave

    # 新しい描画領域
    local -a DRAW_BUFF=()
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "$_ble_textarea_gendx" "$_ble_textarea_gendy"
    ble/canvas/put.draw "$_ble_term_nl"
    ble/canvas/bflush.draw
    ble/util/joblist.bflush
  fi

  # 描画領域情報の初期化
  ble/textarea#invalidate
  _ble_canvas_x=0 _ble_canvas_y=0
  _ble_textarea_gendx=0 _ble_textarea_gendy=0
  _ble_canvas_panel_height[_ble_textarea_panel]=1
}
function ble/widget/.hide-current-line {
  ble-edit/info/hide
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

## 関数 ble/widget/.newline opts
##   @param[in] opts
##     コロン区切りのオプションです。
##     keep-info
##       info を隠さずに表示したままにします。
function ble/widget/.newline {
  local opts=$1
  _ble_edit_mark_active=

  # (for lib/core-complete.sh layer:menu_filter)
  if [[ $_ble_complete_menu_active ]]; then
    _ble_complete_menu_active=
    [[ $_ble_highlight_layer_menu_filter_beg ]] &&
      ble/textarea#invalidate str # (#D0995)
  fi

  ble/widget/.insert-newline "$opts"
  ((LINENO=++_ble_edit_LINENO))

  ble-edit/history/onleave.fire
  ble/widget/.newline/clear-content
}

function ble/widget/discard-line {
  ble-edit/content/clear-arg
  _ble_edit_line_disabled=1 ble/widget/.newline keep-info
  ble/textarea#render
}

if ((_ble_bash>=30100)); then
  function ble/edit/hist_expanded/.core {
    builtin history -p -- "$BASH_COMMAND"
  }
else
  # Workaround for bash-3.0 bug (see memo.txt#D0233, #D0801)
  function ble/edit/hist_expanded/.core {
    # Note: history -p '' によって 履歴項目が減少するかどうかをチェックし、
    #   もし履歴項目が減る状態になっている場合は履歴項目を増やしてから history -p を実行する。
    #   嘗てはサブシェルで評価していたが、そうすると置換指示子が記録されず
    #   :& が正しく実行されないことになるのでこちらの実装に切り替える。
    local line1= line2=
    ble/util/assign line1 'HISTTIMEFORMAT= builtin history 1'
    builtin history -p -- '' &>/dev/null
    ble/util/assign line2 'HISTTIMEFORMAT= builtin history 1'
    if [[ $line1 != "$line2" ]]; then
      local rex_head='^[[:space:]]*[0-9]+[[:space:]]*'
      [[ $line1 =~ $rex_head ]] &&
        line1=${line1:${#BASH_REMATCH}}

      local tmp=$_ble_base_run/$$.ble_edit_history_add.txt
      printf '%s\n' "$line1" "$line1" >| "$tmp"
      builtin history -r "$tmp"
    fi

    builtin history -p -- "$BASH_COMMAND"
  }
fi

function ble-edit/hist_expanded/.expand {
  ble/edit/hist_expanded/.core 2>/dev/null; local ext=$?
  ((ext)) && echo "$BASH_COMMAND"
  builtin echo -n :
  return "$ext"
}

## @var[out] hist_expanded
function ble-edit/hist_expanded.update {
  local BASH_COMMAND="$*"
  if [[ ! -o histexpand || ! ${BASH_COMMAND//[ 	]} ]]; then
    hist_expanded=$BASH_COMMAND
    return 0
  elif ble/util/assign hist_expanded 'ble-edit/hist_expanded/.expand'; then
    hist_expanded=${hist_expanded%$_ble_term_nl:}
    return 0
  else
    hist_expanded=$BASH_COMMAND
    return 1
  fi
}

function ble/widget/accept-line {
  ble-edit/content/clear-arg
  local BASH_COMMAND=$_ble_edit_str

  if [[ ! ${BASH_COMMAND//[ 	]} ]]; then
    ble/widget/.newline keep-info
    ble/textarea#render
    ble/util/buffer.flush >&2
    return
  fi

  # 履歴展開
  local hist_expanded
  if ! ble-edit/hist_expanded.update "$BASH_COMMAND"; then
    _ble_edit_line_disabled=1 ble/widget/.insert-newline
    shopt -q histreedit &>/dev/null || ble/widget/.newline/clear-content
    ble/util/buffer.flush >&2
    ble/edit/hist_expanded/.core 1>/dev/null # エラーメッセージを表示
    return
  fi

  local hist_is_expanded=
  if [[ $hist_expanded != "$BASH_COMMAND" ]]; then
    if shopt -q histverify &>/dev/null; then
      _ble_edit_line_disabled=1 ble/widget/.insert-newline
      ble-edit/content/reset-and-check-dirty "$hist_expanded"
      _ble_edit_ind=${#hist_expanded}
      _ble_edit_mark=0
      _ble_edit_mark_active=
      return
    fi

    BASH_COMMAND=$hist_expanded
    hist_is_expanded=1
  fi

  ble/widget/.newline

  [[ $hist_is_expanded ]] && ble/util/buffer.print "${_ble_term_setaf[12]}[ble: expand]$_ble_term_sgr0 $BASH_COMMAND"

  ((++_ble_edit_CMD))

  # 編集文字列を履歴に追加
  ble-edit/history/add "$BASH_COMMAND"

  # 実行を登録
  ble-edit/exec/register "$BASH_COMMAND"
}

function ble/widget/accept-and-next {
  ble-edit/content/clear-arg
  local index count
  ble-edit/history/get-index -v index
  ble-edit/history/get-count -v count

  if ((index+1<count)); then
    local HISTINDEX_NEXT=$((index+1)) # to be modified in accept-line
    ble/widget/accept-line
    ble-edit/history/goto "$HISTINDEX_NEXT"
  else
    local content=$_ble_edit_str
    ble/widget/accept-line

    ble-edit/history/get-count -v count
    if ((count)); then
      local entry; ble-edit/history/get-entry $((count-1))
      if [[ $entry == "$content" ]]; then
        ble-edit/history/goto $((count-1))
      fi
    fi

    [[ $_ble_edit_str != "$content" ]] &&
      ble-edit/content/reset "$content"
  fi
}
function ble/widget/newline {
  local -a KEYS=(10)
  ble/widget/self-insert
}
function ble-edit/is-single-complete-line {
  ble-edit/content/is-single-line || return 1
  [[ $_ble_edit_str ]] && ble-decode/has-input && return 1
  if shopt -q cmdhist &>/dev/null; then
    ble-edit/content/update-syntax
    ble/syntax:bash/is-complete || return 1
  fi
  return 0
}
function ble/widget/accept-single-line-or {
  if ble-edit/is-single-complete-line; then
    ble/widget/accept-line
  else
    ble/widget/"$@"
  fi
}
function ble/widget/accept-single-line-or-newline {
  ble/widget/accept-single-line-or newline
}

# 
#------------------------------------------------------------------------------
# **** ble-edit/undo ****                                            @edit.undo

## @var _ble_edit_undo_hindex=
##   現在の _ble_edit_undo が保持する情報の履歴項目番号。
##   初期は空文字列でどの履歴項目でもない状態を表す。
##

_ble_edit_undo_VARNAMES=(_ble_edit_undo _ble_edit_undo_history)
_ble_edit_undo_ARRNAMES=(_ble_edit_undo_index _ble_edit_undo_hindex)

_ble_edit_undo=()
_ble_edit_undo_index=0
_ble_edit_undo_history=()
_ble_edit_undo_hindex=

function ble-edit/undo/.check-hindex {
  local hindex; ble-edit/history/get-index -v hindex
  [[ $_ble_edit_undo_hindex == "$hindex" ]] && return 0

  # save
  if [[ $_ble_edit_undo_hindex ]]; then
    local uindex=${_ble_edit_undo_index:-${#_ble_edit_undo[@]}}
    local q=\' Q="'\''" value
    ble/util/sprintf value "'%s' " "$uindex" "${_ble_edit_undo[@]//$q/$Q}"
    _ble_edit_undo_history[_ble_edit_undo_hindex]=$value
  fi

  # load
  if [[ ${_ble_edit_undo_history[hindex]} ]]; then
    builtin eval "local -a data=(${_ble_edit_undo_history[hindex]})"
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

## 関数 ble-edit/undo/.get-current-state
##   @var[out] str ind
function ble-edit/undo/.get-current-state {
  if ((_ble_edit_undo_index==0)); then
    str=
    if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
      local index; ble-edit/history/get-index
      ble-edit/history/get-entry -v str "$index"
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
  return
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
# **** history ****                                                    @history

bleopt/declare -v history_preserve_point ''

## @arr _ble_edit_history
##   コマンド履歴項目を保持する。
##
## @arr _ble_edit_history_edit
## @arr _ble_edit_history_dirt
##   _ble_edit_history_edit 編集されたコマンド履歴項目を保持する。
##   _ble_edit_history の各項目と対応し、必ず同じ数・添字の要素を持つ。
##   _ble_edit_history_dirt は編集されたかどうかを保持する。
##   _ble_edit_history の各項目と対応し、変更のあったい要素にのみ値 1 を持つ。
##
## @var _ble_edit_history_ind
##   現在の履歴項目の番号
##
## @arr _ble_edit_history_onleave
##   履歴移動の通知先を格納する配列
##
_ble_edit_history=()
_ble_edit_history_edit=()
_ble_edit_history_dirt=()
_ble_edit_history_ind=0
_ble_edit_history_onleave=()

## @var _ble_edit_history_prefix
##
##   現在どの履歴を対象としているかを保持する。
##   空文字列の時、コマンド履歴を対象とする。以下の変数を用いる。
##
##     _ble_edit_history
##     _ble_edit_history_ind
##     _ble_edit_history_edit
##     _ble_edit_history_dirt
##     _ble_edit_history_onleave
##
##   空でない文字列 prefix のとき、以下の変数を操作対象とする。
##
##     ${prefix}_history
##     ${prefix}_history_ind
##     ${prefix}_history_edit
##     ${prefix}_history_dirt
##     ${prefix}_history_onleave
##
##   何れの関数も _ble_edit_history_prefix を適切に処理する必要がある。
##
##   実装のために配列 _ble_edit_history_edit などを
##   ローカルに定義して処理するときは、以下の注意点を守る必要がある。
##
##   - その関数自身またはそこから呼び出される関数が、
##     履歴項目に対して副作用を持ってはならない。
##
##   この要請の下で、各関数は呼び出し元のすり替えを意識せずに動作できる。
##
_ble_edit_history_prefix=

## @var _ble_edit_history_loaded
## @var _ble_edit_history_count
##
##   これらの変数はコマンド履歴を対象としているときにのみ用いる。
##
_ble_edit_history_loaded=
_ble_edit_history_count=

function ble-edit/history/onleave.fire {
  local -a observers
  eval "observers=(\"\${${_ble_edit_history_prefix:-_ble_edit}_history_onleave[@]}\")"
  local obs; for obs in "${observers[@]}"; do "$obs" "$@"; done
}

function ble-edit/history/get-index {
  local _var=index
  [[ $1 == -v ]] && { _var=$2; shift 2; }
  if [[ $_ble_edit_history_prefix ]]; then
    (($_var=${_ble_edit_history_prefix}_history_ind))
  elif [[ $_ble_edit_history_loaded ]]; then
    (($_var=_ble_edit_history_ind))
  else
    ble-edit/history/get-count -v "$_var"
  fi
}
function ble-edit/history/get-count {
  local _var=count _ret
  [[ $1 == -v ]] && { _var=$2; shift 2; }

  if [[ $_ble_edit_history_prefix ]]; then
    eval "_ret=\${#${_ble_edit_history_prefix}_history[@]}"
  elif [[ $_ble_edit_history_loaded ]]; then
    _ret=${#_ble_edit_history[@]}
  else
    if [[ ! $_ble_edit_history_count ]]; then
      local history_line
      ble/util/assign history_line 'builtin history 1'
      ble/string#split-words history_line "$history_line"
      _ble_edit_history_count=${history_line[0]}
    fi
    _ret=$_ble_edit_history_count
  fi

  (($_var=_ret))
}
function ble-edit/history/get-entry {
  ble-edit/history/load
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  eval "$__var=\${${_ble_edit_history_prefix:-_ble_edit}_history[\$1]}"
}
function ble-edit/history/get-editted-entry {
  ble-edit/history/load
  local __var=entry
  [[ $1 == -v ]] && { __var=$2; shift 2; }
  eval "$__var=\${${_ble_edit_history_prefix:-_ble_edit}_history_edit[\$1]}"
}

## 関数 ble-edit/history/load
if ((_ble_bash>=40000)); then
  # _ble_bash>=40000 で利用できる以下の機能に依存する
  #   ble/util/is-stdin-ready (via ble-decode/has-input)
  #   ble/util/mapfile

  _ble_edit_history_loading=0
  _ble_edit_history_loading_bgpid=

  # history > tmp
  function ble-edit/history/load/.background-initialize {
    if ! builtin history -p '!1' &>/dev/null; then
      # Note: rcfile から呼び出すと history が未ロードなのでロードする。
      #
      # Note: 当初は親プロセスで history -n にした方が二度手間にならず効率的と考えたが
      #   以下の様な問題が生じたので、やはりサブシェルの中で history -n する事にした。
      #
      #   問題1: bashrc の謎の遅延 (memo.txt#D0702)
      #     shopt -s histappend の状態で親シェルで history -n を呼び出すと、
      #     bashrc を抜けてから Bash 本体によるプロンプトが表示されて、
      #     入力を受け付けられる様になる迄に、謎の遅延が発生する。
      #     特に履歴項目の数が HISTSIZE の丁度半分より多い時に起こる様である。
      #
      #     history -n を呼び出す瞬間だけ shopt -u histappend して
      #     直後に shopt -s histappend とすると、遅延は解消するが、
      #     実際の動作を観察すると histappend が無効になってしまっている。
      #
      #     対策として、一時的に HISTSIZE を大きくして bashrc を抜けて、
      #     最初のユーザからの入力の時に HISTSIZE を復元する事にした。
      #     これで遅延は解消できる様である。
      #
      #   問題2: 履歴の数が倍加する問題 (memo.txt#D0732)
      #     親シェルで history -n を実行すると、
      #     shopt -s histappend の状態だと履歴項目の数が2倍になってしまう。
      #     bashrc を抜ける直前から最初にユーザの入力を受けるまでに倍加する。
      #     bashrc から抜けた後に Readline が独自に履歴を読み取るのだろう。
      #     一方で shopt -u histappend の状態だとシェルが動作している内は問題ないが、
      #     シェルを終了した時に2倍に .bash_history の内容が倍になってしまう。
      #
      #     これの解決方法は不明。(HISTFILE 等を弄ったりすれば可能かもれないが試していない)
      #
      builtin history -n
    fi
    local -x HISTTIMEFORMAT=__ble_ext__
    local -x INDEX_FILE=$history_indfile
    local opt_cygwin=; [[ $OSTYPE == cygwin* ]] && opt_cygwin=1

    local apos=\'
    # 482ms for 37002 entries
    builtin history | ble/bin/awk -v apos="$apos" -v opt_cygwin="$opt_cygwin" '
      BEGIN {
        n = 0;
        hindex = 0;
        INDEX_FILE = ENVIRON["INDEX_FILE"];
        printf("") > INDEX_FILE; # create file
        if (opt_cygwin) print "_ble_edit_history=(";
      }
  
      function flush_line() {
        if (n < 1) return;

        if (n == 1) {
          if (t ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
            print hindex > INDEX_FILE;
          hindex++;
        } else {
          gsub(/['$apos'\\]/, "\\\\&", t);
          gsub(/\n/, "\\n", t);
          print hindex > INDEX_FILE;
          t = "eval -- $" apos t apos;
          hindex++;
        }

        if (opt_cygwin) {
          gsub(/'$apos'/, "'$apos'\\'$apos$apos'", t);
          t = apos t apos;
        }

        print t;
        n = 0;
        t = "";
      }
  
      {
        if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0))
          flush_line();
        t = ++n == 1 ? $0 : t "\n" $0;
      }
  
      END {
        flush_line();
        if (opt_cygwin) print ")";
      }
    ' >| "$history_tmpfile.part"
    ble/bin/mv -f "$history_tmpfile.part" "$history_tmpfile"
  }

  function ble-edit/history/load {
    [[ $_ble_edit_history_prefix ]] && return
    [[ $_ble_edit_history_loaded ]] && return
  
    local opt_async=; [[ $1 == async ]] && opt_async=1
    local opt_info=; ((_ble_edit_attached)) && [[ ! $opt_async ]] && opt_info=1
    local opt_cygwin=; [[ $OSTYPE == cygwin* ]] && opt_cygwin=1
  
    local history_tmpfile=$_ble_base_run/$$.edit-history-load
    local history_indfile=$_ble_base_run/$$.edit-history-load-multiline-index
    while :; do
      case $_ble_edit_history_loading in

      # 42ms 履歴の読み込み
      (0) [[ $opt_info ]] && ble-edit/info/immediate-show text "loading history..."

          # 履歴ファイル生成を Background で開始
          : >| "$history_tmpfile"

          if [[ $opt_async ]]; then
            _ble_edit_history_loading_bgpid=$(
              shopt -u huponexit; ble-edit/history/load/.background-initialize </dev/null &>/dev/null & echo $!)

            function ble-edit/history/load/.background-initialize-completed {
              local history_tmpfile=$_ble_base_run/$$.edit-history-load
              [[ -s $history_tmpfile ]] || ! builtin kill -0 "$_ble_edit_history_loading_bgpid"
            } &>/dev/null

            ((_ble_edit_history_loading++))
          else
            ble-edit/history/load/.background-initialize
            ((_ble_edit_history_loading+=3))
          fi ;;

      # 515ms ble-edit/history/load/.background-initialize 待機
      (1) if [[ $opt_async ]] && ble/util/is-running-in-idle; then
            ble/util/idle.wait-condition ble-edit/history/load/.background-initialize-completed
            ((_ble_edit_history_loading++))
            return
          fi
          ((_ble_edit_history_loading++)) ;;

      # Note: async でバックグラウンドプロセスを起動した後に、直接 (sync で)
      #   呼び出された時、未だ処理が完了していなくても次のステップに進んでしまうので、
      #   此処で条件が満たされるのを待つ (#D0745)
      (2) while ! ble-edit/history/load/.background-initialize-completed; do
            ble/util/msleep 50
            [[ $opt_async ]] && ble-decode/has-input && return 148
          done
          ((_ble_edit_history_loading++)) ;;

      # 47ms _ble_edit_history 初期化 (37000項目)
      (3) if [[ $opt_cygwin ]]; then
            # 620ms Cygwin (99000項目)
            source "$history_tmpfile"
          else
            ble/util/mapfile _ble_edit_history < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;
  
      # 47ms _ble_edit_history_edit 初期化 (37000項目)
      (4) if [[ $opt_cygwin ]]; then
            # 504ms Cygwin (99000項目)
            _ble_edit_history_edit=("${_ble_edit_history[@]}")
          else
            ble/util/mapfile _ble_edit_history_edit < "$history_tmpfile"
          fi
          ((_ble_edit_history_loading++)) ;;
  
      # 11ms 複数行履歴修正 (107/37000項目)
      (5) local -a indices_to_fix
          ble/util/mapfile indices_to_fix < "$history_indfile"
          local i rex='^eval -- \$'\''([^\'\'']|\\.)*'\''$'
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_edit_history[i]} =~ $rex ]] &&
              eval "_ble_edit_history[i]=${_ble_edit_history[i]:8}"
          done
          ((_ble_edit_history_loading++)) ;;

      # 11ms 複数行履歴修正 (107/37000項目)
      (6) local -a indices_to_fix
          [[ ${indices_to_fix+set} ]] ||
            ble/util/mapfile indices_to_fix < "$history_indfile"
          for i in "${indices_to_fix[@]}"; do
            [[ ${_ble_edit_history_edit[i]} =~ $rex ]] &&
              eval "_ble_edit_history_edit[i]=${_ble_edit_history_edit[i]:8}"
          done

          _ble_edit_history_count=${#_ble_edit_history[@]}
          _ble_edit_history_ind=$_ble_edit_history_count
          _ble_edit_history_loaded=1
          [[ $opt_info ]] && ble-edit/info/immediate-clear
          ((_ble_edit_history_loading++))
          return 0 ;;
  
      (*) return 1 ;;
      esac
  
      [[ $opt_async ]] && ble-decode/has-input && return 148
    done
  }
  function ble-edit/history/clear-background-load {
    _ble_edit_history_loading=0
  }
else
  function ble-edit/history/.generate-source-to-load-history {
    if ! builtin history -p '!1' &>/dev/null; then
      # rcfile として起動すると history が未だロードされていない。
      builtin history -n
    fi
    HISTTIMEFORMAT=__ble_ext__

    # 285ms for 16437 entries
    local apos="'"
    builtin history | ble/bin/awk -v apos="'" '
      BEGIN{
        n="";
        print "_ble_edit_history=("
      }

      # ※rcfile として読み込むと HISTTIMEFORMAT が ?? に化ける。
      /^ *[0-9]+\*? +(__ble_ext__|\?\?)/ {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        n = $1; t = "";
        sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0);
      }
      {
        line = $0;
        if (line ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/)
          line = apos substr(line, 9) apos;
        else
          gsub(apos, apos "\\" apos apos, line);

        t = t != "" ? t "\n" line : line;
      }
      END {
        if (n != "") {
          n = "";
          print "  " apos t apos;
        }

        print ")"
      }
    '
  }

  ## called by ble-edit/initialize
  function ble-edit/history/load {
    [[ $_ble_edit_history_prefix ]] && return
    [[ $_ble_edit_history_loaded ]] && return
    _ble_edit_history_loaded=1

    ((_ble_edit_attached)) &&
      ble-edit/info/immediate-show text "loading history..."

    # * プロセス置換にしてもファイルに書き出しても大した違いはない。
    #   270ms for 16437 entries (generate-source の時間は除く)
    # * プロセス置換×source は bash-3 で動かない。eval に変更する。
    builtin eval -- "$(ble-edit/history/.generate-source-to-load-history)"
    _ble_edit_history_edit=("${_ble_edit_history[@]}")
    _ble_edit_history_count=${#_ble_edit_history[@]}
    _ble_edit_history_ind=$_ble_edit_history_count
    if ((_ble_edit_attached)); then
      ble-edit/info/clear
    fi
  }
  function ble-edit/history/clear-background-load { :; }
fi

# @var[in,out] HISTINDEX_NEXT
#   used by ble/widget/accept-and-next to get modified next-entry positions
function ble-edit/history/add/.command-history {
  # 注意: bash-3.2 未満では何故か bind -x の中では常に history off になっている。
  [[ -o history ]] || ((_ble_bash<30200)) || return

  if [[ $_ble_edit_history_loaded ]]; then
    # 登録・不登録に拘わらず取り敢えず初期化
    _ble_edit_history_ind=${#_ble_edit_history[@]}

    # _ble_edit_history_edit を未編集状態に戻す
    local index
    for index in "${!_ble_edit_history_dirt[@]}"; do
      _ble_edit_history_edit[index]=${_ble_edit_history[index]}
    done
    _ble_edit_history_dirt=()

    # 同時に _ble_edit_undo も初期化する。
    ble-edit/undo/clear-all
  fi

  local cmd=$1
  if [[ $HISTIGNORE ]]; then
    local pats pat
    ble/string#split pats : "$HISTIGNORE"
    for pat in "${pats[@]}"; do
      [[ $cmd == $pat ]] && return
    done
  fi

  local histfile=

  if [[ $_ble_edit_history_loaded ]]; then
    if [[ $HISTCONTROL ]]; then
      local ignorespace ignoredups erasedups spec
      for spec in ${HISTCONTROL//:/ }; do
        case "$spec" in
        (ignorespace) ignorespace=1 ;;
        (ignoredups)  ignoredups=1 ;;
        (ignoreboth)  ignorespace=1 ignoredups=1 ;;
        (erasedups)   erasedups=1 ;;
        esac
      done

      if [[ $ignorespace ]]; then
        [[ $cmd == [' 	']* ]] && return
      fi
      if [[ $ignoredups ]]; then
        local lastIndex=$((${#_ble_edit_history[@]}-1))
        ((lastIndex>=0)) && [[ $cmd == "${_ble_edit_history[lastIndex]}" ]] && return
      fi
      if [[ $erasedups ]]; then
        local indexNext=$HISTINDEX_NEXT
        local i n=-1 N=${#_ble_edit_history[@]}
        for ((i=0;i<N;i++)); do
          if [[ ${_ble_edit_history[i]} != "$cmd" ]]; then
            if ((++n!=i)); then
              _ble_edit_history[n]=${_ble_edit_history[i]}
              _ble_edit_history_edit[n]=${_ble_edit_history_edit[i]}
            fi
          else
            ((i<HISTINDEX_NEXT&&HISTINDEX_NEXT--))
          fi
        done
        for ((i=N-1;i>n;i--)); do
          unset -v '_ble_edit_history[i]'
          unset -v '_ble_edit_history_edit[i]'
        done
        [[ ${HISTINDEX_NEXT+set} ]] && HISTINDEX_NEXT=$indexNext
      fi
    fi
    local topIndex=${#_ble_edit_history[@]}
    _ble_edit_history[topIndex]=$cmd
    _ble_edit_history_edit[topIndex]=$cmd
    _ble_edit_history_count=$((topIndex+1))
    _ble_edit_history_ind=$_ble_edit_history_count

    # _ble_bash<30100 の時は必ずここを通る。
    # 初期化時に _ble_edit_history_loaded=1 になるので。
    ((_ble_bash<30100)) && histfile=${HISTFILE:-$HOME/.bash_history}
  else
    if [[ $HISTCONTROL ]]; then
      # 未だ履歴が初期化されていない場合は取り敢えず history -s に渡す。
      # history -s でも HISTCONTROL に対するフィルタはされる。
      # history -s で項目が追加されたかどうかはスクリプトからは分からないので
      # _ble_edit_history_count は一旦クリアする。
      _ble_edit_history_count=
    else
      # HISTCONTROL がなければ多分 history -s で必ず追加される。
      # _ble_edit_history_count 取得済ならば更新。
      [[ $_ble_edit_history_count ]] &&
        ((_ble_edit_history_count++))
    fi
  fi

  if [[ $cmd == *$'\n'* ]]; then
    # Note: 改行を含む場合は %q は常に $'' の形式になる。
    ble/util/sprintf cmd 'eval -- %q' "$cmd"
  fi

  if [[ $histfile ]]; then
    # bash-3.1 workaround
    local tmp=$_ble_base_run/$$.ble_edit_history_add.txt
    builtin printf '%s\n' "$cmd" >> "$histfile"
    builtin printf '%s\n' "$cmd" >| "$tmp"
    builtin history -r "$tmp"
  else
    ble-edit/history/clear-background-load
    builtin history -s -- "$cmd"
  fi
}

function ble-edit/history/add {
  local command=$1
  if [[ $_ble_edit_history_prefix ]]; then
    local code='
      # PREFIX_history_edit を未編集状態に戻す
      local index
      for index in "${!PREFIX_history_dirt[@]}"; do
        PREFIX_history_edit[index]=${PREFIX_history[index]}
      done
      PREFIX_history_dirt=()

      local topIndex=${#PREFIX_history[@]}
      PREFIX_history[topIndex]=$command
      PREFIX_history_edit[topIndex]=$command
      PREFIX_history_ind=$((topIndex+1))'
    eval "${code//PREFIX/$_ble_edit_history_prefix}"
  else
    ble-edit/history/add/.command-history "$command"
  fi
}

function ble-edit/history/goto {
  ble-edit/history/load

  local histlen= index0= index1=$1
  ble-edit/history/get-count -v histlen
  ble-edit/history/get-index -v index0

  ((index0==index1)) && return

  if ((index1>histlen)); then
    index1=histlen
    ble/widget/.bell
  elif ((index1<0)); then
    index1=0
    ble/widget/.bell
  fi

  ((index0==index1)) && return

  local code='
    # store
    if [[ ${PREFIX_history_edit[index0]} != "$_ble_edit_str" ]]; then
      PREFIX_history_edit[index0]=$_ble_edit_str
      PREFIX_history_dirt[index0]=1
    fi

    # restore
    ble-edit/history/onleave.fire
    PREFIX_history_ind=$index1
    ble-edit/content/reset "${PREFIX_history_edit[index1]}" history'
  eval "${code//PREFIX/${_ble_edit_history_prefix:-_ble_edit}}"

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

function ble/widget/history-next {
  if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
    local arg; ble-edit/content/get-arg 1
    local index; ble-edit/history/get-index
    ble-edit/history/goto $((index+arg))
  else
    ble-edit/content/clear-arg
    ble/widget/.bell
  fi
}
function ble/widget/history-prev {
  local arg; ble-edit/content/get-arg 1
  local index; ble-edit/history/get-index
  ble-edit/history/goto $((index-arg))
}
function ble/widget/history-beginning {
  ble-edit/content/clear-arg
  ble-edit/history/goto 0
}
function ble/widget/history-end {
  ble-edit/content/clear-arg
  if [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]]; then
    local count; ble-edit/history/get-count
    ble-edit/history/goto "$count"
  else
    ble/widget/.bell
  fi
}

## 編集関数 history-expand-line
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
## 編集関数 history-expand-backward-line
##   @exit 展開が行われた時に成功します。それ以外の時に失敗します。
function ble/widget/history-expand-backward-line {
  ble-edit/content/clear-arg
  local prevline=${_ble_edit_str::_ble_edit_ind} hist_expanded
  ble-edit/hist_expanded.update "$prevline" || return 1
  [[ $prevline == "$hist_expanded" ]] && return 1

  local ret
  ble/string#common-prefix "$prevline" "$hist_expanded"; local dmin=${#ret}
  ble-edit/content/replace "$dmin" "$_ble_edit_ind" "${hist_expanded:dmin}"
  _ble_edit_ind=${#hist_expanded}
  _ble_edit_mark=0
  _ble_edit_mark_active=
  return 0
}
## 編集関数 magic-space
##   履歴展開と静的略語展開を実行してから空白を挿入します。
function ble/widget/magic-space {
  # keymap/vi.sh
  [[ $_ble_decode_keymap == vi_imap ]] &&
    local oind=$_ble_edit_ind ostr=$_ble_edit_str

  local arg; ble-edit/content/get-arg ''
  ble/widget/history-expand-backward-line ||
    ble/complete/sabbrev/expand
  local ext=$?
  ((ext==148)) && return 148 # sabbrev/expand でメニュー補完に入った時など。

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

## 関数 ble-edit/isearch/search needle opts ; beg end
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
        return
      fi
    else
      if ((++start<=${#_ble_edit_str})); then
        local mark=$_ble_edit_mark; ((mark<${#_ble_edit_str}&&mark++))
        local ind=$_ble_edit_ind; ((ind<${#_ble_edit_str}&&ind++))
        opts=$opts:allow_empty
        _ble_edit_mark=$mark _ble_edit_ind=$ind ble-edit/isearch/search "$needle" "$opts"
        return
      fi
    fi
  fi
  return 1
}
## 関数 ble-edit/isearch/.shift-backward-references
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

## 関数 ble-edit/isearch/forward-search-history opts
## 関数 ble-edit/isearch/backward-search-history opts
## 関数 ble-edit/isearch/backward-search-history-blockwise opts
##
##   backward-search-history-blockwise does blockwise search
##   as a workaround for bash slow array access
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     regex     正規表現による検索を行います。
##     glob      グロブパターンによる一致を試みます。
##     head      固定文字列に依る先頭一致を試みます。
##     tail      固定文字列に依る終端一致を試みます。
##     condition 述語コマンドを評価 (eval) して一致を試みます。
##     predicate 述語関数を呼び出して一致を試みます。
##       これらの内の何れか一つを指定します。
##       何も指定しない場合は固定文字列の部分一致を試みます。
##
##     stop_check
##       ユーザの入力があった時に終了ステータス 148 で中断します。
##
##     progress
##       検索の途中経過を表示します。
##       後述の isearch_progress_callback 変数に指定された関数を呼び出します。
##
##     backward
##       内部使用のオプションです。
##       forward-search-history に対して指定して、後方検索を行う事を指定します。
##
##     cyclic
##       履歴の端まで達した時、履歴の反対側の端から検索を続行します。
##       一致が見つからずに start の直前の要素まで達した時に失敗します。
##
##   @var[in] _ble_edit_history_edit
##     検索対象の配列と全体の検索開始位置を指定します。
##   @var[in] start
##     全体の検索開始位置を指定します。
##
##   @var[in] needle
##     検索文字列を指定します。
##
##     opts に regex または glob を指定した場合は、
##     それぞれ正規表現またはグロブパターンを指定します。
##
##     opts に condition を指定した場合は needle を述語コマンドと解釈します。
##     変数 LINE 及び INDEX にそれぞれ行の内容と履歴番号を設定して eval されます。
##
##     opts に predicate を指定した場合は needle を述語関数の関数名と解釈します。
##     指定する述語関数は検索が一致した時に成功し、それ以外の時に失敗する関数です。
##     第1引数と第2引数に行の内容と履歴番号を指定して関数が呼び出されます。
##
##   @var[in,out] index
##     今回の呼び出しの検索開始位置を指定します。
##     一致が成功したとき見つかった位置を返します。
##     一致が中断されたとき次の位置 (再開時に最初に検査する位置) を返します。
##
##   @var[in,out] isearch_time
##
##   @var[in] isearch_progress_callback
##     progress の表示時に呼び出す関数名を指定します。
##     第一引数には現在の検索位置 (history index) を指定します。
##
##   @exit
##     見つかったときに 0 を返します。
##     見つからなかったときに 1 を返します。
##     中断された時に 148 を返します。
##
function ble-edit/isearch/.read-search-options {
  local opts=$1

  search_type=fixed
  case :$opts: in
  (*:regex:*)     search_type=regex ;;
  (*:glob:*)      search_type=glob  ;;
  (*:head:*)      search_type=head ;;
  (*:tail:*)      search_type=tail ;;
  (*:condition:*) search_type=condition ;;
  (*:predicate:*) search_type=predicate ;;
  esac

  [[ :$opts: != *:stop_check:* ]]; has_stop_check=$?
  [[ :$opts: != *:progress:* ]]; has_progress=$?
  [[ :$opts: != *:backward:* ]]; has_backward=$?
}
function ble-edit/isearch/backward-search-history-blockwise {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble-edit/isearch/.read-search-options "$opts"

  ble-edit/history/load
  if [[ $_ble_edit_history_prefix ]]; then
    local -a _ble_edit_history_edit
    eval "_ble_edit_history_edit=(\"\${${_ble_edit_history_prefix}_history_edit[@]}\")"
  fi

  local NSTPCHK=1000 # 十分高速なのでこれぐらい大きくてOK
  local NPROGRESS=$((NSTPCHK*2)) # 倍数である必要有り
  local irest block j i=$index
  index=

  local flag_cycled= range_min range_max
  while :; do
    if ((i<=start)); then
      range_min=0 range_max=$start
    else
      flag_cycled=1
      range_min=$((start+1)) range_max=$i
    fi

    while ((i>=range_min)); do
      ((block=range_max-i,
        block<5&&(block=5),
        block>i+1-range_min&&(block=i+1-range_min),
        irest=NSTPCHK-isearch_time%NSTPCHK,
        block>irest&&(block=irest)))

      case $search_type in
      (regex)     for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_edit_history_edit[j]} =~ $needle ]] && index=$j
                  done ;;
      (glob)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_edit_history_edit[j]} == $needle ]] && index=$j
                  done ;;
      (head)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_edit_history_edit[j]} == "$needle"* ]] && index=$j
                  done ;;
      (tail)      for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_edit_history_edit[j]} == *"$needle" ]] && index=$j
                  done ;;
      (condition) eval "function ble-edit/isearch/.search-block.proc {
                    local LINE INDEX
                    for ((j=i-block;++j<=i;)); do
                      LINE=\${_ble_edit_history_edit[j]} INDEX=\$j
                      { $needle; } && index=\$j
                    done
                  }"
                  ble-edit/isearch/.search-block.proc ;;
      (predicate) for ((j=i-block;++j<=i;)); do
                    "$needle" "${_ble_edit_history_edit[j]}" "$j" && index=$j
                  done ;;
      (*)         for ((j=i-block;++j<=i;)); do
                    [[ ${_ble_edit_history_edit[j]} == *"$needle"* ]] && index=$j
                  done ;;
      esac

      ((isearch_time+=block))
      [[ $index ]] && return 0

      ((i-=block))
      if ((has_stop_check&&isearch_time%NSTPCHK==0)) && ble-decode/has-input; then
        index=$i
        return 148
      elif ((has_progress&&isearch_time%NPROGRESS==0)); then
        "$isearch_progress_callback" "$i"
      fi
    done

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      ((i=${#_ble_edit_history_edit[@]}-1))
      ((start<i)) || return 1
    else
      return 1
    fi
  done
}
function ble-edit/isearch/next-history/forward-search-history.impl {
  local opts=$1
  local search_type has_stop_check has_progress has_backward
  ble-edit/isearch/.read-search-options "$opts"

  ble-edit/history/load
  if [[ $_ble_edit_history_prefix ]]; then
    local -a _ble_edit_history_edit
    eval "_ble_edit_history_edit=(\"\${${_ble_edit_history_prefix}_history_edit[@]}\")"
  fi

  while :; do
    local flag_cycled= expr_cond expr_incr
    if ((has_backward)); then
      if ((index<=start)); then
        expr_cond='index>=0' expr_incr='index--'
      else
        expr_cond='index>start' expr_incr='index--' flag_cycled=1
      fi
    else
      if ((index>=start)); then
        expr_cond="index<${#_ble_edit_history_edit[@]}" expr_incr='index++'
      else
        expr_cond="index<start" expr_incr='index++' flag_cycled=1
      fi
    fi

    case $search_type in
    (regex)
#%define search_loop
      for ((;expr_cond;expr_incr)); do
        ((isearch_time++,has_stop_check&&isearch_time%100==0)) &&
          ble-decode/has-input && return 148
        @ && return 0
        ((has_progress&&isearch_time%1000==0)) &&
          "$isearch_progress_callback" "$index"
      done ;;
#%end
#%expand search_loop.r/@/[[ ${_ble_edit_history_edit[index]} =~ $needle ]]/
    (glob)
#%expand search_loop.r/@/[[ ${_ble_edit_history_edit[index]} == $needle ]]/
    (head)
#%expand search_loop.r/@/[[ ${_ble_edit_history_edit[index]} == "$needle"* ]]/
    (tail)
#%expand search_loop.r/@/[[ ${_ble_edit_history_edit[index]} == *"$needle" ]]/
    (condition)
#%expand search_loop.r/@/LINE=${_ble_edit_history_edit[index]} INDEX=$index eval "$needle"/
    (predicate)
#%expand search_loop.r/@/"$needle" "${_ble_edit_history_edit[index]}" "$index"/
    (*)
#%expand search_loop.r/@/[[ ${_ble_edit_history_edit[index]} == *"$needle"* ]]/
    esac

    if [[ ! $flag_cycled && :$opts: == *:cyclic:* ]]; then
      if ((has_backward)); then
        ((index=${#_ble_edit_history_edit[@]}-1))
        ((index>start)) || return 1
      else
        ((index=0))
        ((index<start)) || return 1
      fi
    else
      return 1
    fi
  done
}
function ble-edit/isearch/forward-search-history {
  ble-edit/isearch/next-history/forward-search-history.impl "$1"
}
function ble-edit/isearch/backward-search-history {
  ble-edit/isearch/next-history/forward-search-history.impl "$1:backward"
}

# 
#------------------------------------------------------------------------------
# **** incremental search ****                                 @history.isearch

## 変数 _ble_edit_isearch_str
##   一致した文字列
## 変数 _ble_edit_isearch_dir
##   現在・直前の検索方法
## 配列 _ble_edit_isearch_arr[]
##   インクリメンタル検索の過程を記録する。
##   各要素は ind:dir:beg:end:needle の形式をしている。
##   ind は履歴項目の番号を表す。dir は履歴検索の方向を表す。
##   beg, end はそれぞれ一致開始位置と終了位置を表す。
##   丁度 _ble_edit_ind 及び _ble_edit_mark に対応する。
##   needle は検索に使用した文字列を表す。
## 変数 _ble_edit_isearch_old
##   前回の検索に使用した文字列
_ble_edit_isearch_str=
_ble_edit_isearch_dir=-
_ble_edit_isearch_arr=()
_ble_edit_isearch_old=

## 関数 ble-edit/isearch/status/append-progress-bar pos count
##   @var[in,out] text
function ble-edit/isearch/status/append-progress-bar {
  ble/util/is-unicode-output || return
  local pos=$1 count=$2 dir=$3
  [[ :$dir: == *:-:* || :$dir: == *:backward:* ]] && ((pos=count-1-pos))
  local ret; ble/string#create-unicode-progress-bar "$pos" "$count" 5
  text=$text$' \e[1;38;5;69;48;5;253m'$ret$'\e[m '
}

## 関数 ble-edit/isearch/.show-status-with-progress.fib [pos]
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
  local index; ble-edit/history/get-index
  local histIndex='!'$((index+1))
  local text="(${#_ble_edit_isearch_arr[@]}: $ll $histIndex $rr) \`$_ble_edit_isearch_str'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble-edit/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_isearch_dir"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi
  ((fib_ntask)) && text="$text *$fib_ntask"

  ble-edit/info/show ansi "$text"
}

## 関数 ble-edit/isearch/.show-status.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.show-status.fib {
  ble-edit/isearch/.show-status-with-progress.fib
}
function ble-edit/isearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/isearch/.show-status.fib
}
function ble-edit/isearch/erase-status {
  ble-edit/info/default
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
## 関数 ble-edit/isearch/.push-isearch-array
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
    unset -v "_ble_edit_isearch_arr[$ilast]"
    return
  fi

  local oind; ble-edit/history/get-index -v oind
  local obeg=$_ble_edit_ind oend=$_ble_edit_mark
  [[ $_ble_edit_mark_active ]] || oend=$obeg
  ((obeg>oend)) && local obeg=$oend oend=$obeg
  local oneedle=$_ble_edit_isearch_str
  local ohash=$obeg:$oend:$oneedle

  # [... A | B] -> B と来た時 (何もしない) [... A | B] になる。
  [[ $ind == "$oind" && $hash == "$ohash" ]] && return

  # [... A | B] -> C と来た時 (B を _ble_edit_isearch_arr に移動) [... A B | C] になる。
  ble/array#push _ble_edit_isearch_arr "$oind:$_ble_edit_isearch_dir:$ohash"
}
## 関数 ble-edit/isearch/.goto-match.fib
##   @var[in] fib_ntask
function ble-edit/isearch/.goto-match.fib {
  local ind=$1 beg=$2 end=$3 needle=$4

  # 検索履歴に待避 (変数 ind beg end needle 使用)
  ble-edit/isearch/.push-isearch-array

  # 状態を更新
  _ble_edit_isearch_str=$needle
  [[ $needle ]] && _ble_edit_isearch_old=$needle
  local oind; ble-edit/history/get-index -v oind
  ((oind!=ind)) && ble-edit/history/goto "$ind"
  ble-edit/isearch/.set-region "$beg" "$end"

  # isearch 表示
  ble-edit/isearch/.show-status.fib
  ble/textarea#redraw
}

# ---- isearch fibers ---------------------------------------------------------

## 関数 ble-edit/isearch/.next.fib opts [needle]
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
      local ind; ble-edit/history/get-index -v ind
      ble-edit/isearch/.goto-match.fib "$ind" "$beg" "$end" "$needle"
      return
    fi
  fi
  ble-edit/isearch/.next-history.fib "$opts" "$needle"
}

## 関数 ble-edit/isearch/.next-history.fib [opts [needle]]
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
##   @var[in] _ble_edit_history_ind
##     現在の履歴項目の位置を指定します。
##     新しい検索を開始する時の検索開始位置になります。
##
##   @var[in] _ble_edit_isearch_dir
##     現在の検索方向を指定します。
##   @var[in] _ble_edit_history_edit[]
##   @var[in,out] isearch_time
##
function ble-edit/isearch/.next-history.fib {
  local opts=$1
  if [[ $fib_suspend ]]; then
    # resume the previous search
    local needle=${fib_suspend#*:} isAdd=
    local index start; eval "${fib_suspend%%:*}"
    fib_suspend=
  else
    # initialize new search
    local needle=${2-$_ble_edit_isearch_str} isAdd=
    [[ :$opts: == *:append:* ]] && isAdd=1
    local start; ble-edit/history/get-index -v start
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
    ble-edit/isearch/backward-search-history-blockwise stop_check:progress
  else
    ble-edit/isearch/forward-search-history stop_check:progress
  fi
  local ext=$?

  if ((ext==0)); then
    # 見付かった場合

    # 一致範囲 beg-end を取得
    local str; ble-edit/history/get-editted-entry -v str "$index"
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
    return
  else
    # 見つからなかった場合
    ble/widget/.bell "isearch: \`$needle' not found"
    return
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
    ((code==0)) && return
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
    ((code==0)) && return
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
  unset -v '_ble_edit_isearch_arr[ilast]'

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
    local index; ble-edit/history/get-index
    if ((index==_ble_edit_isearch_save[0])); then
      _ble_edit_mark=${_ble_edit_isearch_save[2]}
      if [[ $old_mark_active != S ]] || ((_ble_edit_index==_ble_edit_isearch_save[1])); then
        _ble_edit_mark_active=$old_mark_active
      fi
    fi
  fi
}
function ble/widget/isearch/exit.impl {
  ble-decode/keymap/pop
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
  ble-decode-key "${KEYS[@]}"
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

## 関数 ble/widget/history-isearch.impl opts
function ble/widget/history-isearch.impl {
  local opts=$1
  ble-edit/content/clear-arg
  ble-decode/keymap/push isearch
  ble/util/fiberchain#initialize ble-edit/isearch

  local index; ble-edit/history/get-index
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
  local ble_bind_keymap=isearch

  ble-bind -f __defchar__ isearch/self-insert
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
_ble_edit_nsearch_needle=
_ble_edit_nsearch_opts=
_ble_edit_nsearch_stack=()
_ble_edit_nsearch_match=
_ble_edit_nsearch_index=

## 関数 ble-edit/nsearch/.show-status.fib [pos_progress]
##   @var[in] fib_ntask
function ble-edit/nsearch/.show-status.fib {
  local ll rr
  if [[ :$_ble_edit_isearch_opts: == *:forward:* ]]; then
    ll="  " rr=">>"
  else
    ll=\<\< rr="  " # Note: Emacs workaround: '<<' や "<<" と書けない。
  fi

  local index='!'$((_ble_edit_nsearch_match+1))
  local nmatch=${#_ble_edit_nsearch_stack[@]}
  local needle=$_ble_edit_nsearch_needle
  local text="(nsearch#$nmatch: $ll $index $rr) \`$needle'"

  if [[ $1 ]]; then
    local pos=$1
    local count; ble-edit/history/get-count
    text=$text' searching...'
    ble-edit/isearch/status/append-progress-bar "$pos" "$count" "$_ble_edit_isearch_opts"
    local percentage=$((count?pos*1000/count:1000))
    text=$text" @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  local ntask=$fib_ntask
  ((ntask)) && text="$text *$ntask"

  ble-edit/info/show ansi "$text"
}
function ble-edit/nsearch/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-edit/nsearch/.show-status.fib
}
function ble-edit/nsearch/erase-status {
  ble-edit/info/default
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

      ble-edit/content/reset-and-check-dirty "$line"
      _ble_edit_nsearch_match=${record[1]}
      _ble_edit_nsearch_index=${record[1]}
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
      if ((_ble_edit_mark!=_ble_edit_ind)); then
        _ble_edit_mark_active=search
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
    eval "$fib_suspend"
    fib_suspend=
  else
    local index=$_ble_edit_nsearch_index
    local start=$index
  fi
  local needle=$_ble_edit_nsearch_needle
  if
    if [[ $opt_forward ]]; then
      local count; ble-edit/history/get-count
      [[ $opt_resume ]] || ((++index))
      ((index<count))
    else
      [[ $opt_resume ]] || ((--index))
      ((index>=0))
    fi
  then
    local isearch_time=$fib_clock
    local isearch_progress_callback=ble-edit/nsearch/.show-status.fib
    local isearch_opts=stop_check:progress; [[ :$opts: != *:substr:* ]] && isearch_opts=$isearch_opts:head
    if [[ $opt_forward ]]; then
      ble-edit/isearch/forward-search-history "$isearch_opts"; local ext=$?
    else
      ble-edit/isearch/backward-search-history-blockwise "$isearch_opts"; local ext=$?
    fi
    fib_clock=$isearch_time
  else
    local ext=1
  fi

  # 書き換え
  if ((ext==0)); then
    local old_match=$_ble_edit_nsearch_match
    ble/array#push _ble_edit_nsearch_stack "backward,$old_match,$_ble_edit_ind,$_ble_edit_mark:$_ble_edit_str"

    local line; ble-edit/history/get-editted-entry -v line "$index"
    local prefix=${line%%"$needle"*}
    local beg=${#prefix}
    local end=$((beg+${#needle}))
    _ble_edit_nsearch_match=$index
    _ble_edit_nsearch_index=$index
    ble-edit/content/reset-and-check-dirty "$line"
    ((_ble_edit_mark=beg,_ble_edit_ind=end))
    if ((_ble_edit_mark!=_ble_edit_ind)); then
      _ble_edit_mark_active=search
    else
      _ble_edit_mark_active=
    fi
    ble-edit/nsearch/.show-status.fib
    ble/textarea#redraw

  elif ((ext==148)); then
    fib_suspend="index=$index start=$start"
    return 148
  else
    ble/widget/.bell "ble.sh: nsearch: '$needle' not found"
    ble-edit/nsearch/.show-status.fib
    if [[ $opt_forward ]]; then
      local count; ble-edit/history/get-count
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

function ble/widget/history-search {
  local opts=$1
  ble-edit/content/clear-arg

  # initialize variables
  if [[ :$opts: == *:input:* ]]; then
    ble/builtin/read -ep "nsearch> " _ble_edit_nsearch_needle || return 1
  else
    _ble_edit_nsearch_needle=${_ble_edit_str::_ble_edit_ind}
  fi
  _ble_edit_nsearch_stack=()
  local index; ble-edit/history/get-index
  _ble_edit_nsearch_match=$index
  _ble_edit_nsearch_index=$index
  if [[ :$opts: == *:substr:* ]]; then
    _ble_edit_nsearch_opts=substr
  else
    _ble_edit_nsearch_opts=
  fi
  _ble_edit_mark_active=
  ble-decode/keymap/push nsearch

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
  ble/widget/history-search input:substr:backward
}
function ble/widget/history-nsearch-forward {
  ble/widget/history-search input:substr:forward
}
function ble/widget/history-search-backward {
  ble/widget/history-search backward
}
function ble/widget/history-search-forward {
  ble/widget/history-search forward
}
function ble/widget/history-substring-search-backward {
  ble/widget/history-search substr:backward
}
function ble/widget/history-substring-search-forward {
  ble/widget/history-search substr:forward
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
function ble/widget/nsearch/exit {
  ble-decode/keymap/pop
  _ble_edit_mark_active=
  ble-edit/nsearch/erase-status
}
function ble/widget/nsearch/exit-default {
  ble/widget/nsearch/exit
  ble-decode-key "${KEYS[@]}"
}
function ble/widget/nsearch/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-edit/nsearch/show-status
  else
    ble/widget/nsearch/exit
    local record=${_ble_edit_nsearch_stack[0]}
    if [[ $record ]]; then
      local line=${record#*:}
      ble/string#split record , "${record%%:*}"

      ble-edit/content/reset-and-check-dirty "$line"
      _ble_edit_ind=${record[2]}
      _ble_edit_mark=${record[3]}
    fi
  fi
}
function ble/widget/nsearch/accept-line {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/widget/.bell "nsearch: now searching..."
  else
    ble/widget/nsearch/exit
    ble-decode-key 13 # RET
  fi
}

function ble-decode/keymap:nsearch/define {
  local ble_bind_keymap=nsearch

  ble-bind -f __default__ nsearch/exit-default
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
  [[ $ble_bind_nometa && $1 == *M-* ]] && return
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
  ble-decode/keymap:safe/.bind 'C-w'       'kill-region-or uword'
  ble-decode/keymap:safe/.bind 'M-w'       'copy-region-or uword'
  ble-decode/keymap:safe/.bind 'C-y'       'yank'

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
  ble-decode/keymap:safe/.bind 'C-d'       'delete-region-or forward-char'
  ble-decode/keymap:safe/.bind 'delete'    'delete-region-or forward-char'
  ble-decode/keymap:safe/.bind 'C-?'       'delete-region-or backward-char'
  ble-decode/keymap:safe/.bind 'DEL'       'delete-region-or backward-char'
  ble-decode/keymap:safe/.bind 'C-h'       'delete-region-or backward-char'
  ble-decode/keymap:safe/.bind 'BS'        'delete-region-or backward-char'
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
}
function ble-decode/keymap:safe/bind-complete {
  ble-decode/keymap:safe/.bind 'C-i'       'complete'
  ble-decode/keymap:safe/.bind 'TAB'       'complete'
  ble-decode/keymap:safe/.bind 'M-?'       'complete show_menu'
  ble-decode/keymap:safe/.bind 'M-*'       'complete insert_all'
  ble-decode/keymap:safe/.bind 'C-TAB'     'menu-complete'
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
}

function ble/widget/safe/__attach__ {
  ble-edit/info/set-default text ''
}
function ble-decode/keymap:safe/define {
  local ble_bind_keymap=safe
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  ble-decode/keymap:safe/bind-complete

  ble-bind -f 'C-d'      'delete-region-or forward-char-or-exit'

  ble-bind -f 'SP'       magic-space
  ble-bind -f 'M-^'      history-expand-line

  ble-bind -f __attach__ safe/__attach__

  ble-bind -f 'C-c'      discard-line
  ble-bind -f 'C-j'      accept-line
  ble-bind -f 'C-RET'    accept-line
  ble-bind -f 'C-m'      accept-single-line-or-newline
  ble-bind -f 'RET'      accept-single-line-or-newline
  ble-bind -f 'C-o'      accept-and-next
  ble-bind -f 'C-g'      bell
  ble-bind -f 'C-x C-g'  bell
  ble-bind -f 'C-M-g'    bell

  ble-bind -f 'C-l'      clear-screen
  ble-bind -f 'M-l'      redraw-line

  ble-bind -f 'f1'       command-help
  ble-bind -f 'C-x C-v'  display-shell-version
  ble-bind -c 'C-z'      fg
  ble-bind -c 'M-z'      fg
}

function ble-edit/bind/load-keymap-definition:safe {
  ble-decode/keymap/load safe
}

ble/util/autoload "keymap/emacs.sh" \
                  ble-decode/keymap:emacs/define
ble/util/autoload "keymap/vi.sh" \
                  ble-decode/keymap:vi_{i,n,o,x,s,c}map/define
ble/util/autoload "keymap/vi_digraph.sh" \
                  ble-decode/keymap:vi_digraph/define

# 
#------------------------------------------------------------------------------
# **** ble/builtin/read ****                                         @edit.read

_ble_edit_read_accept=
_ble_edit_read_result=
function ble/widget/read/accept {
  _ble_edit_read_accept=1
  _ble_edit_read_result=$_ble_edit_str
  # [[ $_ble_edit_read_result ]] &&
  #   ble-edit/history/add "$_ble_edit_read_result" # Note: cancel でも登録する
  ble-decode/keymap/pop
}
function ble/widget/read/cancel {
  local _ble_edit_line_disabled=1
  ble/widget/read/accept
  _ble_edit_read_accept=2
}

function ble-decode/keymap:read/define {
  local ble_bind_keymap=read
  local ble_bind_nometa=
  ble-decode/keymap:safe/bind-common
  ble-decode/keymap:safe/bind-history
  # ble-decode/keymap:safe/bind-complete

  ble-bind -f 'C-c' read/cancel
  ble-bind -f 'C-\' read/cancel
  ble-bind -f 'C-m' read/accept
  ble-bind -f 'RET' read/accept
  ble-bind -f 'C-j' read/accept

  # shell functions
  ble-bind -f  'C-g'     bell
  # ble-bind -f  'C-l'     clear-screen
  ble-bind -f  'C-l'     redraw-line
  ble-bind -f  'M-l'     redraw-line
  ble-bind -f  'C-x C-v' display-shell-version

  # command-history
  # ble-bind -f 'M-^'      history-expand-line
  # ble-bind -f 'SP'       magic-space

  # ble-bind -f 'C-[' bell # unbound for "bleopt decode_isolated_esc=auto"
  ble-bind -f 'C-]' bell
  ble-bind -f 'C-^' bell
}

_ble_edit_read_history=()
_ble_edit_read_history_edit=()
_ble_edit_read_history_dirt=()
_ble_edit_read_history_ind=0
_ble_edit_read_history_onleave=()

function ble/builtin/read/.process-option {
  case $1 in
  (-e) opt_readline=1 ;;
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
      continue
    fi

    if [[ $arg == -- ]]; then
      is_normal_args=1
      continue
    fi

    local i n=${#arg}
    for ((i=1;i<n;i++)); do
      case -${arg:i} in
      (-[adinNptu])  ble/builtin/read/.process-option -${arg:i:1} "$1"; shift; break ;;
      (-[adinNptu]*) ble/builtin/read/.process-option -${arg:i:1} "${arg:i+1}"; break ;;
      (-[ers]*)      ble/builtin/read/.process-option -${arg:i:1} ;;
      esac
    done
  done
}

function ble/builtin/read/.setup-textarea {
  # 初期化
  local def_kmap; ble-decode/DEFAULT_KEYMAP -v def_kmap
  ble-decode/keymap/push read

  [[ $_ble_edit_read_context == external ]] &&
    _ble_canvas_panel_height[0]=0

  # textarea, info
  _ble_textarea_panel=1
  ble/textarea#invalidate
  ble-edit/info/set-default ansi ''

  # edit/prompt
  _ble_edit_PS1=$opt_prompt
  _ble_edit_prompt=("" 0 0 0 32 0 "" "")

  # edit
  _ble_edit_dirty_observer=()
  ble/widget/.newline/clear-content
  _ble_edit_arg=
  ble-edit/content/reset "$opt_default" newline
  _ble_edit_ind=${#opt_default}

  # edit/undo
  ble-edit/undo/clear-all

  # edit/history
  _ble_edit_history_prefix=_ble_edit_read_

  # syntax, highlight
  _ble_syntax_lang=text
  _ble_highlight_layer__list=(plain region overwrite_mode disabled)
}
function ble/builtin/read/TRAPWINCH {
  local IFS=$_ble_term_IFS
  _ble_textmap_pos=()
  ble/util/buffer "$_ble_term_ed"
  ble/textarea#redraw
}
function ble/builtin/read/.loop {
  set +m # ジョブ管理を無効にする

  # Note: サブシェルの中では eval で failglob を防御できない様だ。
  #   それが理由で visible-bell を呼び出すと read が終了してしまう。
  #   対策として failglob を外す。サブシェルの中なので影響はない筈。
  # ref #D1090
  shopt -u failglob

  local x0=$_ble_canvas_x y0=$_ble_canvas_y
  ble/builtin/read/.setup-textarea
  trap -- ble/builtin/read/TRAPWINCH WINCH

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

  ble-edit/info/reveal
  ble/textarea#render
  ble/util/buffer.flush >&2

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
    IFS= builtin read -r -d '' -n 1 $timeout_option char "${opts_in[@]}"; local ext=$?
    if ((ext==142)); then
      # timeout
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
    ble-decode/.hook/erase-progress
    ble-edit/info/reveal
    ble/textarea#render
    ble/util/buffer.flush >&2
  done

  # 入力が終わったら消すか次の行へ行く
  if [[ $_ble_edit_read_context == internal ]]; then
    local -a DRAW_BUFF=()
    ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
    ble/canvas/goto.draw "$x0" "$y0"
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
  local opt_readline= opt_prompt= opt_default= opt_timeout= opt_fd=0
  ble/builtin/read/.read-arguments "$@"
  if ! [[ $opt_readline && -t $opt_fd ]]; then
    # "-e オプションが指定されてかつ端末からの読み取り" のとき以外は builtin read する。
    [[ $opt_prompt ]] && ble/array#push opts -p "$opt_prompt"
    [[ $opt_timeout ]] && ble/array#push opts -t "$opt_timeout"
    __ble_args=("${opts[@]}" "${opts_in[@]}" -- "${vars[@]}")
    __ble_command='builtin read "${__ble_args[@]}"'
    return
  fi

  ble-decode/keymap/load read
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

## 関数 read [-ers] [-adinNptu arg] [name...]
##
##   ble.sh の所為で builtin read -e が全く動かなくなるので、
##   read -e を ble.sh の枠組みで再実装する。
##
function ble/builtin/read {
  if [[ $_ble_decode_bind_state == none ]]; then
    builtin read "$@"
    return
  fi

  local __ble_command= __ble_args= __ble_input=
  ble/builtin/read/.impl "$@"; local __ble_ext=$?
  [[ $__ble_command ]] || return "$__ble_ext"

  # 局所変数により被覆されないように外側で評価
  builtin eval -- "$__ble_command"
  return
}
function read { ble/builtin/read "$@"; }

#------------------------------------------------------------------------------
# **** command-help ****                                          @command-help

## 設定関数 ble/cmdinfo/help
## 設定関数 ble/cmdinfo/help:$command
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

## 関数 ble/widget/command-help/.read-man
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
  local pager_cmd=${pager%%[$' \t\n']*}
  [[ ${pager_cmd##*/} == less ]] || return 1

  # awk/gawk
  local awk=awk; type -t gawk &>/dev/null && awk=gawk

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
  eval "$manpager" <<< "$man_content" # 1 fork
}
## 関数 ble/widget/command-help.core
##   @var[in] type
##   @var[in] command
##   @var[in] comp_cword comp_words comp_line comp_point
function ble/widget/command-help.core {
  ble/function#try ble/cmdinfo/help:"$command" && return
  ble/function#try ble/cmdinfo/help "$command" && return

  if [[ $type == builtin || $type == keyword ]]; then
    # 組み込みコマンド・キーワードは man bash を表示
    ble/widget/command-help/.locate-in-man-bash "$command" && return
  elif [[ $type == function ]]; then
    # シェル関数は定義を表示
    local pager=ble/util/pager
    type -t source-highlight &>/dev/null &&
      pager='source-highlight -s sh -f esc | '$pager
    LESS="$LESS -r" eval 'declare -f "$command" | '"$pager" && return
  fi

  MANOPT= ble/bin/man "${command##*/}" 2>/dev/null && return
  # Note: $(man "${command##*/}") と (特に日本語で) 正しい結果が得られない。
  # if local content=$(MANOPT= ble/bin/man "${command##*/}" 2>&1) && [[ $content ]]; then
  #   builtin printf '%s\n' "$content" | ble/util/pager
  #   return
  # fi

  if local content; content=$("$command" --help 2>&1) && [[ $content ]]; then
    builtin printf '%s\n' "$content" | ble/util/pager
    return 0
  fi

  echo "ble: help of \`$command' not found" >&2
  return 1
}

## 関数 ble/widget/command-help/type.resolve-alias
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

    local old_literal=$literal old_command=$command

    local alias_def
    ble/util/assign alias_def "alias $command"
    unalias "$command"
    eval "alias_def=${alias_def#*=}" # remove quote
    literal=${alias_def%%[$' \t\n']*} command= type=
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
    unalias "$command" &>/dev/null
    ble/util/type type "$command"
  fi

  local q="'" Q="'\''"
  printf "type='%s'\n" "${type//$q/$Q}"
  printf "literal='%s'\n" "${literal//$q/$Q}"
  printf "command='%s'\n" "${command//$q/$Q}"
  return
} 2>/dev/null

## 関数 ble/widget/command-help/.type
##   @var[out] type command
function ble/widget/command-help/.type {
  local literal=$1
  type= command=
  ble/syntax:bash/simple-word/is-simple "$literal" || return 1
  local ret; ble/syntax:bash/simple-word/eval "$literal"; command=$ret
  ble/util/type type "$command"

  # alias の時はサブシェルで解決
  if [[ $type == alias ]]; then
    eval "$(ble/widget/command-help/.type/.resolve-alias "$literal" "$command")"
  fi

  if [[ $type == keyword && $command != "$literal" ]]; then
    if [[ $command == %* ]] && jobs -- "$command" &>/dev/null; then
      type=jobs
    elif ble/is-function "$command"; then
      type=function
    elif enable -p | ble/bin/grep -q -F -x "enable $cmd" &>/dev/null; then
      type=builtin
    elif type -P -- "$cmd" &>/dev/null; then
      type=file
    else
      type=
      return 1
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
  _ble_edit_io_stdout=
  _ble_edit_io_stderr=
  ble/util/openat _ble_edit_io_stdout '>&1'
  ble/util/openat _ble_edit_io_stderr '>&2'
  _ble_edit_io_fname1=$_ble_base_run/$$.stdout
  _ble_edit_io_fname2=$_ble_base_run/$$.stderr

  function ble-edit/bind/stdout.on {
    exec 1>&$_ble_edit_io_stdout 2>&$_ble_edit_io_stderr
  }
  function ble-edit/bind/stdout.off {
    ble/util/buffer.flush >&2
    ble-edit/bind/stdout/check-stderr
    exec 1>>$_ble_edit_io_fname1 2>>$_ble_edit_io_fname2
  }
  function ble-edit/bind/stdout.finalize {
    ble-edit/bind/stdout.on
    [[ -f $_ble_edit_io_fname1 ]] && ble/bin/rm -f "$_ble_edit_io_fname1"
    [[ -f $_ble_edit_io_fname2 ]] && ble/bin/rm -f "$_ble_edit_io_fname2"
  }

  ## 関数 ble-edit/bind/stdout/check-stderr
  ##   bash が stderr にエラーを出力したかチェックし表示する。
  function ble-edit/bind/stdout/check-stderr {
    local file=${1:-$_ble_edit_io_fname2}

    # if the visible bell function is already defined.
    if ble/is-function ble/term/visible-bell; then
      # checks if "$file" is an ordinary non-empty file
      #   since the $file might be /dev/null depending on the configuration.
      #   /dev/null の様なデバイスではなく、中身があるファイルの場合。
      if [[ -f $file && -s $file ]]; then
        local message= line
        while IFS= builtin read -r line || [[ $line ]]; do
          # * The head of error messages seems to be ${BASH##*/}.
          #   例えば ~/bin/bash-3.1 等から実行していると
          #   "bash-3.1: ～" 等というエラーメッセージになる。
          if [[ $line == 'bash: '* || $line == "${BASH##*/}: "* ]]; then
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
    function ble-edit/bind/stdout/TRAPUSR1 {
      [[ $_ble_term_state == internal ]] || return

      local IFS=$' \t\n'
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
            builtin eval "$_ble_decode_bind_hook" ;;
          esac
        done
      fi
    }

    trap -- 'ble-edit/bind/stdout/TRAPUSR1' USR1

    ble/bin/rm -f "$_ble_edit_io_fname2.pipe"
    ble/bin/mkfifo "$_ble_edit_io_fname2.pipe"
    {
      {
        function ble-edit/stdout/check-ignoreeof-message {
          local line=$1

          [[ $line == *$bleopt_internal_ignoreeof_trap* ||
               $line == *'Use "exit" to leave the shell.'* ||
               $line == *'ログアウトする為には exit を入力して下さい'* ||
               $line == *'シェルから脱出するには "exit" を使用してください。'* ||
               $line == *'シェルから脱出するのに "exit" を使いなさい.'* ||
               $line == *'Gebruik Kaart na Los Tronk'* ]] && return 0

          # lib/core-edit.ignoreeof-messages.txt の中身をキャッシュする様にする?
          [[ $line == *exit* ]] && ble/bin/grep -q -F "$line" "$_ble_base"/lib/core-edit.ignoreeof-messages.txt
        }

        while IFS= builtin read -r line; do
          SPACE=$' \n\t'
          if [[ $line == *[^$SPACE]* ]]; then
            builtin printf '%s\n' "$line" >> "$_ble_edit_io_fname2"
          fi

          if [[ $bleopt_internal_ignoreeof_trap ]] && ble-edit/stdout/check-ignoreeof-message "$line"; then
            builtin echo eof >> "$_ble_edit_io_fname2.proc"
            kill -USR1 $$
            ble/util/msleep 100 # 連続で送ると bash が落ちるかも (落ちた事はないが念の為)
          fi
        done < "$_ble_edit_io_fname2.pipe"
      } &>/dev/null & disown
    } &>/dev/null

    ble/util/openat _ble_edit_fd_stderr_pipe '> "$_ble_edit_io_fname2.pipe"'

    function ble-edit/bind/stdout.off {
      ble/util/buffer.flush >&2
      ble-edit/bind/stdout/check-stderr
      exec 1>>$_ble_edit_io_fname1 2>&$_ble_edit_fd_stderr_pipe
    }
  fi
fi

[[ $_ble_edit_detach_flag != reload ]] &&
  _ble_edit_detach_flag=
function ble-edit/bind/.exit-TRAPRTMAX {
  # シグナルハンドラの中では stty は bash によって設定されている。
  ble/base/unload
  builtin exit 0
}

## 関数 ble-edit/bind/.check-detach
##
##   @exit detach した場合に 0 を返します。それ以外の場合に 1 を返します。
##
function ble-edit/bind/.check-detach {
  # Note: #D1130 reload の為に detach して attach しなかった場合
  if [[ ! $_ble_attached && $_ble_edit_detach_flag == reload ]]; then
    ble-detach/message \
      "${_ble_term_setaf[12]}[ble: detached]$_ble_term_sgr0" \
      "Please run \`stty sane' to recover the correct TTY state."

    if ((_ble_bash>=40000)); then
      READLINE_LINE='stty sane;' READLINE_POINT=10
      printf %s "$READLINE_LINE"
    fi

    ble-edit/exec:gexec/.eval-prologue
    return 0
  fi

  if [[ ! -o emacs && ! -o vi ]]; then
    # 実は set +o emacs などとした時点で eval の評価が中断されるので、これを検知することはできない。
    # 従って、現状ではここに入ってくることはないようである。
    builtin echo "${_ble_term_setaf[9]}[ble: unsupported]$_ble_term_sgr0 Sorry, ble.sh is supported only with some editing mode (set -o emacs/vi)." 1>&2
    ble-detach
  fi

  if [[ $_ble_edit_detach_flag ]]; then
    type=$_ble_edit_detach_flag
    _ble_edit_detach_flag=
    #ble/term/visible-bell ' Bye!! '

    ble-detach/impl

    if [[ $type == exit ]]; then
      # ※この部分は現在使われていない。
      #   exit 時の処理は trap EXIT を用いて行う事に決めた為。
      #   一応 _ble_edit_detach_flag=exit と直に入力する事で呼び出す事はできる。
      ble-detach/message "${_ble_term_setaf[12]}[ble: exit]$_ble_term_sgr0"

      # bind -x の中から exit すると bash が stty を「前回の状態」に復元してしまう様だ。
      # シグナルハンドラの中から exit すれば stty がそのままの状態で抜けられる様なのでそうする。
      trap 'ble-edit/bind/.exit-TRAPRTMAX' RTMAX
      kill -RTMAX $$
    else
      ble-detach/message \
        "${_ble_term_setaf[12]}[ble: detached]$_ble_term_sgr0" \
        "Please run \`stty sane' to recover the correct TTY state."

      if ((_ble_bash>=40000)); then
        READLINE_LINE='stty sane;' READLINE_POINT=10
        printf %s "$READLINE_LINE"
      fi
    fi

    ble/base/restore-bash-options
    ble/base/restore-POSIXLY_CORRECT
    return 0
  else
    # Note: ここに入った時 -o emacs か -o vi のどちらかが成立する。なぜなら、
    #   [[ ! -o emacs && ! -o vi ]] のときは ble-detach が呼び出されるのでここには来ない。
    local state=$_ble_decode_bind_state
    if [[ ( $state == emacs || $state == vi ) && ! -o $state ]]; then
      ble-decode/reset-default-keymap
      ble-decode/detach
      ble-decode/attach
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
    ble/canvas/panel#goto.draw "$_ble_textarea_panel" "${_ble_edit_cur[0]}" "${_ble_edit_cur[1]}"
    ble/canvas/flush.draw
  }
fi

function ble-edit/bind/.head {
  ble-edit/bind/stdout.on

  [[ $bleopt_internal_suppress_bash_output ]] ||
    ble-edit/bind/.head/adjust-bash-rendering
}

function ble-edit/bind/.tail-without-draw {
  ble-edit/bind/stdout.off
}

if ((_ble_bash>=40000)); then
  function ble-edit/bind/.tail {
    ble-edit/info/reveal
    ble/textarea#render
    ble/util/idle.do && ble/textarea#render
    ble/textarea#adjust-for-bash-bind # bash-4.0+
    ble-edit/bind/stdout.off
  }
else
  function ble-edit/bind/.tail {
    ble-edit/info/reveal
    ble/textarea#render # bash-3 では READLINE_LINE を設定する方法はないので常に 0 幅
    ble/util/idle.do && ble/textarea#render # bash-4.0+
    ble-edit/bind/stdout.off
  }
fi

## ble-decode.sh 用の設定
function ble-decode/PROLOGUE {
  ble-edit/bind/.head
  ble-decode-bind/uvw
  ble/term/enter
}

## ble-decode.sh 用の設定
function ble-decode/EPILOGUE {
  if ((_ble_bash>=40000)); then
    # 貼付対策:
    #   大量の文字が入力された時に毎回再描画をすると滅茶苦茶遅い。
    #   次の文字が既に来て居る場合には描画処理をせずに抜ける。
    #   (再描画は次の文字に対する bind 呼出でされる筈。)
    if ble-decode/has-input; then
      ble-edit/bind/.tail-without-draw
      return 0
    fi
  fi

  # _ble_decode_bind_hook で bind/tail される。
  "ble-edit/exec:$bleopt_internal_exec_type/process" && return 0

  ble-edit/bind/.tail
  return 0
}

function ble/widget/print {
  ble-edit/content/clear-arg
  local message=$1
  [[ ${message//[$_ble_term_IFS]} ]] || return

  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  ble/util/buffer.flush >&2
  builtin printf '%s\n' "$message" >&2
}
function ble/widget/internal-command {
  ble-edit/content/clear-arg
  local -a BASH_COMMAND
  BASH_COMMAND=("$*")
  [[ ${BASH_COMMAND//[$_ble_term_IFS]} ]] || return 1

  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  eval "$BASH_COMMAND"
}
function ble/widget/external-command {
  ble-edit/content/clear-arg
  local -a BASH_COMMAND
  BASH_COMMAND=("$*")
  [[ ${BASH_COMMAND//[$_ble_term_IFS]} ]] || return 1

  ble-edit/info/hide
  ble/textarea#invalidate
  local -a DRAW_BUFF=()
  ble/canvas/panel#set-height.draw "$_ble_textarea_panel" 0
  ble/canvas/panel#goto.draw "$_ble_textarea_panel" 0 0
  ble/canvas/bflush.draw
  ble/term/leave
  ble/util/buffer.flush >&2
  eval "$BASH_COMMAND"; local ext=$?
  ble/term/enter
  return "$ext"
}
function ble/widget/execute-command {
  ble-edit/content/clear-arg
  local -a BASH_COMMAND
  BASH_COMMAND=("$*")

  _ble_edit_line_disabled=1 ble/widget/.insert-newline

  # Note: 空コマンドでも .insert-newline は実行する。
  [[ ${BASH_COMMAND//[$_ble_term_IFS]} ]] || return 1

  # やはり通常コマンドはちゃんとした環境で評価するべき
  ble-edit/exec/register "$BASH_COMMAND"
}

## 関数 ble/widget/.SHELL_COMMAND command
##   ble-bind -c で登録されたコマンドを処理します。
function ble/widget/.SHELL_COMMAND { ble/widget/execute-command "$@"; }

## 関数 ble/widget/.EDIT_COMMAND command
##   ble-bind -x で登録されたコマンドを処理します。
function ble/widget/.EDIT_COMMAND {
  local command=$1
  local READLINE_LINE=$_ble_edit_str
  local READLINE_POINT=$_ble_edit_ind
  ble/widget/.hide-current-line
  ble/util/buffer.flush >&2
  eval "$command" || return 1
  ble-edit/content/clear-arg

  [[ $READLINE_LINE != "$_ble_edit_str" ]] &&
    ble-edit/content/reset-and-check-dirty "$READLINE_LINE"
  ((_ble_edit_ind=READLINE_POINT))
}

## ble-decode.sh 用の設定
function ble-decode/DEFAULT_KEYMAP {
  local ret
  bleopt/get:default_keymap; local defmap=$ret
  if ble-edit/bind/load-keymap-definition "$defmap"; then
    if [[ $defmap == vi ]]; then
      builtin eval -- "$2=vi_imap"
    else
      builtin eval -- "$2=\$defmap"
    fi && ble-decode/keymap/is-keymap "${!2}" && return 0
  fi

  echo "ble.sh: The definition of the default keymap \"$bleopt_default_keymap\" is not found. ble.sh uses \"safe\" keymap instead."
  ble-edit/bind/load-keymap-definition safe &&
    builtin eval -- "$2=safe" &&
    bleopt_default_keymap=safe
}

function ble-edit/bind/load-keymap-definition {
  local name=$1
  if ble/is-function ble-edit/bind/load-keymap-definition:"$name"; then
    ble-edit/bind/load-keymap-definition:"$name"
  else
    source "$_ble_base/keymap/$name.sh"
  fi
}
function ble-edit/bind/clear-keymap-definition-loader {
  unset -f ble-edit/bind/load-keymap-definition:safe
  unset -f ble-edit/bind/load-keymap-definition:emacs
  unset -f ble-edit/bind/load-keymap-definition:vi
}

#------------------------------------------------------------------------------
# **** entry points ****

function ble-edit/initialize {
  ble-edit/prompt/initialize
}
function ble-edit/attach {
  ble-edit/attach/.attach
  _ble_canvas_x=0 _ble_canvas_y=0
  ble/util/buffer "$_ble_term_cr"
}
function ble-edit/reset-history {
  if ((_ble_bash>=40000)); then
    _ble_edit_history_loaded=
    ble-edit/history/clear-background-load
    ble/util/idle.push 'ble-edit/history/load async'
  elif ((_ble_bash>=30100)) && [[ $bleopt_history_lazyload ]]; then
    _ble_edit_history_loaded=
  else
    # * history-load は initialize ではなく attach で行う。
    #   detach してから attach する間に
    #   追加されたエントリがあるかもしれないので。
    # * bash-3.0 では history -s は最近の履歴項目を置換するだけなので、
    #   履歴項目は全て自分で処理する必要がある。
    #   つまり、初めから load しておかなければならない。
    ble-edit/history/load
  fi
}
function ble-edit/detach {
  ble-edit/bind/stdout.finalize
  ble-edit/attach/.detach
}
