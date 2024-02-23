#!/usr/bin/env bash
exec 51>1.txt                                          # disable=#D0857
exec 10>&-; { exec 52<&10; } 51</dev/null; exec 51<&52 # disable=#D2164
exec 50>&51                                            # disable=#D0857
echo "===="
exec 50>2.txt                                          # disable=#D0857
echo "===="
echo hi >&50
ls -l 1.txt 2.txt

# In Linux:
#
# $ strace -e trace=%desc bash D2165.sh
# openat(AT_FDCWD, "1.txt", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3
# fcntl(51, F_GETFD)                      = -1 EBADF (不正なファイル記述子です)
# dup2(3, 51)                             = 51
# close(3)                                = 0
# fcntl(10, F_GETFD)                      = -1 EBADF (不正なファイル記述子です)
# close(10)                               = -1 EBADF (不正なファイル記述子です)
# openat(AT_FDCWD, "/dev/null", O_RDONLY) = 3
# fcntl(51, F_GETFD)                      = 0
# fcntl(51, F_DUPFD, 10)                  = 10
# fcntl(51, F_GETFD)                      = 0
# fcntl(10, F_SETFD, FD_CLOEXEC)          = 0
# dup2(3, 51)                             = 51
# close(3)                                = 0
# fcntl(52, F_GETFD)                      = -1 EBADF (不正なファイル記述子です)
# dup2(10, 52)                            = 52
# fcntl(10, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(52, F_SETFD, FD_CLOEXEC)          = 0
# dup2(10, 51)                            = 51
# fcntl(10, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(51, F_SETFD, FD_CLOEXEC)          = 0
# fcntl(51, F_SETFD, 0)                   = 0
# close(10)                               = 0
# fcntl(51, F_GETFD)                      = 0
# fcntl(51, F_DUPFD, 53)                  = 53
# fcntl(51, F_GETFD)                      = 0
# fcntl(53, F_SETFD, FD_CLOEXEC)          = 0
# dup2(52, 51)                            = 51
# fcntl(52, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(51, F_SETFD, FD_CLOEXEC)          = 0
# close(53)                               = 0
# fcntl(50, F_GETFD)                      = -1 EBADF (不正なファイル記述子です)
# dup2(51, 50)                            = 50
# fcntl(51, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(50, F_SETFD, FD_CLOEXEC)          = 0
# openat(AT_FDCWD, "2.txt", O_WRONLY|O_CREAT|O_TRUNC, 0666) = 3
# fcntl(50, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(50, F_DUPFD, 10)                  = 10
# fcntl(50, F_GETFD)                      = 0x1 (flags FD_CLOEXEC)
# fcntl(10, F_SETFD, FD_CLOEXEC)          = 0
# dup2(3, 50)                             = 50
# close(3)                                = 0
