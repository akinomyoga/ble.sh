# -*- mode: sh; mode: sh-bash -*-

if ble/bin/.freeze-utility-path colored; then
  function ble/test/diff {
    local tmp=$_ble_base_run/$$.test.diff.$BASHPID
    ble/util/print "$1" > "$tmp.expect"
    ble/util/print "$2" > "$tmp.result"
    ble/bin/colored diff -u "$tmp.expect" "$tmp.result"
    > "$tmp.expect" > "$tmp.result"
  }
else
  function ble/test/diff {
    local tmp=$_ble_base_run/$$.test.diff.$BASHPID
    ble/util/print "$1" > "$tmp.expect"
    ble/util/print "$2" > "$tmp.result"
    diff -u "$tmp.expect" "$tmp.result"
    > "$tmp.expect" > "$tmp.result"
  }
fi

function ble/test/.read-arguments {
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (stdout=*)
      qstdout=1 _stdout=${arg#*=} ;;
    (ret=*)
      qret=1 _ret=${arg#*=} ;;
    (exit=*)
      qexit=1 _exit=${arg#*=} ;;
    (*)
      ble/array#push args "$arg" ;;
    esac
  done
}
function ble/test {
  local caller_lineno=${BASH_LINENO[0]}
  local caller_source=${BASH_SOURCE[1]}

  local -a args=()
  local qstdout= qret= qexit=
  local _stdout= _ret= _exit=
  ble/test/.read-arguments "$@"
  local stdout= ret= exit=
  ble/util/assign stdout "${args[*]}" 2>/dev/null; exit=$?

  # 何もチェックが指定されなかった時は終了ステータス
  [[ ! $qstdout$qret$qexit ]] && qexit=1 _exit=0

  local estdout= eret= eexit=
  [[ $qexit && $exit != "$_exit" ]] && eexit=1
  [[ $qstdout && $stdout != "$_stdout" ]] && estdout=1
  [[ $qret && $ret != "$_ret" ]] && eret=1

  if [[ $estdout$eret$eexit ]]; then
    ble/util/print $'\e[1mCOMMAND\e[m: '"${args[*]} ($caller_source:$caller_lineno)" >&2
    if [[ $eexit ]]; then
      ble/util/print $'\e[91mFAIL\e[m: exit'
      ble/test/diff "$_exit" "$exit"
    fi
    if [[ $estdout ]]; then
      ble/util/print $'\e[91mFAIL\e[m: stdout'
      ble/test/diff "$_stdout" "$stdout"
    fi
    if [[ $eret ]]; then
      ble/util/print $'\e[91mFAIL\e[m: ret'
      ble/test/diff "$_ret" "$ret"
    fi
    echo
  fi
}
