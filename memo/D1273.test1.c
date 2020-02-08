// This is MinGW Program

#include <stdio.h>
#include <windows.h>
#include <sys/stat.h>

BOOL is_process_alive(HANDLE handle) {
  DWORD result;
  return GetExitCodeProcess(handle, &result) && result == STILL_ACTIVE;
}
BOOL is_file(const char* filename) {
  struct stat st;
  if (stat(filename, &st) == 0 && S_ISREG(st.st_mode)) return TRUE;
  return FALSE;
}

int main(int argc, char** argv) {
  const char* winpid = argv[1];
  const char* filename = argv[2];

  int ppid = atoi(winpid);
  if (!ppid) {
    fprintf(stderr, "invalid process ID '%s'\n", winpid);
    return 1;
  }
  HANDLE parent_process = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, ppid);
  if (parent_process == NULL) {
    fprintf(stderr, "failed to open the parent process '%s'\n", winpid);
    return 1;
  }

  int exit_code = 0;
  BOOL terminate = FALSE;
  while (!terminate) {
    FILE* f = fopen(filename, "r");
    if (!f) {
      fprintf(stderr, "failed to open the file '%s'\n", filename);
      terminate = TRUE;
      exit_code = 1;
      break;
    }
    unlink(filename);
    for (;;) {
      if (!is_process_alive(parent_process)) {
        terminate = TRUE;
        break;
      }
      if (is_file(filename)) break; // reopen

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
