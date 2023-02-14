#!/bin/bash

function ble/complete/mandb/search-file/.check {
  local path=$1
  if [[ $path && -s $path ]]; then
    ret=$path
    return 0
  else
    return 1
  fi
}
function ble/complete/mandb/search-file {
  local command=$1

  # Try "man -w" first
  ble/complete/mandb/search-file/.check "$(man -w "$command" 2>/dev/null)" && return 0

  local manpath=${MANPATH:-/usr/share/man:/usr/local/share/man:/usr/local/man}
  ble/string#split manpath : "$manpath"
  local path
  for path in "${manpath[@]}"; do
    ble/complete/mandb/search-file/.check "$path/man1/$man.1.gz" && return 0
    ble/complete/mandb/search-file/.check "$path/man1/$man.1" && return 0
    ble/complete/mandb/search-file/.check "$path/man1/$man.8.gz" && return 0
    ble/complete/mandb/search-file/.check "$path/man1/$man.8" && return 0
  done
  return 1
}

ble/complete/mandb/search-file "${1:-grep}" || return 1
path=$ret

if [[ $ret == *.gz ]]; then
  gzip -cd "$path" #/usr/share/man/man1/grep.1.gz
else
  cat "$path"
fi |
  awk '
    BEGIN {
      g_key = "";
      g_desc = "";
      print ".TH __ble_ignore__ 1 __ble_ignore__ __ble_ignore__";
      print ".ll 9999"
    }
    function flush_topic() {
      if (g_key == "") return;
      print "__ble_key__";
      print ".TP";
      print g_key;
      print "";
      print "__ble_desc__";
      print "";
      print g_desc;
      print "";

      g_key = "";
      g_desc = "";
    }

    /^\.TP\y/ { flush_topic(); mode = "key"; next; }
    /^\.(SS|SH)\y/ { flush_topic(); next; }

    mode == "key" {
      g_key = $0;
      g_desc = "";
      mode = "desc";
      next;
    }
    mode == "desc" {
      if (g_desc != "") g_desc = g_desc "\n";
      g_desc = g_desc $0;
    }

    END { flush_topic(); }
  ' | groff -Tutf8 -man | awk '
    function process_pair(name, desc) {
      if (!(g_name ~ /^-/)) return;

      # FS (\034) は ble.sh で内部使用の為除外する。
      sep = "\x1b[1;91m:\x1b[m";
      #sep = "\034";
      if (g_name ~ /\034/) return;
      gsub(/\034/, "\x1b[7m^\\\x1b[27m", desc);

      n = split(name, names, /,[[:space:]]*/);
      sub(/(\.  |; ).*/, ".", desc);
      for (i = 1; i <= n; i++) {
        name = names[i];
        insert_suffix = " ";
        menu_suffix = "";
        if (match(name, /[[ =]/)) {
          m = substr(name, RSTART, 1);
          if (m == "=") {
            insert_suffix = "=";
          } else if (m == "[") {
            insert_suffix = "";
          }
          menu_suffix = substr(name, RSTART);
          name = substr(name, 1, RSTART - 1);
        }
        printf("%s" sep "%s" sep "%s" sep "%s\n", name, menu_suffix, insert_suffix, desc);
      }
    }

    function flush_pair() {
      if (g_name == "") return;
      if (g_name ~ /^-/) {
        process_pair(g_name, g_desc);
        #print "\x1b[1;94m" g_name "\x1b[0m";
        #print g_desc;
        #print "";
      }
      g_name = "";
      g_desc = "";
    }

    sub(/^[[:space:]]*__ble_key__/, "", $0) {
      flush_pair();
      mode = "key";
    }
    sub(/^[[:space:]]*__ble_desc__/, "", $0) {
      mode = "desc";
    }

    mode == "key" {
      line = $0;
      gsub(/\x1b\[[ -?]*[@-~]/, "", line); # CSI seq
      gsub(/\x1b[ -/]*[0-~]/, "", line); # ESC seq
      gsub(/\x0E/, "", line);
      gsub(/\x0F/, "", line);
      gsub(/^[[:space:]]*|[[:space:]]*$/, "", line);
      #gsub(/[[:space:]]+/, " ", line);
      if (line == "") next;
      if (g_name != "") g_name = g_name " ";
      g_name = g_name line;
    }

    mode == "desc" {
      line = $0;
      gsub(/^[[:space:]]*|[[:space:]]*$/, "", line);
      #gsub(/[[:space:]]+/, " ", line);
      if (line == "") {
        if (g_desc != "") mode = "";
        next;
      }
      if (g_desc != "") g_desc = g_desc " ";
      g_desc = g_desc line;
    }

    END { flush_pair(); }
  ' | sort -k 1
