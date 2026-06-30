package org.zo.interop;

import org.openziti.ZitiConnection;
import org.openziti.ZitiContext;

import java.nio.charset.StandardCharsets;

/**
 * Echo client: dials ZITI_SERVICE, sends "ping from java\n", reads a line back, OK if it matches.
 */
final class EchoClient {

    static void run() throws Exception {
        String service = Env.service();
        String target = Env.target(service);
        long start = System.currentTimeMillis();

        try {
            ZitiContext ctx = Env.context();
            String msg = "ping from " + Env.LANG + "\n";

            try (ZitiConnection conn = ctx.dial(service)) {
                conn.write(msg.getBytes(StandardCharsets.UTF_8));

                String line = readLine(conn);
                long ms = System.currentTimeMillis() - start;

                if (msg.equals(line) || msg.stripTrailing().equals(line.stripTrailing())) {
                    Result.ok("echo", target, ms);
                } else {
                    Result.fail("echo", target, "mismatch: got '" + line.stripTrailing() + "'");
                }
            }
        } catch (Exception e) {
            Result.fail("echo", target, e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    private static String readLine(ZitiConnection conn) throws Exception {
        StringBuilder sb = new StringBuilder();
        byte[] one = new byte[1];
        while (true) {
            int n = conn.read(one, 0, 1);
            if (n < 0) {
                break;
            }
            if (n == 0) {
                continue;
            }
            char c = (char) (one[0] & 0xff);
            sb.append(c);
            if (c == '\n') {
                break;
            }
        }
        return sb.toString();
    }
}
