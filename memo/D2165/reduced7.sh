#!/usr/bin/env bash
enable -f ~/opt/bash/dev/lib/bash/fdflags fdflags

exec 50>1.txt          # disable=#D0857
fdflags -s +cloexec 50
exec 50>2.txt          # disable=#D0857
echo hello >&50
ls -l 1.txt 2.txt
