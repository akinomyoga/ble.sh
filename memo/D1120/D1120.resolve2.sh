#!/bin/bash

function ble/history:bash/resolve-multiline/.worker {
  local apos=\'
  local HISTTIMEFORMAT=__ble_ext__
  local -x HISTORY_SOURCE=$1
  local -x dev_stdin_available=0
  [[ -r /dev/stdin && ! -d /dev/stdin ]] && dev_stdin_available=1
  builtin history $arg_count | ble/bin/awk -v apos="$apos" '
    BEGIN {
      n = 0;

      FILE_HISTORY = ENVIRON["HISTORY_SOURCE"];
      dev_stdin_available = ENVIRON["dev_stdin_available"];
      q = apos;
      Q = apos "\\" apos apos;

      print "builtin history -c" > FILE_HISTORY;
      multiline_count = 0;
      modification_count = 0;
    }

    function write_scalar(line) {
      scalar_array[scalar_count++] = line;
    }
    function write_complex(value) {
      write_flush();
      print "builtin history -s -- " value > FILE_HISTORY;
    }
    function write_flush(_, i, text) {
      if (scalar_count == 0) return;
      if (dev_stdin_available && scalar_count >= 8) {
        text = scalar_array[0];
        for (i = 1; i < scalar_count; i++)
          text = text "\n" scalar_array[i];
        gsub(/'$apos'/, Q, text);
        print "builtin history -r /dev/stdin <<< " q text q > FILE_HISTORY;
      } else {
        for (i = 0; i < scalar_count; i++) {
          text = scalar_array[i];
          gsub(/'$apos'/, Q, text);
          print "builtin history -s -- " q text q > FILE_HISTORY;
        }
      }
      scalar_count = 0;
    }

    function flush_line() {
      if (n < 1) return;

      if (entry ~ /^eval -- \$'$apos'([^'$apos'\\]|\\.)*'$apos'$/) {
        multiline_count++;
        modification_count++;
        write_complex(substr(entry, 9));
      } else if (n > 1) {
        multiline_count++;
        gsub(/'$apos'/, Q, entry);
        write_complex(q entry q);
      } else {
        write_scalar(entry);
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
      write_flush();
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
