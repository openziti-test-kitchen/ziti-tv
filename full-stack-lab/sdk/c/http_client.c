/*
 * http_client.c -- Minimal HTTP/1.1 client over OpenZiti using ziti-sdk-c 1.x.
 *
 * Dials ZITI_SERVICE, sends GET /, reads the response, and prints:
 *   RESULT ok   http c-><target> <ms>ms
 *   RESULT fail http c-><target> <reason>
 *
 * "OK" means: response starts with "HTTP/1.1 200", body contains a JSON object
 * with a "lang" field. Exit 0 on success, non-zero on failure.
 *
 * Environment:
 *   ZITI_IDENTITY  path to enrolled identity JSON (default /ziti/id.json)
 *   ZITI_SERVICE   service name to dial            (default http.c)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <uv.h>
#include <ziti/ziti.h>
#include <ziti/ziti_events.h>

/* ---------- state ---------- */
typedef struct {
    ziti_context ztx;
    const char  *service;
    const char  *target;
    uint64_t     start_ms;
    char         resp[8192];
    size_t       resp_len;
    int          result;
    int          done;
} http_client_state_t;

static http_client_state_t g_state;

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

static void finish(http_client_state_t *st, const char *reason)
{
    if (st->done) return;
    st->done = 1;
    uint64_t elapsed = now_ms() - st->start_ms;
    if (reason == NULL) {
        printf("RESULT ok http c->%s %llums\n",
               st->target, (unsigned long long)elapsed);
        st->result = 0;
    } else {
        printf("RESULT fail http c->%s %s\n", st->target, reason);
        st->result = 1;
    }
    ziti_shutdown(st->ztx);
}

/* ---------- validate the buffered response ---------- */
static void check_response(http_client_state_t *st)
{
    /* Status line must start with 200 */
    if (strncmp(st->resp, "HTTP/1.1 200", 12) != 0 &&
        strncmp(st->resp, "HTTP/1.0 200", 12) != 0) {
        finish(st, "non-200 status");
        return;
    }

    /* Find body separator */
    const char *body = strstr(st->resp, "\r\n\r\n");
    if (body != NULL) {
        body += 4;
    } else {
        body = strstr(st->resp, "\n\n");
        if (body != NULL) body += 2;
    }

    if (body == NULL || strstr(body, "\"lang\"") == NULL) {
        finish(st, "missing-json-lang-field");
        return;
    }
    finish(st, NULL);
}

/* ---------- write completion: frees heap copy of request ---------- */
static void on_write_free(ziti_connection conn, ssize_t status, void *ctx)
{
    (void)conn;
    free(ctx);
    if (status < 0)
        fprintf(stderr, "write error: %s\n", ziti_errorstr((int)status));
}

/* ---------- data callback ---------- */
static ssize_t on_data(ziti_connection conn, const uint8_t *buf, ssize_t len)
{
    http_client_state_t *st = ziti_conn_data(conn);

    if (len == ZITI_EOF || len == 0) {
        if (!st->done) check_response(st);
        ziti_close(conn, NULL);
        return 0;
    }
    if (len < 0) {
        if (!st->done) finish(st, ziti_errorstr((int)len));
        ziti_close(conn, NULL);
        return len;
    }

    /* Append to response buffer (capped) */
    size_t copy = (size_t)len;
    if (st->resp_len + copy >= sizeof(st->resp) - 1)
        copy = sizeof(st->resp) - st->resp_len - 1;
    if (copy > 0) {
        memcpy(st->resp + st->resp_len, buf, copy);
        st->resp_len += copy;
        st->resp[st->resp_len] = '\0';
    }

    /* Attempt early completion once we have headers + a JSON body */
    if (!st->done) {
        const char *sep = strstr(st->resp, "\r\n\r\n");
        if (sep == NULL) sep = strstr(st->resp, "\n\n");
        if (sep != NULL && strstr(sep, "\"lang\"") != NULL) {
            check_response(st);
            ziti_close(conn, NULL);
        }
    }
    return len;
}

/* ---------- connect callback ---------- */
static void on_connect(ziti_connection conn, int status)
{
    http_client_state_t *st = ziti_conn_data(conn);
    if (status != ZITI_OK) {
        finish(st, ziti_errorstr(status));
        ziti_close(conn, NULL);
        return;
    }
    st->start_ms = now_ms();

    static const char REQ[] =
        "GET / HTTP/1.1\r\n"
        "Host: ziti\r\n"
        "Accept: application/json\r\n"
        "Connection: close\r\n"
        "\r\n";

    /* Heap copy: the static buffer lives past uv_run but we still follow the
     * convention of heap-alloc + free in the write callback.               */
    size_t rlen = sizeof(REQ) - 1; /* exclude NUL */
    uint8_t *rbuf = malloc(rlen);
    if (rbuf == NULL) { finish(st, "malloc"); ziti_close(conn, NULL); return; }
    memcpy(rbuf, REQ, rlen);
    ziti_write(conn, rbuf, rlen, on_write_free, rbuf);
}

/* ---------- context event callback ---------- */
static void on_event(ziti_context ztx, const ziti_event_t *ev)
{
    http_client_state_t *st = &g_state;
    if (ev->type == ZitiContextEvent) {
        if (ev->ctx.ctrl_status != ZITI_OK) {
            /* Ignore the ZITI_DISABLED event that fires during normal shutdown.
             * Only treat a pre-dial context failure as a genuine error.        */
            if (st->done) return;
            fprintf(stderr, "context error: %s\n",
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
    if (service == NULL || service[0] == '\0') service = "http.c";

    g_state.service = service;
    g_state.target  = last_segment(service);
    g_state.result  = 1;

    ziti_config cfg;
    int rc = ziti_load_config(&cfg, identity);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_load_config failed: %s\n", ziti_errorstr(rc));
        printf("RESULT fail http c->%s load-config\n", g_state.target);
        return 1;
    }

    rc = ziti_context_init(&g_state.ztx, &cfg);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_context_init failed: %s\n", ziti_errorstr(rc));
        printf("RESULT fail http c->%s context-init\n", g_state.target);
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
