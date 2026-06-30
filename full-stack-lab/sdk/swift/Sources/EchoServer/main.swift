// echo server over OpenZiti (CZiti / ziti-sdk-swift).
//
// Binds (hosts) ZITI_SERVICE on the overlay and echoes every byte back, forever.
// No TCP listener, no open port. Connectivity is purely the Ziti overlay.
//
// Contract: APP=echo ROLE=server. Servers run forever and emit no RESULT line.

import Foundation
import Common
import CZiti

let service = zitiServiceName()
let idPath = zitiIdentityPath()

guard let ziti = Ziti(fromFile: idPath) else {
    stderrLine("failed to load Ziti identity from \(idPath)")
    exit(1)
}

// We must keep a strong reference to the listening connection for the life of
// the process, and to each accepted client connection until it closes.
var listenConn: ZitiConnection?
var clients: [ObjectIdentifier: ZitiConnection] = [:]

ziti.run { zErr in
    if let zErr = zErr {
        stderrLine("ziti init failed: \(zErr.localizedDescription)")
        exit(1)
    }

    guard let server = ziti.createConnection() else {
        stderrLine("failed to create Ziti connection")
        exit(1)
    }
    listenConn = server

    server.listen(service, { _, status in
        // onListen: status is the bind result.
        if status != Ziti.ZITI_OK {
            stderrLine("listen failed for \(service): status \(status)")
            exit(1)
        }
        stderrLine("hosting service '\(service)' over the overlay; no TCP port is open")
    }, { _, client, status in
        // onClient: a dial arrived. Accept it and wire an echo data callback.
        guard status == Ziti.ZITI_OK else {
            stderrLine("client arrival error: status \(status)")
            return
        }
        clients[ObjectIdentifier(client)] = client
        client.accept({ _, acceptStatus in
            if acceptStatus != Ziti.ZITI_OK {
                stderrLine("accept failed: status \(acceptStatus)")
            }
        }, { conn, data, len in
            // DataCallback: len < 0 signals error/EOF; data present means echo it.
            if len < 0 {
                conn.close(nil)
                clients[ObjectIdentifier(conn)] = nil
                return len
            }
            if len > 0, let data = data {
                conn.write(data) { _, _ in }
            }
            return len
        })
    })
}

// run(_:) drives the loop on this thread and does not return; keep alive anyway.
RunLoop.main.run()
