#!/usr/bin/env bash

umask 022
shopt -s nullglob

function mkd {
  [[ -d $1 ]] || mkdir -p "$1"
}

function download {
  local url=$1 dst=$2
  if [[ ! -s $dst ]]; then
    [[ $dst == ?*/* ]] && mkd "${dst%/*}"
    if type wget &>/dev/null; then
      wget "$url" -O "$dst.part" && mv "$dst.part" "$dst"
    else
      echo "make_command: 'wget' not found." >&2
      exit 2
    fi
  fi
}

function sub:help {
  printf '%s\n' \
         'usage: make_command.sh SUBCOMMAND args...' \
         '' 'SUBCOMMAND' ''
  local sub
  for sub in $(declare -F | sed -n 's|^declare -[fx]* sub:\([^/]*\)$|\1|p'); do
    if declare -f sub:"$sub"/help &>/dev/null; then
      sub:"$sub"/help
    else
      printf '  %s\n' "$sub"
    fi
  done
  printf '\n'
}

#------------------------------------------------------------------------------

_ble_canvas_c2w_UnicodeUcdVersions=({4.1,5.{0,1,2},6.{0..3},{7..11}.0,12.{0,1},13.0,14.0,15.{0,1},16.0}.0)
_ble_canvas_c2w_UnicodeUcdVersion_latest=16.0.0
_ble_canvas_c2w_UnicodeEmojiVersion_latest=16.0

function sub:c2w {
  local version
  for version in "${_ble_canvas_c2w_UnicodeUcdVersions[@]}"; do
    local data=out/data/unicode-EastAsianWidth-$version.txt
    download http://www.unicode.org/Public/$version/ucd/EastAsianWidth.txt "$data"
    echo "__unicode_version__ $version"
    cat "$data"
  done | gawk '
    function lower_bound(arr, N, value, _, l, u, m) {
      l = 0;
      u = N - 1;
      while (u > l) {
        m = int((l + u) / 2);
        if (arr[m] < value)
          l = m + 1;
        else
          u = m;
      }
      return l;
    }
    function upper_bound(arr, N, value, _, l, u, m) {
      l = 0;
      u = N - 1;
      while (u > l) {
        m = int((l + u) / 2);
        if (arr[m] <= value)
          l = m + 1;
        else
          u = m;
      }
      return l;
    }
    function arr_range_inf(arr, N, value, _, r) {
      i = lower_bound(arr, N, value);
      if (i > 0 && value < arr[i]) i--;
      return i;
    }
    function arr_range_sup(arr, N, value, _, r) {
      i = upper_bound(arr, N, value);
      if (i + 1 < N && arr[i] < value) i++;
      return i;
    }

    function determine_width(EastAsianWidth, GeneralCategory) {
      if (GeneralCategory ~ /^(M[ne]|Cf)$/) return 0;

      if (EastAsianWidth == "A")
        eaw = cjkwidth;
      else if (EastAsianWidth == "W" || EastAsianWidth == "F")
        eaw = 2;
      else
        eaw = 1;

      if (GeneralCategory ~ /^(C[ncs]|Z[lp])$/)
        return -eaw;
      else
        return eaw;
    }

    BEGIN {
      cjkwidth = 3;
      iucsver = -1;
    }

    /^[[:blank:]]*(#|$)/ {next;}

    $1 == "__unicode_version__" {
      print "Processing ucsver " $2 > "/dev/stderr";
      ucsver = $2;
      iucsver++;
      for (code = 0; code < 0x110000; code++)
        table[iucsver, code] = -1;

      if ($2 ~ /^[0-9]+\.[0-9]+\.[0-9]*$/)
        sub(/\.[0-9]*$/, "", $2)
      g_version_name[iucsver] = $2;
      next;
    }

    function process_line(_, beg, end, eaw, gencat, w, code) {
      beg = end = 0;

      # EastAsianWidth.txt in Unicode 4.0..15.0.0 has the line form
      # "0021..0023;Na # Po"
      if ($2 == "#") {
        if (match($1, /^([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = beg + 1;
          eaw = m[2];
          gencat = $3;
        } else if (match($1, /^([0-9a-fA-F]+)\.\.([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = strtonum("0x" m[2]) + 1;
          eaw = m[3];
          gencat = $3;
        } else {
          print "unmached: " $0 >"/dev/stderr";
        }
      }

      # EastAsianWidth.txt in Unicode 15.1.0 has the line form
      # "0021..0023 ; Na # Po"
      if ($2 == ";" && $4 == "#") {
        if (match($1, /^([0-9a-fA-F]+)$/, m)) {
          beg = strtonum("0x" m[1]);
          end = beg + 1;
          eaw = $3;
          gencat = $5;
        } else if (match($1, /^([0-9a-fA-F]+)\.\.([0-9a-fA-F]+)$/, m)) {
          beg = strtonum("0x" m[1]);
          end = strtonum("0x" m[2]) + 1;
          eaw = $3;
          gencat = $5;
        } else {
          print "unmached: " $0 >"/dev/stderr";
        }
      }

      if (beg < end) {
        w = determine_width(eaw, gencat);
        for (code = beg; code < end; code++) table[iucsver, code] = w;
        next;
      }
    }
    { process_line(); }

    function combine_version(vermap_count, vermap_output, vermap_v2i, c, v, value) {
      vermap_count = 0;
      vermap_output = "";
      for (c = 0; c < 0x110000; c++) {
        value = table[0, c];
        for (v = 1; v <= iucsver; v++)
          value = value " " table[v, c];

        if (vermap_v2i[value] == "") {
          vermap_v2i[value] = vermap_count++;
          vermap_output = vermap_output "  " value "\n"
        }
        table[c] = vermap_v2i[value];
      }
      print "_ble_unicode_c2w_UnicodeVersionCount=" iucsver + 1;
      print "_ble_unicode_c2w_UnicodeVersionMapping=(";
      printf("%s", vermap_output);
      print ")";
    }

    function output_table(_, output_values, output_ranges, code, c0, v0, ranges, irange, p, c1, c2) {
      ISOLATED_THRESHOLD = 1; # 2 や 3 も試したが 1 が最も compact

      irange = 0;
      output_values = " ";
      output_ranges = " ";
      for (code = 0; code < 0x110000; ) {
        c0 = code++;
        v0 = table[c0];

        while (code < 0x110000 && table[code] == v0) code++;

        if (code - c0 <= ISOLATED_THRESHOLD) {
          for (; c0 < code; c0++)
            output_values = output_values " [" c0 "]=" v0;
        } else {
          ranges[irange++] = c0;
          output_values = output_values " [" c0 "]=" v0;
          output_ranges = output_ranges " " c0;
        }
      }
      ranges[irange++] = 0x110000;
      output_ranges = output_ranges " " 0x110000;

      sub(/^[[:blank:]]+/, "", output_values);
      sub(/^[[:blank:]]+/, "", output_ranges);
      print "_ble_unicode_c2w=(" output_values ")"
      print "_ble_unicode_c2w_ranges=(" output_ranges ")"

      output_index = " ";
      for (c1 = 0; c1 < 0x20000; c1 = c2) {
        c2 = c1 + 256;
        i1 = arr_range_inf(ranges, irange, c1);
        i2 = arr_range_sup(ranges, irange, c2);

        # assertion
        if (!(ranges[i1] <= c1 && c2 <= ranges[i2]))
          print "Error " ranges[i1] "<=" c1,c2 "<=" ranges[i2] > "/dev/stderr";

        if (i2 - i1 == 1)
          output_index = output_index " " table[c1];
        else
          output_index = output_index " " i1 ":" i2;
      }
      for (c1; c1 < 0x110000; c1 = c2) {
        c2 = c1 + 0x1000;
        i1 = arr_range_inf(ranges, irange, c1);
        i2 = arr_range_sup(ranges, irange, c2);
        if (i2 - i1 == 1)
          output_index = output_index " " table[c1];
        else
          output_index = output_index " " i1 ":" i2;
      }

      sub(/^[[:blank:]]+/, "", output_index);
      print "_ble_unicode_c2w_index=(" output_index ")";
    }

    function generate_version_function() {
      print "function ble/unicode/c2w/version2index {";
      print "  case $1 in";
      for (v = 0; v <= iucsver; v++)
        print "  (" g_version_name[v] ") ret=" v " ;;";
      print "  (*) return 1 ;;";
      print "  esac";
      print "}"
      print "_ble_unicode_c2w_version=" iucsver;
    }

    END {
      print "Combining Unicode versions..." > "/dev/stderr";
      combine_version();
      print "Generating tables..." > "/dev/stderr";
      output_table();
      generate_version_function();
    }
  ' "$data" | ifold -w 131 --spaces --no-text-justify --indent=.. > src/canvas.c2w.sh
}

function sub:convert-custom-c2w {
  local -x name=$1
  gawk '
    match($0, /^[[:blank:]]*U\+([[:xdigit:]]+)[[:blank:]]+([0-9]+)/, m) {
      code = strtonum("0x" m[1]);
      w = m[2];

      g_output_values = g_output_values " [" code "]=" w;
      g_output_ranges = g_output_ranges " " code;
    }
    END {
      name = ENVIRON["name"];
      print name "=(" substr(g_output_values, 2) ")";
      # print name "_ranges=(" substr(g_output_ranges, 2) ")";
      print name "_ranges=(\"${!" name "[@]}\")"
    }
  ' | ifold -w 131 --spaces --no-text-justify --indent=..
}

function sub:emoji {
  local -x name=${1:-_ble_unicode_EmojiStatus}

  local unicode_version=$_ble_canvas_c2w_UnicodeEmojiVersion_latest
  local cache=out/data/unicode-emoji-$unicode_version.txt
  download "https://unicode.org/Public/emoji/$unicode_version/emoji-test.txt" "$cache"

  local -x q=\'
  local versions=$(gawk 'match($0, / E([0-9]+\.[0-9]+)/, m) > 0 { print m[1]; }' "$cache" | sort -Vu | tr '\n' ' ')
  gawk -v versions="$versions" '
    BEGIN {
      NAME = ENVIRON["name"];
      q = ENVIRON["q"];

      EmojiStatus_None               = 0;
      EmojiStatus_FullyQualified     = 1;
      EmojiStatus_MinimallyQualified = 2;
      EmojiStatus_Unqualified        = 3;
      EmojiStatus_Component          = 4;
      print "_ble_unicode_EmojiStatus_None="               EmojiStatus_None;
      print "_ble_unicode_EmojiStatus_FullyQualified="     EmojiStatus_FullyQualified;
      print "_ble_unicode_EmojiStatus_MinimallyQualified=" EmojiStatus_MinimallyQualified;
      print "_ble_unicode_EmojiStatus_Unqualified="        EmojiStatus_Unqualified;
      print "_ble_unicode_EmojiStatus_Component="          EmojiStatus_Component;
    }

    function register_codepoint(char_code, char_emoji_version, char_qtype, _, iver) {
      iver = ver2iver[char_emoji_version];
      if (iver == "") {
        print "unknown version \"" char_emoji_version "\"" > "/dev/stderr";
        return;
      }

      g_code2qtype[char_code] = iver == 0 ? char_qtype : q "V>=" iver "?" char_qtype ":0" q;
      if (g_code2qtype[char_code + 1] == "")
        g_code2qtype[char_code + 1] = "0";
    }

    function register_RegionalIndicators(_, code) {
      for (code = 0x1F1E6; code <= 0x1F1FF; code++)
        register_codepoint(code, "0.6", EmojiStatus_FullyQualified);
    }

    BEGIN {
      split(versions, vers);
      nvers = length(vers);
      for (iver = 0; iver < nvers; iver++) {
        ver2iver[vers[iver + 1]] = iver;
        iver2ver[iver] = vers[iver + 1];
      }
      register_RegionalIndicators();
    }

    # 単一絵文字 (sequence でない) のみを登録する。
    match($0, / E([0-9]+\.[0-9]+)/, m) > 0 {
      if ($3 == "fully-qualified") {
        register_codepoint(strtonum("0x" $1), m[1], EmojiStatus_FullyQualified);
      } else if ($3 == "component") {
        register_codepoint(strtonum("0x" $1), m[1], EmojiStatus_Component);
      } else if ($3 == "unqualified") {
        register_codepoint(strtonum("0x" $1), m[1], EmojiStatus_Unqualified);
      }
    }

    function print_database(_, codes, qtypes, len, i, n, keys, code, qtype, prev_qtype) {

      # uniq g_code2qtype
      len = 0;
      prev_qtype = EmojiStatus_None;
      n = asorti(g_code2qtype, keys, "@ind_num_asc");
      for (i = 1; i <= n; i++) {
        code = int(keys[i]);
        qtype = g_code2qtype[code];
        if (qtype == "") qtype = EmojiStatus_None;
        if (qtype != prev_qtype) {
          codes[len] = code;
          qtypes[len] = qtype;
          len++;
        }
        prev_qtype = qtype;
      }

      output_values = "";
      output_ranges = "";
      prev_code = 0;
      prev_qtype = EmojiStatus_None;
      for (i = 0; i < len; i++) {
        code = codes[i];
        qtype = qtypes[i];

        if (i + 1 < len && (n = codes[i + 1]) - code <= 1) {
          # 孤立コード
          for (; code < n; code++)
            output_values = output_values " [" code "]=" qtype;

        } else if (qtype != prev_qtype) {
          output_values = output_values " [" code "]=" qtype;
          output_ranges = output_ranges " " code

          # 非孤立領域の範囲
          p = int(code);
          if (qtype == EmojiStatus_None) p--;
          if (p < 0x10000) {
            if (bmp_min == "" || p < bmp_min) bmp_min = p;
            if (bmp_max == "" || p > bmp_max) bmp_max = p;
          } else {
            if (smp_min == "" || p < smp_min) smp_min = p;
            if (smp_max == "" || p > smp_max) smp_max = p;
          }

          # 非孤立領域が BMP/SMP を跨がない事の確認
          if (prev_qtype != EmojiStatus_None && prev_code < 0x10000 && 0x10000 < code)
            print "\x1b[31mEmojiStatus_xmaybe: a BMP-SMP crossing range unexpected.\x1b[m" > "/dev/stderr";
          prev_code = code;
          prev_qtype = qtype;
        }
      }

      # printf("_ble_unicode_EmojiStatus_bmp_min=%-6d # U+%04X\n", bmp_min, bmp_min);
      # printf("_ble_unicode_EmojiStatus_bmp_max=%-6d # U+%04X\n", bmp_max, bmp_max);
      # printf("_ble_unicode_EmojiStatus_smp_min=%-6d # U+%04X\n", smp_min, smp_min);
      # printf("_ble_unicode_EmojiStatus_smp_max=%-6d # U+%04X\n", smp_max, smp_max);

      printf("_ble_unicode_EmojiStatus_xmaybe='$q'%d<=code&&code<=%d||%d<=code&&code<=%d'$q'\n", bmp_min, bmp_max, smp_min, smp_max);
      print NAME "=(" substr(output_values, 2) ")"
      print NAME "_ranges=(" substr(output_ranges, 2) ")";

    }

    function print_functions(_, iver) {
      print "function ble/unicode/EmojiStatus/version2index {";
      print "  case $1 in";
      for (iver = 0; iver < nvers; iver++)
        print "  (" iver2ver[iver] ") ret=" iver " ;;";
      print "  (*) return 1 ;;";
      print "  esac";
      print "}"
      print "_ble_unicode_EmojiStatus_version=" nvers - 1;
      print "bleopt/declare -n emoji_version " iver2ver[nvers - 1];
    }

    END {
      print_database();
      print_functions();
    }
  ' "$cache" | ifold -w 131 --spaces --no-text-justify --indent=.. > src/canvas.emoji.sh
}

function sub:GraphemeClusterBreak {
  #local unicode_version=latest base_url=http://www.unicode.org/Public/UCD/latest/ucd
  local unicode_version=$_ble_canvas_c2w_UnicodeUcdVersion_latest
  local base_url=https://www.unicode.org/Public/$unicode_version/ucd

  local cache=out/data/unicode-GraphemeBreakProperty-$unicode_version.txt
  download "$base_url/auxiliary/GraphemeBreakProperty.txt" "$cache"

  local cache2=out/data/unicode-emoji-data-$unicode_version.txt
  download "$base_url/emoji/emoji-data.txt" "$cache2"

  local cache3=out/data/unicode-GraphemeBreakTest-$unicode_version.txt
  download "$base_url/auxiliary/GraphemeBreakTest.txt" "$cache3"

  local cache4=out/data/unicode-DerivedCoreProperties-$unicode_version.txt
  download "$base_url/DerivedCoreProperties.txt" "$cache4"

  gawk '
    BEGIN {
      #ITEMS_PER_LINE = 6;
      MAX_COLUMNS = 160;
      Q = "'\''";
      out = "   ";
      out_length = 3;
      out_count = 0;
    }
    { sub(/[[:blank:]]*#.*$/, ""); sub(/[[:blank:]]+$/, ""); }
    $0 == "" {next}

    function out_flush() {
      if (!out_count) return;
      print out;
      out = "   ";
      out_length = 3;
      out_count = 0;
    }

    function process_case(line, _, m, i, b, str, ans) {
      i = b = 0;
      ans = "";
      str = "";
      while (match(line, /([÷×])[[:blank:]]*([[:xdigit:]]+)[[:blank:]]*/, m) > 0) {
        if (m[1] == "÷") b = i;
        str = str "\\U" m[2];
        ans = ans (ans == "" ? "" : ",") b;
        line = substr(line, RLENGTH + 1);
        i++;
      }
      n = i;
      if (line == "÷") {
        ans = ans (ans == "" ? "" : ",") i;
      } else
        print "GraphemeBreakTest.txt: Unexpected line (" $0 ")" >"/dev/stderr";

      ent = ans ":" Q str Q;
      entlen = length(ent) + 1

      if (out_length + entlen >= MAX_COLUMNS) out_flush();
      out = out " " ent;
      out_length += entlen;
      out_count++;
      #if (out_count % ITEMS_PER_LINE == 0) out_flush();
    }
    {
      gsub(/000D × 000A/, "000D ÷ 000A"); # Tailored
      process_case($0);
    }
    END { out_flush(); }
  ' "$cache3" > lib/test-canvas.GraphemeClusterTest.sh

  {
    echo '# __Grapheme_Cluster_Break__'
    cat "$cache"
    echo '# __Extended_Pictographic__'
    cat "$cache2"
    echo '# __Indic_Conjunct_Break__'
    cat "$cache4"
  } | gawk '
    BEGIN {
      # ble.sh 実装では元の GraphemeClusterBreak に以下の修正を加える。
      #
      # * CR/LF は独立した制御文字として扱う
      # * Extend の一部は InCB_Linker 及び InCB_Extend としている。Unicode
      #   15.1.0 で追加された Indic_Conjunct_Break (InCB) に依存した書記素クラ
      #   スター境界 (GR9c) に対応するため。ZWJ も \p{InCB=Extend} だが区別の為
      #   に ZWJ は ZWJ のままにする。
      # * サロゲートペアを処理する為にサロゲートペアも規則に含める。

      PropertyCount = 18;
      prop2v["Other"]              = Other              = 0;
      prop2v["CR"]                 = CR                 = 1;
      prop2v["LF"]                 = LF                 = 1;
      prop2v["Control"]            = Control            = 1;
      prop2v["ZWJ"]                = ZWJ                = 2;
      prop2v["Prepend"]            = Prepend            = 3;
      prop2v["Extend"]             = Extend             = 4;
      prop2v["SpacingMark"]        = SpacingMark        = 5;
      prop2v["Regional_Indicator"] = Regional_Indicator = 6;
      prop2v["L"]                  = L                  = 7;
      prop2v["V"]                  = V                  = 8;
      prop2v["T"]                  = T                  = 9;
      prop2v["LV"]                 = LV                 = 10;
      prop2v["LVT"]                = LVT                = 11;
      prop2v["Pictographic"]       = Pictographic       = 12;
      prop2v["InCB_Consonant"]     = InCB_Consonant     = 15;
      prop2v["InCB_Linker"]        = InCB_Linker        = 16;
      prop2v["InCB_Extend"]        = InCB_Extend        = 17;

      # [blesh extension] surrogate pair
      prop2v["HighSurrogate"] = HSG = 13;
      prop2v["LowSurrogate"]  = LSG = 14;

      for (key in prop2v) v2prop[prop2v[key]] = key;

      InCB_ZWJ_seen = 0;
    }

    function process_GraphemeClusterBreak(code, prop, _, v, m, b, e, i) {
      v = prop2v[prop];
      if (match(code, /([[:xdigit:]]+)\.\.([[:xdigit:]]+)/, m) > 0) {
        b = strtonum("0x" m[1]);
        e = strtonum("0x" m[2]);
      } else {
        b = e = strtonum("0x" code);
      }

      for (i = b; i <= e; i++)
        table[i] = v;

      if (e > max_code) max_code = e;
    }
    function process_ExtendedPictographic(_, m, b, e, i) {
      if (match($1, /([[:xdigit:]]+)\.\.([[:xdigit:]]+)/, m) > 0) {
        b = strtonum("0x" m[1]);
        e = strtonum("0x" m[2]);
      } else {
        b = e = strtonum("0x" $1);
      }

      for (i = b; i <= e; i++) {
        if (table[i])
          printf("Extended_Pictograph: U+%04X already has Grapheme_Cluster_Break Property '\''%s'\''.\n", i, v2prop[table[i]]) > "/dev/stderr";
        else
          table[i] = Pictographic;
      }
      if (e > max_code) max_code = e;
    }
    function process_IndicConjunctBreak(_, m, code, InCB, b, e, i) {
      if (match($0, /^([[:xdigit:].]+)[[:blank:]]*;[[:blank:]]*InCB[[:blank:]]*;[[:blank:]]*(Consonant|Extend|Linker)[[:blank:];#]/, m) > 0) {
        code = m[1];
        InCB = m[2];
        if (match(code, /^([[:xdigit:]]+)\.\.([[:xdigit:]]+)$/, m) > 0) {
          b = strtonum("0x" m[1]);
          e = strtonum("0x" m[2]);
        } else if (match(code, /^([[:xdigit:]]+)$/, m) > 0) {
          b = e = strtonum("0x" $1);
        } else {
          return;
        }

        for (i = b; i <= e; i++) {
          if (InCB == "Consonant") {
            if (table[i])
              printf("Indic_Conjunct_Break: U+%04X already has Grapheme_Cluster_Break Property '\''%s'\''.\n", i, v2prop[table[i]]) > "/dev/stderr";
            else
              table[i] = InCB_Consonant;
          } else if (InCB == "Linker") {
            if (table[i] != Extend) {
              printf("InCB=Linker: U+%04X has unexpected Grapheme_Cluster_Break Property '\''%s'\''.\n", i, v2prop[table[i]]) > "/dev/stderr";
            } else {
              table[i] = InCB_Linker;
            }
          } else if (InCB == "Extend") {
            if (table[i] == Extend) {
              table[i] = InCB_Extend;
            } else if (table[i] == ZWJ) {
              InCB_ZWJ_seen = 1;
            } else {
              printf("InCB=Extend: U+%04X has unexpected Grapheme_Cluster_Break Property '\''%s'\''.\n", i, v2prop[table[i]]) > "/dev/stderr";
            }
          }
        }

        if (e > max_code) max_code = e;
      }
    }

    /__Grapheme_Cluster_Break__/ { mode = "break"; }
    /__Extended_Pictographic__/ { mode = "picto"; }
    /__Indic_Conjunct_Break__/ { mode = "indic"; }
    /^[[:blank:]]*(#|$)/ {next;}
    mode == "break" && $2 == ";" { process_GraphemeClusterBreak($1, $3); }
    mode == "picto" && /Extended_Pictographic/ { process_ExtendedPictographic(); }
    mode == "indic" {
      process_IndicConjunctBreak();
      next;
    }

    function rule_add(i, j, value) {
      if (rule[i, j] != "") return;
      rule[i, j] = value;
    }
    function rule_initialize() {
      for (i = 0; i < PropertyCount; i++) {
        rule_add(Control, i, 0);
        rule_add(i, Control, 0);
      }
      rule_add(L, L, 1);
      rule_add(L, V, 1);
      rule_add(L, LV, 1);
      rule_add(L, LVT, 1);
      rule_add(LV, V, 1);
      rule_add(LV, T, 1);
      rule_add(V, V, 1);
      rule_add(V, T, 1);
      rule_add(LVT, T, 1);
      rule_add(T, T, 1);
      for (i = 0; i < PropertyCount; i++) {
        rule_add(i, Extend, 1);
        rule_add(i, InCB_Linker, 1); # \p{InCB=Linker} are all Extend
        rule_add(i, InCB_Extend, 1); # \p{InCB=Extend} are all Extend but ZWJ
        rule_add(i, ZWJ, 1);
      }
      for (i = 0; i < PropertyCount; i++) {
        rule_add(i, SpacingMark, 2);
        rule_add(Prepend, i, 2);
      }
      rule_add(ZWJ, Pictographic, 3);
      rule_add(Regional_Indicator, Regional_Indicator, 4);
      rule_add(InCB_Linker, InCB_Consonant, 6);
      rule_add(InCB_Extend, InCB_Consonant, 6);
      rule_add(ZWJ, InCB_Consonant, 6);

      # [blesh extension] surrogate pair
      rule_add(HSG, LSG, 5);
    }
    function rule_print(_, i, j, t, out) {
      out = "";
      for (i = 0; i < PropertyCount; i++) {
        out = out " ";
        for (j = 0; j < PropertyCount; j++) {
          t = rule[i, j];
          if (t == "") t = 0;
          out = out " " t;
        }
        out = out "\n";
      }
      print "_ble_unicode_GraphemeClusterBreak_rule=(";
      print out ")";
    }

    # 孤立した物は先に出力
    function print_isolated(_, out, c, i, j, v) {
      out = "";
      count = 0;
      for (i = 0; i <= max_code; i = j) {
        j = i + 1;
        while (j <= max_code && table[j] == table[i]) j++;
        if (j - i <= 2) {
          v = table[i];
          if (v == "") v = 0;
          for (k = i; k < j; k++) {
            table[k] = "-";
            if (count++ % 16 == 0)
              out = out (out == "" ? "  " : "\n  ")
            out = out "[" k "]=" v " ";
          }
        }
      }
      print "_ble_unicode_GraphemeClusterBreak=("
      print "  # isolated Grapheme_Cluster_Break property (" count " chars)"
      print out;
    }
    function print_ranges(_, out1, c, i, j, v) {
      out1 = "";
      count1 = 0;
      count2 = 0;
      for (i = 0; i <= max_code; i = j) {
        j = i + 1;
        while (j <= max_code && table[j] == table[i] || table[j] == "-") j++;

        v = table[i];
        if (v == "") v = 0;

        if (count1++ % 16 == 0)
          out1 = out1 (out1 == "" ? "  " : "\n  ")
        out1 = out1 "[" i "]=" v " ";

        if (count2++ % 32 == 0)
          out2 = out2 (out2 == "" ? "  " : "\n  ")
        out2 = out2 i " ";
      }
      print "";
      print "  # Grapheme_Cluster_Break ranges (" count1 " ranges)"
      print out1;
      print ")"
      print "_ble_unicode_GraphemeClusterBreak_ranges=("
      print out2 (max_code+1);
      print ")"
    }

    function prop_print(_, key, i, prop) {
      print "_ble_unicode_GraphemeClusterBreak_Count=" PropertyCount;
      for (i = 0; i < PropertyCount; i++) {
        prop = v2prop[i];
        if (prop != "CR" && prop != "LF")
          print "_ble_unicode_GraphemeClusterBreak_" prop "=" i;
      }
    }

    END {
      # We asseme in canvas.sh that ZWJ is InCB=Extend.  In case where this
      # assumption is broken in future, we explicitly check it here.
      if (!InCB_ZWJ_seen) {
        printf("Indic_Conjunct_Break: warning: \\p{InCB=Extend} did not include ZWJ.") > "/dev/stderr";
      }

      process_GraphemeClusterBreak("D800..DBFF", "HighSurrogate");
      process_GraphemeClusterBreak("DC00..DFFF", "LowSurrogate");

      prop_print();

      print "_ble_unicode_GraphemeClusterBreak_MaxCode=" (max_code + 1);
      print_isolated();
      print_ranges();

      rule_initialize();
      rule_print();
    }
  ' | sed 's/[[:blank:]]\{1,\}$//' > src/canvas.GraphemeClusterBreak.sh
}

# currently unused
function sub:IndicConjunctBreak {
  #local unicode_version=latest base_url=http://www.unicode.org/Public/UCD/latest/ucd
  local unicode_version=$_ble_canvas_c2w_UnicodeUcdVersion_latest
  local base_url=https://www.unicode.org/Public/$unicode_version/ucd

  local cache=out/data/unicode-DerivedCoreProperties-$unicode_version.txt
  download "$base_url/DerivedCoreProperties.txt" "$cache"

  gawk -F '[[:blank:]]*[;#][[:blank:]]*' '
    BEGIN {
      PropertyCount = 4;
      prop2v["None"]      = None      = 0;
      prop2v["Linker"]    = Linker    = 1;
      prop2v["Consonant"] = Consonant = 2;
      prop2v["Extend"]    = Extend    = 3;
    }

    function process_IndicConjunctBreak(code, prop, _, v, m, b, e, i) {
      v = prop2v[prop];
      if (match(code, /([[:xdigit:]]+)\.\.([[:xdigit:]]+)/, m) > 0) {
        b = strtonum("0x" m[1]);
        e = strtonum("0x" m[2]);
      } else {
        b = e = strtonum("0x" code);
      }

      for (i = b; i <= e; i++)
        table[i] = v;

      if (e > max_code) max_code = e;
    }

    /^[[:blank:]]*(#|$)/ {next;}

    $2 == "InCB" { process_IndicConjunctBreak($1, $3); }

    # 孤立した物は先に出力
    function print_isolated(_, out, c, i, j, v) {
      out = "";
      count = 0;
      for (i = 0; i <= max_code; i = j) {
        j = i + 1;
        while (j <= max_code && table[j] == table[i]) j++;
        if (j - i <= 2) {
          v = table[i];
          if (v == "") v = 0;
          for (k = i; k < j; k++) {
            table[k] = "-";
            if (count++ % 16 == 0)
              out = out (out == "" ? "  " : "\n  ")
            out = out "[" k "]=" v " ";
          }
        }
      }
      print "_ble_unicode_IndicConjunctBreak=("
      print "  # isolated Indic_Conjunct_Break property (" count " chars)"
      print out;
    }
    function print_ranges(_, out1, c, i, j, v) {
      out1 = "";
      count1 = 0;
      count2 = 0;
      for (i = 0; i <= max_code; i = j) {
        j = i + 1;
        while (j <= max_code && table[j] == table[i] || table[j] == "-") j++;

        v = table[i];
        if (v == "") v = 0;

        if (count1++ % 16 == 0)
          out1 = out1 (out1 == "" ? "  " : "\n  ")
        out1 = out1 "[" i "]=" v " ";

        if (count2++ % 32 == 0)
          out2 = out2 (out2 == "" ? "  " : "\n  ")
        out2 = out2 i " ";
      }
      print "";
      print "  # Indic_Conjunct_Break ranges (" count1 " ranges)"
      print out1;
      print ")"
      print "_ble_unicode_IndicConjunctBreak_ranges=("
      print out2 (max_code+1);
      print ")"
    }

    function prop_print(_, key) {
      print "_ble_unicode_IndicConjunctBreak_Count=" PropertyCount;
      for (key in prop2v)
        print "_ble_unicode_IndicConjunctBreak_" key "=" prop2v[key];
    }

    END {
      prop_print();

      print "_ble_unicode_IndicConjunctBreak_MaxCode=" (max_code + 1);
      print_isolated();
      print_ranges();
    }
  ' "$cache" | sed 's/[[:blank:]]\{1,\}$//' > src/canvas.IndicConjunctBreak.sh
}

# currently unused
function sub:update-EastAsianWidth {
  local version
  for version in "${_ble_canvas_c2w_UnicodeUcdVersions[@]}"; do
    local data=out/data/unicode-EastAsianWidth-$version.txt
    download http://www.unicode.org/Public/$version/ucd/EastAsianWidth.txt "$data"
    gawk '
      /^[[:blank:]]*(#|$)/ {next;}

      BEGIN {
        prev_end = 0;
        prev_w = "";
        cjkwidth = 1;
      }

      function determine_width(eastAsianWidth, generalCategory, _, eaw) {
        if (generalCategory ~ /^(C[ncs]|Z[lp])$/)
          return -1;
        else if (generalCategory ~ /^(M[ne]|Cf)$/)
          return 0;
        else if (eastAsianWidth == "A")
          return cjkwidth;
        else if (eastAsianWidth == "W" || eastAsianWidth == "F")
          return 2;
        else
          return 1;
      }

      function register_width(beg, end, w) {
        if (end > beg && w != prev_w) {
          printf("U+%04X %s\n", beg, w);
          prev_w = w;
        }
        prev_end = end;
      }

      $2 == "#" {
        if (match($1, /^([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = beg + 1;
          eaw = m[2];
        } else if (match($1, /^([0-9a-fA-F]+)\.\.([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = strtonum("0x" m[2]) + 1;
          eaw = m[3];
        } else {
          next;
        }

        w = determine_width(eaw, $3);

        # Undefined characters
        register_width(prev_end, beg, 1);

        # Current range
        register_width(beg, end, w);
      }
      END {
        register_width(prev_end, 0x110000, 1);
      }
    ' "$data" > "out/data/c2w.eaw-$version.txt"

    gawk '
      function lower_bound(arr, N, value, _, l, u, m) {
        l = 0;
        u = N - 1;
        while (u > l) {
          m = int((l + u) / 2);
          if (arr[m] < value)
            l = m + 1;
          else
            u = m;
        }
        return l;
      }
      function upper_bound(arr, N, value, _, l, u, m) {
        l = 0;
        u = N - 1;
        while (u > l) {
          m = int((l + u) / 2);
          if (arr[m] <= value)
            l = m + 1;
          else
            u = m;
        }
        return l;
      }
      function arr_range_inf(arr, N, value, _, r) {
        i = lower_bound(arr, N, value);
        if (i > 0 && value < arr[i]) i--;
        return i;
      }
      function arr_range_sup(arr, N, value, _, r) {
        i = upper_bound(arr, N, value);
        if (i + 1 < N && arr[i] < value) i++;
        return i;
      }

      /^[[:blank:]]*(#|$)/ {next;}

      BEGIN {
        cjkwidth = 3;
        for (code = 0; code < 0x110000; code++) table[code] = -1;
      }

      function determine_width(eastAsianWidth, generalCategory) {
        if (generalCategory ~ /^(M[ne]|Cf)$/) return 0;

        if (eastAsianWidth == "A")
          eaw = cjkwidth;
        else if (eastAsianWidth == "W" || eastAsianWidth == "F")
          eaw = 2;
        else
          eaw = 1;

        if (generalCategory ~ /^(C[ncs]|Z[lp])$/)
          return -eaw;
        else
          return eaw;
      }

      $2 == "#" {
        if (match($1, /^([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = beg + 1;
          eaw = m[2];
        } else if (match($1, /^([0-9a-fA-F]+)\.\.([0-9a-fA-F]+);([^[:blank:]]+)/, m)) {
          beg = strtonum("0x" m[1]);
          end = strtonum("0x" m[2]) + 1;
          eaw = m[3];
        } else {
          next;
        }

        w = determine_width(eaw, $3);
        for (code = beg; code < end; code++)
          table[code] = w;
      }

      function dump_table(filename) {
        printf "" > filename;
        out = "";
        for (c = 0; c < 0x110000; c++) {
          out = out " " table[c];
          if ((c + 1) % 32 == 0) {
            print out >> filename;
            out = "";
          }
        }
        close(filename);
      }

      function output_table(_, output_values, output_ranges, code, c0, v0, ranges, irange, p, c1, c2) {
        ISOLATED_THRESHOLD = 1; # 2 や 3 も試したが 1 が最も compact

        irange = 0;
        output_values = " ";
        output_ranges = " ";
        for (code = 0; code < 0x110000; ) {
          c0 = code++;
          v0 = table[c0];

          while (code < 0x110000 && table[code] == v0) code++;

          if (code - c0 <= ISOLATED_THRESHOLD) {
            for (; c0 < code; c0++)
              output_values = output_values " [" c0 "]=" v0;
          } else {
            ranges[irange++] = c0;
            output_values = output_values " [" c0 "]=" v0;
            output_ranges = output_ranges " " c0;
          }
        }
        ranges[irange++] = 0x110000;
        output_ranges = output_ranges " " 0x110000;

        sub(/^[[:blank:]]+/, "", output_values);
        sub(/^[[:blank:]]+/, "", output_ranges);
        print "_ble_unicode_EastAsianWidth_c2w=(" output_values ")"
        print "_ble_unicode_EastAsianWidth_c2w_ranges=(" output_ranges ")"

        output_index = " ";
        for (c1 = 0; c1 < 0x20000; c1 = c2) {
          c2 = c1 + 256;
          i1 = arr_range_inf(ranges, irange, c1);
          i2 = arr_range_sup(ranges, irange, c2);

          # assertion
          if (!(ranges[i1] <= c1 && c2 <= ranges[i2]))
            print "Error " ranges[i1] "<=" c1,c2 "<=" ranges[i2] > "/dev/stderr";

          if (i2 - i1 == 1)
            output_index = output_index " " table[c1];
          else
            output_index = output_index " " i1 ":" i2;
        }
        for (c1; c1 < 0x110000; c1 = c2) {
          c2 = c1 + 0x1000;
          i1 = arr_range_inf(ranges, irange, c1);
          i2 = arr_range_sup(ranges, irange, c2);
          if (i2 - i1 == 1)
            output_index = output_index " " table[c1];
          else
            output_index = output_index " " i1 ":" i2;
        }

        sub(/^[[:blank:]]+/, "", output_index);
        print "_ble_unicode_EastAsianWidth_c2w_index=(" output_index ")";
      }

      END {
        output_table();
        dump_table("out/data/c2w.eaw-'"$version"'.dump");
      }

    ' "$data" | ifold -w 131 --spaces --no-text-justify --indent=.. > "out/data/c2w.eaw-$version.sh"
  done
}

# currently unused
function sub:update-GeneralCategory {
  local version
  for version in "${_ble_canvas_c2w_UnicodeUcdVersions[@]}"; do
    local data=out/data/unicode-UnicodeData-$version.txt
    download "http://www.unicode.org/Public/$version/ucd/UnicodeData.txt" "$data" || continue

    # 4.1 -> 401, 13.0 -> 1300, etc.
    local VER; IFS=. eval 'VER=($version)'
    printf -v VER '%d%02d' "${VER[0]}" "${VER[1]}"

    gawk -F ';' -v VER="$VER" '
      BEGIN {
        mode = 0;
        range_beg = 0;
        range_end = 0;
        range_cat = "";
        table = "";
        range = "";
      }

      function register_range(beg, end, cat, _, i) {
        # printf("%x %x %s\n", beg, end, cat);
        if (end - beg <= 2) {
          for (i = beg; i < end; i++)
            table = table " [" i "]=" cat;
        } else {
          range = range " " beg;
          table = table " [" beg "]=" cat;
        }
      }

      function close_range(){
        if (range_cat != "")
          register_range(range_beg, range_end, range_cat);
        if (code > range_end)
          register_range(range_end, code, "Cn");
      }

      {
        code = strtonum("0x" $1);
        cat = $3;

        if (mode == 1) {
          if (!($2 ~ /Last>/)) {
            print "Error: <..., First> is expected" > "/dev/stderr";
          } else if (range_cat != cat) {
            print "Error: mismatch of General_Category of First and Last." > "/dev/stderr";
          }
          range_end = code + 1;
          mode = 0;
        } else {
          if (code > range_end || range_cat != cat){
            close_range();
            range_beg = code;
            range_cat = cat;
          }
          range_end = code + 1;

          if ($2 ~ /First>/) {
            mode = 1;
          } else if ($2 ~ /Last>/) {
            print "Error: <..., Last> is unexpected" > "/dev/stderr";
          }
        }
      }

      END {
        code = 0x110000;
        close_range();

        print "_ble_unicode_GeneralCategory" VER "=(" substr(table, 2) ")";
        print "_ble_unicode_GeneralCategory" VER "_range=(" substr(range, 2) ")";
      }
    ' "$data" | ifold -w 131 --spaces --no-text-justify --indent=.. > "out/data/GeneralCategory.$version.txt"
  done
}

#------------------------------------------------------------------------------

if (($#==0)); then
  sub:help
elif declare -f sub:"$1" &>/dev/null; then
  sub:"$@"
else
  echo "unknown subcommand '$1'" >&2
  builtin exit 1
fi
