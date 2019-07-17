#!/bin/bash

function ble/history:bash/resolve-multiline/.worker {
  local apos=\'
  local HISTTIMEFORMAT=__ble_ext__
  builtin history | ble/bin/awk -v apos="$apos" '
    BEGIN {
      n = 0;

      TMPBASE = ENVIRON["TMPBASE"];
      filename_source = TMPBASE ".sh";

      q = apos;
      Q = apos "\\" apos apos;

      print "builtin history -c" > filename_source;
      multiline_count = 0;
      modification_count = 0;

      read_section_count = 0;
    }

    function write_scalar(line) {
      scalar_array[scalar_count++] = line;
    }
    function write_complex(value) {
      write_flush();
      print "builtin history -s -- " value > filename_source;
    }
    function write_flush(_, i, text, filename) {
      if (scalar_count == 0) return;
      if (scalar_count >= 2) {
        filename_section = TMPBASE "." read_section_count++ ".part";
        for (i = 0; i < scalar_count; i++)
          print scalar_array[i] > filename_section;
        print "builtin history -r " filename_section > filename_source;
      } else {
        for (i = 0; i < scalar_count; i++) {
          text = scalar_array[i];
          gsub(/'$apos'/, Q, text);
          print "builtin history -s -- " q text q > filename_source;
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
      print "builtin history -a /dev/null" > filename_source
      print "multiline_count=" multiline_count;
      print "modification_count=" modification_count;
    }
  '
}
function ble/history:bash/resolve-multiline {
  local -x TMPBASE=$_ble_base_run/$$.history.multiline-resolve
  local multiline_count=0 modification_count=0
  eval -- $(ble/history:bash/resolve-multiline/.worker 2>/dev/null)
  if ((modification_count)); then
     local HISTCONTROL= HISTSIZE= HISTIGNORE=
     time source "$TMPBASE.sh"
  fi
}
ble/history:bash/resolve-multiline
