#!/usr/bin/env bash

function brightness/shuffled-string {
  local -a chars2 chars3=()
  chars2=({a..g})
  while ((${#chars2[@]})); do
    local i=$((RANDOM%${#chars2[@]}))
    chars3+=("${chars2[i]}")
    unset -v 'chars2[i]'
    chars2=("${chars2[@]}")
  done
  IFS= eval 'REPLY="${chars3[*]}"'
}

function brightness/prepare-sample-table {
  local i
  for i in {0..255}; do
    printf -v 'sample[i]' '\e[47;94m%03d \e[40;38;2;%d;%d;%dm %s \e[107m %s \e[0;47m' "$i" "$i" "$i" "$i" "${| brightness/shuffled-string; }" "${| brightness/shuffled-string; }"
  done
}

function brightness/output-sample-table {
  echo $'\e[47m\e[K\e[m'
  for ((y=0;y<28;y++)); do
    local line=
    for ((x=0;x<3;x++)); do
      ((i=(x*28+y)*3))
      line="${line:+$line | }${sample[i]}"
    done
    echo $'\e[47m '"$line"$'\e[47m \e[K\e[m'
  done
  echo $'\e[47m\e[K\e[m'
}

function sub:show-brightness-sample {
  brightness/prepare-sample-table
  brightness/output-sample-table
}

function sub:list-safe-colors {
  local -x c_output_type=ansi
  local -x c_Y_min=100
  local -x c_Y_max=174
  local -x c_filter_by_brightness=1
  local -x c_filter_by_cielab=0
  local -x c_deltaE=cie94

  local OPTIND=1 OPTARG="" OPTERR=0 opt
  while getopts ':y:Y:t:bBdDe:' opt "$@"; do
    case $opt in
    (y) c_Y_min=$OPTARG ;;
    (Y) c_Y_max=$OPTARG ;;
    (t)
      case $OPTARG in
      (ansi|markdown|html)
        c_output_type=$OPTARG ;;
      (*)
        printf 'list-safe-colors: -t: unrecognized output format "%s"\n' "$OPTARG" >&2
        return 2
      esac ;;
    (E)
      case $OPTARG in
      (cie76|cie94|ITP)
        c_deltaE=$OPTARG ;;
      (*)
        printf 'list-safe-colors: -E: unrecognized color distance "%s"\n' "$OPTARG" >&2
        return 2
      esac ;;
    (b) c_filter_by_brightness=1 ;;
    (B) c_filter_by_brightness=0 ;;
    (d) c_filter_by_cielab=1 ;;
    (D) c_filter_by_cielab=0 ;;
    *)
      printf 'list-safe-colors: usage error\n' >&2
      return 2
      ;;
    esac
  done
  shift "$((OPTIND - 1))"

  awk '
    function rgb2color(R, G, B) {
      return R * 0x10000 + G * 0x100 + B;
    }
    function gray2color(V) {
      return rgb2color(V, V, V);
    }
    function max(a, b) { return a >= b ? a : b; }

    function initialize_palette(table, _, inten) {
      inten[i] = 0;
      for (i = 1; i < 6; i++)
        inten[i] = 55 + 40 * i;

      table[ 0] = 0x000000;
      table[ 1] = 0x800000;
      table[ 2] = 0x008000;
      table[ 3] = 0x808000;
      table[ 4] = 0x000080;
      table[ 5] = 0x800080;
      table[ 6] = 0x008080;
      table[ 7] = 0xC0C0C0;
      table[ 8] = 0x808080;
      table[ 9] = 0xFF0000;
      table[10] = 0x00FF00;
      table[11] = 0xFFFF00;
      table[12] = 0x0000FF;
      table[13] = 0xFF00FF;
      table[14] = 0x00FFFF;
      table[15] = 0xFFFFFF;
      for (i = 0; i < 216; i++)
        table[i + 16] = rgb2color(inten[int(i / 36)], inten[int(i / 6) % 6], inten[i % 6]);
      for (i = 0; i < 24; i++)
        table[i + 232] = gray2color(10 * i + 8);
    }

    BEGIN {
      c_output_type = ENVIRON["c_output_type"];
      c_Y_min = ENVIRON["c_Y_min"] + 0;
      c_Y_max = ENVIRON["c_Y_max"] + 0;
      c_filter_by_brightness = ENVIRON["c_filter_by_brightness"] + 0;
      c_filter_by_cielab = ENVIRON["c_filter_by_cielab"] + 0;
      c_deltaE = ENVIRON["c_deltaE"];
      initialize_palette(g_index_colors);
    }

    function gamma_correction(value) {
      value /= 255.0;
      if (value <= 0.04045) {
        return value / 12.92;
      } else {
        return ((value + 0.055) / 1.055) ^ 2.4;
      }
    }
    function gamma_inverse(value) {
      if (value <= 0.0) return 0;
      if (value >= 1.0) return 255;
      if (value <= 0.0031308) {
        value *= 12.92;
      } else {
        value = 1.055 * value ^ (1.0 / 2.4) - 0.055;
      }
      return int(value * 255.0 + 0.5);
    }
    function color2LRGB(color, RGB) {
      RGB[0] = gamma_correction(int(color / 0x10000));
      RGB[1] = gamma_correction(int(color / 0x100) % 0x100);
      RGB[2] = gamma_correction(color % 0x100);
    }
    function LRGB2color(RGB, _, R, G, B) {
      R = gamma_inverse(RGB[0]);
      G = gamma_inverse(RGB[1]);
      B = gamma_inverse(RGB[2]);
      return R * 0x10000 + G * 0x100 + B;
    }

    function brightness(color, _, RGB) {
      color2LRGB(color, RGB);
      return gamma_inverse(0.2126 * RGB[0] + 0.7152 * RGB[1] + 0.0722 * RGB[2]);
    }

    function simulate_color_blindness(color, type, _, RGB, X, Y, Z, L, M, S) {
      # https://mk.bcgsc.ca/colorblind/math.mhtml
      color2LRGB(color, RGB);
      if (type == 0) {
        RGB[0] = 0.2126 * RGB[0] + 0.7152 * RGB[1] + 0.0722 * RGB[2];
        RGB[1] = RGB[0];
        RGB[2] = RGB[0];
      } else {
        X = 0.4124564 * RGB[0] + 0.3575761 * RGB[1] + 0.1804375 * RGB[2];
        Y = 0.2126729 * RGB[0] + 0.7151522 * RGB[1] + 0.0721750 * RGB[2];
        Z = 0.0193339 * RGB[0] + 0.1191920 * RGB[1] + 0.9503041 * RGB[2];
        L =  0.4002 * X + 0.7076 * Y - 0.0808 * Z;
        M = -0.2263 * X + 1.1653 * Y + 0.0457 * Z;
        S =  0.0    * X + 0.0    * Y + 0.9182 * Z;
        if (type == 1) {
          L = 1.05118294 * M - 0.05116099 * S;
        } else if (type == 2) {
          M = 0.9513092 * L + 0.04866992 * S;
        } else if (type == 3) {
          S = -0.86744736 * L + 1.86727089 * M;
        }
        X = 1.8600666 * L - 1.1294801 * M + 0.2198983 * S;
        Y = 0.3612229 * L + 0.6388043 * M + 0.0       * S;
        Z = 0.0       * L + 0.0       * M + 1.089087  * S;
        RGB[0] =  3.24045484 * X - 1.5371389 * Y - 0.49853155 * Z;
        RGB[1] = -0.96926639 * X + 1.8760109 * Y + 0.04155608 * Z;
        RGB[2] =  0.05564342 * X - 0.2040259 * Y + 1.05722516 * Z;
      }
      return LRGB2color(RGB);
    }

    #--------------------------------------------------------------------------
    # ITP distances

    function PQ_EOT_FInv(value, _, c1, c2, c3, m1, m2) {
      # https://en.wikipedia.org/wiki/Perceptual_quantizer
      m1 = 0.1593017578125;
      m2 = 78.84375;
      c2 = 18.8515625;
      c3 = 18.6875;
      c1 = c3 - c2 + 1.0;
      value = value ^ m1;
      return ((c1 + c2 * value) / (1.0 + c3 * value)) ^ m2;
    }

    function PQ_EOT_F(value, _, c1, c2, c3, m1, m2) {
      # https://en.wikipedia.org/wiki/Perceptual_quantizer
      m1 = 0.1593017578125;
      m2 = 78.84375;
      c2 = 18.8515625;
      c3 = 18.6875;
      c1 = c3 - c2 + 1.0;
      value = value ^ (1.0 / m2);
      return (max(value - c1, 0.0) / (c2 - c3 * value)) ^ (1.0 / m1);
    }

    function DeltaE_ITP(color1, color2, _, RGB1, L1, M1, S1, I1, T1, P1, RGB2, L2, M2, S2, I2, T2, P2) {
      # https://en.wikipedia.org/wiki/Color_difference
      # https://en.wikipedia.org/wiki/ICtCp
      color2LRGB(color1, RGB1);
      L1 = PQ_EOT_FInv((1688 * RGB1[0] + 2146 * RGB1[1] +  262 * RGB1[2]) / 4096.0);
      M1 = PQ_EOT_FInv(( 683 * RGB1[0] + 2951 * RGB1[1] +  462 * RGB1[2]) / 4096.0);
      S1 = PQ_EOT_FInv((  99 * RGB1[0] +  309 * RGB1[1] + 3688 * RGB1[2]) / 4096.0);
      I1 = ( 2048 * L1 +  2048 * M1 +    0 * S1) / 4096.0;
      T1 = ( 6610 * L1 - 13613 * M1 + 7003 * S1) / 4096.0 * 0.5;
      P1 = (17933 * L1 - 17390 * M1 -  543 * S1) / 4096.0;

      color2LRGB(color2, RGB2);
      L2 = PQ_EOT_FInv((1688 * RGB2[0] + 2146 * RGB2[1] +  262 * RGB2[2]) / 4096.0);
      M2 = PQ_EOT_FInv(( 683 * RGB2[0] + 2951 * RGB2[1] +  462 * RGB2[2]) / 4096.0);
      S2 = PQ_EOT_FInv((  99 * RGB2[0] +  309 * RGB2[1] + 3688 * RGB2[2]) / 4096.0);
      I2 = ( 2048 * L2 +  2048 * M2 +    0 * S2) / 4096.0;
      T2 = ( 6610 * L2 - 13613 * M2 + 7003 * S2) / 4096.0 * 0.5;
      P2 = (17933 * L2 - 17390 * M2 -  543 * S2) / 4096.0;

      return 720 * sqrt((I1 - I2) ^ 2 + (T1 - T2) ^ 2 + (P1 - P2) ^ 2);
    }

    #--------------------------------------------------------------------------
    # CIE distances

    function fLAB(x, _, delta) {
      delta = 6.0 / 29.0;
      if (x > delta * delta * delta)
        return x ^ (1.0 / 3.0);
      else
        return (1.0 / 3.0) * x / (delta * delta) + 4.0 / 29.0;
    }

    function color2Lab(color, Lab, _, RGB, X, Y, Z) {
      color2LRGB(color, RGB);
      X = fLAB((0.4124564 * RGB[0] + 0.3575761 * RGB[1] + 0.1804375 * RGB[2]) / 0.95047);
      Y = fLAB((0.2126729 * RGB[0] + 0.7151522 * RGB[1] + 0.0721750 * RGB[2]) / 1.00000);
      Z = fLAB((0.0193339 * RGB[0] + 0.1191920 * RGB[1] + 0.9503041 * RGB[2]) / 1.08883);
      Lab[0] = 116 * Y - 16;
      Lab[1] = 500 * (X - Y);
      Lab[2] = 200 * (Y - Z);
    }

    function DeltaE_CIE76(color1, color2, _, Lab1, Lab2, L1, a1, b1, L2, a2, b2) {
      color2Lab(color1, Lab1);
      L1 = Lab1[0];
      a1 = Lab1[1];
      b1 = Lab1[2];

      color2Lab(color2, Lab2);
      L2 = Lab2[0];
      a2 = Lab2[1];
      b2 = Lab2[2];

      return sqrt((L1 - L2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2);
    }

    function DeltaE_CIE94(color1, color2, _, Lab1, Lab2, L1, a1, b1, L2, a2, b2, C1, C2, Cbar, dL2, dC2, dH2) {
      color2Lab(color1, Lab1);
      L1 = Lab1[0];
      a1 = Lab1[1];
      b1 = Lab1[2];

      color2Lab(color2, Lab2);
      L2 = Lab2[0];
      a2 = Lab2[1];
      b2 = Lab2[2];

      C1 = sqrt(a1 * a1 + b1 * b1);
      C2 = sqrt(a2 * a2 + b2 * b2);
      Cbar = 0.5 * (C1 + C2);

      dL2 = (L1 - L2) ^ 2;
      dC2 = (C1 - C2) ^ 2;
      dH2 = (a1 - a2) ^ 2 + (b1 - b2) ^ 2 - dC2;

      dL2 /= 2.0 ^ 2;
      dC2 /= (1.0 + 0.048 * Cbar) ^ 2;
      dH2 /= (1.0 + 0.014 * Cbar) ^ 2;

      return sqrt(dL2 + dC2 + dH2);
    }

    function DeltaE(color1, color2) {
      if (c_deltaE == "cie94") {
        return DeltaE_CIE94(color1, color2);
      } else if (c_deltaE == "cie76") {
        return DeltaE_CIE76(color1, color2);
      } else if (c_deltaE == "ITP") {
        return DeltaE_ITP(color1, color2);
      } else {
        return DeltaE_CIE94(color1, color2);
      }
    }
    #--------------------------------------------------------------------------

    function ansi_color_sample(c, b, _, R, G, B) {
      R = int(c / 0x10000);
      G = int(c / 0x100) % 0x100;
      B = c % 0x100;
      return sprintf("\x1b[48;2;%d;%d;%dm    \x1b[47m \x1b[40;38;2;%d;%d;%dm #%06x \x1b[107m #%06x \x1b[39;47m \x1b[94mY=%03d\x1b[39m", R, G, B, R, G, B, c, c, b);
    }

    function html_color_sample(c, b, _, R, G, B, td1, td2, td3, td4) {
      R = int(c / 0x10000);
      G = int(c / 0x100) % 0x100;
      B = c % 0x100;
      td1 = sprintf("<td style=\"background-color: #%06x; width: 4ex;\"></td>", c);
      td2 = sprintf("<td>(%d,%d,%d) Y=%d</td>", R, G, B, b);
      td3 = sprintf("<td class=\"blesh-color-sample-black\"><code style=\"color: #%06x;\">#%06x</code></td>", c, c);
      td4 = sprintf("<td class=\"blesh-color-sample-white\"><code style=\"color: #%06x;\">#%06x</code></td>", c, c);
      return td1 td2 td3 td4;
    }

    function list_colors(_, d1_min, d2_min, i, c, b, c1, b1, c2, b2, c3, b3, d1, d2, d11, d21, d12, d22, d13, d23, s, s1, s2, s3) {
      d1_min = DeltaE(gray2color(c_Y_min), 0x000000);
      d2_min = DeltaE(gray2color(c_Y_max), 0xFFFFFF);
      # print d1_min, d2_min;

      if (c_output_type == "markdown") {
        printf("| %s | %-17s | %-17s | %-17s | %-17s | %s %s |\n", "Index", "Color", "protanopia", "deuteranopia", "tritanopia", "ΔE_b", "ΔE_w");
        printf("|:------|:------------------|:------------------|:------------------|:------------------|:------------|\n");
      } else if (c_output_type == "html") {
        printf("<!DOCTYPE html>\n");
        printf("<html>\n");
        printf("<head>\n");
        printf("<title>List of safe colors</title>\n");
        printf("<style>\n");
        printf("table.blesh-color-sample-table {border-collapse: collapse;}\n");
        printf("table.blesh-color-sample-table>*>*>td, table.blesh-color-sample-table>*>*>th {border: 1px solid silver; text-align: center; padding: 0.3ex 0.5ex;}\n");
        printf("td.blesh-color-sample-black {background-color: #000;}\n");
        printf("td.blesh-color-sample-white {background-color: #fff;}\n");
        printf("</style>\n");
        printf("</head>\n");
        printf("<body>\n");
        printf("<h1>List of safe colors</h1>\n");
        printf("<p>This content is generated by the following command:</p>\n");
        printf("<pre>$ make/color.sample.sh list-safe-colors -thtml -%s%s -y%d -Y%d -Ecie94</pre>\n", c_filter_by_brightness ? "b" : "B", c_filter_by_cielab ? "d" : "D", c_Y_min, c_Y_max);
        printf("<ul>\n");
        printf("<li>Brightness range [%g, %g] (filtering %s)</li>\n", c_Y_min, c_Y_max, c_filter_by_brightness ? "enabled" : "disabled");
        printf("<li>Color distance definition: %s</li>\n", c_deltaE == "cie74 ΔE<sub>74</sub>" ? "CIE76" : c_deltaE == "ITP ΔE<sub>ITP</sub>" ? "ITP" : "CIE94 ΔE<sub>94</sub>");
        printf("<li>Min distance from white: ΔE<sub>w</sub> ≧ %g (filtering %s)</li>\n", d1_min, c_filter_by_cielab ? "enabled" : "disabled");
        printf("<li>Min distance from black: ΔE<sub>b</sub> ≧ %g (filtering %s)</li>\n", d2_min, c_filter_by_cielab ? "enabled" : "disabled");
        printf("</ul>\n");
        printf("<table class=\"blesh-color-sample-table\">\n");
        printf("<tr><th>%s</th><th colspan=\"4\">%s</th><th colspan=\"4\">%s</th><th colspan=\"4\">%s</th><th colspan=\"4\">%s</th><th>%s %s</th></tr>\n", "Index", "Color", "Simulated protanopia", "Simulated deuteranopia", "Simulated tritanopia", "ΔE<sub>b</sub>", "ΔE<sub>w</sub>");
      }
      for (i = 16; i < 256; i++) {
        c = g_index_colors[i];
        b = brightness(c);
        c1 = simulate_color_blindness(c, 1);
        b1 = brightness(c1);
        c2 = simulate_color_blindness(c, 2);
        b2 = brightness(c2);
        c3 = simulate_color_blindness(c, 3);
        b3 = brightness(c3);

        if (c_filter_by_brightness) {
          if (b < c_Y_min || c_Y_max < b) continue;
          if (b1 < c_Y_min || c_Y_max < b1) continue;
          if (b2 < c_Y_min || c_Y_max < b2) continue;
          if (b3 < c_Y_min || c_Y_max < b3) continue;
        }

        d1 = DeltaE(c, 0x000000);
        d2 = DeltaE(c, 0xFFFFFF);

        if (c_filter_by_cielab) {
          d11 = DeltaE(c1, 0x000000);
          d21 = DeltaE(c1, 0xFFFFFF);
          d12 = DeltaE(c2, 0x000000);
          d22 = DeltaE(c2, 0xFFFFFF);
          d13 = DeltaE(c3, 0x000000);
          d23 = DeltaE(c3, 0xFFFFFF);
          if (d1 < d1_min || d2 < d2_min) continue;
          if (d11 < d1_min || d21 < d2_min) continue;
          if (d12 < d1_min || d22 < d2_min) continue;
          if (d13 < d1_min || d23 < d2_min) continue;
        }

        if (c_output_type == "markdown") {
          s  = sprintf("`#%06x` (Y=%d)", c, b);
          s1 = sprintf("`#%06x` (Y=%d)", c1, b1);
          s2 = sprintf("`#%06x` (Y=%d)", c2, b2);
          s3 = sprintf("`#%06x` (Y=%d)", c3, b3);
          printf("| %-5d | %-17s | %-17s | %-17s | %-17s | %5.1f %5.1f |\n", i, s, s1, s2, s3, d1, d2);
        } else if (c_output_type == "html") {
          s  = html_color_sample(c, b);
          s1 = html_color_sample(c1, b1);
          s2 = html_color_sample(c2, b2);
          s3 = html_color_sample(c3, b3);
          printf("<tr>\n  <td>%d</td>\n  %s\n  %s\n  %s\n  %s\n  <td>%.1f %.1f</td>\n</tr>\n", i, s, s1, s2, s3, d1, d2);
        } else {
          s  = ansi_color_sample(c, b);
          s1 = ansi_color_sample(c1, b1);
          s2 = ansi_color_sample(c2, b2);
          s3 = ansi_color_sample(c3, b3);
          printf("\x1b[47m| %3d | %s | %s | %s | %s |\x1b[K %5.1f %5.1f |\x1b[m\n", i, s, s1, s2, s3, d1, d2);
        }
      }

      if (c_output_type == "html") {
        printf("</table>\n");
        printf("</body>\n");
        printf("</html>\n");
      }
    }

    BEGIN { list_colors(); }
  '
}

function sub:patch1 {
  local -a safe
  safe=($(sub:list-safe-colors | awk '{print $2;}'))
  IFS='|' eval 'local rex_safe="${safe[*]}"'
  grc --exclude=contrib 'fg=([0-9]+|navy|purple)\b' | gawk '
    /\ybg=|\yfg=('"$rex_safe"')\y/ { next; }

    function process_line(line, _, m, filename, lineno, content, content_new) {
      if (match($0, /^([^:]+):([^:]+):(.*)/, m) <= 0) return;

      if (m[1] != g_filename) {
        g_filename = m[1];

        filename = g_filename;
        sub(/^\.\//, "", filename);

        printf("\x1b[1mdiff a/%s b/%s\x1b[m\n", filename, filename);
        # printf("index 9dfe57d9..e34eae59 100644\n");
        printf("\x1b[1m--- a/%s\x1b[m\n", filename);
        printf("\x1b[1m+++ b/%s\x1b[m\n", filename);
      }

      lineno = m[2];
      content = m[3];

      content_new = content;
      gsub(/\yfg=26\y/, "fg=33", content_new);
      gsub(/\yfg=92\y/, "fg=99", content_new);
      gsub(/\yfg=94\y/, "fg=100", content_new);
      gsub(/\yfg=124\y/, "fg=166", content_new);
      gsub(/\yfg=navy\y/, "fg=63", content_new);
      gsub(/\yfg=purple\y/, "fg=133", content_new);
      if (content_new == content) {
        print "unprocessed line '\''\x1b[34m" line "\x1b[m'\''" >"/dev/stderr";
        return;
      }

      printf("\x1b[94;48;5;189m\x1b[K@@ -%d,1 +%d,1 @@\x1b[m\n", lineno, lineno);
      printf("\x1b[94;48;5;189m-\x1b[39;48;5;224m%s\x1b[m\n", content);
      printf("\x1b[94;48;5;189m+\x1b[39;48;5;194m%s\x1b[m\n", content_new);
    }
    { process_line($0); }
  '
}

function sub:patch1-save {
  sub:patch1 | sed 's/\x1b\[[0-9:;<>=?]*[@-~]//g' > a.patch
}

# generate base16 palette samples from contrib/colorglass.base16.dat
function sub:generate-base16-sample {
  local -x c_output_type=ansi

  local OPTIND=1 OPTARG="" OPTERR=0 opt
  while getopts ':t:' opt "$@"; do
    case $opt in
    (t)
      case $OPTARG in
      (ansi|markdown|html)
        c_output_type=$OPTARG ;;
      (*)
        printf 'generate-base16-sample: -t: unrecognized output format "%s"\n' "$OPTARG"
        return 2 ;;
      esac ;;
    *)
      printf 'list-safe-colors: usage error\n' >&2
      return 2
      ;;
    esac
  done
  shift "$((OPTIND - 1))"

  awk '
    BEGIN {
      c_output_type = ENVIRON["c_output_type"];
      print_header();
    }

    function html_print_hline(_, i, line) {
      line = sprintf("| %-32s |", "");
      for (i = 0; i < 8; i++)
        line = line sprintf(" %-12s |", "");
      gsub(/\|/, "+", line);
      gsub(/ /, "-", line);
      print line;
    }

    function print_header(_, line) {
      if (c_output_type == "html") {
        print "<!DOCTYPE html>";
        print "<html>";
        print "<head>";
        print "<title>List of base16 palettes (colorglass.base16.dat)</title>";
        print "<style>";
        print "table.blesh-color-sample {border-collapse: collapse;}";
        print "table.blesh-color-sample>*>*>td, table.blesh-color-sample>*>*>th {border: 1px solid silver; padding: 0.5ex;}";
        print "</style>";
        print "</head>";
        print "<body>";
        print "<h1>List of base16 palettes</h1>";
        print "<p>The themes are defined in <code>contrib/colorglass.base16.dat</code>.</p>";
        print "<p>This content is generated by the following command:</p>";
        print "<pre>$ make/color.sample.sh generate-base16-sample -thtml</pre>";
        print "<table class=\"blesh-color-sample\">";
        print "<tr>";
        print "  <th>Name</th>";
        for (i = 0; i < 8; i++)
          printf("  <th colspan=\"2\">i = %d<br/>i = %d</th>\n", i, i + 8);
        print "</tr>";
      } else if (c_output_type == "markdown") {
        line = sprintf("| %-32s |", "Palette name");
        for (i = 0; i < 8; i++)
          line = line sprintf(" %-23s |", "i=" i " <br/>i=" (i + 8));
        print line;

        line = "|:---------------------------------|"
        for (i = 0; i < 8; i++)
          line = line ":-----------------------:|";
        print line;
      } else {
        line = sprintf("| \x1b[1m%-32s\x1b[m |", "Name");
        for (i = 0; i < 8; i++)
          line = line sprintf(" \x1b[1m%-12s\x1b[m |", sprintf("i=%d, i=%d", i, i + 8));
        print line;
        html_print_hline();
      }
    }
    function print_footer() {
      if (c_output_type == "html") {
        print "</table>";
        print "</body>";
        print "</html>";
      }
    }

    /^[[:space:]]*(#|$)/ || NF < 17 { next; }

    function ansi_color_sample(c, _, R, G, B) {
      R = int(c / 0x10000);
      G = int(c / 0x100) % 0x100;
      B = c % 0x100;
      return sprintf("\x1b[48;2;%d;%d;%dm    \x1b[m #%06x", R, G, B, c);
    }

    {
      # vars: i color1 color2 line
      if (c_output_type == "html") {
        print "<tr>";
        printf("  <td rowspan=\"2\">%s</td>\n", $1);
        for (i = 0; i < 8; i++) {
          color1 = strtonum($(i+2));
          printf("  <td style=\"background-color: #%06x; width: 4ex;\"></td><td><code>#%06x</code></td>\n", color1, color1);
        }
        print "</tr>";
        print "<tr>";
        for (i = 0; i < 8; i++) {
          color2 = strtonum($(i+10));
          printf("  <td style=\"background-color: #%06x; width: 4ex;\"></td><td><code>#%06x</code></td>\n", color2, color2);
        }
        print "</tr>";
      } else if (c_output_type == "markdown") {
        line = sprintf("| %-32s |", "`" $1 "`");
        for (i = 0; i < 8; i++) {
          color1 = $(i+2);
          color2 = $(i+10);
          sub(/^0x/, "#", color1);
          sub(/^0x/, "#", color2);
          line = line " `" color1 "`<br/>`" color2 "` |";
        }
        print line;
      } else {
        line = sprintf("| %-32s |", $1);
        for (i = 0; i < 8; i++)
          line = line sprintf(" %-12s |", ansi_color_sample(strtonum($(i+2))));
        print line;
        line = sprintf("| %-32s |", "");
        for (i = 0; i < 8; i++)
          line = line sprintf(" %-12s |", ansi_color_sample(strtonum($(i+10))));
        print line;
        html_print_hline();
      }
    }
    END { print_footer(); }
  ' contrib/colorglass.base16.dat
}

#------------------------------------------------------------------------------

function print-lines {
  printf '%s\n' "$@"
}

function sub:help {
  print-lines \
    "usage: ${0##*/} SUBCOMMAND" \
    '' \
    'SUBCOMMAND' \
    '' \
    '  show-brightness-sample' \
    '    Show sample of the brightness by grayscale.' \
    '' \
    '  list-safe-colors [-bBdD | -t [ansi|html|markdown] |' \
    '                  -y MINBRIGHT | -Y MAXBRIGHT]' \
    '    Show the list of safe colors.' \
    '' \
    '  patch1' \
    '    Generate and show the patch to replace the unsafe colors to safe ones.' \
    '' \
    '  patch1-save' \
    '    Save the patch generated by "patch1" to "a.patch"' \
    '' \
    '  generate-base16-sample [-t [ansi|html|markdown]]' \
    '    Show the list of base16 palettes' \
    '' \
    '  help' \
    '    Show this help.' \
    ''
}

if declare -F "sub:$1" &>/dev/null; then
  "sub:$@"
else
  echo 'usage: ./safe-color.sh SUBCOMMAND ARGS...' >&2
fi
