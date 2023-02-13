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

    /**
     user agent
     */
    public var userAgent: String?

    
    public init(delegate: UPnPDeviceBuilderDelegate?, userAgent: String? = nil, scpdCompletionHandler: (UPnPScpdBuilder.completionHandler)?) {
        self.delegate = delegate
        self.userAgent = userAgent
        self.scpdCompletionHandler = scpdCompletionHandler
    }

    /**
     build from url
     */
    public func build(url: URL) {
        var fields: [KeyValuePair] = []
        if let userAgent = self.userAgent {
            fields.append(KeyValuePair(key: "USER-AGENT", value: userAgent))
        }
        HttpClient(url: url, fields: fields) {
            (data, response, error) in
            guard error == nil else {
                self.delegate?.onDeviceBuildError(error: "error - \(error!)")
                return
            }
            guard getStatusCodeRange(response: response) == .success else {
                self.delegate?.onDeviceBuildError(error: "status code - \(getStatusCode(response: response, defaultValue: 0))")
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
            do {
                guard let device = try UPnPDevice.read(xmlString: xmlString) else {
                    self.delegate?.onDeviceBuildError(error: "UPnPDevice.read() failed")
                    return
                }

                device.status = .building
                device.baseUrl = url
                
                let services = device.allServices
                if services.isEmpty {
                    device.status = .completed
                } else {
                    device.buildingServiceCount = services.count
                    for service in services {
                        UPnPScpdBuilder(device: device, service: service, userAgent: self.userAgent, completionHandler: self.scpdCompletionHandler)
                          .build()
                    }
                }
                
                if let delegate = self.delegate {
                    delegate.onDeviceBuild(url: url, device: device)
                }
                
            } catch {
                self.delegate?.onDeviceBuildError(error: "\(error)")
            }
            
        }.start()
    }
}
