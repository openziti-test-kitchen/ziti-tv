package org.zo.interop;

/**
 * Single entrypoint for the one image. Dispatches on:
 *   args[0] APP  = echo | http
 *   args[1] ROLE = server | client
 */
public final class Main {

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: <echo|http> <server|client>");
            System.exit(2);
            return;
        }
        String app = args[0];
        String role = args[1];

        switch (app + "/" + role) {
            case "echo/server" -> EchoServer.run();
            case "echo/client" -> EchoClient.run();
            case "http/server" -> HttpServer.run();
            case "http/client" -> HttpClient.run();
            default -> {
                System.err.println("unknown APP/ROLE: " + app + "/" + role);
                System.exit(2);
            }
        }
    }
}
