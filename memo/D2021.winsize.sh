#!/bin/bash

(
  winsz1() { local sz; ble/util/assign-words sz 'stty size'; LINES=${sz[0]} COLUMNS=${sz[1]}; }
  winsz2() { local sc; ble/util/assign sc 'resize'; builtin eval -- "$sc"; }
  winsz3() { local sz; ble/util/assign-words sz 'tput lines cols'; LINES=${sz[0]} COLUMNS=${sz[1]}; }
  ble-measure winsz1
  ble-measure winsz2
  ble-measure winsz3

  # (:) で LINES, COLUMNS が更新されるのは bash >= 4.3 のみ。今回は
  # bash-5.2 に対する wa を考えているので気にしなくて良い。
  winsz4() { local sz; ble/util/assign-words sz '"$BASH" -O checkwinsize -c "(:);echo \"\$LINES \$COLUMNS\""'; LINES=${sz[0]} COLUMNS=${sz[1]}; }
  winsz4b() { local sz; ble/util/assign sz '"$BASH" -O checkwinsize -c "(:);echo \"LINES=\$LINES COLUMNS=\$COLUMNS\""'; builtin eval -- "$sz"; }
  ble-measure winsz4
  ble-measure winsz4b

  # winsz4b() { local sz; ble/util/assign sz '"$BASH" -O checkwinsize -c "(:);echo \"LINES=\$LINES COLUMNS=\$COLUMNS\""'; builtin eval -- "$sz"; declare -p sz LINES COLUMNS; }
  # LINES= COLUMNS= winsz4b


  # winsz3 > winsz1 > winsz2 > winsz4 > winsz4b の順に速い。
)
