package org.zo.interop;

/**
 * Emits the single contract line on stdout and exits with the contract status code.
 *   RESULT ok   <APP> java-><TARGET> <ms>ms
 *   RESULT fail <APP> java-><TARGET> <reason>
 */
final class Result {

    private Result() {
    }

    static void ok(String app, String target, long ms) {
        System.out.println("RESULT ok " + app + " " + Env.LANG + "->" + target + " " + ms + "ms");
        System.out.flush();
        System.exit(0);
    }

    static void fail(String app, String target, String reason) {
        System.out.println("RESULT fail " + app + " " + Env.LANG + "->" + target + " " + reason);
        System.out.flush();
        System.exit(1);
    }
}
