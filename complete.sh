#!/bin/bash
#
# ble-autoload "$_ble_base/complete.sh" ble/widget/complete
#

#==============================================================================
# action

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

function ble-complete/util/escape-specialchars {
  eval "$ble_util_upvar_setup"
  local a b ret="$*" chars=']['$' \t\n\\''"'\''`$|&;<>()*?{}!^'
  if [[ $ret == *["$chars"]* ]]; then
    a=\\ b="\\$a" ret="${ret//"$a"/$b}"
    a=\" b="\\$a" ret="${ret//"$a"/$b}"
    a=\' b="\\$a" ret="${ret//"$a"/$b}"
    a=\` b="\\$a" ret="${ret//"$a"/$b}"
    a=\$ b="\\$a" ret="${ret//"$a"/$b}"
    a=' '   b="\\$a"   ret="${ret//"$a"/$b}"
    a=$'\t' b="\\$a"   ret="${ret//"$a"/$b}"
    a=$'\n' b="\$'\n'" ret="${ret//"$a"/$b}"
    a=\| b="\\$a" ret="${ret//"$a"/$b}"
    a=\& b="\\$a" ret="${ret//"$a"/$b}"
    a=\; b="\\$a" ret="${ret//"$a"/$b}"
    a=\< b="\\$a" ret="${ret//"$a"/$b}"
    a=\> b="\\$a" ret="${ret//"$a"/$b}"
    a=\( b="\\$a" ret="${ret//"$a"/$b}"
    a=\) b="\\$a" ret="${ret//"$a"/$b}"
    a=\[ b="\\$a" ret="${ret//"$a"/$b}"
    a=\* b="\\$a" ret="${ret//"$a"/$b}"
    a=\? b="\\$a" ret="${ret//"$a"/$b}"
    a=\] b="\\$a" ret="${ret//"$a"/$b}"
    a=\{ b="\\$a" ret="${ret//"$a"/$b}"
    a=\} b="\\$a" ret="${ret//"$a"/$b}"
    a=\! b="\\$a" ret="${ret//"$a"/$b}"
    a=\^ b="\\$a" ret="${ret//"$a"/$b}"
  fi
  eval "$ble_util_upvar"
}

function ble-complete/util/escape-regexchars {
  eval "$ble_util_upvar_setup"
  local a b ret="$*"
  if [[ $ret == *['\.[*^$/']* ]]; then
    a=\\ b="\\$a" ret="${ret//"$a"/$b}"
    a=\. b="\\$a" ret="${ret//"$a"/$b}"
    a=\[ b="\\$a" ret="${ret//"$a"/$b}"
    a=\* b="\\$a" ret="${ret//"$a"/$b}"
    a=\^ b="\\$a" ret="${ret//"$a"/$b}"
    a=\$ b="\\$a" ret="${ret//"$a"/$b}"
    a=\/ b="\\$a" ret="${ret//"$a"/$b}"
  fi
  eval "$ble_util_upvar"
}

function ble-complete/action/util/complete.addtail {
  INSERT="$INSERT$1"
  [[ ${text:index} == "$1"* ]] && ((index++))
}

#------------------------------------------------------------------------------

# action/plain

function ble-complete/action/plain/initialize {
  local ins
  ble-complete/util/escape-specialchars -v ins "${CAND:${#COMPV}}"

  [[ $_ble_complete_raw_paramx && $ins == [a-zA-Z_0-9]* ]] && ins='\'"$ins"

  INSERT="$COMPS$ins"
}
function ble-complete/action/plain/complete { :; }

# action/word

function ble-complete/action/word/initialize {
  ble-complete/action/plain/initialize
}
function ble-complete/action/word/complete {
  ble-complete/action/util/complete.addtail ' '
}

# action/file

function ble-complete/action/file/initialize {
  ble-complete/action/plain/initialize
}
function ble-complete/action/file/complete {
  local tail=
  if [[ -e $CAND || -h $CAND ]]; then
    if [[ -d $CAND ]]; then
      ble-complete/action/util/complete.addtail /
      tail=/
    else
      ble-complete/action/util/complete.addtail ' '
    fi
  fi
}

# action/argument

function ble-complete/action/argument/initialize { ble-complete/action/plain/initialize; }
function ble-complete/action/argument/complete {
  if [[ -d $CAND ]]; then
    ble-complete/action/util/complete.addtail /
  else
    ble-complete/action/util/complete.addtail ' '
  fi
}
function ble-complete/action/argument-nospace/initialize { ble-complete/action/plain/initialize; }
function ble-complete/action/argument-nospace/complete {
  if [[ -d $CAND ]]; then
    ble-complete/action/util/complete.addtail /
  fi
}

# action/command

function ble-complete/action/command/initialize {
  ble-complete/action/plain/initialize
}
function ble-complete/action/command/complete {
  if [[ -d $CAND ]]; then
    ble-complete/action/util/complete.addtail /
  else
    ble-complete/action/util/complete.addtail ' '
  fi
}

# action/variable

function ble-complete/action/variable/initialize { ble-complete/action/plain/initialize; }
function ble-complete/action/variable/complete {
  ble-complete/action/util/complete.addtail '='
}

#==============================================================================
# source

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

# source/wordlist

function ble-complete/source/wordlist {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX="${BASH_REMATCH[0]}"

  local cand
  for cand; do
    if [[ $cand == "$COMPV"* ]]; then
      ble-complete/yield-candidate "$cand" ble-complete/action/word
    fi
  done
}

# source/command

function ble-complete/source/command/gen {
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return
  compgen -c -- "$COMPV"
  [[ $COMPV == */* ]] && compgen -A function -- "$COMPV"
  shopt -q autocd &>/dev/null && compgen -d -- "$COMPV"
}
function ble-complete/source/command {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX="${BASH_REMATCH[0]}"

  local cand arr i=0
  local compgen
  ble/util/assign compgen ble-complete/source/command/gen
  ble/string#split arr $'\n' "$compgen"
  for cand in "${arr[@]}"; do
    ((i++%100==0)) && ble/util/is-stdin-ready && return 27
    ble-complete/yield-candidate "$cand" ble-complete/action/command
  done

  ble-complete/source/dir
}

# source/file

function ble-complete/source/file {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX="${BASH_REMATCH[0]}"

  local cand
  for cand in "$COMPV"*; do
    [[ -e $cand || -h $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    ble-complete/yield-candidate "$cand" ble-complete/action/file
  done
}

# source/dir

function ble-complete/source/dir {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX="${BASH_REMATCH[0]}"

  local cand
  for cand in "$COMPV"*/; do
    [[ -d $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    ble-complete/yield-candidate "${cand%/}" ble-complete/action/file
  done
}

# source/argument (complete -p)

function ble-complete/source/argument/.compgen-helper-vars {
  COMP_WORDS=("${comp_words[@]}")
  COMP_LINE="$comp_line"
  COMP_POINT="$comp_point"
  COMP_CWORD="$comp_cword"
  COMP_TYPE=9
  COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode-key/.invoke-command
}
function ble-complete/source/argument/.compgen-helper-prog {
  if [[ $comp_prog ]]; then
    (
      local COMP_WORDS COMP_CWORD
      export COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
      ble-complete/source/argument/.compgen-helper-vars
      local cmd="${comp_words[0]}" cur="${comp_words[comp_cword]}" prev="${comp_words[comp_cword-1]}"
      "$comp_prog" "$cmd" "$cur" "$prev"
    )
  fi
}
function ble-complete/source/argument/.compgen-helper-func {
  [[ $comp_func ]] || return
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY
  ble-complete/source/argument/.compgen-helper-vars

  # compopt に介入して -o/+o option を読み取る。
  function compopt {
    builtin compopt "$@"; local ret="$?"

    local -a ospec
    while (($#)); do
      local arg="$1"; shift
      case "$arg" in
      (-*)
        local ic c
        for ((ic=1;ic<${#arg};ic++)); do
          c="${arg:ic:1}"
          case "$c" in
          (o)    ospec[${#ospec[@]}]="-$1"; shift ;;
          ([DE]) fDefault=1; break 2 ;;
          (*)    ((ret==0&&(ret=1))) ;;
          esac
        done ;;
      (+o) ospec[${#ospec[@]}]="+$1"; shift ;;
      (*)
        # 特定のコマンドに対する compopt 指定
        return "$ret" ;;
      esac
    done

    local s
    for s in "${ospec[@]}"; do
      case "$s" in
      (-*) comp_opts="$comp_opts${s:1}:" ;;
      (+*) comp_opts="${comp_opts//:${s:1}/:}" ;;
      esac
    done

    return "$ret"
  }


  local cmd="${comp_words[0]}" cur="${comp_words[comp_cword]}" prev="${comp_words[comp_cword-1]}"
  "$comp_func" "$cmd" "$cur" "$prev"

  unset -f compopt
}

## 関数 ble-complete/source/argument/.compgen
## @var[out] comp_opts
## @var[in] COMPV
## @var[in] index _ble_syntax_*
## @var[in] 他色々
## @exit 入力がある時に 27 を返します。
function ble-complete/source/argument/.compgen {
  shopt -q progcomp || return 1

  local comp_words comp_line comp_point comp_cword
  local comp_prog= comp_func=
  ble-syntax:bash/extract-command "$index" || return 1

  local cmd="${comp_words[0]}" compcmd=
  if complete -p "$cmd" &>/dev/null; then
    compcmd="$cmd"
  elif [[ ${cmd##*/} != $cmd ]] && complete -p "${cmd##*/}" &>/dev/null; then
    compcmd="${cmd##*/}"
  elif complete -p -D &>/dev/null; then
    compcmd='-D'
  fi

  [[ $compcmd ]] || return 1

  local -a compargs compoptions
  local iarg=1
  eval "compargs=($(complete -p "$cmd" 2>/dev/null))"
  while ((iarg<${#compargs[@]})); do
    local arg="${compargs[iarg++]}"
    case "$arg" in
    (-*)
      local ic c
      for ((ic=1;ic<${#arg};ic++)); do
        c="${arg:ic:1}"
        case "$c" in
        ([abcdefgjksuvDE])
          ble/array#push compoptions "-$c" ;;
        ([pr])
          ;; # 無視 (-p 表示 -r 削除)
        ([AGWXPS])
          ble/array#push compoptions "-$c" "${compargs[iarg++]}" ;;
        (o)
          local o="${compargs[iarg++]}"
          comp_opts="$comp_opts$o:"
          ble/array#push compoptions "-$c" "$o" ;;
        (F)
          comp_func="${compargs[iarg++]}"
          ble/array#push compoptions "-$c" ble-complete/source/argument/.compgen-helper-func ;;
        (C)
          comp_prog="${compargs[iarg++]}"
          ble/array#push compoptions "-$c" ble-complete/source/argument/.compgen-helper-prog ;;
        (*)
          # just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done

  ble/util/is-stdin-ready && return 27

  local rex_compv arr compgen
  ble-complete/util/escape-regexchars -v rex_compv "$COMPV"
  ble/util/assign compgen 'compgen "${compoptions[@]}" -- "$COMPV" 2>/dev/null'
  ble/util/assign compgen 'command sed -n "/^$rex_compv/{s/[[:space:]]\{1,\}\$//;p;}" <<< "$compgen" | command sort -u' 2>/dev/null
  ble/string#split arr $'\n' "$compgen"
  # * 一旦 compgen だけで ble/util/assign するのは、compgen をサブシェルではなく元のシェルで評価する為である。
  #   補完関数が遅延読込になっている場合などに、読み込まれた補完関数が次回から使える様にする為に必要である。
  # * "$COMPV" で始まる単語だけを候補として列挙する為に sed /^$rex_compv/ でフィルタする。
  #   compgen に -- "$COMPV" を渡しても何故か思うようにフィルタしてくれない為である。
  #   (compgen -W "$(compgen ...)" -- "$COMPV" の様にしないと駄目なのか?)
  # * sed で末端の [[:space:]]+ を除去する。
  #   git の補完関数など勝手に末尾に space をつける物が存在する為である。
  #   単語の後にスペースを挿入する事を意図していると思われるが、
  #   通常 compgen (例: compgen -f) で生成される候補に含まれるスペースは、挿入時のエスケープ対象である。
  #   →これだとスペースで終わるファイル名を挿入できない…。
  # * arr=($(...)) としないのは IFS=$'\n' の影響を $(...) の中に持ち込まないためである。

  local action=argument
  [[ $comp_opts == *:nospace:* ]] && action=argument-nospace

  local cand i=0 count=0
  for cand in "${arr[@]}"; do
    ((i++%100==0)) && ble/util/is-stdin-ready && return 27
    ble-complete/yield-candidate "$cand" ble-complete/action/"$action"
    ((count++))
  done

  ((count!=0))
}

function ble-complete/source/argument {
  local comp_opts=:

  # try complete&compgen
  ble-complete/source/argument/.compgen; local exit="$?"
  [[ $exit == 0 || $exit == 27 ]] && return "$exit"

  # 候補が見付からない場合
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble-complete/source/dir
  else
    # filenames, default, bashdefault
    ble-complete/source/file
  fi
}

# source/variable

function ble-complete/source/variable {
  [[ ${COMPV+set} ]] || return 1

  local action
  if [[ $1 == '=' ]]; then
    action=variable # 確定時に '=' を挿入
  else
    action=word # 確定時に ' ' を挿入
  fi

  local cand arr compgen
  ble/util/assign compgen 'compgen -v -- "$COMPV"'
  ble/string#split arr $'\n' "$compgen"

  for cand in "${arr[@]}"; do
    ble-complete/yield-candidate "$cand" ble-complete/action/"$action"
  done
}

#------------------------------------------------------------------------------

function ble-complete/.fignore/prepare {
  _fignore=()
  local i=0 leaf tmp
  ble/string#split tmp ':' "$FIGNORE"
  for leaf in "${tmp[@]}"; do
    [[ $leaf ]] && _fignore[i++]="$leaf"
  done
}
function ble-complete/.fignore/filter {
  local pat
  for pat in "${_fignore[@]}"; do
    [[ $1 == *"$pat" ]] && return 1
  done
}

function ble/widget/complete {
  local text="$_ble_edit_str" index="$_ble_edit_ind"
  _ble_edit_str.update-syntax
  local context
  ble-syntax/completion-context "$text" "$index"
  # ble-edit/info/draw-text "${context[*]}"
  # return

  if ((${#context[@]}==0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return
  fi

  local cand_count=0
  local -a cand_cand=() # 候補文字列
  local -a cand_prop=() # 関数 開始 終了
  local -a cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  local -a cand_show=() # 表示文字列 (～ 分かり易い文字列)
  local -a cand_data=() # 関数で使うデータ

  local rex_raw_paramx='^('"$_ble_syntax_rex_simple_word_element"'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

  if [[ $FIGNORE ]]; then
    local -a _fignore
    ble-complete/.fignore/prepare
  fi

  local ctx source
  for ctx in "${context[@]}"; do
    # initialize completion range
    ctx=($ctx)
    ble/string#split source : "${ctx[0]}"
    local COMP1="${ctx[1]}" COMP2="$index"
    local COMPS="${text:COMP1:COMP2-COMP1}"
    local COMPV _ble_complete_raw_paramx=
    if [[ ! $COMPS || $COMPS =~ $_ble_syntax_rex_simple_word ]]; then
      builtin eval "COMPV=$COMPS"
      [[ $COMPS =~ $rex_raw_paramx ]] && _ble_complete_raw_paramx=1
    fi
    local COMP_PREFIX=

    # generate candidates
    local ACTION DATA
    if ble/util/isfunction ble-complete/source/"${source[0]}"; then
      ble-complete/source/"${source[@]}"
    fi
  done

  ble/util/is-stdin-ready && return 27

  if ((cand_count==0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return
  fi

  local flag_force_fignore=
  shopt -q force_fignore && ((${#_fignore[@]})) && flag_force_fignore=1

  # 共通部分
  local i common comp1 clen comp2="$index"
  local acount=0 aindex=0
  for ((i=0;i<cand_count;i++)); do
    ((i%100==0)) && ble/util/is-stdin-ready && return 27

    local word="${cand_word[i]}"
    local -a prop
    prop=(${cand_prop[i]})

    [[ $flag_force_fignore ]] && ! ble-complete/.fignore/filter "$word" && continue

    if ((i==0)); then
      common="$word"
      comp1="${prop[1]}"
      clen="${#common}"
      ((acount=1,aindex=i))
    else
      # より近くの開始点の候補を優先する場合
      if ((comp1<prop[1])); then
        common="$word"
        comp1="${prop[1]}"
        clen="${#common}"
        ((acount=1,aindex=i))
        continue
      elif ((comp1>prop[1])); then
        continue
      fi

      # # 補完開始点に関係なく共通部分を探す場合
      # if ((comp1<prop[1])); then
      #   word="${text:comp1:prop[1]-comp1}""$word"
      # elif ((comp1>prop[1])); then
      #   common="${text:prop[1]:comp1-prop[1]}""$common"
      #   comp1="${prop[1]}"
      # fi

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common="${common::clen}"
      ((acount++))
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

  if ((acount==1)); then
    # 一意確定の時
    local ACTION
    ACTION=(${cand_prop[aindex]})
    if ble/util/isfunction "$ACTION/complete"; then
      local COMP1="$comp1" COMP2="$comp2"
      local INSERT="$common"
      local CAND="${cand_cand[aindex]}"
      local DATA="${cand_data[aindex]}"

      "$ACTION/complete"
      comp1="$COMP1" comp2="$COMP2" common="$INSERT"
    fi
    ble-edit/info/clear
  else
    # 候補が複数ある時
    ble-edit/info/draw-text "${cand_show[*]}"
  fi

  ble/widget/.delete-range "$comp1" "$index"
  ble/widget/insert-string "$common"
}
