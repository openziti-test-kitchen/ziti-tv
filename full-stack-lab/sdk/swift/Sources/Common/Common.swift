// Shared helpers for the Swift interop-matrix programs.
//
// Every program in the polyglot matrix obeys one contract:
//   - read the enrolled identity JSON from ZITI_IDENTITY (default /ziti/id.json)
//   - read the service name from ZITI_SERVICE
//   - bind or dial that service by NAME over the OpenZiti overlay, no host ports
//   - clients print EXACTLY one RESULT line and exit 0 on ok, non-zero on fail
//
// The OpenZiti Swift SDK (CZiti) wraps ziti-sdk-c and is callback based on a run
// loop. It is not threadsafe: all Ziti operations must happen on the thread that
// called Ziti.run(_:). See README for the platform constraint (Apple only).

import Foundation

public let kSelfLang = "swift"

/// Path to the enrolled identity JSON. Defaults to /ziti/id.json per the matrix contract.
public func zitiIdentityPath() -> String {
    let env = ProcessInfo.processInfo.environment
    let p = env["ZITI_IDENTITY"] ?? ""
    return p.isEmpty ? "/ziti/id.json" : p
}

/// The Ziti service name to bind/dial. Required; aborts if missing.
public func zitiServiceName() -> String {
    let env = ProcessInfo.processInfo.environment
    let s = env["ZITI_SERVICE"] ?? ""
    if s.isEmpty {
        FileHandle.standardError.write("ZITI_SERVICE is not set\n".data(using: .utf8)!)
        exit(2)
    }
    return s
}

/// SELF_LANG for server responses. Defaults to "swift".
public func selfLang() -> String {
    let env = ProcessInfo.processInfo.environment
    let v = env["SELF_LANG"] ?? ""
    return v.isEmpty ? kSelfLang : v
}

/// TARGET is the last dotted segment of the service name (e.g. echo.go -> go).
public func target(from service: String) -> String {
    service.split(separator: ".").last.map(String.init) ?? service
}

public func nowMs() -> Double { Date().timeIntervalSince1970 * 1000.0 }

/// Print the single RESULT line a client is allowed to emit, then exit.
///   RESULT ok   <APP> swift-><TARGET> <ms>ms
///   RESULT fail <APP> swift-><TARGET> <reason>
public func resultOK(app: String, service: String, ms: Double) -> Never {
    let t = target(from: service)
    print("RESULT ok \(app) swift->\(t) \(Int(ms.rounded()))ms")
    exit(0)
}

public func resultFail(app: String, service: String, reason: String) -> Never {
    let t = target(from: service)
    // Keep the reason single-token-ish so the line stays parseable.
    let r = reason.replacingOccurrences(of: " ", with: "_")
    print("RESULT fail \(app) swift->\(t) \(r)")
    exit(1)
}

public func stderrLine(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}
