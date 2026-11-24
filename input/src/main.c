// ambrosia-input: the session's input method.
//
//   ambrosia-input              what KWin starts: waits to be handed text
//   ambrosia-input type TEXT    hands it TEXT; ends 0 once it is typed, 1 if
//                               nothing in front takes text, 2 if it isn't
//                               running
//
// KWin tells its input method whenever a text field has the keyboard
// (`activate`, with a context to write through) and when it loses it
// (`deactivate`). We keep the context and do nothing with it until text
// arrives over our socket ($XDG_RUNTIME_DIR/ambrosia-input); then it is
// committed, which puts it in at the insertion point of whatever app is in
// front, by the same road a Japanese or Chinese input method's text takes.
//
// The shell's picker has the keyboard while it is up, so the app's field is
// inactive at the moment a choice is made, and comes back after the picker
// closes, in two steps: KWin hands it the text focus at once (the app sends
// its state: `commit_state`), and the keyboard a little later (50 to 100 ms,
// seen on KWin 6.8), at which the app sends its state again. Qt drops text
// that arrives between the two, having no focused object to give it to, and
// nothing tells us. So a request waits for a field that has gone quiet: one
// that has sent its state twice since it became active and nothing for a
// moment, or nothing at all for a longer while (a field that was active all
// along, or an app that sends once). It gives up after a second and a half.
#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#include "input-method-v1.h"

// How long a field must have been quiet before we write to it: after its
// second round of state, or with no second round; what tells two rounds
// apart; and how long a request waits for a field at all.
enum { QUIET_MS = 40, LONG_QUIET_MS = 250, ROUND_MS = 25, GIVE_UP_MS = 1500 };

static struct zwp_input_method_v1 *method;
static struct zwp_input_method_context_v1 *context;
static uint32_t serial;

// The one request being served: who asked, what to type, and until when.
static int asker = -1;
static char text[4096];
static size_t length;
static bool complete;
static long long deadline;
// When the field last changed hands or sent its state, and how many rounds
// of state it has sent since it became active.
static long long touched_at;
static int rounds;

static long long now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000LL + t.tv_nsec / 1000000;
}

// AMBROSIA_INPUT_DEBUG=1 in its environment: each thing that happens, with
// the time in milliseconds, on stderr (which KWin passes on to its own).
static bool debug;
#define LOG(...) do { if (debug) { fprintf(stderr, "ambrosia-input %lld: ", now()); fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } } while (0)

static bool socket_path(struct sockaddr_un *address)
{
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    if (!runtime || !*runtime)
        return false;
    memset(address, 0, sizeof *address);
    address->sun_family = AF_UNIX;
    return snprintf(address->sun_path, sizeof address->sun_path, "%s/ambrosia-input", runtime) < (int)sizeof address->sun_path;
}

static void answer(const char *word)
{
    if (asker < 0)
        return;
    LOG("answer %.2s", word);
    (void)!write(asker, word, strlen(word));
    close(asker);
    asker = -1;
    length = 0;
    complete = false;
}

// When the field in front may be written to (see the top), or -1 with none.
static long long ready_at(void)
{
    if (!context)
        return -1;
    return touched_at + (rounds >= 2 ? QUIET_MS : LONG_QUIET_MS);
}

static void on_surrounding_text(void *data, struct zwp_input_method_context_v1 *c, const char *t, uint32_t cursor, uint32_t anchor)
{
    (void)data, (void)c, (void)cursor, (void)anchor;
    LOG("surrounding_text %zu bytes", strlen(t));
}
static void on_reset(void *data, struct zwp_input_method_context_v1 *c)
{
    (void)data, (void)c;
    LOG("reset");
}
static void on_content_type(void *data, struct zwp_input_method_context_v1 *c, uint32_t hint, uint32_t purpose)
{
    (void)data, (void)c, (void)hint, (void)purpose;
}
static void on_invoke_action(void *data, struct zwp_input_method_context_v1 *c, uint32_t button, uint32_t index)
{
    (void)data, (void)c, (void)button, (void)index;
}
static void on_commit_state(void *data, struct zwp_input_method_context_v1 *c, uint32_t s)
{
    (void)data;
    LOG("commit_state %u%s", s, c == context ? "" : " (an old field)");
    if (c != context)
        return;
    serial = s;
    const long long at = now();
    if (at - touched_at >= ROUND_MS || rounds == 0)
        rounds++;
    touched_at = at;
}
static void on_preferred_language(void *data, struct zwp_input_method_context_v1 *c, const char *language)
{
    (void)data, (void)c, (void)language;
}
static const struct zwp_input_method_context_v1_listener context_listener = {
    .surrounding_text = on_surrounding_text,
    .reset = on_reset,
    .content_type = on_content_type,
    .invoke_action = on_invoke_action,
    .commit_state = on_commit_state,
    .preferred_language = on_preferred_language,
};

static void on_activate(void *data, struct zwp_input_method_v1 *m, struct zwp_input_method_context_v1 *c)
{
    (void)data, (void)m;
    if (context)
        zwp_input_method_context_v1_destroy(context);
    context = c;
    serial = 0;
    rounds = 0;
    touched_at = now();
    LOG("activate %p", (void *)c);
    zwp_input_method_context_v1_add_listener(context, &context_listener, NULL);
}
static void on_deactivate(void *data, struct zwp_input_method_v1 *m, struct zwp_input_method_context_v1 *c)
{
    (void)data, (void)m;
    LOG("deactivate %p", (void *)c);
    if (c == context)
        context = NULL;
    zwp_input_method_context_v1_destroy(c);
    touched_at = now();
}
static const struct zwp_input_method_v1_listener method_listener = {
    .activate = on_activate,
    .deactivate = on_deactivate,
};

static void on_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    (void)data, (void)version;
    if (!method && strcmp(interface, zwp_input_method_v1_interface.name) == 0) {
        method = wl_registry_bind(registry, name, &zwp_input_method_v1_interface, 1);
        zwp_input_method_v1_add_listener(method, &method_listener, NULL);
    }
}
static void on_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
    (void)data, (void)registry, (void)name;
}
static const struct wl_registry_listener registry_listener = {
    .global = on_global,
    .global_remove = on_global_remove,
};

static int type(int count, char **words)
{
    struct sockaddr_un address;
    if (!socket_path(&address)) {
        fputs("ambrosia-input: no XDG_RUNTIME_DIR\n", stderr);
        return 2;
    }
    const int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, (struct sockaddr *)&address, sizeof address) < 0) {
        fputs("ambrosia-input: the input method isn't running (KWin starts it: kwinrc, [Wayland] InputMethod)\n", stderr);
        return 2;
    }
    for (int i = 0; i < count; i++) {
        if (i > 0)
            (void)!write(fd, " ", 1);
        (void)!write(fd, words[i], strlen(words[i]));
    }
    shutdown(fd, SHUT_WR);
    char reply[8] = "";
    const ssize_t got = read(fd, reply, sizeof reply - 1);
    close(fd);
    return got >= 2 && strncmp(reply, "ok", 2) == 0 ? 0 : 1;
}

int main(int argc, char **argv)
{
    if (argc >= 3 && strcmp(argv[1], "type") == 0)
        return type(argc - 2, argv + 2);
    if (argc > 1) {
        fputs("usage: ambrosia-input | ambrosia-input type TEXT\n", stderr);
        return 2;
    }

    debug = getenv("AMBROSIA_INPUT_DEBUG") != NULL;
    // WAYLAND_SOCKET, from KWin, is the connection that may be the input method.
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fputs("ambrosia-input: no Wayland display\n", stderr);
        return 1;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!method) {
        fputs("ambrosia-input: this connection isn't offered the input method (KWin gives it only to the program its own settings start)\n", stderr);
        return 1;
    }

    struct sockaddr_un address;
    if (!socket_path(&address)) {
        fputs("ambrosia-input: no XDG_RUNTIME_DIR\n", stderr);
        return 1;
    }
    unlink(address.sun_path);
    const int listener = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    if (listener < 0 || bind(listener, (struct sockaddr *)&address, sizeof address) < 0 || listen(listener, 4) < 0) {
        perror("ambrosia-input: socket");
        return 1;
    }

    for (;;) {
        while (wl_display_dispatch_pending(display) > 0) { }
        if (wl_display_flush(display) < 0 && errno != EAGAIN)
            break;

        if (asker >= 0) {
            const long long at = now();
            if (complete && context && at >= ready_at()) {
                LOG("commit to %p, serial %u, after %d rounds", (void *)context, serial, rounds);
                zwp_input_method_context_v1_commit_string(context, serial, text);
                wl_display_flush(display);
                answer("ok\n");
            } else if (at >= deadline) {
                answer("no\n");
            }
        }

        int timeout = -1;
        if (asker >= 0) {
            long long until = deadline;
            if (complete && context && ready_at() < until)
                until = ready_at();
            const long long left = until - now();
            timeout = left < 0 ? 0 : (int)left;
        }
        struct pollfd fds[3] = {
            { .fd = wl_display_get_fd(display), .events = POLLIN },
            { .fd = listener, .events = POLLIN },
            { .fd = asker >= 0 && !complete ? asker : -1, .events = POLLIN },
        };
        if (poll(fds, 3, timeout) < 0) {
            if (errno == EINTR)
                continue;
            break;
        }

        if (fds[0].revents & (POLLERR | POLLHUP))
            break;
        if ((fds[0].revents & POLLIN) && wl_display_dispatch(display) < 0)
            break;

        if (fds[2].revents) {
            const ssize_t got = read(asker, text + length, sizeof text - 1 - length);
            if (got > 0) {
                length += (size_t)got;
            } else {
                // All of it has arrived (or there is no room for more).
                text[length] = '\0';
                complete = true;
                if (length == 0)
                    answer("no\n");
            }
            if (length >= sizeof text - 1) {
                text[length] = '\0';
                complete = true;
            }
        }

        if (fds[1].revents & POLLIN) {
            const int fd = accept4(listener, NULL, NULL, SOCK_CLOEXEC);
            if (fd >= 0 && asker >= 0) {
                // One at a time: the picker makes one choice.
                (void)!write(fd, "no\n", 3);
                close(fd);
            } else if (fd >= 0) {
                LOG("asked, the field %s", context ? "active" : "not active");
                asker = fd;
                length = 0;
                complete = false;
                deadline = now() + GIVE_UP_MS;
            }
        }
    }
    unlink(address.sun_path);
    return 0;
}
