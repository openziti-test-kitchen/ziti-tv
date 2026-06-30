// swift-tools-version:5.7
//
// Swift entry in the OpenZiti polyglot interop matrix.
//
// IMPORTANT PLATFORM CONSTRAINT:
// The OpenZiti Swift SDK (CZiti) is distributed as a binary xcframework built
// for Apple platforms only (macOS / iOS). It wraps ziti-sdk-c but is NOT
// published for Linux, so this package builds and runs on macOS, not in a Linux
// container. See README.md. The sources here are written against the real CZiti
// API so they compile and run on a macOS host edge.

import PackageDescription

let package = Package(
    name: "zo-sdk-swift",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // CZiti binary xcframework, distributed via the -dist repo.
        // Pin to a known release; bump as needed.
        .package(
            url: "https://github.com/openziti/ziti-sdk-swift-dist.git",
            from: "0.41.55"
        )
    ],
    targets: [
        .target(
            name: "Common"
        ),
        .executableTarget(
            name: "EchoServer",
            dependencies: [
                "Common",
                .product(name: "CZiti", package: "ziti-sdk-swift-dist")
            ]
        ),
        .executableTarget(
            name: "EchoClient",
            dependencies: [
                "Common",
                .product(name: "CZiti", package: "ziti-sdk-swift-dist")
            ]
        ),
        .executableTarget(
            name: "HttpServer",
            dependencies: [
                "Common",
                .product(name: "CZiti", package: "ziti-sdk-swift-dist")
            ]
        ),
        .executableTarget(
            name: "HttpClient",
            dependencies: [
                "Common",
                .product(name: "CZiti", package: "ziti-sdk-swift-dist")
            ]
        )
    ]
)
