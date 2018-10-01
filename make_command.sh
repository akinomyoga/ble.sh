#!/bin/bash

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

function sub:install {
  local src=$1
  local dst=$2
  mkd "${dst%/*}"
  if [[ $src == *.sh ]]; then
    sed '
      1i# this script is a part of blesh (https://github.com/akinomyoga/ble.sh) under MIT license
      /^[[:space:]]*#/d;/^[[:space:]]*$/d
    ' "$src" > "$dst"
  else
    cp "$src" "$dst"
  fi
}
function sub:install/help {
  printf '  install src dst\n'
}

function sub:dist {
  local tmpdir="ble-$FULLVER"
  local src
  for src in "$@"; do
    local dst="$tmpdir${src#out}"
    sub:install "$src" "$dst"
  done
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

#------------------------------------------------------------------------------
# sub:check

function sub:check/builtin {
  echo "--- $FUNCNAME $1 ---"
  local command="$1" esc='(\[[ -?]*[@-~])*'
  grc --color --exclude=./test --exclude=*.md --exclude=./make_command.sh "(^|[^-./\${}=])\b$command"'\b([[:space:]|&;<>()`"'\'']|$)' |
    grep -Ev "^$esc([^[:space:]]$esc)+[[:space:]]*#|(\b|$esc)(builtin|function)$esc([[:space:]]$esc)+$command(\b|$esc)" |
    grep -Ev "$command(\b|$esc)="
}

function sub:check/a.txt {
  echo "--- $FUNCNAME ---"
  grc --color --exclude=./test --exclude=./make_command.sh 'a\.txt|/dev/pts/[0-9]*' |
    grep -Ev "$rex_grep_head#|[[:space:]]#"
}

function sub:check/bash300bug {
  echo "--- $FUNCNAME ---"
  # bash-3.0 では local arr=(1 2 3) とすると
  # local arr='(1 2 3)' と解釈されてしまう。
  grc 'local [a-zA-Z_]+=\(' --exclude=./test --exclude=./make_command.sh

  # bash-3.0 では local -a arr=("$hello") とすると
  # クォートしているにも拘らず $hello の中身が単語分割されてしまう。
  grc 'local -a [[:alnum:]_]+=\([^)]*[\"'\''`]' --exclude=./test --exclude=./make_command.sh
}

function sub:check/bash301bug-array-element-length {
  echo "--- $FUNCNAME ---"
  # bash-3.1 で ${#arr[index]} を用いると、
  # 日本語の文字数が変になる。
  grc '\$\{#[[:alnum:]]+\[[^@*]' --exclude=test | grep -Ev '^([^#]*[[:space:]])?#'
}

function sub:check/assign {
  echo "--- $FUNCNAME ---"
  local command="$1"
  grc --color --exclude=./test --exclude=./memo '\$\([^()]' |
    grep -Ev "$rex_grep_head#|[[:space:]]#"
}

function sub:check/memo-numbering {
  echo "--- $FUNCNAME ---"

  grep -ao '\[#D....\]' memo.txt | awk '
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
  sed -n '0,/^[[:space:]]\{1,\}Done/d;/  \* .*\[#D....\]$/d;/^  \* /p' memo.txt
}

# 誤って ((${#arr[@]})) を ((${arr[@]})) などと書いてしまうミス。
function sub:check/array-count-in-arithmetic-expression {
  echo "--- $FUNCNAME ---"
  grc --exclude=./make_command.sh '\(\([^[:space:]]*\$\{[[:alnum:]_]+\[[@*]\]\}'
}

function sub:check {
  if ! type grc >/dev/null; then
    echo 'blesh check: grc not found. grc can be found in github.com:akinomyoga/mshex.git/' >&2
    exit
  fi

  local esc='(\[[ -?]*[@-~])*'
  local rex_grep_head="^$esc[[:graph:]]+$esc:$esc[[:digit:]]*$esc:$esc"

  # builtin return break continue : eval echo unset は unset しているので大丈夫のはず

  #sub:check/builtin 'history'
  #sub:check/builtin 'echo'
  #sub:check/builtin '(compopt|type|printf|read)'
  sub:check/builtin 'bind'
  sub:check/builtin 'read'
  sub:check/builtin 'exit'
  #sub:check/assign

  sub:check/a.txt
  sub:check/bash300bug
  sub:check/bash301bug-array-element-length
  sub:check/array-count-in-arithmetic-expression

  sub:check/memo-numbering
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

  if [[ $opt_public ]]; then
    local rex_function_name='[^[:space:]()/]*'
  else
    local rex_function_name='[^[:space:]()]*'
  fi
  sed -n 's/^[[:space:]]*function \('"$rex_function_name"'\)[[:space:]].*/\1/p' "${files[@]}" | sort -u
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
