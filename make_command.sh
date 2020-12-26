#!/usr/bin/env bash

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

function ble/array#push {
  while (($#>=2)); do
    builtin eval "$1[\${#$1[@]}]=\$2"
    set -- "$1" "${@:3}"
  done
}

#------------------------------------------------------------------------------

function sub:help {
  printf '%s\n' \
         'usage: make_command.sh SUBCOMMAND args...' \
         '' 'SUBCOMMAND' ''
  local sub
  for sub in $(declare -F | sed -n 's|^declare -[fx]* sub:\([^/]*\)$|\1|p'); do
    if declare -f sub:"$sub"/help &>/dev/null; then
      sub:"$sub"/help
    else
      printf '  %s\n' "$sub"
    fi
  done
  printf '\n'
}

function sub:install {
  # read options
  local flag_error= flag_release=
  while [[ $1 == -* ]]; do
    local arg=$1; shift
    case $arg in
    (--release) flag_release=1 ;;
    (*) echo "install: unknown option $arg" >&2
        flag_error=1 ;;
    esac
  done
  [[ $flag_error ]] && return 1

  local src=$1
  local dst=$2
  mkd "${dst%/*}"
  if [[ $src == *.sh ]]; then
    local nl=$'\n' q=\' script=$'1i\\\n# this script is a part of blesh (https://github.com/akinomyoga/ble.sh) under BSD-3-Clause license'
    script=$script$nl'/^[[:space:]]*#/d;/^[[:space:]]*$/d'
    [[ $flag_release ]] &&
      script=$script$nl's/^\([[:space:]]*_ble_base_repository=\)'$q'.*'$q'\([[:space:]]*\)$/\1'${q}release:$dist_git_branch$q'/'
    sed "$script" "$src" >| "$dst.part" && mv "$dst.part" "$dst"
  else
    cp "$src" "$dst"
  fi
}
function sub:install/help {
  printf '  install src dst\n'
}

function sub:dist {
  local dist_git_branch=$(git rev-parse --abbrev-ref HEAD)
  local tmpdir=ble-$FULLVER
  local src
  for src in "$@"; do
    local dst=$tmpdir${src#out}
    sub:install --release "$src" "$dst"
  done
  [[ -d dist ]] || mkdir -p dist
  tar caf "dist/$tmpdir.$(date +'%Y%m%d').tar.xz" "$tmpdir" && rm -r "$tmpdir"
}

function sub:ignoreeof-messages {
  (
    cd ~/local/build/bash-4.3/po
    sed -nr '/msgid "Use \\"%s\\" to leave the shell\.\\n"/{n;s/^[[:space:]]*msgstr "(.*)"[^"]*$/\1/p;}' *.po | while builtin read -r line || [[ $line ]]; do
      [[ $line ]] || continue
      echo $(printf "$line" exit) # $() は末端の改行を削除するため
    done
  ) >| lib/core-edit.ignoreeof-messages.new
}

#------------------------------------------------------------------------------
# sub:check
# sub:check-all

function sub:check {
  bash out/ble.sh --test
}
function sub:check-all {
  local -x _ble_make_command_check_count=0
  local bash rex_version='^bash-([0-9]+)\.([0-9]+)$'
  for bash in $(compgen -c -- bash- | grep -E '^bash-[0-9]+\.[0-9]+$' | sort -Vr); do
    [[ $bash =~ $rex_version && ${BASH_REMATCH[1]} -ge 3 ]] || continue
    "$bash" out/ble.sh --test || return 1
    ((_ble_make_command_check_count++))
  done
}

#------------------------------------------------------------------------------
# sub:scan

function sub:scan/grc-source {
  local -a options=(--color --exclude=./{test,memo,ext,wiki,contrib,[TD]????.*} --exclude=\*.{md,awk} --exclude=./make_command.sh)
  grc "${options[@]}" "$@"
}
function sub:scan/list-command {
  local -a options=(--color --exclude=./{test,memo,ext,wiki,contrib,[TD]????.*} --exclude=\*.{md,awk})

  # read arguments
  local flag_exclude_this= flag_error=
  local command=
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--exclude-this)
      flag_exclude_this=1 ;;
    (--exclude=*)
      ble/array#push options "$arg" ;;
    (--)
      [[ $1 ]] && command=$1
      break ;;
    (-*)
      echo "check: unknown option '$arg'" >&2
      flag_error=1 ;;
    (*)
      command=$arg ;;
    esac
  done
  if [[ ! $command ]]; then
    echo "check: command name is not specified." >&2
    flag_error=1
  fi
  [[ $flag_error ]] && return 1

  [[ $flag_exclude_this ]] && ble/array#push options --exclude=./make_command.sh
  grc "${options[@]}" "(^|[^-./\${}=])\b$command"'\b([[:space:]|&;<>()`"'\'']|$)'
}

function sub:scan/builtin {
  echo "--- $FUNCNAME $1 ---"
  local command=$1 esc='(\[[ -?]*[@-~])*'
  sub:scan/list-command --exclude-this --exclude={generate-release-note.sh,lib/test-*.sh} "$command" "${@:2}" |
    grep -Ev "$rex_grep_head([[:space:]]*|[[:alnum:][:space:]]*[[:space:]])#|(\b|$esc)(builtin|function)$esc([[:space:]]$esc)+$command(\b|$esc)" |
    grep -Ev "$command(\b|$esc)=" |
    grep -Ev "ble\.sh $esc\($esc$command$esc\)$esc" |
    sed -E 'h;s/'"$esc"'//g;\Z(\.awk|push|load|==) \b'"$command"'\bZd;g' 
}

function sub:scan/check-todo-mark {
  echo "--- $FUNCNAME ---"
  grc --color --exclude=./make_command.sh '@@@'
}
function sub:scan/a.txt {
  echo "--- $FUNCNAME ---"
  grc --color --exclude=./test --exclude=./lib/test-*.sh --exclude=./make_command.sh --exclude=\*.md 'a\.txt|/dev/(pts/|pty)[0-9]*' |
    grep -Ev "$rex_grep_head#|[[:space:]]#"
}

function sub:scan/bash300bug {
  echo "--- $FUNCNAME ---"
  # bash-3.0 では local arr=(1 2 3) とすると
  # local arr='(1 2 3)' と解釈されてしまう。
  grc 'local [a-zA-Z_]+=\(' --exclude=./test --exclude=./make_command.sh --exclude=ChangeLog.md

  # bash-3.0 では local -a arr=("$hello") とすると
  # クォートしているにも拘らず $hello の中身が単語分割されてしまう。
  grc 'local -a [[:alnum:]_]+=\([^)]*[\"'\''`]' --exclude=./test --exclude=./make_command.sh
}

function sub:scan/bash301bug-array-element-length {
  echo "--- $FUNCNAME ---"
  # bash-3.1 で ${#arr[index]} を用いると、
  # 日本語の文字数が変になる。
  grc '\$\{#[[:alnum:]]+\[[^@*]' --exclude={test,ChangeLog.md} | grep -Ev '^([^#]*[[:space:]])?#'
}

function sub:scan/assign {
  echo "--- $FUNCNAME ---"
  local command="$1"
  grc --color --exclude=./test --exclude=./memo '\$\([^()]' |
    grep -Ev "$rex_grep_head#|[[:space:]]#"
}

function sub:scan/memo-numbering {
  echo "--- $FUNCNAME ---"

  grep -ao '\[#D....\]' note.txt memo/done.txt | awk '
    function report_error(message) {
      printf("memo-numbering: \x1b[1;31m%s\x1b[m\n", message) > "/dev/stderr";
    }
    !/\[#D[0-9]{4}\]/ {
      report_error("invalid  number \"" $0 "\".");
      next;
    }
    {
      num = $0;
      gsub(/^\[#D0+|\]$/, "", num);
      if (prev != "" && num != prev - 1) {
        if (prev < num) {
          report_error("reverse ordering " num " has come after " prev ".");
        } else if (prev == num) {
          report_error("duplicate number " num ".");
        } else {
          for (i = prev - 1; i > num; i--) {
            report_error("memo-numbering: missing number " i ".");
          }
        }
      }
      prev = num;
    }
    END {
      if (prev != 1) {
        for (i = prev - 1; i >= 1; i--)
          report_error("memo-numbering: missing number " i ".");
      }
    }
  '
  cat note.txt memo/done.txt | sed -n '0,/^[[:space:]]\{1,\}Done/d;/  \* .*\[#D....\]$/d;/^  \* /p'
}

# 誤って ((${#arr[@]})) を ((${arr[@]})) などと書いてしまうミス。
function sub:scan/array-count-in-arithmetic-expression {
  echo "--- $FUNCNAME ---"
  grc --exclude=./make_command.sh '\(\([^[:space:]]*\$\{[[:alnum:]_]+\[[@*]\]\}'
}

# unset 変数名 としていると誤って関数が消えることがある。
function sub:scan/unset-variable {
  echo "--- $FUNCNAME ---"
  local esc='(\[[ -?]*[@-~])*'
  sub:scan/list-command unset --exclude-this |
    grep -Ev "unset$esc[[:space:]]$esc-[vf]|$rex_grep_head[[:space:]]*#"
}
function sub:scan/eval-literal {
  echo "--- $FUNCNAME ---"
  local esc='(\[[ -?]*[@-~])*'
  sub:scan/grc-source 'builtin eval "\$' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zeval "(\$[[:alnum:]_]+)+(\[[^]["'\''\$`]+\])?\+?=Zd
      g'
}

function sub:scan {
  if ! type grc >/dev/null; then
    echo 'blesh check: grc not found. grc can be found in github.com:akinomyoga/mshex.git/' >&2
    exit
  fi

  local esc='(\[[ -?]*[@-~])*'
  local rex_grep_head="^$esc[[:graph:]]+$esc:$esc[[:digit:]]*$esc:$esc"

  # builtin return break continue : eval echo unset は unset しているので大丈夫のはず

  #sub:scan/builtin 'history'
  sub:scan/builtin 'echo' --exclude=./keymap/vi_test.sh --exclude=./ble.pp |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Z\bstty[[:space:]]+echoZd
      \Zecho \$PPIDZd
      g'
  #sub:scan/builtin '(compopt|type|printf)'
  sub:scan/builtin 'bind' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zinvalid bind typeZd
      \Zline = "bind"Zd
      g'
  sub:scan/builtin 'read' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \ZDo not read Zd
      \Zfailed to read Zd
      g'
  sub:scan/builtin 'exit' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zble.pp.*return 1 2>/dev/null || exit 1Zd
      \Z^[-[:space:][:alnum:]_./:=$#*]+('\''[^'\'']*|"[^"()`]*|([[:space:]]|^)#.*)\bexit\bZd
      \Z\(exit\) ;;Zd
      \Zprint NR; exit;Zd;g'
  sub:scan/builtin 'eval' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Z\('\''eval'\''\)Zd
      \Zbuiltins2=\(.* eval\)Zd
      \Z\^eval --Zd
      \Zt = "eval -- \$"Zd
      \Ztext = "eval -- \$'\''Zd
      \Zcmd '\''eval -- %q'\''Zd
      g'
  sub:scan/builtin 'unset' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zunset _ble_init_(version|arg|exit|test)\bZd
      \Zreadonly -f unsetZd
      g'
  sub:scan/builtin 'unalias' |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zbuiltins1=\(.* unalias\)Zd
      g'

  #sub:scan/assign
  sub:scan/builtin trap |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zble/util/print "trap -- '\''\$\{h//\$Q/\$q}'\'' \$nZd
      \Zline = "bind"Zd
      \Zlocal trap_command="trap -- Zd
      g'

  sub:scan/a.txt
  sub:scan/check-todo-mark
  sub:scan/bash300bug
  sub:scan/bash301bug-array-element-length
  sub:scan/array-count-in-arithmetic-expression
  sub:scan/unset-variable |
    sed -E 'h;s/'"$esc"'//g;s/^[^:]*:[0-9]+:[[:space:]]*//
      \Zunset _ble_init_(version|arg|exit|test)\bZd
      \Zbuiltins1=\(.* unset .*\)Zd
      \Zfunction unsetZd
      \Zreadonly -f unsetZd
      g'
  sub:scan/eval-literal

  sub:scan/memo-numbering
}

function sub:show-contrib {
  local cache_contrib_github=out/contrib-github.txt
  if [[ ! ( $cache_contrib_github -nt .git/refs/remotes/origin/master ) ]]; then
    {
      wget 'https://api.github.com/repos/akinomyoga/ble.sh/issues?state=all&per_page=100&pulls=true' -O -
      wget 'https://api.github.com/repos/akinomyoga/blesh-contrib/issues?state=all&per_page=100&pulls=true' -O -
    } |
      sed -n 's/^[[:space:]]*"login": "\(.*\)",$/\1/p' |
      sort | uniq -c | sort -rn > "$cache_contrib_github"
  fi

  echo "Contributions (from ChangeLog.md)"
  sed -n 's/.*([^()]* by \([^()]*\)).*/\1/p' memo/ChangeLog.md |
    sort | uniq -c | sort -rn
  echo

  echo "Contributions (from GitHub Issues/PRs)"
  cat "$cache_contrib_github"
}

#------------------------------------------------------------------------------
# sub:release-note
#
# 使い方
# ./make_command.sh release-note v0.3.2..v0.3.3

function sub:release-note/help {
  printf '  release-note v0.3.2..v0.3.3 [--changelog CHANGELOG]\n'
}

function sub:release-note/read-arguments {
  flags=
  fname_changelog=memo/ChangeLog.md
  while (($#)); do
    local arg=$1; shift 1
    case $arg in
    (--changelog)
      if (($#)); then
        fname_changelog=$1; shift
      else
        flags=E$flags
        echo "release-note: missing option argument for '$arg'." >&2
      fi ;;
    esac
  done
}

function sub:release-note/.find-commit-pairs {
  {
    echo __MODE_HEAD__
    git log --format=format:'%h%s' --date-order --abbrev-commit "$1"; echo
    echo __MODE_MASTER__
    git log --format=format:'%h%s' --date-order --abbrev-commit master; echo
  } | awk -F '' '
    /^__MODE_HEAD__$/ {
      mode = "head";
      nlist = 0;
      next;
    }
    /^__MODE_MASTER__$/ { mode = "master"; next; }

    mode == "head" {
      i = nlist++;
      titles[i] = $2
      commit_head[i] = $1;
      title2index[$2] = i;
    }
    mode == "master" && (i = title2index[$2]) != "" && commit_master[i] == "" {
      commit_master[i] = $1;
    }
    
    END {
      for (i = 0; i < nlist; i++) {
        print commit_head[i] ":" commit_master[i] ":" titles[i];
      }
    }
  '
}

function sub:release-note {
  local flags fname_changelog
  sub:release-note/read-arguments "$@"

  ## @arr commits
  ##   この配列は after:before の形式の要素を持つ。
  ##   但し after は前の version から release までに加えられた変更の commit である。
  ##   そして before は after に対応する master における commit である。
  local -a commits
  IFS=$'\n' eval 'commits=($(sub:release-note/.find-commit-pairs "$@"))'

  local commit_pair
  for commit_pair in "${commits[@]}"; do
    local a=${commit_pair%%:*}
    commit_pair=${commit_pair:${#a}+1}
    local b=${commit_pair%%:*}
    local c=${commit_pair#*:}

    local result=
    [[ $b ]] && result=$(awk '
        sub(/^##+ +/, "") { heading = "[" $0 "] "; next; }
        sub(/\y'"$b"'\y/, "'"$a (master: $b)"'") {print heading $0;}
      ' "$fname_changelog")
    if [[ $result ]]; then
      echo "$result"
    elif [[ $c ]]; then
      echo "- $c $a (master: ${b:-N/A}) ■NOT-FOUND■"
    else
      echo "■not found $a"
    fi
  done | tac
}

#------------------------------------------------------------------------------

function sub:list-functions/help {
  printf '  list-functions [-p] files...\n'
}
function sub:list-functions {
  local -a files; files=()
  local opt_literal=
  local i=0 N=$# args; args=("$@")
  while ((i<N)); do
    local arg=${args[i++]}
    if [[ ! $opt_literal && $arg == -* ]]; then
      if [[ $arg == -- ]]; then
        opt_literal=1
      elif [[ $arg == --* ]]; then
        printf 'list-functions: unknown option "%s"\n' "$arg" >&2
        opt_error=1
      elif [[ $arg == -* ]]; then
        local j
        for ((j=1;j<${#arg};j++)); do
          local o=${arg:j:1}
          case $o in
          (p) opt_public=1 ;;
          (*) printf 'list-functions: unknown option "-%c"\n' "$o" >&2
              opt_error=1 ;;
          esac
        done
      fi
    else
      files+=("$arg")
    fi
  done

  if ((${#files[@]}==0)); then
    files=($(find out -name \*.sh -o -name \*.bash))
  fi

  if [[ $opt_public ]]; then
    local rex_function_name='[^[:space:]()/]*'
  else
    local rex_function_name='[^[:space:]()]*'
  fi
  sed -n 's/^[[:space:]]*function \('"$rex_function_name"'\)[[:space:]].*/\1/p' "${files[@]}" | sort -u
}

function sub:first-defined {
  local name dir
  for name; do
    for dir in ../ble-0.{1..3} ../ble.sh; do
      (cd "$dir"; grc "$name" &>/dev/null) || continue
      echo "$name $dir"
      return 0
    done
  done
  echo "$name not found"
  return 1
}
function sub:first-defined/help {
  printf '  first-defined KEYWORDS...\n'
}

#------------------------------------------------------------------------------

function sub:scan-words {
  # sed -E "s/'[^']*'//g;s/(^| )[[:space:]]*#.*/ /g" $(findsrc --exclude={wiki,test,\*.md}) |
  #   grep -hoE '\$\{?[_a-zA-Z][_a-zA-Z0-9]*\b|\b[_a-zA-Z][-:._/a-zA-Z0-9]*\b' |
  #   sed -E 's/^\$\{?//g;s.^ble/widget/..;\./.!d;/:/d' |
  #   sort | uniq -c | sort -n
  sed -E "s/(^| )[[:space:]]*#.*/ /g" $(findsrc --exclude={memo,wiki,test,\*.md}) |
    grep -hoE '\b[_a-zA-Z][_a-zA-Z0-9]{3,}\b' |
    sed -E 's/^bleopt_//' |
    sort | uniq -c | sort -n | less
}
function sub:scan-varnames {
  sed -E "s/(^| )[[:space:]]*#.*/ /g" $(findsrc --exclude={wiki,test,\*.md}) |
    grep -hoE '\$\{?[_a-zA-Z][_a-zA-Z0-9]*\b|\b[_a-zA-Z][_a-zA-Z0-9]*=' |
    sed -E 's/^\$\{?(.*)/\1$/g;s/[$=]//' |
    sort | uniq -c | sort -n | less
}

#------------------------------------------------------------------------------
# sub:check-readline-bindable

function sub:check-readline-bindable {
  join -v1 <(
    for bash in bash $(compgen -c -- bash-); do
      [[ $bash == bash-[12]* ]] && continue
      "$bash" -c 'bind -l' 2>/dev/null
    done | sort -u
  ) <(sort keymap/emacs.rlfunc.txt)
}

#------------------------------------------------------------------------------

if (($#==0)); then
  sub:help
elif declare -f sub:"$1" &>/dev/null; then
  sub:"$@"
else
  echo "unknown subcommand '$1'" >&2
  builtin exit 1
fi
