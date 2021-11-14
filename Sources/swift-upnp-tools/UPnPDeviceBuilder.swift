//
// UPnPDeviceBuilder.swift
// 

import Foundation

// UPnP Device Builder Delegate
public protocol UPnPDeviceBuilderDelegate {
    func onDeviceBuild(url: URL?, device: UPnPDevice?)
}

// UPnP Device Builder
public class UPnPDeviceBuilder {

    // delegate
    public var delegate: UPnPDeviceBuilderDelegate?

    public init(delegate: UPnPDeviceBuilderDelegate?) {
        self.delegate = delegate
    }

    // build from url
    public func build(url: URL) {
        HttpClient(url: url) {
            (data, response, error) in
            guard error == nil else {
                print("error - \(error!)")
                return
            }
            guard let data = data else {
                print("no data")
                return
            }
            guard let xmlString = String(data: data, encoding: .utf8) else {
                print("no xml string")
                return
            }
            guard let device = UPnPDevice.read(xmlString: xmlString) else {
                print("UPnPDevice.read() failed")
                print(xmlString)
                return
            }
            let services = device.allServices
            for service in services {
                UPnPScpdBuilder(service: service).build()
            }
            if let delegate = self.delegate {
                delegate.onDeviceBuild(url: url, device: device)
            }
        }.start()
    }
}
