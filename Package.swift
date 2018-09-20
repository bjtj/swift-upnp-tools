// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-upnp-tools",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "swift-upnp-tools",
            targets: ["swift-upnp-tools"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
      .package(url: "https://github.com/IBM-Swift/BlueSocket.git", from: "1.0.15"),
      .package(url: "https://github.com/bjtj/swift-http-server.git", from: "0.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "swift-upnp-tools",
            dependencies: ["Socket", "swift-http-server"]),
        .testTarget(
            name: "swift-upnp-toolsTests",
            dependencies: ["swift-upnp-tools"]),
    ]
)
