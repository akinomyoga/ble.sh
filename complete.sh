#!/bin/bash
#
# ble-autoload "$_ble_base/complete.sh" ble-edit+complete
#

# ## 関数 ble-complete/action/word/unique
# ##   @var[in,out] CAND
# ##   @var[in    ] CAND_HEAD
# ##   @var[in    ] CAND_DATA
# function ble-complete/action/default/unique {
#   :
# }
# function ble-complete/action/default/insert {
#   if [[ $CAND == "$CAND_HEAD"* ]]; then
#     local ins="${CAND:${#CAND_HEAD}}"
#     ble-edit+insert-string "$ins"
#   else
#     .ble-edit.delete-range "${CAND_PROP[1]}" "${CAND_PROP[2]}"
#     ble-edit+insert-string "$CAND"
#   fi
# }

# function ble-complete/action/word/unique {
#   CAND="$CAND "
# }
# function ble-complete/action/word/insert {
#   if [[ $CAND == "$CAND_HEAD"* ]]; then
#     local ins="${CAND:${#CAND_HEAD}}"

#     if [[ $ins == [a-zA-Z_0-9]* ]]; then
#       # 直前のパラメータ展開とくっつかない様に修正
#       local rex='^'"$_ble_syntax_rex_simple_word_element"'*(\$[a-zA-Z_][a-zA-Z_0-9]*)$'
#       if [[ ${text:CAND_PROP[1]:CAND_PROP[2]-CAND_PROP[1]} =~ $rex ]]; then
#         local rematchCount="${#BASH_REMATCH[*]}"
#         local param="${BASH_REMATCH[rematchCount-1]}"
#         .ble-edit.delete-range "$((CAND_PROP[2]-${#param}))" "${CAND_PROP[2]}"
#         ins="\${${param:1}}$ins"
#       fi
#     fi

#     ble-edit+insert-string "$ins"
#   else
#     .ble-edit.delete-range "${CAND_PROP[1]}" "${CAND_PROP[2]}"
#     ble-edit+insert-string "$CAND"
#   fi
# }

# function ble-complete/action/file/unique {
#   if [[ -e $CAND ]]; then
#     if [[ -d $CAND ]]; then
#       CAND="$CAND/"
#     else
#       CAND="$CAND "
#     fi
#   fi
# }
# function ble-complete/action/file/insert {
#   ble-complete/action/word/insert
# }
# function ble-complete/action/command/unique {
#   ble-complete/action/word/unique
# }
# function ble-complete/action/command/insert {
#   ble-complete/action/word/insert
# }

# function ble-edit+complete.v2 {
#   # 試験実装

#   local text="$_ble_edit_str" index="$_ble_edit_ind"
#   _ble_edit_str.update-syntax
#   local context
#   ble-syntax/completion-context "$text" "$index"
#   # .ble-line-info.draw "${context[*]}"
#   # return

#   if ((${#context[@]}==0)); then
#     .ble-edit.bell
#     .ble-line-info.clear
#     return
#   fi

#   local cand_word=() # word
#   local cand_head=() # head
#   local cand_show=() # 表示文字列
#   local cand_prop=() # 関数 開始 終了
#   local cand_data=() # 関数で使うデータ

#   local ctx head vhead cand
#   for ctx in "${context[@]}"; do
#     ctx=($ctx)
#     head="${text:ctx[1]:index-ctx[1]}"
#     if [[ -z $head || $head =~ $_ble_syntax_rex_simple_word ]]; then
#       eval "vhead=$head"
#       case "${ctx[0]}" in
#       (file)
#         local vhead_prefix_length=0
#         [[ $vhead =~ ^.+/ ]] &&
#           vhead_prefix_length=${#BASH_REMATCH[0]}

#         # compgen を使うと勝手に quote 削除やら tilde 展開をして
#         # しかも間違っているので、代わりに glob で候補列挙する。
#         for cand in "$vhead"*; do
#           [[ -e "$cand" ]] || continue
#           cand_word+=("$cand")
#           cand_head+=("$vhead")
#           cand_show+=("${cand:vhead_prefix_length}")
#           cand_prop+=("ble-complete/action/file ${ctx[1]} $index ${#vhead}")
#           cand_data+=("")
#         done  ;;
#       (command)
#         if [[ $vhead ]]; then
#           local vhead_prefix_length=0
#           [[ $vhead =~ ^.+/ ]] &&
#             vhead_prefix_length=${#BASH_REMATCH[0]}

#           IFS=$'\n' eval 'local arr=($(compgen -c -- "$vhead"))'
#           for cand in "${arr[@]}"; do
#             cand_word+=("$cand")
#             cand_head+=("$vhead")
#             cand_show+=("${cand:vhead_prefix_length}")
#             cand_prop+=("ble-complete/action/word ${ctx[1]} $index ${#vhead}")
#             cand_data+=("")
#           done
#         fi ;;
#       (variable)
#         if [[ $vhead ]]; then
#           IFS=$'\n' eval 'local arr=($(compgen -v -- "$vhead"))'
#           for cand in "${arr[@]}"; do
#             cand_word+=("$cand")
#             cand_head+=("$vhead")
#             cand_show+=("$cand")
#             cand_prop+=("ble-complete/action/variable ${ctx[1]} $index ${#vhead}")
#             cand_data+=("")
#           done
#         fi;;
#       esac
#     fi
#   done

#   if ((${#cand_word[@]}==0)); then
#     .ble-edit.bell
#     .ble-line-info.clear
#     return
#   fi

#   # 共通部分
#   local i iN="${#cand_word[@]}"
#   local common clen=-1 count=0 cindex=-1
#   for ((i=0;i<iN;i++)); do
#     local word="${cand_word[i]}"
#     local head="${cand_head[i]}"
#     if [[ $word == "$head"* ]]; then
#       local ins="${word:${#head}}"
#       if ((cindex=i,count++==0)); then
#         common="$ins"
#         clen="${#ins}"
#       elif [[ $ins != "$common"* ]]; then
#         ((clen>${#ins}&&(clen=${#ins})))
#         while [[ "${ins::clen}" != "${common::clen}" ]]; do
#           ((clen--));
#         done
#         common="${common::clen}"
#       fi
#     fi
#   done

#   if ((count==0)); then
#     .ble-edit.bell
#     .ble-line-info.clear
#   elif ((count==1)); then
#     # 一意確定の時
#     local CAND_PROP=(${cand_prop[cindex]})
#     local CAND="${cand_word[cindex]}"
#     local -r CAND_HEAD="${cand_head[cindex]}"
#     local CAND_DATA="${cand_data[cindex]}"
#     if ble/util/isfunction "$CAND_PROP/unique"; then
#       "$CAND_PROP/unique"
#     else
#       ble-complete/action/default/unique
#     fi
    
#     if ble/util/isfunction "$CAND_PROP/insert"; then
#       "$CAND_PROP/insert"
#     else
#       ble-complete/action/default/insert
#     fi

#     .ble-line-info.clear
#   else
#     # 複数の異なる種類の insert が混ざっている時にどの様に取り扱うべきか?
#     # - command, file は同じ insert を使うので混ぜても OK
#     # - variable は異なる insert を用いる必要がある
#     # - 両候補が混在している時は insert するべきでない?
#     #   そもそも二種類の補完が混ざっている事自体が悪いのかも知れない。
#     if [[ $common ]]; then
#       ble-edit+insert-string "$common"
#     fi

#     .ble-line-info.draw "${cand_show[*]}"
#   fi
# }


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
  local cand_cand=() # 候補文字列
  local cand_prop=() # 関数 開始 終了
  local cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  local cand_show=() # 表示文字列 (～ 分かり易い文字列)
  local cand_data=() # 関数で使うデータ

  local rex_raw_paramx='^('"$_ble_syntax_rex_simple_word_element"'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

  local ctx head vhead cand
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
    local cand ACTION DATA
    case "${ctx[0]}" in
    (file)
      if [[ ${COMPV+set} ]]; then
        [[ $COMPV =~ ^.+/ ]] &&
          COMP_PREFIX=${#BASH_REMATCH[0]}
        for cand in "$COMPV"*; do
          [[ -e "$cand" ]] || continue
          ble-complete/yield-candidate "$cand" ble-complete/action/file
        done
      fi ;;
    (command)
      if [[ ${COMPV+set} ]]; then
        [[ $COMPV =~ ^.+/ ]] &&
          COMP_PREFIX=${#BASH_REMATCH[0]}
        IFS=$'\n' eval 'local arr=($(compgen -c -- "$COMPV"))'
        for cand in "${arr[@]}"; do
          ble-complete/yield-candidate "$cand" ble-complete/action/word
        done
      fi ;;
    (variable)
      if [[ ${COMPV+set} ]]; then
        IFS=$'\n' eval 'local arr=($(compgen -v -- "$COMPV"))'
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
    local prop=(${cand_prop[i]})

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
    local ACTION=(${cand_prop[0]})
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
