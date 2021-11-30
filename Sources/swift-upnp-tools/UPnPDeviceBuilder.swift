//
// UPnPDeviceBuilder.swift
// 

import Foundation

/**
 UPnP Device Builder Delegate
 */
public protocol UPnPDeviceBuilderDelegate {
    func onDeviceBuild(url: URL?, device: UPnPDevice?)
    func onDeviceBuildError(error: String?)
}

/**
 UPnP Device Builder
 */
public class UPnPDeviceBuilder {

    /**
     delegate
     */
    public var delegate: UPnPDeviceBuilderDelegate?

    /**
     scpd handler
     */
    public var scpdCompletionHandler: (UPnPScpdBuilder.completionHandler)?

    
    public init(delegate: UPnPDeviceBuilderDelegate?, scpdCompletionHandler: (UPnPScpdBuilder.completionHandler)?) {
        self.delegate = delegate
        self.scpdCompletionHandler = scpdCompletionHandler
    }

    /**
     build from url
     */
    public func build(url: URL) {
        HttpClient(url: url) {
            (data, response, error) in
            guard error == nil else {
                self.delegate?.onDeviceBuildError(error: "error - \(error!)")
                return
            }
            guard let data = data else {
                self.delegate?.onDeviceBuildError(error: "no data")
                return
            }
            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.delegate?.onDeviceBuildError(error: "no xml string")
                return
            }
            guard let device = UPnPDevice.read(xmlString: xmlString) else {
                self.delegate?.onDeviceBuildError(error: "UPnPDevice.read() failed")
                return
            }

            device.baseUrl = url
            
            let services = device.allServices
            for service in services {
                UPnPScpdBuilder(device: device, service: service, completionHandler: self.scpdCompletionHandler)
                  .build()
            }
            
            if let delegate = self.delegate {
                delegate.onDeviceBuild(url: url, device: device)
            }
        }.start()
    }
}
