#!/bin/bash
#
# ble-autoload "$_ble_base/lib/core-complete.sh" ble/widget/complete
#

: ${bleopt_complete_ambiguous:=1}

#==============================================================================
# action

## 既存の action
##
##   ble-complete/action/plain
##   ble-complete/action/word
##   ble-complete/action/file
##   ble-complete/action/argument
##   ble-complete/action/command
##   ble-complete/action/variable
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
##   @var[in    ] comps_raw_paramx
##   @var[in    ] comps_close_type
##
## 関数 $ACTION/complete
##   一意確定時に、挿入文字列・範囲に対する加工を行います。
##   例えばディレクトリ名の場合に / を後に付け加える等です。
##
##   @var[in] CAND
##   @var[in] ACTION
##   @var[in] DATA
##   @var[in] COMP1 COMP2
##
##   @var[in,out] INSERT
##     補完によって挿入される文字列を指定します。
##     加工後の挿入する文字列を返します。
##
##   @var[in,out] compr_beg compr_end
##     補完によって置換される範囲を指定します。
##     加工後の置換範囲を返します。
##
##   @var[in] compr_replace
##     既存の部分を保持したまま補完が実行される場合に 1 を指定します。
##     既存の部分が置換される場合には空文字列を指定します。
##

function ble-complete/util/escape-specialchars {
  eval "$ble_util_upvar_setup"
  local a b ret="$*" chars=']['$' \t\n\\''"'\''`$|&;<>()*?{}!^'
  if [[ $ret == *["$chars"]* ]]; then
    a=\\ b="\\$a" ret=${ret//"$a"/$b}
    a=\" b="\\$a" ret=${ret//"$a"/$b}
    a=\' b="\\$a" ret=${ret//"$a"/$b}
    a=\` b="\\$a" ret=${ret//"$a"/$b}
    a=\$ b="\\$a" ret=${ret//"$a"/$b}
    a=' '   b="\\$a"   ret=${ret//"$a"/$b}
    a=$'\t' b="\\$a"   ret=${ret//"$a"/$b}
    a=$'\n' b="\$'\n'" ret=${ret//"$a"/$b}
    a=\| b="\\$a" ret=${ret//"$a"/$b}
    a=\& b="\\$a" ret=${ret//"$a"/$b}
    a=\; b="\\$a" ret=${ret//"$a"/$b}
    a=\< b="\\$a" ret=${ret//"$a"/$b}
    a=\> b="\\$a" ret=${ret//"$a"/$b}
    a=\( b="\\$a" ret=${ret//"$a"/$b}
    a=\) b="\\$a" ret=${ret//"$a"/$b}
    a=\[ b="\\$a" ret=${ret//"$a"/$b}
    a=\* b="\\$a" ret=${ret//"$a"/$b}
    a=\? b="\\$a" ret=${ret//"$a"/$b}
    a=\] b="\\$a" ret=${ret//"$a"/$b}
    a=\{ b="\\$a" ret=${ret//"$a"/$b}
    a=\} b="\\$a" ret=${ret//"$a"/$b}
    a=\! b="\\$a" ret=${ret//"$a"/$b}
    a=\^ b="\\$a" ret=${ret//"$a"/$b}
  fi
  eval "$ble_util_upvar"
}

function ble-complete/util/escape-regexchars {
  eval "$ble_util_upvar_setup"
  ble/string#escape-for-sed-regex "$*"
  eval "$ble_util_upvar"
}

function ble-complete/action/util/complete.addtail {
  INSERT=$INSERT$1
  [[ ${comp_text:compr_end} == "$1"* ]] && ((compr_end++))
}

#------------------------------------------------------------------------------

# action/plain

function ble-complete/action/plain/initialize {
  if [[ $CAND == "$COMPV"* ]]; then
    local ins=${CAND:${#COMPV}} ret

    # 単語内の文脈に応じたエスケープ
    case $comps_close_type in
    (\')      ble/string#escape-for-bash-single-quote "$ins"; ins=$ret ;;
    (\$\')    ble/string#escape-for-bash-escape-string "$ins"; ins=$ret ;;
    (\"|\$\") ble/string#escape-for-bash-double-quote "$ins"; ins=$ret ;;
    (*)       ble-complete/util/escape-specialchars -v ins "$ins" ;;
    esac

    # Note: 現在の simple-word の定義だと引用符内にパラメータ展開を許していないので、
    #  必然的にパラメータ展開が直前にあるのは引用符の外である事が保証されている。
    #  以下は、今後 simple-word の引用符内にパラメータ展開を許す時には修正が必要。
    [[ $comps_raw_paramx && $ins == [a-zA-Z_0-9]* ]] && ins='\'"$ins"

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
  elif ! type "$CAND" &>/dev/null; then
    # 関数名について縮約されたもので一意確定した時。
    #
    # Note: 関数名について縮約されている時、
    #   本来は一意確定でなくても一意確定として此処に来ることがある。
    #   そのコマンドが存在していない時に、縮約されていると判定する。
    #
    if [[ $CAND == */ ]]; then
      # 縮約されていると想定し続きの補完候補を出す。
      local COMP_PREFIX=
      local cand_count=0
      local -a cand_cand=() cand_prop=() cand_word=() cand_show=() cand_data=()
      COMPS=$CAND COMPV=$CAND ble-complete/source/command
      ble-edit/info/show text "${cand_show[*]}"
    fi
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

## 定義されている source
##
##   source/wordlist
##   source/command
##   source/file
##   source/dir
##   source/argument
##   source/variable
##
## source の実装
##
## 関数 ble-complete/source/$name args...
##   @param[in] args...
##     ble-syntax/completion-context で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV
##     補完を実行しようとしている範囲と文字列が指定される。
##
##   @var[out] COMP_PREFIX
##     ble-complete/yield-candidate で参照される一時変数。
##
##   @var[in] comp_type
##     候補生成に関連するフラグ文字列。各フラグに対応する文字を含む。
##
##     文字 a を含む時、曖昧補完に用いる候補を生成する。
##     曖昧一致するかどうかは呼び出し元で判定されるので、
##     曖昧一致する可能性のある候補をできるだけ多く生成すれば良い。
##
##     文字 i を含む時、大文字小文字を区別しない補完候補生成を行います。
##

# source/wordlist

function ble-complete/source/wordlist {
  [[ ${COMPV+set} ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand
  for cand; do
    if [[ $cand == "$COMPV"* ]]; then
      ble-complete/yield-candidate "$cand" ble-complete/action/word
    fi
  done
}

# source/command

function ble-complete/source/command/.contract-by-slashes {
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

function ble-complete/source/command/gen {
  (
    [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
    # Note: 何故か compgen -A command はクォート除去が実行されない。
    #   compgen -A function はクォート除去が実行される。
    #   従って、compgen -A command には直接 COMPV を渡し、
    #   compgen -A function には compv_quoted を渡す。
    compgen -c -- "$COMPV"
    if [[ $COMPV == */* ]]; then
      local q="'" Q="'\''"
      local compv_quoted="'${COMPV//$q/$Q}'"
      compgen -A function -- "$compv_quoted"
    fi
  ) | ble-complete/source/command/.contract-by-slashes

  # ディレクトリ名列挙 (/ 付きで生成する)
  #
  #   Note: shopt -q autocd &>/dev/null かどうかに拘らず列挙する。
  #
  #   Note: compgen -A directory (以下のコード参照) はバグがあって、
  #     bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  #     compgen -A directory -S / -- "$compv_quoted"
  #
  local ret
  ble-complete/source/file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
}
function ble-complete/source/command {
  [[ ${COMPV+set} ]] || return 1
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand arr i=0
  local compgen
  ble/util/assign compgen ble-complete/source/command/gen
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'sort -u <<< "$compgen"' # 1 fork/exec
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble-complete/yield-candidate "$cand" ble-complete/action/command
  done
}

# source/file

function ble-complete/util/eval-pathname-expansion {
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

  if [[ $comp_type == *i* ]]; then
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

  IFS= GLOBIGNORE= eval 'ret=(); ret=($pattern)' 2>/dev/null

  ble/util/invoke-hook dtor
}

## 関数 ble-complete/source/file/.construct-ambiguous-pathname-pattern path
##   指定された path に対応する曖昧一致パターンを生成します。
##   例えばalpha/beta/gamma に対して a*/b*/g* でファイル名を生成します。
##
##   @param[in] path
##   @var[out] ret
##
##   @remarks
##     a*/b*/g* だと曖昧一致しないファイル名も生成されるが、
##     生成後のフィルタによって一致しないものは除去されるので気にしない。
##
function ble-complete/source/file/.construct-ambiguous-pathname-pattern {
  local path=$1
  local pattern= i=0
  local names; ble/string#split names / "$1"
  local name
  for name in "${names[@]}"; do
    ((i++)) && pattern=$pattern/
    if [[ $name ]]; then
      ble/string#escape-for-bash-glob "${name::1}"
      pattern="$pattern$ret*"
    fi
  done
  [[ $pattern ]] || pattern="*"
  ret=$pattern
}
## 関数 ble-complete/source/file/.construct-pathname-pattern path
##   @param[in] path
##   @var[out] ret
function ble-complete/source/file/.construct-pathname-pattern {
  local path=$1
  if [[ $comp_type == *a* ]]; then
    ble-complete/source/file/.construct-ambiguous-pathname-pattern "$path"; local pattern=$ret
  else
    ble/string#escape-for-bash-glob "$path"; local pattern=$ret*
  fi
  ret=$pattern
}

function ble-complete/source/file {
  [[ ${COMPV+set} ]] || return 1
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  #   Note: compgen -A file (以下のコード参照) はバグがあって、
  #     bash-4.0 と 4.1 でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #     local candidates; ble/util/assign-array candidates 'compgen -A file -- "$compv_quoted"'

  local ret
  ble-complete/source/file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret"
  local -a candidates; candidates=("${ret[@]}")

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
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # Note: compgen -A directory (以下のコード参照) はバグがあって、
  #   bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #   local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #   local candidates; ble/util/assign-array candidates 'compgen -A directory -S / -- "$compv_quoted"'

  local ret
  ble-complete/source/file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  local -a candidates; candidates=("${ret[@]}")

  local cand
  for cand in "${candidates[@]}"; do
    [[ -d $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    [[ $cand == / ]] || cand=${cand%/}
    ble-complete/yield-candidate "$cand" ble-complete/action/file
  done
}

# source/argument (complete -p)

function ble-complete/source/argument/.progcomp-helper-vars {
  COMP_LINE=
  COMP_WORDS=()
  local word delta=0 index=0 q="'" Q="'\''" qq="''"
  for word in "${comp_words[@]}"; do
    local ret close_type
    if ble-syntax:bash/simple-word/close-open-word "$word"; then
      ble-syntax:bash/simple-word/eval "$ret"
      ((index)) && ret="'${ret//$q/$Q}'" ret=${ret#"$qq"} ret=${ret%"$qq"} # コマンド名以外はクォート
      ((index<=comp_cword&&(delta+=${#ret}-${#word})))
      word=$ret
    fi
    ble/array#push COMP_WORDS "$word"

    if ((index++==0)); then
      COMP_LINE=$word
    else
      COMP_LINE="$COMP_LINE $word"
    fi
  done

  COMP_CWORD=$comp_cword
  COMP_POINT=$((comp_point+delta))
  COMP_TYPE=9
  COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode-key/.invoke-command

  # 直接渡す場合。$'' などがあると bash-completion が正しく動かないので、
  # エスケープを削除して適当に処理する。
  #
  # COMP_WORDS=("${comp_words[@]}")
  # COMP_LINE="$comp_line"
  # COMP_POINT="$comp_point"
  # COMP_CWORD="$comp_cword"
  # COMP_TYPE=9
  # COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode-key/.invoke-command
}
function ble-complete/source/argument/.progcomp-helper-prog {
  if [[ $comp_prog ]]; then
    (
      local COMP_WORDS COMP_CWORD
      export COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
      ble-complete/source/argument/.progcomp-helper-vars
      local cmd="${comp_words[0]}" cur="${comp_words[comp_cword]}" prev="${comp_words[comp_cword-1]}"
      "$comp_prog" "$cmd" "$cur" "$prev"
    )
  fi
}
function ble-complete/source/argument/.progcomp-helper-func {
  [[ $comp_func ]] || return
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY
  ble-complete/source/argument/.progcomp-helper-vars

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

  local cmd=${comp_words[0]} cur=${comp_words[comp_cword]} prev=${comp_words[comp_cword-1]}
  eval '"$comp_func" "$cmd" "$cur" "$prev"'; local ret=$?
  unset -f compopt

  if [[ $is_default_completion && $ret == 124 ]]; then
    is_default_completion=retry
  fi
}

## 関数 ble-complete/source/argument/.progcomp
##   @var[out] comp_opts
##
##   @var[in] COMP1 COMP2 COMPV COMPS comp_type
##     ble-complete/source の標準的な変数たち。
##
##   @var[in] comp_words comp_line comp_point comp_cword
##     ble-syntax:bash/extract-command によって生成される変数たち。
##
##   @var[in] 他色々
##   @exit 入力がある時に 148 を返します。
function ble-complete/source/argument/.progcomp {
  shopt -q progcomp || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}

  local comp_prog= comp_func=
  local cmd=${comp_words[0]} compcmd= is_default_completion=

  if complete -p "$cmd" &>/dev/null; then
    compcmd=$cmd
  elif [[ $cmd == */?* ]] && complete -p "${cmd##*/}" &>/dev/null; then
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
          ble/array#push compoptions "-$c" ble-complete/source/argument/.progcomp-helper-func ;;
        (C)
          comp_prog="${compargs[iarg++]}"
          ble/array#push compoptions "-$c" ble-complete/source/argument/.progcomp-helper-prog ;;
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
  local q="'" Q="'\''"
  local compgen compv_quoted="'${COMPV//$q/$Q}'"
  ble/util/assign compgen 'compgen "${compoptions[@]}" -- "$compv_quoted" 2>/dev/null'

  # Note: complete -D 補完仕様に従った補完関数が 124 を返したとき再度始めから補完を行う。
  #   ble-complete/source/argument/.progcomp-helper-func 関数内で補間関数の終了ステータスを確認し、
  #   もし 124 だった場合には is_default_completion に retry を設定する。
  if [[ $is_default_completion == retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    ble-complete/source/argument/.progcomp
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

## 関数 ble-complete/source/argument/.generate-user-defined-completion
##   ユーザ定義の補完を実行します。ble/cmdinfo/complete:コマンド名
##   という関数が定義されている場合はそれを使います。
##   それ以外の場合は complete によって登録されているプログラム補完が使用されます。
##
##   @var[in] comp_index
##   @var[in] (variables set by ble-syntax/parse)
##
function ble-complete/source/argument/.generate-user-defined-completion {
  local comp_words comp_line comp_point comp_cword
  ble-syntax:bash/extract-command "$comp_index" || return 1

  local cmd=${comp_words[0]}
  if ble/util/isfunction "ble/cmdinfo/complete:$cmd"; then
    "ble/cmdinfo/complete:$cmd"
  elif [[ $cmd == */?* ]] && ble/util/isfunction "ble/cmdinfo/complete:${cmd##*/}"; then
    "ble/cmdinfo/complete:${cmd##*/}"
  else
    ble-complete/source/argument/.progcomp
  fi
}

function ble-complete/source/argument {
  local comp_opts=:
  local old_cand_count=$old_cand_count

  # try complete&compgen
  ble-complete/source/argument/.generate-user-defined-completion; local exit=$?
  [[ $exit == 0 || $exit == 148 ]] && return "$exit"

  # 候補が見付からない場合
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble-complete/source/dir
  else
    # filenames, default, bashdefault
    ble-complete/source/file
  fi

  if ((cand_count<=old_cand_count)); then
    if local rex='^-[-a-zA-Z_]+[:=]'; [[ $COMPV =~ $rex ]]; then
      # var=filename --option=filename など。

      local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
      local COMP_PREFIX=$prefix
      [[ $comp_type != *a* && $value =~ ^.+/ ]] && COMP_PREFIX=$prefix${BASH_REMATCH[0]}

      local ret cand
      ble-complete/source/file/.construct-pathname-pattern "$value"
      ble-complete/util/eval-pathname-expansion "$ret"
      for cand in "${ret[@]}"; do
        [[ -e $cand || -h $cand ]] || continue
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/yield-candidate "$prefix$cand" ble-complete/action/file
      done
    fi
  fi
}

# source/variable

function ble-complete/source/variable {
  [[ ${COMPV+set} ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}

  local action
  if [[ $1 == '=' ]]; then
    action=variable # 確定時に '=' を挿入
  else
    action=word # 確定時に ' ' を挿入
  fi

  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  local cand arr
  ble/util/assign-array arr 'compgen -v -- "$compv_quoted"'

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
##   @var[in] comp_index
##   @arr[in,out] context
##
##   @arr[out] nearest_contexts
##   @var COMP1 COMP2
##     補完範囲
##   @var COMPS
##     補完範囲の (クオートが含まれうる) コマンド文字列
##   @var COMPV
##     補完範囲のコマンド文字列が意味する実際の文字列
##   @var comps_raw_paramx
##     Cパラメータ展開 $var の直後かどうか。
function ble-complete/.pick-nearest-context {
  COMP1= COMP2=$comp_index
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

  COMPS=${comp_text:COMP1:COMP2-COMP1}
  comps_raw_paramx=
  local rex_raw_paramx='^('$_ble_syntax_bash_simple_rex_element'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

  if [[ ! $COMPS ]]; then
    COMPV=
  elif local ret close_type; ble-syntax:bash/simple-word/close-open-word "$COMPS"; then
    comps_close_type=$close_type
    ble-syntax:bash/simple-word/eval "$ret"; COMPV=$ret
    [[ $COMPS =~ $rex_raw_paramx ]] && comps_raw_paramx=1
  fi
}

## 関数 ble-complete/util/construct-ambiguous-regex text
##   曖昧一致に使う正規表現を生成します。
##   @param[in] text
##   @var[in] comp_type
##   @var[out] ret
function ble-complete/util/construct-ambiguous-regex {
  local text=$1
  local i=0 n=${#text} c=
  local -a buff=()
  for ((i=0;i<n;i++)); do
    ((i)) && ble/array#push buff '.*'
    ch=${text:i:1}
    if [[ $ch == [a-zA-Z] ]]; then
      if [[ $comp_type == *i* ]]; then
        ble/string#toggle-case "$ch"
        ch=[$ch$ret]
      fi
    else
      ble/string#escape-for-extended-regex "$ch"; ch=$ret
    fi
    ble/array#push buff "$ch"
  done
  IFS= eval 'ret="${buff[*]}"'
}
## 関数 ble-complete/.filter-candidates-by-regex rex_filter
##   生成された候補 (cand_*) において指定した正規表現に一致する物だけを残します。
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble-complete/.filter-candidates-by-regex {
  local rex_filter=$1
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=0
  local -a prop=() cand=() word=() show=() data=()
  for ((i=0;i<cand_count;i++)); do
    ((i%bleopt_complete_stdin_frequency==0)) && ble/util/is-stdin-ready && return 148
    [[ ${cand_cand[i]} =~ $rex_filter ]] || continue
    prop[j]=${cand_prop[i]}
    cand[j]=${cand_cand[i]}
    word[j]=${cand_word[i]}
    show[j]=${cand_show[i]}
    data[j]=${cand_data[i]}
    ((j++))
  done
  cand_count=$j
  cand_prop=("${prop[@]}")
  cand_cand=("${cand[@]}")
  cand_word=("${word[@]}")
  cand_show=("${show[@]}")
  cand_data=("${data[@]}")
}

function ble/widget/complete {
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  ble-syntax/import
  _ble_edit_str.update-syntax
  local context
  ble-syntax/completion-context "$comp_text" "$comp_index"

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

  local comp_type=
  ble/util/test-rl-variable completion-ignore-case &&
    comp_type=${comp_type}i

  local cand_count=0
  local -a cand_cand=() # 候補文字列
  local -a cand_prop=() # 関数 開始 終了
  local -a cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  local -a cand_show=() # 表示文字列 (～ 分かり易い文字列)
  local -a cand_data=() # 関数で使うデータ
  local opt_ambiguous=
  while :; do
    # 候補源が尽きたら終わり
    if ((${#context[@]}==0)); then
      ble/widget/.bell
      ble-edit/info/clear
      return
    fi

    # 次の開始点が近くにある候補源たち
    local -a nearest_contexts=()
    local COMP1 COMP2 COMPS COMPV; unset COMPV
    local comps_raw_paramx= comps_close_type=
    ble-complete/.pick-nearest-context

    # 候補生成
    local ctx actx source
    for ctx in "${nearest_contexts[@]}"; do
      ble/string#split-words actx "$ctx"
      ble/string#split source : "${actx[0]}"

      local COMP_PREFIX= # 既定値 (yield-candidate で参照)
      ble-complete/source/"${source[@]}"
    done

    ble/util/is-stdin-ready && return 148
    ((cand_count)) && break

    if [[ $bleopt_complete_ambiguous ]]; then
      comp_type=${comp_type}a
      for ctx in "${nearest_contexts[@]}"; do
        ble/string#split-words actx "$ctx"
        ble/string#split source : "${actx[0]}"

        local COMP_PREFIX= # 既定値 (yield-candidate で参照)
        ble-complete/source/"${source[@]}"
      done
      comp_type=${comp_type//a}

      local ret; ble-complete/util/construct-ambiguous-regex "$COMPV"
      local rex_ambiguous_compv=^$ret
      ble-complete/.filter-candidates-by-regex "$rex_ambiguous_compv"
      (($?==148)) && return 148
      if ((cand_count)); then
        opt_ambiguous=1
        break
      fi
    fi
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

  if [[ $opt_ambiguous ]]; then
    # 曖昧一致に於いて複数の候補の共通部分が
    # 元の文字列に曖昧一致しない場合は補完しない。
    [[ $common =~ $rex_ambiguous_compv ]] || common=$COMPS
  elif ((cand_count!=1)) && [[ $common != "$COMPS"* ]]; then
    common=$COMPS
  fi

  # 編集範囲の最小化
  local compr_beg=$COMP1 compr_end=$COMP2
  local compr_replace=
  if [[ $common == "$COMPS"* ]]; then
    # 既存部分の置換がない場合
    common=${common:COMP2-COMP1}
    ((compr_beg=COMP2))
  else
    # 既存部分の置換がある場合
    compr_replace=1
    while ((compr_beg<COMP2)) && [[ $common == "${comp_text:compr_beg:1}"* ]]; do
      common=${common:1}
      ((compr_beg++))
    done
  fi

  local INSERT=$common
  if ((cand_count==1)); then
    # 一意確定の時

    # Note: $ACTION/complete が info に表示できる様に先に clear する。
    ble-edit/info/clear

    local ACTION
    ble/string#split-words ACTION "${cand_prop[0]}"
    if ble/util/isfunction "$ACTION/complete"; then
      local CAND=${cand_cand[0]}
      local DATA=${cand_data[0]}
      "$ACTION/complete"
    fi
  else
    # 候補が複数ある時
    ble-edit/info/show text "${cand_show[*]}"
  fi

  ble/widget/.replace-range "$compr_beg" "$compr_end" "$INSERT" 1
  ((_ble_edit_ind=compr_beg+${#INSERT},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ ${COMPV+set} ]] || return 1

  if [[ $COMPV == -* ]]; then
    local action=ble-complete/action/word
    case $type in
    (pushd)
      if [[ $COMPV == - || $COMPV == -n ]]; then
        ble-complete/yield-candidate -n "$action"
      fi ;;
    (*)
      COMP_PREFIX=$COMPV
      local -a list=()
      [[ $COMPV == -* ]] && ble-complete/yield-candidate "${COMPV}" "$action"
      [[ $COMPV != *L* ]] && ble-complete/yield-candidate "${COMPV}L" "$action"
      [[ $COMPV != *P* ]] && ble-complete/yield-candidate "${COMPV}P" "$action"
      ((_ble_bash>=40200)) && [[ $COMPV != *e* ]] && ble-complete/yield-candidate "${COMPV}e" "$action"
      ((_ble_bash>=40300)) && [[ $COMPV != *@* ]] && ble-complete/yield-candidate "${COMPV}@" "$action" ;;
    esac
    return
  fi

  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  ble-complete/source/dir

  if [[ $CDPATH ]]; then
    local names; ble/string#split names : "$CDPATH"
    local name
    for name in "${names[@]}"; do
      [[ $name ]] || continue
      name=${name%/}/

      local ret cand
      ble-complete/source/file/.construct-pathname-pattern "$COMPV"
      ble-complete/util/eval-pathname-expansion "$name/$ret"
      for cand in "${ret[@]}"; do
        [[ $cand && -d $cand ]] || continue
        [[ $cand == / ]] || cand=${cand%/}
        cand=${cand#"$name"/}
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/yield-candidate "$cand" ble-complete/action/file
      done
    done
  fi
}
function ble/cmdinfo/complete:cd {
  ble/cmdinfo/complete:cd/.impl cd
}
function ble/cmdinfo/complete:pushd {
  ble/cmdinfo/complete:cd/.impl pushd
}
