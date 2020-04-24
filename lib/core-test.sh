# -*- mode: sh; mode: sh-bash -*-

function ble/test/getdir {
  dir=$_ble_base_run/$$.test
  [[ -d $dir ]] || ble/bin/mkdir -p "$dir"
}

_ble_test_dir=
function ble/test/chdir {
  local dir
  ble/test/getdir
  ble/util/getpid
  _ble_test_dir=$dir/$BASHPID.d
  [[ -d $_ble_test_dir ]] ||
    ble/bin/mkdir -p "$_ble_test_dir"
  cd "$_ble_test_dir"
}
function ble/test/rmdir {
  [[ -d $_ble_test_dir ]] &&
    ble/bin/rm -rf "$_ble_test_dir"
  return 0
}

if ble/bin/.freeze-utility-path colored; then
  function ble/test/diff.impl {
    ble/bin/colored diff -u "$@"
  }
else
  function ble/test/diff.impl {
    diff -u "$@"
  }
fi
function ble/test/diff {
  local dir
  ble/test/getdir
  ble/util/getpid
  local f1=$BASHPID.$1.expect
  local f2=$BASHPID.$1.result
  (
    cd "$dir"
    ble/util/print "$2" > "$f1"
    ble/util/print "$3" > "$f2"
    ble/test/diff.impl "$f1" "$f2"
    > "$f1" > "$f2"
  )
}

_ble_test_section_fd=
_ble_test_section_file=
_ble_test_section_title=section
_ble_test_section_count=0
function ble/test/start-section {
  [[ $_ble_test_section_fd ]] && ble/test/end-section
  _ble_test_section_title=$1
  _ble_test_section_count=$2
  local dir
  ble/test/getdir
  ble/util/getpid
  _ble_test_section_file=$dir/$BASHPID
  ble/fd#alloc _ble_test_section_fd '> "$_ble_test_section_file"'
}
function ble/test/end-section {
  [[ $_ble_test_section_fd ]] || return 1
  ble/fd#close _ble_test_section_fd
  _ble_test_section_fd=

  local ntest npass count=$_ble_test_section_count

  local ntest nfail npass
  builtin eval -- $(
    ble/bin/awk '
      BEGIN{test=0;fail=0;pass=0;}
      /^test /{test++}
      /^fail /{fail++}
      /^pass /{pass++}
      END{print "ntest="test" nfail="fail" npass="pass;}
    ' "$_ble_test_section_file")

  local sgr=$'\e[32m' sgr0=$'\e[m'
  ((npass==ntest)) || sgr=$'\e[31m'

  local ncrash=$((ntest-nfail-npass))
  local nskip=$((count-ntest))
  ble/util/print "[section] $_ble_test_section_title: $sgr$npass/$ntest$sgr0 ($nfail fail, $ncrash crash, $nskip skip)"
  ((npass==ntest))
}
function ble/test/section#incr {
  local title=$1
  [[ $_ble_test_section_fd ]] || return 1
  ble/util/print "test $title" >&$_ble_test_section_fd
}
function ble/test/section#report {
  local ext=$? title=$1
  [[ $_ble_test_section_fd ]] || return 1
  local code=fail; ((ext==0)) && code=pass
  ble/util/print "$code $title" >&$_ble_test_section_fd
}

function ble/test/.read-arguments {
  local _stdout _stderr _exit _ret
  local qstdout qstderr qexit qret
  local -a buff=()
  while (($#)); do
    local arg=$1; shift
    case $arg in
    ('#'*)
      local ret; ble/string#trim "${arg#'#'}"
      title=$ret ;;
    (stdout[:=]*)
      [[ $qstdout ]] && _stdout=$_stdout$'\n'
      qstdout=1
      _stdout=$_stdout${arg#*[:=]} ;;
    (stderr[:=]*)
      [[ $qstderr ]] && _stderr=$_stderr$'\n'
      qstderr=1
      _stderr=$_stderr${arg#*[:=]} ;;
    (ret[:=]*)
      qret=1
      _ret=${arg#*[:=]} ;;
    (exit[:=]*)
      qexit=1
      _exit=${arg#*[:=]} ;;
    (code[:=]*)
      ((${#buff[@]})) && ble/array#push buff $'\n'
      ble/array#push buff "${arg#*[:=]}" ;;
    (*)
      ((${#buff[@]})) && ble/array#push buff ' '
      ble/array#push buff "$arg" ;;
    esac
  done

  [[ $qstdout ]] && item_expect[0]=$_stdout
  [[ $qstderr ]] && item_expect[1]=$_stderr
  [[ $qexit   ]] && item_expect[2]=$_exit
  [[ $qret    ]] && item_expect[3]=$_ret

  # 何もチェックが指定されなかった時は終了ステータスをチェックする
  ((${#item_expect[@]})) || item_expect[2]=0

  IFS= builtin eval 'code="${buff[*]}"'
}
function ble/test {
  local -a item_name=(stdout stderr exit ret)

  local code title
  local -a item_expect=()
  ble/test/.read-arguments "$@"

  local caller_lineno=${BASH_LINENO[0]}
  local caller_source=${BASH_SOURCE[1]}
  title="$caller_source:$caller_lineno${title+ ($title)}"
  ble/test/section#incr "$title"

  # run
  ble/util/assign stderr '
    ble/util/assign stdout "$code" 2>&1'; exit=$?
  local -a item_result=()
  item_result[0]=$stdout
  item_result[1]=$stderr
  item_result[2]=$exit
  item_result[3]=$ret

  local i flag_error=
  for i in "${!item_expect[@]}"; do
    [[ ${item_result[i]} == "${item_expect[i]}" ]] && continue

    if [[ ! $flag_error ]]; then
      flag_error=1
      ble/util/print $'\e[1m'"$title"$'\e[m: \e[91m'"$code"$'\e[m'
    fi

    ble/test/diff "${item_name[i]}" "${item_expect[i]}" "${item_result[i]}"
  done
  if [[ $flag_error ]]; then
    if [[ ! ${item_expect[1]+set} && $stderr ]]; then
      ble/util/print "<STDERR>"
      ble/util/print "$stderr"
      ble/util/print "</STDERR>"
    fi
    ble/util/print
  fi

  [[ ! $flag_error ]]
  ble/test/section#report "$title"
  return 0
}
