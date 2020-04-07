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

_ble_test_section_fd=
_ble_test_section_title=section
_ble_test_section_count=0
function ble/test/start-section {
  _ble_test_section_title=$1
  _ble_test_section_count=$2
  local tmp=$_ble_base_run/$$.test
  ble/util/openat _ble_test_section_fd '> "$tmp"'
}
function ble/test/end-section {
  local tmp=$_ble_base_run/$$.test
  local ntest npass count=$_ble_test_section_count

  local ntest nfail npass
  builtin eval -- $(
    ble/bin/awk '
      BEGIN{test=0;fail=0;pass=0;}
      /^test /{test++}
      /^fail /{fail++}
      /^pass /{pass++}
      END{print "ntest="test" nfail="fail" npass="pass;}
    ' "$tmp")

  local sgr=$'\e[32m' sgr0=$'\e[m'
  ((npass==ntest)) || sgr=$'\e[31m'

  local ncrash=$((ntest-nfail-npass))
  local nskip=$((count-ntest))
  ble/util/print "[section] $_ble_test_section_title: $sgr$npass/$ntest$sgr0 ($nfail fail, $ncrash crash, $nskip skip)"
}
function ble/test/section#incr {
  local title=$1
  [[ $_ble_test_section_fd ]] || return
  ble/util/print "test $title" >&$_ble_test_section_fd
}
function ble/test/section#report {
  local ext=$? title=$1
  [[ $_ble_test_section_fd ]] || return
  local code=fail; ((ext==0)) && code=pass
  ble/util/print "$code $title" >&$_ble_test_section_fd
}

function ble/test/.read-arguments {
  local -a buff=()
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (stdout[:=]*)
      if [[ ! $qstdout ]]; then
        qstdout=1 _stdout=${arg#*[:=]}
      else
        _stdout=$_stdout$'\n'${arg#*[:=]}
      fi ;;
    (ret[:=]*)
      qret=1 _ret=${arg#*[:=]} ;;
    (exit[:=]*)
      qexit=1 _exit=${arg#*[:=]} ;;
    (code[:=]*)
      ((${#buff[@]})) && ble/array#push buff $'\n'
      ble/array#push buff "${arg#*[:=]}" ;;
    (*)
      ((${#buff[@]})) && ble/array#push buff ' '
      ble/array#push buff "$arg" ;;
    esac
  done
  IFS= builtin eval 'code="${buff[*]}"'
}
function ble/test {
  local caller_lineno=${BASH_LINENO[0]}
  local caller_source=${BASH_SOURCE[1]}
  ble/test/section#incr "$caller_source:$caller"

  local code
  local qstdout= qret= qexit=
  local _stdout= _ret= _exit=
  ble/test/.read-arguments "$@"
  local stdout= ret= exit=
  ble/util/assign stdout "$code" 2>/dev/null; exit=$?

  # 何もチェックが指定されなかった時は終了ステータス
  [[ ! $qstdout$qret$qexit ]] && qexit=1 _exit=0

  local estdout= eret= eexit=
  [[ $qexit && $exit != "$_exit" ]] && eexit=1
  [[ $qstdout && $stdout != "$_stdout" ]] && estdout=1
  [[ $qret && $ret != "$_ret" ]] && eret=1

  if [[ $estdout$eret$eexit ]]; then
    ble/util/print $'\e[1m'"$caller_source:$caller_lineno"$'\e[m: \e[91m'"$code"$'\e[m' >&2
    if [[ $eexit ]]; then
      ble/util/print $'\e[91mFAIL: exit\e[m'
      ble/test/diff "$_exit" "$exit"
    fi
    if [[ $estdout ]]; then
      ble/util/print $'\e[91mFAIL: stdout\e[m'
      ble/test/diff "$_stdout" "$stdout"
    fi
    if [[ $eret ]]; then
      ble/util/print $'\e[91mFAIL: ret\e[m'
      ble/test/diff "$_ret" "$ret"
    fi
    ble/util/print
  fi

  [[ ! $estdout$eret$eexit ]]
  ble/test/section#report "$caller_source:$caller"
  return 0
}
