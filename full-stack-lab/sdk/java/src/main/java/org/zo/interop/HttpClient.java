package org.zo.interop;

import org.openziti.ZitiConnection;
import org.openziti.ZitiContext;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

/**
 * HTTP client: GET / over the Ziti connection for ZITI_SERVICE.
 * OK if status 200 and the body parses as the expected JSON object.
 *
 * Speaks raw HTTP/1.1 over the dialed ZitiConnection (no URL interception needed).
 */
final class HttpClient {

    static void run() throws Exception {
        String service = Env.service();
        String target = Env.target(service);
        long start = System.currentTimeMillis();

        try {
            ZitiContext ctx = Env.context();

            try (ZitiConnection conn = ctx.dial(service)) {
                String req = "GET / HTTP/1.1\r\n"
                        + "Host: " + service + "\r\n"
                        + "Accept: application/json\r\n"
                        + "User-Agent: zo-sdk-java\r\n"
                        + "Connection: close\r\n"
                        + "\r\n";
                conn.write(req.getBytes(StandardCharsets.US_ASCII));

                String raw = readAll(conn);
                long ms = System.currentTimeMillis() - start;

                int sep = raw.indexOf("\r\n\r\n");
                String head = sep >= 0 ? raw.substring(0, sep) : raw;
                String body = sep >= 0 ? raw.substring(sep + 4) : "";

                int status = parseStatus(head);
                if (status != 200) {
                    Result.fail("http", target, "status " + status);
                    return;
                }
                if (!looksLikeJsonObject(body)) {
                    Result.fail("http", target, "body not json: '" + body.stripTrailing() + "'");
                    return;
                }
                Result.ok("http", target, ms);
            }
        } catch (Exception e) {
            Result.fail("http", target, e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    private static String readAll(ZitiConnection conn) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[2048];
        while (true) {
            int n = conn.read(buf, 0, buf.length);
            if (n < 0) {
                break;
            }
            if (n > 0) {
                out.write(buf, 0, n);
            }
        }
        return out.toString(StandardCharsets.UTF_8);
    }

    private static int parseStatus(String head) {
        int nl = head.indexOf("\r\n");
        String statusLine = nl >= 0 ? head.substring(0, nl) : head;
        String[] parts = statusLine.split(" ");
        if (parts.length >= 2) {
            try {
                return Integer.parseInt(parts[1]);
            } catch (NumberFormatException ignored) {
                return -1;
            }
        }
        return -1;
    }

    private static boolean looksLikeJsonObject(String body) {
        String t = body.strip();
        return t.startsWith("{") && t.endsWith("}") && t.contains("\"lang\"");
    }
}
