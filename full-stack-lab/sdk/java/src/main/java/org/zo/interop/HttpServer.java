package org.zo.interop;

import org.openziti.ZitiAddress;
import org.openziti.ZitiContext;

import java.net.InetAddress;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.channels.AsynchronousServerSocketChannel;
import java.nio.channels.AsynchronousSocketChannel;

/**
 * HTTP server over a Ziti listener bound to ZITI_SERVICE.
 *   GET /         -> 200 JSON {"lang":"java","host":<hostname>}
 *   GET /healthz  -> 200 "ok"
 *
 * A minimal HTTP/1.1 implementation, one request per connection (Connection: close),
 * spoken directly over the Ziti AsynchronousSocketChannel. No host port, no servlet container.
 */
final class HttpServer {

    static void run() throws Exception {
        ZitiContext ctx = Env.context();
        String service = Env.service();

        AsynchronousServerSocketChannel server = ctx.openServer();
        server.bind(new ZitiAddress.Bind(service));
        System.err.println("http server bound service '" + service + "' (lang=" + Env.LANG + ")");

        while (true) {
            AsynchronousSocketChannel conn = server.accept().get();
            Thread t = new Thread(() -> handle(conn));
            t.setDaemon(true);
            t.start();
        }
    }

    private static void handle(AsynchronousSocketChannel conn) {
        try (conn) {
            String requestLine = readRequestLine(conn);
            String path = "/";
            String[] parts = requestLine.split(" ");
            if (parts.length >= 2) {
                path = parts[1];
            }

            String body;
            String contentType;
            if (path.startsWith("/healthz")) {
                body = "ok";
                contentType = "text/plain";
            } else {
                String host = hostname();
                body = "{\"lang\":\"" + Env.LANG + "\",\"host\":\"" + host + "\"}";
                contentType = "application/json";
            }

            byte[] bodyBytes = body.getBytes(StandardCharsets.UTF_8);
            String head = "HTTP/1.1 200 OK\r\n"
                    + "Content-Type: " + contentType + "\r\n"
                    + "Content-Length: " + bodyBytes.length + "\r\n"
                    + "Connection: close\r\n"
                    + "\r\n";

            writeAll(conn, head.getBytes(StandardCharsets.US_ASCII));
            writeAll(conn, bodyBytes);
        } catch (Exception e) {
            System.err.println("http conn error: " + e.getMessage());
        }
    }

    /** Reads through the end of the request head (blank line) and returns the request line. */
    private static String readRequestLine(AsynchronousSocketChannel conn) throws Exception {
        StringBuilder sb = new StringBuilder();
        ByteBuffer buf = ByteBuffer.allocate(1);
        String firstLine = null;
        while (true) {
            buf.clear();
            int n = conn.read(buf).get();
            if (n < 0) {
                break;
            }
            buf.flip();
            char c = (char) (buf.get() & 0xff);
            sb.append(c);
            if (firstLine == null && c == '\n') {
                firstLine = sb.toString().stripTrailing();
            }
            int len = sb.length();
            if (len >= 4 && sb.charAt(len - 1) == '\n' && sb.charAt(len - 2) == '\r'
                    && sb.charAt(len - 3) == '\n' && sb.charAt(len - 4) == '\r') {
                break;
            }
        }
        return firstLine != null ? firstLine : sb.toString().stripTrailing();
    }

    private static void writeAll(AsynchronousSocketChannel conn, byte[] data) throws Exception {
        ByteBuffer b = ByteBuffer.wrap(data);
        while (b.hasRemaining()) {
            conn.write(b).get();
        }
    }

    private static String hostname() {
        String h = System.getenv("HOSTNAME");
        if (h != null && !h.isEmpty()) {
            return h;
        }
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "unknown";
        }
    }
}
