#!/usr/bin/env bash

if [[ ${BLE_VERSION-} ]]; then
  fname=memo/D2207.measure-local.txt
  rm -rf "$fname"
  blehook POSTEXEC='bleopt debug_xtrace='
  bleopt debug_xtrace_ps4='+[$EPOCHREALTIME $BASH_SOURCE:$LINENO${FUNCNAME:+ (${#FUNCNAME[*]} $FUNCNAME)}] '
  ble/widget/insert-string "echo $EPOCHSECONDS"
  bleopt debug_xtrace="$fname"
  return "$?"
fi

input_file=${1:-memo/D2207.measure-local.txt}
sed -ni.bk '\:ble-decode/\.hook 13$:,$p' "$input_file"

< "$input_file" gawk '
  BEGIN {
    # Only shows the levels that took more than this time.
    THRESHOLD_DURATION = 0.5; # [msec]
  }

  function s_trunc(str, len) {
    return length(str) > len ? substr(str, 1, len - 3) "..." : str;
  }

  function flush_cmd(level, now, _, dur_msec, prev_cmd, prev_source, prev_lineno, prev_func, line, child, i, n) {
    if (g_record[level] == "") return;

    start_time = g_record[level, "epoch"]
    end_time = now;
    dur_msec = (end_time - start_time) * 1000;

    prev_cmd = s_trunc(g_record[level], 80);
    gsub(/[\x00-\x1F]/ ,"?", prev_cmd);

    prev_source = g_record[level, "source"];
    prev_lineno = g_record[level, "lineno"];
    prev_func = g_record[level, "func"];
    if (prev_cmd == "???") {
      prev_source = "";
    } else if (prev_source == "" && prev_func == "") {
      prev_source = sprintf(" [(global):%d]", prev_lineno);
    } else {
      prev_source = sprintf(" [%s:%d (%s)]", prev_source, prev_lineno, prev_func);
    }

    n = 0 + g_record[level, "#child"];

    g_record[level] = "";
    g_record[level, "#child"] = 0;

    if (dur_msec < THRESHOLD_DURATION) return;

    line = sprintf("%17.6f %7.3fms %2d  __tree__\x1b[1m%s\x1b[;34m%s\x1b[m", start_time, dur_msec, level, prev_cmd, prev_source);
    for (i = 0; i < n; i++) {
      child = g_record[level, "child", i];
      gsub(/__tree__/, i < n - 1 ? "&|  " : "&   ", child);
      sub(/__tree__.../, "__tree__+- ", child);
      line = line "\n" child;
    }

    if (level > g_min_level) {
      if (g_record[level - 1] == "") {
        g_record[level - 1] = "???";
        g_record[level - 1, "epoch"] = start_time;
        g_record[level - 1, "#child"] = 0;
      }
      i = 0 + g_record[level - 1, "#child"];
      g_record[level - 1, "child", i] = line;
      g_record[level - 1, "#child"] = i + 1;
    } else {
      gsub(/__tree__/, "", line);
      print line;
    }
  }

  function flush_level(level, now) {
    for (; g_level >= level; g_level--)
      flush_cmd(g_level, now);
    g_level = level;
  }

  match($0, /^(\+*)\[([0-9.]+) ([^:[:space:]]*):([0-9]*)( \(([0-9]+) ([^()]*)\))?\] (.*)$/, m) {
    eval_level = m[1];
    epoch = 0.0 + m[2];
    source = m[3];
    lineno = m[4];
    func_level = 0 + m[6];
    func_name = m[7];
    cmd = m[8];

    level = length(eval_level) + func_level;
    flush_level(level, epoch);

    if (g_min_level == "" || g_min_level > level)
      g_min_level = level;

    g_record[level] = cmd;
    g_record[level, "epoch"] = epoch;
    g_record[level, "source"] = source;
    g_record[level, "lineno"] = lineno;
    g_record[level, "func"] = func_name;
  }

  END { flush_level(1, epoch); }
'
