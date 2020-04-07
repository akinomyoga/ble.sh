#!/bin/bash

HISTFILE=A.txt

# echo A:$(builtin history 1)
# shopt -s histappend
# history -a
# echo B:$(builtin history 1)
# history -r
# echo C:$(builtin history 1)

# echo A:$(builtin history 1)
# shopt -s histappend
# history -n
# echo B:$(builtin history 1)

# builtin history 1; echo $?
# builtin history -s echo hello
# builtin history 1; echo $?

#------------------------------------------------------------------------------
# history -r が与える影響

function history-read-another-file.bashrc {
  # これを実行すると B.txt, A.txt の両方が読み取られる。
  HISTFILE=A.txt
  history -r B.txt
}

function history-read-same-file.bashrc {
  # これを実行すると A.txt が2回読み込まれる。
  HISTFILE=A.txt
  history -r A.txt
}

function history-read-default-file.bashrc {
  # これを実行しても A.txt が2回読み込まれる。
  HISTFILE=A.txt
  history -r
}

#------------------------------------------------------------------------------
# history -c が与える影響

function history-clear.bashrc {
  HISTFILE=A.txt
  history -c
}
history-clear.bashrc
