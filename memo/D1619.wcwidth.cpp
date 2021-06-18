#define _XOPEN_SOURCE
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>
#include <locale.h>

int compare_array(int *a, int *b, size_t size) {
  for (size_t i = 0; i < size; i++)
    if (a[i] != b[i])
      return a[i] > b[i] ? 1 : -1;
  return 0;
}

int main() {
  int widths1[32], widths2[32];

  int *widths = &widths1[0];
  int *old_widths = &widths2[0];
  int skipping = 0;

  setlocale(LC_ALL, "C.UTF-8");

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


  FILE* file = fopen("c2w.wcwidth.txt", "w");
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
