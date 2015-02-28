#!/bin/bash
#
# ble-autoload "$_ble_base/complete.sh" ble-edit+complete
#

## 既存の action
##
##   ble-complete/action/word
##   ble-complete/action/file
##
## action の実装
##
## 関数 $ACTION/initialize
##   基本的に INSERT を設定すれば良い
##   @var[in    ] CAND
##   @var[in,out] ACTION
##   @var[in,out] DATA
##   @var[in,out] SHOW
##   @var[in,out] INSERT
##     COMP1-COMP2 を置き換える文字列を指定します
##
##   @var[in    ] COMP1 COMP2 COMPS COMPV
##     COMP1-COMP2 は補完対象の範囲を指定します。
##     COMPS は COMP1-COMP2 にある文字列を表し、
##     COMPV は COMPS の評価値 (クォート除去、簡単なパラメータ展開をした値) を表します。
##     COMPS に複雑な構造が含まれていて即時評価ができない場合は
##     COMPV は unset になります。必要な場合は [[ ${COMPV+set} ]] で判定して下さい。
##     ※ [[ -v COMPV ]] は bash-4.2 以降です。
##
##   @var[in    ] COMP_PREFIX
##   @var[in    ] _ble_complete_raw_paramx
##
## 関数 $ACTION/complete
##   一意確定時に、挿入文字列に対する加工を行います。
##   例えばディレクトリ名の場合に / を後に付け加える等です。
##   
##   @var[in    ] CAND
##   @var[in    ] ACTION
##   @var[in    ] DATA
##   
##   @var[in,out] COMP1 COMP2 INSERT
##

function ble-complete/yield-candidate {
  local CAND="$1" ACTION="$2" DATA="${*:3}"
  local SHOW="${1#"$COMP_PREFIX"}" INSERT="$CAND"
  "$ACTION/initialize"
  
  local icand
  ((icand=cand_count++))
  cand_cand[icand]="$CAND"
  cand_prop[icand]="$ACTION $COMP1 $COMP2"
  cand_word[icand]="$INSERT"
  cand_show[icand]="$SHOW"
  cand_data[icand]="$DATA"
}

function ble-complete/util/escape-specialchars {
  local _a _b _var=ret
  [[ $1 == -v ]] && { _var="$2"; shift 2; }
  local _ret="$*"
  if [[ $_ret == *['][\ "'\''$|&;<>()*?{}!^']* ]]; then
    _a=\\ _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\  _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\" _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\' _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\$ _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\| _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\& _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\; _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\< _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\> _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\( _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\) _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\[ _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\* _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\? _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\] _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\{ _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\} _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\! _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
    _a=\^ _b="\\$_a" _ret="${_ret//"$_a"/$_b}"
  fi
  eval "$_var=\"\$_ret\""
}

function ble-complete/action/word/initialize {
  local ins
  ble-complete/util/escape-specialchars -v ins "${CAND:${#COMPV}}"

  [[ $_ble_complete_raw_paramx && $ins == [a-zA-Z_0-9]* ]] && ins='\'"$ins"

  INSERT="$COMPS$ins"
}
function ble-complete/action/word/complete {
  INSERT="$INSERT "
}

function ble-complete/action/file/initialize {
  ble-complete/action/word/initialize
}
function ble-complete/action/file/complete {
  if [[ -e $CAND ]]; then
    if [[ -d $CAND ]]; then
      INSERT="$INSERT/"
    else
      INSERT="$INSERT "
    fi
  fi
}

function ble-edit+complete {
  local text="$_ble_edit_str" index="$_ble_edit_ind"
  _ble_edit_str.update-syntax
  local context
  ble-syntax/completion-context "$text" "$index"
  # .ble-line-info.draw "${context[*]}"
  # return

  if ((${#context[@]}==0)); then
    .ble-edit.bell
    .ble-line-info.clear
    return
  fi

  local cand_count=0
  local -a cand_cand=() # 候補文字列
  local -a cand_prop=() # 関数 開始 終了
  local -a cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  local -a cand_show=() # 表示文字列 (～ 分かり易い文字列)
  local -a cand_data=() # 関数で使うデータ

  local rex_raw_paramx='^('"$_ble_syntax_rex_simple_word_element"'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

  local ctx cand
  for ctx in "${context[@]}"; do
    # initialize completion range
    ctx=($ctx)
    local COMP1="${ctx[1]}" COMP2="$index"
    local COMPS="${text:COMP1:COMP2-COMP1}"
    local COMPV _ble_complete_raw_paramx=
    if [[ -z $COMPS || $COMPS =~ $_ble_syntax_rex_simple_word ]]; then
      eval "COMPV=$COMPS"
      [[ $COMPS =~ $rex_raw_paramx ]] && _ble_complete_raw_paramx=1
    fi
    local COMP_PREFIX=

    # generate candidates
    local cand ACTION DATA arr
    case "${ctx[0]}" in
    (file)
      if [[ ${COMPV+set} ]]; then
        [[ $COMPV =~ ^.+/ ]] &&
          COMP_PREFIX="${BASH_REMATCH[0]}"
        for cand in "$COMPV"*; do
          [[ -e "$cand" ]] || continue
          ble-complete/yield-candidate "$cand" ble-complete/action/file
        done
      fi ;;
    (command)
      if [[ ${COMPV+set} ]]; then
        [[ $COMPV =~ ^.+/ ]] &&
          COMP_PREFIX="${BASH_REMATCH[0]}"
        IFS=$'\n' eval 'arr=($(compgen -c -- "$COMPV"; [[ $COMPV == */* ]] && compgen -A function -- "$COMPV"))'
        for cand in "${arr[@]}"; do
          ble-complete/yield-candidate "$cand" ble-complete/action/word
        done
      fi ;;
    (variable)
      if [[ ${COMPV+set} ]]; then
        IFS=$'\n' eval 'arr=($(compgen -v -- "$COMPV"))'
        for cand in "${arr[@]}"; do
          ble-complete/yield-candidate "$cand" ble-complete/action/word
        done
      fi ;;
    esac
  done

  if ((cand_count==0)); then
    .ble-edit.bell
    .ble-line-info.clear
    return
  fi

  # 共通部分
  local i common comp1 clen comp2="$index"
  for ((i=0;i<cand_count;i++)); do
    local word="${cand_word[i]}"
    local -a prop
    prop=(${cand_prop[i]})

    if ((i==0)); then
      common="$word"
      comp1="${prop[1]}"
      clen="${#common}"
    else
      if ((comp1<prop[1])); then
        word="${text:comp1:prop[1]-comp1}""$word"
      elif ((comp1>prop[1])); then
        common="${text:prop[1]:comp1-prop[1]}""$common"
        comp1="${prop[1]}"
      fi

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common="${common::clen}"
    fi
  done

  # 編集範囲の最小化
  if [[ $common == "${text:comp1:comp2-comp1}"* ]]; then
    # 既存部分の置換がない場合
    common="${common:comp2-comp1}"
    ((comp1=comp2))
  else
    # 既存部分の置換がある場合
    while ((comp1<comp2)) && [[ $common == "${text:comp1:1}"* ]]; do
      common="${common:1}"
      ((comp1++))
    done
  fi

  if ((cand_count==1)); then
    # 一意確定の時
    local ACTION
    ACTION=(${cand_prop[0]})
    if ble/util/isfunction "$ACTION/complete"; then
      local COMP1="$comp1" COMP2="$comp2"
      local INSERT="$common"
      local CAND="${cand_cand[0]}"
      local DATA="${cand_data[0]}"

      "$ACTION/complete"
      comp1="$COMP1" comp2="$COMP2" common="$INSERT"
    fi
    .ble-line-info.clear
  else
    # 候補が複数ある時
    .ble-line-info.draw "${cand_show[*]}"
  fi

  .ble-edit.delete-range "$comp1" "$index"
  ble-edit+insert-string "$common"
}
