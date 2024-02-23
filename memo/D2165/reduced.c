#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>

int main() {
  int fd1 = open("1.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644);
  if (fd1 < 0) {
    fprintf(stderr, "failed to open 1.txt\n");
    return 1;
  }
  int fd2 = dup2(fd1, 51);
  if (fd2 < 0) {
    fprintf(stderr, "failed to move <1.txt> to 51\n");
    return 1;
  }
  close(fd1);

  //fcntl(51, F_SETFD, FD_CLOEXEC);
  dup2(51, 50);

  fd1 = open("2.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644);
  if (fd1 < 0) {
    fprintf(stderr, "failed to open 2.txt\n");
    return 1;
  }
  fd2 = dup2(fd1, 50);
  if (fd2 < 0) {
    fprintf(stderr, "failed to move <2.txt> to 50\n");
    return 1;
  }
  close(fd1);

  write(50, "hi\n", 3);
  close(50);

  return 0;
}
