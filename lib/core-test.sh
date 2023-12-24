# -*- mode: sh; mode: sh-bash -*-

#------------------------------------------------------------------------------
# test directory management

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
  cd -L "$_ble_test_dir"
}
function ble/test/rmdir {
  [[ -d $_ble_test_dir ]] &&
    ble/bin/rm -rf "$_ble_test_dir"
  return 0
}

#------------------------------------------------------------------------------
# logging / diff

_ble_test_logfile_fd=
function ble/test/log {
  if [[ $_ble_test_logfile_fd ]]; then
    ble/util/print "$1" >&"$_ble_test_logfile_fd"
  fi
  ble/util/print "$1"
}
function ble/test/log#open {
  local file=$1
  if ble/fd#alloc _ble_test_logfile_fd '>>$file'; then
    local h10=----------
    [[ -s $file ]] &&
      ble/util/print "$h10$h10$h10$h10$h10$h10$h10" >&"$_ble_test_logfile_fd"
    ble/util/print "[$(date +'%F %T %Z')] test: start logging" >&"$_ble_test_logfile_fd"
  fi
}
function ble/test/log#close {
  if [[ $_ble_test_logfile_fd ]]; then
    ble/util/print "[$(date +'%F %T %Z')] test: end logging" >&"$_ble_test_logfile_fd"
    ble/fd#close _ble_test_logfile_fd
    _ble_test_logfile_fd=
  fi
}

if ble/bin#freeze-utility-path colored; then
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
    ble/util/print "$2" >| "$f1"
    ble/util/print "$3" >| "$f2"
    ble/util/assign ret 'ble/test/diff.impl "$f1" "$f2"'
    ble/test/log "$ret"
    >| "$f1" >| "$f2"
  )
}

#------------------------------------------------------------------------------

_ble_test_section_failure_count=0
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
  if ((ntest)); then
    local percentage=$((npass*1000/ntest)) # Note: 切り捨て
    ble/util/sprintf percentage '%6s' "$((percentage/10)).$((percentage%10))%" # "XXX.X%"
  else
    local percentage=---.-%
  fi
  ble/test/log "$sgr$percentage$sgr0 [section] $_ble_test_section_title: $sgr$npass/$ntest$sgr0 ($nfail fail, $ncrash crash, $nskip skip)"
  if ((npass==ntest)); then
    return 0
  else
    ((_ble_test_section_failure_count++))
    return 1
  fi
}
function ble/test/section#incr {
  local title=$1
  [[ $_ble_test_section_fd ]] || return 1
  ble/util/print "test $title" >&"$_ble_test_section_fd"
}
function ble/test/section#report {
  local ext=$? title=$1
  [[ $_ble_test_section_fd ]] || return 1
  local code=fail; ((ext==0)) && code=pass
  ble/util/print "$code $title" >&"$_ble_test_section_fd"
}

function ble/test/.read-arguments {
  local xstdout xstderr xexit xret
  local qstdout qstderr qexit qret
  local -a buff=()
  while (($#)); do
    local arg=$1; shift
    case $arg in
    ('#'*)
      local ret; ble/string#trim "${arg#'#'}"
      _ble_test_title=$ret ;;
    (stdout[:=]*)
      [[ $qstdout ]] && xstdout=$xstdout$'\n'
      qstdout=1
      xstdout=$xstdout${arg#*[:=]} ;;
    (stderr[:=]*)
      [[ $qstderr ]] && xstderr=$xstderr$'\n'
      qstderr=1
      xstderr=$xstderr${arg#*[:=]} ;;
    (ret[:=]*)
      qret=1
      xret=${arg#*[:=]} ;;
    (exit[:=]*)
      qexit=1
      xexit=${arg#*[:=]} ;;
    (code[:=]*)
      ((${#buff[@]})) && ble/array#push buff $'\n'
      ble/array#push buff "${arg#*[:=]}" ;;
    (--depth=*)
      _ble_test_caller_depth=${arg#*=} ;;
    (--display-code=*)
      _ble_test_display_code=${arg#*=} ;;
    (*)
      ((${#buff[@]})) && ble/array#push buff ' '
      ble/array#push buff "$arg" ;;
    esac
  done

  [[ $qstdout ]] && _ble_test_item_expect[0]=$xstdout
  [[ $qstderr ]] && _ble_test_item_expect[1]=$xstderr
  [[ $qexit   ]] && _ble_test_item_expect[2]=$xexit
  [[ $qret    ]] && _ble_test_item_expect[3]=$xret

  # 何もチェックが指定されなかった時は終了ステータスをチェックする
  ((${#_ble_test_item_expect[@]})) || _ble_test_item_expect[2]=0

  IFS= builtin eval '_ble_test_code="${buff[*]}"'
}

_ble_test_item_name=(stdout stderr exit ret)
## @fn ble/test [--depth=NUM|--display-code=CODE] CODE [[code|stdout|stderr|exit|ret]=VALUE]... '# title'
##   @var[out] stdout stderr exit ret
function ble/test {
  local _ble_test_code
  local _ble_test_title
  local _ble_test_caller_depth=0
  local _ble_test_display_code=
  local -a _ble_test_item_expect=()
  ble/test/.read-arguments "$@"

  local caller_lineno=${BASH_LINENO[_ble_test_caller_depth+0]}
  local caller_source=${BASH_SOURCE[_ble_test_caller_depth+1]}
  _ble_test_title="$caller_source:$caller_lineno${_ble_test_title+ ($_ble_test_title)}"
  ble/test/section#incr "$_ble_test_title"

  # run
  ble/util/assign stderr '
    ble/util/assign stdout "$_ble_test_code" 2>&1'; exit=$?
  local -a item_result=()
  item_result[0]=$stdout
  item_result[1]=$stderr
  item_result[2]=$exit
  item_result[3]=$ret

  local i flag_error=
  for i in "${!_ble_test_item_expect[@]}"; do
    [[ ${item_result[i]} == "${_ble_test_item_expect[i]}" ]] && continue

    if [[ ! $flag_error ]]; then
      flag_error=1
      ble/test/log $'\e[1m'"$_ble_test_title"$'\e[m: \e[91m'"${_ble_test_display_code:-$_ble_test_code}"$'\e[m'
    fi

    ble/test/diff "${_ble_test_item_name[i]}" "${_ble_test_item_expect[i]}" "${item_result[i]}"
  done
  if [[ $flag_error ]]; then
    if [[ ! ${_ble_test_item_expect[1]+set} && $stderr ]]; then
      ble/test/log "<STDERR>"
      ble/test/log "$stderr"
      ble/test/log "</STDERR>"
    fi
    ble/test/log
  fi

  [[ ! $flag_error ]]
  ble/test/section#report "$_ble_test_title"
  return 0
}
