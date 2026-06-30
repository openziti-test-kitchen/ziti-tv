// http client over OpenZiti (CZiti / ziti-sdk-swift).
//
// Dials ZITI_SERVICE, writes a minimal HTTP/1.1 GET / over the raw Ziti conn,
// and reports ok if the response is 200 and the JSON body parses.
//
// Prints EXACTLY one RESULT line and exits 0 on ok, non-zero on fail.

import Foundation
import Common
import CZiti

let app = "http"
let service = zitiServiceName()
let idPath = zitiIdentityPath()

let request = "GET / HTTP/1.1\r\nHost: \(service)\r\nAccept: application/json\r\nConnection: close\r\n\r\n"

guard let ziti = Ziti(fromFile: idPath) else {
    resultFail(app: app, service: service, reason: "identity_load_failed")
}

let start = nowMs()
var conn: ZitiConnection?
var received = Data()

DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
    resultFail(app: app, service: service, reason: "timeout")
}

func evaluate(_ buf: Data) {
    guard let text = String(data: buf, encoding: .utf8) else { return }
    guard let headerEnd = text.range(of: "\r\n\r\n") else { return } // wait for full headers
    let statusLine = text.split(separator: "\r\n", maxSplits: 1, omittingEmptySubsequences: false)[0]
    guard statusLine.contains(" 200") else {
        resultFail(app: app, service: service, reason: "status_not_200")
    }
    // Body is everything after the blank line. With Connection: close the server
    // closes after the body, but we can validate as soon as we have valid JSON.
    let body = String(text[headerEnd.upperBound...])
    guard let bodyData = body.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: bodyData),
          obj is [String: Any] else {
        return // not enough body yet, or not valid JSON yet
    }
    resultOK(app: app, service: service, ms: nowMs() - start)
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
        guard status == Ziti.ZITI_OK else {
            resultFail(app: app, service: service, reason: "dial_status_\(status)")
        }
        dialed.write(request.data(using: .utf8)!) { _, wstatus in
            if wstatus < 0 {
                resultFail(app: app, service: service, reason: "write_status_\(wstatus)")
            }
        }
    }, { _, data, len in
        if len < 0 {
            // EOF/close: do a final evaluation in case body arrived with the close.
            evaluate(received)
            resultFail(app: app, service: service, reason: "read_status_\(len)")
        }
        if len > 0, let data = data {
            received.append(data)
            evaluate(received)
        }
        return len
    })
}

RunLoop.main.run()
