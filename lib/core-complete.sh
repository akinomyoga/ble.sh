#!/bin/bash
#
# ble-autoload "$_ble_base/lib/core-complete.sh" ble/widget/complete
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
##   @var[in    ] ble_complete_raw_paramx
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
  ble/string#escape-for-sed-regex "$*"
  eval "$ble_util_upvar"
}

function ble-complete/action/util/complete.addtail {
  INSERT="$INSERT$1"
  [[ ${text:index} == "$1"* ]] && ((index++))
}

#------------------------------------------------------------------------------

# action/plain

function ble-complete/action/plain/initialize {
  if [[ $CAND == "$COMPV"* ]]; then
    local ins
    ble-complete/util/escape-specialchars -v ins "${CAND:${#COMPV}}"
    [[ $ble_complete_raw_paramx && $ins == [a-zA-Z_0-9]* ]] && ins='\'"$ins"
    INSERT=$COMPS$ins
  else
    ble-complete/util/escape-specialchars -v INSERT "$CAND"
  fi
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
  if [[ -e $CAND || -h $CAND ]]; then
    if [[ -d $CAND ]]; then
      [[ $CAND != */ ]] &&
        ble-complete/action/util/complete.addtail /
    else
      ble-complete/action/util/complete.addtail ' '
    fi
  fi
}

# action/argument

function ble-complete/action/argument/initialize { ble-complete/action/plain/initialize; }
function ble-complete/action/argument/complete {
  if [[ -d $CAND ]]; then
    [[ $CAND != */ ]] &&
      ble-complete/action/util/complete.addtail /
  else
    ble-complete/action/util/complete.addtail ' '
  fi
}
function ble-complete/action/argument-nospace/initialize { ble-complete/action/plain/initialize; }
function ble-complete/action/argument-nospace/complete {
  if [[ -d $CAND && $CAND != */ ]]; then
    ble-complete/action/util/complete.addtail /
  fi
}

# action/command

function ble-complete/action/command/initialize {
  ble-complete/action/plain/initialize
}
function ble-complete/action/command/complete {
  if [[ -d $CAND ]]; then
    [[ $CAND != */ ]] &&
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
  local CAND=$1 ACTION=$2 DATA="${*:3}"
  local SHOW=${1#$COMP_PREFIX} INSERT=$CAND
  "$ACTION/initialize"

  [[ $flag_force_fignore ]] && ! ble-complete/.fignore/filter "$CAND" && return

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_prop[icand]="$ACTION $COMP1 $COMP2"
  cand_word[icand]=$INSERT
  cand_show[icand]=$SHOW
  cand_data[icand]=$DATA
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

  # ディレクトリ名列挙 (/ 付きで生成する)
  #   Note: shopt -q autocd &>/dev/null かどうかに拘らず列挙する。
  compgen -A directory -S / -- "$COMPV"

  # local ret; ble/util/eval-pathname-expansion '"$COMPV"*/'
  # local cand
  # for cand in "${ret[@]}"; do
  #   [[ -d $cand ]] && printf '%s\n' "$cand"
  # done
}
function ble-complete/source/command {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand arr i=0
  local compgen
  ble/util/assign compgen ble-complete/source/command/gen
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'sort -u <<< "$compgen"' # 1 fork/exec
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148

    # workaround: 何故か compgen -c -- "$COMPV" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble-complete/yield-candidate "$cand" ble-complete/action/command
  done
}

# source/file

function ble-complete/source/file {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local candidates
  ble/util/assign-array candidates 'compgen -A file -- "$COMPV"'

  local cand
  for cand in "${candidates[@]}"; do
    [[ -e $cand || -h $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    ble-complete/yield-candidate "$cand" ble-complete/action/file
  done
}

# source/dir

function ble-complete/source/dir {
  [[ ${COMPV+set} ]] || return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX="${BASH_REMATCH[0]}"

  local candidates
  ble/util/assign-array candidates 'compgen -A directory -S / -- "$COMPV"'

  local cand
  for cand in "${candidates[@]}"; do
    [[ -d $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    [[ $cand == / ]] || cand=${cand%/}
    ble-complete/yield-candidate "$cand" ble-complete/action/file
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
  ble-complete/source/argument/.compgen-helper-varsz

  # compopt に介入して -o/+o option を読み取る。
  local fDefault=
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
      (-*) comp_opts=${comp_opts//:"${s:1}":/:}${s:1}: ;;
      (+*) comp_opts=${comp_opts//:"${s:1}":/:} ;;
      esac
    done

    return "$ret"
  }

  local cmd="${comp_words[0]}" cur="${comp_words[comp_cword]}" prev="${comp_words[comp_cword-1]}"
  "$comp_func" "$cmd" "$cur" "$prev"; local ret=$?
  unset -f compopt

  if [[ $is_default_completion && $ret == 124 ]]; then
    is_default_completion=retry
  fi
}

## 関数 ble-complete/source/argument/.compgen
## @var[out] comp_opts
## @var[in] COMPV
## @var[in] index
## @var[in] (variables set by ble-syntax/parse)
## @var[in] 他色々
## @exit 入力がある時に 148 を返します。
function ble-complete/source/argument/.compgen {
  shopt -q progcomp || return 1

  local comp_words comp_line comp_point comp_cword
  local comp_prog= comp_func=
  ble-syntax:bash/extract-command "$index" || return 1

  local cmd=${comp_words[0]} compcmd= is_default_completion=
  if complete -p "$cmd" &>/dev/null; then
    compcmd=$cmd
  elif [[ ${cmd##*/} != "$cmd" ]] && complete -p "${cmd##*/}" &>/dev/null; then
    compcmd=${cmd##*/}
  elif complete -p -D &>/dev/null; then
    is_default_completion=1
    compcmd='-D'
  fi

  [[ $compcmd ]] || return 1

  local -a compargs compoptions
  local ret iarg=1
  ble/util/assign ret 'complete -p "$compcmd" 2>/dev/null'
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
          ble/array#push compoptions "-$c" ;;
        ([pr])
          ;; # 無視 (-p 表示 -r 削除)
        ([AGWXPS])
          ble/array#push compoptions "-$c" "${compargs[iarg++]}" ;;
        (o)
          local o="${compargs[iarg++]}"
          comp_opts=${comp_opts//:"$o":/:}$o:
          ble/array#push compoptions "-$c" "$o" ;;
        (F)
          comp_func="${compargs[iarg++]}"
          ble/array#push compoptions "-$c" ble-complete/source/argument/.compgen-helper-func ;;
        (C)
          comp_prog="${compargs[iarg++]}"
          ble/array#push compoptions "-$c" ble-complete/source/argument/.compgen-helper-prog ;;
        (*)
          # -D, etc. just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done

  ble/util/is-stdin-ready && return 148

  # Note: 一旦 compgen だけで ble/util/assign するのは、compgen をサブシェルではなく元のシェルで評価する為である。
  #   補完関数が遅延読込になっている場合などに、読み込まれた補完関数が次回から使える様にする為に必要である。
  local compgen
  ble/util/assign compgen 'compgen "${compoptions[@]}" -- "$COMPV" 2>/dev/null'

  # Note: complete -D 補完仕様に従った補完関数が 124 を返したとき再度始めから補完を行う。
  #   ble-complete/source/argument/.compgen-helper-func 関数内で補間関数の終了ステータスを確認し、
  #   もし 124 だった場合には is_default_completion に retry を設定する。
  if [[ $is_default_completion == retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    ble-complete/source/argument/.compgen
    return
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

  # Note: "$COMPV" で始まる単語だけを候補として列挙する為に sed /^$rex_compv/ でフィルタする。
  #   compgen に -- "$COMPV" を渡しても何故か思うようにフィルタしてくれない為である。
  #   (compgen -W "$(compgen ...)" -- "$COMPV" の様にしないと駄目なのか?)
  local arr rex_compv
  ble-complete/util/escape-regexchars -v rex_compv "$COMPV"
  if [[ $use_workaround_for_git ]]; then
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/{s/[[:space:]]\{1,\}\$//;p;}" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  else
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/p" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  fi

  local action=argument
  [[ $comp_opts == *:nospace:* ]] && action=argument-nospace

  local cand i=0 count=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148
    ble-complete/yield-candidate "$cand" ble-complete/action/"$action"
    ((count++))
  done

  ((count!=0))
}

function ble-complete/source/argument {
  local comp_opts=:

  # try complete&compgen
  ble-complete/source/argument/.compgen; local exit="$?"
  [[ $exit == 0 || $exit == 148 ]] && return "$exit"

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

  local cand arr
  ble/util/assign-array arr 'compgen -v -- "$COMPV"'

  local i=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148
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

## 関数 ble-complete/.pick-nearest-context
##   一番開始点に近い補完源の一覧を求めます。
##
##   @var[in] index
##   @arr[in,out] context
##
##   @arr[out] nearest_contexts
##   @var COMP1 COMP2
##     補完範囲
##   @var COMPS
##     補完範囲の (クオートが含まれうる) コマンド文字列
##   @var COMPV
##     補完範囲のコマンド文字列が意味する実際の文字列
##   @var ble_complete_raw_paramx
##     Cパラメータ展開 $var の直後かどうか。
function ble-complete/.pick-nearest-context {
  COMP1= COMP2=$index
  nearest_contexts=()

  local -a unused_contexts=()
  local ctx actx
  for ctx in "${context[@]}"; do
    ble/string#split-words actx "$ctx"
    if ((COMP1<actx[1])); then
      COMP1=${actx[1]}
      ble/array#push unused_contexts "${nearest_contexts[@]}"
      nearest_contexts=("$ctx")
    elif ((COMP1==actx[1])); then
      ble/array#push nearest_contexts "$ctx"
    else
      ble/array#push unused_contexts "$ctx"
    fi
  done
  context=("${unused_contexts[@]}")

  COMPS=${text:COMP1:COMP2-COMP1}
  ble_complete_raw_paramx=
  local rex_raw_paramx='^('$_ble_syntax_bash_simple_rex_element'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'
  if [[ ! $COMPS ]] || ble-syntax:bash/simple-word/is-simple "$COMPS"; then
    local ret; ble-syntax:bash/simple-word/eval "$COMPS"; COMPV=$ret
    [[ $COMPS =~ $rex_raw_paramx ]] && ble_complete_raw_paramx=1
  fi
}

function ble/widget/complete {
  local text=$_ble_edit_str index=$_ble_edit_ind
  ble-syntax/import
  _ble_edit_str.update-syntax
  local context
  ble-syntax/completion-context "$text" "$index"

  if ((${#context[@]}==0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return
  fi

  local flag_force_fignore=
  local -a _fignore=()
  if [[ $FIGNORE ]]; then
    ble-complete/.fignore/prepare
    ((${#_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  local cand_count=0
  local -a cand_cand=() # 候補文字列
  local -a cand_prop=() # 関数 開始 終了
  local -a cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  local -a cand_show=() # 表示文字列 (～ 分かり易い文字列)
  local -a cand_data=() # 関数で使うデータ
  while ((cand_count==0)); do
    # 候補源が尽きたら終わり
    if ((${#context[@]}==0)); then
      ble/widget/.bell
      ble-edit/info/clear
      return
    fi

    # 次の開始点が近くにある候補源たち
    local -a nearest_contexts=()
    local COMP1 COMP2 COMPS COMPV; unset COMPV
    local ble_complete_raw_paramx=
    ble-complete/.pick-nearest-context

    # 候補生成
    local ctx actx source
    for ctx in "${nearest_contexts[@]}"; do
      ble/string#split-words actx "$ctx"
      ble/string#split source : "${actx[0]}"
      if ble/util/isfunction ble-complete/source/"${source[0]}"; then
        local COMP_PREFIX= # 既定値 (yield-candidate で参照)
        ble-complete/source/"${source[@]}"
      fi
    done

    ble/util/is-stdin-ready && return 148
  done

  # 共通部分
  local common=${cand_word[0]} clen=${#cand_word[0]}
  if ((cand_count>1)); then
    local word loop=0
    for word in "${cand_word[@]:1}"; do
      ((loop++%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common=${common::clen}
    done
  fi

  # 編集範囲の最小化
  if [[ $common == "${text:COMP1:COMP2-COMP1}"* ]]; then
    # 既存部分の置換がない場合
    common=${common:COMP2-COMP1}
    ((COMP1=COMP2))
  else
    # 既存部分の置換がある場合
    while ((COMP1<COMP2)) && [[ $common == "${text:COMP1:1}"* ]]; do
      common=${common:1}
      ((COMP1++))
    done
  fi

  if ((cand_count==1)); then
    # 一意確定の時
    local ACTION
    ble/string#split-words ACTION "${cand_prop[0]}"
    if ble/util/isfunction "$ACTION/complete"; then
      local INSERT=$common
      local CAND=${cand_cand[0]}
      local DATA=${cand_data[0]}

      "$ACTION/complete"
      common=$INSERT
    fi
    ble-edit/info/clear
  else
    # 候補が複数ある時
    ble-edit/info/show text "${cand_show[*]}"
  fi

  ble/widget/.delete-range "$COMP1" "$index"
  [[ $common ]] && ble/widget/.insert-string "$common"
}
