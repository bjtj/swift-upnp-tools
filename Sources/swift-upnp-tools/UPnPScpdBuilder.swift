//
// UPnPScpdBuilder.swift
//

import Foundation

/**
 UPnP Scpd Builder
 */
public class UPnPScpdBuilder {

    /**
     UPnP Scpd Builder Delegate
     - Parameter device
     - Parameter service
     - Parameter scpd
     - Parameter error
     */
    public typealias completionHandler = (UPnPDevice?, UPnPService?, UPnPScpd?, Error?) -> Void

    /**
     UPnP Device
     */
    public var device: UPnPDevice
    
    /**
     UPnP Service
     */
    public var service: UPnPService

    /**
     Scpd Handler
     */
    public var completionHandler: completionHandler?
    
    public init(device: UPnPDevice, service: UPnPService, completionHandler: (completionHandler)?) {
        self.device = device
        self.service = service
        self.completionHandler = completionHandler
    }

    /**
     build
     */
    public func build() {

        guard let device = service.device else {
            service.buildStatus = .failed
            service.error = UPnPError.custom(string: "service has no device")
            self.completionHandler?(nil, service, nil, service.error)
            return
        }
        guard let baseUrl = device.rootDevice.baseUrl else {
            service.buildStatus = .failed
            service.error = UPnPError.custom(string: "no base url")
            self.completionHandler?(device, service, nil, service.error)
            return
        }
        guard let scpdUrl = service.scpdUrl else {
            service.buildStatus = .failed
            service.error = UPnPError.custom(string: "no scpd url")
            self.completionHandler?(device, service, nil, service.error)
            return
        }
        guard let url = URL(string: scpdUrl, relativeTo: baseUrl) else {
            service.buildStatus = .failed
            service.error = UPnPError.custom(string: "url failed")
            self.completionHandler?(device, service, nil, service.error)
            return
        }
        
        service.buildStatus = .progress
        
        HttpClient(url: url) {
            (data, response, error) in

            guard error == nil else {
                self.service.buildStatus = .failed
                self.service.error = UPnPError.custom(string: "HttpClient - error: '\(error!)'")
                self.completionHandler?(device, self.service, nil, self.service.error)
                return
            }
            
            guard let data = data else {
                self.service.buildStatus = .failed
                self.service.error = UPnPError.custom(string: "HttpClient - error: no data")
                self.completionHandler?(device, self.service, nil, self.service.error)
                return
            }

            guard let xmlString = String(data: data, encoding: .utf8) else {
                self.service.buildStatus = .failed
                self.service.error = UPnPError.custom(string: "HttpClient - error: xml string failed")
                self.completionHandler?(device, self.service, nil, self.service.error)
                return
            }

            guard let scpd = UPnPScpd.read(xmlString: xmlString) else {
                self.service.buildStatus = .failed
                self.service.error = UPnPError.custom(string: "HttpClient - read scpd failed - URL: '\(url)'")
                self.completionHandler?(device, self.service, nil, self.service.error)
                return
            }

            self.service.scpd = scpd
            self.service.buildStatus = .completed
            self.completionHandler?(device, self.service, scpd, nil)
            
        }.start()
    }
}
