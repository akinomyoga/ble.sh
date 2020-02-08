// This is MinGW Program

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

int main(int argc, char** argv) {
  if (0 != rename(argv[1], argv[2])) {
    perror("test2");
  }
  return 0;
}
