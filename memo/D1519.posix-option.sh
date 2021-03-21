#!/bin/bash

cat <<EOF
# With "set -o posix", the functions whose name doesn't have the form of C
# identifier cannot be defined.  The following case fails.

set -o posix
function ble/base/workaround-POSIXLY_CORRECT { true; }

# With "set -o posix", functions of non-POSIX name that are defined before
# setting "set -o posix" can be called.  The following case runs.

function ble/base/workaround-POSIXLY_CORRECT { true; }
set -o posix
ble/base/workaround-POSIXLY_CORRECT

EOF


# function ble/base/workaround-POSIXLY_CORRECT { true; }
# set -o posix
# alias type=echo
# LANG=C \type ble/base/workaround-POSIXLY_CORRECT
# echo "$LANG"

# set -e
# false && true && true
# true && true && true
# echo complete

# unset() { echo unset; }
# eval() { echo eval; }
# builtin() { echo builtin; }
# read() { echo read; }

# set -o posix
# unset
# eval
# builtin
# read < /dev/null


# set -o posix にする事で上書きしている関数を無視して本来の物が実行されるビルト
# インを確認する。
function list-posix-safe-builtins {
  local builtins
  builtins=($(printf '%s\n' $(enable) | sort -u))

  local b posix_safe posix_unsafe
  for b in "${builtins[@]}"; do
    #echo "testing $b..."
    (
      eval "$b() { return 108; }"
      if [[ $b == set ]]; then
        builtin set -p posix
      else
        set -o posix
      fi
      "$b" --help < /dev/null &>/dev/null
    )
    if (($? == 108)); then
      posix_unsafe+=("$b")
    else
      posix_safe+=("$b")
    fi
  done

  echo '# For the following builtins, the original builtins are executed even when'
  echo '# they are overrided by functions with "set -o posix" (POSIXLY_CORRECT=y):'
  echo
  echo "${posix_safe[@]}" | ifold -w 80 -s
  echo
  echo '# For the following builtins, the overriding functions are executed even'
  echo '# when "set -o posix"'
  echo
  echo "${posix_unsafe[@]}" | ifold -w 80 -s
  echo
}
list-posix-safe-builtins
