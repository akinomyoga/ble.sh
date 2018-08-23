#!/bin/bash
#
# ble-autoload "$_ble_base/lib/core-complete.sh" ble/widget/complete
#

function ble-complete/string#search-longest-suffix-in {
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
function ble-complete/string#common-suffix-prefix {
  local lhs=$1 rhs=$2
  if ((${#lhs}<${#rhs})); then
    local i n=${#lhs}
    for ((i=0;i<n;i++)); do
      ret=${lhs:i}
      [[ $rhs == "$ret"* ]] && return
    done
    ret=
  else
    local j m=${#rhs}
    for ((j=m;j>0;j--)); do
      ret=${rhs::j}
      [[ $lhs == *"$ret" ]] && return
    done
    ret=
  fi
}

## ble-complete 内で共通で使われるローカル変数
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
##   候補生成に関連するフラグ文字列。各フラグに対応する文字を含む。
##
##   a 文字 a を含む時、曖昧補完に用いる候補を生成する。
##     曖昧一致するかどうかは呼び出し元で判定されるので、
##     曖昧一致する可能性のある候補をできるだけ多く生成すれば良い。
##
##   i 文字 i を含む時、大文字小文字を区別しない補完候補生成を行う。
##
##   s 文字 s を含む時、ユーザの入力があっても中断しない事を表す。
##

function ble-complete/check-cancel {
  [[ $comp_type != *s* ]] && ble-decode/has-input
}

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
##
##     S クォート ''  の中にいる事を表します。
##     E クォート $'' の中にいる事を表します。
##     D クォート ""  の中にいる事を表します。
##     I クォート $"" の中にいる事を表します。
##
##     Note: shopt -s nocaseglob のため、フラグ文字は
##       大文字・小文字でも重複しないように定義する必要がある。
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
##   @var[in,out] INSERT SUFFIX
##     補完によって挿入される文字列を指定します。
##     加工後の挿入する文字列を返します。
##
##   @var[in] insert_beg insert_end
##     補完によって置換される範囲を指定します。
##
##   @var[in] insert_replace
##     既存の部分を保持したまま補完が実行される場合に 1 を指定します。
##     既存の部分が置換される場合には空文字列を指定します。
##

function ble-complete/action/util/complete.addtail {
  SUFFIX=$SUFFIX$1
}
function ble-complete/action/util/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble-complete/action/util/complete.addtail \' ;;
  (*[DI]*) ble-complete/action/util/complete.addtail \" ;;
  esac
}

#------------------------------------------------------------------------------

# action/plain

function ble-complete/action/plain/initialize {
  if [[ $CAND == "$COMPV"* ]]; then
    local ins=${CAND:${#COMPV}} ret

    # 単語内の文脈に応じたエスケープ
    case $comps_flags in
    (*S*)    ble/string#escape-for-bash-single-quote "$ins"; ins=$ret ;;
    (*E*)    ble/string#escape-for-bash-escape-string "$ins"; ins=$ret ;;
    (*[DI]*) ble/string#escape-for-bash-double-quote "$ins"; ins=$ret ;;
    (*)   ble/string#escape-for-bash-specialchars "$ins"; ins=$ret ;;
    esac

    # Note: 現在の simple-word の定義だと引用符内にパラメータ展開を許していないので、
    #  必然的にパラメータ展開が直前にあるのは引用符の外である事が保証されている。
    #  以下は、今後 simple-word の引用符内にパラメータ展開を許す時には修正が必要。
    [[ $comps_flags == *p* && $ins == [a-zA-Z_0-9]* ]] && ins='\'"$ins"

    INSERT=$COMPS$ins
  else
    local ret
    ble/string#escape-for-bash-specialchars "$CAND"; INSERT=$ret
  fi
}
function ble-complete/action/plain/complete { :; }

# action/word

function ble-complete/action/word/initialize {
  ble-complete/action/plain/initialize
}
function ble-complete/action/word/complete {
  ble-complete/action/util/complete.close-quotation
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
      ble-complete/action/util/complete.close-quotation
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
    ble-complete/action/util/complete.close-quotation
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
    ble-complete/action/util/complete.close-quotation
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
##     ble-syntax/completion-context/generate で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[out] COMP_PREFIX
##     ble-complete/yield-candidate で参照される一時変数。
##

# source/wordlist

function ble-complete/source/wordlist {
  [[ $comps_flags == *v* ]] || return 1
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

function ble-complete/source/command/gen.1 {
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
}

function ble-complete/source/command/gen {
  if [[ $comp_type != *a* && $bleopt_complete_contract_function_names ]]; then
    ble-complete/source/command/gen.1 |
      ble-complete/source/command/.contract-by-slashes
  else
    ble-complete/source/command/gen.1
  fi

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
  [[ $comps_flags == *v* ]] || return 1
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand arr i=0
  local compgen
  ble/util/assign compgen ble-complete/source/command/gen
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'sort -u <<< "$compgen"' # 1 fork/exec
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble-complete/yield-candidate "$cand" ble-complete/action/command
  done
}

# source/file

function ble-complete/util/eval-pathname-expansion {
  local pattern=$1

  local old_noglob=
  if [[ -o noglob ]]; then
    noglob=1
    set +f
  fi

  local old_nullglob=
  if ! shopt -q nullglob; then
    old_nullglob=0
    shopt -s nullglob
  fi

  local old_nocaseglob=
  if [[ $comp_type == *i* ]]; then
    if ! shopt -q nocaseglob; then
      old_nocaseglob=0
      shopt -s nocaseglob
    fi
  else
    if shopt -q nocaseglob; then
      old_nocaseglob=1
      shopt -u nocaseglob
    fi
  fi

  IFS= GLOBIGNORE= eval 'ret=($pattern)' 2>/dev/null

  if [[ $old_nocaseglob ]]; then
    if ((old_nocaseglob)); then
      shopt -s nocaseglob
    else
      shopt -u nocaseglob
    fi
  fi

  [[ $old_nullglob ]] && shopt -u nullglob

  [[ $old_noglob ]] && set -f
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
  [[ $comps_flags == *v* ]] || return 1
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
  [[ $comps_flags == *v* ]] || return 1
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
  local shell_specialchars=']\ ["'\''`$|&;<>()*?{}!^'$'\n\t'
  local word delta=0 index=0 q="'" Q="'\''" qq="''"
  for word in "${comp_words[@]}"; do
    local ret close_type
    if ble-syntax:bash/simple-word/close-open-word "$word"; then
      ble-syntax:bash/simple-word/eval "$ret"
      ((index)) && [[ $ret == *["$shell_specialchars"]* ]] &&
        ret="'${ret//$q/$Q}'" ret=${ret#"$qq"} ret=${ret%"$qq"} # コマンド名以外はクォート
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
  COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode/widget/.call-keyseq

  # 直接渡す場合。$'' などがあると bash-completion が正しく動かないので、
  # エスケープを削除して適当に処理する。
  #
  # COMP_WORDS=("${comp_words[@]}")
  # COMP_LINE="$comp_line"
  # COMP_POINT="$comp_point"
  # COMP_CWORD="$comp_cword"
  # COMP_TYPE=9
  # COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode/widget/.call-keyseq
}
function ble-complete/source/argument/.progcomp-helper-prog {
  if [[ $comp_prog ]]; then
    (
      local COMP_WORDS COMP_CWORD
      export COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
      ble-complete/source/argument/.progcomp-helper-vars
      local cmd=${comp_words[0]} cur=${comp_words[comp_cword]} prev=${comp_words[comp_cword-1]}
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
  "$comp_func" "$cmd" "$cur" "$prev"; local ret=$?
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
          local o=${compargs[iarg++]}
          comp_opts=${comp_opts//:"$o":/:}$o:
          ble/array#push compoptions "-$c" "$o" ;;
        (F)
          comp_func=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble-complete/source/argument/.progcomp-helper-func ;;
        (C)
          comp_prog=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble-complete/source/argument/.progcomp-helper-prog ;;
        (*)
          # -D, etc. just discard
        esac
      done ;;
    (*)
      ;; # 無視
    esac
  done

  ble-complete/check-cancel && return 148

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
  local arr ret
  ble/string#escape-for-sed-regex "$COMPV"; local rex_compv=$ret
  if [[ $use_workaround_for_git ]]; then
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/{s/[[:space:]]\{1,\}\$//;p;}" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  else
    ble/util/assign-array arr 'ble/bin/sed -n "/^\$/d;/^$rex_compv/p" <<< "$compgen" | ble/bin/sort -u' 2>/dev/null
  fi

  local action=argument
  [[ $comp_opts == *:nospace:* ]] && action=argument-nospace

  local cand i=0 count=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
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
  if ble/is-function "ble/cmdinfo/complete:$cmd"; then
    "ble/cmdinfo/complete:$cmd"
  elif [[ $cmd == */?* ]] && ble/is-function "ble/cmdinfo/complete:${cmd##*/}"; then
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
      #
      # Note: 微妙に異なる条件で ble-syntax/completion-context/generate の方でも
      #   単語の途中の = からの補完に対応しているが、候補生成の異なる優先度
      #   を持たせるために両方で処理する現在の実装を保持する。

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
  [[ $comps_flags == *v* ]] || return 1
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
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    ble-complete/yield-candidate "$cand" ble-complete/action/"$action"
  done
}

#------------------------------------------------------------------------------
# 候補生成

## @var[out] cand_count
##   候補の数
## @arr[out] cand_cand
##   候補文字列
## @arr[out] cand_prop
##   関数 開始 終了
## @arr[out] cand_word
##   挿入文字列 (～ エスケープされた候補文字列)
## @arr[out] cand_show
##   表示文字列 (～ 分かり易い文字列)
## @arr[out] cand_data
##   関数で使うデータ

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

## 関数 ble-complete/candidates/.pick-nearest-context
##   一番開始点に近い補完源の一覧を求めます。
##
##   @var[in] comp_index
##   @arr[in,out] contexts
##
##   @arr[out] nearest_contexts
##   @var COMP1 COMP2
##     補完範囲
##   @var COMPS
##     補完範囲の (クオートが含まれうる) コマンド文字列
##   @var COMPV
##     補完範囲のコマンド文字列が意味する実際の文字列
##   @var comps_flags
function ble-complete/candidates/.pick-nearest-context {
  COMP1= COMP2=$comp_index
  nearest_contexts=()

  local -a unused_contexts=()
  local ctx actx
  for ctx in "${contexts[@]}"; do
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
  contexts=("${unused_contexts[@]}")

  COMPS=${comp_text:COMP1:COMP2-COMP1}
  comps_flags=
  local rex_raw_paramx='^('$_ble_syntax_bash_simple_rex_element'*)\$[a-zA-Z_][a-zA-Z_0-9]*$'

  if [[ ! $COMPS ]]; then
    comps_flags=${comps_flags}v COMPV=
  elif local ret close_type; ble-syntax:bash/simple-word/close-open-word "$COMPS"; then
    comps_flags=$comps_flags$close_type
    ble-syntax:bash/simple-word/eval "$ret"; comps_flags=${comps_flags}v COMPV=$ret
    [[ $COMPS =~ $rex_raw_paramx ]] && comps_flags=${comps_flags}p
  else
    COMPV=
  fi
}

## 関数 ble-complete/candidates/.filter-by-regex rex_filter
##   生成された候補 (cand_*) において指定した正規表現に一致する物だけを残します。
##   @param[in] rex_filter
##   @var[in,out] cand_count
##   @arr[in,out] cand_{prop,cand,word,show,data}
##   @exit
##     ユーザ入力によって中断された時に 148 を返します。
function ble-complete/candidates/.filter-by-regex {
  local rex_filter=$1
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=0
  local -a prop=() cand=() word=() show=() data=()
  for ((i=0;i<cand_count;i++)); do
    ((i%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
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

## 関数 ble-complete/candidates/get-contexts comp_text comp_index
## 関数 ble-complete/candidates/get-prefix-contexts comp_text comp_index
##   @param[in] comp_text
##   @param[in] comp_index
##   @var[out] contexts
function ble-complete/candidates/get-contexts {
  local comp_text=$1 comp_index=$2
  ble-syntax/import
  _ble_edit_str.update-syntax
  ble-syntax/completion-context/generate "$comp_text" "$comp_index"
  ((${#contexts[@]}))
}
function ble-complete/candidates/get-prefix-contexts {
  local comp_text=$1 comp_index=$2
  ble-complete/candidates/get-contexts "$@" || return

  # 現在位置より前に始まる補完文脈だけを選択する
  local -a filtered_contexts=()
  local ctx actx
  for ctx in "${contexts[@]}"; do
    ble/string#split-words actx "$ctx"
    local comp1=${actx[1]}
    ((comp1<comp_index)) &&
      ble/array#push filtered_contexts "$ctx"
  done
  contexts=("${filtered_contexts[@]}")
  ((${#contexts[@]}))
}


## 関数 ble-complete/candidates/generate
##   @var[in] comp_text comp_index
##   @arr[in] contexts
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags
##   @var[out] cand_*
##   @var[out] rex_ambiguous_compv
function ble-complete/candidates/generate {
  local flag_force_fignore=
  local -a _fignore=()
  if [[ $FIGNORE ]]; then
    ble-complete/.fignore/prepare
    ((${#_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  ble/util/test-rl-variable completion-ignore-case &&
    comp_type=${comp_type}i

  cand_count=0
  cand_cand=() # 候補文字列
  cand_prop=() # 関数 開始 終了
  cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  cand_show=() # 表示文字列 (～ 分かり易い文字列)
  cand_data=() # 関数で使うデータ
  while :; do
    # 候補源が尽きたら終わり
    ((${#contexts[@]})) || return 1

    # 次の開始点が近くにある候補源たち
    local -a nearest_contexts=()
    comps_flags=
    ble-complete/candidates/.pick-nearest-context

    # 候補生成
    local ctx actx source
    for ctx in "${nearest_contexts[@]}"; do
      ble/string#split-words actx "$ctx"
      ble/string#split source : "${actx[0]}"

      local COMP_PREFIX= # 既定値 (yield-candidate で参照)
      ble-complete/source/"${source[@]}"
    done

    ble-complete/check-cancel && return 148
    ((cand_count)) && break

    if [[ $bleopt_complete_ambiguous && $COMPV ]]; then
      comp_type=${comp_type}a
      for ctx in "${nearest_contexts[@]}"; do
        ble/string#split-words actx "$ctx"
        ble/string#split source : "${actx[0]}"

        local COMP_PREFIX= # 既定値 (yield-candidate で参照)
        ble-complete/source/"${source[@]}"
      done

      local ret; ble-complete/util/construct-ambiguous-regex "$COMPV"
      rex_ambiguous_compv=^$ret
      ble-complete/candidates/.filter-by-regex "$rex_ambiguous_compv"
      (($?==148)) && return 148
      ((cand_count)) && break
      comp_type=${comp_type//a}
    fi
  done
  return 0
}

## 関数 ble-complete/candidates/determine-common-prefix
##   cand_* を元に common prefix を算出します。
##   @var[in] cand_*
##   @var[in] rex_ambiguous_compv
##   @var[out] ret
function ble-complete/candidates/determine-common-prefix {
  # 共通部分
  local common=${cand_word[0]} clen=${#cand_word[0]}
  if ((cand_count>1)); then
    local word loop=0
    for word in "${cand_word[@]:1}"; do
      ((loop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

      ((clen>${#word}&&(clen=${#word})))
      while [[ ${word::clen} != "${common::clen}" ]]; do
        ((clen--))
      done
      common=${common::clen}
    done
  fi

  if [[ $comp_type == *a* ]]; then
    # 曖昧一致に於いて複数の候補の共通部分が
    # 元の文字列に曖昧一致しない場合は補完しない。
    [[ $common =~ $rex_ambiguous_compv ]] || common=$COMPS
  elif ((cand_count!=1)) && [[ $common != "$COMPS"* ]]; then
    common=$COMPS
  fi

  ret=$common
}

## 関数 ble-complete/insert insert_beg insert_end insert suffix
function ble-complete/insert {
  local insert_beg=$1 insert_end=$2
  local insert=$3 suffix=$4
  local original_text=${_ble_edit_str:insert_beg:insert_end-insert_beg}

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
      insert_beg+=${#ret}
    fi
  fi

  if ble/util/test-rl-variable skip-completed-text; then
    # カーソルの右のテキストの吸収
    if [[ $insert ]]; then
      local right_text=${_ble_edit_str:insert_end}
      right_text=${right_text%%[$IFS]*}
      if ble/string#common-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に先頭一致する場合に吸収
        insert_end+=${#ret}
      elif ble-complete/string#common-suffix-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に末尾一致する場合に吸収
        insert_end+=${#ret}
      fi
    fi

    # suffix の吸収
    if [[ $suffix ]]; then
      local right_text=${_ble_edit_str:insert_end}
      if ble/string#common-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        insert_end+=${#ret}
      elif ble-complete/string#common-suffix-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        insert_end+=${#ret}
      fi
    fi
  fi

  local ins=$insert$suffix
  ble/widget/.replace-range "$insert_beg" "$insert_end" "$ins" 1
  ((_ble_edit_ind=insert_beg+${#ins},
    _ble_edit_ind>${#_ble_edit_str}&&
      (_ble_edit_ind=${#_ble_edit_str})))
}

function ble/widget/complete {
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local contexts
  ble-complete/candidates/get-contexts "$comp_text" "$comp_index" || return 1

  local COMP1 COMP2 COMPS COMPV comp_type=
  local comps_flags
  local rex_ambiguous_compv
  local cand_count
  local -a cand_cand cand_prop cand_word cand_show cand_data
  ble-complete/candidates/generate; local ext=$?
  if ((ext==148)); then
    return 148
  elif ((ext!=0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return 1
  fi

  local ret
  ble-complete/candidates/determine-common-prefix; local INSERT=$ret SUFFIX=
  local insert_beg=$COMP1 insert_end=$COMP2
  local insert_replace= #@@@ unused?
  [[ $INSERT == "$COMPS"* ]] || insert_replace=1

  if ((cand_count==1)); then
    # 一意確定の時

    # Note: $ACTION/complete が info に表示できる様に先に clear する。
    #   関数名について縮約された候補に対して続きを表示するのに使う。
    ble-edit/info/clear

    local ACTION
    ble/string#split-words ACTION "${cand_prop[0]}"
    if ble/is-function "$ACTION/complete"; then
      local CAND=${cand_cand[0]}
      local DATA=${cand_data[0]}
      "$ACTION/complete"
    fi
  else
    # 候補が複数ある時
    ble-edit/info/show text "${cand_show[*]}"
  fi

  local insert=$INSERT suffix=$SUFFIX
  ble/util/invoke-hook _ble_complete_insert_hook
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

function ble/widget/complete-insert {
  local original=$1 insert=$2 suffix=$3
  [[ ${_ble_edit_str::_ble_edit_ind} == *"$original" ]] || return 1

  local insert_beg=$((_ble_edit_ind-${#original}))
  local insert_end=$_ble_edit_ind
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

#------------------------------------------------------------------------------
#
# auto-complete
#

function ble-complete/auto-complete/initialize {
  ble-color-defface auto_complete fg=247

  local ret
  ble-decode-kbd/generate-keycode auto_complete_enter
  _ble_complete_KCODE_ENTER=$ret
}
ble-complete/auto-complete/initialize

function ble-highlight-layer:region/mark:auto_complete/get-sgr {
  ble-color-face2sgr auto_complete
}

_ble_complete_ac_type=
_ble_complete_ac_comp1=
_ble_complete_ac_cand=
_ble_complete_ac_word=
_ble_complete_ac_insert=
_ble_complete_ac_suffix=
## 関数 ble-complete/auto-complete.impl opts
##   @param[in] opts
#      コロン区切りのオプションのリストです。
##     sync   ユーザ入力があっても処理を中断しない事を指定します。
function ble-complete/auto-complete.impl {
  local opts=$1
  local comp_type=
  [[ :$opts: == *:sync:* ]] && comp_type=${comp_type}s

  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  [[ $comp_text ]] || return 0

  local contexts
  ble-complete/candidates/get-prefix-contexts "$comp_text" "$comp_index" || return 0

  # ble-complete/candidates/generate 設定
  local bleopt_complete_contract_function_names=
  ((bleopt_complete_stdin_frequency>25)) &&
    local bleopt_complete_stdin_frequency=25
  local COMP1 COMP2 COMPS COMPV
  local comps_flags
  local rex_ambiguous_compv
  local cand_count
  local -a cand_cand cand_prop cand_word cand_show cand_data
  ble-complete/candidates/generate
  ((ext)) && return "$ext"

  ((cand_count)) || return

  _ble_complete_ac_comp1=$COMP1
  _ble_complete_ac_cand=${cand_cand[0]}
  _ble_complete_ac_word=${cand_word[0]}
  [[ $_ble_complete_ac_word == "$COMPS" ]] && return

  # addtail 等の修飾
  local INSERT=$_ble_complete_ac_word SUFFIX=
  local ACTION
  ble/string#split-words ACTION "${cand_prop[0]}"
  if ble/is-function "$ACTION/complete"; then
    local CAND=${cand_cand[0]}
    local DATA=${cand_data[0]}
    "$ACTION/complete"
  fi
  _ble_complete_ac_insert=$INSERT
  _ble_complete_ac_suffix=$SUFFIX

  if [[ $_ble_complete_ac_word == "$COMPS"* ]]; then
    # 入力候補が既に続きに入力されている時は提示しない
    [[ ${comp_text:COMP1} == "$_ble_complete_ac_word"* ]] && return

    _ble_complete_ac_type=c
    local ins=${INSERT:${#COMPS}}
    _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
    ((_ble_edit_mark=_ble_edit_ind+${#ins}))
  else
    if [[ $comp_type == *a* ]]; then
      _ble_complete_ac_type=a
    else
      _ble_complete_ac_type=r
    fi
    _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_ind" " [$INSERT] "
    ((_ble_edit_mark=_ble_edit_ind+4+${#INSERT}))
  fi

  _ble_edit_mark_active=auto_complete
  ble-decode/keymap/push auto_complete
  ble-decode-key "$_ble_complete_KCODE_ENTER" # dummy key input to record keyboard macros
  return
}

## 背景関数 ble/widget/auto-complete.idle
function ble-complete/auto-complete.idle {
  # ※特に上書きしなければ常に wait-user-input で抜ける。
  ble/util/idle.wait-user-input

  [[ $_ble_decode_key__kmap == emacs || $_ble_decode_key__kmap == vi_imap ]] || return 0

  case $_ble_decode_widget_last in
  (ble/widget/self-insert) ;;
  (ble/widget/complete) ;;
  (ble/widget/vi_imap/complete) ;;
  (*) return 0 ;;
  esac

  [[ $_ble_edit_str ]] || return 0

  # bleopt_complete_ac_delay だけ経過してから処理
  local rest_delay=$((bleopt_complete_ac_delay-ble_util_idle_elapsed))
  if ((rest_delay>0)); then
    ble/util/idle.sleep "$rest_delay"
    return
  fi

  ble-complete/auto-complete.impl
}
ble/function#try ble/util/idle.push-background ble-complete/auto-complete.idle

## 編集関数 ble/widget/auto-complete-enter
##
##   Note:
##     キーボードマクロで自動補完を明示的に起動する時に用いる編集関数です。
##     auto-complete.idle に於いて ble-decode-key を用いて
##     キー auto_complete_enter を発生させ、
##     再生時にはこのキーを通して自動補完が起動されます。
##
function ble/widget/auto-complete-enter {
  ble-complete/auto-complete.impl sync
}
function ble/widget/auto_complete/cancel {
  ble-decode/keymap/pop
  _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_mark" ''
  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
}
function ble/widget/auto_complete/accept {
  ble-decode/keymap/pop
  _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_mark" ''

  local comp_text=$_ble_edit_str
  local insert_beg=$_ble_complete_ac_comp1
  local insert_end=$_ble_edit_ind
  local insert=$_ble_complete_ac_insert
  local suffix=$_ble_complete_ac_suffix
  ble/util/invoke-hook _ble_complete_insert_hook
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"

  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
  ble-edit/content/clear-arg
}
function ble/widget/auto_complete/exit-default {
  ble/widget/auto_complete/cancel
  ble-decode-key "${KEYS[@]}"
}
function ble/widget/auto_complete/self-insert {
  local code=$((KEYS[0]&ble_decode_MaskChar))
  ((code==0)) && return

  local ret

  # もし挿入によって現在の候補が変わらないのであれば、
  # 候補を表示したまま挿入を実行する。
  ble/util/c2s "$code"; local ins=$ret
  local comps_cur=${_ble_edit_str:_ble_complete_ac_comp1:_ble_edit_ind-_ble_complete_ac_comp1}
  local comps_new=$comps_cur$ins
  if [[ $_ble_complete_ac_type == c ]]; then
    # c: 入力済み部分が補完結果の先頭に含まれる場合
    #   挿入した後でも補完結果の先頭に含まれる場合、その文字数だけ確定。
    if [[ $_ble_complete_ac_word == "$comps_new"* ]]; then
      ((_ble_edit_ind+=${#ins}))

      # Note: 途中で完全一致した場合は tail を挿入せずに終了する事にする
      [[ ! $_ble_complete_ac_word ]] && ble/widget/auto_complete/cancel
      return
    fi
  elif [[ $_ble_complete_ac_type == [ra] ]]; then
    if local ret close_type; ble-syntax:bash/simple-word/close-open-word "$comps_new"; then
      ble-syntax:bash/simple-word/eval "$ret"; local compv_new=$ret
      if [[ $_ble_complete_ac_type == r ]]; then
        # r: 遡って書き換わる時
        #   挿入しても展開後に一致する時、そのまま挿入。
        #   元から展開後に一致していない場合もあるが、その場合は一旦候補を消してやり直し。
        if [[ $_ble_complete_ac_cand == "$compv_new"* ]]; then
          _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          [[ $_ble_complete_ac_cand == "$compv_new" ]] &&
            ble/widget/auto_complete/cancel
          return
        fi
      elif [[ $_ble_complete_ac_type == a ]]; then
        # a: 曖昧一致の時
        #   文字を挿入後に展開してそれが曖昧一致する時、そのまま挿入。
        ble-complete/util/construct-ambiguous-regex "$compv_new"
        local rex_ambiguous_compv=^$ret
        if [[ $_ble_complete_ac_cand =~ $rex_ambiguous_compv ]]; then
          _ble_edit_str.replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          return
        fi
      fi
    fi
  fi

  ble/widget/auto_complete/cancel
  ble-decode-key "${KEYS[@]}"
}
function ble-decode/keymap:auto_complete/define {
  local ble_bind_keymap=auto_complete

  ble-bind -f __defchar__ auto_complete/self-insert
  ble-bind -f __default__ auto_complete/exit-default
  ble-bind -f C-g         auto_complete/cancel
  ble-bind -f S-RET       auto_complete/accept
  ble-bind -f S-C-m       auto_complete/accept
  ble-bind -f auto_complete_enter nop
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

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
