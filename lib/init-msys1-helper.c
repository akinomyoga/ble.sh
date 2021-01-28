// For MSYS 1.0
#include <stdio.h>
#include <windows.h>
#include <sys/stat.h>
#include <signal.h>

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
