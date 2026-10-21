// Lists one directory with raw getdents64 and a chosen buffer size,
// optionally stat-ing every entry; prints total and first-batch times.
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>
struct d64 { unsigned long long ino; long long off; unsigned short reclen; unsigned char type; char name[]; };
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) {
  size_t buf = atol(argv[2]); int st = argc > 3 ? atoi(argv[3]) : 0;
  char *b = malloc(buf); struct stat s; struct statx sx;
  double t0 = now(), first = -1;
  int fd = open(argv[1], O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  long n = 0, calls = 0;
  for (;;) {
    long r = syscall(SYS_getdents64, fd, b, buf); calls++;
    if (r <= 0) break;
    for (long o = 0; o < r;) {
      struct d64 *d = (void *)(b + o); o += d->reclen; n++;
      if (st == 1) fstatat(fd, d->name, &s, AT_SYMLINK_NOFOLLOW);
      if (st == 2) statx(fd, d->name, AT_SYMLINK_NOFOLLOW | AT_STATX_DONT_SYNC, STATX_TYPE | STATX_SIZE | STATX_MTIME, &sx);
    }
    if (first < 0) first = now() - t0;
  }
  printf("buf=%zu stat=%d entries=%ld calls=%ld first_batch_ms=%.3f total_ms=%.2f\n", buf, st, n, calls, first, now() - t0);
  return 0;
}
