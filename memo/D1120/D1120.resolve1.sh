#!/bin/bash

function ble/history:bash/resolve-multiline/.worker {
  local apos=\'
  local HISTTIMEFORMAT=__ble_ext__
  local -x HISTORY_SOURCE=$1
  builtin history $arg_count | ble/bin/awk -v apos="$apos" '
    BEGIN {
      n = 0;
      hindex = 0;
      FILE_HISTORY = ENVIRON["HISTORY_SOURCE"];
      print "builtin history -c" > FILE_HISTORY;
      multiline_count = 0;
      modification_count = 0;
    }

    function flush_line() {
      if (n < 1) return;

      if (entry ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/) {
        multiline_count++;
        modification_count++;
        print "builtin history -s -- " substr(entry, 9) > FILE_HISTORY;
      } else {
        if (n > 1) multiline_count++;
        gsub(/'$apos'/, "'$apos'\\'$apos$apos'", entry);
        entry = apos entry apos;
        print "builtin history -s -- " entry > FILE_HISTORY;
      }

      n = 0;
      entry = "";
    }

    {
      if (sub(/^ *[0-9]+\*? +(__ble_ext__|\?\?)/, "", $0))
        flush_line();
      entry = ++n == 1 ? $0 : entry "\n" $0;
    }

    END {
      flush_line();
      print "builtin history -a /dev/null" > FILE_HISTORY
      print "multiline_count=" multiline_count;
      print "modification_count=" modification_count;
    }
  '
}
function ble/history:bash/resolve-multiline {
  local foutput=history_resolve_multiline.out
  local multiline_count=0 modification_count=0
  eval -- $(ble/history:bash/resolve-multiline/.worker "$foutput" 2>/dev/null)
  echo "modification_count=$modification_count"
  if ((modification_count)); then
     local HISTCONTROL= HISTSIZE= HISTIGNORE=
     time source "$foutput"
  fi
}
ble/history:bash/resolve-multiline
