#!/usr/bin/env bash

fname_changelog=memo/ChangeLog.md

function read-arguments {
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
read-arguments "$@"

function process {
  ## @arr commits
  ##   この配列は after:before の形式の要素を持つ。
  ##   但し after は前の version から release までに加えられた変更の commit である。
  ##   そして before は after に対応する master における commit である。
  local -a commits; commits=("$@")

  local commit_pair
  for commit_pair in "${commits[@]}"; do
    local a=${commit_pair%%:*}
    commit_pair=${commit_pair:${#a}+1}
    local b=${commit_pair%%:*}
    local c=${commit_pair#*:}

    local result=
    [[ $b ]] && result=$(awk '
        sub(/^##+ +/, "") { heading = "[" $1 "] "; next; }
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

function find-commit-pairs {
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

IFS=$'\n' eval 'commit_pairs=($(find-commit-pairs "$@"))'
process "${commit_pairs[@]}"

# 使い方
# ./generate-release-note.sh v0.3.2..v0.3.3
#
