# source script for ble.sh interactive sessions -*- mode: sh; mode: sh-bash -*-

ble-import lib/core-test

ble/test/start-section 'ble/builtin/history' 41

#------------------------------------------------------------------------------
# helpers

## @fn ble/test/history/write-file file count [ts] [first]
##   Writes "count" entries "echo cmdN" (N starting at "first", default 1) to
##   "file" in the HISTFILE format.  When "ts" is non-empty, every entry is
##   preceded by a timestamp line as written by Bash with HISTTIMEFORMAT.
function ble/test/history/write-file {
  local file=$1 count=$2 ts=$3 first=${4:-1} i
  {
    for ((i=first;i<first+count;i++)); do
      [[ $ts ]] && ble/util/print "#$((1700000000+i))"
      ble/util/print "echo cmd$i"
    done
  } >| "$file"
}
## @fn ble/test/history/append-file file count [ts] [first]
function ble/test/history/append-file {
  local file=$1 count=$2 ts=$3 first=${4:-1} i
  {
    for ((i=first;i<first+count;i++)); do
      [[ $ts ]] && ble/util/print "#$((1700000000+i))"
      ble/util/print "echo cmd$i"
    done
  } >> "$file"
}
## @fn ble/test/history/load-file file
##   Replaces the in-memory history with the content of "file", which is what
##   Bash does with HISTFILE on startup.
function ble/test/history/load-file {
  builtin history -c
  builtin history -r "$1"
}
## @fn ble/test/history/list
##   Prints the commands in the in-memory history, one entry per line.
function ble/test/history/list {
  (HISTTIMEFORMAT=; builtin history) | ble/bin/awk '{ sub(/^ *[0-9]+\*? +/, ""); print; }'
}
## @fn ble/test/history/count
##   Prints the number of lines of the in-memory history.
function ble/test/history/count {
  (HISTTIMEFORMAT=; builtin history) | ble/bin/awk 'END { print NR; }'
}
## @fn ble/test/history/.check-session-entries
##   Checks whether entries added with "builtin history -s" are written by
##   "builtin history -a" in this process.  This is how .initialize collects
##   the entries added before ble.sh is loaded.  In non-interactive shells of
##   old Bash versions, "history -s" does not count as a line of the session,
##   so the tests that depend on it are skipped there.
function ble/test/history/.check-session-entries {
  (
    builtin history -c
    ble/test/history/enable-timestamps
    builtin history -s 'echo probe'
    builtin history -a probe.ini
    [[ -s probe.ini ]]
  )
}
## @fn ble/test/history/rskip file
function ble/test/history/rskip {
  local rskip; ble/builtin/history/.get-rskip "$1"
  ble/util/print "$rskip"
}
## @fn ble/test/history/reset-state
##   Clears the state of ble/builtin/history that persists in the runtime
##   directory and in variables, so that a test starts from a clean slate.
function ble/test/history/reset-state {
  >| "$_ble_base_run/$$.history.new"
  >| "$_ble_base_run/$$.history.app"
  >| "$_ble_base_run/$$.history.ini"
  ble/bin/rm -f "$_ble_base_run/$$.history.touch"
  _ble_builtin_history_histnew_count=0
  _ble_builtin_history_histapp_count=0
  _ble_builtin_history_initialized=
  _ble_builtin_history_wskip=0
  _ble_builtin_history_prevmax=0
}

## @fn ble/test/history/enable-timestamps
##   Makes Bash write and parse timestamp lines like in an interactive session
##   with HISTTIMEFORMAT.  A real assignment is needed because a temporary
##   assignment for a builtin does not take effect in non-interactive shells.
##   Old versions of Bash set the history comment character only during the
##   initialization of interactive shells, so assigning "histchars" (with its
##   default value) is needed for "history -r" to recognize timestamp lines
##   in the non-interactive test process.
function ble/test/history/enable-timestamps {
  HISTTIMEFORMAT='%s '
  histchars='!^#'
}

## @fn ble/test/history/initialize-rskip nfile ngrow ts histsize [nsession]
##   Simulates the situation in which ble/builtin/history/.initialize runs:
##   Bash has read "nfile" entries from HISTFILE (with timestamp lines when "ts"
##   is non-empty) under the specified HISTSIZE (empty for unlimited),
##   "nsession" entries have been added in this session, and "ngrow" entries
##   have been appended to HISTFILE by another session afterwards.  Prints the
##   resulting rskip.  This function has to be called in a subshell.
function ble/test/history/initialize-rskip {
  local nfile=$1 ngrow=$2 ts=$3 histsize=$4 nsession=${5:-0}
  ble/test/history/reset-state
  HISTFILE=$PWD/histfile
  { [[ $ts ]] || ((nsession)); } && ble/test/history/enable-timestamps
  ble/test/history/write-file "$HISTFILE" "$nfile" "$ts"
  if [[ $histsize ]]; then
    HISTSIZE=$histsize
  else
    builtin unset -v HISTSIZE
  fi
  ble/test/history/load-file "$HISTFILE"
  local i
  for ((i=1;i<=nsession;i++)); do
    builtin history -s "echo session$i"
  done
  ((ngrow)) && ble/test/history/append-file "$HISTFILE" "$ngrow" "$ts" "$((nfile+1))"
  ble/builtin/history/.initialize
  ble/test/history/rskip "$HISTFILE"
}

#------------------------------------------------------------------------------
# ble/builtin/history/.count-entries
#
#   An entry is a line that does not start with "#" followed by a digit, which
#   is exactly what Bash skips as a timestamp line when reading HISTFILE.

(
  ble/test/chdir || exit
  ble/test/history/write-file plain 3
  ble/test/history/write-file ts 3 ts
  ble/test 'ble/builtin/history/.count-entries plain' ret=3
  ble/test 'ble/builtin/history/.count-entries ts' ret=3
  ble/util/print-lines '#1700000001' 'echo a' '#12ab junk' 'echo b' '#0' 'echo c' '#1 not a timestamp' 'echo d' >| odd
  ble/test 'ble/builtin/history/.count-entries odd' ret=4 \
           '# any "#<digit>..." line is a timestamp line for Bash'
  ble/util/print-lines '#comment' 'echo a' '# 1' 'echo b' >| comments
  ble/test 'ble/builtin/history/.count-entries comments' ret=4 \
           '# "#" not followed by a digit is a command'
  ble/test/rmdir
)

#------------------------------------------------------------------------------
# ble/builtin/history/.is-HISTSIZE-reached

(
  ble/test '(builtin unset -v HISTSIZE; ble/builtin/history/.is-HISTSIZE-reached 1000000)' exit=1
  ble/test '(HISTSIZE=; ble/builtin/history/.is-HISTSIZE-reached 1000000)' exit=1
  ble/test '(HISTSIZE=abc; ble/builtin/history/.is-HISTSIZE-reached 1000000)' exit=1
  ble/test '(HISTSIZE=5x; ble/builtin/history/.is-HISTSIZE-reached 1000000)' exit=1
  ble/test '(HISTSIZE=" 5 "; ble/builtin/history/.is-HISTSIZE-reached 4)' exit=1
  ble/test '(HISTSIZE=" 5 "; ble/builtin/history/.is-HISTSIZE-reached 5)' exit=0
  ble/test '(HISTSIZE=+5; ble/builtin/history/.is-HISTSIZE-reached 6)' exit=0
  if ((_ble_bash>=40300)); then
    ble/test '(HISTSIZE=-1; ble/builtin/history/.is-HISTSIZE-reached 1000000)' exit=1 \
             '# negative HISTSIZE is unlimited in Bash >= 4.3'
  else
    ble/test '(HISTSIZE=-1; ble/builtin/history/.is-HISTSIZE-reached 0)' exit=0 \
             '# negative HISTSIZE is a limit in Bash <= 4.2'
  fi
)

#------------------------------------------------------------------------------
# ble/builtin/history/.read
#
#   "skip" and rskip count entries, not lines.

(
  ble/test/chdir || exit
  ble/test/history/reset-state
  ble/test/history/enable-timestamps
  ble/test/history/write-file file 3 ts
  builtin history -c

  ble/test 'ble/builtin/history/.read file 1; ble/test/history/list' \
           stdout=$'echo cmd2\necho cmd3' \
           '# skip counts entries (a timestamped entry has two lines)'
  ble/test 'ble/test/history/rskip file' stdout=3 \
           '# rskip is the number of entries in the file'
  ble/test 'ble/util/print "$_ble_builtin_history_wskip"' stdout=2 \
           '# wskip follows the last history number'

  # fetch: the new entries are kept in the "new" file until the next read
  builtin history -c
  ble/test/history/reset-state
  ble/test 'ble/builtin/history/.read file 1 fetch; ble/test/history/count' stdout=0
  ble/test 'ble/util/print "$_ble_builtin_history_histnew_count"' stdout=2 \
           '# fetched entries are counted in entries'
  ble/test 'ble/test/history/rskip file' stdout=3
  ble/test 'ble/builtin/history/.read file 3; ble/test/history/list' \
           stdout=$'echo cmd2\necho cmd3' \
           '# a later read loads the fetched entries'
  ble/test 'ble/util/print "$_ble_builtin_history_histnew_count"' stdout=0

  ble/test/rmdir
)

#------------------------------------------------------------------------------
# ble/builtin/history/.write
#
#   rskip is advanced by the number of entries written (not lines), and set
#   to the number of entries when the file is rewritten (history -w).

(
  ble/test/chdir || exit
  ble/test/history/reset-state
  ble/test/history/enable-timestamps
  ble/test/history/write-file seed 3 ts
  ble/test/history/load-file seed
  >| out
  ble/builtin/history/.set-rskip out 10

  ble/test 'ble/builtin/history/.write out 0 append; ble/test/history/rskip out' stdout=13 \
           '# append: rskip advances by 3 entries although 6 lines were written'
  ble/test 'ble/builtin/history/.count-entries out' ret=3
  ble/test 'ble/bin/awk "END { print NR; }" out' stdout=6
  ble/test 'ble/util/print "$_ble_builtin_history_wskip"' stdout=3

  ble/test 'ble/builtin/history/.write out 0; ble/test/history/rskip out' stdout=3 \
           '# rewrite (history -w): rskip is the number of entries in the file'
  ble/test 'ble/bin/awk "END { print NR; }" out' stdout=6

  # a multi-line entry is written as one "eval -- $'"'"'...'"'"'" line and counts as one entry
  builtin history -s $'echo multi\necho line2'
  q=\'
  ble/test 'ble/builtin/history/.write out "$_ble_builtin_history_wskip" append; ble/test/history/rskip out' stdout=4
  ble/test 'ble/bin/awk "END { print NR; }" out' stdout=8
  ble/test 'ble/bin/awk "END { print; }" out' stdout="eval -- \$${q}echo multi\\necho line2${q}"

  ble/test/rmdir
)

#------------------------------------------------------------------------------
# ble/builtin/history/.initialize
#
#   rskip starts as the number of entries in HISTFILE.  It is clamped to the
#   number of entries Bash has read from HISTFILE when the in-memory history
#   is not truncated by HISTSIZE, so that entries appended by other sessions
#   between Bash's startup and the lazy initialization are picked up by the
#   next "history -n".  With a truncated in-memory history the clamp must not
#   apply (it would re-read the file).

(
  ble/test/chdir || exit

  ble/test '(ble/test/history/initialize-rskip 10 0 "" "")' stdout=10 \
           '# no growth, unlimited'
  ble/test '(ble/test/history/initialize-rskip 10 2 "" "")' stdout=10 \
           '# growth by 2 entries is detected'
  ble/test '(ble/test/history/initialize-rskip 10 2 ts "")' stdout=10 \
           '# the same with timestamp lines (entries, not lines)'
  ble/test '(ble/test/history/initialize-rskip 10 0 ts "")' stdout=10
  ble/test '(ble/test/history/initialize-rskip 10 2 "" 10)' stdout=12 \
           '# in-memory history full (HISTSIZE reached): no clamp'
  ble/test '(ble/test/history/initialize-rskip 10 2 "" 5)' stdout=12 \
           '# in-memory history truncated by HISTSIZE: no clamp'
  ble/test '(ble/test/history/initialize-rskip 10 0 ts 5)' stdout=10
  if ble/test/history/.check-session-entries; then
    ble/test '(ble/test/history/initialize-rskip 10 0 ts "" 1)' stdout=10 \
             '# an entry added in this session is not counted as read from HISTFILE'
    ble/test '(ble/test/history/initialize-rskip 10 2 ts "" 1)' stdout=10 \
             '# ... and does not hide growth'
  fi

  # the following "history -n" loads exactly the new entries
  ble/test '(
    ble/test/history/initialize-rskip 10 2 ts "" >/dev/null
    ble/builtin/history/option:n
    ble/test/history/rskip "$HISTFILE"; ble/test/history/count
    ble/test/history/list | ble/bin/awk "NR > 10")' \
    stdout=$'12\n12\necho cmd11\necho cmd12' \
    '# history -n after growth'
  ble/test '(
    ble/test/history/initialize-rskip 10 2 ts 5 >/dev/null
    ble/builtin/history/option:n
    ble/test/history/rskip "$HISTFILE"; ble/test/history/count
    ble/test/history/list | ble/bin/awk "NR > 3")' \
    stdout=$'12\n5\necho cmd9\necho cmd10' \
    '# history -n after growth with HISTSIZE truncation: nothing is re-read'

  # entries added before the initialization are written by the next history -a
  if ble/test/history/.check-session-entries; then
    ble/test '(
      ble/test/history/initialize-rskip 10 0 ts "" 1 >/dev/null
      ble/builtin/history/.write "$HISTFILE" "$_ble_builtin_history_wskip" append
      ble/test/history/rskip "$HISTFILE"; ble/builtin/history/.count-entries "$HISTFILE"; ble/util/print "$ret"
      ble/bin/awk "END { print; }" "$HISTFILE")' \
      stdout=$'11\n11\necho session1' \
      '# entries collected by .initialize advance rskip when written'
  fi

  ble/test/rmdir
)

ble/test/end-section
