// echo client over OpenZiti (CZiti / ziti-sdk-swift).
//
// Dials ZITI_SERVICE over the overlay, sends "ping from swift\n", reads one
// line, and reports ok if the reply matches what was sent.
//
// Prints EXACTLY one RESULT line and exits 0 on ok, non-zero on fail.

import Foundation
import Common
import CZiti

let app = "echo"
let service = zitiServiceName()
let idPath = zitiIdentityPath()
let message = "ping from swift\n"

guard let ziti = Ziti(fromFile: idPath) else {
    resultFail(app: app, service: service, reason: "identity_load_failed")
}

let start = nowMs()
var conn: ZitiConnection?
var received = Data()

// Hard timeout so a dead service never hangs the matrix cell.
DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
    resultFail(app: app, service: service, reason: "timeout")
}

ziti.run { zErr in
    if let zErr = zErr {
        resultFail(app: app, service: service, reason: "init_\(zErr.localizedDescription)")
    }

    guard let c = ziti.createConnection() else {
        resultFail(app: app, service: service, reason: "create_conn_failed")
    }
    conn = c

    c.dial(service, { dialed, status in
        // onConn: dial result. On success, write our line.
        guard status == Ziti.ZITI_OK else {
            resultFail(app: app, service: service, reason: "dial_status_\(status)")
        }
        dialed.write(message.data(using: .utf8)!) { _, wstatus in
            if wstatus < 0 {
                resultFail(app: app, service: service, reason: "write_status_\(wstatus)")
            }
        }
    }, { _, data, len in
        // DataCallback: len < 0 is error/EOF. Accumulate until we have a line.
        if len < 0 {
            resultFail(app: app, service: service, reason: "read_status_\(len)")
        }
        if len > 0, let data = data {
            received.append(data)
            if let s = String(data: received, encoding: .utf8), s.contains("\n") {
                let line = s.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)[0] + "\n"
                if String(line) == message {
                    resultOK(app: app, service: service, ms: nowMs() - start)
                } else {
                    resultFail(app: app, service: service, reason: "mismatch")
                }
            }
        }
        return len
    })
}

RunLoop.main.run()
