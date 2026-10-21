// Enumerates a folder with GIO (what Nautilus uses) asking for the given
// attributes, without printing, and reports the time.
#include <gio/gio.h>
#include <stdio.h>
int main(int argc, char **argv) {
  GFile *dir = g_file_new_for_path(argv[1]);
  gint64 t0 = g_get_monotonic_time();
  GFileEnumerator *e = g_file_enumerate_children(dir, argv[2], G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, NULL, NULL);
  long n = 0; GFileInfo *i;
  while ((i = g_file_enumerator_next_file(e, NULL, NULL))) { n++; g_object_unref(i); }
  printf("entries=%ld ms=%.1f attrs=%s\n", n, (g_get_monotonic_time() - t0) / 1e3, argv[2]);
  return 0;
}
