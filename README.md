# SwiftUpnpTools

This is a swift upnp tool (library) mainly depends on IBM BlueSocket (https://github.com/IBM-Swift/BlueSocket).

## Swift version

```shell
$ swift --version
Swift version 4.2.3 (swift-4.2.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

## Dependencies

* https://github.com/IBM-Swift/BlueSocket
* https://github.com/bjtj/swift-http-server
* https://github.com/bjtj/swift-xml

## Test, Build

```shell
swift test
```

```shell
swift build
```

## How to use it?

Add it to dependency (package.swift)

```swift
dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(url: "https://github.com/bjtj/swift-upnp-tools.git", from: "0.1.6"),
  ],
```

Import package into your code

```swift
import SwiftUpnpTools
```

Sample application code (UPnPControlPoint)

https://github.com/bjtj/swift-upnp-app/blob/master/Sources/swift-upnp-app/main.swift

## API

### UPnPControlPoint

Example

```swift
let cp = UPnPControlPoint(port: 0)
cp.onDeviceAdded {
    (device) in
    DispatchQueue.global(qos: .background).async {
    ...
    }
}
```

### UPnPServer

Example

```swift
let server = UPnPServer(port: 0)
server.run()
```
