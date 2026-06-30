/*
 * http_server.c -- Minimal HTTP/1.1 server over OpenZiti using ziti-sdk-c 1.x.
 *
 * Binds ZITI_SERVICE and speaks HTTP without any TCP listener:
 *   GET /        -> 200 {"lang":"c","host":"<hostname>"}
 *   GET /healthz -> 200 ok
 *   other        -> 404 not found
 *
 * One uv_loop, one ziti context, one bound service. Each incoming Ziti
 * connection is a standalone HTTP session: buffer until we have a complete
 * request line + headers, dispatch, reply, close.
 *
 * Environment:
 *   ZITI_IDENTITY  path to enrolled identity JSON (default /ziti/id.json)
 *   ZITI_SERVICE   service name to host            (default http.c)
 *   SELF_LANG      server language tag             (default c)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <uv.h>
#include <ziti/ziti.h>
#include <ziti/ziti_events.h>

#define HOSTNAME_MAX 256

/* ---------- per-connection state ---------- */
typedef struct {
    char   req[4096];
    size_t req_len;
    int    dispatched;
} conn_state_t;

/* ---------- forward declarations ---------- */
static void on_close_free(ziti_connection conn);

/* ---------- globals ---------- */
static ziti_context g_ztx;
static const char  *g_service;
static const char  *g_lang;
static char         g_hostname[HOSTNAME_MAX];

/* ---------- write completion: frees the heap buffer ---------- */
static void on_write_free(ziti_connection conn, ssize_t status, void *ctx)
{
    (void)conn;
    (void)status;
    free(ctx);
}

/* ---------- send an HTTP response and half-close the write side ---------- */
static void respond(ziti_connection conn, const char *status,
                    const char *ctype, const char *body)
{
    size_t blen = strlen(body);
    char   hdr[512];
    int    hlen = snprintf(hdr, sizeof(hdr),
        "HTTP/1.1 %s\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Connection: close\r\n"
        "\r\n",
        status, ctype, blen);
    if (hlen < 0 || hlen >= (int)sizeof(hdr)) {
        ziti_close(conn, NULL);
        return;
    }

    size_t total = (size_t)hlen + blen;
    uint8_t *buf = malloc(total);
    if (buf == NULL) { ziti_close(conn, NULL); return; }
    memcpy(buf, hdr, (size_t)hlen);
    memcpy(buf + (size_t)hlen, body, blen);

    ziti_write(conn, buf, total, on_write_free, buf);
    /* Signal end-of-write so the peer's recv loop terminates cleanly. */
    ziti_close_write(conn);
}

/* ---------- HTTP dispatch ---------- */
static void dispatch(ziti_connection conn, conn_state_t *cs)
{
    char method[16] = {0};
    char uri[256]   = {0};
    sscanf(cs->req, "%15s %255s", method, uri);

    if (strcmp(method, "GET") == 0 && strcmp(uri, "/healthz") == 0) {
        respond(conn, "200 OK", "text/plain", "ok");
    } else if (strcmp(method, "GET") == 0 && strcmp(uri, "/") == 0) {
        char body[512];
        snprintf(body, sizeof(body),
                 "{\"lang\":\"%s\",\"host\":\"%s\"}\n", g_lang, g_hostname);
        respond(conn, "200 OK", "application/json", body);
    } else {
        respond(conn, "404 Not Found", "text/plain", "not found\n");
    }
}

/* ---------- data callback ---------- */
static ssize_t on_data(ziti_connection conn, const uint8_t *buf, ssize_t len)
{
    conn_state_t *cs = ziti_conn_data(conn);

    if (len == ZITI_EOF || len == 0) {
        ziti_close(conn, on_close_free);
        return 0;
    }
    if (len < 0) {
        fprintf(stderr, "http on_data error: %s\n", ziti_errorstr((int)len));
        ziti_close(conn, on_close_free);
        return len;
    }

    if (!cs->dispatched) {
        size_t copy = (size_t)len;
        if (cs->req_len + copy >= sizeof(cs->req) - 1)
            copy = sizeof(cs->req) - cs->req_len - 1;
        memcpy(cs->req + cs->req_len, buf, copy);
        cs->req_len += copy;
        cs->req[cs->req_len] = '\0';

        if (strstr(cs->req, "\r\n\r\n") != NULL ||
            strstr(cs->req, "\n\n")     != NULL) {
            cs->dispatched = 1;
            dispatch(conn, cs);
        }
    }
    return len;
}

/* ---------- accept callback ---------- */
static void on_accept(ziti_connection client, int status)
{
    if (status != ZITI_OK) {
        fprintf(stderr, "accept error: %s\n", ziti_errorstr(status));
        conn_state_t *cs = ziti_conn_data(client);
        free(cs);
        ziti_close(client, NULL);
    }
}

/* ---------- close callback: frees per-connection state ---------- */
static void on_close_free(ziti_connection conn)
{
    conn_state_t *cs = ziti_conn_data(conn);
    free(cs);
}

/* ---------- new client callback ---------- */
static void on_client(ziti_connection serv, ziti_connection client, int status,
                      const ziti_client_ctx *cctx)
{
    (void)serv;
    (void)cctx;
    if (status != ZITI_OK) {
        fprintf(stderr, "on_client error: %s\n", ziti_errorstr(status));
        return;
    }
    conn_state_t *cs = calloc(1, sizeof(*cs));
    if (cs == NULL) { ziti_close(client, NULL); return; }
    ziti_conn_set_data(client, cs);
    ziti_accept(client, on_accept, on_data);
}

/* ---------- listen callback ---------- */
static void on_listen(ziti_connection serv, int status)
{
    (void)serv;
    if (status != ZITI_OK) {
        fprintf(stderr, "listen error on '%s': %s\n",
                g_service, ziti_errorstr(status));
        exit(1);
    }
    printf("http server: hosting '%s' lang=%s host=%s\n",
           g_service, g_lang, g_hostname);
}

/* ---------- context event callback ---------- */
static void on_event(ziti_context ztx, const ziti_event_t *ev)
{
    if (ev->type == ZitiContextEvent) {
        if (ev->ctx.ctrl_status != ZITI_OK) {
            fprintf(stderr, "context error: %s\n",
                    ev->ctx.err ? ev->ctx.err : ziti_errorstr(ev->ctx.ctrl_status));
            exit(1);
        }
        ziti_connection serv;
        ziti_conn_init(ztx, &serv, NULL);
        ziti_listen(serv, g_service, on_listen, on_client);
    }
}

/* ---------- main ---------- */
int main(void)
{
    const char *identity = getenv("ZITI_IDENTITY");
    if (identity == NULL || identity[0] == '\0') identity = "/ziti/id.json";

    g_service = getenv("ZITI_SERVICE");
    if (g_service == NULL || g_service[0] == '\0') g_service = "http.c";

    g_lang = getenv("SELF_LANG");
    if (g_lang == NULL || g_lang[0] == '\0') g_lang = "c";

    if (gethostname(g_hostname, sizeof(g_hostname)) != 0)
        strncpy(g_hostname, "unknown", sizeof(g_hostname) - 1);

    printf("http_server lang=%s service=%s identity=%s hostname=%s\n",
           g_lang, g_service, identity, g_hostname);

    ziti_config cfg;
    int rc = ziti_load_config(&cfg, identity);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_load_config failed: %s\n", ziti_errorstr(rc));
        return 1;
    }

    rc = ziti_context_init(&g_ztx, &cfg);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_context_init failed: %s\n", ziti_errorstr(rc));
        return 1;
    }

    ziti_options opts = {0};
    opts.events   = ZitiContextEvent | ZitiServiceEvent;
    opts.event_cb = on_event;
    ziti_context_set_options(g_ztx, &opts);

    uv_loop_t *loop = uv_default_loop();
    ziti_context_run(g_ztx, loop);
    return uv_run(loop, UV_RUN_DEFAULT);
}
