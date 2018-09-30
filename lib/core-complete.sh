#!/bin/bash

ble-import "$_ble_base/lib/core-syntax.sh"

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
##   ble-complete/action:plain
##   ble-complete/action:word
##   ble-complete/action:file
##   ble-complete/action:progcomp
##   ble-complete/action:command
##   ble-complete/action:variable
##
## action の実装
##
## 関数 ble-complete/action:$ACTION/initialize
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
##
##     S クォート ''  の中にいる事を表します。
##     E クォート $'' の中にいる事を表します。
##     D クォート ""  の中にいる事を表します。
##     I クォート $"" の中にいる事を表します。
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
## 関数 ble-complete/action:$ACTION/complete
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

function ble-complete/action/util/complete.addtail {
  suffix=$suffix$1
}
function ble-complete/action/util/complete.close-quotation {
  case $comps_flags in
  (*[SE]*) ble-complete/action/util/complete.addtail \' ;;
  (*[DI]*) ble-complete/action/util/complete.addtail \" ;;
  esac
}

#------------------------------------------------------------------------------

# action:plain

function ble-complete/action:plain/initialize {
  if [[ $CAND == "$COMPV"* ]]; then
    local ins=${CAND:${#COMPV}} ret

    # 単語内の文脈に応じたエスケープ
    case $comps_flags in
    (*S*)    ble/string#escape-for-bash-single-quote "$ins"; ins=$ret ;;
    (*E*)    ble/string#escape-for-bash-escape-string "$ins"; ins=$ret ;;
    (*[DI]*) ble/string#escape-for-bash-double-quote "$ins"; ins=$ret ;;
    (*)
      if [[ $comps_fixed ]]; then
        ble/string#escape-for-bash-specialchars-in-brace "$ins"
      else
        ble/string#escape-for-bash-specialchars "$ins"
      fi
      ins=$ret ;;
    esac

    # 直前にパラメータ展開があればエスケープ
    if [[ $comps_flags == *p* && $ins == [a-zA-Z_0-9]* ]]; then
      case $comps_flags in
      (*[DI]*)
        if [[ $COMPS =~ $rex_raw_paramx ]]; then
          local rematch1=${BASH_REMATCH[1]}
          INSERT=$rematch1'${'${COMPS:${#rematch1}+1}'}'$ins
          return
        else
          ins='""'$ins
        fi ;;
      (*) ins='\'$ins ;;
      esac
    fi

    INSERT=$COMPS$ins
  elif [[ $comps_fixed && $CAND == "${comps_fixed#*:}"* ]]; then
    local comps_fixed_part=${COMPS::${comps_fixed%%:*}}
    local compv_fixed_part=${comps_fixed#*:}
    local ins=${CAND:${#compv_fixed_part}}
    local ret; ble/string#escape-for-bash-specialchars-in-brace "$ins"
    INSERT=$comps_fixed_part$ret

  else
    local ret
    ble/string#escape-for-bash-specialchars "$CAND"; INSERT=$ret
  fi
}
function ble-complete/action:plain/complete { :; }

# action:word

function ble-complete/action:word/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:word/complete {
  ble-complete/action/util/complete.close-quotation
  ble-complete/action/util/complete.addtail ' '
}

function ble-complete/action:literal-substr/initialize { :; }
function ble-complete/action:literal-substr/complete { :; }
function ble-complete/action:literal-word/initialize { :; }
function ble-complete/action:literal-word/complete { ble-complete/action:word/complete; }
function ble-complete/action:substr/initialize { ble-complete/action:word/initialize; }
function ble-complete/action:substr/complete { :; }

# action:file

function ble-complete/action:file/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:file/complete {
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
function ble-complete/action:file/getg {
  if [[ -h $CAND ]]; then
    ble-color-face2g filename_link
  elif [[ -d $CAND ]]; then
    ble-color-face2g filename_directory
  elif [[ -S $CAND ]]; then
    ble-color-face2g filename_socket
  elif [[ -b $CAND ]]; then
    ble-color-face2g filename_block
  elif [[ -c $CAND ]]; then
    ble-color-face2g filename_character
  elif [[ -p $CAND ]]; then
    ble-color-face2g filename_pipe
  elif [[ -x $CAND ]]; then
    ble-color-face2g filename_executable
  elif [[ -e $CAND ]]; then
    ble-color-face2g filename_other
  else
    ble-color-face2g filename_warning
  fi
}

# action:progcomp

function ble-complete/action:progcomp/initialize {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/initialize
  else
    ble-complete/action:plain/initialize
  fi
}
function ble-complete/action:progcomp/complete {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/complete
  else
    if [[ -d $CAND ]]; then
      [[ $CAND != */ ]] &&
        ble-complete/action/util/complete.addtail /
    else
      ble-complete/action/util/complete.close-quotation
      ble-complete/action/util/complete.addtail ' '
    fi
  fi

  [[ $DATA == *:nospace:* ]] && suffix=${suffix%' '}
}
function ble-complete/action:progcomp/getg {
  if [[ $DATA == *:filenames:* ]]; then
    ble-complete/action:file/getg
  fi
}

# action:command

function ble-complete/action:command/initialize {
  ble-complete/action:plain/initialize
}
function ble-complete/action:command/complete {
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
      insert_flags=${insert_flags}n
    fi
  else
    ble-complete/action/util/complete.close-quotation
    ble-complete/action/util/complete.addtail ' '
  fi
}
function ble-complete/action:command/getg {
  if [[ -d $CAND ]]; then
    ble-color-face2g filename_directory
  else
    # Note: ble-syntax/highlight/cmdtype はキャッシュ機能がついているが、
    #   キーワードに対して呼び出さない前提なのでキーワードを渡すと
    #   BLE_ATTR_ERR を返してしまう。
    local type; ble/util/type type "$CAND"
    ble-syntax/highlight/cmdtype1 "$type" "$CAND"
    if [[ $CAND == */ ]] && ((type==BLE_ATTR_ERR)); then
      type=BLE_ATTR_CMD_FUNCTION
    fi
    ble-syntax/attr2g "$type"
  fi
}

# action:variable

function ble-complete/action:variable/initialize { ble-complete/action:plain/initialize; }
function ble-complete/action:variable/complete {
  case $DATA in
  (assignment) 
    # var= 等に於いて = を挿入
    ble-complete/action/util/complete.addtail '=' ;;
  (braced)
    # ${var 等に於いて } を挿入
    ble-complete/action/util/complete.addtail '}' ;;
  (word)       ble-complete/action:word/complete ;;
  (arithmetic) ;; # do nothing
  esac
}
function ble-complete/action:variable/getg {
  ble-color-face2g syntax_varname
}

#==============================================================================
# source

## 関数 ble-complete/cand/yield ACTION CAND DATA
##   @param[in] ACTION
##   @param[in] CAND
##   @param[in] DATA
##   @var[in] COMP_PREFIX
function ble-complete/cand/yield {
  local ACTION=$1 CAND=$2 DATA="${*:3}"
  [[ $flag_force_fignore ]] && ! ble-complete/.fignore/filter "$CAND" && return

  local PREFIX_LEN=0
  [[ $CAND == "$COMP_PREFIX"* ]] && PREFIX_LEN=${#COMP_PREFIX}

  local INSERT=$CAND
  ble-complete/action:"$ACTION"/initialize

  local icand
  ((icand=cand_count++))
  cand_cand[icand]=$CAND
  cand_word[icand]=$INSERT
  cand_pack[icand]=$ACTION:${#CAND},${#INSERT},$PREFIX_LEN:$CAND$INSERT$DATA
}

_ble_complete_cand_varnames=(ACTION CAND INSERT DATA PREFIX_LEN)

## 関数 ble-complete/cand/unpack data
##   @param[in] data
##     ACTION:ncand,ninsert,PREFIX_LEN:$CAND$INSERT$DATA
##   @var[out] ACTION CAND INSERT DATA PREFIX_LEN
function ble-complete/cand/unpack {
  local pack=$1
  ACTION=${pack%%:*} pack=${pack#*:}
  local text=${pack#*:}
  IFS=, eval 'pack=(${pack%%:*})'
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
## 関数 ble-complete/source:$name args...
##   @param[in] args...
##     ble-syntax/completion-context/generate で設定されるユーザ定義の引数。
##
##   @var[in] COMP1 COMP2 COMPS COMPV comp_type
##
##   @var[out] COMP_PREFIX
##     ble-complete/cand/yield で参照される一時変数。
##

# source:wordlist

function ble-complete/source:wordlist {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # process options
  local opt_raw= opt_noword=
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
        (*) ;; # ignore
        esac
      done ;;
    esac
  done

  local action=word
  [[ $opt_noword ]] && action=substr
  [[ $opt_raw ]] && action=literal-$action

  local cand
  for cand; do
    [[ $cand == "$COMPV"* ]] && ble-complete/cand/yield "$action" "$cand"
  done
}

# source:command

function ble-complete/source:command/.contract-by-slashes {
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

function ble-complete/source:command/gen.1 {
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

function ble-complete/source:command/gen {
  if [[ $comp_type != *a* && $bleopt_complete_contract_function_names ]]; then
    ble-complete/source:command/gen.1 |
      ble-complete/source:command/.contract-by-slashes
  else
    ble-complete/source:command/gen.1
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
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  ((${#ret[@]})) && printf '%s\n' "${ret[@]}"
}
function ble-complete/source:command {
  [[ $comps_flags == *v* ]] || return 1
  [[ ! $COMPV ]] && shopt -q no_empty_cmd_completion && return 1
  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  local cand arr i=0
  local compgen
  ble/util/assign compgen 'ble-complete/source:command/gen'
  [[ $compgen ]] || return 1
  ble/util/assign-array arr 'sort -u <<< "$compgen"' # 1 fork/exec
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    # workaround: 何故か compgen -c -- "$compv_quoted" で
    #   厳密一致のディレクトリ名が混入するので削除する。
    [[ $cand != */ && -d $cand ]] && ! type "$cand" &>/dev/null && continue

    ble-complete/cand/yield command "$cand"
  done
}

# source:file

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

## 関数 ble-complete/source:file/.construct-ambiguous-pathname-pattern path
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
function ble-complete/source:file/.construct-ambiguous-pathname-pattern {
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
## 関数 ble-complete/source:file/.construct-pathname-pattern path
##   @param[in] path
##   @var[out] ret
function ble-complete/source:file/.construct-pathname-pattern {
  local path=$1
  if [[ $comp_type == *a* ]]; then
    ble-complete/source:file/.construct-ambiguous-pathname-pattern "$path"; local pattern=$ret
  else
    ble/string#escape-for-bash-glob "$path"; local pattern=$ret*
  fi
  ret=$pattern
}

function ble-complete/source:file {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  #   Note: compgen -A file (以下のコード参照) はバグがあって、
  #     bash-4.0 と 4.1 でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #     local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #     local candidates; ble/util/assign-array candidates 'compgen -A file -- "$compv_quoted"'

  local ret
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret"
  local -a candidates; candidates=("${ret[@]}")

  local cand
  for cand in "${candidates[@]}"; do
    [[ -e $cand || -h $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    ble-complete/cand/yield file "$cand"
  done
}

# source:dir

function ble-complete/source:dir {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type != *a* && $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  # Note: compgen -A directory (以下のコード参照) はバグがあって、
  #   bash-4.3 以降でクォート除去が実行されないので使わない (#D0714 #M0009)
  #
  #   local q="'" Q="'\''"; local compv_quoted="'${COMPV//$q/$Q}'"
  #   local candidates; ble/util/assign-array candidates 'compgen -A directory -S / -- "$compv_quoted"'

  local ret
  ble-complete/source:file/.construct-pathname-pattern "$COMPV"
  ble-complete/util/eval-pathname-expansion "$ret/"
  local -a candidates; candidates=("${ret[@]}")

  local cand
  for cand in "${candidates[@]}"; do
    [[ -d $cand ]] || continue
    [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
    [[ $cand == / ]] || cand=${cand%/}
    ble-complete/cand/yield file "$cand"
  done
}

# source:rhs

function ble-complete/source:rhs { ble-complete/source:file; }

# source:argument (complete -p)

## 関数 ble-complete/source:argument/.progcomp-helper-vars
##   プログラム補完で提供される変数を構築します。
##   @param[in]  comp_words comp_cword comp_line comp_point
##   @param[out] COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT COMP_KEY COMP_TYPE
function ble-complete/source:argument/.progcomp-helper-vars {
  COMP_TYPE=9
  COMP_KEY="${KEYS[${#KEYS[@]}-1]:-9}" # KEYS defined in ble-decode/widget/.call-keyseq

  # Note: 以降の処理は基本的には comp_words, comp_line, comp_point, comp_cword を
  #   直接 COMP_WORDS COMP_LINE COMP_POINT COMP_CWORD にコピーするだけである。
  #   しかし、直接代入する場合。$'' などがあると bash-completion が正しく動かないので、
  #   エスケープを削除して適当に処理する。

  COMP_LINE=
  COMP_WORDS=()
  local shell_specialchars=']\ ["'\''`$|&;<>()*?{}!^'$'\n\t' q="'" Q="'\''" qq="''"
  local word delta=0 index=0 offset=0
  for word in "${comp_words[@]}"; do
    # @var point
    #   word が現在の単語の時、word 内のカーソル位置を保持する。
    #   それ以外の時は空文字列。
    local point=$((comp_point-offset))
    ((0<=point&&point<=${#word})) || point=

    # 単語が単純単語ならば展開する
    local ret simple_flags simple_ibrace
    if [[ ! $word ]]; then
      # Note: 空文字列に対して正しい単語とする為に '' とすると git の補完関数が動かなくなる。
      #   仕方がないので空文字列のままで登録する事にする。
      : do nothing
      # word="''"; [[ $point ]] && point=2
    elif ble-syntax:bash/simple-word/reconstruct-incomplete-word "$word"; then
      ble-syntax:bash/simple-word/eval "$ret"
      ((${#COMP_WORDS[*]})) && [[ $ret == *["$shell_specialchars"]* ]] &&
        ret="'${ret//$q/$Q}'" ret=${ret#"$qq"} ret=${ret%"$qq"} # コマンド名以外はクォート
      word=$ret
      if [[ $point ]]; then
        if ((point==${#1})); then
          point=${#word}
        elif ble-syntax:bash/simple-word/reconstruct-incomplete-word "${1::point}"; then
          ble-syntax:bash/simple-word/eval "$ret"
          ((${#COMP_WORDS[*]})) && [[ $ret == *["$shell_specialchars"]* ]] &&
            ret="'${ret//$q/$Q}" ret=${ret#"$qq"}
          point=${#ret}
        fi
      fi
    fi

    # COMP_CWORD / COMP_POINT の更新
    if [[ $point ]]; then
      COMP_CWORD=${#COMP_WORDS[*]}
      COMP_POINT=$point
      [[ $COMP_LINE ]] && ((COMP_POINT+=${#COMP_LINE}+1))
    fi

    # COMP_LINE / COMP_WORDS の更新
    if [[ $COMP_LINE ]]; then
      COMP_LINE="$COMP_LINE $word"
    else
      COMP_LINE=$word
    fi
    ble/array#push COMP_WORDS "$word"

    ((offset+=${#word}+1))
  done

}
function ble-complete/source:argument/.progcomp-helper-prog {
  if [[ $comp_prog ]]; then
    (
      local COMP_WORDS COMP_CWORD
      export COMP_LINE COMP_POINT COMP_TYPE COMP_KEY
      ble-complete/source:argument/.progcomp-helper-vars
      local cmd=${comp_words[0]} cur=${comp_words[comp_cword]} prev=${comp_words[comp_cword-1]}
      "$comp_prog" "$cmd" "$cur" "$prev"
    )
  fi
}
function ble-complete/source:argument/.progcomp-helper-func {
  [[ $comp_func ]] || return
  local -a COMP_WORDS
  local COMP_LINE COMP_POINT COMP_CWORD COMP_TYPE COMP_KEY
  ble-complete/source:argument/.progcomp-helper-vars

  # compopt に介入して -o/+o option を読み取る。
  local fDefault=
  function compopt {
    builtin compopt "$@"; local ret="$?"

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

## 関数 ble-complete/source:argument/.progcomp
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
function ble-complete/source:argument/.progcomp {
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
          ble/array#push compoptions "-$c" ble-complete/source:argument/.progcomp-helper-func ;;
        (C)
          comp_prog=${compargs[iarg++]}
          ble/array#push compoptions "-$c" ble-complete/source:argument/.progcomp-helper-prog ;;
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
  #   ble-complete/source:argument/.progcomp-helper-func 関数内で補間関数の終了ステータスを確認し、
  #   もし 124 だった場合には is_default_completion に retry を設定する。
  if [[ $is_default_completion == retry && ! $_ble_complete_retry_guard ]]; then
    local _ble_complete_retry_guard=1
    ble-complete/source:argument/.progcomp
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

  local action=progcomp
  [[ $comp_opts == *:filenames:* && $COMPV == */* ]] && COMP_PREFIX=${COMPV%/*}/

  local cand i=0 count=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/yield "$action" "$cand" "$comp_opts"
    ((count++))
  done

  ((count!=0))
}

## 関数 ble-complete/source:argument/.generate-user-defined-completion
##   ユーザ定義の補完を実行します。ble/cmdinfo/complete:コマンド名
##   という関数が定義されている場合はそれを使います。
##   それ以外の場合は complete によって登録されているプログラム補完が使用されます。
##
##   @var[in] COMP1 COMP2
##   @var[in] (variables set by ble-syntax/parse)
##
function ble-complete/source:argument/.generate-user-defined-completion {
  local comp_words comp_line comp_point comp_cword
  ble-syntax:bash/extract-command "$COMP2" || return 1

  # 単語の途中に補完開始点がある時、単語を分割する
  if
    # @var point 単語内のカーソルの位置
    # @var comp1 単語内の補完開始点
    local forward_words=
    ((comp_cword)) && IFS=' ' eval 'forward_words="${comp_words[*]::comp_cword} "'
    local point=$((comp_point-${#forward_words}))
    local comp1=$((point-(COMP2-COMP1)))
    ((comp1>0))
  then
    local w=${comp_words[comp_cword]}
    comp_words=("${comp_words[@]::comp_cword}" "${w::comp1}" "${w:comp1}" "${comp_words[@]:comp_cword+1}")
    IFS=' ' eval 'comp_line="${comp_words[*]}"'
    ((comp_cword++,comp_point++))
  fi

  local cmd=${comp_words[0]}
  if ble/is-function "ble/cmdinfo/complete:$cmd"; then
    "ble/cmdinfo/complete:$cmd"
  elif [[ $cmd == */?* ]] && ble/is-function "ble/cmdinfo/complete:${cmd##*/}"; then
    "ble/cmdinfo/complete:${cmd##*/}"
  else
    ble-complete/source:argument/.progcomp
  fi
}

function ble-complete/source:argument {
  local comp_opts=:

  [[ $comp_type == *a* ]] &&
      ble-complete/candidates/.filter-by-regex "$comps_rex_ambiguous"
  local old_cand_count=$cand_count

  # try complete&compgen
  ble-complete/source:argument/.generate-user-defined-completion; local ext=$?
  ((ext==148)) && return "$ext"
  if ((ext==0)); then
    if [[ $comp_type == *a* ]]; then
      ble-complete/candidates/.filter-by-regex "$comps_rex_ambiguous"
      (($?==148)) && return "$ext"
    fi
    ((cand_count>old_cand_count)) && return "$ext"
  fi

  # 候補が見付からない場合 (または曖昧補完で COMPV に / が含まれる場合)
  if [[ $comp_opts == *:dirnames:* ]]; then
    ble-complete/source:dir
  else
    # filenames, default, bashdefault
    ble-complete/source:file
  fi

  if ((cand_count<=old_cand_count)); then
    if local rex='^/?[-a-zA-Z_]+[:=]'; [[ $COMPV =~ $rex ]]; then
      # var=filename --option=filename /I:filename など。
      local prefix=$BASH_REMATCH value=${COMPV:${#BASH_REMATCH}}
      local COMP_PREFIX=$prefix
      [[ $comp_type != *a* && $value =~ ^.+/ ]] && COMP_PREFIX=$prefix${BASH_REMATCH[0]}

      local ret cand
      ble-complete/source:file/.construct-pathname-pattern "$value"
      ble-complete/util/eval-pathname-expansion "$ret"
      for cand in "${ret[@]}"; do
        [[ -e $cand || -h $cand ]] || continue
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/cand/yield file "$prefix$cand"
      done
    fi
  fi
}

# source:variable
# source:user
# source:hostname

function ble-complete/source/compgen {
  [[ $comps_flags == *v* ]] || return 1
  [[ $comp_type == *a* ]] && local COMPS=${COMPS::1} COMPV=${COMPV::1}

  local compgen_action=$1
  local action=$2
  local data=$3

  local q="'" Q="'\''"
  local compv_quoted="'${COMPV//$q/$Q}'"
  local cand arr
  ble/util/assign-array arr 'compgen -A "$compgen_action" -- "$compv_quoted"'

  # 既に完全一致している場合は、より前の起点から補完させるために省略
  [[ $1 != '=' && ${#arr[@]} == 1 && $arr == "$COMPV" ]] && return

  local i=0
  for cand in "${arr[@]}"; do
    ((i++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/yield "$action" "$cand" "$data"
  done
}

function ble-complete/source:variable {
  local data=
  case $1 in
  ('=') data=assignment ;;
  ('b') data=braced ;;
  ('a') data=arithmetic ;;
  ('w'|*) data=word ;;
  esac
  ble-complete/source/compgen variable variable "$data"
}
function ble-complete/source:user {
  ble-complete/source/compgen user word
}
function ble-complete/source:hostname {
  ble-complete/source/compgen hostname word
}

#==============================================================================
# context

## 関数  ble-complete/complete/determine-context-from-opts opts
##   @param[in] opts
##   @var[out] context
function ble-complete/complete/determine-context-from-opts {
  local opts=$1
  context=syntax
  if local rex=':context=([^:]+):'; [[ :$opts: =~ $rex ]]; then
    local rematch1=${BASH_REMATCH[1]}
    if ble/is-function ble-complete/context:"$rematch1"/generate-sources; then
      context=$rematch1
    else
      echo "ble/widget/complete: unknown context '$rematch1'" >&2
    fi
  fi
}
## 関数 ble-complete/context/filter-prefix-sources
##   @var[in] comp_text comp_index
##   @var[in,out] sources
function ble-complete/context/filter-prefix-sources {
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
## 関数 ble-complete/context/overwrite-sources source
##   @param[in] source
##   @var[in] comp_text comp_index
##   @var[in,out] sources
function ble-complete/context/overwrite-sources {
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

## 関数 ble-complete/context:syntax/generate-sources comp_text comp_index
##   @var[in] comp_text comp_index
##   @var[out] sources
function ble-complete/context:syntax/generate-sources {
  ble-syntax/import
  ble-edit/content/update-syntax
  ble-syntax/completion-context/generate "$comp_text" "$comp_index"
  ((${#sources[@]}))
}
function ble-complete/context:filename/generate-sources {
  ble-complete/context:syntax/generate-sources || return
  ble-complete/context/overwrite-sources file
}
function ble-complete/context:command/generate-sources {
  ble-complete/context:syntax/generate-sources || return
  ble-complete/context/overwrite-sources command
}
function ble-complete/context:variable/generate-sources {
  ble-complete/context:syntax/generate-sources || return
  ble-complete/context/overwrite-sources variable
}
function ble-complete/context:username/generate-sources {
  ble-complete/context:syntax/generate-sources || return
  ble-complete/context/overwrite-sources user
}
function ble-complete/context:hostname/generate-sources {
  ble-complete/context:syntax/generate-sources || return
  ble-complete/context/overwrite-sources hostname
}

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
##     ble-complete/cand/unpack "${cand_pack[0]}"
##
##   先頭に ACTION が格納されているので
##   ACTION だけ参照する場合には以下の様にする。
##
##     local ACTION=${cand_pack[0]%%:*}
##

## 関数 ble-complete/util/construct-ambiguous-regex text fixlen
##   曖昧一致に使う正規表現を生成します。
##   @param[in] text
##   @param[in,out] fixlen=1
##   @var[in] comp_type
##   @var[out] ret
function ble-complete/util/construct-ambiguous-regex {
  local text=$1 fixlen=${2:-1}
  local i=0 n=${#text} c=
  local -a buff=()
  for ((i=0;i<n;i++)); do
    ((i>=fixlen)) && ble/array#push buff '.*'
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

## 関数 ble-complete/candidates/.pick-nearest-sources
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
function ble-complete/candidates/.pick-nearest-sources {
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
  elif local ret simple_flags simple_ibrace; ble-syntax:bash/simple-word/reconstruct-incomplete-word "$COMPS"; then
    local reconstructed=$ret
    comps_flags=$comps_flags$simple_flags
    ble-syntax:bash/simple-word/eval "$reconstructed"; comps_flags=${comps_flags}v COMPV=$ret
    [[ $COMPS =~ $rex_raw_paramx ]] && comps_flags=${comps_flags}p

    if ((${simple_ibrace%:*})); then
      ble-syntax:bash/simple-word/eval "${reconstructed::${simple_ibrace#*:}}"
      comps_fixed=${simple_ibrace%:*}:$ret
    fi
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

function ble-complete/candidates/.filter-word-by-prefix {
  local prefix=$1
  # todo: 複数の配列に触る非効率な実装だが後で考える
  local i j=0
  local -a prop=() cand=() word=() show=() data=()
  for ((i=0;i<cand_count;i++)); do
    ((i%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148
    [[ ${cand_word[i]} == "$prefix"* ]] || continue
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

function ble-complete/candidates/.initialize-rex_raw_paramx {
  local element=$_ble_syntax_bash_simple_rex_element
  local open_dquot=$_ble_syntax_bash_simple_rex_open_dquot
  rex_raw_paramx='^('$element'*('$open_dquot')?)\$[a-zA-Z_][a-zA-Z_0-9]*$'
}

## 関数 ble-complete/candidates/generate
##   @var[in] comp_text comp_index
##   @arr[in] sources
##   @var[out] COMP1 COMP2 COMPS COMPV
##   @var[out] comp_type comps_flags comps_fixed
##   @var[out] cand_*
##   @var[out] comps_rex_ambiguous
function ble-complete/candidates/generate {
  local flag_force_fignore=
  local -a _fignore=()
  if [[ $FIGNORE ]]; then
    ble-complete/.fignore/prepare
    ((${#_fignore[@]})) && shopt -q force_fignore && flag_force_fignore=1
  fi

  local rex_raw_paramx
  ble-complete/candidates/.initialize-rex_raw_paramx

  ble/util/test-rl-variable completion-ignore-case &&
    comp_type=${comp_type}i

  cand_count=0
  cand_cand=() # 候補文字列
  cand_word=() # 挿入文字列 (～ エスケープされた候補文字列)
  cand_pack=() # 候補の詳細データ

  local -a remaining_sources nearest_sources
  remaining_sources=("${sources[@]}")
  while ((${#remaining_sources[@]})); do
    # 次の開始点が近くにある候補源たち
    nearest_sources=()
    ble-complete/candidates/.pick-nearest-sources

    # 候補生成
    local src asrc source
    for src in "${nearest_sources[@]}"; do
      ble/string#split-words asrc "$src"
      ble/string#split source : "${asrc[0]}"

      local COMP_PREFIX= # 既定値 (yield-candidate で参照)
      ble-complete/source:"${source[@]}"
      ble-complete/check-cancel && return 148
    done

    [[ $comps_fixed ]] &&
      ble-complete/candidates/.filter-word-by-prefix "${COMPS::${comps_fixed%%:*}}"
    ((cand_count)) && return 0
  done

  if [[ $bleopt_complete_ambiguous && $COMPV ]]; then
    comp_type=${comp_type}a
    remaining_sources=("${sources[@]}")

    local src asrc source
    while ((${#remaining_sources[@]})); do
      nearest_sources=()
      ble-complete/candidates/.pick-nearest-sources

      # comps_rex_ambiguous 初期化
      local fixlen=1
      if [[ $comps_fixed ]]; then
        local compv_fixed_part=${comps_fixed#*:}
        [[ $compv_fixed_part ]] && fixlen=${#compv_fixed_part}
      fi
      local ret; ble-complete/util/construct-ambiguous-regex "$COMPV" "$fixlen"
      comps_rex_ambiguous=^$ret

      for src in "${nearest_sources[@]}"; do
        ble/string#split-words asrc "$src"
        ble/string#split source : "${asrc[0]}"

        local COMP_PREFIX= # 既定値 (yield-candidate で参照)
        ble-complete/source:"${source[@]}"
        ble-complete/check-cancel && return 148
      done

      ble-complete/candidates/.filter-by-regex "$comps_rex_ambiguous"
      (($?==148)) && return 148

      [[ $comps_fixed ]] &&
        ble-complete/candidates/.filter-word-by-prefix "${COMPS::${comps_fixed%%:*}}"
      ((cand_count)) && return 0
    done
    comp_type=${comp_type//a}
  fi

  return 0
}

## 関数 ble-complete/candidates/determine-common-prefix
##   cand_* を元に common prefix を算出します。
##   @var[in] cand_*
##   @var[in] comps_rex_ambiguous
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
    local simple_flags simple_ibrace
    ble-syntax:bash/simple-word/reconstruct-incomplete-word "$common" &&
      ble-syntax:bash/simple-word/eval "$ret" &&
      [[ $ret =~ $comps_rex_ambiguous ]] ||
        common=$COMPS
  elif ((cand_count!=1)) && [[ $common != "$COMPS"* ]]; then
    # Note: #D0768 文法的に単純であれば (構造を破壊しなければ) 遡って書き換えが起こることを許す。
    ble-syntax:bash/simple-word/is-simple-or-open-simple "$common" ||
      common=$COMPS
  fi

  ret=$common
}

#------------------------------------------------------------------------------
#
# 候補表示
#

_ble_complete_menu_beg=
_ble_complete_menu_end=
_ble_complete_menu_str=
_ble_complete_menu_active=
_ble_complete_menu_common_part=
_ble_complete_menu_items=()
_ble_complete_menu_pack=()
_ble_complete_menu_comp=()
_ble_complete_menu_selected=-1
_ble_complete_menu_filter=

## 関数 ble-complete/menu/construct-single-entry pack opts
##   @param[in] pack
##     cand_pack の要素と同様の形式の文字列です。
##   @param[in] opts
##     コロン区切りのオプションです。
##     selected
##       選択されている候補の描画シーケンスを生成します。
##     use_vars
##       引数の pack を展開する代わりに、
##       既に展開されているローカル変数を参照します。
##       この時、引数 pack は使用されません。
##   @var[in,out] x y
##   @var[out] ret
##   @var[in] cols lines menu_common_part
function ble-complete/menu/construct-single-entry {
  local opts=$2
  if [[ :$opts: != *:use_vars:* ]]; then
    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "$1"
  fi
  local show=${CAND:PREFIX_LEN}
  local g=0; ble/function#try ble-complete/action:"$ACTION"/getg
  [[ :$opts: == *:selected:* ]] && ((g|=_ble_color_gflags_Revert))
  if [[ $menu_common_part && $CAND == "$menu_common_part"* ]]; then
    local out= alen=$((${#menu_common_part}-PREFIX_LEN))
    local sgr0 sgr1 g1
    if ((alen>0)); then
      # 高速化の為、直接 _ble_color_g2sgr を参照する
      ret=${_ble_color_g2sgr[g1=g|_ble_color_gflags_Bold]}
      [[ $ret ]] || ble-color-g2sgr "$g1"; sgr0=$ret
      ret=${_ble_color_g2sgr[g1=g|_ble_color_gflags_Bold|_ble_color_gflags_Revert]}
      [[ $ret ]] || ble-color-g2sgr "$g1"; sgr1=$ret

      ble-edit/info/.construct-text "${show::alen}"
      out=$out$sgr0$ret
    fi
    if ((alen<${#show})); then
      # 高速化の為、直接 _ble_color_g2sgr を参照する
      ret=${_ble_color_g2sgr[g]}
      [[ $ret ]] || ble-color-g2sgr "$g"; sgr0=$ret
      ret=${_ble_color_g2sgr[g1=g|_ble_color_gflags_Revert]}
      [[ $ret ]] || ble-color-g2sgr "$g1"; sgr1=$ret

      ble-edit/info/.construct-text "${show:alen}"
      out=$out$sgr0$ret
    fi
    ret=$out$_ble_term_sgr0
  else
    # 高速化の為、直接 _ble_color_g2sgr を参照する
    local sgr0 sgr1
    ret=${_ble_color_g2sgr[g]}
    [[ $ret ]] || ble-color-g2sgr "$g"; sgr0=$ret
    ret=${_ble_color_g2sgr[g1=g|_ble_color_gflags_Revert]}
    [[ $ret ]] || ble-color-g2sgr "$g1"; sgr1=$ret

    ble-edit/info/.construct-text "$show"
    ret=$sgr0$ret$_ble_term_sgr0
  fi
}

## 関数 ble-complete/menu/style:$menu_style/construct
##   候補一覧メニューの表示・配置を計算します。
##
##   @var[out] x y esc
##   @arr[out] menu_items
##   @var[in] manu_style
##   @arr[in] cand_pack
##   @var[in] cols lines menu_common_part
##

## 関数 ble-complete/menu/style:align/construct
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble-complete/menu/style:align/construct {
  local ret iloop=0

  # 初めに各候補の幅を計算する
  local measure; measure=()
  local max_wcell=$bleopt_complete_menu_align max_width=1
  ((max_wcell<=0?(max_wcell=20):(max_wcell<2&&(max_wcell=2))))
  local pack w esc1 nchar_max=$((cols*lines)) nchar=0
  for pack in "${cand_pack[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    x=0 y=0; ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
    ((w=y*cols+x))

    ble/array#push measure "$w:${#pack}:$pack$esc1"

    if ((w++,max_width<w)); then
      ((max_width<max_wcell)) &&
        ((nchar+=(iloop-1)*((max_wcell<w?max_wcell:w)-max_width)))
      ((w>max_wcell)) && 
        ((w=(w+max_wcell-1)/max_wcell*max_wcell))
      ((max_width=w))
    fi

    # 画面に入る可能性がある所までで止める
    (((nchar+=w)>=nchar_max)) && break
  done

  local wcell=$((max_width<max_wcell?max_width:max_wcell))
  ((wcell=cols/(cols/wcell)))
  local ncell=$((cols/wcell))

  x=0 y=0 esc=
  menu_items=()
  local i=0 N=${#measure[@]}
  local entry index w s pack esc1
  local x0 y0
  local icell pad
  for entry in "${measure[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    w=${entry%%:*} entry=${entry#*:}
    s=${entry%%:*} entry=${entry#*:}
    pack=${entry::s} esc1=${entry:s}

    ((x0=x,y0=y))
    if ((x==0||x+w<cols)); then
      ((x+=w%cols,y+=w/cols))
      ((y>=lines&&(x=x0,y=y0,1))) && break
    else
      if [[ $menu_style == align-nowrap ]]; then
        esc=$esc$'\n'
        ((x0=x=0,y0=++y,y>=lines)) && break
        ((x=w%cols,y+=w/cols))
        ((y>=lines&&(x=x0,y=y0,1))) && break
      else
        ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
        ((y>=lines&&(x=x0,y=y0,1))) && break
      fi
    fi

    ble/array#push menu_items "$x0,$y0,$x,$y,${#pack},${#esc1}:$pack$esc1"
    esc=$esc$esc1

    # 候補と候補の間の空白
    if ((++i<N)); then
      ((icell=x==0?0:(x+wcell)/wcell))
      if ((icell<ncell)); then
        # 次の升目
        ble/string#reserve-prototype $((pad=icell*wcell-x))
        esc=$esc${_ble_string_prototype::pad}
        ((x=icell*wcell))
      else
        # 次の行
        esc=$esc$'\n'
        ((x=0,++y>=lines)) && break
      fi
    fi
  done
}
function ble-complete/menu/style:align-nowrap/construct {
  ble-complete/menu/style:align/construct
}

## 関数 ble-complete/menu/style:dense/construct
##   complete_menu_style=align{,-nowrap} に対して候補を配置します。
function ble-complete/menu/style:dense/construct {
  local ret iloop=0

  x=0 y=0 esc= menu_items=()

  local pack i=0 N=${#cand_pack[@]}
  for pack in "${cand_pack[@]}"; do
    ((iloop++%bleopt_complete_stdin_frequency==0)) && ble-complete/check-cancel && return 148

    local x0=$x y0=$y esc1
    ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
    ((y>=lines&&(x=x0,y=y0,1))) && return

    if [[ $menu_style == dense-nowrap ]]; then
      if ((y>y0&&x>0)); then
        ((y=++y0,x=x0=0))
        esc=$esc$'\n'
        ble-complete/menu/construct-single-entry "$pack"; esc1=$ret
        ((y>=lines&&(x=x0,y=y0,1))) && return
      fi
    fi

    ble/array#push menu_items "$x0,$y0,$x,$y,${#pack},${#esc1}:$pack$esc1"
    esc=$esc$esc1

    # 候補と候補の間の空白
    if ((++i<N)); then
      if [[ $menu_style == nowrap ]] && ((x==0)); then
        : skip
      elif ((x+1<cols)); then
        esc=$esc' '
        ((x++))
      else
        esc=$esc$'\n'
        ((x=0,++y>=lines)) && break
      fi
    fi
  done
}
function ble-complete/menu/style:dense-nowrap/construct {
  ble-complete/menu/style:dense/construct
}

function bleopt/check:complete_menu_style {
  if ! ble/is-function "ble-complete/menu/style:$value/construct"; then
    echo "bleopt: Invalid value complete_menu_style='$value'. A function 'ble-complete/menu/style:$value/construct' is not defined." >&2
    return 1
  fi
}

function ble-complete/menu/clear {
  if [[ $_ble_complete_menu_active ]]; then
    _ble_complete_menu_active=
    ble-edit/info/immediate-clear
  fi
}

## 関数 ble-complete/menu/show opts
##   @param[in] opts
##
##   @var[in] comp_type
##   @var[in] COMP1 COMP2 COMPS COMPV comps_flags comps_fixed
##   @arr[in] cand_pack
##   @var[in] menu_common_part
##
function ble-complete/menu/show {
  local opts=$1

  # settings
  local menu_style=$bleopt_complete_menu_style
  local cols lines
  ble-edit/info/.initialize-size

  if ((${#cand_pack[@]})); then
    local x y esc menu_items
    ble/function#try ble-complete/menu/style:"$menu_style"/construct || return

    info_data=(store "$x" "$y" "$esc")
  else
    menu_items=()
    info_data=(raw $'\e[38;5;242m(no candidates)\e[m')
  fi

  ble-edit/info/immediate-show "${info_data[@]}"
  _ble_complete_menu_info_data=("${info_data[@]}")
  _ble_complete_menu_items=("${menu_items[@]}")
  if [[ :$opts: != *:filter:* ]]; then
    local beg=$COMP1 end=$_ble_edit_ind
    _ble_complete_menu_beg=$beg
    _ble_complete_menu_end=$end
    _ble_complete_menu_str=$_ble_edit_str
    _ble_complete_menu_selected=-1
    _ble_complete_menu_active=1
    _ble_complete_menu_common_part=$menu_common_part
    _ble_complete_menu_comp=("$COMP1" "$COMP2" "$COMPS" "$COMPV" "$comp_type" "$comps_flags" "$comps_fixed")
    _ble_complete_menu_pack=("${cand_pack[@]}")
    _ble_complete_menu_filter=${_ble_edit_str:beg:end-beg}
  fi
  return 0
}

function ble-complete/menu/redraw {
  if [[ $_ble_complete_menu_active ]]; then
    ble-edit/info/immediate-show "${_ble_complete_menu_info_data[@]}"
  fi
}

## ble-complete/menu/get-active-range [str [ind]]
##   @param[in,opt] str ind
##   @var[out] beg end
function ble-complete/menu/get-active-range {
  [[ $_ble_complete_menu_active ]] || return 1

  local str=${1-$_ble_edit_str} ind=${2-$_ble_edit_ind}
  local mbeg=$_ble_complete_menu_beg
  local mend=$_ble_complete_menu_end
  local left=${_ble_complete_menu_str::mend}
  local right=${_ble_complete_menu_str:mend}
  if [[ ${str::_ble_edit_ind} == "$left"* && ${str:_ble_edit_ind} == *"$right" ]]; then
    ((beg=mbeg,end=${#str}-${#right}))
    return 0
  else
    ble-complete/menu/clear
    return 1
  fi
}

#------------------------------------------------------------------------------
# 補完

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
    local ret; ble/string#common-prefix "$insert" "$original_text"
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
      elif ble-complete/string#common-suffix-prefix "$insert" "$right_text"; [[ $ret ]]; then
        # カーソルの右に末尾一致する場合に吸収
        ((insert_end+=${#ret}))
      fi
    fi

    # suffix の吸収
    if [[ $suffix ]]; then
      local right_text=${_ble_edit_str:insert_end}
      if ble/string#common-prefix "$suffix" "$right_text"; [[ $ret ]]; then
        ((insert_end+=${#ret}))
      elif ble-complete/string#common-suffix-prefix "$suffix" "$right_text"; [[ $ret ]]; then
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

_ble_complete_state=
function ble/widget/complete {
  local opts=$1
  ble-edit/content/clear-arg

  local state=$_ble_complete_state
  _ble_complete_state=start

  if [[ :$opts: == *:enter_menu:* ]]; then
    [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]] &&
      ble-complete/menu-complete/enter && return
  elif [[ $bleopt_complete_menu_complete && $_ble_complete_menu_active != auto ]]; then
    [[ $_ble_complete_menu_active && :$opts: != *:context=*:* ]] &&
      [[ $_ble_edit_str == "$_ble_complete_menu_str" ]] &&
      ble-complete/menu-complete/enter && return
    [[ $WIDGET == "$LASTWIDGET" && $state != complete ]] && opts=$opts:enter_menu
  fi

  # 文脈の決定
  local context; ble-complete/complete/determine-context-from-opts "$opts"

  # 補完源の生成
  local comp_text=$_ble_edit_str comp_index=$_ble_edit_ind
  local sources
  ble-complete/context:"$context"/generate-sources "$comp_text" "$comp_index" || return 1

  local COMP1 COMP2 COMPS COMPV comp_type=
  local comps_flags comps_fixed
  local comps_rex_ambiguous
  local cand_count
  local -a cand_cand cand_word cand_pack
  ble-complete/candidates/generate; local ext=$?
  if ((ext==148)); then
    return 148
  elif ((ext!=0)); then
    ble/widget/.bell
    ble-edit/info/clear
    return 1
  fi

  local ret
  ble-complete/candidates/determine-common-prefix; local insert=$ret suffix=
  local insert_beg=$COMP1 insert_end=$COMP2
  local insert_flags=
  [[ $insert == "$COMPS"* ]] || insert_flags=r

  if [[ :$opts: == *:enter_menu:* ]]; then
    local menu_common_part=$COMPV
    ble-complete/menu/show || return
    ble-complete/menu-complete/enter; local ext=$?
    ((ext==148)) && return 148
    ((ext)) && ble/widget/.bell
    return
  elif [[ :$opts: == *:show_menu:* ]]; then
    local menu_common_part=$COMPV
    ble-complete/menu/show
    return # exit status of ble-complete/menu/show
  fi

  if ((cand_count==1)); then
    # 一意確定の時
    local ACTION=${cand_pack[0]%%:*}
    if ble/is-function ble-complete/action:"$ACTION"/complete; then
      local "${_ble_complete_cand_varnames[@]}"
      ble-complete/cand/unpack "${cand_pack[0]}"
      ble-complete/action:"$ACTION"/complete
      (($?==148)) && return 148
    fi
  else
    # 候補が複数ある時
    insert_flags=${insert_flags}m
  fi

  if [[ $insert$suffix != "$COMPS" ]]; then
    ble/util/invoke-hook _ble_complete_insert_hook
    ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
  fi

  if [[ $insert_flags == *m* ]]; then
    # menu_common_part (メニュー強調文字列)
    #   もし insert が単純単語の場合には
    #   menu_common_part を挿入後の評価値とする。
    #   そうでなければ仕方がないので挿入前の値 COMPV とする。
    local menu_common_part=$COMPV
    local ret simple_flags simple_ibrace
    if ble-syntax:bash/simple-word/reconstruct-incomplete-word "$insert"; then
      ble-syntax:bash/simple-word/eval "$ret"
      menu_common_part=$ret
    fi
    ble-complete/menu/show || return
  elif [[ $insert_flags == *n* ]]; then
    ble/widget/complete show_menu || return
    _ble_complete_menu_active=auto
  else
    _ble_complete_state=complete
    ble-complete/menu/clear
  fi
  return 0
}

function ble/widget/complete-insert {
  local original=$1 insert=$2 suffix=$3
  [[ ${_ble_edit_str::_ble_edit_ind} == *"$original" ]] || return 1

  local insert_beg=$((_ble_edit_ind-${#original}))
  local insert_end=$_ble_edit_ind
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"
}

function ble/widget/menu-complete {
  local opts=$1
  ble/widget/complete enter_menu:$opts
}

#------------------------------------------------------------------------------
# menu-filter

function ble-complete/menu/filter-incrementally {
  if [[ $_ble_decode_keymap == emacs || $_ble_decode_keymap == vi_[ic]map ]]; then
    local str=$_ble_edit_str
  elif [[ $_ble_decode_keymap == auto_complete ]]; then
    local str=${_ble_edit_str::_ble_edit_ind}${_ble_edit_str:_ble_edit_mark}
  elif [[ $_ble_decode_keymap == menu_complete ]]; then
    return 0
  else
    return 1
  fi

  local beg end; ble-complete/menu/get-active-range "$str" "$_ble_edit_ind" || return 1
  local input=${str:beg:end-beg}
  [[ $input == "$_ble_complete_menu_filter" ]] && return 0

  local ret simple_flags simple_ibrace
  ble-syntax:bash/simple-word/reconstruct-incomplete-word "$input" || return 1
  [[ $simple_ibrace ]] && ((${simple_ibrace%%:*}>10#${_ble_complete_menu_comp[6]%%:*})) && return 1 # 別のブレース展開要素に入った時
  ble-syntax:bash/simple-word/eval "$ret"
  local COMPV=$ret

  local iloop=0 interval=$bleopt_complete_stdin_frequency

  local comp_type=
  local -a cand_pack; cand_pack=()
  local pack "${_ble_complete_cand_varnames[@]}"
  for pack in "${_ble_complete_menu_pack[@]}"; do
    ((iloop++%interval==0)) && ble-complete/check-cancel && return 148
    ble-complete/cand/unpack "$pack"
    [[ $CAND == "$COMPV"* ]] &&
      ble/array#push cand_pack "$pack"
  done

  if ((${#cand_pack[@]}==0)); then
    # 曖昧一致
    local ret; ble-complete/util/construct-ambiguous-regex "$COMPV"; local rex=^$ret
    for pack in "${_ble_complete_menu_pack[@]}"; do
      ((iloop++%interval==0)) && ble-complete/check-cancel && return 148
      ble-complete/cand/unpack "$pack"
      [[ $CAND =~ $rex ]] &&
        ble/array#push cand_pack "$pack"
    done
    ((${#cand_pack[@]})) && comp_type=${comp_type}a
  fi

  local menu_common_part=$COMPV
  ble-complete/menu/show filter || return
  _ble_complete_menu_filter=$input
  return 0
}

function ble-complete/menu-filter.idle {
  ble/util/idle.wait-user-input
  [[ $_ble_complete_menu_active ]] || return
  ble-complete/menu/filter-incrementally; local ext=$?
  ((ext==148)) && return 148
  ((ext)) && ble-complete/menu/clear
}

ble/function#try ble/util/idle.push-background ble-complete/menu-filter.idle

#------------------------------------------------------------------------------
#
# menu-complete
#

## メニュー補完では以下の変数を参照する
##
##   @var[in] _ble_complete_menu_beg
##   @var[in] _ble_complete_menu_end
##   @var[in] _ble_complete_menu_original
##   @var[in] _ble_complete_menu_selected
##   @var[in] _ble_complete_menu_common_part
##   @arr[in] _ble_complete_menu_items
##
## 更に以下の変数を使用する
##
##   @var[in,out] _ble_complete_menu_original=

_ble_complete_menu_original=

function ble-highlight-layer:region/mark:menu_complete/get-face {
  face=menu_complete
}

function ble-complete/menu-complete/select {
  local osel=$_ble_complete_menu_selected nsel=$1
  ((osel==nsel)) && return

  local infox infoy
  ble/canvas/panel#get-origin "$_ble_edit_info_panel" --prefix=info

  local -a DRAW_BUFF=()
  local x0=$_ble_canvas_x y0=$_ble_canvas_y
  if ((osel>=0)); then
    # 消去
    local entry=${_ble_complete_menu_items[osel]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "${fields[@]::2}"
    ble/canvas/put.draw "${text:fields[4]}"
    _ble_canvas_x=${fields[2]} _ble_canvas_y=$((infoy+fields[3]))
  fi

  local value=
  if ((nsel>=0)); then
    local entry=${_ble_complete_menu_items[nsel]}
    local fields text=${entry#*:}
    ble/string#split fields , "${entry%%:*}"

    local x=${fields[0]} y=${fields[1]}
    ble/canvas/panel#goto.draw "$_ble_edit_info_panel" "$x" "$y"

    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "${text::fields[4]}"
    value=$INSERT

    # construct reverted candidate
    local ret cols lines menu_common_part
    ble-edit/info/.initialize-size
    menu_common_part=$_ble_complete_menu_common_part
    ble-complete/menu/construct-single-entry - selected:use_vars
    ble/canvas/put.draw "$ret"
    _ble_canvas_x=$x _ble_canvas_y=$((infoy+y))

    _ble_complete_menu_selected=$nsel
  else
    _ble_complete_menu_selected=-1
    value=$_ble_complete_menu_original
  fi
  ble/canvas/goto.draw "$x0" "$y0"
  ble/canvas/bflush.draw

  ble-edit/content/replace "$_ble_complete_menu_beg" "$_ble_edit_ind" "$value"
  ((_ble_edit_ind=_ble_complete_menu_beg+${#value}))
}

#ToDo:mark_active menu_complete の着色の定義
function ble-complete/menu-complete/enter {
  [[ ${#_ble_complete_menu_items[@]} -ge 1 ]] || return 1

  local beg end; ble-complete/menu/get-active-range || return 1

  _ble_edit_mark=$beg
  _ble_edit_ind=$end
  local comps_fixed=${_ble_complete_menu_comp[6]}
  if [[ $comps_fixed ]]; then
    local comps_fixed_length=${comps_fixed%%:*}
    ((_ble_edit_mark+=comps_fixed_length))
  fi

  _ble_complete_menu_original=${_ble_edit_str:beg:end-beg}
  ble-complete/menu/redraw
  ble-complete/menu-complete/select 0

  _ble_edit_mark_active=menu_complete
  ble-decode/keymap/push menu_complete
  return 0
}

function ble/widget/menu_complete/forward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected+1))
  local ncand=${#_ble_complete_menu_items[@]}
  if ((nsel>=ncand)); then
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      nsel=0
    else
      ble/widget/.bell "menu-complete: no more candidates"
      return 1
    fi
  fi
  ble-complete/menu-complete/select "$nsel"
}
function ble/widget/menu_complete/backward {
  local opts=$1
  local nsel=$((_ble_complete_menu_selected-1))
  if ((nsel<0)); then
    local ncand=${#_ble_complete_menu_items[@]}
    if [[ :$opts: == *:cyclic:* ]] && ((ncand>=2)); then
      ((nsel=ncand-1))
    else
      ble/widget/.bell "menu-complete: no more candidates"
      return 1
    fi
  fi
  ble-complete/menu-complete/select "$nsel"
}
function ble/widget/menu_complete/forward-line {
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return
  local entry=${_ble_complete_menu_items[osel]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local i=$osel nsel=-1
  for entry in "${_ble_complete_menu_items[@]:osel+1}"; do
    ble/string#split fields , "${entry%%:*}"
    local x=${fields[0]} y=${fields[1]}
    ((y<=oy||y==oy+1&&x<=ox||nsel<0)) || break
    ((++i,y>oy&&(nsel=i)))
  done

  if ((nsel>=0)); then
    ble-complete/menu-complete/select "$nsel"
  else
    ble/widget/.bell 'menu-complete: no more candidates'
    return 1
  fi
}
function ble/widget/menu_complete/backward-line {
  local osel=$_ble_complete_menu_selected
  ((osel>=0)) || return
  local entry=${_ble_complete_menu_items[osel]}
  local fields; ble/string#split fields , "${entry%%:*}"
  local ox=${fields[0]} oy=${fields[1]}
  local i=-1 nsel=-1
  for entry in "${_ble_complete_menu_items[@]::osel}"; do
    ble/string#split fields , "${entry%%:*}"
    local x=${fields[0]} y=${fields[1]}
    ((y<oy-1||y==oy-1&&x<=ox||y<oy&&nsel<0)) || break
    ((++i,nsel=i))
  done

  if ((nsel>=0)); then
    ble-complete/menu-complete/select "$nsel"
  else
    ble/widget/.bell 'menu-complete: no more candidates'
    return 1
  fi
}

function ble/widget/menu_complete/exit {
  local opts=$1
  ble-decode/keymap/pop

  if ((_ble_complete_menu_selected>=0)); then
    # 置換情報を再構成
    local new=${_ble_edit_str:_ble_complete_menu_beg:_ble_edit_ind-_ble_complete_menu_beg}
    local old=$_ble_complete_menu_original
    local comp_text=${_ble_edit_str::_ble_complete_menu_beg}$old${_ble_edit_str:_ble_edit_ind}
    local insert_beg=$_ble_complete_menu_beg
    local insert_end=$((_ble_complete_menu_beg+${#old}))
    local insert=$new
    local insert_flags=

    # suffix の決定と挿入
    local suffix=
    if [[ :$opts: == *:complete:* ]]; then
      local pack=${_ble_complete_menu_pack[_ble_complete_menu_selected]}
      local ACTION=${pack%%:*}
      if ble/is-function ble-complete/action:"$ACTION"/complete; then
        # 補完文脈の復元
        local COMP1=${_ble_complete_menu_comp[0]}
        local COMP2=${_ble_complete_menu_comp[1]}
        local COMPS=${_ble_complete_menu_comp[2]}
        local COMPV=${_ble_complete_menu_comp[3]}
        local comp_type=${_ble_complete_menu_comp[4]}
        local comps_flags=${_ble_complete_menu_comp[5]}
        local comps_fixed=${_ble_complete_menu_comp[6]}

        # 補完候補のロード
        local "${_ble_complete_cand_varnames[@]}"
        ble-complete/cand/unpack "$pack"

        ble-complete/action:"$ACTION"/complete
        ble-complete/insert "$_ble_complete_menu_beg" "$_ble_edit_ind" "$insert" "$suffix"
      fi
    fi

    # 通知
    ble/util/invoke-hook _ble_complete_insert_hook
  fi

  ble-complete/menu/clear
  _ble_edit_mark_active=

}
function ble/widget/menu_complete/cancel {
  ble-decode/keymap/pop
  ble-complete/menu-complete/select -1
  _ble_edit_mark_active=
}
function ble/widget/menu_complete/exit-default {
  ble/widget/menu_complete/exit
  ble-decode-key "${KEYS[@]}"
}

function ble-decode/keymap:menu_complete/define {
  local ble_bind_keymap=menu_complete

  # ble-bind -f __defchar__ menu_complete/self-insert
  ble-bind -f __default__ 'menu_complete/exit-default'
  ble-bind -f C-m         'menu_complete/exit complete'
  ble-bind -f RET         'menu_complete/exit complete'
  ble-bind -f C-g         'menu_complete/cancel'
  ble-bind -f C-f         'menu_complete/forward'
  ble-bind -f right       'menu_complete/forward'
  ble-bind -f C-i         'menu_complete/forward cyclic'
  ble-bind -f TAB         'menu_complete/forward cyclic'
  ble-bind -f C-b         'menu_complete/backward'
  ble-bind -f left        'menu_complete/backward'
  ble-bind -f C-S-i       'menu_complete/backward cyclic'
  ble-bind -f S-TAB       'menu_complete/backward cyclic'
  ble-bind -f C-n         'menu_complete/forward-line'
  ble-bind -f down        'menu_complete/forward-line'
  ble-bind -f C-p         'menu_complete/backward-line'
  ble-bind -f up          'menu_complete/backward-line'
}

#------------------------------------------------------------------------------
#
# auto-complete
#

function ble-complete/auto-complete/initialize {
  local ret
  ble-decode-kbd/generate-keycode auto_complete_enter
  _ble_complete_KCODE_ENTER=$ret
}
ble-complete/auto-complete/initialize

function ble-highlight-layer:region/mark:auto_complete/get-face {
  face=auto_complete
}

_ble_complete_ac_type=
_ble_complete_ac_comp1=
_ble_complete_ac_cand=
_ble_complete_ac_word=
_ble_complete_ac_insert=
_ble_complete_ac_suffix=

## 関数 ble-complete/auto-complete/.search-history-light text
##   !string もしくは !?string を用いて履歴の検索を行います
##   @param[in] text
##   @var[out] ret
function ble-complete/auto-complete/.search-history-light {
  [[ $_ble_edit_history_prefix ]] && return 1

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
    local frag longest_fragments; len=0 longest_fragments=('')
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
function ble-complete/auto-complete/.search-history-heavy {
  local text=$1

  local count; ble-edit/history/get-count -v count
  local start=$((count-1))
  local index=$((count-1))
  local needle=$text

  # 途中からの検索再開
  ((start==_ble_complete_ac_history_start)) &&
    [[ $needle == "$_ble_complete_ac_history_needle"* ]] &&
    index=$_ble_complete_ac_history_index

  local isearch_time=0 isearch_ntask=1
  local isearch_opts=head
  [[ $comp_type == *s* ]] || isearch_opts=$isearch_opts:stop_check
  ble-edit/isearch/backward-search-history-blockwise "$isearch_opts"; local ext=$?
  _ble_complete_ac_history_start=$start
  _ble_complete_ac_history_index=$index
  _ble_complete_ac_history_needle=$needle
  ((ext)) && return "$ext"

  ble-edit/history/get-editted-entry -v ret "$index"
  return 0
}

## 関数 ble-complete/auto-complete/.setup-auto-complete-mode
##   @var[in] type COMP1 cand word insert suffix
function ble-complete/auto-complete/.setup-auto-complete-mode {
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

## 関数 ble-complete/auto-complete/.check-history opts
##   @param[in] opts
##   @var[in] comp_type comp_text comp_index
function ble-complete/auto-complete/.check-history {
  local opts=$1
  local searcher=.search-history-heavy
  [[ :$opts: == *:light:*  ]] && searcher=.search-history-light

  local ret
  ((_ble_edit_ind==${#_ble_edit_str})) || return 1
  ble-complete/auto-complete/"$searcher" "$_ble_edit_str" || return # 0, 1 or 148
  local word=$ret cand=
  local COMP1=0 COMPS=$_ble_edit_str
  [[ $word == "$COMPS" ]] && return 1
  local insert=$word suffix=

  local type=h
  local ins=${insert:${#COMPS}}
  ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
  ((_ble_edit_mark=_ble_edit_ind+${#ins}))

  # vars: type COMP1 cand word insert suffix
  ble-complete/auto-complete/.setup-auto-complete-mode
  return 0
}

## 関数 ble-complete/auto-complete/.check-context
##   @var[in] comp_type comp_text comp_index
function ble-complete/auto-complete/.check-context {
  local sources
  ble-complete/context:syntax/generate-sources "$comp_text" "$comp_index" &&
    ble-complete/context/filter-prefix-sources || return 1

  # ble-complete/candidates/generate 設定
  local bleopt_complete_contract_function_names=
  ((bleopt_complete_stdin_frequency>25)) &&
    local bleopt_complete_stdin_frequency=25
  local COMP1 COMP2 COMPS COMPV
  local comps_flags comps_fixed
  local comps_rex_ambiguous
  local cand_count
  local -a cand_cand cand_word cand_pack
  ble-complete/candidates/generate; local ext=$?
  [[ $COMPV ]] || return 1
  ((ext)) && return "$ext"

  ((cand_count)) || return

  local word=${cand_word[0]} cand=${cand_cand[0]}
  [[ $word == "$COMPS" ]] && return 1

  # addtail 等の修飾
  local insert=$word suffix=
  local ACTION=${cand_pack[0]%%:*}
  if ble/is-function ble-complete/action:"$ACTION"/complete; then
    local "${_ble_complete_cand_varnames[@]}"
    ble-complete/cand/unpack "${cand_pack[0]}"
    ble-complete/action:"$ACTION"/complete
  fi

  local type=
  if [[ $word == "$COMPS"* ]]; then
    # 入力候補が既に続きに入力されている時は提示しない
    [[ ${comp_text:COMP1} == "$word"* ]] && return 1

    type=c
    local ins=${insert:${#COMPS}}
    ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
    ((_ble_edit_mark=_ble_edit_ind+${#ins}))
  else
    if [[ $comp_type == *a* ]]; then
      type=a
    else
      type=r
    fi
    ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" " [$insert] "
    ((_ble_edit_mark=_ble_edit_ind+4+${#insert}))
  fi

  # vars: type COMP1 cand word insert suffix
  ble-complete/auto-complete/.setup-auto-complete-mode
  return 0
}

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

  if [[ $bleopt_complete_auto_history ]]; then
    ble-complete/auto-complete/.check-history light; local ext=$?
    ((ext==0||ext==148)) && return "$ext"

    [[ $_ble_edit_history_prefix || $_ble_edit_history_loaded ]] &&
      ble-complete/auto-complete/.check-history; local ext=$?
    ((ext==0||ext==148)) && return "$ext"
  fi
  
  ble-complete/auto-complete/.check-context
}

## 背景関数 ble/widget/auto-complete.idle
function ble-complete/auto-complete.idle {
  # ※特に上書きしなければ常に wait-user-input で抜ける。
  ble/util/idle.wait-user-input

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
  ble/util/invoke-hook _ble_complete_insert_hook
  ble-complete/insert "$insert_beg" "$insert_end" "$insert" "$suffix"

  _ble_edit_mark_active=
  _ble_complete_ac_insert=
  _ble_complete_ac_suffix=
  ble-complete/menu/clear
  ble-edit/content/clear-arg
}
function ble/widget/auto_complete/cancel-default {
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
  elif [[ $_ble_complete_ac_type == [ra] && $ins != [{,}] ]]; then
    if local ret simple_flags simple_ibrace; ble-syntax:bash/simple-word/reconstruct-incomplete-word "$comps_new"; then
      ble-syntax:bash/simple-word/eval "$ret"; local compv_new=$ret
      if [[ $_ble_complete_ac_type == r ]]; then
        # r: 遡って書き換わる時
        #   挿入しても展開後に一致する時、そのまま挿入。
        #   元から展開後に一致していない場合もあるが、その場合は一旦候補を消してやり直し。
        if [[ $_ble_complete_ac_cand == "$compv_new"* ]]; then
          ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          [[ $_ble_complete_ac_cand == "$compv_new" ]] &&
            ble/widget/auto_complete/cancel
          processed=1
        fi
      elif [[ $_ble_complete_ac_type == a ]]; then
        # a: 曖昧一致の時
        #   文字を挿入後に展開してそれが曖昧一致する時、そのまま挿入。
        ble-complete/util/construct-ambiguous-regex "$compv_new"
        local comps_rex_ambiguous=^$ret
        if [[ $_ble_complete_ac_cand =~ $comps_rex_ambiguous ]]; then
          ble-edit/content/replace "$_ble_edit_ind" "$_ble_edit_ind" "$ins"
          ((_ble_edit_ind+=${#ins},_ble_edit_mark+=${#ins}))
          processed=1
        fi
      fi
    fi
  fi

  if [[ $processed ]]; then
    # notify dummy insertion
    local comp_text= insert_beg=0 insert_end=0 insert=$ins suffix=
    ble/util/invoke-hook _ble_complete_insert_hook
    return 0
  else
    ble/widget/auto_complete/cancel
    ble-decode-key "${KEYS[@]}"
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
  local rex='^['$_ble_term_IFS']*([^'$_ble_term_IFS']+['$_ble_term_IFS']*)?'
  if [[ $_ble_complete_ac_type == [ch] ]]; then
    local ins=${_ble_edit_str:_ble_edit_ind:_ble_edit_mark-_ble_edit_ind}
    [[ $ins =~ $rex ]]
    if [[ $BASH_REMATCH == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return
    else
      local ins=$BASH_REMATCH

      # 通知
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=${_ble_edit_str:insert_beg:insert_end-insert_beg}$ins
      local suffix=
      ble/util/invoke-hook _ble_complete_insert_hook

      # Note: 以下の様に _ble_edit_ind だけずらす。
      #   <C>he<I>llo world<M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      ((_ble_edit_ind+=${#ins}))
      return 0
    fi
  elif [[ $_ble_complete_ac_type == [ra] ]]; then
    local ins=$_ble_complete_ac_insert
    [[ $ins =~ $rex ]]
    if [[ $BASH_REMATCH == "$ins" ]]; then
      ble/widget/auto_complete/insert
      return
    else
      local ins=$BASH_REMATCH

      # 通知
      local comp_text=$_ble_edit_str
      local insert_beg=$_ble_complete_ac_comp1
      local insert_end=$_ble_edit_ind
      local insert=$ins
      local suffix=
      ble/util/invoke-hook _ble_complete_insert_hook

      # Note: 以下の様に内容を書き換える。
      #   <C>hll<I> [hello world] <M> → <C>hello <I>world<M>
      #   (<C> = comp1, <I> = _ble_edit_ind, <M> = _ble_edit_mark)
      _ble_complete_ac_type=c
      ble-edit/content/replace "$_ble_complete_ac_comp1" "$_ble_edit_mark" "$_ble_complete_ac_insert"
      ((_ble_edit_ind=_ble_complete_ac_comp1+${#ins},
        _ble_edit_mark=_ble_complete_ac_comp1+${#_ble_complete_ac_insert}))
      return 0
    fi
  fi
  return 1
}
function ble/widget/auto_complete/accept-line {
  ble/widget/auto_complete/insert
  ble-decode-key 13
}

function ble-decode/keymap:auto_complete/define {
  local ble_bind_keymap=auto_complete

  ble-bind -f __defchar__ auto_complete/self-insert
  ble-bind -f __default__ auto_complete/cancel-default
  ble-bind -f C-g         auto_complete/cancel
  ble-bind -f S-RET       auto_complete/insert
  ble-bind -f S-C-m       auto_complete/insert
  ble-bind -f C-f         auto_complete/insert-on-end
  ble-bind -f right       auto_complete/insert-on-end
  ble-bind -f M-f         auto_complete/insert-word
  ble-bind -f M-right     auto_complete/insert-word
  ble-bind -f C-j         auto_complete/accept-line
  ble-bind -f C-RET       auto_complete/accept-line
  ble-bind -f auto_complete_enter nop
}

#------------------------------------------------------------------------------
#
# sabbrev
#

## 関数 ble-complete/sabbrev/register key value
##   静的略語展開を登録します。
##   @param[in] key value
##
## 関数 ble-complete/sabbrev/list
##   登録されている静的略語展開の一覧を表示します。
##
## 関数 ble-complete/sabbrev/get key
##   静的略語展開の展開値を取得します。
##   @param[in] key
##   @var[out] ret
##
if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  function ble-complete/sabbrev/register {
    local key=$1 value=$2
    _ble_complete_sabbrev[$key]=$value
  }
  function ble-complete/sabbrev/list {
    local key q=\' Q="'\''"
    for key in "${!_ble_complete_sabbrev[@]}"; do
      local value=${_ble_complete_sabbrev[$key]}
      printf 'ble-sabbrev %s=%s\n' "$key" "'${value//$q/$Q}'"
    done
  }
  function ble-complete/sabbrev/get {
    local key=$1
    ret=${_ble_complete_sabbrev[$key]}
    [[ $ret ]]
  }
else
  _ble_complete_sabbrev_keys=()
  _ble_complete_sabbrev_values=()
  function ble-complete/sabbrev/register {
    local key=$1 value=$2 i=0
    for key2 in "${_ble_complete_sabbrev_keys[@]}"; do
      [[ $key2 == "$key" ]] && break
      ((i++))
    done
    _ble_complete_sabbrev_keys[i]=$key
    _ble_complete_sabbrev_values[i]=$value
  }
  function ble-complete/sabbrev/list {
    local i N=${#_ble_complete_sabbrev_keys[@]} q=\' Q="'\''"
    for ((i=0;i<N;i++)); do
      local key=${_ble_complete_sabbrev_keys[i]}
      local value=${_ble_complete_sabbrev_values[i]}
      printf 'ble-sabbrev %s=%s\n' "$key" "'${value//$q/$Q}'"
    done
  }
  function ble-complete/sabbrev/get {
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
fi

## 関数 ble-sabbrev key=value
##   静的略語展開を登録します。
function ble-sabbrev {
  if (($#)); then
    local spec key value
    for spec; do
      key=${spec%%=*} value=${spec#*=}
      ble-complete/sabbrev/register "$key" "$value"
    done
  else
    ble-complete/sabbrev/list
  fi
}

function ble-complete/sabbrev/expand {
  local sources comp_index=$_ble_edit_ind comp_text=$_ble_edit_str
  ble-complete/context:syntax/generate-sources
  local src asrc pos=$comp_index
  for src in "${sources[@]}"; do
    ble/string#split-words asrc "$src"
    case ${asrc[0]} in
    (file|command|argument|variable:w)
      ((asrc[1]<pos)) && pos=${asrc[1]} ;;
    esac
  done

  ((pos<comp_index)) || return 1

  local key=${_ble_edit_str:pos:comp_index-pos}
  local ret; ble-complete/sabbrev/get "$key" || return 1

  ble/widget/.replace-range "$pos" "$comp_index" "$ret"
  ((_ble_edit_ind=pos+${#ret}))
  return 0
}
function ble/widget/sabbrev-expand {
  if ! ble-complete/sabbrev/expand; then
    ble/widget/.bell
    return 1
  fi
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

function ble-complete/dabbrev/.show-status.fib {
  local index='!'$((_ble_complete_dabbrev_index+1))
  local nmatch=${#_ble_complete_dabbrev_stack[@]}
  local needle=$_ble_complete_dabbrev_original
  local text="(dabbrev#$nmatch: << $index) \`$needle'"

  local pos=$1
  if [[ $pos ]]; then
    local count; ble-edit/history/get-count
    local percentage=$((count?pos*1000/count:1000))
    text="$text searching... @$pos ($((percentage/10)).$((percentage%10))%)"
  fi

  ((fib_ntask)) && text="$text *$fib_ntask"

  ble-edit/info/show text "$text"
}
function ble-complete/dabbrev/show-status {
  local fib_ntask=${#_ble_util_fiberchain[@]}
  ble-complete/dabbrev/.show-status.fib
}
function ble-complete/dabbrev/erase-status {
  ble-edit/info/default
}

## 関数 ble-complete/dabbrev/initialize-variables
function ble-complete/dabbrev/initialize-variables {
  # Note: _ble_term_IFS を前置しているので ! や ^ が先頭に来ない事は保証される
  local wordbreaks=$_ble_term_IFS$COMP_WORDBREAKS
  [[ $wordbreaks == *'('* ]] && wordbreaks=${wordbreaks//['()']}'()'
  [[ $wordbreaks == *']'* ]] && wordbreaks=']'${wordbreaks//']'}
  [[ $wordbreaks == *'-'* ]] && wordbreaks=${wordbreaks//'-'}'-'
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

  local index; ble-edit/history/get-index
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=${#_ble_edit_str}

  _ble_complete_dabbrev_stack=()
}

function ble-complete/dabbrev/reset {
  local original=$_ble_complete_dabbrev_original
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" "$original"
  ((_ble_edit_ind=_ble_edit_mark+${#original}))
  _ble_edit_mark_active=
}

## 関数 ble-complete/dabbrev/search-in-history-entry line index
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
function ble-complete/dabbrev/search-in-history-entry {
  local line=$1 index=$2

  # 現在編集している行自身には一致させない。
  local index_editing; ble-edit/history/get-index -v index_editing
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

function ble-complete/dabbrev/.search.fib {
  if [[ ! $fib_suspend ]]; then
    local start=$_ble_complete_dabbrev_index
    local index=$_ble_complete_dabbrev_index
    local pos=$_ble_complete_dabbrev_pos

    # Note: start は最初に backward-history-search が呼ばれる時の index。
    #   backward-history-search が呼び出される前に index-- されるので、
    #   start は最初から 1 減らして定義しておく。
    #   これにより cyclic 検索で再度自分に一致する事が保証される。
    # Note: start がこれで負になった時は "履歴項目の数" を設定する。
    #   未だ "履歴" に登録されていない最新の項目 (_ble_edit_history_edit
    #   には格納されている) も検索の対象とするため。
    ((--start>=0)) || ble-edit/history/get-count -v start
  else
    local start index pos; eval "$fib_suspend"
    fib_suspend=
  fi

  local dabbrev_match=
  local dabbrev_pos=$pos
  local dabbrev_current_match=${_ble_edit_str:_ble_edit_mark:_ble_edit_ind-_ble_edit_mark}

  local line; ble-edit/history/get-editted-entry -v line "$index"
  if ! ble-complete/dabbrev/search-in-history-entry "$line" "$index"; then
    ((index--,dabbrev_pos=0))

    local isearch_time=0
    local isearch_opts=stop_check:cyclic

    # 条件による一致判定の設定
    isearch_opts=$isearch_opts:condition
    local dabbrev_original=$_ble_complete_dabbrev_original
    local dabbrev_regex1=$_ble_complete_dabbrev_regex1
    local needle='[[ $LINE =~ $dabbrev_regex1 ]] && ble-complete/dabbrev/search-in-history-entry "$LINE" "$INDEX"'
    # Note: glob で先に枝刈りした方が速い。
    [[ $dabbrev_original ]] && needle='[[ $LINE == *"$dabbrev_original"* ]] && '$needle

    # 検索進捗の表示
    isearch_opts=$isearch_opts:progress
    local isearch_progress_callback=ble-complete/dabbrev/.show-status.fib

    ble-edit/isearch/backward-search-history-blockwise "$isearch_opts"; local ext=$?
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
  ble-edit/content/replace "$_ble_edit_mark" "$_ble_edit_ind" "$dabbrev_match"
  ((_ble_edit_ind=_ble_edit_mark+${#dabbrev_match}))

  ((index>_ble_complete_dabbrev_index)) &&
    ble/widget/.bell # 周回
  _ble_complete_dabbrev_index=$index
  _ble_complete_dabbrev_pos=$dabbrev_match_pos

  ble/textarea#redraw
}
function ble-complete/dabbrev/next.fib {
  ble-complete/dabbrev/.search.fib; local ext=$?
  if ((ext==0)); then
    _ble_edit_mark_active=menu_complete
    ble-complete/dabbrev/.show-status.fib
  elif ((ext==148)); then
    ble-complete/dabbrev/.show-status.fib
  else
    ble/widget/.bell
    ble/widget/dabbrev/exit
    ble-complete/dabbrev/reset
    fib_kill=1
  fi
  return "$ext"
}
function ble/widget/dabbrev-expand {
  ble-complete/dabbrev/initialize-variables
  ble-decode/keymap/push dabbrev
  ble/util/fiberchain#initialize ble-complete/dabbrev
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
      ble-complete/dabbrev/show-status
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
    ble-complete/dabbrev/show-status
  else
    ble/widget/.bell
    return 1
  fi
}
function ble/widget/dabbrev/cancel {
  if ((${#_ble_util_fiberchain[@]})); then
    ble/util/fiberchain#clear
    ble-complete/dabbrev/show-status
  else
    ble/widget/dabbrev/exit
    ble-complete/dabbrev/reset
  fi
}
function ble/widget/dabbrev/exit {
  ble-decode/keymap/pop
  _ble_edit_mark_active=
  ble-complete/dabbrev/erase-status
}
function ble/widget/dabbrev/exit-default {
  ble/widget/dabbrev/exit
  ble-decode-key "${KEYS[@]}"
}
function ble/widget/dabbrev/accept-line {
  ble/widget/dabbrev/exit
  ble-decode-key 13
}
function ble-decode/keymap:dabbrev/define {
  local ble_bind_keymap=dabbrev
  ble-bind -f __default__ 'dabbrev/exit-default'
  ble-bind -f C-g         'dabbrev/cancel'
  ble-bind -f C-r         'dabbrev/next'
  ble-bind -f C-s         'dabbrev/prev'
  ble-bind -f RET         'dabbrev/exit'
  ble-bind -f C-m         'dabbrev/exit'
  ble-bind -f C-RET       'dabbrev/accept-line'
  ble-bind -f C-j         'dabbrev/accept-line'
}

#------------------------------------------------------------------------------
# default cmdinfo/complete

function ble/cmdinfo/complete:cd/.impl {
  local type=$1
  [[ $comps_flags == *v* ]] || return 1

  if [[ $COMPV == -* ]]; then
    local action=word
    case $type in
    (pushd)
      if [[ $COMPV == - || $COMPV == -n ]]; then
        ble-complete/cand/yield "$action" -n
      fi ;;
    (*)
      COMP_PREFIX=$COMPV
      local -a list=()
      [[ $COMPV == -* ]] && ble-complete/cand/yield "$action" "${COMPV}"
      [[ $COMPV != *L* ]] && ble-complete/cand/yield "$action" "${COMPV}L"
      [[ $COMPV != *P* ]] && ble-complete/cand/yield "$action" "${COMPV}P"
      ((_ble_bash>=40200)) && [[ $COMPV != *e* ]] && ble-complete/cand/yield "$action" "${COMPV}e"
      ((_ble_bash>=40300)) && [[ $COMPV != *@* ]] && ble-complete/cand/yield "$action" "${COMPV}@" ;;
    esac
    return
  fi

  [[ $COMPV =~ ^.+/ ]] && COMP_PREFIX=${BASH_REMATCH[0]}

  ble-complete/source:dir

  if [[ $CDPATH ]]; then
    local names; ble/string#split names : "$CDPATH"
    local name
    for name in "${names[@]}"; do
      [[ $name ]] || continue
      name=${name%/}/

      local ret cand
      ble-complete/source:file/.construct-pathname-pattern "$COMPV"
      ble-complete/util/eval-pathname-expansion "$name/$ret"
      for cand in "${ret[@]}"; do
        [[ $cand && -d $cand ]] || continue
        [[ $cand == / ]] || cand=${cand%/}
        cand=${cand#"$name"/}
        [[ $FIGNORE ]] && ! ble-complete/.fignore/filter "$cand" && continue
        ble-complete/cand/yield file "$cand"
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

ble/util/invoke-hook _ble_complete_load_hook
