// http server over OpenZiti (CZiti / ziti-sdk-swift).
//
// Serves minimal HTTP over a Ziti listener bound to ZITI_SERVICE. The Swift SDK
// exposes a raw byte stream (ZitiConnection), not a Foundation URL listener, so
// we parse the request line ourselves and write a raw HTTP/1.1 response.
//
//   GET /        -> 200 application/json  {"lang":"<SELF_LANG>","host":"<hostname>"}
//   GET /healthz -> 200 text/plain        ok
//   anything else-> 404
//
// Contract: APP=http ROLE=server. Runs forever, no RESULT line.

import Foundation
import Common
import CZiti

let service = zitiServiceName()
let idPath = zitiIdentityPath()
let lang = selfLang()
let host = ProcessInfo.processInfo.hostName

func httpResponse(status: String, contentType: String, body: String) -> Data {
    let bodyData = body.data(using: .utf8) ?? Data()
    var head = "HTTP/1.1 \(status)\r\n"
    head += "Content-Type: \(contentType)\r\n"
    head += "Content-Length: \(bodyData.count)\r\n"
    head += "Connection: close\r\n"
    head += "\r\n"
    var out = head.data(using: .utf8)!
    out.append(bodyData)
    return out
}

func respond(forRequestLine line: String) -> Data {
    // line looks like: "GET /healthz HTTP/1.1"
    let parts = line.split(separator: " ")
    let path = parts.count >= 2 ? String(parts[1]) : "/"
    switch path {
    case "/healthz":
        return httpResponse(status: "200 OK", contentType: "text/plain", body: "ok")
    case "/":
        // Hand-built JSON keeps the dependency surface minimal and the output exact.
        let json = "{\"lang\":\"\(lang)\",\"host\":\"\(host)\"}"
        return httpResponse(status: "200 OK", contentType: "application/json", body: json)
    default:
        return httpResponse(status: "404 Not Found", contentType: "text/plain", body: "not found")
    }
}

guard let ziti = Ziti(fromFile: idPath) else {
    stderrLine("failed to load Ziti identity from \(idPath)")
    exit(1)
}

var listenConn: ZitiConnection?
// Per-client request buffers, keyed by connection identity.
var buffers: [ObjectIdentifier: Data] = [:]
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
        if status != Ziti.ZITI_OK {
            stderrLine("listen failed for \(service): status \(status)")
            exit(1)
        }
        stderrLine("serving HTTP for service '\(service)' over the overlay; no TCP port is open")
    }, { _, client, status in
        guard status == Ziti.ZITI_OK else { return }
        let key = ObjectIdentifier(client)
        clients[key] = client
        buffers[key] = Data()
        client.accept({ _, _ in }, { conn, data, len in
            let k = ObjectIdentifier(conn)
            if len < 0 {
                conn.close(nil); clients[k] = nil; buffers[k] = nil
                return len
            }
            if len > 0, let data = data {
                buffers[k, default: Data()].append(data)
                // Wait for end of HTTP headers, then reply once and close.
                if let buf = buffers[k],
                   let s = String(data: buf, encoding: .utf8),
                   s.contains("\r\n\r\n") {
                    let firstLine = s.split(separator: "\r\n", maxSplits: 1,
                                            omittingEmptySubsequences: false)[0]
                    let resp = respond(forRequestLine: String(firstLine))
                    conn.write(resp) { c, _ in c.close(nil) }
                    buffers[k] = nil
                }
            }
            return len
        })
    })
}

RunLoop.main.run()
