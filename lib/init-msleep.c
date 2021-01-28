// For Cygwin and MSYS
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <time.h>
#include <errno.h>

#define BUILTIN_ENABLED 0x01
struct word_desc { char* word; int flags; };
struct word_list { struct word_list* next; struct word_desc* word; };
struct builtin {
  const char* name;
  int (*function)(struct word_list*);
  int flags;
  const char** long_doc;
  const char* short_doc;
  char* handle;
};

static int msleep_builtin(struct word_list* list) {
  if (!list || !list->word) return 2;
  double value = atof(list->word->word) * 0.001;
  if (value < 0.0) return 2;
  if (value == 0.0) return 0;
  struct timespec tv;
  tv.tv_sec = floor(value);
  tv.tv_nsec = floor((value - floor(value)) * 1e9);
  while (nanosleep(&tv, &tv) == -1 && errno == EINTR);
  return 0;
}
static const char* msleep_doc[] = { "This is a builtin for ble.sh. Sleep for 'msec' milliseconds.", 0 };
struct builtin msleep_struct = { "ble/builtin/msleep", msleep_builtin, BUILTIN_ENABLED, msleep_doc, "ble/builtin/msleep msec", 0, };
