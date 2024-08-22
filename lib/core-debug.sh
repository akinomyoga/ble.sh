# -*- mode: sh; mode: sh-bash -*-

## @fn ble/debug/setdbg
function ble/debug/setdbg {
  ble/bin/rm -f "$_ble_base_run/dbgerr"
  local ret
  ble/util/readlink /proc/self/fd/3 3>&1
  ln -s "$ret" "$_ble_base_run/dbgerr"
}
## @fn ble/debug/print text
function ble/debug/print {
  if [[ -e $_ble_base_run/dbgerr ]]; then
    ble/util/print "$1" >> "$_ble_base_run/dbgerr"
  else
    ble/util/print "$1" >&2
  fi
}
## @fn ble/debug/leakvar#check
##   [デバグ用] 宣言忘れに依るグローバル変数の汚染位置を特定するための関数。
##
##   使い方
##
##   ```
##   eval "${_ble_debug_check_leak_variable//@var/ret}"
##   ...codes1...
##   ble/debug/leakvar#check ret tag1
##   ...codes2...
##   ble/debug/leakvar#check ret tag2
##   ...codes3...
##   ble/debug/leakvar#check ret tag3
##   ```
_ble_debug_check_leak_variable='local @var=__t1wJltaP9nmow__'
function ble/debug/leakvar#reset {
  builtin eval "$1=__t1wJltaP9nmow__"
}
function ble/debug/leakvar#check {
  local ext=$?
  if [[ ${!1} != __t1wJltaP9nmow__ ]] && ble/variable#is-global "$1"; then
    local IFS=$_ble_term_IFS
    ble/util/print "$1=${!1}:${*:2} [${FUNCNAME[*]:1:5}]" >> ~/a.txt # DEBUG_LEAKVAR
    builtin eval "$1=__t1wJltaP9nmow__"
  fi
  return "$?"
}
function ble/debug/leakvar#list {
  local _ble_local_exclude_file=${_ble_base_repository:-$_ble_base}/make/debug.leakvar.exclude-list.txt
  if [[ ! -f $_ble_local_exclude_file ]]; then
    ble/util/print "$_ble_local_exclude_file: not found." >&2
    return 1
  fi
  set | ble/bin/grep -Eavf "$_ble_local_exclude_file" | ble/bin/grep -Eao '^[[:alnum:]_]+='
  return 0
}

function ble/debug/print-variables/.append {
  local q=\' Q="'\''"
  _ble_local_out=$_ble_local_out"$1='${2//$q/$Q}'"
}
function ble/debug/print-variables/.append-array {
  local ret; ble/string#quote-words "${@:2}"
  _ble_local_out=$_ble_local_out"$1=($ret)"
}
function ble/debug/print-variables {
  (($#)) || return 0

  local flags= tag= arg
  local -a _ble_local_vars=()
  while (($#)); do
    arg=$1; shift
    case $arg in
    (-t) tag=$1; shift ;;
    (-*) ble/util/print "print-variables: unknown option '$arg'" >&2
         flags=${flags}e ;;
    (*) ble/array#push _ble_local_vars "$arg" ;;
    esac
  done
  [[ $flags == *e* ]] && return 1

  local _ble_local_out= _ble_local_var=
  [[ $tag ]] && _ble_local_out="$tag: "
  ble/util/unlocal flags tag arg
  for _ble_local_var in "${_ble_local_vars[@]}"; do
    if ble/is-array "$_ble_local_var"; then
      builtin eval -- "ble/debug/print-variables/.append-array \"\$_ble_local_var\" \"\${$_ble_local_var[@]}\""
    else
      ble/debug/print-variables/.append "$_ble_local_var" "${!_ble_local_var}"
    fi
    _ble_local_out=$_ble_local_out' '
  done
  ble/debug/print "${_ble_local_out%' '}"
}

_ble_debug_stopwatch=()
function ble/debug/stopwatch/start {
  ble/array#push _ble_debug_stopwatch "${EPOCHREALTIME:-$SECONDS.000000}"
}
function ble/debug/stopwatch/stop {
  local end=${EPOCHREALTIME:-$SECONDS.000000}
  if local ret; ble/array#pop _ble_debug_stopwatch; then
    local usec=$(((${end%%[.,]*}-${ret%%[,.]*})*1000000+(10#0${end#*[.,]}-10#0${ret#*[,.]})))
    printf '[%3d.%06d sec] %s\n' "$((usec/1000000))" "$((usec%1000000))" "$1"
  else
    printf '[---.------ sec] %s\n' "$1"
  fi
}

_ble_debug_profiler_magic=__GdWfuwABAUmlg__
_ble_debug_profiler_prefix=
_ble_debug_profiler_original_xtrace=
_ble_debug_profiler_original_xtrace_ps4=
function ble/debug/profiler/start {
  [[ ! $_ble_debug_profiler_prefix ]] || return 1
  if ((_ble_bash<50000)); then
    ble/util/print "ble.sh: profiler is only supported in Bash 5.0+." >&2
    return 2
  fi

  local prefix=${1:-prof.$$}
  [[ $prefix == /* ]] || prefix=$PWD/$prefix
  _ble_debug_profiler_prefix=$prefix

  _ble_debug_profiler_original_xtrace=$bleopt_debug_xtrace
  _ble_debug_profiler_original_xtrace_ps4=$bleopt_debug_xtrace_ps4
  bleopt debug_xtrace="$prefix.xtrace"
  bleopt debug_xtrace_ps4='+${#BASH_LINENO[@]} ${BASHPID:-$$} ${EPOCHREALTIME:-SECONDS} ${FUNCNAME:-(global)} ${LINENO:--} ${BASH_SOURCE:--} '"$_ble_debug_profiler_magic"' '

  blehook EXIT!=ble/debug/profiler/stop
}

function ble/debug/profiler/stop {
  [[ $_ble_debug_profiler_prefix ]] || return 1
  local prefix=$_ble_debug_profiler_prefix
  _ble_debug_profiler_prefix=
  bleopt debug_xtrace="$_ble_debug_profiler_original_xtrace"
  bleopt debug_xtrace_ps4="$_ble_debug_profiler_original_xtrace_ps4"

  # awk
  local -a awk_args=()
  local opts=$bleopt_debug_profiler_opts ret

  # debug_profiler_opts='line'
  local -x profiler_line_output=
  local -x profiler_line_html=
  if ble/opts#extract-last-optarg "$opts" line; then
    local file=$prefix.line.txt
    [[ -s $file ]] && ble/array#push awk_args mode=line_stat "$file"

    profiler_line_output=$file.part
    [[ $ret == html ]] &&
      profiler_line_html=$prefix.line.html
  fi

  # debug_profiler_opts='func'
  local -x profiler_func_output=
  local -x profiler_func_html=
  if ble/opts#extract-last-optarg "$opts" func; then
    local file=$prefix.func.txt
    [[ -s $file ]] && ble/array#push awk_args mode=func_stat "$file"
    profiler_func_output=$file.part
    [[ $ret == html ]] &&
      profiler_func_html=$prefix.func.html
  fi

  # debug_profiler_opts='tree'
  local -x profiler_tree_output=
  local -x profiler_tree_threshold_duration=
  if [[ :$opts: == *:tree:* ]]; then
    profiler_tree_output=$prefix.tree.txt
    profiler_tree_threshold_duration=${bleopt_debug_profiler_tree_threshold:-1.0} # [ms]
  fi

  # input file
  local f1=$prefix.xtrace
  ble/array#push awk_args mode=xtrace "$f1"
  local nline
  ble/util/print "ble/debug/profiler: counting lines..." >&2
  ble/util/assign-words nline 'ble/bin/wc -l "$f1" 2>/dev/null'
  ble/util/print $'\e[A\rble/debug/profiler: counting lines... '"$nline" >&2

  # nawk becomes unacceptably slow when there is a long line. It seems to scale
  # as O(N^2). If mawk/gawk is available, we prefer mawk/gawk to nawk.
  local awk=ble/bin/awk
  if ble/is-function ble/bin/mawk; then
    awk=ble/bin/mawk
  elif ble/is-function ble/bin/gawk; then
    awk=ble/bin/gawk
  fi

  "$awk" -v magic="$_ble_debug_profiler_magic" -v nline="$nline" '
    BEGIN {
      xtrace_debug_enabled = 1;
      print "ble/debug/profiler: collecting information..." >"/dev/stderr";
      if (nline) progress_interval = int(nline / 100);

      ipid = 0;
      ilabel = 0;
      ifname = 0;
      _usec_sec0 = "";

      lines_initialize();
      funcs_initialize();
      tree_initialize();
    }

    function to_percentage(value) {
      value *= 100;
      if (value >= 100) return sprintf("%d%%", int(value));
      if (value >= 10) return sprintf("%.2f%%", value);
      if (value >= 0.1) return sprintf("%.3f%%", value);
      if (value >= 0.0001) return sprintf(".%04d%%", int(value * 10000));
      return "0.0%";
    }

    function pids_register(pid) {
      if (pid_mark[pid] == "") {
        pid_mark[pid] = ipid;
        pids[ipid++] = pid;
      }
    }

    function pids_clear() {
      ipid = 0;
      delete pids;
      delete pid_mark;
    }

    function parse_usec(text, _, sec, usec) {
      sec = text;
      usec = 0;
      if (sub(/[.,].*/, "", sec)) {
        usec = text
        sub(/^.*[.,]0*/, "", usec);
      }

      if (_usec_sec0 == "")
        _usec_sec0 = sec;
      sec -= _usec_sec0;
      return sec * 1000000 + usec;
    }

    ## @var[out] level depth pid epoch usec fname label command
    function parse_line(_, s) {
      s = $1;
      level = gsub(/\+/, "", s);
      depth = 1 + (s > 0 ? s : 0);
      level += depth - 1;
      pid = $2;
      epoch = $3;
      usec = parse_usec($3);

      fname = $4;
      lineno = $5;
      source = $6;
      for (i = 7; $i != magic && i <= NF; i++)
        source = source " " $i;
      label = sprintf("\x1b[35m%s\x1b[36m (%s:\x1b[32m%s\x1b[36m):\x1b[m", source, fname, lineno);
      command = "";
      if ($i == magic) {
        command = $(++i);
        for (i++; i <= NF; i++)
          command = command " " $i;
      }
    }

    #--------------------------------------------------------------------------
    # util

    function str_strip_ansi(str) {
      gsub(/\x1b\[[ -?]*[@-~]/, "", str);
      gsub(/\x1b[ -\/]*[0-~]/, "", str);
      gsub(/[\x01-\x1F\x7F]/, "", str);
      return str;
    }

    function str_html_escape(str) {
      gsub(/&/, "\\&amp;", str);
      gsub(/</, "\\&lt;", str);
      gsub(/>/, "\\&gt;", str);
      return str;
    }

    function str_ansi_escape(str) {
      if (str ~ /[\x01-\x1F]/) {
        gsub(/\x1b/, "\x1b[7m^[\x1b[27m", str);
        gsub(/\x07/, "\x1b[7m^G\x1b[27m", str);
        gsub(/\x08/, "\x1b[7m^H\x1b[27m", str);
        gsub(/\x09/, "\x1b[7m^I\x1b[27m", str);
        gsub(/\x0a/, "\x1b[7m^J\x1b[27m", str);
        gsub(/\x0b/, "\x1b[7m^K\x1b[27m", str);
        gsub(/\x0c/, "\x1b[7m^L\x1b[27m", str);
        gsub(/\x0d/, "\x1b[7m^M\x1b[27m", str);
        gsub(/[\x01-\x1A\x1C-\x1F]/ ,"?", str);
      }
      return str;
    }

    #--------------------------------------------------------------------------
    # line_stat

    function lines_initialize() {
      c_lines_output = ENVIRON["profiler_line_output"];
      c_lines_enabled = c_lines_output != "";
      if (!c_lines_enabled) return;
      c_lines_html = ENVIRON["profiler_line_html"];
    }

    function lines_level_push(pid, level, usec, label, command, _, lv) {
      if (!line_stat[label, "count"]++)
        labels[ilabel++] = label;

      lines_level_pop(pid, level, usec);

      # debug
      #for (lv = ilevel[pid] + 1; lv < level; lv++)
      #  if (stk[pid, lv, "label"] != "")
      #    print "unexpected label[" lv "] = (" stk[pid, lv, "label"] ") ilevel=" ilevel[pid] "->" level >"/dev/stderr";

      stk[pid, level, "label"] = label;
      stk[pid, level, "begin"] = usec;
      stk[pid, level, "child"] = 0.0;
      stk[pid, level, "allstep_count"] = 0;
      stk[pid, level, "substep_count"] = 0;
      stk[pid, level, "substep_time"] = 0.0;
      stk[pid, level, "command"] = command;
      ilevel[pid] = level;
    }

    function lines_level_getParent(pid, lv) {
      for (lv--; lv >= 1; lv--)
        if (stk[pid, lv, "label"] != "") break;
      return lv;
    }

    function lines_level_pop(pid, level, usec, _, lv, label, elapsed, plv) {
      for (lv = ilevel[pid]; lv >= level; lv--) {
        label = stk[pid, lv, "label"];
        stk[pid, lv, "label"] = "";
        if (label == "") continue;

        elapsed = usec - stk[pid, lv, "begin"];
        if (elapsed < 0) {
          #print "[debug] negative time: " NR ": " $0 >"/dev/stderr";
          elapsed = 0.0;
        }

        line_stat[label, "total"] += elapsed;
        line_stat[label, "child"] += stk[pid, lv, "child"];
        if (lv >= 3)
          stk[pid, lv - 2, "child"] += elapsed;

        line_stat[label, "allstep_count"] += stk[pid, lv, "allstep_count"];
        line_stat[label, "substep_count"] += stk[pid, lv, "substep_count"];
        line_stat[label, "substep_time"] += stk[pid, lv, "substep_time"];
        if ((plv = lines_level_getParent(pid, lv))) {
          stk[pid, plv, "allstep_count"] += 1 + stk[pid, lv, "allstep_count"];
          stk[pid, plv, "substep_count"]++;
          stk[pid, plv, "substep_time"] += elapsed;
        }

        max_time = line_stat[label, "max_time"];
        if (max_time == "" || elapsed > max_time) {
          line_stat[label, "max_command"] = stk[pid, lv, "command"];
          line_stat[label, "max_time"] = elapsed;
          line_stat[label, "max_child"] = stk[pid, lv, "child"];
        }
      }
      ilevel[pid] = lv;
    }

    function lines_text_header(_, line) {
      line = sprintf("# %6s %8s %8s", "count", "subcount", "allcount");
      line = line sprintf(" %10s %-6s %10s %-6s %10s", "total_msec", "TOTAL%", "self_msec", "SELF%", "child_msec");
      line = line sprintf(" %10s %10s %10s", "max_msec", "max_self", "max_child");
      printf("%s %s%s\n", line, "\x1b[35mSOURCE\x1b[36m (FUNCNAME):\x1b[32mLINENO\x1b[36m:\x1b[m", "COMMAND") > c_lines_output;
    }

    function lines_text_print(info, _, line) {
      line = sprintf("%8d %8d %8d", info["count"], info["substep_count"], info["allstep_count"]);
      line = line sprintf(" %10.3f %-6s %10.3f %-6s %10.3f", info["total_time"], info["total_time_percentage"], info["total_self"], info["total_self_percentage"], info["total_child"]);
      line = line sprintf(" %10.3f %10.3f %10.3f", info["max_time"], info["max_self"], info["max_child"]);
      printf("%s %s%s\n", line, info["label"], info["command"]) > c_lines_output;
    }

    function lines_html_header(_, line) {
      line = sprintf("<!DOCTYPE html>\n");
      line = line sprintf("<title>ble.sh xtrace profiling result</title>\n");
      line = line sprintf("<style>table,td,th{border-collapse:collapse;border:1px solid black}td{max-width:40em;}</style>\n");
      line = line sprintf("<table>\n");
      line = line sprintf("<tr>\n");
      line = line sprintf("  <th rowspan=2>count</th>\n");
      line = line sprintf("  <th rowspan=2>substep</th>\n");
      line = line sprintf("  <th rowspan=2>allstep</th>\n");
      line = line sprintf("  <th colspan=3>total (msec)</th>\n");
      line = line sprintf("  <th colspan=3>average (msec)</th>\n");
      line = line sprintf("  <th colspan=3>max (msec)</th>\n");
      line = line sprintf("  <th rowspan=2>command</th>\n");
      line = line sprintf("  <th rowspan=2>location</th>\n");
      line = line sprintf("</tr>\n");
      line = line sprintf("<tr>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>self</th>\n");
      line = line sprintf("  <th>child</th>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>self</th>\n");
      line = line sprintf("  <th>child</th>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>self</th>\n");
      line = line sprintf("  <th>child</th>\n");
      line = line sprintf("</tr>\n");
      printf("%s", line) > c_lines_html;
    }

    function lines_html_print(info, _, line, label) {
      label = str_strip_ansi(info["label"]);
      sub(/:$/, "", label);
      line = sprintf("<tr>\n");
      line = line sprintf("  <td>%d</td>\n", info["count"]);
      line = line sprintf("  <td>%d</td>\n", info["substep_count"]);
      line = line sprintf("  <td>%d</td>\n", info["allstep_count"]);
      line = line sprintf("  <td>%.3f</td>\n", info["total_time"]);
      line = line sprintf("  <td>%.3f</td>\n", info["total_self"]);
      line = line sprintf("  <td>%.3f</td>\n", info["total_child"]);
      line = line sprintf("  <td>%.3f</td>\n", info["average_time"]);
      line = line sprintf("  <td>%.3f</td>\n", info["average_self"]);
      line = line sprintf("  <td>%.3f</td>\n", info["average_child"])
      line = line sprintf("  <td>%.3f</td>\n", info["max_time"]);
      line = line sprintf("  <td>%.3f</td>\n", info["max_self"]);
      line = line sprintf("  <td>%.3f</td>\n", info["max_child"]);
      line = line sprintf("  <td>%s</td>\n", str_html_escape(info["command"]));
      line = line sprintf("  <td>%s</td>\n", str_html_escape(label));
      line = line sprintf("</tr>\n");
      printf("%s", line) > c_lines_html;
    }

    function lines_html_footer() {
      printf("</table>\n") > c_lines_html;
    }

    function lines_save(_, i, label, count, info, total_time) {
      lines_text_header();
      if (c_lines_html) lines_html_header();

      total_time = 0.0;
      for (i = 0; i < ilabel; i++) {
        label = labels[i];
        total_time += line_stat[label, "total"] - line_stat[label, "child"];
      }
      total_time *= 0.001;

      for (i = 0; i < ilabel; i++) {
        label = labels[i];
        count = line_stat[label, "count"];

        info["count"] = count;
        info["allstep_count"] = line_stat[label, "allstep_count"];
        info["substep_count"] = line_stat[label, "substep_count"];
        info["substep_time"] = line_stat[label, "substep_time"] * 0.001;

        info["total_time"] = line_stat[label, "total"] * 0.001;
        info["total_child"] = line_stat[label, "child"] * 0.001;
        info["total_self"] = info["total_time"] - info["total_child"];
        info["total_time_percentage"] = to_percentage(info["total_time"] / total_time);
        info["total_self_percentage"] = to_percentage(info["total_self"] / total_time);
        info["average_time"] = info["total_time"] / count;
        info["average_self"] = info["total_self"] / count;
        info["average_child"] = info["total_child"] / count
        info["max_time"] = line_stat[label, "max_time"] * 0.001;
        info["max_child"] = line_stat[label, "max_child"] * 0.001;
        info["max_self"] = info["max_time"] - info["max_child"];

        info["label"] = label;
        info["command"] = line_stat[label, "max_command"];

        lines_text_print(info);
        if (c_lines_html) lines_html_print(info);
      }

      if (c_lines_html) lines_html_footer();
    }

    function lines_load_line(_, i, s, label, old_max_time, new_max_time) {
      s = substr($0, index($0, "\x1b[35m"));
      i = index(s, "\x1b[m");
      label = substr(s, 1, i + 2);
      if (!line_stat[label, "count"])
        labels[ilabel++] = label;

      line_stat[label, "count"] += $1;
      line_stat[label, "substep_count"] += $2;
      line_stat[label, "allstep_count"] += $3;
      line_stat[label, "substep_time"] += 0.0; # not saved
      line_stat[label, "total"] += int($4 * 1000 + 0.5);
      line_stat[label, "child"] += int($8 * 1000 + 0.5);

      old_max_time = line_stat[label, "max_time"];
      new_max_time = int($9 * 1000 + 0.5);
      if (old_max_time == "" || new_max_time > old_max_time) {
        line_stat[label, "max_command"] = substr(s, i + 3);
        line_stat[label, "max_time"] = new_max_time;
        line_stat[label, "max_child"] = int($11 * 1000 + 0.5);
      }
    }

    function lines_finalize() {
      if (c_lines_enabled)
        lines_save();
    }

    #--------------------------------------------------------------------------
    # func_stat

    function funcs_initialize() {
      c_funcs_output = ENVIRON["profiler_func_output"];
      c_funcs_enabled = c_funcs_output != "";
      if (!c_funcs_enabled) return;
      c_funcs_html = ENVIRON["profiler_func_html"];
    }

    function funcs_depth_push(pid, depth, usec, fname, source, _, old_depth) {
      if (!func_stat[fname, "mark"]++)
        fnames[ifname++] = fname;

      # old_depth = idepth[pid];
      if (funcs_depth_pop(pid, depth, usec)) {
        func_stk[pid, depth, "fname"] = fname;
        func_stk[pid, depth, "begin"] = usec;
        # if (depth > old_depth && proc[pid, "time"])
        #   func_stk[pid, depth, "begin"] = proc[pid, "time"];
        func_stk[pid, depth, "child"] = 0.0;
        func_stk[pid, depth, "allcall_count"] = 0;
        func_stk[pid, depth, "subcall_count"] = 0;
        func_stk[pid, depth, "source"] = source;
        idepth[pid] = depth;
      }
    }

    function funcs_depth_getParent(pid, dep) {
      for (dep--; dep >= 1; dep--)
        if (func_stk[pid, dep, "fname"] != "") break;
      return dep;
    }

    function funcs_depth_pop(pid, depth, usec, fname, _, dp, label, elapsed, pdp) {
      for (dp = idepth[pid]; dp >= depth; dp--) {
        if (dp == depth && fname == func_stk[pid, dp, "fname"]) {
          idepth[pid] = dp;
          return 0; # 前の関数の続き
        }

        fname = func_stk[pid, dp, "fname"];
        func_stk[pid, dp, "fname"] = "";
        if (fname == "") continue;

        elapsed = usec - func_stk[pid, dp, "begin"];
        if (elapsed < 0) elapsed = 0.0;

        func_stat[fname, "count"]++;
        func_stat[fname, "total"] += elapsed;
        func_stat[fname, "child"] += func_stk[pid, dp, "child"];
        func_stat[fname, "allcall_count"] += func_stk[pid, dp, "allcall_count"];
        func_stat[fname, "subcall_count"] += func_stk[pid, dp, "subcall_count"];
        if ((pdp = funcs_depth_getParent(pid, dp))) {
          func_stk[pid, pdp, "child"] += elapsed;
          func_stk[pid, pdp, "allcall_count"] += 1 + func_stk[pid, dp, "allcall_count"];
          func_stk[pid, pdp, "subcall_count"]++;
        }

        func_stat[fname, "source"] = func_stk[pid, dp, "source"]; # always overwrite
        max_time = func_stat[fname, "max_time"];
        if (max_time == "" || elapsed > max_time) {
          func_stat[fname, "max_time"] = elapsed;
          func_stat[fname, "max_child"] = func_stk[pid, dp, "child"];
        }
      }
      idepth[pid] = dp;
      return 1;
    }

    function funcs_text_header(_, line) {
      line = sprintf("# %6s %8s %8s", "count", "subcall", "allcall");
      line = line sprintf(" %10s %-6s %10s %-6s %10s", "total_msec", "TOTAL%", "self_msec", "SELF%", "child_msec");
      line = line sprintf(" %10s %10s %10s", "max_msec", "max_self", "max_child");
      printf("%s %s (\x1b[35m%s\x1b[m)\n", line, "FUNCNAME", "SOURCE") > c_funcs_output;
    }

    function funcs_text_print(info, _, line) {
      line = sprintf("%8d %8d %8d", info["count"], info["subcall_count"], info["allcall_count"]);
      line = line sprintf(" %10.3f %-6s %10.3f %-6s %10.3f", info["total_time"], info["total_time_percentage"], info["total_self"], info["total_self_percentage"], info["total_child"]);
      line = line sprintf(" %10.3f %10.3f %10.3f", info["max_time"], info["max_self"], info["max_child"]);
      printf("%s %s (\x1b[35m%s\x1b[m)\n", line, info["fname"], info["source"]) > c_funcs_output;
    }

    function funcs_html_header(_, line) {
      line = sprintf("<!DOCTYPE html>\n");
      line = line sprintf("<title>ble.sh xtrace profiling result</title>\n");
      line = line sprintf("<style>table,td,th{border-collapse:collapse;border:1px solid black}td{max-width:40em;}</style>\n");
      line = line sprintf("<table>\n");
      line = line sprintf("<tr>\n");
      line = line sprintf("  <th rowspan=2>count</th>\n");
      line = line sprintf("  <th rowspan=2>subcall</th>\n");
      line = line sprintf("  <th rowspan=2>allcall</th>\n");
      line = line sprintf("  <th colspan=3>total (ms)</th>\n");
      line = line sprintf("  <th colspan=3>self (ms)</th>\n");
      line = line sprintf("  <th colspan=2>child (ms)</th>\n");
      line = line sprintf("  <th rowspan=2>function</th>\n");
      line = line sprintf("  <th rowspan=2>location</th>\n");
      line = line sprintf("</tr>\n");
      line = line sprintf("<tr>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>%%</th>\n");
      line = line sprintf("  <th>max</th>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>%%</th>\n");
      line = line sprintf("  <th>max</th>\n");
      line = line sprintf("  <th>sum</th>\n");
      line = line sprintf("  <th>max</th>\n");
      line = line sprintf("</tr>\n");
      printf("%s", line) > c_funcs_html;
    }
    function funcs_html_print(info, _, line) {
      line = sprintf("<tr>\n");
      line = line sprintf("  <td>%s</td><td>%s</td><td>%s</td>\n", info["count"], info["subcall_count"], info["allcall_count"]);
      line = line sprintf("  <td>%s</td><td>%s</td><td>%s</td>\n", info["total_time"], info["total_time_percentage"], info["max_time"]);
      line = line sprintf("  <td>%s</td><td>%s</td><td>%s</td>\n", info["total_self"], info["total_self_percentage"], info["max_self"]);
      line = line sprintf("  <td>%s</td><td>%s</td>\n", info["total_child"], info["max_child"]);
      line = line sprintf("  <td><code>%s</code></td><td>%s</td>\n", info["fname"], info["source"]);
      line = line sprintf("</tr>\n");
      printf("%s", line) > c_funcs_html;
    }
    function funcs_html_footer() {
      printf("</table>\n") > c_funcs_html;
    }

    function funcs_save(_, i, fname, count, info, total_time) {
      funcs_text_header();
      if (c_funcs_html) funcs_html_header();

      total_time = 0.0;
      for (i = 0; i < ifname; i++) {
        fname = fnames[i];
        total_time += func_stat[fname, "total"] - func_stat[fname, "child"];
      }
      total_time *= 0.001;

      for (i = 0; i < ifname; i++) {
        fname = fnames[i];
        count = func_stat[fname, "count"];

        info["count"] = count;
        info["allcall_count"] = func_stat[fname, "allcall_count"];
        info["subcall_count"] = func_stat[fname, "subcall_count"];

        info["total_time"] = func_stat[fname, "total"] * 0.001;
        info["total_child"] = func_stat[fname, "child"] * 0.001;
        info["total_self"] = info["total_time"] - info["total_child"];
        info["total_time_percentage"] = to_percentage(info["total_time"] / total_time);
        info["total_self_percentage"] = to_percentage(info["total_self"] / total_time);
        info["average_time"] = info["total_time"] / count;
        info["average_self"] = info["total_self"] / count;
        info["average_child"] = info["total_child"] / count
        info["max_time"] = func_stat[fname, "max_time"] * 0.001;
        info["max_child"] = func_stat[fname, "max_child"] * 0.001;
        info["max_self"] = info["max_time"] - info["max_child"];

        info["fname"] = fname;
        info["source"] = func_stat[fname, "source"];

        funcs_text_print(info);
        if (c_funcs_html) funcs_html_print(info);
      }
      if (c_funcs_html) funcs_html_footer();
    }

    function funcs_load_line(_, fname, i, s, old_max_time, new_max_time) {
      fname = $12;
      if (!func_stat[fname, "mark"]) {
        fnames[ifname++] = fname;
        func_stat[fname, "mark"]++;
      }

      # extract source
      i = index($0, "\x1b[35m");
      if (i > 0) {
        s = substr($0, i + 5);
        i = index(s, "\x1b[m");
        func_stat[fname, "source"] = substr(s, 1, i - 1);
      }

      func_stat[fname, "count"] += $1;
      func_stat[fname, "subcall_count"] += $2;
      func_stat[fname, "allcall_count"] += $3;
      func_stat[fname, "total"] += int($4 * 1000 + 0.5);
      func_stat[fname, "child"] += int($8 * 1000 + 0.5);

      old_max_time = func_stat[fname, "max_time"];
      new_max_time = int($9 * 1000 + 0.5);
      if (old_max_time == "" || new_max_time > old_max_time) {
        func_stat[fname, "max_time"] = new_max_time;
        func_stat[fname, "max_child"] = int($11 * 1000 + 0.5);
      }
    }

    function funcs_finalize() {
      if (c_funcs_enabled)
        funcs_save();
    }

    #--------------------------------------------------------------------------

    function tree_initialize() {
      c_tree_output = ENVIRON["profiler_tree_output"];
      c_tree_enabled = c_tree_output != "";
      if (!c_tree_enabled) return;

      c_tree_threshold_duration = ENVIRON["profiler_tree_threshold_duration"] * 1000;
      g_tree_min_level = "";
    }

    function tree_flush_command(level, now_usec, _, start_time, clk_start, clk_end, dur_usec, prev_cmd, prev_source, prev_lineno, prev_func, line, child, i, n) {
      if (g_tree_record[level] == "") return;

      start_time = g_tree_record[level, "epoch"];
      clk_start = g_tree_record[level, "start"];
      clk_end = now_usec;
      dur_usec = clk_end - clk_start;

      prev_cmd = str_ansi_escape(g_tree_record[level]);

      prev_source = g_tree_record[level, "source"];
      prev_lineno = g_tree_record[level, "lineno"];
      prev_func = g_tree_record[level, "func"];
      if (prev_cmd == "???") {
        prev_source = "";
      } else if (prev_source == "" && prev_func == "") {
        prev_source = sprintf(" [(global):%d]", prev_lineno);
      } else {
        prev_source = sprintf(" [%s:%d (%s)]", prev_source, prev_lineno, prev_func);
      }

      n = 0 + g_tree_record[level, "#child"];

      g_tree_record[level] = "";
      g_tree_record[level, "#child"] = 0;

      if (dur_usec < c_tree_threshold_duration) return;

      line = sprintf("%17.6f %10.3fms %2d  __tree__\x1b[1m%s\x1b[;34m%s\x1b[m", start_time, dur_usec * 0.001, level, prev_cmd, prev_source);
      for (i = 0; i < n; i++) {
        child = g_tree_record[level, "child", i];
        gsub(/__tree__/, i < n - 1 ? "&|  " : "&   ", child);
        sub(/__tree__.../, "__tree__+- ", child);
        line = line "\n" child;
      }

      if (level > g_tree_min_level) {
        if (g_tree_record[level - 1] == "") {
          g_tree_record[level - 1] = "???";
          g_tree_record[level - 1, "start"] = start_time;
          g_tree_record[level - 1, "start"] = clk_start;
          g_tree_record[level - 1, "#child"] = 0;
        }
        i = 0 + g_tree_record[level - 1, "#child"];
        g_tree_record[level - 1, "child", i] = line;
        g_tree_record[level - 1, "#child"] = i + 1;
      } else {
        gsub(/__tree__/, "", line);
        print line >> c_tree_output;
      }
    }

    function tree_flush_level(level, now_usec) {
      for (; g_tree_level >= level; g_tree_level--)
        tree_flush_command(g_tree_level, now_usec);
      g_tree_level = level;
    }

    function tree_process_line(level, epoch, usec, source, lineno, funcname, command) {
      tree_flush_level(level, usec);

      if (g_tree_min_level == "" || g_tree_min_level > level)
        g_tree_min_level = level;

      g_tree_record[level] = command;
      g_tree_record[level, "epoch"] = epoch;
      g_tree_record[level, "start"] = usec;
      g_tree_record[level, "source"] = source;
      g_tree_record[level, "lineno"] = lineno;
      g_tree_record[level, "func"] = funcname;
      g_tree_last_usec = usec;
    }

    function tree_finalize() {
      if (c_tree_enabled)
        tree_flush_level(1, g_tree_last_usec);
    }

    #--------------------------------------------------------------------------

    function flush_stack(_, i) {
      for (i = 0; i < ipid; i++) {
        if (c_lines_enabled) lines_level_pop(pids[i], 1, proc[pids[i], "time"]);
        if (c_funcs_enabled) funcs_depth_pop(pids[i], 1, proc[pids[i], "time"]);
      }
      pids_clear();
    }

    mode == "line_stat" { if ($0 ~ /^['"$_ble_term_space"']*[^#'"$_ble_term_space"']/) lines_load_line(); next; }
    mode == "func_stat" { if ($0 ~ /^['"$_ble_term_space"']*[^#'"$_ble_term_space"']/) funcs_load_line(); next; }

    progress_interval && ++iline % progress_interval == 0 {
      print "\x1b[A\rble/debug/profiler: collecting information... " int((iline * 100) / nline) "%" >"/dev/stderr";
    }

    /^\+/ && index($0, magic) {
      if (!xtrace_debug_enabled) next;

      parse_line();
      if (fname == "(global)") {
        # flush on user input
        if (command ~ /^(ble-decode\/.hook|_ble_decode_hook) [0-9]+$/) flush_stack();

        label = command;
        sub(/^['"$_ble_term_space"']+|['"$_ble_term_space"'].*/, "", label);
        label = sprintf("\x1b[35m%s\x1b[36m:\x1b[32m%s\x1b[36m (%s):\x1b[m", source, lineno, label);
      }

      # register "pid" and "label" to the lists
      pids_register(pid);
      if (c_lines_enabled)
        lines_level_push(pid, level, usec, label, command);
      if (c_funcs_enabled)
        funcs_depth_push(pid, depth, usec, fname, source);
      if (c_tree_enabled)
        tree_process_line(level, epoch, usec, source, lineno, fname, command);
      proc[pid, "time"] = usec;
      next;
    }

    /^---- \[.*\] ble\/base\/xtrace\/restore/ {
      flush_stack();
      xtrace_debug_enabled = 0;
    }
    /^---- \[.*\] ble\/base\/xtrace\/adjust/ {
      xtrace_debug_enabled = 1;
    }

    END {
      flush_stack();
      print "ble/debug/profiler: writing result..." >"/dev/stderr";
      lines_finalize();
      funcs_finalize();
      tree_finalize();
    }
  ' "${awk_args[@]}" || return "$?"

  local -a files_to_remove
  files_to_remove=("$f1")

  if [[ $profiler_line_output == *.part ]]; then
    local file=${profiler_line_output%.part}
    {
      LANG=C ble/bin/grep '^#' "$file.part"
      LANG=C ble/bin/grep -v '^#' "$file.part" | ble/bin/sort -nrk4
    } >| "$file" &&
      ble/array#push files_to_remove "$file.part"
  fi

  if [[ $profiler_func_output == *.part ]]; then
    local file=${profiler_func_output%.part}
    {
      LANG=C ble/bin/grep '^#' "$file.part"
      LANG=C ble/bin/grep -v '^#' "$file.part" | ble/bin/sort -nrk4
    } >| "$file" &&
      ble/array#push files_to_remove "$file.part"
  fi

  ble/bin/rm -f "${files_to_remove[@]}"
}
