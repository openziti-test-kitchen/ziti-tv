/*
 * echo_client.c -- OpenZiti echo client using ziti-sdk-c 1.x API.
 *
 * Dials ZITI_SERVICE, sends "ping from c\n", reads the reply, and prints:
 *   RESULT ok   echo c-><target> <ms>ms
 *   RESULT fail echo c-><target> <reason>
 *
 * Exit 0 on success, non-zero on failure.
 *
 * Environment:
 *   ZITI_IDENTITY  path to enrolled identity JSON (default /ziti/id.json)
 *   ZITI_SERVICE   service name to dial            (default echo.c)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <uv.h>
#include <ziti/ziti.h>
#include <ziti/ziti_events.h>

#define PING_MSG "ping from c\n"

/* ---------- state ---------- */
typedef struct {
    ziti_context ztx;
    const char  *service;
    const char  *target;   /* last dotted component of service name */
    uint64_t     start_ms;
    char         recv_buf[256];
    size_t       recv_len;
    int          result;   /* 0 = ok, 1 = fail */
    int          done;     /* 1 after finish() fires: ignore shutdown events */
} client_state_t;

static client_state_t g_state;

/* ---------- helpers ---------- */
static uint64_t now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000u + (uint64_t)(ts.tv_nsec / 1000000);
}

static const char *last_segment(const char *s)
{
    const char *p = strrchr(s, '.');
    return p ? p + 1 : s;
}

static void finish(client_state_t *st, const char *reason)
{
    if (st->done) return;   /* idempotent: only one RESULT line ever printed */
    st->done = 1;
    uint64_t elapsed = now_ms() - st->start_ms;
    if (reason == NULL) {
        printf("RESULT ok echo c->%s %llums\n",
               st->target, (unsigned long long)elapsed);
        st->result = 0;
    } else {
        printf("RESULT fail echo c->%s %s\n", st->target, reason);
        st->result = 1;
    }
    ziti_shutdown(st->ztx);
}

/* ---------- callbacks ---------- */
static void on_write(ziti_connection conn, ssize_t status, void *ctx)
{
    (void)conn;
    (void)ctx;
    if (status < 0)
        fprintf(stderr, "write error: %s\n", ziti_errorstr((int)status));
}

static ssize_t on_data(ziti_connection conn, const uint8_t *buf, ssize_t len)
{
    client_state_t *st = ziti_conn_data(conn);

    if (len == ZITI_EOF || len == 0) {
        /* Server closed. Check what we got. */
        if (st->recv_len > 0 &&
            strncmp(st->recv_buf, PING_MSG, strlen(PING_MSG)) == 0) {
            finish(st, NULL);
        } else {
            finish(st, "echo mismatch or empty reply");
        }
        ziti_close(conn, NULL);
        return 0;
    }
    if (len < 0) {
        finish(st, ziti_errorstr((int)len));
        ziti_close(conn, NULL);
        return len;
    }

    size_t copy = (size_t)len;
    if (st->recv_len + copy >= sizeof(st->recv_buf))
        copy = sizeof(st->recv_buf) - st->recv_len - 1;
    memcpy(st->recv_buf + st->recv_len, buf, copy);
    st->recv_len += copy;
    st->recv_buf[st->recv_len] = '\0';

    /* Got a full line: echo is newline-terminated */
    if (memchr(st->recv_buf, '\n', st->recv_len) != NULL) {
        if (strncmp(st->recv_buf, PING_MSG, strlen(PING_MSG)) == 0) {
            finish(st, NULL);
        } else {
            finish(st, "echo mismatch");
        }
        ziti_close(conn, NULL);
    }
    return len;
}

static void on_connect(ziti_connection conn, int status)
{
    client_state_t *st = ziti_conn_data(conn);
    if (status != ZITI_OK) {
        finish(st, ziti_errorstr(status));
        ziti_close(conn, NULL);
        return;
    }
    st->start_ms = now_ms();
    ziti_write(conn, (uint8_t *)PING_MSG, strlen(PING_MSG), on_write, NULL);
}

static void on_event(ziti_context ztx, const ziti_event_t *ev)
{
    client_state_t *st = &g_state;
    if (ev->type == ZitiContextEvent) {
        if (ev->ctx.ctrl_status != ZITI_OK) {
            /* Ignore the ZITI_DISABLED event that fires during normal shutdown.
             * Only treat a pre-dial context failure as a genuine error.        */
            if (st->done) return;
            fprintf(stderr, "ziti context error: %s\n",
                    ev->ctx.err ? ev->ctx.err : ziti_errorstr(ev->ctx.ctrl_status));
            finish(st, ev->ctx.err ? ev->ctx.err : ziti_errorstr(ev->ctx.ctrl_status));
            return;
        }
        ziti_connection conn;
        ziti_conn_init(ztx, &conn, st);
        ziti_dial(conn, st->service, on_connect, on_data);
    }
}

/* ---------- main ---------- */
int main(void)
{
    const char *identity = getenv("ZITI_IDENTITY");
    if (identity == NULL || identity[0] == '\0') identity = "/ziti/id.json";

    const char *service = getenv("ZITI_SERVICE");
    if (service == NULL || service[0] == '\0') service = "echo.c";

    g_state.service = service;
    g_state.target  = last_segment(service);
    g_state.result  = 1; /* pessimistic default */

    ziti_config cfg;
    int rc = ziti_load_config(&cfg, identity);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_load_config(%s) failed: %s\n",
                identity, ziti_errorstr(rc));
        printf("RESULT fail echo c->%s load-config\n", g_state.target);
        return 1;
    }

    rc = ziti_context_init(&g_state.ztx, &cfg);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_context_init failed: %s\n", ziti_errorstr(rc));
        printf("RESULT fail echo c->%s context-init\n", g_state.target);
        return 1;
    }

    ziti_options opts = {0};
    opts.events   = ZitiContextEvent;
    opts.event_cb = on_event;

    ziti_context_set_options(g_state.ztx, &opts);

    uv_loop_t *loop = uv_default_loop();
    ziti_context_run(g_state.ztx, loop);
    uv_run(loop, UV_RUN_DEFAULT);

    return g_state.result;
}
