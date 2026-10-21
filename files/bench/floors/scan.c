// Loads a newline-separated path list into memory (lower-cased) and times
// a substring search over all of it: the cost of a flat in-memory name index.
#define _GNU_SOURCE
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "rb"); fseek(f, 0, SEEK_END); long len = ftell(f); rewind(f);
  char *b = malloc(len + 1); fread(b, 1, len, f); b[len] = 0;
  long lines = 0; for (long i = 0; i < len; i++) { b[i] = tolower((unsigned char)b[i]); if (b[i] == '\n') lines++; }
  for (int a = 2; a < argc; a++) {
    const char *q = argv[a]; size_t ql = strlen(q); double best = 1e9; long hits = 0;
    for (int run = 0; run < 7; run++) {
      double t0 = now(); long h = 0; char *p = b, *end = b + len;
      while ((p = memmem(p, end - p, q, ql))) { h++; char *nl = memchr(p, '\n', end - p); if (!nl) break; p = nl + 1; }
      double dt = now() - t0; if (dt < best) best = dt; hits = h;
    }
    printf("paths=%ld bytes=%ld query=%s hits=%ld best_ms=%.2f\n", lines, len, q, hits, best);
  }
  return 0;
}
