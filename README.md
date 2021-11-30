# SwiftUpnpTools

[![Swift](https://github.com/bjtj/swift-upnp-tools/actions/workflows/swift.yml/badge.svg)](https://github.com/bjtj/swift-upnp-tools/actions/workflows/swift.yml) [![Build Status](https://app.travis-ci.com/bjtj/swift-upnp-tools.svg?branch=master)](https://app.travis-ci.com/bjtj/swift-upnp-tools)

This is a swift upnp tool (library) mainly depends on IBM BlueSocket (<https://github.com/IBM-Swift/BlueSocket>).


## Swift version

```shell
$ swift --version
Swift version 4.2.3 (swift-4.2.3-RELEASE)
Target: x86_64-unknown-linux-gnu
```

```shell
$ swift --version
Swift version 5.5 (swift-5.5-RELEASE)
Target: x86_64-unknown-linux-gnu
```

## Dependencies

* BlueSocket: <https://github.com/IBM-Swift/BlueSocket>
* SwiftHttpServer: <https://github.com/bjtj/swift-http-server>
* SwiftXml: <https://github.com/bjtj/swift-xml>

## Build, Test

```shell
swift build
```

```shell
swift test
```

## How to use it?

Add it to dependency (package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/bjtj/swift-upnp-tools.git", from: "0.1.13"),
  ],
```

Import package into your code

```swift
import SwiftUpnpTools
```

Sample application code (UPnPControlPoint)

<https://github.com/bjtj/swift-upnp-app/blob/master/Sources/swift-upnp-app/main.swift>

## Examples

Check out `/Samples` please.

### UPnPControlPoint

```swift
let cp = UPnPControlPoint(port: 0)
cp.onDeviceAdded {
    (device) in
	
	...
}

cp.onScpd {
	(service, scpd, error) in
	
	...
}

try cp.run()

cp.sendMsearch(st: "ssdp:all", mx: 3)

...

cp.finish()
```

### UPnPServer

```swift
let server = UPnPServer(port: 0)
server.run()

guard let device = UPnPDevice.read(xmlString: deviceDescription) else {
    return
}

server.registerDevice(device: device)
server.onActionRequest {
    (service, soapRequest) in
	
    let properties = OrderedProperties()
    properties["GetLoadlevelTarget"] = "10"
    return properties
}

...

server.finish()
```
