#!/bin/bash

function ble-edit/io:msys1/is-msys1 {
  local cr; cr=$'\r'
  [[ $OSTYPE == msys && ! $cr ]]
}
function ble-edit/io:msys1/get-winpid.proc {
  /usr/bin/ps | /usr/bin/gawk -v pid="$1" '
    BEGIN {
      cygpid_len = 9;
      winpid_len = 36;
    }
    NR == 1 {
      line = $0;
      if (!match(line, /.*\yPID\y/)) next;
      cygpid_end = RLENGTH;
      if (!match(line, /.*\yWINPID\y/)) next;
      winpid_end = RLENGTH;
      next;
    }
    function get_last_number(line, limit, _, head, i) {
      head = substr(line, 1, limit);
      if (i = match(head, /[0-9]+$/))
        return substr(head, i, RLENGTH);
      return -1;
    }
    {
      cygpid = get_last_number($0, cygpid_end);
      if (cygpid != pid) next;
      print get_last_number($0, winpid_end);
      exit
    }
  '
}
function ble-edit/io:msys1/compile-helper {
  local helper=$1
  [[ -x $helper && $helper -nt $_ble_base/lib/init-msys1.sh ]] && return 0

  # /mingw/bin/gcc
  local include='#include' # '#' で始まる行はインストール時に消される
  gcc -O2 -s -o "$helper" -xc - << EOF || return 1
$include <stdio.h>
$include <windows.h>
$include <sys/stat.h>
$include <signal.h>

BOOL is_process_alive(HANDLE handle) {
  DWORD result;
  return GetExitCodeProcess(handle, &result) && result == STILL_ACTIVE;
}

BOOL is_file(const char* filename) {
  struct stat st;
  return stat(filename, &st) == 0 && S_ISREG(st.st_mode);
}

int main(int argc, char** argv) {
  const char* winpid = argv[1];
  const char* fname_buff = argv[2];
  const char* fname_read = argv[3];

  signal(SIGINT, SIG_IGN);
  //signal(SIGQUIT, SIG_IGN);

  int ppid = atoi(winpid);
  if (!ppid) {
    fprintf(stderr, "ble.sh (msys1): invalid process ID '%s'\n", winpid);
    return 1;
  }
  HANDLE parent_process = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, ppid);
  if (parent_process == NULL) {
    fprintf(stderr, "ble.sh (msys1): failed to open the parent process '%s'\n", winpid);
    return 1;
  }

  int exit_code = 0;
  BOOL terminate = FALSE;
  while (!terminate) {
    unlink(fname_read);
    if (rename(fname_buff, fname_read) != 0) {
      perror("ble.sh (msys1)");
      fprintf(stderr, "ble.sh (msys1): failed to move the file '%s' -> '%s'\n", fname_buff, fname_read);
      terminate = TRUE;
      exit_code = 1;
      break;
    }

    FILE* f = fopen(fname_read, "r");
    if (!f) {
      fprintf(stderr, "ble.sh (msys1): failed to open the file '%s'\n", fname_read);
      terminate = TRUE;
      exit_code = 1;
      break;
    }

    for (;;) {
      if (!is_process_alive(parent_process)) {
        terminate = TRUE;
        break;
      }
      if (is_file(fname_buff)) break;

      int count = 0;
      char buff[4096];
      while (count = fread(&buff, 1, sizeof buff, f))
        fwrite(buff, 1, count, stdout);
      fflush(stdout);
      Sleep(20);
    }
    fclose(f);
  }

  CloseHandle(parent_process);
  return exit_code;
}
EOF

  [[ -x $helper ]]
}

function ble-edit/io:msys1/start-background {
  local basename=$_ble_edit_io_fname2
  local fname_buff=$basename.buff

  ble-edit/io:msys1/is-msys1 || return 1

  local helper=$_ble_base_cache/init-msys1-helper.exe
  local helper2=$_ble_base_run/$$.init-msys1-helper.exe
  ble-edit/io:msys1/compile-helper "$helper" &&
    /usr/bin/cp "$helper" "$helper2" || return 1

  local winpid
  ble/util/assign winpid 'ble-edit/io:msys1/get-winpid.proc $$'
  [[ $winpid ]] || return 1

  : >| "$fname_buff"
  ble/fd#alloc _ble_edit_io_fd2 '> "$fname_buff"'
  "$helper2" "$winpid" "$fname_buff" "${fname_buff%.buff}.read" | ble-edit/io/check-ignoreeof-loop & disown
} &>/dev/null
