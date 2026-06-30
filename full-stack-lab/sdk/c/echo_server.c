/*
 * echo_server.c -- OpenZiti echo server using ziti-sdk-c 1.x API.
 *
 * Binds ZITI_SERVICE (default: echo.c) and echoes every received byte back to
 * the sender. No TCP port is opened. Runs forever on the uv default loop.
 *
 * Environment:
 *   ZITI_IDENTITY  path to enrolled identity JSON (default /ziti/id.json)
 *   ZITI_SERVICE   service name to host            (default echo.c)
 *   SELF_LANG      informational; printed at startup (default c)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <uv.h>
#include <ziti/ziti.h>
#include <ziti/ziti_events.h>

/* ---------- forward declarations ---------- */
static void on_event(ziti_context ztx, const ziti_event_t *ev);
static void on_listen(ziti_connection serv, int status);
static void on_client(ziti_connection serv, ziti_connection client, int status,
                      const ziti_client_ctx *cctx);
static void on_accept(ziti_connection client, int status);
static ssize_t on_data(ziti_connection conn, const uint8_t *buf, ssize_t len);
static void on_write(ziti_connection conn, ssize_t status, void *ctx);

/* ---------- globals ---------- */
static ziti_context g_ztx;
static const char  *g_service;

/* ---------- data callback ---------- */
static ssize_t on_data(ziti_connection conn, const uint8_t *buf, ssize_t len)
{
    if (len == ZITI_EOF) {
        ziti_close(conn, NULL);
        return 0;
    }
    if (len < 0) {
        fprintf(stderr, "on_data error: %s\n", ziti_errorstr((int)len));
        ziti_close(conn, NULL);
        return len;
    }
    /* Echo the exact bytes back. The buffer is owned by the SDK; copy it for
     * the async write so it remains valid until on_write fires.             */
    uint8_t *copy = malloc((size_t)len);
    if (copy == NULL) {
        fprintf(stderr, "malloc failed echoing %zd bytes\n", len);
        ziti_close(conn, NULL);
        return ZITI_ALLOC_FAILED;
    }
    memcpy(copy, buf, (size_t)len);
    ziti_write(conn, copy, (size_t)len, on_write, copy);
    return len;
}

/* ---------- write completion ---------- */
static void on_write(ziti_connection conn, ssize_t status, void *ctx)
{
    free(ctx); /* free the copy allocated in on_data */
    if (status < 0) {
        fprintf(stderr, "write error: %s\n", ziti_errorstr((int)status));
        ziti_close(conn, NULL);
    }
}

/* ---------- accept callback (per client connection) ---------- */
static void on_accept(ziti_connection client, int status)
{
    if (status != ZITI_OK) {
        fprintf(stderr, "accept failed: %s\n", ziti_errorstr(status));
        ziti_close(client, NULL);
    }
    /* on_data is already registered via ziti_accept below; nothing else needed */
}

/* ---------- new client arrives on the bound service ---------- */
static void on_client(ziti_connection serv, ziti_connection client, int status,
                      const ziti_client_ctx *cctx)
{
    (void)serv;
    (void)cctx;
    if (status != ZITI_OK) {
        fprintf(stderr, "client error: %s\n", ziti_errorstr(status));
        return;
    }
    ziti_accept(client, on_accept, on_data);
}

/* ---------- listen (bind) completion ---------- */
static void on_listen(ziti_connection serv, int status)
{
    (void)serv;
    if (status != ZITI_OK) {
        fprintf(stderr, "listen failed on service '%s': %s\n",
                g_service, ziti_errorstr(status));
        exit(1);
    }
    printf("echo server: hosting service '%s' (no TCP port)\n", g_service);
}

/* ---------- ziti context event callback ---------- */
static void on_event(ziti_context ztx, const ziti_event_t *ev)
{
    if (ev->type == ZitiContextEvent) {
        if (ev->ctx.ctrl_status != ZITI_OK) {
            fprintf(stderr, "ziti context error: %s\n",
                    ev->ctx.err ? ev->ctx.err : ziti_errorstr(ev->ctx.ctrl_status));
            exit(1);
        }
        /* Context is up: bind the service. */
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
    if (g_service == NULL || g_service[0] == '\0') g_service = "echo.c";

    const char *lang = getenv("SELF_LANG");
    if (lang == NULL || lang[0] == '\0') lang = "c";

    printf("echo_server lang=%s service=%s identity=%s\n", lang, g_service, identity);

    ziti_config cfg;
    int rc = ziti_load_config(&cfg, identity);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_load_config(%s) failed: %s\n",
                identity, ziti_errorstr(rc));
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

    rc = ziti_context_set_options(g_ztx, &opts);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_context_set_options failed: %s\n", ziti_errorstr(rc));
        return 1;
    }

    uv_loop_t *loop = uv_default_loop();
    rc = ziti_context_run(g_ztx, loop);
    if (rc != ZITI_OK) {
        fprintf(stderr, "ziti_context_run failed: %s\n", ziti_errorstr(rc));
        return 1;
    }

    return uv_run(loop, UV_RUN_DEFAULT);
}
