package org.zo.interop;

import org.openziti.Ziti;
import org.openziti.ZitiContext;

/**
 * Shared environment + Ziti context bootstrap for all four apps.
 *
 * No enrollment happens here. The identity JSON referenced by ZITI_IDENTITY must already be enrolled.
 */
final class Env {

    static final String LANG = System.getenv().getOrDefault("SELF_LANG", "java");

    private Env() {
    }

    static String identityPath() {
        String p = System.getenv("ZITI_IDENTITY");
        if (p == null || p.isEmpty()) {
            p = "/ziti/id.json";
        }
        return p;
    }

    static String service() {
        String s = System.getenv("ZITI_SERVICE");
        if (s == null || s.isEmpty()) {
            throw new IllegalStateException("ZITI_SERVICE is not set");
        }
        return s;
    }

    /** TARGET = last dotted segment of the service name (e.g. echo.go -> go). */
    static String target(String service) {
        int dot = service.lastIndexOf('.');
        return dot >= 0 ? service.substring(dot + 1) : service;
    }

    /**
     * Loads the enrolled identity and blocks until the context reaches Active so that
     * services are known before we dial or bind.
     */
    static ZitiContext context() throws Exception {
        Ziti.setApplicationInfo("org.zo.interop", "1.0");
        ZitiContext ctx = Ziti.newContext(identityPath(), new char[0]);
        waitForActive(ctx);
        return ctx;
    }

    private static void waitForActive(ZitiContext ctx) throws Exception {
        long deadline = System.currentTimeMillis() + 30_000L;
        while (System.currentTimeMillis() < deadline) {
            ZitiContext.Status st = ctx.getStatus();
            if (st instanceof ZitiContext.Status.Active) {
                return;
            }
            if (st instanceof ZitiContext.Status.NotAuthorized
                    || st instanceof ZitiContext.Status.Unavailable) {
                throw new IllegalStateException("ziti context status: " + st);
            }
            Thread.sleep(100);
        }
        throw new IllegalStateException("ziti context did not become Active within 30s");
    }
}
