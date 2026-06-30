package org.zo.interop;

import org.openziti.ZitiAddress;
import org.openziti.ZitiContext;

import java.nio.ByteBuffer;
import java.nio.channels.AsynchronousServerSocketChannel;
import java.nio.channels.AsynchronousSocketChannel;

/**
 * Echo server: binds ZITI_SERVICE on the overlay and echoes bytes back forever.
 * No TCP listener, no host port.
 */
final class EchoServer {

    static void run() throws Exception {
        ZitiContext ctx = Env.context();
        String service = Env.service();

        AsynchronousServerSocketChannel server = ctx.openServer();
        server.bind(new ZitiAddress.Bind(service));
        System.err.println("echo server bound service '" + service + "' (lang=" + Env.LANG + ")");

        while (true) {
            AsynchronousSocketChannel conn = server.accept().get();
            Thread t = new Thread(() -> handle(conn));
            t.setDaemon(true);
            t.start();
        }
    }

    private static void handle(AsynchronousSocketChannel conn) {
        try (conn) {
            ByteBuffer buf = ByteBuffer.allocate(4096);
            while (true) {
                buf.clear();
                int n = conn.read(buf).get();
                if (n < 0) {
                    break;
                }
                buf.flip();
                while (buf.hasRemaining()) {
                    conn.write(buf).get();
                }
            }
        } catch (Exception e) {
            System.err.println("echo conn error: " + e.getMessage());
        }
    }
}
