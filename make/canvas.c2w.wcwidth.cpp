#define _XOPEN_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <locale.h>


namespace impl1_dump_wcwidth {

  int compare_array(int *a, int *b, size_t size) {
    for (size_t i = 0; i < size; i++)
      if (a[i] != b[i])
        return a[i] > b[i] ? 1 : -1;
    return 0;
  }

  int save_wcwidth() {
    int widths1[32], widths2[32];

    int *widths = &widths1[0];
    int *old_widths = &widths2[0];
    int skipping = 0;

    setlocale(LC_ALL, "");
    //setlocale(LC_ALL, "C.UTF-8");

    // for (int32_t i = 0;i <= 0x10FFFF; i++) {
    //   widths[i % 32] = wcwidth(i);

    //   if ((i + 1) % 32 == 0) {
    //     if (compare_array(widths, old_widths, 32) == 0) {
    //       if (!skipping)
    //         printf("...\n");
    //       skipping = 1;
    //     } else {
    //       printf("U+%06X", i / 32 * 32);
    //       for (int j = 0; j < 32; j++)
    //         printf(widths[j] < 0 ? " -" : " %d", widths[j]);
    //       printf("\n");

    //       int *tmp = widths;
    //       widths = old_widths;
    //       old_widths = tmp;

    //       skipping = 0;
    //     }
    //   }
    // }


    FILE* file = fopen("canvas.c2w.wcwidth.txt", "w");
    int prev_w = 999;
    for (int32_t i = 0;i <= 0x10FFFF; i++) {
      int w = wcwidth(i);
      if (w == -1) w = 1;
      if (w != prev_w) {
        fprintf(file, "U+%04X %d\n", i, w);
        prev_w = w;
      }
    }
    fclose(file);
    return 0;
  }
}

#include <cstring>
#include <fstream>
#include <string>
#include <iostream>
#include <iterator>
#include <algorithm>
#include <vector>

namespace compare_with_unicode {

  int config_cjkwidth = 1;

  struct eaw_line_reader {
    std::size_t index;
    std::string line;

  private:
    int xdigit2decimal(char c) {
      if ('0' <= c && c <= '9') return (int) (c - '0');
      if ('A' <= c && c <= 'Z') return (int) (c - 'A') + 10;
      if ('a' <= c && c <= 'z') return (int) (c - 'A') + 10;
      return -1;
    }

  public:
    char ch() const { return line[index]; }

    void skip_space() {
      while (index < line.size() && std::isspace(line[index])) index++;
    }
    void skip_until(char c) {
      while (index < line.size() && line[index] != ']') index++;
      if (line[index] == ']') index++;
    }

    bool read_integer(std::uint32_t& value, int base = 10) {
      value = 0;
      int ndigit = 0, digit;
      while (index < line.size() && (digit = xdigit2decimal(line[index])) >= 0 && digit < base) {
        value = value * base + digit;
        ndigit++;
        index++;
      }
      return ndigit > 0;
    }

    bool readhex(std::uint32_t& value) {
      return read_integer(value, 16);
    }

    bool read_word(std::string& word) {
      while (index < line.size() && !std::isspace(line[index]))
        word += line[index++];
      return word.size() != 0;
    }

    static const char* to_gencat(std::string const& value) {
#define check(Literal) if (value == Literal) return Literal
      check("Lu");check("Ll");check("Lt");check("Lm");check("Lo");
      check("L&"); // L& represents that each character in the range belongs to one of Lu/Ll/Lt.
      check("Mn");check("Mc");check("Me");
      check("Nd");check("Nl");check("No");
      check("Pc");check("Pd");check("Ps");
      check("Pe");check("Pi");check("Pf");check("Po");
      check("Sm");check("Sc");check("Sk");check("So");
      check("Zs");check("Zl");check("Zp");
      check("Cc");check("Cf");check("Cs");
      check("Co");check("Cn");
      std::fprintf(stderr, "unknown GeneralCategory=%s\n", value.c_str());
      return nullptr;
#undef check
    }

  public:
    bool parse(std::uint32_t& code1, std::uint32_t& code2, int& eaw_width, const char*& gencat, std::string& name) {
      if (!readhex(code1)) return false;
      skip_space();

      if (index + 2 < line.size() && line[index] == '.' && line[index + 1] == '.') {
        index += 2;
        if (!readhex(code2)) return false;
        skip_space();
      } else {
        code2 = code1;
      }

      if (!(index < line.size() && line[index] == ';')) return false;
      index++;
      skip_space();

      std::string eaw;
      if (!read_word(eaw)) return false;
      skip_space();
      if (eaw == "N" || eaw == "Na" || eaw == "H")
        eaw_width = 1;
      else if (eaw == "W" || eaw == "F")
        eaw_width = 2;
      else if (eaw == "A")
        eaw_width = 3; // Ambiguous
      else
        std::fprintf(stderr, "unknown EastAsianWidth=%s\n", eaw.c_str());

      if (!(index < line.size() && line[index] == '#')) return false;
      index++;
      skip_space();

      std::string cat;
      if (!read_word(cat)) return false;
      gencat = to_gencat(cat);
      skip_space();

      if (index < line.size() && line[index] == '[') {
        skip_until(']');
        skip_space();
      }

      name = std::string(line, index);

      //std::printf("%4x..%4x %s %s\n", code1, code2, eaw.c_str(), cat.c_str());

      return true;
    }
  };

  class char_width_data {
  public:
    struct ch_prop {
      int eaw_width;
      const char* gencat;
      std::size_t hName;

      friend bool operator==(ch_prop const& lhs, ch_prop const& rhs) {
        return lhs.eaw_width == rhs.eaw_width && lhs.gencat == rhs.gencat;
      }

      int width() const {
        if (gencat == "Mn" || gencat == "Me" || gencat == "Cf")
          return 0;
        else if (gencat == "Cn" || gencat == "Cc" || gencat == "Cs" || gencat == "Zl" || gencat == "Zp")
          return -1;
        else if (eaw_width == 3)
          return config_cjkwidth;
        else
          return eaw_width;
      }
    };

  private:
    std::vector<ch_prop> data;
    std::vector<std::string> names;

  public:
    bool load(const char* filename) {
      data.resize(0x110000);
      std::fill(data.begin(), data.end(), ch_prop {3, "Cn"});
      {
        std::ifstream ifs(filename);
        if (!ifs) {
          std::cerr << "failed to open the file '" << filename << "'" << std::endl;
          return false;
        }

        std::string name;

        eaw_line_reader reader;
        while (std::getline(ifs, reader.line)) {
          reader.index = 0;
          reader.skip_space();
          if (reader.ch() == '\0' || reader.ch() == '#') continue;

          std::uint32_t code1, code2;
          ch_prop prop;
          if (!reader.parse(code1, code2, prop.eaw_width, prop.gencat, name))
            std::cerr << "invalid format: " << reader.line << std::endl;

          prop.hName = names.size();
          names.push_back(name);

          for (std::uint32_t code = code1; code <= code2; code++)
            data[code] = prop;
        }
      }
      return true;
    }

  public:
    int width(std::uint32_t code) const { return data[code].width(); }
    int eaw(std::uint32_t code) const { return data[code].eaw_width; }
    const char* gencat(std::uint32_t code) const { return data[code].gencat; }
    ch_prop const& prop(std::uint32_t code) const { return data[code]; }
    const char* name(std::uint32_t code) const { return names[data[code].hName].c_str(); }
  };

  void print_wcwidth_difference(std::FILE* file, int (*wcwidth)(wchar_t wc), const char* unicode_version_string) {
    char_width_data data;
    {
      char filename[256];
      std::sprintf(filename, "../out/data/unicode-EastAsianWidth-%s.0.txt", unicode_version_string);
      if (!data.load(filename)) std::exit(1);
      std::clog << "loaded data from '" << filename << "'" << std::endl;
    }

    std::fprintf(file, "# CODE[..CODE] WCWIDTH UNICODE_EAW NO_CONFLICT\n");

    std::uint32_t code1, code2;
    int prev_wcw;
    for (std::uint32_t code = 0; code < 0x110000; ) {
      int wcw = wcwidth(code);
      //if (wcw == -1) wcw = 1;
      int eaw = data.width(code);

      std::uint32_t code0 = code++;
      while (code < 0x110000 && wcwidth(code) == wcw && data.prop(code) == data.prop(code0)) code++;

      bool no_conflict = wcw == eaw || eaw == 3 && (wcw == 1 || wcw == 2) || eaw == -1;

      if (code - code0 == 1) {
        std::fprintf(file, "%04x       wcwidth=%d width(eaw=%d,gencat=%s)=%d %d\n", code0, wcw, data.eaw(code0), data.gencat(code0), eaw, no_conflict);
      } else {
        std::fprintf(file, "%04x..%04x wcwidth=%d width(eaw=%d,gencat=%s)=%d %d\n", code0, code - 1, wcw, data.eaw(code0), data.gencat(code0), eaw, no_conflict);
      }

      if (wcw != eaw) {
        char field1[100], field2[20];
        if (code - code0 == 1) {
          std::sprintf(field1, "_ble_unicode_c2w_custom[%d]=%d", code0, wcw);
          std::sprintf(field2, "U+%04X", code0);
        }else {
          std::sprintf(field1, "let '_ble_unicode_c2w_custom['{%d..%d}']=%d'", code0, code - 1, wcw);
          std::sprintf(field2, "U+%04X..%04X", code0, code - 1);
        }
        std::fprintf(stdout, "%-52s # %-14s %s %d %s\n",
          field1, field2, data.gencat(code0), data.eaw(code0), data.name(code0));
      }
    }
  }

  int run(int argc, char** argv) {
    const char* unicode_version_string = 1 < argc ? argv[1] : "13.0";
    setlocale(LC_ALL, "");
    {
      char filename[256];
      std::sprintf(filename, "../out/data/c2w.wcwidth-compare.%s.txt", unicode_version_string);
      std::FILE* file = std::fopen(filename, "w");
      print_wcwidth_difference(file, &::wcwidth, unicode_version_string);
      std::fclose(file);
    }
    return 0;
  }

  // Note: unused. gawk で実装する事にした。
  // void generate_EastAsianWidth_table() {
  //   char_width_data data;
  //   const char* filename = "../out/data/unicode-EastAsianWidth-11.0.0.txt";
  //   if (!data.load(filename)) return 1;
  //   std::clog << "loaded data from '" << filename << "'" << std::endl;

  //   int prev_eaw = -1;
  //   for (std::uint32_t code = 0; code < 0x110000; code++) {
  //     int eaw = data.eaw(code);
  //     if (eaw == prev_eaw) continue;
  //     std::printf("[%04x]=%d\n", code, eaw);
  //   }
  // }
}

extern int musl2014_wcwidth(wchar_t wc);
extern int musl2023_wcwidth(wchar_t wc);
extern int konsole2023_wcwidth(wchar_t wc);

namespace compare_wcwidth_impl {
  int musl2014() {
    const char* filename = "../out/data/c2w.wcwidth-compare.musl2014-vs-8.0.txt";
    std::FILE* file = std::fopen(filename, "w");
    compare_with_unicode::print_wcwidth_difference(file, &musl2014_wcwidth, "8.0");
    std::fclose(file);
    return 0;
  }
  int musl2023() {
    const char* filename = "../out/data/c2w.wcwidth-compare.musl2023-vs-12.1.txt";
    std::FILE* file = std::fopen(filename, "w");
    compare_with_unicode::print_wcwidth_difference(file, &musl2023_wcwidth, "12.1");
    std::fclose(file);
    return 0;
  }
  int konsole2023() {
    const char* filename = "../out/data/c2w.wcwidth-compare.konsole2023-vs-15.0.txt";
    std::FILE* file = std::fopen(filename, "w");
    compare_with_unicode::print_wcwidth_difference(file, &konsole2023_wcwidth, "15.0");
    std::fclose(file);
    return 0;
  }
}

namespace check_vector {
  const int vec[] = {
    0x25bd, 0x25b6,

    0x9FBC, 0x9FC4, 0x31B8, 0xD7B0, 0x3099,
    0x9FCD, 0x1F93B, 0x312E, 0x312F, 0x16FE2,
    0x32FF, 0x31BB, 0x9FFD, 0x1B132,
  };

  int musl2014() {
    std::size_t const sz = sizeof(vec) / sizeof(vec[0]);
    for (int i = 0; i < sz; i++)
      std::printf("ws[%d]=%d # U+%04X\n", i, musl2014_wcwidth(vec[i]), vec[i]);
    return 0;
  }
}

namespace generate_table {
  void print_musl2014_table(FILE* file) {
    int widths1[32], widths2[32];

    int *widths = &widths1[0];
    int *old_widths = &widths2[0];
    int skipping = 0;

    setlocale(LC_ALL, "");

    int prev_w = 999;
    for (int32_t i = 0;i <= 0x10FFFF; i++) {
      int w = musl2014_wcwidth(i);
      if (w == -1) w = 1;
      if (w != prev_w) {
        fprintf(file, "U+%04X %d\n", i, w);
        prev_w = w;
      }
    }
  }

  int musl2014() {
    // FILE* file = fopen("c2w.musl-wcwidth.txt", "w");
    // print_musl2014_table(file);
    // fclose(file);
    print_musl2014_table(stdout);
    return 0;
  }

}

int main(int argc, char** argv) {
  if (1 < argc) {
    if (std::strcmp(argv[1], "compare_eaw") == 0)
      return compare_with_unicode::run(argc - 1, argv + 1);
    if (std::strcmp(argv[1], "compare_musl") == 0)
      return compare_wcwidth_impl::musl2014();
    if (std::strcmp(argv[1], "compare_musl2023") == 0)
      return compare_wcwidth_impl::musl2023();
    if (std::strcmp(argv[1], "compare_konsole2023") == 0)
      return compare_wcwidth_impl::konsole2023();

    if (std::strcmp(argv[1], "vector_musl2014") == 0)
      return check_vector::musl2014();

    if (std::strcmp(argv[1], "table_musl2014") == 0)
      return generate_table::musl2014();
  }

  return impl1_dump_wcwidth::save_wcwidth();
}
